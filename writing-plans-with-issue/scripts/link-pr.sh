#!/bin/bash
# writing-plans-with-issue: link-pr.sh
# 创建 Pull Request 并关联 Issue（Closes #N）
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# ── 参数解析 ──

ISSUE_NUM="${1:-}"

if [ -z "$ISSUE_NUM" ]; then
  ISSUE_NUM=$(read_issue_num)
fi

# ── 辅助函数 ──

build_pr_title() {
  local first_commit summary
  first_commit=$(git log --reverse "${BASE_BRANCH}..HEAD" --format="%s" 2>/dev/null | head -1)

  if echo "$first_commit" | grep -qE "^(feat|fix|refactor|docs|test|chore)"; then
    printf '%s\n' "$first_commit"
    return
  fi

  # fallback: 取分支名最后一段，只替换尾部连字符
  summary="${BRANCH##*/}"              # 去掉 feat/ 等前缀
  summary="${summary#[-_]}"            # 去首部连字符
  summary="${summary%[-_]}"            # 去尾部连字符
  summary="${summary//[-_]/ }"         # 中间连字符换空格
  printf 'feat: %s\n' "$summary"
}

build_pr_body() {
  cat <<EOF
Closes #$ISSUE_NUM

## Changes

$(git log --reverse "${BASE_BRANCH}..HEAD" --format="- %s" 2>/dev/null || echo "- Initial implementation")

## Checklist

- [ ] Code review approved
- [ ] Tests passing
- [ ] Documentation updated
- [ ] Issue #$ISSUE_NUM will be auto-closed on merge

---
_Auto-created by writing-plans-with-issue_
EOF
}

# ── 主流程 ──

main() {
  cd_to_git_root
  check_dependencies

  BRANCH=$(git branch --show-current)
  if [ -z "$BRANCH" ]; then
    log_error "Not on a git branch."
    exit 1
  fi

  BASE_BRANCH=$(detect_base_branch)
  log_info "Current branch: $BRANCH (base: $BASE_BRANCH)"

  # 检查是否有提交
  COMMIT_COUNT=$(git rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0")
  if [ "$COMMIT_COUNT" -eq 0 ]; then
    log_warn "No commits found on this branch compared to $BASE_BRANCH."
    echo "Make sure you have committed your changes."
    exit 1
  fi
  log_info "Found $COMMIT_COUNT commit(s) on this branch"

  log_info "Creating PR and linking to Issue #$ISSUE_NUM..."

  PR_TITLE=$(build_pr_title)
  PR_BODY=$(build_pr_body)
  log_info "PR title: $PR_TITLE"

  # 推送分支
  log_info "Pushing branch to remote..."
  set +e
  PUSH_OUTPUT=$(git push -u origin "$BRANCH" 2>&1)
  PUSH_EXIT=$?
  set -e
  if [ $PUSH_EXIT -ne 0 ]; then
    if echo "$PUSH_OUTPUT" | grep -q "Everything up-to-date"; then
      log_info "Branch already up-to-date on remote."
    else
      log_error "Push failed: $PUSH_OUTPUT"
      exit 1
    fi
  else
    log_info "Pushed $BRANCH to origin."
  fi

  # 检查是否已有 PR
  EXISTING_PR=$(provider_list_prs "$BRANCH" 2>/dev/null || echo "")

  if [ -n "$EXISTING_PR" ]; then
    PR_URL=$(provider_get_pr_url "$EXISTING_PR")
    log_warn "PR #$EXISTING_PR already exists for this branch."
    log_info "PR URL: $PR_URL"
    echo "To update the PR body with Issue link, run manually."
  else
    log_info "Creating new PR..."

    TEMP_BODY=$(mktemp)
    local errfile; errfile=$(mktemp)
    trap 'rm -f "$TEMP_BODY" "$errfile"' EXIT
    echo "$PR_BODY" > "$TEMP_BODY"

    set +e
    PR_URL=$(provider_create_pr "$PR_TITLE" "$TEMP_BODY" "$BASE_BRANCH" 2>"$errfile")
    PR_EXIT=$?
    set -e

    if [ $PR_EXIT -ne 0 ]; then
      log_error "Failed to create PR."
      cat "$errfile" >&2
      rm -f "$errfile"
      exit 1
    fi
    rm -f "$errfile"

    log_info "PR created: $PR_URL"
  fi

  # 更新 Issue 状态
  log_info "Updating Issue #$ISSUE_NUM status to in-review..."
  if [ -f "$SCRIPT_DIR/sync-status.sh" ]; then
    bash "$SCRIPT_DIR/sync-status.sh" "$ISSUE_NUM" "in-review" 2>/dev/null || {
      log_warn "Failed to update Issue status. Run manually:"
      echo "  bash $SCRIPT_DIR/sync-status.sh $ISSUE_NUM in-review"
    }
  fi

  echo ""
  log_info "PR created and linked to Issue!"
  echo "  PR: $PR_URL"
  echo "  Issue: #$ISSUE_NUM"
  echo "  Status: in-review"
  echo ""
  echo "When PR is merged, Issue #$ISSUE_NUM will be automatically closed."
}

main "$@"
