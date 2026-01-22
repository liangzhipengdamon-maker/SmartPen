"""自定义范字数据模型"""
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field
from enum import Enum


class CharacterStyle(str, Enum):
    """字体风格"""
    KAISHU = "kaishu"      # 楷书
    XINGSHU = "xingshu"    # 行书
    CAOSHU = "caoshu"      # 草书
    LISHU = "lishu"        # 隶书
    SONGTI = "songti"      # 宋体
    CUSTOM = "custom"      # 自定义


class StrokeData(BaseModel):
    """笔画数据"""
    points: List[tuple[float, float]] = Field(..., description="笔画点序列 (归一化 0-1)")
    order: int = Field(..., ge=0, description="笔画顺序")

    class Config:
        json_schema_extra = {
            "example": {
                "points": [(0.3, 0.4), (0.5, 0.5), (0.7, 0.4)],
                "order": 0
            }
        }


class CustomCharacterCreate(BaseModel):
    """创建自定义范字请求"""
    char: str = Field(..., min_length=1, max_length=1, description="汉字（单个）")
    style: CharacterStyle = Field(default=CharacterStyle.CUSTOM, description="字体风格")
    strokes: List[StrokeData] = Field(..., min_length=1, description="笔画列表")
    creator_id: str = Field(..., description="创建者 ID (教师)")
    creator_name: str = Field(..., description="创建者姓名")
    tags: List[str] = Field(default_factory=list, description="标签（如：一年级、上册等）")
    is_public: bool = Field(default=False, description="是否公开分享")

    class Config:
        json_schema_extra = {
            "example": {
                "char": "永",
                "style": "kaishu",
                "strokes": [
                    {"points": [(0.3, 0.4), (0.5, 0.5), (0.7, 0.4)], "order": 0},
                    {"points": [(0.5, 0.3), (0.5, 0.7)], "order": 1}
                ],
                "creator_id": "teacher_123",
                "creator_name": "王老师",
                "tags": ["一年级", "上册"],
                "is_public": True
            }
        }


class CustomCharacterUpdate(BaseModel):
    """更新自定义范字请求"""
    style: Optional[CharacterStyle] = None
    strokes: Optional[List[StrokeData]] = None
    tags: Optional[List[str]] = None
    is_public: Optional[bool] = None


class CustomCharacterResponse(BaseModel):
    """自定义范字响应"""
    id: int
    char: str
    style: CharacterStyle
    strokes: List[StrokeData]
    creator_id: str
    creator_name: str
    tags: List[str]
    is_public: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    usage_count: int = Field(default=0, description="使用次数")

    class Config:
        from_attributes = True


class CustomCharacterList(BaseModel):
    """自定义范字列表响应"""
    total: int
    items: List[CustomCharacterResponse]
    page: int
    page_size: int


class CharacterImageUpload(BaseModel):
    """上传字符图像创建范字请求"""
    char: str = Field(..., min_length=1, max_length=1)
    style: CharacterStyle = Field(default=CharacterStyle.CUSTOM)
    creator_id: str = Field(..., description="创建者 ID")
    creator_name: str = Field(..., description="创建者姓名")
    tags: List[str] = Field(default_factory=list)
    is_public: bool = Field(default=False)
    # 图像数据将在 multipart/form-data 中上传
