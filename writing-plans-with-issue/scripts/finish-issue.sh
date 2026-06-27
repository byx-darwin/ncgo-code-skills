#!/bin/bash
# writing-plans-with-issue: finish-issue.sh
# 本地合并后的收尾：同步验收 checkbox、push base 分支、关闭 Issue、清理 local state
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# ── 参数解析 ──

ISSUE_NUM="${1:-}"
COMMENT="${2:-}"

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM=$(read_issue_num)
fi

# ── 主流程 ──

main() {
  cd_to_git_root
  check_dependencies

  BASE_BRANCH=$(detect_base_branch)
  CURRENT_BRANCH=$(git branch --show-current)

  # ── Step 0: 确认在 base 分支上 ──

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

  # ── Step 2: 同步验收标准 checkbox ──

  log_info "Syncing acceptance criteria checkboxes..."

  ISSUE_BODY=$(provider_get_issue_body "$ISSUE_NUM") || {
    log_error "Failed to fetch Issue #$ISSUE_NUM body. Check Issue number and auth."
    exit 1
  }

  if [ -z "$ISSUE_BODY" ]; then
    log_error "Issue #$ISSUE_NUM body is empty — refusing to proceed."
    exit 1
  fi

  # 将 "## 验收标准" 到下一个 "##" 之前的 - [ ] 替换为 - [x]
  UPDATED_BODY=$(printf '%s' "$ISSUE_BODY" | awk '
    /^## 验收标准/ { in_section=1; print; next }
    in_section && /^## / { in_section=0 }
    in_section && /^- \[ \]/ { sub(/- \[ \]/, "- [x]") }
    { print }
  ')

  if [ "$ISSUE_BODY" != "$UPDATED_BODY" -a -n "$UPDATED_BODY" ]; then
    TEMP_BODY=$(mktemp)
    trap 'rm -f "$TEMP_BODY"' EXIT
    printf '%s' "$UPDATED_BODY" > "$TEMP_BODY"
    provider_update_issue_body "$ISSUE_NUM" "$TEMP_BODY"
    log_info "Acceptance criteria checkboxes synced."
  else
    log_info "Acceptance criteria already checked (or no changes needed)."
  fi

  # ── Step 3: 关闭 Issue ──

  ISSUE_STATE=$(provider_get_issue_state "$ISSUE_NUM" 2>/dev/null || echo "UNKNOWN")

  if [ "$ISSUE_STATE" = "closed" ]; then
    log_info "Issue #$ISSUE_NUM is already closed."
  else
    log_info "Closing Issue #$ISSUE_NUM..."

    if [ -n "$COMMENT" ]; then
      provider_close_issue "$ISSUE_NUM" "$COMMENT" || {
        log_error "Failed to close Issue #$ISSUE_NUM"
        exit 1
      }
    else
      # 默认评论：列出与 Issue 相关的 merge 提交
      RELATED_COMMITS=$(git log --oneline --merges -5 "$BASE_BRANCH" 2>/dev/null | head -3)
      DEFAULT_COMMENT="已完成并合并到 ${BASE_BRANCH}。

最近的合并提交:
${RELATED_COMMITS:-（无合并提交记录）}"

      provider_close_issue "$ISSUE_NUM" "$DEFAULT_COMMENT" || {
        log_error "Failed to close Issue #$ISSUE_NUM"
        exit 1
      }
    fi

    log_info "Issue #$ISSUE_NUM closed."
  fi

  # ── Step 4: 清理 local state ──

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
}

main "$@"
