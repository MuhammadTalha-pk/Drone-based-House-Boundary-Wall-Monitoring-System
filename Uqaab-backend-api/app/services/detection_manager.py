# # app/services/detection_manager.py

# import threading
# import logging
# from time import time
# from typing import Dict, Optional
# from sqlalchemy.orm import Session

# logger = logging.getLogger(__name__)


# class DetectionManager:
#     """
#     Manages one detection thread per fence camera.
#     Global singleton - one instance for the whole app.
#     """

#     def __init__(self):
#         self._threads: Dict[int, threading.Thread] = {}
#         self._stop_flags: Dict[int, threading.Event] = {}
#         self._detector = None
#         self._initialized = False

#     def initialize(
#         self,
#         api_base_url: str = "http://localhost:8000",
#         model_path: str = "yolov8n-pose.pt",
#     ):
#         """
#         Call once at app startup.
#         Loads the YOLO model.
#         """
#         if self._initialized:
#             return

#         from app.services.wall_climbing_detector import WallClimbingDetector

#         self._detector = WallClimbingDetector(
#             api_base_url=api_base_url,
#             api_token="",  # Not needed - alert endpoint has no auth
#             model_path=model_path,
#         )
#         self._initialized = True
#         logger.info("✅ DetectionManager initialized")

#     def start_camera(
#         self,
#         camera_id: int,
#         camera_name: str,
#         rtsp_url: str,
#         polygon: list,
#         property_id: int,
#         camera_cell_row: int = 0,
#         camera_cell_col: int = 0,
#     ):
#         """Start a detection thread for one fence camera"""
#         if not self._initialized:
#             logger.error("DetectionManager not initialized!")
#             return

#         # Stop existing thread first
#         self.stop_camera(camera_id)

#         stop_event = threading.Event()
#         self._stop_flags[camera_id] = stop_event

#         def run():
#             try:
#                 self._detector.process_camera(
#                     camera_id=camera_id,
#                     camera_name=camera_name,
#                     rtsp_url=rtsp_url,
#                     polygon=polygon,
#                     property_id=property_id,
#                     camera_cell_row=camera_cell_row,
#                     camera_cell_col=camera_cell_col,
#                     stop_event=stop_event,
#                     save_snapshots=True,
#                     snapshot_dir="static/snapshots",
#                 )
#             except Exception as e:
#                 logger.error(
#                     f"[Camera {camera_id}] Detection thread crashed: {e}"
#                 )

#         thread = threading.Thread(
#             target=run,
#             daemon=True,
#             name=f"detector-cam-{camera_id}",
#         )
#         thread.start()
#         self._threads[camera_id] = thread
#         logger.info(f"✅ Detection thread started for camera {camera_id}")

#     def stop_camera(self, camera_id: int):
#         """Stop the detection thread for a camera"""
#         if camera_id in self._stop_flags:
#             self._stop_flags[camera_id].set()
#             del self._stop_flags[camera_id]

#         if camera_id in self._threads:
#             del self._threads[camera_id]
#             logger.info(f"🛑 Detection stopped for camera {camera_id}")

#     def restart_camera(
#         self,
#         camera_id: int,
#         camera_name: str,
#         rtsp_url: str,
#         polygon: list,
#         property_id: int,
#         camera_cell_row: int = 0,
#         camera_cell_col: int = 0,
#     ):
#         """Stop then restart detection (used when polygon is updated)"""
#         self.stop_camera(camera_id)
#         time.sleep(1)
#         self.start_camera(
#             camera_id=camera_id,
#             camera_name=camera_name,
#             rtsp_url=rtsp_url,
#             polygon=polygon,
#             property_id=property_id,
#             camera_cell_row=camera_cell_row,
#             camera_cell_col=camera_cell_col,
#         )

#     def start_all_from_db(self, db: Session):
#         """
#         Auto-start detection for ALL fence cameras
#         that have a saved polygon config.
#         Called once at server startup.
#         """
#         from app.models.camera import Camera
#         from app.models.fence_config import FenceConfig

#         try:
#             fence_cameras = (
#                 db.query(Camera)
#                 .filter(Camera.camera_type == "fence")
#                 .all()
#             )

#             started = 0
#             for camera in fence_cameras:
#                 config = (
#                     db.query(FenceConfig)
#                     .filter(FenceConfig.camera_id == camera.id)
#                     .first()
#                 )
#                 if config and config.polygon_points:
#                     self.start_camera(
#                         camera_id=camera.id,
#                         camera_name=camera.name,
#                         rtsp_url=camera.rtsp_url,
#                         polygon=config.polygon_points,
#                         property_id=camera.property_id,
#                         camera_cell_row=camera.grid_cell_row,
#                         camera_cell_col=camera.grid_cell_col,
#                     )
#                     started += 1

#             logger.info(
#                 f"✅ Auto-started detection for {started} fence cameras"
#             )
#         except Exception as e:
#             logger.error(f"start_all_from_db error: {e}")

#     def get_status(self) -> Dict:
#         return {
#             cam_id: {
#                 "running": t.is_alive(),
#                 "thread": t.name,
#             }
#             for cam_id, t in self._threads.items()
#         }

#     @property
#     def is_initialized(self) -> bool:
#         return self._initialized


# # ✅ Global singleton
# detection_manager = DetectionManager()

import threading
import logging
import time as time_module
from typing import Dict
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


class DetectionManager:
    def __init__(self):
        self._threads: Dict[int, threading.Thread] = {}
        self._stop_flags: Dict[int, threading.Event] = {}
        self._detector = None
        self._initialized = False

    def initialize(
        self,
        api_base_url: str = "http://localhost:8000",
        model_path: str = "yolov8n-pose.pt",
    ):
        if self._initialized:
            return

        from app.services.wall_climbing import WallClimbingDetector

        self._detector = WallClimbingDetector(model_path=model_path)
        self._initialized = True
        logger.info("✅ DetectionManager initialized")

    def start_camera(
        self,
        camera_id: int,
        camera_name: str,
        rtsp_url: str,
        polygon: list,
        property_id: int,
        camera_cell_row: int = 0,
        camera_cell_col: int = 0,
    ):
        if not self._initialized:
            logger.error("DetectionManager not initialized!")
            return

        self.stop_camera(camera_id)

        stop_event = threading.Event()
        self._stop_flags[camera_id] = stop_event

        def run():
            try:
                self._detector.process_camera(
                    camera_id=camera_id,
                    camera_name=camera_name,
                    rtsp_url=rtsp_url,
                    polygon=polygon,
                    property_id=property_id,
                    camera_cell_row=camera_cell_row,
                    camera_cell_col=camera_cell_col,
                    stop_event=stop_event,
                    save_snapshots=True,
                    snapshot_dir="static/snapshots",
                )
            except Exception as e:
                logger.error(f"[Camera {camera_id}] Detection thread crashed: {e}")

        thread = threading.Thread(
            target=run,
            daemon=True,
            name=f"detector-cam-{camera_id}",
        )
        thread.start()
        self._threads[camera_id] = thread
        logger.info(f"✅ Detection thread started for camera {camera_id}")

    def stop_camera(self, camera_id: int):
        if camera_id in self._stop_flags:
            self._stop_flags[camera_id].set()
            del self._stop_flags[camera_id]

        if camera_id in self._threads:
            del self._threads[camera_id]
            logger.info(f"🛑 Detection stopped for camera {camera_id}")

    def restart_camera(
        self,
        camera_id: int,
        camera_name: str,
        rtsp_url: str,
        polygon: list,
        property_id: int,
        camera_cell_row: int = 0,
        camera_cell_col: int = 0,
    ):
        self.stop_camera(camera_id)
        time_module.sleep(1)
        self.start_camera(
            camera_id=camera_id,
            camera_name=camera_name,
            rtsp_url=rtsp_url,
            polygon=polygon,
            property_id=property_id,
            camera_cell_row=camera_cell_row,
            camera_cell_col=camera_cell_col,
        )

    def start_all_from_db(self, db: Session):
        from app.models.camera import Camera
        from app.models.fence_config import FenceConfig

        try:
            fence_cameras = db.query(Camera).filter(Camera.camera_type == "fence").all()

            started = 0
            for camera in fence_cameras:
                config = (
                    db.query(FenceConfig)
                    .filter(FenceConfig.camera_id == camera.id)
                    .first()
                )
                if config and config.polygon_points:
                    self.start_camera(
                        camera_id=camera.id,
                        camera_name=camera.name,
                        rtsp_url=camera.rtsp_url,
                        polygon=config.polygon_points,
                        property_id=camera.property_id,
                        camera_cell_row=camera.grid_cell_row,
                        camera_cell_col=camera.grid_cell_col,
                    )
                    started += 1

            logger.info(f"✅ Auto-started detection for {started} fence cameras")
        except Exception as e:
            logger.error(f"start_all_from_db error: {e}")

    def get_status(self) -> Dict:
        return {
            cam_id: {
                "running": t.is_alive(),
                "thread": t.name,
            }
            for cam_id, t in self._threads.items()
        }

    @property
    def is_initialized(self) -> bool:
        return self._initialized


detection_manager = DetectionManager()