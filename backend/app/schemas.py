import re
from datetime import date
from typing import Literal
from pydantic import BaseModel, EmailStr, Field, model_validator, field_validator


class Register(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=10, max_length=128)
    phone: str = Field(default='', max_length=20)

    @field_validator('phone')
    @classmethod
    def phone_format(cls, value):
        if value and not re.fullmatch(r'\+[1-9]\d{7,14}', value):
            raise ValueError('Số điện thoại phải có mã quốc gia, ví dụ +84901234567')
        return value


class Login(BaseModel):
    email: EmailStr
    password: str = Field(max_length=128)
    channel: Literal['email', 'sms'] = 'email'


class Verify(BaseModel):
    challenge_id: str
    code: str = Field(pattern=r'^\d{6}$')


class Refresh(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=255)


class EmployeeCreate(Register):
    role: Literal['employee', 'customer', 'admin'] = 'employee'
    department: str = Field(default='Sản phẩm', min_length=1, max_length=100)
    title: str = Field(default='Nhân viên', min_length=1, max_length=100)


class EmployeeUpdate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    phone: str = Field(default='', max_length=20)
    department: str = Field(min_length=1, max_length=100)
    title: str = Field(min_length=1, max_length=100)
    role: Literal['employee', 'customer', 'admin'] = 'employee'

    _phone = field_validator('phone')(Register.phone_format.__func__)


class BranchInput(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    address: str = Field(min_length=2, max_length=255)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius: int = Field(default=200, ge=20, le=5000)


class ShiftInput(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    start: str = Field(pattern=r'^([01]\d|2[0-3]):[0-5]\d$')
    end: str = Field(pattern=r'^([01]\d|2[0-3]):[0-5]\d$')
    branch_id: int
    break_minutes: int = Field(default=60, ge=0, le=240)

    @model_validator(mode='after')
    def valid_shift(self):
        minutes = lambda value: int(value[:2]) * 60 + int(value[3:])
        if minutes(self.end) - minutes(self.start) <= self.break_minutes:
            raise ValueError('Ca phải kết thúc trong ngày, thời gian nghỉ nhỏ hơn thời lượng ca')
        return self


class AssignmentInput(BaseModel):
    user_id: int
    shift_id: int
    work_date: date


class LocationInput(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy: float = Field(ge=0, le=100)


class CheckInput(LocationInput):
    qr_token: str = Field(min_length=20, max_length=2000)


class LeaveInput(BaseModel):
    kind: Literal['Nghỉ phép', 'Nghỉ ốm', 'Việc cá nhân', 'Làm từ xa']
    start_date: date
    end_date: date
    reason: str = Field(min_length=5, max_length=1000)

    @model_validator(mode='after')
    def date_order(self):
        if self.end_date < self.start_date:
            raise ValueError('Ngày kết thúc phải từ ngày bắt đầu')
        if (self.end_date - self.start_date).days > 30:
            raise ValueError('Mỗi đơn tối đa 31 ngày')
        return self


class Decision(BaseModel):
    status: Literal['approved', 'rejected']


class Exchange(BaseModel):
    code: str = Field(min_length=20, max_length=255)
    verifier: str = Field(min_length=43, max_length=128)
