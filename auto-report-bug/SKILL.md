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
