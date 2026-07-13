# app/main.py (UPDATED - WebSocket Router Added)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os
import logging

from app.core.config import settings
from app.core.database import engine, Base, SessionLocal
from app.api.v1.auth import router as auth_router
from app.api.v1.properties import router as property_router
from app.api.v1.settings import router as settings_router
from app.api.v1.dashboard import router as dashboard_router
from app.api.v1.fence_config import router as fence_config_router
from app.api.v1.climbing_detection import router as climbing_detection_router
# from api.v1.stream import router as stream_router
from app.api.v1.person_tracking import router as person_tracking_router
from app.api.v1.face_detection import router as face_detection_router
from app.api.v1.weapon_detection import router as weapon_detection_router
from app.api.v1.websocket import router as websocket_router  # ✅ NEW: WebSocket endpoint

from app.services.detection_manager import detection_manager
from app.services.face_detection_manager import face_detection_manager
from app.services.weapon_detection_manager import weapon_detection_manager

from fastapi.staticfiles import StaticFiles

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

Base.metadata.create_all(bind=engine)

for d in [
    "static/snapshots",
    "static/videos",
    "static/faces",
    "static/weapons",
    "uploads/people",
]:
    os.makedirs(d, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Starting EagleWatch backend...")

    try:
        detection_manager.initialize(
            api_base_url="http://localhost:8000",
            model_path="models/yolov8n-pose.pt",
        )
        logger.info("✅ Detection manager initialized")
    except Exception as e:
        logger.error(f"❌ Detection manager init failed: {e}")

    try:
        db = SessionLocal()
        detection_manager.start_all_from_db(db)
        db.close()
    except Exception as e:
        logger.error(f"❌ Auto-start wall-climbing detection failed: {e}")

    try:
        db = SessionLocal()
        face_detection_manager.start_all_entrance_cameras(db)
        db.close()
        logger.info("✅ Face detection manager started for all entrance cameras")
    except Exception as e:
        logger.error(f"❌ Face detection auto-start failed: {e}")

    try:
        weapon_detection_manager.initialize()
        logger.info("✅ Weapon detection model loaded")
    except Exception as e:
        logger.error(f"❌ Weapon detection model load failed: {e}")

    try:
        db = SessionLocal()
        weapon_detection_manager.start_all_weapon_cameras(db)
        db.close()
        logger.info("✅ Weapon detection started for all fence/insider cameras")
    except Exception as e:
        logger.error(f"❌ Weapon detection auto-start failed: {e}")

    yield

    logger.info("🛑 Shutting down EagleWatch backend...")
    face_detection_manager.stop_all()
    weapon_detection_manager.stop_all()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Backend API for EagleWatch Surveillance System",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static",  StaticFiles(directory="static"),  name="static")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# ── Routers ──────────────────────────────────────────────────────────────────
app.include_router(auth_router,               prefix="/api/v1/auth",            tags=["Authentication"])
app.include_router(property_router,           prefix="/api/v1/properties",       tags=["Properties"])
app.include_router(settings_router,           prefix="/api/v1/settings",         tags=["Settings"])
app.include_router(dashboard_router,          prefix="/api/v1/dashboard",        tags=["Dashboard & Alerts"])
app.include_router(fence_config_router,       prefix="/api/v1/fence-config",     tags=["Fence Config"])
app.include_router(climbing_detection_router, prefix="/api/v1/climbing",         tags=["Climbing Detection"])
# app.include_router(stream_router,             prefix="/api/v1/stream",           tags=["Camera Stream"])
app.include_router(person_tracking_router,    prefix="/api/v1/person-tracking",  tags=["Person Tracking"])
app.include_router(face_detection_router,     prefix="/api/v1/face-detection",   tags=["Face Detection"])
app.include_router(weapon_detection_router,   prefix="/api/v1/weapon-detection", tags=["Weapon Detection"])
app.include_router(websocket_router,          prefix="/api/v1/ws",               tags=["WebSocket Alerts"])  # ✅ NEW


@app.get("/")
def home():
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running ✅",
        "docs": "/docs",
        "websocket": "/api/v1/ws/alerts/{property_id}?token=<jwt_token>",  # ✅ NEW
    }