"""
Scoring API Router - 综合评分端点

Provides endpoints for comprehensive scoring (handwriting + posture).
Combines DTW handwriting scoring with posture quality evaluation.
"""

from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from typing import List, Optional
import logging
import json
import io

import numpy as np

from app.models.posture import (
    ComprehensiveScoreRequest,
    ComprehensiveScoreResult,
    PostureData,
    PostureAnalysis,
    StrokeAnalysis
)
from app.models.character import CharacterData
from app.parsers.hanzi_writer import HanziWriterLoader
from app.algorithms.dtw import calculate_dtw_distance
from app.scoring.posture_scorer import score_posture
from app.scoring.normalizer import normalize_score
from app.scoring.stroke_order import validate_stroke_order
from app.models.inksight import InkSightModel, InksightResult

logger = logging.getLogger(__name__)

router = APIRouter()

# Shared instances
_loader = HanziWriterLoader()

# Scoring weights
HANDWRITING_WEIGHT = 0.7  # 70% weight for handwriting quality
POSTURE_WEIGHT = 0.3      # 30% weight for posture quality


def _get_grade(score: float) -> str:
    """Convert score to grade string"""
    if score >= 90:
        return "优秀"
    elif score >= 80:
        return "良好"
    elif score >= 60:
        return "及格"
    else:
        return "需练习"


def _generate_comprehensive_feedback(
    handwriting_score: float,
    posture_score: float,
    posture_analysis: Optional[PostureAnalysis]
) -> str:
    """Generate comprehensive feedback message"""
    feedback_parts = []

    # Handwriting feedback
    if handwriting_score >= 90:
        feedback_parts.append("字写得很好")
    elif handwriting_score >= 70:
        feedback_parts.append("字写得不错")
    elif handwriting_score >= 60:
        feedback_parts.append("字写得一般")
    else:
        feedback_parts.append("字需要多练习")

    # Posture feedback
    if posture_analysis is not None:
        if posture_analysis.is_correct:
            if posture_score >= 90:
                feedback_parts.append("坐姿也很标准")
            else:
                feedback_parts.append("坐姿良好")
        else:
            feedback_parts.append("但" + posture_analysis.feedback.replace("。", ""))

    return "".join(feedback_parts) + "！"


@router.post("/score/comprehensive", response_model=ComprehensiveScoreResult)
async def comprehensive_score(request: ComprehensiveScoreRequest):
    """
    综合评分端点 - 结合书写质量和姿态评分

    评分权重：
    - 书写质量: 70%
    - 坐姿质量: 30%

    Args:
        request: 包含用户笔画轨迹和姿态数据的请求

    Returns:
        ComprehensiveScoreResult with detailed scoring breakdown

    Raises:
        HTTPException: 400 if invalid input, 404 if character not found
    """
    # Validate input
    if not request.character or len(request.character) != 1:
        raise HTTPException(
            status_code=400,
            detail="请提供单个汉字"
        )

    if not request.user_strokes:
        raise HTTPException(
            status_code=400,
            detail="请提供书写笔画数据"
        )

    try:
        # Step 1: Load reference character data
        logger.info(f"Loading reference character: {request.character}")
        reference_data = await _loader.load_character(request.character)

        # Step 2: Validate stroke order/count before DTW
        template_strokes = [
            [(p.x, p.y) for p in median.points]
            for median in reference_data.medians
        ]
        order_result = validate_stroke_order(template_strokes, request.user_strokes)
        if not order_result.is_valid or not order_result.stroke_count_match:
            return ComprehensiveScoreResult(
                total_score=0.0,
                handwriting_score=0.0,
                posture_score=0.0,
                grade="需练习",
                stroke_analysis=[],
                posture_analysis=None,
                feedback="笔顺错误",
                error_type=order_result.error_type or "stroke_order_error",
                message="笔顺错误"
            )

        # Step 3: Score handwriting using DTW
        logger.info(f"Scoring {len(request.user_strokes)} user strokes")
        handwriting_score, stroke_analyses = _score_handwriting(
            request.user_strokes,
            reference_data
        )

        # Step 4: Score posture (if provided)
        posture_score = 100.0
        posture_analysis = None

        if request.posture_data:
            logger.info("Scoring posture data")
            posture_analysis = score_posture(request.posture_data)
            posture_score = posture_analysis.score
        else:
            logger.info("No posture data provided, using default score")
            posture_score = 100.0  # No penalty if no posture data

        # Step 5: Calculate comprehensive score
        total_score = (
            handwriting_score * HANDWRITING_WEIGHT +
            posture_score * POSTURE_WEIGHT
        )

        # Step 6: Generate feedback
        grade = _get_grade(total_score)
        feedback = _generate_comprehensive_feedback(
            handwriting_score,
            posture_score,
            posture_analysis
        )

        # Step 7: Build response
        return ComprehensiveScoreResult(
            total_score=round(total_score, 1),
            handwriting_score=round(handwriting_score, 1),
            posture_score=round(posture_score, 1),
            grade=grade,
            stroke_analysis=stroke_analyses,
            posture_analysis=posture_analysis,
            feedback=feedback
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in comprehensive scoring: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"评分失败: {str(e)}"
        )


def _extract_user_strokes_from_photo(
    image_bytes: bytes,
    character: str
) -> Optional[List[List[tuple[float, float]]]]:
    """
    Extract user strokes from photo using InkSight (placeholder if unavailable).
    Returns list of strokes in 0-1 normalized coordinates, or None on failure.
    """
    try:
        from PIL import Image
    except Exception as e:
        logger.warning(f"PIL not available for image decode: {e}")
        return None

    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        image_np = np.array(img)
    except Exception as e:
        logger.warning(f"Failed to decode image: {e}")
        return None

    try:
        inksight = InkSightModel.get_instance()
        inksight.load()
        if inksight.model is not None and inksight.model.__class__.__name__ == "MockModel":
            logger.warning("InkSight mock model detected; returning no_strokes")
            return None
        result = inksight.predict(image_np)
        if isinstance(result, InksightResult):
            strokes = result.strokes
        else:
            strokes = getattr(result, "strokes", None)

        if not strokes:
            return None

        # Ensure list of list of (x, y) floats
        normalized_strokes: List[List[tuple[float, float]]] = []
        for stroke in strokes:
            if not stroke:
                continue
            points = [(float(x), float(y)) for x, y in stroke]
            normalized_strokes.append(points)

        return normalized_strokes if normalized_strokes else None
    except Exception as e:
        logger.warning(f"InkSight extraction failed: {e}")
        return None


@router.post("/score/from_photo", response_model=ComprehensiveScoreResult)
async def score_from_photo(
    character: str = Form(...),
    image: UploadFile = File(...),
    posture_data: Optional[str] = Form(None),
):
    """
    Score handwriting from a photo.
    """
    if not character or len(character) != 1:
        raise HTTPException(status_code=400, detail="请提供单个汉字")

    image_bytes = await image.read()
    user_strokes = _extract_user_strokes_from_photo(image_bytes, character)
    if not user_strokes:
        raise HTTPException(
            status_code=422,
            detail={
                "error_type": "no_strokes_detected",
                "message": "未检测到可评分的书写轨迹",
            },
        )

    parsed_posture: Optional[PostureData] = None
    if posture_data:
        try:
            parsed_posture = PostureData(**json.loads(posture_data))
        except Exception as e:
            logger.warning(f"Failed to parse posture_data: {e}")

    request = ComprehensiveScoreRequest(
        character=character,
        user_strokes=user_strokes,
        posture_data=parsed_posture,
    )
    return await comprehensive_score(request)


def _score_handwriting(
    user_strokes: List[List[tuple[float, float]]],
    reference_data: CharacterData
) -> tuple[float, List[StrokeAnalysis]]:
    """
    Score user's handwriting using DTW algorithm

    Args:
        user_strokes: User's stroke trajectories (normalized 0-1)
        reference_data: Reference character data from Hanzi Writer

    Returns:
        Tuple of (overall_score, list of stroke analyses)
    """
    stroke_analyses = []
    stroke_scores = []

    reference_medians = reference_data.medians

    # Score each stroke
    for i, user_stroke in enumerate(user_strokes):
        # Find corresponding reference stroke
        if i < len(reference_medians):
            ref_median = reference_medians[i]
            ref_points = [(p.x, p.y) for p in ref_median.points]

            # Calculate DTW distance
            try:
                distance = calculate_dtw_distance(user_stroke, ref_points)

                # Convert distance to similarity score (0-1)
                # Distance 0 = perfect match, larger = worse
                similarity = normalize_score(distance, max_distance=0.5) / 100.0

                # Convert to 0-100 score
                stroke_score = similarity * 100.0

                issues = []
                if stroke_score < 60:
                    issues.append(f"第 {i+1} 笔与标准差异较大")

                stroke_analyses.append(StrokeAnalysis(
                    stroke_index=i,
                    similarity=round(similarity, 3),
                    score=round(stroke_score, 1),
                    issues=issues
                ))

                stroke_scores.append(similarity)

            except Exception as e:
                logger.warning(f"Error scoring stroke {i}: {e}")
                stroke_analyses.append(StrokeAnalysis(
                    stroke_index=i,
                    similarity=0.0,
                    score=0.0,
                    issues=["评分失败"]
                ))
                stroke_scores.append(0.0)
        else:
            # Extra stroke not in reference
            stroke_analyses.append(StrokeAnalysis(
                stroke_index=i,
                similarity=0.0,
                score=0.0,
                issues=["多余的笔画"]
            ))
            stroke_scores.append(0.0)

    # Calculate overall handwriting score
    if stroke_scores:
        handwriting_score = sum(stroke_scores) / len(stroke_scores) * 100.0
    else:
        handwriting_score = 0.0

    return round(handwriting_score, 1), stroke_analyses


@router.get("/score/health")
async def health_check():
    """Health check endpoint for scoring service"""
    return {"status": "healthy", "service": "scoring"}
