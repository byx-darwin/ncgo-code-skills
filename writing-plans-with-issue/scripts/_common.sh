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
BLUE='\033[0;34m'
NC='\033[0m'

# ── 日志 ──

log_info()   { printf "${GREEN}✅%s${NC}\n" " $1"; }
log_warn()   { printf "${YELLOW}⚠️%s${NC}\n" " $1"; }
log_error()  { printf "${RED}❌%s${NC}\n" " $1"; }
log_header() { printf "${BLUE}%s${NC}\n" "$1"; }

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

# ── 认证缓存（用户级，24h TTL） ──

AUTH_CACHE_DIR="$HOME/.claude/ncgo-code-skills"
AUTH_CACHE_FILE="$AUTH_CACHE_DIR/auth-cache.json"
AUTH_CACHE_TTL=86400  # 24 小时

# 检查认证缓存是否有效
auth_cache_valid() {
  local platform="$1"
  [ -f "$AUTH_CACHE_FILE" ] || return 1

  local cached_time
  cached_time=$(jq -r ".${platform}.verified_at // empty" "$AUTH_CACHE_FILE" 2>/dev/null)
  [ -n "$cached_time" ] || return 1

  # 解析时间戳为 epoch（兼容 macOS/Linux）
  local cached_epoch
  if date -d "$cached_time" +%s &>/dev/null; then
    cached_epoch=$(date -d "$cached_time" +%s)
  elif date -jf "%Y-%m-%dT%H:%M:%SZ" "$cached_time" +%s &>/dev/null; then
    cached_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$cached_time" +%s)
  else
    return 1
  fi

  local now_epoch
  now_epoch=$(date +%s)
  local age=$(( now_epoch - cached_epoch ))

  [ "$age" -lt "$AUTH_CACHE_TTL" ]
}

# 写入认证缓存
auth_cache_write() {
  local platform="$1"
  local extra_json="${2:-}"  # 额外字段，如 "\"account\": \"byx-darwin\""

  mkdir -p "$AUTH_CACHE_DIR"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # 读取现有缓存或初始化
  local cache="{}"
  [ -f "$AUTH_CACHE_FILE" ] && cache=$(cat "$AUTH_CACHE_FILE" 2>/dev/null || echo "{}")

  # 构建平台条目
  local entry="{\"verified_at\": \"$timestamp\""
  [ -n "$extra_json" ] && entry="$entry, $extra_json"
  entry="$entry}"

  # 更新缓存
  cache=$(echo "$cache" | jq ".${platform} = $entry" 2>/dev/null || echo "{\"$platform\": $entry}")
  echo "$cache" > "$AUTH_CACHE_FILE"
}

# 失效认证缓存
auth_cache_invalidate() {
  local platform="$1"
  [ -f "$AUTH_CACHE_FILE" ] || return 0
  local cache
  cache=$(jq "del(.${platform})" "$AUTH_CACHE_FILE" 2>/dev/null || echo "{}")
  echo "$cache" > "$AUTH_CACHE_FILE"
}

# ── 错误报告（auto-report-bug 捕获层） ──

report_error() {
  local script_path="$1"
  local line_number="$2"
  local exit_code="$3"

  # 收集上下文
  local skill_name
  skill_name=$(basename "$(dirname "$(dirname "$script_path")")")
  local script_name
  script_name=$(basename "$script_path")
  local provider
  provider=$(provider_name 2>/dev/null || echo "unknown")
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # 生成错误 ID（基于脚本路径 + 行号的 hash）
  local error_id
  if command -v md5sum &>/dev/null; then
    error_id=$(echo "${script_path}:${line_number}" | md5sum | cut -c1-8)
  elif command -v md5 &>/dev/null; then
    error_id=$(echo "${script_path}:${line_number}" | md5 | cut -c1-8)
  else
    error_id=$(echo "${script_path}:${line_number}" | cksum | cut -c1-8)
  fi

  # 读取 stderr（从脚本设置的 STDERR_FILE 变量）
  local stderr_content=""
  if [ -n "${STDERR_FILE:-}" ] && [ -f "${STDERR_FILE:-}" ]; then
    stderr_content=$(head -c 2000 "$STDERR_FILE" 2>/dev/null || echo "")
  fi

  # 写入缓冲文件
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  [ -z "$repo_root" ] && return 0
  local cache_dir="$repo_root/.cache/bug-reports"
  mkdir -p "$cache_dir"

  cat > "$cache_dir/pending.json" <<EOF
{
  "id": "$error_id",
  "skill": "$skill_name",
  "script": "$script_name",
  "line": $line_number,
  "command": $(echo "$BASH_COMMAND" | jq -Rs . 2>/dev/null || echo "\"\""),
  "exit_code": $exit_code,
  "stderr": $(echo "$stderr_content" | jq -Rs . 2>/dev/null || echo "\"\""),
  "provider": "$provider",
  "timestamp": "$timestamp"
}
EOF
}
