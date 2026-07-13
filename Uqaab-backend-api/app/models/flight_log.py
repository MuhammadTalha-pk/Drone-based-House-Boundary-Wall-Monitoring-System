from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class FlightLog(Base):
    __tablename__ = "flight_logs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)
    drone_id = Column(Integer, ForeignKey("drones.id", ondelete="SET NULL"), nullable=True)

    drone_name = Column(String(255), nullable=False)
    flight_type = Column(String(50), nullable=False)  # DISPATCH, PATROL, TEST
    takeoff_time = Column(String(100), nullable=False)
    land_time = Column(String(100), nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    property = relationship("Property", backref="flight_logs")
    drone = relationship("Drone", backref="flight_logs")