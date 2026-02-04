# InkSight 迁移记录

## 迁移时间
2026-02-04

## 迁移原因
InkSight 模型过于重型，不符合产品核心需求（书写节奏 > 笔顺正确性）

## 迁移目标
- **前端**: ML Kit Pose Detection → 实时节奏追踪
- **后端**: OpenCV + scikit-image → 骨架提取 + 结构评分

## 替代方案
详见 `/Users/Zhuanz/.claude/plans/curious-popping-ocean.md`

## 已归档文件
- `backend/app/models/inksight.py` → `backend/archive/inksight.py`
- `backend/download_inksight.py` → `backend/archive/download_inksight.py`
- `backend/tests/test_inksight.py` → `backend/archive/tests/test_inksight.py`

## 已移除依赖
- `tensorflow>=2.15.0,<2.18.0`
- `transformers>=4.30.0`
- `torch>=2.0.0`
- `keras` (隐式依赖)

## 已添加依赖
- `opencv-python-headless>=4.8.0`
- `scikit-image>=0.21.0`
- `scipy>=1.11.0`
- `Pillow>=10.0.0`

## 保留依赖
- `dtw-python>=1.0.0` (节奏评分核心算法)

## API 变更
- `POST /api/score/from_photo` 暂时返回 503 状态码
- 错误信息: "评分引擎升级中，OpenCV 骨架提取功能即将上线"

## 下一步 (Phase 2 & Phase 3)
详见 `/Users/Zhuanz/.claude/plans/curious-popping-ocean.md`:
- Phase 2: 前端集成 ML Kit Pose Detection
- Phase 3: 后端实现 OpenCV 结构评分器

## 回滚方案
如需回滚到 InkSight:
```bash
# 1. 恢复文件
cp backend/archive/inksight.py backend/app/models/
cp backend/archive/download_inksight.py backend/
cp backend/archive/tests/test_inksight.py backend/tests/

# 2. 恢复 requirements.txt
git checkout HEAD~1 backend/requirements.txt

# 3. 恢复导入
git checkout HEAD~1 backend/app/models/__init__.py
git checkout HEAD~1 backend/app/models/model_loader.py
git checkout HEAD~1 backend/app/api/scoring.py
```

## 验证步骤
```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
python -c "from app.models import __all__; print('Import OK')"
```
