"""用户进度追踪数据模型"""
from datetime import datetime
from typing import List, Optional, Dict
from pydantic import BaseModel, Field
from enum import Enum


class PracticeMode(str, Enum):
    """练习模式"""
    BASIC = "basic"           # 基础模式
    EXPERT = "expert"         # 专家模式
    CUSTOM = "custom"         # 自定义模式
    TIMED = "timed"           # 计时模式


class ScoreLevel(str, Enum):
    """评分等级"""
    EXCELLENT = "excellent"   # 优秀 (90-100)
    GOOD = "good"             # 良好 (80-89)
    PASS = "pass"             # 及格 (60-79)
    FAIL = "fail"             # 不及格 (0-59)


class PracticeRecordCreate(BaseModel):
    """练习记录创建请求"""
    user_id: str = Field(..., description="用户 ID")
    character: str = Field(..., min_length=1, max_length=1, description="练习的字符")
    character_type: str = Field(default="standard", description="字符类型: standard/custom")
    custom_character_id: Optional[int] = Field(None, description="自定义范字 ID")
    mode: PracticeMode = Field(default=PracticeMode.BASIC, description="练习模式")

    # 评分数据
    total_score: int = Field(..., ge=0, le=100, description="总分")
    stroke_scores: List[int] = Field(..., description="各笔画得分")
    stroke_order_correct: bool = Field(..., description="笔顺是否正确")

    # 姿态数据（可选）
    posture_score: Optional[int] = Field(None, ge=0, le=100, description="坐姿评分")
    grip_correct: Optional[bool] = Field(None, description="握笔是否正确")

    # 统计数据
    time_spent: float = Field(..., description="用时（秒）")
    stroke_count: int = Field(..., ge=0, description="笔画数")

    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "user_123",
                "character": "永",
                "character_type": "standard",
                "mode": "basic",
                "total_score": 85,
                "stroke_scores": [90, 85, 80, 75, 70],
                "stroke_order_correct": True,
                "posture_score": 90,
                "grip_correct": True,
                "time_spent": 45.5,
                "stroke_count": 5
            }
        }


class PracticeRecordResponse(BaseModel):
    """练习记录响应"""
    id: int
    user_id: str
    character: str
    character_type: str
    custom_character_id: Optional[int]
    mode: PracticeMode
    total_score: int
    stroke_scores: List[int]
    stroke_order_correct: bool
    posture_score: Optional[int]
    grip_correct: Optional[bool]
    time_spent: float
    stroke_count: int
    score_level: ScoreLevel
    created_at: datetime

    class Config:
        from_attributes = True


class UserProgressSummary(BaseModel):
    """用户进度汇总"""
    user_id: str
    total_practices: int = Field(description="总练习次数")
    unique_characters: int = Field(description="练习的不同字符数")
    average_score: float = Field(description="平均分")
    best_score: int = Field(description="最高分")
    total_time_spent: float = Field(description="总用时（小时）")
    recent_scores: List[int] = Field(description="最近 10 次得分")

    # 按字符统计
    character_stats: Dict[str, Dict] = Field(description="各字符统计")

    # 姿态统计
    posture_avg_score: Optional[float] = Field(None, description="平均坐姿评分")
    grip_correct_rate: Optional[float] = Field(None, description="握笔正确率")


class UserStreak(BaseModel):
    """用户连续练习天数"""
    user_id: str
    current_streak: int = Field(description="当前连续天数")
    longest_streak: int = Field(description="最长连续天数")
    last_practice_date: Optional[datetime] = Field(None, description="最后练习日期")


class PracticeGoal(BaseModel):
    """练习目标"""
    id: int
    user_id: str
    goal_type: str = Field(..., description="目标类型: daily_score/character_count/time_spent")
    target_value: float = Field(..., description="目标值")
    current_value: float = Field(..., description="当前值")
    deadline: Optional[datetime] = Field(None, description="截止日期")
    achieved: bool = Field(default=False, description="是否达成")
    created_at: datetime


class PracticeGoalCreate(BaseModel):
    """创建练习目标"""
    user_id: str
    goal_type: str = Field(..., description="目标类型")
    target_value: float
    deadline: Optional[datetime] = None
