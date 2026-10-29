from datetime import date, timedelta
from sqlalchemy import select
from app.database import Session
from app.models import User, Challenge, Attendance, RefreshToken, Leave
from app.security import sign, digest


def test_health(ctx):
    c, _, _ = ctx
    assert c.get('/health').json()['status'] == 'ok'


def test_registration_verifies_and_never_grants_staff(ctx):
    c, _, codes = ctx
    payload = {'name': 'New Person', 'email': 'new@example.com', 'password': 'LongPassword123!', 'role': 'admin'}
    response = c.post('/auth/register', json=payload)
    assert response.status_code == 201
    assert 'code' not in response.json()
    result = c.post('/auth/verify', json={'challenge_id': response.json()['challenge_id'], 'code': codes['new@example.com']})
    assert result.status_code == 200
    assert result.json()['user']['role'] == 'customer'
    assert c.get('/employees', headers={'Authorization': 'Bearer ' + result.json()['access_token']}).status_code == 403


def test_password_plus_otp_and_replay_blocked(ctx):
    c, _, codes = ctx
    assert c.post('/auth/login', json={'email': 'employee@example.com', 'password': 'bad'}).status_code == 401
    challenge = c.post('/auth/login', json={'email': 'employee@example.com', 'password': 'Password123!'}).json()
    assert 'access_token' not in challenge
    data = {'challenge_id': challenge['challenge_id'], 'code': codes['employee@example.com']}
    result = c.post('/auth/verify', json=data)
    assert result.status_code == 200
    assert c.post('/auth/verify', json=data).status_code == 400
    assert c.get('/me', headers={'Authorization': 'Bearer ' + result.json()['access_token']}).status_code == 200


def test_otp_lock_after_five_attempts(ctx):
    c, _, codes = ctx
    challenge = c.post('/auth/login', json={'email': 'employee@example.com', 'password': 'Password123!'}).json()
    wrong = '111111' if codes['employee@example.com'] != '111111' else '222222'
    for _ in range(5):
        assert c.post('/auth/verify', json={'challenge_id': challenge['challenge_id'], 'code': wrong}).status_code == 400
    assert c.post('/auth/verify', json={'challenge_id': challenge['challenge_id'], 'code': codes['employee@example.com']}).status_code == 400


def test_refresh_rotation_logout_and_locked_account(ctx):
    c, h, codes = ctx
    challenge = c.post('/auth/login', json={'email': 'employee@example.com', 'password': 'Password123!'}).json()
    result = c.post('/auth/verify', json={'challenge_id': challenge['challenge_id'], 'code': codes['employee@example.com']}).json()
    token = result['refresh_token']
    fresh = c.post('/auth/refresh', json={'refresh_token': token})
    assert fresh.status_code == 200
    assert c.post('/auth/refresh', json={'refresh_token': token}).status_code == 401
    new_token = fresh.json()['refresh_token']
    assert c.post('/auth/logout', json={'refresh_token': new_token}).status_code == 200
    assert c.post('/auth/refresh', json={'refresh_token': new_token}).status_code == 401
    assert c.delete('/employees/2', headers=h['admin']).status_code == 200
    assert c.get('/me', headers=h['employee']).status_code == 401


def test_rbac_protects_all_admin_operations(ctx):
    c, h, _ = ctx
    for path in ('/employees', '/qr/1', '/locations', '/audit'):
        assert c.get(path, headers=h['employee']).status_code == 403
    for path in ('/attendance', '/shifts', '/branches', '/assignments', '/leaves', '/insights'):
        assert c.get(path, headers=h['customer']).status_code == 403
    assert c.get('/employees').status_code == 401
    assert c.post('/employees', headers=h['employee'], json={'name': 'Other', 'email': 'o@example.com', 'password': 'Password123!'}).status_code == 403


def test_employee_crud_protects_self_and_history(ctx):
    c, h, _ = ctx
    data = {'name': 'New Staff', 'email': 'staff@example.com', 'password': 'Password123!', 'department': 'IT', 'title': 'Engineer', 'role': 'employee'}
    created = c.post('/employees', headers=h['admin'], json=data)
    assert created.status_code == 201
    item = created.json()
    assert 'password_hash' not in item
    update = {key: item[key] for key in ('name', 'phone', 'role', 'department', 'title')}
    update['name'] = 'Updated Name'
    assert c.put(f'/employees/{item["id"]}', headers=h['admin'], json=update).json()['name'] == 'Updated Name'
    assert c.delete(f'/employees/{item["id"]}', headers=h['admin']).status_code == 200
    assert c.delete('/employees/1', headers=h['admin']).status_code == 400
    assert c.post('/employees', headers=h['admin'], json=data).status_code == 409


def test_branch_and_shift_crud_and_foreign_keys(ctx):
    c, h, _ = ctx
    data = {'name': 'New Office', 'address': 'Hanoi', 'latitude': 21.02, 'longitude': 105.85, 'radius': 100}
    branch = c.post('/branches', headers=h['admin'], json=data)
    assert branch.status_code == 201
    branch_id = branch.json()['id']
    assert c.put(f'/branches/{branch_id}', headers=h['admin'], json={**data, 'radius': 150}).json()['radius'] == 150
    shift_data = {'name': 'Morning', 'start': '09:00', 'end': '18:00', 'branch_id': branch_id, 'break_minutes': 60}
    shift = c.post('/shifts', headers=h['admin'], json=shift_data)
    assert shift.status_code == 201
    shift_id = shift.json()['id']
    assert c.delete(f'/branches/{branch_id}', headers=h['admin']).status_code == 409
    assert c.put(f'/shifts/{shift_id}', headers=h['admin'], json={**shift_data, 'name': 'Updated shift'}).status_code == 200
    assert c.delete(f'/shifts/{shift_id}', headers=h['admin']).status_code == 200
    assert c.delete(f'/branches/{branch_id}', headers=h['admin']).status_code == 200
    assert c.post('/shifts', headers=h['admin'], json={**shift_data, 'branch_id': 999}).status_code == 409
    assert c.post('/shifts', headers=h['admin'], json={**shift_data, 'end': '08:00'}).status_code == 422


def test_assignment_crud_no_duplicate_or_customer(ctx):
    c, h, _ = ctx
    data = {'user_id': 2, 'shift_id': 1, 'work_date': '2026-10-30'}
    response = c.post('/assignments', headers=h['admin'], json=data)
    assert response.status_code == 201
    item_id = response.json()['id']
    assert c.post('/assignments', headers=h['admin'], json=data).status_code == 409
    assert c.put(f'/assignments/{item_id}', headers=h['admin'], json={**data, 'work_date': '2026-10-31'}).status_code == 200
    assert c.delete(f'/assignments/{item_id}', headers=h['admin']).status_code == 200
    assert c.post('/assignments', headers=h['admin'], json={**data, 'user_id': 3}).status_code == 400


def attendance_payload(c, h):
    qr = c.get('/qr/1', headers=h['admin']).json()['qr_token']
    return {'latitude': 10.7769, 'longitude': 106.7009, 'accuracy': 10, 'qr_token': qr}


def test_checkin_checkout_geofence_qr_duplicates_and_isolation(ctx):
    c, h, _ = ctx
    payload = attendance_payload(c, h)
    assert c.post('/attendance/check-in', headers=h['employee'], json={**payload, 'latitude': 11}).status_code == 400
    assert c.post('/attendance/check-in', headers=h['employee'], json={**payload, 'accuracy': 110}).status_code == 422
    assert c.post('/attendance/check-in', headers=h['employee'], json={**payload, 'qr_token': 'x' * 30}).status_code == 400
    response = c.post('/attendance/check-in', headers=h['employee'], json=payload)
    assert response.status_code == 201
    assert response.json()['late_minutes'] == 30
    assert c.post('/attendance/check-in', headers=h['employee'], json=payload).status_code == 409
    assert len(c.get('/attendance', headers=h['employee']).json()) == 1
    assert c.post('/attendance/check-out', headers=h['employee'], json=payload).status_code == 200
    assert c.post('/attendance/check-out', headers=h['employee'], json=payload).status_code == 409
    assert c.delete('/assignments/1', headers=h['admin']).status_code == 409


def test_expired_wrong_branch_and_wrong_token_kind(ctx):
    c, h, _ = ctx
    payload = attendance_payload(c, h)
    for token in (sign({'kind': 'attendance_qr', 'branch_id': 1}, -1), sign({'kind': 'attendance_qr', 'branch_id': 999}), sign({'kind': 'access', 'sub': '2'})):
        response = c.post('/attendance/check-in', headers=h['employee'], json={**payload, 'qr_token': token})
        assert response.status_code in (400, 401)


def test_leave_crud_owner_decision_and_overlap(ctx):
    c, h, _ = ctx
    data = {'kind': 'Nghỉ phép', 'start_date': '2026-10-30', 'end_date': '2026-10-31', 'reason': 'Family visit'}
    response = c.post('/leaves', headers=h['employee'], json=data)
    assert response.status_code == 201
    item_id = response.json()['id']
    assert c.post('/leaves', headers=h['employee'], json=data).status_code == 409
    assert c.put(f'/leaves/{item_id}', headers=h['admin'], json=data).status_code == 403
    assert c.put(f'/leaves/{item_id}', headers=h['employee'], json={**data, 'reason': 'Updated reason'}).status_code == 200
    assert c.post(f'/leaves/{item_id}/decision', headers=h['employee'], json={'status': 'approved'}).status_code == 403
    assert c.post(f'/leaves/{item_id}/decision', headers=h['admin'], json={'status': 'approved'}).status_code == 200
    assert c.put(f'/leaves/{item_id}', headers=h['employee'], json=data).status_code == 409
    assert c.delete(f'/leaves/{item_id}', headers=h['employee']).status_code == 409
    next_data = {**data, 'start_date': '2026-11-02', 'end_date': '2026-11-02'}
    second = c.post('/leaves', headers=h['employee'], json=next_data).json()
    assert c.delete(f'/leaves/{second["id"]}', headers=h['employee']).status_code == 200
    assert c.get('/leaves', headers=h['employee']).json()[0]['user_id'] == 2


def test_approved_leave_blocks_check_in(ctx):
    c, h, _ = ctx
    response = c.post('/leaves', headers=h['employee'], json={'kind': 'Nghỉ phép', 'start_date': '2026-10-29', 'end_date': '2026-10-29', 'reason': 'Family event'})
    c.post(f'/leaves/{response.json()["id"]}/decision', headers=h['admin'], json={'status': 'approved'})
    assert c.post('/attendance/check-in', headers=h['employee'], json=attendance_payload(c, h)).status_code == 409


def test_location_sharing_expires_and_stops(ctx):
    c, h, _ = ctx
    payload = {'latitude': 10.7769, 'longitude': 106.7009, 'accuracy': 10}
    assert c.post('/locations/share', headers=h['employee'], json=payload).status_code == 200
    assert len(c.get('/locations', headers=h['admin']).json()) == 1
    assert c.get('/locations', headers=h['employee']).status_code == 403
    assert c.delete('/locations/share', headers=h['employee']).status_code == 200
    assert c.get('/locations', headers=h['admin']).json() == []


def test_insights_export_and_audit(ctx):
    c, h, _ = ctx
    assert c.get('/insights', headers=h['employee']).json()['week_minutes'] == 0
    assert c.get('/attendance/export', headers=h['employee']).status_code == 403
    export = c.get('/attendance/export', headers=h['admin'])
    assert export.status_code == 200
    assert 'Late minutes' in export.text
    c.post('/locations/share', headers=h['employee'], json={'latitude': 10, 'longitude': 106, 'accuracy': 1})
    assert c.get('/audit', headers=h['admin']).json()[0]['action'] == 'location.share'


def test_unconfigured_google_and_oauth_state(ctx):
    c, _, _ = ctx
    assert c.get('/auth/google/start', follow_redirects=False).status_code == 503
    assert c.get('/auth/google/callback?code=test&state=bad').status_code == 400
    assert c.post('/auth/google/exchange', json={'code': 'x' * 30, 'verifier': 'v' * 64}).status_code == 401


def test_validation_invalid_dates_coordinates_and_short_password(ctx):
    c, h, _ = ctx
    assert c.post('/auth/register', json={'name': 'User', 'email': 'new@example.com', 'password': 'short'}).status_code == 422
    assert c.post('/locations/share', headers=h['employee'], json={'latitude': 100, 'longitude': 106, 'accuracy': 10}).status_code == 422
    assert c.post('/leaves', headers=h['employee'], json={'kind': 'Nghỉ phép', 'start_date': '2026-11-02', 'end_date': '2026-11-01', 'reason': 'Valid reason'}).status_code == 422


def test_login_rate_limit(ctx):
    c, _, _ = ctx
    for _ in range(30):
        c.post('/auth/logout', json={'refresh_token': 'x' * 30})
    assert c.post('/auth/logout', json={'refresh_token': 'x' * 30}).status_code == 429


def test_oauth_callback_verifier_and_one_time_exchange(ctx, monkeypatch):
    from app.config import settings
    from app.models import OAuthState
    from app import main
    import time
    c, _, _ = ctx
    verifier = 'secure-app-verifier-' + 'v' * 48
    with Session() as db:
        db.add(OAuthState(digest=digest('oauth-state'), nonce='nonce', code_challenge=digest(verifier), expires=int(time.time()) + 300))
        db.commit()

    class Response:
        def __init__(self, data): self.data = data
        def raise_for_status(self): pass
        def json(self): return self.data

    class GoogleClient:
        def __init__(self, **kwargs): pass
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def post(self, *args, **kwargs): return Response({'access_token': 'google-access-token'})
        def get(self, *args, **kwargs): return Response({'sub': 'google-subject', 'email': 'google@example.com', 'email_verified': True, 'name': 'Google Person'})

    monkeypatch.setattr(main.httpx, 'Client', GoogleClient)
    response = c.get('/auth/google/callback?code=provider-code&state=oauth-state', follow_redirects=False)
    assert response.status_code == 307
    from urllib.parse import urlparse, parse_qs
    code = parse_qs(urlparse(response.headers['location']).query)['code'][0]
    assert c.post('/auth/google/exchange', json={'code': code, 'verifier': 'wrong' * 12}).status_code == 401
    result = c.post('/auth/google/exchange', json={'code': code, 'verifier': verifier})
    assert result.status_code == 200
    assert result.json()['user']['role'] == 'customer'
    assert c.post('/auth/google/exchange', json={'code': code, 'verifier': verifier}).status_code == 401
    assert c.get('/auth/google/callback?code=provider-code&state=oauth-state', follow_redirects=False).status_code == 400


def test_oauth_start_requires_app_verifier_binding(ctx, monkeypatch):
    from app.config import settings
    c, _, _ = ctx
    monkeypatch.setattr(settings(), 'google_client_id', 'test-id')
    monkeypatch.setattr(settings(), 'google_client_secret', 'test-secret')
    assert c.get('/auth/google/start', follow_redirects=False).status_code == 400
    response = c.get('/auth/google/start?app_challenge=' + 'a' * 64, follow_redirects=False)
    assert response.status_code == 307
    assert response.headers['location'].startswith('https://accounts.google.com/')


def test_cannot_approve_leave_after_checkin_or_rewrite_shift_history(ctx):
    c, h, _ = ctx
    assert c.post('/attendance/check-in', headers=h['employee'], json=attendance_payload(c, h)).status_code == 201
    response = c.post('/leaves', headers=h['employee'], json={'kind': 'Nghỉ phép', 'start_date': '2026-10-29', 'end_date': '2026-10-29', 'reason': 'Family event'})
    assert c.post(f'/leaves/{response.json()["id"]}/decision', headers=h['admin'], json={'status': 'approved'}).status_code == 409
    assert c.put('/shifts/1', headers=h['admin'], json={'name': 'Changed', 'start': '09:00', 'end': '18:00', 'branch_id': 1, 'break_minutes': 60}).status_code == 409
    assert c.post('/attendance/check-out', headers=h['employee'], json=attendance_payload(c, h)).status_code == 200
    assert c.get('/attendance', headers=h['employee']).json()[0]['check_in'].endswith('+00:00')


def test_production_config_fails_closed_for_demo_and_placeholder_secret():
    import pytest
    from app.config import Settings
    config = {'environment': 'production', 'database_url': 'postgresql://user:pass@db/attendance', 'public_url': 'https://api.example.com', 'jwt_secret': 'unique-unit-test-only-secret-' + 'x' * 40, 'smtp_host': 'smtp.example.com', 'smtp_user': 'test', 'smtp_password': 'test', 'smtp_from': 'test@example.com', 'seed_demo': False}
    Settings(**config).validate_production()
    for changes in ({'seed_demo': True}, {'jwt_secret': 'REPLACE_WITH_AT_LEAST_48_RANDOM_CHARACTERS'}, {'public_url': 'http://api.example.com'}, {'database_url': 'sqlite:///db'}, {'smtp_password': ''}):
        with pytest.raises(RuntimeError):
            Settings(**{**config, **changes}).validate_production()


def test_sms_cannot_bypass_registration_email_verification(ctx):
    c, _, codes = ctx
    data = {'name': 'New Person', 'email': 'unverified@example.com', 'password': 'LongPassword123!', 'phone': '+84901234567'}
    assert c.post('/auth/register', json=data).status_code == 201
    assert c.post('/auth/login', json={'email': data['email'], 'password': data['password'], 'channel': 'sms'}).status_code == 403
    response = c.post('/auth/login', json={'email': data['email'], 'password': data['password'], 'channel': 'email'})
    assert response.status_code == 200
    assert c.post('/auth/verify', json={'challenge_id': response.json()['challenge_id'], 'code': codes[data['email']]}).status_code == 200
    assert c.post('/auth/login', json={'email': data['email'], 'password': data['password'], 'channel': 'sms'}).status_code == 200
