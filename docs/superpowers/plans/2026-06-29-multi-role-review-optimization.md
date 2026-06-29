<!-- Issue: #N -->

# ncgo-code-skills 全量优化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复多角色审查发现的 11 个问题，涵盖代码错误、安全漏洞、工程治理、文档补齐、代码规范化五个维度。

**Architecture:** 按优先级分三批：🔴紧急修复（路径错误/Token安全/未提交修改）→ 🟡质量增强（竞态修复/README补齐/代码去重）→ 🟢规范化（垃圾清理/模板泛化/symlink标准化）。每批内任务相互独立。

**Tech Stack:** Bash、sed、jq、Provider Layer（`writing-plans-with-issue/scripts/_provider.sh`）

**关联审查报告:** 本项目对话中的多角色全面分析

## Global Constraints

- 三平台兼容（GitHub / Gitee / GitLab），通过 Provider 层自动检测
- 脚本使用 `jq` 1.5+ 语法（`--arg`、`--argjson`），不使用 bash 4.4+ 特性
- `/tmp/` 固定文件名全部替换为 `mktemp`
- 所有修改保持向后兼容（不破坏现有接口签名）
- commit message 引用 Issue `#N`

## Issue 规划

**Issue 标题:** fix: 多角色审查优化 — 11项代码/安全/文档改进

**Issue 标签:** refactor,security,documentation,priority:high

**Issue 描述:**
基于多角色全面分析（架构/安全/代码质量/文档），修复 11 个发现的问题。包括：issue-status 路径硬编码错误、Gitee Token URL 暴露、ncgo-code 未提交修改、/tmp/ 固定文件名竞态、README 缺少新 skill、list-issues.sh 代码重复、.gitignore 遗漏、specs 垃圾目录清理、plan-template Go 示例不匹配、weekly-report 缺少 symlink。所有修改保持三平台兼容。

**验收标准:**
- [ ] issue-status 路径不再含 `ncgo-skills` 错误引用
- [ ] Gitee Token 通过 HTTP Header 传递，不出现在 URL
- [ ] ncgo-code clone 3 个文件修改已提交并 push
- [ ] `.gitignore` 含 `.superpowers/` 条目
- [ ] `/tmp/gh_*_err.txt` 固定文件名全部替换为 `mktemp`
- [ ] `README.md` 和 `README.zh-CN.md` 列出全部 4 个 skill + `finish-issue.sh`
- [ ] `list-issues.sh` 复用 `_common.sh` 共享函数，使用 `set -euo pipefail`
- [ ] `docs/superpowers/specs/` 无垃圾嵌套目录
- [ ] `plan-template.md` 移除 Go 示例，改为 bash 通用描述
- [ ] `~/.claude/skills/weekly-report` symlink 已创建
- [ ] 所有脚本语法检查通过

**关联:**
- 计划文件: `docs/superpowers/plans/2026-06-29-multi-role-review-optimization.md`
- 依赖: 无

## File Structure

```
# 修改现有文件
issue-status/SKILL.md                         # 修复路径引用
writing-plans-with-issue/scripts/
├── _provider_gitee.sh                         # Token 从 URL 移到 Header
├── _provider_github.sh                        # /tmp/ 固定名 → mktemp
├── _provider_gitlab.sh                        # /tmp/ 固定名 → mktemp（如有）
├── create-issue.sh                            # /tmp/ 固定名 → mktemp（若存在）
├── link-pr.sh                                 # /tmp/ 固定名 → mktemp（若存在）
├── list-issues.sh                             # 重构：复用 _common.sh
│
├── SKILL.md                                   # 版本更新
└── plan-template.md                           # 去 Go 化

.gitignore                                     # + .superpowers/
README.md                                      # + brainstorm-from-issue, + finish-issue.sh
README.zh-CN.md                                # 同上

# 新增
~/.claude/skills/weekly-report                 # symlink → repo

# 删除
docs/superpowers/specs/.claude/                # 垃圾清理
docs/superpowers/specs/docs/                   # 垃圾清理
```

## Tasks

### Task 1: 创建 Issue

**Description:** 从 "Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash /Users/byx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-06-29-multi-role-review-optimization.md
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

### Task 3: 🔴 紧急修复 — issue-status 路径 + .gitignore + 提交未提交修改

**Description:** 修复三个紧急问题：(1) `issue-status/SKILL.md:41` 中 `~/.claude/skills/ncgo-skills/ncgo-code/` 改为 `~/.claude/skills/ncgo-code/`；(2) `.gitignore` 添加 `.superpowers/` 条目；(3) 提交 `~/.claude/skills/ncgo-code/` 中 3 个文件的未提交修改（去 GitHub 化注释 + 别名建议）。

- [ ] **Step 1: 修复 issue-status 路径**

将 `issue-status/SKILL.md` 第 41 行中的：
```
`~/.claude/skills/ncgo-skills/ncgo-code/writing-plans-with-issue/scripts/sync-status.sh`
```
替换为：
```
`~/.claude/skills/ncgo-code/writing-plans-with-issue/scripts/sync-status.sh`
```

- [ ] **Step 2: .gitignore 添加 .superpowers/**

```bash
echo '.superpowers/' >> .gitignore
```

- [ ] **Step 3: 提交 ncgo-code clone 未提交修改**

```bash
cd ~/.claude/skills/ncgo-code
git add writing-plans-with-issue/SKILL.md writing-plans-with-issue/scripts/create-issue.sh writing-plans-with-issue/scripts/sync-status.sh
git commit -m "chore: remove GitHub-specific references from comments and logs (#N)"
```

- [ ] **Step 4: Commit 工作区修改**

```bash
cd /Users/byx/Documents/workspace/github.com/byx-darwin/ncgo-code-skills
git add issue-status/SKILL.md .gitignore
git commit -m "fix: correct issue-status path reference and add .superpowers to gitignore (#N)"
```

### Task 4: 🔴 安全修复 — Gitee Token 从 URL 移到 Header

**Description:** 修改 `_provider_gitee.sh` 中的 `_gitee_api()` 函数，将 `access_token=${GITEE_TOKEN}` 从 URL query string 移到 HTTP Header `Authorization: Bearer ${GITEE_TOKEN}`，防止 Token 通过 `ps aux` 和 shell history 泄露。

- [ ] **Step 1: 查看 Gitee OpenAPI v5 认证方式**

Gitee API v5 支持两种认证：
- URL query: `?access_token=xxx`（当前使用，不安全）
- Header: `Authorization: Bearer xxx`（推荐，不会出现在进程列表）

- [ ] **Step 2: 修改 _gitee_api() 函数**

将 `_gitee_api()` 中的 URL 拼接方式改为 Header 传递。修改 `_provider_gitee.sh`:

```bash
# 修改前（当前代码 ~line 36-46）:
local sep="?"
[[ "$path" == *"?"* ]] && sep="&"
local url="${GITEE_API_BASE}${path}${sep}access_token=${GITEE_TOKEN}"

if [ -n "$body" ]; then
  curl -s -X "$method" "$url" \
    -H "Content-Type: application/json" \
    -d "$body" 2>/tmp/gitee_curl_err.txt
else
  curl -s -X "$method" "$url" 2>/tmp/gitee_curl_err.txt
fi

# 修改后:
local url="${GITEE_API_BASE}${path}"

if [ -n "$body" ]; then
  curl -s -X "$method" "$url" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${GITEE_TOKEN}" \
    -d "$body" 2>/tmp/gitee_curl_err.txt
else
  curl -s -X "$method" "$url" \
    -H "Authorization: Bearer ${GITEE_TOKEN}" 2>/tmp/gitee_curl_err.txt
fi
```

- [ ] **Step 3: 同步修改 _gitee_get_repo() 中的 label 检查调用**

检查 `provider_ensure_label()` 中直接拼接 URL 的 `curl` 调用，同样改为 Header 方式。

- [ ] **Step 4: Commit**

```bash
git add writing-plans-with-issue/scripts/_provider_gitee.sh
git commit -m "fix(security): move Gitee token from URL query to Authorization header (#N)"
```

### Task 5: 🟡 安全修复 — /tmp/ 固定文件名替换为 mktemp

**Description:** 所有脚本中 `/tmp/gh_create_err.txt`、`/tmp/gh_pr_create_err.txt`、`/tmp/gitee_curl_err.txt` 等固定文件名替换为 `mktemp` 生成的唯一临时文件名，消除并行调用时的竞态条件。

**受影响的文件：**
- `writing-plans-with-issue/scripts/_provider_github.sh` — `gh_create_err.txt`、`gh_pr_create_err.txt`
- `writing-plans-with-issue/scripts/_provider_gitee.sh` — `gitee_curl_err.txt`
- `writing-plans-with-issue/scripts/_provider_gitlab.sh` — 检查是否有固定 /tmp/ 文件名
- `writing-plans-with-issue/scripts/create-issue.sh` — `gh_create_err.txt`

- [ ] **Step 1: 修复 _provider_github.sh**

```bash
# 每个函数内使用 mktemp 生成唯一 error file，函数退出时 trap 清理
```

- [ ] **Step 2: 修复 _provider_gitee.sh**

同上。

- [ ] **Step 3: 修复 create-issue.sh**

同上。

- [ ] **Step 4: 检查 _provider_gitlab.sh**

```bash
grep -n '/tmp/' writing-plans-with-issue/scripts/_provider_gitlab.sh
```

如有固定 `/tmp/` 文件名，同样替换。

- [ ] **Step 5: Commit**

```bash
git add writing-plans-with-issue/scripts/
git commit -m "fix(security): replace hardcoded /tmp/ paths with mktemp to prevent race conditions (#N)"
```

### Task 6: 🟡 代码重构 — list-issues.sh 复用 _common.sh

**Description:** 重构 `list-issues.sh`，移除本地重复的颜色/日志函数和平台检测代码，改为 source `_common.sh`（其中已集成 `_provider.sh`）。同时修复 `set -o pipefail` → `set -euo pipefail`。

- [ ] **Step 1: 重构 list-issues.sh**

保持功能不变的前提下：
1. 将 `set -o pipefail` 改为 `set -euo pipefail`
2. 移除 `RED/GREEN/YELLOW/BLUE/NC` 颜色变量（`_common.sh` 已提供）
3. 移除 `log_info/log_warn/log_error/log_header` 函数（`_common.sh` 已提供）
4. 移除 `detect_os()` 函数和 `gh_install_instructions()` 函数（平台检测已由 Provider 层处理）
5. 移除 `check_dependencies()` 重复实现，改用 `_common.sh` 中的 `check_dependencies`
6. 移除内联的 `source "$SCRIPT_DIR/_provider.sh"`，改为 `source "$SCRIPT_DIR/_common.sh"`

- [ ] **Step 2: 验证语法**

```bash
bash -n writing-plans-with-issue/scripts/list-issues.sh && echo "✅ 语法检查通过"
```

- [ ] **Step 3: 测试 list-issues.sh**

```bash
bash writing-plans-with-issue/scripts/list-issues.sh
```

- [ ] **Step 4: Commit**

```bash
git add writing-plans-with-issue/scripts/list-issues.sh
git commit -m "refactor: list-issues.sh reuse _common.sh, add strict error handling (#N)"
```

### Task 7: 🟡 文档补齐 — README 更新

**Description:** 更新 `README.md` 和 `README.zh-CN.md`：(1) Skills 章节添加 `brainstorm-from-issue`；(2) 目录结构补充 `finish-issue.sh`；(3) 目录结构补充 `brainstorm-from-issue/`。

- [ ] **Step 1: 更新 README.md Skills 章节**

在 `weekly-report` 之后添加 `brainstorm-from-issue` skill 介绍：

```markdown
### `brainstorm-from-issue` (ncgo-code)

获取仓库所有 open issues，按业务领域语义分类，逐分类 brainstorming 并输出独立 spec 文件。支持功能需求和 Bug 两种 Issue 类型。

```
"从 issue 开始 brainstorming" / "分类分析 open issues"
```
```

- [ ] **Step 2: 更新 README.md 目录结构**

补充 `finish-issue.sh` 和 `brainstorm-from-issue/`：

```
├── brainstorm-from-issue/
│   ├── SKILL.md
│   └── scripts/
│       └── fetch-open-issues.sh
├── issue-status/
├── weekly-report/
└── writing-plans-with-issue/
    ├── SKILL.md
    ├── plan-template.md
    └── scripts/
        ├── create-issue.sh
        ├── finish-issue.sh     ← 补充
        ├── sync-status.sh
        ├── link-pr.sh
        └── list-issues.sh
```

- [ ] **Step 3: 同步更新 README.zh-CN.md**

与 README.md 保持一致的修改。

- [ ] **Step 4: Commit**

```bash
git add README.md README.zh-CN.md
git commit -m "docs: add brainstorm-from-issue and finish-issue.sh to README (#N)"
```

### Task 8: 🟢 代码规范化 — plan-template.md 去 Go 化

**Description:** `plan-template.md` 包含 Go 特定示例代码（`go test`、`go build`、`golangci-lint`、`package.FunctionName`），但 ncgo-code-skills 项目本身是 bash 脚本项目。将模板泛化为语言无关的通用描述，使模板适用于任何语言的项目。

- [ ] **Step 1: 修改 Task 3 示例代码**

将 Task 3 中的 Go 代码示例改为语言无关的伪代码描述：

```
将 `// exact/path/to/file_test.go` 和 Go 测试代码替换为语言无关的：
```bash
# Step 1: Write the failing test
# Step 2: Run test to verify it fails
# Step 3: Implement minimal code
# Step 4: Run test to verify it passes
# Step 5: Commit
```

- [ ] **Step 2: 修改 Validation 章节**

将 Go 特定的 build/test/lint 命令替换为通用描述：

```markdown
### Build Verification

```bash
# Build (language-specific)
# Test (language-specific)
# Lint (language-specific)
```
```

- [ ] **Step 3: Commit**

```bash
git add writing-plans-with-issue/plan-template.md
git commit -m "docs: generalize plan-template from Go-specific to language-agnostic (#N)"
```

### Task 9: 🟢 清理 + symlink 标准化

**Description:** (1) 清理 `docs/superpowers/specs/` 下的垃圾嵌套目录；(2) 创建 `~/.claude/skills/weekly-report` symlink。

- [ ] **Step 1: 清理 specs 垃圾目录**

```bash
rm -rf docs/superpowers/specs/.claude/
rm -rf docs/superpowers/specs/docs/
```

- [ ] **Step 2: 创建 weekly-report symlink**

```bash
ln -sfn "$(pwd)/weekly-report" ~/.claude/skills/weekly-report
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/
git commit -m "chore: clean up nested junk directories under specs (#N)"
```

### Task 10: 收尾 — 同步 ncgo-code clone + 关闭 Issue

**Description:** 开发完成后，将 workspace clone 的修改同步到 ncgo-code clone，push 并关闭 Issue。

- [ ] **Step 1: Push workspace clone**

```bash
cd /Users/byx/Documents/workspace/github.com/byx-darwin/ncgo-code-skills && git push origin main
```

- [ ] **Step 2: 同步 ncgo-code clone**

```bash
cd ~/.claude/skills/ncgo-code && git pull --rebase origin main
```

- [ ] **Step 3: 运行 scripts/finish-issue.sh**

```bash
bash /Users/byx/.claude/skills/writing-plans-with-issue/scripts/finish-issue.sh
```

- [ ] **Step 4: 确认 Issue 已关闭**

```bash
gh issue view "$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo 'already cleaned')"
```
