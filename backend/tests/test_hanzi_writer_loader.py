"""
HanziWriterLoader Tests - 汢字数据加载器测试

Tests for Hanzi Writer CDN data loader.
Following TDD principles with RED-GREEN-REFACTOR cycle.
"""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
import httpx

from app.parsers.hanzi_writer import HanziWriterLoader
from app.models.character import CharacterData, CharacterSource


class TestHanziWriterLoader:
    """Test HanziWriterLoader CDN integration"""

    @pytest.fixture
    def loader(self):
        """Create loader instance"""
        return HanziWriterLoader()

    @pytest.fixture
    def mock_hanzi_writer_response(self):
        """Mock Hanzi Writer CDN response for '永' character"""
        return {
            "character": "永",
            "strokes": [
                "M 300 100 Q 350 150 400 200",  # Stroke 0: dot
                "M 350 250 Q 400 300 450 350",  # Stroke 1: horizontal
                "M 300 300 L 400 400",          # Stroke 2: vertical
                "M 200 350 L 400 350",          # Stroke 3: hook
                "M 300 450 L 300 550"           # Stroke 4: right-falling
            ],
            "medians": [
                [[300, 100], [350, 150], [400, 200]],
                [[350, 250], [400, 300], [450, 350]],
                [[300, 300], [400, 400]],
                [[200, 350], [400, 350]],
                [[300, 450], [300, 550]]
            ],
            "radicals": {
                "水": {"symbol": "水", "meaning": "water"}
            }
        }

    @pytest.mark.asyncio
    async def test_load_character_success(self, loader, mock_hanzi_writer_response):
        """Test successful character loading from CDN"""
        with patch("httpx.AsyncClient.get") as mock_get:
            # Mock successful response (use MagicMock for sync methods, AsyncMock for async)
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json = MagicMock(return_value=mock_hanzi_writer_response)
            mock_response.raise_for_status = MagicMock()
            mock_get.return_value = mock_response

            # Load character
            character = await loader.load_character("永")

            # Verify
            assert isinstance(character, CharacterData)
            assert character.character == "永"
            assert character.source == CharacterSource.HANZI_WRITER
            assert len(character.strokes) == 5
            assert len(character.medians) == 5

            # Verify CDN URL was called correctly
            mock_get.assert_called_once()
            call_args = mock_get.call_args
            assert "永.json" in str(call_args)

    @pytest.mark.asyncio
    async def test_load_character_not_found(self, loader):
        """Test 404 error when character not found on CDN"""
        with patch("httpx.AsyncClient.get") as mock_get:
            # Mock 404 response
            mock_response = MagicMock()
            mock_response.status_code = 404
            mock_response.raise_for_status.side_effect = httpx.HTTPStatusError(
                "Not Found", request=MagicMock(), response=mock_response
            )
            mock_get.return_value = mock_response

            # Should raise HTTPStatusError
            with pytest.raises(httpx.HTTPStatusError):
                await loader.load_character("𠮷")  # Rare character

    @pytest.mark.asyncio
    async def test_load_character_network_error(self, loader):
        """Test network error handling"""
        with patch("httpx.AsyncClient.get") as mock_get:
            # Mock network error
            mock_get.side_effect = httpx.NetworkError("Connection failed")

            # Should raise NetworkError
            with pytest.raises(httpx.NetworkError):
                await loader.load_character("永")

    @pytest.mark.asyncio
    async def test_load_character_invalid_data(self, loader):
        """Test handling of invalid CDN response (missing medians)"""
        with patch("httpx.AsyncClient.get") as mock_get:
            # Mock response with invalid data (missing medians)
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json = MagicMock(return_value={
                "character": "永",
                "strokes": ["M 100 100"]
                # Missing "medians" key
            })
            mock_response.raise_for_status = MagicMock()
            mock_get.return_value = mock_response

            # Should raise ValueError due to missing medians
            with pytest.raises(ValueError, match="medians"):
                await loader.load_character("永")

    @pytest.mark.asyncio
    async def test_batch_load_multiple_characters(self, loader, mock_hanzi_writer_response):
        """Test loading multiple characters in batch"""
        with patch("httpx.AsyncClient.get") as mock_get:
            # Mock successful responses for two characters
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json = MagicMock(return_value=mock_hanzi_writer_response)
            mock_response.raise_for_status = MagicMock()
            mock_get.return_value = mock_response

            # Load batch
            characters = await loader.batch_load(["永", "字"])

            # Verify
            assert len(characters) == 2
            assert "永" in characters
            assert "字" in characters
            assert isinstance(characters["永"], CharacterData)
            assert isinstance(characters["字"], CharacterData)

    @pytest.mark.asyncio
    async def test_batch_load_partial_failure(self, loader, mock_hanzi_writer_response):
        """Test batch load with some characters failing"""
        with patch("httpx.AsyncClient.get") as mock_get:
            async def mock_get_side_effect(url, **kwargs):
                mock_response = MagicMock()
                if "永.json" in url:
                    mock_response.status_code = 200
                    mock_response.json = MagicMock(return_value=mock_hanzi_writer_response)
                    mock_response.raise_for_status = MagicMock()
                elif "字.json" in url:
                    mock_response.status_code = 404
                    mock_response.raise_for_status.side_effect = httpx.HTTPStatusError(
                        "Not Found", request=MagicMock(), response=mock_response
                    )
                return mock_response

            mock_get.side_effect = mock_get_side_effect

            # Should raise error on first failure (or we could collect all errors)
            with pytest.raises(httpx.HTTPStatusError):
                await loader.batch_load(["永", "字"])

    def test_cdn_url_construction(self, loader):
        """Test that CDN URL is constructed correctly"""
        char = "永"
        expected_url = f"{loader.CDN_URL}{char}.json"
        assert loader._get_cdn_url(char) == expected_url

    def test_cdn_url_construction_different_chars(self, loader):
        """Test CDN URL construction for various characters"""
        test_cases = [
            ("永", "https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/永.json"),
            ("字", "https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/字.json"),
            ("中", "https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/中.json"),
        ]
        for char, expected_url in test_cases:
            assert loader._get_cdn_url(char) == expected_url

    @pytest.mark.asyncio
    async def test_load_character_without_radicals(self, loader):
        """Test loading character without radical data"""
        with patch("httpx.AsyncClient.get") as mock_get:
            # Mock response without radicals
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json = MagicMock(return_value={
                "character": "永",
                "strokes": ["M 100 100"],
                "medians": [[[100, 100]]]
                # No radicals key
            })
            mock_response.raise_for_status = MagicMock()
            mock_get.return_value = mock_response

            # Should still work
            character = await loader.load_character("永")
            assert character.radicals is None

    @pytest.mark.asyncio
    async def test_caching_behavior(self, loader, mock_hanzi_writer_response):
        """Test that loading same character twice uses cache (if implemented)"""
        with patch("httpx.AsyncClient.get") as mock_get:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json = MagicMock(return_value=mock_hanzi_writer_response)
            mock_response.raise_for_status = MagicMock()
            mock_get.return_value = mock_response

            # Load same character twice
            await loader.load_character("永")
            await loader.load_character("永")

            # If caching is implemented, this should be called only once
            # For now, we expect two calls (no caching)
            assert mock_get.call_count == 2


class TestHanziWriterLoaderIntegration:
    """Integration tests (may require actual network access)"""

    @pytest.fixture
    def loader(self):
        """Create loader instance"""
        return HanziWriterLoader()

    @pytest.mark.slow
    @pytest.mark.asyncio
    async def test_load_real_character_from_cdn(self, loader):
        """
        Test loading a real character from Hanzi Writer CDN

        NOTE: This test requires actual network access.
        Mark with @pytest.mark.slow to skip in fast test runs.
        """
        # Try loading a common character
        character = await loader.load_character("永")

        assert isinstance(character, CharacterData)
        assert character.character == "永"
        assert len(character.strokes) > 0
        assert len(character.medians) > 0
        assert len(character.strokes) == len(character.medians)
