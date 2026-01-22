"""
Characters API Router - 汉字数据检索端点

Provides endpoints for retrieving Hanzi Writer character data
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, List
import logging

from app.parsers.hanzi_writer import HanziWriterLoader
from app.models.character import CharacterData, CoordinateSystem

logger = logging.getLogger(__name__)

router = APIRouter()

# Create shared loader instance
_loader = HanziWriterLoader()


class CharacterResponse(BaseModel):
    """Character data response model (normalized coordinates)"""
    character: str
    source: str
    strokes: List[Dict]
    medians: List[Dict]
    radicals: Optional[Dict] = None


class CharacterStatusResponse(BaseModel):
    """Character availability status response"""
    character: str
    available: bool
    source: str


@router.get("/characters/{char}", response_model=CharacterResponse)
async def get_character(char: str):
    """
    Retrieve character data from Hanzi Writer CDN

    Args:
        char: Single Chinese character (e.g., "永")

    Returns:
        Character data including strokes (SVG paths) and medians (normalized coordinates)

    Raises:
        HTTPException: 400 if invalid input, 404 if character not found, 500 on other errors
    """
    if len(char) != 1:
        raise HTTPException(
            status_code=400,
            detail="Please provide a single character"
        )

    try:
        # Load character data from CDN
        character_data = await _loader.load_character(char)

        # Convert to API response format (normalized coordinates)
        response_dict = character_data.to_api_response()
        return CharacterResponse(**response_dict)

    except Exception as e:
        # Handle specific error types
        error_msg = str(e)
        if "404" in error_msg or "Not Found" in error_msg:
            logger.warning(f"Character '{char}' not found on CDN")
            raise HTTPException(
                status_code=404,
                detail=f"Character '{char}' not found in database"
            )
        elif "Network" in error_msg or "Connection" in error_msg:
            logger.error(f"Network error loading character '{char}': {e}")
            raise HTTPException(
                status_code=503,
                detail="Unable to connect to character data service"
            )
        else:
            logger.error(f"Unexpected error loading character '{char}': {e}")
            raise HTTPException(
                status_code=500,
                detail="An unexpected error occurred"
            )


@router.get("/characters/{char}/status", response_model=CharacterStatusResponse)
async def get_character_status(char: str):
    """
    Check if character data is available on CDN

    Args:
        char: Single Chinese character

    Returns:
        Status information including availability and data source
    """
    if len(char) != 1:
        raise HTTPException(
            status_code=400,
            detail="Please provide a single character"
        )

    try:
        # Try to load the character to verify availability
        await _loader.load_character(char)
        return CharacterStatusResponse(
            character=char,
            available=True,
            source="hanzi-writer-data"
        )
    except Exception as e:
        error_msg = str(e)
        if "404" in error_msg or "Not Found" in error_msg:
            return CharacterStatusResponse(
                character=char,
                available=False,
                source="hanzi-writer-data"
            )
        else:
            # Other errors (network, etc.) don't mean the character doesn't exist
            return CharacterStatusResponse(
                character=char,
                available=True,  # Assume available if we can't check
                source="hanzi-writer-data"
            )
