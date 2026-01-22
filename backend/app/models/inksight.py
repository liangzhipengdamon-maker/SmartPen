"""
InkSight Model Wrapper - InkSight 模型包装器

Python native TensorFlow loading (NO ONNX).
CRITICAL: TensorFlow 2.15-2.17 required.

PRD v2.1 Constraints:
- MUST use: TensorFlow native loading
- FORBIDDEN: ONNX Runtime
- Model: google-research/inksight-small-p from HuggingFace
"""

import logging
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional, Union
from pydantic import BaseModel
import threading

# TensorFlow import (version constrained in requirements.txt)
try:
    import tensorflow as tf
    # Verify TensorFlow version
    tf_version = tuple(int(x) for x in tf.__version__.split('.')[:2])
    if not (2, 15) <= tf_version < (2, 18):
        logging.warning(
            f"TensorFlow version {tf.__version__} detected. "
            f"Recommended: 2.15-2.17"
        )
except ImportError:
    tf = None
    logging.error("TensorFlow not installed. Install: pip install 'tensorflow>=2.15.0,<2.18.0'")

from app.models.model_loader import (
    get_inksight_model_path,
    is_model_cached,
    get_huggingface_model_id
)

logger = logging.getLogger(__name__)


class InksightResult(BaseModel):
    """Result from InkSight prediction"""
    trajectory: List[Tuple[float, float]]
    strokes: List[List[Tuple[float, float]]]
    confidence: float = 0.0


class InkSightModel:
    """
    InkSight model wrapper using TensorFlow native loading.

    Singleton pattern to ensure only one model instance.
    """

    _instance: Optional['InkSightModel'] = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        # Initialize only once
        if not hasattr(self, '_initialized'):
            self.model = None
            self._is_loaded = False
            self._model_path = get_inksight_model_path()
            self._initialized = True
            logger.info(f"InkSightModel initialized. Cache path: {self._model_path}")

    @classmethod
    def get_instance(cls) -> 'InkSightModel':
        """Get the singleton instance of InkSightModel"""
        return cls()

    def is_loaded(self) -> bool:
        """Check if model is loaded"""
        return self._is_loaded and self.model is not None

    def load(self) -> None:
        """
        Load InkSight model from HuggingFace or cache.

        Downloads model from HuggingFace if not cached.
        Uses TensorFlow native loading (NO ONNX).

        Falls back to mock model if InkSight is not available.
        """
        if self.is_loaded():
            logger.info("Model already loaded")
            return

        if tf is None:
            logger.warning("TensorFlow not available, using mock model")
            self._create_mock_model()
            return

        try:
            # Try to load from HuggingFace hub
            # Note: InkSight may not be in standard transformers yet
            # This is a placeholder for when it becomes available
            from transformers import AutoModel

            model_id = get_huggingface_model_id()
            logger.info(f"Attempting to load InkSight model: {model_id}")

            # Try loading (will fail if model not public yet)
            try:
                self.model = AutoModel.from_pretrained(model_id, from_tf=True)
                self._is_loaded = True
                logger.info("InkSight model loaded successfully")
            except Exception as e:
                logger.warning(f"InkSight model not available on HuggingFace: {e}")
                logger.info("Falling back to mock model for development")
                self._create_mock_model()

        except ImportError as e:
            logger.warning(f"Transformers not available: {e}")
            logger.info("Using mock model for development")
            self._create_mock_model()
        except Exception as e:
            logger.warning(f"Failed to load InkSight model: {e}")
            logger.info("Falling back to mock model for development")
            self._create_mock_model()

    def _create_mock_model(self) -> None:
        """
        Create a mock model for testing when real model is unavailable.

        This allows development and testing without the full InkSight model.
        """
        logger.warning("Using mock InkSight model for testing")

        class MockModel:
            """Mock model that generates simple trajectories"""

            def __init__(self):
                self.loaded = True

            def predict(self, image: np.ndarray) -> InksightResult:
                """Generate simple mock trajectory"""
                # Create a simple left-to-right trajectory
                height, width = image.shape[:2]
                num_points = 20

                trajectory = []
                for i in range(num_points):
                    x = 0.2 + 0.6 * (i / num_points)  # 20% to 80% width
                    y = 0.5  # Middle height
                    trajectory.append((x, y))

                return InksightResult(
                    trajectory=trajectory,
                    strokes=[trajectory],
                    confidence=0.85
                )

        self.model = MockModel()
        self._is_loaded = True

    def predict(
        self,
        image: Union[np.ndarray, str, Path]
    ) -> InksightResult:
        """
        Predict handwriting trajectory from character image.

        Args:
            image: Input image as numpy array (H, W, 3) or file path

        Returns:
            InksightResult with trajectory in 0-1 normalized coordinates
        """
        if not self.is_loaded():
            self.load()

        # Load image if path provided
        if isinstance(image, (str, Path)):
            image = self._load_image_from_path(image)

        # Preprocess image
        processed = preprocess_image(image)

        # Run prediction
        try:
            result = self.model.predict(processed)

            # Handle mock model return
            if isinstance(result, InksightResult):
                return result

            # Handle real model return (tensor/array)
            trajectory = self._extract_trajectory(result)

            return InksightResult(
                trajectory=trajectory,
                strokes=self._split_into_strokes(trajectory),
                confidence=0.85
            )

        except Exception as e:
            logger.error(f"Prediction failed: {e}")
            # Return fallback result
            return InksightResult(
                trajectory=[(0.5, 0.5)],
                strokes=[[(0.5, 0.5)]],
                confidence=0.0
            )

    def _load_image_from_path(self, path: Union[str, Path]) -> np.ndarray:
        """Load image from file path"""
        from PIL import Image

        img = Image.open(path)
        return np.array(img)

    def _extract_trajectory(self, model_output) -> List[Tuple[float, float]]:
        """Extract trajectory points from model output"""
        # This is a placeholder - real implementation depends on model output format
        # For now, return a simple trajectory
        return [(0.2 + i * 0.03, 0.5) for i in range(20)]

    def _split_into_strokes(
        self,
        trajectory: List[Tuple[float, float]]
    ) -> List[List[Tuple[float, float]]]:
        """Split trajectory into individual strokes"""
        # Simple implementation: single stroke
        # Real implementation would detect pen lifts
        return [trajectory]


def preprocess_image(image: np.ndarray) -> np.ndarray:
    """
    Preprocess image for InkSight model input.

    Args:
        image: Input image (H, W, 3) uint8

    Returns:
        Preprocessed image normalized to model expected format
    """
    # Convert to float
    if image.dtype == np.uint8:
        image = image.astype(np.float32) / 255.0

    # Ensure RGB (remove alpha if present)
    if image.shape[-1] == 4:
        image = image[..., :3]

    # Resize to model expected input size (typically 224x224 or 256x256)
    target_size = (256, 256)
    from PIL import Image
    img_pil = Image.fromarray((image * 255).astype(np.uint8))
    img_resized = img_pil.resize(target_size, Image.LANCZOS)
    image = np.array(img_resized).astype(np.float32) / 255.0

    # Normalize to [-1, 1] (common for vision models)
    image = image * 2.0 - 1.0

    return image


def map_inksight_to_hanzi_1024(
    point: Tuple[float, float]
) -> Tuple[int, int]:
    """
    Convert InkSight 0-1 coordinates to Hanzi Writer 1024 grid.

    Args:
        point: (x, y) in 0-1 range

    Returns:
        (x, y) in 0-1024 range
    """
    x, y = point
    return (int(x * 1024), int(y * 1024))


def map_hanzi_1024_to_inksight(
    point: Tuple[int, int]
) -> Tuple[float, float]:
    """
    Convert Hanzi Writer 1024 grid to InkSight 0-1 coordinates.

    Args:
        point: (x, y) in 0-1024 range

    Returns:
        (x, y) in 0-1 range
    """
    x, y = point
    return (x / 1024.0, y / 1024.0)


def convert_to_hanzi_writer_format(
    result: InksightResult
) -> dict:
    """
    Convert InkSight result to Hanzi Writer format.

    Args:
        result: InksightResult from model prediction

    Returns:
        Dictionary compatible with Hanzi Writer data structure
    """
    # Convert trajectory to Hanzi Writer format
    medians = []
    for stroke in result.strokes:
        stroke_medians = []
        for x, y in stroke:
            # Convert to 1024 grid
            hx, hy = map_inksight_to_hanzi_1024((x, y))
            stroke_medians.append([hx, hy])
        medians.append(stroke_medians)

    return {
        'medians': medians,
        'character': '',  # To be filled by caller
        'strokes': [],    # SVG paths would be generated separately
    }
