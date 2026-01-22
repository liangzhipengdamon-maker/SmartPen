"""
Model Loader - 模型加载器

HuggingFace model download and caching utilities.
"""

import os
from pathlib import Path
from typing import Optional


def get_model_cache_dir() -> Path:
    """
    Get the default cache directory for AI models.

    Returns:
        Path to cache directory
    """
    # Use platform-specific cache location
    home = Path.home()
    if os.name == 'nt':  # Windows
        cache_dir = home / 'AppData' / 'Local' / 'SmartPen' / 'models'
    else:  # macOS / Linux
        cache_dir = home / '.cache' / 'smartpen' / 'models'

    # Create directory if it doesn't exist
    cache_dir.mkdir(parents=True, exist_ok=True)

    return cache_dir


def get_inksight_model_path() -> Path:
    """
    Get the path to InkSight model cache.

    Returns:
        Path to InkSight model directory
    """
    cache_dir = get_model_cache_dir()
    return cache_dir / 'inksight-small-p'


def is_model_cached(model_path: Optional[Path] = None) -> bool:
    """
    Check if the InkSight model is already cached.

    Args:
        model_path: Optional custom model path

    Returns:
        True if model files exist in cache
    """
    if model_path is None:
        model_path = get_inksight_model_path()

    # Check for model indicators (config.json, model files, etc.)
    if not model_path.exists():
        return False

    # Check for common model files
    indicators = ['config.json', 'model.h5', 'saved_model.pb', 'tf_model.h5']
    return any((model_path / f).exists() for f in indicators)


def get_huggingface_model_id() -> str:
    """
    Get the HuggingFace model ID for InkSight.

    Returns:
        HuggingFace model identifier
    """
    # Using small-p variant for faster inference
    return "google-research/inksight-small-p"
