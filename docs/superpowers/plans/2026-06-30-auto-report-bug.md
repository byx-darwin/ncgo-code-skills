<!-- Issue: #18 -->
# auto-report-bug 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 ncgo-code-skills 建立自动错误反馈机制，脚本执行出错时自动生成 GitHub Issue 并提交到 `byx-darwin/ncgo-code-skills` 仓库。

**Architecture:** 五层分层架构：捕获层（`_common.sh` 的 `report_error()` + 各脚本 ERR trap）→ 缓冲层（`.cache/bug-reports/pending.json`）→ 检测层（Stop Hook）→ 处理层（`auto-report-bug` SKILL.md）→ 通知层。

**Tech Stack:** Bash, gh CLI, Claude Code Stop Hook, GitHub Issues API

## Global Constraints

- 所有脚本保持 `set -euo pipefail`
- 新 Hook 脚本必须捕获所有异常，失败时静默退出，不影响正常流程
- 错误捕获为 best-effort，stderr 字段可为空
- 去重时已存在或已评估过的 Issue 不重复创建也不追加评论
- 提交目标固定为 `byx-darwin/ncgo-code-skills` GitHub 仓库

## GitHub Issue 规划

**Issue 标题:** feat: auto-report-bug 自动错误反馈技能

**Issue 标签:** enhancement,auto-report-bug,priority:high

**Issue 描述:**
为 ncgo-code-skills 建立自动错误反馈机制。当技能脚本执行出错时，自动捕获错误上下文、通过 LLM 生成分析报告、去重检查后提交 Issue 到 `byx-darwin/ncgo-code-skills` GitHub 仓库。

采用五层分层架构：捕获层 → 缓冲层 → 检测层 → 处理层 → 通知层。

**验收标准:**
- [ ] `_common.sh` 包含 `report_error()` 函数
- [ ] Stop Hook 检测脚本正常工作
- [ ] `auto-report-bug/SKILL.md` 技能定义完整
- [ ] 各脚本已接入错误捕获 trap
- [ ] `.claude/settings.json` 已注册新 Hook
- [ ] 去重逻辑正确（不重复创建/评论）
- [ ] 端到端测试通过（模拟错误 → Issue 创建成功）
- [ ] Hook 本身出错不影响正常流程

**关联:**
- 计划文件: `docs/superpowers/plans/2026-06-30-auto-report-bug.md`
- 设计文档: `docs/superpowers/specs/2026-06-30-auto-report-bug-design.md`

## File Structure

```
ncgo-code-skills/
├── auto-report-bug/                    # 新建
│   └── SKILL.md                        # 技能定义
├── hooks/
│   ├── auto-report-bug.sh              # 新建 — Stop Hook 检测脚本
│   └── auto-smoke-test.sh              # 已有
├── writing-plans-with-issue/
│   └── scripts/
│       ├── _common.sh                  # 修改 — 新增 report_error()
│       ├── create-issue.sh             # 修改 — 接入 ERR trap
│       ├── sync-status.sh              # 修改 — 接入 ERR trap
│       ├── finish-issue.sh             # 修改 — 接入 ERR trap
│       ├── link-pr.sh                  # 修改 — 接入 ERR trap
│       └── list-issues.sh              # 修改 — 接入 ERR trap
├── brainstorm-from-issue/
│   └── scripts/
│       └── fetch-open-issues.sh        # 修改 — 接入 ERR trap
├── .claude/
│   └── settings.json                   # 修改 — 注册新 Hook
└── .cache/
    └── bug-reports/                    # 新建（运行时）
        └── pending.json                # 运行时生成
```

## Tasks

### Task 1: 创建 GitHub Issue

**Description:** 从 "GitHub Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-06-30-auto-report-bug.md
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

### Task 3: 错误捕获层 — 在 `_common.sh` 中添加 `report_error()`

**Description:** 在 `writing-plans-with-issue/scripts/_common.sh` 中新增 `report_error()` 函数，负责收集错误上下文并写入 `pending.json`。

- [ ] **Step 1: 在 `_common.sh` 末尾添加 `report_error()` 函数**

在 `writing-plans-with-issue/scripts/_common.sh` 文件末尾追加：

```bash
# ── 错误报告（auto-report-bug 捕获层） ──

report_error() {
  local script_path="$1"
  local line_number="$2"
  local exit_code="$3"

  # 收集上下文
  local skill_name
  skill_name=$(basename "$(dirname "$(dirname "$script_path")")")
  local script_name
  script_name=$(basename "$script_path")
  local provider
  provider=$(provider_name 2>/dev/null || echo "unknown")
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # 生成错误 ID（基于脚本路径 + 行号的 hash）
  local error_id
  if command -v md5sum &>/dev/null; then
    error_id=$(echo "${script_path}:${line_number}" | md5sum | cut -c1-8)
  elif command -v md5 &>/dev/null; then
    error_id=$(echo "${script_path}:${line_number}" | md5 | cut -c1-8)
  else
    error_id=$(echo "${script_path}:${line_number}" | cksum | cut -c1-8)
  fi

  # 读取 stderr（从脚本设置的 STDERR_FILE 变量）
  local stderr_content=""
  if [ -n "${STDERR_FILE:-}" ] && [ -f "${STDERR_FILE:-}" ]; then
    stderr_content=$(head -c 2000 "$STDERR_FILE" 2>/dev/null || echo "")
  fi

  # 写入缓冲文件
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  [ -z "$repo_root" ] && return 0
  local cache_dir="$repo_root/.cache/bug-reports"
  mkdir -p "$cache_dir"

  cat > "$cache_dir/pending.json" <<EOF
{
  "id": "$error_id",
  "skill": "$skill_name",
  "script": "$script_name",
  "line": $line_number,
  "command": "$BASH_COMMAND",
  "exit_code": $exit_code,
  "stderr": $(echo "$stderr_content" | jq -Rs . 2>/dev/null || echo "\"\""),
  "provider": "$provider",
  "timestamp": "$timestamp"
}
EOF
}
```

- [ ] **Step 2: 验证函数语法正确**

```bash
bash -n writing-plans-with-issue/scripts/_common.sh && echo "✅ 语法正确"
```

- [ ] **Step 3: 提交**

```bash
git add writing-plans-with-issue/scripts/_common.sh
git commit -m "feat: add report_error() to _common.sh for auto-report-bug (#18)"
```

### Task 4: 检测层 — 创建 `hooks/auto-report-bug.sh`

**Description:** 创建 Stop Hook 检测脚本，检查 `pending.json` 是否存在并输出内容供 Claude 读取。

- [ ] **Step 1: 创建 `hooks/auto-report-bug.sh`**

```bash
cat > hooks/auto-report-bug.sh << 'HOOKEOF'
#!/usr/bin/env bash
# auto-report-bug.sh — Stop Hook：检查是否有待报告的错误
# 检测到 pending.json 后输出内容，触发 Claude 介入处理。

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
[ -z "$REPO_ROOT" ] && exit 0

PENDING_FILE="$REPO_ROOT/.cache/bug-reports/pending.json"

# 检查 pending.json 是否存在
if [ ! -f "$PENDING_FILE" ]; then
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐛 检测到脚本错误，正在生成 Bug 报告..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 输出 pending.json 内容供 Claude 读取
cat "$PENDING_FILE"
HOOKEOF
chmod +x hooks/auto-report-bug.sh
```

- [ ] **Step 2: 验证语法**

```bash
bash -n hooks/auto-report-bug.sh && echo "✅ 语法正确"
```

- [ ] **Step 3: 提交**

```bash
git add hooks/auto-report-bug.sh
git commit -m "feat: add auto-report-bug Stop Hook script (#18)"
```

### Task 5: 处理层 — 创建 `auto-report-bug/SKILL.md`

**Description:** 创建 `auto-report-bug` 技能定义文件，描述 LLM 分析错误、去重检查、Issue 创建流程。

- [ ] **Step 1: 创建 `auto-report-bug/SKILL.md`**

```markdown
# auto-report-bug

自动错误反馈技能。当 ncgo-code-skills 脚本执行出错时，自动分析错误并生成 GitHub Issue。

## 触发条件

由 `hooks/auto-report-bug.sh` Stop Hook 触发。当 `.cache/bug-reports/pending.json` 存在时，Hook 输出其内容，Claude 读取后按以下流程执行。

## 流程

**Step 1: 读取 pending.json**

读取 `.cache/bug-reports/pending.json`，提取：`skill`、`script`、`line`、`command`、`exit_code`、`stderr`、`provider`、`timestamp`。

**Step 2: 去重检查**

```bash
SEARCH_QUERY="[auto-report] ${script} L${line}"
EXISTING=$(gh issue list \
  --repo byx-darwin/ncgo-code-skills \
  --search "$SEARCH_QUERY" \
  --state all \
  --json number,title,state \
  --limit 5 2>/dev/null || echo "[]")
```

如果找到匹配的 Issue（无论 open/closed），输出通知并删除 `pending.json`，结束：

```
ℹ️  已存在类似 Issue #N，跳过提交
   https://github.com/byx-darwin/ncgo-code-skills/issues/N
```

**Step 3: 生成 Issue 内容**

基于 pending.json 中的错误信息，生成：

**标题：** `[auto-report] {script} L{line} 执行失败`

**正文：**

```markdown
## 错误信息
- **技能**: {skill}
- **脚本**: {script}:{line}
- **命令**: `{command}`
- **退出码**: {exit_code}
- **平台**: {provider}
- **时间**: {timestamp}

## 错误详情
```
{stderr}
```

## LLM 分析
{基于错误上下文生成的分析：可能原因、建议修复方向}

---
*此 Issue 由 auto-report-bug 技能自动创建*
```

**标签：** `bug,auto-reported,{skill}`

**Step 4: 创建 Issue**

```bash
gh issue create \
  --repo byx-darwin/ncgo-code-skills \
  --title "$TITLE" \
  --body "$BODY" \
  --label "bug,auto-reported,$SKILL_NAME"
```

**Step 5: 清理 + 通知**

```bash
rm -f .cache/bug-reports/pending.json
echo "✅ Bug 报告已提交: Issue #N"
echo "   https://github.com/byx-darwin/ncgo-code-skills/issues/N"
```

## 异常处理

- `gh auth status` 失败 → 记录到 `.cache/bug-reports/failed.log`，保留 `pending.json` 以便下次重试
- `gh issue create` 失败 → 同上
- `pending.json` 格式异常 → 删除无效文件，不阻塞流程
```

- [ ] **Step 2: 提交**

```bash
git add auto-report-bug/SKILL.md
git commit -m "feat: add auto-report-bug SKILL.md (#18)"
```

### Task 6: 各脚本接入错误捕获 trap

**Description:** 为 `writing-plans-with-issue/scripts/` 和 `brainstorm-from-issue/scripts/` 下的各脚本添加 ERR trap 和 stderr 捕获。

- [ ] **Step 1: 为每个脚本添加 trap 代码**

对以下每个脚本，在 `source _common.sh`（或等效）之后、业务逻辑之前插入：

```bash
export STDERR_FILE=$(mktemp /tmp/ncgo-stderr-XXXXXX)
trap 'rm -f "$STDERR_FILE"' EXIT
trap 'report_error "${BASH_SOURCE[0]}" "$LINENO" "$?"' ERR
```

目标脚本列表：
- `writing-plans-with-issue/scripts/create-issue.sh`
- `writing-plans-with-issue/scripts/sync-status.sh`
- `writing-plans-with-issue/scripts/finish-issue.sh`
- `writing-plans-with-issue/scripts/link-pr.sh`
- `writing-plans-with-issue/scripts/list-issues.sh`
- `brainstorm-from-issue/scripts/fetch-open-issues.sh`

**注意：** `brainstorm-from-issue/scripts/fetch-open-issues.sh` 没有 source `_common.sh`，需先添加 source 路径，或内联 `report_error` 的依赖。

- [ ] **Step 2: 验证每个脚本语法**

```bash
for f in writing-plans-with-issue/scripts/create-issue.sh \
         writing-plans-with-issue/scripts/sync-status.sh \
         writing-plans-with-issue/scripts/finish-issue.sh \
         writing-plans-with-issue/scripts/link-pr.sh \
         writing-plans-with-issue/scripts/list-issues.sh \
         brainstorm-from-issue/scripts/fetch-open-issues.sh; do
  bash -n "$f" && echo "✅ $f" || echo "❌ $f"
done
```

- [ ] **Step 3: 提交**

```bash
git add writing-plans-with-issue/scripts/ brainstorm-from-issue/scripts/
git commit -m "feat: wire ERR trap into all scripts for auto-report-bug (#18)"
```

### Task 7: 注册 Hook 配置

**Description:** 在 `.claude/settings.json` 中注册 `auto-report-bug.sh` Stop Hook。

- [ ] **Step 1: 修改 `.claude/settings.json`**

当前内容：
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "command": "bash hooks/auto-smoke-test.sh"
      }
    ]
  }
}
```

修改为：
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "command": "bash hooks/auto-report-bug.sh"
      },
      {
        "matcher": "",
        "command": "bash hooks/auto-smoke-test.sh"
      }
    ]
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add .claude/settings.json
git commit -m "feat: register auto-report-bug Stop Hook (#18)"
```

### Task 8: 端到端测试

**Description:** 模拟脚本错误，验证完整流程：错误捕获 → Hook 检测 → Issue 创建（或去重跳过）。

- [ ] **Step 1: 手动创建 pending.json 模拟错误**

```bash
mkdir -p .cache/bug-reports
cat > .cache/bug-reports/pending.json << 'EOF'
{
  "id": "test1234",
  "skill": "writing-plans-with-issue",
  "script": "create-issue.sh",
  "line": 99,
  "command": "false",
  "exit_code": 1,
  "stderr": "test error output",
  "provider": "github",
  "timestamp": "2026-06-30T00:00:00Z"
}
EOF
```

- [ ] **Step 2: 运行 Hook 脚本，验证检测输出**

```bash
bash hooks/auto-report-bug.sh
# 应输出 pending.json 内容
```

- [ ] **Step 3: 验证去重（再次运行应检测到已有 Issue）**

```bash
# 如果 Task 8 Step 4 成功创建了 Issue，再次模拟相同错误应被去重跳过
bash hooks/auto-report-bug.sh
```

- [ ] **Step 4: 清理测试数据**

```bash
rm -f .cache/bug-reports/pending.json
```

- [ ] **Step 5: 提交（如有测试脚本改动）**

### Task 9: 收尾 — 本地合并后关闭 Issue

**Description:** 开发完成并本地合并到 base 分支后，push 并关闭 Issue。

- [ ] **Step 1: 确保已合并到 base 分支**

```bash
git branch --show-current  # 应该在 main/master 上
```

- [ ] **Step 2: 运行 scripts/finish-issue.sh**

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/finish-issue.sh
```

- [ ] **Step 3: 确认 Issue 已关闭**

```bash
gh issue view "$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo 'already cleaned')"
```
