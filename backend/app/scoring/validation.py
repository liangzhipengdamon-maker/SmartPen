from __future__ import annotations

from typing import List, Optional, Tuple

import numpy as np

# Stroke validation thresholds (InkSight output normalized to 0-1 coordinates)
MIN_STROKE_POINTS = 2
MIN_TOTAL_POINTS = 8
MIN_SPAN = 0.05  # 0.05 in 0-1 space ~5% of width/height


def validate_extracted_strokes(
    strokes: List[List[tuple[float, float]]]
) -> Tuple[List[List[tuple[float, float]]], Optional[str]]:
    """
    Validate extracted strokes to avoid scoring blank/invalid images.

    Returns filtered strokes and an optional error message.
    """
    if not strokes:
        return [], "未检测到可评分的书写轨迹"

    filtered = [s for s in strokes if s and len(s) >= MIN_STROKE_POINTS]
    if not filtered:
        return [], "未检测到可评分的书写轨迹"

    points = [(x, y) for stroke in filtered for (x, y) in stroke]
    if len(points) < MIN_TOTAL_POINTS:
        return [], "未检测到可评分的书写轨迹"

    xs = [p[0] for p in points]
    ys = [p[1] for p in points]

    if any(not np.isfinite(x) for x in xs) or any(not np.isfinite(y) for y in ys):
        return [], "未检测到可评分的书写轨迹"

    span_x = max(xs) - min(xs)
    span_y = max(ys) - min(ys)
    if span_x < MIN_SPAN and span_y < MIN_SPAN:
        return [], "未检测到可评分的书写轨迹（可能是照片旋转/裁剪不正确）"

    return filtered, None
