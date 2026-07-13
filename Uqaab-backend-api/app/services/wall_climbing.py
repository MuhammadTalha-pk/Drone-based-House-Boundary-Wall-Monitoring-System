# # app/services/wall_climbing.py
# import cv2
# import numpy as np
# import time
# import logging
# import os
# from typing import List, Dict, Optional, Tuple

# from app.core.database import SessionLocal
# from app.models.alert import Alert
# from app.models.property import Property
# from app.services.person_tracker import PersonTracker
# from app.services.face_recognition_service import FaceRecognitionService

# logger = logging.getLogger(__name__)

# # ─── Tuning constants ─────────────────────────────────────────────────────────
# MIN_PERSON_CONF   = 0.65
# MIN_KP_CONF       = 0.60
# MIN_KP_INSIDE     = 7
# MIN_UPPER_BODY    = 2
# UPPER_BODY_KP_IDX = {5, 6, 7, 8, 9, 10}

# # ─── Geometry helpers ─────────────────────────────────────────────────────────

# def point_in_polygon(
#     point: Tuple[float, float],
#     polygon: List[Dict],
# ) -> bool:
#     x, y   = point
#     n      = len(polygon)
#     inside = False
#     j      = n - 1
#     for i in range(n):
#         xi, yi = polygon[i]["x"], polygon[i]["y"]
#         xj, yj = polygon[j]["x"], polygon[j]["y"]
#         if ((yi > y) != (yj > y)) and (
#             x < (xj - xi) * (y - yi) / (yj - yi) + xi
#         ):
#             inside = not inside
#         j = i
#     return inside


# def person_in_polygon(
#     keypoints: np.ndarray,
#     polygon: List[Dict],
#     frame_w: int,
#     frame_h: int,
#     min_points_inside: int = MIN_KP_INSIDE,
#     min_confidence: float = MIN_KP_CONF,
# ) -> Tuple[bool, int, List[Tuple[int, int]]]:
#     """
#     Fence-camera only.
#     Returns (is_intruder, total_kp_inside, inside_pixel_coords).
#     Requires MIN_UPPER_BODY upper-body keypoints inside the polygon
#     to reject false positives (bags, chairs, etc.).
#     """
#     if keypoints is None or len(keypoints) == 0:
#         return False, 0, []

#     points_inside     = 0
#     inside_coords     = []
#     upper_body_inside = 0

#     for idx, kp in enumerate(keypoints):
#         x, y, conf = float(kp[0]), float(kp[1]), float(kp[2])
#         if conf < min_confidence:
#             continue
#         nx = max(0.0, min(1.0, x / frame_w))
#         ny = max(0.0, min(1.0, y / frame_h))
#         if point_in_polygon((nx, ny), polygon):
#             points_inside += 1
#             inside_coords.append((int(x), int(y)))
#             if idx in UPPER_BODY_KP_IDX:
#                 upper_body_inside += 1

#     is_inside = (
#         points_inside     >= min_points_inside and
#         upper_body_inside >= MIN_UPPER_BODY
#     )
#     return is_inside, points_inside, inside_coords


# def find_detected_cell(
#     keypoints: np.ndarray,
#     cells: List[Dict],
#     frame_w: int,
#     frame_h: int,
#     min_confidence: float = 0.3,
# ) -> Optional[str]:
#     if not cells or keypoints is None or len(keypoints) == 0:
#         return None

#     best_cell_name = None
#     best_count     = 0

#     for cell in cells:
#         polygon = cell.get("polygon_points", [])
#         if not polygon:
#             continue
#         count = 0
#         for kp in keypoints:
#             x, y, conf = float(kp[0]), float(kp[1]), float(kp[2])
#             if conf < min_confidence:
#                 continue
#             nx = max(0.0, min(1.0, x / frame_w))
#             ny = max(0.0, min(1.0, y / frame_h))
#             if point_in_polygon((nx, ny), polygon):
#                 count += 1
#         if count > best_count:
#             best_count     = count
#             best_cell_name = cell.get("cell_name")

#     return best_cell_name if best_count > 0 else None


# def denormalize_polygon(
#     polygon: List[Dict],
#     frame_w: int,
#     frame_h: int,
# ) -> List[Tuple[int, int]]:
#     return [
#         (int(p["x"] * frame_w), int(p["y"] * frame_h))
#         for p in polygon
#     ]


# # ─── Drawing helpers ──────────────────────────────────────────────────────────

# def draw_polygon_overlay(
#     frame: np.ndarray,
#     polygon: List[Dict],
#     is_alert: bool = False,
# ) -> np.ndarray:
#     h, w  = frame.shape[:2]
#     pts   = np.array(denormalize_polygon(polygon, w, h), dtype=np.int32)
#     color = (0, 0, 255) if is_alert else (0, 255, 255)
#     overlay = frame.copy()
#     cv2.fillPoly(overlay, [pts], color)
#     cv2.addWeighted(overlay, 0.25, frame, 0.75, 0, frame)
#     cv2.polylines(frame, [pts], True, color, 3)
#     if is_alert:
#         cv2.rectangle(frame, (0, 0), (w, 60), (0, 0, 200), -1)
#         cv2.putText(
#             frame, "WALL CLIMBING ALERT", (10, 42),
#             cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3,
#         )
#     return frame


# def draw_person_annotations(
#     frame, box, keypoints, is_intruder, inside_coords, points_inside,
# ):
#     color  = (0, 0, 255) if is_intruder else (0, 255, 0)
#     x1, y1, x2, y2 = map(int, box[:4])
#     cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
#     label = f"INTRUDER ({points_inside}pts)" if is_intruder else "Person"
#     cv2.putText(
#         frame, label, (x1 + 2, y1 - 8),
#         cv2.FONT_HERSHEY_SIMPLEX, 0.65, color, 2,
#     )
#     for kp in keypoints:
#         kx, ky, kconf = int(kp[0]), int(kp[1]), float(kp[2])
#         if kconf > MIN_KP_CONF:
#             dot_color = (0, 255, 255) if is_intruder else (0, 200, 0)
#             cv2.circle(frame, (kx, ky), 5, dot_color, -1)
#     for coord in inside_coords:
#         cv2.circle(frame, coord, 8, (0, 0, 255), -1)
#     return frame


# # ─── Main detector ────────────────────────────────────────────────────────────

# class WallClimbingDetector:

#     def __init__(self, model_path: str = "models/yolov8n-pose.pt"):
#         from ultralytics import YOLO
#         logger.info("Loading YOLOv8 pose model...")
#         self.model = YOLO(model_path)
#         self.track_last_alert: Dict[str, float] = {}
#         logger.info("✅ YOLOv8 pose model loaded")

#     def _load_cells_for_camera(self, camera_id: int) -> List[Dict]:
#         try:
#             from app.models.fence_cell import FenceCell
#             db = SessionLocal()
#             try:
#                 cells = (
#                     db.query(FenceCell)
#                     .filter(FenceCell.camera_id == camera_id)
#                     .order_by(FenceCell.row, FenceCell.col)
#                     .all()
#                 )
#                 return [
#                     {
#                         "cell_name":     c.cell_name,
#                         "polygon_points": c.polygon_points,
#                     }
#                     for c in cells
#                 ]
#             finally:
#                 db.close()
#         except Exception as e:
#             logger.warning(f"[Camera {camera_id}] Could not load cells: {e}")
#             return []

#     def _analyze_frame(
#         self,
#         frame: np.ndarray,
#         polygon: List[Dict],
#         camera_id: int,
#         cells: List[Dict],
#         is_insider: bool = False,
#     ) -> Tuple[bool, np.ndarray, int, List[Tuple], List, Optional[str]]:
#         h, w      = frame.shape[:2]
#         annotated = frame.copy()

#         # Draw fence polygon outline (fence cameras only)
#         if not is_insider and polygon:
#             annotated = draw_polygon_overlay(annotated, polygon, is_alert=False)

#         try:
#             results = self.model.predict(
#                 frame,
#                 verbose=False,
#                 conf=MIN_PERSON_CONF,
#             )
#         except Exception as e:
#             logger.error(f"[Camera {camera_id}] YOLO inference error: {e}")
#             return False, annotated, 0, [], [], None

#         result = results[0]
#         if (
#             result.keypoints is None
#             or result.boxes is None
#             or len(result.boxes) == 0
#         ):
#             return False, annotated, 0, [], [], None

#         boxes         = result.boxes.xyxy.cpu().numpy()
#         box_confs     = result.boxes.conf.cpu().numpy()
#         keypoints_all = result.keypoints.data.cpu().numpy()
#         track_ids     = list(range(len(boxes)))

#         intruder_detected  = False
#         max_confidence     = 0
#         intruder_bboxes    = []
#         intruder_track_ids = []
#         detected_cell_name = None

#         for box, box_conf, keypoints, track_id in zip(
#             boxes, box_confs, keypoints_all, track_ids
#         ):
#             if box_conf < MIN_PERSON_CONF:
#                 continue

#             if is_insider:
#                 # ── Insider camera ───────────────────────────────────────────
#                 # Any person in frame is a candidate — no polygon boundary.
#                 # Wall climbing logic does NOT apply here.
#                 is_intruder   = True
#                 points_inside = sum(
#                     1 for kp in keypoints if float(kp[2]) > MIN_KP_CONF
#                 )
#                 inside_coords = [
#                     (int(kp[0]), int(kp[1]))
#                     for kp in keypoints
#                     if float(kp[2]) > MIN_KP_CONF
#                 ]
#             else:
#                 # ── Fence camera ─────────────────────────────────────────────
#                 # Wall climbing: person must be inside the polygon AND pass
#                 # the upper-body keypoint guard to reject false positives.
#                 is_intruder, points_inside, inside_coords = person_in_polygon(
#                     keypoints=keypoints,
#                     polygon=polygon,
#                     frame_w=w,
#                     frame_h=h,
#                 )

#             if is_intruder:
#                 intruder_detected = True
#                 intruder_bboxes.append(tuple(map(int, box[:4])))
#                 intruder_track_ids.append(track_id)
#                 max_confidence = max(max_confidence, int(box_conf * 100))

#                 # Which cell/zone is the person in?
#                 cell = find_detected_cell(keypoints, cells, w, h)
#                 if cell:
#                     detected_cell_name = cell

#             annotated = draw_person_annotations(
#                 annotated, box, keypoints,
#                 is_intruder, inside_coords, points_inside,
#             )

#         # Draw alert overlays
#         if intruder_detected:
#             if is_insider:
#                 # Purple banner for insider zone alert
#                 cv2.rectangle(annotated, (0, 0), (w, 60), (128, 0, 128), -1)
#                 cv2.putText(
#                     annotated, "INSIDER ZONE ALERT", (10, 42),
#                     cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3,
#                 )
#             else:
#                 # Red polygon overlay for wall climbing alert
#                 annotated = draw_polygon_overlay(annotated, polygon, is_alert=True)

#             if detected_cell_name:
#                 label = "Zone" if is_insider else "Cell"
#                 cv2.putText(
#                     annotated,
#                     f"{label}: {detected_cell_name}",
#                     (10, 90),
#                     cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 255), 2,
#                 )

#         return (
#             intruder_detected, annotated, max_confidence,
#             intruder_bboxes, intruder_track_ids, detected_cell_name,
#         )

#     def _try_get_face_encoding(self, frame, person_bbox):
#         try:
#             import mediapipe as mp
#             x1, y1, x2, y2 = person_bbox
#             person_crop = frame[y1:y2, x1:x2]
#             if person_crop.size == 0:
#                 return None
#             with mp.solutions.face_detection.FaceDetection(
#                 model_selection=0, min_detection_confidence=0.5
#             ) as fd:
#                 rgb = cv2.cvtColor(person_crop, cv2.COLOR_BGR2RGB)
#                 res = fd.process(rgb)
#                 if not res.detections:
#                     return None
#                 det  = res.detections[0]
#                 bbox = det.location_data.relative_bounding_box
#                 ph, pw = person_crop.shape[:2]
#                 fx1 = max(0, int(bbox.xmin * pw))
#                 fy1 = max(0, int(bbox.ymin * ph))
#                 fx2 = min(pw, int((bbox.xmin + bbox.width)  * pw))
#                 fy2 = min(ph, int((bbox.ymin + bbox.height) * ph))
#                 face_crop = person_crop[fy1:fy2, fx1:fx2]
#                 if face_crop.size == 0:
#                     return None
#                 return FaceRecognitionService.compute_encoding(face_crop)
#         except Exception as e:
#             logger.debug(f"Face encoding failed: {e}")
#             return None

#     def process_camera(
#         self,
#         camera_id: int,
#         camera_name: str,
#         rtsp_url: str,
#         polygon: List[Dict],          # empty [] for insider cameras
#         property_id: int,
#         camera_cell_row: int = 0,
#         camera_cell_col: int = 0,
#         stop_event=None,
#         save_snapshots: bool = True,
#         snapshot_dir: str = "static/snapshots",
#     ):
#         os.makedirs(snapshot_dir, exist_ok=True)

#         # Insider cameras have no polygon — that is valid and expected.
#         # Fence cameras must have a polygon with at least 3 points.
#         is_insider = not polygon or len(polygon) < 3
#         if not is_insider and len(polygon) < 3:
#             logger.error(
#                 f"[Camera {camera_id}] Fence camera needs ≥3 polygon points"
#             )
#             return

#         cells             = self._load_cells_for_camera(camera_id)
#         cells_last_loaded = time.time()
#         CELLS_RELOAD_INTERVAL = 60  # reload cells every 60 s

#         logger.info(
#             f"[Camera {camera_id}] Starting "
#             f"{'INSIDER zone' if is_insider else 'FENCE wall-climbing'} detection | "
#             f"URL: {rtsp_url} | "
#             f"Polygon pts: {len(polygon)} | "
#             f"Cells: {[c['cell_name'] for c in cells] or 'none'} | "
#             f"Thresholds: person_conf={MIN_PERSON_CONF} "
#             f"kp_conf={MIN_KP_CONF} kp_inside={MIN_KP_INSIDE} "
#             f"upper_body={MIN_UPPER_BODY}"
#         )

#         reconnect_attempts = 0
#         max_reconnect      = 10

#         while True:
#             if stop_event and stop_event.is_set():
#                 break

#             cap = cv2.VideoCapture(rtsp_url)
#             cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

#             if not cap.isOpened():
#                 reconnect_attempts += 1
#                 logger.warning(
#                     f"[Camera {camera_id}] Cannot open stream. "
#                     f"Attempt {reconnect_attempts}/{max_reconnect}"
#                 )
#                 if reconnect_attempts >= max_reconnect:
#                     logger.error(
#                         f"[Camera {camera_id}] Max reconnects reached. Stopping."
#                     )
#                     break
#                 time.sleep(5)
#                 continue

#             reconnect_attempts = 0
#             frame_count        = 0
#             logger.info(f"[Camera {camera_id}] Stream connected ✅")

#             while True:
#                 if stop_event and stop_event.is_set():
#                     cap.release()
#                     return

#                 # Reload cells periodically so updates take effect without restart
#                 if time.time() - cells_last_loaded > CELLS_RELOAD_INTERVAL:
#                     cells             = self._load_cells_for_camera(camera_id)
#                     cells_last_loaded = time.time()
#                     logger.info(
#                         f"[Camera {camera_id}] Cells reloaded: "
#                         f"{[c['cell_name'] for c in cells] or 'none'}"
#                     )

#                 ret, frame = cap.read()
#                 if not ret or frame is None:
#                     logger.warning(
#                         f"[Camera {camera_id}] Frame read failed — reconnecting"
#                     )
#                     break

#                 frame_count += 1
#                 if frame_count % 3 != 0:
#                     continue

#                 (
#                     intruder_detected, annotated_frame, confidence,
#                     intruder_bboxes, intruder_track_ids, detected_cell_name,
#                 ) = self._analyze_frame(
#                     frame, polygon, camera_id, cells, is_insider
#                 )

#                 if not intruder_detected:
#                     continue

#                 # Per-track cooldown (60 s)
#                 track_id     = intruder_track_ids[0] if intruder_track_ids else None
#                 cooldown_key = f"{camera_id}_{track_id}"
#                 if time.time() - self.track_last_alert.get(cooldown_key, 0) < 60:
#                     continue
#                 self.track_last_alert[cooldown_key] = time.time()

#                 face_encoding = None
#                 if intruder_bboxes:
#                     face_encoding = self._try_get_face_encoding(
#                         frame, intruder_bboxes[0]
#                     )

#                 db = SessionLocal()
#                 try:
#                     tracker = PersonTracker(db)
#                     should_alert, tracking_id = tracker.track_person(
#                         property_id=property_id,
#                         camera_id=camera_id,
#                         camera_type="insider" if is_insider else "fence",
#                         face_encoding=face_encoding,
#                         local_tracker_id=(
#                             str(track_id) if track_id is not None else None
#                         ),
#                     )

#                     if not should_alert and face_encoding is not None:
#                         logger.debug(
#                             f"[Camera {camera_id}] Cooldown for {tracking_id}"
#                         )
#                         continue

#                     # Alert type differs by camera type
#                     if is_insider:
#                         alert_type = (
#                             f"Insider Zone Detection"
#                             + (
#                                 f" — {detected_cell_name}"
#                                 if detected_cell_name
#                                 else ""
#                             )
#                         )
#                     else:
#                         alert_type = (
#                             f"Wall Climbing Detected"
#                             + (
#                                 f" in Cell {detected_cell_name}"
#                                 if detected_cell_name
#                                 else ""
#                             )
#                         )

#                     alert = Alert(
#                         property_id=property_id,
#                         camera_id=camera_id,
#                         alert_type=alert_type,
#                         camera_name=camera_name,
#                         severity="critical",
#                         confidence=confidence,
#                         camera_cell_row=camera_cell_row,
#                         camera_cell_col=camera_cell_col,
#                         detected_cell=detected_cell_name,
#                         image_url=None,
#                         clip_url=None,
#                         is_read=False,
#                         status="active",
#                     )
#                     db.add(alert)
#                     db.flush()

#                     snapshot_url = None
#                     if save_snapshots:
#                         filename = f"alert_{alert.id}_snap.jpg"
#                         path     = os.path.join(snapshot_dir, filename)
#                         if cv2.imwrite(path, annotated_frame):
#                             snapshot_url = f"/static/snapshots/{filename}"

#                     alert.image_url = snapshot_url
#                     db.add(alert)

#                     prop = (
#                         db.query(Property)
#                         .filter(Property.id == property_id)
#                         .first()
#                     )
#                     if prop:
#                         active_count = (
#                             db.query(Alert)
#                             .filter(
#                                 Alert.property_id == property_id,
#                                 Alert.status == "active",
#                             )
#                             .count()
#                         )
#                         prop.active_alerts = active_count + 1

#                     db.commit()
#                     logger.info(
#                         f"✅ Alert id={alert.id} | camera={camera_id} | "
#                         f"type={'insider' if is_insider else 'fence'} | "
#                         f"conf={confidence}% | "
#                         f"cell={detected_cell_name or 'N/A'} | "
#                         f"tracking={tracking_id}"
#                     )

#                 except Exception as e:
#                     try:
#                         db.rollback()
#                     except Exception:
#                         pass
#                     logger.error(
#                         f"[Camera {camera_id}] Alert save failed: {e}"
#                     )
#                 finally:
#                     db.close()

#             cap.release()
#             logger.info(f"[Camera {camera_id}] Stream lost — waiting 3s")
#             time.sleep(3)

#         logger.info(f"[Camera {camera_id}] Detection loop exited")

# app/services/wall_climbing.py

import cv2
import numpy as np
import time
import logging
import os
from typing import List, Dict, Optional, Tuple, Set
from scipy.spatial.distance import cdist  # pip install scipy

from app.core.database import SessionLocal
from app.models.alert import Alert
from app.models.property import Property
from app.services.person_tracker import PersonTracker
from app.services.face_recognition_service import FaceRecognitionService

logger = logging.getLogger(__name__)

# ─── Detection thresholds ─────────────────────────────────────────────────────
MIN_PERSON_CONF   = 0.90
MIN_KP_CONF       = 0.60
MIN_KP_INSIDE     = 7
MIN_UPPER_BODY    = 2
UPPER_BODY_KP_IDX = {5, 6, 7, 8, 9, 10}

# ─── Our own tracker settings ─────────────────────────────────────────────────

# How similar two bounding boxes must be to be the "same person"
# IoU = Intersection over Union. 1.0 = perfect overlap, 0.0 = no overlap
# 0.3 means boxes must overlap at least 30% to match
IOU_THRESHOLD = 0.3

# If a person disappears for this many processed frames → forget them
# At FRAME_SKIP=3 on 30fps: 10 frames = ~1 second
MAX_DISAPPEARED_FRAMES = 10

# Must be detected as intruder for this many frames before alerting
# Prevents single-frame false positives
CONFIRM_FRAMES_REQUIRED = 3

# Once alerted → never alert again for same person this session
PERMANENT_TRACK_MEMORY = True

FRAME_SKIP            = 3
CELLS_RELOAD_INTERVAL = 60


# ─── IoU helper ───────────────────────────────────────────────────────────────

def compute_iou(boxA: Tuple, boxB: Tuple) -> float:
    """
    Intersection over Union between two boxes.
    Box format: (x1, y1, x2, y2)

    IoU = area of overlap / area of union

    Example:
        boxA = (100, 100, 200, 200)  → 100x100 box
        boxB = (150, 150, 250, 250)  → 100x100 box overlapping by 50x50
        IoU  = 2500 / (10000 + 10000 - 2500) = 0.143
    """
    xA = max(boxA[0], boxB[0])
    yA = max(boxA[1], boxB[1])
    xB = min(boxA[2], boxB[2])
    yB = min(boxA[3], boxB[3])

    interW = max(0, xB - xA)
    interH = max(0, yB - yA)
    interArea = interW * interH

    if interArea == 0:
        return 0.0

    areaA = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1])
    areaB = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1])

    return interArea / float(areaA + areaB - interArea)


# ─── Our Custom Tracker ───────────────────────────────────────────────────────

class SimplePersonTracker:
    """
    Our own IoU-based tracker — does NOT depend on YOLO's .track().

    How it works:
    ─────────────
    Each frame gives us a list of bounding boxes from YOLO .predict()
    (not .track — we don't need YOLO's tracker anymore).

    We match new boxes to existing tracks using IoU (box overlap).
    Same person → boxes overlap heavily → same track ID kept.
    New person  → no overlap with any existing track → new track ID.
    Person left → no new box matches their track → disappeared counter++
                  After MAX_DISAPPEARED_FRAMES → track deleted.

    This is MORE STABLE than YOLO's built-in tracker because:
    1. Works correctly with frame skipping
    2. Never loses a track due to YOLO's internal state reset
    3. We control exactly when a track is "lost"
    4. No dependency on YOLO's ByteTrack/BoT-SORT internals

    Track data structure:
    {
        track_id:     int,          unique incrementing ID
        box:          (x1,y1,x2,y2),  last seen bounding box
        disappeared:  int,          frames since last seen
        first_seen:   float,        unix timestamp
        last_seen:    float,        unix timestamp
    }
    """

    def __init__(self):
        self.next_id     = 1
        self.tracks: Dict[int, Dict] = {}
        # track_id → track data

    def update(
        self,
        detections: List[Tuple],  # list of (x1, y1, x2, y2) boxes
    ) -> Dict[int, Tuple]:
        """
        Match new detections to existing tracks.

        Returns:
            Dict mapping track_id → (x1, y1, x2, y2) for ALL active tracks.
            Only currently detected people appear (disappeared ones are excluded
            from return value but kept internally until MAX_DISAPPEARED_FRAMES).
        """
        now = time.time()

        # ── No detections this frame ──────────────────────────────────────────
        if len(detections) == 0:
            # Increment disappeared counter for all tracks
            to_delete = []
            for tid in self.tracks:
                self.tracks[tid]["disappeared"] += 1
                if self.tracks[tid]["disappeared"] > MAX_DISAPPEARED_FRAMES:
                    to_delete.append(tid)
            for tid in to_delete:
                del self.tracks[tid]
            return {}

        # ── No existing tracks → register all detections as new ──────────────
        if len(self.tracks) == 0:
            result = {}
            for box in detections:
                tid = self._register(box, now)
                result[tid] = box
            return result

        # ── Match detections to existing tracks using IoU ─────────────────────
        track_ids  = list(self.tracks.keys())
        track_boxes = [self.tracks[tid]["box"] for tid in track_ids]

        # Build IoU matrix: rows=existing tracks, cols=new detections
        # iou_matrix[i][j] = IoU between track i and detection j
        iou_matrix = np.zeros((len(track_boxes), len(detections)))
        for i, tbox in enumerate(track_boxes):
            for j, dbox in enumerate(detections):
                iou_matrix[i][j] = compute_iou(tbox, dbox)

        # Greedy matching: repeatedly take highest IoU pair
        # until no pair exceeds IOU_THRESHOLD
        matched_tracks     = set()
        matched_detections = set()
        result             = {}

        # Flatten and sort by IoU descending
        pairs = []
        for i in range(len(track_boxes)):
            for j in range(len(detections)):
                pairs.append((iou_matrix[i][j], i, j))
        pairs.sort(key=lambda x: x[0], reverse=True)

        for iou_val, i, j in pairs:
            if iou_val < IOU_THRESHOLD:
                break  # sorted descending, so all remaining are below threshold
            if i in matched_tracks or j in matched_detections:
                continue  # already matched

            # Match found: update track with new box position
            tid = track_ids[i]
            self.tracks[tid]["box"]         = detections[j]
            self.tracks[tid]["disappeared"] = 0
            self.tracks[tid]["last_seen"]   = now
            matched_tracks.add(i)
            matched_detections.add(j)
            result[tid] = detections[j]

        # Unmatched existing tracks → increment disappeared
        to_delete = []
        for i, tid in enumerate(track_ids):
            if i not in matched_tracks:
                self.tracks[tid]["disappeared"] += 1
                if self.tracks[tid]["disappeared"] > MAX_DISAPPEARED_FRAMES:
                    to_delete.append(tid)
        for tid in to_delete:
            del self.tracks[tid]
            logger.debug(f"Track {tid} deleted (disappeared)")

        # Unmatched new detections → register as new tracks
        for j, box in enumerate(detections):
            if j not in matched_detections:
                tid = self._register(box, now)
                result[tid] = box

        return result

    def _register(self, box: Tuple, now: float) -> int:
        tid = self.next_id
        self.next_id += 1
        self.tracks[tid] = {
            "box":         box,
            "disappeared": 0,
            "first_seen":  now,
            "last_seen":   now,
        }
        logger.debug(f"New track registered: ID={tid} box={box}")
        return tid

    def get_active_track_ids(self) -> Set[int]:
        return set(self.tracks.keys())


# ─── Geometry helpers ─────────────────────────────────────────────────────────

def point_in_polygon(point: Tuple[float, float], polygon: List[Dict]) -> bool:
    x, y   = point
    n      = len(polygon)
    inside = False
    j      = n - 1
    for i in range(n):
        xi, yi = polygon[i]["x"], polygon[i]["y"]
        xj, yj = polygon[j]["x"], polygon[j]["y"]
        if ((yi > y) != (yj > y)) and (
            x < (xj - xi) * (y - yi) / (yj - yi) + xi
        ):
            inside = not inside
        j = i
    return inside


def person_in_polygon(
    keypoints: np.ndarray,
    polygon: List[Dict],
    frame_w: int,
    frame_h: int,
    min_points_inside: int = MIN_KP_INSIDE,
    min_confidence: float  = MIN_KP_CONF,
) -> Tuple[bool, int, List[Tuple[int, int]]]:
    if keypoints is None or len(keypoints) == 0:
        return False, 0, []

    points_inside     = 0
    inside_coords     = []
    upper_body_inside = 0

    for idx, kp in enumerate(keypoints):
        x, y, conf = float(kp[0]), float(kp[1]), float(kp[2])
        if conf < min_confidence:
            continue
        nx = max(0.0, min(1.0, x / frame_w))
        ny = max(0.0, min(1.0, y / frame_h))
        if point_in_polygon((nx, ny), polygon):
            points_inside += 1
            inside_coords.append((int(x), int(y)))
            if idx in UPPER_BODY_KP_IDX:
                upper_body_inside += 1

    is_inside = (
        points_inside     >= min_points_inside and
        upper_body_inside >= MIN_UPPER_BODY
    )
    return is_inside, points_inside, inside_coords


def find_detected_cell(
    keypoints: np.ndarray,
    cells: List[Dict],
    frame_w: int,
    frame_h: int,
    min_confidence: float = 0.3,
) -> Optional[str]:
    if not cells or keypoints is None or len(keypoints) == 0:
        return None
    best_cell_name = None
    best_count     = 0
    for cell in cells:
        polygon = cell.get("polygon_points", [])
        if not polygon:
            continue
        count = 0
        for kp in keypoints:
            x, y, conf = float(kp[0]), float(kp[1]), float(kp[2])
            if conf < min_confidence:
                continue
            nx = max(0.0, min(1.0, x / frame_w))
            ny = max(0.0, min(1.0, y / frame_h))
            if point_in_polygon((nx, ny), polygon):
                count += 1
        if count > best_count:
            best_count     = count
            best_cell_name = cell.get("cell_name")
    return best_cell_name if best_count > 0 else None


def denormalize_polygon(
    polygon: List[Dict], frame_w: int, frame_h: int,
) -> List[Tuple[int, int]]:
    return [
        (int(p["x"] * frame_w), int(p["y"] * frame_h))
        for p in polygon
    ]


# ─── Drawing helpers ──────────────────────────────────────────────────────────

def draw_polygon_overlay(
    frame: np.ndarray,
    polygon: List[Dict],
    is_alert: bool = False,
) -> np.ndarray:
    h, w  = frame.shape[:2]
    pts   = np.array(denormalize_polygon(polygon, w, h), dtype=np.int32)
    color = (0, 0, 255) if is_alert else (0, 255, 255)
    overlay = frame.copy()
    cv2.fillPoly(overlay, [pts], color)
    cv2.addWeighted(overlay, 0.25, frame, 0.75, 0, frame)
    cv2.polylines(frame, [pts], True, color, 3)
    if is_alert:
        cv2.rectangle(frame, (0, 0), (w, 60), (0, 0, 200), -1)
        cv2.putText(
            frame, "WALL CLIMBING ALERT", (10, 42),
            cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3,
        )
    return frame


def draw_person_annotations(
    frame, box, keypoints, is_intruder,
    inside_coords, points_inside,
    track_id=None, already_alerted=False,
):
    if already_alerted:
        color = (128, 128, 128)
        label = f"DONE [ID:{track_id}]"
    elif is_intruder:
        color = (0, 0, 255)
        label = f"INTRUDER [ID:{track_id}] ({points_inside}pts)"
    else:
        color = (0, 255, 0)
        label = f"Person [ID:{track_id}]"

    x1, y1, x2, y2 = map(int, box[:4])
    cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
    cv2.putText(
        frame, label, (x1 + 2, y1 - 8),
        cv2.FONT_HERSHEY_SIMPLEX, 0.55, color, 2,
    )
    for kp in keypoints:
        kx, ky, kconf = int(kp[0]), int(kp[1]), float(kp[2])
        if kconf > MIN_KP_CONF:
            dot_color = (128, 128, 128) if already_alerted else (
                (0, 255, 255) if is_intruder else (0, 200, 0)
            )
            cv2.circle(frame, (kx, ky), 5, dot_color, -1)
    if not already_alerted:
        for coord in inside_coords:
            cv2.circle(frame, coord, 8, (0, 0, 255), -1)
    return frame


# ─── Main Detector ────────────────────────────────────────────────────────────

class WallClimbingDetector:
    """
    Uses YOLO .predict() (NOT .track) for detection.
    Uses our own SimplePersonTracker for stable IDs.
    Uses alerted_track_ids set for "see once, alert once".
    """

    def __init__(self, model_path: str = "models/yolov8n-pose.pt"):
        from ultralytics import YOLO
        logger.info("Loading YOLOv8 pose model…")
        self.model = YOLO(model_path)

        # One SimplePersonTracker per camera
        # camera_id → SimplePersonTracker
        self.trackers: Dict[int, SimplePersonTracker] = {}

        # camera_id → Set[track_id] permanently alerted
        self.alerted_track_ids: Dict[int, Set[int]] = {}

        # camera_id → Dict[track_id → consecutive intruder frame count]
        self.pending_confirm: Dict[int, Dict[int, int]] = {}

        logger.info("✅ YOLOv8 pose model loaded")

    def _init_camera(self, camera_id: int):
        if camera_id not in self.trackers:
            self.trackers[camera_id]         = SimplePersonTracker()
            self.alerted_track_ids[camera_id] = set()
            self.pending_confirm[camera_id]   = {}

    def _load_cells_for_camera(self, camera_id: int) -> List[Dict]:
        try:
            from app.models.fence_cell import FenceCell
            db = SessionLocal()
            try:
                cells = (
                    db.query(FenceCell)
                    .filter(FenceCell.camera_id == camera_id)
                    .order_by(FenceCell.row, FenceCell.col)
                    .all()
                )
                return [
                    {
                        "cell_name":      c.cell_name,
                        "polygon_points": c.polygon_points,
                    }
                    for c in cells
                ]
            finally:
                db.close()
        except Exception as e:
            logger.warning(f"[Camera {camera_id}] Could not load cells: {e}")
            return []

    def _analyze_frame(
        self,
        frame: np.ndarray,
        polygon: List[Dict],
        camera_id: int,
        cells: List[Dict],
        is_insider: bool = False,
    ) -> Tuple[bool, np.ndarray, List[Dict]]:
        """
        1. Run YOLO .predict() — pure detection, no tracking
        2. Feed boxes to our SimplePersonTracker → stable IDs
        3. For each tracked person check polygon / insider zone
        4. Return intruder list with our stable track IDs
        """
        h, w      = frame.shape[:2]
        annotated = frame.copy()

        if not is_insider and polygon:
            annotated = draw_polygon_overlay(annotated, polygon, is_alert=False)

        # ── YOLO predict (NOT track) ──────────────────────────────────────────
        try:
            results = self.model.predict(
                frame,
                verbose=False,
                conf=MIN_PERSON_CONF,
            )
        except Exception as e:
            logger.error(f"[Camera {camera_id}] YOLO error: {e}")
            return False, annotated, []

        result = results[0]

        if (
            result.keypoints is None
            or result.boxes is None
            or len(result.boxes) == 0
        ):
            # No detections — update tracker with empty list so
            # disappeared counters increment correctly
            self.trackers[camera_id].update([])
            return False, annotated, []

        boxes         = result.boxes.xyxy.cpu().numpy()
        box_confs     = result.boxes.conf.cpu().numpy()
        keypoints_all = result.keypoints.data.cpu().numpy()

        # ── Feed boxes to OUR tracker → get stable IDs ───────────────────────
        detection_boxes = [
            tuple(map(int, box[:4]))
            for box, conf in zip(boxes, box_confs)
            if conf >= MIN_PERSON_CONF
        ]
        # track_map: our_track_id → box
        track_map = self.trackers[camera_id].update(detection_boxes)

        # Reverse map: box → our_track_id
        # We match by box position since YOLO gives us boxes in same order
        box_to_trackid: Dict[Tuple, int] = {
            box: tid for tid, box in track_map.items()
        }

        alerted_set  = self.alerted_track_ids[camera_id]
        intruder_list = []
        any_intruder  = False
        alert_active  = False

        for box, box_conf, keypoints in zip(boxes, box_confs, keypoints_all):
            if box_conf < MIN_PERSON_CONF:
                continue

            box_tuple = tuple(map(int, box[:4]))

            # Find our stable track ID for this box
            # Match to closest box in track_map if exact match not found
            track_id = box_to_trackid.get(box_tuple)
            if track_id is None:
                # Find closest matching box by IoU
                best_iou = 0
                for tid, tbox in track_map.items():
                    iou = compute_iou(box_tuple, tbox)
                    if iou > best_iou:
                        best_iou = iou
                        track_id = tid

            # ── Intruder check ────────────────────────────────────────────────
            if is_insider:
                is_intruder   = True
                points_inside = sum(
                    1 for kp in keypoints if float(kp[2]) > MIN_KP_CONF
                )
                inside_coords = [
                    (int(kp[0]), int(kp[1]))
                    for kp in keypoints
                    if float(kp[2]) > MIN_KP_CONF
                ]
            else:
                is_intruder, points_inside, inside_coords = person_in_polygon(
                    keypoints=keypoints,
                    polygon=polygon,
                    frame_w=w,
                    frame_h=h,
                )

            already_alerted = (track_id in alerted_set) if track_id else False

            if is_intruder:
                any_intruder = True
                if not already_alerted:
                    alert_active = True
                cell = find_detected_cell(keypoints, cells, w, h)
                intruder_list.append({
                    "track_id":        track_id,
                    "box":             box_tuple,
                    "confidence":      int(box_conf * 100),
                    "keypoints":       keypoints,
                    "cell":            cell,
                    "pts_inside":      points_inside,
                    "inside_coords":   inside_coords,
                    "already_alerted": already_alerted,
                })

            annotated = draw_person_annotations(
                annotated, box, keypoints,
                is_intruder, inside_coords, points_inside,
                track_id=track_id,
                already_alerted=already_alerted,
            )

        if alert_active:
            if is_insider:
                cv2.rectangle(annotated, (0, 0), (w, 60), (128, 0, 128), -1)
                cv2.putText(
                    annotated, "INSIDER ZONE ALERT", (10, 42),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3,
                )
            elif polygon:
                annotated = draw_polygon_overlay(annotated, polygon, is_alert=True)

        return any_intruder, annotated, intruder_list

    def _try_get_face_encoding(self, frame, person_bbox):
        try:
            import mediapipe as mp
            x1, y1, x2, y2 = person_bbox
            person_crop = frame[y1:y2, x1:x2]
            if person_crop.size == 0:
                return None
            with mp.solutions.face_detection.FaceDetection(
                model_selection=0, min_detection_confidence=0.5
            ) as fd:
                rgb = cv2.cvtColor(person_crop, cv2.COLOR_BGR2RGB)
                res = fd.process(rgb)
                if not res.detections:
                    return None
                det  = res.detections[0]
                bbox = det.location_data.relative_bounding_box
                ph, pw = person_crop.shape[:2]
                fx1 = max(0, int(bbox.xmin * pw))
                fy1 = max(0, int(bbox.ymin * ph))
                fx2 = min(pw, int((bbox.xmin + bbox.width)  * pw))
                fy2 = min(ph, int((bbox.ymin + bbox.height) * ph))
                face_crop = person_crop[fy1:fy2, fx1:fx2]
                if face_crop.size == 0:
                    return None
                return FaceRecognitionService.compute_encoding(face_crop)
        except Exception as e:
            logger.debug(f"Face encoding failed: {e}")
            return None

    def process_camera(
        self,
        camera_id: int,
        camera_name: str,
        rtsp_url: str,
        polygon: List[Dict],
        property_id: int,
        camera_cell_row: int = 0,
        camera_cell_col: int = 0,
        stop_event=None,
        save_snapshots: bool = True,
        snapshot_dir: str = "static/snapshots",
    ):
        os.makedirs(snapshot_dir, exist_ok=True)
        self._init_camera(camera_id)

        is_insider = not polygon or len(polygon) < 3

        cells             = self._load_cells_for_camera(camera_id)
        cells_last_loaded = time.time()

        logger.info(
            f"[Camera {camera_id}] Starting | "
            f"Mode={'INSIDER' if is_insider else 'FENCE'} | "
            f"OWN TRACKER (IoU-based) | "
            f"confirm={CONFIRM_FRAMES_REQUIRED} frames | "
            f"see-once={PERMANENT_TRACK_MEMORY}"
        )

        reconnect_attempts = 0

        while True:
            if stop_event and stop_event.is_set():
                break

            cap = cv2.VideoCapture(rtsp_url)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

            if not cap.isOpened():
                reconnect_attempts += 1
                if reconnect_attempts >= 10:
                    logger.error(f"[Camera {camera_id}] Max reconnects — stopping")
                    break
                time.sleep(5)
                continue

            reconnect_attempts = 0
            frame_count        = 0
            logger.info(f"[Camera {camera_id}] Stream connected ✅")

            while True:
                if stop_event and stop_event.is_set():
                    cap.release()
                    return

                if time.time() - cells_last_loaded > CELLS_RELOAD_INTERVAL:
                    cells             = self._load_cells_for_camera(camera_id)
                    cells_last_loaded = time.time()

                ret, frame = cap.read()
                if not ret or frame is None:
                    break

                frame_count += 1
                if frame_count % FRAME_SKIP != 0:
                    continue

                # ── Detect + our tracking ─────────────────────────────────────
                any_intruder, annotated_frame, intruder_list = self._analyze_frame(
                    frame, polygon, camera_id, cells, is_insider
                )

                if not any_intruder or not intruder_list:
                    continue

                # ── Per intruder: see-once gate ───────────────────────────────
                for intruder in intruder_list:

                    if intruder["already_alerted"]:
                        continue

                    track_id    = intruder["track_id"]
                    alerted_set = self.alerted_track_ids[camera_id]
                    pending     = self.pending_confirm[camera_id]

                    if track_id is not None:
                        # Increment confirmation counter
                        pending[track_id] = pending.get(track_id, 0) + 1

                        if pending[track_id] < CONFIRM_FRAMES_REQUIRED:
                            logger.debug(
                                f"[Camera {camera_id}] Track {track_id} "
                                f"confirming {pending[track_id]}/{CONFIRM_FRAMES_REQUIRED}"
                            )
                            continue

                        # Confirmed — mark permanently done
                        alerted_set.add(track_id)
                        pending.pop(track_id, None)

                    # ── Face encoding + DB gate ───────────────────────────────
                    face_encoding = self._try_get_face_encoding(
                        frame, intruder["box"]
                    )

                    db = SessionLocal()
                    try:
                        tracker    = PersonTracker(db)
                        should_alert, tracking_id = tracker.track_person(
                            property_id=property_id,
                            camera_id=camera_id,
                            camera_type="insider" if is_insider else "fence",
                            face_encoding=face_encoding,
                            local_tracker_id=(
                                str(track_id) if track_id is not None else None
                            ),
                        )

                        if not should_alert:
                            logger.info(
                                f"[Camera {camera_id}] DB gate blocked "
                                f"track={track_id}"
                            )
                            continue

                        # ── CREATE ALERT ──────────────────────────────────────
                        if is_insider:
                            alert_type = (
                                "Insider Zone Detection"
                                + (
                                    f" — {intruder['cell']}"
                                    if intruder["cell"] else ""
                                )
                            )
                        else:
                            alert_type = (
                                "Wall Climbing Detected"
                                + (
                                    f" in Cell {intruder['cell']}"
                                    if intruder["cell"] else ""
                                )
                            )

                        alert = Alert(
                            property_id=property_id,
                            camera_id=camera_id,
                            alert_type=alert_type,
                            camera_name=camera_name,
                            severity="critical",
                            confidence=intruder["confidence"],
                            camera_cell_row=camera_cell_row,
                            camera_cell_col=camera_cell_col,
                            detected_cell=intruder["cell"],
                            image_url=None,
                            clip_url=None,
                            is_read=False,
                            status="active",
                        )
                        db.add(alert)
                        db.flush()

                        snapshot_url = None
                        if save_snapshots:
                            fname = f"alert_{alert.id}_snap.jpg"
                            path  = os.path.join(snapshot_dir, fname)
                            if cv2.imwrite(path, annotated_frame):
                                snapshot_url = f"/static/snapshots/{fname}"
                        alert.image_url = snapshot_url

                        prop = (
                            db.query(Property)
                            .filter(Property.id == property_id)
                            .first()
                        )
                        if prop:
                            cnt = (
                                db.query(Alert)
                                .filter(
                                    Alert.property_id == property_id,
                                    Alert.status      == "active",
                                )
                                .count()
                            )
                            prop.active_alerts = cnt + 1

                        db.commit()
                        logger.info(
                            f"✅ ALERT id={alert.id} | cam={camera_id} | "
                            f"track={track_id} | conf={intruder['confidence']}%"
                        )

                        # ── WebSocket ─────────────────────────────────────────
                        try:
                            from app.core.websocket import websocket_manager
                            import asyncio
                            payload = {
                                "type":          "new_alert",
                                "alert_number":  alert.id,
                                "alert_type":    "insider_zone" if is_insider else "person_climbing",
                                "camera_name":   camera_name,
                                "camera_id":     camera_id,
                                "detected_cell": intruder["cell"],
                                "severity":      "critical",
                                "confidence":    intruder["confidence"],
                                "timestamp":     (
                                    alert.timestamp.isoformat()
                                    if alert.timestamp else None
                                ),
                                "image_url":     snapshot_url,
                                "status":        "active",
                                "is_read":       False,
                                "message":       (
                                    f"⚠️ INSIDER ZONE at {camera_name}"
                                    if is_insider
                                    else f"🧗 WALL CLIMBING at {camera_name}"
                                ),
                                "tracking_id":   tracking_id,
                                "property_id":   property_id,
                            }
                            loop = asyncio.get_event_loop()
                            if loop.is_running():
                                asyncio.run_coroutine_threadsafe(
                                    websocket_manager.broadcast_alert(payload),
                                    loop,
                                )
                        except Exception as ws_err:
                            logger.error(f"WS error: {ws_err}")

                    except Exception as e:
                        try:
                            db.rollback()
                        except Exception:
                            pass
                        if track_id is not None:
                            self.alerted_track_ids[camera_id].add(track_id)
                        logger.error(f"Alert save failed: {e}", exc_info=True)
                    finally:
                        db.close()

            cap.release()
            time.sleep(3)

        logger.info(f"[Camera {camera_id}] Detection loop exited")