# SmartPen 视觉感知功能开发计划

## 执行摘要

**项目状态**: Sprint 5 - 实时监测功能开发

**当前进度**:
- ✅ 姿态检测核心算法完成 (70%)
- ✅ ML Kit Pose Detection 已集成
- ✅ 状态管理架构完整
- ⚠️ 相机流处理未完成 (标注 TODO)
- ❌ 握笔检测未实现 (仅框架)
- ❌ 警报系统未集成

**关键文件路径**:
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/providers/posture_provider.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/services/grip_detector.dart`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/pubspec.yaml`
- `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/lib/services/mlkit_service.dart`

---

## 功能优先级

### P0 - Sprint 5 核心功能

| 优先级 | 功能 | 状态 | 工作量 |
|--------|------|------|--------|
| P0-1 | 实时相机流处理 | TODO (第 132 行) | 2-3 天 |
| P0-2 | 音频资源准备 | 缺失 | 0.5 天 |
| P0-3 | 警报系统集成 | 代码存在未连接 | 1-2 天 |

### P1 - Sprint 5 推荐功能

| 优先级 | 功能 | 状态 | 工作量 |
|--------|------|------|--------|
| P1-1 | ML Kit Hand Detection | 未集成 | 2-3 天 |
| P1-2 | 握笔检测算法 | 仅框架 (第 17-40 行) | 2-3 天 |
| P1-3 | 性能监控 | 部分实现 | 1 天 |

### P2 - Sprint 6 增强功能

| 优先级 | 功能 | 状态 | 工作量 |
|--------|------|------|--------|
| P2-1 | iOS 平台支持 | 缺失 | 2 天 |
| P2-2 | 高级 UI 动画 | 待开发 | 2-3 天 |

---

## 详细实现步骤

### 阶段 1: 实时相机流处理 (P0-1)

**目标**: 完善相机帧捕获并传递给姿态检测

**修改文件**: `posture_provider.dart`

**当前问题**:
```dart
// 第 132-137 行 - TODO 注释
Future<void> startCameraStream() async {
  // TODO: 实现 camera 包的相机初始化
  // 这需要 device_id 和其他配置
  debugPrint('CameraController: Starting camera stream...');
  _provider.startMonitoring();
}
```

**实现步骤**:
1. 使用 `camera` 包初始化相机控制器
2. 配置分辨率预设 (ResolutionPreset.medium)
3. 实现图像流订阅 (`startImageStream`)
4. 添加帧率控制 (10 FPS 限制)
5. 实现 `processCameraImage()` 调用链

**验收标准**:
- ✅ 相机能稳定启动
- ✅ 帧率稳定在 5-10 FPS
- ✅ 无内存泄漏
- ✅ 相机权限错误处理完善

---

### 阶段 2: 音频资源准备 (P0-2)

**目标**: 创建警报系统所需的声音文件

**修改文件**: `pubspec.yaml`

**当前问题**: 依赖配置中缺少音频相关依赖

**实现步骤**:
1. 创建音频资源目录:
   ```bash
   mkdir -p assets/sounds
   ```

2. 添加音频文件:
   - `assets/sounds/alert_warning.mp3` - 警告级提示音
   - `assets/sounds/alert_critical.mp3` - 严重级提示音

3. 更新 `pubspec.yaml`:
   ```yaml
   dependencies:
     audioplayers: ^6.0.0
     vibration: ^2.0.0

   flutter:
     assets:
       - assets/sounds/
   ```

**验收标准**:
- ✅ 音频文件存在且可播放
- ✅ `flutter pub get` 无错误

---

### 阶段 3: 警报系统集成 (P0-3)

**目标**: 连接姿态检测与警报系统

**修改文件**: `posture_provider.dart`

**实现步骤**:
1. 在 `startMonitoring()` 的 `poseStream.listen` 中添加警报触发
2. 集成 `AlertSystem().processPostureAnalysis()`
3. 实现警报冷却机制
4. 添加用户配置选项 (启用/禁用)

**验收标准**:
- ✅ 不良姿态触发声音警报
- ✅ 不良姿态触发振动 (Android)
- ✅ 警报冷却机制工作
- ✅ 用户可以禁用警报

---

### 阶段 4: ML Kit Hand Detection 集成 (P1-1)

**目标**: 为握笔检测准备基础能力

**修改文件**: `pubspec.yaml`

**实现步骤**:
1. 添加依赖:
   ```yaml
   dependencies:
     google_mlkit_hand_detection: ^0.2.0
   ```

2. 创建新文件 `lib/services/hand_detection_service.dart`:
   - 参考 `MLKitPoseService` 架构
   - 实现 Isolate 处理
   - 提供 `processCameraImage()` 方法

3. 集成到相机流:
   - 使用 `StreamGroup` 合并 Pose 和 Hand 检测流

**验收标准**:
- ✅ Hand Detection 能稳定检测手部
- ✅ 不影响 Pose Detection 性能
- ✅ 能获取手部关键点数据

---

### 阶段 5: 握笔检测算法实现 (P1-2)

**目标**: 实现握笔方式分析

**修改文件**: `grip_detector.dart`

**当前问题** (第 17-40 行):
```dart
// 注释明确说明需要 ML Kit Hand Detection API
// 当前是简化实现，直接返回标准握笔
```

**实现步骤**:
1. 修改 `analyzeGrip()` 方法接受 `Hand` 对象
2. 实现拇指-食指角度计算 (`_calculateThumbIndexAngle()`)
3. 实现手指伸展度计算 (`_calculateFingerExtension()`)
4. 实现握笔类型分类逻辑

**验收标准**:
- ✅ 能识别标准握笔和错误握笔
- ✅ 计算拇指-食指角度准确
- ✅ UI 实时反馈握笔状态

---

## 关键文件修改清单

### 必须修改 (P0)

1. **`lib/providers/posture_provider.dart`**
   - 第 132-137 行: 完善 `startCameraStream()`
   - 第 56-72 行: 集成警报系统

2. **`pubspec.yaml`**
   - 添加 `audioplayers` 依赖
   - 添加 `vibration` 依赖
   - 添加 `assets/sounds/` 资源路径

### 需要创建 (P1)

3. **`assets/sounds/alert_warning.mp3`** - 警告音
4. **`assets/sounds/alert_critical.mp3`** - 严重警告音
5. **`lib/services/hand_detection_service.dart`** - Hand Detection 服务

### 需要完善 (P1)

6. **`lib/services/grip_detector.dart`**
   - 第 54-65 行: 实现真实的握笔检测算法

---

## 技术选型

| 组件 | 技术选型 | 版本 | 状态 |
|------|---------|------|------|
| 姿态检测 | ML Kit Pose Detection | 0.14.0 | ✅ 已集成 |
| 手部检测 | ML Kit Hand Detection | 0.2.0 | ❌ 待添加 |
| 相机访问 | Camera Plugin | 0.11.3 | ✅ 已集成 |
| 音频播放 | AudioPlayers | 6.0.0 | ❌ 待添加 |
| 振动反馈 | Vibration | 2.0.0 | ❌ 待添加 |

---

## 风险评估

### 风险 1: 相机流性能问题 (高)

**缓解措施**:
- 使用 Isolate 隔离计算 ✅ 已实现
- 添加帧率限制 (10 FPS)
- 实现帧跳过机制

### 风险 2: Hand Detection 性能不足 (中)

**缓解措施**:
- 降级策略: 仅在用户请求时启动
- 分时段检测: Hand 每 2 秒检测一次

### 风险 3: 电池消耗过快 (中)

**缓解措施**:
- 添加"低功耗模式"
- 电量 <20% 时自动降级

---

## 验收标准

### Sprint 5 验收标准

| 功能 | 验收标准 |
|------|---------|
| 相机流处理 | 帧率 5-10 FPS，无内存泄漏 |
| 姿态检测集成 | 实时检测脊柱角度、眼屏距离、头部倾斜 |
| 警报系统 | 不良姿态触发声音和振动 |
| 音频资源 | 音频文件存在，可正常播放 |
| 错误处理 | 相机权限拒绝有友好提示 |

---

## 时间估算

### Sprint 5 (6.5-9.5 天)

| 阶段 | 工作量 |
|------|--------|
| 阶段 1: 相机流 | 2-3 天 |
| 阶段 2: 音频资源 | 0.5 天 |
| 阶段 3: 警报集成 | 1-2 天 |
| 阶段 4: Hand Detection | 2-3 天 |
| 阶段 6: 性能监控 | 1 天 |

### Sprint 6 (6-8 天，可选)

| 阶段 | 工作量 |
|------|--------|
| 阶段 5: 握笔检测 | 2-3 天 |
| 阶段 7: iOS 支持 | 2 天 |
| 高级 UI 优化 | 2-3 天 |

---

## 测试策略

1. **单元测试**: `PostureDetector`、`GripDetector` 算法测试
2. **集成测试**: 相机流 → 姿态检测 → UI 更新
3. **性能测试**: 帧率稳定性、内存泄漏检测
4. **用户测试**: 真实场景使用测试

---

## 成功指标

### 技术指标
- ✅ 姿态检测准确率 > 90%
- ✅ 实时帧率 ≥ 5 FPS
- ✅ 丢帧率 < 5%
- ✅ 内存占用 < 200MB

### 用户体验指标
- ✅ 警报响应时间 < 500ms
- ✅ 假警报率 < 10%
