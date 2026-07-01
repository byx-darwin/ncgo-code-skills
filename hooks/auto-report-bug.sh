#!/usr/bin/env bash
# auto-report-bug.sh — Stop Hook：检查是否有待报告的错误
# 检测到 pending.json 后输出内容，触发 Claude 介入处理。
# 设计原则：失败时静默退出，不影响正常流程。

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
[ -z "$REPO_ROOT" ] && exit 0

PENDING_FILE="$REPO_ROOT/.cache/bug-reports/pending.json"

# 检查 pending.json 是否存在
if [ ! -f "$PENDING_FILE" ]; then
  exit 0
fi

# 验证 JSON 格式（格式异常则清理，不阻塞）
if ! jq empty "$PENDING_FILE" 2>/dev/null; then
  echo "⚠️  pending.json 格式异常，已清理" >&2
  rm -f "$PENDING_FILE"
  exit 0
fi

# 检查 gh CLI 是否可用且已认证
if ! command -v gh &>/dev/null; then
  echo "⚠️  gh CLI 未安装，无法提交 Bug 报告" >&2
  exit 0
fi

# 使用认证缓存（用户级，24h TTL）
AUTH_CACHE_FILE="$HOME/.claude/ncgo-code-skills/auth-cache.json"
AUTH_CACHE_TTL=86400

_auth_cache_valid() {
  [ -f "$AUTH_CACHE_FILE" ] || return 1
  local cached_time
  cached_time=$(jq -r '.github.verified_at // empty' "$AUTH_CACHE_FILE" 2>/dev/null)
  [ -n "$cached_time" ] || return 1

  local cached_epoch now_epoch age
  if date -d "$cached_time" +%s &>/dev/null; then
    cached_epoch=$(date -d "$cached_time" +%s)
  elif date -jf "%Y-%m-%dT%H:%M:%SZ" "$cached_time" +%s &>/dev/null; then
    cached_epoch=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$cached_time" +%s)
  else
    return 1
  fi
  now_epoch=$(date +%s)
  age=$(( now_epoch - cached_epoch ))
  [ "$age" -lt "$AUTH_CACHE_TTL" ]
}

if ! _auth_cache_valid; then
  if ! gh auth status &>/dev/null; then
    echo "⚠️  gh 未认证，Bug 报告已保存但无法提交" >&2
    echo "   运行: gh auth login" >&2
    exit 0
  fi
  # 更新缓存
  mkdir -p "$(dirname "$AUTH_CACHE_FILE")"
  _cached_account=$(gh api user --jq .login 2>/dev/null || echo "unknown")
  _cached_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq ".github = {\"verified_at\": \"$_cached_ts\", \"account\": \"$_cached_account\"}" \
    "$AUTH_CACHE_FILE" 2>/dev/null > "${AUTH_CACHE_FILE}.tmp" && \
    mv "${AUTH_CACHE_FILE}.tmp" "$AUTH_CACHE_FILE" || true
fi

# 读取错误信息
SKILL=$(jq -r '.skill // "unknown"' "$PENDING_FILE")
SCRIPT=$(jq -r '.script // "unknown"' "$PENDING_FILE")
LINE=$(jq -r '.line // "?"' "$PENDING_FILE")
EXIT_CODE=$(jq -r '.exit_code // "?"' "$PENDING_FILE")
TIMESTAMP=$(jq -r '.timestamp // "unknown"' "$PENDING_FILE")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐛 检测到脚本错误，需要生成 Bug 报告"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  技能: $SKILL"
echo "  脚本: $SCRIPT:$LINE"
echo "  退出码: $EXIT_CODE"
echo "  时间: $TIMESTAMP"
echo ""
echo "  ⚡ 请使用 auto-report-bug 技能处理此错误"
echo "     （读取 pending.json → 去重 → 生成 Issue → 提交）"
echo ""
