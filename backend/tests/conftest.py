import os
import tempfile
from pathlib import Path

_temp = tempfile.TemporaryDirectory(prefix='nguyenhoangvu-tests-')
os.environ['DATABASE_URL'] = 'sqlite:///' + str(Path(_temp.name) / 'test.db')
os.environ['ENVIRONMENT'] = 'development'
os.environ['SEED_DEMO'] = 'false'
os.environ['JWT_SECRET'] = 'unit-test-secret-only-012345678901234567890123456789'

import pytest
from datetime import datetime
from zoneinfo import ZoneInfo
from fastapi.testclient import TestClient
from app.database import Base, engine, Session
from app.models import User, Branch, Shift, Assignment
from app.security import passwords, sign
from app.main import app


@pytest.fixture()
def ctx(monkeypatch):
    from app import main
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    codes = {}
    monkeypatch.setattr(main, 'deliver_otp', lambda user, channel, code: codes.update({user.email: code}))
    monkeypatch.setattr(main, 'local_now', lambda: datetime(2026, 10, 29, 9, tzinfo=ZoneInfo('Asia/Ho_Chi_Minh')))
    with Session() as db:
        users = []
        for role in ('admin', 'employee', 'customer'):
            user = User(name=role, email=role+'@example.com', role=role, password_hash=passwords.hash('Password123!'), verified=True)
            db.add(user); db.flush(); users.append(user)
        branch = Branch(name='Office', address='Saigon', latitude=10.7769, longitude=106.7009, radius=200)
        db.add(branch); db.flush()
        shift = Shift(name='Office shift', start='08:30', end='17:30', branch_id=branch.id)
        db.add(shift); db.flush()
        db.add(Assignment(user_id=users[1].id, shift_id=shift.id, work_date='2026-10-29'))
        db.commit()
        headers = {user.role: {'Authorization': 'Bearer ' + sign({'sub': str(user.id), 'kind': 'access'})} for user in users}
    with TestClient(app) as client:
        yield client, headers, codes
