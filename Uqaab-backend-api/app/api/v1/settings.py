import os
import shutil
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.schemas.settings import (
    CameraCreateRequest, CameraUpdateRequest, CameraResponse,
    CameraListResponse, CameraCreatedResponse, GridCellSchema,   # ← added CameraCreatedResponse
    DroneCreateRequest, DroneUpdateRequest, DroneResponse, DroneListResponse,
    PersonCreateRequest, PersonUpdateRequest, PersonResponse, PersonListResponse,
    FlightLogCreateRequest, FlightLogResponse, FlightLogListResponse,
    DetailResponse, RelationshipsResponse, RolesResponse,
)
from app.crud import settings as settings_crud
from app.crud import property as property_crud
from app.api.v1.auth import get_current_user

router = APIRouter()

ALLOWED_ROLES = ["Guard", "Guest", "Authorized Person"]
UPLOAD_DIR = "uploads/people"
os.makedirs(UPLOAD_DIR, exist_ok=True)


# ==================== HELPERS ====================

def verify_property_ownership(db: Session, property_id: int, user_id: int):
    prop = property_crud.get_property_for_user(db, property_id, user_id)
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")
    return prop


def camera_to_response(cam) -> CameraResponse:
    return CameraResponse(
        id=str(cam.id),
        name=cam.name,
        rtsp_url=cam.rtsp_url,
        camera_type=cam.camera_type,
        grid_cell=GridCellSchema(row=cam.grid_cell_row, col=cam.grid_cell_col),
    )


def drone_to_response(drone) -> DroneResponse:
    return DroneResponse(
        id=str(drone.id),
        name=drone.name,
        connection_string=drone.connection_string,
        status=drone.status,
        home_cell=GridCellSchema(row=drone.home_cell_row, col=drone.home_cell_col),
    )


def person_to_response(person) -> PersonResponse:
    return PersonResponse(
        id=str(person.id),
        name=person.name,
        role=person.role,
        photo_urls=person.photo_urls or [],
    )


def flight_log_to_response(log) -> FlightLogResponse:
    return FlightLogResponse(
        id=str(log.id),
        drone_name=log.drone_name,
        type=log.flight_type,
        takeoff_time=log.takeoff_time,
        land_time=log.land_time,
    )


# ==================== CAMERAS ====================

@router.get("/{property_id}/cameras", response_model=CameraListResponse)
def get_cameras(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    cameras = settings_crud.get_cameras(db, property_id)
    return CameraListResponse(
        success=True,
        message=f"Found {len(cameras)} cameras",
        cameras=[camera_to_response(c) for c in cameras],
    )


# ── CHANGED: response_model → CameraCreatedResponse, returns camera_id ────────
@router.post("/{property_id}/cameras", response_model=CameraCreatedResponse, status_code=201)
def create_camera(
    property_id: int,
    request: CameraCreateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    if not request.name.strip():
        raise HTTPException(status_code=400, detail="Camera name is required")
    if not request.rtsp_url.strip():
        raise HTTPException(status_code=400, detail="RTSP URL is required")

    new_camera = settings_crud.create_camera(db, property_id, request)  # ← capture object

    prop = property_crud.get_property(db, property_id)
    if prop:
        prop.cameras_total = len(settings_crud.get_cameras(db, property_id))
        prop.cameras_online = prop.cameras_total
        db.commit()

    return CameraCreatedResponse(
        success=True,
        message="Camera added successfully!",
        camera_id=new_camera.id,           # ← real integer ID
    )


@router.put("/cameras/{camera_id}", response_model=DetailResponse)
def update_camera(
    camera_id: int,
    request: CameraUpdateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = settings_crud.get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    verify_property_ownership(db, camera.property_id, current_user.id)
    settings_crud.update_camera(db, camera_id, request)
    return DetailResponse(success=True, message="Camera updated successfully!")


@router.delete("/cameras/{camera_id}", response_model=DetailResponse)
def delete_camera(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = settings_crud.get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    verify_property_ownership(db, camera.property_id, current_user.id)

    prop_id = camera.property_id
    settings_crud.delete_camera(db, camera_id)

    prop = property_crud.get_property(db, prop_id)
    if prop:
        prop.cameras_total = len(settings_crud.get_cameras(db, prop_id))
        prop.cameras_online = prop.cameras_total
        db.commit()

    return DetailResponse(success=True, message="Camera deleted successfully!")


# ==================== DRONES ====================

@router.get("/{property_id}/drones", response_model=DroneListResponse)
def get_drones(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    drones = settings_crud.get_drones(db, property_id)
    return DroneListResponse(
        success=True,
        message=f"Found {len(drones)} drones",
        drones=[drone_to_response(d) for d in drones],
    )


@router.post("/{property_id}/drones", response_model=DetailResponse, status_code=201)
def create_drone(
    property_id: int,
    request: DroneCreateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    if not request.name.strip():
        raise HTTPException(status_code=400, detail="Drone name is required")

    settings_crud.create_drone(db, property_id, request)

    prop = property_crud.get_property(db, property_id)
    if prop:
        drones = settings_crud.get_drones(db, property_id)
        if drones:
            prop.drone_status = "Docked"
        db.commit()

    return DetailResponse(success=True, message="Drone added successfully!")


@router.put("/drones/{drone_id}", response_model=DetailResponse)
def update_drone(
    drone_id: int,
    request: DroneUpdateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    drone = settings_crud.get_drone(db, drone_id)
    if not drone:
        raise HTTPException(status_code=404, detail="Drone not found")
    verify_property_ownership(db, drone.property_id, current_user.id)
    settings_crud.update_drone(db, drone_id, request)
    return DetailResponse(success=True, message="Drone updated successfully!")


@router.delete("/drones/{drone_id}", response_model=DetailResponse)
def delete_drone(
    drone_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    drone = settings_crud.get_drone(db, drone_id)
    if not drone:
        raise HTTPException(status_code=404, detail="Drone not found")
    verify_property_ownership(db, drone.property_id, current_user.id)

    prop_id = drone.property_id
    settings_crud.delete_drone(db, drone_id)

    prop = property_crud.get_property(db, prop_id)
    if prop:
        drones = settings_crud.get_drones(db, prop_id)
        prop.drone_status = "Docked" if drones else "Offline"
        db.commit()

    return DetailResponse(success=True, message="Drone deleted successfully!")


# ==================== FILE UPLOAD ====================

@router.post("/upload-person-image")
async def upload_person_image(
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
):
    allowed_types = {"image/jpeg", "image/png", "image/jpg", "image/webp"}
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="File type must be one of: jpeg, png, jpg, webp")

    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        file_ext = ".jpg"

    unique_name = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(UPLOAD_DIR, unique_name)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save file: {str(e)}")

    return {"url": f"/uploads/people/{unique_name}"}


# ==================== AUTHORIZED PEOPLE ====================

@router.get("/{property_id}/people", response_model=PersonListResponse)
def get_people(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    people = settings_crud.get_people(db, property_id)
    return PersonListResponse(
        success=True,
        message=f"Found {len(people)} people",
        people=[person_to_response(p) for p in people],
    )


@router.post("/{property_id}/people", response_model=DetailResponse, status_code=201)
def create_person(
    property_id: int,
    request: PersonCreateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    if not request.name.strip():
        raise HTTPException(status_code=400, detail="Name is required")
    if request.role not in ALLOWED_ROLES:
        raise HTTPException(status_code=400, detail=f"Role must be one of: {', '.join(ALLOWED_ROLES)}")
    settings_crud.create_person(db, property_id, request)
    return DetailResponse(success=True, message="Person added successfully!")


@router.put("/people/{person_id}", response_model=DetailResponse)
def update_person(
    person_id: int,
    request: PersonUpdateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    person = settings_crud.get_person(db, person_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")
    verify_property_ownership(db, person.property_id, current_user.id)
    if request.role is not None and request.role not in ALLOWED_ROLES:
        raise HTTPException(status_code=400, detail=f"Role must be one of: {', '.join(ALLOWED_ROLES)}")
    settings_crud.update_person(db, person_id, request)
    return DetailResponse(success=True, message="Person updated successfully!")


@router.delete("/people/{person_id}", response_model=DetailResponse)
def delete_person(
    person_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    person = settings_crud.get_person(db, person_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")
    verify_property_ownership(db, person.property_id, current_user.id)
    settings_crud.delete_person(db, person_id)
    return DetailResponse(success=True, message="Person deleted successfully!")


# ==================== FLIGHT LOGS ====================

@router.get("/{property_id}/flight-logs", response_model=FlightLogListResponse)
def get_flight_logs(
    property_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    logs = settings_crud.get_flight_logs(db, property_id)
    return FlightLogListResponse(
        success=True,
        message=f"Found {len(logs)} flight logs",
        flight_logs=[flight_log_to_response(l) for l in logs],
    )


@router.post("/{property_id}/flight-logs", response_model=DetailResponse, status_code=201)
def create_flight_log(
    property_id: int,
    request: FlightLogCreateRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    verify_property_ownership(db, property_id, current_user.id)
    settings_crud.create_flight_log(db, property_id, request)
    return DetailResponse(success=True, message="Flight log created!")


# ==================== ROLES ====================

@router.get("/roles", response_model=RolesResponse)
def get_roles(current_user=Depends(get_current_user)):
    return RolesResponse(success=True, roles=ALLOWED_ROLES)


@router.get("/relationships", response_model=RelationshipsResponse)
def get_relationships(current_user=Depends(get_current_user)):
    return RelationshipsResponse(success=True, relationships=ALLOWED_ROLES)