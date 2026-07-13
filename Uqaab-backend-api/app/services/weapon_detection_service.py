# app/services/weapon_detection_service.py (UPDATED - WebSocket Integration)
"""
Weapon Detection Service (Fence & Insider Cameras) - WITH REAL-TIME ALERTS
===========================================================================
Detects weapons via YOLOv11s, identifies holders via face recognition,
and immediately broadcasts WebSocket alerts for non-guard / stray weapons.
"""
import cv2
import os
import uuid
import math
import logging
import threading
import time
import numpy as np
from datetime import datetime, timezone
from typing import Optional, List, Dict, Tuple
import mediapipe as mp

from app.core.database import SessionLocal
from app.models.camera import Camera
from app.models.alert import Alert
from app.models.property import Property
from app.models.weapon_detection import WeaponDetectionEvent
from app.services.face_recognition_service import FaceRecognitionService
from app.services.person_tracker import PersonTracker
from app.services.alert_service import notify_weapon_detected  # ✅ NEW

logger = logging.getLogger(__name__)

WEAPONS_DIR   = "static/weapons"
FACES_DIR     = "static/faces"
SNAPSHOTS_DIR = "static/snapshots"
VIDEOS_DIR    = "static/videos"

FRAME_SKIP              = 5
VIDEO_DURATION_SEC      = 5
WEAPON_CONF_THRESHOLD   = 0.45
FACE_DETECTION_CONF     = 0.5
PROXIMITY_RATIO         = 0.30
STRAY_COOLDOWN_KEY      = "stray"
FACE_MODEL_PATH         = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "models", "blaze_face_short_range.tflite"
)


def _ts() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")


def _bbox_center(bbox: Tuple[int, int, int, int]) -> Tuple[float, float]:
    x1, y1, x2, y2 = bbox
    return (x1 + x2) / 2.0, (y1 + y2) / 2.0


def _distance(p1: Tuple[float, float], p2: Tuple[float, float]) -> float:
    return math.sqrt((p1[0] - p2[0]) ** 2 + (p1[1] - p2[1]) ** 2)


class WeaponDetectionService:
    def __init__(self, camera_id, rtsp_url, property_id, camera_type, weapon_model):
        self.camera_id   = camera_id
        self.rtsp_url    = rtsp_url
        self.property_id = property_id
        self.camera_type = camera_type
        self.weapon_model = weapon_model

        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None

        self._last_stray_alert_time: float = 0.0
        self._stray_cooldown_sec: int = 5
        self._weapon_buffer: int = 0

        for d in [WEAPONS_DIR, FACES_DIR, SNAPSHOTS_DIR, VIDEOS_DIR]:
            os.makedirs(d, exist_ok=True)

    def start(self):
        if self._thread and self._thread.is_alive():
            logger.warning(f"[Cam {self.camera_id}] Weapon detection already running")
            return

        self._stop_event.clear()
        self._thread = threading.Thread(
            target=self._run_loop,
            name=f"weapon_detect_cam_{self.camera_id}",
            daemon=True,
        )
        self._thread.start()
        logger.info(
            f"[Cam {self.camera_id}] Weapon detection started "
            f"(type={self.camera_type}) → {self.rtsp_url}"
        )

    def stop(self):
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=10)
        logger.info(f"[Cam {self.camera_id}] Weapon detection stopped")

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def _run_loop(self):
        import mediapipe as mp
        from mediapipe.tasks import python as mp_tasks
        from mediapipe.tasks.python import vision

        base_options = mp_tasks.BaseOptions(model_asset_path=FACE_MODEL_PATH)
        options = vision.FaceDetectorOptions(
            base_options=base_options,
            running_mode=vision.RunningMode.IMAGE,
            min_detection_confidence=FACE_DETECTION_CONF,
        )
        face_detector = vision.FaceDetector.create_from_options(options)

        reconnect_attempts = 0
        max_reconnect = 10

        try:
            while not self._stop_event.is_set():
                cap = cv2.VideoCapture(self.rtsp_url)
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

                if not cap.isOpened():
                    reconnect_attempts += 1
                    logger.warning(
                        f"[Cam {self.camera_id}] Cannot open stream. "
                        f"Attempt {reconnect_attempts}/{max_reconnect}"
                    )
                    if reconnect_attempts >= max_reconnect:
                        logger.error(
                            f"[Cam {self.camera_id}] Max reconnects reached. Stopping."
                        )
                        break
                    time.sleep(5)
                    continue

                reconnect_attempts = 0
                frame_count = 0
                logger.info(f"[Cam {self.camera_id}] Stream connected ✅")

                while not self._stop_event.is_set():
                    ret, frame = cap.read()
                    if not ret or frame is None:
                        logger.warning(
                            f"[Cam {self.camera_id}] Stream lost — reconnecting"
                        )
                        break

                    frame_count += 1
                    if frame_count % FRAME_SKIP != 0:
                        continue

                    try:
                        self._process_frame(frame, face_detector)
                    except Exception as e:
                        logger.error(
                            f"[Cam {self.camera_id}] Frame processing error: {e}",
                            exc_info=True,
                        )

                cap.release()
                if not self._stop_event.is_set():
                    logger.info(
                        f"[Cam {self.camera_id}] Waiting 3s before reconnect"
                    )
                    time.sleep(3)
        finally:
            face_detector.close()

        logger.info(f"[Cam {self.camera_id}] Weapon detection loop exited")

    def _process_frame(self, frame, face_detector):
        h, w = frame.shape[:2]

        results = self.weapon_model.predict(
            frame,
            verbose=False,
            conf=WEAPON_CONF_THRESHOLD,
            device="cpu",
        )

        result = results[0]
        if result.boxes is None or len(result.boxes) == 0:
            self._weapon_buffer = 0
            return

        self._weapon_buffer += 1
        if self._weapon_buffer < 3:
            return

        boxes      = result.boxes.xyxy.cpu().numpy()
        confs      = result.boxes.conf.cpu().numpy()
        class_ids  = result.boxes.cls.cpu().numpy().astype(int)

        import mediapipe as mp
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        face_results = face_detector.detect(mp_image)

        face_bboxes = []
        if face_results.detections:
            for detection in face_results.detections:
                bbox = detection.bounding_box
                fx1 = max(0, bbox.origin_x)
                fy1 = max(0, bbox.origin_y)
                fx2 = min(w, bbox.origin_x + bbox.width)
                fy2 = min(h, bbox.origin_y + bbox.height)
                if fx2 > fx1 and fy2 > fy1:
                    face_bboxes.append((fx1, fy1, fx2, fy2))

        frame_diagonal = math.sqrt(w ** 2 + h ** 2)
        max_proximity_px = PROXIMITY_RATIO * frame_diagonal

        for box, conf, cls_id in zip(boxes, confs, class_ids):
            wx1, wy1, wx2, wy2 = map(int, box[:4])
            weapon_center = _bbox_center((wx1, wy1, wx2, wy2))
            weapon_conf_pct = int(conf * 100)
            weapon_class = self.weapon_model.names.get(cls_id, "weapon")

            closest_face = None
            closest_dist = float("inf")

            for face_bbox in face_bboxes:
                face_center = _bbox_center(face_bbox)
                dist = _distance(weapon_center, face_center)
                if dist < closest_dist:
                    closest_dist = dist
                    closest_face = face_bbox

            if closest_face is not None and closest_dist <= max_proximity_px:
                self._handle_weapon_with_person(
                    frame=frame,
                    weapon_bbox=(wx1, wy1, wx2, wy2),
                    weapon_class=weapon_class,
                    weapon_conf=weapon_conf_pct,
                    face_bbox=closest_face,
                )
            else:
                self._handle_stray_weapon(
                    frame=frame,
                    weapon_bbox=(wx1, wy1, wx2, wy2),
                    weapon_class=weapon_class,
                    weapon_conf=weapon_conf_pct,
                )

    def _handle_weapon_with_person(self, frame, weapon_bbox, weapon_class, weapon_conf, face_bbox):
        fx1, fy1, fx2, fy2 = face_bbox

        face_crop = frame[fy1:fy2, fx1:fx2]
        if face_crop.size == 0:
            self._handle_stray_weapon(frame, weapon_bbox, weapon_class, weapon_conf)
            return

        encoding = FaceRecognitionService.compute_encoding(face_crop)

        db = SessionLocal()
        try:
            if encoding is not None:
                rec_svc = FaceRecognitionService(db)
                result = rec_svc.recognize(
                    property_id=self.property_id,
                    face_encoding=encoding,
                )

                if result.is_authorized and result.role == "Guard":
                    logger.info(
                        f"[Cam {self.camera_id}] ✅ Guard '{result.person_name}' "
                        f"with weapon — suppressed"
                    )
                    self._log_weapon_event(
                        db=db, frame=frame, weapon_bbox=weapon_bbox,
                        weapon_class=weapon_class, weapon_conf=weapon_conf,
                        face_crop=face_crop, holder_identified=True,
                        holder_person_id=result.person_id,
                        holder_person_name=result.person_name,
                        holder_role=result.role, is_guard=True, is_stray=False,
                        tracking_id=None, alert_id=None, drone_triggered=False,
                    )
                    db.commit()
                    return

                logger.info(
                    f"[Cam {self.camera_id}] ❌ Non-guard with weapon: "
                    f"name={result.person_name or 'Unknown'} role={result.role or 'None'}"
                )
                person_name = result.person_name
                person_id = result.person_id
                person_role = result.role
            else:
                logger.info(
                    f"[Cam {self.camera_id}] ❌ Unidentifiable person with weapon"
                )
                person_name = None
                person_id = None
                person_role = None
                encoding = None

            tracker = PersonTracker(db)
            should_alert, tracking_id = tracker.track_person(
                property_id=self.property_id,
                camera_id=self.camera_id,
                camera_type=self.camera_type,
                face_encoding=encoding,
            )

            if not should_alert:
                logger.debug(
                    f"[Cam {self.camera_id}] COOLDOWN active for "
                    f"{tracking_id} — skipping weapon alert"
                )
                return

            camera = db.query(Camera).filter(Camera.id == self.camera_id).first()
            camera_name = camera.name if camera else f"Camera {self.camera_id}"

            # Save media first
            uid = f"weapon_{int(time.time())}_{self.camera_id}"
            weapon_crop_url = self._save_weapon_crop(frame, weapon_bbox, uid)
            snapshot_url = self._save_snapshot(frame, uid)
            face_url = self._save_face(face_crop, uid)
            video_url = self._save_video(uid)

            # ✅ NEW: Use AlertService to create alert + broadcast WebSocket
            alert, broadcast_ok = notify_weapon_detected(
                db=db,
                property_id=self.property_id,
                camera_id=self.camera_id,
                camera_name=camera_name,
                camera_type=self.camera_type,
                confidence=weapon_conf,
                camera_cell_row=camera.grid_cell_row if camera else 0,
                camera_cell_col=camera.grid_cell_col if camera else 0,
                image_url=snapshot_url,
                clip_url=video_url,
                tracking_id=tracking_id,
                holder_person_name=person_name,
                holder_role=person_role,
            )

            self._log_weapon_event(
                db=db, frame=frame, weapon_bbox=weapon_bbox,
                weapon_class=weapon_class, weapon_conf=weapon_conf,
                face_crop=face_crop, holder_identified=True,
                holder_person_id=person_id,
                holder_person_name=person_name,
                holder_role=person_role, is_guard=False, is_stray=False,
                tracking_id=tracking_id, alert_id=alert.id,
                drone_triggered=True,
                weapon_crop_url=weapon_crop_url,
                snapshot_url=snapshot_url,
                face_url=face_url,
                video_url=video_url,
            )

            db.commit()

            logger.info(
                f"[Cam {self.camera_id}] 🚨 WEAPON ALERT created id={alert.id} "
                f"holder={person_name or 'Unknown'} tracking={tracking_id} | "
                f"Broadcast: {broadcast_ok}"
            )

        except Exception as e:
            logger.error(
                f"[Cam {self.camera_id}] Weapon+person processing error: {e}",
                exc_info=True,
            )
            try:
                db.rollback()
            except Exception:
                pass
        finally:
            db.close()

    def _handle_stray_weapon(self, frame, weapon_bbox, weapon_class, weapon_conf):
        now = time.time()

        if (now - self._last_stray_alert_time) < self._stray_cooldown_sec:
            logger.debug(
                f"[Cam {self.camera_id}] Stray weapon cooldown active — skipping"
            )
            return

        self._last_stray_alert_time = now

        db = SessionLocal()
        try:
            camera = db.query(Camera).filter(Camera.id == self.camera_id).first()
            camera_name = camera.name if camera else f"Camera {self.camera_id}"

            # Save media first
            uid = f"stray_{int(time.time())}_{self.camera_id}"
            weapon_crop_url = self._save_weapon_crop(frame, weapon_bbox, uid)
            snapshot_url = self._save_snapshot(frame, uid)
            video_url = self._save_video(uid)

            # ✅ NEW: Use AlertService for stray weapon alert + broadcast
            alert, broadcast_ok = notify_weapon_detected(
                db=db,
                property_id=self.property_id,
                camera_id=self.camera_id,
                camera_name=camera_name,
                camera_type=self.camera_type,
                confidence=weapon_conf,
                camera_cell_row=camera.grid_cell_row if camera else 0,
                camera_cell_col=camera.grid_cell_col if camera else 0,
                image_url=snapshot_url,
                clip_url=video_url,
                tracking_id=uid,
            )

            self._log_weapon_event(
                db=db, frame=frame, weapon_bbox=weapon_bbox,
                weapon_class=weapon_class, weapon_conf=weapon_conf,
                face_crop=None, holder_identified=False,
                holder_person_id=None, holder_person_name=None,
                holder_role=None, is_guard=False, is_stray=True,
                tracking_id=uid, alert_id=alert.id,
                drone_triggered=True,
                weapon_crop_url=weapon_crop_url,
                snapshot_url=snapshot_url,
                face_url=None,
                video_url=video_url,
            )

            db.commit()

            logger.info(
                f"[Cam {self.camera_id}] 🚨 STRAY WEAPON ALERT created "
                f"id={alert.id} | Broadcast: {broadcast_ok}"
            )

        except Exception as e:
            logger.error(
                f"[Cam {self.camera_id}] Stray weapon processing error: {e}",
                exc_info=True,
            )
            try:
                db.rollback()
            except Exception:
                pass
        finally:
            db.close()

    def _log_weapon_event(self, db, frame, weapon_bbox, weapon_class, weapon_conf,
                          face_crop, holder_identified, holder_person_id,
                          holder_person_name, holder_role, is_guard, is_stray,
                          tracking_id, alert_id, drone_triggered=False,
                          weapon_crop_url=None, snapshot_url=None,
                          face_url=None, video_url=None):
        uid = tracking_id or uuid.uuid4().hex[:10]

        if weapon_crop_url is None:
            weapon_crop_url = self._save_weapon_crop(frame, weapon_bbox, uid)
        if snapshot_url is None:
            snapshot_url = self._save_snapshot(frame, uid)
        if face_url is None and face_crop is not None:
            face_url = self._save_face(face_crop, uid)

        wx1, wy1, wx2, wy2 = weapon_bbox

        event = WeaponDetectionEvent(
            property_id=self.property_id,
            camera_id=self.camera_id,
            camera_type=self.camera_type,
            weapon_class=weapon_class,
            weapon_confidence=weapon_conf,
            weapon_bbox={"x1": wx1, "y1": wy1, "x2": wx2, "y2": wy2},
            holder_identified=holder_identified,
            holder_person_id=holder_person_id,
            holder_person_name=holder_person_name,
            holder_role=holder_role,
            is_guard=is_guard,
            is_stray_weapon=is_stray,
            tracking_id=tracking_id,
            snapshot_url=snapshot_url,
            weapon_crop_url=weapon_crop_url,
            face_image_url=face_url,
            video_clip_url=video_url,
            alert_id=alert_id,
            drone_triggered=drone_triggered,
        )
        db.add(event)

    def _save_weapon_crop(self, frame, weapon_bbox, uid):
        wx1, wy1, wx2, wy2 = weapon_bbox
        crop = frame[wy1:wy2, wx1:wx2]
        filename = f"{uid}_weapon.jpg"
        path = os.path.join(WEAPONS_DIR, filename)
        if crop.size > 0:
            cv2.imwrite(path, crop)
        return f"/static/weapons/{filename}"

    def _save_face(self, face_crop, uid):
        filename = f"{uid}_face.jpg"
        path = os.path.join(FACES_DIR, filename)
        cv2.imwrite(path, face_crop)
        return f"/static/faces/{filename}"

    def _save_snapshot(self, frame, uid):
        filename = f"{uid}_snap.jpg"
        path = os.path.join(SNAPSHOTS_DIR, filename)
        cv2.imwrite(path, frame)
        return f"/static/snapshots/{filename}"

    def _save_video(self, uid):
        try:
            filename = f"{uid}_clip.mp4"
            path = os.path.join(VIDEOS_DIR, filename)

            cap = cv2.VideoCapture(self.rtsp_url)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            if not cap.isOpened():
                return None

            fps    = cap.get(cv2.CAP_PROP_FPS) or 20.0
            width  = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH) or 640)
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