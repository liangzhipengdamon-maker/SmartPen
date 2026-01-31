# Gradle 构建问题解决方案

## 问题

Gradle 8.5 下载失败（Premature EOF），这是网络问题。

## 解决方案

### 方案 1: 清理缓存重试

```bash
# 1. 清理所有缓存
rm -rf ~/.gradle/caches/
rm -rf /Users/Zhuanz/.gradle/caches/
rm -rf frontend/build/.gradle/

# 2. 重新构建
cd /Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend
export ANDROID_HOME=/Users/Zhuanz/Documents/01_SmartPen/sdk/android
export PATH="$PATH:/Users/Zhuanz/Documents/01_SmartPen/sdk/flutter/bin:/Users/Zhuanz/Documents/01_SmartPen/sdk/android/platform-tools"
flutter build apk --release --target-platform android-arm64
```

### 方案 2: 手动下载 Gradle

```bash
# 1. 手动下载 Gradle 8.5
cd ~/.gradle/wrapper/dists
mkdir -p gradle-8.5-all
cd gradle-8.5-all
curl -L -o gradle-8.5-all.zip https://services.gradle.org/distributions/gradle-8.5-all.zip

# 2. 解压
unzip gradle-8.5-all.zip

# 3. 重新构建
```

### 方案 3: 使用国内镜像（推荐）

编辑 `android/gradle/wrapper/gradle-wrapper.properties`:

```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.5-all.zip
```

然后重新构建。

### 方案 4: 使用 Android Studio（最简单）

1. 打开 Android Studio
2. 打开项目: `/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend`
3. 等待 Gradle 同步完成（会自动下载）
4. `Build` → `Build Bundle(s) / APK(s)` → `Build APK(s)`
5. 选择 `Release`

## 常见 Gradle 镜像

- 腾讯云: `https://mirrors.cloud.tencent.com/gradle/`
- 阿里云: `https://mirrors.aliyun.com/macports/distfiles/gradle/`
- 华为云: `https://mirrors.huaweicloud.com/gradle/`

## 验证构建

构建成功后，APK 在:
```
/Users/Zhuanz/Documents/01_SmartPen/smartpen-project/frontend/build/app/outputs/flutter-apk/app-release.apk
```
