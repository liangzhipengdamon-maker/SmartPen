"""
OpenCV Image Preprocessing - OpenCV 图像预处理

Perspective transform, binarization, and image normalization.
P1-T4: OpenCV 预处理管道
"""

import logging
import numpy as np
from typing import Tuple, Optional, List

# OpenCV import
try:
    import cv2
    OPENCV_AVAILABLE = True
except ImportError:
    cv2 = None
    OPENCV_AVAILABLE = False
    logging.warning("OpenCV not installed. Install: pip install opencv-python")

logger = logging.getLogger(__name__)


def preprocess_image(
    image: np.ndarray,
    target_size: Optional[Tuple[int, int]] = None
) -> np.ndarray:
    """
    Apply basic preprocessing to image.

    Args:
        image: Input image (H, W, 3) or (H, W)
        target_size: Optional target size (W, H)

    Returns:
        Preprocessed image
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning original image")
        return image

    # Convert to grayscale if needed
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    else:
        gray = image.copy()

    # Apply Gaussian blur to reduce noise
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    # Resize if target size specified
    if target_size is not None:
        blurred = cv2.resize(blurred, target_size)

    return blurred


def binarize_image(
    image: np.ndarray,
    threshold: Optional[int] = None,
    method: str = 'otsu'
) -> np.ndarray:
    """
    Binarize image to black and white.

    Args:
        image: Input grayscale image
        threshold: Manual threshold (None for automatic)
        method: Binarization method ('otsu', 'adaptive', 'fixed')

    Returns:
        Binary image (0 or 255)
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, using simple threshold")
        # Simple threshold without OpenCV
        if threshold is None:
            threshold = 128
        return (image > threshold).astype(np.uint8) * 255

    # Ensure grayscale
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    else:
        gray = image

    if method == 'otsu':
        # Otsu's binarization (automatic threshold)
        _, binary = cv2.threshold(
            gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU
        )
    elif method == 'adaptive':
        # Adaptive thresholding
        binary = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 11, 2
        )
    else:  # fixed
        # Fixed threshold
        if threshold is None:
            threshold = 128
        _, binary = cv2.threshold(gray, threshold, 255, cv2.THRESH_BINARY)

    return binary


def detect_corners(
    image: np.ndarray,
    max_corners: int = 4
) -> np.ndarray:
    """
    Detect corners in image (for document/paper detection).

    Args:
        image: Input image
        max_corners: Maximum number of corners to detect

    Returns:
        Array of corner points (N, 2)
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning default corners")
        h, w = image.shape[:2]
        return np.array([
            [0, 0],
            [w, 0],
            [w, h],
            [0, h]
        ], dtype=np.float32)

    # Ensure grayscale
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    else:
        gray = image

    # Try to find contours (for document detection)
    binary = binarize_image(gray, method='otsu')

    # Find contours
    contours, _ = cv2.findContours(
        binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    if contours:
        # Find largest contour
        largest = max(contours, key=cv2.contourArea)

        # Approximate contour to polygon
        epsilon = 0.02 * cv2.arcLength(largest, True)
        approx = cv2.approxPolyDP(largest, epsilon, True)

        if len(approx) == 4:
            # Return 4 corners
            return approx.reshape(4, 2).astype(np.float32)

    # Fallback: return image corners
    h, w = image.shape[:2]
    return np.array([
        [0, 0],
        [w - 1, 0],
        [w - 1, h - 1],
        [0, h - 1]
    ], dtype=np.float32)


def apply_perspective_transform(
    image: np.ndarray,
    src_corners: np.ndarray,
    dst_corners: np.ndarray,
    output_size: Optional[Tuple[int, int]] = None
) -> np.ndarray:
    """
    Apply perspective transform to rectify image.

    Args:
        image: Input image
        src_corners: Source corner points (4, 2)
        dst_corners: Destination corner points (4, 2)
        output_size: Output size (W, H)

    Returns:
        Transformed image
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning original image")
        return image

    # Calculate perspective transform matrix
    M = cv2.getPerspectiveTransform(src_corners, dst_corners)

    # Determine output size
    if output_size is None:
        # Use max width/height from destination corners
        max_width = int(np.max(dst_corners[:, 0]))
        max_height = int(np.max(dst_corners[:, 1]))
        output_size = (max_width, max_height)

    # Apply transform
    warped = cv2.warpPerspective(image, M, output_size)

    return warped


def crop_to_content(
    image: np.ndarray,
    padding: int = 10
) -> np.ndarray:
    """
    Crop image to content (remove whitespace).

    Args:
        image: Input image (binary)
        padding: Padding around content

    Returns:
        Cropped image
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning original image")
        return image

    # Find bounding box of non-white pixels
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_RGB2GRAY)
    else:
        gray = image

    # Binary inverse to find content
    _, binary = cv2.threshold(gray, 254, 255, cv2.THRESH_BINARY_INV)

    # Find contours
    contours, _ = cv2.findContours(
        binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    if contours:
        # Get bounding rectangle of all contours
        all_points = np.vstack([c.reshape(-1, 2) for c in contours])
        x, y, w, h = cv2.boundingRect(all_points)

        # Add padding
        x = max(0, x - padding)
        y = max(0, y - padding)
        w = min(image.shape[1] - x, w + 2 * padding)
        h = min(image.shape[0] - y, h + 2 * padding)

        return image[y:y+h, x:x+w]

    return image
