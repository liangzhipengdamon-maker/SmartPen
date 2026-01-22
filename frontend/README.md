# SmartPen Frontend

智笔 - AI 硬笔书法教学系统 Flutter 前端。

## 环境要求

1. **Flutter SDK** (3.0.0 或更高)
   ```bash
   # macOS
   brew install flutter

   # 验证安装
   flutter doctor
   ```

2. **IDE**
   - VS Code + Flutter 插件
   - Android Studio
   - IntelliJ IDEA

3. **设备/模拟器**
   - iOS Simulator (macOS only)
   - Android Emulator
   - 真机设备

## 快速开始

### 1. 安装依赖

```bash
cd frontend
flutter pub get
```

### 2. 启动后端 API

在新终端中：
```bash
cd ../backend
source .venv/bin/activate
uvicorn app.main:app --reload
```

### 3. 运行 Flutter 应用

```bash
# 运行调试版本
flutter run

# 或指定设备
flutter run -d macos    # macOS Desktop
flutter run -d chrome   # Web
flutter run -d iphone   # iOS Simulator
flutter run -d emulator-5554  # Android Emulator
```

### 4. 运行测试

```bash
# Widget 测试
flutter test

# 单元测试
flutter test test/widget_test.dart
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── api/
│   └── characters_api.dart   # API 客户端
├── models/
│   └── character.dart        # 数据模型
├── providers/
│   └── character_provider.dart # 状态管理
├── screens/
│   └── home_screen.dart      # 主屏幕
├── services/                  # 服务层 (姿态检测等)
└── widgets/
    ├── character_display.dart # 字符显示组件
    ├── writing_canvas.dart    # 书写画布组件
    └── score_panel.dart       # 评分面板组件
```

## 功能特性

- ✅ 字符加载和显示 (Hanzi Writer SVG)
- ✅ 触摸书写和笔画捕获
- ✅ 实时笔画渲染
- ✅ 撤销/清空功能
- ✅ AI 评分集成
- ✅ 米字格背景
- ✅ 评分结果可视化

## 开发说明

### 后端 API 配置

默认后端地址: `http://localhost:8000`

如需修改，编辑 `lib/api/characters_api.dart`:
```dart
CharactersApi(
  baseUrl: 'http://your-server:port',
)
```

### 代码生成

使用 `json_serializable` 生成代码:
```bash
flutter pub run build_runner build
```

## 故障排除

### Flutter 未找到命令

```bash
# macOS
export PATH="$PATH:/opt/homebrew/bin"

# 或添加到 ~/.zshrc 或 ~/.bash_profile
echo 'export PATH="$PATH:/opt/homebrew/bin"' >> ~/.zshrc
source ~/.zshrc
```

### 依赖安装失败

```bash
flutter clean
flutter pub get
```

### iOS 签名问题

```bash
cd ios
pod install
cd ..
flutter run
```

## 下一步

- [ ] 添加 ML Kit Pose 集成 (Sprint 5)
- [ ] 添加实时姿态监测 UI
- [ ] 添加练习模式选择
- [ ] 添加用户进度追踪
