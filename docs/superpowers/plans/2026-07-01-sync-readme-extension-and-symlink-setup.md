<!-- Issue: #23 -->
# sync-readme 扩展 & 符号链接安装 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将开发仓库通过符号链接安装到 `~/.claude/skills/ncgo-code/`，扩展 sync-readme 同时维护 CLAUDE.md，并新增 check-status skill 检查安装状态。

**Architecture:** install.sh 一次性创建符号链接；sync-readme 扩展后同时更新 README.md、README.zh-CN.md、CLAUDE.md 三个文件的 `## Structure` 部分；sync-readme-check.sh Hook 同步扩展检查范围；check-status 作为独立 skill 提供 `/check-status` 命令。

**Tech Stack:** Bash, git, Claude Code skill system

## Global Constraints

- 所有脚本使用 `set -euo pipefail` + `cd_to_git_root()`，符合项目约定
- install.sh 必须幂等（多次运行不会出错）
- check-status 只检查 ncgo-code 自身的 skills，不涉及第三方 skills
- 三个文档（README.md、README.zh-CN.md、CLAUDE.md）的目录树格式必须一致

## GitHub Issue 规划

**Issue 标题:** feat: sync-readme 扩展支持 CLAUDE.md 同步，新增 check-status 和符号链接安装

**Issue 标签:** enhancement,sync-readme,check-status,priority:medium

**Issue 描述:**
扩展 sync-readme skill，在维护 README.md 和 README.zh-CN.md 的同时，也同步维护 CLAUDE.md 的 `## Structure` 部分。新增 install.sh 脚本将开发仓库通过符号链接安装到 `~/.claude/skills/ncgo-code/`，使开发变更立即生效。新增 check-status skill 提供 `/check-status` 命令，随时检查技能集合的安装完整性和配置正确性。

**验收标准:**
- [ ] install.sh 可正确创建符号链接，幂等运行
- [ ] sync-readme 可同时更新三个文档的目录结构
- [ ] sync-readme-check.sh 同时检查三个文件的一致性
- [ ] check-status skill 可正确报告安装状态
- [ ] 测试通过（手动验证 + hook 触发验证）
- [ ] 文档更新（README、CLAUDE.md 反映新 skill）

**关联:**
- 计划文件: `docs/superpowers/plans/2026-07-01-sync-readme-extension-and-symlink-setup.md`
- 设计规格: `docs/superpowers/specs/2026-07-01-sync-readme-extension-and-symlink-setup-design.md`

## File Structure

```
新增:
sync-readme/scripts/
└── install.sh                    # 符号链接安装脚本

修改:
sync-readme/SKILL.md              # 新增 CLAUDE.md 同步步骤
hooks/sync-readme-check.sh        # 增加 CLAUDE.md 一致性检查

新增:
check-status/
├── SKILL.md                      # skill 定义
└── scripts/
    └── check-status.sh           # 状态检查脚本
```

## Tasks

### Task 1: 创建 GitHub Issue

**Description:** 从 "GitHub Issue 规划" 部分提取信息，创建 Issue 并保存编号到 `.claude/gh-issue/current-issue.txt`。

- [ ] **Step 1: 运行 scripts/create-issue.sh**

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/create-issue.sh docs/superpowers/plans/2026-07-01-sync-readme-extension-and-symlink-setup.md
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

### Task 3: 实现 install.sh 符号链接安装脚本

**Description:** 创建 `sync-readme/scripts/install.sh`，将 `~/.claude/skills/ncgo-code` 配置为指向开发仓库的符号链接。

**参考设计规格：** `docs/superpowers/specs/2026-07-01-sync-readme-extension-and-symlink-setup-design.md` 第 1 节

- [ ] **Step 1: 创建 install.sh**

创建 `sync-readme/scripts/install.sh`，实现以下流程：

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. 计算开发仓库的绝对路径（install.sh → sync-readme/scripts/ → 仓库根）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL_DIR="$HOME/.claude/skills/ncgo-code"

# 2. 检查当前状态
if [ -L "$INSTALL_DIR" ]; then
    CURRENT_TARGET="$(readlink "$INSTALL_DIR")"
    if [ "$CURRENT_TARGET" = "$REPO_ROOT" ]; then
        echo "✅ 已安装: $INSTALL_DIR → $REPO_ROOT"
        exit 0
    else
        echo "⚠️  符号链接指向错误位置: $CURRENT_TARGET"
        echo "   期望指向: $REPO_ROOT"
        rm "$INSTALL_DIR"
    fi
elif [ -d "$INSTALL_DIR" ]; then
    echo "📦 发现已有安装，备份到 ${INSTALL_DIR}.bak"
    mv "$INSTALL_DIR" "${INSTALL_DIR}.bak"
fi

# 3. 创建符号链接
ln -s "$REPO_ROOT" "$INSTALL_DIR"
echo "✅ 已链接: $INSTALL_DIR → $REPO_ROOT"

# 4. 验证
if [ -f "$INSTALL_DIR/README.md" ]; then
    echo "✅ 链接验证通过"
else
    echo "❌ 链接验证失败: 无法读取 $INSTALL_DIR/README.md"
    exit 1
fi

[ -d "${INSTALL_DIR}.bak" ] && echo "📦 旧版本备份在: ${INSTALL_DIR}.bak"
```

- [ ] **Step 2: 赋予执行权限**

```bash
chmod +x sync-readme/scripts/install.sh
```

- [ ] **Step 3: 手动测试（在当前状态下）**

```bash
# 运行前确认 ~/.claude/skills/ncgo-code 的状态
ls -la ~/.claude/skills/ncgo-code

# 运行 install.sh
bash sync-readme/scripts/install.sh

# 验证结果
ls -la ~/.claude/skills/ncgo-code
```

- [ ] **Step 4: 提交**

```bash
git add sync-readme/scripts/install.sh
git commit -m "feat: add install.sh for symlink-based skill installation (#N)"
```

> 注意：将 `#N` 替换为实际的 Issue 编号。

### Task 4: 扩展 sync-readme SKILL.md 支持 CLAUDE.md 同步

**Description:** 修改 `sync-readme/SKILL.md`，新增 CLAUDE.md 的 `## Structure` 同步步骤。

**参考设计规格：** `docs/superpowers/specs/2026-07-01-sync-readme-extension-and-symlink-setup-design.md` 第 2 节

- [ ] **Step 1: 更新 SKILL.md 的流程描述**

在 `sync-readme/SKILL.md` 的 `## 流程` 部分，插入新步骤并扩展现有步骤：

在 Step 2 之后插入：
```
**Step 2.5: 对比 CLAUDE.md 中的目录结构**

读取 `CLAUDE.md` 的 `## Structure` 部分，提取当前记录的目录。
```

扩展 Step 4：
```
**Step 4: 更新 README 和 CLAUDE.md 文件**

更新三个文件的目录结构部分，使用同一棵生成的目录树。保持格式一致：
- 英文 README: `## Structure`
- 中文 README: `## 目录结构`
- CLAUDE.md: `## Structure`
```

扩展 Step 5：
```
**Step 5: 提交更改**

git add README.md README.zh-CN.md CLAUDE.md
git commit -m "docs: sync README and CLAUDE.md with actual directory structure"
```

- [ ] **Step 2: 验证 SKILL.md 格式正确**

```bash
cat sync-readme/SKILL.md
```

确认三个文件都被提及，且流程步骤编号连贯。

- [ ] **Step 3: 提交**

```bash
git add sync-readme/SKILL.md
git commit -m "feat: extend sync-readme to also sync CLAUDE.md structure (#N)"
```

### Task 5: 更新 sync-readme-check.sh Hook 检查三个文件

**Description:** 修改 `hooks/sync-readme-check.sh`，使其同时检查 README.md、README.zh-CN.md、CLAUDE.md 三个文件的 `## Structure` 部分。

**参考设计规格：** `docs/superpowers/specs/2026-07-01-sync-readme-extension-and-symlink-setup-design.md` 第 3 节

- [ ] **Step 1: 阅读现有 hook 脚本**

```bash
cat hooks/sync-readme-check.sh
```

了解当前的检查逻辑。

- [ ] **Step 2: 扩展检查范围**

在现有脚本中，将只检查 README.md 的逻辑扩展为同时检查三个文件。核心逻辑：

```bash
# 扫描实际目录结构（排除隐藏目录和 docs）
ACTUAL_DIRS=$(find . -maxdepth 1 -type d ! -name '.' ! -name '.*' ! -name 'docs' | sed 's|^\./||' | sort)

# 检查三个文件的 ## Structure 部分
NEEDS_SYNC=false

for file in README.md README.zh-CN.md CLAUDE.md; do
    if [ -f "$file" ]; then
        # 提取 ## Structure 或 ## 目录结构 部分的内容
        # 与实际目录对比
        # 如果不一致，标记 NEEDS_SYNC=true
    fi
done

if [ "$NEEDS_SYNC" = true ]; then
    echo "⚠️  目录结构与文档不一致，建议运行 /sync-readme"
fi
```

具体实现需参考现有脚本的解析方式，保持一致。

- [ ] **Step 3: 测试 Hook**

```bash
# 手动运行检查
bash hooks/sync-readme-check.sh
```

确认在一致/不一致状态下都能正确报告。

- [ ] **Step 4: 提交**

```bash
git add hooks/sync-readme-check.sh
git commit -m "feat: extend sync-readme-check hook to verify CLAUDE.md (#N)"
```

### Task 6: 创建 check-status skill

**Description:** 创建 `check-status/` skill，提供 `/check-status` 命令检查 ncgo-code 技能集合的安装状态。

**参考设计规格：** `docs/superpowers/specs/2026-07-01-sync-readme-extension-and-symlink-setup-design.md` 第 4 节

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p check-status/scripts
```

- [ ] **Step 2: 编写 SKILL.md**

创建 `check-status/SKILL.md`：

```markdown
# check-status

检查 ncgo-code 技能集合的安装完整性和配置正确性。

## 触发条件

手动触发：
```
/check-status
```

自然语言触发：
```
"检查技能安装状态"
"ncgo-code 是否正常"
"skill status"
```

## 流程

**Step 1: 运行 check-status.sh**

```bash
bash [base-dir]/scripts/check-status.sh
```

脚本将检查：
1. 符号链接状态（`~/.claude/skills/ncgo-code` 是否为符号链接，指向哪里）
2. Skills 完整性（所有预期 skill 是否包含 SKILL.md）
3. Hooks 注册状态（`.claude/settings.json` 中是否注册了所有 hook）
4. 文档同步状态（目录数量是否与 README/CLAUDE.md 记录一致）

**Step 2: 输出状态报告**

脚本输出格式示例：

```
ncgo-code 状态报告
──────────────────
📍 安装位置: ~/.claude/skills/ncgo-code → /path/to/repo (符号链接 ✅)

Skills (7/7 ✅):
  ✅ auto-report-bug
  ✅ brainstorm-from-issue
  ✅ check-status
  ✅ issue-status
  ✅ sync-readme
  ✅ weekly-report
  ✅ writing-plans-with-issue

Hooks (3/3 ✅):
  ✅ auto-report-bug.sh
  ✅ auto-smoke-test.sh
  ✅ sync-readme-check.sh

文档同步: ✅ 一致
```

## 注意事项

- 只检查 ncgo-code 自身的 skills，不涉及第三方
- 符号链接检查：如为普通目录，建议运行 install.sh
- Hook 检查：读取当前项目的 `.claude/settings.json`
- 文档同步检查为轻量级（只比较目录数量）
```

- [ ] **Step 3: 编写 check-status.sh**

创建 `check-status/scripts/check-status.sh`，实现以下检查：

```bash
#!/usr/bin/env bash
set -euo pipefail

# 切换到 git 仓库根目录
cd_to_git_root() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
        echo "❌ 不在 git 仓库中"
        exit 1
    }
    cd "$root"
}

cd_to_git_root
REPO_ROOT="$(pwd)"
INSTALL_DIR="$HOME/.claude/skills/ncgo-code"

echo "ncgo-code 状态报告"
echo "──────────────────"

# 1. 符号链接状态
echo ""
echo "📍 安装位置:"
if [ -L "$INSTALL_DIR" ]; then
    TARGET="$(readlink "$INSTALL_DIR")"
    if [ "$TARGET" = "$REPO_ROOT" ]; then
        echo "   $INSTALL_DIR → $REPO_ROOT (符号链接 ✅)"
    else
        echo "   $INSTALL_DIR → $TARGET (符号链接，但指向非当前仓库 ⚠️)"
    fi
elif [ -d "$INSTALL_DIR" ]; then
    echo "   $INSTALL_DIR (普通目录，未链接到开发仓库 ⚠️)"
    echo "   建议运行: bash $REPO_ROOT/sync-readme/scripts/install.sh"
else
    echo "   $INSTALL_DIR (不存在 ❌)"
fi

# 2. Skills 完整性
echo ""
echo "Skills:"
EXPECTED_SKILLS=("auto-report-bug" "brainstorm-from-issue" "check-status" "issue-status" "sync-readme" "weekly-report" "writing-plans-with-issue")
SKILL_OK=0
SKILL_TOTAL=${#EXPECTED_SKILLS[@]}

for skill in "${EXPECTED_SKILLS[@]}"; do
    if [ -f "$skill/SKILL.md" ]; then
        echo "  ✅ $skill"
        ((SKILL_OK++))
    else
        echo "  ❌ $skill (缺少 SKILL.md)"
    fi
done
echo "  ($SKILL_OK/$SKILL_TOTAL)"

# 3. Hooks 注册状态
echo ""
echo "Hooks:"
SETTINGS_FILE=".claude/settings.json"
EXPECTED_HOOKS=("auto-report-bug.sh" "auto-smoke-test.sh" "sync-readme-check.sh")
HOOK_OK=0
HOOK_TOTAL=${#EXPECTED_HOOKS[@]}

for hook in "${EXPECTED_HOOKS[@]}"; do
    if [ -f "hooks/$hook" ] && grep -q "$hook" "$SETTINGS_FILE" 2>/dev/null; then
        echo "  ✅ $hook"
        ((HOOK_OK++))
    elif [ ! -f "hooks/$hook" ]; then
        echo "  ❌ $hook (脚本文件不存在)"
    else
        echo "  ❌ $hook (未在 settings.json 中注册)"
    fi
done
echo "  ($HOOK_OK/$HOOK_TOTAL)"

# 4. 文档同步状态（轻量检查）
echo ""
echo "文档同步:"
ACTUAL_COUNT=$(find . -maxdepth 1 -type d ! -name '.' ! -name '.*' ! -name 'docs' | wc -l | tr -d ' ')
README_COUNT=$(grep -c "├── \|[└]── " README.md 2>/dev/null || echo 0)
# 简化比较：数量是否大致匹配
if [ "$ACTUAL_COUNT" -gt 0 ] && [ "$README_COUNT" -gt 0 ]; then
    echo "  ✅ 目录数量一致 ($ACTUAL_COUNT 个 skill 目录)"
else
    echo "  ⚠️  可能不一致，建议运行 /sync-readme"
fi
```

- [ ] **Step 4: 赋予执行权限**

```bash
chmod +x check-status/scripts/check-status.sh
```

- [ ] **Step 5: 手动测试**

```bash
bash check-status/scripts/check-status.sh
```

验证输出格式和检查项正确。

- [ ] **Step 6: 提交**

```bash
git add check-status/
git commit -m "feat: add check-status skill for installation status verification (#N)"
```

### Task 7: 同步文档（运行 sync-readme）

**Description:** 运行 sync-readme 流程，将新增的 check-status skill 和 install.sh 脚本同步到 README.md、README.zh-CN.md、CLAUDE.md 的 `## Structure` 部分。

- [ ] **Step 1: 触发 /sync-readme**

使用 `/sync-readme` 命令，或按照 sync-readme SKILL.md 的流程手动执行。

- [ ] **Step 2: 验证三个文件都已更新**

```bash
grep -A 30 "## Structure" README.md
grep -A 30 "## 目录结构" README.zh-CN.md
grep -A 30 "## Structure" CLAUDE.md
```

确认三个文件都包含 `check-status/` 和 `sync-readme/scripts/install.sh`。

- [ ] **Step 3: 提交文档同步**

```bash
git add README.md README.zh-CN.md CLAUDE.md
git commit -m "docs: sync directory structure with new check-status skill and install.sh (#N)"
```

### Task 8: 收尾 — 本地合并后关闭 Issue

**Description:** 开发完成并本地合并到 base 分支后，push 并关闭 Issue。

- [ ] **Step 1: 确保已合并到 base 分支**

```bash
git branch --show-current  # 应该在 main/master 上
```

- [ ] **Step 2: 运行 scripts/finish-issue.sh**

`finish-issue.sh` 会自动：
1. 将 Issue `## 验收标准` 下的 `- [ ]` 替换为 `- [x]`
2. Push base 分支
3. 关闭 Issue
4. 清理 local state

```bash
bash /Users/baoyx/.claude/skills/writing-plans-with-issue/scripts/finish-issue.sh
```

- [ ] **Step 3: 确认 Issue 已关闭且 checkbox 已打钩**

```bash
gh issue view "$(cat .claude/gh-issue/current-issue.txt 2>/dev/null || echo 'already cleaned')"
```
