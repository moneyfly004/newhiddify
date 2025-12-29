#!/bin/bash

cd /Users/apple/Downloads/hiddify-app-main

echo "==========================================="
echo "开始构建 APK (Debug)"
echo "==========================================="
echo ""

echo "1. 清理项目..."
flutter clean

echo ""
echo "2. 获取依赖..."
flutter pub get

echo ""
echo "3. 运行代码生成..."
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "4. 分析代码..."
flutter analyze --no-fatal-infos 2>&1 | grep -E "error •" | head -10

echo ""
echo "5. 开始构建 APK..."
flutter build apk --debug

echo ""
echo "==========================================="
echo "构建完成！"
echo "==========================================="

if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo "✓ APK 构建成功！"
    ls -lh build/app/outputs/flutter-apk/app-debug.apk
else
    echo "✗ APK 构建失败，请检查错误信息"
fi

