---
name: create-skill
description: 创建新的 Claude Code skill 或 command（元技能）
---

# 创建新技能

**需求**：$ARGUMENTS

---

## 核心原则

**先测试再编写。** 观察当前 Claude 在没有该技能时的行为，然后针对性地编写规则。

---

## 创建流程

### 1. 需求分析

- 这个技能要解决什么问题？
- 现有的 skills/commands 是否已经覆盖？（检查重叠）
- 应该是 skill 还是 command？

| 类型 | 适用场景 | 特点 |
|------|---------|------|
| **skill** | 需要子代理/独立上下文 | 支持 `context: fork`、`agent` 字段 |
| **command** | 主对话中直接执行 | 更简单，无隔离开销 |

### 2. 基线测试

- 不使用新技能，让 Claude 处理一个典型场景
- 记录 Claude 的实际行为和偏差点
- 识别需要纠正的具体模式

### 3. 编写技能文件

**SKILL.md 结构**：

```yaml
---
name: <英文短名>
description: <触发条件描述，不是工作流描述>
# 可选字段：
# context: fork          # 独立上下文（子代理）
# agent: Explore         # 使用 Explore 子代理
# allowed-tools: Read, Grep, Glob  # 限制可用工具
---
```

**description 字段关键规则**：
> 描述"什么时候用"，而不是"怎么用"。
> Claude 会优先参考 description 来决定是否触发该技能。

**正文结构**：
1. 标题 + 一句话核心原则
2. 流程/步骤（简洁明确）
3. 输出格式（模板）
4. 常见错误/红线
5. 权限声明

### 4. 验证

- 用相同场景重新测试
- 确认 Claude 的行为符合预期

### 5. 安装位置

| 位置 | 路径 | 作用域 |
|------|------|--------|
| 个人全局 | `~/.claude/skills/<name>/SKILL.md` | 所有项目 |
| 项目级 | `.claude/skills/<name>/SKILL.md` | 仅当前项目 |
| 命令 | `~/.claude/commands/<name>.md` | 所有项目 |

---

## 编写要点

- 保持中文，与现有技能风格一致
- 不要过度设计 — 先解决核心问题，后续迭代优化
- 新 skill 的 description 会占用 context budget（2% 上限），保持精简
- 使用 `$ARGUMENTS` 接收用户输入参数
- 总 skill 数量建议控制在 10 个以内，避免 context 溢出
