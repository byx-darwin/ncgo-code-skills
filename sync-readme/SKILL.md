# sync-readme

同步 README 文档与实际目录结构。当新增或删除技能/脚本时，自动更新 README.md 和 README.zh-CN.md。

## 触发条件

手动触发：
```
/sync-readme
```

或由 Stop Hook 提醒后执行。

## 流程

**Step 1: 扫描实际目录结构**

```bash
# 获取所有顶级目录（排除隐藏目录和 docs）
find . -maxdepth 1 -type d ! -name '.' ! -name '.*' ! -name 'docs' | sed 's|^\./||' | sort
```

**Step 2: 对比 README 中的目录结构**

读取 `README.md` 和 `README.zh-CN.md` 的 `## Structure` / `## 目录结构` 部分，提取当前记录的目录。

**Step 3: 生成更新内容**

对于每个变化：
- **新增目录**：添加到目录结构中，按字母顺序插入
- **删除目录**：从目录结构中移除
- **新增脚本**：在对应技能目录下添加脚本条目

**Step 4: 更新 README 文件**

更新两个 README 文件的目录结构部分。保持格式一致：
- 英文 README: `## Structure`
- 中文 README: `## 目录结构`

**Step 5: 提交更改**

```bash
git add README.md README.zh-CN.md
git commit -m "docs: sync README with actual directory structure"
```

## 目录结构格式

```
~/.claude/skills/ncgo-code/
├── LICENSE
├── README.md / README.zh-CN.md
├── <skill-name>/
│   ├── SKILL.md
│   └── scripts/
│       └── <script-name>.sh    # 简短描述
├── hooks/
│   ├── <hook-name>.sh
│   └── ...
└── ...
```

## 注意事项

- 技能目录按字母顺序排列
- 每个脚本后添加简短注释说明用途
- `hooks/` 目录单独列出，不属于技能
- 保持中英文 README 同步
