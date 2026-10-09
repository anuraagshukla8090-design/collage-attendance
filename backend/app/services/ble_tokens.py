import hashlib
import hmac
from datetime import datetime, timedelta

from app.core.config import get_settings
from app.models import AttendanceSession
from app.schemas import BleTokenSlot


def token_for_slot(session: AttendanceSession, slot: int) -> str:
    message = f"{session.id}:{slot}".encode()
    return hmac.new(bytes.fromhex(session.ble_secret), message, hashlib.sha256).digest()[:8].hex()


def build_token_schedule(session: AttendanceSession) -> list[BleTokenSlot]:
    rotation = get_settings().ble_rotation_seconds
    seconds = int((session.expires_at - session.started_at).total_seconds())
    slots = (seconds + rotation - 1) // rotation
    return [
        BleTokenSlot(
            token=token_for_slot(session, slot),
            valid_from=session.started_at + timedelta(seconds=slot * rotation),
            valid_until=min(
                session.expires_at,
                session.started_at + timedelta(seconds=(slot + 1) * rotation),
            ),
        )
        for slot in range(slots)
    ]


def is_valid_token(session: AttendanceSession, token: str, now: datetime) -> bool:
    rotation = get_settings().ble_rotation_seconds
    slot = int((now - session.started_at).total_seconds() // rotation)
    # Previous slot allows a scan at the rotation boundary to finish its API call.
    candidates = {token_for_slot(session, index) for index in (slot, slot - 1) if index >= 0}
    return any(hmac.compare_digest(token.lower(), candidate) for candidate in candidates)
