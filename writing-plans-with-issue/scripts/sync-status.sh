#!/bin/bash
# writing-plans-with-issue: sync-status.sh
# 更新 GitHub Issue 的状态标签
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

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
}

# 解析参数
ISSUE_NUM="${1:-}"
STATUS="${2:-}"

# 如果只提供了一个参数，判断是 Issue 编号还是状态
if [ -z "$STATUS" ]; then
  if [[ "$ISSUE_NUM" =~ ^(in-progress|in-review|done)$ ]]; then
    # 传的是状态，从文件读 Issue 编号
    STATUS="$ISSUE_NUM"
    if [ -f .claude/gh-issue/current-issue.txt ]; then
      ISSUE_NUM=$(cat .claude/gh-issue/current-issue.txt)
      log_info "Using current Issue: #$ISSUE_NUM"
    else
      log_error "No Issue number found. Provide issue number: sync-status.sh <number> <status>"
      exit 1
    fi
  else
    log_error "Usage: sync-status.sh [issue-number] <status>"
    echo "  Status: in-progress, in-review, done"
    exit 1
  fi
fi

# 如果没有 Issue 编号，从文件读取
if [ -z "$ISSUE_NUM" ]; then
  if [ -f .claude/gh-issue/current-issue.txt ]; then
    ISSUE_NUM=$(cat .claude/gh-issue/current-issue.txt)
    log_info "Using current Issue: #$ISSUE_NUM"
  else
    log_error "No Issue number found. Create one first with create-issue.sh"
    exit 1
  fi
fi

# 验证状态值
case "$STATUS" in
  in-progress|in-review|done) ;;
  *)
    log_error "Invalid status: $STATUS"
    echo "Valid statuses: in-progress, in-review, done"
    exit 1
    ;;
esac

main() {
  log_info "Updating Issue #$ISSUE_NUM status to: $STATUS"

  check_dependencies

  # 确保目标状态标签存在
  TARGET_LABEL="status: $STATUS"
  if ! gh label list --json name -q '.[].name' 2>/dev/null | grep -qxF "$TARGET_LABEL"; then
    log_info "Creating label: $TARGET_LABEL"
    gh label create "$TARGET_LABEL" 2>/dev/null || {
      log_warn "Failed to create label '$TARGET_LABEL'"
    }
  fi

  # 移除所有旧状态标签
  log_info "Removing existing status labels..."
  gh issue edit "$ISSUE_NUM" \
    --remove-label "status: plan" \
    --remove-label "status: in-progress" \
    --remove-label "status: in-review" \
    --remove-label "status: done" \
    2>/dev/null || log_warn "No existing status labels to remove"

  # 添加新状态标签
  log_info "Adding status label: $TARGET_LABEL"
  if gh issue edit "$ISSUE_NUM" --add-label "$TARGET_LABEL" 2>&1; then
    log_info "Issue #$ISSUE_NUM status updated to: $STATUS"
  else
    log_error "Failed to update Issue status."
    echo "Run manually: gh issue edit $ISSUE_NUM --add-label 'status: $STATUS'"
    exit 1
  fi

  # done 时清理 current-issue.txt
  if [ "$STATUS" = "done" ]; then
    rm -f .claude/gh-issue/current-issue.txt
    log_info "Cleared current Issue (status: done)"
  fi
}

main "$@"
