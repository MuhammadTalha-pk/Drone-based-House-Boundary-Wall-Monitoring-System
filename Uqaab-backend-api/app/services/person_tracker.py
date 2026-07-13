"""
Central Person Tracking Service
================================
Handles unique person tracking across all cameras.
Applies 60-second cooldown PER PERSON (identified by face) to prevent alert spam.

IMPORTANT: Cooldown is PER-PERSON, not global.
           Different people → independent cooldowns.
           Same person → single cooldown.
"""
import uuid
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Tuple
from sqlalchemy.orm import Session
from sqlalchemy import and_

from app.models.person_tracking import PersonAlertTracking

logger = logging.getLogger(__name__)

# ⚙️ CONFIG
ALERT_COOLDOWN_SECONDS = 60          # No duplicate alerts within this window (per-person)
FACE_MATCH_THRESHOLD   = 0.45        # 🔒 STRICT: lower = more distinct identities
STALE_TRACKING_HOURS   = 24          # Cleanup old entries


def _utcnow() -> datetime:
    """Always return timezone-aware UTC datetime (matches DB TIMESTAMPTZ)."""
    return datetime.now(timezone.utc)


def _ensure_aware(dt: Optional[datetime]) -> Optional[datetime]:
    """Convert naive datetime to UTC-aware (for legacy DB rows)."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


class PersonTracker:
    """
    Manages unique person tracking with per-person 60-second alert cooldown.
    
    Usage:
        tracker = PersonTracker(db)
        should_alert, tracking_id = tracker.track_person(
            property_id=1,
            camera_id=5,
            camera_type="fence",
            face_encoding=encoding_or_none,
        )
        if should_alert:
            # Create alert
    """

    def __init__(self, db: Session):
        self.db = db

    # ─────────────────────────────────────────────────
    # MAIN ENTRY POINT
    # ─────────────────────────────────────────────────
    def track_person(
        self,
        property_id: int,
        camera_id: int,
        camera_type: str,
        face_encoding: Optional[List[float]] = None,
        local_tracker_id: Optional[str] = None,
    ) -> Tuple[bool, str]:
        """
        Track a detected person and decide whether to generate alert.
        
        Returns:
            (should_alert, tracking_id)
        """
        now = _utcnow()

        # 🔒 Step 1: Find existing tracking ONLY by face identity (strict)
        tracking = self._find_matching_person(
            property_id=property_id,
            face_encoding=face_encoding,
        )

        # ─── CASE A: NEW PERSON (never seen before) ─────────────────
        if not tracking:
            tracking_id = f"person_{uuid.uuid4().hex[:12]}"
            tracking = PersonAlertTracking(
                tracking_id=tracking_id,
                property_id=property_id,
                face_encoding=face_encoding,
                camera_ids_seen=[camera_id],
                camera_types_seen=[camera_type],
                last_camera_id=camera_id,
                last_camera_type=camera_type,
                last_alert_time=now,
                total_alerts_generated=1,
                total_detections=1,
                first_seen_at=now,
                last_seen_at=now,
            )
            self.db.add(tracking)
            self.db.commit()
            self.db.refresh(tracking)

            logger.info(
                f"🆕 NEW PERSON: {tracking_id} | "
                f"camera={camera_id} ({camera_type}) → ALERT"
            )
            return True, tracking_id

        # ─── CASE B: SAME PERSON seen before ────────────────────────
        tracking.total_detections += 1
        tracking.last_seen_at = now
        tracking.last_camera_id = camera_id
        tracking.last_camera_type = camera_type

        # Update camera lists
        if camera_id not in (tracking.camera_ids_seen or []):
            tracking.camera_ids_seen = (tracking.camera_ids_seen or []) + [camera_id]
        if camera_type not in (tracking.camera_types_seen or []):
            tracking.camera_types_seen = (tracking.camera_types_seen or []) + [camera_type]

        # ⏰ Check 60-second cooldown FOR THIS SPECIFIC PERSON
        last_alert = _ensure_aware(tracking.last_alert_time)
        if last_alert:
            elapsed = (now - last_alert).total_seconds()
            if elapsed < ALERT_COOLDOWN_SECONDS:
                self.db.commit()
                logger.info(
                    f"⏸️  COOLDOWN for {tracking.tracking_id}: "
                    f"elapsed={elapsed:.1f}s < {ALERT_COOLDOWN_SECONDS}s → NO ALERT"
                )
                return False, tracking.tracking_id

        # Cooldown expired → alert allowed for THIS person
        tracking.last_alert_time = now
        tracking.total_alerts_generated += 1

        # Optional: refresh stored encoding with latest (running average) to adapt
        if face_encoding and tracking.face_encoding:
            tracking.face_encoding = self._blend_encodings(
                tracking.face_encoding, face_encoding
            )

        self.db.commit()

        logger.info(
            f"🔁 SAME PERSON after cooldown: {tracking.tracking_id} | "
            f"alert_count={tracking.total_alerts_generated} → ALERT"
        )
        return True, tracking.tracking_id

    # ─────────────────────────────────────────────────
    # MATCHING LOGIC (face-only, strict)
    # ─────────────────────────────────────────────────
    def _find_matching_person(
        self,
        property_id: int,
        face_encoding: Optional[List[float]],
    ) -> Optional[PersonAlertTracking]:
        """
        Find existing tracking record by FACE IDENTITY ONLY.
        No fallback to "recent camera activity" — that caused cross-person matches.
        """
        if not face_encoding:
            # No encoding → we cannot identify uniquely → treat as new person
            # (will create a new tracking record)
            logger.debug("No face encoding provided → treating as new person")
            return None

        return self._match_by_face(property_id, face_encoding)

    def _match_by_face(
        self,
        property_id: int,
        face_encoding: List[float],
    ) -> Optional[PersonAlertTracking]:
        """Return the CLOSEST matching person if distance < threshold."""
        try:
            import numpy as np

            query_vec = np.array(face_encoding, dtype=float)
            if query_vec.size == 0:
                return None

            cutoff = _utcnow() - timedelta(hours=STALE_TRACKING_HOURS)

            candidates = (
                self.db.query(PersonAlertTracking)
                .filter(
                    and_(
                        PersonAlertTracking.property_id == property_id,
                        PersonAlertTracking.face_encoding.isnot(None),
                        PersonAlertTracking.last_seen_at >= cutoff,
                    )
                )
                .all()
            )

            best_match: Optional[PersonAlertTracking] = None
            best_distance = float("inf")

            for candidate in candidates:
                if not candidate.face_encoding:
                    continue

                candidate_vec = np.array(candidate.face_encoding, dtype=float)
                if candidate_vec.shape != query_vec.shape:
                    continue

                distance = float(np.linalg.norm(query_vec - candidate_vec))

                if distance < best_distance:
                    best_distance = distance
                    best_match = candidate

            if best_match and best_distance < FACE_MATCH_THRESHOLD:
                logger.debug(
                    f"✅ Matched face → {best_match.tracking_id} "
                    f"(distance={best_distance:.3f} < {FACE_MATCH_THRESHOLD})"
                )
                return best_match

            if best_match:
                logger.debug(
                    f"❌ Closest candidate {best_match.tracking_id} "
                    f"distance={best_distance:.3f} ≥ {FACE_MATCH_THRESHOLD} → NEW person"
                )
            else:
                logger.debug("❌ No candidates → NEW person")

            return None

        except Exception as e:
            logger.error(f"Face matching error: {e}", exc_info=True)
            return None

    # ─────────────────────────────────────────────────
    # HELPERS
    # ─────────────────────────────────────────────────
    @staticmethod
    def _blend_encodings(
        old: List[float],
        new: List[float],
        weight_new: float = 0.2,
    ) -> List[float]:
        """
        Running average blend so the stored encoding adapts slightly over time.
        Keeps identity stable while tolerating lighting/angle changes.
        """
        try:
            import numpy as np
            o = np.array(old, dtype=float)
            n = np.array(new, dtype=float)
            if o.shape != n.shape:
                return old
            blended = (1.0 - weight_new) * o + weight_new * n
            return blended.tolist()
        except Exception:
            return old

    # ─────────────────────────────────────────────────
    # MAINTENANCE
    # ─────────────────────────────────────────────────
    def cleanup_stale_trackings(self, hours: int = STALE_TRACKING_HOURS) -> int:
        cutoff = _utcnow() - timedelta(hours=hours)
        deleted = (
            self.db.query(PersonAlertTracking)
            .filter(PersonAlertTracking.last_seen_at < cutoff)
            .delete(synchronize_session=False)
        )
        self.db.commit()
        logger.info(f"🧹 Cleaned up {deleted} stale person trackings")
        return deleted

    def get_tracking_stats(self, property_id: int) -> dict:
        total = (
            self.db.query(PersonAlertTracking)
            .filter(PersonAlertTracking.property_id == property_id)
            .count()
        )
        active_window = _utcnow() - timedelta(minutes=5)
        active = (
            self.db.query(PersonAlertTracking)
            .filter(
                and_(
                    PersonAlertTracking.property_id == property_id,
                    PersonAlertTracking.last_seen_at >= active_window,
                )
            )
            .count()
        )
        return {
            "total_unique_persons": total,
            "active_last_5min": active,
        }


# ─────────────────────────────────────────────────
# HELPER WRAPPER
# ─────────────────────────────────────────────────
def should_generate_person_alert(
    db: Session,
    property_id: int,
    camera_id: int,
    camera_type: str,
    face_encoding: Optional[List[float]] = None,
) -> Tuple[bool, str]:
    tracker = PersonTracker(db)
    return tracker.track_person(
        property_id=property_id,
        camera_id=camera_id,
        camera_type=camera_type,
        face_encoding=face_encoding,
    )