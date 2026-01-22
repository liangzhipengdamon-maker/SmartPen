# Android APK 构建指南

## 前置要求

1. **安装 Flutter SDK**
   ```bash
   # 下载 Flutter SDK
   # https://docs.flutter.dev/get-started/install

   # 配置环境变量
   export PATH="$PATH:/path/to/flutter/bin"
   ```

2. **安装 Android SDK**
   ```bash
   # 通过 Android Studio 安装
   # 或安装 Command Line Tools
   ```

3. **接受 Android 许可**
   ```bash
   flutter doctor --android-licenses
   ```

4. **检查开发环境**
   ```bash
   flutter doctor
   ```

## 配置本地环境

### 1. 配置 local.properties

```bash
cd frontend/android
cp local.properties.example local.properties
# 编辑 local.properties，设置正确的 Flutter SDK 路径
```

示例 `local.properties`:
```properties
sdk.dir=/Users/your-username/Library/Android/sdk
flutter.sdk=/Users/your-username/development/flutter
```

### 2. 配置应用信息

编辑 `android/app/build.gradle`:
```gradle
defaultConfig {
    applicationId "com.smartpen.app"  // 修改为你的包名
    minSdk 21
    targetSdk 34
    versionCode 1
    versionName "1.0.0"
}
```

### 3. 配置 API 地址

编辑 `frontend/lib/api/characters_api.dart`:
```dart
static const String baseUrl = 'http://your-server-ip:8000';
```

## 构建 APK

### Debug 版本 (开发测试)

```bash
cd frontend

# 构建 Debug APK
flutter build apk --debug

# 输出位置
# build/app/outputs/flutter-apk/app-debug.apk
```

### Release 版本 (正式发布)

```bash
cd frontend

# 构建 Release APK
flutter build apk --release

# 输出位置
# build/app/outputs/flutter-apk/app-release.apk

# 构建 App Bundle (用于 Google Play)
flutter build appbundle --release

# 输出位置
# build/app/outputs/bundle/release/app-release.aab
```

### 指定架构

```bash
# 仅 ARM64
flutter build apk --release --target-platform android-arm64

# 仅 ARM32
flutter build apk --release --target-platform android-arm

# 所有架构 (APK 会更大)
flutter build apk --release --target-platform android-arm64,android-arm
```

## 签名配置 (Release)

### 1. 创建密钥库

```bash
keytool -genkey -v -keystore ~/smartpen-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias smartpen
```

### 2. 配置签名

创建 `android/key.properties`:
```properties
storePassword=your-password
keyPassword=your-password
keyAlias=smartpen
storeFile=/Users/your-username/smartpen-key.jks
```

### 3. 更新 build.gradle

```gradle
// 在 android { 之前添加
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. 构建签名的 APK

```bash
flutter build apk --release
```

## 安装 APK

### 通过 USB 安装

```bash
# 连接设备并启用 USB 调试
flutter devices

# 安装 Debug 版本
flutter install

# 或手动安装
adb install build/app/outputs/flutter-apk/app-debug.apk

# 安装 Release 版本
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 通过无线安装

1. 将 APK 传输到手机
2. 在手机上打开文件管理器
3. 点击 APK 文件安装
4. 允许安装未知来源应用

## 常见问题

### 1. 构建失败: Gradle 错误

```bash
# 清理构建缓存
cd android
./gradlew clean
cd ..

# 清理 Flutter 缓存
flutter clean

# 重新获取依赖
flutter pub get

# 重新构建
flutter build apk --release
```

### 2. 网络请求失败

检查 `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Android 9+ 需要配置网络安全 -->
<application
    android:usesCleartextTraffic="true"
    ...>
```

### 3. 相机权限问题

确保在运行时请求权限:
```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) {
    // 权限已授予
  }
}
```

### 4. ML Kit 不工作

确保添加了正确的依赖:
```gradle
dependencies {
    implementation 'com.google.mlkit:pose-detection:18.0.0-beta3'
    implementation 'com.google.mlkit:pose-detection-accurate:18.0.0-beta3'
}
```

## 发布到 Google Play

### 1. 准备材料

- 应用图标 (512x512)
- 功能截图 (至少 2 张)
- 应用描述
- 隐私政策
- 内容评级问卷

### 2. 创建 Google Play 开发者账号

访问 https://play.google.com/console

### 3. 上传应用

1. 创建新应用
2. 上传 App Bundle (AAB)
3. 填写商店信息
4. 设置定价和分发
5. 提交审核

## 调试技巧

### 查看日志

```bash
# 查看实时日志
flutter logs

# 过滤日志
flutter logs | grep "ERROR"

# 查看特定标签
adb logcat -s "MainActivity"
```

### 分析 APK

```bash
# 查看 APK 内容
unzip -l build/app/outputs/flutter-apk/app-release.apk

# 查看 APK 大小
ls -lh build/app/outputs/flutter-apk/

# 分析 APK 构成
flutter build apk --analyze-size
```

### 性能分析

```bash
# 运行性能分析
flutter run --profile

# 生成性能报告
flutter drive --profile
```
