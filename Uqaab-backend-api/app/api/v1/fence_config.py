# app/api/v1/fence_config.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.schemas.fence_config import FenceConfigResponse, Point
from app.schemas.fence_cell import (
    SaveCellsRequest, FenceCellListResponse, FenceCellResponse
)
from app.models.fence_config import FenceConfig
from app.api.v1.auth import get_current_user
from app.crud.settings import get_camera
from app.crud.fence_cell import get_cells, replace_cells, delete_cells
from app.services.detection_manager import detection_manager

router = APIRouter()


# ─── POLYGON (fence cameras only) ────────────────────────────────────────────

@router.post("/cameras/{camera_id}/fence-config", response_model=FenceConfigResponse)
def create_or_update_fence_config(
    camera_id: int,
    points: List[Point],
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")
    if camera.camera_type != "fence":
        raise HTTPException(status_code=400, detail="Camera must be a fence camera")
    if len(points) < 3:
        raise HTTPException(status_code=400, detail="Polygon needs at least 3 points")

    existing = db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).first()
    points_data = [p.model_dump() for p in points]

    if existing:
        existing.polygon_points = points_data
        existing.is_active = 1
        db.commit()
        db.refresh(existing)
        config = existing
    else:
        config = FenceConfig(camera_id=camera_id, polygon_points=points_data, is_active=1)
        db.add(config)
        db.commit()
        db.refresh(config)

    # Auto-start detection
    try:
        detection_manager.stop_camera(camera.id)
        detection_manager.start_camera(
            camera_id=camera.id,
            camera_name=camera.name,
            rtsp_url=camera.rtsp_url,
            polygon=points_data,
            property_id=camera.property_id,
            camera_cell_row=camera.grid_cell_row,
            camera_cell_col=camera.grid_cell_col,
        )
    except Exception as e:
        print(f"⚠️ Could not start detection: {e}")

    return config


@router.get("/cameras/{camera_id}/fence-config", response_model=FenceConfigResponse)
def get_fence_config(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    config = db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Fence config not found")
    return config


@router.delete("/cameras/{camera_id}/fence-config")
def delete_fence_config(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    config = db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).first()
    if not config:
        raise HTTPException(status_code=404, detail="Fence config not found")

    detection_manager.stop_camera(camera_id)
    # Also wipe cells when polygon is removed
    delete_cells(db, camera_id)
    db.delete(config)
    db.commit()
    return {"success": True, "message": "Fence config and cells deleted"}


# ─── CELLS (ALL camera types) ─────────────────────────────────────────────────

@router.post("/cameras/{camera_id}/cells", response_model=FenceCellListResponse)
def save_cells(
    camera_id: int,
    request: SaveCellsRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Replace all cells for this camera with the submitted list.
    Works for ALL camera types (fence, entrance, insider).
    For fence cameras, the polygon config must exist first.
    Frontend sends the complete cell grid after user finishes drawing.
    """
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    # For fence cameras: polygon must exist first
    if camera.camera_type == "fence":
        config = db.query(FenceConfig).filter(FenceConfig.camera_id == camera_id).first()
        if not config:
            raise HTTPException(
                status_code=400,
                detail="Draw the fence polygon before defining cells",
            )

    if not request.cells:
        raise HTTPException(status_code=400, detail="No cells provided")

    # Validate each cell has exactly 4 points
    for cell in request.cells:
        if len(cell.polygon_points) != 4:
            raise HTTPException(
                status_code=400,
                detail=f"Cell {cell.cell_name} must have exactly 4 points",
            )

    db_cells = replace_cells(db, camera_id, request.cells)

    return FenceCellListResponse(
        success=True,
        message=f"Saved {len(db_cells)} cells for camera {camera_id}",
        cells=[FenceCellResponse.model_validate(c) for c in db_cells],
    )


@router.get("/cameras/{camera_id}/cells", response_model=FenceCellListResponse)
def list_cells(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Return all cells for a camera (any type), ordered by row then col."""
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    cells = get_cells(db, camera_id)
    return FenceCellListResponse(
        success=True,
        message=f"Found {len(cells)} cells",
        cells=[FenceCellResponse.model_validate(c) for c in cells],
    )


@router.delete("/cameras/{camera_id}/cells")
def clear_cells(
    camera_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Delete all cells for a camera (any type)."""
    camera = get_camera(db, camera_id)
    if not camera:
        raise HTTPException(status_code=404, detail="Camera not found")

    deleted = delete_cells(db, camera_id)
    return {"success": True, "message": f"Deleted {deleted} cells"}