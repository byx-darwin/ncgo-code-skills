#!/bin/bash
# writing-plans-with-issue: create-issue.sh
# 从计划文件解析 "GitHub Issue 规划" 部分并创建 GitHub Issue
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

export STDERR_FILE=$(mktemp /tmp/ncgo-stderr-XXXXXX)
trap 'rm -f "$STDERR_FILE"' EXIT
trap 'report_error "${BASH_SOURCE[0]}" "$LINENO" "$?"' ERR

# ── 参数解析 ──

PLAN_FILE="${1:-}"

if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(find docs/superpowers/plans -name "*.md" -type f -maxdepth 1 2>/dev/null | sort -t- -k1,3 -r | head -1)
  if [ -z "$PLAN_FILE" ]; then
    log_error "No plan file found. Usage: create-issue.sh <plan-file>"
    exit 1
  fi
  log_info "Using latest plan file: $PLAN_FILE"
fi

if [ ! -f "$PLAN_FILE" ]; then
  log_error "Plan file not found: $PLAN_FILE"
  exit 1
fi

if ! grep -q "## GitHub Issue 规划" "$PLAN_FILE"; then
  log_error "Plan file does not contain 'GitHub Issue 规划' section."
  echo "Please use writing-plans-with-issue skill to create the plan."
  exit 1
fi

# ── 提取 Issue 信息 ──

extract_issue_info() {
  ISSUE_TITLE=$(grep "^\*\*Issue 标题:\*\*" "$PLAN_FILE" | sed 's/^\*\*Issue 标题:\*\*[[:space:]]*//;s/^[* ]*//;s/[* ]*$//')
  if [ -z "$ISSUE_TITLE" ]; then
    log_error "Failed to extract Issue title from plan file."
    exit 1
  fi

  ISSUE_LABELS=$(grep "^\*\*Issue 标签:\*\*" "$PLAN_FILE" | sed 's/^\*\*Issue 标签:\*\*[[:space:]]*//;s/^[* ]*//;s/[* ]*$//')
  # 标准化标签格式（只移除逗号周围空格，保留标签内部空格）
  ISSUE_LABELS=$(normalize_labels "$ISSUE_LABELS")

  ISSUE_DESC=$(awk '/^\*\*Issue 描述:\*\*/{flag=1; next} /^\*\*|^##/{flag=0} flag' "$PLAN_FILE" | sed 's/^[[:space:]]*//')

  ACCEPTANCE=$(awk '/^\*\*验收标准:\*\*/{flag=1; next} /^\*\*|^##/{flag=0} flag' "$PLAN_FILE")

  MILESTONE=$(grep -A 1 "^\*\*里程碑:\*\*" "$PLAN_FILE" | tail -1 | sed 's/^[* ]*//;s/[* ]*$//' | grep -v "可选" || echo "")
}

# ── 构建 Issue body ──

build_issue_body() {
  cat <<EOF
## 描述

$ISSUE_DESC

## 验收标准

$ACCEPTANCE

## 计划

计划文件: \`$PLAN_FILE\`

## 开发工作流

1. 使用 Superpowers subagent-driven-development 实现
2. 代码审查
3. 测试验证
4. PR 合并后自动关闭

---
_Auto-created by writing-plans-with-issue_
EOF
}

# ── 注入 Issue 引用到计划文件 ──

inject_issue_ref() {
  local issue_num="$1"
  local plan_file="$2"
  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '$tmpfile'" RETURN
  echo "<!-- Issue: #$issue_num -->" > "$tmpfile"
  cat "$plan_file" >> "$tmpfile"
  cp "$tmpfile" "$plan_file"
}

# ── 主流程 ──

main() {
  cd_to_git_root
  check_dependencies

  log_info "Creating GitHub Issue from plan file..."
  extract_issue_info

  log_info "Issue title: $ISSUE_TITLE"
  log_info "Issue labels: $ISSUE_LABELS"

  ISSUE_BODY=$(build_issue_body)

  # 防止重复创建
  EXISTING_ISSUE=$(grep -o '<!-- Issue: #[0-9]* -->' "$PLAN_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "")
  if [ -n "$EXISTING_ISSUE" ]; then
    log_warn "计划文件已关联 Issue #$EXISTING_ISSUE"
    echo "  如需创建新 Issue，请先删除计划文件中的 '<!-- Issue: #$EXISTING_ISSUE -->'"
    echo "  然后重新运行: $0 $PLAN_FILE"
    exit 1
  fi

  # 确保用户标签存在
  IFS=',' read -ra LABEL_ARRAY <<< "$ISSUE_LABELS"
  for label in "${LABEL_ARRAY[@]}"; do
    label=$(echo "$label" | xargs)
    [ -z "$label" ] && continue
    ensure_status_label "$label" || true
  done

  # 确保 status: plan 标签存在
  ensure_status_label "status: plan" || true

  log_info "Creating Issue on platform..."

  # 用临时文件存储 body（避免 shell 转义问题）
  TEMP_BODY=$(mktemp)
  trap 'rm -f "$TEMP_BODY" "$STDERR_FILE"' EXIT
  echo "$ISSUE_BODY" > "$TEMP_BODY"

  # 调用 Provider 创建 Issue
  local errfile; errfile=$(mktemp)
  trap 'rm -f "$TEMP_BODY" "$errfile" "$STDERR_FILE"' EXIT
  set +e
  ISSUE_URL=$(provider_create_issue "$ISSUE_TITLE" "$TEMP_BODY" "$ISSUE_LABELS" "$MILESTONE" 2>"$errfile")
  CREATE_EXIT=$?
  set -e

  if [ $CREATE_EXIT -ne 0 ]; then
    log_error "Failed to create Issue."
    cat "$errfile" >&2
    rm -f "$errfile"
    exit 1
  fi
  rm -f "$errfile"

  # 提取 Issue 编号
  ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')
  if [ -z "$ISSUE_NUM" ]; then
    log_error "Failed to extract Issue number from URL: $ISSUE_URL"
    exit 1
  fi

  # 保存 Issue 编号
  mkdir -p .claude/gh-issue
  echo "$ISSUE_NUM" > .claude/gh-issue/current-issue.txt

  # 注入 Issue 引用
  if ! grep -q "<!-- Issue: #" "$PLAN_FILE"; then
    inject_issue_ref "$ISSUE_NUM" "$PLAN_FILE"
    log_info "Added Issue reference to plan file"
  fi

  # 添加初始状态标签
  if provider_add_labels "$ISSUE_NUM" "status: plan" 2>/dev/null; then
    log_info "Added status: plan label"
  else
    log_warn "Failed to add 'status: plan'. Add manually."
  fi

  echo ""
  log_info "Issue created successfully!"
  echo "  URL: $ISSUE_URL"
  echo "  Number: #$ISSUE_NUM"
  if [ -n "$ISSUE_LABELS" ]; then
    echo "  Labels: $ISSUE_LABELS, status: plan"
  fi
  echo "  Saved to: .claude/gh-issue/current-issue.txt"
  echo ""
  echo "Next steps:"
  echo "  1. sync-status.sh in-progress   (Task 2)"
  echo "  2. subagent-driven-development   (Task 3+)"
}

main "$@"
