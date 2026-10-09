from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import attendance, auth, sessions, students
from app.db.session import Base, SessionLocal, engine
from app.services.seed import seed_demo_data


@asynccontextmanager
async def lifespan(_app: FastAPI):
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        seed_demo_data(db)
    yield


app = FastAPI(
    title="BLE Attendance MVP API",
    version="0.1.0",
    description="Demo API for connectionless Android BLE attendance.",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(students.router)
app.include_router(sessions.router)
app.include_router(attendance.router)


@app.get("/")
def root() -> dict:
    return {"name": "BLE Attendance MVP", "status": "ok"}


@app.get("/health")
def health() -> dict:
    return {"status": "healthy"}
