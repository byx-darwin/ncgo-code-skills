# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A collection of Claude Code skills for the complete development lifecycle — plan, Issue tracking, PR automation, and weekly reporting. Designed to work with [Superpowers](https://github.com/obra/Superpowers).

Skills are installed to `~/.claude/skills/ncgo-code/` and invoked via slash commands or natural language triggers.

## Architecture

### Skills Structure

Each skill is a top-level directory containing a `SKILL.md` file (the skill definition) and optionally a `scripts/` subdirectory. Skills are self-contained and discoverable by Claude Code's skill system.

```
<skill-name>/
├── SKILL.md          # Skill definition (triggers, workflow, documentation)
└── scripts/          # Optional: bash scripts invoked by the skill
    ├── _common.sh    # Shared functions (when multiple scripts exist)
    └── <script>.sh
```

### Provider Abstraction Layer

The `writing-plans-with-issue/scripts/` directory contains a platform abstraction layer that enables cross-platform Issue/PR operations:

- **`_provider.sh`** — Platform detection (GitHub/Gitee/GitLab) based on `git remote get-url origin`. Dispatches to the appropriate backend. Can be overridden via `WRITING_PLANS_PLATFORM` env var.
- **`_provider_github.sh`** — GitHub backend using `gh` CLI
- **`_provider_gitee.sh`** — Gitee backend using `curl` + `GITEE_TOKEN`
- **`_provider_gitlab.sh`** — GitLab backend using `glab` CLI
- **`_common.sh`** — Shared functions: logging (`log_info`, `log_warn`, `log_error`), `cd_to_git_root()`, `read_issue_num()`, `report_error()`

All provider scripts implement the same interface: `provider_create_issue`, `provider_add_labels`, `provider_remove_label`, `provider_close_issue`, etc. Scripts source `_provider.sh` to get all `provider_*` functions for the current platform.

### Hooks System

Three Stop hooks run automatically after Claude finishes a response (configured in `.claude/settings.json`):

1. **`hooks/auto-report-bug.sh`** — Checks for `.cache/bug-reports/pending.json`. If found, outputs its contents to trigger Claude's `auto-report-bug` skill flow.
2. **`hooks/sync-readme-check.sh`** — Compares actual directory structure against README's "Structure" section. Outputs a reminder to run `/sync-readme` if they diverge.
3. **`hooks/auto-smoke-test.sh`** — Monitors Provider script files for changes (via md5 hash). When changed, automatically runs `smoke-test.sh` to verify cross-platform compatibility.

### State Files

- **`.claude/gh-issue/current-issue.txt`** — Tracks the current active Issue number (gitignored, local per-developer)
- **`.cache/bug-reports/pending.json`** — Error context written by `report_error()` in `_common.sh`, consumed by `auto-report-bug` hook
- **`.cache/smoke-hashes`** — Hash cache to avoid redundant smoke test runs

## Structure

```
~/.claude/skills/ncgo-code/
├── LICENSE
├── README.md / README.zh-CN.md
├── auto-report-bug/
│   └── SKILL.md
├── brainstorm-from-issue/
│   ├── SKILL.md
│   └── scripts/
│       └── fetch-open-issues.sh        # Fetch open issues for brainstorming
├── check-status/
│   ├── SKILL.md
│   └── scripts/
│       └── check-status.sh             # Check installation status
├── hooks/
│   ├── auto-report-bug.sh
│   ├── auto-smoke-test.sh
│   └── sync-readme-check.sh
├── issue-status/
│   └── SKILL.md
├── sync-readme/
│   ├── SKILL.md
│   └── scripts/
│       └── install.sh                  # Symlink-based installation
├── weekly-report/
│   └── SKILL.md
└── writing-plans-with-issue/
    ├── SKILL.md
    ├── plan-template.md
    └── scripts/
        ├── _common.sh                  # Shared functions + report_error()
        ├── _provider.sh                # Platform abstraction layer
        ├── create-issue.sh             # Parse plan → create issue
        ├── sync-status.sh              # Update issue labels
        ├── finish-issue.sh             # Push + close issue + cleanup
        ├── link-pr.sh                  # Create PR + Closes #N
        ├── list-issues.sh              # List issues by status
        └── smoke-test.sh               # Cross-platform provider smoke test
```

## Commands

### Smoke Test (Provider Verification)

```bash
# Run cross-platform provider smoke test (auto-detects platform)
bash writing-plans-with-issue/scripts/smoke-test.sh

# Force a specific platform
bash writing-plans-with-issue/scripts/smoke-test.sh --platform gitlab

# Gitee defaults to readonly (API write limitation); force write tests:
bash writing-plans-with-issue/scripts/smoke-test.sh --write

# Keep test issue after run (for debugging)
bash writing-plans-with-issue/scripts/smoke-test.sh --keep
```

The smoke test covers 11 core operations: `prerequisites → create → get_body → get_json → get_state → add_labels → remove_label → list → update_body → close → verify_closed`.

### Platform Authentication

```bash
# GitHub
gh auth login && gh auth status

# Gitee
export GITEE_TOKEN="your_token"  # from https://gitee.com/profile/personal_access_tokens

# GitLab
glab auth login && glab auth status
```

## Key Design Decisions

### Plan Structure (writing-plans-with-issue)

Plans must follow a strict structure:
- **Task 1** must be "Create Issue" (runs `create-issue.sh`)
- **Task 2** must be "Sync status to in-progress" (runs `sync-status.sh`)
- **Task 3+** are development tasks
- **Final task** is either "Close Issue" (local merge path) or implicit via PR merge

Exception: Gitee with limited API write permissions uses a simplified template without Issue integration.

### Issue Label Format

Labels must be comma-separated with **no spaces after commas**: `enhancement,go-auth,priority:high`. A leading space causes "label not found" errors on all three platforms.

### Plan File Path Convention

Plans use `[base-dir]` as a placeholder for the skill's absolute path. When generating plans, `[base-dir]` is replaced with the actual skill base directory (e.g., `/Users/xxx/.claude/skills/ncgo-code/writing-plans-with-issue`) because subagents executing the plan don't have skill context.

## Workflow Integration

The complete lifecycle from idea to merged PR:

```
1. brainstorm-from-issue (optional) → classify open issues, brainstorm per category
2. /writing-plans-with-issue → plan file + Issue #N created as Task 1
3. /subagent-driven-development → execute plan tasks, commits reference (#N)
4. /issue-status "in-review" → before PR
5. /finishing-a-development-branch → create PR with "Closes #N"
6. PR merged → GitHub/GitLab auto-closes Issue #N
```

## Testing Notes

- Gitee free-tier accounts have API write restrictions. The provider gracefully handles this — read-only operations work, write operations report clear errors.
- The `auto-smoke-test` hook automatically runs tests when Provider scripts change, using content hashing to avoid redundant runs.
- All scripts use `set -euo pipefail` and `cd_to_git_root()` for safety.
