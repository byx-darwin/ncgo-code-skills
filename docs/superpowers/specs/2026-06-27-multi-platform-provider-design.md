# Multi-Platform Provider Architecture — Design Spec

**日期:** 2026-06-27
**状态:** 已确认
**关联 Issue:** （实施时创建）

## 目标

将 writing-plans-with-issue skill 从仅支持 GitHub（`gh` CLI）扩展为支持 GitHub / Gitee / GitLab 三个平台，通过 Provider 抽象层隔离平台差异。

## 平台概览

| 平台 | CLI / 接口 | 域名特征 | 认证方式 |
|------|-----------|---------|---------|
| GitHub | `gh` CLI（官方，已验证） | `github.com` | `gh auth login` |
| Gitee | `curl` + REST API（无 CLI） | `gitee.com` | `GITEE_TOKEN` 环境变量 |
| GitLab | `glab` CLI（半官方） | 其余所有域名 | `glab auth login` |

## 架构

```
scripts/
├── _common.sh              # 公共工具：日志、git 操作、Issue 编号存取（微调）
├── _provider.sh            # 平台检测 + 分发 → source 对应 backend
├── _provider_github.sh     # GitHub backend（gh CLI）
├── _provider_gitee.sh      # Gitee backend（curl + jq）
├── _provider_gitlab.sh     # GitLab backend（glab CLI）
├── create-issue.sh         # 业务流程（改调 provider_*）
├── sync-status.sh          # 业务流程（改调 provider_*）
├── finish-issue.sh         # 业务流程（改调 provider_*）
├── link-pr.sh              # 业务流程（改调 provider_*）
└── list-issues.sh          # 业务流程（改调 provider_*）
```

**核心原则：** 主脚本只做业务流程（解析计划文件、git 操作、checkbox 同步），不碰 `gh`/`curl`/`glab` 任何底层命令。所有平台操作通过 Provider 函数完成。

---

## Provider 接口契约

所有 backend 必须实现以下 11 个函数。

### 前置检查

```
provider_check_prerequisites()
```
检查对应 CLI / Token 是否可用。不可用时输出安装引导并 `exit 1`。
- GitHub: 检查 `gh` + `gh auth status`
- Gitee: 检查 `curl` + `jq` + `GITEE_TOKEN` 环境变量
- GitLab: 检查 `glab` + `glab auth status`

### Issue 操作

```
provider_create_issue(title, body_file, labels_csv, milestone) → stdout: issue_url
```
创建 Issue。`labels_csv` 为逗号分隔字符串。返回 Issue URL（从中提取编号）。

```
provider_add_labels(issue_num, labels_csv)
```
给 Issue 添加标签。`labels_csv` 为逗号分隔字符串。

```
provider_remove_label(issue_num, label)
```
移除单个标签。

```
provider_close_issue(issue_num, comment)
```
关闭 Issue 并附加评论。

```
provider_get_issue_body(issue_num) → stdout: body_text
```
获取 Issue body 全文（用于 finish-issue.sh 的 checkbox 同步）。

```
provider_get_issue_state(issue_num) → stdout: open | closed
```
返回 Issue 状态，统一小写。

```
provider_get_issue_json(issue_num) → stdout: json
```
返回 `{number, title, state, url}` JSON。

```
provider_list_issues(label, state, limit) → stdout: json_array
```
按标签和状态过滤 Issues。

### PR / MR 操作

```
provider_create_pr(title, body_file, base_branch) → stdout: pr_url
```
创建 Pull Request（GitHub/Gitee）或 Merge Request（GitLab）。

```
provider_list_prs(head_branch) → stdout: json_array
```
查询已有 PR/MR（按 head branch 过滤）。

### 标签管理

```
provider_ensure_label(label_name)
```
确保标签存在，不存在则创建。

### 仓库信息

```
provider_repo_name_with_owner() → stdout: owner/repo
```
返回 `owner/repo` 格式。

---

## 平台检测逻辑

文件：`_provider.sh`

```bash
detect_platform() {
  # 手动覆盖优先
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
    # 自建 GitLab、gitlab.com、以及其他所有情况
    echo "gitlab"
  fi
}
```

**分发：**

```bash
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

**环境变量覆盖：** 当域名检测不准确时（如自建 GitLab 用了不带 `gitlab` 的域名），用户可设置 `WRITING_PLANS_PLATFORM=gitlab`。

---

## Backend 实现要点

### GitHub (`_provider_github.sh`)

现有 `gh` 调用直接搬家，基本零风险。

| Provider 函数 | gh 命令 |
|--------------|---------|
| `provider_create_issue` | `gh issue create --title ... --body-file ... --label ...` |
| `provider_add_labels` | `gh issue edit $NUM --add-label "$LABELS"` |
| `provider_remove_label` | `gh issue edit $NUM --remove-label "$LABEL"` |
| `provider_close_issue` | `gh issue close $NUM --comment "..."` |
| `provider_get_issue_body` | `gh issue view $NUM --json body -q '.body'` |
| `provider_get_issue_state` | `gh issue view $NUM --json state -q '.state'` |
| `provider_list_issues` | `gh issue list --label ... --state ... --json ...` |
| `provider_create_pr` | `gh pr create --title ... --body-file ... --base ...` |
| `provider_list_prs` | `gh pr list --head ... --json number --jq ...` |
| `provider_ensure_label` | `gh label view ... \|\| gh label create ...` |
| `provider_repo_name_with_owner` | `gh repo view --json nameWithOwner -q .nameWithOwner` |

### Gitee (`_provider_gitee.sh`)

纯 `curl` + `jq`，无 CLI。

**依赖：** `curl`（系统自带）、`jq`（需预装，`brew install jq`）

**认证：** 从环境变量 `GITEE_TOKEN` 读取 Personal Access Token，每请求带 `access_token=$GITEE_TOKEN` 参数。

**API 基础 URL：** `https://gitee.com/api/v5`

| Provider 函数 | HTTP 调用 |
|--------------|----------|
| `provider_create_issue` | `POST /repos/{owner}/{repo}/issues` body: `{title, body, labels, milestone}` |
| `provider_add_labels` | GET 当前 issue → 合并 labels 数组 → `PATCH /repos/{owner}/{repo}/issues/{num}` |
| `provider_remove_label` | GET 当前 issue → 过滤 label → `PATCH /repos/{owner}/{repo}/issues/{num}` |
| `provider_close_issue` | `PATCH /repos/{owner}/{repo}/issues/{num}` body: `{state: "closed"}` + 先发评论 |
| `provider_get_issue_body` | `GET /repos/{owner}/{repo}/issues/{num}` → `jq -r '.body'` |
| `provider_get_issue_state` | `GET /repos/{owner}/{repo}/issues/{num}` → `jq -r '.state'` → 映射 closed→closed, 其他→open |
| `provider_list_issues` | `GET /repos/{owner}/{repo}/issues?labels=...&state=...&page=1&per_page=...` |
| `provider_create_pr` | `POST /repos/{owner}/{repo}/pulls` body: `{title, body, base, head}` |
| `provider_list_prs` | `GET /repos/{owner}/{repo}/pulls?head=...` |
| `provider_ensure_label` | `GET /repos/{owner}/{repo}/labels/{name}` → 404 → `POST /repos/{owner}/{repo}/labels` |
| `provider_repo_name_with_owner` | 从 `git remote get-url origin` 解析 |

**Gitee state 映射：**
- Gitee API 的 `state` 值：`open` / `progressing` / `closed`
- `provider_get_issue_state` 返回：`closed` → `closed`，其他 → `open`

**Gitee label 操作特点：**
- 标签嵌在 Issue 的 `labels` 字段（字符串数组）中，不是独立资源
- 修改标签需 PATCH 整个 Issue，传入完整 labels 列表
- `provider_add_labels` = GET labels → 合并新标签 → PATCH
- `provider_remove_label` = GET labels → filter → PATCH

### GitLab (`_provider_gitlab.sh`)

使用 `glab` CLI。命令名和 `gh` 不同但功能对应。

| Provider 函数 | glab 命令 |
|--------------|----------|
| `provider_create_issue` | `glab issue create -t "..." -d "$(cat body_file)" -l "..."` |
| `provider_add_labels` | `glab issue update $NUM --add-label "$LABELS"` |
| `provider_remove_label` | `glab issue update $NUM --remove-label "$LABEL"` |
| `provider_close_issue` | `glab issue close $NUM -m "..."` |
| `provider_get_issue_body` | `glab issue view $NUM --output json` → `jq -r '.description'` |
| `provider_get_issue_state` | `glab issue view $NUM --output json` → `jq -r '.state'` |
| `provider_list_issues` | `glab issue list --label ... --state ... --output json` |
| `provider_create_pr` | `glab mr create -t "..." -d "$(cat body_file)" -b "$BASE"` |
| `provider_list_prs` | `glab mr list --source-branch "$HEAD" --output json` |
| `provider_ensure_label` | `glab label create "$NAME" 2>/dev/null`（不存在则创建） |
| `provider_repo_name_with_owner` | `glab repo view --output json` → `jq -r '.namespace.full_path'` |

---

## 主脚本改动概览

每个脚本的改动量约 5-10 行，模式一致：

| 脚本 | 改动次数 | 改动内容 |
|------|---------|---------|
| `_common.sh` | 2 处 | `check_dependencies()` → 调 `provider_check_prerequisites()`；`ensure_status_label()` → 调 `provider_ensure_label()` |
| `create-issue.sh` | 3 处 | `gh issue create` → `provider_create_issue`；`ensure_status_label` → `provider_ensure_label`；`gh issue edit --add-label` → `provider_add_labels` |
| `sync-status.sh` | 3 处 | `gh issue edit --add-label` → `provider_add_labels`；`gh issue edit --remove-label` → `provider_remove_label`；`check_dependencies` → 间接通过 `_common.sh` |
| `finish-issue.sh` | 3 处 | `gh issue view --json body` → `provider_get_issue_body`；`gh issue view --json state` → `provider_get_issue_state`；`gh issue close` → `provider_close_issue` |
| `link-pr.sh` | 4 处 | `gh pr list` → `provider_list_prs`；`gh pr create` → `provider_create_pr`；`gh repo view` → `provider_repo_name_with_owner`；`PR_URL` 构建适配各平台 |
| `list-issues.sh` | 5 处 | 所有 `gh issue list` → `provider_list_issues`；所有 `gh issue view` → `provider_get_issue_json` |

**不变的部分：** 计划文件解析、git 操作、Issue 编号存取（`current-issue.txt`）、checkbox 同步 awk 逻辑、标签状态机。

---

## 文件结构总结

```
scripts/
├── _common.sh              # Modify: provider_check_prerequisites, provider_ensure_label 替换
├── _provider.sh            # NEW: 平台检测 + 分发（~30 行）
├── _provider_github.sh     # NEW: GitHub backend（~100 行）
├── _provider_gitee.sh      # NEW: Gitee backend（~150 行，含 curl + jq）
├── _provider_gitlab.sh     # NEW: GitLab backend（~100 行）
├── create-issue.sh         # Modify: ~5 处 gh → provider_
├── sync-status.sh          # Modify: ~3 处 gh → provider_
├── finish-issue.sh         # Modify: ~3 处 gh → provider_
├── link-pr.sh              # Modify: ~4 处 gh → provider_
└── list-issues.sh          # Modify: ~5 处 gh → provider_
```

总增量：~480 行新增，~40 行修改。

---

## 不做的

- 不引入 Python/Node.js 等新语言依赖
- 不改动 SKILL.md 和 plan-template.md（它们不感知平台）
- 不做 Gitee API 的 OAuth 流程（只用 Personal Access Token）
- GitLab 的自签证书问题由用户自行处理（`glab` 本身支持 `--insecure`）

---

## Gitee 前置准备（首次使用）

```bash
# 1. 安装 jq
brew install jq              # macOS
sudo apt install jq          # Debian/Ubuntu

# 2. 在 Gitee 后台生成 Token
#    https://gitee.com/profile/personal_access_tokens
#    权限勾选：issues、pulls、labels、repo

# 3. 设置环境变量（建议放到 ~/.zshrc 或 ~/.bashrc）
export GITEE_TOKEN="你的token"
```

---

## GitLab 前置准备（首次使用）

```bash
# 1. 安装 glab
brew install glab            # macOS
sudo apt install glab        # Debian/Ubuntu

# 2. 认证（GitLab.com 或自建实例）
glab auth login              # GitLab.com
glab auth login --hostname gitlab.mycorp.com  # 自建实例
```
