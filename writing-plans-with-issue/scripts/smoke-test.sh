#!/usr/bin/env bash
# smoke-test.sh — cross-platform Provider verification
# Tests core Issue lifecycle operations on the current platform (GitHub/Gitee/GitLab).
# Creates a temporary test issue, runs all provider functions against it, cleans up.
#
# Usage:
#   bash smoke-test.sh              # auto-detect platform
#   bash smoke-test.sh --platform gitee   # force specific platform
#   bash smoke-test.sh --keep       # keep test issue after run
#
# Compatible: Linux / macOS / Windows (Git Bash)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# ── 参数 ──

KEEP=0
FORCE_PLATFORM=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform) FORCE_PLATFORM="${2:?'--platform requires value'}"; shift 2 ;;
    --keep)     KEEP=1; shift ;;
    -h|--help)
      echo "Usage: smoke-test.sh [--platform github|gitee|gitlab] [--keep]"
      echo "  Tests all provider functions against the current platform."
      echo "  --platform   Force a specific platform (default: auto-detect)"
      echo "  --keep       Keep the test issue after run (default: clean up)"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── 平台覆盖 ──

if [ -n "$FORCE_PLATFORM" ]; then
  case "$FORCE_PLATFORM" in
    github|gitee|gitlab) export WRITING_PLANS_PLATFORM="$FORCE_PLATFORM" ;;
    *) echo "❌ Invalid platform: $FORCE_PLATFORM" >&2; exit 1 ;;
  esac
fi

# ── 状态追踪 ──

PASS=0
FAIL=0
SKIP=0
LIMIT=0
TOTAL=0

reset_counts() { PASS=0; FAIL=0; SKIP=0; LIMIT=0; TOTAL=0; }

pass()  { ((PASS++)); ((TOTAL++)); echo "  ✅ $1"; }
fail()  { ((FAIL++)); ((TOTAL++)); echo "  ❌ $1 — $2"; }
skip()  { ((SKIP++)); ((TOTAL++)); echo "  ⏭️  $1 — $2"; }
limit() { ((LIMIT++)); ((TOTAL++)); echo "  🔒 $1 — $2"; }

is_gitee_limit() {
  # Detect Gitee platform write restriction
  [[ "$PLATFORM" == "gitee" ]] && echo "$1" | grep -q "project or enterprise"
}

report() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$FAIL" -eq 0 ] && [ "$LIMIT" -eq 0 ] && [ "$SKIP" -eq 0 ]; then
    echo "✅ All $TOTAL tests passed!"
  elif [ "$FAIL" -eq 0 ] && [ "$LIMIT" -gt 0 ]; then
    echo "⚠️  $PASS/$TOTAL passed, $LIMIT blocked by platform (Gitee 免费账号 API 写入限制)"
  elif [ "$FAIL" -gt 0 ]; then
    echo "❌ $PASS passed, $FAIL failed, $LIMIT platform-limited, $SKIP skipped (total: $TOTAL)"
  else
    echo "⚠️  $PASS/$TOTAL passed, $SKIP skipped"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  return "$FAIL"
}

# ── 测试函数 ──

test_prerequisites() {
  echo "🔍 Testing: prerequisites"

  # provider_check_prerequisites() exits on failure, so we trap it
  set +e
  output=$(provider_check_prerequisites 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    pass "check_prerequisites"
  else
    fail "check_prerequisites" "$output"
    echo ""
    echo "❌ Cannot continue — prerequisites failed."
    exit 1
  fi

  # Ensure test labels exist (needed for create_issue and add_labels tests)
  echo "🔍 Ensuring test labels exist..."
  provider_ensure_label "smoke-test" 2>/dev/null || true
  provider_ensure_label "smoke-test-added" 2>/dev/null || true
}

test_create_issue() {
  echo "🔍 Testing: create_issue"

  local title="[SMOKE-TEST] Provider verification — $(date +%s)"
  local body_file; body_file=$(mktemp)
  echo "This is a smoke test issue created by scripts/smoke-test.sh. Safe to delete." > "$body_file"

  local output
  set +e
  output=$(provider_create_issue "$title" "$body_file" "smoke-test" "" 2>&1)
  rc=$?
  set -e
  rm -f "$body_file"

  if [ $rc -eq 0 ] && [ -n "$output" ]; then
    TEST_ISSUE_URL="$output"
    # Extract issue number from URL (works for all platforms: .../issues/N)
    TEST_ISSUE_NUM=$(echo "$output" | grep -oE '[0-9]+$' | head -1)
    pass "create_issue → #$TEST_ISSUE_NUM"
  elif is_gitee_limit "$output"; then
    limit "create_issue" "Gitee 平台限制（Token 无 Issue 写入权限）"
  else
    fail "create_issue" "$output"
  fi
}

test_get_issue_body() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "get_issue_body" "no test issue"; return; }
  echo "🔍 Testing: get_issue_body"

  local body
  set +e
  body=$(provider_get_issue_body "$TEST_ISSUE_NUM" 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ] && echo "$body" | grep -q "smoke test"; then
    pass "get_issue_body — contains expected text"
  else
    fail "get_issue_body" "missing expected text or rc=$rc"
  fi
}

test_get_issue_json() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "get_issue_json" "no test issue"; return; }
  echo "🔍 Testing: get_issue_json"

  local json
  set +e
  json=$(provider_get_issue_json "$TEST_ISSUE_NUM" 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ] && echo "$json" | jq -e '.number and .title and .state and .url' > /dev/null 2>&1; then
    pass "get_issue_json — all 4 fields present"
  else
    fail "get_issue_json" "missing required fields or rc=$rc"
  fi
}

test_get_issue_state() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "get_issue_state" "no test issue"; return; }
  echo "🔍 Testing: get_issue_state"

  local state
  set +e
  state=$(provider_get_issue_state "$TEST_ISSUE_NUM" 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ] && [ -n "$state" ]; then
    pass "get_issue_state → $state"
  else
    fail "get_issue_state" "empty or rc=$rc"
  fi
}

test_add_labels() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "add_labels" "no test issue"; return; }
  echo "🔍 Testing: add_labels"

  set +e
  output=$(provider_add_labels "$TEST_ISSUE_NUM" "smoke-test-added" 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    pass "add_labels — added 'smoke-test-added'"
  else
    fail "add_labels" "$output"
  fi
}

test_remove_label() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "remove_label" "no test issue"; return; }
  echo "🔍 Testing: remove_label"

  set +e
  output=$(provider_remove_label "$TEST_ISSUE_NUM" "smoke-test-added" 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    pass "remove_label — removed 'smoke-test-added'"
  else
    fail "remove_label" "$output"
  fi
}

test_list_issues() {
  echo "🔍 Testing: list_issues"

  local list
  set +e
  list=$(provider_list_issues "smoke-test" "open" "5" 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ] && echo "$list" | jq -e 'type == "array"' > /dev/null 2>&1; then
    local count; count=$(echo "$list" | jq 'length')
    pass "list_issues — returned array with $count items"
  else
    fail "list_issues" "not a valid JSON array or rc=$rc"
  fi
}

test_update_issue_body() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "update_issue_body" "no test issue"; return; }
  echo "🔍 Testing: update_issue_body"

  local body_file; body_file=$(mktemp)
  echo "[SMOKE-TEST] Updated body at $(date)" > "$body_file"

  set +e
  output=$(provider_update_issue_body "$TEST_ISSUE_NUM" "$body_file" 2>&1)
  rc=$?
  set -e
  rm -f "$body_file"

  if [ $rc -eq 0 ]; then
    pass "update_issue_body — updated successfully"
  elif is_gitee_limit "$output"; then
    limit "update_issue_body" "Gitee 平台限制（Token 无 Issue 写入权限）"
  else
    fail "update_issue_body" "$output"
  fi
}

test_close_issue() {
  [ -z "${TEST_ISSUE_NUM:-}" ] && { skip "close_issue" "no test issue"; return; }
  echo "🔍 Testing: close_issue"

  set +e
  output=$(provider_close_issue "$TEST_ISSUE_NUM" "[SMOKE-TEST] Test complete, closing." 2>&1)
  rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    pass "close_issue — closed #$TEST_ISSUE_NUM"
  elif is_gitee_limit "$output"; then
    limit "close_issue" "Gitee 平台限制（Token 无 Issue 写入权限）"
  else
    fail "close_issue" "$output"
  fi
}

# ── 主流程 ──

main() {
  cd_to_git_root
  cd_to_git_root > /dev/null 2>&1 || true  # silent

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Provider Smoke Test — Platform: ${PLATFORM}"
  echo "  Repo: $(provider_repo_name_with_owner 2>/dev/null || echo 'unknown')"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Phase 1: Prerequisites
  test_prerequisites

  # Phase 2: Lifecycle tests (these depend on create_issue succeeding)
  test_create_issue
  test_get_issue_body
  test_get_issue_json
  test_get_issue_state
  test_add_labels
  test_remove_label
  test_list_issues
  test_update_issue_body

  # Phase 3: Close (unless --keep)
  if [ "${KEEP:-0}" -eq 0 ]; then
    test_close_issue
    # Verify it's actually closed
    if [ -n "${TEST_ISSUE_NUM:-}" ]; then
      local state
      state=$(provider_get_issue_state "$TEST_ISSUE_NUM" 2>/dev/null || echo "unknown")
      if [ "$state" = "closed" ]; then
        pass "verify_closed — state is '$state'"
      else
        fail "verify_closed" "state is '$state', expected 'closed'"
      fi
    fi
  else
    echo "🔍 Skipping close (--keep)"
    echo "  Test issue: $TEST_ISSUE_URL"
  fi

  report
}

main "$@"
