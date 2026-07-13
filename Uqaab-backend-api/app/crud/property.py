from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.property import Property
from app.schemas.property import CreatePropertyRequest, UpdatePropertyRequest


def get_properties_by_user(db: Session, user_id: int) -> List[Property]:
    """Get all properties belonging to a user"""
    return db.query(Property).filter(Property.user_id == user_id).order_by(Property.created_at.desc()).all()


def get_property(db: Session, property_id: int) -> Optional[Property]:
    """Get a single property by ID"""
    return db.query(Property).filter(Property.id == property_id).first()


def get_property_for_user(db: Session, property_id: int, user_id: int) -> Optional[Property]:
    """Get a property only if it belongs to the user"""
    return db.query(Property).filter(
        Property.id == property_id,
        Property.user_id == user_id
    ).first()


def create_property(db: Session, user_id: int, request: CreatePropertyRequest) -> Property:
    """Create a new property"""
    db_property = Property(
        user_id=user_id,
        name=request.name,
        address=request.address,
        latitude=request.latitude,
        longitude=request.longitude,
        x_lasers=request.laser_grid.x_lasers,
        y_lasers=request.laser_grid.y_lasers,
        box_width=request.laser_grid.box_width,
        box_length=request.laser_grid.box_length,
        grid_height=request.laser_grid.grid_height,
    )
    db.add(db_property)
    db.commit()
    db.refresh(db_property)
    return db_property


def update_property(db: Session, property_id: int, user_id: int, request: UpdatePropertyRequest) -> Optional[Property]:
    """Update a property"""
    db_property = get_property_for_user(db, property_id, user_id)
    if not db_property:
        return None

    if request.name is not None:
        db_property.name = request.name
    if request.address is not None:
        db_property.address = request.address
    if request.latitude is not None:
        db_property.latitude = request.latitude
    if request.longitude is not None:
        db_property.longitude = request.longitude
    if request.laser_grid is not None:
        db_property.x_lasers = request.laser_grid.x_lasers
        db_property.y_lasers = request.laser_grid.y_lasers
        db_property.box_width = request.laser_grid.box_width
        db_property.box_length = request.laser_grid.box_length
        db_property.grid_height = request.laser_grid.grid_height

    db.commit()
    db.refresh(db_property)
    return db_property


def delete_property(db: Session, property_id: int, user_id: int) -> bool:
    """Delete a property (only if it belongs to the user)"""
    db_property = get_property_for_user(db, property_id, user_id)
    if not db_property:
        return False
    db.delete(db_property)
    db.commit()
    return True