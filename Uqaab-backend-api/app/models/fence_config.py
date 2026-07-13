from sqlalchemy import Column, Integer, JSON, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class FenceConfig(Base):
    __tablename__ = "fence_configs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    camera_id = Column(Integer, ForeignKey("cameras.id", ondelete="CASCADE"), nullable=False, unique=True)

    polygon_points = Column(JSON, nullable=True)   # normalized zone polygon [{x,y}, ...]
    cells_config = Column(JSON, nullable=True)     # NEW: {"image_width":..., "image_height":..., "cells":[...]}
    is_active = Column(Integer, default=1)

    camera = relationship("Camera", back_populates="fence_config")