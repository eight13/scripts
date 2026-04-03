# Claude Code Starter

Claude Code 精简配置包 — 开箱即用的中文工作流。

## 一键部署

```powershell
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; irm https://raw.githubusercontent.com/eight13/scripts/main/claude-starter/setup.ps1 | iex
```

自动完成：安装 Node.js/Git（如缺失） → 部署配置到 `~/.claude/` → 关闭遥测。

部署完成后在 VS Code 扩展商店安装 Claude Code 即可使用。

## 包含什么

### 命令

| 命令 | 说明 |
|------|------|
| `/task <描述>` | 统一任务入口 — 自动识别任务类型（分析/修复/开发/探讨），规划后执行 |
| `/init-project` | 扫描当前项目，生成 CLAUDE.md 项目配置 |

### 技能

| 技能 | 说明 |
|------|------|
| `/analyze <文件>` | 深度分析文件结构、依赖、问题（子代理，不消耗主对话上下文） |
| `/review <文件>` | 代码审查：质量 + 安全 + 可维护性（子代理） |
| `/create-skill` | 创建新的自定义技能或命令 |

### 配置

| 文件 | 说明 |
|------|------|
| `base-style.md` | 中文交互风格、两阶段工作流（探讨→执行）、权限模型 |
| `settings.json` | 工具权限（Bash/Edit/Write/WebSearch 等） |

## 使用方式

```
# 进入项目目录
cd your-project

# 首次使用，初始化项目配置
/init-project

# 之后用 /task 开始工作
/task 分析一下 main.cpp 的结构
/task 这个函数有 bug，报错信息是 xxx
/task 加一个导出 CSV 的功能
/task 想讨论一下架构方案
```

## 手动安装

如果不想用脚本，手动复制也行：

```
将以下文件复制到 ~/.claude/ (即 %USERPROFILE%\.claude\)

base-style.md
settings.json
commands/task.md
commands/init-project.md
skills/analyze/SKILL.md
skills/review/SKILL.md
skills/create-skill/SKILL.md
```
