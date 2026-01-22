"""用户进度追踪数据库模型和操作"""
from datetime import datetime, timedelta
from typing import List, Optional, Dict
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Float, JSON, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session
from pydantic import BaseModel

from ..models.user_progress import (
    PracticeRecordCreate,
    PracticeRecordResponse,
    ScoreLevel,
    PracticeGoalCreate,
)

Base = declarative_base()


class PracticeRecordDB(Base):
    """练习记录数据库表"""
    __tablename__ = "practice_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), nullable=False, index=True)
    character = Column(String(1), nullable=False, index=True)
    character_type = Column(String(20), nullable=False, default="standard")
    custom_character_id = Column(Integer, ForeignKey("custom_characters.id"), nullable=True)
    mode = Column(String(20), nullable=False, default="basic")

    # 评分数据
    total_score = Column(Integer, nullable=False)
    stroke_scores = Column(JSON, nullable=False)  # List[int]
    stroke_order_correct = Column(Boolean, nullable=False)

    # 姿态数据
    posture_score = Column(Integer, nullable=True)
    grip_correct = Column(Boolean, nullable=True)

    # 统计数据
    time_spent = Column(Float, nullable=False)
    stroke_count = Column(Integer, nullable=False)

    score_level = Column(String(20), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)


class PracticeGoalDB(Base):
    """练习目标数据库表"""
    __tablename__ = "practice_goals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), nullable=False, index=True)
    goal_type = Column(String(50), nullable=False)  # daily_score, character_count, time_spent
    target_value = Column(Float, nullable=False)
    current_value = Column(Float, default=0.0)
    deadline = Column(DateTime, nullable=True)
    achieved = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)


class UserProgressCRUD:
    """用户进度 CRUD 操作"""

    @staticmethod
    def create_practice_record(db: Session, obj_in: PracticeRecordCreate) -> PracticeRecordDB:
        """创建练习记录"""
        # 计算评分等级
        score_level = UserProgressCRUD._calculate_score_level(obj_in.total_score)

        db_obj = PracticeRecordDB(
            user_id=obj_in.user_id,
            character=obj_in.character,
            character_type=obj_in.character_type,
            custom_character_id=obj_in.custom_character_id,
            mode=obj_in.mode.value,
            total_score=obj_in.total_score,
            stroke_scores=obj_in.stroke_scores,
            stroke_order_correct=obj_in.stroke_order_correct,
            posture_score=obj_in.posture_score,
            grip_correct=obj_in.grip_correct,
            time_spent=obj_in.time_spent,
            stroke_count=obj_in.stroke_count,
            score_level=score_level.value,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    @staticmethod
    def _calculate_score_level(score: int) -> ScoreLevel:
        """计算评分等级"""
        if score >= 90:
            return ScoreLevel.EXCELLENT
        elif score >= 80:
            return ScoreLevel.GOOD
        elif score >= 60:
            return ScoreLevel.PASS
        else:
            return ScoreLevel.FAIL

    @staticmethod
    def get_user_records(
        db: Session,
        user_id: str,
        character: Optional[str] = None,
        mode: Optional[str] = None,
        days: Optional[int] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[List[PracticeRecordDB], int]:
        """获取用户练习记录"""
        query = db.query(PracticeRecordDB).filter(PracticeRecordDB.user_id == user_id)

        if character:
            query = query.filter(PracticeRecordDB.character == character)
        if mode:
            query = query.filter(PracticeRecordDB.mode == mode)
        if days:
            since = datetime.utcnow() - timedelta(days=days)
            query = query.filter(PracticeRecordDB.created_at >= since)

        total = query.count()
        items = query.order_by(PracticeRecordDB.created_at.desc()).offset(skip).limit(limit).all()

        return items, total

    @staticmethod
    def get_progress_summary(db: Session, user_id: str) -> Dict:
        """获取用户进度汇总"""
        # 总练习次数
        total_practices = db.query(PracticeRecordDB).filter(
            PracticeRecordDB.user_id == user_id
        ).count()

        if total_practices == 0:
            return {
                "user_id": user_id,
                "total_practices": 0,
                "unique_characters": 0,
                "average_score": 0.0,
                "best_score": 0,
                "total_time_spent": 0.0,
                "recent_scores": [],
                "character_stats": {},
                "posture_avg_score": None,
                "grip_correct_rate": None,
            }

        # 统计数据
        from sqlalchemy import func

        stats = db.query(
            func.avg(PracticeRecordDB.total_score).label("avg_score"),
            func.max(PracticeRecordDB.total_score).label("max_score"),
            func.sum(PracticeRecordDB.time_spent).label("total_time"),
            func.avg(PracticeRecordDB.posture_score).label("avg_posture"),
            func.avg(
                func.cast(PracticeRecordDB.grip_correct, Integer)
            ).label("avg_grip"),
        ).filter(PracticeRecordDB.user_id == user_id).first()

        # 不同字符数
        unique_characters = db.query(PracticeRecordDB.character).filter(
            PracticeRecordDB.user_id == user_id
        ).distinct().count()

        # 最近 10 次得分
        recent_records = db.query(PracticeRecordDB.total_score).filter(
            PracticeRecordDB.user_id == user_id
        ).order_by(PracticeRecordDB.created_at.desc()).limit(10).all()
        recent_scores = [r[0] for r in recent_records]

        # 按字符统计
        char_stats = db.query(
            PracticeRecordDB.character,
            func.count(PracticeRecordDB.id).label("count"),
            func.avg(PracticeRecordDB.total_score).label("avg_score"),
        ).filter(PracticeRecordDB.user_id == user_id).group_by(
            PracticeRecordDB.character
        ).all()

        character_stats = {
            char: {"count": count, "average_score": float(avg_score)}
            for char, count, avg_score in char_stats
        }

        return {
            "user_id": user_id,
            "total_practices": total_practices,
            "unique_characters": unique_characters,
            "average_score": float(stats.avg_score or 0),
            "best_score": int(stats.max_score or 0),
            "total_time_spent": float(stats.total_time or 0) / 3600,  # 转换为小时
            "recent_scores": recent_scores,
            "character_stats": character_stats,
            "posture_avg_score": float(stats.avg_posture) if stats.avg_posture else None,
            "grip_correct_rate": float(stats.avg_grip) * 100 if stats.avg_grip else None,
        }

    @staticmethod
    def get_streak(db: Session, user_id: str) -> Dict:
        """获取连续练习天数"""
        # 获取练习日期
        dates = db.query(func.date(PracticeRecordDB.created_at)).filter(
            PracticeRecordDB.user_id == user_id
        ).distinct().order_by(
            func.date(PracticeRecordDB.created_at).desc()
        ).all()

        if not dates:
            return {
                "user_id": user_id,
                "current_streak": 0,
                "longest_streak": 0,
                "last_practice_date": None,
            }

        dates = [d[0] for d in dates]
        last_practice_date = dates[0]

        # 计算当前连续天数
        current_streak = 0
        check_date = datetime.utcnow().date()

        for i, date in enumerate(dates):
            if date == check_date - timedelta(days=i):
                current_streak += 1
            else:
                break

        # 计算最长连续天数
        longest_streak = 1
        temp_streak = 1

        for i in range(1, len(dates)):
            if (dates[i - 1] - dates[i]).days == 1:
                temp_streak += 1
            else:
                longest_streak = max(longest_streak, temp_streak)
                temp_streak = 1

        longest_streak = max(longest_streak, temp_streak, current_streak)

        return {
            "user_id": user_id,
            "current_streak": current_streak,
            "longest_streak": longest_streak,
            "last_practice_date": last_practice_date,
        }

    @staticmethod
    def create_goal(db: Session, obj_in: PracticeGoalCreate) -> PracticeGoalDB:
        """创建练习目标"""
        db_obj = PracticeGoalDB(
            user_id=obj_in.user_id,
            goal_type=obj_in.goal_type,
            target_value=obj_in.target_value,
            deadline=obj_in.deadline,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    @staticmethod
    def update_goal_progress(db: Session, user_id: str, goal_type: str, increment: float):
        """更新目标进度"""
        goals = db.query(PracticeGoalDB).filter(
            PracticeGoalDB.user_id == user_id,
            PracticeGoalDB.goal_type == goal_type,
            PracticeGoalDB.achieved == False,
        ).all()

        for goal in goals:
            goal.current_value += increment
            if goal.current_value >= goal.target_value:
                goal.achieved = True

        db.commit()
