# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits, naming and copy rules, platform requirements — one line each, with exact values copied verbatim from the spec. Every task's requirements implicitly include this section.]

---

## GitHub Issue 规划

**Issue 标题:** feat: [功能名称]

**Issue 标签:** enhancement, [module], [priority]
<!-- 
标签说明：
- 类型：enhancement（新功能）, bug（修复）, refactor（重构）, docs（文档）, test（测试）
- 模块：go-common, go-middleware, go-framework, 或具体包名
- 优先级：priority:high, priority:medium, priority:low
-->

**Issue 描述:**
[2-3 句话描述这个功能的目的和价值。回答：为什么要做这个功能？它解决什么问题？对用户有什么好处？]

**验收标准:**
- [ ] 所有任务完成
- [ ] 测试通过（单元测试 + 集成测试）
- [ ] 代码审查通过
- [ ] 文档更新
- [ ] 覆盖率 > 80%
- [ ] [具体的功能验收标准 1]
- [ ] [具体的功能验收标准 2]
- [ ] [具体的功能验收标准 3]

**关联:**
- 计划文件: `docs/superpowers/plans/YYYY-MM-DD-feature-name.md`
- 里程碑: [可选，如 v1.2.0]
- 依赖: [可选，其他 Issue 编号，如 #123]

---

## File Structure

[Which files will be created or modified and what each one is responsible for. Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.]

```
path/to/module/
├── file1.go           # 职责说明
├── file1_test.go      # 测试
├── file2.go           # 职责说明
└── file2_test.go      # 测试
```

---

## Tasks

### Task 1.1: [Component Name]

**Files:**
- Create: `exact/path/to/file.go`
- Modify: `exact/path/to/existing.go:123-145`
- Test: `exact/path/to/file_test.go`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter and return types]

- [ ] **Step 1: Write the failing test**

```go
// exact/path/to/file_test.go
package package_test

import (
    "testing"
    "github.com/byx-darwin/go-tools/path/to/package"
    "github.com/stretchr/testify/require"
)

func TestFunctionName(t *testing.T) {
    // Arrange
    input := "test input"
    
    // Act
    result := package.FunctionName(input)
    
    // Assert
    require.Equal(t, "expected", result)
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd go-common && go test ./path/to/package/... -run TestFunctionName -v
```

Expected: FAIL — `FunctionName` undefined

- [ ] **Step 3: Implement minimal code to make test pass**

```go
// exact/path/to/file.go
package package

// FunctionName does something useful.
func FunctionName(input string) string {
    // Minimal implementation
    return "expected"
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd go-common && go test ./path/to/package/... -run TestFunctionName -v
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add exact/path/to/file.go exact/path/to/file_test.go
git commit -m "feat(package): add FunctionName"
```

---

### Task 1.2: [Component Name]

**Files:**
- Create: `exact/path/to/file.go`
- Create: `exact/path/to/file_test.go`

**Interfaces:**
- Consumes: `FunctionName` from Task 1.1
- Produces: `AnotherFunction`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement minimal code**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

## Validation

### Build Verification

```bash
# Build all modules
go build ./go-common/... ./go-middleware/... ./go-framework/...

# Test all modules
go test ./go-common/... ./go-middleware/... ./go-framework/... -count=1

# Lint
for m in go-common go-middleware go-framework; do
  golangci-lint run --timeout=5m ./$m/...
done
```

### Coverage Check

```bash
go test -coverprofile=coverage.out ./go-common/path/to/package/...
go tool cover -func=coverage.out | grep total
# Expected: > 80%
```

---

## Completion Checklist

- [ ] All tasks completed
- [ ] All tests passing
- [ ] Code review approved
- [ ] Documentation updated
- [ ] Coverage > 80%
- [ ] GitHub Issue updated
- [ ] PR created with `Closes #N`
- [ ] Merged to main

---

## Notes

[Any additional notes, decisions made during planning, or things to watch out for during implementation.]
