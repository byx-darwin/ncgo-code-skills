#!/bin/bash
# writing-plans-with-issue: shared functions
# Source by other scripts: source "$(dirname "$0")/_common.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_provider.sh"

# ── 颜色 ──

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── 日志 ──

log_info() { printf "${GREEN}✅%s${NC}\n" " $1"; }
log_warn() { printf "${YELLOW}⚠️%s${NC}\n" " $1"; }
log_error() { printf "${RED}❌%s${NC}\n" " $1"; }

# ── Git 根目录定位 ──

cd_to_git_root() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "Not in a git repository."
    exit 1
  fi
  GIT_ROOT="$(git rev-parse --show-toplevel)"
  cd "$GIT_ROOT"
}

# ── 依赖检查 ──

check_dependencies() {
  provider_check_prerequisites
}

# ── Base 分支检测 ──

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

# ── 从 current-issue.txt 或 plan 文件读取 Issue 编号 ──

read_issue_num() {
  local num
  if [ -f .claude/gh-issue/current-issue.txt ]; then
    num=$(tr -d '[:space:]' < .claude/gh-issue/current-issue.txt)
    if [[ "$num" =~ ^[0-9]+$ ]]; then
      echo "$num"
      return
    fi
  fi
  log_error "No valid Issue number found in .claude/gh-issue/current-issue.txt"
  echo "Run create-issue.sh first, or pass the issue number explicitly."
  exit 1
}

# ── 标签处理：只移除逗号周围空格（保留标签内部空格） ──

normalize_labels() {
  echo "$1" | sed 's/[[:space:]]*,[[:space:]]*/,/g; s/^[[:space:]]*//; s/[[:space:]]*$//'
}

# ── 确保状态标签存在（避免 label list 分页遗漏） ──

ensure_status_label() {
  local label="$1"
  provider_ensure_label "$label" || return 1
  return 0
}
