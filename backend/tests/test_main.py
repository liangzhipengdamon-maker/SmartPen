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
