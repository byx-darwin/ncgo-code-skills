# SDD-Pipeline — Claude Code Agent Teams 原生方案

**日期:** 2026-06-26
**状态:** 方案已定向 — 采用 Claude Code 原生 Agent Teams

## 决策

放弃独立 `launch-sdd.sh` 脚本方案，改为接入 **Claude Code 原生 Agent Teams**（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）。

理由：
- Agent Teams 已内置：任务拆分、子 Agent 派发、git worktree 隔离、消息通信、任务状态追踪
- 不需要自己造调度器、并发控制、文件隔离
- SDD 的「拆任务→派发→审查→修复→提交」流水线正是 Agent Teams 的标准场景

## 目标流程

```
用户: "我要实现 XXX 功能"
  │
  ▼
writing-plans-with-issue (当前 session)
  ├─ 生成计划文件 docs/superpowers/plans/xxx.md
  ├─ 执行 Task 1: create-issue.sh → Issue #N
  └─ 输出下一步指令
  │
  ▼
用户复制指令，开新 Claude Code + Agent Teams session:
  $ CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions
  > /subagent-driven-development docs/superpowers/plans/xxx.md
  │
  ▼
SDD Controller (Team Lead)
  ├─ Task 3  → Teammate A (sonnet)  → Review → fix → ✅
  ├─ Task 4  → Teammate B (sonnet)  → Review → fix → ✅
  ├─ Task 5  → Teammate C (haiku)   → Review → ✅
  ├─ ...
  └─ Task 11 → 最终审查 (opus) → fix → finish-issue.sh → ✅
```

## SKILL.md 改造点

当前末尾输出：

```
✅ 计划已生成: docs/superpowers/plans/xxx.md

现在可以开始开发了:
  /subagent-driven-development docs/superpowers/plans/xxx.md
```

改为：

```
✅ 计划已生成: docs/superpowers/plans/xxx.md
✅ Issue #N 已创建

下一步 — 新窗口执行（Agent Teams 模式）:
  1. 打开新终端窗口
  2. 运行: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude
  3. 输入: /subagent-driven-development docs/superpowers/plans/xxx.md

或者单 Agent 模式（当前窗口）:
  /subagent-driven-development docs/superpowers/plans/xxx.md
```

## 改造项

| # | 文件 | 改动 |
|---|------|------|
| 1 | `SKILL.md` | 末尾 Execution Handoff 部分改为双路径提示（Agent Teams / 单 Agent） |
| 2 | `SKILL.md` | 新增一节说明 Agent Teams 并行加速效果 |
| 3 | `plan-template.md` | 验证命令加入 Agent Teams 环境变量的检测提醒 |
| 4 | 无需新增脚本 | `launch-sdd.sh` 废弃，不提交 |

## Agent Teams 下的 SDD 加速估算

| 场景 | 串行时间 | Agent Teams 并行 | 加速比 |
|------|---------|-----------------|--------|
| Tasks 3-6（go-auth，4 个独立包） | ~3min | ~1min（4 agent 并行） | ~3x |
| Tasks 7-8（go-middleware，依赖 Task 5-6） | ~4min | ~3min（先后派发） | ~1.3x |
| Task 9（依赖 Task 3,5,7,8） | ~5min | ~5min（串行依赖） | 1x |
| Task 10-11（最终验证） | ~3min | ~3min | 1x |

保守估计：通过并行执行独立任务，**SDD 总耗时从 ~15min 降到 ~8min**。

## 备注

- 本方案不增加新脚本或新 Agent，只改 SKILL.md 文档和 plan-template.md 提示语
- Agent Teams 目前需要 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 环境变量，属实验性功能
- 后续 Agent Teams 正式 GA 后可简化为一行命令
