"""
Basic tests for SmartPen backend

基础测试 - 验证项目结构是否正确
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import AsyncMock, patch, MagicMock

from app.main import app
from app.models.character import CharacterData, CharacterSource


@pytest.fixture
def client():
    """Create test client"""
    return TestClient(app)


@pytest.fixture
def mock_character_data():
    """Mock character data for testing"""
    return {
        "character": "永",
        "source": "hanzi-writer-data",
        "strokes": [
            {"path": "M 300 100 Q 400 200 500 300", "stroke_order": 0}
        ],
        "medians": [
            {
                "points": [[100/1024, 100/1024], [200/1024, 200/1024]],
                "stroke_order": 0
            }
        ],
        "radicals": None
    }


class TestRootEndpoints:
    """Test root and health endpoints"""

    def test_root_endpoint(self, client):
        """Test root endpoint returns API info"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "SmartPen" in data["message"]
        assert data["version"] == "0.1.0"

    def test_health_check(self, client):
        """Test health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"


class TestCharacterEndpoints:
    """Test character retrieval endpoints"""

    @pytest.mark.asyncio
    async def test_get_character_endpoint_with_mock(self, client, mock_character_data):
        """Test character endpoint returns data (with mocked loader)"""
        with patch("app.api.characters._loader.load_character") as mock_load:
            # Create a CharacterData instance to return
            from app.models.character import CharacterData, StrokePath, StrokeMedian, MedianPoint

            mock_character = CharacterData(
                character="永",
                source=CharacterSource.HANZI_WRITER,
                strokes=[StrokePath(path="M 300 100 Q 400 200 500 300", stroke_order=0)],
                medians=[
                    StrokeMedian(
                        points=[MedianPoint(x=100/1024, y=100/1024), MedianPoint(x=200/1024, y=200/1024)],
                        stroke_order=0
                    )
                ]
            )
            mock_load.return_value = mock_character

            response = client.get("/api/characters/永")
            assert response.status_code == 200
            data = response.json()
            assert data["character"] == "永"
            assert "strokes" in data
            assert "medians" in data

    def test_get_character_invalid_input(self, client):
        """Test character endpoint rejects invalid input"""
        response = client.get("/api/characters/abc")
        assert response.status_code == 400

    def test_get_character_empty_input(self, client):
        """Test character endpoint rejects empty string"""
        response = client.get("/api/characters/")
        assert response.status_code == 404  # Not found - empty path doesn't match route

    @pytest.mark.asyncio
    async def test_get_character_not_found(self, client):
        """Test character endpoint returns 404 for rare character"""
        with patch("app.api.characters._loader.load_character") as mock_load:
            import httpx
            mock_load.side_effect = httpx.HTTPStatusError(
                "Not Found", request=MagicMock(), response=MagicMock(status_code=404)
            )

            response = client.get("/api/characters/𠮷")
            assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_get_character_status_available(self, client):
        """Test character status endpoint for available character"""
        with patch("app.api.characters._loader.load_character") as mock_load:
            from app.models.character import CharacterData, StrokePath, StrokeMedian, MedianPoint

            mock_character = CharacterData(
                character="永",
                source=CharacterSource.HANZI_WRITER,
                strokes=[StrokePath(path="M 300 100", stroke_order=0)],
                medians=[StrokeMedian(points=[MedianPoint(x=0.5, y=0.5)], stroke_order=0)]
            )
            mock_load.return_value = mock_character

            response = client.get("/api/characters/永/status")
            assert response.status_code == 200
            data = response.json()
            assert data["character"] == "永"
            assert data["available"] is True
            assert data["source"] == "hanzi-writer-data"

    @pytest.mark.asyncio
    async def test_get_character_status_not_available(self, client):
        """Test character status endpoint for unavailable character"""
        with patch("app.api.characters._loader.load_character") as mock_load:
            import httpx
            mock_load.side_effect = httpx.HTTPStatusError(
                "Not Found", request=MagicMock(), response=MagicMock(status_code=404)
            )

            response = client.get("/api/characters/𠮷/status")
            assert response.status_code == 200
            data = response.json()
            assert data["character"] == "𠮷"
            assert data["available"] is False


class TestScoringEndpoints:
    """Test scoring endpoints"""

    @pytest.fixture
    def mock_two_stroke_character(self):
        """Mock character data with two strokes"""
        from app.models.character import StrokePath, StrokeMedian, MedianPoint

        return CharacterData(
            character="永",
            source=CharacterSource.HANZI_WRITER,
            strokes=[
                StrokePath(path="M 300 100 Q 400 200 500 300", stroke_order=0),
                StrokePath(path="M 100 300 Q 200 400 300 500", stroke_order=1),
            ],
            medians=[
                StrokeMedian(
                    points=[MedianPoint(x=0.1, y=0.1), MedianPoint(x=0.2, y=0.2)],
                    stroke_order=0
                ),
                StrokeMedian(
                    points=[MedianPoint(x=0.3, y=0.3), MedianPoint(x=0.4, y=0.4)],
                    stroke_order=1
                ),
            ]
        )

    @pytest.mark.asyncio
    async def test_score_comprehensive_stroke_count_mismatch(self, client, mock_two_stroke_character):
        """Stroke count mismatch should return '笔顺错误' and skip DTW"""
        with patch("app.api.scoring._loader.load_character") as mock_load, \
                patch("app.api.scoring.calculate_dtw_distance") as mock_dtw:
            mock_load.return_value = mock_two_stroke_character
            mock_dtw.side_effect = AssertionError("DTW should not be called on stroke mismatch")

            payload = {
                "character": "永",
                "user_strokes": [
                    [(0.1, 0.1), (0.2, 0.2)],  # Only 1 stroke
                ],
                "posture_data": None,
            }

            response = client.post("/api/score/comprehensive", json=payload)
            assert response.status_code == 200
            data = response.json()
            assert data["feedback"] == "笔顺错误"
            assert data.get("error_type") == "stroke_count_mismatch"
            assert data["total_score"] == 0.0

    @pytest.mark.asyncio
    async def test_score_comprehensive_stroke_count_match(self, client, mock_two_stroke_character):
        """Stroke count match should proceed to scoring"""
        with patch("app.api.scoring._loader.load_character") as mock_load, \
                patch("app.api.scoring.calculate_dtw_distance") as mock_dtw:
            mock_load.return_value = mock_two_stroke_character
            mock_dtw.return_value = 0.0

            payload = {
                "character": "永",
                "user_strokes": [
                    [(0.1, 0.1), (0.2, 0.2)],
                    [(0.3, 0.3), (0.4, 0.4)],
                ],
                "posture_data": None,
            }

            response = client.post("/api/score/comprehensive", json=payload)
            assert response.status_code == 200
            data = response.json()
            assert data["feedback"] != "笔顺错误"
            assert data.get("error_type") is None
