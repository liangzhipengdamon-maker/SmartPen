# Android APK 快速构建指南

## 🚀 一键构建

### 方法 1: 使用构建脚本 (推荐)

```bash
cd frontend/android
chmod +x build.sh
./build.sh
```

按照提示选择构建类型：
1. **Debug 版本** - 用于开发测试
2. **Release 版本** - 用于正式发布
3. **App Bundle** - 用于 Google Play 上架

### 方法 2: 手动构建

```bash
# 1. 配置环境
cd frontend/android
cp local.properties.example local.properties
# 编辑 local.properties 设置 Flutter SDK 路程

# 2. 构建 APK
cd ..
flutter build apk --release

# 3. 找到 APK
# build/app/outputs/flutter-apk/app-release.apk
```

## 📱 安装到手机

### 方法 1: USB 安装

```bash
# 1. 启用手机 USB 调试
# 2. 连接电脑
adb devices

# 3. 安装 APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 方法 2: 无线安装

1. 将 APK 文件传输到手机
2. 在手机上打开文件管理器
3. 点击 APK 文件安装
4. 允许安装未知来源应用

## ⚙️ 配置说明

### 1. 修改 API 地址

编辑 `frontend/lib/api/characters_api.dart`:

```dart
// 将这里的地址改为你的服务器地址
static const String baseUrl = 'http://192.168.1.100:8000';
```

### 2. 修改应用名称

编辑 `frontend/android/app/src/main/res/values/strings.xml`:

```xml
<string name="app_name">智笔</string>
```

### 3. 修改包名

编辑 `frontend/android/app/build.gradle`:

```gradle
defaultConfig {
    applicationId "com.yourcompany.smartpen"  // 改成你自己的
    ...
}
```

## 📋 环境要求

- Flutter SDK 3.16+
- Android SDK 21+ (targetSdk 34)
- JDK 8+

检查环境:
```bash
flutter doctor
```

## 🔧 常见问题

### 问题 1: 构建失败 "flutter.sdk not set"

**解决**:
```bash
cd frontend/android
cp local.properties.example local.properties
# 编辑文件，设置正确的 Flutter SDK 路径
```

### 问题 2: 网络请求失败

**解决**: 确保手机和服务器在同一网络，并且地址配置正确。

### 问题 3: 相机权限问题

**解决**: 首次使用时，应用会请求相机权限，请点击允许。

## 📦 输出文件

构建完成后，APK 文件位于:
```
frontend/build/smartpen-1.0.0.apk
```

文件大小约 20-30 MB。

## 🎯 下一步

1. 将 APK 安装到手机
2. 确保手机和服务器在同一网络
3. 启动应用，开始使用！

详细文档请参考 `frontend/android/BUILD.md`
