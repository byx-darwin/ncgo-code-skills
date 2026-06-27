# Multi-Platform Provider Architecture — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 writing-plans-with-issue skill 的脚本从仅支持 GitHub（`gh` CLI）扩展为支持 GitHub / Gitee / GitLab 三平台，通过 Provider 抽象层隔离平台差异。

**Architecture:** 新增 `_provider.sh`（平台检测 + 分发）+ 3 个 backend 文件（`_provider_github.sh` / `_provider_gitee.sh` / `_provider_gitlab.sh`），每个 backend 实现 11 个统一函数接口。6 个现有脚本改动 ~40 行：把所有 `gh` 调用替换为 `provider_*` 函数。不改业务流程逻辑。

**Tech Stack:** Bash, gh CLI, glab CLI, curl + jq（Gitee）

## Global Constraints

- 所有脚本保持在纯 Bash 范围内，不引入 Python/Node.js 等新语言
- 不改动 SKILL.md 和 plan-template.md
- GitHub backend 的行为必须 100% 向后兼容（现有功能不变）
- Provider 函数名统一 `provider_` 前缀
- Gitee Token 从环境变量 `GITEE_TOKEN` 读取
- 平台检测：`github.com` → github，`gitee.com` → gitee，其余 → gitlab；环境变量 `WRITING_PLANS_PLATFORM` 可覆盖
- 详细接口定义见 spec: `docs/superpowers/specs/2026-06-27-multi-platform-provider-design.md`

---

## GitHub Issue 规划

**Issue 标题:** feat: writing-plans-with-issue 支持 Gitee / GitLab 多平台

**Issue 标签:** enhancement,writing-plans-with-issue,priority:high

**Issue 描述:**
为 writing-plans-with-issue skill 新增 Gitee 和 GitLab 平台支持。通过 Provider 抽象层（`_provider.sh` + 3 个 backend 文件），将所有 `gh` CLI 调用替换为平台无关的 `provider_*` 函数。GitHub 用户无需任何改动，Gitee 用户设置 `GITEE_TOKEN` 环境变量即可使用，GitLab 用户安装 `glab` CLI 即可。

**验收标准:**
- [ ] 所有任务完成
- [ ] GitHub 平台所有 6 个脚本功能正常（向后兼容）
- [ ] Gitee 平台 create-issue / sync-status / finish-issue / list-issues 可用
- [ ] GitLab 平台 create-issue / sync-status / finish-issue / list-issues 可用
- [ ] `_provider.sh` 可根据 `git remote` URL 正确识别三平台
- [ ] `WRITING_PLANS_PLATFORM` 环境变量可手动覆盖平台检测
- [ ] 代码审查通过

**关联:**
- 计划文件: `docs/superpowers/plans/2026-06-27-multi-platform-provider-plan.md`
- 设计文档: `docs/superpowers/specs/2026-06-27-multi-platform-provider-design.md`
- 里程碑: v1.3.0
- 依赖: 无

---

## File Structure

```
writing-plans-with-issue/scripts/
├── _common.sh              # Modify: check_dependencies → provider_check_prerequisites
│                           #         ensure_status_label → provider_ensure_label
├── _provider.sh            # NEW: 平台检测 + 分发（~35 行）
├── _provider_github.sh     # NEW: GitHub backend — gh CLI 封装（~100 行）
├── _provider_gitee.sh      # NEW: Gitee backend — curl + jq（~160 行）
├── _provider_gitlab.sh     # NEW: GitLab backend — glab CLI 封装（~110 行）
├── create-issue.sh         # Modify: ~5 处 gh → provider_
├── sync-status.sh          # Modify: ~3 处 gh → provider_
├── finish-issue.sh         # Modify: ~3 处 gh → provider_
├── link-pr.sh              # Modify: ~4 处 gh → provider_
└── list-issues.sh          # Modify: ~5 处 gh → provider_
```

---

## Tasks

> **Task 编号规则（硬性）：Task 1 = 创建 Issue，Task 2 = 同步状态为 in-progress。Task 3+ 为开发任务，最后一个为收尾任务。**

### Task 1: 创建 GitHub Issue

**Description:** 从 "GitHub Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-06-27-multi-platform-provider-plan.md
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

### Task 3: `_provider.sh` — 平台检测与分发

**Files:**
- Create: `/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider.sh`

**Interfaces:**
- Produces: 全局变量 `PLATFORM`（`github` / `gitee` / `gitlab`），所有后续脚本 `source` 它即可获得 `provider_*` 函数

**Description:** 实现 `detect_platform()` 函数（环境变量优先 + 域名匹配），并根据检测结果 `source` 对应 backend 文件。这是整个 Provider 架构的入口。

- [ ] **Step 1: 创建 `_provider.sh`**

实现内容：
```bash
#!/bin/bash
# writing-plans-with-issue: platform detection + provider dispatch
# Source this file to get all provider_* functions for the current platform.

SCRIPT_DIR="${PROVIDER_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

detect_platform() {
  # Manual override via env var
  if [ -n "${WRITING_PLANS_PLATFORM:-}" ]; then
    echo "$WRITING_PLANS_PLATFORM"
    return
  fi

  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || echo "")

  if [[ "$remote_url" == *github.com* ]]; then
    echo "github"
  elif [[ "$remote_url" == *gitee.com* ]]; then
    echo "gitee"
  else
    echo "gitlab"
  fi
}

PLATFORM=$(detect_platform)

case "$PLATFORM" in
  github) source "$SCRIPT_DIR/_provider_github.sh" ;;
  gitee)  source "$SCRIPT_DIR/_provider_gitee.sh"  ;;
  gitlab) source "$SCRIPT_DIR/_provider_gitlab.sh" ;;
  *)
    echo "❌ Unsupported platform: $PLATFORM"
    echo "   Set WRITING_PLANS_PLATFORM=github|gitee|gitlab to override."
    exit 1
    ;;
esac
```

- [ ] **Step 2: 验证语法**

```bash
bash -n /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider.sh
echo "✅ Syntax OK"
```

- [ ] **Step 3: Commit**

```bash
cd /Users/baoyx/.claude/skills/writing-plans-with-issue
git add scripts/_provider.sh
git commit -m "feat(provider): add platform detection and dispatch (#N)"
```

---

### Task 4: `_provider_github.sh` — GitHub Backend

**Files:**
- Create: `/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider_github.sh`

**Interfaces:**
- Implements: 11 个 `provider_*` 函数（完整清单见 spec）
- Consumes: 无（独立 backend）

**Description:** 将现有 `gh` 调用封装为标准 Provider 接口。从 `_common.sh` 中提取 `check_dependencies`（gh 版本）和 `ensure_status_label` 逻辑，从各脚本中提取 `gh issue create/close/list` 等调用。

- [ ] **Step 1: 创建 `_provider_github.sh`**

实现 11 个函数（具体 `gh` 命令映射见 spec）。必须实现的函数：

1. `provider_check_prerequisites()` — 检查 `gh` + `gh auth status`
2. `provider_create_issue()` — `gh issue create`
3. `provider_add_labels()` — `gh issue edit $NUM --add-label "$LABELS"`
4. `provider_remove_label()` — `gh issue edit $NUM --remove-label "$LABEL"`
5. `provider_close_issue()` — `gh issue close $NUM --comment "$COMMENT"`
6. `provider_get_issue_body()` — `gh issue view $NUM --json body -q '.body'`
7. `provider_get_issue_state()` — `gh issue view $NUM --json state -q '.state'`
8. `provider_get_issue_json()` — `gh issue view $NUM --json number,title,state,url`
9. `provider_list_issues()` — `gh issue list --label ... --state ... --json ...`
10. `provider_create_pr()` — `gh pr create`
11. `provider_list_prs()` — `gh pr list --head ... --json number --jq`
12. `provider_ensure_label()` — `gh label view || gh label create`
13. `provider_repo_name_with_owner()` — `gh repo view --json nameWithOwner -q`

- [ ] **Step 2: 验证语法**

```bash
bash -n /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider_github.sh
echo "✅ Syntax OK"
```

- [ ] **Step 3: Commit**

```bash
cd /Users/baoyx/.claude/skills/writing-plans-with-issue
git add scripts/_provider_github.sh
git commit -m "feat(provider): add GitHub backend (#N)"
```

---

### Task 5: `_provider_gitee.sh` — Gitee Backend（curl + jq）

**Files:**
- Create: `/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider_gitee.sh`

**Interfaces:**
- Implements: 同 Task 4 的 11 个函数，但用 `curl` + `jq` 调用 Gitee OpenAPI

**Description:** 这是最复杂的 backend。所有 Issue 操作通过 `curl` 调用 `https://gitee.com/api/v5`。关键差异：
- Token 从 `$GITEE_TOKEN` 环境变量读取
- Label 操作需 GET → 合并/过滤 → PATCH（Gitee 不把 label 当独立资源）
- Issue state 值映射：`closed`→`closed`，其他→`open`
- PR 路径为 `/pulls`

> **依赖：** 本 task 需要 `curl`（系统自带）和 `jq`。`provider_check_prerequisites()` 中检查 `jq` 是否可用。

- [ ] **Step 1: 创建 `_provider_gitee.sh`**

实现 11 个 Provider 函数，使用 `curl` + Gitee OpenAPI v5。API base: `https://gitee.com/api/v5`。

关键实现细节：
- 每个 curl 请求带 `?access_token=$GITEE_TOKEN`
- `provider_create_issue`: `POST /repos/$OWNER/$REPO/issues` + JSON body
- `provider_add_labels`: GET issue → `jq` 合并 `labels[]` → PATCH
- `provider_remove_label`: GET issue → `jq` 过滤 label → PATCH
- `provider_close_issue`: 先 `POST /comments`，再 `PATCH state=closed`
- `provider_get_issue_body`: `GET /issues/$NUM` → `jq -r '.body'`
- `provider_get_issue_state`: `GET /issues/$NUM` → `jq -r '.state'` → 映射 `closed`/其他
- `provider_list_issues`: `GET /issues?labels=...&state=...&per_page=$LIMIT`
- `provider_repo_name_with_owner`: 从 `git remote get-url origin` 解析
- 错误处理：检查 HTTP status code，非 2xx 时输出 curl stderr 并 exit 1

- [ ] **Step 2: 验证语法**

```bash
bash -n /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider_gitee.sh
echo "✅ Syntax OK"
```

- [ ] **Step 3: Commit**

```bash
cd /Users/baoyx/.claude/skills/writing-plans-with-issue
git add scripts/_provider_gitee.sh
git commit -m "feat(provider): add Gitee backend with curl + jq (#N)"
```

---

### Task 6: `_provider_gitlab.sh` — GitLab Backend（glab CLI）

**Files:**
- Create: `/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider_gitlab.sh`

**Interfaces:**
- Implements: 同 Task 4 的 11 个函数，用 `glab` CLI

**Description:** GitLab backend，使用 `glab` CLI。命令名和 `gh` 不同（`glab mr` vs `gh pr`，`glab issue update` vs `gh issue edit`），但功能对应。关键差异：
- MR（Merge Request）不是 PR
- JSON 输出格式略有不同（字段名适配）
- 标签操作：`glab issue update --add-label` / `--remove-label`

- [ ] **Step 1: 创建 `_provider_gitlab.sh`**

实现 11 个 Provider 函数，使用 `glab` CLI。关键映射：
- `provider_create_issue`: `glab issue create -t ... -d ... -l ...`
- `provider_add_labels`: `glab issue update $NUM --add-label "$LABELS"`
- `provider_remove_label`: `glab issue update $NUM --remove-label "$LABEL"`
- `provider_close_issue`: `glab issue close $NUM -m "$COMMENT"`
- `provider_get_issue_body`: `glab issue view $NUM --output json | jq -r '.description'`
- `provider_get_issue_state`: `glab issue view $NUM --output json | jq -r '.state'`
- `provider_create_pr`: `glab mr create -t ... -d ... -b "$BASE_BRANCH"`
- `provider_list_prs`: `glab mr list --source-branch "$HEAD" --output json`
- `provider_ensure_label`: `glab label create "$NAME" 2>/dev/null || true`
- `provider_repo_name_with_owner`: `glab repo view --output json | jq -r '.namespace.full_path'`

- [ ] **Step 2: 验证语法**

```bash
bash -n /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider_gitlab.sh
echo "✅ Syntax OK"
```

- [ ] **Step 3: Commit**

```bash
cd /Users/baoyx/.claude/skills/writing-plans-with-issue
git add scripts/_provider_gitlab.sh
git commit -m "feat(provider): add GitLab backend with glab CLI (#N)"
```

---

### Task 7: 改造 `_common.sh` + `create-issue.sh`

**Files:**
- Modify: `/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_common.sh`
- Modify: `/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh`

**Interfaces:**
- Consumes: `_provider.sh`（`source` 后获得所有 `provider_*` 函数）
- Produces: `_common.sh` 中的 `check_dependencies()` 和 `ensure_status_label()` 改为调 `provider_*`

**Description:** `_common.sh` 和 `create-issue.sh` 是第一组被改造的消费者脚本。`_common.sh` 改动最基础，`create-issue.sh` 是第一个完整验证 Provider 模式可工作的脚本。

- [ ] **Step 1: `_common.sh` 改动**

两处改动：
1. `check_dependencies()` 改为调 `provider_check_prerequisites()`，移除原有 `gh` 检查逻辑
2. `ensure_status_label()` 改为调 `provider_ensure_label()`，移除原有 `gh label view/create` 调用
3. 在文件开头新增 `source "$SCRIPT_DIR/_provider.sh"`（在 `set -euo pipefail` 之后）

- [ ] **Step 2: `create-issue.sh` 改动**

三处改动：
1. 第 148 行：`gh issue create` → `provider_create_issue`
2. 第 124 行：`ensure_status_label` → `provider_ensure_label`（`provider_ensure_label` 已经是标准接口）
3. 第 178 行：`gh issue edit --add-label` → `provider_add_labels`
4. 移除文件底部 `main "$@"` 前对 `check_dependencies` 的独立调用，该调用现在通过 `_common.sh` 的 `source` 自动完成

- [ ] **Step 3: 在 GitHub 环境验证**

```bash
cd /Users/baoyx/Documents/workspace/github.com/byx-darwin/ncgo-code-skills
# 用现有 plan 文件验证 create-issue.sh 仍能正常工作
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-06-27-multi-platform-provider-plan.md
# 预期：提示 "计划文件已关联 Issue #N"（正常，因为 Issue 已在 Task 1 创建）
```

- [ ] **Step 4: Commit**

```bash
cd /Users/baoyx/.claude/skills/writing-plans-with-issue
git add scripts/_common.sh scripts/create-issue.sh
git commit -m "refactor: migrate _common.sh and create-issue.sh to provider interface (#N)"
```

---

### Task 8: 改造 `sync-status.sh` + `finish-issue.sh` + `link-pr.sh` + `list-issues.sh`

**Files:**
- Modify: `sync-status.sh`, `finish-issue.sh`, `link-pr.sh`, `list-issues.sh`

**Description:** 剩余 4 个脚本的 Provider 迁移。全部是 `gh` → `provider_*` 的机械替换。

- [ ] **Step 1: `sync-status.sh` 改动**
  - `gh issue edit $NUM --add-label "$LABEL"` → `provider_add_labels`
  - `gh issue edit $NUM --remove-label "$LABEL"` → `provider_remove_label`
  - `ensure_status_label` → `provider_ensure_label`

- [ ] **Step 2: `finish-issue.sh` 改动**
  - `gh issue view $NUM --json body -q '.body'` → `provider_get_issue_body`
  - `gh issue view $NUM --json state -q '.state'` → `provider_get_issue_state`
  - `gh issue close $NUM --comment "..."` → `provider_close_issue`
  - `gh issue edit $NUM --body-file "$TEMP_BODY"` → 用 `provider_get_issue_body` + PATCH 或等效方式（需要新增 `provider_update_issue_body()` 函数，或复用现有接口）

- [ ] **Step 3: `link-pr.sh` 改动**
  - `gh pr list --head "$BRANCH"` → `provider_list_prs`
  - `gh pr create` → `provider_create_pr`
  - `gh repo view --json nameWithOwner` → `provider_repo_name_with_owner`
  - `PR_URL` 拼接逻辑适配各平台 URL 格式

- [ ] **Step 4: `list-issues.sh` 改动**
  - 所有 `gh issue list` → `provider_list_issues`
  - `gh issue view` → `provider_get_issue_json`
  - `check_dependencies` 检查 `gh` → 改为通用方式（或在 `_common.sh` 中处理）

- [ ] **Step 5: Commit**

```bash
cd /Users/baoyx/.claude/skills/writing-plans-with-issue
git add scripts/sync-status.sh scripts/finish-issue.sh scripts/link-pr.sh scripts/list-issues.sh
git commit -m "refactor: migrate remaining scripts to provider interface (#N)"
```

---

### Task 9: 端到端验证 — GitHub 平台

**Description:** 在 GitHub 环境上跑全流程，确保 Provider 改造后 100% 向后兼容。

- [ ] **Step 1: 用测试计划文件验证 create-issue**

```bash
cd /Users/baoyx/Documents/workspace/github.com/byx-darwin/ncgo-code-skills
# 创建一个临时测试计划
cp docs/superpowers/plans/2026-06-26-launch-sdd-skill-update.md /tmp/test-plan.md
# 移除已有的 Issue 引用
sed -i '' '/<!-- Issue: #/d' /tmp/test-plan.md
```

> 注意：此步骤需要用户确认，因为它会创建一个真实的测试 Issue。

- [ ] **Step 2: 验证 sync-status**
- [ ] **Step 3: 验证 finish-issue**

验证无误后关闭测试 Issue。

---

### Task 10: 收尾 — 本地合并后关闭 Issue

**Description:** 开发完成并合并到 base 分支后，push + 同步验收 checkbox + 关闭 Issue。

- [ ] **Step 1: 确保已合并到 base 分支**
- [ ] **Step 2: 运行 `finish-issue.sh`**
- [ ] **Step 3: 确认 Issue 已关闭**

---

## Validation

### Provider Interface Validation

```bash
# 验证所有 provider_* 函数在三个 backend 中都存在
for backend in _provider_github.sh _provider_gitee.sh _provider_gitlab.sh; do
  echo "=== $backend ==="
  for fn in provider_check_prerequisites provider_create_issue provider_add_labels \
            provider_remove_label provider_close_issue provider_get_issue_body \
            provider_get_issue_state provider_get_issue_json provider_list_issues \
            provider_create_pr provider_list_prs provider_ensure_label \
            provider_repo_name_with_owner; do
    grep -q "^$fn()" "/Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/$backend" \
      && echo "  ✅ $fn" || echo "  ❌ MISSING: $fn"
  done
done
```

### Platform Detection Test

```bash
# 在 GitHub 仓库中验证检测结果
cd /Users/baoyx/Documents/workspace/github.com/byx-darwin/ncgo-code-skills
source /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider.sh
echo "Detected: $PLATFORM"
# Expected: github

# 手动覆盖测试
WRITING_PLANS_PLATFORM=gitee source /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/_provider.sh
echo "Override: $PLATFORM"
# Expected: gitee
```

### GitHub Backward Compatibility

```bash
# 验证现有 create-issue.sh 仍可解析计划文件
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh \
  docs/superpowers/plans/2026-06-27-multi-platform-provider-plan.md
# Expected: 提示 "计划文件已关联 Issue #N"，不报错
```

---

## Completion Checklist

- [ ] All tasks completed
- [ ] GitHub 平台 6 个脚本功能正常
- [ ] Gitee backend 代码完成
- [ ] GitLab backend 代码完成
- [ ] 平台检测逻辑正确
- [ ] 代码审查通过
- [ ] GitHub Issue 已关闭

---

## Notes

- Tasks 3, 4, 5, 6（四个 Provider 文件）完全独立，可并行开发。Tasks 4/5/6 共享 Task 3 的函数签名定义
- Task 7 和 Task 8 有依赖：必须先完成 Tasks 3-6 才能改消费者脚本
- Gitee backend（Task 5）是最复杂的文件，预计 ~160 行，需要仔细处理 JSON 解析和错误处理
- GitLab 的 `glab` CLI 未安装在当前环境，代码编写时参考 `glab --help` 文档即可，运行验证需要安装 `glab`
- Task 9（端到端验证）仅验证 GitHub 平台，Gitee/GitLab 验证需要对应的环境
