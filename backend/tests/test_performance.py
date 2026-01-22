"""
Performance Tests - 性能测试

Tests for scoring engine performance benchmarks.
Following TDD principles with RED-GREEN-REFACTOR cycle.
"""

import pytest
import time
from typing import List, Tuple

from app.algorithms.resampling import resample_stroke
from app.algorithms.dtw import compare_strokes
from app.scoring.normalizer import calculate_character_score
from app.scoring.stroke_order import validate_stroke_order


class TestStrokeResamplingPerformance:
    """Test stroke resampling performance"""

    def test_resample_single_stroke_fast(self):
        """Single stroke resampling should be fast (< 10ms)"""
        # Long stroke with many points
        stroke = [(i * 0.01, i * 0.01) for i in range(100)]

        start = time.perf_counter()
        resampled = resample_stroke(stroke, target_points=50)
        elapsed = time.perf_counter() - start

        assert elapsed < 0.01, f"Resampling took {elapsed:.4f}s, expected < 0.01s"
        assert len(resampled) == 50

    def test_resample_multiple_strokes_fast(self):
        """Multiple strokes resampling should be fast (< 50ms)"""
        # Simulate 10 strokes
        strokes = [[(i * 0.01, j * 0.01) for i in range(50)] for j in range(10)]

        start = time.perf_counter()
        resampled = [resample_stroke(s, target_points=30) for s in strokes]
        elapsed = time.perf_counter() - start

        assert elapsed < 0.05, f"Resampling took {elapsed:.4f}s, expected < 0.05s"
        assert len(resampled) == 10


class TestDTWPerformance:
    """Test DTW distance calculation performance"""

    def test_dtw_single_comparison_fast(self):
        """Single DTW comparison should be fast (< 50ms)"""
        template = [(i * 0.05, i * 0.05) for i in range(20)]
        user = [(i * 0.05 + 0.01, i * 0.05 + 0.01) for i in range(20)]

        start = time.perf_counter()
        score, distance = compare_strokes(template, user)
        elapsed = time.perf_counter() - start

        assert elapsed < 0.05, f"DTW comparison took {elapsed:.4f}s, expected < 0.05s"
        assert 0 <= score <= 1

    def test_dtw_multiple_comparisons_fast(self):
        """Multiple DTW comparisons should be fast (< 200ms)"""
        # Simulate 5 template vs 5 user strokes
        templates = [[(i * 0.05, j * 0.05) for i in range(20)] for j in range(5)]
        user_strokes = [[(i * 0.05 + 0.01, j * 0.05 + 0.01) for i in range(20)] for j in range(5)]

        start = time.perf_counter()
        for tmpl, user in zip(templates, user_strokes):
            score, _ = compare_strokes(tmpl, user)
        elapsed = time.perf_counter() - start

        assert elapsed < 0.2, f"5 DTW comparisons took {elapsed:.4f}s, expected < 0.2s"


class TestCharacterScoringPerformance:
    """Test character scoring performance"""

    def test_simple_character_scoring_fast(self):
        """Simple character scoring should be fast (< 500ms)"""
        # Simulate '一' (1 stroke)
        template_strokes = [[(0.2, 0.5), (0.8, 0.5)]]
        user_strokes = [[(0.22, 0.51), (0.78, 0.49)]]

        # Resample
        resampled_templates = [resample_stroke(s, 20) for s in template_strokes]
        resampled_user = [resample_stroke(s, 20) for s in user_strokes]

        start = time.perf_counter()

        # Calculate stroke scores
        stroke_scores = []
        for tmpl, user in zip(resampled_templates, resampled_user):
            score, _ = compare_strokes(tmpl, user)
            stroke_scores.append(score)

        # Calculate character score
        breakdown = calculate_character_score(stroke_scores)

        elapsed = time.perf_counter() - start

        assert elapsed < 0.5, f"Character scoring took {elapsed:.4f}s, expected < 0.5s"
        assert breakdown.total_score > 0

    def test_complex_character_scoring_fast(self):
        """Complex character scoring should be fast (< 2s)"""
        # Simulate '永' (5 strokes) with realistic point counts
        template_strokes = [
            [(0.42 + i * 0.01, 0.80 - i * 0.01) for i in range(15)],  # Stroke 1
            [(0.30 + i * 0.02, 0.57 + i * 0.01) for i in range(12)],  # Stroke 2
            [(0.50 + i * 0.01, 0.30 + i * 0.03) for i in range(18)],  # Stroke 3
            [(0.70 - i * 0.02, 0.40 + i * 0.02) for i in range(14)],  # Stroke 4
            [(0.35 + i * 0.015, 0.65 - i * 0.015) for i in range(16)],  # Stroke 5
        ]
        user_strokes = [
            [(0.43 + i * 0.01, 0.79 - i * 0.01) for i in range(15)],  # Stroke 1 (close)
            [(0.32 + i * 0.02, 0.58 + i * 0.01) for i in range(12)],  # Stroke 2 (close)
            [(0.51 + i * 0.01, 0.31 + i * 0.03) for i in range(18)],  # Stroke 3 (close)
            [(0.69 - i * 0.02, 0.41 + i * 0.02) for i in range(14)],  # Stroke 4 (close)
            [(0.36 + i * 0.015, 0.64 - i * 0.015) for i in range(16)],  # Stroke 5 (close)
        ]

        # Resample to uniform length
        target_points = 30
        resampled_templates = [resample_stroke(s, target_points) for s in template_strokes]
        resampled_user = [resample_stroke(s, target_points) for s in user_strokes]

        start = time.perf_counter()

        # Calculate stroke scores
        stroke_scores = []
        for tmpl, user in zip(resampled_templates, resampled_user):
            score, _ = compare_strokes(tmpl, user)
            stroke_scores.append(score)

        # Calculate character score
        breakdown = calculate_character_score(stroke_scores, expected_stroke_count=5)

        # Validate stroke order
        order_result = validate_stroke_order(resampled_templates, resampled_user)

        elapsed = time.perf_counter() - start

        # Main success criterion: < 2 seconds
        assert elapsed < 2.0, f"Complex character scoring took {elapsed:.4f}s, expected < 2.0s"
        assert breakdown.total_score > 0
        assert order_result.is_valid


class TestEndToEndPerformance:
    """Test end-to-end scoring pipeline performance"""

    def test_full_scoring_pipeline_fast(self):
        """Full scoring pipeline should be fast (< 2s)"""
        # Realistic character data (5 strokes)
        template_strokes = [
            [(0.42, 0.80), (0.49, 0.76), (0.52, 0.74), (0.53, 0.72)],
            [(0.30, 0.57), (0.35, 0.57), (0.45, 0.60), (0.50, 0.57)],
            [(0.50, 0.30), (0.50, 0.50), (0.50, 0.70)],
            [(0.70, 0.40), (0.50, 0.60), (0.30, 0.80)],
            [(0.35, 0.65), (0.40, 0.60), (0.50, 0.55)],
        ]
        user_strokes = [
            [(0.43, 0.79), (0.50, 0.75), (0.51, 0.73), (0.54, 0.71)],
            [(0.32, 0.56), (0.38, 0.58), (0.43, 0.62)],
            [(0.51, 0.31), (0.49, 0.51), (0.51, 0.69)],
            [(0.69, 0.41), (0.51, 0.59), (0.31, 0.79)],
            [(0.36, 0.64), (0.41, 0.59), (0.49, 0.56)],
        ]

        start = time.perf_counter()

        # Step 1: Resample
        target_points = 20
        resampled_templates = [resample_stroke(s, target_points) for s in template_strokes]
        resampled_user = [resample_stroke(s, target_points) for s in user_strokes]

        # Step 2: DTW comparison
        stroke_scores = []
        for tmpl, user in zip(resampled_templates, resampled_user):
            score, distance = compare_strokes(tmpl, user)
            stroke_scores.append(score)

        # Step 3: Character scoring
        breakdown = calculate_character_score(stroke_scores, expected_stroke_count=5)

        # Step 4: Stroke order validation
        order_result = validate_stroke_order(resampled_templates, resampled_user)

        elapsed = time.perf_counter() - start

        # Main success criterion: < 2 seconds
        assert elapsed < 2.0, f"Full pipeline took {elapsed:.4f}s, expected < 2.0s"
        assert breakdown.total_score > 70  # Good quality
        assert order_result.is_valid


@pytest.mark.parametrize("num_strokes", [3, 5, 8, 10])
def test_scaling_with_stroke_count(num_strokes):
    """Test performance scaling with stroke count"""
    # Generate test strokes
    template_strokes = [
        [(i * 0.05 + j * 0.1, i * 0.03 + j * 0.1) for i in range(15)]
        for j in range(num_strokes)
    ]
    user_strokes = [
        [(i * 0.05 + j * 0.1 + 0.01, i * 0.03 + j * 0.1 + 0.01) for i in range(15)]
        for j in range(num_strokes)
    ]

    start = time.perf_counter()

    # Resample
    target_points = 20
    resampled_templates = [resample_stroke(s, target_points) for s in template_strokes]
    resampled_user = [resample_stroke(s, target_points) for s in user_strokes]

    # DTW comparison
    stroke_scores = []
    for tmpl, user in zip(resampled_templates, resampled_user):
        score, _ = compare_strokes(tmpl, user)
        stroke_scores.append(score)

    # Character scoring
    breakdown = calculate_character_score(stroke_scores)

    elapsed = time.perf_counter() - start

    # Performance should scale roughly linearly with stroke count
    # For 10 strokes, should still be under 2 seconds
    max_allowed = 0.2 * num_strokes  # 200ms per stroke
    assert elapsed < max_allowed, f"{num_strokes} strokes took {elapsed:.4f}s, expected < {max_allowed:.2f}s"
