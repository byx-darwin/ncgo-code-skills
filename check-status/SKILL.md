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
"查看技能状态"
```

## 流程

**Step 1: 运行 check-status.sh**

```bash
bash [base-dir]/scripts/check-status.sh
```

脚本将检查：
1. **符号链接状态**：`~/.claude/skills/ncgo-code` 是否为符号链接，指向哪里
2. **Skills 完整性**：所有预期 skill 是否包含 SKILL.md
3. **Hooks 注册状态**：`.claude/settings.json` 中是否注册了所有 hook
4. **文档同步状态**：目录数量是否与 README/CLAUDE.md 记录一致

**Step 2: 输出状态报告**

脚本输出格式示例（正常状态）：

```
ncgo-code 状态报告
──────────────────
📍 开发仓库: /path/to/ncgo-code-skills
📍 安装位置: ~/.claude/skills/ (每个 skill 单独符号链接)

Skills (8/8 ✅):
  ✅ auto-report-bug (符号链接 → 开发仓库)
  ✅ brainstorm-from-issue (符号链接 → 开发仓库)
  ✅ check-status (符号链接 → 开发仓库)
  ✅ issue-status (符号链接 → 开发仓库)
  ✅ sync-readme (符号链接 → 开发仓库)
  ✅ weekly-report (符号链接 → 开发仓库)
  ✅ writing-plans-with-issue (符号链接 → 开发仓库)

Hooks (3/3 ✅):
  ✅ auto-report-bug.sh
  ✅ auto-smoke-test.sh
  ✅ sync-readme-check.sh

文档同步: ✅ 一致
```

## 注意事项

- 只检查 ncgo-code 自身的 skills，不涉及第三方
- 符号链接检查：如为普通目录，建议运行 `install.sh`
- Hook 检查：读取当前项目的 `.claude/settings.json`
- 文档同步检查为轻量级（只比较目录数量）
