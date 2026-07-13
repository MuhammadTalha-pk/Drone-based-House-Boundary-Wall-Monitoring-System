# # app/services/face_detection_service.py (UPDATED - WebSocket Integration)
# """
# Face Detection Service (Entrance Cameras Only) - WITH REAL-TIME ALERTS
# =======================================================================
# Continuously reads RTSP frames, detects faces, recognizes authorized persons,
# and immediately broadcasts WebSocket alerts for unauthorized detections.
# """
# import cv2
# import os
# import uuid
# import logging
# import threading
# import time
# from datetime import datetime, timezone
# from typing import Optional

# from app.core.database import SessionLocal
# from app.models.camera import Camera
# from app.models.alert import Alert
# from app.models.face_detection import FaceDetectionEvent
# from app.services.face_recognition_service import FaceRecognitionService
# from app.services.person_tracker import PersonTracker
# from app.services.alert_service import notify_unauthorized_person  # ✅ NEW

# logger = logging.getLogger(__name__)

# FACES_DIR     = "static/faces"
# SNAPSHOTS_DIR = "static/snapshots"
# VIDEOS_DIR    = "static/videos"

# FRAME_SKIP          = 5
# VIDEO_DURATION_SEC  = 5
# FACE_DETECTION_CONF = 0.6
# FACE_MODEL_PATH     = os.path.join(
#     os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
#     "models", "blaze_face_short_range.tflite"
# )


# class FaceDetectionService:
#     def __init__(self, camera_id: int, rtsp_url: str, property_id: int):
#         self.camera_id   = camera_id
#         self.rtsp_url    = rtsp_url
#         self.property_id = property_id

#         self._stop_event = threading.Event()
#         self._thread: Optional[threading.Thread] = None

#         os.makedirs(FACES_DIR,     exist_ok=True)
#         os.makedirs(SNAPSHOTS_DIR, exist_ok=True)
#         os.makedirs(VIDEOS_DIR,    exist_ok=True)

#     def start(self):
#         if self._thread and self._thread.is_alive():
#             logger.warning(f"[Cam {self.camera_id}] Already running")
#             return

#         self._stop_event.clear()
#         self._thread = threading.Thread(
#             target=self._run_loop,
#             name=f"face_detect_cam_{self.camera_id}",
#             daemon=True,
#         )
#         self._thread.start()
#         logger.info(f"[Cam {self.camera_id}] Face detection started → {self.rtsp_url}")

#     def stop(self):
#         self._stop_event.set()
#         if self._thread:
#             self._thread.join(timeout=10)
#         logger.info(f"[Cam {self.camera_id}] Face detection stopped")

#     def is_running(self) -> bool:
#         return self._thread is not None and self._thread.is_alive()

#     def _run_loop(self):
#         import mediapipe as mp
#         from mediapipe.tasks import python as mp_tasks
#         from mediapipe.tasks.python import vision

#         base_options = mp_tasks.BaseOptions(model_asset_path=FACE_MODEL_PATH)
#         options = vision.FaceDetectorOptions(
#             base_options=base_options,
#             running_mode=vision.RunningMode.IMAGE,
#             min_detection_confidence=FACE_DETECTION_CONF,
#         )
#         face_detector = vision.FaceDetector.create_from_options(options)

#         cap = cv2.VideoCapture(self.rtsp_url)
#         cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

#         if not cap.isOpened():
#             logger.error(f"[Cam {self.camera_id}] Cannot open stream: {self.rtsp_url}")
#             face_detector.close()
#             return

#         frame_count = 0

#         try:
#             while not self._stop_event.is_set():
#                 ret, frame = cap.read()
#                 if not ret:
#                     logger.warning(f"[Cam {self.camera_id}] Stream lost, reconnecting...")
#                     cap.release()
#                     time.sleep(3)
#                     cap = cv2.VideoCapture(self.rtsp_url)
#                     cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
#                     continue

#                 frame_count += 1
#                 if frame_count % FRAME_SKIP != 0:
#                     continue

#                 self._process_frame(frame, face_detector)
#         finally:
#             cap.release()
#             face_detector.close()

#     def _process_frame(self, frame, face_detector):
#         import mediapipe as mp

#         h, w = frame.shape[:2]
#         rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

#         mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
#         results = face_detector.detect(mp_image)

#         if not results.detections:
#             return

#         for detection in results.detections:
#             bbox = detection.bounding_box

#             x1 = max(0, bbox.origin_x)
#             y1 = max(0, bbox.origin_y)
#             x2 = min(w, bbox.origin_x + bbox.width)
#             y2 = min(h, bbox.origin_y + bbox.height)

#             if x2 <= x1 or y2 <= y1:
#                 continue

#             face_crop = frame[y1:y2, x1:x2]
#             if face_crop.size == 0:
#                 continue

#             encoding = FaceRecognitionService.compute_encoding(face_crop)
#             if encoding is None:
#                 logger.debug(f"[Cam {self.camera_id}] No encoding returned for crop")
#                 continue

#             db = SessionLocal()
#             try:
#                 rec_svc = FaceRecognitionService(db)
#                 result  = rec_svc.recognize(
#                     property_id=self.property_id,
#                     face_encoding=encoding,
#                 )

#                 if result.is_authorized:
#                     logger.info(
#                         f"[Cam {self.camera_id}] ✅ Authorized: "
#                         f"{result.person_name} ({result.role})"
#                     )
#                     self._log_event(
#                         db=db,
#                         face_crop=face_crop,
#                         full_frame=frame,
#                         encoding=encoding,
#                         result=result,
#                         tracking_id=None,
#                         alert_id=None,
#                         save_snapshot=False,
#                         save_video=False,
#                     )
#                     db.commit()
#                 else:
#                     logger.info(f"[Cam {self.camera_id}] ❌ Unauthorized face detected")
#                     self._handle_unauthorized(
#                         db=db,
#                         face_crop=face_crop,
#                         full_frame=frame,
#                         encoding=encoding,
#                         result=result,
#                     )

#             except Exception as e:
#                 logger.error(f"[Cam {self.camera_id}] Processing error: {e}", exc_info=True)
#                 try:
#                     db.rollback()
#                 except Exception:
#                     pass
#             finally:
#                 db.close()

#     def _handle_unauthorized(self, db, face_crop, full_frame, encoding, result):
#         """Handle unauthorized person with WebSocket alert broadcast."""

#         tracker = PersonTracker(db)
#         should_alert, tracking_id = tracker.track_person(
#             property_id=self.property_id,
#             camera_id=self.camera_id,
#             camera_type="entrance",
#             face_encoding=encoding,
#         )

#         if not should_alert:
#             logger.debug(
#                 f"[Cam {self.camera_id}] COOLDOWN active for {tracking_id}, skipping alert"
#             )
#             return

#         camera = db.query(Camera).filter(Camera.id == self.camera_id).first()
#         camera_name = camera.name if camera else f"Camera {self.camera_id}"

#         # Save media first
#         uid = f"unauth_{int(time.time())}_{self.camera_id}"
#         face_url     = self._save_face(face_crop, uid)
#         snapshot_url = self._save_snapshot(full_frame, uid)
#         video_url    = self._save_video(uid)

#         # ✅ NEW: Use AlertService to create alert + broadcast WebSocket
#         alert, broadcast_ok = notify_unauthorized_person(
#             db=db,
#             property_id=self.property_id,
#             camera_id=self.camera_id,
#             camera_name=camera_name,
#             confidence=int(result.confidence * 100),
#             image_url=snapshot_url,
#             clip_url=video_url,
#             tracking_id=tracking_id,
#         )

#         # Log face detection event linked to the alert
#         self._log_event(
#             db=db,
#             face_crop=face_crop,
#             full_frame=full_frame,
#             encoding=encoding,
#             result=result,
#             tracking_id=tracking_id,
#             alert_id=alert.id,
#             save_snapshot=False,
#             save_video=False,
#             face_url_override=face_url,
#             snapshot_url_override=snapshot_url,
#             video_url_override=video_url,
#         )

#         db.commit()

#         logger.info(
#             f"[Cam {self.camera_id}] 🚨 ALERT created id={alert.id} "
#             f"tracking={tracking_id} | Broadcast: {broadcast_ok}"
#         )

#     def _log_event(self, db, face_crop, full_frame, encoding, result, tracking_id,
#                    alert_id, save_snapshot=True, save_video=True,
#                    face_url_override=None, snapshot_url_override=None, video_url_override=None):
#         uid = uuid.uuid4().hex[:10]

#         face_url     = face_url_override     or self._save_face(face_crop, uid)
#         snapshot_url = snapshot_url_override or (self._save_snapshot(full_frame, uid) if save_snapshot else None)
#         video_url    = video_url_override    or (self._save_video(uid)                if save_video    else None)

#         event = FaceDetectionEvent(
#             property_id=self.property_id,
#             camera_id=self.camera_id,
#             is_authorized=result.is_authorized,
#             matched_person_id=result.person_id,
#             matched_person_name=result.person_name,
#             matched_role=result.role,
#             recognition_confidence=result.confidence,
#             tracking_id=tracking_id,
#             face_image_url=face_url,
#             snapshot_url=snapshot_url,
#             video_clip_url=video_url,
#             alert_id=alert_id,
#         )
#         db.add(event)

#     def _save_face(self, face_crop, uid: str) -> str:
#         filename = f"{uid}_face.jpg"
#         path = os.path.join(FACES_DIR, filename)
#         cv2.imwrite(path, face_crop)
#         return f"/static/faces/{filename}"

#     def _save_snapshot(self, frame, uid: str) -> str:
#         filename = f"{uid}_snap.jpg"
#         path = os.path.join(SNAPSHOTS_DIR, filename)
#         cv2.imwrite(path, frame)
#         return f"/static/snapshots/{filename}"

#     def _save_video(self, uid: str) -> Optional[str]:
#         try:
#             filename = f"{uid}_clip.mp4"
#             path = os.path.join(VIDEOS_DIR, filename)

#             cap = cv2.VideoCapture(self.rtsp_url)
#             cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

#             if not cap.isOpened():
#                 return None

#             fps    = cap.get(cv2.CAP_PROP_FPS) or 20.0
#             width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)  or 640)
#             height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 480)

#             fourcc = cv2.VideoWriter_fourcc(*"mp4v")
#             writer = cv2.VideoWriter(path, fourcc, fps, (width, height))

#             deadline = time.time() + VIDEO_DURATION_SEC
#             while time.time() < deadline:
#                 ret, frame = cap.read()
#                 if not ret:
#                     break
#                 writer.write(frame)

#             cap.release()
#             writer.release()
#             return f"/static/videos/{filename}"

#         except Exception as e:
#             logger.error(f"[Cam {self.camera_id}] Video save failed: {e}")
#             return None


# def _ts() -> str:
#     return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")

# app/services/face_detection_service.py
"""
Face Detection Service (Entrance Cameras Only)
==============================================
Continuously reads RTSP frames, detects faces via MediaPipe, crops them,
encodes them, asks FaceRecognitionService if they're authorized, and if not
— creates an alert + tracking record + saves face/snapshot/video.

One instance runs per entrance camera (managed by FaceDetectionManager).
"""
import cv2
import os
import uuid
import logging
import threading
import time
from datetime import datetime, timezone
from typing import Optional

from app.core.database import SessionLocal
from app.models.camera import Camera
from app.models.alert import Alert
from app.models.face_detection import FaceDetectionEvent
from app.services.face_recognition_service import FaceRecognitionService
from app.services.person_tracker import PersonTracker

logger = logging.getLogger(__name__)

# ─── Paths ────────────────────────────────────────────────────────────────────
FACES_DIR     = "static/faces"
SNAPSHOTS_DIR = "static/snapshots"
VIDEOS_DIR    = "static/videos"

# ─── Config ───────────────────────────────────────────────────────────────────
FRAME_SKIP          = 5         # Process every Nth frame (reduce CPU load)
VIDEO_DURATION_SEC  = 5         # Seconds of video saved on alert
FACE_DETECTION_CONF = 0.6       # MediaPipe minimum detection confidence
FACE_MODEL_PATH     = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "models", "blaze_face_short_range.tflite"
)


class FaceDetectionService:
    """
    One instance per entrance camera.
    Call start() to begin monitoring in a background thread.
    Call stop() to terminate.
    """

    def __init__(self, camera_id: int, rtsp_url: str, property_id: int):
        self.camera_id   = camera_id
        self.rtsp_url    = rtsp_url
        self.property_id = property_id

        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None

        # Ensure output directories exist
        os.makedirs(FACES_DIR,     exist_ok=True)
        os.makedirs(SNAPSHOTS_DIR, exist_ok=True)
        os.makedirs(VIDEOS_DIR,    exist_ok=True)

    # ─────────────────────────────────────────────────────────────────
    # LIFECYCLE
    # ─────────────────────────────────────────────────────────────────
    def start(self):
        if self._thread and self._thread.is_alive():
            logger.warning(f"[Cam {self.camera_id}] Already running")
            return

        self._stop_event.clear()
        self._thread = threading.Thread(
            target=self._run_loop,
            name=f"face_detect_cam_{self.camera_id}",
            daemon=True,
        )
        self._thread.start()
        logger.info(f"[Cam {self.camera_id}] Face detection started → {self.rtsp_url}")

    def stop(self):
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=10)
        logger.info(f"[Cam {self.camera_id}] Face detection stopped")

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    # ─────────────────────────────────────────────────────────────────
    # MAIN LOOP
    # ─────────────────────────────────────────────────────────────────
    def _run_loop(self):
        import mediapipe as mp
        from mediapipe.tasks import python as mp_tasks
        from mediapipe.tasks.python import vision

        # Build detector using the new Tasks API
        base_options = mp_tasks.BaseOptions(
            model_asset_path=FACE_MODEL_PATH
        )
        options = vision.FaceDetectorOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.IMAGE,
            min_detection_confidence=FACE_DETECTION_CONF,
        )
        face_detector = vision.FaceDetector.create_from_options(options)

        cap = cv2.VideoCapture(self.rtsp_url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        if not cap.isOpened():
            logger.error(f"[Cam {self.camera_id}] Cannot open stream: {self.rtsp_url}")
            face_detector.close()
            return

        frame_count = 0

        try:
            while not self._stop_event.is_set():
                ret, frame = cap.read()
                if not ret:
                    logger.warning(f"[Cam {self.camera_id}] Stream lost, reconnecting...")
                    cap.release()
                    time.sleep(3)
                    cap = cv2.VideoCapture(self.rtsp_url)
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    continue

                frame_count += 1
                if frame_count % FRAME_SKIP != 0:
                    continue

                self._process_frame(frame, face_detector)
        finally:
            cap.release()
            face_detector.close()

    # ─────────────────────────────────────────────────────────────────
    # PER-FRAME PROCESSING
    # ─────────────────────────────────────────────────────────────────
    def _process_frame(self, frame, face_detector):
        """Detect faces in frame and run the full recognition pipeline."""
        import mediapipe as mp

        h, w = frame.shape[:2]
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Wrap the numpy array in a MediaPipe Image
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        results = face_detector.detect(mp_image)

        if not results.detections:
            return

        for detection in results.detections:
            bbox = detection.bounding_box

            # Tasks API returns pixel coords directly
            x1 = max(0, bbox.origin_x)
            y1 = max(0, bbox.origin_y)
            x2 = min(w, bbox.origin_x + bbox.width)
            y2 = min(h, bbox.origin_y + bbox.height)

            if x2 <= x1 or y2 <= y1:
                continue

            face_crop = frame[y1:y2, x1:x2]
            if face_crop.size == 0:
                continue

            # Compute 128-d encoding
            encoding = FaceRecognitionService.compute_encoding(face_crop)
            if encoding is None:
                logger.debug(f"[Cam {self.camera_id}] No encoding returned for crop")
                continue

            # Ask recognition service
            db = SessionLocal()
            try:
                rec_svc = FaceRecognitionService(db)
                result  = rec_svc.recognize(
                    property_id=self.property_id,
                    face_encoding=encoding,
                )

                if result.is_authorized:
                    logger.info(
                        f"[Cam {self.camera_id}] ✅ Authorized: "
                        f"{result.person_name} ({result.role})"
                    )
                    # Log authorized event (no alert)
                    self._log_event(
                        db=db,
                        face_crop=face_crop,
                        full_frame=frame,
                        encoding=encoding,
                        result=result,
                        tracking_id=None,
                        alert_id=None,
                        save_snapshot=False,
                        save_video=False,
                    )
                    db.commit()
                else:
                    logger.info(f"[Cam {self.camera_id}] ❌ Unauthorized face detected")
                    self._handle_unauthorized(
                        db=db,
                        face_crop=face_crop,
                        full_frame=frame,
                        encoding=encoding,
                        result=result,
                    )

            except Exception as e:
                logger.error(f"[Cam {self.camera_id}] Processing error: {e}", exc_info=True)
                try:
                    db.rollback()
                except Exception:
                    pass
            finally:
                db.close()

    # ─────────────────────────────────────────────────────────────────
    # UNAUTHORIZED FLOW
    # ─────────────────────────────────────────────────────────────────
    def _handle_unauthorized(self, db, face_crop, full_frame, encoding, result):
        """Full unauthorized pipeline: track → cooldown → alert → save media."""

        tracker = PersonTracker(db)
        should_alert, tracking_id = tracker.track_person(
            property_id=self.property_id,
            camera_id=self.camera_id,
            camera_type="entrance",
            face_encoding=encoding,
        )

        if not should_alert:
            logger.debug(
                f"[Cam {self.camera_id}] COOLDOWN active for {tracking_id}, skipping alert"
            )
            return

        # Get camera name
        camera = db.query(Camera).filter(Camera.id == self.camera_id).first()
        camera_name = camera.name if camera else f"Camera {self.camera_id}"

        # Create Alert record first (to get alert ID for file naming)
        alert = Alert(
            property_id=self.property_id,
            camera_id=self.camera_id,
            alert_type="Unauthorized Person at Entrance",
            camera_name=camera_name,
            severity="high",
            confidence=int(result.confidence * 100),
            image_url=None,
            clip_url=None,
            status="active",
            is_read=False,
        )
        db.add(alert)
        db.flush()   # get alert.id

        # Save media with alert number naming
        uid = f"alert_{alert.id}"
        face_url     = self._save_face(face_crop, uid)
        snapshot_url = self._save_snapshot(full_frame, uid)
        video_url    = self._save_video(uid)

        # Update alert with media URLs
        alert.image_url = snapshot_url
        alert.clip_url = video_url

        # Log face detection event
        self._log_event(
            db=db,
            face_crop=face_crop,
            full_frame=full_frame,
            encoding=encoding,
            result=result,
            tracking_id=tracking_id,
            alert_id=alert.id,
            save_snapshot=False,
            save_video=False,
            face_url_override=face_url,
            snapshot_url_override=snapshot_url,
            video_url_override=video_url,
        )

        db.commit()

        logger.info(
            f"[Cam {self.camera_id}] 🚨 ALERT created id={alert.id} "
            f"tracking={tracking_id}"
        )

    # ─────────────────────────────────────────────────────────────────
    # EVENT LOGGING
    # ─────────────────────────────────────────────────────────────────
    def _log_event(
        self,
        db,
        face_crop,
        full_frame,
        encoding,
        result,
        tracking_id,
        alert_id,
        save_snapshot: bool = True,
        save_video: bool = True,
        face_url_override: Optional[str] = None,
        snapshot_url_override: Optional[str] = None,
        video_url_override: Optional[str] = None,
    ):
        uid = uuid.uuid4().hex[:10]

        face_url     = face_url_override     or self._save_face(face_crop, uid)
        snapshot_url = snapshot_url_override or (self._save_snapshot(full_frame, uid) if save_snapshot else None)
        video_url    = video_url_override    or (self._save_video(uid)                if save_video    else None)

        event = FaceDetectionEvent(
            property_id=self.property_id,
            camera_id=self.camera_id,
            is_authorized=result.is_authorized,
            matched_person_id=result.person_id,
            matched_person_name=result.person_name,
            matched_role=result.role,
            recognition_confidence=result.confidence,
            tracking_id=tracking_id,
            face_image_url=face_url,
            snapshot_url=snapshot_url,
            video_clip_url=video_url,
            alert_id=alert_id,
        )
        db.add(event)
        # Note: commit handled by caller

    # ─────────────────────────────────────────────────────────────────
    # MEDIA HELPERS
    # ─────────────────────────────────────────────────────────────────
    def _save_face(self, face_crop, uid: str) -> str:
        filename = f"{uid}_face.jpg"
        path = os.path.join(FACES_DIR, filename)
        cv2.imwrite(path, face_crop)
        return f"/static/faces/{filename}"

    def _save_snapshot(self, frame, uid: str) -> str:
        filename = f"{uid}_snap.jpg"
        path = os.path.join(SNAPSHOTS_DIR, filename)
        cv2.imwrite(path, frame)
        return f"/static/snapshots/{filename}"

    def _save_video(self, uid: str) -> Optional[str]:
        """
        Capture VIDEO_DURATION_SEC seconds of live video after alert trigger.
        Runs synchronously (called from detection thread).
        """
        try:
            filename = f"{uid}_clip.mp4"
            path = os.path.join(VIDEOS_DIR, filename)

            cap = cv2.VideoCapture(self.rtsp_url)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            if not cap.isOpened():
                return None

            fps    = cap.get(cv2.CAP_PROP_FPS) or 20.0
            width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)  or 640)
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT) or 480)

            fourcc = cv2.VideoWriter_fourcc(*"mp4v")
            writer = cv2.VideoWriter(path, fourcc, fps, (width, height))

            deadline = time.time() + VIDEO_DURATION_SEC
            while time.time() < deadline:
                ret, frame = cap.read()
                if not ret:
                    break
                writer.write(frame)

            cap.release()
            writer.release()
            return f"/static/videos/{filename}"

        except Exception as e:
            logger.error(f"[Cam {self.camera_id}] Video save failed: {e}")
            return None


# ─────────────────────────────────────────────────────────────────────────────
# TIMESTAMP HELPER
# ─────────────────────────────────────────────────────────────────────────────
def _ts() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")