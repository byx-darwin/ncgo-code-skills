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
