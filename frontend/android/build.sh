#!/bin/bash

# SmartPen Android APK 构建脚本

set -e

echo "=========================================="
echo "  SmartPen Android APK 构建脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}错误: Flutter 未安装或未添加到 PATH${NC}"
    echo "请访问 https://docs.flutter.dev/get-started/install 安装 Flutter"
    exit 1
fi

echo -e "${GREEN}✓${NC} Flutter 已安装"

# 检查环境
echo ""
echo "检查 Flutter 环境..."
flutter doctor --android-licenses

# 进入 frontend 目录
cd "$(dirname "$0")/.."
FRONTEND_DIR=$(pwd)
echo ""
echo "项目目录: $FRONTEND_DIR"

# 检查 local.properties
if [ ! -f "android/local.properties" ]; then
    echo ""
    echo -e "${YELLOW}⚠${NC}  未找到 android/local.properties"
    echo "请从 android/local.properties.example 复制并配置："
    echo "  cp android/local.properties.example android/local.properties"
    echo "然后编辑文件，设置正确的 Flutter SDK 路径"
    read -p "是否现在创建？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        FLUTTER_SDK=$(flutter --version 2>/dev/null | grep "Flutter" | awk '{print $2}')
        if [ -z "$FLUTTER_SDK" ]; then
            FLUTTER_PATH=$(which flutter)
            FLUTTER_SDK=$(dirname $(dirname $FLUTTER_PATH))
        fi

        if [ -n "$FLUTTER_SDK" ]; then
            cat > android/local.properties << EOF
sdk.dir=$ANDROID_HOME
flutter.sdk=$FLUTTER_SDK
EOF
            echo -e "${GREEN}✓${NC} 已创建 android/local.properties"
        else
            echo -e "${RED}错误: 无法自动检测 Flutter SDK 路径${NC}"
            echo "请手动创建并配置 android/local.properties"
            exit 1
        fi
    else
        exit 1
    fi
fi

# 选择构建类型
echo ""
echo "请选择构建类型:"
echo "  1) Debug 版本 (开发测试，较大)"
echo "  2) Release 版本 (正式发布，较小)"
echo "  3) App Bundle (用于 Google Play)"
read -p "请输入选择 (1-3): " -n 1 -r
echo
BUILD_TYPE=$REPLY

# 获取版本号
VERSION=$(grep "version:" pubspec.yaml | head -1 | sed 's/version: //' | sed 's/+.*//')
# 生成构建号：YYMMDDHH (如 25012313 = 2025年1月23日13时)
# 确保不超过 Android 最大限制 2100000000
BUILD_NUMBER=$(date +%y%m%d%H)

echo ""
echo "版本号: $VERSION"
echo "构建号: $BUILD_NUMBER"

# 清理旧构建
echo ""
echo -e "${YELLOW}清理旧构建...${NC}"
flutter clean

# 获取依赖
echo ""
echo "获取依赖..."
flutter pub get

# 构建
echo ""
echo "开始构建..."
case $BUILD_TYPE in
    1)
        echo "构建 Debug APK..."
        flutter build apk --debug \
            --build-number=$BUILD_NUMBER
        APK_PATH="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-debug.apk"
        OUTPUT_NAME="smartpen-debug-$VERSION.apk"
        ;;
    2)
        echo "构建 Release APK..."
        flutter build apk --release \
            --build-number=$BUILD_NUMBER \
            --target-platform android-arm64
        APK_PATH="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
        OUTPUT_NAME="smartpen-$VERSION.apk"
        ;;
    3)
        echo "构建 App Bundle..."
        flutter build appbundle --release \
            --build-number=$BUILD_NUMBER
        APK_PATH="$FRONTEND_DIR/build/app/outputs/bundle/release/app-release.aab"
        OUTPUT_NAME="smartpen-$VERSION.aab"
        ;;
    *)
        echo -e "${RED}错误: 无效的选择${NC}"
        exit 1
        ;;
esac

# 复制到当前目录
OUTPUT_PATH="$FRONTEND_DIR/build/$OUTPUT_NAME"
mkdir -p "$FRONTEND_DIR/build"
cp "$APK_PATH" "$OUTPUT_PATH"

# 获取文件大小
FILE_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')

# 完成
echo ""
echo "=========================================="
echo -e "${GREEN}✓ 构建完成！${NC}"
echo "=========================================="
echo ""
echo "输出文件: $OUTPUT_NAME"
echo "文件大小: $FILE_SIZE"
echo "文件位置: $OUTPUT_PATH"
echo ""
echo "安装方法:"
echo "  1. 通过 USB: adb install $APK_PATH"
echo "  2. 无线: 将 $OUTPUT_PATH 传输到手机并安装"
echo ""
echo "如需签名配置，请参考 android/BUILD.md"
echo ""
