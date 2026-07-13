from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)
    camera_id = Column(Integer, ForeignKey("cameras.id", ondelete="SET NULL"), nullable=True)

    # Alert info
    alert_type = Column(String(100), nullable=False)  # Person Detected, Vehicle Detected, Motion Detected
    camera_name = Column(String(255), nullable=False)
    severity = Column(String(50), default="medium")  # low, medium, high, critical
    confidence = Column(Integer, default=0)  # 0-100

 # ── NEW: which cell the intruder was detected in ────────────
    detected_cell = Column(String(10), nullable=True)     # "A1", "B2", etc.


    # Grid cell where alert was triggered
    camera_cell_row = Column(Integer, default=0)
    camera_cell_col = Column(Integer, default=0)

    # Media
    image_url = Column(String(500), nullable=True)
    clip_url = Column(String(500), nullable=True)

    # Status
    is_read = Column(Boolean, default=False)
    status = Column(String(50), default="active")  # active, resolved, false_positive

    # Timestamps
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    property = relationship("Property", backref="alerts")
    camera = relationship("Camera", backref="alerts")