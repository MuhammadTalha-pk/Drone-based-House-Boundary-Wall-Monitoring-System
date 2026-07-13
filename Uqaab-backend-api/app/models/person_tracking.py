from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, JSON, Boolean, Float
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class PersonAlertTracking(Base):
    """
    Central tracking table for person detections across ALL cameras.
    
    Purpose:
    - Tracks unique persons across fence/entrance/insider cameras
    - Prevents duplicate alerts within 60 seconds for same person
    - Applies ONLY to persons (NOT weapons/objects)
    """
    __tablename__ = "person_alert_tracking"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)

    # Unique tracker ID (UUID string) to identify same person across cameras
    tracking_id = Column(String(100), unique=True, index=True, nullable=False)

    # Property scope
    property_id = Column(
        Integer,
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Optional face encoding if person was recognized via face
    # Used to match same person across different camera types
    face_encoding = Column(JSON, nullable=True)

    # Camera tracking — which cameras have seen this person
    camera_ids_seen = Column(JSON, default=[])   # [1, 3, 7]
    camera_types_seen = Column(JSON, default=[]) # ["fence", "entrance"]

    # Last detection info
    last_camera_id = Column(
        Integer,
        ForeignKey("cameras.id", ondelete="SET NULL"),
        nullable=True,
    )
    last_camera_type = Column(String(50), nullable=True)  # fence/entrance/insider

    # Alert control (THE KEY FIELDS)
    last_alert_time = Column(DateTime(timezone=True), nullable=True)
    total_alerts_generated = Column(Integer, default=0)
    total_detections = Column(Integer, default=0)

    # Metadata
    first_seen_at = Column(DateTime(timezone=True), server_default=func.now())
    last_seen_at = Column(DateTime(timezone=True), server_default=func.now())

    # Face matching (optional — if linked to an authorized person)
    matched_person_id = Column(
        Integer,
        ForeignKey("authorized_people.id", ondelete="SET NULL"),
        nullable=True,
    )
    is_authorized = Column(Boolean, default=False)

    # Relationships
    property = relationship("Property", backref="person_trackings")
    last_camera = relationship("Camera")
    matched_person = relationship("AuthorizedPerson")