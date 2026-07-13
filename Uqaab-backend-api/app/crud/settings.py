# from sqlalchemy.orm import Session
# from typing import List, Optional
# from app.models.camera import Camera
# from app.models.drone import Drone
# from app.models.authorized_person import AuthorizedPerson
# from app.models.flight_log import FlightLog
# from app.schemas.settings import (
#     CameraCreateRequest, CameraUpdateRequest,
#     DroneCreateRequest, DroneUpdateRequest,
#     PersonCreateRequest, PersonUpdateRequest,
#     FlightLogCreateRequest,
# )
# from app.services.face_recognition_service import FaceRecognitionService
# import os

# def _get_local_path(url: str) -> str:
#     # URL is like "/uploads/people/xxx.jpg"
#     # Local path should be "uploads/people/xxx.jpg"
#     if url.startswith("/"):
#         return url[1:]
#     return url


# # ==================== CAMERA CRUD ====================

# def get_cameras(db: Session, property_id: int) -> List[Camera]:
#     return db.query(Camera).filter(Camera.property_id == property_id).all()


# def get_camera(db: Session, camera_id: int) -> Optional[Camera]:
#     return db.query(Camera).filter(Camera.id == camera_id).first()

# def create_camera(db: Session, property_id: int, request: CameraCreateRequest) -> Camera:
#     db_camera = Camera(
#         property_id=property_id,
#         name=request.name,
#         rtsp_url=request.rtsp_url,
#         camera_type=request.camera_type,
#         grid_cell_row=request.grid_cell.row,
#         grid_cell_col=request.grid_cell.col,
#     )
#     db.add(db_camera)
#     db.commit()
#     db.refresh(db_camera)
#     return db_camera


# def update_camera(db: Session, camera_id: int, request: CameraUpdateRequest) -> Optional[Camera]:
#     db_camera = get_camera(db, camera_id)
#     if not db_camera:
#         return None
#     if request.name is not None:
#         db_camera.name = request.name
#     if request.rtsp_url is not None:
#         db_camera.rtsp_url = request.rtsp_url
#     if request.camera_type is not None:
#         db_camera.camera_type = request.camera_type
#     if request.grid_cell is not None:
#         db_camera.grid_cell_row = request.grid_cell.row
#         db_camera.grid_cell_col = request.grid_cell.col
#     db.commit()
#     db.refresh(db_camera)
#     return db_camera


# def delete_camera(db: Session, camera_id: int) -> bool:
#     db_camera = get_camera(db, camera_id)
#     if not db_camera:
#         return False
    
#     # Explicitly clean up related records first
#     from app.models.fence_config import FenceConfig
#     from app.models.fence_cell import FenceCell
    
#     db.query(FenceCell).filter(FenceCell.camera_id == camera_id).delete(synchronize_session=False)
#     db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).delete(synchronize_session=False)
    
#     db.delete(db_camera)
#     db.commit()
#     return True

# # ==================== DRONE CRUD ====================

# def get_drones(db: Session, property_id: int) -> List[Drone]:
#     return db.query(Drone).filter(Drone.property_id == property_id).all()


# def get_drone(db: Session, drone_id: int) -> Optional[Drone]:
#     return db.query(Drone).filter(Drone.id == drone_id).first()


# def create_drone(db: Session, property_id: int, request: DroneCreateRequest) -> Drone:
#     db_drone = Drone(
#         property_id=property_id,
#         name=request.name,
#         connection_string=request.connection_string,
#         status="Offline",
#         home_cell_row=request.home_cell.row,
#         home_cell_col=request.home_cell.col,
#     )
#     db.add(db_drone)
#     db.commit()
#     db.refresh(db_drone)
#     return db_drone


# def update_drone(db: Session, drone_id: int, request: DroneUpdateRequest) -> Optional[Drone]:
#     db_drone = get_drone(db, drone_id)
#     if not db_drone:
#         return None
#     if request.name is not None:
#         db_drone.name = request.name
#     if request.connection_string is not None:
#         db_drone.connection_string = request.connection_string
#     if request.home_cell is not None:
#         db_drone.home_cell_row = request.home_cell.row
#         db_drone.home_cell_col = request.home_cell.col
#     db.commit()
#     db.refresh(db_drone)
#     return db_drone


# def delete_drone(db: Session, drone_id: int) -> bool:
#     db_drone = get_drone(db, drone_id)
#     if not db_drone:
#         return False
#     db.delete(db_drone)
#     db.commit()
#     return True


# # ==================== AUTHORIZED PERSON CRUD (UPDATED) ====================

# def get_people(db: Session, property_id: int) -> List[AuthorizedPerson]:
#     return db.query(AuthorizedPerson).filter(AuthorizedPerson.property_id == property_id).all()


# def get_person(db: Session, person_id: int) -> Optional[AuthorizedPerson]:
#     return db.query(AuthorizedPerson).filter(AuthorizedPerson.id == person_id).first()


# def create_person(db: Session, property_id: int, request: PersonCreateRequest) -> AuthorizedPerson:
#     encodings = []
#     if request.photo_urls:
#         local_paths = [_get_local_path(url) for url in request.photo_urls]
#         encodings = FaceRecognitionService.encode_all_photos_for_person(local_paths)

#     db_person = AuthorizedPerson(
#         property_id=property_id,
#         name=request.name,
#         role=request.role,   # ✅ renamed from relationship_type
#         photo_urls=request.photo_urls,
#         face_encodings=encodings,
#     )
#     db.add(db_person)
#     db.commit()
#     db.refresh(db_person)
#     return db_person


# def update_person(db: Session, person_id: int, request: PersonUpdateRequest) -> Optional[AuthorizedPerson]:
#     db_person = get_person(db, person_id)
#     if not db_person:
#         return None
#     if request.name is not None:
#         db_person.name = request.name
#     if request.role is not None:   # ✅ renamed
#         db_person.role = request.role
#     if request.photo_urls is not None:
#         db_person.photo_urls = request.photo_urls
#         # Update encodings
#         local_paths = [_get_local_path(url) for url in request.photo_urls]
#         db_person.face_encodings = FaceRecognitionService.encode_all_photos_for_person(local_paths)
#     db.commit()
#     db.refresh(db_person)
#     return db_person


# def delete_person(db: Session, person_id: int) -> bool:
#     db_person = get_person(db, person_id)
#     if not db_person:
#         return False
#     db.delete(db_person)
#     db.commit()
#     return True


# # ==================== FLIGHT LOG CRUD ====================

# def get_flight_logs(db: Session, property_id: int) -> List[FlightLog]:
#     return db.query(FlightLog).filter(
#         FlightLog.property_id == property_id
#     ).order_by(FlightLog.created_at.desc()).all()


# def create_flight_log(db: Session, property_id: int, request: FlightLogCreateRequest) -> FlightLog:
#     db_log = FlightLog(
#         property_id=property_id,
#         drone_id=request.drone_id,
#         drone_name=request.drone_name,
#         flight_type=request.flight_type,
#         takeoff_time=request.takeoff_time,
#         land_time=request.land_time,
#     )
#     db.add(db_log)
#     db.commit()
#     db.refresh(db_log)
#     return db_log

from sqlalchemy.orm import Session
from typing import List, Optional
from app.models.camera import Camera
from app.models.drone import Drone
from app.models.authorized_person import AuthorizedPerson
from app.models.flight_log import FlightLog
from app.schemas.settings import (
    CameraCreateRequest, CameraUpdateRequest,
    DroneCreateRequest, DroneUpdateRequest,
    PersonCreateRequest, PersonUpdateRequest,
    FlightLogCreateRequest,
)
from app.services.face_recognition_service import FaceRecognitionService
import os

def _get_local_path(url: str) -> str:
    if url.startswith("/"):
        return url[1:]
    return url


# ==================== CAMERA CRUD ====================

def get_cameras(db: Session, property_id: int) -> List[Camera]:
    return db.query(Camera).filter(Camera.property_id == property_id).all()


def get_camera(db: Session, camera_id: int) -> Optional[Camera]:
    return db.query(Camera).filter(Camera.id == camera_id).first()


def create_camera(db: Session, property_id: int, request: CameraCreateRequest) -> Camera:
    db_camera = Camera(
        property_id=property_id,
        name=request.name,
        rtsp_url=request.rtsp_url,
        camera_type=request.camera_type,
        grid_cell_row=request.grid_cell.row,
        grid_cell_col=request.grid_cell.col,
    )
    db.add(db_camera)
    db.commit()
    db.refresh(db_camera)
    return db_camera


def update_camera(db: Session, camera_id: int, request: CameraUpdateRequest) -> Optional[Camera]:
    from app.models.fence_config import FenceConfig
    from app.models.fence_cell import FenceCell

    db_camera = get_camera(db, camera_id)
    if not db_camera:
        return None

    old_type = db_camera.camera_type

    if request.name is not None:
        db_camera.name = request.name
    if request.rtsp_url is not None:
        db_camera.rtsp_url = request.rtsp_url
    if request.camera_type is not None:
        db_camera.camera_type = request.camera_type
    if request.grid_cell is not None:
        db_camera.grid_cell_row = request.grid_cell.row
        db_camera.grid_cell_col = request.grid_cell.col

    # ✅ FIX: clean up stale config whenever camera type changes
    if request.camera_type is not None and request.camera_type != old_type:
        # Always wipe cells — they are type-specific for both fence and insider
        db.query(FenceCell).filter(
            FenceCell.camera_id == camera_id
        ).delete(synchronize_session=False)

        # Wipe fence polygon only when leaving fence type
        if old_type == "fence":
            db.query(FenceConfig).filter(
                FenceConfig.camera_id == camera_id
            ).delete(synchronize_session=False)

    db.commit()
    db.refresh(db_camera)
    return db_camera


def delete_camera(db: Session, camera_id: int) -> bool:
    db_camera = get_camera(db, camera_id)
    if not db_camera:
        return False

    from app.models.fence_config import FenceConfig
    from app.models.fence_cell import FenceCell

    db.query(FenceCell).filter(FenceCell.camera_id == camera_id).delete(synchronize_session=False)
    db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).delete(synchronize_session=False)

    db.delete(db_camera)
    db.commit()
    return True


# ==================== DRONE CRUD ====================

def get_drones(db: Session, property_id: int) -> List[Drone]:
    return db.query(Drone).filter(Drone.property_id == property_id).all()


def get_drone(db: Session, drone_id: int) -> Optional[Drone]:
    return db.query(Drone).filter(Drone.id == drone_id).first()


def create_drone(db: Session, property_id: int, request: DroneCreateRequest) -> Drone:
    db_drone = Drone(
        property_id=property_id,
        name=request.name,
        connection_string=request.connection_string,
        status="Offline",
        home_cell_row=request.home_cell.row,
        home_cell_col=request.home_cell.col,
    )
    db.add(db_drone)
    db.commit()
    db.refresh(db_drone)
    return db_drone


def update_drone(db: Session, drone_id: int, request: DroneUpdateRequest) -> Optional[Drone]:
    db_drone = get_drone(db, drone_id)
    if not db_drone:
        return None
    if request.name is not None:
        db_drone.name = request.name
    if request.connection_string is not None:
        db_drone.connection_string = request.connection_string
    if request.home_cell is not None:
        db_drone.home_cell_row = request.home_cell.row
        db_drone.home_cell_col = request.home_cell.col
    db.commit()
    db.refresh(db_drone)
    return db_drone


def delete_drone(db: Session, drone_id: int) -> bool:
    db_drone = get_drone(db, drone_id)
    if not db_drone:
        return False
    db.delete(db_drone)
    db.commit()
    return True


# ==================== AUTHORIZED PERSON CRUD ====================

def get_people(db: Session, property_id: int) -> List[AuthorizedPerson]:
    return db.query(AuthorizedPerson).filter(AuthorizedPerson.property_id == property_id).all()


def get_person(db: Session, person_id: int) -> Optional[AuthorizedPerson]:
    return db.query(AuthorizedPerson).filter(AuthorizedPerson.id == person_id).first()


def create_person(db: Session, property_id: int, request: PersonCreateRequest) -> AuthorizedPerson:
    encodings = []
    if request.photo_urls:
        local_paths = [_get_local_path(url) for url in request.photo_urls]
        encodings = FaceRecognitionService.encode_all_photos_for_person(local_paths)

    db_person = AuthorizedPerson(
        property_id=property_id,
        name=request.name,
        role=request.role,
        photo_urls=request.photo_urls,
        face_encodings=encodings,
    )
    db.add(db_person)
    db.commit()
    db.refresh(db_person)
    return db_person


def update_person(db: Session, person_id: int, request: PersonUpdateRequest) -> Optional[AuthorizedPerson]:
    db_person = get_person(db, person_id)
    if not db_person:
        return None
    if request.name is not None:
        db_person.name = request.name
    if request.role is not None:
        db_person.role = request.role
    if request.photo_urls is not None:
        db_person.photo_urls = request.photo_urls
        local_paths = [_get_local_path(url) for url in request.photo_urls]
        db_person.face_encodings = FaceRecognitionService.encode_all_photos_for_person(local_paths)
    db.commit()
    db.refresh(db_person)
    return db_person


def delete_person(db: Session, person_id: int) -> bool:
    db_person = get_person(db, person_id)
    if not db_person:
        return False
    db.delete(db_person)
    db.commit()
    return True


# ==================== FLIGHT LOG CRUD ====================

def get_flight_logs(db: Session, property_id: int) -> List[FlightLog]:
    return db.query(FlightLog).filter(
        FlightLog.property_id == property_id
    ).order_by(FlightLog.created_at.desc()).all()


def create_flight_log(db: Session, property_id: int, request: FlightLogCreateRequest) -> FlightLog:
    db_log = FlightLog(
        property_id=property_id,
        drone_id=request.drone_id,
        drone_name=request.drone_name,
        flight_type=request.flight_type,
        takeoff_time=request.takeoff_time,
        land_time=request.land_time,
    )
    db.add(db_log)
    db.commit()
    db.refresh(db_log)
    return db_log