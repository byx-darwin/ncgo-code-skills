# ncgo-code

Claude Code 开发工作流技能集 — 从计划编写到 GitHub Issue 创建、状态跟踪、PR 自动化，完整编码闭环。

## 安装

```bash
git clone https://github.com/byx-darwin/ncgo-code-skills.git ~/.claude/skills/ncgo-code
```

## 技能

### writing-plans-with-issue

创建包含 GitHub Issue 规划的技术计划。Task 1 自动创建 Issue，Task 2 同步状态，后续所有 commit 可引用 `(#N)`。

```
触发词: "创建实现计划"、"写实现方案"、"write implementation plan"
```

生成计划后输出：

```
✅ 计划已生成: docs/superpowers/plans/xxx.md

现在可以开始开发了（推荐在新窗口/工作树中执行）：
  /subagent-driven-development docs/superpowers/plans/xxx.md
```

### issue-status

管理当前活跃 Issue 的状态标签。

```
触发词: "标记完成"、"开始开发"、"提交审查"、"mark done"、"in review"
```

状态映射:

| 自然语言 | 状态 |
|---------|------|
| "开始开发"、"start" | `in-progress` |
| "提交审查"、"review" | `in-review` |
| "完成"、"done" | `done` |

## 依赖

- [Superpowers](https://github.com/anthropics/superpowers) — 提供 `writing-plans`、`subagent-driven-development`、`finishing-a-development-branch`
- [GitHub CLI](https://cli.github.com/) (`gh`) — Issue 和 PR 操作

## 完整开发闭环

```
writing-plans-with-issue          → 生成计划 + Task 1 创建 Issue
    ↓
/subagent-driven-development      → 执行开发任务（在新窗口）
    ↓
finishing-a-development-branch    → 创建 PR + Closes #N
    ↓
PR 合并                           → Issue 自动关闭 ✅
```

## 许可证

MIT
