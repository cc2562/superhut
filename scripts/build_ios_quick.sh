#!/bin/bash

# SuperHUT iOS 快速构建脚本（简化版）

set -e

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 开始快速构建 SuperHUT iOS 应用..."

cd "$PROJECT_ROOT"

# 获取版本号
VERSION=$(grep "version:" pubspec.yaml | awk '{print $2}' | tr -d '\r')

# 清理并构建
echo "📦 清理项目..."
flutter clean > /dev/null

echo "📥 获取依赖..."
flutter pub get > /dev/null

echo "⬇️  下载 iOS 引擎..."
flutter precache --ios > /dev/null

echo "🍺 安装 CocoaPods..."
cd ios && pod install > /dev/null && cd ..

echo "🔨 构建 iOS 应用..."
flutter build ios --no-codesign --release > /dev/null

echo "📱 创建 IPA 包..."
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/

# 创建输出目录
mkdir -p releases

# 生成文件名
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
IPA_NAME="superhut-v${VERSION}-unsigned-${TIMESTAMP}.ipa"

cd build/ios/ipa
zip -r "../../../releases/${IPA_NAME}" Payload > /dev/null

echo "✅ 构建完成！"
echo "📦 文件位置: releases/${IPA_NAME}"
echo "📏 文件大小: $(ls -lh "../../../releases/${IPA_NAME}" | awk '{print $5}')"
