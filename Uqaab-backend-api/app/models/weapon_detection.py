# app/models/weapon_detection.py
"""
Stores per-detection events from fence & insider cameras.
One row per frame where a weapon was detected and classified.
"""
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class WeaponDetectionEvent(Base):
    __tablename__ = "weapon_detection_events"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)

    # Which property / camera triggered the event
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)
    camera_id   = Column(Integer, ForeignKey("cameras.id",   ondelete="SET NULL"), nullable=True)
    camera_type = Column(String(50), nullable=True)  # "fence" | "insider"

    # Weapon detection result
    weapon_class      = Column(String(100), nullable=False, default="weapon")
    weapon_confidence = Column(Integer, default=0)           # 0-100
    weapon_bbox       = Column(JSON, nullable=True)          # {x1, y1, x2, y2} pixel coords

    # Person identification (if face found near weapon)
    holder_identified   = Column(Boolean, default=False)     # did we find who's holding it
    holder_person_id    = Column(Integer, ForeignKey("authorized_people.id", ondelete="SET NULL"), nullable=True)
    holder_person_name  = Column(String(255), nullable=True)
    holder_role         = Column(String(100), nullable=True) # Guard / Guest / Authorized Person
    is_guard            = Column(Boolean, default=False)     # True = alert suppressed
    is_stray_weapon     = Column(Boolean, default=False)     # True = no person near weapon

    # Link to person-tracking record (cooldown dedup)
    tracking_id = Column(String(100), nullable=True)         # FK-like to PersonAlertTracking.tracking_id

    # Media saved on disk
    snapshot_url    = Column(String(500), nullable=True)     # static/snapshots/<filename>
    weapon_crop_url = Column(String(500), nullable=True)     # static/weapons/<filename>
    face_image_url  = Column(String(500), nullable=True)     # static/faces/<filename>
    video_clip_url  = Column(String(500), nullable=True)     # static/videos/<filename>

    # Alert generated (if not guard)
    alert_id = Column(Integer, ForeignKey("alerts.id", ondelete="SET NULL"), nullable=True)

    # Drone trigger (placeholder for future drone integration)
    drone_triggered = Column(Boolean, default=False)

    # Timestamps
    detected_at = Column(DateTime(timezone=True), server_default=func.now())
    created_at  = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    property       = relationship("Property",         backref="weapon_detections")
    camera         = relationship("Camera",           backref="weapon_detections")
    holder_person  = relationship("AuthorizedPerson", backref="weapon_holder_events", foreign_keys=[holder_person_id])
    alert          = relationship("Alert",            backref="weapon_event",         foreign_keys=[alert_id])
