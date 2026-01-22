"""
Stroke Resampling Tests - 笔画重采样算法测试

Tests for stroke resampling to normalize point count for DTW comparison.
Following TDD principles with RED-GREEN-REFACTOR cycle.
"""

import pytest
import numpy as np
from typing import List, Tuple

from app.algorithms.resampling import resample_stroke, resample_strokes


class TestResampleStroke:
    """Test single stroke resampling"""

    def test_resample_short_stroke_to_more_points(self):
        """Test resampling short stroke (3 points) to 10 points"""
        # Original stroke with 3 points
        stroke = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        target_points = 10

        resampled = resample_stroke(stroke, target_points)

        # Should have exactly target_points
        assert len(resampled) == target_points
        # First and last points should match original
        assert resampled[0] == (0.0, 0.0)
        assert resampled[-1] == (1.0, 1.0)

    def test_resample_long_stroke_to_fewer_points(self):
        """Test resampling long stroke (20 points) to 5 points"""
        # Create a stroke with 20 points along a diagonal
        stroke = [(i / 19.0, i / 19.0) for i in range(20)]
        target_points = 5

        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == target_points
        assert resampled[0] == (0.0, 0.0)
        assert resampled[-1] == (1.0, 1.0)

    def test_resample_same_length(self):
        """Test resampling stroke to same length (should copy)"""
        stroke = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        target_points = 3

        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == 3
        # Values should be very close (might have minor floating point differences)
        for original, resampled_point in zip(stroke, resampled):
            assert abs(original[0] - resampled_point[0]) < 1e-10
            assert abs(original[1] - resampled_point[1]) < 1e-10

    def test_resample_single_point(self):
        """Test resampling single point stroke to multiple points"""
        stroke = [(0.5, 0.5)]
        target_points = 5

        # Should raise error or handle gracefully
        # For now, we expect it to duplicate the point
        resampled = resample_stroke(stroke, target_points)

        # All points should be the same
        assert all(p == (0.5, 0.5) for p in resampled)

    def test_resample_preserves_path(self):
        """Test that resampled points lie on original path"""
        # Stroke with points forming a straight line
        stroke = [(0.0, 0.0), (0.5, 0.25), (1.0, 0.5)]
        target_points = 20

        resampled = resample_stroke(stroke, target_points)

        # All resampled points should be on or very close to the original path
        # For a straight line y = 0.5 * x, check each point
        for x, y in resampled:
            expected_y = 0.5 * x
            assert abs(y - expected_y) < 0.01, f"Point ({x}, {y}) not on path"

    def test_resample_with_curve(self):
        """Test resampling a curved stroke"""
        # Quadratic curve-like stroke
        stroke = [
            (0.0, 0.0),
            (0.25, 0.1),
            (0.5, 0.3),
            (0.75, 0.6),
            (1.0, 1.0)
        ]
        target_points = 15

        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == target_points
        # Check monotonic progression (stroke should go from bottom-left to top-right)
        x_coords = [p[0] for p in resampled]
        y_coords = [p[1] for p in resampled]

        # X and Y should be non-decreasing for this stroke
        for i in range(1, len(x_coords)):
            assert x_coords[i] >= x_coords[i - 1], "X coordinate should not decrease"
            assert y_coords[i] >= y_coords[i - 1], "Y coordinate should not decrease"

    def test_resample_uniform_spacing(self):
        """Test that resampled points are approximately uniformly spaced"""
        # Long straight stroke
        stroke = [(i / 100.0, i / 100.0) for i in range(101)]
        target_points = 10

        resampled = resample_stroke(stroke, target_points)

        # Calculate distances between consecutive points
        distances = []
        for i in range(len(resampled) - 1):
            x1, y1 = resampled[i]
            x2, y2 = resampled[i + 1]
            dist = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5
            distances.append(dist)

        # Check variance is low (points are evenly spaced)
        mean_dist = sum(distances) / len(distances)
        variance = sum((d - mean_dist) ** 2 for d in distances) / len(distances)
        std_dev = variance ** 0.5

        # Standard deviation should be small relative to mean distance
        assert std_dev < mean_dist * 0.1, "Points should be uniformly spaced"

    def test_resample_with_repeated_points(self):
        """Test resampling stroke with repeated consecutive points"""
        stroke = [(0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (1.0, 1.0)]
        target_points = 5

        # Should handle gracefully (deduplicate or proceed)
        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == target_points
        assert resampled[0] == (0.0, 0.0)
        assert resampled[-1] == (1.0, 1.0)


class TestResampleStrokes:
    """Test multiple stroke resampling"""

    def test_resample_multiple_strokes(self):
        """Test resampling multiple strokes to same point count"""
        strokes = [
            [(0.0, 0.0), (1.0, 1.0)],  # 2 points
            [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)],  # 3 points
            [(0.0, 0.0)] * 10 + [(1.0, 1.0)],  # 11 points
        ]
        target_points = 15

        resampled = resample_strokes(strokes, target_points)

        # All strokes should have same number of points
        assert len(resampled) == 3
        assert all(len(stroke) == target_points for stroke in resampled)

    def test_resample_strokes_preserves_count(self):
        """Test that resampling preserves stroke count"""
        strokes = [
            [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)],
            [(0.5, 0.0), (0.5, 1.0)],
        ]
        target_points = 10

        resampled = resample_strokes(strokes, target_points)

        assert len(resampled) == len(strokes)

    def test_resample_empty_strokes(self):
        """Test resampling empty stroke list"""
        strokes = []
        target_points = 10

        resampled = resample_strokes(strokes, target_points)

        assert resampled == []

    def test_resample_real_character_strokes(self):
        """Test resampling realistic character stroke data"""
        # Simulating a few strokes of '永' character
        strokes = [
            # Dot (4 points)
            [(0.42, 0.80), (0.49, 0.76), (0.52, 0.74), (0.53, 0.72)],
            # Horizontal (9 points)
            [(0.30, 0.57), (0.35, 0.57), (0.45, 0.60), (0.47, 0.59),
             (0.50, 0.57), (0.49, 0.12), (0.49, 0.06), (0.47, 0.02), (0.35, 0.08)],
        ]
        target_points = 20

        resampled = resample_strokes(strokes, target_points)

        assert len(resampled) == 2
        assert all(len(stroke) == target_points for stroke in resampled)

        # First and last points of each stroke should be preserved
        for original, resampled_stroke in zip(strokes, resampled):
            assert resampled_stroke[0] == original[0]
            assert resampled_stroke[-1] == original[-1]


class TestEdgeCases:
    """Test edge cases and error handling"""

    def test_resample_with_two_points(self):
        """Test resampling minimal stroke (2 points)"""
        stroke = [(0.0, 0.0), (1.0, 1.0)]
        target_points = 10

        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == target_points
        # Points should be evenly spaced along the line
        for i, (x, y) in enumerate(resampled):
            expected_ratio = i / (target_points - 1)
            assert abs(x - expected_ratio) < 0.01
            assert abs(y - expected_ratio) < 0.01

    def test_resample_with_large_target(self):
        """Test resampling to large number of points"""
        stroke = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        target_points = 100

        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == target_points

    def test_resample_with_small_target(self):
        """Test resampling to small number of points"""
        stroke = [(i / 10.0, i / 10.0) for i in range(11)]
        target_points = 3

        resampled = resample_stroke(stroke, target_points)

        assert len(resampled) == target_points
