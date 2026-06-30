# auto-report-bug 设计文档

**日期**：2026-06-30  
**状态**：设计完成，待实施  
**目标**：为 ncgo-code-skills 建立自动错误反馈机制，脚本执行出错时自动生成 GitHub Issue

---

## 背景

ncgo-code-skills 包含多个 shell 脚本（`create-issue.sh`、`sync-status.sh` 等），在执行过程中可能因网络问题、API 变更、权限不足等原因失败。目前错误只输出到终端，无法追踪和系统性修复。

**目标**：建立一个自动反馈机制 —— 脚本出错时自动捕获上下文、调用 LLM 总结、去重检查后提交 Issue 到 `byx-darwin/ncgo-code-skills` GitHub 仓库。

---

## 需求

| # | 需求 | 决策 |
|---|------|------|
| 1 | 触发方式 | 自动检测（脚本执行出错时） |
| 2 | Issue 内容 | 标准信息 + LLM 总结分析 |
| 3 | 实现方式 | 独立技能 `auto-report-bug` |
| 4 | 确认流程 | 自动提交，通知用户 |
| 5 | 错误检测 | 混合模式：`_common.sh` 公共函数 + Hook 兜底 |
| 6 | 提交目标 | 固定 GitHub 仓库 `byx-darwin/ncgo-code-skills` |
| 7 | 去重 | 查询已有 Issue，已提交/已评估过则跳过，不重复评论 |
| 8 | 范围 | 仅 ncgo-code-skills 自身脚本和技能的错误 |

---

## 方案选型

### 方案 A：轻量 Hook + 内联 LLM 调用
错误捕获后直接在 Hook 中调用 `claude -p` 生成内容并创建 Issue。  
**缺点**：去重逻辑和 LLM 调用混在 Hook 里，难以维护。

### 方案 B：完整 Skill 架构
创建 `auto-report-bug` 技能，Hook 触发技能执行。  
**缺点**：错误捕获层和技能层边界不够清晰。

### 方案 C（选定）：分层架构
将系统分为五层：捕获层 → 缓冲层 → 检测层 → 处理层 → 通知层。  
**优点**：分层清晰，与现有 `_common.sh` / Provider 模式一致，易于测试和扩展。

---

## 详细设计

### 整体架构

```
┌─────────────────┐
│  捕获层          │  _common.sh 的 report_error() 函数
│  (各脚本 trap)   │  各脚本在 ERR trap 中调用
└────────┬────────┘
         ▼
┌─────────────────┐
│  缓冲层          │  写入 .cache/bug-reports/pending.json
│                  │  （包含：技能名、命令、错误信息、平台、时间戳）
└────────┬────────┘
         ▼
┌─────────────────┐
│  检测层          │  Stop Hook 检查 pending.json 是否存在
└────────┬────────┘
         ▼
┌─────────────────┐
│  处理层          │  auto-report-bug 技能（SKILL.md）
│                  │  1. 读取 pending.json
│                  │  2. Claude 分析错误，生成 Issue 标题/正文
│                  │  3. gh issue list --search 去重
│                  │  4. gh issue create 提交
│                  │  5. 删除 pending.json
└────────┬────────┘
         ▼
┌─────────────────┐
│  通知层          │  输出通知消息给用户
└─────────────────┘
```

### 第一层：错误捕获层

**`writing-plans-with-issue/scripts/_common.sh` 新增函数：**

```bash
# 调用方式：在脚本开头设置 trap
trap 'report_error "${BASH_SOURCE[0]}" "$LINENO" "$?"' ERR

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
  error_id=$(echo "${script_path}:${line_number}" | md5sum | cut -c1-8)
  
  # 写入缓冲文件
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
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
  "stderr": "$(cat /tmp/ncgo-stderr-$$ 2>/dev/null || echo "")",
  "provider": "$provider",
  "timestamp": "$timestamp"
}
EOF
}
```

**各脚本接入方式（示例）：**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

# 错误捕获：stderr 重定向到临时文件
STDERR_FILE=$(mktemp /tmp/ncgo-stderr-XXXXXX)
trap 'rm -f "$STDERR_FILE"' EXIT
trap 'report_error "${BASH_SOURCE[0]}" "$LINENO" "$?"' ERR

# 原有逻辑...
```

### 第二层：缓冲层

**`pending.json` 格式：**

```json
{
  "id": "a1b2c3d4",
  "skill": "writing-plans-with-issue",
  "script": "create-issue.sh",
  "line": 42,
  "command": "gh issue create ...",
  "exit_code": 1,
  "stderr": "error: ...",
  "provider": "github",
  "timestamp": "2026-06-30T22:30:00Z"
}
```

缓冲文件路径：`$REPO_ROOT/.cache/bug-reports/pending.json`

### 第三层：检测层

**`hooks/auto-report-bug.sh`：**

```bash
#!/usr/bin/env bash
# Stop Hook：检查是否有待报告的错误

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || exit 0)
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
```

**Hook 配置（`.claude/settings.json`）：**

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

### 第四层：处理层（auto-report-bug 技能）

**目录结构：**

```
auto-report-bug/
└── SKILL.md
```

**SKILL.md 核心流程：**

1. 读取 `.cache/bug-reports/pending.json`
2. 生成搜索关键词：`[auto-report] {脚本名} L{行号}`
3. 去重检查：
   ```bash
   gh issue list \
     --repo byx-darwin/ncgo-code-skills \
     --search "$SEARCH_QUERY" \
     --state all \
     --json number,title,state \
     --limit 5
   ```
4. 如果找到匹配（无论 open/closed）→ 跳过，删除 `pending.json`
5. 如果没有匹配 → Claude 分析错误，生成 Issue 标题/正文 → `gh issue create` → 删除 `pending.json`

**Issue 格式：**

```markdown
标题: [auto-report] {脚本名} L{行号} 执行失败

正文:
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
{Claude 基于错误上下文生成的分析：可能原因、建议修复方向}

---
*此 Issue 由 auto-report-bug 技能自动创建*
```

**标签**：`bug`、`auto-reported`、`{技能名}`

### 第五层：通知层

**成功创建 Issue 后：**
```
✅ Bug 报告已提交: Issue #N
   https://github.com/byx-darwin/ncgo-code-skills/issues/N
```

**去重命中时：**
```
ℹ️  已存在类似 Issue #N，跳过提交
   https://github.com/byx-darwin/ncgo-code-skills/issues/N
```

---

## 文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `writing-plans-with-issue/scripts/_common.sh` | 修改 | 新增 `report_error()` 函数 |
| `hooks/auto-report-bug.sh` | 新建 | Stop Hook 检测脚本 |
| `auto-report-bug/SKILL.md` | 新建 | 技能定义 |
| `.claude/settings.json` | 修改 | 注册新 Hook |
| `writing-plans-with-issue/scripts/*.sh` | 修改 | 各脚本接入错误捕获 |
| `brainstorm-from-issue/scripts/*.sh` | 修改 | 各脚本接入错误捕获 |

---

## 不涉及的范围

- 不监控非 ncgo-code-skills 项目的脚本错误
- 不支持用户手动触发（`/report-bug` 等命令）
- 不修改已存在的 Issue（去重命中时不追加评论）
- 不依赖外部 LLM API，使用 Claude Code 自身能力

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| Hook 本身出错影响正常流程 | `auto-report-bug.sh` 内部全部捕获异常，失败时静默退出 |
| `gh` 未登录导致创建失败 | 检测 `gh auth status`，失败时记录到 `.cache/bug-reports/failed.log` |
| `pending.json` 写入冲突（并发） | Stop Hook 串行执行，不存在并发问题 |
| stderr 临时文件泄漏 | 使用 `mktemp` + `trap EXIT` 清理 |
