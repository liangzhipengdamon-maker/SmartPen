"""
Scoring package - Score normalization and character evaluation

Exports scoring functions for converting DTW distances to meaningful scores.
"""

from app.scoring.normalizer import (
    normalize_score,
    calculate_character_score,
    ScoreBreakdown,
)

from app.scoring.stroke_order import (
    validate_stroke_order,
    StrokeOrderResult,
    detect_stroke_direction,
    StrokeDirection,
)

__all__ = [
    "normalize_score",
    "calculate_character_score",
    "ScoreBreakdown",
    "validate_stroke_order",
    "StrokeOrderResult",
    "detect_stroke_direction",
    "StrokeDirection",
]
