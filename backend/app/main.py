import csv
import hmac
import io
import math
import secrets
import time
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from zoneinfo import ZoneInfo
import httpx
from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, StreamingResponse, JSONResponse
from sqlalchemy import select, update, delete, func
from sqlalchemy.exc import IntegrityError
from .config import settings
from .database import Base, engine, Session, db_session
from .models import User, Challenge, RefreshToken, Branch, Shift, Assignment, Attendance, Leave, LocationShare, Audit, OAuthState, RateBucket
from .schemas import Register, Login, Verify, Refresh, EmployeeCreate, EmployeeUpdate, BranchInput, ShiftInput, AssignmentInput, CheckInput, LocationInput, LeaveInput, Decision, Exchange
from .security import passwords, digest, sign, decode, current_user, admin, employee, tokens, consume_refresh, audit
from .delivery import deliver_otp
from .bootstrap import provision_admin

TZ = ZoneInfo('Asia/Ho_Chi_Minh')


def local_now():
    return datetime.now(TZ)


def public_user(user):
    return {key: getattr(user, key) for key in ('id', 'name', 'email', 'phone', 'role', 'department', 'title', 'active', 'verified')}


def row(item):
    result = {}
    for column in item.__table__.columns:
        value = getattr(item, column.name)
        if isinstance(value, datetime) and value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        result[column.name] = value
    return result


def get_or_404(db, cls, item_id):
    item = db.get(cls, item_id)
    if not item:
        raise HTTPException(404, 'Không tìm thấy dữ liệu')
    return item


def seed(db):
    if db.scalar(select(User.id).limit(1)):
        return
    for name, email, role in [('Nguyễn Hoàng Vũ', 'vu@demo.vn', 'employee'), ('Quản trị viên', 'admin@demo.vn', 'admin'), ('Khách hàng', 'khach@demo.vn', 'customer')]:
        db.add(User(name=name, email=email, role=role, verified=True, password_hash=passwords.hash(settings().demo_password)))
    db.flush()
    branch = Branch(name='Văn phòng Sài Gòn', address='Quận 1, TP. Hồ Chí Minh', latitude=10.7769, longitude=106.7009, radius=200)
    db.add(branch)
    db.flush()
    shift = Shift(name='Ca hành chính', start='08:30', end='17:30', branch_id=branch.id)
    db.add(shift)
    db.flush()
    for offset in range(7):
        day = (local_now().date() + timedelta(days=offset)).isoformat()
        for user in db.scalars(select(User).where(User.role != 'customer')):
            db.add(Assignment(user_id=user.id, shift_id=shift.id, work_date=day))
    db.commit()


@asynccontextmanager
async def lifespan(_):
    Base.metadata.create_all(engine)
    if settings().seed_demo:
        with Session() as db:
            seed(db)
    if settings().bootstrap_admin_email:
        with Session() as db:
            provision_admin(db, settings().bootstrap_admin_email, settings().bootstrap_admin_password)
    yield


app = FastAPI(title='NguyenHoangVu | Attendance API', version='1.0.0', lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=[value.strip() for value in settings().cors_origins.split(',') if value.strip()], allow_methods=['GET', 'POST', 'PUT', 'DELETE'], allow_headers=['Authorization', 'Content-Type'])


@app.exception_handler(IntegrityError)
async def conflict(_, exc):
    return JSONResponse(status_code=409, content={'detail': 'Dữ liệu trùng hoặc còn được tham chiếu. Kiểm tra lịch và bản ghi liên quan.'})


@app.middleware('http')
async def rate_limit(request: Request, call_next):
    if request.url.path.startswith('/auth/'):
        # Shared database buckets work across workers; never trust client forwarding headers.
        minute = int(time.time()) // 60
        key = f'{request.client.host if request.client else "unknown"}:{minute}'
        dialect = engine.dialect.name
        from sqlalchemy.dialects.postgresql import insert as pg_insert
        from sqlalchemy.dialects.sqlite import insert as sqlite_insert
        insert = pg_insert if dialect == 'postgresql' else sqlite_insert
        with Session() as db:
            statement = insert(RateBucket).values(key=key, count=1, expires=(minute + 2) * 60)
            statement = statement.on_conflict_do_update(index_elements=['key'], set_={'count': RateBucket.count + 1}).returning(RateBucket.count)
            count = db.execute(statement).scalar_one()
            db.execute(delete(RateBucket).where(RateBucket.expires < int(time.time())))
            db.commit()
        if count > 30:
            return JSONResponse(status_code=429, content={'detail': 'Quá nhiều yêu cầu xác thực. Thử lại sau một phút.'}, headers={'Retry-After': '60'})
    response = await call_next(request)
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Cache-Control'] = 'no-store'
    return response


@app.get('/health')
def health(db=Depends(db_session)):
    db.execute(select(1))
    return {'status': 'ok', 'service': 'NguyenHoangVu', 'environment': settings().environment}


def create_challenge(db, user, purpose, channel):
    code = f'{secrets.randbelow(1000000):06d}'
    challenge = Challenge(id=secrets.token_urlsafe(32), user_id=user.id, purpose=purpose, code_hash=digest(code + settings().jwt_secret), channel=channel, expires=int(time.time()) + 300)
    deliver_otp(user, channel, code)
    db.add(challenge)
    db.commit()
    return {'challenge_id': challenge.id, 'channel': channel, 'expires_in': 300, 'destination': user.email if channel == 'email' else '***' + user.phone[-4:]}


@app.post('/auth/register', status_code=201)
def register(data: Register, db=Depends(db_session)):
    email = str(data.email).lower()
    if db.scalar(select(User).where(User.email == email)):
        raise HTTPException(409, 'Email đã được đăng ký')
    # Self-registration never grants employee/admin access; admin provisions staff.
    user = User(name=data.name, email=email, phone=data.phone, password_hash=passwords.hash(data.password), role='customer')
    db.add(user)
    db.flush()
    return create_challenge(db, user, 'register', 'email')


@app.post('/auth/login')
def login(data: Login, db=Depends(db_session)):
    user = db.scalar(select(User).where(User.email == str(data.email).lower()))
    if not user or not user.active or not user.password_hash:
        passwords.verify(data.password, passwords.hash('timing-equalization'))
        raise HTTPException(401, 'Email hoặc mật khẩu không đúng')
    if not passwords.verify(data.password, user.password_hash):
        raise HTTPException(401, 'Email hoặc mật khẩu không đúng')
    if not user.verified and data.channel != 'email':
        raise HTTPException(403, 'Xác minh email trước khi sử dụng OTP SMS')
    return create_challenge(db, user, 'login' if user.verified else 'register', data.channel)


@app.post('/auth/verify')
def verify(data: Verify, db=Depends(db_session)):
    challenge = db.get(Challenge, data.challenge_id)
    if not challenge or challenge.consumed or challenge.purpose not in ('register', 'login') or challenge.expires < time.time() or challenge.attempts >= 5:
        raise HTTPException(400, 'Mã OTP hết hạn hoặc đã bị khóa')
    # Atomic attempt accounting and consume prevent parallel OTP replay.
    attempt = db.execute(update(Challenge).where(Challenge.id == challenge.id, Challenge.attempts < 5, Challenge.consumed.is_(False)).values(attempts=Challenge.attempts + 1)).rowcount
    if not attempt:
        raise HTTPException(400, 'Mã OTP đã bị khóa')
    if not hmac.compare_digest(challenge.code_hash, digest(data.code + settings().jwt_secret)):
        db.commit()
        raise HTTPException(400, 'Mã OTP không đúng')
    consumed = db.execute(update(Challenge).where(Challenge.id == challenge.id, Challenge.consumed.is_(False)).values(consumed=True)).rowcount
    if not consumed:
        db.rollback()
        raise HTTPException(400, 'Mã OTP đã được sử dụng')
    user = get_or_404(db, User, challenge.user_id)
    if not user.active:
        raise HTTPException(403, 'Tài khoản đã khóa')
    user.verified = True
    result = tokens(db, user)
    audit(db, user, 'auth.login', challenge.channel)
    db.commit()
    return {**result, 'user': public_user(user)}


@app.post('/auth/refresh')
def refresh(data: Refresh, db=Depends(db_session)):
    user = consume_refresh(db, data.refresh_token)
    result = tokens(db, user)
    db.commit()
    return {**result, 'user': public_user(user)}


@app.post('/auth/logout')
def logout(data: Refresh, db=Depends(db_session)):
    db.execute(update(RefreshToken).where(RefreshToken.digest == digest(data.refresh_token)).values(revoked=True))
    db.commit()
    return {'ok': True}


@app.get('/auth/google/start')
def google_start(app_challenge: str = '', db=Depends(db_session)):
    cfg = settings()
    if not cfg.google_client_id or not cfg.google_client_secret:
        raise HTTPException(503, 'Google OAuth chưa được cấu hình')
    if len(app_challenge) != 64 or any(c not in '0123456789abcdef' for c in app_challenge):
        raise HTTPException(400, 'Thiếu xác thực ứng dụng OAuth')
    state, nonce = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
    db.add(OAuthState(digest=digest(state), nonce=nonce, code_challenge=app_challenge, expires=int(time.time()) + 300))
    db.commit()
    return RedirectResponse('https://accounts.google.com/o/oauth2/v2/auth?' + urlencode({'client_id': cfg.google_client_id, 'redirect_uri': cfg.public_url + '/auth/google/callback', 'response_type': 'code', 'scope': 'openid email profile', 'state': state, 'nonce': nonce, 'prompt': 'select_account'}))


@app.get('/auth/google/callback')
def google_callback(code: str = '', state: str = '', error: str = '', db=Depends(db_session)):
    if error:
        raise HTTPException(400, 'Đã hủy đăng nhập Google')
    record = db.execute(delete(OAuthState).where(OAuthState.digest == digest(state), OAuthState.expires > int(time.time())).returning(OAuthState.code_challenge)).scalar_one_or_none()
    db.commit()
    if not record:
        raise HTTPException(400, 'OAuth state không hợp lệ')
    cfg = settings()
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post('https://oauth2.googleapis.com/token', data={'code': code, 'client_id': cfg.google_client_id, 'client_secret': cfg.google_client_secret, 'redirect_uri': cfg.public_url + '/auth/google/callback', 'grant_type': 'authorization_code'})
            response.raise_for_status()
            profile_response = client.get('https://openidconnect.googleapis.com/v1/userinfo', headers={'Authorization': 'Bearer ' + response.json()['access_token']})
            profile_response.raise_for_status()
            profile = profile_response.json()
        if profile.get('email_verified') is not True:
            raise HTTPException(403, 'Email Google chưa được xác minh')
    except (httpx.HTTPError, KeyError):
        raise HTTPException(502, 'Google xác thực thất bại')
    user = db.scalar(select(User).where(User.google_sub == profile['sub']))
    if not user:
        existing = db.scalar(select(User).where(User.email == profile['email'].lower()))
        if existing:
            # Do not implicitly link privileged password accounts by email alone.
            raise HTTPException(409, 'Email đã có tài khoản. Vui lòng đăng nhập bằng mật khẩu và OTP.')
        user = User(name=profile.get('name', profile['email']), email=profile['email'].lower(), google_sub=profile['sub'], verified=True, role='customer')
        db.add(user)
        db.flush()
    if not user.active:
        raise HTTPException(403, 'Tài khoản đã khóa')
    code = secrets.token_urlsafe(40)
    db.add(Challenge(id=digest(code), user_id=user.id, purpose='oauth_exchange', channel='google', code_hash=record, expires=int(time.time()) + 60))
    db.commit()
    return RedirectResponse(cfg.mobile_callback + '?' + urlencode({'code': code}))


@app.post('/auth/google/exchange')
def google_exchange(data: Exchange, db=Depends(db_session)):
    challenge = db.execute(delete(Challenge).where(Challenge.id == digest(data.code), Challenge.purpose == 'oauth_exchange', Challenge.expires > int(time.time()), Challenge.code_hash == digest(data.verifier)).returning(Challenge.user_id)).scalar_one_or_none()
    if not challenge:
        raise HTTPException(401, 'Mã OAuth đã hết hạn hoặc đã được sử dụng')
    user = get_or_404(db, User, challenge)
    if not user.active:
        raise HTTPException(403, 'Tài khoản đã khóa')
    result = tokens(db, user)
    db.commit()
    return {**result, 'user': public_user(user)}


@app.get('/me')
def me(user=Depends(current_user)):
    return public_user(user)


@app.get('/employees')
def employees(user=Depends(admin), db=Depends(db_session)):
    return [public_user(item) for item in db.scalars(select(User).order_by(User.id))]


@app.post('/employees', status_code=201)
def create_employee(data: EmployeeCreate, user=Depends(admin), db=Depends(db_session)):
    item = User(**data.model_dump(exclude={'password', 'email'}), email=str(data.email).lower(), password_hash=passwords.hash(data.password), verified=True)
    db.add(item)
    audit(db, user, 'employee.create', item.email)
    db.commit()
    return public_user(item)


@app.put('/employees/{item_id}')
def update_employee(item_id: int, data: EmployeeUpdate, user=Depends(admin), db=Depends(db_session)):
    item = get_or_404(db, User, item_id)
    if item.id == user.id and data.role != 'admin':
        raise HTTPException(400, 'Không thể tự hạ quyền quản trị')
    for key, value in data.model_dump().items():
        setattr(item, key, value)
    audit(db, user, 'employee.update', str(item_id))
    db.commit()
    return public_user(item)


@app.delete('/employees/{item_id}')
def delete_employee(item_id: int, user=Depends(admin), db=Depends(db_session)):
    item = get_or_404(db, User, item_id)
    if item.id == user.id:
        raise HTTPException(400, 'Không thể tự khóa tài khoản')
    item.active = False
    db.execute(update(RefreshToken).where(RefreshToken.user_id == item.id).values(revoked=True))
    audit(db, user, 'employee.deactivate', str(item_id))
    db.commit()
    return {'ok': True}


@app.get('/branches')
def branches(user=Depends(employee), db=Depends(db_session)):
    return [row(item) for item in db.scalars(select(Branch).order_by(Branch.id))]


@app.get('/shifts')
def shifts(user=Depends(employee), db=Depends(db_session)):
    return [row(item) for item in db.scalars(select(Shift).order_by(Shift.id))]


def register_crud(path, cls, schema):
    def create(data: schema, user=Depends(admin), db=Depends(db_session)):
        item = cls(**data.model_dump())
        db.add(item)
        audit(db, user, path + '.create')
        db.commit()
        return row(item)

    def edit(item_id: int, data: schema, user=Depends(admin), db=Depends(db_session)):
        item = get_or_404(db, cls, item_id)
        if cls is Shift and db.scalar(select(Attendance.id).where(Attendance.shift_id == item_id).limit(1)):
            raise HTTPException(409, 'Ca đã có bảng công. Tạo ca mới để bảo toàn lịch sử.')
        for key, value in data.model_dump().items():
            setattr(item, key, value)
        audit(db, user, path + '.update', str(item_id))
        db.commit()
        return row(item)

    def remove(item_id: int, user=Depends(admin), db=Depends(db_session)):
        db.delete(get_or_404(db, cls, item_id))
        audit(db, user, path + '.delete', str(item_id))
        db.commit()
        return {'ok': True}

    app.add_api_route('/' + path, create, methods=['POST'], status_code=201, name='create_' + path)
    app.add_api_route('/' + path + '/{item_id}', edit, methods=['PUT'], name='edit_' + path)
    app.add_api_route('/' + path + '/{item_id}', remove, methods=['DELETE'], name='delete_' + path)


register_crud('branches', Branch, BranchInput)
register_crud('shifts', Shift, ShiftInput)


@app.get('/assignments')
def assignments(user=Depends(employee), db=Depends(db_session)):
    query = select(Assignment).order_by(Assignment.work_date)
    if user.role != 'admin':
        query = query.where(Assignment.user_id == user.id)
    return [row(item) for item in db.scalars(query)]


def assignment_values(db, data):
    person = get_or_404(db, User, data.user_id)
    get_or_404(db, Shift, data.shift_id)
    if not person.active or person.role == 'customer':
        raise HTTPException(400, 'Chỉ phân ca cho nhân viên đang hoạt động')
    return {**data.model_dump(), 'work_date': data.work_date.isoformat()}


@app.post('/assignments', status_code=201)
def assign(data: AssignmentInput, user=Depends(admin), db=Depends(db_session)):
    item = Assignment(**assignment_values(db, data))
    db.add(item)
    audit(db, user, 'assignment.create')
    db.commit()
    return row(item)


@app.put('/assignments/{item_id}')
def edit_assignment(item_id: int, data: AssignmentInput, user=Depends(admin), db=Depends(db_session)):
    item = get_or_404(db, Assignment, item_id)
    if db.scalar(select(Attendance.id).where(Attendance.user_id == item.user_id, Attendance.work_date == item.work_date)):
        raise HTTPException(409, 'Không sửa lịch đã chấm công')
    for key, value in assignment_values(db, data).items():
        setattr(item, key, value)
    audit(db, user, 'assignment.update', str(item_id))
    db.commit()
    return row(item)


@app.delete('/assignments/{item_id}')
def delete_assignment(item_id: int, user=Depends(admin), db=Depends(db_session)):
    item = get_or_404(db, Assignment, item_id)
    if db.scalar(select(Attendance.id).where(Attendance.user_id == item.user_id, Attendance.work_date == item.work_date)):
        raise HTTPException(409, 'Không xóa lịch đã chấm công')
    db.delete(item)
    audit(db, user, 'assignment.delete', str(item_id))
    db.commit()
    return {'ok': True}


@app.get('/qr/{branch_id}')
def qr(branch_id: int, user=Depends(admin), db=Depends(db_session)):
    branch = get_or_404(db, Branch, branch_id)
    return {'qr_token': sign({'kind': 'attendance_qr', 'branch_id': branch.id, 'nonce': secrets.token_urlsafe(12)}, 45), 'expires_in': 45}


def distance_m(lat1, lon1, lat2, lon2):
    a, b = math.radians(lat2 - lat1), math.radians(lon2 - lon1)
    h = math.sin(a / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(b / 2) ** 2
    return 6371000 * 2 * math.atan2(math.sqrt(h), math.sqrt(max(0, 1 - h)))


def validate_attendance(db, user, data):
    today = local_now().date().isoformat()
    assignment = db.scalar(select(Assignment).where(Assignment.user_id == user.id, Assignment.work_date == today))
    if not assignment:
        raise HTTPException(400, 'Bạn chưa được phân ca hôm nay')
    if db.scalar(select(Leave.id).where(Leave.user_id == user.id, Leave.status == 'approved', Leave.kind != 'Làm từ xa', Leave.start_date <= today, Leave.end_date >= today)):
        raise HTTPException(409, 'Hôm nay có đơn nghỉ đã được duyệt')
    shift = get_or_404(db, Shift, assignment.shift_id)
    branch = get_or_404(db, Branch, shift.branch_id)
    try:
        qr_payload = decode(data.qr_token, 'attendance_qr')
    except HTTPException:
        raise HTTPException(400, 'QR không hợp lệ hoặc đã hết hạn. Vui lòng quét mã mới.')
    if qr_payload.get('branch_id') != branch.id:
        raise HTTPException(400, 'QR không thuộc chi nhánh được phân ca')
    distance = distance_m(data.latitude, data.longitude, branch.latitude, branch.longitude)
    if data.accuracy > min(100, branch.radius / 2) or distance > branch.radius:
        raise HTTPException(400, f'Vị trí ngoài phạm vi chấm công ({round(distance)}m) hoặc GPS chưa đủ chính xác')
    return today, shift, distance


@app.post('/attendance/check-in', status_code=201)
def check_in(data: CheckInput, user=Depends(employee), db=Depends(db_session)):
    today, shift, distance = validate_attendance(db, user, data)
    if db.scalar(select(Attendance.id).where(Attendance.user_id == user.id, Attendance.work_date == today)):
        raise HTTPException(409, 'Bạn đã vào ca hôm nay')
    start = datetime.fromisoformat(today + 'T' + shift.start).replace(tzinfo=TZ)
    if local_now() < start - timedelta(hours=2):
        raise HTTPException(400, 'Chỉ được vào ca trước giờ bắt đầu tối đa 2 giờ')
    end = datetime.fromisoformat(today + 'T' + shift.end).replace(tzinfo=TZ)
    if local_now() >= end:
        raise HTTPException(400, 'Ca đã kết thúc, không thể vào ca mới')
    item = Attendance(user_id=user.id, shift_id=shift.id, work_date=today, latitude=data.latitude, longitude=data.longitude, accuracy=data.accuracy, distance=distance, late_minutes=max(0, int((local_now() - start).total_seconds() // 60)))
    db.add(item)
    audit(db, user, 'attendance.check_in')
    db.commit()
    return row(item)


@app.post('/attendance/check-out')
def check_out(data: CheckInput, user=Depends(employee), db=Depends(db_session)):
    today, _, _ = validate_attendance(db, user, data)
    item = db.scalar(select(Attendance).where(Attendance.user_id == user.id, Attendance.work_date == today))
    if not item or item.check_out:
        raise HTTPException(409, 'Chưa vào ca hoặc đã kết thúc ca')
    changed = db.execute(update(Attendance).where(Attendance.id == item.id, Attendance.check_out.is_(None)).values(check_out=datetime.now(timezone.utc))).rowcount
    if not changed:
        raise HTTPException(409, 'Ca đã được kết thúc')
    db.refresh(item)
    audit(db, user, 'attendance.check_out')
    db.commit()
    return row(item)


@app.get('/attendance')
def attendance(user=Depends(employee), db=Depends(db_session)):
    query = select(Attendance).order_by(Attendance.work_date.desc()).limit(500)
    if user.role != 'admin':
        query = query.where(Attendance.user_id == user.id)
    return [row(item) for item in db.scalars(query)]


@app.get('/attendance/export')
def export(user=Depends(admin), db=Depends(db_session)):
    output = io.StringIO()
    output.write('\ufeff')
    writer = csv.writer(output)
    writer.writerow(['Employee ID', 'Name', 'Date', 'Check in UTC', 'Check out UTC', 'Late minutes'])
    for item, person in db.execute(select(Attendance, User).join(User, User.id == Attendance.user_id).order_by(Attendance.work_date.desc())):
        # Protect spreadsheet consumers from formula injection in names.
        name = "'" + person.name if person.name.lstrip().startswith(('=', '+', '-', '@')) else person.name
        writer.writerow([person.id, name, item.work_date, item.check_in, item.check_out, item.late_minutes])
    return StreamingResponse(iter([output.getvalue()]), media_type='text/csv; charset=utf-8', headers={'Content-Disposition': 'attachment; filename=attendance.csv'})


@app.get('/leaves')
def leaves(user=Depends(employee), db=Depends(db_session)):
    query = select(Leave).order_by(Leave.id.desc())
    if user.role != 'admin':
        query = query.where(Leave.user_id == user.id)
    return [row(item) for item in db.scalars(query)]


def leave_values(data):
    if data.start_date < local_now().date():
        raise HTTPException(400, 'Ngày nghỉ phải từ hôm nay')
    return {**data.model_dump(), 'start_date': data.start_date.isoformat(), 'end_date': data.end_date.isoformat()}


def check_overlap(db, user_id, values, exclude_id=0):
    if db.scalar(select(Leave.id).where(Leave.user_id == user_id, Leave.id != exclude_id, Leave.status != 'rejected', Leave.start_date <= values['end_date'], Leave.end_date >= values['start_date'])):
        raise HTTPException(409, 'Đã có đơn nghỉ trong khoảng ngày này')


@app.post('/leaves', status_code=201)
def create_leave(data: LeaveInput, user=Depends(employee), db=Depends(db_session)):
    values = leave_values(data)
    check_overlap(db, user.id, values)
    item = Leave(user_id=user.id, **values)
    db.add(item)
    audit(db, user, 'leave.create')
    db.commit()
    return row(item)


def own_pending(db, item_id, user):
    item = get_or_404(db, Leave, item_id)
    if item.user_id != user.id:
        raise HTTPException(403, 'Đơn không thuộc tài khoản của bạn')
    if item.status != 'pending':
        raise HTTPException(409, 'Chỉ được sửa hoặc xóa đơn đang chờ duyệt')
    return item


@app.put('/leaves/{item_id}')
def edit_leave(item_id: int, data: LeaveInput, user=Depends(employee), db=Depends(db_session)):
    item = own_pending(db, item_id, user)
    values = leave_values(data)
    check_overlap(db, user.id, values, item_id)
    for key, value in values.items():
        setattr(item, key, value)
    audit(db, user, 'leave.update', str(item_id))
    db.commit()
    return row(item)


@app.delete('/leaves/{item_id}')
def delete_leave(item_id: int, user=Depends(employee), db=Depends(db_session)):
    db.delete(own_pending(db, item_id, user))
    audit(db, user, 'leave.delete', str(item_id))
    db.commit()
    return {'ok': True}


@app.post('/leaves/{item_id}/decision')
def decide_leave(item_id: int, data: Decision, user=Depends(admin), db=Depends(db_session)):
    item = get_or_404(db, Leave, item_id)
    if item.user_id == user.id:
        raise HTTPException(403, 'Không thể tự duyệt đơn của mình')
    if item.status != 'pending':
        raise HTTPException(409, 'Đơn đã được xử lý')
    if data.status == 'approved' and item.kind != 'Làm từ xa' and db.scalar(select(Attendance.id).where(Attendance.user_id == item.user_id, Attendance.work_date >= item.start_date, Attendance.work_date <= item.end_date).limit(1)):
        raise HTTPException(409, 'Khoảng nghỉ đã có bảng công. Cần điều chỉnh đơn trước khi duyệt.')
    changed = db.execute(update(Leave).where(Leave.id == item.id, Leave.status == 'pending').values(status=data.status, reviewer_id=user.id)).rowcount
    if not changed:
        raise HTTPException(409, 'Đơn đã được xử lý')
    db.refresh(item)
    audit(db, user, 'leave.' + data.status, str(item_id))
    db.commit()
    return row(item)


@app.post('/locations/share')
def share_location(data: LocationInput, user=Depends(employee), db=Depends(db_session)):
    db.execute(delete(LocationShare).where(LocationShare.user_id == user.id))
    item = LocationShare(user_id=user.id, **data.model_dump(), expires=int(time.time()) + 3600)
    db.add(item)
    audit(db, user, 'location.share', 'expires in 1 hour')
    db.commit()
    return row(item)


@app.delete('/locations/share')
def stop_share(user=Depends(employee), db=Depends(db_session)):
    db.execute(delete(LocationShare).where(LocationShare.user_id == user.id))
    audit(db, user, 'location.stop')
    db.commit()
    return {'ok': True}


@app.get('/locations')
def locations(user=Depends(admin), db=Depends(db_session)):
    db.execute(delete(LocationShare).where(LocationShare.expires <= int(time.time())))
    result = [row(item) for item in db.scalars(select(LocationShare))]
    db.commit()
    return result


@app.get('/insights')
def insights(user=Depends(employee), db=Depends(db_session)):
    week_start = (local_now().date() - timedelta(days=local_now().weekday())).isoformat()
    records = list(db.scalars(select(Attendance).where(Attendance.user_id == user.id, Attendance.work_date >= week_start)))
    minutes, overtime = 0, 0
    for item in records:
        start = item.check_in.replace(tzinfo=timezone.utc) if item.check_in.tzinfo is None else item.check_in
        end = item.check_out or datetime.now(timezone.utc)
        end = end.replace(tzinfo=timezone.utc) if end.tzinfo is None else end
        shift = db.get(Shift, item.shift_id)
        worked = max(0, int((end - start).total_seconds() // 60) - (shift.break_minutes if shift else 60))
        minutes += worked
        overtime += max(0, worked - 480)
    load = min(100, round(minutes / (40 * 60) * 100))
    suggestions = []
    if overtime >= 120:
        suggestions.append('Bạn đã làm thêm từ 2 giờ tuần này. Cân nhắc trao đổi quản lý để nghỉ bù.')
    if any(item.check_out is None for item in records):
        suggestions.append('Đang trong ca: đặt nhắc nhở nghỉ ngắn sau mỗi 90 phút làm việc.')
    if minutes > 40 * 60:
        suggestions.append('Tổng giờ tuần vượt 40 giờ. Xem lại lịch để tránh quá tải.')
    if not suggestions:
        suggestions.append('Nhịp làm việc đang cân bằng. Giữ giờ nghỉ trưa và kết thúc ca đúng lịch.')
    return {'week_minutes': minutes, 'overtime_minutes': overtime, 'load_percent': load, 'suggestions': suggestions, 'disclaimer': 'Gợi ý theo giờ công đã ghi nhận; không phải đánh giá y tế hay năng suất.'}


@app.get('/audit')
def audit_logs(user=Depends(admin), db=Depends(db_session)):
    return [row(item) for item in db.scalars(select(Audit).order_by(Audit.id.desc()).limit(200))]
