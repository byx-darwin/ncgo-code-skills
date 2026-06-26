<!-- Issue: #1 -->
# Launch SDD — Skill Output 改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 writing-plans-with-issue skill 的计划生成后输出从单路径提示改为双路径（Agent Teams / 单 Agent），并新增 Agent Teams 并行加速说明，同时在 plan-template.md 的 Validation 区加入 Agent Teams 环境变量检测提醒。

**Architecture:** 纯文档改动，仅涉及 SKILL.md 和 plan-template.md 两个 Markdown 文件。不新增脚本，不修改任何 .sh 文件。改动量小（~30 行新增），风险极低。

**Tech Stack:** Markdown

## Global Constraints

- 仅修改 `SKILL.md` 和 `plan-template.md`，不新增脚本，不删除现有文件
- `launch-sdd.sh` 已废弃，不提交（本计划不涉及）
- 保持现有 Skill 结构和所有其他部分不变
- Agent Teams 环境变量名必须精确：`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- 加速估算表格数据直接引用设计文档 `launch-sdd-design.md` 中的数值

---

## GitHub Issue 规划

**Issue 标题:** feat: writing-plans-with-issue 支持 Agent Teams 双路径输出

**Issue 标签:** enhancement,writing-plans-with-issue,priority:medium

**Issue 描述:**
改造 writing-plans-with-issue skill 的计划生成输出，从单一 `/subagent-driven-development` 提示变为双路径提示（Agent Teams 并行模式 + 单 Agent 模式），并在 SKILL.md 中新增 Agent Teams 并行加速效果说明节，在 plan-template.md 的 Validation 区加入 Agent Teams 环境变量检测提醒。此改动让用户在拿到计划后清楚知道如何用 Agent Teams 获得 2-3x 加速。

**验收标准:**
- [ ] 所有任务完成
- [ ] 测试通过（N/A — 纯文档改动，人工审查即可）
- [ ] 代码审查通过
- [ ] 文档更新
- [ ] SKILL.md 末尾 Execution Handoff 输出为双路径格式
- [ ] SKILL.md 新增 Agent Teams 并行加速说明节（含加速估算表）
- [ ] plan-template.md Validation 区新增 Agent Teams 环境变量检测提醒
- [ ] plan-template.md 中 `[base-dir]` 占位符已替换为实际路径

**关联:**
- 计划文件: `docs/superpowers/plans/2026-06-26-launch-sdd-skill-update.md`
- 里程碑: v1.3.0
- 依赖: 无

---

## File Structure

```
writing-plans-with-issue/
├── SKILL.md              # Modify: 新增 Agent Teams 并行加速节 + 验证 Execution Handoff 双路径
├── plan-template.md      # Modify: Validation 区新增 Agent Teams 环境变量检测提醒
└── docs/
    └── launch-sdd-design.md  # 参考设计文档（不修改）
```

---

## Tasks

> **Task 编号规则（硬性）：Task 1 = 创建 Issue，Task 2 = 同步状态为 in-progress。Task 3+ 为开发任务，最后一个为收尾任务。**

### Task 1: 创建 GitHub Issue

**Description:** 从 "GitHub Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-06-26-launch-sdd-skill-update.md
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
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/sync-status.sh in-progress
```

- [ ] **Step 2: 确认**

```bash
echo "✅ Issue #$(cat .claude/gh-issue/current-issue.txt) 已标记为 in-progress"
```

---

### Task 3: SKILL.md — 新增 Agent Teams 并行加速节

**Files:**
- Modify: `/Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md`

**Interfaces:**
- Consumes: 设计文档 `launch-sdd-design.md` 中的加速估算数据
- Produces: SKILL.md 中新增的 "## Agent Teams 并行加速" 节

- [ ] **Step 1: 在 SKILL.md 的 Workflow 节之前插入 "Agent Teams 并行加速" 节**

插入位置：`## Workflow（完整闭环）` 之前，`## Plan Document Structure` 之后。

插入内容：

```markdown
## Agent Teams 并行加速

当使用 Agent Teams 模式执行计划时，独立任务可并行派发给多个 subagent，显著缩短总耗时。

### 加速估算

以下为典型 SDD 流水线的串行 vs 并行对比（基于 `launch-sdd-design.md` 中的实测数据）：

| 场景 | 串行时间 | Agent Teams 并行 | 加速比 |
|------|---------|-----------------|--------|
| 独立包任务（4 个 agent 并行） | ~3min | ~1min | ~3x |
| 有依赖的任务（先后派发） | ~4min | ~3min | ~1.3x |
| 串行依赖任务 | ~5min | ~5min | 1x |
| 最终验证 | ~3min | ~3min | 1x |

保守估计：通过并行执行独立任务，**SDD 总耗时从 ~15min 降到 ~8min**。

### 使用方式

```bash
# Agent Teams 模式（推荐）
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions
> /subagent-driven-development docs/superpowers/plans/xxx.md

# 单 Agent 模式（兼容）
> /subagent-driven-development docs/superpowers/plans/xxx.md
```

> **注意：** Agent Teams 目前需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 环境变量，属实验性功能。后续正式 GA 后可简化为一行命令。
```

- [ ] **Step 2: 验证插入位置和内容正确**

```bash
grep -n "Agent Teams 并行加速" /Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md
grep -n "使用方式" /Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add /Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md
git commit -m "docs(skill): add Agent Teams parallel acceleration section to SKILL.md (#N)"
```

---

### Task 4: plan-template.md — Validation 区新增 Agent Teams 环境变量检测提醒

**Files:**
- Modify: `/Users/baoyx/.claude/skills/writing-plans-with-issue/plan-template.md`

**Interfaces:**
- Consumes: 无
- Produces: plan-template.md Validation 区新增的 env var 检测脚本

- [ ] **Step 1: 在 plan-template.md 的 Validation 节开头（Build Verification 之前）插入 Agent Teams 环境变量检测**

插入位置：`### Build Verification` 之前。

插入内容：

```markdown
### Agent Teams Readiness Check

> 如果计划使用 Agent Teams 模式执行，运行此检测确认环境就绪。

```bash
# 检测 Agent Teams 环境变量是否已设置
if [ -n "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]; then
  echo "✅ Agent Teams 已启用 (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)"
else
  echo "⚠️ Agent Teams 未启用 — 独立任务将串行执行"
  echo "   启用方式: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions"
fi
```
```

- [ ] **Step 2: 将 plan-template.md 中的 `[base-dir]` 占位符替换为实际路径**

```bash
# 检查是否还有未替换的 [base-dir]
grep -n '\[base-dir\]' /Users/baoyx/.claude/skills/writing-plans-with-issue/plan-template.md
```

如果仍有 `[base-dir]`，替换为 `/Users/baoyx/.claude/skills/writing-plans-with-issue`。

- [ ] **Step 3: Commit**

```bash
git add /Users/baoyx/.claude/skills/writing-plans-with-issue/plan-template.md
git commit -m "feat(template): add Agent Teams readiness check to validation section (#N)"
```

---

### Task 5: SKILL.md — 验证 Execution Handoff 双路径输出

**Files:**
- Modify: `/Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md`（仅验证，可能无需改动）

**Description:** 确认 SKILL.md 的 Workflow 区（Step 3 末尾输出）已包含双路径提示（Agent Teams + 单 Agent）。

- [ ] **Step 1: 检查当前 Workflow 区输出是否已是双路径格式**

```bash
grep -A 15 '方式 1.*Agent Teams\|Agent Teams 模式' /Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md
```

当前 Workflow 区（第 224-231 行）已包含双路径输出：
```
方式 1 — Agent Teams 模式（推荐，独立任务并行执行）:
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions
  > /subagent-driven-development docs/superpowers/plans/YYYY-MM-DD-feature-name.md

方式 2 — 单 Agent 模式（当前窗口）:
  /subagent-driven-development docs/superpowers/plans/YYYY-MM-DD-feature-name.md
```

如果已存在 → **跳过本 task，标记为完成**。如果缺失 → 补充。

- [ ] **Step 2: （如需要）Commit**

```bash
# 仅当有改动时
git add /Users/baoyx/.claude/skills/writing-plans-with-issue/SKILL.md
git commit -m "docs(skill): verify dual-path execution handoff in SKILL.md (#N)"
```

---

### Task 6: 收尾 — 本地合并后关闭 Issue

**Description:** 开发完成并合并到 base 分支后，push + 同步验收 checkbox + 关闭 Issue。

> 如选择 PR 路径（Option 2），则用 `link-pr.sh` 代替。

- [ ] **Step 1: 确保已合并到 base 分支**

```bash
git branch --show-current  # 应该在 main/master 上
```

- [ ] **Step 2: 运行 scripts/finish-issue.sh**（自动同步 checkbox、push、关闭 Issue、清理 state）

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/finish-issue.sh
```

---

## Validation

### Agent Teams Readiness Check

> 如果计划使用 Agent Teams 模式执行，运行此检测确认环境就绪。

```bash
# 检测 Agent Teams 环境变量是否已设置
if [ -n "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]; then
  echo "✅ Agent Teams 已启用 (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=$CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)"
else
  echo "⚠️ Agent Teams 未启用 — 独立任务将串行执行"
  echo "   启用方式: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions"
fi
```

### Content Verification

```bash
# 验证 SKILL.md 新增节存在
grep -q "Agent Teams 并行加速" ~/.claude/skills/writing-plans-with-issue/SKILL.md && echo "✅ SKILL.md 加速节 OK"

# 验证 plan-template.md 检测脚本存在
grep -q "Agent Teams Readiness Check" ~/.claude/skills/writing-plans-with-issue/plan-template.md && echo "✅ plan-template.md 检测脚本 OK"

# 验证无残留 [base-dir] 占位符
! grep -q '\[base-dir\]' ~/.claude/skills/writing-plans-with-issue/plan-template.md && echo "✅ 无残留占位符"
```

---

## Completion Checklist

- [ ] All tasks completed
- [ ] All tests passing (N/A — doc change)
- [ ] Code review approved
- [ ] Documentation updated
- [ ] GitHub Issue updated（验收 checkbox 已打钩，finish-issue.sh 自动同步）
- [ ] SKILL.md 新增 "Agent Teams 并行加速" 节
- [ ] plan-template.md 新增 "Agent Teams Readiness Check"
- [ ] Merged to main

---

## Notes

- Task 5 可能已由之前的修改完成（SKILL.md Workflow 区已有双路径输出），执行时先验证再决定是否跳过
- 所有改动都是 Markdown 文档，无需编译或测试
- `launch-sdd.sh` 脚本不创建、不修改、不提交（设计文档明确废弃）
- `[base-dir]` 已替换为实际路径 `/Users/baoyx/.claude/skills/writing-plans-with-issue`
