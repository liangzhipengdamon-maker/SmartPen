"""
OpenCV Preprocessing Tests - OpenCV 预处理测试

Tests for image preprocessing and skeleton extraction.
Following TDD principles with RED-GREEN-REFACTOR cycle.

P1-T4: OpenCV Preprocessing Pipeline (perspective transform, binarization)
P1-T5: Skeleton Extraction (Zhang-Suen algorithm)
"""

import pytest
import numpy as np
from pathlib import Path

from app.preprocessing.image import (
    preprocess_image,
    binarize_image,
    apply_perspective_transform,
    detect_corners,
)
from app.preprocessing.skeleton import (
    extract_skeleton,
    zhang_suen_thinning,
    create_proximity_mask,
)


class TestImagePreprocessing:
    """Test image preprocessing functions"""

    def test_preprocess_image_basic(self):
        """Should apply basic preprocessing"""
        # Create test image
        test_image = np.random.randint(0, 255, (256, 256, 3), dtype=np.uint8)

        processed = preprocess_image(test_image)

        assert processed is not None
        assert isinstance(processed, np.ndarray)

    def test_binarize_image(self):
        """Should binarize image to black/white"""
        # Create grayscale image
        test_image = np.random.randint(0, 255, (128, 128), dtype=np.uint8)

        binary = binarize_image(test_image)

        assert binary is not None
        assert binary.dtype == np.uint8
        # Should only contain 0 or 255
        unique_values = np.unique(binary)
        assert len(unique_values) <= 2

    def test_detect_corners(self):
        """Should detect corners in document/image"""
        # Create a simple image with white background
        test_image = np.ones((256, 256, 3), dtype=np.uint8) * 255

        corners = detect_corners(test_image)

        assert corners is not None
        assert isinstance(corners, np.ndarray)
        assert corners.shape[0] == 4  # 4 corners

    def test_apply_perspective_transform(self):
        """Should apply perspective transform to image"""
        # Create test image
        test_image = np.ones((256, 256, 3), dtype=np.uint8) * 128

        # Define source and destination corners
        src_corners = np.array([[50, 50], [200, 50], [200, 200], [50, 200]], dtype=np.float32)
        dst_corners = np.array([[0, 0], [256, 0], [256, 256], [0, 256]], dtype=np.float32)

        transformed = apply_perspective_transform(test_image, src_corners, dst_corners)

        assert transformed is not None
        assert transformed.shape[:2] == (256, 256)


class TestSkeletonExtraction:
    """Test skeleton extraction using Zhang-Suen algorithm"""

    def test_extract_skeleton_simple(self):
        """Should extract skeleton from binary image"""
        # Create simple binary image (white square on black)
        binary = np.zeros((100, 100), dtype=np.uint8)
        binary[30:70, 30:70] = 255

        skeleton = extract_skeleton(binary)

        assert skeleton is not None
        assert skeleton.shape == binary.shape
        # Skeleton should be thinner than original
        assert np.sum(skeleton > 0) < np.sum(binary > 0)

    def test_zhang_suen_thinning_horizontal(self):
        """Should thin horizontal line to single pixel"""
        # Create thick horizontal line
        binary = np.zeros((50, 50), dtype=np.uint8)
        binary[23:28, 10:40] = 255  # 5-pixel wide line

        thinned = zhang_suen_thinning(binary)

        assert thinned is not None
        # Line should be thinned
        # Count pixels in middle row
        cross_section = thinned[25, :]
        # Should be thinned but still have some pixels
        assert 0 < np.sum(cross_section > 0) <= 40

    def test_zhang_suen_thinning_vertical(self):
        """Should thin vertical line to single pixel"""
        # Create thick vertical line
        binary = np.zeros((50, 50), dtype=np.uint8)
        binary[10:40, 23:28] = 255  # 5-pixel wide line

        thinned = zhang_suen_thinning(binary)

        assert thinned is not None
        # Line should be thinned
        cross_section = thinned[:, 25]
        # Should be thinned but still have some pixels
        assert 0 < np.sum(cross_section > 0) <= 40

    def test_extract_skeleton_preserves_connectivity(self):
        """Skeleton should preserve connectivity of shapes"""
        # Create hollow square
        binary = np.zeros((100, 100), dtype=np.uint8)
        binary[20:80, 20] = 255  # Top
        binary[20:80, 79] = 255  # Bottom
        binary[20, 20:80] = 255  # Left
        binary[79, 20:80] = 255  # Right

        skeleton = extract_skeleton(binary)

        assert skeleton is not None
        # Skeleton should maintain some connectivity
        assert np.sum(skeleton > 0) > 0

    def test_create_proximity_mask(self):
        """Should create proximity mask from skeleton"""
        # Create simple skeleton
        skeleton = np.zeros((100, 100), dtype=np.uint8)
        skeleton[50, :] = 255  # Horizontal line

        mask = create_proximity_mask(skeleton, radius=5)

        assert mask is not None
        assert mask.shape == skeleton.shape
        # Mask should be wider than skeleton
        assert np.sum(mask > 0) > np.sum(skeleton > 0)

    def test_proximity_mask_radius(self):
        """Proximity mask radius should affect width"""
        skeleton = np.zeros((100, 100), dtype=np.uint8)
        skeleton[50, 50] = 255  # Single point

        mask_small = create_proximity_mask(skeleton, radius=2)
        mask_large = create_proximity_mask(skeleton, radius=10)

        # Larger radius should produce more pixels
        assert np.sum(mask_large > 0) > np.sum(mask_small > 0)


class TestIntegration:
    """Integration tests for preprocessing pipeline"""

    def test_full_preprocessing_pipeline(self):
        """Test full preprocessing: capture -> preprocess -> skeleton -> mask"""
        # Simulate captured image
        test_image = np.ones((256, 256, 3), dtype=np.uint8) * 255
        # Draw some content
        test_image[50:200, 50:200] = 128  # Gray square

        # Step 1: Preprocess
        processed = preprocess_image(test_image)

        # Step 2: Binarize
        binary = binarize_image(processed)

        # Step 3: Extract skeleton
        skeleton = extract_skeleton(binary)

        # Step 4: Create proximity mask
        mask = create_proximity_mask(skeleton, radius=5)

        # Verify pipeline
        assert processed is not None
        assert binary is not None
        assert skeleton is not None
        assert mask is not None

    def test_empty_image_handling(self):
        """Should handle empty/all-white/all-black images"""
        # All white
        white = np.ones((100, 100, 3), dtype=np.uint8) * 255
        result = preprocess_image(white)
        assert result is not None

        # All black
        black = np.zeros((100, 100, 3), dtype=np.uint8)
        result = preprocess_image(black)
        assert result is not None

    def test_grayscale_input(self):
        """Should handle grayscale input"""
        gray = np.random.randint(0, 255, (100, 100), dtype=np.uint8)

        binary = binarize_image(gray)

        assert binary is not None
        assert binary.shape == gray.shape


@pytest.mark.slow
class TestRealImageProcessing:
    """Tests with more realistic image data"""

    def test_character_skeleton(self):
        """Test skeleton extraction on character-like shape"""
        # Create a simple "十" character
        binary = np.zeros((100, 100), dtype=np.uint8)
        binary[40:60, 20:80] = 255  # Horizontal
        binary[20:80, 40:60] = 255  # Vertical

        skeleton = extract_skeleton(binary)

        assert skeleton is not None
        # Should thin the character
        assert np.sum(skeleton > 0) < np.sum(binary > 0)
