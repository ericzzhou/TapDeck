#!/bin/bash
# TapDeck .app 打包脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_NAME="TapDeck"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== 运行测试 ==="
swift test --quiet

echo "=== 构建 Release ==="
swift build -c release --product TapDeck

echo "=== 创建 .app bundle ==="
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 主二进制
cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "=== Ad-hoc 签名 ==="
codesign --force --sign - "$APP_BUNDLE"

echo "=== 验证 ==="
codesign --verify "$APP_BUNDLE" && echo "签名验证通过"
test -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" && echo "主二进制: OK"
test -f "$APP_BUNDLE/Contents/Info.plist" && echo "Info.plist: OK"

echo ""
echo "=== 打包完成 ==="
echo "应用位置: $APP_BUNDLE"
echo ""
echo "安装: cp -r $APP_BUNDLE /Applications/"
echo "运行: open $APP_BUNDLE"
echo ""
echo "首次运行需要在 系统设置 → 隐私与安全 → 输入监控 中授权 TapDeck。"
