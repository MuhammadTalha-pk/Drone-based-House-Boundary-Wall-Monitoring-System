from sqlalchemy import Column, DateTime, Integer, String, ForeignKey, JSON, func
from sqlalchemy.orm import relationship

from app.core.database import Base


class AuthorizedPerson(Base):
    __tablename__ = "authorized_people"

    id = Column(Integer, primary_key=True, index=True)

    property_id = Column(Integer, ForeignKey("properties.id"), nullable=False)

    name = Column(String, nullable=False)

    # ✅ RENAMED: relationship_type → role
    # ✅ RESTRICTED: Only "Guard", "Guest", "Authorized Person"
    role = Column(String, nullable=False, default="Guest")

    # URLs of uploaded photos
    photo_urls = Column(JSON, default=[])

    # Face recognition encodings (128-d vectors)
    face_encodings = Column(JSON, default=[])

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    property = relationship("Property", back_populates="authorized_people")