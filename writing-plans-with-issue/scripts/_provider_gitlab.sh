#!/bin/bash
# writing-plans-with-issue: GitLab backend (glab CLI)
# Provides all provider_* functions for GitLab.com and self-hosted GitLab instances.

# ── Prerequisites ──

provider_check_prerequisites() {
  if ! command -v glab &> /dev/null; then
    echo "❌ GitLab CLI (glab) is required."
    echo "Install:"
    echo "  macOS:  brew install glab"
    echo "  Linux:  https://gitlab.com/gitlab-org/cli/-/releases"
    echo ""
    echo "After install: glab auth login"
    exit 1
  fi

  # 检查认证缓存
  if auth_cache_valid "gitlab" 2>/dev/null; then
    return 0
  fi

  if ! glab auth status &> /dev/null; then
    echo "❌ GitLab CLI is not authenticated."
    echo ""
    echo "Run: glab auth login"
    echo "  - For GitLab.com: choose the default host"
    echo "  - For self-hosted: glab auth login --hostname your-gitlab.example.com"
    exit 1
  fi

  # 缓存认证结果（记录已配置的主机列表）
  local hosts
  hosts=$(glab auth status --show-token 2>/dev/null | grep -oE '^\S+' | jq -R . | jq -s . 2>/dev/null || echo '["unknown"]')
  auth_cache_write "gitlab" "\"hosts\": $hosts" 2>/dev/null || true
}

# ── Issue operations ──

provider_create_issue() {
  local title="$1"
  local body_file="$2"
  local labels="$3"
  local milestone="${4:-}"

  local body_text
  body_text=$(cat "$body_file")

  local args=(-t "$title" -d "$body_text")
  [ -n "$labels" ] && args+=(-l "$labels")
  [ -n "$milestone" ] && args+=(-m "$milestone")

  # glab issue create outputs the issue URL (contains /-/issues/N)
  local output
  local errfile; errfile=$(mktemp)
  output=$(glab issue create "${args[@]}" 2>"$errfile") || {
    local exit_code=$?
    cat "$errfile" >&2
    rm -f "$errfile"
    return $exit_code
  }
  rm -f "$errfile"

  # Extract URL from output (format: "https://.../-/issues/N" or "http://...")
  echo "$output" | grep -oE 'https?://[^ ]+/-/issues/[0-9]+' | head -1 || \
    echo "$output" | grep -oE 'https?://[^ ]+' | tail -1
}

provider_add_labels() {
  local issue_num="$1"
  local labels="$2"
  glab issue update "$issue_num" -l "$labels" > /dev/null 2>&1 || {
    echo "❌ Failed to add labels to GitLab Issue #$issue_num"
    return 1
  }
}

provider_remove_label() {
  local issue_num="$1"
  local label="$2"
  glab issue update "$issue_num" --unlabel "$label" > /dev/null 2>&1 || true
}

provider_close_issue() {
  local issue_num="$1"
  local comment="${2:-}"
  # glab issue close does not support -m; add a note first if comment is provided
  if [ -n "$comment" ]; then
    glab issue note "$issue_num" -m "$comment" > /dev/null 2>&1 || true
  fi
  glab issue close "$issue_num" || {
    echo "❌ Failed to close GitLab Issue #$issue_num"
    return 1
  }
}

provider_get_issue_body() {
  local issue_num="$1"
  glab issue view "$issue_num" --output json 2>/dev/null | jq -r '.description // empty' || {
    echo "❌ Failed to fetch GitLab Issue #$issue_num body"
    return 1
  }
}

provider_get_issue_state() {
  local issue_num="$1"
  local state
  state=$(glab issue view "$issue_num" --output json 2>/dev/null | jq -r '.state // empty') || {
    echo "❌ Failed to fetch GitLab Issue #$issue_num state"
    return 1
  }
  # GitLab states: opened, closed. Normalize to lowercase.
  # Use exact match to avoid partial replacement
  case "$state" in
    opened|open) echo "open" ;;
    closed) echo "closed" ;;
    *) echo "$state" | tr '[:upper:]' '[:lower:]' ;;
  esac
}

provider_get_issue_json() {
  local issue_num="$1"
  glab issue view "$issue_num" --output json 2>/dev/null | \
    jq '{number: (.iid // .number), title: .title, state: .state, url: .web_url}' || {
    echo "❌ Failed to fetch GitLab Issue #$issue_num"
    return 1
  }
}

provider_list_issues() {
  local label="$1"
  local state="$2"
  local limit="${3:-20}"

  # Build args dynamically to avoid passing empty values
  # glab issue list flags: (none)=opened, -c=closed, -A=all
  local args=(--per-page "$limit" -O json)

  case "$state" in
    closed) args+=(-c) ;;
    all)    args+=(-A) ;;
    # open/opened/empty = default (opened)
  esac

  # Only add label filter if non-empty
  [ -n "$label" ] && args+=(-l "$label")

  glab issue list "${args[@]}" 2>/dev/null | \
    jq '[.[] | {number: (.iid // .number), title: .title, state: .state, url: .web_url}]' || {
    echo "❌ Failed to list GitLab issues"
    return 1
  }
}

provider_update_issue_body() {
  local issue_num="$1"
  local body_file="$2"
  local body_text
  body_text=$(cat "$body_file")
  glab issue update "$issue_num" -d "$body_text" > /dev/null 2>&1 || {
    echo "❌ Failed to update GitLab Issue #$issue_num body"
    return 1
  }
}

# ── MR operations (Merge Request = GitLab's PR) ──

provider_create_pr() {
  local title="$1"
  local body_file="$2"
  local base_branch="$3"

  local body_text
  body_text=$(cat "$body_file")

  local head_branch
  head_branch=$(git branch --show-current)

  glab mr create \
    -t "$title" \
    -d "$body_text" \
    -s "$head_branch" \
    -b "$base_branch" 2>"$errfile" || {
    local exit_code=$?
    cat "$errfile" >&2
    rm -f "$errfile"
    return $exit_code
  }
  rm -f "$errfile"

  # Get the MR URL
  glab mr list --source-branch "$head_branch" --output json 2>/dev/null | \
    jq -r '.[0].web_url // empty'
}

provider_list_prs() {
  local head_branch="$1"
  glab mr list --source-branch "$head_branch" --output json 2>/dev/null | \
    jq -r '.[0].iid // .[0].number // empty' 2>/dev/null || echo ""
}

provider_get_pr_url() {
  local pr_num="$1"
  glab mr view "$pr_num" --output json 2>/dev/null | jq -r '.web_url // empty' || echo ""
}

# ── Label management ──

provider_ensure_label() {
  local label="$1"
  # glab 1.x uses --name flag; failures are non-fatal (label may already exist)
  glab label create --name "$label" --color "ededed" 2>/dev/null || true
  return 0
}

# ── Repository info ──

provider_repo_name_with_owner() {
  glab repo view --output json 2>/dev/null | jq -r '.path_with_namespace // empty' || {
    echo "❌ Failed to get GitLab repository info"
    return 1
  }
}
