from datetime import datetime

from fastapi import APIRouter
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.api.deps import CurrentStudent, DbSession, api_error
from app.core.security import verify_secret
from app.models import Attendance, AttendanceSession, Device
from app.schemas import AttendanceMarkRequest, AttendanceMarkResponse, AttendanceResponse
from app.services.ble_tokens import is_valid_token

router = APIRouter(prefix="/attendance", tags=["attendance"])


@router.post("/mark", response_model=AttendanceMarkResponse)
def mark_attendance(body: AttendanceMarkRequest, student: CurrentStudent, db: DbSession):
    session = db.get(AttendanceSession, body.session_id)
    if not session:
        raise api_error("SESSION_NOT_FOUND", "Attendance session was not found", 404)

    now = datetime.utcnow()
    if session.status != "ACTIVE":
        code = "SESSION_EXPIRED" if session.status == "EXPIRED" else "SESSION_CLOSED"
        raise api_error(code, "Attendance is closed", 409)
    if now >= session.expires_at:
        session.status = "EXPIRED"
        db.commit()
        raise api_error("SESSION_EXPIRED", "The 90-second attendance window has ended", 409)
    if not is_valid_token(session, body.ble_token, now):
        raise api_error("BLE_TOKEN_INVALID", "The nearby Bluetooth token is invalid or stale", 403)

    device = db.scalar(
        select(Device).where(Device.student_id == student.id, Device.active.is_(True))
    )
    if not device:
        raise api_error("DEVICE_NOT_REGISTERED", "No device is registered for this student", 409)
    if device.device_id != body.device_id:
        raise api_error("DEVICE_MISMATCH", "Attendance must be marked from the registered phone", 403)
    if not verify_secret(body.pin, student.attendance_pin_hash):
        raise api_error("INVALID_PIN", "Attendance PIN is incorrect", 403)

    attendance = Attendance(
        session_id=session.id,
        student_id=student.id,
        timestamp=now,
        device_id=device.device_id,
        ble_rssi=body.ble_rssi,
    )
    db.add(attendance)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        # The DB constraint remains the final authority under concurrent requests.
        raise api_error("ALREADY_MARKED", "Attendance is already marked for this class", 409)
    db.refresh(attendance)
    return AttendanceMarkResponse(
        attendance=AttendanceResponse(
            id=attendance.id,
            session_id=session.id,
            student_id=student.id,
            student_code=student.student_code,
            student_name=student.name,
            subject=session.subject,
            timestamp=attendance.timestamp,
            device_id=attendance.device_id,
            ble_rssi=attendance.ble_rssi,
        )
    )
