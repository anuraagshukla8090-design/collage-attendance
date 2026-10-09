import os
from functools import lru_cache


class Settings:
    def __init__(self) -> None:
        raw_url = os.getenv("DATABASE_URL", "sqlite:///./attendance.db")
        # Render and some providers still emit the legacy postgres:// form.
        if raw_url.startswith("postgres://"):
            raw_url = raw_url.replace("postgres://", "postgresql+psycopg://", 1)
        elif raw_url.startswith("postgresql://"):
            raw_url = raw_url.replace("postgresql://", "postgresql+psycopg://", 1)
        self.database_url = raw_url
        self.secret_key = os.getenv("SECRET_KEY", "local-demo-secret-change-me")
        self.access_token_minutes = int(os.getenv("ACCESS_TOKEN_MINUTES", "720"))
        self.session_seconds = int(os.getenv("ATTENDANCE_SESSION_SECONDS", "90"))
        self.ble_rotation_seconds = int(os.getenv("BLE_ROTATION_SECONDS", "10"))


@lru_cache
def get_settings() -> Settings:
    return Settings()
