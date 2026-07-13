from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class Drone(Base):
    __tablename__ = "drones"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)

    name = Column(String(255), nullable=False)
    connection_string = Column(String(500), nullable=False)
    status = Column(String(50), default="Offline")
    home_cell_row = Column(Integer, nullable=False, default=0)
    home_cell_col = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    property = relationship("Property", backref="drones")