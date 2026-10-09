from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


def utcnow() -> datetime:
    return datetime.utcnow()


class Teacher(Base):
    __tablename__ = "teachers"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    sessions: Mapped[list["AttendanceSession"]] = relationship(back_populates="teacher")


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True)
    student_code: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(120))
    password_hash: Mapped[str] = mapped_column(String(255))
    attendance_pin_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    devices: Mapped[list["Device"]] = relationship(back_populates="student")
    attendances: Mapped[list["Attendance"]] = relationship(back_populates="student")


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(primary_key=True)
    # MVP rule: a student can have exactly one bound installation. The unique
    # constraint also closes a concurrent double-registration race.
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id"), unique=True, index=True)
    device_id: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    registered_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    student: Mapped[Student] = relationship(back_populates="devices")


class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    session_code: Mapped[str] = mapped_column(String(8), unique=True, index=True)
    teacher_id: Mapped[int] = mapped_column(ForeignKey("teachers.id"), index=True)
    subject: Mapped[str] = mapped_column(String(160))
    started_at: Mapped[datetime] = mapped_column(DateTime)
    expires_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    status: Mapped[str] = mapped_column(String(20), default="ACTIVE", index=True)
    ble_secret: Mapped[str] = mapped_column(String(64))
    teacher: Mapped[Teacher] = relationship(back_populates="sessions")
    attendances: Mapped[list["Attendance"]] = relationship(back_populates="session")


class Attendance(Base):
    __tablename__ = "attendances"
    __table_args__ = (
        UniqueConstraint("session_id", "student_id", name="uq_attendance_session_student"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("attendance_sessions.id"), index=True)
    student_id: Mapped[int] = mapped_column(ForeignKey("students.id"), index=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    device_id: Mapped[str] = mapped_column(String(100))
    ble_rssi: Mapped[int | None] = mapped_column(Integer, nullable=True)
    session: Mapped[AttendanceSession] = relationship(back_populates="attendances")
    student: Mapped[Student] = relationship(back_populates="attendances")
