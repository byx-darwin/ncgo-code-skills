# ncgo-code

Claude Code development workflow skills — plan generation with GitHub Issue integration, status tracking, and PR automation for the full coding lifecycle.

## Install

```bash
git clone https://github.com/byx-darwin/ncgo-code-skills.git ~/.claude/skills/ncgo-code
```

## Skills

### writing-plans-with-issue

Generates implementation plans with built-in GitHub Issue creation. Task 1 creates the Issue (#N), Task 2 syncs status, all subsequent commits reference `(#N)`.

```
Triggers: "create implementation plan", "write plan", "写实现方案"
```

After plan generation:

```
✅ Plan created: docs/superpowers/plans/xxx.md

Ready to develop (recommend new window/worktree):
  /subagent-driven-development docs/superpowers/plans/xxx.md
```

### issue-status

Updates the status label of the current active Issue.

```
Triggers: "mark done", "start dev", "in review", "标记完成", "提交审查"
```

Status mapping:

| Natural language | Label |
|-----------------|-------|
| "start", "开始开发" | `in-progress` |
| "review", "提交审查" | `in-review` |
| "done", "完成" | `done` |

## Prerequisites

- [Superpowers](https://github.com/anthropics/superpowers) — `writing-plans`, `subagent-driven-development`, `finishing-a-development-branch`
- [GitHub CLI](https://cli.github.com/) (`gh`) — Issue & PR operations

## Workflow

```
writing-plans-with-issue          → Plan + Task 1 create Issue
    ↓
/subagent-driven-development      → Execute tasks (new window)
    ↓
finishing-a-development-branch    → PR + Closes #N
    ↓
PR merged                         → Issue auto-closed ✅
```

## License

MIT
