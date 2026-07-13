from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.services.person_tracker import PersonTracker
from app.models.person_tracking import PersonAlertTracking
from app.crud.property import get_property_for_user

router = APIRouter()


@router.get("/{property_id}/stats")
def get_tracking_stats(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get person tracking statistics for a property."""
    prop = get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    tracker = PersonTracker(db)
    stats = tracker.get_tracking_stats(property_id)

    return {
        "success": True,
        "property_id": property_id,
        "stats": stats,
    }


@router.get("/{property_id}/active")
def get_active_trackings(
    property_id: int,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """List recent person trackings for a property."""
    prop = get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    trackings = (
        db.query(PersonAlertTracking)
        .filter(PersonAlertTracking.property_id == property_id)
        .order_by(PersonAlertTracking.last_seen_at.desc())
        .limit(limit)
        .all()
    )

    return {
        "success": True,
        "count": len(trackings),
        "trackings": [
            {
                "tracking_id": t.tracking_id,
                "cameras_seen": t.camera_ids_seen,
                "camera_types_seen": t.camera_types_seen,
                "last_camera_type": t.last_camera_type,
                "total_detections": t.total_detections,
                "total_alerts": t.total_alerts_generated,
                "first_seen": t.first_seen_at.isoformat() if t.first_seen_at else None,
                "last_seen": t.last_seen_at.isoformat() if t.last_seen_at else None,
                "is_authorized": t.is_authorized,
            }
            for t in trackings
        ],
    }


@router.post("/cleanup")
def cleanup_stale_trackings(
    hours: int = 24,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Remove tracking records older than N hours."""
    tracker = PersonTracker(db)
    deleted = tracker.cleanup_stale_trackings(hours=hours)
    return {
        "success": True,
        "deleted_count": deleted,
        "message": f"Cleaned up {deleted} stale tracking records",
    }


@router.delete("/{tracking_id}")
def delete_tracking(
    tracking_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Manually delete a specific tracking record."""
    tracking = (
        db.query(PersonAlertTracking)
        .filter(PersonAlertTracking.tracking_id == tracking_id)
        .first()
    )
    if not tracking:
        raise HTTPException(status_code=404, detail="Tracking not found")

    prop = get_property_for_user(db, tracking.property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=403, detail="Not authorized")

    db.delete(tracking)
    db.commit()

    return {"success": True, "message": f"Tracking {tracking_id} deleted"}