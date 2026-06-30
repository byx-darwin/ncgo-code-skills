#!/usr/bin/env bash
# sync-readme-check.sh — Stop Hook：检查 README 是否需要更新
# 扫描目录结构，与 README 中记录的对比，不一致时输出提醒。

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

# 从 README.md 提取目录结构中列出的顶级技能目录
get_readme_dirs() {
  # 提取 README 中列出的技能目录（以 / 结尾的顶级目录）
  grep -E '^├── [a-z].*/$|^└── [a-z].*/$' README.md 2>/dev/null \
    | sed 's/.*── //' \
    | sed 's|/$||' \
    | sort -u
}

# 获取实际目录
actual=$(get_actual_dirs)
# 获取 README 中记录的目录
readme=$(get_readme_dirs)

# 比较
missing_in_readme=$(comm -23 <(echo "$actual") <(echo "$readme") 2>/dev/null || true)
extra_in_readme=$(comm -13 <(echo "$actual") <(echo "$readme") 2>/dev/null || true)

need_update=false
message=""

if [ -n "$missing_in_readme" ]; then
  need_update=true
  message+="\n  📁 README 中缺少的目录:\n"
  while IFS= read -r dir; do
    [ -n "$dir" ] && message+="     - $dir\n"
  done <<< "$missing_in_readme"
fi

if [ -n "$extra_in_readme" ]; then
  need_update=true
  message+="\n  📁 README 中多余（已删除）的目录:\n"
  while IFS= read -r dir; do
    [ -n "$dir" ] && message+="     - $dir\n"
  done <<< "$extra_in_readme"
fi

if [ "$need_update" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  📝 README 可能需要更新"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "$message"
  echo "  运行 /sync-readme 自动更新 README"
  echo ""
fi

exit 0
