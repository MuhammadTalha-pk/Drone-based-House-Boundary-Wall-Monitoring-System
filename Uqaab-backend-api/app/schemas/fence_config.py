from typing import List, Optional
from pydantic import BaseModel


class Point(BaseModel):
    x: float
    y: float


class FenceConfigCreate(BaseModel):
    polygon_points: List[Point]


class FenceConfigResponse(BaseModel):
    id: int
    camera_id: int
    polygon_points: Optional[List[Point]]
    is_active: bool

    class Config:
        from_attributes = True


# ==================== CELL SCHEMAS ====================

class CellDefinition(BaseModel):
    cell_id: int
    label: str
    polygon: List[List[float]]  # [[x1, y1], [x2, y2], ...]


class CellsConfigSave(BaseModel):
    image_width: int
    image_height: int
    cells: List[CellDefinition]


class CellsConfigResponse(BaseModel):
    camera_id: int
    image_width: Optional[int] = None
    image_height: Optional[int] = None
    cells: List[CellDefinition] = []

    class Config:
        from_attributes = True