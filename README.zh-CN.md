# ncgo-code

Claude Code 开发全流程技能集 — 计划、Issue 跟踪、PR 自动化、周报生成。与 [Superpowers](https://github.com/obra/Superpowers) 配合使用。

## 安装

```bash
# 1. Superpowers
git clone https://github.com/obra/Superpowers.git ~/.claude/skills/superpowers

# 2. ncgo-code
git clone https://github.com/byx-darwin/ncgo-code-skills.git ~/.claude/skills/ncgo-code

# 3. GitHub CLI
brew install gh && gh auth login
```

## 技能

### `writing-plans-with-issue` (ncgo-code)

生成实现计划，Task 1 自动创建 Issue。在写任何代码之前拿到 Issue #N，后续所有 commit 引用 `(#N)`。

```
"给新功能写个实现方案"
```

### `issue-status` (ncgo-code)

更新当前活跃 Issue 的状态标签。自动读取 `.claude/gh-issue/current-issue.txt`。

```
"标记完成" / "提交审查" / "开始开发"
```

### `weekly-report` (ncgo-code)

扫描一个或多个 Git 仓库，按项目分组生成结构化研发周报。支持自定义截止时间和多项目聚合，输出纯文本格式（无表格）。

```
"生成本周周报" / "项目A 项目B 周报，周五 18:00 截止"
```

## 完整流程

从想法到 PR 合并的每一步，以及涉及的 skill：

```
第一步 — 头脑风暴（可选）
  superpowers:brainstorming
  → 澄清需求，明确范围

第二步 — 创建计划 + Issue
  /writing-plans-with-issue
  → 计划文件 + Issue 元数据
  → Task 1: 创建 Issue (#N)
  → Task 2: 同步状态为 in-progress

  输出:
  ✅ 计划已生成: docs/superpowers/plans/xxx.md
  现在可以开始开发了:
    /subagent-driven-development docs/superpowers/plans/xxx.md

第三步 — 隔离工作空间（推荐）
  superpowers:using-git-worktrees
  → git worktree add -b feat/xxx ../xxx-worktree main

第四步 — 执行开发任务
  /subagent-driven-development docs/superpowers/plans/xxx.md
  → 逐个执行任务，commit 引用 (#N)

第五步 — 管理状态
  /issue-status "in-review"   ← 提 PR 前
  /issue-status "done"        ← 合并后

第六步 — 创建 PR
  superpowers:finishing-a-development-branch
  → 选择 "创建 PR"
  → link-pr.sh: PR 关联 "Closes #N"

第七步 — 合并
  PR 合并 → GitHub 自动关闭 Issue #N ✅
```

## 目录结构

```
~/.claude/skills/ncgo-code/
├── LICENSE
├── README.md / README.zh-CN.md
├── issue-status/
│   └── SKILL.md
├── weekly-report/
│   └── SKILL.md
└── writing-plans-with-issue/
    ├── SKILL.md
    ├── plan-template.md
    └── scripts/
        ├── create-issue.sh      # 解析计划 → gh issue create
        ├── sync-status.sh       # 更新 Issue 标签
        ├── link-pr.sh           # 创建 PR + Closes #N
        └── list-issues.sh       # 按状态列出 Issue
```

## 许可证

MIT — 详见 [LICENSE](LICENSE)
