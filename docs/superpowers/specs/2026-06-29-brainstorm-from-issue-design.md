# Brainstorm From Issue — Design Spec

**日期:** 2026-06-29
**状态:** 已确认
**关联 Issue:** #10

## 目标

新增独立 skill `brainstorm-from-issue`：获取仓库所有 open issues，按业务领域语义分类，生成分类报告供用户确认，然后逐分类启动 brainstorming，每个分类输出独立 spec 文件。支持功能需求和 Bug 两种 Issue 类型。

## 文件结构

```
brainstorm-from-issue/
├── SKILL.md                    # skill 指令（核心逻辑）
└── scripts/
    └── fetch-open-issues.sh    # 获取所有 open issues 并输出 JSON
```

**关键设计：**
- `fetch-open-issues.sh` 复用 `writing-plans-with-issue/scripts/` 中的 Provider 层（`_provider.sh` + 各 backend），通过 `source` 引用，不重复代码
- 脚本输出 JSON 数组到 stdout，每个元素包含 `{number, title, body, labels, url}`
- SKILL.md 是 skill 的核心——引导 Claude 完成分类 → 报告 → brainstorming → spec 输出的全流程
- 无额外依赖，只需已有的 Provider 脚本

## 平台支持

GitHub / Gitee / GitLab 三平台，复用 Provider 层自动检测平台并调用对应 backend。

## Workflow 流程

```
1. 前置检查
   ├─ 检查 Provider 脚本是否存在（writing-plans-with-issue/scripts/）
   └─ 检查平台认证（gh / GITEE_TOKEN / glab）

2. 获取 Issues
   └─ 运行 fetch-open-issues.sh → 输出 JSON 数组
      └─ 若无 open issues → 提示"没有 open issues"并退出

3. 分类归纳
   └─ Claude 读取 JSON，按业务领域语义分组
      └─ 输出分类报告（表格形式：分类名 | Issue 编号列表 | 摘要）

4. 用户确认分类
   └─ 展示报告 → 用户可调整（移动 Issue、合并/拆分分类）
      └─ 用户确认 → 进入下一步

5. 逐分类 Brainstorming
   └─ 对每个分类：
      ├─ 将该分类下所有 Issue 内容注入为上下文
      ├─ Claude 按 brainstorming 流程推进（提问、方案对比、设计）
      │  ├─ 功能需求 → 设计功能方案
      │  └─ Bug → 分析根因、修复方案
      ├─ 生成 spec 文件 → docs/superpowers/specs/YYYY-MM-DD-<分类名>-design.md
      └─ 用户审查 spec → 修改或确认

6. 衔接下一步
   └─ 所有 spec 完成后，提示用户：
      "是否为某个 spec 创建实现计划？调用 writing-plans-with-issue"
```

## fetch-open-issues.sh 脚本设计

**输入：** 无参数（自动检测当前仓库和平台）。可选参数 `--limit N` 控制最大获取数量（默认 100）。

**输出：** stdout 输出 JSON 数组

```json
[
  {
    "number": 10,
    "title": "feat: 支持 Gitee 平台",
    "body": "Issue 正文内容...",
    "labels": ["enhancement", "priority:high"],
    "url": "https://github.com/owner/repo/issues/10"
  }
]
```

**实现要点：**
- `source` Provider 层脚本（`_provider.sh`），自动检测平台
- 调用 `provider_list_issues(state="open", limit=100)` 获取所有 open issues 的基础信息（number, title, labels, url）
- 对每个 issue 调用 `provider_get_issue_body(number)` 获取正文
- 组装 JSON 输出（依赖 `jq` 构建，与 Gitee backend 一致）

**错误处理：**
- Provider 前置检查失败 → 输出安装引导并 `exit 1`
- 无 open issues → 输出 `[]`（空数组），不报错

## 分类报告格式

展示给用户的表格示例：

```
📋 共 12 个 open issues，归纳为 3 个业务分类：

| # | 分类 | Issues | 类型 | 摘要 |
|---|------|--------|------|------|
| 1 | Issue 管理增强 | #10, #7, #3 | 功能 | 多平台支持、标签自动同步、批量操作 |
| 2 | PR 工作流 | #8, #5 | 功能 | PR 模板、自动关联 Issue |
| 3 | 脚本 Bug 修复 | #12, #9, #4 | Bug | 标签空格问题、状态同步竞态、JSON 解析失败 |

如需调整（移动 Issue、合并/拆分分类），请告诉我。确认后开始逐个 brainstorming。
```

## Brainstorming 集成要点

- 每个分类的 brainstorming 是独立的交互式会话——Claude 读取该分类下所有 Issue 的完整内容作为初始上下文
- 功能类 Issue → 按 brainstorming 标准流程（提问 → 方案对比 → 设计）
- Bug 类 Issue → 先分析根因，再设计修复方案（同样遵循 brainstorming 流程，但起点是问题诊断）
- 混合分类（既有功能又有 Bug）→ Claude 先处理 Bug，再处理功能需求
- 每个分类完成后生成 spec 文件，用户审查确认后再进入下一个分类

## 不做的

- **不做自动调用 `writing-plans-with-issue`**——只提示用户，由用户决定是否衔接
- **不做 Issue 创建/修改**——只读，不写
- **不做历史 Issues（closed）分析**——只关注 open issues
- **不做跨仓库聚合**——只分析当前仓库
- **不重复 Provider 代码**——`source` 引用已有脚本
