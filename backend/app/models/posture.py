"""
Posture Data Models - 姿态数据模型

Defines Pydantic models for posture detection data from ML Kit Pose Detection.
Includes spine angle, eye-screen distance, head tilt, and scoring results.
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from enum import Enum


class PostureLevel(str, Enum):
    """Posture quality levels"""
    GOOD = "good"           # 姿态正确
    WARNING = "warning"     # 需要注意
    CRITICAL = "critical"   # 严重问题


class PostureData(BaseModel):
    """
    Raw posture detection data from frontend

    Collected from ML Kit Pose Detection during user's writing session.
    """
    spine_angle: float = Field(
        ...,
        ge=0,
        le=90,
        description="脊柱角度 (偏离垂直方向的角度，单位：度)"
    )
    eye_screen_distance: float = Field(
        ...,
        ge=0,
        le=100,
        description="眼屏距离 (单位：厘米)"
    )
    head_tilt: float = Field(
        ...,
        ge=0,
        le=90,
        description="头部倾斜角度 (单位：度)"
    )
    timestamp: Optional[datetime] = Field(
        None,
        description="检测时间戳"
    )

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat() if v else None
        }


class PostureAnalysis(BaseModel):
    """
    Posture analysis result with scoring

    Contains evaluation of the user's posture and actionable feedback.
    """
    is_correct: bool = Field(
        ...,
        description="姿态是否正确"
    )
    score: float = Field(
        ...,
        ge=0,
        le=100,
        description="姿态得分 (0-100)"
    )
    level: PostureLevel = Field(
        ...,
        description="姿态等级"
    )
    issues: List[str] = Field(
        default_factory=list,
        description="检测到的问题列表"
    )
    feedback: str = Field(
        ...,
        description="用户反馈文本"
    )

    # Raw metrics for reference
    spine_angle: float = Field(..., description="脊柱角度")
    eye_screen_distance: float = Field(..., description="眼屏距离")
    head_tilt: float = Field(..., description="头部倾斜")


class ComprehensiveScoreRequest(BaseModel):
    """
    Request model for comprehensive scoring (handwriting + posture)

    Combines user's handwriting strokes with optional posture data
    for holistic evaluation.
    """
    character: str = Field(
        ...,
        min_length=1,
        max_length=1,
        description="要评分的汉字"
    )
    user_strokes: List[List[tuple[float, float]]] = Field(
        ...,
        min_length=1,
        description="用户书写的笔画轨迹，每个笔画是一系列 (x, y) 坐标点，坐标范围 0-1"
    )
    posture_data: Optional[PostureData] = Field(
        None,
        description="姿态检测数据（可选）"
    )


class StrokeAnalysis(BaseModel):
    """Individual stroke analysis result"""
    stroke_index: int = Field(..., description="笔画索引")
    similarity: float = Field(..., ge=0, le=1, description="与标准笔画的相似度")
    score: float = Field(..., ge=0, le=100, description="笔画得分")
    issues: List[str] = Field(default_factory=list, description="笔画问题")


class ComprehensiveScoreResult(BaseModel):
    """
    Comprehensive scoring result

    Combines handwriting quality (70%) and posture quality (30%)
    for a holistic evaluation of the user's performance.
    """
    total_score: float = Field(
        ...,
        ge=0,
        le=100,
        description="总分 (0-100)"
    )
    handwriting_score: float = Field(
        ...,
        ge=0,
        le=100,
        description="书写得分 (70% 权重)"
    )
    posture_score: float = Field(
        ...,
        ge=0,
        le=100,
        description="姿态得分 (30% 权重)"
    )
    grade: str = Field(
        ...,
        description="等级 (优秀/良好/及格/需练习)"
    )
    stroke_analysis: List[StrokeAnalysis] = Field(
        default_factory=list,
        description="各笔画详细分析"
    )
    posture_analysis: Optional[PostureAnalysis] = Field(
        None,
        description="姿态分析结果"
    )
    feedback: str = Field(
        ...,
        description="综合反馈文本"
    )
