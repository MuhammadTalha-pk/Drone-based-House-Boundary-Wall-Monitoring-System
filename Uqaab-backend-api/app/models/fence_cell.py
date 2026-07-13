# app/models/fence_cell.py
from sqlalchemy import Column, Integer, String, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.core.database import Base


class FenceCell(Base):
    __tablename__ = "fence_cells"

    id         = Column(Integer, primary_key=True, index=True, autoincrement=True)
    camera_id  = Column(Integer, ForeignKey("cameras.id", ondelete="CASCADE"), nullable=False, index=True)
    cell_name  = Column(String(10), nullable=False)          # "A1", "B2", etc.
    row        = Column(Integer, nullable=False, default=0)  # 0-based row index
    col        = Column(Integer, nullable=False, default=0)  # 0-based col index

    # 4 normalized points  [{"x": 0.1, "y": 0.2}, ...]
    polygon_points = Column(JSON, nullable=False, default=[])

    camera = relationship("Camera", backref="fence_cells")