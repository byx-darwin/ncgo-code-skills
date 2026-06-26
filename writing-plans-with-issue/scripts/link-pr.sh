#!/bin/bash
# writing-plans-with-issue: link-pr.sh
# 创建 Pull Request 并关联 Issue（Closes #N）
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

# 本脚本所在目录（用于调用同级脚本）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 自动检测仓库默认分支（兼容 main/master）
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

# ── 平台检测与安装指令 ──

detect_os() {
  case "$(uname -s)" in
    Darwin)  echo "macOS" ;;
    Linux)   echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}

gh_install_instructions() {
  local os
  os=$(detect_os)
  echo "GitHub CLI (gh) is required but not installed."
  echo ""
  case "$os" in
    macOS)
      echo "  brew install gh"
      ;;
    linux)
      echo "  Debian/Ubuntu: sudo apt install gh"
      echo "  Fedora/RHEL:   sudo dnf install gh"
      echo "  Arch:          sudo pacman -S github-cli"
      ;;
    windows)
      echo "  winget install GitHub.cli"
      echo "  或: choco install gh"
      ;;
    *)
      echo "  下载: https://cli.github.com/"
      ;;
  esac
  echo ""
  echo "安装后运行: gh auth login"
}

check_dependencies() {
  if ! command -v gh &> /dev/null; then
    gh_install_instructions
    exit 1
  fi

  if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI is not authenticated."
    echo ""
    echo "Run: gh auth login"
    echo "  - 选择 GitHub.com"
    echo "  - 选择 HTTPS"
    echo "  - 使用浏览器登录或粘贴 token"
    exit 1
  fi

  if ! command -v git &> /dev/null; then
    log_error "Git is required but not installed."
    echo "Download: https://git-scm.com/"
    exit 1
  fi
}

ISSUE_NUM="${1:-}"

if [ -z "$ISSUE_NUM" ]; then
  if [ -f .claude/gh-issue/current-issue.txt ]; then
    ISSUE_NUM=$(cat .claude/gh-issue/current-issue.txt)
    log_info "Using current Issue: #$ISSUE_NUM"
  else
    log_error "No Issue number provided and .claude/gh-issue/current-issue.txt not found."
    echo "Usage: link-pr.sh [issue-number]"
    exit 1
  fi
fi

BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
  log_error "Not on a git branch."
  exit 1
fi

BASE_BRANCH=$(detect_base_branch)
log_info "Current branch: $BRANCH (base: $BASE_BRANCH)"

# 检查是否有提交
if git rev-parse HEAD >/dev/null 2>&1; then
  COMMIT_COUNT=$(git rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo "0")
  if [ "$COMMIT_COUNT" -eq 0 ]; then
    log_warn "No commits found on this branch compared to $BASE_BRANCH."
    echo "Make sure you have committed your changes."
    exit 1
  fi
  log_info "Found $COMMIT_COUNT commit(s) on this branch"
else
  log_error "Not in a git repository or no commits found."
  exit 1
fi

build_pr_title() {
  local first_commit
  first_commit=$(git log --reverse "${BASE_BRANCH}..HEAD" --format="%s" 2>/dev/null | head -1)

  if echo "$first_commit" | grep -qE "^(feat|fix|refactor|docs|test|chore)"; then
    echo "$first_commit"
  else
    # fallback: 用分支名
    echo "feat: $BRANCH" | sed 's/[_-]/ /g'
  fi
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

main() {
  log_info "Creating PR and linking to Issue #$ISSUE_NUM..."

  check_dependencies

  PR_TITLE=$(build_pr_title)
  PR_BODY=$(build_pr_body)

  log_info "PR title: $PR_TITLE"

  # 推送分支到远程
  log_info "Pushing branch to remote..."
  set +e
  PUSH_OUTPUT=$(git push -u origin "$BRANCH" 2>&1)
  PUSH_EXIT=$?
  set -e
  if [ $PUSH_EXIT -ne 0 ]; then
    if echo "$PUSH_OUTPUT" | grep -q "Everything up-to-date"; then
      log_info "Branch already up-to-date on remote."
    else
      log_warn "Push may have failed: $PUSH_OUTPUT"
    fi
  fi

  # 检查是否已有 PR
  EXISTING_PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")

  if [ -n "$EXISTING_PR" ]; then
    log_warn "PR #$EXISTING_PR already exists for this branch."
    echo "Updating PR body to link Issue #$ISSUE_NUM..."

    gh pr edit "$EXISTING_PR" --body "$PR_BODY"

    PR_URL="https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/pull/$EXISTING_PR"
    log_info "PR updated: $PR_URL"
  else
    log_info "Creating new PR..."

    TEMP_FILE=$(mktemp)
    trap 'rm -f "$TEMP_FILE"' EXIT
    echo "$PR_BODY" > "$TEMP_FILE"

    set +e
    PR_URL=$(gh pr create \
      --title "$PR_TITLE" \
      --body-file "$TEMP_FILE" \
      --base "$BASE_BRANCH" \
      2>&1)
    PR_EXIT=$?
    set -e

    if [ $PR_EXIT -ne 0 ]; then
      log_error "Failed to create PR."
      echo "$PR_URL"
      exit 1
    fi

    log_info "PR created: $PR_URL"
  fi

  # 更新 Issue 状态（调用同级目录的 sync-status.sh）
  log_info "Updating Issue #$ISSUE_NUM status to in-review..."
  if [ -x "$SCRIPT_DIR/sync-status.sh" ]; then
    bash "$SCRIPT_DIR/sync-status.sh" "$ISSUE_NUM" "in-review" 2>/dev/null || {
      log_warn "Failed to update Issue status. Run manually:"
      echo "  bash $SCRIPT_DIR/sync-status.sh $ISSUE_NUM in-review"
    }
  else
    log_warn "sync-status.sh not found. Update status manually:"
    echo "  gh issue edit $ISSUE_NUM --add-label 'status: in-review'"
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
