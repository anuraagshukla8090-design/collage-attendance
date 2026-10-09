from fastapi import APIRouter
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.deps import CurrentStudent, DbSession, api_error
from app.core.security import hash_secret
from app.models import Attendance, AttendanceSession, Device
from app.schemas import (
    AttendanceResponse,
    DeviceRegistrationRequest,
    DeviceRegistrationResponse,
    SetPinRequest,
)

router = APIRouter(prefix="/students", tags=["students"])


def active_device(db: DbSession, student_id: int) -> Device | None:
    return db.scalar(
        select(Device).where(Device.student_id == student_id, Device.active.is_(True))
    )


@router.post("/register-device", response_model=DeviceRegistrationResponse)
def register_device(
    body: DeviceRegistrationRequest, student: CurrentStudent, db: DbSession
) -> DeviceRegistrationResponse:
    current = active_device(db, student.id)
    if current:
        if current.device_id != body.device_id:
            raise api_error(
                "DEVICE_MISMATCH",
                "This student is already bound to another Android installation",
                409,
            )
        return DeviceRegistrationResponse(registered=True, device_id=current.device_id)
    db.add(Device(student_id=student.id, device_id=body.device_id, active=True))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise api_error("DEVICE_IN_USE", "This installation is already bound to another student", 409)
    return DeviceRegistrationResponse(registered=True, device_id=body.device_id)


@router.post("/set-attendance-pin")
def set_attendance_pin(body: SetPinRequest, student: CurrentStudent, db: DbSession) -> dict:
    device = active_device(db, student.id)
    if not device:
        raise api_error("DEVICE_NOT_REGISTERED", "Register this installation first", 409)
    if device.device_id != body.device_id:
        raise api_error("DEVICE_MISMATCH", "This is not the registered installation", 409)
    student.attendance_pin_hash = hash_secret(body.pin)
    db.commit()
    return {"status": "PIN_SET"}


@router.get("/{student_id}/attendance", response_model=list[AttendanceResponse])
def student_attendance(student_id: int, student: CurrentStudent, db: DbSession):
    if student.id != student_id:
        raise api_error("FORBIDDEN", "You can only view your own attendance", 403)
    rows = db.execute(
        select(Attendance, AttendanceSession)
        .join(AttendanceSession, Attendance.session_id == AttendanceSession.id)
        .where(Attendance.student_id == student.id)
        .order_by(Attendance.timestamp.desc())
    ).all()
    return [
        AttendanceResponse(
            id=attendance.id,
            session_id=attendance.session_id,
            student_id=student.id,
            student_code=student.student_code,
            student_name=student.name,
            subject=session.subject,
            timestamp=attendance.timestamp,
            device_id=attendance.device_id,
            ble_rssi=attendance.ble_rssi,
        )
        for attendance, session in rows
    ]
