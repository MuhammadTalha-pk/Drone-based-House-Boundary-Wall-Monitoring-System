from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ========== Laser Grid Schema ==========

class LaserGridSchema(BaseModel):
    """Matches your Kotlin LaserGrid data class exactly"""
    x_lasers: int = 3
    y_lasers: int = 8
    box_width: float = 2.0
    box_length: float = 0.6
    grid_height: float = 2.4


# ========== What Android SENDS ==========

class CreatePropertyRequest(BaseModel):
    """
    Matches your Kotlin CreatePropertyRequest:
    - name
    - address
    - latitude
    - longitude
    - laserGrid (nested object)
    """
    name: str
    address: str = ""
    latitude: float = 0.0
    longitude: float = 0.0
    laser_grid: LaserGridSchema


class UpdatePropertyRequest(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    laser_grid: Optional[LaserGridSchema] = None


# ========== What Backend SENDS back ==========

class PropertyResponse(BaseModel):
    """
    Matches your Kotlin Property data class exactly.
    """
    id: str  # String to match your Kotlin model
    name: str
    address: str
    latitude: float
    longitude: float
    laser_grid: LaserGridSchema
    cameras_online: int
    cameras_total: int
    drone_status: str
    active_alerts: int
    created_at: str  # String to match your Kotlin model

    class Config:
        from_attributes = True


class PropertyListResponse(BaseModel):
    success: bool
    message: str
    properties: List[PropertyResponse] = []


class PropertyDetailResponse(BaseModel):
    success: bool
    message: str
    property: Optional[PropertyResponse] = None


class DeleteResponse(BaseModel):
    success: bool
    message: str