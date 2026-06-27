#!/bin/bash
# writing-plans-with-issue: GitHub backend (gh CLI)
# Provides all provider_* functions for GitHub.com repositories.

# ── Prerequisites ──

provider_check_prerequisites() {
  if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is required."
    echo "Install: https://cli.github.com/"
    echo "  macOS:  brew install gh"
    echo "  Linux:  https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    exit 1
  fi

  if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI is not authenticated."
    echo ""
    echo "Run: gh auth login"
    echo "  - Choose GitHub.com"
    echo "  - Choose HTTPS"
    echo "  - Use browser or paste token"
    exit 1
  fi
}

# ── Issue operations ──

provider_create_issue() {
  local title="$1"
  local body_file="$2"
  local labels="$3"
  local milestone="${4:-}"

  local args=(--title "$title" --body-file "$body_file")
  [ -n "$labels" ] && args+=(--label "$labels")
  [ -n "$milestone" ] && args+=(--milestone "$milestone")

  gh issue create "${args[@]}" 2>/tmp/gh_create_err.txt || {
    local exit_code=$?
    cat /tmp/gh_create_err.txt >&2
    rm -f /tmp/gh_create_err.txt
    return $exit_code
  }
  rm -f /tmp/gh_create_err.txt
}

provider_add_labels() {
  local issue_num="$1"
  local labels="$2"
  gh issue edit "$issue_num" --add-label "$labels" || {
    echo "❌ Failed to add labels to Issue #$issue_num"
    return 1
  }
}

provider_remove_label() {
  local issue_num="$1"
  local label="$2"
  gh issue edit "$issue_num" --remove-label "$label" 2>/dev/null || true
}

provider_close_issue() {
  local issue_num="$1"
  local comment="${2:-}"
  if [ -n "$comment" ]; then
    gh issue close "$issue_num" --comment "$comment" || {
      echo "❌ Failed to close Issue #$issue_num"
      return 1
    }
  else
    gh issue close "$issue_num" || {
      echo "❌ Failed to close Issue #$issue_num"
      return 1
    }
  fi
}

provider_get_issue_body() {
  local issue_num="$1"
  gh issue view "$issue_num" --json body -q '.body' 2>/dev/null || {
    echo "❌ Failed to fetch Issue #$issue_num body"
    return 1
  }
}

provider_get_issue_state() {
  local issue_num="$1"
  local state
  state=$(gh issue view "$issue_num" --json state -q '.state' 2>/dev/null) || {
    echo "❌ Failed to fetch Issue #$issue_num state"
    return 1
  }
  # Normalize to lowercase
  echo "$state" | tr '[:upper:]' '[:lower:]'
}

provider_get_issue_json() {
  local issue_num="$1"
  gh issue view "$issue_num" --json number,title,state,url 2>/dev/null || {
    echo "❌ Failed to fetch Issue #$issue_num"
    return 1
  }
}

provider_list_issues() {
  local label="$1"
  local state="$2"
  local limit="${3:-20}"
  gh issue list --label "$label" --state "$state" --limit "$limit" --json number,title,labels,state,url 2>/dev/null || {
    echo "❌ Failed to list issues"
    return 1
  }
}

# ── PR operations ──

provider_create_pr() {
  local title="$1"
  local body_file="$2"
  local base_branch="$3"

  gh pr create --title "$title" --body-file "$body_file" --base "$base_branch" 2>/tmp/gh_pr_create_err.txt || {
    local exit_code=$?
    cat /tmp/gh_pr_create_err.txt >&2
    rm -f /tmp/gh_pr_create_err.txt
    return $exit_code
  }
  rm -f /tmp/gh_pr_create_err.txt
}

provider_list_prs() {
  local head_branch="$1"
  gh pr list --head "$head_branch" --json number --jq '.[0].number' 2>/dev/null || echo ""
}

# ── Label management ──

provider_ensure_label() {
  local label="$1"
  if ! gh label view "$label" &>/dev/null; then
    gh label create "$label" --color "ededed" 2>/dev/null || {
      echo "⚠️  Failed to create label '$label'"
      return 1
    }
    echo "✅ Created label: $label"
  fi
  return 0
}

# ── Repository info ──

provider_repo_name_with_owner() {
  gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || {
    echo "❌ Failed to get repository info"
    return 1
  }
}
