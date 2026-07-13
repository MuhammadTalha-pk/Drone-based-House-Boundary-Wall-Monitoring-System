# app/services/weapon_detection_manager.py
"""
Weapon Detection Manager
========================
Manages one WeaponDetectionService instance per fence/insider camera.
Called from main.py lifespan so services auto-start on server boot.

Loads the YOLOv11s weapon model ONCE and shares it across all camera threads.
The model runs inference on GPU (CUDA).
"""
from app.services.weapon_detection_service import WeaponDetectionService
import logging
from typing import Dict, Optional
from sqlalchemy.orm import Session

from app.models.camera import Camera

logger = logging.getLogger(__name__)

# Path to the trained weapon detection model
WEAPON_MODEL_PATH = "models/weapon.pt"


class WeaponDetectionManager:
    """
    Singleton-like manager (one instance for the whole app).
    Loads the YOLO model once and creates per-camera detection services.
    """

    def __init__(self):
        # camera_id → WeaponDetectionService
        self._services: Dict[int, "WeaponDetectionService"] = {}
        self._model = None
        self._initialized = False

    # ──────────────────────────────────────────────────────────────
    # INITIALIZATION — loads YOLO model on GPU
    # ──────────────────────────────────────────────────────────────
    def initialize(self, model_path: str = WEAPON_MODEL_PATH):
        """
        Load the YOLOv11s weapon model onto GPU.
        Call once at app startup (before starting any cameras).
        """
        if self._initialized:
            return

        try:
            from ultralytics import YOLO
            import torch

            logger.info(f"Loading weapon model from {model_path}...")
            self._model = YOLO(model_path)

            # Verify CUDA availability and move model to GPU
            if torch.cuda.is_available():
                logger.info(
                    f"✅ CUDA available: {torch.cuda.get_device_name(0)} | "
                    f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f}GB"
                )
            else:
                logger.warning(
                    "⚠️  CUDA not available — weapon detection will run on CPU "
                    "(much slower)"
                )

            # Print model info
            logger.info(
                f"✅ Weapon model loaded | "
                f"Classes: {self._model.names} | "
                f"Task: {self._model.task}"
            )

            self._initialized = True

        except Exception as e:
            logger.error(f"❌ Failed to load weapon model: {e}", exc_info=True)

    # ──────────────────────────────────────────────────────────────
    # AUTO-START FROM DB
    # ──────────────────────────────────────────────────────────────
    def start_all_weapon_cameras(self, db: Session):
        """
        Find every fence + insider camera in the DB and start
        weapon detection on each.
        """
        if not self._initialized:
            logger.error("WeaponDetectionManager not initialized — skipping auto-start")
            return

        cameras = (
            db.query(Camera)
            .filter(Camera.camera_type.in_(["fence", "insider"]))
            .all()
        )
        logger.info(
            f"Found {len(cameras)} fence/insider camera(s) for weapon detection"
        )

        for cam in cameras:
            self.start_camera(
                camera_id=cam.id,
                rtsp_url=cam.rtsp_url,
                property_id=cam.property_id,
                camera_type=cam.camera_type,
            )

    # ──────────────────────────────────────────────────────────────
    # PER-CAMERA CONTROL
    # ──────────────────────────────────────────────────────────────
    def start_camera(
        self,
        camera_id: int,
        rtsp_url: str,
        property_id: int,
        camera_type: str,
    ):
        if not self._initialized:
            logger.error("WeaponDetectionManager not initialized!")
            return

        from app.services.weapon_detection_service import WeaponDetectionService

        if camera_id in self._services and self._services[camera_id].is_running():
            logger.info(f"[WDM] Camera {camera_id} already running")
            return

        svc = WeaponDetectionService(
            camera_id=camera_id,
            rtsp_url=rtsp_url,
            property_id=property_id,
            camera_type=camera_type,
            weapon_model=self._model,   # Share the loaded model
        )
        svc.start()
        self._services[camera_id] = svc
        logger.info(
            f"[WDM] Started weapon detection for camera {camera_id} "
            f"(type={camera_type})"
        )

    def stop_camera(self, camera_id: int):
        svc = self._services.pop(camera_id, None)
        if svc:
            svc.stop()
            logger.info(f"[WDM] Stopped weapon detection for camera {camera_id}")

    def restart_camera(
        self,
        camera_id: int,
        rtsp_url: str,
        property_id: int,
        camera_type: str,
    ):
        self.stop_camera(camera_id)
        self.start_camera(camera_id, rtsp_url, property_id, camera_type)

    def stop_all(self):
        for cam_id in list(self._services.keys()):
            self.stop_camera(cam_id)

    def status(self) -> dict:
        return {
            cam_id: svc.is_running()
            for cam_id, svc in self._services.items()
        }

    @property
    def is_initialized(self) -> bool:
        return self._initialized


# Global singleton
weapon_detection_manager = WeaponDetectionManager()
