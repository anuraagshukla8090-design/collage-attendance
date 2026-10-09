from fastapi import APIRouter
from sqlalchemy import select

from app.api.deps import DbSession, api_error
from app.core.security import create_access_token, verify_secret
from app.models import Device, Student, Teacher
from app.schemas import (
    StudentLoginRequest,
    StudentLoginResponse,
    TeacherLoginRequest,
    TeacherLoginResponse,
)

router = APIRouter(prefix="/auth", tags=["authentication"])


@router.post("/teacher/login", response_model=TeacherLoginResponse)
def teacher_login(body: TeacherLoginRequest, db: DbSession) -> TeacherLoginResponse:
    teacher = db.scalar(select(Teacher).where(Teacher.email == body.email.lower().strip()))
    if not teacher or not verify_secret(body.password, teacher.password_hash):
        raise api_error("INVALID_CREDENTIALS", "Email or password is incorrect", 401)
    return TeacherLoginResponse(
        access_token=create_access_token("teacher", teacher.id),
        teacher_id=teacher.id,
        name=teacher.name,
        email=teacher.email,
    )


@router.post("/student/login", response_model=StudentLoginResponse)
def student_login(body: StudentLoginRequest, db: DbSession) -> StudentLoginResponse:
    student = db.scalar(
        select(Student).where(Student.student_code == body.student_code.lower().strip())
    )
    if not student or not verify_secret(body.password, student.password_hash):
        raise api_error("INVALID_CREDENTIALS", "Student ID or password is incorrect", 401)
    has_device = db.scalar(
        select(Device.id).where(Device.student_id == student.id, Device.active.is_(True))
    ) is not None
    return StudentLoginResponse(
        access_token=create_access_token("student", student.id),
        student_id=student.id,
        student_code=student.student_code,
        name=student.name,
        device_registered=has_device,
        has_attendance_pin=student.attendance_pin_hash is not None,
    )
