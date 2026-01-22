"""
Character Model Tests - 汉字数据模型测试

Tests for CharacterData, coordinate conversion, and validation.
Following TDD principles with RED-GREEN-REFACTOR cycle.
"""

import pytest
from pydantic import ValidationError

from app.models.character import (
    CharacterData,
    CharacterRequest,
    CharacterSource,
    CoordinateSystem,
    MedianPoint,
    StrokeMedian,
    StrokePath,
    RadicalData,
)


class TestMedianPoint:
    """Test MedianPoint coordinate conversion"""

    def test_from_hanzi_1024_origin(self):
        """Test conversion of origin (0, 0)"""
        point = MedianPoint.from_hanzi_1024(0, 0)
        assert point.x == 0.0
        assert point.y == 0.0

    def test_from_hanzi_1024_max(self):
        """Test conversion of maximum (1024, 1024)"""
        point = MedianPoint.from_hanzi_1024(1024, 1024)
        assert point.x == 1.0
        assert point.y == 1.0

    def test_from_hanzi_1024_midpoint(self):
        """Test conversion of midpoint (512, 512)"""
        point = MedianPoint.from_hanzi_1024(512, 512)
        assert point.x == 0.5
        assert point.y == 0.5

    def test_from_hanzi_1024_round_trip(self):
        """Test round-trip conversion maintains precision"""
        original = (300, 750)
        point = MedianPoint.from_hanzi_1024(*original)
        converted = point.to_hanzi_1024()
        assert converted == original

    def test_validation_range_valid(self):
        """Valid coordinates (0-1) are accepted"""
        point = MedianPoint(x=0.5, y=0.5)
        assert point.x == 0.5
        assert point.y == 0.5

    def test_validation_range_invalid_x(self):
        """Invalid x coordinate (>1) is rejected"""
        with pytest.raises(ValidationError):
            MedianPoint(x=1.5, y=0.5)

    def test_validation_range_invalid_negative(self):
        """Negative coordinates are rejected"""
        with pytest.raises(ValidationError):
            MedianPoint(x=-0.1, y=0.5)


class TestStrokeMedian:
    """Test StrokeMedian trajectory data"""

    def test_from_hanzi_1024_single_point(self):
        """Test conversion of single-point stroke"""
        median = StrokeMedian.from_hanzi_1024([(512, 512)], stroke_order=0)
        assert len(median.points) == 1
        assert median.points[0].x == 0.5
        assert median.points[0].y == 0.5
        assert median.stroke_order == 0

    def test_from_hanzi_1024_multi_point(self):
        """Test conversion of multi-point stroke"""
        points = [(0, 0), (512, 512), (1024, 1024)]
        median = StrokeMedian.from_hanzi_1024(points, stroke_order=0)
        assert len(median.points) == 3
        assert median.points[0].x == 0.0
        assert median.points[1].x == 0.5
        assert median.points[2].x == 1.0

    def test_to_hanzi_1024_round_trip(self):
        """Test round-trip conversion of stroke trajectory"""
        original = [(100, 200), (300, 400), (500, 600)]
        median = StrokeMedian.from_hanzi_1024(original, stroke_order=0)
        converted = median.to_hanzi_1024()
        assert converted == original

    def test_min_length_validation(self):
        """Test that empty stroke list is rejected"""
        with pytest.raises(ValidationError):
            StrokeMedian(points=[], stroke_order=0)

    def test_stroke_order_negative_validation(self):
        """Test that negative stroke order is rejected"""
        with pytest.raises(ValidationError):
            StrokeMedian.from_hanzi_1024([(0, 0)], stroke_order=-1)


class TestCharacterData:
    """Test CharacterData model validation and conversion"""

    def test_from_hanzi_writer_minimal(self):
        """Test creation from minimal Hanzi Writer data"""
        data = {
            "character": "永",
            "strokes": ["M 300 100 Q 400 200 500 300"],
            "medians": [[[100, 100], [200, 200], [300, 300]]]
        }
        character = CharacterData.from_hanzi_writer(data)
        assert character.character == "永"
        assert character.source == CharacterSource.HANZI_WRITER
        assert len(character.strokes) == 1
        assert len(character.medians) == 1

    def test_from_hanzi_writer_with_radicals(self):
        """Test creation with radical data"""
        data = {
            "character": "字",
            "strokes": ["M 100 100 Q 200 200 300 300", "M 400 400 Q 500 500 600 600"],
            "medians": [
                [[100, 100], [200, 200]],
                [[400, 400], [500, 500]]
            ],
            "radicals": {
                "宀": {"symbol": "宀", "meaning": "roof"}
            }
        }
        character = CharacterData.from_hanzi_writer(data)
        assert character.radicals is not None
        assert "宀" in character.radicals
        assert character.radicals["宀"].meaning == "roof"

    def test_to_hanzi_writer_format(self):
        """Test export to Hanzi Writer format"""
        data = {
            "character": "永",
            "strokes": ["M 300 100 Q 400 200 500 300"],
            "medians": [[[100, 100], [200, 200], [300, 300]]]
        }
        character = CharacterData.from_hanzi_writer(data)
        exported = character.to_hanzi_writer_format()
        assert exported["character"] == "永"
        assert exported["strokes"] == data["strokes"]
        assert exported["medians"] == data["medians"]

    def test_coordinate_normalization(self):
        """Test that coordinates are normalized to 0-1"""
        data = {
            "character": "永",
            "strokes": ["M 300 100"],
            "medians": [[[0, 0], [512, 512], [1024, 1024]]]
        }
        character = CharacterData.from_hanzi_writer(data)
        # Check normalized coordinates
        assert character.medians[0].points[0].x == 0.0
        assert character.medians[0].points[1].x == 0.5
        assert character.medians[0].points[2].x == 1.0

    def test_validate_stroke_count_match(self):
        """Test that mismatched stroke/median counts are rejected"""
        with pytest.raises(ValidationError) as exc_info:
            CharacterData(
                character="永",
                source=CharacterSource.HANZI_WRITER,
                strokes=[StrokePath(path="M 100 100", stroke_order=0)],
                medians=[
                    StrokeMedian.from_hanzi_1024([(0, 0)], stroke_order=0),
                    StrokeMedian.from_hanzi_1024([(100, 100)], stroke_order=1)
                ]
            )
        assert "Stroke count mismatch" in str(exc_info.value)

    def test_validate_stroke_order_sequential(self):
        """Test that non-sequential stroke orders are rejected"""
        with pytest.raises(ValidationError) as exc_info:
            CharacterData(
                character="永",
                source=CharacterSource.HANZI_WRITER,
                strokes=[
                    StrokePath(path="M 100 100", stroke_order=0),
                    StrokePath(path="M 200 200", stroke_order=2)  # Skip 1
                ],
                medians=[
                    StrokeMedian.from_hanzi_1024([(0, 0)], stroke_order=0),
                    StrokeMedian.from_hanzi_1024([(100, 100)], stroke_order=2)
                ]
            )
        assert "Invalid stroke orders" in str(exc_info.value)

    def test_to_api_response(self):
        """Test API response format"""
        data = {
            "character": "永",
            "strokes": ["M 300 100 Q 400 200 500 300"],
            "medians": [[[100, 100], [200, 200]]]
        }
        character = CharacterData.from_hanzi_writer(data)
        response = character.to_api_response()
        assert response["character"] == "永"
        assert response["source"] == "hanzi-writer-data"
        assert "strokes" in response
        assert "medians" in response
        assert len(response["strokes"]) == 1
        assert len(response["medians"]) == 1
        # Check normalized coordinates in response
        assert response["medians"][0]["points"][0] == [100/1024, 100/1024]

    def test_multi_stroke_character(self):
        """Test character with multiple strokes (like '永' with 5 strokes)"""
        data = {
            "character": "永",
            "strokes": [
                "M 300 100 Q 350 150 400 200",  # Stroke 0
                "M 350 250 Q 400 300 450 350",  # Stroke 1
                "M 300 300 L 400 400",          # Stroke 2
                "M 200 350 L 400 350",          # Stroke 3
                "M 300 450 L 300 550"           # Stroke 4
            ],
            "medians": [
                [[300, 100], [350, 150], [400, 200]],
                [[350, 250], [400, 300], [450, 350]],
                [[300, 300], [400, 400]],
                [[200, 350], [400, 350]],
                [[300, 450], [300, 550]]
            ]
        }
        character = CharacterData.from_hanzi_writer(data)
        assert len(character.strokes) == 5
        assert len(character.medians) == 5
        # Verify stroke orders
        for i, stroke in enumerate(character.strokes):
            assert stroke.stroke_order == i
        for i, median in enumerate(character.medians):
            assert median.stroke_order == i


class TestCharacterRequest:
    """Test CharacterRequest validation"""

    def test_valid_single_character(self):
        """Test valid single character request"""
        request = CharacterRequest(character="永")
        assert request.character == "永"
        assert request.coordinate_system == CoordinateSystem.NORMALIZED

    def test_valid_coordinate_system(self):
        """Test coordinate system selection"""
        request = CharacterRequest(
            character="永",
            coordinate_system=CoordinateSystem.HANZI_1024
        )
        assert request.coordinate_system == CoordinateSystem.HANZI_1024

    def test_invalid_empty_character(self):
        """Test that empty character is rejected"""
        with pytest.raises(ValidationError):
            CharacterRequest(character="")

    def test_invalid_multi_character(self):
        """Test that multi-character string is rejected"""
        with pytest.raises(ValidationError):
            CharacterRequest(character="汉字")


class TestRoundTripConsistency:
    """Test data consistency through round-trip conversions"""

    def test_hanzi_writer_round_trip(self):
        """Test that data survives Hanzi Writer format round-trip"""
        original = {
            "character": "永",
            "strokes": [
                "M 300 100 Q 350 150 400 200",
                "M 350 250 Q 400 300 450 350"
            ],
            "medians": [
                [[300, 100], [350, 150], [400, 200]],
                [[350, 250], [400, 300], [450, 350]]
            ],
            "radicals": {
                "水": {"symbol": "水", "meaning": "water"}
            }
        }
        character = CharacterData.from_hanzi_writer(original)
        exported = character.to_hanzi_writer_format()

        assert exported["character"] == original["character"]
        assert exported["strokes"] == original["strokes"]
        assert exported["medians"] == original["medians"]
        assert exported["radicals"] == original["radicals"]

    def test_coordinate_precision_preservation(self):
        """Test that coordinate precision is preserved through conversions"""
        test_cases = [
            (0, 0),
            (1024, 1024),
            (512, 512),
            (100, 200),
            (999, 888),
        ]
        for x, y in test_cases:
            point = MedianPoint.from_hanzi_1024(x, y)
            converted = point.to_hanzi_1024()
            assert converted == (x, y), f"Precision lost for ({x}, {y})"
