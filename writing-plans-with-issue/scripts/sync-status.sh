#!/bin/bash
# writing-plans-with-issue: sync-status.sh
# 更新 GitHub Issue 的状态标签
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# ── 参数解析 ──

ISSUE_NUM="${1:-}"
STATUS="${2:-}"

if [ -z "$STATUS" ]; then
  if [[ "$ISSUE_NUM" =~ ^(in-progress|in-review|done)$ ]]; then
    STATUS="$ISSUE_NUM"
    ISSUE_NUM=""
  fi
fi

if [ -z "$STATUS" ]; then
  log_error "Usage: sync-status.sh [issue-number] <status>"
  echo "  Status: in-progress, in-review, done"
  exit 1
fi

case "$STATUS" in
  in-progress|in-review|done) ;;
  *)
    log_error "Invalid status: $STATUS"
    echo "Valid statuses: in-progress, in-review, done"
    exit 1
    ;;
esac

# ── 读取 Issue 编号 ──

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM=$(read_issue_num)
fi

# ── 主流程 ──

main() {
  cd_to_git_root
  check_dependencies

  TARGET_LABEL="status: $STATUS"
  log_info "Updating Issue #$ISSUE_NUM status to: $STATUS"

  # 确保目标状态标签存在
  ensure_status_label "$TARGET_LABEL" || true

  # 先加后删（原子性更好：即使后续失败，新状态标签已就位）
  log_info "Adding status label: $TARGET_LABEL"
  gh issue edit "$ISSUE_NUM" --add-label "$TARGET_LABEL" || {
    log_error "Failed to add status label."
    echo "Run manually: gh issue edit $ISSUE_NUM --add-label '$TARGET_LABEL'"
    exit 1
  }

  # 移除其他所有旧状态标签
  log_info "Removing old status labels..."
  for old in "status: plan" "status: in-progress" "status: in-review" "status: done"; do
    if [ "$old" != "$TARGET_LABEL" ]; then
      gh issue edit "$ISSUE_NUM" --remove-label "$old" 2>/dev/null || true
    fi
  done

  log_info "Issue #$ISSUE_NUM status updated to: $STATUS"

  # done 时清理 current-issue.txt
  if [ "$STATUS" = "done" ]; then
    rm -f .claude/gh-issue/current-issue.txt
    log_info "Cleared current Issue (status: done)"
  fi
}

main "$@"
