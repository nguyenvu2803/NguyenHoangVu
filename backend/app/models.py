from datetime import datetime, timezone
from sqlalchemy import String, ForeignKey, UniqueConstraint, Text
from sqlalchemy.orm import Mapped, mapped_column
from .database import Base


def now():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = 'users'
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(254), unique=True)
    phone: Mapped[str] = mapped_column(String(20), default='')
    password_hash: Mapped[str] = mapped_column(Text, default='')
    role: Mapped[str] = mapped_column(String(20), default='employee')
    department: Mapped[str] = mapped_column(String(100), default='Sản phẩm')
    title: Mapped[str] = mapped_column(String(100), default='Nhân viên')
    active: Mapped[bool] = mapped_column(default=True)
    verified: Mapped[bool] = mapped_column(default=False)
    google_sub: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)


class Challenge(Base):
    __tablename__ = 'challenges'
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'))
    purpose: Mapped[str] = mapped_column(String(30))
    code_hash: Mapped[str] = mapped_column(String(64))
    channel: Mapped[str] = mapped_column(String(20))
    expires: Mapped[int]
    attempts: Mapped[int] = mapped_column(default=0)
    consumed: Mapped[bool] = mapped_column(default=False)


class RefreshToken(Base):
    __tablename__ = 'refresh_tokens'
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'))
    expires: Mapped[int]
    revoked: Mapped[bool] = mapped_column(default=False)


class Branch(Base):
    __tablename__ = 'branches'
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    address: Mapped[str] = mapped_column(String(255))
    latitude: Mapped[float]
    longitude: Mapped[float]
    radius: Mapped[int] = mapped_column(default=200)


class Shift(Base):
    __tablename__ = 'shifts'
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    start: Mapped[str] = mapped_column(String(5), default='08:30')
    end: Mapped[str] = mapped_column(String(5), default='17:30')
    branch_id: Mapped[int] = mapped_column(ForeignKey('branches.id'))
    break_minutes: Mapped[int] = mapped_column(default=60)


class Assignment(Base):
    __tablename__ = 'assignments'
    __table_args__ = (UniqueConstraint('user_id', 'work_date'),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'))
    shift_id: Mapped[int] = mapped_column(ForeignKey('shifts.id'))
    work_date: Mapped[str] = mapped_column(String(10))


class Attendance(Base):
    __tablename__ = 'attendance'
    __table_args__ = (UniqueConstraint('user_id', 'work_date'),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'))
    shift_id: Mapped[int] = mapped_column(ForeignKey('shifts.id'))
    work_date: Mapped[str] = mapped_column(String(10))
    check_in: Mapped[datetime] = mapped_column(default=now)
    check_out: Mapped[datetime | None] = mapped_column(nullable=True)
    latitude: Mapped[float]
    longitude: Mapped[float]
    accuracy: Mapped[float]
    distance: Mapped[float]
    late_minutes: Mapped[int] = mapped_column(default=0)
    method: Mapped[str] = mapped_column(String(20), default='gps_qr')


class Leave(Base):
    __tablename__ = 'leaves'
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'))
    kind: Mapped[str] = mapped_column(String(60))
    start_date: Mapped[str] = mapped_column(String(10))
    end_date: Mapped[str] = mapped_column(String(10))
    reason: Mapped[str] = mapped_column(String(1000))
    status: Mapped[str] = mapped_column(String(20), default='pending')
    reviewer_id: Mapped[int | None] = mapped_column(ForeignKey('users.id'), nullable=True)


class LocationShare(Base):
    __tablename__ = 'location_shares'
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'))
    latitude: Mapped[float]
    longitude: Mapped[float]
    accuracy: Mapped[float]
    expires: Mapped[int]


class Audit(Base):
    __tablename__ = 'audit_logs'
    id: Mapped[int] = mapped_column(primary_key=True)
    actor_id: Mapped[int | None] = mapped_column(nullable=True)
    action: Mapped[str] = mapped_column(String(120))
    detail: Mapped[str] = mapped_column(String(1000), default='')
    created_at: Mapped[datetime] = mapped_column(default=now)


class OAuthState(Base):
    __tablename__ = 'oauth_states'
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    expires: Mapped[int]
    nonce: Mapped[str] = mapped_column(String(80))
    code_challenge: Mapped[str] = mapped_column(String(64))


class RateBucket(Base):
    __tablename__ = 'rate_buckets'
    key: Mapped[str] = mapped_column(String(160), primary_key=True)
    count: Mapped[int] = mapped_column(default=1)
    expires: Mapped[int]
