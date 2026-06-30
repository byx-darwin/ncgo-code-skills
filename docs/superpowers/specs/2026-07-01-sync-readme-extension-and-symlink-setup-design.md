# sync-readme 扩展 & 符号链接安装设计

## 概述

本次扩展涉及三个相关功能：

1. **符号链接安装机制**：将 `~/.claude/skills/ncgo-code` 从独立副本改为指向开发仓库的符号链接，使开发变更立即在安装位置生效，无需手动同步。
2. **sync-readme 扩展**：让 `sync-readme` skill 在维护 README.md 和 README.zh-CN.md 的同时，也同步维护项目根目录 `CLAUDE.md` 的 `## Structure` 部分。
3. **check-status 新 skill**：提供 `/check-status` 命令，随时检查 ncgo-code 技能集合的安装完整性和配置正确性。

附带更新 `sync-readme-check.sh` Stop Hook，使其同时检查三个文件的一致性。

## 动机

当前工作流：在开发仓库 (`/path/to/ncgo-code-skills/`) 编辑 skill 文件后，需要手动将变更复制到安装位置 (`~/.claude/skills/ncgo-code/`)，否则 Claude Code 读取的仍是旧版本。这容易遗忘，且增加维护负担。

使用符号链接方案后：
- 开发仓库就是安装位置（通过链接）
- 改动立即生效，无需同步步骤
- 零运行时开销

同时，CLAUDE.md 作为 Claude 读取的项目指南，其中的 `## Structure` 目录树与实际目录脱节时，会导致 Claude 对项目的理解不准确。让 sync-readme 同时维护该文件，保持文档与实际状态一致。

## 设计

### 1. `install.sh`：符号链接安装脚本

**位置**：`sync-readme/scripts/install.sh`

**职责**：一次性将 `~/.claude/skills/ncgo-code` 配置为指向开发仓库的符号链接。

**流程**：

```
1. 计算开发仓库的绝对路径
   （通过脚本自身位置推导：install.sh → sync-readme/scripts/ → 仓库根目录）

2. 检查 ~/.claude/skills/ncgo-code 的状态：
   ├─ 已是符号链接且指向正确 → 报告"已安装"，退出
   ├─ 是符号链接但指向错误位置 → 删除，继续
   ├─ 是普通目录 → 备份为 ncgo-code.bak，继续
   └─ 不存在 → 直接创建

3. 创建符号链接：
   ln -s <dev-repo-absolute-path> ~/.claude/skills/ncgo-code

4. 验证链接有效（能读取 SKILL.md）

5. 输出结果：
   ✅ 已链接: ~/.claude/skills/ncgo-code → /path/to/dev/repo
   📦 旧版本已备份到: ~/.claude/skills/ncgo-code.bak（如适用）
```

**约束**：
- 幂等：多次运行不会出问题
- 不自动删除 `.bak`，留给用户确认后再清理
- 使用 `set -euo pipefail`，符合项目约定

### 2. sync-readme SKILL.md 扩展

**修改文件**：`sync-readme/SKILL.md`

**扩展内容**：

在现有流程（扫描目录 → 更新 README.md + README.zh-CN.md）基础上，增加对 CLAUDE.md 的同步。

#### 新增步骤

```
Step 2.5: 解析 CLAUDE.md 的 ## Structure 部分

读取 CLAUDE.md，定位 ## Structure section header，
提取从该 header 到下一个同级 ## header 之间的内容作为"当前记录"。

Step 4（扩展）: 更新 CLAUDE.md

将生成的目录树替换 CLAUDE.md 中 ## Structure 部分的内容。
保持 section header 不变，只替换其下方的目录树内容。

Step 5（扩展）: 提交时包含 CLAUDE.md

git add README.md README.zh-CN.md CLAUDE.md
git commit -m "docs: sync README and CLAUDE.md with actual directory structure"
```

#### 树格式统一

README.md、README.zh-CN.md、CLAUDE.md 使用同一棵生成的目录树，格式统一为：

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

CLAUDE.md 当前使用的简化格式被替换为详细格式。信息更丰富对 Claude 理解项目状态没有坏处，且三个文件保持一致更容易维护。

### 3. `sync-readme-check.sh` Hook 更新

**修改文件**：`hooks/sync-readme-check.sh`

**当前行为**：只比较目录结构与 README.md 的 `## Structure` 部分。

**扩展行为**：同时检查三个文件：
- `README.md`（`## Structure`）
- `README.zh-CN.md`（`## 目录结构`）
- `CLAUDE.md`（`## Structure`）

任一文件的目录树与实际目录不一致时，输出提醒用户运行 `/sync-readme`。

### 4. `check-status` 新 skill

**位置**：`check-status/`（新增顶级 skill 目录）

**触发方式**：`/check-status` 或自然语言（"检查技能安装状态"、"ncgo-code 是否正常"）

**职责**：检查 ncgo-code 技能集合的安装完整性和配置正确性，输出状态报告。

**检查项**：

```
1. 符号链接状态
   └─ ~/.claude/skills/ncgo-code 是否为符号链接，指向哪个路径

2. Skills 完整性
   └─ 扫描仓库根目录，列出所有包含 SKILL.md 的目录
   └─ 与预期列表对比，报告缺失或多余的 skill

3. Hooks 注册状态
   └─ 读取当前项目的 .claude/settings.json
   └─ 检查 hooks/ 目录下的 3 个 hook 脚本是否都已注册
   └─ 报告未注册的 hook

4. 文档同步状态（可选，轻量检查）
   └─ 比较目录数量与 README/CLAUDE.md 中 ## Structure 记录的目录数量
   └─ 数量不一致时提示用户运行 /sync-readme
```

**输出格式**：

```
ncgo-code 状态报告
──────────────────
📍 安装位置: ~/.claude/skills/ncgo-code → /path/to/dev/repo (符号链接)

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

或有不一致时：

```
ncgo-code 状态报告
──────────────────
📍 安装位置: ~/.claude/skills/ncgo-code (普通目录，未链接到开发仓库)
   ⚠️ 建议运行: bash ~/.claude/skills/ncgo-code/sync-readme/scripts/install.sh

Skills (6/7):
  ✅ auto-report-bug
  ✅ brainstorm-from-issue
  ...
  ❌ check-status (缺少 SKILL.md)

Hooks (2/3):
  ✅ auto-report-bug.sh
  ✅ auto-smoke-test.sh
  ❌ sync-readme-check.sh (未注册)

文档同步: ⚠️ 不一致，建议运行 /sync-readme
```

**实现文件**：
- `check-status/SKILL.md`：skill 定义
- `check-status/scripts/check-status.sh`：检查逻辑

## 文件变更汇总

| 文件 | 操作 | 说明 |
|------|------|------|
| `sync-readme/scripts/install.sh` | 新增 | 符号链接安装脚本 |
| `sync-readme/SKILL.md` | 修改 | 新增 CLAUDE.md 同步步骤 |
| `hooks/sync-readme-check.sh` | 修改 | 增加 CLAUDE.md 一致性检查 |
| `check-status/SKILL.md` | 新增 | check-status skill 定义 |
| `check-status/scripts/check-status.sh` | 新增 | 状态检查脚本 |

## 测试方式

### install.sh 测试

```bash
# 1. 当前已安装状态（普通目录）→ 应备份并创建符号链接
bash sync-readme/scripts/install.sh
ls -la ~/.claude/skills/ncgo-code   # 应为符号链接

# 2. 重复运行（已为符号链接）→ 应报告"已安装"
bash sync-readme/scripts/install.sh

# 3. 删除符号链接后运行 → 应重新创建
rm ~/.claude/skills/ncgo-code
bash sync-readme/scripts/install.sh
```

### sync-readme 扩展测试

```bash
# 1. 在开发仓库新增一个测试 skill 目录
mkdir -p test-skill && echo "# test" > test-skill/SKILL.md

# 2. 运行 sync-readme（手动触发）
# 验证 README.md、README.zh-CN.md、CLAUDE.md 的 ## Structure 都已更新

# 3. 清理
rm -rf test-skill
# 再次运行 sync-readme 验证目录树已移除 test-skill
```

### Hook 测试

修改一个 skill 目录后触发 Stop Hook，验证提醒消息正常输出。

### check-status 测试

```bash
# 1. 正常状态：符号链接已配置，所有 skills 和 hooks 完整
bash check-status/scripts/check-status.sh
# 预期：全部 ✅

# 2. 模拟 skill 缺失：临时移除一个 SKILL.md
mv auto-report-bug/SKILL.md auto-report-bug/SKILL.md.bak
bash check-status/scripts/check-status.sh
# 预期：auto-report-bug 报告 ❌

# 3. 恢复
mv auto-report-bug/SKILL.md.bak auto-report-bug/SKILL.md
```
