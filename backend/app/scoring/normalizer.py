"""
Score Normalizer - 评分归一化模块

Converts DTW distances and stroke similarity scores to 0-100 scale.
"""

import numpy as np
from typing import List, Optional
from pydantic import BaseModel


class ScoreBreakdown(BaseModel):
    """Detailed score breakdown for feedback"""
    total_score: float
    stroke_count: int
    expected_count: Optional[int] = None
    average_score: float = 0.0
    min_score: float = 0.0
    max_score: float = 0.0
    perfect_strokes: int = 0


def normalize_score(distance: float, max_distance: float = 1.0) -> float:
    """
    Normalize DTW distance to 0-100 score.

    Uses exponential decay: score = 100 * exp(-distance / max_distance)
    - distance = 0 -> score = 100 (perfect match)
    - distance = max_distance -> score ≈ 36.8
    - distance = 2 * max_distance -> score ≈ 13.5

    Args:
        distance: DTW distance (non-negative)
        max_distance: Reference distance for normalization (default 1.0)

    Returns:
        Score in [0, 100] range

    Examples:
        >>> normalize_score(0.0)
        100.0
        >>> normalize_score(0.5)
        ~60.65
    """
    # Ensure distance is non-negative
    distance = max(0.0, distance)

    # Exponential decay formula
    score = 100.0 * np.exp(-distance / max_distance)

    # Clamp to [0, 100]
    return float(max(0.0, min(100.0, score)))


def calculate_character_score(
    stroke_scores: List[float],
    expected_stroke_count: Optional[int] = None
) -> ScoreBreakdown:
    """
    Calculate overall character score from individual stroke scores.

    Args:
        stroke_scores: List of stroke similarity scores (0-1 each)
        expected_stroke_count: Expected number of strokes (for penalty calculation)

    Returns:
        ScoreBreakdown with detailed scoring information

    Examples:
        >>> calculate_character_score([1.0, 0.9, 0.95])
        ScoreBreakdown(total_score=95.0, stroke_count=3, ...)
    """
    if not stroke_scores:
        return ScoreBreakdown(
            total_score=0.0,
            stroke_count=0,
            expected_count=expected_stroke_count,
            average_score=0.0,
            min_score=0.0,
            max_score=0.0,
            perfect_strokes=0
        )

    stroke_count = len(stroke_scores)
    average_score = sum(stroke_scores) / stroke_count
    min_score = min(stroke_scores)
    max_score = max(stroke_scores)
    perfect_strokes = sum(1 for s in stroke_scores if s >= 0.95)

    # Start with average score (0-100 scale)
    total_score = average_score * 100.0

    # Apply stroke count penalty if expected count is provided
    if expected_stroke_count is not None and stroke_count != expected_stroke_count:
        # Calculate ratio of actual to expected
        ratio = stroke_count / expected_stroke_count

        # Penalty is stronger for missing strokes than extra strokes
        if ratio < 1.0:
            # Missing strokes: linear penalty
            # e.g., 4/5 strokes -> 20% penalty
            penalty = (1.0 - ratio) * 50.0  # Up to 50% penalty
        else:
            # Extra strokes: smaller penalty
            # e.g., 6/5 strokes -> 10% penalty
            penalty = (ratio - 1.0) * 25.0  # Up to 25% penalty

        total_score = max(0.0, total_score - penalty)

    # Clamp to [0, 100]
    total_score = max(0.0, min(100.0, total_score))

    return ScoreBreakdown(
        total_score=total_score,
        stroke_count=stroke_count,
        expected_count=expected_stroke_count,
        average_score=average_score,
        min_score=min_score,
        max_score=max_score,
        perfect_strokes=perfect_strokes
    )
