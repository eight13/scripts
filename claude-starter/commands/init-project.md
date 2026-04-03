---
name: init-project
description: 扫描当前项目，生成项目特定的 CLAUDE.md
allowed-tools: Read, Write, Grep, Glob, Bash
---

# 🏗️ 项目配置初始化

**参数**：$ARGUMENTS

---

## 功能

扫描当前项目，生成 `CLAUDE.md` 项目配置文件。

---

## 执行流程

### 0️⃣ 环境安全检查

初始化前先检查 Claude Code 遥测设置：

```bash
# Windows：检查用户级环境变量
powershell -Command "[Environment]::GetEnvironmentVariable('DISABLE_TELEMETRY', 'User')"
```

**判断逻辑**：
- 如果返回值为 `1` → 显示 `✅ 遥测已关闭` 并继续
- 如果返回值为空或非 `1` → 提示风险并询问：
  > "⚠️ 检测到 DISABLE_TELEMETRY 未设置。Claude Code 默认会向 Anthropic + Datadog 静默上报行为遥测（966 个埋点），反馈调查时还会上传完整对话转录。
  > 建议设置 `DISABLE_TELEMETRY=1` 关闭遥测（不影响核心 AI 功能）。
  > 是否自动设置？"
- 用户确认 → 执行：
  ```bash
  powershell -Command "[Environment]::SetEnvironmentVariable('DISABLE_TELEMETRY', '1', 'User')"
  ```
  提示"✅ 已设置，重启 Claude Code 后生效"
- 用户拒绝 → 记录到输出报告的建议项中，继续流程

### 1️⃣ 项目扫描

```bash
# 扫描文件
find . -type f \( -name "*.cpp" -o -name "*.hpp" -o -name "*.py" -o -name "*.js" \) | head -50

# 识别技术栈
ls package.json CMakeLists.txt requirements.txt 2>/dev/null
```

### 2️⃣ 信息提取

| 项目 | 获取方式 |
|------|----------|
| 名称 | 目录名 / 配置文件 |
| 技术栈 | 依赖文件分析 |
| 目录结构 | 文件分布统计 |
| 编码规范 | 代码样本分析 |

### 3️⃣ 生成配置

**CLAUDE.md**（项目根目录）必须包含以下章节：

- 项目信息（概述、技术栈、文件统计）
- 项目架构（启动流程、核心类、模块依赖）
- 编码约定
- 编译验证
- 可用命令

**`.claude/project-lessons.md`**（项目经验，随使用积累）

### 4️⃣ 输出报告

```
🏗️ 项目配置已初始化

**识别结果**：
- 项目名：[name]
- 技术栈：[stack]
- 文件数：[count]

**生成文件**：
- CLAUDE.md
- .claude/project-lessons.md

**建议**：
1. 检查编码规范
2. 补充项目特定约定

💡 现在可以使用 /task 开始工作
```

---

## 参数

| 参数 | 说明 |
|------|------|
| 无 | 完整扫描 |
| `--quick` | 快速扫描 |
| `--force` | 覆盖已有 |
