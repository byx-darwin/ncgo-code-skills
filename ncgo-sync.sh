#!/bin/bash
# ncgo-sync - 同步 ncgo-code-skills 仓库的所有本地副本
# 用法: bash ncgo-sync.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}✅${NC} $1"; }
log_warn()  { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

REMOTE="git@github.com:byx-darwin/ncgo-code-skills.git"
BRANCH="main"

# 所有需要同步的本地 git 仓库副本
SYNC_DIRS=(
    "$HOME/.claude/skills/ncgo-code"
    "$HOME/Documents/workspace/github.com/byx-darwin/ncgo-code-skills"
)

echo ""
echo "============================================"
echo "  ncgo-code-skills 多目录同步工具"
echo "============================================"
echo ""

# ── Step 1: 检查网络 ──
echo ">>> 检查远端连通性..."
REMOTE_URL=$(git -C "${SYNC_DIRS[0]}" remote get-url origin 2>/dev/null || echo "$REMOTE")

if ! ssh -T -o StrictHostKeyChecking=no git@github.com 2>&1 | grep -q "successfully authenticated" ; then
    echo "(GitHub 远端连通，继续...)"
fi

# ── Step 2: 逐个目录更新 ──
UPDATED=0
SKIPPED=0

for dir in "${SYNC_DIRS[@]}"; do
    echo ""
    echo "── 📂 $dir ──"

    if [ ! -d "$dir/.git" ]; then
        log_warn "不是 git 仓库，跳过"
        ((SKIPPED++))
        continue
    fi

    cd "$dir"

    # 检查是否有未提交的修改
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        log_warn "有未提交的修改，跳过（请先 commit 或 stash）"
        git status --short
        ((SKIPPED++))
        continue
    fi

    # 确保在正确的分支
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
        log_warn "当前分支 $CURRENT_BRANCH ≠ $BRANCH，切换中..."
        git checkout "$BRANCH" 2>/dev/null || {
            log_error "无法切换到 $BRANCH"
            ((SKIPPED++))
            continue
        }
    fi

    # 拉取更新
    BEFORE=$(git rev-parse HEAD)
    git pull origin "$BRANCH" --rebase 2>&1 | tail -3
    AFTER=$(git rev-parse HEAD)

    if [ "$BEFORE" != "$AFTER" ]; then
        log_info "已更新: ${BEFORE:0:7} → ${AFTER:0:7}"
        ((UPDATED++))
    else
        log_info "已是最新"
        ((UPDATED++))
    fi
done

# ── Step 3: 报告 ──
echo ""
echo "============================================"
echo "  同步完成: $UPDATED 个目录已是最新, $SKIPPED 个跳过"
echo "============================================"
echo ""
