"""
Skeleton Extraction - 骨架提取

Zhang-Suen thinning algorithm for extracting 1-pixel wide skeletons.
P1-T5: 骨架提取 (Zhang-Suen 算法)
P1-T6: 幻觉抑制掩码
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

logger = logging.getLogger(__name__)


def extract_skeleton(binary_image: np.ndarray) -> np.ndarray:
    """
    Extract skeleton from binary image using Zhang-Suen algorithm.

    Args:
        binary_image: Binary image (0 or 255)

    Returns:
        Skeleton image (1-pixel wide)
    """
    # Ensure binary (0 or 1)
    if binary_image.max() > 1:
        binary = (binary_image > 127).astype(np.uint8)
    else:
        binary = binary_image.astype(np.uint8)

    # Apply Zhang-Suen thinning
    skeleton = zhang_suen_thinning(binary)

    return skeleton


def zhang_suen_thinning(binary: np.ndarray, max_iter: int = 100) -> np.ndarray:
    """
    Zhang-Suen thinning algorithm for binary images.

    Iteratively removes boundary pixels until skeleton is 1-pixel wide.

    Args:
        binary: Binary image (0 or 1)
        max_iter: Maximum iterations

    Returns:
        Thinned skeleton (0 or 1)
    """
    # Make a copy
    skeleton = binary.copy()

    # Pad to avoid boundary issues
    padded = np.pad(skeleton, 1, mode='constant', constant_values=0)

    changed = True
    iteration = 0

    while changed and iteration < max_iter:
        changed = False
        iteration += 1

        # Subiteration 1: Remove south-east boundary pixels
        removed_1 = _zhang_suen_iteration(padded, iteration_type=1)
        padded = padded ^ removed_1

        # Subiteration 2: Remove north-west boundary pixels
        removed_2 = _zhang_suen_iteration(padded, iteration_type=2)
        padded = padded ^ removed_2

        changed = np.any(removed_1) or np.any(removed_2)

    # Remove padding
    skeleton = padded[1:-1, 1:-1]

    return skeleton


def _zhang_suen_iteration(binary: np.ndarray, iteration_type: int) -> np.ndarray:
    """
    Single iteration of Zhang-Suen algorithm.

    Args:
        binary: Padded binary image
        iteration_type: 1 or 2 (determines which pixels to remove)

    Returns:
        Boolean mask of pixels to remove
    """
    h, w = binary.shape

    # Get 8-neighborhood
    # P9 P2 P3
    # P8 P1 P4
    # P7 P6 P5
    p1 = binary[1:-1, 1:-1]  # Center

    p2 = binary[0:-2, 1:-1]   # Top
    p3 = binary[0:-2, 2:]     # Top-right
    p4 = binary[1:-1, 2:]     # Right
    p5 = binary[2:, 2:]       # Bottom-right
    p6 = binary[2:, 1:-1]     # Bottom
    p7 = binary[2:, 0:-2]     # Bottom-left
    p8 = binary[1:-1, 0:-2]   # Left
    p9 = binary[0:-2, 0:-2]   # Top-left

    # Calculate conditions
    # A(p1) = number of 0->1 transitions in circular sequence P2->P3->...->P9->P2
    A = (
        ((p2 == 0) & (p3 == 1)).astype(int) +
        ((p3 == 0) & (p4 == 1)).astype(int) +
        ((p4 == 0) & (p5 == 1)).astype(int) +
        ((p5 == 0) & (p6 == 1)).astype(int) +
        ((p6 == 0) & (p7 == 1)).astype(int) +
        ((p7 == 0) & (p8 == 1)).astype(int) +
        ((p8 == 0) & (p9 == 1)).astype(int) +
        ((p9 == 0) & (p2 == 1)).astype(int)
    )

    # B(p1) = number of 1 neighbors
    B = p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9

    # Conditions common to both iterations
    # 2 <= B(p1) <= 6
    cond_B = (B >= 2) & (B <= 6)

    # A(p1) == 1
    cond_A = (A == 1)

    # p1 == 1 (foreground pixel)
    cond_p1 = (p1 == 1)

    if iteration_type == 1:
        # Subiteration 1
        # P2 * P4 * P6 = 0
        cond_1 = (p2 * p4 * p6 == 0)

        # P4 * P6 * P8 != 0 (not: P4 * P6 * P8 = 0)
        cond_2 = ((p4 * p6 * p8) != 0)

    else:  # iteration_type == 2
        # Subiteration 2
        # P2 * P4 * P8 = 0
        cond_1 = (p2 * p4 * p8 == 0)

        # P2 * P6 * P8 != 0 (not: P2 * P6 * P8 = 0)
        cond_2 = ((p2 * p6 * p8) != 0)

    # Combine conditions
    remove_mask = cond_p1 & cond_B & cond_A & cond_1 & cond_2

    # Return full-size mask with padding
    full_mask = np.zeros_like(binary, dtype=bool)
    full_mask[1:-1, 1:-1] = remove_mask

    return full_mask


def create_proximity_mask(
    skeleton: np.ndarray,
    radius: int = 5,
    mask_size: Optional[Tuple[int, int]] = None
) -> np.ndarray:
    """
    Create proximity mask around skeleton.

    Used for hallucination suppression: only allow points near skeleton.

    Args:
        skeleton: Binary skeleton image (0 or 255)
        radius: Radius around skeleton to include
        mask_size: Output mask size (default: same as skeleton)

    Returns:
        Binary mask (0 or 255) with dilated skeleton
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning skeleton as mask")
        return skeleton

    # Ensure binary
    if skeleton.max() > 1:
        binary = (skeleton > 127).astype(np.uint8)
    else:
        binary = skeleton.astype(np.uint8)

    # Create kernel for dilation
    kernel_size = 2 * radius + 1
    kernel = np.ones((kernel_size, kernel_size), np.uint8)

    # Dilate skeleton
    dilated = cv2.dilate(binary, kernel, iterations=1)

    # Convert back to 0-255 range
    mask = (dilated * 255).astype(np.uint8)

    # Resize if needed
    if mask_size is not None and mask.shape[:2][::-1] != mask_size:
        mask = cv2.resize(mask, mask_size, interpolation=cv2.INTER_NEAREST)

    return mask


def apply_mask(
    image: np.ndarray,
    mask: np.ndarray,
    invert: bool = False
) -> np.ndarray:
    """
    Apply binary mask to image.

    Args:
        image: Input image
        mask: Binary mask (0 or 255)
        invert: If True, invert mask before applying

    Returns:
        Masked image
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning original image")
        return image

    # Ensure mask is binary
    if mask.max() > 1:
        binary_mask = (mask > 127).astype(np.uint8)
    else:
        binary_mask = mask.astype(np.uint8)

    if invert:
        binary_mask = 1 - binary_mask

    # Ensure image and mask have same size
    if image.shape[:2] != binary_mask.shape[:2]:
        binary_mask = cv2.resize(
            binary_mask,
            (image.shape[1], image.shape[0]),
            interpolation=cv2.INTER_NEAREST
        )

    # Apply mask
    if len(image.shape) == 3:
        # Color image: apply to all channels
        masked = image * binary_mask[:, :, np.newaxis]
    else:
        # Grayscale
        masked = image * binary_mask

    return masked.astype(image.dtype)


def validate_trajectory_with_mask(
    trajectory: list,
    mask: np.ndarray,
    image_size: Tuple[int, int] = (1024, 1024)
) -> list:
    """
    Validate and filter trajectory points using mask.

    Removes points that fall outside the masked region (hallucination suppression).

    Args:
        trajectory: List of (x, y) points in 0-1 range
        mask: Binary mask (0 or 255) in image_size dimensions
        image_size: Size of image (width, height)

    Returns:
        Filtered trajectory with only valid points
    """
    if not OPENCV_AVAILABLE:
        logger.warning("OpenCV not available, returning original trajectory")
        return trajectory

    h, w = mask.shape[:2]

    valid_points = []
    removed_count = 0

    for x, y in trajectory:
        # Convert to image coordinates
        ix = int(x * w)
        iy = int(y * h)

        # Check bounds
        if 0 <= ix < w and 0 <= iy < h:
            # Check if point is in valid region
            if mask[iy, ix] > 127:
                valid_points.append((x, y))
            else:
                removed_count += 1
        else:
            # Out of bounds
            removed_count += 1

    if removed_count > 0:
        logger.warning(f"Removed {removed_count} hallucination points from trajectory")

    return valid_points
