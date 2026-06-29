# ncgo-code

Claude Code skills for the complete development lifecycle — plan, Issue tracking, PR automation, and weekly reporting. Designed to work with [Superpowers](https://github.com/obra/Superpowers).

## Install

```bash
# 1. Superpowers
git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers

# 2. ncgo-code
git clone https://github.com/byx-darwin/ncgo-code-skills.git ~/.claude/skills/ncgo-code

# 3. GitHub CLI
brew install gh && gh auth login
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
├── brainstorm-from-issue/
│   ├── SKILL.md
│   └── scripts/
│       └── fetch-open-issues.sh
├── issue-status/
│   └── SKILL.md
├── weekly-report/
│   └── SKILL.md
└── writing-plans-with-issue/
    ├── SKILL.md
    ├── plan-template.md
    └── scripts/
        ├── create-issue.sh      # Parse plan → create issue
        ├── sync-status.sh       # Update issue labels
        ├── finish-issue.sh      # Push + close issue + cleanup
        ├── link-pr.sh           # Create PR + Closes #N
        └── list-issues.sh       # List issues by status
```

## License

MIT — see [LICENSE](LICENSE)
