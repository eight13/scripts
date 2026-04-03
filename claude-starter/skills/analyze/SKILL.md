---
name: analyze
description: 深度分析文件及其依赖关系（子代理执行，节省 Token）
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob, Bash(find *), Bash(head *), Bash(tail *), Bash(wc *)
---

# 📊 代码深度分析

**目标**：$ARGUMENTS

---

## 分析流程

1. **基础信息**：行数、类数、函数数、职责
2. **依赖关系**：#include/import 追踪
3. **调用链**：Grep 搜索调用位置
4. **问题检测**：命名、空指针、资源泄漏

---

## 输出格式

```
📊 分析报告：[文件名]

## 概述
| 项目 | 值 |
|------|-----|
| 行数 | N |
| 类/函数 | N |
| 职责 | xxx |

## 依赖
入向：[谁依赖它]
出向：[它依赖谁]

## 核心逻辑
[关键函数简述]

## 问题
1. ⚠️ [问题] - line N

## 建议
- [建议]
```

---

**注意**：只分析，不修改。
