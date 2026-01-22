"""
InkSight Model Tests - InkSight 模型测试

Tests for InkSight model wrapper (TensorFlow native, NO ONNX).
Following TDD principles with RED-GREEN-REFACTOR cycle.

CRITICAL CONSTRAINTS (PRD v2.1):
- MUST use: TensorFlow 2.15-2.17 (Python native)
- FORBIDDEN: ONNX Runtime
"""

import pytest
from typing import List, Tuple
from pathlib import Path

from app.models.inksight import InkSightModel, InksightResult


class TestInkSightModel:
    """Test InkSight model wrapper"""

    def test_model_singleton(self):
        """InkSightModel should be a singleton (one instance)"""
        model1 = InkSightModel.get_instance()
        model2 = InkSightModel.get_instance()

        assert model1 is model2

    def test_model_initialization(self):
        """Model should initialize without loading weights"""
        model = InkSightModel.get_instance()

        # Model should exist but not necessarily loaded
        assert model is not None
        assert hasattr(model, 'model')
        assert hasattr(model, 'is_loaded')

    def test_load_model_from_huggingface(self):
        """Should load model (mock or real)"""
        model = InkSightModel.get_instance()

        # Load model (will use mock if InkSight not available)
        model.load()

        assert model.is_loaded()
        assert model.model is not None
        # Note: May use mock model during development

    @pytest.mark.slow
    def test_predict_single_character(self):
        """Should predict trajectory from character image"""
        model = InkSightModel.get_instance()
        model.load()

        # Create a simple test image (white background, black text)
        import numpy as np
        test_image = np.ones((128, 128, 3), dtype=np.uint8) * 255
        # Draw a simple horizontal line (simulate "一")
        test_image[64, 20:108] = 0  # Black horizontal line

        result = model.predict(test_image)

        assert result is not None
        assert result.trajectory is not None
        assert len(result.trajectory) > 0
        # Each point should be (x, y) tuple in 0-1 range
        for point in result.trajectory:
            assert isinstance(point, tuple)
            assert len(point) == 2
            assert 0.0 <= point[0] <= 1.0
            assert 0.0 <= point[1] <= 1.0

    @pytest.mark.slow
    def test_predict_returns_multiple_strokes(self):
        """Should predict multiple strokes for complex characters"""
        model = InkSightModel.get_instance()
        model.load()

        import numpy as np
        # Create a test image for "十" (cross)
        test_image = np.ones((128, 128, 3), dtype=np.uint8) * 255
        test_image[20:108, 64] = 0  # Vertical line
        test_image[64, 20:108] = 0  # Horizontal line

        result = model.predict(test_image)

        assert result is not None
        assert result.strokes is not None
        assert len(result.strokes) >= 1  # At least one stroke


class TestInksightResult:
    """Test InksightResult data model"""

    def test_result_model_structure(self):
        """InksightResult should contain all expected fields"""
        trajectory = [(0.1, 0.2), (0.3, 0.4), (0.5, 0.6)]
        strokes = [[(0.1, 0.2), (0.3, 0.4)], [(0.5, 0.6), (0.7, 0.8)]]
        confidence = 0.85

        result = InksightResult(
            trajectory=trajectory,
            strokes=strokes,
            confidence=confidence
        )

        assert result.trajectory == trajectory
        assert result.strokes == strokes
        assert result.confidence == confidence


class TestModelLoader:
    """Test HuggingFace model loader"""

    def test_model_cache_directory(self):
        """Model should be cached in a known location"""
        from app.models.model_loader import get_model_cache_dir

        cache_dir = get_model_cache_dir()

        assert cache_dir.exists()
        assert cache_dir.is_dir()

    def test_model_download_detection(self):
        """Should detect if model is already cached"""
        from app.models.model_loader import is_model_cached

        # Before first download, should be False or True depending on cache
        is_cached = is_model_cached()

        # Should return boolean
        assert isinstance(is_cached, bool)


class TestCoordinateMapping:
    """Test coordinate mapping between InkSight and Hanzi Writer systems"""

    def test_inksight_to_hanzi_1024(self):
        """Should map InkSight 0-1 coordinates to Hanzi Writer 1024 grid"""
        from app.models.inksight import map_inksight_to_hanzi_1024

        # InkSight uses 0-1 normalized coordinates
        inksight_point = (0.5, 0.5)
        hanzi_point = map_inksight_to_hanzi_1024(inksight_point)

        # Hanzi Writer uses 1024x1024 grid
        assert isinstance(hanzi_point, tuple)
        assert len(hanzi_point) == 2
        assert 0 <= hanzi_point[0] <= 1024
        assert 0 <= hanzi_point[1] <= 1024

    def test_inksight_to_hanzi_1024_roundtrip(self):
        """Roundtrip mapping should preserve coordinates"""
        from app.models.inksight import map_inksight_to_hanzi_1024, map_hanzi_1024_to_inksight

        original = (0.5, 0.5)
        hanzi = map_inksight_to_hanzi_1024(original)
        back = map_hanzi_1024_to_inksight(hanzi)

        # Allow small floating point errors
        assert abs(back[0] - original[0]) < 0.001
        assert abs(back[1] - original[1]) < 0.001


class TestImagePreprocessing:
    """Test image preprocessing for InkSight input"""

    def test_preprocess_image(self):
        """Should preprocess image to model expected format"""
        from app.models.inksight import preprocess_image

        import numpy as np
        # Create test image
        test_image = np.ones((256, 256, 3), dtype=np.uint8) * 255

        processed = preprocess_image(test_image)

        # Should return tensor or array with correct shape
        assert processed is not None
        assert hasattr(processed, 'shape') or hasattr(processed, 'numpy')

    def test_preprocess_image_normalization(self):
        """Should normalize image pixel values"""
        from app.models.inksight import preprocess_image

        import numpy as np
        test_image = np.random.randint(0, 255, (128, 128, 3), dtype=np.uint8)

        processed = preprocess_image(test_image)

        # Check normalization (typically 0-1 or -1 to 1)
        arr = processed if hasattr(processed, 'numpy') else processed
        # Values should be normalized
        assert arr.max() <= 2.0  # Allow for common normalization ranges
        assert arr.min() >= -1.0


@pytest.mark.slow
class TestEndToEndInkSight:
    """End-to-end tests with real InkSight model"""

    def test_full_pipeline(self):
        """Test full pipeline: image -> InkSight -> Hanzi Writer format"""
        model = InkSightModel.get_instance()
        model.load()

        import numpy as np
        # Create test image
        test_image = np.ones((128, 128, 3), dtype=np.uint8) * 255
        test_image[64, 20:108] = 0  # Simple horizontal line

        # Predict
        result = model.predict(test_image)

        # Convert to Hanzi Writer format
        from app.models.inksight import convert_to_hanzi_writer_format
        hanzi_data = convert_to_hanzi_writer_format(result)

        assert hanzi_data is not None
        assert 'strokes' in hanzi_data or 'medians' in hanzi_data
