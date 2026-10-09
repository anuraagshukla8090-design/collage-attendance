from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_secret
from app.models import Student, Teacher


DEMO_TEACHERS = (
    ("teacher@demo.com", "Dr. Meera Kapoor"),
    ("teacher2@demo.com", "Prof. Rohan Verma"),
    ("teacher3@demo.com", "Dr. Ananya Iyer"),
)

DEMO_STUDENTS = (
    ("student001", "Rahul Sharma"),
    ("student002", "Priya Patel"),
    ("student003", "Arjun Singh"),
    ("student004", "Aisha Khan"),
    ("student005", "Vikram Reddy"),
    ("student006", "Sneha Joshi"),
    ("student007", "Aditya Nair"),
    ("student008", "Kavya Deshmukh"),
)


def seed_demo_data(db: Session) -> None:
    for email, name in DEMO_TEACHERS:
        if not db.scalar(select(Teacher).where(Teacher.email == email)):
            db.add(
                Teacher(
                    name=name,
                    email=email,
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
