from pydantic import BaseModel
from typing import Optional, List
from typing import Literal


# ==================== GRID CELL ====================
class GridCellSchema(BaseModel):
    row: int
    col: int


# ==================== CAMERA ====================
class CameraCreateRequest(BaseModel):
    name: str
    rtsp_url: str
    camera_type: Literal["entrance", "insider", "fence"] = "entrance"
    grid_cell: GridCellSchema


class CameraUpdateRequest(BaseModel):
    name: Optional[str] = None
    rtsp_url: Optional[str] = None
    camera_type: Optional[Literal["entrance", "insider", "fence"]] = None
    grid_cell: Optional[GridCellSchema] = None


class CameraResponse(BaseModel):
    id: str
    name: str
    rtsp_url: str
    camera_type: str
    grid_cell: GridCellSchema

    class Config:
        from_attributes = True


# ── NEW: returned after camera creation so frontend gets the real ID ──────────
class CameraCreatedResponse(BaseModel):
    success: bool
    message: str
    camera_id: int


# ==================== DRONE ====================
class DroneCreateRequest(BaseModel):
    name: str
    connection_string: str
    home_cell: GridCellSchema


class DroneUpdateRequest(BaseModel):
    name: Optional[str] = None
    connection_string: Optional[str] = None
    home_cell: Optional[GridCellSchema] = None


class DroneResponse(BaseModel):
    id: str
    name: str
    connection_string: str
    status: str
    home_cell: GridCellSchema

    class Config:
        from_attributes = True


# ==================== AUTHORIZED PERSON ====================
AllowedRole = Literal["Guard", "Guest", "Authorized Person"]


class PersonCreateRequest(BaseModel):
    name: str
    role: AllowedRole = "Guest"
    photo_urls: List[str] = []


class PersonUpdateRequest(BaseModel):
    name: Optional[str] = None
    role: Optional[AllowedRole] = None
    photo_urls: Optional[List[str]] = None


class PersonResponse(BaseModel):
    id: str
    name: str
    role: str
    photo_urls: List[str] = []

    class Config:
        from_attributes = True


# ==================== FLIGHT LOG ====================
class FlightLogCreateRequest(BaseModel):
    drone_name: str
    flight_type: str
    takeoff_time: str
    land_time: str
    drone_id: Optional[int] = None


class FlightLogResponse(BaseModel):
    id: str
    drone_name: str
    type: str
    takeoff_time: str
    land_time: str

    class Config:
        from_attributes = True


# ==================== LIST RESPONSES ====================
class CameraListResponse(BaseModel):
    success: bool
    message: str
    cameras: List[CameraResponse] = []


class DroneListResponse(BaseModel):
    success: bool
    message: str
    drones: List[DroneResponse] = []


class PersonListResponse(BaseModel):
    success: bool
    message: str
    people: List[PersonResponse] = []


class FlightLogListResponse(BaseModel):
    success: bool
    message: str
    flight_logs: List[FlightLogResponse] = []


class DetailResponse(BaseModel):
    success: bool
    message: str


class RolesResponse(BaseModel):
    success: bool
    roles: List[str]


class RelationshipsResponse(BaseModel):
    success: bool
    relationships: List[str]