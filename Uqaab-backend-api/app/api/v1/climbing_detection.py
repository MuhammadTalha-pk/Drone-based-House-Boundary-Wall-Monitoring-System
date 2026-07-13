# # app/api/v1/climbing_detection.py

# from fastapi import APIRouter, Depends, HTTPException
# from sqlalchemy.orm import Session

# from app.core.database import get_db
# from app.api.v1.auth import get_current_user
# from app.crud.settings import get_camera
# from app.models.fence_config import FenceConfig
# from app.services.detection_manager import detection_manager

# router = APIRouter()


# @router.post("/{camera_id}/start")
# def start_detection(
#     camera_id: int,
#     db: Session = Depends(get_db),
#     current_user=Depends(get_current_user),
# ):
#     camera = get_camera(db, camera_id)
#     if not camera:
#         raise HTTPException(status_code=404, detail="Camera not found")
#     if camera.camera_type != "fence":
#         raise HTTPException(
#             status_code=400,
#             detail="Only fence cameras support wall climbing detection"
#         )

#     config = (
#         db.query(FenceConfig)
#         .filter(FenceConfig.camera_id == camera_id)
#         .first()
#     )
#     if not config or not config.polygon_points:
#         raise HTTPException(
#             status_code=400,
#             detail="No polygon configured. Please calibrate this camera first."
#         )

#     detection_manager.start_camera(
#         camera_id=camera.id,
#         camera_name=camera.name,
#         rtsp_url=camera.rtsp_url,
#         polygon=config.polygon_points,
#         property_id=camera.property_id,
#         camera_cell_row=camera.grid_cell_row,
#         camera_cell_col=camera.grid_cell_col,
#     )

#     return {
#         "success": True,
#         "message": f"Wall climbing detection started for camera '{camera.name}'"
#     }


# @router.post("/{camera_id}/stop")
# def stop_detection(
#     camera_id: int,
#     current_user=Depends(get_current_user),
# ):
#     detection_manager.stop_camera(camera_id)
#     return {
#         "success": True,
#         "message": f"Wall climbing detection stopped for camera {camera_id}"
#     }


# @router.post("/{camera_id}/restart")
# def restart_detection(
#     camera_id: int,
#     db: Session = Depends(get_db),
#     current_user=Depends(get_current_user),
# ):
#     """Call this after updating polygon points to apply new config"""
#     camera = get_camera(db, camera_id)
#     if not camera:
#         raise HTTPException(status_code=404, detail="Camera not found")

#     config = (
#         db.query(FenceConfig)
#         .filter(FenceConfig.camera_id == camera_id)
#         .first()
#     )
#     if not config or not config.polygon_points:
#         raise HTTPException(
#             status_code=400,
#             detail="No polygon configured. Please calibrate first."
#         )

#     detection_manager.stop_camera(camera_id)
#     detection_manager.start_camera(
#         camera_id=camera.id,
#         camera_name=camera.name,
#         rtsp_url=camera.rtsp_url,
#         polygon=config.polygon_points,
#         property_id=camera.property_id,
#         camera_cell_row=camera.grid_cell_row,
#         camera_cell_col=camera.grid_cell_col,
#     )

#     return {
#         "success": True,
#         "message": f"Detection restarted for camera '{camera.name}' with updated polygon"
#     }


# @router.get("/status")
# def get_status(
#     current_user=Depends(get_current_user),
# ):
#     """Get status of all running detection threads"""
#     return {
#         "success": True,
#         "initialized": detection_manager.is_initialized,
#         "detectors": detection_manager.get_status(),
#     }

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.auth import get_current_user
from app.crud.settings import get_camera
from app.models.fence_config import FenceConfig
from app.services.detection_manager import detection_manager

router = APIRouter()


@router.post("/{camera_id}/start")
def start_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    if camera.camera_type != "fence":
        raise HTTPException(status_code=400, detail="Only fence cameras supported")

    config = db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).first()
    if not config or not config.polygon_points:
        raise HTTPException(status_code=400, detail="No polygon configured")

    detection_manager.start_camera(
        camera_id=camera.id,
        camera_name=camera.name,
        rtsp_url=camera.rtsp_url,
        polygon=config.polygon_points,
        property_id=camera.property_id,
        camera_cell_row=camera.grid_cell_row,
        camera_cell_col=camera.grid_cell_col,
    )
    return {"success": True, "message": f"Detection started for '{camera.name}'"}


@router.post("/{camera_id}/stop")
def stop_detection(camera_id: int, current_user=Depends(get_current_user)):
    detection_manager.stop_camera(camera_id)
    return {"success": True, "message": f"Detection stopped for camera {camera_id}"}


@router.post("/{camera_id}/restart")
def restart_detection(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    config = db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).first()
    if not config or not config.polygon_points:
        raise HTTPException(status_code=400, detail="No polygon configured")

    detection_manager.restart_camera(
        camera_id=camera.id,
        camera_name=camera.name,
        rtsp_url=camera.rtsp_url,
        polygon=config.polygon_points,
        property_id=camera.property_id,
        camera_cell_row=camera.grid_cell_row,
        camera_cell_col=camera.grid_cell_col,
    )
    return {"success": True, "message": f"Detection restarted for '{camera.name}'"}


@router.get("/status")
def get_status(current_user=Depends(get_current_user)):
    return {
        "success": True,
        "initialized": detection_manager.is_initialized,
        "detectors": detection_manager.get_status(),
    }