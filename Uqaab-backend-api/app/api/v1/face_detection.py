# app/api/v1/face_detection.py
"""
Face Detection API
==================
Endpoints to:
  - View detection events (per property / camera)
  - Trigger face encoding for authorized persons
  - Start / stop / status of the face detection manager
"""
import os
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.crud.settings import get_person, get_camera
from app.crud.property import get_property_for_user
from app.crud.face_detection import (
    get_events_for_property,
    get_events_for_camera,
    get_event,
    delete_event,
)
from app.schemas.face_detection import (
    FaceDetectionListResponse,
    FaceDetectionEventResponse,
    EncodeFaceRequest,
    EncodeFaceResponse,
    FaceDetectionStatusResponse,
)
from app.services.face_recognition_service import FaceRecognitionService
from app.services.face_detection_manager import face_detection_manager

router = APIRouter()
logger = logging.getLogger(__name__)


# ─── EVENTS ─────────────────────────────────────────────────────────────────

@router.get("/{property_id}/events", response_model=FaceDetectionListResponse)
def list_events(
    property_id: int,
    limit: int = 100,
    only_unauthorized: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    prop = get_property_for_user(db, property_id, current_user.id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    events = get_events_for_property(
        db, property_id, limit=limit, only_unauthorized=only_unauthorized
    )
    return FaceDetectionListResponse(
        success=True,
        count=len(events),
        events=[FaceDetectionEventResponse.model_validate(e) for e in events],
    )


@router.get("/cameras/{camera_id}/events", response_model=FaceDetectionListResponse)
def list_camera_events(
    camera_id: int,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    events = get_events_for_camera(db, camera_id, limit=limit)
    return FaceDetectionListResponse(
        success=True,
        count=len(events),
        events=[FaceDetectionEventResponse.model_validate(e) for e in events],
    )


@router.get("/events/{event_id}", response_model=FaceDetectionEventResponse)
def get_single_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    event = get_event(db, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return FaceDetectionEventResponse.model_validate(event)


@router.delete("/events/{event_id}")
def remove_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    ok = delete_event(db, event_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Event not found")
    return {"success": True, "message": f"Event {event_id} deleted"}


# ─── FACE ENCODING ──────────────────────────────────────────────────────────

@router.post("/encode-person", response_model=EncodeFaceResponse)
def encode_person_faces(
    request: EncodeFaceRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Re-compute and store face encodings for an authorized person.
    Call this after adding / updating a person's photos.
    """
    person = get_person(db, request.person_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")

    photo_urls: list = person.photo_urls or []
    if not photo_urls:
        raise HTTPException(status_code=400, detail="Person has no photos")

    # Convert URL paths to local filesystem paths
    # Assumption: photo_urls like "/uploads/people/xxx.jpg" → "uploads/people/xxx.jpg"
    local_paths = []
    for url in photo_urls:
        local = url.lstrip("/")
        if os.path.exists(local):
            local_paths.append(local)
        else:
            logger.warning(f"Photo not found on disk: {local}")

    if not local_paths:
        raise HTTPException(
            status_code=400,
            detail="No valid photos found on disk — upload photos first",
        )

    encodings = FaceRecognitionService.encode_all_photos_for_person(local_paths)

    if not encodings:
        raise HTTPException(
            status_code=422,
            detail="Could not extract face from any of the photos. "
                   "Ensure photos show a clear frontal face.",
        )

    person.face_encodings = encodings
    db.commit()

    logger.info(
        f"Encoded {len(encodings)} faces for person {person.id} ({person.name})"
    )
    return EncodeFaceResponse(
        success=True,
        message=f"Successfully encoded {len(encodings)} face(s)",
        person_id=person.id,
        encodings_count=len(encodings),
    )


# ─── MANAGER CONTROL ────────────────────────────────────────────────────────

@router.get("/status", response_model=FaceDetectionStatusResponse)
def detection_status(current_user=Depends(get_current_user)):
    """Return running status of all face detection workers."""
    return FaceDetectionStatusResponse(
        success=True,
        running_cameras=face_detection_manager.status(),
    )


@router.post("/cameras/{camera_id}/start")
def start_camera_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    if camera.camera_type != "entrance":
        raise HTTPException(status_code=400, detail="Only entrance cameras support face detection")

    face_detection_manager.start_camera(
        camera_id=camera.id,
        rtsp_url=camera.rtsp_url,
        property_id=camera.property_id,
    )
    return {"success": True, "message": f"Face detection started for camera {camera_id}"}


@router.post("/cameras/{camera_id}/stop")
def stop_camera_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    face_detection_manager.stop_camera(camera_id)
    return {"success": True, "message": f"Face detection stopped for camera {camera_id}"}


@router.post("/cameras/{camera_id}/restart")
def restart_camera_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    face_detection_manager.restart_camera(
        camera_id=camera.id,
        rtsp_url=camera.rtsp_url,
        property_id=camera.property_id,
    )
    return {"success": True, "message": f"Face detection restarted for camera {camera_id}"}