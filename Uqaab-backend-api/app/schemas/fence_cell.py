# app/schemas/fence_cell.py
from pydantic import BaseModel
from typing import List
from app.schemas.fence_config import Point          # reuse existing Point(x, y)


class FenceCellCreate(BaseModel):
    cell_name: str          # "A1"
    row: int
    col: int
    polygon_points: List[Point]


class FenceCellResponse(BaseModel):
    id: int
    camera_id: int
    cell_name: str
    row: int
    col: int
    polygon_points: List[Point]

    class Config:
        from_attributes = True


class FenceCellListResponse(BaseModel):
    success: bool
    message: str
    cells: List[FenceCellResponse] = []


class SaveCellsRequest(BaseModel):
    """
    Android / frontend sends the full list of cells in one shot.
    Backend replaces all existing cells for this camera.
    """
    cells: List[FenceCellCreate]