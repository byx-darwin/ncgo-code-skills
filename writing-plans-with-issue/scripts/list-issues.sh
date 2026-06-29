#!/bin/bash
# writing-plans-with-issue: list-issues.sh
# 按状态分组列出所有平台 Issue（辅助工具，非 skill）
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

main() {
  cd_to_git_root
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
    ISSUE_NUM=$(tr -d '[:space:]' < .claude/gh-issue/current-issue.txt)
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
