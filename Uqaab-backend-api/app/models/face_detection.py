# app/models/face_detection.py
"""
Stores per-detection events from entrance cameras.
One row per frame where a face was detected and classified.
"""
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class FaceDetectionEvent(Base):
    __tablename__ = "face_detection_events"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)

    # Which property / camera triggered the event
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)
    camera_id   = Column(Integer, ForeignKey("cameras.id",   ondelete="SET NULL"), nullable=True)

    # Recognition result
    is_authorized   = Column(Boolean, nullable=False, default=False)
    matched_person_id = Column(Integer, ForeignKey("authorized_people.id", ondelete="SET NULL"), nullable=True)
    matched_person_name = Column(String(255), nullable=True)
    matched_role        = Column(String(100), nullable=True)   # Guard / Guest / Authorized Person
    recognition_confidence = Column(Float, default=0.0)        # 0-1 distance similarity

    # Link to person-tracking record (only set for unauthorized persons)
    tracking_id = Column(String(100), nullable=True)           # FK-like to PersonAlertTracking.tracking_id

    # Media saved on disk
    face_image_url    = Column(String(500), nullable=True)     # static/faces/<filename>
    snapshot_url      = Column(String(500), nullable=True)     # static/snapshots/<filename>
    video_clip_url    = Column(String(500), nullable=True)     # static/videos/<filename>

    # Alert generated (if unauthorized)
    alert_id = Column(Integer, ForeignKey("alerts.id", ondelete="SET NULL"), nullable=True)

    # Timestamps
    detected_at = Column(DateTime(timezone=True), server_default=func.now())
    created_at  = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    property       = relationship("Property",  backref="face_detections")
    camera         = relationship("Camera",    backref="face_detections")
    matched_person = relationship("AuthorizedPerson", backref="face_matches", foreign_keys=[matched_person_id])
    alert          = relationship("Alert",     backref="face_event", foreign_keys=[alert_id])