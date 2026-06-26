---
name: writing-plans-with-issue
description: 创建包含 GitHub Issue 规划的技术计划/实现方案。当用户需要为新功能、重构或开发任务创建实现计划、写实现方案、制定开发计划、write implementation plan 时使用此技能。它会生成带有 GitHub Issue 集成的完整计划文件 — Issue 创建是计划中的第一个任务，确保在开始编码之前获得 Issue 编号。
---

# Writing Plans with Issue Integration

## Overview

在创建技术计划时，将 GitHub Issue 创建和状态同步作为计划的前两个任务，确保在编写任何代码之前就拿到 Issue #N，后续所有 commit 都可以引用它。

**Announce at start:** "正在使用 writing-plans-with-issue 创建包含 GitHub Issue 集成的实现计划"

**配套 skill：** 
- `issue-status` — 手动管理 Issue 状态（标记开发中/审查中/完成）

## Prerequisites（首次运行一次性设置）

> **跨平台兼容：** 脚本兼容 Linux、macOS、Windows（需要 Git Bash 或 WSL）。

首次使用前，确认以下三项即可：

```bash
# 1. Superpowers 已安装？
ls ~/.claude/skills/superpowers/using-superpowers/ 2>/dev/null || {
  echo "⚠️ Superpowers 未安装，运行:"
  echo "git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers/"
  exit 1
}

# 2. gh CLI 已认证？
gh auth status &>/dev/null || {
  echo "⚠️ gh 未认证，运行: gh auth login"
  exit 1
}

# 3. 项目目录就绪（静默创建，不报错）
mkdir -p docs/superpowers/plans .claude/gh-issue
grep -q '.claude/gh-issue/' .gitignore 2>/dev/null || echo '.claude/gh-issue/' >> .gitignore
```

> 三项全部通过后说明环境就绪。后续调用本 skill 不需要重复检查，直接进入计划编写。

## Path Convention

> **脚本路径规则（遵循 skill 标准模式）：**
> - SKILL.md 内部引用本 skill 自带脚本时使用相对路径（如 `scripts/create-issue.sh`），模型执行时从 skill base directory 自动解析
> - 生成计划文件时，需将脚本路径写为绝对路径：**skill base directory + `/scripts/xxx.sh`**
>   - skill base directory 在 skill 调用时由系统告知（如 `/Users/xxx/.claude/skills/writing-plans-with-issue`）
>   - 计划文件中的 bash 命令需要用绝对路径，因为 subagent 执行时没有 skill context

## Bundled Scripts

| 脚本 | 用途 | 对应阶段 |
|------|------|---------|
| `scripts/create-issue.sh` | 从计划文件解析 Issue 信息并创建 GitHub Issue | Task 1 |
| `scripts/sync-status.sh` | 更新 GitHub Issue 的状态标签 | Task 2 / PR 阶段 |
| `scripts/link-pr.sh` | 创建 Pull Request 并关联 Issue（Closes #N） | 开发完成后 |

---

## Plan Document Structure

按以下顺序编写计划文件，不可跳过任何部分。

### 1. Issue 引用标记（计划文件第一行）

```markdown
<!-- Issue: #N -->  ← 在 Task 1 执行后由 create-issue.sh 自动添加
```

### 2. Standard Header

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [一句话描述目标]

**Architecture:** [2-3 句架构说明]

**Tech Stack:** [关键技术/库]

## Global Constraints

[项目级约束条件]
```

### 3. GitHub Issue 规划（MANDATORY）

定义即将创建的 Issue 的元数据。这些信息将被 `create-issue.sh` 脚本解析。

- **`**Issue 标题:**` 和 `**Issue 标签:**` 必须在同一行**（脚本按行解析）。
- **标签用逗号分隔，逗号后不要有空格**（gh CLI 要求）。

```markdown
## GitHub Issue 规划

**Issue 标题:** feat: [功能名称]

**Issue 标签:** enhancement,[module],priority:high

**Issue 描述:**
[2-3 句话描述这个功能的目的和价值。可以多行。]

**验收标准:**
- [ ] 所有任务完成
- [ ] 测试通过（单元测试 + 集成测试）
- [ ] 代码审查通过
- [ ] 文档更新
- [ ] 覆盖率 > 80%

**关联:**
- 计划文件: `docs/superpowers/plans/YYYY-MM-DD-feature-name.md`
- 里程碑: [可选]
- 依赖: [可选]
```

### 4. File Structure

用 ASCII tree 列出新增和修改的文件路径。

### 5. Tasks — Issue 相关任务必须排在最前

**硬性规则：Task 1 = 创建 GitHub Issue，Task 2 = 同步状态为 in-progress。** 后续所有开发任务（Task 3+）的 commit message 都需引用 `#N`。

```markdown
## Tasks

### Task 1: 创建 GitHub Issue

**Description:** 从 "GitHub Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash [base-dir]/scripts/create-issue.sh docs/superpowers/plans/[计划文件名].md
```

- [ ] **Step 2: 验证 Issue 已创建**

```bash
cat .claude/gh-issue/current-issue.txt
gh issue view "$(cat .claude/gh-issue/current-issue.txt)"
```

### Task 2: 同步 Issue 状态为 in-progress

**Description:** 将 Issue 状态更新为 `status: in-progress`，表示开发已开始。

- [ ] **Step 1: 运行 scripts/sync-status.sh**

```bash
bash [base-dir]/scripts/sync-status.sh in-progress
```

- [ ] **Step 2: 确认**

```bash
echo "✅ Issue #$(cat .claude/gh-issue/current-issue.txt) 已标记为 in-progress"
```

### Task 3: [开发任务 1]
### Task N: [后续开发任务]
```

> **生成计划时的路径替换：** 上述模板中的 `[base-dir]` 必须替换为本 skill 的 base directory（skill 调用时系统告知，如 `/Users/xxx/.claude/skills/writing-plans-with-issue`）。计划文件由 subagent 执行，需要绝对路径。

---

## Workflow（完整闭环）

```
1. Prerequisites 检查
   ├─ Superpowers 已安装？ → 否 → 提示安装后退出
   ├─ gh CLI 已认证？     → 否 → 提示安装后退出
   └─ 项目目录已就绪？

2. 探索需求（可选）
   └─ superpowers:brainstorming

3. 创建计划文件（本 skill）
   ├─ 写出 Standard Header + Issue 规划 + File Structure
   ├─ 写出 Tasks（Task 1 = 创建 Issue, Task 2 = 同步状态）
   ├─ 将 [base-dir] 替换为 skill base directory，写入计划文件
   └─ 输出提示：

```
✅ 计划已生成: docs/superpowers/plans/YYYY-MM-DD-feature-name.md

现在可以开始开发了（推荐在新窗口/工作树中执行）：
  /subagent-driven-development docs/superpowers/plans/YYYY-MM-DD-feature-name.md
```

4. 执行 Task 1: 创建 GitHub Issue
   └─ create-issue.sh
      ├─ 解析 "GitHub Issue 规划" 部分
      ├─ gh issue create → Issue #N
      ├─ 保存编号到 .claude/gh-issue/current-issue.txt
      └─ 在计划文件顶部注入 <!-- Issue: #N -->

5. 执行 Task 2: 同步状态为 in-progress
   └─ sync-status.sh in-progress
      └─ 移除旧状态标签 → 添加 status: in-progress

6. 执行 Task 3+: 开发实现
   └─ superpowers:subagent-driven-development
      └─ 所有 commit message 引用 #N

7. 完成开发 → 创建 PR
   └─ superpowers:finishing-a-development-branch
      └─ link-pr.sh → PR (Closes #N) + Issue status: in-review
         └─ PR 合并 → GitHub 自动关闭 Issue #N ✅
```

---

## 关键设计决策

### 为什么 Task 1 必须是创建 Issue？

1. **Commit 引用**：拿到 Issue #N 后，每个 commit message 可以引用 `(#N)`，GitHub 自动关联
2. **可追踪性**：从第一个 commit 起就被 Issue 追踪，不遗漏任何变更
3. **不依赖记忆**：作为显式任务而非隐藏步骤，执行者不会跳过

### 为什么 Issue 标签逗号后不要有空格？

`gh issue create --label "enhancement, go-auth"` → 被解析为 ` go-auth`（前导空格），导致 "label not found"。正确写法是 `enhancement,go-auth`。`create-issue.sh` 已内置 `tr -d ' '` 防御性处理。

### 为什么 current-issue.txt 要 gitignore？

`.claude/gh-issue/current-issue.txt` 是本地状态文件（记录当前会话的 Issue 编号）。多人协作时每人应有自己的 Issue，不应提交到仓库。计划文件中的 `<!-- Issue: #N -->` 才是持久化的关联记录。

---

## Troubleshooting

### Superpowers 未安装

```bash
# 检查
ls ~/.claude/skills/superpowers/using-superpowers/

# 安装：将 superpowers 克隆到 skills 目录
git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers/
```

### gh CLI 未安装或未认证

```bash
brew install gh         # macOS
gh auth login           # 认证
gh auth status          # 验证
```

### Issue 创建失败 — 标签不存在

检查标签格式（逗号后无空格）：
```markdown
✅ **Issue 标签:** enhancement,go-auth,priority:high
❌ **Issue 标签:** enhancement, go-auth, priority:high
```

`create-issue.sh` 会自动创建不存在的标签，但如果标签名本身拼写错误，需手动删除：`gh label delete "错误标签名"`

### .claude/gh-issue/current-issue.txt 未找到

Task 1 未执行或执行失败，重新运行（将 `[base-dir]` 替换为 skill base directory）：
```bash
bash [base-dir]/scripts/create-issue.sh docs/superpowers/plans/[计划文件].md
```

### 已有 Issue 时想为新计划创建新 Issue

删除旧的 `current-issue.txt` 后再执行 Task 1：
```bash
rm .claude/gh-issue/current-issue.txt
# 然后执行 Task 1
```

## Version History

- v1.0.0 (2026-06-26) — 初始版本
  - 计划结构：Standard Header + Issue 规划 + File Structure + Tasks
  - Task 1 = 创建 GitHub Issue，Task 2 = 同步状态为 in-progress
  - Prerequisites 检查（Superpowers + gh CLI + 项目目录）
  - 跨平台脚本（macOS/Linux/Windows Git Bash），含自动安装引导
  - 脚本路径采用 `[base-dir]` 占位符 + 生成时替换模式
  - `create-issue.sh` 含重复创建防护
  - `link-pr.sh` 自动检测 main/master 分支
  - 配套 skill: `issue-status`（手动状态管理）
