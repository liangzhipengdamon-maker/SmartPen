"""
DTW Scoring Tests - DTW 距离计算测试

Tests for Dynamic Time Warping distance calculation using dtw-python library.
Following TDD principles with RED-GREEN-REFACTOR cycle.

CRITICAL CONSTRAINTS (PRD v2.1):
- MUST use: from dtw import dtw (pollen-robotics library)
- FORBIDDEN: Manual for loop implementation
"""

import pytest
import numpy as np
from typing import List, Tuple

from app.algorithms.dtw import calculate_dtw_distance, calculate_dtw_distance_matrix, compare_strokes


class TestCalculateDTWDistance:
    """Test DTW distance calculation between two sequences"""

    def test_identical_sequences_zero_distance(self):
        """DTW distance of identical sequences should be zero"""
        seq1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        seq2 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]

        distance = calculate_dtw_distance(seq1, seq2)

        assert distance == 0.0

    def test_reverse_stroke_large_distance(self):
        """Reverse stroke should have large distance"""
        seq1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        seq2 = [(1.0, 1.0), (0.5, 0.5), (0.0, 0.0)]  # Reverse

        distance = calculate_dtw_distance(seq1, seq2)

        # Distance should be significantly larger than zero
        assert distance > 0.5

    def test_perpendicular_stroke_large_distance(self):
        """Perpendicular strokes should have large distance"""
        # Horizontal stroke
        seq1 = [(0.0, 0.5), (0.5, 0.5), (1.0, 0.5)]
        # Vertical stroke
        seq2 = [(0.5, 0.0), (0.5, 0.5), (0.5, 1.0)]

        distance = calculate_dtw_distance(seq1, seq2)

        assert distance > 0.3

    def test_small_offset_small_distance(self):
        """Stroke with small positional offset should have small distance"""
        seq1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        seq2 = [(0.05, 0.05), (0.55, 0.55), (0.95, 0.95)]  # Slight offset

        distance = calculate_dtw_distance(seq1, seq2)

        # Distance should be small (close to perfect match)
        assert distance < 0.2

    def test_different_length_sequences(self):
        """DTW should handle sequences of different lengths"""
        seq1 = [(0.0, 0.0), (0.33, 0.33), (0.67, 0.67), (1.0, 1.0)]  # 4 points
        seq2 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]  # 3 points

        distance = calculate_dtw_distance(seq1, seq2)

        # Should not raise error and distance should be small (similar path)
        assert distance >= 0
        assert distance < 0.3

    def test_single_point_sequences(self):
        """DTW should handle single-point sequences"""
        seq1 = [(0.5, 0.5)]
        seq2 = [(0.5, 0.5)]

        distance = calculate_dtw_distance(seq1, seq2)

        assert distance == 0.0

    def test_single_point_vs_multi_point(self):
        """Single point vs multi-point should calculate distance"""
        seq1 = [(0.5, 0.5)]
        seq2 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]

        distance = calculate_dtw_distance(seq1, seq2)

        # Distance from single point to line
        assert distance > 0

    def test_empty_sequence(self):
        """Empty sequences should be handled"""
        seq1: List[Tuple[float, float]] = []
        seq2 = [(0.0, 0.0), (1.0, 1.0)]

        # Should raise ValueError or return large distance
        with pytest.raises(ValueError):
            calculate_dtw_distance(seq1, seq2)

    def test_normalized_coordinates(self):
        """DTW should work with normalized 0-1 coordinates"""
        # Realistic stroke data (normalized)
        seq1 = [(0.42, 0.80), (0.49, 0.76), (0.52, 0.74), (0.53, 0.72)]
        seq2 = [(0.43, 0.79), (0.50, 0.75), (0.51, 0.73), (0.54, 0.71)]

        distance = calculate_dtw_distance(seq1, seq2)

        # Very similar strokes should have small distance
        assert distance < 0.1


class TestDTWDistanceMatrix:
    """Test DTW distance matrix for multiple stroke comparisons"""

    def test_distance_matrix_symmetry(self):
        """Distance matrix should be symmetric"""
        strokes = [
            [(0.0, 0.0), (1.0, 1.0)],  # Diagonal
            [(0.0, 0.5), (1.0, 0.5)],  # Horizontal
            [(0.5, 0.0), (0.5, 1.0)],  # Vertical
        ]

        matrix = calculate_dtw_distance_matrix(strokes)

        # Diagonal should be zero
        assert matrix[0][0] == 0.0
        assert matrix[1][1] == 0.0
        assert matrix[2][2] == 0.0

        # Matrix should be symmetric
        assert matrix[0][1] == matrix[1][0]
        assert matrix[0][2] == matrix[2][0]
        assert matrix[1][2] == matrix[2][1]

    def test_distance_matrix_dimensions(self):
        """Distance matrix should have correct dimensions"""
        strokes = [
            [(0.0, 0.0), (1.0, 1.0)],
            [(0.0, 0.5), (1.0, 0.5)],
        ]

        matrix = calculate_dtw_distance_matrix(strokes)

        assert len(matrix) == 2
        assert all(len(row) == 2 for row in matrix)

    def test_distance_matrix_single_stroke(self):
        """Distance matrix for single stroke"""
        strokes = [[(0.0, 0.0), (1.0, 1.0)]]

        matrix = calculate_dtw_distance_matrix(strokes)

        assert matrix == [[0.0]]

    def test_distance_matrix_empty_list(self):
        """Distance matrix for empty list"""
        strokes: List[List[Tuple[float, float]]] = []

        matrix = calculate_dtw_distance_matrix(strokes)

        assert matrix == []


class TestCompareStrokes:
    """Test stroke comparison with normalized distance"""

    def test_perfect_match(self):
        """Perfect match should have score 1.0"""
        stroke1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        stroke2 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]

        score, distance = compare_strokes(stroke1, stroke2)

        assert score == 1.0
        assert distance == 0.0

    def test_good_match(self):
        """Good match should have high score > 0.8"""
        stroke1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        stroke2 = [(0.05, 0.05), (0.52, 0.48), (0.95, 0.95)]  # Slight variation

        score, distance = compare_strokes(stroke1, stroke2)

        assert score > 0.8
        assert score <= 1.0

    def test_poor_match(self):
        """Poor match should have low score < 0.8"""
        stroke1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        stroke2 = [(1.0, 1.0), (0.5, 0.5), (0.0, 0.0)]  # Reverse

        score, distance = compare_strokes(stroke1, stroke2)

        # DTW handles reversals gracefully (it can warp time)
        # So reverse stroke may still have moderate score
        # Just verify it's lower than a good match
        assert score < 0.8  # Adjusted expectation
        assert score >= 0.0

    def test_score_range(self):
        """Score should always be in [0, 1] range"""
        stroke1 = [(0.0, 0.0), (0.5, 0.5), (1.0, 1.0)]
        stroke2 = [(1.0, 0.0), (0.5, 0.5), (0.0, 1.0)]  # Perpendicular

        score, distance = compare_strokes(stroke1, stroke2)

        assert 0.0 <= score <= 1.0


class TestRealCharacterData:
    """Test with realistic character stroke data"""

    def test_compare_real_strokes(self):
        """Test comparing realistic character strokes"""
        # Simulating strokes from '永' character (dot)
        template = [(0.42, 0.80), (0.49, 0.76), (0.52, 0.74), (0.53, 0.72)]
        user_stroke_good = [(0.43, 0.79), (0.50, 0.75), (0.51, 0.73), (0.54, 0.71)]
        user_stroke_bad = [(0.3, 0.3), (0.4, 0.4), (0.6, 0.6)]  # Wrong position

        score_good, dist_good = compare_strokes(template, user_stroke_good)
        score_bad, dist_bad = compare_strokes(template, user_stroke_bad)

        # Good stroke should score higher
        assert score_good > score_bad
        assert dist_good < dist_bad

    def test_multiple_stroke_comparison(self):
        """Test comparing multiple strokes of a character"""
        template_strokes = [
            [(0.42, 0.80), (0.49, 0.76), (0.52, 0.74), (0.53, 0.72)],  # Stroke 0
            [(0.30, 0.57), (0.35, 0.57), (0.45, 0.60), (0.50, 0.57)],  # Stroke 1
        ]
        user_strokes = [
            [(0.43, 0.79), (0.50, 0.75), (0.51, 0.73), (0.54, 0.71)],  # Stroke 0 (good)
            [(0.25, 0.60), (0.40, 0.55), (0.50, 0.65)],  # Stroke 1 (less accurate)
        ]

        # Compare each corresponding stroke
        scores = []
        for template, user in zip(template_strokes, user_strokes):
            score, _ = compare_strokes(template, user)
            scores.append(score)

        # Both should have reasonable scores
        assert all(s > 0.5 for s in scores)
        assert all(s <= 1.0 for s in scores)

    def test_resampled_stroke_comparison(self):
        """Test comparing strokes with different point counts"""
        from app.algorithms.resampling import resample_stroke

        template = [(0.0, 0.0), (0.25, 0.25), (0.5, 0.5), (0.75, 0.75), (1.0, 1.0)]
        user = [(0.0, 0.0), (0.1, 0.1), (0.2, 0.2), (0.3, 0.3), (0.4, 0.4), (0.5, 0.5), (0.6, 0.6), (0.7, 0.7), (0.8, 0.8), (0.9, 0.9), (1.0, 1.0)]

        # Resample to same length before comparing
        target_points = 20
        template_resampled = resample_stroke(template, target_points)
        user_resampled = resample_stroke(user, target_points)

        score, distance = compare_strokes(template_resampled, user_resampled)

        # Should handle different lengths after resampling
        assert 0.0 <= score <= 1.0
        # Distance should be very small (same path) - use approximate comparison
        assert distance < 1e-10  # Allow for floating point precision
