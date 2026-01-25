"""
Posture Scorer - 姿态评分算法

Evaluates user's sitting posture based on ML Kit Pose Detection metrics.
Scores spine angle, eye-screen distance, and head tilt.
"""

import logging
from typing import List, Optional

from app.models.posture import (
    PostureData,
    PostureAnalysis,
    PostureLevel
)

logger = logging.getLogger(__name__)


class PostureScorer:
    """
    Posture quality evaluator

    Evaluates sitting posture and provides actionable feedback.
    Uses threshold-based scoring with penalties for poor posture.
    """

    # Scoring thresholds (based on ergonomic research)
    # Spine angle: deviation from vertical (lower is better)
    SPINE_ANGLE_WARNING = 10.0   # degrees
    SPINE_ANGLE_CRITICAL = 20.0  # degrees

    # Eye-screen distance: cm (higher is better)
    EYE_DISTANCE_WARNING = 35.0  # cm
    EYE_DISTANCE_CRITICAL = 25.0  # cm

    # Head tilt: deviation from horizontal (lower is better)
    HEAD_TILT_WARNING = 15.0     # degrees
    HEAD_TILT_CRITICAL = 30.0    # degrees

    # Maximum penalties for each metric
    SPINE_PENALTY_MAX = 30.0      # points
    EYE_DISTANCE_PENALTY_MAX = 40.0  # points
    HEAD_TILT_PENALTY_MAX = 30.0  # points

    def __init__(
        self,
        spine_warning: float = SPINE_ANGLE_WARNING,
        spine_critical: float = SPINE_ANGLE_CRITICAL,
        eye_warning: float = EYE_DISTANCE_WARNING,
        eye_critical: float = EYE_DISTANCE_CRITICAL,
        head_warning: float = HEAD_TILT_WARNING,
        head_critical: float = HEAD_TILT_CRITICAL,
    ):
        """
        Initialize posture scorer with customizable thresholds.

        Args:
            spine_warning: Spine angle threshold for warning level
            spine_critical: Spine angle threshold for critical level
            eye_warning: Eye distance threshold for warning level
            eye_critical: Eye distance threshold for critical level
            head_warning: Head tilt threshold for warning level
            head_critical: Head tilt threshold for critical level
        """
        self.spine_warning = spine_warning
        self.spine_critical = spine_critical
        self.eye_warning = eye_warning
        self.eye_critical = eye_critical
        self.head_warning = head_warning
        self.head_critical = head_critical

    def score(self, posture_data: PostureData) -> PostureAnalysis:
        """
        Evaluate posture quality and generate feedback.

        Scoring:
        - Start with 100 points
        - Apply penalties for each metric that exceeds thresholds
        - Spine angle: up to 30 points penalty
        - Eye distance: up to 40 points penalty
        - Head tilt: up to 30 points penalty

        Args:
            posture_data: Detected posture metrics from ML Kit

        Returns:
            PostureAnalysis with score, level, issues, and feedback
        """
        score = 100.0
        issues: List[str] = []

        # Evaluate spine angle
        spine_penalty = self._evaluate_spine_angle(posture_data.spine_angle)
        score -= spine_penalty
        if spine_penalty > 0:
            if posture_data.spine_angle >= self.spine_critical:
                issues.append(f"脊柱弯曲严重 ({posture_data.spine_angle:.1f}°)")

    # Evaluate eye-screen distance
        eye_penalty = self._evaluate_eye_distance(posture_data.eye_screen_distance)
        score -= eye_penalty
        if eye_penalty > 0:
            if posture_data.eye_screen_distance <= self.eye_critical:
                issues.append(f"距离屏幕太近 ({posture_data.eye_screen_distance:.1f}cm)")

        # Evaluate head tilt
        head_penalty = self._evaluate_head_tilt(posture_data.head_tilt)
        score -= head_penalty
        if head_penalty > 0:
            if posture_data.head_tilt >= self.head_critical:
                issues.append(f"头部倾斜严重 ({posture_data.head_tilt:.1f}°)")

        # Clamp score to [0, 100]
        score = max(0.0, min(100.0, score))

        # Determine posture level
        level = self._determine_level(
            posture_data.spine_angle,
            posture_data.eye_screen_distance,
            posture_data.head_tilt
        )

        # Generate feedback
        feedback = self._generate_feedback(issues, score)

        return PostureAnalysis(
            is_correct=level == PostureLevel.GOOD,
            score=score,
            level=level,
            issues=issues,
            feedback=feedback,
            spine_angle=posture_data.spine_angle,
            eye_screen_distance=posture_data.eye_screen_distance,
            head_tilt=posture_data.head_tilt
        )

    def _evaluate_spine_angle(self, angle: float) -> float:
        """
        Calculate penalty for spine angle deviation.

        Args:
            angle: Spine angle in degrees (0 = vertical)

        Returns:
            Penalty points (0 to SPINE_PENALTY_MAX)
        """
        if angle < self.spine_warning:
            return 0.0

        # Linear penalty between warning and critical
        if angle < self.spine_critical:
            ratio = (angle - self.spine_warning) / (self.spine_critical - self.spine_warning)
            return ratio * (self.SPINE_PENALTY_MAX * 0.5)

        # At or above critical, apply maximum penalty
        return self.SPINE_PENALTY_MAX

    def _evaluate_eye_distance(self, distance: float) -> float:
        """
        Calculate penalty for eye-screen distance.

        Args:
            distance: Distance in cm

        Returns:
            Penalty points (0 to EYE_DISTANCE_PENALTY_MAX)
        """
        if distance >= self.eye_warning:
            return 0.0

        # Linear penalty between warning and critical
        if distance > self.eye_critical:
            ratio = (self.eye_warning - distance) / (self.eye_warning - self.eye_critical)
            return ratio * (self.EYE_DISTANCE_PENALTY_MAX * 0.5)

        # At or below critical, apply maximum penalty
        return self.EYE_DISTANCE_PENALTY_MAX

    def _evaluate_head_tilt(self, tilt: float) -> float:
        """
        Calculate penalty for head tilt.

        Args:
            tilt: Head tilt angle in degrees

        Returns:
            Penalty points (0 to HEAD_TILT_PENALTY_MAX)
        """
        if tilt < self.head_warning:
            return 0.0

        # Linear penalty between warning and critical
        if tilt < self.head_critical:
            ratio = (tilt - self.head_warning) / (self.head_critical - self.head_warning)
            return ratio * (self.HEAD_TILT_PENALTY_MAX * 0.5)

        # At or above critical, apply maximum penalty
        return self.HEAD_TILT_PENALTY_MAX

    def _determine_level(
        self,
        spine_angle: float,
        eye_distance: float,
        head_tilt: float
    ) -> PostureLevel:
        """
        Determine overall posture level based on all metrics.

        Args:
            spine_angle: Spine angle in degrees
            eye_distance: Eye-screen distance in cm
            head_tilt: Head tilt angle in degrees

        Returns:
            PostureLevel (GOOD, WARNING, or CRITICAL)
        """
        # Check for critical issues
        critical_count = 0
        if spine_angle >= self.spine_critical:
            critical_count += 1
        if eye_distance <= self.eye_critical:
            critical_count += 1
        if head_tilt >= self.head_critical:
            critical_count += 1

        if critical_count > 0:
            return PostureLevel.CRITICAL

        # Check for warning issues
        warning_count = 0
        if spine_angle >= self.spine_warning:
            warning_count += 1
        if eye_distance <= self.eye_warning:
            warning_count += 1
        if head_tilt >= self.head_warning:
            warning_count += 1

        if warning_count > 0:
            return PostureLevel.WARNING

        return PostureLevel.GOOD

    def _generate_feedback(self, issues: List[str], score: float) -> str:
        """
        Generate user-friendly feedback message.

        Args:
            issues: List of detected posture issues
            score: Calculated posture score

        Returns:
            User-friendly feedback text
        """
        if not issues:
            if score >= 95:
                return "坐姿标准，继续保持！"
            else:
                return "坐姿良好，稍微调整一下会更完美。"

        # Generate feedback based on issues
        feedback_parts = []

        # Spine issues
        spine_issues = [i for i in issues if "脊柱" in i]
        if spine_issues:
            feedback_parts.append("请坐直身体，保持脊柱挺直")

        # Eye distance issues
        eye_issues = [i for i in issues if "距离" in i]
        if eye_issues:
            feedback_parts.append("请远离屏幕，保持适当距离")

        # Head tilt issues
        head_issues = [i for i in issues if "头部" in i]
        if head_issues:
            feedback_parts.append("请摆正头部，保持平视")

        # Combine feedback
        if feedback_parts:
            return "，".join(feedback_parts) + "。"

        return "请调整坐姿后再继续书写。"


# Global scorer instance
_default_scorer = PostureScorer()


def score_posture(posture_data: PostureData) -> PostureAnalysis:
    """
    Convenience function to score posture data.

    Uses the default PostureScorer instance.

    Args:
        posture_data: Detected posture metrics

    Returns:
        PostureAnalysis with score and feedback
    """
    return _default_scorer.score(posture_data)
