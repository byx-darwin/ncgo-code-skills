#!/usr/bin/env bash
# auto-report-bug.sh — Stop Hook：检查是否有待报告的错误
# 检测到 pending.json 后输出内容，触发 Claude 介入处理。

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
[ -z "$REPO_ROOT" ] && exit 0

PENDING_FILE="$REPO_ROOT/.cache/bug-reports/pending.json"

# 检查 pending.json 是否存在
if [ ! -f "$PENDING_FILE" ]; then
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐛 检测到脚本错误，正在生成 Bug 报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 输出 pending.json 内容供 Claude 读取
cat "$PENDING_FILE"
