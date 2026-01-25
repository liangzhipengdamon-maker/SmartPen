"""
Character Data Models - 汉字数据模型

Defines Pydantic models for Hanzi Writer character data and internal representations.
Supports both 1024-grid coordinates (Hanzi Writer) and normalized 0-1 coordinates (InkSight).
"""

from pydantic import BaseModel, Field, field_validator
from typing import List, Tuple, Dict, Optional, Union
from enum import Enum


class CoordinateSystem(str, Enum):
    """Coordinate system types"""
    HANZI_1024 = "hanzi_1024"      # Hanzi Writer: 0-1024 grid
    NORMALIZED = "normalized"       # InkSight/Internal: 0-1 float
    SCREEN_PIXELS = "screen_pixels"  # Flutter: device pixels


class StrokePath(BaseModel):
    """SVG path string for rendering (Hanzi Writer "skin")"""
    path: str = Field(..., description="SVG path data (e.g., 'M 300 100 Q ...')")
    stroke_order: int = Field(..., ge=0, description="Stroke order index (0-based)")


class MedianPoint(BaseModel):
    """Single point in a stroke trajectory"""
    x: float = Field(..., ge=0, le=1, description="X coordinate (normalized 0-1)")
    y: float = Field(..., ge=0, le=1, description="Y coordinate (normalized 0-1)")

    @classmethod
    def from_hanzi_1024(cls, x: int, y: int) -> "MedianPoint":
        """Create from Hanzi Writer 1024-grid coordinates"""
        return cls(x=x / 1024.0, y=y / 1024.0)

    def to_hanzi_1024(self) -> Tuple[int, int]:
        """Convert to Hanzi Writer 1024-grid coordinates"""
        return (int(self.x * 1024), int(self.y * 1024))


class StrokeMedian(BaseModel):
    """Stroke trajectory data (Hanzi Writer "bone") for scoring"""
    points: List[MedianPoint] = Field(
        ..., min_length=1, description="Sequence of points in the stroke"
    )
    stroke_order: int = Field(..., ge=0, description="Stroke order index (0-based)")

    @classmethod
    def from_hanzi_1024(cls, points: List[Tuple[int, int]], stroke_order: int) -> "StrokeMedian":
        """Create from Hanzi Writer 1024-grid coordinates"""
        return cls(
            points=[MedianPoint.from_hanzi_1024(x, y) for x, y in points],
            stroke_order=stroke_order
        )

    def to_hanzi_1024(self) -> List[Tuple[int, int]]:
        """Convert to Hanzi Writer 1024-grid coordinates"""
        return [p.to_hanzi_1024() for p in self.points]


class RadicalData(BaseModel):
    """Character radical (component) information"""
    symbol: str = Field(..., description="Radical symbol")
    meaning: Optional[str] = Field(None, description="Radical meaning")
    position: Optional[str] = Field(None, description="Position in character")


class CharacterSource(str, Enum):
    """Character data source"""
    HANZI_WRITER = "hanzi-writer-data"    # CDN data
    CUSTOM = "custom"                      # User-created template
    INKSIGHT = "inksight"                 # AI-generated from image


class CharacterData(BaseModel):
    """
    Complete character data model

    Combines rendering data (strokes) and scoring data (medians).
    Coordinates stored in normalized 0-1 format for internal consistency.
    """

    # Core identity
    character: str = Field(..., min_length=1, max_length=1, description="Single Chinese character")
    source: CharacterSource = Field(
        default=CharacterSource.HANZI_WRITER,
        description="Data source"
    )

    # Rendering data (Hanzi Writer "skin")
    strokes: List[StrokePath] = Field(
        ..., min_length=1, description="SVG paths for rendering"
    )

    # Scoring data (Hanzi Writer "bone")
    medians: List[StrokeMedian] = Field(
        ..., min_length=1, description="Stroke trajectories for DTW scoring"
    )

    # Optional metadata
    radicals: Optional[Dict[str, RadicalData]] = Field(
        None, description="Character radical components"
    )

    @field_validator("medians")
    @classmethod
    def validate_stroke_count(cls, v: List[StrokeMedian], info) -> List[StrokeMedian]:
        """Validate that medians and strokes have matching counts"""
        if "strokes" in info.data and len(v) != len(info.data["strokes"]):
            raise ValueError(
                f"Stroke count mismatch: {len(v)} medians vs {len(info.data['strokes'])} strokes"
            )
        return v

    @field_validator("medians")
    @classmethod
    def validate_stroke_order(cls, v: List[StrokeMedian]) -> List[StrokeMedian]:
        """Validate that stroke orders are sequential starting from 0"""
        orders = [m.stroke_order for m in v]
        expected = list(range(len(v)))
        if orders != expected:
            raise ValueError(
                f"Invalid stroke orders: {orders}. Expected sequential: {expected}"
            )
        return v

    @classmethod
    def from_hanzi_writer(cls, data: dict, character: str = None) -> "CharacterData":
        """
        Create CharacterData from Hanzi Writer CDN JSON format

        Args:
            data: Hanzi Writer JSON dict with keys:
                  - strokes: List[str] (SVG paths)
                  - medians: List[List[Tuple[int, int]]] (1024-grid coordinates)
                  - radicals: dict (optional)
            character: Character string (required if not in data dict)

        Returns:
            CharacterData with normalized coordinates
        """
        # Character may be in data dict or passed as parameter (inferred from URL)
        char_value = data.get("character", character)

        strokes = [
            StrokePath(path=path, stroke_order=i)
            for i, path in enumerate(data["strokes"])
        ]

        medians = [
            StrokeMedian.from_hanzi_1024(points=points, stroke_order=i)
            for i, points in enumerate(data["medians"])
        ]

        return cls(
            character=char_value,
            source=CharacterSource.HANZI_WRITER,
            strokes=strokes,
            medians=medians,
            radicals=data.get("radicals")
        )

    def to_hanzi_writer_format(self) -> dict:
        """
        Export to Hanzi Writer JSON format (1024-grid coordinates)

        Returns:
            dict compatible with Hanzi Writer data structure
        """
        # Serialize radicals to dict if present
        radicals_dict = None
        if self.radicals:
            radicals_dict = {
                k: v.model_dump(exclude_none=True) for k, v in self.radicals.items()
            }

        return {
            "character": self.character,
            "strokes": [s.path for s in self.strokes],
            "medians": [[list(p) for p in m.to_hanzi_1024()] for m in self.medians],
            "radicals": radicals_dict
        }

    def to_api_response(self) -> dict:
        """
        Convert to API response format (normalized coordinates)

        Returns:
            dict for JSON serialization
        """
        return {
            "character": self.character,
            "source": self.source.value,
            "strokes": [
                {
                    "path": s.path,
                    "stroke_order": s.stroke_order,
                    "points": [{"x": p.x, "y": p.y} for p in self.medians[s.stroke_order].points]
                }
                for s in self.strokes
            ],
            "medians": [
                {
                    "points": [[p.x, p.y] for p in m.points],
                    "stroke_order": m.stroke_order
                }
                for m in self.medians
            ],
            "radicals": self.radicals
        }


class CharacterRequest(BaseModel):
    """Request model for character data queries"""
    character: str = Field(..., min_length=1, max_length=1, description="Single Chinese character")
    coordinate_system: CoordinateSystem = Field(
        default=CoordinateSystem.NORMALIZED,
        description="Desired coordinate system for response"
    )
