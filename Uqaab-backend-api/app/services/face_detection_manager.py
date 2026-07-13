# app/services/face_detection_manager.py
"""
Face Detection Manager
======================
Manages one FaceDetectionService instance per entrance camera.
Called from main.py lifespan so services auto-start on server boot.
"""
import logging
from typing import Dict
from app.services.face_detection_service import FaceDetectionService
from sqlalchemy.orm import Session

from app.models.camera import Camera

logger = logging.getLogger(__name__)


class FaceDetectionManager:
    """
    Singleton-like manager (one instance in detection_manager or main).
    """

    def __init__(self):
        # camera_id → FaceDetectionService
        self._services: Dict[int, "FaceDetectionService"] = {}  # noqa: F821

    # ──────────────────────────────────────────────────────────────
    # AUTO-START FROM DB
    # ──────────────────────────────────────────────────────────────
    def start_all_entrance_cameras(self, db: Session):
        """Find every entrance camera in the DB and start detection."""
        cameras = (
            db.query(Camera)
            .filter(Camera.camera_type == "entrance")
            .all()
        )
        logger.info(f"Found {len(cameras)} entrance camera(s) to monitor")

        for cam in cameras:
            self.start_camera(cam.id, cam.rtsp_url, cam.property_id)

    # ──────────────────────────────────────────────────────────────
    # PER-CAMERA CONTROL
    # ──────────────────────────────────────────────────────────────
    def start_camera(self, camera_id: int, rtsp_url: str, property_id: int):
        from app.services.face_detection_service import FaceDetectionService

        if camera_id in self._services and self._services[camera_id].is_running():
            logger.info(f"[FDM] Camera {camera_id} already running")
            return

        svc = FaceDetectionService(
            camera_id=camera_id,
            rtsp_url=rtsp_url,
            property_id=property_id,
        )
        svc.start()
        self._services[camera_id] = svc
        logger.info(f"[FDM] Started face detection for camera {camera_id}")

    def stop_camera(self, camera_id: int):
        svc = self._services.pop(camera_id, None)
        if svc:
            svc.stop()
            logger.info(f"[FDM] Stopped face detection for camera {camera_id}")

    def restart_camera(self, camera_id: int, rtsp_url: str, property_id: int):
        self.stop_camera(camera_id)
        self.start_camera(camera_id, rtsp_url, property_id)

    def stop_all(self):
        for cam_id in list(self._services.keys()):
            self.stop_camera(cam_id)

    def status(self) -> dict:
        return {
            cam_id: svc.is_running()
            for cam_id, svc in self._services.items()
        }


# Global singleton
face_detection_manager = FaceDetectionManager()