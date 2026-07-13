# app/api/v1/weapon_detection.py
"""
REST API for controlling weapon detection on fence & insider cameras.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.crud.settings import get_camera
from app.models.weapon_detection import WeaponDetectionEvent
from app.schemas.weapon_detection import (
    WeaponEventResponse,
    WeaponEventListResponse,
    WeaponDetectionStatusResponse,
)
from app.services.weapon_detection_manager import weapon_detection_manager

router = APIRouter()


# ==================== START / STOP / RESTART ====================

@router.post("/{camera_id}/start")
def start_weapon_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Start weapon detection on a fence or insider camera."""
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    if camera.camera_type not in ("fence", "insider"):
        raise HTTPException(
            status_code=400,
            detail="Weapon detection only runs on fence and insider cameras",
        )

    weapon_detection_manager.start_camera(
        camera_id=camera.id,
        rtsp_url=camera.rtsp_url,
        property_id=camera.property_id,
        camera_type=camera.camera_type,
    )

    return {
        "success": True,
        "message": f"Weapon detection started for '{camera.name}' ({camera.camera_type})",
    }


@router.post("/{camera_id}/stop")
def stop_weapon_detection(
    camera_id: int,
    current_user=Depends(get_current_user),
):
    """Stop weapon detection on a camera."""
    weapon_detection_manager.stop_camera(camera_id)
    return {
        "success": True,
        "message": f"Weapon detection stopped for camera {camera_id}",
    }


@router.post("/{camera_id}/restart")
def restart_weapon_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Restart weapon detection on a camera."""
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    if camera.camera_type not in ("fence", "insider"):
        raise HTTPException(
            status_code=400,
            detail="Weapon detection only runs on fence and insider cameras",
        )

    weapon_detection_manager.restart_camera(
        camera_id=camera.id,
        rtsp_url=camera.rtsp_url,
        property_id=camera.property_id,
        camera_type=camera.camera_type,
    )

    return {
        "success": True,
        "message": f"Weapon detection restarted for '{camera.name}'",
    }


# ==================== STATUS ====================

@router.get("/status", response_model=WeaponDetectionStatusResponse)
def get_weapon_status(current_user=Depends(get_current_user)):
    """Get status of all running weapon detection threads."""
    return WeaponDetectionStatusResponse(
        success=True,
        initialized=weapon_detection_manager.is_initialized,
        detectors=weapon_detection_manager.status(),
    )


# ==================== EVENTS ====================

@router.get("/events/{property_id}", response_model=WeaponEventListResponse)
def get_weapon_events(
    property_id: int,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get recent weapon detection events for a property."""
    events = (
        db.query(WeaponDetectionEvent)
        .filter(WeaponDetectionEvent.property_id == property_id)
        .order_by(WeaponDetectionEvent.detected_at.desc())
        .limit(limit)
        .all()
    )

    event_responses = []
    for e in events:
        event_responses.append(
            WeaponEventResponse(
                id=str(e.id),
                camera_id=e.camera_id,
                camera_type=e.camera_type,
                weapon_class=e.weapon_class,
                weapon_confidence=e.weapon_confidence,
                holder_identified=e.holder_identified,
                holder_person_name=e.holder_person_name,
                holder_role=e.holder_role,
                is_guard=e.is_guard,
                is_stray_weapon=e.is_stray_weapon,
                drone_triggered=e.drone_triggered,
                snapshot_url=e.snapshot_url,
                weapon_crop_url=e.weapon_crop_url,
                face_image_url=e.face_image_url,
                video_clip_url=e.video_clip_url,
                detected_at=e.detected_at.isoformat() if e.detected_at else None,
            )
        )

    return WeaponEventListResponse(
        success=True,
        message=f"Found {len(event_responses)} weapon events",
        events=event_responses,
    )
