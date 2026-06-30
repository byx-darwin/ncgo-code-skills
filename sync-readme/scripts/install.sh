#!/usr/bin/env bash
set -euo pipefail

# 切换到 git 仓库根目录
cd_to_git_root() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "❌ 不在 git 仓库中"
        exit 1
    }
    cd "$root"
}

cd_to_git_root
REPO_ROOT="$(pwd)"
INSTALL_DIR="$HOME/.claude/skills/ncgo-code"

echo "🔧 ncgo-code 符号链接安装"
echo "────────────────────────"
echo "开发仓库: $REPO_ROOT"
echo "安装位置: $INSTALL_DIR"
echo ""

# 检查当前状态
if [ -L "$INSTALL_DIR" ]; then
    CURRENT_TARGET="$(readlink "$INSTALL_DIR")"
    if [ "$CURRENT_TARGET" = "$REPO_ROOT" ]; then
        echo "✅ 已安装: $INSTALL_DIR → $REPO_ROOT"
        exit 0
    else
        echo "⚠️  符号链接指向错误位置: $CURRENT_TARGET"
        echo "   期望指向: $REPO_ROOT"
        rm "$INSTALL_DIR"
    fi
elif [ -d "$INSTALL_DIR" ]; then
    echo "📦 发现已有安装（普通目录），备份到 ${INSTALL_DIR}.bak"
    mv "$INSTALL_DIR" "${INSTALL_DIR}.bak"
fi

# 确保父目录存在
mkdir -p "$(dirname "$INSTALL_DIR")"

# 创建符号链接
ln -s "$REPO_ROOT" "$INSTALL_DIR"
echo "✅ 已链接: $INSTALL_DIR → $REPO_ROOT"

# 验证链接有效
if [ -f "$INSTALL_DIR/README.md" ]; then
    echo "✅ 链接验证通过"
else
    echo "❌ 链接验证失败: 无法读取 $INSTALL_DIR/README.md"
    exit 1
fi

if [ -d "${INSTALL_DIR}.bak" ]; then
    echo ""
    echo "📦 旧版本备份在: ${INSTALL_DIR}.bak"
    echo "   确认无误后可手动删除: rm -rf ${INSTALL_DIR}.bak"
fi
