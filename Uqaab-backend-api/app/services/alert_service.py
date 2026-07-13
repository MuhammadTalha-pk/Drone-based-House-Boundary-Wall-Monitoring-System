# app/services/alert_service.py
"""
Alert Notification Service
===========================
Centralized service to create alerts in DB AND broadcast via WebSocket
in a single atomic operation.

Used by all detection systems:
  - Wall Climbing Detection (fence cameras)
  - Face Detection (entrance cameras)  
  - Weapon Detection (fence/insider cameras)

Ensures frontend dashboard receives instant push notification
whenever any suspicious activity is detected.
"""
import logging
from typing import Optional, Tuple
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.models.alert import Alert
from app.models.property import Property
from app.core.websocket import websocket_manager

logger = logging.getLogger(__name__)

# Alert type constants for consistency
ALERT_TYPE_WEAPON = "weapon_detection"
ALERT_TYPE_UNAUTHORIZED = "unauthorized_person"
ALERT_TYPE_CLIMBING = "person_climbing"

# Camera type constants
CAMERA_ENTRANCE = "entrance"
CAMERA_FENCE = "fence"
CAMERA_INSIDER = "insider"


class AlertService:
    """
    Unified alert creation + notification service.
    All detection modules should call this instead of creating Alerts directly.
    """

    @staticmethod
    def create_and_notify(
        db: Session,
        property_id: int,
        camera_id: int,
        camera_name: str,
        camera_type: str,
        alert_type: str,
        severity: str = "medium",
        confidence: int = 0,
        camera_cell_row: Optional[int] = None,
        camera_cell_col: Optional[int] = None,
        image_url: Optional[str] = None,
        clip_url: Optional[str] = None,
        tracking_id: Optional[str] = None,
        holder_person_name: Optional[str] = None,
        holder_role: Optional[str] = None,
    ) -> Tuple[Alert, bool]:
        """
        Create alert in database AND broadcast to frontend via WebSocket.

        Args:
            db: SQLAlchemy session
            property_id: Property ID
            camera_id: Camera ID
            camera_name: Human-readable camera name
            camera_type: "entrance" | "fence" | "insider"
            alert_type: "weapon_detection" | "unauthorized_person" | "person_climbing"
            severity: "low" | "medium" | "high" | "critical"
            confidence: 0-100 detection confidence
            camera_cell_row: Grid cell row (nullable)
            camera_cell_col: Grid cell column (nullable)
            image_url: Snapshot image URL
            clip_url: Video clip URL
            tracking_id: Person tracking ID for cross-camera correlation
            holder_person_name: For weapon detection - identified person's name
            holder_role: For weapon detection - identified person's role

        Returns:
            Tuple of (created_alert, broadcast_success)
        """
        try:
            # ── 1. Create Alert in Database ──────────────────────────
            alert = Alert(
                property_id=property_id,
                camera_id=camera_id,
                alert_type=AlertService._format_alert_type(alert_type),
                camera_name=camera_name,
                severity=severity,
                confidence=confidence,
                camera_cell_row=camera_cell_row or 0,
                camera_cell_col=camera_cell_col or 0,
                image_url=image_url,
                clip_url=clip_url,
                status="active",
                is_read=False,
            )
            db.add(alert)
            db.flush()  # Get alert.id without committing yet

            # Update property active alerts count
            prop = db.query(Property).filter(Property.id == property_id).first()
            if prop:
                active_count = (
                    db.query(Alert)
                    .filter(
                        Alert.property_id == property_id,
                        Alert.status == "active",
                    )
                    .count()
                )
                prop.active_alerts = active_count

            db.commit()
            db.refresh(alert)

            logger.info(
                f"🚨 ALERT CREATED | ID: {alert.id} | Type: {alert_type} | "
                f"Camera: {camera_name} ({camera_type}) | "
                f"Property: {property_id} | Cell: ({camera_cell_row}, {camera_cell_col})"
            )

            # ── 2. Build WebSocket Payload ───────────────────────────
            payload = AlertService._build_payload(
                alert=alert,
                camera_type=camera_type,
                alert_type=alert_type,
                tracking_id=tracking_id,
                holder_person_name=holder_person_name,
                holder_role=holder_role,
            )

            # ── 3. Broadcast to Frontend ─────────────────────────────
            import asyncio
            try:
                # Run async broadcast in sync context
                loop = asyncio.get_event_loop()
                if loop.is_running():
                    asyncio.create_task(websocket_manager.broadcast_alert(payload))
                else:
                    loop.run_until_complete(websocket_manager.broadcast_alert(payload))

                broadcast_success = True
                logger.info(f"📡 Alert {alert.id} broadcasted to property {property_id}")
            except Exception as e:
                broadcast_success = False
                logger.error(f"❌ Failed to broadcast alert {alert.id}: {e}")

            return alert, broadcast_success

        except Exception as e:
            db.rollback()
            logger.error(f"❌ Failed to create alert: {e}", exc_info=True)
            raise

    @staticmethod
    def _format_alert_type(alert_type: str) -> str:
        """Convert internal type to human-readable alert type."""
        type_map = {
            ALERT_TYPE_WEAPON: "Weapon Detected",
            ALERT_TYPE_UNAUTHORIZED: "Unauthorized Person at Entrance",
            ALERT_TYPE_CLIMBING: "Wall Climbing Detected",
        }
        return type_map.get(alert_type, alert_type)

    @staticmethod
    def _build_payload(
        alert: Alert,
        camera_type: str,
        alert_type: str,
        tracking_id: Optional[str] = None,
        holder_person_name: Optional[str] = None,
        holder_role: Optional[str] = None,
    ) -> dict:
        """
        Build standardized WebSocket payload for frontend consumption.
        Matches your requested format exactly.
        """
        # Human-readable messages per alert type
        messages = {
            ALERT_TYPE_WEAPON: f"🚨 WEAPON DETECTED at {alert.camera_name}",
            ALERT_TYPE_UNAUTHORIZED: f"⚠️ UNAUTHORIZED PERSON at {alert.camera_name}",
            ALERT_TYPE_CLIMBING: f"🧗 PERSON CLIMBING detected at {alert.camera_name}",
        }

        # Build camera display string
        camera_display = f"{camera_type.upper()} - {alert.camera_name}"

        # Build cell display (nullable)
        cell_display = None
        if alert.camera_cell_row is not None and alert.camera_cell_col is not None:
            if alert.camera_cell_row > 0 or alert.camera_cell_col > 0:
                cell_display = f"Row {alert.camera_cell_row}, Col {alert.camera_cell_col}"

        payload = {
            # Core required fields
            "type": "new_alert",
            "alert_number": alert.id,
            "alert_type": alert_type,
            "camera_type": camera_type,
            "camera_name": alert.camera_name,
            "camera_id": alert.camera_id,

            # Grid cell (nullable)
            "cell_row": alert.camera_cell_row if alert.camera_cell_row > 0 else None,
            "cell_col": alert.camera_cell_col if alert.camera_cell_col > 0 else None,
            "cell_display": cell_display,

            # Additional context
            "severity": alert.severity,
            "confidence": alert.confidence,
            "timestamp": alert.timestamp.isoformat() if alert.timestamp else datetime.now(timezone.utc).isoformat(),
            "image_url": alert.image_url,
            "clip_url": alert.clip_url,
            "status": alert.status,
            "is_read": alert.is_read,

            # Human-readable message
            "message": messages.get(alert_type, f"Alert at {alert.camera_name}"),
            "camera_display": camera_display,

            # Optional tracking/identification data
            "tracking_id": tracking_id,
            "holder_person_name": holder_person_name,
            "holder_role": holder_role,

            # Property scope for routing
            "property_id": alert.property_id,
        }

        return payload

    @staticmethod
    def update_and_notify(
        db: Session,
        alert: Alert,
        image_url: Optional[str] = None,
        clip_url: Optional[str] = None,
    ) -> None:
        """
        Update alert with media URLs and notify frontend of update.
        Call this after saving snapshot/video files.
        """
        if image_url:
            alert.image_url = image_url
        if clip_url:
            alert.clip_url = clip_url

        db.commit()
        db.refresh(alert)

        # Notify frontend of media update
        payload = {
            "type": "alert_updated",
            "alert_number": alert.id,
            "image_url": alert.image_url,
            "clip_url": alert.clip_url,
            "property_id": alert.property_id,
        }

        import asyncio
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.create_task(websocket_manager.broadcast_alert(payload))
            else:
                loop.run_until_complete(websocket_manager.broadcast_alert(payload))
        except Exception as e:
            logger.error(f"Failed to broadcast alert update: {e}")


# Convenience functions for detection modules
def notify_weapon_detected(
    db: Session,
    property_id: int,
    camera_id: int,
    camera_name: str,
    camera_type: str,
    confidence: int,
    camera_cell_row: Optional[int] = None,
    camera_cell_col: Optional[int] = None,
    image_url: Optional[str] = None,
    clip_url: Optional[str] = None,
    tracking_id: Optional[str] = None,
    holder_person_name: Optional[str] = None,
    holder_role: Optional[str] = None,
) -> Tuple[Alert, bool]:
    """Convenience wrapper for weapon detection alerts."""
    return AlertService.create_and_notify(
        db=db,
        property_id=property_id,
        camera_id=camera_id,
        camera_name=camera_name,
        camera_type=camera_type,
        alert_type=ALERT_TYPE_WEAPON,
        severity="critical",
        confidence=confidence,
        camera_cell_row=camera_cell_row,
        camera_cell_col=camera_cell_col,
        image_url=image_url,
        clip_url=clip_url,
        tracking_id=tracking_id,
        holder_person_name=holder_person_name,
        holder_role=holder_role,
    )


def notify_unauthorized_person(
    db: Session,
    property_id: int,
    camera_id: int,
    camera_name: str,
    confidence: int,
    camera_cell_row: Optional[int] = None,
    camera_cell_col: Optional[int] = None,
    image_url: Optional[str] = None,
    clip_url: Optional[str] = None,
    tracking_id: Optional[str] = None,
) -> Tuple[Alert, bool]:
    """Convenience wrapper for unauthorized person alerts."""
    return AlertService.create_and_notify(
        db=db,
        property_id=property_id,
        camera_id=camera_id,
        camera_name=camera_name,
        camera_type=CAMERA_ENTRANCE,
        alert_type=ALERT_TYPE_UNAUTHORIZED,
        severity="high",
        confidence=confidence,
        camera_cell_row=camera_cell_row,
        camera_cell_col=camera_cell_col,
        image_url=image_url,
        clip_url=clip_url,
        tracking_id=tracking_id,
    )


def notify_person_climbing(
    db: Session,
    property_id: int,
    camera_id: int,
    camera_name: str,
    confidence: int,
    camera_cell_row: Optional[int] = None,
    camera_cell_col: Optional[int] = None,
    image_url: Optional[str] = None,
    clip_url: Optional[str] = None,
    tracking_id: Optional[str] = None,
) -> Tuple[Alert, bool]:
    """Convenience wrapper for wall climbing alerts."""
    return AlertService.create_and_notify(
        db=db,
        property_id=property_id,
        camera_id=camera_id,
        camera_name=camera_name,
        camera_type=CAMERA_FENCE,
        alert_type=ALERT_TYPE_CLIMBING,
        severity="critical",
        confidence=confidence,
        camera_cell_row=camera_cell_row,
        camera_cell_col=camera_cell_col,
        image_url=image_url,
        clip_url=clip_url,
        tracking_id=tracking_id,
    )
    