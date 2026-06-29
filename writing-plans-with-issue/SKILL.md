---
name: writing-plans-with-issue
description: 创建包含 Issue 集成的实现计划（支持 GitHub/Gitee/GitLab）。当用户需要为新功能、重构或开发任务创建实现计划、写实现方案、制定开发计划 时使用此技能。它会生成带有 Issue 集成的完整计划文件 — Issue 创建是计划中的第一个任务，确保在开始编码之前获得 Issue 编号。
---

# Writing Plans with Issue Integration

## Overview

在创建技术计划时，将 Issue 创建和状态同步作为计划的前两个任务，确保在编写任何代码之前就拿到 Issue #N，后续所有 commit 都可以引用它。支持 GitHub / Gitee / GitLab 三平台，通过 Provider 层自动检测。

**Announce at start:** "正在使用 writing-plans-with-issue 创建包含 Issue 集成的实现计划"

**配套 skill：** 
- `issue-status` — 手动管理 Issue 状态（标记开发中/审查中/完成）

## Prerequisites（首次运行一次性设置）

> **跨平台兼容：** 脚本兼容 Linux、macOS、Windows（需要 Git Bash 或 WSL）。支持 GitHub / Gitee / GitLab 三平台。

首次使用前，确认以下三项即可：

```bash
# 1. Superpowers 已安装？（检查两个可能位置：skills 目录 或 plugins 缓存）
(ls ~/.claude/skills/superpowers/using-superpowers/ 2>/dev/null || \
 ls ~/.claude/plugins/cache/superpowers-marketplace/superpowers/*/skills/using-superpowers/ 2>/dev/null) >/dev/null 2>&1 || {
  echo "⚠️ Superpowers 未安装，运行:"
  echo "git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers/"
  exit 1
}

# 2. 平台认证（按当前仓库自动检测，或设置 WRITING_PLANS_PLATFORM 手动覆盖）
#    GitHub: gh auth status
#    Gitee:  echo $GITEE_TOKEN
#    GitLab: glab auth status

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
| `scripts/create-issue.sh` | 从计划文件解析 Issue 信息并创建 Issue（GitHub/Gitee/GitLab） | Task 1 |
| `scripts/sync-status.sh` | 更新 Issue 的状态标签 | Task 2 / PR 阶段 |
| `scripts/link-pr.sh` | 创建 Pull Request 并关联 Issue（Closes #N） | 开发完成后（PR 路径） |
| `scripts/finish-issue.sh` | 本地合并后收尾：push + 关闭 Issue + 清理 state | 开发完成后（本地合并路径） |
| `scripts/smoke-test.sh` | 跨平台 Provider 冒烟测试（读写全流程） | 开发 / 调试 |

---

## 测试（冒烟测试）

修改 Provider 代码后，运行跨平台冒烟测试验证：

```bash
# 在当前仓库运行（自动检测平台）
bash scripts/smoke-test.sh

# 强制指定平台
bash scripts/smoke-test.sh --platform gitlab

# Gitee 默认只测读操作（API 写入受限），加 --write 强制完整测试
bash scripts/smoke-test.sh --write
```

测试覆盖 11 项核心操作：`prerequisites → create → get_body → get_json → get_state → add_labels → remove_label → list → update_body → close → verify_closed`。

**平台默认行为：**

| 平台 | 默认模式 | 测试数 |
|------|---------|:-----:|
| GitHub | 完整读写 | 11 |
| GitLab | 完整读写 | 11 |
| Gitee | 只读（`--readonly`） | 2 |

Gitee 因免费账号 API 写入受限，默认跳过写操作。如有完整权限的 Token，用 `--write` 强制测试写入。

---

Gitee 免费账号的 API 写入可能受限。**生成计划前，必须先检测当前平台的 Issue 写入能力**，选择对应的计划模板。

### 检测方法

```bash
# 检测当前平台
PLATFORM=$(git remote get-url origin 2>/dev/null | grep -q 'gitee.com' && echo "gitee" || echo "other")

# 如果是 Gitee，检测 Issue 创建是否可用
if [ "$PLATFORM" = "gitee" ]; then
  if [ -z "${GITEE_TOKEN:-}" ]; then
    echo "⚠️ GITEE_TOKEN 未设置，将使用简化计划模板（无 Issue 关联）"
    USE_SIMPLE_TEMPLATE=1
  else
    # 快速测试：尝试创建一个小 issue 看返回
    TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "https://gitee.com/api/v5/repos/OWNER/REPO/issues" \
      -H "Authorization: Bearer ${GITEE_TOKEN}" \
      -H "Content-Type: application/json" \
      -d '{"title":"test","body":"test"}' 2>/dev/null)
    if [ "$TEST_RESULT" = "404" ]; then
      echo "⚠️ Gitee API 写入受限（免费账号限制），将使用简化计划模板"
      USE_SIMPLE_TEMPLATE=1
    fi
  fi
fi
```

### 两种计划模板

| 场景 | 模板 | 包含 |
|------|------|------|
| GitHub / GitLab / Gitee(有写入) | **完整模板** | Issue 规划 + Task 1(创建) + Task 2(同步) + 开发任务 + 收尾(关闭) |
| Gitee(写入受限) | **简化模板** | ~~Issue 规划~~ + 直接开发任务（无 Issue 关联） |

### 简化模板（Gitee 写入受限时使用）

```markdown
<!-- Gitee: Issue 写入受限，使用简化模板 -->

# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [一句话描述目标]

**Architecture:** [2-3 句架构说明]

**Tech Stack:** [关键技术/库]

**平台说明:** Gitee 免费账号 API 写入受限，本计划不包含 Issue 自动创建/关闭步骤。

## Global Constraints

[项目级约束条件]

## File Structure

[文件结构]

## Tasks

### Task 1: [开发任务 1]

**Description:** [描述]

- [ ] **Step 1:** ...

### Task 2: [开发任务 2]

...

> **注意：** Gitee 平台限制，Issue 需在网页端手动创建和管理。
```

### 流程调整

```
1. 检测平台 → Gitee + 写入受限？
   ├─ 否 → 使用完整模板（含 Issue 规划 + Task 1/2 + 收尾）
   └─ 是 → 使用简化模板（无 Issue 关联）
        ├─ 计划文件顶部注释 `<!-- Gitee: Issue 写入受限 -->`
        ├─ 跳过 `## Issue 规划` 章节
        ├─ 不生成 Task 1(创建 Issue)、Task 2(同步状态)、收尾任务
        └─ 提示用户: "Gitee 平台限制，请在网页端手动管理 Issue"
```

---

## Plan Document Structure

> **⚠️ 硬性约束 — 违反任何一条即视为无效计划：**
> 1. **必须包含 `## Issue 规划` 章节**（位于 Standard Header 和 File Structure 之间）
>    - **例外：** Gitee 写入受限时使用简化模板，跳过此章节
> 2. **Task 1 必须是"创建 Issue"，Task 2 必须是"同步状态为 in-progress"**
>    - **例外：** Gitee 写入受限时，Task 1 直接开始第一个开发任务
> 3. **Task 3 才能开始第一个开发任务**（仅限完整模板）
> 4. 跳过上述任何部分 = 计划无效，必须重新生成
>    - **例外：** 详见上方「Gitee 写入能力检测」章节

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

### 3. Issue 规划（MANDATORY）

定义即将创建的 Issue 的元数据。这些信息将被 `create-issue.sh` 脚本解析。

- **`**Issue 标题:**` 和 `**Issue 标签:**` 必须在同一行**（脚本按行解析）。
- **标签用逗号分隔，逗号后不要有空格**（各平台 CLI/API 统一要求）。

```markdown
## Issue 规划

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

> **🚨 硬性规则 — 不可违反：**
> - Task 1 **必须**是"创建 Issue"（不可用开发任务替代）
> - Task 2 **必须**是"同步状态为 in-progress"
> - Task 3 **才能**开始第一个开发任务
> - 违反此规则 = 计划结构错误，必须重写

后续所有开发任务（Task 3+）的 commit message 都需引用 `#N`。

```markdown
## Tasks

### Task 1: 创建 Issue

**Description:** 从 "Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash [base-dir]/scripts/create-issue.sh docs/superpowers/plans/[计划文件名].md
```

- [ ] **Step 2: 验证 Issue 已创建**

```bash
cat .claude/gh-issue/current-issue.txt
# 在对应平台查看 Issue（GitHub 示例）：
# gh issue view "$(cat .claude/gh-issue/current-issue.txt)"
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

### Task N+1: 收尾 — 本地合并后关闭 Issue

**Description:** 开发完成并本地合并到 base 分支后，push 并关闭 Issue。

> **注意：** 如果选择 PR 路径（Option 2），则不需要此任务 — `link-pr.sh` 会在 PR body 中包含 `Closes #N`，PR 合并时平台自动关闭 Issue。

- [ ] **Step 1: 确保已合并到 base 分支**

```bash
git branch --show-current  # 应该在 main/master 上
```

- [ ] **Step 2: 运行 scripts/finish-issue.sh（含验收 checkbox 同步）**

`finish-issue.sh` 会自动：
1. 将 Issue `## 验收标准` 下的 `- [ ]` 替换为 `- [x]`
2. Push base 分支
3. 关闭 Issue
4. 清理 local state

```bash
bash [base-dir]/scripts/finish-issue.sh
```

- [ ] **Step 3: 确认 Issue 已关闭且 checkbox 已打钩**

```bash
# GitHub:
gh issue view "$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo 'already cleaned')"
# Gitee:
curl -s "https://gitee.com/api/v5/repos/{owner}/{repo}/issues/$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo '0')"
# GitLab:
glab issue view "$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo 'already cleaned')" --output json
```

> **生成计划时的路径替换：** 上述模板中的 `[base-dir]` 必须替换为本 skill 的 base directory（skill 调用时系统告知，如 `/Users/xxx/.claude/skills/writing-plans-with-issue`）。计划文件由 subagent 执行，需要绝对路径。

---

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

---

## Workflow（完整闭环）

```
1. Prerequisites 检查
   ├─ Superpowers 已安装？ → 否 → 提示安装后退出
   ├─ 平台认证通过？       → 否 → 提示对应平台认证后退出
   │   ├─ GitHub: gh auth status
   │   ├─ Gitee: echo $GITEE_TOKEN
   │   └─ GitLab: glab auth status
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
✅ Issue #N 已创建

下一步执行（二选一）：

方式 1 — Agent Teams 模式（推荐，独立任务并行执行）:
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --dangerously-skip-permissions
  > /subagent-driven-development docs/superpowers/plans/YYYY-MM-DD-feature-name.md

方式 2 — 单 Agent 模式（当前窗口）:
  /subagent-driven-development docs/superpowers/plans/YYYY-MM-DD-feature-name.md
```

4. 执行 Task 1: 创建 Issue
   └─ create-issue.sh
      ├─ 解析 "Issue 规划" 部分
      ├─ provider_create_issue → Issue #N
      ├─ 保存编号到 .claude/gh-issue/current-issue.txt
      └─ 在计划文件顶部注入 <!-- Issue: #N -->

5. 执行 Task 2: 同步状态为 in-progress
   └─ sync-status.sh in-progress
      └─ 移除旧状态标签 → 添加 status: in-progress

6. 执行 Task 3+: 开发实现
   └─ superpowers:subagent-driven-development
      └─ 所有 commit message 引用 #N

7. 完成开发 → 选择集成路径
   ├─ Option 1: 本地合并
   │  └─ finishing-a-development-branch (merge locally)
   │     └─ finish-issue.sh → push base 分支 + 关闭 Issue #N + 清理 state ✅
   │
   └─ Option 2: 创建 PR
      └─ link-pr.sh → PR (Closes #N) + Issue status: in-review
         └─ PR 合并 → 平台自动关闭 Issue #N ✅

8. （可选）执行回顾
   └─ /code-review → 分析代码问题 + 流程摩擦点
      └─ 输出 skill 改进建议 → 用户确认后应用
```

---

## 关键设计决策

### 为什么 Task 1 必须是创建 Issue？

1. **Commit 引用**：拿到 Issue #N 后，每个 commit message 可以引用 `(#N)`，平台自动关联
2. **可追踪性**：从第一个 commit 起就被 Issue 追踪，不遗漏任何变更
3. **不依赖记忆**：作为显式任务而非隐藏步骤，执行者不会跳过

### 为什么 Issue 标签逗号后不要有空格？

以 GitHub 为例：`gh issue create --label "enhancement, go-auth"` → 被解析为 ` go-auth`（前导空格），导致 "label not found"。Gitee API 和 GitLab `glab` 也有类似问题。正确写法是 `enhancement,go-auth`。`create-issue.sh` 已内置 `tr -d ' '` 防御性处理。

### 为什么 current-issue.txt 要 gitignore？

`.claude/gh-issue/current-issue.txt` 是本地状态文件（记录当前会话的 Issue 编号）。多人协作时每人应有自己的 Issue，不应提交到仓库。计划文件中的 `<!-- Issue: #N -->` 才是持久化的关联记录。

---

## Troubleshooting

### Superpowers 未安装

```bash
# 检查（两个可能位置）
ls ~/.claude/skills/superpowers/using-superpowers/ 2>/dev/null || \
ls ~/.claude/plugins/cache/superpowers-marketplace/superpowers/*/skills/using-superpowers/ 2>/dev/null

# 安装方式 1：git clone 到 skills 目录
git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers/

# 安装方式 2：通过 Superpowers marketplace（推荐）
# 参考: https://github.com/obra/Superpowers#installation
```

### 平台认证失败

**GitHub:**
```bash
brew install gh         # macOS
gh auth login           # 认证
gh auth status          # 验证
```

**Gitee:**
```bash
# 1. 安装 jq（API 调用依赖）
brew install jq              # macOS
sudo apt install jq          # Debian/Ubuntu

# 2. 在 Gitee 后台生成 Token: https://gitee.com/profile/personal_access_tokens
#    权限勾选：issues、pulls、labels、repo

# 3. 设置环境变量
export GITEE_TOKEN="你的token"
```

**GitLab:**
```bash
brew install glab       # macOS
glab auth login         # GitLab.com
glab auth login --hostname gitlab.mycorp.com  # 自建实例
glab auth status        # 验证
```

### Issue 创建失败 — 标签不存在

检查标签格式（逗号后无空格）：
```markdown
✅ **Issue 标签:** enhancement,go-auth,priority:high
❌ **Issue 标签:** enhancement, go-auth, priority:high
```

`create-issue.sh` 会自动创建不存在的标签，但如果标签名本身拼写错误，需手动在对应平台删除。

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

---

## 计划输出前自检清单（必须执行）

在输出最终计划文件之前，**必须逐项验证以下清单**。任何一项不通过 = 计划无效，必须修正后再输出。

```
✅ 自检清单：
[ ] 1. 计划文件包含 `## Issue 规划` 章节？
[ ] 2. `## Issue 规划` 中包含 `**Issue 标题:**` 和 `**Issue 标签:**`？
[ ] 3. 标签格式正确（逗号分隔，无空格）？
[ ] 4. Task 1 是"创建 Issue"（不是开发任务）？
[ ] 5. Task 2 是"同步状态为 in-progress"（不是开发任务）？
[ ] 6. 第一个开发任务从 Task 3 开始？
[ ] 7. 最后一个 Task 是收尾任务（关闭 Issue 或 PR 关联）？
[ ] 8. 所有脚本路径已从 `[base-dir]` 替换为实际绝对路径？
```

**如果任何一项为 ❌，立即修正后再输出计划文件。不要跳过此步骤。**

---

## Version History

- v1.4.0 (2026-06-29) — Issue 关联强制约束 + 模板同步
  - SKILL.md 新增"计划输出前自检清单"（8 项验证，防止跳过 Issue 关联部分）
  - SKILL.md Issue 规划和 Task 1/2 增加醒目警告框（⚠️/🚨 标记）
  - plan-template.md 全面更新：移除所有 "GitHub" 引用，改为平台无关描述
  - plan-template.md 验证步骤补充 Gitee/GitLab 命令对照
- v1.3.0 (2026-06-29) — 多平台文档同步
  - SKILL.md 全面更新：所有 "GitHub Issue" 引用改为平台无关描述
  - Prerequisites 认证检查覆盖 GitHub / Gitee / GitLab 三平台
  - Troubleshooting 新增 Gitee（Token + jq）和 GitLab（glab）认证指引
  - 代码示例补充 Gitee/GitLab 命令对照
- v1.2.0 (2026-06-26) — 多角色审查 + 质量修复
  - 新增 `_common.sh` 共享库，消除 ~400 行重复代码
  - 统一所有脚本 `set -euo pipefail` + `cd_to_git_root()`
  - `sync-status.sh` 标签操作改为先加后删（非原子→原子）
  - `finish-issue.sh` 新增 Issue body 空检查、已关闭检查、验收 checkbox 同步
  - `link-pr.sh` push 失败改为 exit 1（不再 warn + continue）
  - `create-issue.sh` stderr 分离、标签空格保留、status: plan 失败显式 warning
  - `plan-template.md` 新增 Task 1/2/收尾占位，标签示例修正
- v1.1.0 (2026-06-26) — 本地合并路径支持
  - 新增 `finish-issue.sh`：本地合并后 push + 关闭 Issue + 清理 state
  - 计划模板新增最终任务（收尾 — 本地合并后关闭 Issue）
  - Workflow 图区分 Option 1（本地合并）和 Option 2（PR）两条路径
  - 解决 `finishing-a-development-branch` 不感知 Issue 的问题
- v1.0.0 (2026-06-26) — 初始版本
  - 计划结构：Standard Header + Issue 规划 + File Structure + Tasks
  - Task 1 = 创建 Issue，Task 2 = 同步状态为 in-progress
  - Prerequisites 检查（Superpowers + 平台认证 + 项目目录）
  - 跨平台脚本（macOS/Linux/Windows Git Bash），含自动安装引导
  - 脚本路径采用 `[base-dir]` 占位符 + 生成时替换模式
  - `create-issue.sh` 含重复创建防护
  - `link-pr.sh` 自动检测 main/master 分支
  - 配套 skill: `issue-status`（手动状态管理）
