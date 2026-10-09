from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, Field, field_validator


class TeacherLoginRequest(BaseModel):
    email: str
    password: str


class StudentLoginRequest(BaseModel):
    student_code: str
    password: str


class TeacherLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    teacher_id: int
    name: str
    email: str


class StudentLoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    student_id: int
    student_code: str
    name: str
    device_registered: bool
    has_attendance_pin: bool


class DeviceRegistrationRequest(BaseModel):
    device_id: str = Field(min_length=16, max_length=100)


class DeviceRegistrationResponse(BaseModel):
    registered: bool
    device_id: str


class SetPinRequest(BaseModel):
    device_id: str
    pin: str

    @field_validator("pin")
    @classmethod
    def valid_pin(cls, value: str) -> str:
        if not value.isdigit() or len(value) not in (4, 6):
            raise ValueError("PIN must contain exactly 4 or 6 digits")
        return value


class SessionStartRequest(BaseModel):
    subject: str = Field(default="Machine Learning", min_length=1, max_length=160)


class BleTokenSlot(BaseModel):
    token: str
    valid_from: datetime
    valid_until: datetime

    @field_validator("valid_from", "valid_until", mode="before")
    @classmethod
    def mark_utc(cls, value: datetime) -> datetime:
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class SessionResponse(BaseModel):
    id: str
    session_code: str
    subject: str
    started_at: datetime
    expires_at: datetime
    status: str
    present_count: int = 0
    token_schedule: list[BleTokenSlot] | None = None

    @field_validator("started_at", "expires_at", mode="before")
    @classmethod
    def mark_utc(cls, value: datetime) -> datetime:
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class AttendanceMarkRequest(BaseModel):
    session_id: str
    device_id: str
    ble_token: str = Field(min_length=16, max_length=16)
    ble_rssi: int | None = Field(default=None, ge=-127, le=20)
    pin: str
    client_timestamp: datetime | None = None


class AttendanceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    session_id: str
    student_id: int
    student_code: str
    student_name: str
    subject: str
    timestamp: datetime
    device_id: str
    ble_rssi: int | None

    @field_validator("timestamp", mode="before")
    @classmethod
    def mark_utc(cls, value: datetime) -> datetime:
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


class AttendanceMarkResponse(BaseModel):
    status: str = "MARKED"
    attendance: AttendanceResponse
