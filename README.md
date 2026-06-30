# ncgo-code

Claude Code skills for the complete development lifecycle — plan, Issue tracking, PR automation, and weekly reporting. Designed to work with [Superpowers](https://github.com/obra/Superpowers).

## Install

```bash
# 1. Superpowers
git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers

# 2. ncgo-code
git clone https://github.com/byx-darwin/ncgo-code-skills.git ~/.claude/skills/ncgo-code

# 3. Platform CLI (choose one)
#    GitHub:  brew install gh && gh auth login
#    GitLab:  brew install glab && glab auth login
#    Gitee:   export GITEE_TOKEN="your_token"  (from https://gitee.com/profile/personal_access_tokens)
#             (Gitee 免费账号 API 写入可能受限，仅支持读操作)
```

## Skills

### `writing-plans-with-issue` (ncgo-code)

Generates implementation plans with Issue creation as Task 1. The Issue number `#N` is obtained *before* any code is written — every commit references `(#N)`.

```
"Create an implementation plan for the new feature"
```

### `issue-status` (ncgo-code)

Updates the status label on the active Issue. Reads `.claude/gh-issue/current-issue.txt`.

```
"mark done" / "submit for review" / "start dev"
```

### `weekly-report` (ncgo-code)

Scans one or more Git repositories and generates a structured weekly development report. Supports custom cut-off times and multi-project aggregation, with plain-text output (no tables).

```
"generate this week's report" / "weekly report for project-a project-b, cut off Friday 18:00"
```

### `brainstorm-from-issue` (ncgo-code)

Fetches all open issues in the current repo, classifies them by business domain, and guides brainstorming per category. Each category produces an independent spec file. Supports feature requests and bugs.

```
"brainstorm from issues" / "classify and analyze open issues"
```

### `auto-report-bug` (ncgo-code)

Automatically reports script errors. When a skill script fails, captures error context, generates a GitHub Issue with LLM analysis, and submits it after dedup check. Triggered by Stop Hook.

```
(automatic — triggered on script error)
```

### `sync-readme` (ncgo-code)

Syncs README documentation with actual directory structure. Detects added/removed skills or scripts and updates both English and Chinese README files.

```
"sync readme" / "update directory structure in README"
```

## Full Workflow

This is the complete cycle from idea to merged PR, with all skills involved at each step.

```
Step 1 — Brainstorm (optional)
  superpowers:brainstorming
  → Clarify requirements before writing a plan.

Step 2 — Create plan + Issue
  /writing-plans-with-issue
  → Plan file with Issue metadata
  → Task 1: create Issue (#N)
  → Task 2: sync status to in-progress

  Output:
  ✅ Plan created: docs/superpowers/plans/xxx.md
  Ready to develop:
    /subagent-driven-development docs/superpowers/plans/xxx.md

Step 3 — Isolate workspace (recommended)
  superpowers:using-git-worktrees
  → git worktree add -b feat/xxx ../xxx-worktree main

Step 4 — Execute tasks
  /subagent-driven-development docs/superpowers/plans/xxx.md
  → Runs each task, commits with (#N) references

Step 5 — Manage status
  /issue-status "in-review"   ← before PR
  /issue-status "done"        ← after merge

Step 6 — Create PR
  superpowers:finishing-a-development-branch
  → Select "Create PR"
  → link-pr.sh: PR with "Closes #N"

Step 7 — Merge
  PR merged → GitHub auto-closes Issue #N ✅
```

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
│       └── fetch-open-issues.sh
├── hooks/
│   ├── auto-report-bug.sh
│   ├── auto-smoke-test.sh
│   └── sync-readme-check.sh
├── issue-status/
│   └── SKILL.md
├── weekly-report/
│   └── SKILL.md
├── sync-readme/
│   └── SKILL.md
└── writing-plans-with-issue/
    ├── SKILL.md
    ├── plan-template.md
    └── scripts/
        ├── _common.sh             # Shared functions + report_error()
        ├── _provider.sh           # Platform abstraction layer
        ├── create-issue.sh        # Parse plan → create issue
        ├── sync-status.sh         # Update issue labels
        ├── finish-issue.sh        # Push + close issue + cleanup
        ├── link-pr.sh             # Create PR + Closes #N
        ├── list-issues.sh         # List issues by status
        └── smoke-test.sh          # Cross-platform provider smoke test
```

## Testing

```bash
# Run cross-platform provider smoke test
bash writing-plans-with-issue/scripts/smoke-test.sh

# Gitee defaults to readonly (API write limitation)
# Use --write to force full test if you have a token with write permissions
```

## Platform Support

| Platform | Read | Write | CLI |
|----------|:----:|:-----:|-----|
| GitHub | ✅ | ✅ | `gh` |
| GitLab (self-hosted) | ✅ | ✅ | `glab` |
| Gitee | ✅ | ⚠️ limited | `curl` + `GITEE_TOKEN` |

> **Gitee note:** Free-tier accounts may have API write restrictions. The provider and smoke test gracefully handle this — read-only operations work correctly, write operations report clear error messages with workarounds.

## License

MIT — see [LICENSE](LICENSE)
