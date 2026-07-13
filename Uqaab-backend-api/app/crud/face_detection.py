# app/crud/face_detection.py
from typing import List, Optional
from sqlalchemy.orm import Session

from app.models.face_detection import FaceDetectionEvent


def get_events_for_property(
    db: Session,
    property_id: int,
    limit: int = 100,
    only_unauthorized: bool = False,
) -> List[FaceDetectionEvent]:
    q = db.query(FaceDetectionEvent).filter(
        FaceDetectionEvent.property_id == property_id
    )
    if only_unauthorized:
        q = q.filter(FaceDetectionEvent.is_authorized == False)  # noqa: E712
    return q.order_by(FaceDetectionEvent.detected_at.desc()).limit(limit).all()


def get_events_for_camera(
    db: Session,
    camera_id: int,
    limit: int = 50,
) -> List[FaceDetectionEvent]:
    return (
        db.query(FaceDetectionEvent)
        .filter(FaceDetectionEvent.camera_id == camera_id)
        .order_by(FaceDetectionEvent.detected_at.desc())
        .limit(limit)
        .all()
    )


def get_event(db: Session, event_id: int) -> Optional[FaceDetectionEvent]:
    return db.query(FaceDetectionEvent).filter(FaceDetectionEvent.id == event_id).first()


def delete_event(db: Session, event_id: int) -> bool:
    event = get_event(db, event_id)
    if not event:
        return False
    db.delete(event)
    db.commit()
    return True