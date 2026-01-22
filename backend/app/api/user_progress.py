"""用户进度追踪 API 端点"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from ..database import get_db
from ..models.user_progress import (
    PracticeRecordCreate,
    PracticeRecordResponse,
    UserProgressSummary,
    UserStreak,
    PracticeGoal,
    PracticeGoalCreate,
)
from ..models.user_progress_db import (
    PracticeRecordDB,
    PracticeGoalDB,
    UserProgressCRUD,
)

router = APIRouter(prefix="/api/user-progress", tags=["用户进度"])


@router.post("/practice", response_model=PracticeRecordResponse, status_code=201)
def create_practice_record(
    obj_in: PracticeRecordCreate,
    db: Session = Depends(get_db),
):
    """记录练习结果"""
    try:
        db_obj = UserProgressCRUD.create_practice_record(db, obj_in)

        # 更新目标进度
        if obj_in.mode.value == "basic":
            UserProgressCRUD.update_goal_progress(
                db, obj_in.user_id, "daily_score", obj_in.total_score
            )
            UserProgressCRUD.update_goal_progress(
                db, obj_in.user_id, "character_count", 1
            )
            UserProgressCRUD.update_goal_progress(
                db, obj_in.user_id, "time_spent", obj_in.time_spent / 60  # 分钟
            )

        return PracticeRecordResponse.model_validate(db_obj)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"记录失败: {str(e)}")


@router.get("/practice", response_model=List[PracticeRecordResponse])
def get_practice_records(
    user_id: str = Query(..., description="用户 ID"),
    character: Optional[str] = Query(None, description="筛选字符"),
    mode: Optional[str] = Query(None, description="筛选模式"),
    days: Optional[int] = Query(None, description="最近 N 天"),
    skip: int = Query(0, ge=0, description="跳过数量"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    db: Session = Depends(get_db),
):
    """获取练习记录列表"""
    items, total = UserProgressCRUD.get_user_records(
        db,
        user_id=user_id,
        character=character,
        mode=mode,
        days=days,
        skip=skip,
        limit=limit,
    )
    return [PracticeRecordResponse.model_validate(item) for item in items]


@router.get("/summary", response_model=UserProgressSummary)
def get_progress_summary(
    user_id: str = Query(..., description="用户 ID"),
    db: Session = Depends(get_db),
):
    """获取用户进度汇总"""
    summary = UserProgressCRUD.get_progress_summary(db, user_id)
    return UserProgressSummary(**summary)


@router.get("/streak", response_model=UserStreak)
def get_user_streak(
    user_id: str = Query(..., description="用户 ID"),
    db: Session = Depends(get_db),
):
    """获取连续练习天数"""
    streak = UserProgressCRUD.get_streak(db, user_id)
    return UserStreak(**streak)


@router.post("/goals", response_model=PracticeGoal, status_code=201)
def create_practice_goal(
    obj_in: PracticeGoalCreate,
    db: Session = Depends(get_db),
):
    """创建练习目标"""
    try:
        db_obj = UserProgressCRUD.create_goal(db, obj_in)
        return PracticeGoal.model_validate(db_obj)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"创建目标失败: {str(e)}")


@router.get("/goals", response_model=List[PracticeGoal])
def get_user_goals(
    user_id: str = Query(..., description="用户 ID"),
    achieved_only: bool = Query(False, description="仅显示已达成"),
    db: Session = Depends(get_db),
):
    """获取用户目标列表"""
    query = db.query(PracticeGoalDB).filter(PracticeGoalDB.user_id == user_id)

    if achieved_only:
        query = query.filter(PracticeGoalDB.achieved == True)

    items = query.order_by(PracticeGoalDB.created_at.desc()).all()
    return [PracticeGoal.model_validate(item) for item in items]


@router.get("/leaderboard", response_model=List[dict])
def get_leaderboard(
    character: Optional[str] = Query(None, description="筛选字符"),
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: Session = Depends(get_db),
):
    """获取排行榜（按平均分）"""
    query = db.query(
        PracticeRecordDB.user_id,
        func.avg(PracticeRecordDB.total_score).label("avg_score"),
        func.count(PracticeRecordDB.id).label("practice_count"),
    )

    if character:
        query = query.filter(PracticeRecordDB.character == character)

    results = query.group_by(PracticeRecordDB.user_id).order_by(
        func.avg(PracticeRecordDB.total_score).desc()
    ).limit(limit).all()

    return [
        {
            "user_id": row[0],
            "average_score": float(row[1]),
            "practice_count": row[2],
        }
        for row in results
    ]


@router.get("/analytics", response_model=dict)
def get_user_analytics(
    user_id: str = Query(..., description="用户 ID"),
    db: Session = Depends(get_db),
):
    """获取用户详细分析数据"""
    # 按模式统计
    mode_stats = db.query(
        PracticeRecordDB.mode,
        func.count(PracticeRecordDB.id).label("count"),
        func.avg(PracticeRecordDB.total_score).label("avg_score"),
    ).filter(PracticeRecordDB.user_id == user_id).group_by(
        PracticeRecordDB.mode
    ).all()

    # 按评分等级统计
    level_stats = db.query(
        PracticeRecordDB.score_level,
        func.count(PracticeRecordDB.id).label("count"),
    ).filter(PracticeRecordDB.user_id == user_id).group_by(
        PracticeRecordDB.score_level
    ).all()

    # 每日练习趋势（最近 30 天）
    from datetime import timedelta

    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    daily_trends = db.query(
        func.date(PracticeRecordDB.created_at).label("date"),
        func.count(PracticeRecordDB.id).label("count"),
        func.avg(PracticeRecordDB.total_score).label("avg_score"),
    ).filter(
        PracticeRecordDB.user_id == user_id,
        PracticeRecordDB.created_at >= thirty_days_ago,
    ).group_by(
        func.date(PracticeRecordDB.created_at)
    ).order_by(
        func.date(PracticeRecordDB.created_at)
    ).all()

    return {
        "mode_statistics": [
            {
                "mode": row[0],
                "count": row[1],
                "average_score": float(row[2]),
            }
            for row in mode_stats
        ],
        "level_distribution": [
            {
                "level": row[0],
                "count": row[1],
            }
            for row in level_stats
        ],
        "daily_trends": [
            {
                "date": row[0].isoformat(),
                "count": row[1],
                "average_score": float(row[2]),
            }
            for row in daily_trends
        ],
    }
