from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.session import get_db
from app.models import Student, Teacher


DbSession = Annotated[Session, Depends(get_db)]
bearer = HTTPBearer(auto_error=False)


def api_error(code: str, message: str, status_code: int) -> HTTPException:
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})


def _identity(credentials: HTTPAuthorizationCredentials | None) -> tuple[str, int]:
    if not credentials:
        raise api_error("NOT_AUTHENTICATED", "Authentication is required", status.HTTP_401_UNAUTHORIZED)
    try:
        return decode_access_token(credentials.credentials)
    except (jwt.PyJWTError, KeyError, ValueError):
        raise api_error("INVALID_TOKEN", "Login token is invalid or expired", status.HTTP_401_UNAUTHORIZED)


def current_teacher(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> Teacher:
    kind, entity_id = _identity(credentials)
    teacher = db.get(Teacher, entity_id) if kind == "teacher" else None
    if not teacher:
        raise api_error("TEACHER_REQUIRED", "Teacher login is required", status.HTTP_403_FORBIDDEN)
    return teacher


def current_student(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> Student:
    kind, entity_id = _identity(credentials)
    student = db.get(Student, entity_id) if kind == "student" else None
    if not student:
        raise api_error("STUDENT_REQUIRED", "Student login is required", status.HTTP_403_FORBIDDEN)
    return student


CurrentTeacher = Annotated[Teacher, Depends(current_teacher)]
CurrentStudent = Annotated[Student, Depends(current_student)]
