#!/usr/bin/env python3
"""
Download InkSight model from HuggingFace.

This script downloads the InkSight small-p model weights from HuggingFace
and caches them locally for the SmartPen backend.
"""

import os
import sys
from pathlib import Path

# Set proxy before importing transformers
os.environ['HTTP_PROXY'] = 'http://127.0.0.1:54065'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:54065'

def download_model():
    """Download InkSight model from HuggingFace."""
    print("=" * 60)
    print("InkSight Model Downloader")
    print("=" * 60)
    print()

    # Check TensorFlow version
    try:
        import tensorflow as tf
        print(f"✓ TensorFlow version: {tf.__version__}")
        tf_version = tuple(int(x) for x in tf.__version__.split('.')[:2])
        if not (2, 15) <= tf_version < (2, 18):
            print(f"⚠️  Warning: TensorFlow {tf.__version__} may not be compatible")
            print(f"   Recommended: 2.15.0 - 2.17.0")
    except ImportError:
        print("✗ TensorFlow not installed!")
        print("  Install: pip install tensorflow==2.15.0")
        return False

    print()

    # Import transformers after setting proxy
    try:
        from transformers import AutoModel, AutoConfig
        print("✓ Transformers library available")
    except ImportError:
        print("✗ Transformers not installed!")
        print("  Install: pip install transformers")
        return False

    print()

    # Model configuration
    model_id = "Derendering/InkSight-Small-p"
    print(f"Model ID: {model_id}")
    print(f"Cache dir: ~/.cache/huggingface/hub/")
    print()

    # Download model
    print("Downloading model from HuggingFace...")
    print("(This may take a while, model size ~100MB)")
    print()

    try:
        # Download with from_tf=True to get TensorFlow format
        print("Loading model (this downloads and caches)...")
        model = AutoModel.from_pretrained(model_id, from_tf=True)
        print("✓ Model downloaded successfully!")
        print()

        # Get cache location
        from huggingface_hub import snapshot_download
        cache_path = snapshot_download(repo_id=model_id)
        print(f"✓ Model cached at: {cache_path}")
        print()

        return True

    except Exception as e:
        print(f"✗ Download failed: {e}")
        print()
        print("Possible reasons:")
        print("  1. Model not public yet on HuggingFace")
        print("  2. Network/proxy issues")
        print("  3. Authentication required")
        print()
        print("Solutions:")
        print("  - Check if https://huggingface.co/google-research/inksight-small-p exists")
        print("  - Verify proxy is working: curl -x http://127.0.0.1:54065 https://huggingface.co")
        print("  - Try manual download from HuggingFace")
        return False

def verify_cache():
    """Verify if model is cached."""
    from huggingface_hub import scan_cache_dir

    print("Scanning HuggingFace cache...")
    cache_info = scan_cache_dir()

    # Look for inksight models
    repos = [r for r in cache_info.repos if 'inksight' in r.repo_id.lower()]
    if repos:
        print(f"✓ Found {len(repos)} InkSight model(s) in cache:")
        for r in repos:
            print(f"  - {r.repo_id}")
        return True
    else:
        print("✗ No InkSight models found in cache")
        return False

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Download InkSight model")
    parser.add_argument("--verify", action="store_true", help="Only verify cache, don't download")
    args = parser.parse_args()

    if args.verify:
        success = verify_cache()
    else:
        success = download_model()
        if success:
            print()
            print("=" * 60)
            print("Download complete!")
            print("=" * 60)
            print()
            print("Next steps:")
            print("  1. Verify model loading: python -c 'from app.models.inksight import InkSightModel; InkSightModel().load()'")
            print("  2. Restart backend: uvicorn main:app --reload")
            print("  3. Test photo scoring in the app")
            print()

    sys.exit(0 if success else 1)
