# 快速构建 Android APK

## 方法 1: 使用 Android Studio（推荐新手）

### 步骤：

1. **打开项目**
   ```bash
   # 在 Android Studio 中打开
   /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend
   ```

2. **等待 Gradle 同步完成**
   - 右下角会显示 "Gradle sync finished"
   - 如果有错误，点击 "Try Again"

3. **构建 APK**
   - 菜单栏：`Build` → `Build Bundle(s) / APK(s)` → `Build APK(s)`
   - 选择 `Release`
   - 点击 `Finish`

4. **找到 APK**
   ```
   frontend/build/app/outputs/flutter-apk/app-release.apk
   ```

---

## 方法 2: 使用命令行（需要配置 Flutter 环境）

### 1. 检查 Flutter 安装

```bash
# 检查 Flutter 是否在 PATH 中
which flutter

# 如果没有输出，需要添加到 PATH
# Flutter 通常安装在：
# ~/flutter
# ~/development/flutter
# ~/fvm/default/bin
```

### 2. 配置 PATH

```bash
# 临时添加（当前终端有效）
export PATH="$PATH:/path/to/flutter/bin"

# 永久添加（添加到 ~/.zshrc 或 ~/.bash_profile）
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### 3. 验证环境

```bash
flutter doctor
```

### 4. 构建 Release APK

```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend

# 清理旧构建
flutter clean

# 获取依赖
flutter pub get

# 构建 Release APK
flutter build apk --release --target-platform android-arm64
```

### 5. 找到 APK

```bash
# APK 位置
ls -lh build/app/outputs/flutter-apk/app-release.apk
```

---

## 方法 3: 使用构建脚本（需要 Flutter 在 PATH 中）

```bash
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/android
chmod +x build.sh
./build.sh

# 选择 2 (Release)
```

---

## 常见问题

### Q: Flutter command not found

**A**: Flutter 未安装或未添加到 PATH

**解决**:
1. 检查 Flutter 是否安装:
   ```bash
   ls ~/flutter
   ls ~/development/flutter
   ls ~/fvm/default
   ```

2. 如果找到，添加到 PATH:
   ```bash
   export PATH="$PATH:/path/to/flutter/bin"
   ```

3. 如果没有安装，下载安装:
   ```bash
   # macOS
   curl https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.5-stable.zip

   # 解压到 ~/development/flutter
   ```

### Q: Gradle sync failed

**A**: 网络问题或配置问题

**解决**:
```bash
# 修改 gradle 使用国内镜像
cd frontend/android
# 编辑 build.gradle 和 settings.gradle，添加阿里云镜像
```

### Q: 构建失败，提示 SDK 版本问题

**A**: 更新 Android SDK

**解决**:
- 打开 Android Studio
- SDK Manager → 安装所需的 SDK 版本
- 或在项目中选择较低的 compileSdk

---

## 当前状态

项目已准备好构建，只需：

1. ✅ 确保 Flutter 已安装
2. ✅ 配置 PATH
3. ✅ 运行构建命令

---

**建议新手使用 Android Studio 构建，更简单直观！**
