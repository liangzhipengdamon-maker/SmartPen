"""
Hanzi Writer CDN Loader - 汉字数据加载器

Loads character stroke and median data from Hanzi Writer CDN.
Converts 1024-grid coordinates to normalized 0-1 coordinates.
"""

import httpx
from typing import Dict, List
import logging

from app.models.character import CharacterData, CharacterSource

logger = logging.getLogger(__name__)


class HanziWriterLoader:
    """
    Load Hanzi Writer character data from CDN

    CDN URL: https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/

    Data format:
    {
        "character": "永",
        "strokes": ["M 300 100 Q ..."],  # SVG paths for rendering
        "medians": [[[100, 100], [200, 200], ...]],  # Stroke trajectories for scoring
        "radicals": {...}  # Optional
    }
    """

    CDN_URL = "https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/"


    def __init__(self, timeout: float = 10.0):
        """
        Initialize loader

        Args:
            timeout: HTTP request timeout in seconds
        """
        self.timeout = timeout

    def _get_cdn_url(self, char: str) -> str:
        """
        Construct CDN URL for character

        Args:
            char: Single Chinese character

        Returns:
            Full CDN URL
        """
        url = f"{self.CDN_URL}{char}.json"
        logger.debug("HanziWriter CDN URL: %s", url)
        return url

    async def load_character(self, char: str) -> CharacterData:
        """
        Load character data from Hanzi Writer CDN

        Args:
            char: Single Chinese character (e.g., "永")

        Returns:
            CharacterData with normalized coordinates (0-1)

        Raises:
            httpx.HTTPStatusError: If character not found (404)
            httpx.NetworkError: If network request fails
            ValueError: If CDN response is invalid
        """
        url = self._get_cdn_url(char)

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                logger.debug(f"Loading character '{char}' from {url}")
                response = await client.get(url)
                response.raise_for_status()
                data = response.json()

        except httpx.HTTPStatusError as e:
            logger.error(f"Failed to load character '{char}': HTTP {e.response.status_code}")
            raise
        except httpx.NetworkError as e:
            logger.error(f"Network error loading character '{char}': {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error loading character '{char}': {e}")
            raise

        # Validate response data
        if not isinstance(data, dict):
            raise ValueError(f"Invalid response for character '{char}': expected dict, got {type(data)}")

        if "medians" not in data:
            raise ValueError(f"Invalid data for character '{char}': missing 'medians' field")

        if "strokes" not in data:
            raise ValueError(f"Invalid data for character '{char}': missing 'strokes' field")

        # Parse and convert to CharacterData
        try:
            # Pass character string since CDN response doesn't include it
            character = CharacterData.from_hanzi_writer(data, character=char)
            logger.info(f"Successfully loaded character '{char}' with {len(character.strokes)} strokes")
            return character
        except Exception as e:
            logger.error(f"Failed to parse data for character '{char}': {e}")
            raise ValueError(f"Failed to parse character data: {e}")

    async def batch_load(self, chars: List[str]) -> Dict[str, CharacterData]:
        """
        Load multiple characters in batch

        Args:
            chars: List of Chinese characters

        Returns:
            Dict mapping character to CharacterData

        Raises:
            httpx.HTTPStatusError: If any character fails to load
        """
        results = {}
        for char in chars:
            results[char] = await self.load_character(char)
        return results
