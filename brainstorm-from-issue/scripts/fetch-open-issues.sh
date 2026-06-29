#!/usr/bin/env bash
# brainstorm-from-issue: fetch-open-issues.sh
# 获取所有 open issues 并输出 JSON 数组到 stdout
# 复用 writing-plans-with-issue 的 Provider 层
# 兼容: GitHub / Gitee / GitLab, Linux / macOS / Windows (Git Bash)

set -euo pipefail

# ── 参数解析 ──
LIMIT=100
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="${2:?'--limit requires a number'}"; shift 2 ;;
    -h|--help)
      echo "Usage: fetch-open-issues.sh [--limit N]"
      echo "  获取所有 open issues，输出 JSON 数组到 stdout"
      echo "  --limit N   最大获取数量（默认 100）"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Provider 层路径 ──
PROVIDER_DIR="${WRITING_PLANS_PROVIDER_DIR:-$HOME/.claude/skills/writing-plans-with-issue/scripts}"

if [ ! -f "$PROVIDER_DIR/_provider.sh" ]; then
  cat >&2 <<EOF
❌ Provider scripts not found at: $PROVIDER_DIR

writing-plans-with-issue skill is required.
Install it:
  git clone https://github.com/your-org/writing-plans-with-issue ~/.claude/skills/writing-plans-with-issue

Or set WRITING_PLANS_PROVIDER_DIR to the correct path.
EOF
  exit 1
fi

source "$PROVIDER_DIR/_provider.sh"
provider_check_prerequisites || exit 1

if ! command -v jq &>/dev/null; then
  echo "❌ jq is required. Install: brew install jq (macOS) / sudo apt install jq (Linux)" >&2
  exit 1
fi

# ── 进度输出（到 stderr，不污染 stdout JSON） ──
log_progress() { echo "🔄 $1" >&2; }
log_done()    { echo "✅ $1" >&2; }
log_warn()    { echo "⚠️  $1" >&2; }

# ── 获取 open issues 列表 ──
log_progress "获取 open issues（最多 ${LIMIT} 条）..."

issues_list=$(provider_list_issues "" "open" "$LIMIT" 2>/dev/null) || {
  echo "❌ Failed to list open issues" >&2
  exit 1
}

count=$(echo "$issues_list" | jq 'length')

if [ "$count" -eq 0 ]; then
  log_done "没有 open issues"
  echo "[]"
  exit 0
fi

log_progress "共 ${count} 个 open issues，获取详情中..."

# ── 逐个获取 body + labels ──
# provider_list_issues 返回的字段因平台而异：
#   GitHub: {number, title, labels, state, url}  — labels 已有
#   Gitee:  {number, title, state, url}          — 无 labels
#   GitLab: {number, title, state, url}          — 无 labels
# provider_get_issue_json 返回: {number, title, state, url}（均无 labels）
# provider_get_issue_body 返回: 纯文本 body
# 策略：逐 issue 调用两个 API 补齐 body + labels

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

echo "[" > "$tmpfile"
first=true

for i in $(seq 0 $((count - 1))); do
  # 从列表提取基础信息
  issue_num=$(echo "$issues_list" | jq -r ".[$i].number")
  issue_title=$(echo "$issues_list" | jq -r ".[$i].title")
  issue_url=$(echo "$issues_list" | jq -r ".[$i].url")
  issue_labels=$(echo "$issues_list" | jq -c ".[$i].labels // empty")

  log_progress "  [$((i + 1))/${count}] #${issue_num} ${issue_title:0:50}"

  # 获取完整 body（纯文本，由 jq --arg 负责 JSON 转义）
  body=$(provider_get_issue_body "$issue_num" 2>/dev/null || echo "")

  # 如果列表不包含 labels，从 provider_get_issue_json 补齐
  if [ -z "$issue_labels" ]; then
    detail=$(provider_get_issue_json "$issue_num" 2>/dev/null || echo "{}")
    issue_labels=$(echo "$detail" | jq -c '.labels // []')
  fi

  # labels 格式归一化：
  #   GitHub: [{"name":"bug"},{"name":"feature"}] → ["bug","feature"]
  #   Gitee/GitLab (from detail): 可能也是对象数组或字符串数组
  labels_array=$(echo "$issue_labels" | jq -c '
    if type == "array" then
      map(if type == "object" then (.name // "") else . end) | map(select(. != ""))
    else [] end
  ')

  # 组装单条 JSON 对象，追加到 tmpfile
  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$tmpfile"
  fi

  jq -n \
    --argjson num "$issue_num" \
    --arg title "$issue_title" \
    --arg body "$body" \
    --argjson labels "$labels_array" \
    --arg url "$issue_url" \
    '{number: $num, title: $title, body: $body, labels: $labels, url: $url}' >> "$tmpfile"
done

echo "]" >> "$tmpfile"

log_done "共获取 ${count} 个 issues"

# 输出最终 JSON（格式化）
jq '.' "$tmpfile"
