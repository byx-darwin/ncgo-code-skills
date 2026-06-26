#!/bin/bash
# writing-plans-with-issue: list-issues.sh
# 按状态分组列出 GitHub Issue（辅助工具，非 skill）
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}✅${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }
log_header() { echo -e "${BLUE}$1${NC}"; }

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
    echo "Run: gh auth login"
    exit 1
  fi
}

main() {
  check_dependencies

  echo ""
  log_header "=== Plan（待开始） ==="
  gh issue list --label "status: plan" --state open \
    --json number,title,labels --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
  log_header "=== In Progress（开发中） ==="
  gh issue list --label "status: in-progress" --state open \
    --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
  log_header "=== In Review（审查中） ==="
  gh issue list --label "status: in-review" --state open \
    --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
  log_header "=== 当前活跃 Issue ==="
  if [ -f .claude/gh-issue/current-issue.txt ]; then
    ISSUE_NUM=$(cat .claude/gh-issue/current-issue.txt)
    gh issue view "$ISSUE_NUM" --json number,title,state,url \
      --jq '"#\(.number) \(.title) [\(.state)] \(.url)"' 2>/dev/null \
      || echo "  Issue #$ISSUE_NUM (无法获取详情)"
  else
    echo "  未设置（运行 writing-plans-with-issue 创建新计划）"
  fi

  echo ""
  log_header "=== 最近关闭（5 条） ==="
  gh issue list --state closed --limit 5 \
    --json number,title,closedAt --jq '.[] | "#\(.number) \(.title) (closed: \(.closedAt))"' 2>/dev/null \
    || echo "  (无)"

  echo ""
}

main "$@"
