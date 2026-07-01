# auto-report-bug

自动错误反馈技能。当 ncgo-code-skills 脚本执行出错时，自动分析错误并生成 GitHub Issue。

## 触发条件

由 `hooks/auto-report-bug.sh` Stop Hook 触发。当 `.cache/bug-reports/pending.json` 存在时，Hook 输出错误摘要，Claude 读取后按以下流程执行。

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

**Step 3: 认证检查**

使用用户级认证缓存（`~/.claude/ncgo-code-skills/auth-cache.json`，24h TTL）：

```bash
AUTH_CACHE="$HOME/.claude/ncgo-code-skills/auth-cache.json"
# 检查缓存是否存在且有效（24h 内）
# 若缓存有效 → 跳过 gh auth status
# 若缓存无效/过期 → 运行 gh auth status 验证 → 更新缓存
# 若 gh 未认证 → 记录到 .cache/bug-reports/failed.log，保留 pending.json 等下次重试
```

**Step 4: 生成 Issue 内容**

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

**Step 5: 创建 Issue**

```bash
gh issue create \
  --repo byx-darwin/ncgo-code-skills \
  --title "$TITLE" \
  --body "$BODY" \
  --label "bug,auto-reported,$SKILL_NAME"
```

**Step 6: 清理 + 通知**

```bash
rm -f .cache/bug-reports/pending.json
echo "✅ Bug 报告已提交: Issue #N"
echo "   https://github.com/byx-darwin/ncgo-code-skills/issues/N"
```

## 异常处理

| 异常 | 处理 |
|------|------|
| `gh auth status` 失败 | 记录到 `.cache/bug-reports/failed.log`，保留 `pending.json` 下次重试 |
| `gh issue create` 失败 | 同上 |
| `pending.json` 格式异常 | Hook 已清理，不阻塞流程 |
| `pending.json` 不存在 | Hook 静默退出 |
| 非 git 仓库 | Hook 静默退出 |
| 认证缓存过期 | 重新验证并更新缓存 |

## 设计要点

- **认证缓存**：用户级缓存 `~/.claude/ncgo-code-skills/auth-cache.json`，24h TTL，所有项目共享
- **去重策略**：用 `[auto-report] {脚本名} L{行号}` 搜索，已存在/已评估则跳过，不重复评论
- **失败重试**：`gh` 操作失败时保留 `pending.json`，下次 Stop Hook 触发时自动重试
- **静默失败**：Hook 本身所有异常静默处理，不影响正常开发流程
