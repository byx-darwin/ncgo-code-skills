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
  if ! command -v gh &> /dev/null && ! command -v glab &> /dev/null; then
    if [ "${PLATFORM:-github}" = "gitee" ]; then
      echo "❌ Gitee backend requires curl + jq + GITEE_TOKEN."
      echo "   Set GITEE_TOKEN and ensure curl/jq are installed."
    else
      gh_install_instructions
    fi
    exit 1
  fi
  # Actual auth check is done by provider_check_prerequisites in _common.sh
}

main() {
  # list-issues.sh is standalone (doesn't source _common.sh), so we need provider
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "$SCRIPT_DIR/_provider.sh"
  check_dependencies

  echo ""
  log_header "=== Plan（待开始） ==="
  provider_list_issues "status: plan" "open" "20" 2>/dev/null | \
    jq -r '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
  log_header "=== In Progress（开发中） ==="
  provider_list_issues "status: in-progress" "open" "20" 2>/dev/null | \
    jq -r '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
  log_header "=== In Review（审查中） ==="
  provider_list_issues "status: in-review" "open" "20" 2>/dev/null | \
    jq -r '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
  log_header "=== 当前活跃 Issue ==="
  if [ -f .claude/gh-issue/current-issue.txt ]; then
    ISSUE_NUM=$(cat .claude/gh-issue/current-issue.txt)
    provider_get_issue_json "$ISSUE_NUM" 2>/dev/null | \
      jq -r '"#\(.number) \(.title) [\(.state)] \(.url)"' 2>/dev/null \
      || echo "  Issue #$ISSUE_NUM (无法获取详情)"
  else
    echo "  未设置（运行 writing-plans-with-issue 创建新计划）"
  fi

  echo ""
  log_header "=== 最近关闭（5 条） ==="
  provider_list_issues "" "closed" "5" 2>/dev/null | \
    jq -r '.[] | "#\(.number) \(.title)"' 2>/dev/null \
    || echo "  (无)"

  echo ""
}

main "$@"
