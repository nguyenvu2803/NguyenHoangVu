import hashlib
import hmac
import secrets
import time
from datetime import datetime, timezone
import jwt
from pwdlib import PasswordHash
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select, update
from .config import settings
from .database import db_session
from .models import User, RefreshToken, Audit

passwords = PasswordHash.recommended()
bearer = HTTPBearer(auto_error=False)


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def sign(payload, seconds=900):
    return jwt.encode({**payload, 'iat': int(time.time()), 'exp': int(time.time()) + seconds, 'iss': 'nguyenhoangvu'}, settings().jwt_secret, algorithm='HS256')


def decode(token, kind):
    try:
        payload = jwt.decode(token, settings().jwt_secret, algorithms=['HS256'], issuer='nguyenhoangvu', options={'require': ['exp', 'iat', 'iss', 'kind']})
        if payload['kind'] != kind:
            raise ValueError()
        return payload
    except (jwt.PyJWTError, ValueError):
        raise HTTPException(401, 'Phiên xác thực không hợp lệ hoặc đã hết hạn')


def current_user(credentials: HTTPAuthorizationCredentials = Depends(bearer), db=Depends(db_session)):
    if not credentials:
        raise HTTPException(401, 'Vui lòng đăng nhập')
    payload = decode(credentials.credentials, 'access')
    user = db.get(User, int(payload['sub']))
    if not user or not user.active or not user.verified:
        raise HTTPException(401, 'Tài khoản không hoạt động')
    return user


def admin(user=Depends(current_user)):
    if user.role != 'admin':
        raise HTTPException(403, 'Chỉ quản trị viên được thực hiện')
    return user


def employee(user=Depends(current_user)):
    if user.role not in ('admin', 'employee'):
        raise HTTPException(403, 'Chức năng dành cho nhân viên')
    return user


def tokens(db, user):
    raw = secrets.token_urlsafe(48)
    db.add(RefreshToken(digest=digest(raw), user_id=user.id, expires=int(time.time()) + 30 * 86400))
    return {'access_token': sign({'sub': str(user.id), 'kind': 'access'}), 'refresh_token': raw, 'token_type': 'bearer', 'expires_in': 900}


def consume_refresh(db, raw):
    # Atomic consume prevents concurrent refresh requests from reusing one credential.
    record = db.get(RefreshToken, digest(raw))
    if not record or record.expires < time.time():
        raise HTTPException(401, 'Phiên thiết bị đã hết hạn')
    changed = db.execute(update(RefreshToken).where(RefreshToken.digest == record.digest, RefreshToken.revoked.is_(False)).values(revoked=True)).rowcount
    if not changed:
        raise HTTPException(401, 'Phiên thiết bị đã được sử dụng')
    user = db.get(User, record.user_id)
    if not user or not user.active or not user.verified:
        raise HTTPException(401, 'Tài khoản không hoạt động')
    return user


def audit(db, actor, action, detail=''):
    db.add(Audit(actor_id=actor.id if actor else None, action=action, detail=detail))
