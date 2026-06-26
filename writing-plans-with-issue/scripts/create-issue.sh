#!/bin/bash
# writing-plans-with-issue: create-issue.sh
# 从计划文件解析 "GitHub Issue 规划" 部分并创建 GitHub Issue
# 兼容: Linux, macOS, Windows (Git Bash / WSL)

set -o pipefail

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
      echo "  或:            https://github.com/cli/cli/releases"
      ;;
    windows)
      echo "  winget install GitHub.cli"
      echo "  或: choco install gh"
      echo "  或: https://cli.github.com/"
      ;;
    *)
      echo "  下载: https://cli.github.com/"
      ;;
  esac
  echo ""
  echo "安装后运行: gh auth login"
}

# 检查依赖
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
PLAN_FILE="${1:-}"

if [ -z "$PLAN_FILE" ]; then
  PLAN_FILE=$(find docs/superpowers/plans -name "*.md" -type f 2>/dev/null | sort -r | head -1)
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

# 提取 Issue 信息
extract_issue_info() {
  # 标题（同一行格式: **Issue 标题:** feat: xxx）
  ISSUE_TITLE=$(grep "^\*\*Issue 标题:\*\*" "$PLAN_FILE" | sed 's/^\*\*Issue 标题:\*\*[[:space:]]*//;s/^[* ]*//;s/[* ]*$//')
  if [ -z "$ISSUE_TITLE" ]; then
    ISSUE_TITLE=$(grep -A 1 "^\*\*Issue 标题:\*\*" "$PLAN_FILE" | tail -1 | sed 's/^[* ]*//;s/[* ]*$//')
  fi

  # 标签
  ISSUE_LABELS=$(grep "^\*\*Issue 标签:\*\*" "$PLAN_FILE" | sed 's/^\*\*Issue 标签:\*\*[[:space:]]*//;s/^[* ]*//;s/[* ]*$//')
  if [ -z "$ISSUE_LABELS" ]; then
    ISSUE_LABELS=$(grep -A 1 "^\*\*Issue 标签:\*\*" "$PLAN_FILE" | tail -1 | sed 's/^[* ]*//;s/[* ]*$//')
  fi
  # 移除空格（gh CLI 要求逗号分隔无空格）
  ISSUE_LABELS=$(echo "$ISSUE_LABELS" | tr -d ' ')

  # 描述（从 **Issue 描述:** 到下一个 ** 或 ##）
  ISSUE_DESC=$(awk '/^\*\*Issue 描述:\*\*/{flag=1; next} /^\*\*|^##/{flag=0} flag' "$PLAN_FILE" | sed 's/^[[:space:]]*//')

  # 验收标准
  ACCEPTANCE=$(awk '/^\*\*验收标准:\*\*/{flag=1; next} /^\*\*|^##/{flag=0} flag' "$PLAN_FILE")

  # 里程碑（可选）
  MILESTONE=$(grep -A 1 "^\*\*里程碑:\*\*" "$PLAN_FILE" | tail -1 | sed 's/^[* ]*//;s/[* ]*$//' | grep -v "可选" || echo "")
}

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

# 确保标签存在
ensure_labels() {
  IFS=',' read -ra LABEL_ARRAY <<< "$ISSUE_LABELS"
  for label in "${LABEL_ARRAY[@]}"; do
    label=$(echo "$label" | xargs)
    if [ -z "$label" ]; then
      continue
    fi
    if ! gh label list --json name -q '.[].name' 2>/dev/null | grep -qxF "$label"; then
      log_info "Creating label: $label"
      gh label create "$label" --color "ededed" 2>/dev/null || {
        log_warn "Failed to create label '$label', will skip it"
        continue
      }
    fi
  done
}

# 注入 Issue 引用到计划文件（跨平台兼容：用临时文件替代 sed -i）
inject_issue_ref() {
  local issue_num="$1"
  local plan_file="$2"
  local tmpfile
  tmpfile=$(mktemp)
  echo "<!-- Issue: #$issue_num -->" > "$tmpfile"
  cat "$plan_file" >> "$tmpfile"
  mv "$tmpfile" "$plan_file"
}

# 主流程
main() {
  log_info "Creating GitHub Issue from plan file..."

  check_dependencies
  extract_issue_info

  if [ -z "$ISSUE_TITLE" ]; then
    log_error "Failed to extract Issue title from plan file."
    exit 1
  fi

  log_info "Issue title: $ISSUE_TITLE"
  log_info "Issue labels: $ISSUE_LABELS"

  ISSUE_BODY=$(build_issue_body)
  ensure_labels

  log_info "Creating Issue on GitHub..."

  # 检查是否已有关联的 Issue（防止重复创建）
  EXISTING_ISSUE=$(grep -o '<!-- Issue: #[0-9]* -->' "$PLAN_FILE" 2>/dev/null | grep -o '[0-9]*')
  if [ -n "$EXISTING_ISSUE" ]; then
    log_warn "计划文件已关联 Issue #$EXISTING_ISSUE"
    echo "  如需创建新 Issue，请先删除计划文件中的 '<!-- Issue: #$EXISTING_ISSUE -->'"
    echo "  然后重新运行: $0 $PLAN_FILE"
    exit 1
  fi

  # 使用临时文件存储正文（避免 shell 转义问题）
  TEMP_FILE=$(mktemp)
  trap 'rm -f "$TEMP_FILE"' EXIT
  echo "$ISSUE_BODY" > "$TEMP_FILE"

  # 构建 gh issue create 命令（用数组避免 MILESTONE 参数拆分问题）
  CREATE_ARGS=(--title "$ISSUE_TITLE" --body-file "$TEMP_FILE" --label "$ISSUE_LABELS")
  if [ -n "$MILESTONE" ]; then
    CREATE_ARGS+=(--milestone "$MILESTONE")
  fi

  # 执行创建（set +e 确保能捕获退出码）
  set +e
  ISSUE_URL=$(gh issue create "${CREATE_ARGS[@]}" 2>&1)
  CREATE_EXIT=$?
  set -e

  if [ $CREATE_EXIT -ne 0 ]; then
    log_error "Failed to create Issue."
    echo "$ISSUE_URL"
    exit 1
  fi

  # 提取 Issue 编号（从 URL 末尾的数字）
  ISSUE_NUM=$(echo "$ISSUE_URL" | grep -o '[0-9]*$')

  if [ -z "$ISSUE_NUM" ]; then
    log_error "Failed to extract Issue number from URL: $ISSUE_URL"
    exit 1
  fi

  # 保存 Issue 编号
  mkdir -p .claude/gh-issue
  echo "$ISSUE_NUM" > .claude/gh-issue/current-issue.txt

  # 注入 Issue 引用到计划文件
  if ! grep -q "<!-- Issue: #" "$PLAN_FILE"; then
    inject_issue_ref "$ISSUE_NUM" "$PLAN_FILE"
    log_info "Added Issue reference to plan file"
  fi

  # 添加初始状态标签 status: plan
  gh issue edit "$ISSUE_NUM" --add-label "status: plan" 2>/dev/null || true

  echo ""
  log_info "Issue created successfully!"
  echo "  URL: $ISSUE_URL"
  echo "  Number: #$ISSUE_NUM"
  echo "  Labels: $ISSUE_LABELS, status: plan"
  echo "  Saved to: .claude/gh-issue/current-issue.txt"
  echo ""
  echo "Next steps:"
  echo "  1. sync-status.sh in-progress   (Task 2)"
  echo "  2. subagent-driven-development   (Task 3+)"
}

main "$@"
