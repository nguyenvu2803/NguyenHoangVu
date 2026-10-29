from pydantic import TypeAdapter, EmailStr
from sqlalchemy import select
from .models import User
from .security import passwords


def provision_admin(db, email, password, name='Quản trị viên'):
    email = str(TypeAdapter(EmailStr).validate_python(email)).lower()
    if len(password) < 14 or password.upper().startswith('REPLACE'):
        raise ValueError('Admin password must contain at least 14 characters')
    existing = db.scalar(select(User).where(User.email == email))
    if existing:
        if existing.role != 'admin':
            raise ValueError('Email belongs to a non-admin account; refusing implicit privilege escalation')
        return False
    db.add(User(name=name, email=email, role='admin', password_hash=passwords.hash(password), verified=False, department='Nhân sự', title='Quản trị viên'))
    db.commit()
    return True
