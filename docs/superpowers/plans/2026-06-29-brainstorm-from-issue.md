<!-- Issue: #N -->

# brainstorm-from-issue 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建独立 skill `brainstorm-from-issue`，获取仓库所有 open issues 并按业务领域语义分类，生成分类报告供用户确认，然后逐分类启动 brainstorming，每个分类输出独立 spec 文件。

**Architecture:** 该 skill 由一个 `fetch-open-issues.sh` 脚本和 `SKILL.md` 组成。脚本通过 `source` 复用 `writing-plans-with-issue/scripts/` 中的 Provider 层（`_provider.sh` + 各 backend），自动检测当前平台并获取所有 open issues，输出统一格式的 JSON（包含 number/title/body/labels/url）。`SKILL.md` 引导 Claude 完成分类 → 报告 → 逐分类 brainstorming → spec 输出的完整交互流程。

**Tech Stack:** Bash, jq, Provider Layer (`writing-plans-with-issue/scripts/_provider.sh`), GitHub CLI (`gh`) / Gitee API (`curl` + `jq`) / GitLab CLI (`glab`)

**设计文档:** `docs/superpowers/specs/2026-06-29-brainstorm-from-issue-design.md`

## Global Constraints

- **三平台支持：** GitHub / Gitee / GitLab，通过 Provider 层自动检测
- **代码复用：** `fetch-open-issues.sh` 必须 `source` 引用 `writing-plans-with-issue/scripts/_provider.sh`，不重复 Provider 代码
- **只读操作：** 脚本只读取 Issue，不创建/修改/关闭任何 Issue
- **只关注 open issues：** 不分析 closed issues
- **单仓库：** 不跨仓库聚合
- **jq 兼容：** 使用 jq 1.5+ 语法（`--arg`、`--argjson`、`@json`），不使用 bash 4.4+ 特性（如 `${var@Q}`）

## Issue 规划

**Issue 标题:** feat: brainstorm-from-issue skill — 从 open issues 启动分类 brainstorming

**Issue 标签:** enhancement,brainstorming,priority:medium

**Issue 描述:**
新增独立 skill `brainstorm-from-issue`，获取仓库所有 open issues，按业务领域语义分类，生成分类报告供用户确认，然后逐分类启动 brainstorming，每个分类输出独立 spec 文件。支持功能需求和 Bug 两种 Issue 类型，兼容 GitHub/Gitee/GitLab 三平台。

**验收标准:**
- [ ] `fetch-open-issues.sh` 能正确获取所有 open issues 并输出 JSON
- [ ] JSON 输出包含 number/title/body/labels/url 五个字段
- [ ] SKILL.md 完整描述从分类到 spec 输出的全流程
- [ ] 脚本兼容 GitHub/Gitee/GitLab 三平台（通过 Provider 层）
- [ ] 测试通过：实际运行能获取本仓库 open issues

**关联:**
- 设计文档: `docs/superpowers/specs/2026-06-29-brainstorm-from-issue-design.md`
- 依赖: `writing-plans-with-issue` skill（Provider 层）

## File Structure

```
# 开发目录（repo 根目录内，git 追踪）
brainstorm-from-issue/
├── SKILL.md                         # skill 指令（核心流程：分类 → 报告 → brainstorming → spec 输出）
└── scripts/
    └── fetch-open-issues.sh         # 获取所有 open issues，输出 JSON 数组到 stdout
```

**安装后（symlink 到 ~/.claude/skills/，运行时路径）：**
```
~/.claude/skills/brainstorm-from-issue -> <repo-root>/brainstorm-from-issue   # symlink
```

**跨 skill 依赖（只读引用，不修改）：**
```
~/.claude/skills/writing-plans-with-issue/scripts/    # symlink → <repo-root>/writing-plans-with-issue/scripts/
├── _provider.sh                     # 平台检测 + Provider 入口
├── _common.sh                       # 共享工具函数
├── _provider_github.sh              # GitHub backend
├── _provider_gitee.sh               # Gitee backend
└── _provider_gitlab.sh              # GitLab backend
```

## Tasks

### Task 1: 创建 Issue

**Description:** 从 "Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash /Users/byx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-06-29-brainstorm-from-issue.md
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
bash /Users/byx/.claude/skills/writing-plans-with-issue/scripts/sync-status.sh in-progress
```

- [ ] **Step 2: 确认**

```bash
echo "✅ Issue #$(cat .claude/gh-issue/current-issue.txt) 已标记为 in-progress"
```

### Task 3: 创建 skill 目录结构 + fetch-open-issues.sh

**Description:** 在 repo 根目录创建 `brainstorm-from-issue/` 目录结构，编写 `fetch-open-issues.sh` 脚本。脚本复用 Provider 层获取所有 open issues，输出统一 JSON 格式。完成后创建 symlink 安装到 `~/.claude/skills/`。

- [ ] **Step 1: 创建目录（repo 根目录内）**

```bash
mkdir -p brainstorm-from-issue/scripts
chmod 755 brainstorm-from-issue/scripts
```

- [ ] **Step 2: 编写 fetch-open-issues.sh**

创建 `brainstorm-from-issue/scripts/fetch-open-issues.sh`：

```bash
#!/usr/bin/env bash
# brainstorm-from-issue: fetch-open-issues.sh
# 获取所有 open issues 并输出 JSON 数组到 stdout
# 复用 writing-plans-with-issue 的 Provider 层
# 兼容: GitHub / Gitee / GitLab, Linux / macOS / Windows (Git Bash)

set -euo pipefail

# ── 参数解析 ──
LIMIT=100
while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) LIMIT="${2:?'--limit requires a number'}"; shift 2 ;;
    -h|--help)
      echo "Usage: fetch-open-issues.sh [--limit N]"
      echo "  获取所有 open issues，输出 JSON 数组到 stdout"
      echo "  --limit N   最大获取数量（默认 100）"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Provider 层路径 ──
PROVIDER_DIR="${WRITING_PLANS_PROVIDER_DIR:-$HOME/.claude/skills/writing-plans-with-issue/scripts}"

if [ ! -f "$PROVIDER_DIR/_provider.sh" ]; then
  cat >&2 <<EOF
❌ Provider scripts not found at: $PROVIDER_DIR

writing-plans-with-issue skill is required.
Install it:
  git clone https://github.com/your-org/writing-plans-with-issue ~/.claude/skills/writing-plans-with-issue

Or set WRITING_PLANS_PROVIDER_DIR to the correct path.
EOF
  exit 1
fi

source "$PROVIDER_DIR/_provider.sh"
provider_check_prerequisites || exit 1

if ! command -v jq &>/dev/null; then
  echo "❌ jq is required. Install: brew install jq (macOS) / sudo apt install jq (Linux)" >&2
  exit 1
fi

# ── 进度输出（到 stderr，不污染 stdout JSON） ──
log_progress() { echo "🔄 $1" >&2; }
log_done()    { echo "✅ $1" >&2; }
log_warn()    { echo "⚠️  $1" >&2; }

# ── 获取 open issues 列表 ──
log_progress "获取 open issues（最多 ${LIMIT} 条）..."

issues_list=$(provider_list_issues "" "open" "$LIMIT" 2>/dev/null) || {
  echo "❌ Failed to list open issues" >&2
  exit 1
}

count=$(echo "$issues_list" | jq 'length')

if [ "$count" -eq 0 ]; then
  log_done "没有 open issues"
  echo "[]"
  exit 0
fi

log_progress "共 ${count} 个 open issues，获取详情中..."

# ── 逐个获取 body + labels ──
# provider_list_issues 返回的字段因平台而异：
#   GitHub: {number, title, labels, state, url}  — labels 已有
#   Gitee:  {number, title, state, url}          — 无 labels
#   GitLab: {number, title, state, url}          — 无 labels
# provider_get_issue_json 返回: {number, title, state, url}（均无 labels）
# provider_get_issue_body 返回: 纯文本 body
# 策略：逐 issue 调用两个 API 补齐 body + labels

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

echo "[" > "$tmpfile"
first=true

for i in $(seq 0 $((count - 1))); do
  # 从列表提取基础信息
  issue_num=$(echo "$issues_list" | jq -r ".[$i].number")
  issue_title=$(echo "$issues_list" | jq -r ".[$i].title")
  issue_url=$(echo "$issues_list" | jq -r ".[$i].url")
  issue_labels=$(echo "$issues_list" | jq -c ".[$i].labels // empty")

  log_progress "  [$((i + 1))/${count}] #${issue_num} ${issue_title:0:50}"

  # 获取完整 body（纯文本，由 jq --arg 负责 JSON 转义）
  body=$(provider_get_issue_body "$issue_num" 2>/dev/null || echo "")

  # 如果列表不包含 labels，从 provider_get_issue_json 补齐
  if [ -z "$issue_labels" ]; then
    detail=$(provider_get_issue_json "$issue_num" 2>/dev/null || echo "{}")
    issue_labels=$(echo "$detail" | jq -c '.labels // []')
  fi

  # labels 格式归一化：
  #   GitHub: [{"name":"bug"},{"name":"feature"}] → ["bug","feature"]
  #   Gitee/GitLab (from detail): 可能也是对象数组或字符串数组
  labels_array=$(echo "$issue_labels" | jq -c '
    if type == "array" then
      map(if type == "object" then (.name // "") else . end) | map(select(. != ""))
    else [] end
  ')

  # 组装单条 JSON 对象，追加到 tmpfile
  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$tmpfile"
  fi

  jq -n \
    --argjson num "$issue_num" \
    --arg title "$issue_title" \
    --arg body "$body" \
    --argjson labels "$labels_array" \
    --arg url "$issue_url" \
    '{number: $num, title: $title, body: $body, labels: $labels, url: $url}' >> "$tmpfile"
done

echo "]" >> "$tmpfile"

log_done "共获取 ${count} 个 issues"

# 输出最终 JSON（格式化）
jq '.' "$tmpfile"
```

- [ ] **Step 3: 设置可执行权限**

```bash
chmod +x brainstorm-from-issue/scripts/fetch-open-issues.sh
```

- [ ] **Step 4: 验证脚本语法**

```bash
bash -n brainstorm-from-issue/scripts/fetch-open-issues.sh && echo "✅ 语法检查通过"
```

- [ ] **Step 5: Commit**

```bash
git add brainstorm-from-issue/
git commit -m "feat: add fetch-open-issues.sh for brainstorm-from-issue skill (#N)"
```

- [ ] **Step 6: 创建 symlink 安装到 ~/.claude/skills/**

```bash
ln -s "$(pwd)/brainstorm-from-issue" ~/.claude/skills/brainstorm-from-issue
```

### Task 4: 编写 SKILL.md

**Description:** 编写 `brainstorm-from-issue/SKILL.md`，完整描述 skill 的交互流程：前置检查 → 获取 issues → 分类 → 报告 → 逐分类 brainstorming → spec 输出 → 衔接下一步。

- [ ] **Step 1: 编写 SKILL.md**

创建 `brainstorm-from-issue/SKILL.md`：

```markdown
---
name: brainstorm-from-issue
description: 从仓库 open issues 启动分类 brainstorming。获取所有 open issues，按业务领域语义分类，生成报告供用户确认，然后逐分类 brainstorming 并输出独立 spec 文件。支持功能需求和 Bug。
triggers:
  - brainstorm from issue
  - 从 issue 开始 brainstorming
  - classify issues and brainstorm
  - 分析 open issues 并设计方案
---

# Brainstorm From Issue

从仓库所有 open issues 出发，按业务领域语义分类，逐分类启动 brainstorming 并生成独立 spec 文件。支持功能需求和 Bug 两种 Issue 类型。

**Announce at start:** "正在使用 brainstorm-from-issue 从 open issues 启动分类 brainstorming"

## Prerequisites（首次运行一次性检查）

> 脚本自动检测平台（GitHub/Gitee/GitLab），无需手动配置。

```bash
# 1. Provider 脚本是否存在
PROVIDER_DIR="$HOME/.claude/skills/writing-plans-with-issue/scripts"
[ -f "$PROVIDER_DIR/_provider.sh" ] || {
  echo "⚠️ writing-plans-with-issue skill 未安装"
  echo "安装后重试"
  exit 1
}

# 2. 平台认证（按当前仓库自动检测）
#    GitHub: gh auth status
#    Gitee:  echo $GITEE_TOKEN
#    GitLab: glab auth status
```

## Workflow

```
1. 前置检查
   ├─ Provider 脚本是否存在
   └─ 平台认证通过

2. 获取 Issues
   └─ 运行 fetch-open-issues.sh → JSON 数组
      └─ 若无 open issues → 提示"没有 open issues"并退出

3. 分类归纳
   └─ Claude 读取 JSON，按业务领域语义分组
      └─ 输出分类报告表格

4. 用户确认分类
   └─ 用户可调整（移动 Issue、合并/拆分分类）
      └─ 确认后进入下一步

5. 逐分类 Brainstorming
   └─ 对每个分类：
      ├─ 将该分类下所有 Issue 内容注入为上下文
      ├─ 按 brainstorming 流程推进
      │  ├─ 功能需求 → 提问 → 方案对比 → 设计
      │  └─ Bug → 根因分析 → 修复方案
      ├─ 生成 spec → docs/superpowers/specs/YYYY-MM-DD-<分类名>-design.md
      └─ 用户审查 spec → 修改或确认

6. 衔接下一步
   └─ 所有 spec 完成后提示：
      "是否为某个 spec 创建实现计划？调用 /writing-plans-with-issue"
```

## Step 2: 获取 Issues

```bash
bash ~/.claude/skills/brainstorm-from-issue/scripts/fetch-open-issues.sh
```

输出 JSON 数组到 stdout，每个元素包含 `{number, title, body, labels, url}`。

如果无 open issues，脚本输出 `[]`，提示用户并退出。

## Step 3: 分类归纳

读取 JSON，按以下维度对 issues 进行语义分组：

1. **业务领域：** 哪些 issues 涉及同一功能模块或业务场景？
2. **类型：** 功能需求（enhancement/feature）还是 Bug？
3. **关联性：** 哪些 issues 解决同一底层问题？

### 分类报告格式

输出以下表格供用户确认：

```
📋 共 N 个 open issues，归纳为 M 个业务分类：

| # | 分类 | Issues | 类型 | 摘要 |
|---|------|--------|------|------|
| 1 | [分类名] | #A, #B, #C | 功能/Bug/混合 | [一句话摘要] |
| 2 | [分类名] | #D, #E | 功能 | [一句话摘要] |
| ... | | | | |

如需调整（移动 Issue、合并/拆分分类），请告诉我。确认后开始逐个 brainstorming。
```

**类型判断规则：**
- `labels` 含 `bug`/`bugfix`/`defect` → Bug
- `labels` 含 `enhancement`/`feature` → 功能
- 均无 → 从 `title` 和 `body` 语义判断
- 混合分类标注为"混合"

## Step 4: 用户确认

展示报告后等待用户反馈。用户可以：
- 将某个 Issue 移到另一个分类
- 合并两个分类
- 拆分一个分类为多个
- 直接确认

确认后进入逐分类 brainstorming。

## Step 5: 逐分类 Brainstorming

对每个分类执行独立的 brainstorming 会话：

### 5.1 注入上下文

将该分类下所有 Issue 的完整内容（title + body + labels）作为初始上下文。示例：

```
--- Issue #10: feat: 支持 Gitee 平台 ---
[Issue body...]

--- Issue #7: feat: 标签自动同步 ---
[Issue body...]
```

### 5.2 Brainstorming 流程

- **功能类 Issue：** 调用 `superpowers:brainstorming` 标准流程（提问 → 方案对比 → 设计）
- **Bug 类 Issue：** 先分析根因（复现步骤、影响范围），再设计修复方案
- **混合分类：** 先处理 Bug，再处理功能需求

每个分类的 brainstorming 是独立交互——Claude 提问，用户回答，逐步明确方案。

### 5.3 输出 Spec

brainstorming 完成后，生成 spec 文件：

```
docs/superpowers/specs/YYYY-MM-DD-<分类名>-design.md
```

Spec 格式参考已有设计文档（如 `2026-06-29-brainstorm-from-issue-design.md`）。

用户审查 spec 后可要求修改，确认后再进入下一个分类。

## Step 6: 衔接下一步

所有分类的 spec 完成后，输出汇总：

```
✅ 所有分类 brainstorming 完成，生成以下 spec：

1. docs/superpowers/specs/YYYY-MM-DD-class-a-design.md
2. docs/superpowers/specs/YYYY-MM-DD-class-b-design.md
3. docs/superpowers/specs/YYYY-MM-DD-class-c-design.md

下一步（可选）：
  为某个 spec 创建实现计划：
  /writing-plans-with-issue docs/superpowers/specs/YYYY-MM-DD-xxx-design.md
```

## 不做的事

- **不自动调用 `writing-plans-with-issue`** — 只提示，由用户决定
- **不创建/修改 Issue** — 只读
- **不分析 closed issues** — 只关注 open
- **不跨仓库聚合** — 只分析当前仓库
```

- [ ] **Step 2: Commit**

```bash
git add brainstorm-from-issue/SKILL.md
git commit -m "docs: add SKILL.md for brainstorm-from-issue (#N)"
```

### Task 5: 集成测试

**Description:** 在实际仓库上运行 `fetch-open-issues.sh`，验证输出格式正确，验证 SKILL.md 流程可行。

- [ ] **Step 1: 运行 fetch-open-issues.sh 获取本仓库 open issues**

```bash
bash ~/.claude/skills/brainstorm-from-issue/scripts/fetch-open-issues.sh
```

- [ ] **Step 2: 验证 JSON 输出**

确认输出包含 `number`、`title`、`body`、`labels`、`url` 五个字段：

```bash
bash ~/.claude/skills/brainstorm-from-issue/scripts/fetch-open-issues.sh | jq '.[0] | keys'
# 期望输出: ["body", "labels", "number", "title", "url"]
```

- [ ] **Step 3: 验证 labels 格式**

labels 应为字符串数组：

```bash
bash ~/.claude/skills/brainstorm-from-issue/scripts/fetch-open-issues.sh | jq '.[0].labels'
# 期望: ["enhancement", "priority:high"] 或 []
```

- [ ] **Step 4: 测试 --limit 参数**

```bash
bash ~/.claude/skills/brainstorm-from-issue/scripts/fetch-open-issues.sh --limit 1 | jq 'length'
# 期望: 1
```

- [ ] **Step 5: Commit 修复（如有）**

```bash
# 如发现问题，修复后提交
git add brainstorm-from-issue/
git commit -m "fix: resolve issues found during integration testing (#N)"
```

### Task 6: 收尾 — 本地合并后关闭 Issue

**Description:** 开发完成并本地合并到 base 分支后，push 并关闭 Issue。

- [ ] **Step 1: 确保已合并到 base 分支**

```bash
git branch --show-current  # 应该在 main/master 上
```

- [ ] **Step 2: 运行 scripts/finish-issue.sh**

```bash
bash /Users/byx/.claude/skills/writing-plans-with-issue/scripts/finish-issue.sh
```

- [ ] **Step 3: 确认 Issue 已关闭且 checkbox 已打钩**

```bash
gh issue view "$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo 'already cleaned')"
```
