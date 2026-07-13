# app/crud/fence_cell.py
from typing import List
from sqlalchemy.orm import Session
from app.models.fence_cell import FenceCell
from app.schemas.fence_cell import FenceCellCreate


def get_cells(db: Session, camera_id: int) -> List[FenceCell]:
    return (
        db.query(FenceCell)
        .filter(FenceCell.camera_id == camera_id)
        .order_by(FenceCell.row, FenceCell.col)
        .all()
    )


def replace_cells(
    db: Session, camera_id: int, cells: List[FenceCellCreate]
) -> List[FenceCell]:
    """Delete all existing cells for camera and insert new ones atomically."""
    db.query(FenceCell).filter(FenceCell.camera_id == camera_id).delete()

    db_cells = []
    for c in cells:
        db_cell = FenceCell(
            camera_id=camera_id,
            cell_name=c.cell_name,
            row=c.row,
            col=c.col,
            polygon_points=[p.model_dump() for p in c.polygon_points],
        )
        db.add(db_cell)
        db_cells.append(db_cell)

    db.commit()
    for cell in db_cells:
        db.refresh(cell)
    return db_cells


def delete_cells(db: Session, camera_id: int) -> int:
    deleted = (
        db.query(FenceCell)
        .filter(FenceCell.camera_id == camera_id)
        .delete()
    )
    db.commit()
    return deleted