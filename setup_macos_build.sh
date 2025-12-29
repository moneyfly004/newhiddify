#!/bin/bash
# macOS 构建环境自动配置脚本

set -e

echo "=========================================="
echo "🚀 配置 macOS 构建环境"
echo "=========================================="
echo ""

# 1. 检查并安装 CocoaPods
if ! command -v pod &> /dev/null; then
    echo "📦 安装 CocoaPods..."
    if command -v brew &> /dev/null; then
        brew install cocoapods
    else
        echo "❌ 错误: 需要 Homebrew 或手动安装 CocoaPods"
        exit 1
    fi
else
    echo "✅ CocoaPods 已安装: $(pod --version)"
fi

# 2. 切换 Xcode 路径（需要密码）
echo ""
echo "🔧 配置 Xcode..."
if [ -d "/Applications/Xcode.app" ]; then
    echo "发现 Xcode.app，正在切换..."
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
    sudo xcodebuild -runFirstLaunch
    echo "✅ Xcode 配置完成"
else
    echo "❌ 错误: 未找到 Xcode.app"
    echo "请从 App Store 安装 Xcode"
    exit 1
fi

# 3. 设置环境变量
export LANG=en_US.UTF-8

# 4. 安装 CocoaPods 依赖
echo ""
echo "📦 安装 CocoaPods 依赖..."
cd macos
pod install
cd ..

# 5. 验证环境
echo ""
echo "🔍 验证构建环境..."
xcode-select -p
xcodebuild -version

echo ""
echo "✅ 环境配置完成！"
echo ""
echo "现在可以运行以下命令构建 macOS 应用："
echo "  flutter build macos"
echo ""
echo "或者打包为 DMG/PKG："
echo "  make macos-release"
echo ""

