from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class Property(Base):
    __tablename__ = "properties"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    

    # Owner
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Basic Info
    name = Column(String(255), nullable=False)
    address = Column(String(500), nullable=True, default="")

    # Location
    latitude = Column(Float, nullable=False, default=0.0)
    longitude = Column(Float, nullable=False, default=0.0)

    # Laser Grid Configuration
    x_lasers = Column(Integer, nullable=False, default=3)      # columns
    y_lasers = Column(Integer, nullable=False, default=8)      # rows
    box_width = Column(Float, nullable=False, default=2.0)     # meters
    box_length = Column(Float, nullable=False, default=0.6)    # meters
    grid_height = Column(Float, nullable=False, default=2.4)   # meters

    # Status (will be calculated but stored for quick access)
    cameras_online = Column(Integer, default=0)
    cameras_total = Column(Integer, default=0)
    drone_status = Column(String(50), default="Offline")
    active_alerts = Column(Integer, default=0)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    owner = relationship("User", backref="properties")
    authorized_people = relationship("AuthorizedPerson", back_populates="property")
    