# BLE Attendance MVP

An Android-only proof of concept for college attendance using the phones people already carry. A teacher starts a 90-second session and their Android phone broadcasts a compact Bluetooth Low Energy (BLE) advertisement. Student phones listen for that broadcast, ask the student for a personal PIN, and send the evidence to a FastAPI backend for validation.

No dedicated hardware, Bluetooth pairing, GPS, QR codes, biometrics, Firebase, queues, or cloud-specific services are used.

## Architecture

```text
Teacher Android app                    Student Android app
  POST /sessions/start                   BLE scan (3–5 seconds)
  receives token schedule                reads broadcast only
  advertises session + token  ──BLE──▶   POST /attendance/mark
            │                                      │
            └──────────── FastAPI API ─────────────┘
                               │
                     SQLite / PostgreSQL
```

- `mobile/` is one Flutter app with Teacher Mode and Student Mode.
- `backend/` is a modular FastAPI + SQLAlchemy API.
- SQLite is the default local database. Setting `DATABASE_URL` to a PostgreSQL URL selects PostgreSQL without application changes.
- Authentication uses short JWT bearer tokens suitable for this demo.
- Passwords and attendance PINs are hashed with scrypt and never stored as plaintext.
- `(session_id, student_id)` has a database unique constraint. This is the final duplicate guard even when requests arrive concurrently.
- SQLite runs in WAL mode with a busy timeout. Around 120 short writes over 90 seconds is reasonable for a classroom demo; production should use PostgreSQL.

## Demo accounts

| Role | Login | Password |
|---|---|---|
| Teacher | `teacher@demo.com` | `teacher123` |
| Student | `student001` | `student123` |
| Student | `student002` | `student123` |
| Student | `student003` | `student123` |

Each student creates a 4- or 6-digit attendance PIN on first login. The first successful student login also creates a random installation ID in Android encrypted storage and registers it with the backend. A different installation is rejected with `DEVICE_MISMATCH`.

## Teacher flow

1. Log in with the teacher demo account.
2. The dashboard shows `CSE AI/ML` and `Machine Learning`.
3. Tap **START ATTENDANCE**.
4. The backend creates and commits a session, then returns its 90-second expiry and token schedule.
5. Only after that response does the app start BLE advertising and display the countdown. A Render cold start therefore happens before the usable countdown begins.
6. The app rotates the advertised token every 10 seconds and refreshes the present list every few seconds.
7. Tap **STOP ATTENDANCE** or let the timer expire; advertising stops in both cases.

If the phone does not support BLE peripheral/advertiser mode, the app closes the backend session and shows a clear error. Most modern Android phones support it, but some low-end devices do not.

## Student flow

1. Log in with a student demo account.
2. On first use, the installation is registered and the student creates a PIN.
3. The app scans for five seconds for the fixed attendance BLE service.
4. When found, it displays the subject, `Teacher detected nearby ✓`, signal quality, and logged RSSI.
5. Tap **MARK ATTENDANCE**, enter the PIN, and confirm.
6. The app performs a short fresh scan so the submitted rotating token is current, then sends session, token, device, RSSI, client timestamp, and PIN to the API.
7. On success it displays `Attendance Marked ✓`. Duplicate requests return `ALREADY_MARKED`; expired sessions show `Attendance Closed`.

## BLE design: listening, not connecting

The Android bridge uses `BluetoothLeAdvertiser` for the teacher and `BluetoothLeScanner` for students. The advertisement is explicitly non-connectable. The student never opens a GATT connection and never initiates Bluetooth pairing.

The fixed service UUID is `0000A77E-0000-1000-8000-00805F9B34FB`. A legacy-size-safe manufacturer payload contains:

| Bytes | Meaning |
|---|---|
| 1 | payload version |
| 4 | compact session code |
| 8 | rotating HMAC-derived token |

Using a 16-bit-form service UUID keeps the packet under the 31-byte legacy advertising limit. The compact code is resolved to the full backend session ID before submission. Tokens rotate every 10 seconds. The API accepts the current or immediately previous slot to tolerate a scan on a rotation boundary.

RSSI is stored for demonstration and shown as a rough signal label. It is not treated as a physical distance measurement and is not a strict attendance decision in this MVP.

## Backend: local setup

Python 3.11+ is recommended.

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 --env-file .env
```

On macOS/Linux, activate with `source .venv/bin/activate`. The API docs are at `http://localhost:8000/docs`; health is at `/health`.

Configuration:

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./attendance.db` | SQLite or PostgreSQL SQLAlchemy URL |
| `SECRET_KEY` | local demo fallback | JWT signing key; always override when deployed |
| `ACCESS_TOKEN_MINUTES` | `720` | demo login lifetime |
| `ATTENDANCE_SESSION_SECONDS` | `90` | session duration |
| `BLE_ROTATION_SECONDS` | `10` | token rotation |

Render is pinned to Python `3.12.11` in the Blueprint. Keep this pin unless all compiled dependencies have been verified against a newer Python runtime.

Run backend tests:

```powershell
cd backend
.\.venv\Scripts\python.exe -m pytest -q
```

## Flutter / Android setup

Install Flutter with Android tooling, enable developer mode and USB debugging on both phones, then:

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000
```

For the Android emulator, the default `http://10.0.2.2:8000` reaches the host machine. Physical phones cannot use `localhost` or `10.0.2.2`; use the computer's Wi-Fi/LAN address (for example `http://192.168.1.20:8000`) and allow port 8000 through the firewall. Both phones and the computer should be on the same network.

For Render, use the deployed HTTPS address:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

The app is intentionally Android-only. The native bridge requires a real BLE-capable Android device for radio testing; emulators generally cannot demonstrate advertiser-to-scanner behavior reliably.

## Android permissions

The manifest includes:

- Android 12+: `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, and `BLUETOOTH_CONNECT`.
- Android 11 and older: legacy Bluetooth permissions and `ACCESS_FINE_LOCATION`, required by the older scan API.
- `BLUETOOTH_SCAN` is marked `neverForLocation`; this project does not collect location.
- `INTERNET` for API calls.

Runtime prompts are role-specific: student scanning does not ask for advertise permission, and teacher advertising does not ask for scan/location permission. Bluetooth must already be switched on.

## API endpoints

- `POST /auth/teacher/login`
- `POST /auth/student/login`
- `POST /students/register-device`
- `POST /students/set-attendance-pin`
- `POST /sessions/start`
- `POST /sessions/{id}/stop`
- `GET /sessions/{id}`
- `GET /sessions/resolve/{session_code}`
- `GET /sessions/{id}/attendance`
- `POST /attendance/mark`
- `GET /students/{id}/attendance`

`POST /attendance/mark` validates the authenticated student, active/unexpired session, current BLE token, registered device, hashed PIN, and duplicate status. Expected error codes include `SESSION_EXPIRED`, `SESSION_CLOSED`, `DEVICE_NOT_REGISTERED`, `DEVICE_MISMATCH`, `INVALID_PIN`, `BLE_TOKEN_INVALID`, and `ALREADY_MARKED`.

## Render deployment

The repository-root `render.yaml` can create both the free Python web service and a free PostgreSQL database as one Render Blueprint. A second copy is kept in `backend/render.yaml` if you choose a custom Blueprint path.

1. Push this repository to a Git provider supported by Render.
2. In Render, choose **New Blueprint** and select the repository, or create a Web Service with root directory `backend`.
3. Build command: `pip install -r requirements.txt`.
4. Start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`.
5. Set a long random `SECRET_KEY`.
6. The Blueprint connects the service to PostgreSQL automatically; do not replace `DATABASE_URL` with SQLite on Render because free web-service files are ephemeral.
7. Render's free PostgreSQL database is suitable for this MVP demonstration but currently expires after 30 days. Upgrade it or move to another PostgreSQL provider before that date if you need to keep the records.
8. Verify `https://YOUR-SERVICE.onrender.com/health`, then build the APK with that URL.

Free services may sleep. Start the backend request first; the 90-second session timestamp is created only when `/sessions/start` runs successfully, and the app countdown starts only after its response.

## Build once, install on four phones

After Render gives you the public service address, build the phone-ready APK with:

```powershell
.\scripts\build_android_apk.ps1 -ApiBaseUrl https://YOUR-SERVICE.onrender.com
```

The finished file is `artifacts/BLE-Attendance-MVP-release.apk`. This MVP release uses the debug signing key for simple direct installation; it is not intended for Play Store publishing.

Copy that same APK to all four Android phones using USB, Drive, email, or another file-sharing method. On each phone, open the APK and allow **Install unknown apps** for the app used to open it. Use the phones as follows:

| Phone | Mode and account |
|---|---|
| Phone A | Teacher — `teacher@demo.com` |
| Phone B | Student — `student001` |
| Phone C | Student — `student002` |
| Phone D | Student — `student003` |

Use a different student account and personal attendance PIN on each student phone. One student account is intentionally bound to one app installation, so sharing one student login across phones produces `DEVICE_MISMATCH`.

With the Render HTTPS backend, the four phones do **not** need to be on the same Wi-Fi network. They only need internet access for the API. The student phones must still be physically near the teacher phone so they can receive its short-range BLE advertisement.

## Two-phone acceptance test

1. Start the backend on a LAN-accessible address or deploy it to Render.
2. Install the same APK on Phone A and Phone B.
3. On Phone A, log in as `teacher@demo.com`, tap **START ATTENDANCE**, and grant Bluetooth advertise permission.
4. Confirm Phone A shows `ATTENDANCE ACTIVE`, a countdown close to 01:29, and `Students Present: 0`.
5. On Phone B, log in as `student001`, create a PIN on first use, and grant Bluetooth scan permission.
6. Confirm it shows `Machine Learning`, `Teacher detected nearby ✓`, and a signal label.
7. Tap **MARK ATTENDANCE**, enter the PIN, and confirm `Attendance Marked ✓`.
8. Within a few seconds Phone A should show `Students Present: 1` and Rahul Sharma in the list.
9. Reinstalling the app (which creates a new installation ID) and logging in as `student001` should return `DEVICE_MISMATCH`. To repeat from a clean demo database, stop the backend and delete the local `attendance.db` file, then restart.
10. A direct repeated API submission returns `ALREADY_MARKED`. After 90 seconds, further attempts return `SESSION_EXPIRED` and the app shows attendance closed.

## Known MVP limitations

- The installation UUID is stronger than a plain preference but can still be reset by clearing app data; it is not a hardware identity.
- Teacher token schedules are held in app memory for the short session.
- The student is not checked against course enrollment.
- JWT authentication, demo accounts, and device replacement are intentionally basic.
- RSSI varies with phone orientation, walls, bodies, and radio hardware; it is only logged.
- SQLite and in-process schema creation are for local/demo use, not migrations or durable hosted production.
- BLE advertiser support must be tested on the chosen teacher phone.
- There is no offline attendance queue; the student needs backend connectivity when submitting.
- Android only; no iOS implementation.

## Production roadmap (not implemented)

- Android Keystore hardware-backed device key pairs.
- Cryptographically signed per-attendance challenges instead of an installation UUID.
- Play Integrity verification and replay-resistant server nonces.
- PostgreSQL with migrations, tuned pooling, and durable backups.
- Redis for short-lived challenge/session coordination if scale later requires it.
- AWS deployment and managed observability when infrastructure maturity justifies it.
- Proper university SSO/authentication, roles, courses, rosters, and enrollment management.
- Audited device replacement/recovery workflow.
- Fraud and anomaly detection with transparent review tools.
- iOS support using the platform's background and BLE constraints.

These are deliberate next steps, not hidden dependencies of this MVP.
