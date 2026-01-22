"""
Models package - Data models for SmartPen backend

Exports all Pydantic models for use in API and business logic.
"""

from app.models.character import (
    CharacterData,
    CharacterRequest,
    CharacterSource,
    CoordinateSystem,
    MedianPoint,
    StrokeMedian,
    StrokePath,
    RadicalData,
)

from app.models.inksight import (
    InkSightModel,
    InksightResult,
    map_inksight_to_hanzi_1024,
    map_hanzi_1024_to_inksight,
    convert_to_hanzi_writer_format,
)

from app.models.model_loader import (
    get_model_cache_dir,
    get_inksight_model_path,
    is_model_cached,
    get_huggingface_model_id,
)

__all__ = [
    # Character models
    "CharacterData",
    "CharacterRequest",
    "CharacterSource",
    "CoordinateSystem",
    "MedianPoint",
    "StrokeMedian",
    "StrokePath",
    "RadicalData",
    # InkSight models
    "InkSightModel",
    "InksightResult",
    "map_inksight_to_hanzi_1024",
    "map_hanzi_1024_to_inksight",
    "convert_to_hanzi_writer_format",
    # Model loader
    "get_model_cache_dir",
    "get_inksight_model_path",
    "is_model_cached",
    "get_huggingface_model_id",
]
