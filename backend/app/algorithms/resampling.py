"""
Stroke Resampling Algorithm - 笔画重采样算法

Resample strokes to a uniform number of points for DTW comparison.
Uses linear interpolation to add/remove points while preserving stroke shape.
"""

import numpy as np
from typing import List, Tuple


def resample_stroke(
    stroke: List[Tuple[float, float]],
    target_points: int
) -> List[Tuple[float, float]]:
    """
    Resample a stroke to have exactly target_points using linear interpolation.

    Preserves the shape of the stroke by interpolating along the original path.
    First and last points are always preserved.

    Args:
        stroke: List of (x, y) tuples representing the stroke trajectory
        target_points: Desired number of points in the resampled stroke

    Returns:
        List of (x, y) tuples with exactly target_points elements

    Examples:
        >>> resample_stroke([(0, 0), (1, 1)], 5)
        [(0.0, 0.0), (0.25, 0.25), (0.5, 0.5), (0.75, 0.75), (1.0, 1.0)]
    """
    if not stroke:
        return []

    # Handle degenerate cases
    if len(stroke) == 1:
        # Single point - duplicate it
        return [stroke[0]] * target_points

    # Convert to numpy array for easier computation
    stroke_array = np.array(stroke)

    # Calculate cumulative distances along the stroke
    # This gives us the path length parameter
    diffs = stroke_array[1:] - stroke_array[:-1]
    segment_lengths = np.sqrt((diffs ** 2).sum(axis=1))

    # Cumulative distance from start
    cumdist = np.concatenate([[0], np.cumsum(segment_lengths)])
    total_length = cumdist[-1]

    # Handle zero-length stroke (all points are the same)
    if total_length < 1e-10:
        # All points are essentially the same
        return [tuple(stroke[0])] * target_points

    # Generate evenly spaced parameter values along the path
    target_distances = np.linspace(0, total_length, target_points)

    # Interpolate to find (x, y) at each target distance
    resampled_x = np.interp(target_distances, cumdist, stroke_array[:, 0])
    resampled_y = np.interp(target_distances, cumdist, stroke_array[:, 1])

    # Convert back to list of tuples
    resampled = [(float(x), float(y)) for x, y in zip(resampled_x, resampled_y)]

    return resampled


def resample_strokes(
    strokes: List[List[Tuple[float, float]]],
    target_points: int
) -> List[List[Tuple[float, float]]]:
    """
    Resample multiple strokes to the same number of points.

    Args:
        strokes: List of strokes, each stroke is a list of (x, y) tuples
        target_points: Desired number of points for each stroke

    Returns:
        List of resampled strokes, each with exactly target_points

    Examples:
        >>> strokes = [[(0, 0), (1, 1)], [(0, 0), (0.5, 0.5), (1, 1)]]
        >>> resample_strokes(strokes, 5)
        [[(0.0, 0.0), (0.25, 0.25), (0.5, 0.5), (0.75, 0.75), (1.0, 1.0)],
         [(0.0, 0.0), (0.25, 0.25), (0.5, 0.5), (0.75, 0.75), (1.0, 1.0)]]
    """
    if not strokes:
        return []

    return [resample_stroke(stroke, target_points) for stroke in strokes]
