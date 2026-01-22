"""
Stroke Order Validation Tests - 笔顺验证测试

Tests for validating stroke order and direction.
Following TDD principles with RED-GREEN-REFACTOR cycle.
"""

import pytest
from typing import List, Tuple

from app.scoring.stroke_order import (
    validate_stroke_order,
    StrokeOrderResult,
    detect_stroke_direction,
    StrokeDirection,
)


class TestDetectStrokeDirection:
    """Test stroke direction detection"""

    def test_horizontal_left_to_right(self):
        """Horizontal stroke left to right should be detected"""
        stroke = [(0.2, 0.5), (0.5, 0.5), (0.8, 0.5)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.HORIZONTAL

    def test_horizontal_right_to_left(self):
        """Horizontal stroke right to left should still be horizontal"""
        stroke = [(0.8, 0.5), (0.5, 0.5), (0.2, 0.5)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.HORIZONTAL

    def test_vertical_top_to_bottom(self):
        """Vertical stroke top to bottom should be detected"""
        stroke = [(0.5, 0.2), (0.5, 0.5), (0.5, 0.8)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.VERTICAL

    def test_vertical_bottom_to_top(self):
        """Vertical stroke bottom to top should still be vertical"""
        stroke = [(0.5, 0.8), (0.5, 0.5), (0.5, 0.2)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.VERTICAL

    def test_diagonal_down_right(self):
        """Diagonal stroke down-right should be detected"""
        stroke = [(0.3, 0.3), (0.5, 0.5), (0.7, 0.7)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.DIAGONAL_DOWN_RIGHT

    def test_diagonal_down_left(self):
        """Diagonal stroke down-left should be detected"""
        stroke = [(0.7, 0.3), (0.5, 0.5), (0.3, 0.7)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.DIAGONAL_DOWN_LEFT

    def test_complex_curved_stroke(self):
        """Complex curved stroke should be unknown"""
        stroke = [(0.3, 0.5), (0.4, 0.4), (0.5, 0.5), (0.6, 0.6), (0.5, 0.7)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.UNKNOWN

    def test_single_point(self):
        """Single point should be unknown"""
        stroke = [(0.5, 0.5)]
        direction = detect_stroke_direction(stroke)

        assert direction == StrokeDirection.UNKNOWN


class TestValidateStrokeOrder:
    """Test stroke order validation"""

    def test_perfect_stroke_order(self):
        """Perfect stroke order should pass validation"""
        template_strokes = [
            [(0.2, 0.3), (0.8, 0.3)],  # Stroke 1: horizontal
            [(0.5, 0.2), (0.5, 0.8)],  # Stroke 2: vertical
        ]
        user_strokes = [
            [(0.21, 0.31), (0.79, 0.29)],  # Stroke 1: close to template
            [(0.49, 0.19), (0.51, 0.81)],  # Stroke 2: close to template
        ]

        result = validate_stroke_order(template_strokes, user_strokes)

        assert result.is_valid
        assert result.score > 0.8
        assert result.stroke_count_match is True

    def test_wrong_stroke_count(self):
        """Wrong stroke count should fail validation"""
        template_strokes = [
            [(0.2, 0.3), (0.8, 0.3)],
            [(0.5, 0.2), (0.5, 0.8)],
        ]
        user_strokes = [
            [(0.21, 0.31), (0.79, 0.29)],  # Only 1 stroke
        ]

        result = validate_stroke_order(template_strokes, user_strokes)

        assert result.stroke_count_match is False
        assert result.score < 0.5

    def test_extra_stroke(self):
        """Extra stroke should lower score"""
        template_strokes = [
            [(0.2, 0.3), (0.8, 0.3)],
            [(0.5, 0.2), (0.5, 0.8)],
        ]
        user_strokes = [
            [(0.21, 0.31), (0.79, 0.29)],
            [(0.49, 0.19), (0.51, 0.81)],
            [(0.7, 0.7), (0.8, 0.8)],  # Extra stroke
        ]

        result = validate_stroke_order(template_strokes, user_strokes)

        assert result.stroke_count_match is False
        assert result.score < 0.8

    def test_reversed_stroke_order(self):
        """Reversed stroke order should have lower score"""
        template_strokes = [
            [(0.2, 0.3), (0.8, 0.3)],  # Should be first
            [(0.5, 0.2), (0.5, 0.8)],  # Should be second
        ]
        user_strokes = [
            [(0.49, 0.19), (0.51, 0.81)],  # Drew second first
            [(0.21, 0.31), (0.79, 0.29)],  # Drew first second
        ]

        result = validate_stroke_order(template_strokes, user_strokes)

        # Should detect order mismatch and penalize
        assert result.score < 0.7
        assert result.order_penalty > 0

    def test_completely_wrong_strokes(self):
        """Completely wrong strokes should fail"""
        template_strokes = [
            [(0.2, 0.3), (0.8, 0.3)],
            [(0.5, 0.2), (0.5, 0.8)],
        ]
        user_strokes = [
            [(0.9, 0.9), (0.95, 0.95)],  # Wrong position
            [(0.1, 0.1), (0.15, 0.15)],  # Wrong position
        ]

        result = validate_stroke_order(template_strokes, user_strokes)

        assert result.score < 0.3

    def test_empty_strokes(self):
        """Empty user strokes should fail"""
        template_strokes = [
            [(0.2, 0.3), (0.8, 0.3)],
        ]
        user_strokes: List[List[Tuple[float, float]]] = []

        result = validate_stroke_order(template_strokes, user_strokes)

        assert result.is_valid is False
        assert result.score == 0.0

    def test_realistic_character_strokes(self):
        """Test with realistic character stroke data"""
        # Simulating '一' (one stroke)
        template_strokes = [
            [(0.2, 0.5), (0.8, 0.5)],
        ]
        user_strokes = [
            [(0.22, 0.51), (0.78, 0.49)],
        ]

        result = validate_stroke_order(template_strokes, user_strokes)

        assert result.is_valid
        assert result.score > 0.9

    def test_complex_character_order(self):
        """Test stroke order for complex character"""
        # '十' character: horizontal first, then vertical
        template_strokes = [
            [(0.2, 0.5), (0.8, 0.5)],  # Horizontal (first)
            [(0.5, 0.2), (0.5, 0.8)],  # Vertical (second)
        ]

        # Correct order
        user_strokes_correct = [
            [(0.21, 0.51), (0.79, 0.49)],
            [(0.49, 0.19), (0.51, 0.81)],
        ]

        result_correct = validate_stroke_order(
            template_strokes, user_strokes_correct
        )
        assert result_correct.is_valid

        # Wrong order (vertical first, then horizontal)
        user_strokes_wrong = [
            [(0.49, 0.19), (0.51, 0.81)],  # Drew vertical first
            [(0.21, 0.51), (0.79, 0.49)],  # Drew horizontal second
        ]

        result_wrong = validate_stroke_order(
            template_strokes, user_strokes_wrong
        )

        # Wrong order should have lower score
        assert result_wrong.score < result_correct.score


class TestStrokeOrderResult:
    """Test StrokeOrderResult data model"""

    def test_result_fields(self):
        """StrokeOrderResult should contain all expected fields"""
        result = StrokeOrderResult(
            is_valid=True,
            score=0.85,
            stroke_count_match=True,
            order_penalty=0.0,
            direction_match_rate=1.0,
        )

        assert result.is_valid is True
        assert result.score == 0.85
        assert result.stroke_count_match is True
        assert result.order_penalty == 0.0
        assert result.direction_match_rate == 1.0
