#!/usr/bin/env bash
# auto-smoke-test.sh — Stop hook: run smoke test if Provider scripts changed
# Called by Claude Code Stop hook to verify cross-platform compatibility after dev work.
# Stores hashes in .cache/ to avoid redundant runs.

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && exit 0  # not in a git repo

HASH_FILE="$REPO_ROOT/.cache/smoke-hashes"

# Files to monitor (all Provider scripts)
PROVIDER_FILES=(
  "$REPO_ROOT/writing-plans-with-issue/scripts/_common.sh"
  "$REPO_ROOT/writing-plans-with-issue/scripts/_provider.sh"
  "$REPO_ROOT/writing-plans-with-issue/scripts/_provider_github.sh"
  "$REPO_ROOT/writing-plans-with-issue/scripts/_provider_gitee.sh"
  "$REPO_ROOT/writing-plans-with-issue/scripts/_provider_gitlab.sh"
  "$REPO_ROOT/writing-plans-with-issue/scripts/smoke-test.sh"
)

# Compute current hash (combine all provider file hashes into one)
if command -v md5sum &>/dev/null; then
  CURRENT_HASH=$(cat "${PROVIDER_FILES[@]}" 2>/dev/null | md5sum | cut -d' ' -f1)
elif command -v md5 &>/dev/null; then
  CURRENT_HASH=$(cat "${PROVIDER_FILES[@]}" 2>/dev/null | md5 -q)
else
  CURRENT_HASH=""
fi

# Check if hash exists and matches
if [ -f "$HASH_FILE" ]; then
  STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
  if [ "$CURRENT_HASH" = "$STORED_HASH" ]; then
    exit 0  # no changes, skip
  fi
fi

# Provider files changed — run smoke test
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 检测到 Provider 脚本变更，自动运行冒烟测试..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SMOKE_SCRIPT="$REPO_ROOT/writing-plans-with-issue/scripts/smoke-test.sh"

if [ -f "$SMOKE_SCRIPT" ]; then
  # Run on current platform
  bash "$SMOKE_SCRIPT" 2>&1
  EXIT_CODE=$?

  # Only save hash if tests pass (or readonly)
  if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ 冒烟测试通过 — 更新 hash 缓存"
    mkdir -p "$(dirname "$HASH_FILE")"
    echo "$CURRENT_HASH" > "$HASH_FILE"
  else
    echo ""
    echo "⚠️  冒烟测试失败！请检查 Provider 代码。"
    echo "   手动运行: bash $SMOKE_SCRIPT"
  fi
else
  echo "⚠️  未找到 smoke-test.sh，跳过"
fi
