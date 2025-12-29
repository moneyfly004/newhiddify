#!/bin/bash

# 修复构建错误的脚本

cd /Users/apple/Downloads/hiddify-app-main

echo "1. 清理项目..."
flutter clean

echo "2. 获取依赖..."
flutter pub get

echo "3. 运行代码生成..."
flutter pub run build_runner build --delete-conflicting-outputs

echo "4. 分析代码..."
flutter analyze

echo "5. 构建 Android APK (Debug)..."
flutter build apk --debug

echo "构建完成！"

