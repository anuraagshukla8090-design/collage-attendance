import os
from datetime import datetime, timedelta

os.environ["DATABASE_URL"] = "sqlite:///./test_attendance.db"
os.environ["SECRET_KEY"] = "test-secret"

from fastapi.testclient import TestClient  # noqa: E402

from app.db.session import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402
from app.models import AttendanceSession  # noqa: E402


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def error_code(response) -> str:
    return response.json()["detail"]["code"]


def test_complete_demo_flow_and_guards():
    Base.metadata.drop_all(bind=engine)
    with TestClient(app) as client:
        teacher_login = client.post(
            "/auth/teacher/login",
            json={"email": "teacher@demo.com", "password": "teacher123"},
        )
        assert teacher_login.status_code == 200
        teacher_token = teacher_login.json()["access_token"]

        student_login = client.post(
            "/auth/student/login",
            json={"student_code": "student001", "password": "student123"},
        )
        assert student_login.status_code == 200
        student = student_login.json()
        student_token = student["access_token"]
        student_headers = auth(student_token)
        device_id = "test-installation-00000001"

        registered = client.post(
            "/students/register-device",
            headers=student_headers,
            json={"device_id": device_id},
        )
        assert registered.status_code == 200
        pin_set = client.post(
            "/students/set-attendance-pin",
            headers=student_headers,
            json={"device_id": device_id, "pin": "123456"},
        )
        assert pin_set.status_code == 200

        started = client.post(
            "/sessions/start",
            headers=auth(teacher_token),
            json={"subject": "Machine Learning"},
        )
        assert started.status_code == 200
        session = started.json()
        assert session["status"] == "ACTIVE"
        assert len(session["token_schedule"]) == 9

        resolved = client.get(
            f"/sessions/resolve/{session['session_code']}", headers=student_headers
        )
        assert resolved.status_code == 200
        assert resolved.json()["id"] == session["id"]

        mark_body = {
            "session_id": session["id"],
            "device_id": device_id,
            "ble_token": session["token_schedule"][0]["token"],
            "ble_rssi": -48,
            "pin": "123456",
        }
        marked = client.post("/attendance/mark", headers=student_headers, json=mark_body)
        assert marked.status_code == 200
        assert marked.json()["status"] == "MARKED"

        duplicate = client.post("/attendance/mark", headers=student_headers, json=mark_body)
        assert duplicate.status_code == 409
        assert error_code(duplicate) == "ALREADY_MARKED"

        attendance = client.get(
            f"/sessions/{session['id']}/attendance", headers=auth(teacher_token)
        )
        assert attendance.status_code == 200
        assert len(attendance.json()) == 1

        mismatch = client.post(
            "/students/register-device",
            headers=student_headers,
            json={"device_id": "another-installation-000002"},
        )
        assert mismatch.status_code == 409
        assert error_code(mismatch) == "DEVICE_MISMATCH"

        second = client.post(
            "/sessions/start",
            headers=auth(teacher_token),
            json={"subject": "Machine Learning"},
        ).json()
        with SessionLocal() as db:
            expired_session = db.get(AttendanceSession, second["id"])
            expired_session.expires_at = datetime.utcnow() - timedelta(seconds=1)
            db.commit()
        expired_body = {**mark_body, "session_id": second["id"], "ble_token": second["token_schedule"][0]["token"]}
        expired = client.post("/attendance/mark", headers=student_headers, json=expired_body)
        assert expired.status_code == 409
        assert error_code(expired) == "SESSION_EXPIRED"
