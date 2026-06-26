#!/bin/bash
# writing-plans-with-issue: finish-issue.sh
# 本地合并后的收尾：push base 分支、关闭 Issue、清理 local state
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 参数解析 ──

ISSUE_NUM="${1:-}"
COMMENT="${2:-}"

# ── 读取 current-issue.txt ──

if [ -z "$ISSUE_NUM" ]; then
  if [ -f .claude/gh-issue/current-issue.txt ]; then
    ISSUE_NUM=$(cat .claude/gh-issue/current-issue.txt)
    log_info "Using current Issue: #$ISSUE_NUM"
  else
    log_error "No Issue number provided and .claude/gh-issue/current-issue.txt not found."
    echo "Usage: finish-issue.sh [issue-number] [comment]"
    exit 1
  fi
fi

# ── 依赖检查 ──

if ! command -v gh &> /dev/null; then
  log_error "GitHub CLI (gh) is required."
  echo "Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  log_error "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
fi

# ── 检测 base 分支 ──

detect_base_branch() {
  local remote_head
  remote_head=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||')
  if [ -n "$remote_head" ]; then
    echo "$remote_head"
    return
  fi
  if git show-ref --verify --quiet refs/heads/main; then
    echo "main"
  elif git show-ref --verify --quiet refs/heads/master; then
    echo "master"
  else
    echo "main"
  fi
}

BASE_BRANCH=$(detect_base_branch)
CURRENT_BRANCH=$(git branch --show-current)

# ── 确认在 base 分支上 ──

if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
  log_warn "Not on $BASE_BRANCH (current: $CURRENT_BRANCH)."
  echo "This script should be run AFTER merging into $BASE_BRANCH."
  echo "Run: git checkout $BASE_BRANCH && git merge <feature-branch>"
  exit 1
fi

# ── Step 1: Push base 分支 ──

log_info "Pushing $BASE_BRANCH to origin..."
set +e
PUSH_OUTPUT=$(git push origin "$BASE_BRANCH" 2>&1)
PUSH_EXIT=$?
set -e

if [ $PUSH_EXIT -ne 0 ]; then
  if echo "$PUSH_OUTPUT" | grep -q "Everything up-to-date"; then
    log_info "$BASE_BRANCH already up-to-date on remote."
  else
    log_error "Push failed: $PUSH_OUTPUT"
    exit 1
  fi
else
  log_info "Pushed $BASE_BRANCH to origin."
fi

# ── Step 2: 关闭 Issue ──

log_info "Closing Issue #$ISSUE_NUM..."

if [ -n "$COMMENT" ]; then
  gh issue close "$ISSUE_NUM" --comment "$COMMENT" 2>&1 || {
    log_error "Failed to close Issue #$ISSUE_NUM"
    exit 1
  }
else
  # 默认评论：列出 base 分支上的提交
  MERGE_COMMITS=$(git log --oneline -20 "$BASE_BRANCH" 2>/dev/null | head -10)
  DEFAULT_COMMENT="已完成并合并到 ${BASE_BRANCH}。

最近的提交:
${MERGE_COMMITS}"

  gh issue close "$ISSUE_NUM" --comment "$DEFAULT_COMMENT" 2>&1 || {
    log_error "Failed to close Issue #$ISSUE_NUM"
    exit 1
  }
fi

log_info "Issue #$ISSUE_NUM closed."

# ── Step 3: 清理 local state ──

if [ -f .claude/gh-issue/current-issue.txt ]; then
  rm -f .claude/gh-issue/current-issue.txt
  log_info "Cleaned up .claude/gh-issue/current-issue.txt"
fi

# ── 完成 ──

echo ""
log_info "Done!"
echo "  Issue #$ISSUE_NUM closed"
echo "  $BASE_BRANCH pushed to origin"
echo "  Local state cleaned up"
