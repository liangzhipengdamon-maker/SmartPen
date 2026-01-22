"""
Stroke Order Validation - 笔顺验证模块

Validates stroke order, direction, and count for character writing.
"""

import numpy as np
from typing import List, Tuple
from enum import Enum
from pydantic import BaseModel

from app.algorithms.dtw import calculate_dtw_distance_matrix


class StrokeDirection(Enum):
    """Stroke direction types"""
    HORIZONTAL = "horizontal"
    VERTICAL = "vertical"
    DIAGONAL_DOWN_RIGHT = "diagonal_down_right"
    DIAGONAL_DOWN_LEFT = "diagonal_down_left"
    UNKNOWN = "unknown"


class StrokeOrderResult(BaseModel):
    """Result of stroke order validation"""
    is_valid: bool
    score: float
    stroke_count_match: bool
    order_penalty: float = 0.0
    direction_match_rate: float = 0.0


def detect_stroke_direction(
    stroke: List[Tuple[float, float]],
    direction_threshold: float = 0.7
) -> StrokeDirection:
    """
    Detect the primary direction of a stroke.

    Args:
        stroke: List of (x, y) points
        direction_threshold: Minimum ratio to classify as directional stroke

    Returns:
        StrokeDirection enum value
    """
    if len(stroke) < 2:
        return StrokeDirection.UNKNOWN

    # Calculate start and end points
    start_x, start_y = stroke[0]
    end_x, end_y = stroke[-1]

    # Calculate displacements
    dx = abs(end_x - start_x)
    dy = abs(end_y - start_y)
    total = dx + dy

    if total < 0.1:  # Very small stroke
        return StrokeDirection.UNKNOWN

    # Check for curved stroke by measuring deviation from straight line
    if len(stroke) > 2:
        # Calculate maximum deviation from start-end line
        max_deviation = 0.0
        for x, y in stroke[1:-1]:  # Check middle points
            # Distance from point to line (using perpendicular distance formula)
            # Line equation: (y - y1) = m(x - x1), where m = (y2 - y1)/(x2 - x1)
            if dx > 0.001:  # Not vertical
                # Line from (start_x, start_y) to (end_x, end_y)
                # Perpendicular distance
                numerator = abs((end_y - start_y) * x - (end_x - start_x) * y + end_x * start_y - end_y * start_x)
                denominator = ((end_y - start_y)**2 + (end_x - start_x)**2)**0.5
                if denominator > 0.001:
                    deviation = numerator / denominator
                    max_deviation = max(max_deviation, deviation)

        # If deviation is significant relative to stroke length, it's curved
        stroke_length = total
        if stroke_length > 0 and max_deviation / stroke_length > 0.2:
            return StrokeDirection.UNKNOWN

    # Determine dominant direction
    horizontal_ratio = dx / total
    vertical_ratio = dy / total

    if horizontal_ratio >= direction_threshold:
        return StrokeDirection.HORIZONTAL
    elif vertical_ratio >= direction_threshold:
        return StrokeDirection.VERTICAL
    elif horizontal_ratio > 0.3 and vertical_ratio > 0.3:
        # Diagonal stroke
        if (end_x > start_x and end_y > start_y) or \
           (end_x < start_x and end_y < start_y):
            return StrokeDirection.DIAGONAL_DOWN_RIGHT
        else:
            return StrokeDirection.DIAGONAL_DOWN_LEFT
    else:
        return StrokeDirection.UNKNOWN


def calculate_similarity_matrix(
    template_strokes: List[List[Tuple[float, float]]],
    user_strokes: List[List[Tuple[float, float]]]
) -> np.ndarray:
    """
    Calculate similarity matrix between template and user strokes.

    Returns a matrix where matrix[i][j] is the similarity between
    template stroke i and user stroke j.

    Args:
        template_strokes: Template character strokes
        user_strokes: User-drawn strokes

    Returns:
        Similarity matrix (similarity scores 0-1)
    """
    from app.algorithms.dtw import compare_strokes

    n_templates = len(template_strokes)
    n_user = len(user_strokes)

    matrix = np.zeros((n_templates, n_user))

    for i in range(n_templates):
        for j in range(n_user):
            similarity, _ = compare_strokes(template_strokes[i], user_strokes[j])
            matrix[i][j] = similarity

    return matrix


def validate_stroke_order(
    template_strokes: List[List[Tuple[float, float]]],
    user_strokes: List[List[Tuple[float, float]]],
    order_penalty_factor: float = 0.3
) -> StrokeOrderResult:
    """
    Validate stroke order and direction.

    Args:
        template_strokes: Template character strokes (ground truth)
        user_strokes: User-drawn strokes
        order_penalty_factor: Penalty for incorrect stroke order (0-1)

    Returns:
        StrokeOrderResult with validation details
    """
    # Check for empty strokes
    if not user_strokes:
        return StrokeOrderResult(
            is_valid=False,
            score=0.0,
            stroke_count_match=False,
            order_penalty=1.0,
            direction_match_rate=0.0
        )

    # Check stroke count
    stroke_count_match = len(user_strokes) == len(template_strokes)

    if not stroke_count_match:
        # Wrong stroke count is a major error
        return StrokeOrderResult(
            is_valid=False,
            score=0.3,  # Low score for wrong count
            stroke_count_match=False,
            order_penalty=0.5,
            direction_match_rate=0.0
        )

    # Calculate similarity matrix
    similarity_matrix = calculate_similarity_matrix(template_strokes, user_strokes)

    # Check if strokes are in correct order (diagonal should be highest)
    n = len(template_strokes)
    diagonal_scores = np.diag(similarity_matrix)

    # Calculate order penalty
    order_penalty = 0.0
    for i in range(n):
        # For each template stroke, check if corresponding user stroke is best match
        best_match_idx = np.argmax(similarity_matrix[i])
        if best_match_idx != i:
            # Wrong order detected
            order_penalty += order_penalty_factor / n

    # Calculate average similarity for correct order
    avg_similarity = float(np.mean(diagonal_scores))

    # Apply additional penalty for very low similarity (wrong position strokes)
    # If strokes are completely wrong position-wise, severely penalize
    if avg_similarity < 0.6:
        # Severe penalty for wrong positions
        avg_similarity = avg_similarity * 0.5

    # Calculate direction match rate
    direction_matches = 0
    for i in range(n):
        template_dir = detect_stroke_direction(template_strokes[i])
        user_dir = detect_stroke_direction(user_strokes[i])
        if template_dir == user_dir and template_dir != StrokeDirection.UNKNOWN:
            direction_matches += 1

    direction_match_rate = direction_matches / n if n > 0 else 0.0

    # Calculate final score
    # Start with average similarity
    score = avg_similarity

    # Apply order penalty
    score = score * (1.0 - order_penalty)

    # Boost score if directions match
    if direction_match_rate > 0.5:
        score = min(1.0, score + 0.1 * direction_match_rate)

    # Determine if valid (score >= 0.7 and no major order issues)
    is_valid = score >= 0.7 and order_penalty < 0.3

    return StrokeOrderResult(
        is_valid=is_valid,
        score=float(score),
        stroke_count_match=stroke_count_match,
        order_penalty=float(order_penalty),
        direction_match_rate=float(direction_match_rate)
    )
