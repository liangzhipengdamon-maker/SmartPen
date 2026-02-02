这份文档在 v2.1 技术栈锁定的基础上，更新为“产品工作流”版本，明确真纸伴学的交互模式与教学路径，作为后续实现的唯一真理来源 (Single Source of Truth)。
# 智笔 (SmartPen) - AI 硬笔书法教学系统 (PRD v2.2)

**文档版本:** 2.2 (产品工作流版)
**核心架构:** Flutter (App) + Python FastAPI (Backend) 端云协同
**状态:** 开发就绪 (Ready for Dev)

## PRD v2.2 变更日志 (2025-05-2x) - "Paper-First Pivot"

### 1. 核心交互变更
- **移除**: `WritingCanvas` (数字手写板)。应用不再支持屏幕触控书写。
- **新增**: "电子字帖"模式。手机立式放置，屏幕上半部分显示范字，下半部分为 AI 监测仪表盘。
- **新增**: "智能门禁 (Smart Gate)"。强制校准流程，只有姿态和手部位置正确持续 1 秒后，才能进入练习模式。

### 2. 视觉反馈升级
- **新增**: "叠图模式 (Overlay Mode)"。在评分页实现用户字迹与范字的透明度可调叠加，提供直观的结构对比。
- **修改**: 实时反馈由 "AR 画面叠加" 改为 "非侵入式状态灯 + 语音 TTS"，减少练习时的视觉干扰。

### 3. 算法与数据策略
- **握笔检测**: Sprint 5 阶段采用"占位符策略"。仅检测手腕是否在书写区域 (Presence Detection)，复杂的握笔姿势分析 (Grip Analysis) 推迟至 Sprint 6。
- **语音交互**: 提升语音交互优先级。支持语音指令 "写好了" 触发拍照流程（Sprint 6 预研，UI 预留麦克风图标）。

## 1. 系统概述 (System Overview)
本系统采用 **端云协同架构**：
*   **前端 (Flutter)**：负责 UI 交互、SVG 渲染、真纸伴学的流程控制，以及基于 ML Kit 的实时姿态监测。
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

### 模块三：真纸伴学交互 (Paper-First Interaction)
*   **交互模式**: **电子字帖模式 (Digital Copybook Mode)**。
    *   上半屏：保留 CharacterDisplay（范字），用于演示笔顺和提供临摹参照。
    *   下半屏：AI 导师仪表盘 (AI Tutor Dashboard)，显示姿态状态灯、手势状态灯、语音麦克风图标和“拍照”按钮。
*   **明确废弃**: `WritingCanvas` 组件不再使用，应用不作为手写板。

### 模块四：实时感知与矫正 (Real-time Perception)
*   **前端实现**: 使用 **Flutter**。
*   **核心库**: `google_ml_kit_pose_detection` (基于 Google ML Kit) [8]。
    *   **注意**: 不使用原始 MediaPipe C++ 桥接，而是使用此官方/社区维护的 Flutter 插件以确保稳定性。
*   **新增流程**: 智能门禁 (Smart Gate) 两阶段工作流：
    1.  **校准阶段 (Calibration Phase)**：全屏相机预览，必须满足 Face + Hands + Alignment 持续 > 1s 才能解锁练习。
    2.  **练习/伴学阶段 (Practice/Tutor Phase)**：相机隐形后台运行，UI 转为电子字帖，仅通过语音 TTS 与状态胶囊反馈，不显示实时画面。
*   **UI 描述更新**: 将原本规划的 feedback_overlay (AR 叠加层) 调整为 **非侵入式状态胶囊 (Status Capsule)**。

### 模块五：评分引擎与反馈 (Scoring & Feedback)
*   **后端实现**: Python。
*   **核心库**: `dtw-python` (pollen-robotics) [10]。
*   **算法流程**:
    1.  **加载**: 目标字 $T_{ref}$ (来自 Hanzi Writer) 和 用户字 $T_{user}$ (来自 InkSight 还原)。
    2.  **计算**: 调用 `dtw(t_user, t_ref, dist=manhattan_distance)` 计算距离 [11]。
    3.  **判定**: 基于距离阈值评分，若笔画数量不匹配直接判定为“笔顺错误” [12]。
*   **新增前端视觉反馈**: 双模评价页 (Dual-Mode Evaluation)：
    *   **模式 A (Report)**：分数与评语。
    *   **模式 B (Overlay)**：全屏显示用户拍摄墨迹，红色范字骨架覆盖其上，提供透明度滑块可调。
*   **数据流更新**: 前端需要将标准字的 SVG (Strokes) 与用户拍摄照片对齐渲染，不仅依赖后端返回图像。

### 模块六：教学理念落地 (Pedagogy & Algorithms)
*   **握笔检测降级**: Sprint 5 阶段仅做手部存在性检测 (Presence Detection)：
    *   逻辑：检测 Wrist 位于 ROI 区域内即视为“握笔/准备书写”，关节角度分析延后至 Sprint 6。
*   **数据模型更新**: 在 PostureAnalysis 中显式增加 GripState 字段，为后续算法升级占位。

## 4. 给 AI 开发者的指令 (Implementation Guidelines)
*   **Class Definition**:
    *   `CharacterLoader`: 负责从 `cdn.jsdelivr.net` 拉取数据。
    *   `EvaluationEngine`: 封装 `dtw` 库调用。
    *   `InkSightModel`: 封装 TensorFlow 模型加载与推理 (非 ONNX)。
    *   `SmartGate`: 管理校准/练习阶段切换逻辑。
    *   `PostureAnalysis`: 新增 `GripState` 字段用于占位扩展。

## 5. 风险控制
*   **InkSight 幻觉**: 使用 OpenCV `zhang-suen` 骨架化算法提取物理掩码，过滤 InkSight 生成的画外轨迹 [13]。
