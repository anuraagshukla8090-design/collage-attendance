from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_secret
from app.models import Student, Teacher


DEMO_STUDENTS = (
    ("student001", "Rahul Sharma"),
    ("student002", "Priya Patel"),
    ("student003", "Arjun Singh"),
)


def seed_demo_data(db: Session) -> None:
    if not db.scalar(select(Teacher).where(Teacher.email == "teacher@demo.com")):
        db.add(
            Teacher(
                name="Dr. Meera Kapoor",
                email="teacher@demo.com",
                password_hash=hash_secret("teacher123"),
            )
        )
    for code, name in DEMO_STUDENTS:
        if not db.scalar(select(Student).where(Student.student_code == code)):
            db.add(
                Student(
                    student_code=code,
                    name=name,
                    password_hash=hash_secret("student123"),
                )
            )
    db.commit()
