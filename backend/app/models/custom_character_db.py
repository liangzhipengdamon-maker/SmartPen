"""自定义范字数据库模型和操作"""
from datetime import datetime
from typing import List, Optional
from sqlalchemy import Column, Integer, String, DateTime, Boolean, JSON, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import Session, relationship
from pydantic import BaseModel

from ..models.custom_character import CustomCharacterCreate, CustomCharacterUpdate, StrokeData

Base = declarative_base()


class CustomCharacterDB(Base):
    """自定义范字数据库表"""
    __tablename__ = "custom_characters"

    id = Column(Integer, primary_key=True, index=True)
    char = Column(String(1), nullable=False, index=True)
    style = Column(String(20), nullable=False, default="custom")
    strokes = Column(JSON, nullable=False)  # List[StrokeData]
    creator_id = Column(String(100), nullable=False, index=True)
    creator_name = Column(String(100), nullable=False)
    tags = Column(JSON, default=list)  # List[str]
    is_public = Column(Boolean, default=False, index=True)
    usage_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关系
    # user_practices = relationship("UserPractice", back_populates="custom_character")


class CustomCharacterCRUD:
    """自定义范字 CRUD 操作"""

    @staticmethod
    def create(db: Session, obj_in: CustomCharacterCreate) -> CustomCharacterDB:
        """创建自定义范字"""
        strokes_data = [s.model_dump() for s in obj_in.strokes]

        db_obj = CustomCharacterDB(
            char=obj_in.char,
            style=obj_in.style.value,
            strokes=strokes_data,
            creator_id=obj_in.creator_id,
            creator_name=obj_in.creator_name,
            tags=obj_in.tags,
            is_public=obj_in.is_public,
        )
        db.add(db_obj)
        db.commit()
        db.refresh(db_obj)
        return db_obj

    @staticmethod
    def get(db: Session, id: int) -> Optional[CustomCharacterDB]:
        """获取单个范字"""
        return db.query(CustomCharacterDB).filter(CustomCharacterDB.id == id).first()

    @staticmethod
    def get_multi(
        db: Session,
        creator_id: Optional[str] = None,
        char: Optional[str] = None,
        is_public: Optional[bool] = None,
        tags: Optional[List[str]] = None,
        skip: int = 0,
        limit: int = 100,
    ) -> tuple[List[CustomCharacterDB], int]:
        """获取范字列表"""
        query = db.query(CustomCharacterDB)

        # 过滤条件
        if creator_id:
            query = query.filter(CustomCharacterDB.creator_id == creator_id)
        if char:
            query = query.filter(CustomCharacterDB.char == char)
        if is_public is not None:
            query = query.filter(CustomCharacterDB.is_public == is_public)
        if tags:
            # JSON 数组包含查询
            for tag in tags:
                query = query.filter(CustomCharacterDB.tags.contains(tag))

        total = query.count()
        items = query.order_by(CustomCharacterDB.created_at.desc()).offset(skip).limit(limit).all()

        return items, total

    @staticmethod
    def update(
        db: Session,
        db_obj: CustomCharacterDB,
        obj_in: CustomCharacterUpdate,
    ) -> CustomCharacterDB:
        """更新范字"""
        update_data = obj_in.model_dump(exclude_unset=True)

        if "strokes" in update_data:
            update_data["strokes"] = [s.model_dump() for s in obj_in.strokes]
        if "style" in update_data and hasattr(update_data["style"], "value"):
            update_data["style"] = update_data["style"].value

        for field, value in update_data.items():
            setattr(db_obj, field, value)

        db_obj.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(db_obj)
        return db_obj

    @staticmethod
    def delete(db: Session, id: int) -> Optional[CustomCharacterDB]:
        """删除范字"""
        obj = db.query(CustomCharacterDB).filter(CustomCharacterDB.id == id).first()
        if obj:
            db.delete(obj)
            db.commit()
        return obj

    @staticmethod
    def increment_usage(db: Session, id: int) -> Optional[CustomCharacterDB]:
        """增加使用次数"""
        obj = db.query(CustomCharacterDB).filter(CustomCharacterDB.id == id).first()
        if obj:
            obj.usage_count += 1
            db.commit()
            db.refresh(obj)
        return obj

    @staticmethod
    def get_popular(db: Session, limit: int = 10) -> List[CustomCharacterDB]:
        """获取热门范字（按使用次数）"""
        return db.query(CustomCharacterDB).filter(
            CustomCharacterDB.is_public == True
        ).order_by(
            CustomCharacterDB.usage_count.desc()
        ).limit(limit).all()

    @staticmethod
    def search_by_tags(db: Session, tags: List[str], limit: int = 100) -> List[CustomCharacterDB]:
        """按标签搜索范字"""
        query = db.query(CustomCharacterDB).filter(CustomCharacterDB.is_public == True)

        for tag in tags:
            query = query.filter(CustomCharacterDB.tags.contains(tag))

        return query.order_by(CustomCharacterDB.usage_count.desc()).limit(limit).all()
