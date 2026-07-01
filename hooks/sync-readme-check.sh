#!/usr/bin/env bash
# sync-readme-check.sh — Stop Hook：检查 README 和 CLAUDE.md 是否需要更新
# 扫描目录结构，与文档中记录的对比，不一致时输出提醒。

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
[ -z "$REPO_ROOT" ] && exit 0
cd "$REPO_ROOT" || exit 0

# 获取实际的顶级目录（排除隐藏目录和 docs）
get_actual_dirs() {
  find . -maxdepth 1 -type d \
    ! -name '.' \
    ! -name '.*' \
    ! -name 'docs' \
    | sed 's|^\./||' \
    | sort
}

# 从指定文件提取目录结构中列出的顶级技能目录
get_file_dirs() {
  local file="$1"
  grep -E '^├── [a-z].*/$|^└── [a-z].*/$' "$file" 2>/dev/null \
    | sed 's/.*── //' \
    | sed 's|/$||' \
    | sort -u || true
}

# 获取实际目录
actual=$(get_actual_dirs)

# 逐文件检查，收集差异
message=""
has_issues=false

for file in README.md README.zh-CN.md CLAUDE.md; do
  [ -f "$file" ] || continue
  file_dirs=$(get_file_dirs "$file")

  missing=$(comm -23 <(echo "$actual") <(echo "$file_dirs") 2>/dev/null || true)
  extra=$(comm -13 <(echo "$actual") <(echo "$file_dirs") 2>/dev/null || true)

  if [ -n "$missing" ] || [ -n "$extra" ]; then
    has_issues=true
    message+="\n  📄 $file:\n"
    if [ -n "$missing" ]; then
      message+="    缺少的目录:\n"
      while IFS= read -r dir; do
        [ -n "$dir" ] && message+="      - $dir\n"
      done <<< "$missing"
    fi
    if [ -n "$extra" ]; then
      message+="    多余的目录:\n"
      while IFS= read -r dir; do
        [ -n "$dir" ] && message+="      - $dir\n"
      done <<< "$extra"
    fi
  fi
done

if [ "$has_issues" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📝 文档目录结构可能需要更新"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "$message"
  echo "  运行 /sync-readme 自动更新所有文档"
  echo ""
fi

exit 0
