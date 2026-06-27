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

  if ! glab auth status &> /dev/null; then
    echo "❌ GitLab CLI is not authenticated."
    echo ""
    echo "Run: glab auth login"
    echo "  - For GitLab.com: choose the default host"
    echo "  - For self-hosted: glab auth login --hostname your-gitlab.example.com"
    exit 1
  fi
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

  glab issue create "${args[@]}" 2>/tmp/glab_create_err.txt || {
    local exit_code=$?
    cat /tmp/glab_create_err.txt >&2
    rm -f /tmp/glab_create_err.txt
    return $exit_code
  }
  rm -f /tmp/glab_create_err.txt

  # glab issue create prints the issue URL as the last line
  # Parse it from output (glab prints web URL)
  glab issue list --search "$title" --output json 2>/dev/null | \
    jq -r '.[0].web_url // empty'
}

provider_add_labels() {
  local issue_num="$1"
  local labels="$2"
  glab issue update "$issue_num" --add-label "$labels" > /dev/null 2>&1 || {
    echo "❌ Failed to add labels to GitLab Issue #$issue_num"
    return 1
  }
}

provider_remove_label() {
  local issue_num="$1"
  local label="$2"
  glab issue update "$issue_num" --remove-label "$label" > /dev/null 2>&1 || true
}

provider_close_issue() {
  local issue_num="$1"
  local comment="${2:-}"
  if [ -n "$comment" ]; then
    glab issue close "$issue_num" -m "$comment" || {
      echo "❌ Failed to close GitLab Issue #$issue_num"
      return 1
    }
  else
    glab issue close "$issue_num" || {
      echo "❌ Failed to close GitLab Issue #$issue_num"
      return 1
    }
  fi
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
  echo "$state" | tr '[:upper:]' '[:lower:]' | sed 's/opened/open/'
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

  # Map state: open→opened, closed→closed
  local glab_state="$state"
  [ "$state" = "open" ] && glab_state="opened"

  glab issue list --label "$label" --state "$glab_state" --per-page "$limit" --output json 2>/dev/null | \
    jq '[.[] | {number: (.iid // .number), title: .title, state: .state, url: .web_url}]' || {
    echo "❌ Failed to list GitLab issues"
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
    -b "$base_branch" 2>/tmp/glab_mr_create_err.txt || {
    local exit_code=$?
    cat /tmp/glab_mr_create_err.txt >&2
    rm -f /tmp/glab_mr_create_err.txt
    return $exit_code
  }
  rm -f /tmp/glab_mr_create_err.txt

  # Get the MR URL
  glab mr list --source-branch "$head_branch" --output json 2>/dev/null | \
    jq -r '.[0].web_url // empty'
}

provider_list_prs() {
  local head_branch="$1"
  glab mr list --source-branch "$head_branch" --output json 2>/dev/null | \
    jq -r '.[0].iid // .[0].number // empty' 2>/dev/null || echo ""
}

# ── Label management ──

provider_ensure_label() {
  local label="$1"
  # glab will error if label exists, which is fine
  glab label create "$label" --color "ededed" 2>/dev/null || true
  return 0
}

# ── Repository info ──

provider_repo_name_with_owner() {
  glab repo view --output json 2>/dev/null | jq -r '.namespace.full_path // empty' || {
    echo "❌ Failed to get GitLab repository info"
    return 1
  }
}
