这份文档修正了原 v2.0 中关于 InkSight ONNX 的不可行设定，并明确了 Flutter 和 Python 后端的具体依赖库。请将此内容保存为 智笔产品需求文档_v2.1.md，作为项目的 唯一真理来源 (Single Source of Truth)。
# 智笔 (SmartPen) - AI 硬笔书法教学系统 (PRD v2.1)

**文档版本:** 2.1 (技术栈锁定版)
**核心架构:** Flutter (App) + Python FastAPI (Backend) 端云协同
**状态:** 开发就绪 (Ready for Dev)

## 1. 系统概述 (System Overview)
本系统采用 **端云协同架构**：
*   **前端 (Flutter)**：负责 UI 交互、SVG 渲染及基于 ML Kit 的实时姿态监测。
*   **后端 (Python)**：负责运行重型 AI 模型 (InkSight) 和评分算法 (DTW)，提供 REST API。

## 2. 数据层架构 (Data Layer)
### 2.1 核心数据源
系统基于 **Hanzi Writer Data** 标准：
*   **数据来源**: `chanind/hanzi-writer-data` [1, 2]。
*   **获取方式**: 通过 CDN 动态加载或预下载 `https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/{char}.json` [3]。
*   **数据结构**:
    *   `strokes`: SVG Path 字符串 (用于前端绘制 "皮")。
    *   `medians`: 笔画中心点序列 List[List[Point]] (用于后端 DTW 评分 "骨") [4]。

## 3. 核心功能模块与技术实现 (Core Modules)

### 模块一：标准字库集成 (Standard Library)
*   **技术锚点**: Python 后端解析 `hanzi-writer-data` JSON。
*   **逻辑**: 后端加载 JSON，提取 `medians` 并归一化到 1024x1024 坐标系，作为评分的标准参考 ($T_{ref}$) [5]。

### 模块二：书法范字定制 (Custom Font Pipeline)
*   **功能**: 教师拍照 -> 生成数字化评分模版。
*   **关键修正**: **放弃 ONNX，使用 Python 原生加载**。
*   **技术路径**:
    1.  **输入**: 教师字迹图片。
    2.  **核心推理**: 后端调用 **Google InkSight** 模型 (TensorFlow/Keras 原生加载) [6]。
        *   模型权重: 使用 Hugging Face 发布的 `small-p` 权重 [7]。
        *   输出: 预测的数字墨水轨迹 (Digital Ink)。
    3.  **后处理**: 将 InkSight 的 0-1 相对坐标映射回 1024 系统，生成自定义 JSON。

### 模块三：实时感知与矫正 (Real-time Perception)
*   **前端实现**: 使用 **Flutter**。
*   **核心库**: `google_ml_kit_pose_detection` (基于 Google ML Kit) [8]。
    *   **注意**: 不使用原始 MediaPipe C++ 桥接，而是使用此官方/社区维护的 Flutter 插件以确保稳定性。
*   **监测逻辑**: 实时从 Camera Stream 获取 Pose Landmarks，计算脊柱角度和眼屏距离 [9]。

### 模块四：评分引擎 (Scoring Engine)
*   **后端实现**: Python。
*   **核心库**: `dtw-python` (pollen-robotics) [10]。
*   **算法流程**:
    1.  **加载**: 目标字 $T_{ref}$ (来自 Hanzi Writer) 和 用户字 $T_{user}$ (来自 InkSight 还原)。
    2.  **计算**: 调用 `dtw(t_user, t_ref, dist=manhattan_distance)` 计算距离 [11]。
    3.  **判定**: 基于距离阈值评分，若笔画数量不匹配直接判定为“笔顺错误” [12]。

## 4. 给 AI 开发者的指令 (Implementation Guidelines)
*   **Class Definition**:
    *   `CharacterLoader`: 负责从 `cdn.jsdelivr.net` 拉取数据。
    *   `EvaluationEngine`: 封装 `dtw` 库调用。
    *   `InkSightModel`: 封装 TensorFlow 模型加载与推理 (非 ONNX)。

## 5. 风险控制
*   **InkSight 幻觉**: 使用 OpenCV `zhang-suen` 骨架化算法提取物理掩码，过滤 InkSight 生成的画外轨迹 [13]。
