from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.property import (
    CreatePropertyRequest,
    UpdatePropertyRequest,
    PropertyResponse,
    PropertyListResponse,
    PropertyDetailResponse,
    DeleteResponse,
    LaserGridSchema,
)
from app.crud import property as property_crud
from app.api.v1.auth import get_current_user

router = APIRouter()


def property_to_response(db_property) -> PropertyResponse:
    """Convert database Property to response format matching Kotlin model"""
    return PropertyResponse(
        id=str(db_property.id),  # Convert int to string (Kotlin uses String id)
        name=db_property.name,
        address=db_property.address or "",
        latitude=db_property.latitude,
        longitude=db_property.longitude,
        laser_grid=LaserGridSchema(
            x_lasers=db_property.x_lasers,
            y_lasers=db_property.y_lasers,
            box_width=db_property.box_width,
            box_length=db_property.box_length,
            grid_height=db_property.grid_height,
        ),
        cameras_online=db_property.cameras_online,
        cameras_total=db_property.cameras_total,
        drone_status=db_property.drone_status,
        active_alerts=db_property.active_alerts,
        created_at=db_property.created_at.isoformat() if db_property.created_at else "Just now",
    )


# ======================== GET ALL PROPERTIES ========================
@router.get("/", response_model=PropertyListResponse)
def get_properties(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Get all properties for the logged-in user.

    Android app calls this on WelcomeScreen and PropertyListScreen.
    """
    properties = property_crud.get_properties_by_user(db, current_user.id)
    property_responses = [property_to_response(p) for p in properties]

    return PropertyListResponse(
        success=True,
        message=f"Found {len(property_responses)} properties",
        properties=property_responses,
    )


# ======================== GET SINGLE PROPERTY ========================
@router.get("/{property_id}", response_model=PropertyDetailResponse)
def get_property(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get a single property by ID"""
    db_property = property_crud.get_property_for_user(db, property_id, current_user.id)
    if not db_property:
        raise HTTPException(status_code=404, detail="Property not found")

    return PropertyDetailResponse(
        success=True,
        message="Property found",
        property=property_to_response(db_property),
    )


# ======================== CREATE PROPERTY ========================
@router.post("/", response_model=PropertyDetailResponse, status_code=201)
def create_property(
    request: CreatePropertyRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Create a new property.

    Android app sends:
    {
        "name": "Ali's Warehouse",
        "address": "123 Main St",
        "latitude": 33.6844,
        "longitude": 73.0479,
        "laser_grid": {
            "x_lasers": 3,
            "y_lasers": 8,
            "box_width": 2.0,
            "box_length": 0.6,
            "grid_height": 2.4
        }
    }
    """
    if not request.name.strip():
        raise HTTPException(status_code=400, detail="Property name is required")

    db_property = property_crud.create_property(db, current_user.id, request)

    return PropertyDetailResponse(
        success=True,
        message="Property created successfully!",
        property=property_to_response(db_property),
    )


# ======================== UPDATE PROPERTY ========================
@router.put("/{property_id}", response_model=PropertyDetailResponse)
def update_property(
    property_id: int,
    request: UpdatePropertyRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Update an existing property"""
    db_property = property_crud.update_property(db, property_id, current_user.id, request)
    if not db_property:
        raise HTTPException(status_code=404, detail="Property not found")

    return PropertyDetailResponse(
        success=True,
        message="Property updated successfully!",
        property=property_to_response(db_property),
    )


# ======================== DELETE PROPERTY ========================
@router.delete("/{property_id}", response_model=DeleteResponse)
def delete_property(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Delete a property"""
    success = property_crud.delete_property(db, property_id, current_user.id)
    if not success:
        raise HTTPException(status_code=404, detail="Property not found")

    return DeleteResponse(
        success=True,
        message="Property deleted successfully!",
    )