"""
Preprocessing package - Image preprocessing and skeleton extraction

P1-T4: OpenCV Preprocessing Pipeline
P1-T5: Skeleton Extraction (Zhang-Suen)
P1-T6: Hallucination Suppression Mask
"""

from app.preprocessing.image import (
    preprocess_image,
    binarize_image,
    detect_corners,
    apply_perspective_transform,
    crop_to_content,
)

from app.preprocessing.skeleton import (
    extract_skeleton,
    zhang_suen_thinning,
    create_proximity_mask,
    apply_mask,
    validate_trajectory_with_mask,
)

__all__ = [
    # Image preprocessing
    "preprocess_image",
    "binarize_image",
    "detect_corners",
    "apply_perspective_transform",
    "crop_to_content",
    # Skeleton extraction
    "extract_skeleton",
    "zhang_suen_thinning",
    "create_proximity_mask",
    "apply_mask",
    "validate_trajectory_with_mask",
]
