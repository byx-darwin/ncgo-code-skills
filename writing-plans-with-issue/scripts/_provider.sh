#!/bin/bash
# writing-plans-with-issue: platform detection + provider dispatch
# Source this file to get all provider_* functions for the current platform.
# Other scripts should:
#   source "$(dirname "$0")/_provider.sh"
# After sourcing, PLATFORM is set and all provider_* functions are available.

# Determine script directory for sourcing backends
if [ -z "${PROVIDER_SCRIPT_DIR:-}" ]; then
  PROVIDER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# ── Platform detection ──

detect_platform() {
  # Manual override via environment variable (takes priority)
  if [ -n "${WRITING_PLANS_PLATFORM:-}" ]; then
    echo "$WRITING_PLANS_PLATFORM"
    return
  fi

  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ "$remote_url" == *github.com* ]]; then
    echo "github"
  elif [[ "$remote_url" == *gitee.com* ]]; then
    echo "gitee"
  else
    # Self-hosted GitLab, gitlab.com, and anything else
    echo "gitlab"
  fi
}

PLATFORM=$(detect_platform)

# ── Dispatch to platform backend ──

case "$PLATFORM" in
  github)
    source "$PROVIDER_SCRIPT_DIR/_provider_github.sh"
    ;;
  gitee)
    source "$PROVIDER_SCRIPT_DIR/_provider_gitee.sh"
    ;;
  gitlab)
    source "$PROVIDER_SCRIPT_DIR/_provider_gitlab.sh"
    ;;
  *)
    echo "❌ Unsupported platform: $PLATFORM"
    echo "   Supported: github, gitee, gitlab"
    echo "   Set WRITING_PLANS_PLATFORM=github|gitee|gitlab to override."
    exit 1
    ;;
esac

# ── Utility ──

provider_name() {
  echo "${PLATFORM:-unknown}"
}
