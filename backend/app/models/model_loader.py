"""
Model Loader - 模型加载器

Generic model caching utilities for SmartPen backend.
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


def is_model_cached(model_path: Optional[Path] = None) -> bool:
    """
    Check if a model is already cached.

    Args:
        model_path: Optional custom model path

    Returns:
        True if model files exist in cache
    """
    if model_path is None:
        return False

    # Check for model indicators (config.json, model files, etc.)
    if not model_path.exists():
        return False

    # Check for common model files
    indicators = ['config.json', 'model.h5', 'saved_model.pb', 'tf_model.h5', '.onnx']
    return any((model_path / f).exists() for f in indicators)
