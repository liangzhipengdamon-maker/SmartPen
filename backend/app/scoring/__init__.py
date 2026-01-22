"""
Scoring package - Score normalization and character evaluation

Exports scoring functions for converting DTW distances to meaningful scores.
"""

from app.scoring.normalizer import (
    normalize_score,
    calculate_character_score,
    ScoreBreakdown,
)

__all__ = [
    "normalize_score",
    "calculate_character_score",
    "ScoreBreakdown",
]
