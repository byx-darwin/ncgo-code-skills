#!/bin/bash
# writing-plans-with-issue: Gitee backend (curl + jq via OpenAPI v5)
# Provides all provider_* functions for gitee.com repositories.
# Requires: curl, jq, GITEE_TOKEN environment variable.

GITEE_API_BASE="https://gitee.com/api/v5"

# ── Helpers ──

_gitee_get_repo() {
  # Parse owner/repo from git remote URL
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")
  # Support both HTTPS and SSH formats (HTTPS may include user:token@ prefix):
  # https://user:token@gitee.com/owner/repo.git
  # https://gitee.com/owner/repo.git
  # git@gitee.com:owner/repo.git
  if [[ "$remote_url" == *gitee.com* ]]; then
    # 1. Strip .git suffix (if present)
    # 2. Extract owner/repo after gitee.com separator (/ or :)
    echo "${remote_url%.git}" | sed -E 's|.*gitee.com[:/](.*)|\1|'
  else
    echo "unknown/unknown"
  fi
}

_gitee_api() {
  # _gitee_api METHOD PATH [JSON_BODY]
  # Prints response to stdout, errors to stderr
  local method="$1"
  local path="$2"
  local body="${3:-}"

  # Use ? or & depending on whether path already contains query parameters
  local sep="?"
  [[ "$path" == *"?"* ]] && sep="&"
  local url="${GITEE_API_BASE}${path}${sep}access_token=${GITEE_TOKEN}"

  if [ -n "$body" ]; then
    curl -s -X "$method" "$url" \
      -H "Content-Type: application/json" \
      -d "$body" 2>/tmp/gitee_curl_err.txt
  else
    curl -s -X "$method" "$url" 2>/tmp/gitee_curl_err.txt
  fi
}

_gitee_get_issue_field() {
  local issue_num="$1"
  local field="$2"
  local repo
  repo=$(_gitee_get_repo)
  _gitee_api GET "/repos/${repo}/issues/${issue_num}" | jq -r ".${field}"
}

# ── Prerequisites ──

provider_check_prerequisites() {
  if ! command -v curl &> /dev/null; then
    echo "❌ curl is required but not installed."
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    echo "❌ jq is required for Gitee backend."
    echo "Install: brew install jq  (macOS)"
    echo "        sudo apt install jq  (Debian/Ubuntu)"
    exit 1
  fi

  if [ -z "${GITEE_TOKEN:-}" ]; then
    echo "❌ GITEE_TOKEN environment variable is not set."
    echo ""
    echo "Get your token: https://gitee.com/profile/personal_access_tokens"
    echo "Then: export GITEE_TOKEN=your_token"
    exit 1
  fi
}

# ── Issue operations ──

provider_create_issue() {
  local title="$1"
  local body_file="$2"
  local labels="$3"
  local milestone="${4:-}"

  local repo
  repo=$(_gitee_get_repo)

  local body_text
  body_text=$(cat "$body_file")

  # Build JSON payload with jq for proper escaping
  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body_text" \
    --arg labels "$labels" \
    --arg milestone "$milestone" \
    '{
      title: $title,
      body: $body
    } + (if $labels != "" then {labels: $labels} else {} end) + (if $milestone != "" then {milestone: $milestone | tonumber} else {} end)')

  local response
  response=$(_gitee_api POST "/repos/${repo}/issues" "$payload")

  # Extract HTML URL
  local html_url
  html_url=$(echo "$response" | jq -r '.html_url // empty')
  if [ -z "$html_url" ]; then
    echo "❌ Failed to create Gitee Issue."
    echo "Response: $response" >&2
    [ -f /tmp/gitee_curl_err.txt ] && cat /tmp/gitee_curl_err.txt >&2
    return 1
  fi
  echo "$html_url"
}

provider_add_labels() {
  local issue_num="$1"
  local labels_csv="$2"

  local repo
  repo=$(_gitee_get_repo)

  # Get current labels
  local current_labels
  current_labels=$(_gitee_api GET "/repos/${repo}/issues/${issue_num}" | jq -r '[.labels[].name] | join(",")')

  # Merge with new labels
  local merged
  if [ -n "$current_labels" ] && [ "$current_labels" != "null" ]; then
    merged="${current_labels},${labels_csv}"
  else
    merged="$labels_csv"
  fi

  # Deduplicate and rebuild
  local unique_labels
  unique_labels=$(echo "$merged" | tr ',' '\n' | sort -u | paste -sd ',' -)

  # PATCH the issue with new labels
  _gitee_api PATCH "/repos/${repo}/issues/${issue_num}" \
    "$(jq -n --arg labels "$unique_labels" '{labels: $labels}')" > /dev/null || {
    echo "❌ Failed to add labels to Gitee Issue #$issue_num"
    return 1
  }
}

provider_remove_label() {
  local issue_num="$1"
  local label="$2"

  local repo
  repo=$(_gitee_get_repo)

  # Get current labels, filter out the one to remove
  local new_labels
  new_labels=$(_gitee_api GET "/repos/${repo}/issues/${issue_num}" | \
    jq -r --arg lbl "$label" '[.labels[].name | select(. != $lbl)] | join(",")')

  # PATCH the issue with filtered labels
  _gitee_api PATCH "/repos/${repo}/issues/${issue_num}" \
    "$(jq -n --arg labels "$new_labels" '{labels: $labels}')" > /dev/null || {
    echo "❌ Failed to remove label from Gitee Issue #$issue_num"
    return 1
  }
}

provider_close_issue() {
  local issue_num="$1"
  local comment="${2:-}"

  local repo
  repo=$(_gitee_get_repo)

  # Post comment first (if provided)
  if [ -n "$comment" ]; then
    _gitee_api POST "/repos/${repo}/issues/${issue_num}/comments" \
      "$(jq -n --arg body "$comment" '{body: $body}')" > /dev/null 2>&1 || true
  fi

  # Close the issue
  local response
  response=$(_gitee_api PATCH "/repos/${repo}/issues/${issue_num}" \
    "$(jq -n '{state: "closed"}')")

  local state
  state=$(echo "$response" | jq -r '.state // empty')
  if [ "$state" != "closed" ]; then
    echo "❌ Failed to close Gitee Issue #$issue_num"
    return 1
  fi
}

provider_get_issue_body() {
  local issue_num="$1"
  _gitee_get_issue_field "$issue_num" "body"
}

provider_get_issue_state() {
  local issue_num="$1"
  local state
  state=$(_gitee_get_issue_field "$issue_num" "state")
  # Gitee states: open, progressing, closed
  # Normalize: closed → closed, everything else → open
  if [ "$state" = "closed" ]; then
    echo "closed"
  else
    echo "open"
  fi
}

provider_get_issue_json() {
  local issue_num="$1"
  local repo
  repo=$(_gitee_get_repo)
  _gitee_api GET "/repos/${repo}/issues/${issue_num}" | \
    jq '{number: .number, title: .title, state: .state, url: .html_url}'
}

provider_list_issues() {
  local label="$1"
  local state="$2"
  local limit="${3:-20}"

  local repo
  repo=$(_gitee_get_repo)

  # Build query parameters dynamically (skip empty values)
  local params="per_page=${limit}&sort=updated&direction=desc"
  [ -n "$label" ] && params="${params}&labels=${label}"
  # Map state: open → open, closed → closed, all → (no filter)
  if [ -n "$state" ] && [ "$state" != "all" ]; then
    params="${params}&state=${state}"
  fi

  _gitee_api GET "/repos/${repo}/issues?${params}" | \
    jq '[.[] | {number: .number, title: .title, state: .state, url: .html_url}]'
}

provider_update_issue_body() {
  local issue_num="$1"
  local body_file="$2"
  local repo
  repo=$(_gitee_get_repo)
  local body_text
  body_text=$(cat "$body_file")
  _gitee_api PATCH "/repos/${repo}/issues/${issue_num}" \
    "$(jq -n --arg body "$body_text" '{body: $body}')" > /dev/null || {
    echo "❌ Failed to update Gitee Issue #$issue_num body"
    return 1
  }
}

# ── PR operations ──

provider_create_pr() {
  local title="$1"
  local body_file="$2"
  local base_branch="$3"

  local repo
  repo=$(_gitee_get_repo)

  local head_branch
  head_branch=$(git branch --show-current)

  local body_text
  body_text=$(cat "$body_file")

  local payload
  payload=$(jq -n \
    --arg title "$title" \
    --arg body "$body_text" \
    --arg head "$head_branch" \
    --arg base "$base_branch" \
    '{title: $title, body: $body, head: $head, base: $base}')

  local response
  response=$(_gitee_api POST "/repos/${repo}/pulls" "$payload")

  local html_url
  html_url=$(echo "$response" | jq -r '.html_url // empty')
  if [ -z "$html_url" ]; then
    echo "❌ Failed to create Gitee Pull Request."
    echo "Response: $response" >&2
    return 1
  fi
  echo "$html_url"
}

provider_list_prs() {
  local head_branch="$1"
  local repo
  repo=$(_gitee_get_repo)
  _gitee_api GET "/repos/${repo}/pulls?head=${repo%%/*}:${head_branch}&state=open" | \
    jq -r '.[0].number // empty' 2>/dev/null || echo ""
}

provider_get_pr_url() {
  local pr_num="$1"
  local repo
  repo=$(_gitee_get_repo)
  echo "https://gitee.com/${repo}/pulls/${pr_num}"
}

# ── Label management ──

provider_ensure_label() {
  local label="$1"
  local repo
  repo=$(_gitee_get_repo)

  # Check if label exists
  local status_code
  status_code=$(curl -s -o /dev/null -w "%{http_code}" \
    "${GITEE_API_BASE}/repos/${repo}/labels/${label}?access_token=${GITEE_TOKEN}" 2>/dev/null)

  if [ "$status_code" = "404" ]; then
    # Create the label
    _gitee_api POST "/repos/${repo}/labels" \
      "$(jq -n --arg name "$label" --arg color "ededed" '{name: $name, color: $color}')" > /dev/null 2>&1 || {
      echo "⚠️  Failed to create Gitee label '$label'"
      return 1
    }
    echo "✅ Created label: $label"
  fi
  return 0
}

# ── Repository info ──

provider_repo_name_with_owner() {
  _gitee_get_repo
}
