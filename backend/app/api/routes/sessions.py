import secrets
import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter
from sqlalchemy import func, select

from app.api.deps import CurrentStudent, CurrentTeacher, DbSession, api_error
from app.core.config import get_settings
from app.models import Attendance, AttendanceSession
from app.schemas import AttendanceResponse, SessionResponse, SessionStartRequest
from app.services.ble_tokens import build_token_schedule

router = APIRouter(prefix="/sessions", tags=["attendance sessions"])


def session_response(db: DbSession, session: AttendanceSession, include_tokens: bool = False):
    count = db.scalar(
        select(func.count(Attendance.id)).where(Attendance.session_id == session.id)
    ) or 0
    return SessionResponse(
        id=session.id,
        session_code=session.session_code,
        subject=session.subject,
        started_at=session.started_at,
        expires_at=session.expires_at,
        status=session.status,
        present_count=count,
        token_schedule=build_token_schedule(session) if include_tokens else None,
    )


def expire_if_needed(db: DbSession, session: AttendanceSession) -> None:
    if session.status == "ACTIVE" and datetime.utcnow() >= session.expires_at:
        session.status = "EXPIRED"
        db.commit()


@router.post("/start", response_model=SessionResponse)
def start_session(body: SessionStartRequest, teacher: CurrentTeacher, db: DbSession):
    # The clock starts here, only after this request reaches the backend. The app
    # begins its displayed countdown after receiving this committed response.
    now = datetime.utcnow()
    session_uuid = str(uuid.uuid4())
    session = AttendanceSession(
        id=session_uuid,
        session_code=session_uuid.replace("-", "")[:8],
        teacher_id=teacher.id,
        subject=body.subject.strip(),
        started_at=now,
        expires_at=now + timedelta(seconds=get_settings().session_seconds),
        status="ACTIVE",
        ble_secret=secrets.token_hex(32),
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session_response(db, session, include_tokens=True)


@router.post("/{session_id}/stop", response_model=SessionResponse)
def stop_session(session_id: str, teacher: CurrentTeacher, db: DbSession):
    session = db.get(AttendanceSession, session_id)
    if not session or session.teacher_id != teacher.id:
        raise api_error("SESSION_NOT_FOUND", "Attendance session was not found", 404)
    if session.status == "ACTIVE":
        session.status = "STOPPED"
        db.commit()
    return session_response(db, session)


@router.get("/resolve/{session_code}", response_model=SessionResponse)
def resolve_session(session_code: str, _student: CurrentStudent, db: DbSession):
    session = db.scalar(
        select(AttendanceSession).where(AttendanceSession.session_code == session_code.lower())
    )
    if not session:
        raise api_error("SESSION_NOT_FOUND", "The nearby session is not recognized", 404)
    expire_if_needed(db, session)
    return session_response(db, session)


@router.get("/{session_id}", response_model=SessionResponse)
def get_session(session_id: str, teacher: CurrentTeacher, db: DbSession):
    session = db.get(AttendanceSession, session_id)
    if not session or session.teacher_id != teacher.id:
        raise api_error("SESSION_NOT_FOUND", "Attendance session was not found", 404)
    expire_if_needed(db, session)
    return session_response(db, session)


@router.get("/{session_id}/attendance", response_model=list[AttendanceResponse])
def session_attendance(session_id: str, teacher: CurrentTeacher, db: DbSession):
    session = db.get(AttendanceSession, session_id)
    if not session or session.teacher_id != teacher.id:
        raise api_error("SESSION_NOT_FOUND", "Attendance session was not found", 404)
    rows = db.execute(
        select(Attendance)
        .where(Attendance.session_id == session.id)
        .order_by(Attendance.timestamp.asc())
    ).scalars().all()
    return [
        AttendanceResponse(
            id=row.id,
            session_id=row.session_id,
            student_id=row.student_id,
            student_code=row.student.student_code,
            student_name=row.student.name,
            subject=session.subject,
            timestamp=row.timestamp,
            device_id=row.device_id,
            ble_rssi=row.ble_rssi,
        )
        for row in rows
    ]
