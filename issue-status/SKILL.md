---
name: issue-status
description: 管理当前 GitHub Issue 的状态标签。当用户说"标记完成"、"开始开发"、"提交审查"、"更新状态"、"update issue status"、"mark done"、"in progress"、"in review" 时使用此技能。自动读取 .claude/gh-issue/current-issue.txt 中的 Issue 编号并更新状态。
---

# Issue Status

## Overview

读取 `.claude/gh-issue/current-issue.txt` 获取当前活跃 Issue 编号，调用 `sync-status.sh` 更新 GitHub Issue 的状态标签。

**依赖：** `writing-plans-with-issue`（提供 `scripts/sync-status.sh`）

## Status Mapping

| 用户自然语言 | 目标状态 |
|------------|---------|
| "开始开发"、"start"、"开始"、"in progress"、"开发中" | `in-progress` |
| "提交审查"、"review"、"in review"、"审查中"、"提 PR 了" | `in-review` |
| "完成"、"done"、"标记完成"、"关闭"、"做完了"、"close" | `done` |

## Workflow

### Step 1: 读取当前 Issue 编号

```bash
cat .claude/gh-issue/current-issue.txt
```

如果文件不存在或为空，提示用户：
> 没有活跃 Issue。请先用 `writing-plans-with-issue` 创建计划并生成 Issue。

### Step 2: 调用 sync-status.sh

将用户意图映射为目标状态后，调用：

```bash
bash [base-dir]/scripts/sync-status.sh <issue-number> <status>
```

> **[base-dir] 替换规则：** `sync-status.sh` 位于 `writing-plans-with-issue` skill 的 scripts 目录。执行时从该 skill 的 base directory 构造绝对路径（如 `~/.claude/skills/ncgo-code/writing-plans-with-issue/scripts/sync-status.sh`）。

### Step 3: 确认结果

```
✅ Issue #N 状态已更新: in-progress → in-review
```

## Fallback

如果 `sync-status.sh` 不可用，直接用 `gh issue edit`：

```bash
# 先移除旧状态标签，再添加新标签
gh issue edit <N> --remove-label "status: in-progress" --remove-label "status: in-review" --remove-label "status: done" --remove-label "status: plan"
gh issue edit <N> --add-label "status: <new-status>"
```
