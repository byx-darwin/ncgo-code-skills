#!/usr/bin/env bash
# check-status.sh — 检查 ncgo-code 技能集合的安装完整性
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

echo "ncgo-code 状态报告"
echo "──────────────────"

# 1. 安装概览
echo ""
echo "📍 开发仓库: ${REPO_ROOT}"
echo "📍 安装位置: ${SKILLS_DIR}/ (每个 skill 单独符号链接)"

# 2. Skills 完整性（含符号链接检查）
echo ""
echo "Skills:"
EXPECTED_SKILLS=(
    "auto-report-bug"
    "brainstorm-from-issue"
    "check-status"
    "issue-status"
    "sync-readme"
    "weekly-report"
    "writing-plans-with-issue"
)
SKILL_OK=0
SKILL_TOTAL=${#EXPECTED_SKILLS[@]}

for skill in "${EXPECTED_SKILLS[@]}"; do
    LINK_PATH="${SKILLS_DIR}/${skill}"
    if [ -L "${LINK_PATH}" ] && [ -f "${LINK_PATH}/SKILL.md" ]; then
        # 验证符号链接指向当前仓库
        RESOLVED="$(cd "${LINK_PATH}" && pwd -P 2>/dev/null || echo "")"
        if [ "${RESOLVED}" = "${REPO_ROOT}/${skill}" ]; then
            echo "  ✅ ${skill} (符号链接 → 开发仓库)"
        else
            echo "  ⚠️  ${skill} (符号链接指向其他位置: ${RESOLVED})"
        fi
        SKILL_OK=$((SKILL_OK + 1))
    elif [ -f "${LINK_PATH}/SKILL.md" ]; then
        echo "  ⚠️  ${skill} (已安装但非符号链接)"
        SKILL_OK=$((SKILL_OK + 1))
    elif [ -d "${LINK_PATH}" ]; then
        echo "  ❌ ${skill} (目录存在但缺少 SKILL.md)"
    else
        echo "  ❌ ${skill} (未安装)"
    fi
done
echo "  (${SKILL_OK}/${SKILL_TOTAL})"

# 3. Hooks 注册状态
echo ""
echo "Hooks:"
SETTINGS_FILE=".claude/settings.json"
EXPECTED_HOOKS=(
    "auto-report-bug.sh"
    "auto-smoke-test.sh"
    "sync-readme-check.sh"
)
HOOK_OK=0
HOOK_TOTAL=${#EXPECTED_HOOKS[@]}

for hook in "${EXPECTED_HOOKS[@]}"; do
    if [ ! -f "hooks/$hook" ]; then
        echo "  ❌ $hook (脚本文件不存在)"
    elif [ -f "$SETTINGS_FILE" ] && grep -q "$hook" "$SETTINGS_FILE"; then
        echo "  ✅ $hook"
        HOOK_OK=$((HOOK_OK + 1))
    else
        echo "  ❌ $hook (未在 settings.json 中注册)"
    fi
done
echo "  ($HOOK_OK/$HOOK_TOTAL)"

# 4. 文档同步状态（轻量检查：比较目录数量）
echo ""
echo "文档同步:"
ACTUAL_COUNT=$(find . -maxdepth 1 -type d ! -name '.' ! -name '.*' ! -name 'docs' | wc -l | tr -d ' ')

# 从 README.md 提取目录树中的条目数
README_COUNT=$({ grep -E '^├── [a-z].*/$|^└── [a-z].*/$' README.md 2>/dev/null || true; } | wc -l | tr -d ' ')

# 从 CLAUDE.md 提取目录树中的条目数
CLAUDE_COUNT=$({ grep -E '^├── [a-z].*/$|^└── [a-z].*/$' CLAUDE.md 2>/dev/null || true; } | wc -l | tr -d ' ')

if [ "$ACTUAL_COUNT" -eq "$README_COUNT" ] && [ "$ACTUAL_COUNT" -eq "$CLAUDE_COUNT" ]; then
    echo "  ✅ 一致 ($ACTUAL_COUNT 个目录)"
else
    echo "  ⚠️  可能不一致（实际 ${ACTUAL_COUNT} / README ${README_COUNT} / CLAUDE.md ${CLAUDE_COUNT}）"
    echo "     建议运行 /sync-readme"
fi
