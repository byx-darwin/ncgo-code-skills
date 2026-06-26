# launch-sdd.sh 自动启动 SDD 执行方案

**日期:** 2026-06-26
**状态:** 方案讨论 — 待决策

## 背景

`writing-plans-with-issue` skill 生成计划文件后，当前需要用户手动执行：

```
/subagent-driven-development docs/superpowers/plans/xxx.md
```

这一步是人工操作，理想流程是「计划生成 → 自动打开新窗口 → SDD 自动执行」。

## 方案对比

| 方案 | 原理 | 优点 | 缺点 |
|------|------|------|------|
| **A. SKILL.md 末尾打印命令** | plan 生成后输出可复制的 shell 命令 | 零侵入，完全用户可控 | 需手动复制粘贴，易遗忘 |
| **B. launch-sdd.sh 脚本** | 独立脚本检测终端类型，新窗口执行 | 封装好，跨终端，可复用 | 平台相关（macOS/Linux/Windows 各不同） |
| **C. Claude Code hooks** | settings.json 监听 Skill 事件自动触发 | 全自动，无感 | `claude` 自调用风险高，调试困难，死循环风险 |

### 推荐: 方案 B — `scripts/launch-sdd.sh`

## 详细设计

### 文件结构

```
writing-plans-with-issue/scripts/
├── _common.sh
├── create-issue.sh
├── sync-status.sh
├── link-pr.sh
├── finish-issue.sh
├── launch-sdd.sh          ← 新增
└── sdd-agent-config.sh    ← 可选：配置文件
```

### launch-sdd.sh 核心逻辑

```bash
#!/bin/bash
# 用法: launch-sdd.sh <plan-file> [ai-tool]

# 参数
PLAN_FILE="${1:-}"
AI_TOOL="${2:-claude}"

# 1. 检测终端类型
detect_terminal() {
  case "$(uname -s)" in
    Darwin)
      # 优先 iTerm2，其次 Terminal.app
      if osascript -e 'id of app "iTerm"' &>/dev/null; then echo "iterm2"
      else echo "terminal"
      fi
      ;;
    Linux)
      if command -v gnome-terminal &>/dev/null; then echo "gnome"
      elif command -v konsole &>/dev/null; then echo "konsole"
      elif command -v xterm &>/dev/null; then echo "xterm"
      else echo "unknown"
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# 2. 构建启动命令
build_command() {
  case "$AI_TOOL" in
    claude)
      echo "claude --dangerously-skip-permissions -p '/subagent-driven-development $PLAN_FILE'"
      ;;
    codex)
      echo "codex exec /subagent-driven-development $PLAN_FILE"
      ;;
    *)
      echo "$AI_TOOL /subagent-driven-development $PLAN_FILE"
      ;;
  esac
}

# 3. 新窗口启动
LAUNCH_CMD=$(build_command)
TERM=$(detect_terminal)
WORKDIR=$(pwd)

case "$TERM" in
  iterm2)
    osascript -e "tell app \"iTerm\"
      tell current window
        create tab with default profile
        tell current session
          write text \"cd $WORKDIR && clear && $LAUNCH_CMD\"
        end tell
      end tell
    end tell"
    ;;
  terminal)
    osascript -e "tell app \"Terminal\"
      do script \"cd $WORKDIR && clear && $LAUNCH_CMD\"
      activate
    end tell"
    ;;
  gnome)
    gnome-terminal -- bash -c "cd $WORKDIR && $LAUNCH_CMD; exec bash"
    ;;
  *)
    echo "Unsupported terminal. Run manually: $LAUNCH_CMD"
    ;;
esac
```

### SKILL.md 交互改造

```
✅ 计划已生成: docs/superpowers/plans/xxx.md

执行方式:
1. 自动打开新窗口执行 SDD → bash [base-dir]/scripts/launch-sdd.sh <plan-file>
2. 手动在当前窗口执行       → /subagent-driven-development <plan-file>
3. 稍后处理

按数字选择:
```

## 待决策项

| # | 议题 | 待定 |
|---|------|------|
| 1 | `--dangerously-skip-permissions` 是 Claude Code 专属 flag，其他工具/平台无此概念。脚本中硬编码还是做成可配置？ | 参数化 |
| 2 | 新窗口 vs 新 tab vs 后台进程 — 不同开发者有不同习惯 | 先支持新 tab，后续加配置 |
| 3 | Windows 兼容 — `osascript` 仅 macOS，Linux 用 `gnome-terminal` | 待补充 Windows Terminal |
| 4 | 如果计划文件还没执行 Task 1（未创建 Issue），是否先跑 create-issue.sh？ | 默认跳过，让 SDD 执行器自己跑 |
| 5 | 是否需要独立的 "SDD Agent" 来接管整个流程（计划→执行→审查→关闭） | 远期考虑，先看脚本够不够用 |

## 后续方向

如果 `launch-sdd.sh` 脚本方案验证可行，可以考虑抽离为独立的 Claude Code Agent：

```
Agent: sdd-executor
  - 输入: plan 文件路径
  - 自动执行: Task 1 → Task 2 → ... → Task N → finish-issue.sh
  - 不依赖新窗口，在后台 session 中完成全部流程
  - 用户只需提供 plan 文件，一切自动完成
```

这个 Agent 可以做成 `writing-plans-with-issue` 的配套 skill，专门处理「从 plan 到 merge 的全自动流水线」。
