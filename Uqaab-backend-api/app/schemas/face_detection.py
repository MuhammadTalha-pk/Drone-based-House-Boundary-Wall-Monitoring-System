# app/schemas/face_detection.py
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


# ─── Face Detection Event ───────────────────────────────────────────────────

class FaceDetectionEventResponse(BaseModel):
    id: int
    property_id: int
    camera_id: Optional[int]
    is_authorized: bool
    matched_person_name: Optional[str]
    matched_role: Optional[str]
    recognition_confidence: float
    tracking_id: Optional[str]
    face_image_url: Optional[str]
    snapshot_url: Optional[str]
    video_clip_url: Optional[str]
    alert_id: Optional[int]
    detected_at: datetime

    class Config:
        from_attributes = True


class FaceDetectionListResponse(BaseModel):
    success: bool
    count: int
    events: List[FaceDetectionEventResponse] = []


# ─── Face Encoding Registration ──────────────────────────────────────────────

class EncodeFaceRequest(BaseModel):
    """Trigger re-encoding of an authorized person's photos."""
    person_id: int


class EncodeFaceResponse(BaseModel):
    success: bool
    message: str
    person_id: int
    encodings_count: int


# ─── Manager Status ──────────────────────────────────────────────────────────

class FaceDetectionStatusResponse(BaseModel):
    success: bool
    running_cameras: dict   # {camera_id: is_running}