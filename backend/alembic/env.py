"""Alembic 迁移环境配置"""
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import os
from pathlib import Path

# 添加项目根目录到路径
sys_path = str(Path(__file__).resolve().parents[1])
if sys_path not in sys.path:
    sys.path.append(sys_path)

# 导入模型
from app.models.base import Base
from app.models.custom_character_db import CustomCharacterDB
from app.models.user_progress_db import PracticeRecordDB, PracticeGoalDB

# Alembic Config 对象
config = context.config

# 解释配置文件中的 Python 日志配置
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# 为 autogenerate 支持添加模型的 MetaData 对象
target_metadata = Base.metadata

# 从环境变量获取数据库 URL
def get_database_url():
    """从环境变量获取数据库 URL"""
    # 优先使用 DATABASE_URL 环境变量
    database_url = os.getenv("DATABASE_URL")
    if database_url:
        return database_url

    # 否则从单独的环境变量组装
    user = os.getenv("POSTGRES_USER", "smartpen")
    password = os.getenv("POSTGRES_PASSWORD", "smartpen123")
    host = os.getenv("POSTGRES_HOST", "localhost")
    port = os.getenv("POSTGRES_PORT", "5432")
    db = os.getenv("POSTGRES_DB", "smartpen")

    return f"postgresql://{user}:{password}@{host}:{port}/{db}"

def run_migrations_offline() -> None:
    """在'离线'模式下运行迁移。

    这将配置上下文，只需要一个 URL
    而不是 Engine，尽管这里也接受 Engine。
    通过跳过 Engine 创建，我们甚至不需要 DBAPI 可用。

    在此模式下生成脚本时调用。
    """
    url = get_database_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """在'在线'模式下运行迁移。

    在这种情况下，我们需要创建一个 Engine
    并将连接与该上下文关联。

    """
    configuration = config.get_section(config.config_ini_section)
    configuration["sqlalchemy.url"] = get_database_url()

    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            compare_server_default=True,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
