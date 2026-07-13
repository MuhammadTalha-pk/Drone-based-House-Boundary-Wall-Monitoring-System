from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class Camera(Base):
    __tablename__ = "cameras"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"), nullable=False)

    name = Column(String(255), nullable=False)
    rtsp_url = Column(String(500), nullable=False)
    camera_type = Column(String(50), nullable=False, default="entrance")
    grid_cell_row = Column(Integer, nullable=False, default=0)
    grid_cell_col = Column(Integer, nullable=False, default=0)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    property = relationship("Property", backref="cameras")
    
    # ✅ Parent side: owns the cascade. When Camera is deleted, FenceConfig is also deleted.
    fence_config = relationship(
        "FenceConfig", 
        back_populates="camera", 
        uselist=False, 
        cascade="all, delete-orphan"
    )