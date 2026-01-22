"""数据库初始化脚本

创建初始数据，包括：
- 默认管理员用户
- 示例字符数据
- 初始练习目标
"""
import asyncio
from datetime import datetime, timedelta
from pathlib import Path

from sqlalchemy.orm import Session

from ..database import SessionLocal, engine, Base
from ..models.custom_character_db import CustomCharacterDB
from ..models.user_progress_db import PracticeGoalDB
from ..models.custom_character import (
    CustomCharacterCreate,
    StrokeData,
    CharacterStyle,
)
from ..models.user_progress import PracticeGoalCreate


def init_db():
    """初始化数据库"""
    # 创建所有表
    Base.metadata.create_all(bind=engine)

    db: Session = SessionLocal()
    try:
        # 创建示例自定义范字
        _create_sample_characters(db)

        # 创建示例练习目标
        _create_sample_goals(db)

        db.commit()
        print("✅ 数据库初始化成功")
    except Exception as e:
        print(f"❌ 数据库初始化失败: {e}")
        db.rollback()
        raise
    finally:
        db.close()


def _create_sample_characters(db: Session):
    """创建示例自定义范字"""
    # 检查是否已有数据
    existing = db.query(CustomCharacterDB).first()
    if existing:
        print("⚠️  自定义范字数据已存在，跳过创建")
        return

    # 示例字符 "一"
    char_one = CustomCharacterDB(
        char="一",
        style=CharacterStyle.KAISHU.value,
        strokes=[
            {"points": [(0.3, 0.5), (0.7, 0.5)], "order": 0}
        ],
        creator_id="system",
        creator_name="系统",
        tags=["示例", "基础"],
        is_public=True,
    )

    # 示例字符 "十"
    char_ten = CustomCharacterDB(
        char="十",
        style=CharacterStyle.KAISHU.value,
        strokes=[
            {"points": [(0.5, 0.3), (0.5, 0.7)], "order": 0},
            {"points": [(0.3, 0.5), (0.7, 0.5)], "order": 1}
        ],
        creator_id="system",
        creator_name="系统",
        tags=["示例", "基础"],
        is_public=True,
    )

    # 示例字符 "人"
    char_person = CustomCharacterDB(
        char="人",
        style=CharacterStyle.KAISHU.value,
        strokes=[
            {"points": [(0.5, 0.3), (0.3, 0.7)], "order": 0},
            {"points": [(0.5, 0.4), (0.7, 0.7)], "order": 1}
        ],
        creator_id="system",
        creator_name="系统",
        tags=["示例"],
        is_public=True,
    )

    db.add_all([char_one, char_ten, char_person])
    print("✅ 创建示例自定义范字")


def _create_sample_goals(db: Session):
    """创建示例练习目标"""
    # 检查是否已有数据
    existing = db.query(PracticeGoalDB).first()
    if existing:
        print("⚠️  练习目标数据已存在，跳过创建")
        return

    # 示例每日目标
    daily_score_goal = PracticeGoalDB(
        user_id="demo_user",
        goal_type="daily_score",
        target_value=80.0,  # 每日平均分 80
        current_value=0.0,
        deadline=datetime.now() + timedelta(days=30),
    )

    character_count_goal = PracticeGoalDB(
        user_id="demo_user",
        goal_type="character_count",
        target_value=10.0,  # 每日练习 10 个字符
        current_value=0.0,
        deadline=datetime.now() + timedelta(days=30),
    )

    time_spent_goal = PracticeGoalDB(
        user_id="demo_user",
        goal_type="time_spent",
        target_value=30.0,  # 每日练习 30 分钟
        current_value=0.0,
        deadline=datetime.now() + timedelta(days=30),
    )

    db.add_all([daily_score_goal, character_count_goal, time_spent_goal])
    print("✅ 创建示例练习目标")


def main():
    """主函数"""
    print("=" * 50)
    print("SmartPen 数据库初始化")
    print("=" * 50)

    init_db()

    print("=" * 50)
    print("初始化完成！")
    print("=" * 50)


if __name__ == "__main__":
    main()
