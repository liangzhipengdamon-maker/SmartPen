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


from app.models.paddle_ocr import (
    PaddleOCRModel,
    OCRResult,
    verify_character_match,
    preprocess_ocr_image,
)

from app.models.model_loader import (
    get_model_cache_dir,
    is_model_cached,
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
    # PaddleOCR models
    "PaddleOCRModel",
    "OCRResult",
    "verify_character_match",
    "preprocess_ocr_image",
    # Model loader
    "get_model_cache_dir",
    "is_model_cached",
]
