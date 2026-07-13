from pydantic import BaseModel
from typing import Optional, List


# ==================== ALERT SCHEMAS ====================

class GridCellSchema(BaseModel):
    row: int
    col: int


class AlertCreateRequest(BaseModel):
    alert_type: str
    camera_name: str
    camera_id: Optional[int] = None
    severity: str = "medium"
    confidence: int = 0
    camera_cell_row: int = 0
    camera_cell_col: int = 0
    image_url: Optional[str] = None
    clip_url: Optional[str] = None
    detected_cell: Optional[str] = None     # ── NEW


class AlertResponse(BaseModel):
    id: str
    type: str
    camera_name: str
    timestamp: str
    is_read: bool
    confidence: int
    severity: str
    image_url: Optional[str] = None
    clip_url: Optional[str] = None
    camera_cell: GridCellSchema
    status: str
    detected_cell: Optional[str] = None     # ── NEW

    class Config:
        from_attributes = True


class AlertListResponse(BaseModel):
    success: bool
    message: str
    alerts: List[AlertResponse] = []


class AlertDetailResponse(BaseModel):
    success: bool
    message: str
    alert: Optional[AlertResponse] = None


# ==================== DASHBOARD SCHEMAS ====================

class ActiveAlertResponse(BaseModel):
    id: str
    message: str
    severity: str
    timestamp: str


class CameraFeedResponse(BaseModel):
    id: str
    name: str
    is_online: bool
    stream_url: Optional[str] = None
    thumbnail_url: Optional[str] = None


class DroneFeedResponse(BaseModel):
    id: str
    name: str
    is_online: bool
    stream_url: Optional[str] = None


class DashboardResponse(BaseModel):
    success: bool
    message: str
    property_name: str
    active_alert: Optional[ActiveAlertResponse] = None
    drone_status: str
    cameras_online: int
    cameras_total: int
    new_alerts_count: int
    cameras: List[CameraFeedResponse] = []
    drones: List[DroneFeedResponse] = []
    latitude: float
    longitude: float