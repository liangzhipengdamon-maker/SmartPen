"""自定义范字 API 端点"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.custom_character import (
    CustomCharacterCreate,
    CustomCharacterUpdate,
    CustomCharacterResponse,
    CustomCharacterList,
    CharacterImageUpload,
    CharacterStyle,
)
from ..models.custom_character_db import CustomCharacterDB, CustomCharacterCRUD
from ..services.inksight import InkSightModel
from ..preprocessing.image import preprocess_image

router = APIRouter(prefix="/api/custom-characters", tags=["自定义范字"])


@router.post("/", response_model=CustomCharacterResponse, status_code=201)
def create_custom_character(
    obj_in: CustomCharacterCreate,
    db: Session = Depends(get_db),
):
    """
    创建自定义范字

    教师可以上传手写笔画数据创建个性化范字
    """
    try:
        db_obj = CustomCharacterCRUD.create(db, obj_in)
        return CustomCharacterResponse.model_validate(db_obj)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"创建失败: {str(e)}")


@router.post("/from-image", response_model=CustomCharacterResponse, status_code=201)
async def create_custom_character_from_image(
    char: str = Form(..., min_length=1, max_length=1, description="汉字"),
    style: CharacterStyle = Form(CharacterStyle.CUSTOM, description="字体风格"),
    creator_id: str = Form(..., description="创建者 ID"),
    creator_name: str = Form(..., description="创建者姓名"),
    tags: str = Form("", description="标签（逗号分隔）"),
    is_public: bool = Form(False, description="是否公开"),
    image: UploadFile = File(..., description="字符图像"),
    db: Session = Depends(get_db),
):
    """
    从图像创建自定义范字

    上传手写字符图像，使用 InkSight 生成笔画轨迹
    """
    try:
        # 读取图像
        image_bytes = await image.read()

        # 预处理图像
        processed_image = preprocess_image(image_bytes)

        # 使用 InkSight 生成轨迹
        inksight = InkSightModel()
        trajectory = inksight.predict(processed_image)

        # 转换为笔画数据
        strokes_data = _convert_trajectory_to_strokes(trajectory)

        # 解析标签
        tag_list = [t.strip() for t in tags.split(",") if t.strip()]

        # 创建范字
        obj_in = CustomCharacterCreate(
            char=char,
            style=style,
            strokes=strokes_data,
            creator_id=creator_id,
            creator_name=creator_name,
            tags=tag_list,
            is_public=is_public,
        )

        db_obj = CustomCharacterCRUD.create(db, obj_in)
        return CustomCharacterResponse.model_validate(db_obj)

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"从图像创建失败: {str(e)}")


@router.get("/", response_model=CustomCharacterList)
def list_custom_characters(
    creator_id: Optional[str] = Query(None, description="筛选创建者"),
    char: Optional[str] = Query(None, description="筛选字符"),
    is_public: Optional[bool] = Query(None, description="仅公开范字"),
    tags: Optional[str] = Query(None, description="筛选标签（逗号分隔）"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    db: Session = Depends(get_db),
):
    """获取范字列表"""
    tag_list = [t.strip() for t in tags.split(",")] if tags else None

    skip = (page - 1) * page_size
    items, total = CustomCharacterCRUD.get_multi(
        db,
        creator_id=creator_id,
        char=char,
        is_public=is_public,
        tags=tag_list,
        skip=skip,
        limit=page_size,
    )

    return CustomCharacterList(
        total=total,
        items=[CustomCharacterResponse.model_validate(item) for item in items],
        page=page,
        page_size=page_size,
    )


@router.get("/popular", response_model=List[CustomCharacterResponse])
def get_popular_characters(
    limit: int = Query(10, ge=1, le=50, description="返回数量"),
    db: Session = Depends(get_db),
):
    """获取热门范字（按使用次数）"""
    items = CustomCharacterCRUD.get_popular(db, limit=limit)
    return [CustomCharacterResponse.model_validate(item) for item in items]


@router.get("/search/by-tags", response_model=List[CustomCharacterResponse])
def search_characters_by_tags(
    tags: str = Query(..., description="标签（逗号分隔）"),
    limit: int = Query(20, ge=1, le=100, description="返回数量"),
    db: Session = Depends(get_db),
):
    """按标签搜索范字"""
    tag_list = [t.strip() for t in tags.split(",") if t.strip()]
    items = CustomCharacterCRUD.search_by_tags(db, tags=tag_list, limit=limit)
    return [CustomCharacterResponse.model_validate(item) for item in items]


@router.get("/{character_id}", response_model=CustomCharacterResponse)
def get_custom_character(
    character_id: int,
    db: Session = Depends(get_db),
):
    """获取单个范字详情"""
    db_obj = CustomCharacterCRUD.get(db, character_id)
    if not db_obj:
        raise HTTPException(status_code=404, detail="范字不存在")

    # 增加使用计数
    CustomCharacterCRUD.increment_usage(db, character_id)

    return CustomCharacterResponse.model_validate(db_obj)


@router.put("/{character_id}", response_model=CustomCharacterResponse)
def update_custom_character(
    character_id: int,
    obj_in: CustomCharacterUpdate,
    db: Session = Depends(get_db),
):
    """更新范字"""
    db_obj = CustomCharacterCRUD.get(db, character_id)
    if not db_obj:
        raise HTTPException(status_code=404, detail="范字不存在")

    updated_obj = CustomCharacterCRUD.update(db, db_obj, obj_in)
    return CustomCharacterResponse.model_validate(updated_obj)


@router.delete("/{character_id}", status_code=204)
def delete_custom_character(
    character_id: int,
    creator_id: str = Query(..., description="创建者 ID（验证权限）"),
    db: Session = Depends(get_db),
):
    """删除范字（仅创建者可删除）"""
    db_obj = CustomCharacterCRUD.get(db, character_id)
    if not db_obj:
        raise HTTPException(status_code=404, detail="范字不存在")

    if db_obj.creator_id != creator_id:
        raise HTTPException(status_code=403, detail="无权删除此范字")

    CustomCharacterCRUD.delete(db, character_id)


def _convert_trajectory_to_strokes(trajectory: List) -> List:
    """将 InkSight 轨迹转换为笔画数据"""
    from ..models.custom_character import StrokeData

    # InkSight 返回的轨迹格式需要转换
    # 假设 trajectory 是 List[List[tuple]]
    strokes = []
    for i, stroke_points in enumerate(trajectory):
        strokes.append(StrokeData(points=stroke_points, order=i))
    return strokes
