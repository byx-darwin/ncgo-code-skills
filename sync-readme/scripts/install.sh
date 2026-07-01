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
SKILLS_DIR="$HOME/.claude/skills"

# 扫描仓库中的 skill 目录（包含 SKILL.md 的顶级目录）
SKILLS=()
for dir in */; do
    [ -f "${dir}SKILL.md" ] && SKILLS+=("${dir%/}")
done

if [ ${#SKILLS[@]} -eq 0 ]; then
    echo "❌ 未在仓库中找到任何 skill（缺少 SKILL.md）"
    exit 1
fi

echo "🔧 ncgo-code 符号链接安装"
echo "────────────────────────"
echo "开发仓库: $REPO_ROOT"
echo "安装位置: $SKILLS_DIR/"
echo "Skills: ${SKILLS[*]}"
echo ""

# 确保安装目录存在
mkdir -p "$SKILLS_DIR"

# 1. 移除旧的 ncgo-code 父目录链接（如果存在）
LEGACY_LINK="$SKILLS_DIR/ncgo-code"
if [ -L "$LEGACY_LINK" ] || [ -d "$LEGACY_LINK" ]; then
    if [ -d "$LEGACY_LINK" ] && [ ! -L "$LEGACY_LINK" ]; then
        echo "📦 发现旧版安装（普通目录），备份到 ${LEGACY_LINK}.bak"
        mv "$LEGACY_LINK" "${LEGACY_LINK}.bak"
    else
        echo "🗑️  移除旧的 ncgo-code 链接"
        rm "$LEGACY_LINK"
    fi
fi

# 2. 为每个 skill 创建单独符号链接
INSTALLED=0
for skill in "${SKILLS[@]}"; do
    LINK_PATH="$SKILLS_DIR/$skill"

    if [ -L "$LINK_PATH" ]; then
        CURRENT_TARGET="$(readlink "$LINK_PATH")"
        EXPECTED_TARGET="$REPO_ROOT/$skill"
        # 检查链接是否可用（能读到 SKILL.md）
        if [ -f "$LINK_PATH/SKILL.md" ]; then
            # 链接有效 — 检查是否指向正确的仓库（用 pwd -P 解析真实路径）
            RESOLVED="$(cd "$LINK_PATH" && pwd -P 2>/dev/null || echo "")"
            if [ "${RESOLVED}" = "${REPO_ROOT}/${skill}" ]; then
                echo "  ✅ ${skill} (已安装)"
                INSTALLED=$((INSTALLED + 1))
                continue
            else
                echo "  ⚠️  ${skill} 链接指向其他仓库: ${RESOLVED}，重新创建"
                rm "$LINK_PATH"
            fi
        else
            echo "  ⚠️  ${skill} 链接已失效 (${CURRENT_TARGET})，重新创建"
            rm "$LINK_PATH"
        fi
    elif [ -d "$LINK_PATH" ]; then
        echo "  📦 $skill 已存在为普通目录，备份到 ${LINK_PATH}.bak"
        mv "$LINK_PATH" "${LINK_PATH}.bak"
    fi

    ln -s "$REPO_ROOT/$skill" "$LINK_PATH"
    echo "  ✅ $skill → $REPO_ROOT/$skill"
    INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "✅ 已安装 $INSTALLED 个 skills 到 $SKILLS_DIR/"
echo ""

# 3. 验证
FAILED=0
for skill in "${SKILLS[@]}"; do
    if [ ! -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
        echo "❌ 验证失败: $SKILLS_DIR/$skill/SKILL.md 不可读"
        FAILED=$((FAILED + 1))
    fi
done

if [ $FAILED -eq 0 ]; then
    echo "✅ 全部验证通过"
fi
