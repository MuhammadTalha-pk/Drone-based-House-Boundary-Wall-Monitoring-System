# app/schemas/weapon_detection.py
"""
Pydantic schemas for weapon detection API responses.
"""
from pydantic import BaseModel
from typing import Optional, List


class WeaponEventResponse(BaseModel):
    id: str
    camera_id: Optional[int] = None
    camera_type: Optional[str] = None
    weapon_class: str
    weapon_confidence: int
    holder_identified: bool
    holder_person_name: Optional[str] = None
    holder_role: Optional[str] = None
    is_guard: bool
    is_stray_weapon: bool
    drone_triggered: bool
    snapshot_url: Optional[str] = None
    weapon_crop_url: Optional[str] = None
    face_image_url: Optional[str] = None
    video_clip_url: Optional[str] = None
    detected_at: Optional[str] = None

    class Config:
        from_attributes = True


class WeaponEventListResponse(BaseModel):
    success: bool
    message: str
    events: List[WeaponEventResponse] = []


class WeaponDetectionStatusResponse(BaseModel):
    success: bool
    initialized: bool
    detectors: dict = {}
