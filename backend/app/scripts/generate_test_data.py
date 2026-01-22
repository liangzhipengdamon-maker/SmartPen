"""
测试数据生成脚本

用于开发/测试环境生成模拟数据
"""
import random
from datetime import datetime, timedelta
from sqlalchemy.orm import Session

from ..database import SessionLocal
from ..models.custom_character_db import CustomCharacterDB
from ..models.user_progress_db import PracticeRecordDB, PracticeGoalDB
from ..models.custom_character import StrokeData
from ..models.user_progress import PracticeMode


# 常用汉字
COMMON_CHARACTERS = [
    '一', '二', '三', '四', '五', '六', '七', '八', '九', '十',
    '人', '口', '大', '小', '天', '地', '日', '月', '水', '火',
    '山', '石', '田', '土', '木', '禾', '竹', '米', '金', '丝',
    '永', '和', '平', '安', '福', '春', '夏', '秋', '冬', '中',
    '国', '学', '习', '书', '写', '字', '文', '化', '艺', '术',
]

# 姓氏
SURNAMES = ['王', '李', '张', '刘', '陈', '杨', '黄', '赵', '周', '吴']

# 名字
NAMES = ['明', '华', '强', '伟', '芳', '娜', '敏', '静', '杰', '磊']


def generate_mock_strokes(num_strokes: int) -> list:
    """生成模拟笔画数据"""
    strokes = []
    for i in range(num_strokes):
        # 生成 3-10 个点
        num_points = random.randint(3, 10)
        points = []
        for j in range(num_points):
            x = random.uniform(0.2, 0.8)
            y = random.uniform(0.2, 0.8)
            points.append((x, y))
        strokes.append({
            "points": points,
            "order": i
        })
    return strokes


def generate_random_score(is_expert: bool = False) -> int:
    """生成随机分数"""
    if is_expert:
        return random.randint(85, 100)
    else:
        return random.randint(50, 95)


def generate_test_users(count: int = 10) -> list:
    """生成测试用户列表"""
    users = []
    for i in range(count):
        surname = random.choice(SURNAMES)
        name = random.choice(NAMES)
        user_id = f"user_{i+1:04d}"
        users.append({
            'id': user_id,
            'name': f"{surname}{name}",
        })
    return users


def generate_test_characters(count: int = 20) -> list:
    """生成测试自定义范字"""
    characters = []
    for i in range(count):
        char = random.choice(COMMON_CHARACTERS)
        num_strokes = random.randint(1, 12)

        character = CustomCharacterDB(
            char=char,
            style=random.choice(['kaishu', 'xingshu', 'custom']),
            strokes=generate_mock_strokes(num_strokes),
            creator_id=f"teacher_{random.randint(1, 5):04d}",
            creator_name=f"{random.choice(SURNAMES)}老师",
            tags=random.sample(['一年级', '二年级', '基础', '进阶', '常用'], random.randint(1, 3)),
            is_public=random.choice([True, False]),
            usage_count=random.randint(0, 100),
        )
        characters.append(character)
    return characters


def generate_test_practices(
    db: Session,
    user_id: str,
    days: int = 30,
    practices_per_day: int = (5, 15)
):
    """生成测试练习记录"""
    start_date = datetime.now() - timedelta(days=days)

    for day in range(days):
        date = start_date + timedelta(days=day)
        num_practices = random.randint(*practices_per_day)

        for _ in range(num_practices):
            char = random.choice(COMMON_CHARACTERS)
            total_score = generate_random_score()

            # 生成笔画分数
            num_strokes = random.randint(1, 8)
            stroke_scores = [generate_random_score() for _ in range(num_strokes)]

            # 随机练习模式
            mode = random.choice(['basic', 'expert', 'custom', 'timed'])

            record = PracticeRecordDB(
                user_id=user_id,
                character=char,
                character_type='standard',
                mode=mode,
                total_score=total_score,
                stroke_scores=stroke_scores,
                stroke_order_correct=random.choice([True, False]),
                posture_score=random.randint(60, 100),
                grip_correct=random.choice([True, False, None]),
                time_spent=random.uniform(20, 120),
                stroke_count=num_strokes,
                score_level='excellent' if total_score >= 90 else 'good' if total_score >= 80 else 'pass' if total_score >= 60 else 'fail',
                created_at=date + timedelta(hours=random.randint(8, 22), minutes=random.randint(0, 59)),
            )
            db.add(record)


def generate_test_goals(db: Session, user_id: str):
    """生成测试练习目标"""
    goals = [
        PracticeGoalDB(
            user_id=user_id,
            goal_type='daily_score',
            target_value=80.0,
            current_value=random.uniform(0, 90),
            deadline=datetime.now() + timedelta(days=30),
            achieved=random.choice([True, False]),
        ),
        PracticeGoalDB(
            user_id=user_id,
            goal_type='character_count',
            target_value=10.0,
            current_value=random.uniform(0, 15),
            deadline=datetime.now() + timedelta(days=30),
            achieved=random.choice([True, False]),
        ),
        PracticeGoalDB(
            user_id=user_id,
            goal_type='time_spent',
            target_value=30.0,
            current_value=random.uniform(0, 45),
            deadline=datetime.now() + timedelta(days=30),
            achieved=random.choice([True, False]),
        ),
    ]
    for goal in goals:
        db.add(goal)


def generate_all_test_data(
    num_users: int = 10,
    num_characters: int = 20,
    practice_days: int = 30
):
    """生成所有测试数据"""
    db: Session = SessionLocal()

    try:
        print(f"开始生成测试数据...")

        # 生成自定义范字
        print(f"生成 {num_characters} 个自定义范字...")
        characters = generate_test_characters(num_characters)
        for char in characters:
            db.add(char)
        db.commit()
        print(f"✓ 完成")

        # 生成用户和练习记录
        users = generate_test_users(num_users)
        print(f"生成 {num_users} 个用户的练习数据...")

        for i, user in enumerate(users, 1):
            print(f"  处理用户 {i}/{num_users}: {user['name']}")
            generate_test_practices(db, user['id'], days=practice_days)
            generate_test_goals(db, user['id'])
            db.commit()

        print(f"\n✓ 测试数据生成完成！")
        print(f"  - {num_users} 个用户")
        print(f"  - {num_characters} 个自定义范字")
        print(f"  - {practice_days} 天的练习记录")

    except Exception as e:
        print(f"✗ 生成失败: {e}")
        db.rollback()
        raise
    finally:
        db.close()


def clear_test_data():
    """清理测试数据"""
    db: Session = SessionLocal()

    try:
        confirm = input("确定要清理所有测试数据吗？(yes/no): ")
        if confirm.lower() != 'yes':
            print("已取消")
            return

        print("清理测试数据...")

        # 清理练习记录
        db.query(PracticeRecordDB).delete()
        # 清理练习目标
        db.query(PracticeGoalDB).delete()
        # 清理自定义范字（保留系统创建的）
        db.query(CustomCharacterDB).filter(
            CustomCharacterDB.creator_id != 'system'
        ).delete()

        db.commit()
        print("✓ 测试数据已清理")

    except Exception as e:
        print(f"✗ 清理失败: {e}")
        db.rollback()
        raise
    finally:
        db.close()


def main():
    """主函数"""
    import argparse

    parser = argparse.ArgumentParser(description='生成测试数据')
    parser.add_argument('--users', type=int, default=10, help='用户数量')
    parser.add_argument('--characters', type=int, default=20, help='范字数量')
    parser.add_argument('--days', type=int, default=30, help='练习天数')
    parser.add_argument('--clear', action='store_true', help='清理测试数据')

    args = parser.parse_args()

    print("=" * 50)
    print("SmartPen 测试数据生成器")
    print("=" * 50)
    print()

    if args.clear:
        clear_test_data()
    else:
        generate_all_test_data(
            num_users=args.users,
            num_characters=args.characters,
            practice_days=args.days
        )

    print()
    print("=" * 50)


if __name__ == "__main__":
    main()
