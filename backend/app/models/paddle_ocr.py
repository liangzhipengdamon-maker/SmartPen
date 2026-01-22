"""
PaddleOCR Model Wrapper - PaddleOCR 字符验证

Uses PaddleOCR library to verify user's written character matches expected.
防止张冠李戴 (prevent misattribution).
"""

import logging
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional, Union
from pydantic import BaseModel
import threading

# PaddleOCR import
try:
    from paddleocr import PaddleOCR as PaddleOCRBase
    PADDLEOCR_AVAILABLE = True
except ImportError:
    PaddleOCRBase = None
    PADDLEOCR_AVAILABLE = False
    logging.warning("PaddleOCR not installed. Install: pip install paddleocr")

logger = logging.getLogger(__name__)


class OCRResult(BaseModel):
    """Result from OCR prediction"""
    text: str
    confidence: float
    bbox: List[Tuple[int, int]] = []


class PaddleOCRModel:
    """
    PaddleOCR model wrapper for character verification.

    Singleton pattern to ensure only one model instance.
    """

    _instance: Optional['PaddleOCRModel'] = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if not hasattr(self, '_initialized'):
            self.model = None
            self._is_loaded = False
            self._initialized = True
            logger.info("PaddleOCRModel initialized")

    @classmethod
    def get_instance(cls) -> 'PaddleOCRModel':
        """Get the singleton instance"""
        return cls()

    def is_loaded(self) -> bool:
        """Check if model is loaded"""
        return self._is_loaded and self.model is not None

    def load(self, use_gpu: bool = False) -> None:
        """
        Load PaddleOCR model.

        Args:
            use_gpu: Whether to use GPU acceleration
        """
        if self.is_loaded():
            logger.info("Model already loaded")
            return

        if not PADDLEOCR_AVAILABLE:
            logger.warning("PaddleOCR not available, using mock model")
            self._create_mock_model()
            return

        try:
            # Initialize PaddleOCR
            # use_angle_cls=True for character direction recognition
            # lang=ch for Chinese characters
            self.model = PaddleOCRBase(
                use_angle_cls=True,
                lang='ch',
                use_gpu=use_gpu,
                show_log=False
            )
            self._is_loaded = True
            logger.info("PaddleOCR model loaded successfully")

        except Exception as e:
            logger.error(f"Failed to load PaddleOCR: {e}")
            logger.info("Falling back to mock model")
            self._create_mock_model()

    def _create_mock_model(self) -> None:
        """Create a mock model for testing"""
        logger.warning("Using mock PaddleOCR model for testing")

        class MockPaddleOCR:
            """Mock OCR that returns fixed results"""

            def __init__(self):
                self.loaded = True

            def ocr(self, image):
                """Return mock OCR result"""
                return [[
                    [0, 0, 100, 100],  # bbox
                    ("永", 0.95)  # (text, confidence)
                ]]

        self.model = MockPaddleOCR()
        self._is_loaded = True

    def ocr(
        self,
        image: Union[np.ndarray, str, Path]
    ) -> OCRResult:
        """
        Perform OCR on image.

        Args:
            image: Input image as numpy array or file path

        Returns:
            OCRResult with text and confidence
        """
        if not self.is_loaded():
            self.load()

        # Load image if path provided
        if isinstance(image, (str, Path)):
            image = self._load_image_from_path(image)

        # Preprocess
        processed = preprocess_ocr_image(image)

        # Run OCR
        try:
            results = self.model.ocr(processed)

            # Extract first result
            if results and len(results) > 0 and results[0]:
                result = results[0][0]
                bbox = result[0]
                text_info = result[1]
                text = text_info[0]
                confidence = text_info[1]

                return OCRResult(
                    text=text,
                    confidence=float(confidence),
                    bbox=[tuple(p) for p in bbox]
                )

        except Exception as e:
            logger.error(f"OCR failed: {e}")

        # Fallback result
        return OCRResult(
            text="",
            confidence=0.0,
            bbox=[]
        )

    def verify_character(
        self,
        image: Union[np.ndarray, str, Path],
        expected_char: str,
        min_confidence: float = 0.7
    ) -> bool:
        """
        Verify that image contains expected character.

        Args:
            image: Input image
            expected_char: Expected Chinese character
            min_confidence: Minimum confidence threshold

        Returns:
            True if character matches with sufficient confidence
        """
        result = self.ocr(image)
        return verify_character_match(result, expected_char, min_confidence)

    def _load_image_from_path(self, path: Union[str, Path]) -> np.ndarray:
        """Load image from file path"""
        from PIL import Image
        img = Image.open(path)
        return np.array(img)


def verify_character_match(
    result: OCRResult,
    expected_char: str,
    min_confidence: float = 0.7
) -> bool:
    """
    Verify OCR result matches expected character.

    Args:
        result: OCR result
        expected_char: Expected character
        min_confidence: Minimum confidence threshold

    Returns:
        True if match is confident
    """
    # Check confidence threshold
    if result.confidence < min_confidence:
        logger.debug(
            f"Confidence too low: {result.confidence} < {min_confidence}"
        )
        return False

    # Check exact character match
    if result.text != expected_char:
        logger.debug(
            f"Character mismatch: '{result.text}' != '{expected_char}'"
        )
        return False

    return True


def preprocess_ocr_image(image: np.ndarray) -> np.ndarray:
    """
    Preprocess image for OCR.

    Args:
        image: Input image (H, W, 3)

    Returns:
        Preprocessed image
    """
    # Ensure RGB
    if len(image.shape) == 2:  # Grayscale
        image = np.stack([image] * 3, axis=-1)
    elif image.shape[-1] == 4:  # RGBA
        image = image[..., :3]

    # PaddleOCR handles RGB/GRayscale automatically
    # Just ensure correct dtype
    if image.dtype != np.uint8:
        image = (image * 255).astype(np.uint8)

    return image
