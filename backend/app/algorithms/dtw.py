"""
DTW Scoring Algorithm - DTW 距离计算算法

Dynamic Time Warping distance calculation for stroke comparison.
CRITICAL: Uses dtw-python library (pollen-robotics), NOT custom implementation.

PRD v2.1 Constraints:
- MUST use: from dtw import dtw
- FORBIDDEN: Manual for loop implementation
"""

import numpy as np
from typing import List, Tuple

# CRITICAL: Using dtw library from pollen-robotics
# Installation: pip install dtw-python
from dtw import dtw


def calculate_dtw_distance(
    seq1: List[Tuple[float, float]],
    seq2: List[Tuple[float, float]]
) -> float:
    """
    Calculate DTW distance between two sequences using dtw library.

    Args:
        seq1: First sequence of (x, y) points
        seq2: Second sequence of (x, y) points

    Returns:
        DTW distance (lower = more similar)

    Raises:
        ValueError: If either sequence is empty

    Examples:
        >>> calculate_dtw_distance([(0, 0), (1, 1)], [(0, 0), (1, 1)])
        0.0
        >>> calculate_dtw_distance([(0, 0), (1, 1)], [(1, 1), (0, 0)])
        > 0.0
    """
    if not seq1 or not seq2:
        raise ValueError("Cannot calculate DTW distance for empty sequences")

    # Convert to numpy arrays for dtw library
    arr1 = np.array(seq1)
    arr2 = np.array(seq2)

    # Use Manhattan distance (L1 norm) for point-to-point comparison
    # This is more robust than Euclidean for stroke data
    # dist_method='cityblock' is scipy's name for Manhattan distance
    alignment = dtw(
        arr1,
        arr2,
        dist_method='cityblock',  # L1 distance (Manhattan)
        step_pattern='symmetric2',  # Standard DTW step pattern
        distance_only=False
    )

    # Return the normalized distance
    distance = alignment.normalizedDistance

    return float(distance)


def calculate_dtw_distance_matrix(
    strokes: List[List[Tuple[float, float]]]
) -> List[List[float]]:
    """
    Calculate pairwise DTW distances between all strokes.

    Args:
        strokes: List of strokes, each stroke is a list of (x, y) points

    Returns:
        Square matrix of distances (symmetric, diagonal = 0)

    Examples:
        >>> strokes = [[(0, 0), (1, 1)], [(0, 0), (1, 1)]]
        >>> calculate_dtw_distance_matrix(strokes)
        [[0.0, 0.0], [0.0, 0.0]]
    """
    if not strokes:
        return []

    n = len(strokes)
    matrix = [[0.0] * n for _ in range(n)]

    for i in range(n):
        for j in range(i, n):
            if i == j:
                matrix[i][j] = 0.0
            else:
                distance = calculate_dtw_distance(strokes[i], strokes[j])
                matrix[i][j] = distance
                matrix[j][i] = distance  # Symmetric

    return matrix


def compare_strokes(
    template: List[Tuple[float, float]],
    user_stroke: List[Tuple[float, float]],
    max_distance: float = 1.0
) -> Tuple[float, float]:
    """
    Compare a user stroke to a template stroke and return similarity score.

    Args:
        template: Template stroke (ground truth)
        user_stroke: User-drawn stroke
        max_distance: Maximum expected distance for normalization (default 1.0)

    Returns:
        Tuple of (similarity, distance) where:
        - similarity: Similarity score in [0, 1] (1 = perfect match)
        - distance: Raw DTW distance

    Examples:
        >>> template = [(0, 0), (1, 1)]
        >>> user = [(0, 0), (1, 1)]
        >>> compare_strokes(template, user)
        (1.0, 0.0)
    """
    distance = calculate_dtw_distance(template, user_stroke)

    # Convert distance to similarity score using exponential decay
    # similarity = exp(-distance / max_distance)
    # This gives:
    # - distance = 0 -> similarity = 1.0 (perfect match)
    # - distance = max_distance -> similarity ≈ 0.37
    similarity = np.exp(-distance / max_distance)

    # Clamp similarity to [0, 1] range
    similarity = max(0.0, min(1.0, similarity))

    return (float(similarity), float(distance))
