#!/bin/bash
# TapDeck 构建 + 安装脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
INSTALL_DIR="$HOME/.local/bin"

echo "=== 运行测试 ==="
swift test --quiet

echo "=== 构建 Release ==="
swift build -c release --product TapDeck
swift build -c release --product AccelReader

echo "=== 安装到 $INSTALL_DIR ==="
mkdir -p "$INSTALL_DIR"
cp "$BUILD_DIR/release/TapDeck" "$INSTALL_DIR/TapDeck"
cp "$BUILD_DIR/release/AccelReader" "$INSTALL_DIR/AccelReader"

echo ""
echo "=== 构建完成 ==="
echo "运行: $INSTALL_DIR/TapDeck"
echo ""
echo "注意: AccelReader 需要 root 权限访问加速度计。"
echo "应用启动时会弹出系统密码框请求权限提升。"
