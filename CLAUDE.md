# CLAUDE.md — scripts

## 交互风格

- 使用中文交流，代码注释保持与原文件一致（中文）
- 简洁直接，不需要冗余解释
- 修改代码前先阅读相关文件，理解上下文

## 分层权限模型

| 操作 | 权限 |
|------|------|
| 读取/搜索文件 | 自动 |
| 编辑现有文件 | 需确认 |
| 创建新文件 | 需确认 |
| 执行脚本 | 需确认 |
| Git 操作 | 需确认 |

## 修改审计

- 修改前确认影响范围
- 不随意重构未涉及的代码
- PowerShell 脚本修改后建议用户手动测试（涉及系统网络配置，不可自动运行）

## Token 节省策略

- 大文件（如 ns.ps1 ~20K tokens）分段读取，不要一次性读取全文
- 使用 Grep 定位目标代码段再精确读取
- 对话中记住已读取的文件结构，避免重复读取

## 项目信息

**项目名**: scripts
**类型**: 个人脚本工具集
**平台**: Windows 11

### 技术栈

| 脚本 | 语言 | 运行环境 |
|------|------|----------|
| `ns.ps1` | PowerShell | PowerShell 5.1+ / 管理员权限（部分功能） |
| `forge-buddy.mjs` | JavaScript (ESM) | Node.js 18+ |
| `setup-claude.ps1` | PowerShell | PowerShell 5.1+ / winget |
| `repair-openclash.ps1` | PowerShell | PowerShell 5.1+ / SSH + ASKPASS |
| `openclash_custom_overwrite.sh` | Shell | OpenWrt / OpenClash custom script |
| `check-proxy.ps1` | PowerShell | PowerShell 5.1+ |
| `diag-network.ps1` | PowerShell | PowerShell 5.1+ |
| `disable-ics.ps1` | PowerShell | PowerShell 5.1+ / 管理员权限 |
| `disable-ics.bat` | Batch | 管理员权限 |
| `claude-starter/setup.ps1` | PowerShell | PowerShell 5.1+ / winget |

### 目录结构

```
scripts/
├── ns.ps1                  # 网络状态快照工具（~1900 行）
├── ns-doc.md               # ns.ps1 完整文档
├── forge-buddy.mjs         # Claude Code companion 宠物锻造（~510 行）
├── setup-claude.ps1        # 个人用：一键部署 Claude Code 全量配置
├── repair-openclash.ps1    # OpenClash 故障诊断修复工具
├── openclash_custom_overwrite.sh  # OpenClash 自定义规则注入脚本（路由器端）
├── bsc.yaml                # OpenClash 订阅配置
├── check-proxy.ps1         # 系统代理状态检查（只读）
├── diag-network.ps1        # 网络诊断工具
├── disable-ics.ps1         # ICS 服务禁用（PowerShell）
├── disable-ics.bat         # ICS + HNS 服务禁用（Batch）
├── claude-starter/         # 朋友用：精简版 Claude Code 配置包
│   ├── setup.ps1          #   一键部署脚本（从 GitHub 下载，无需认证）
│   ├── README.md          #   使用说明
│   ├── base-style.md      #   通用交互风格
│   ├── settings.json      #   权限配置
│   ├── commands/
│   │   ├── task.md        #   统一任务入口
│   │   └── init-project.md#   项目初始化
│   └── skills/
│       ├── analyze/       #   深度代码分析
│       ├── review/        #   代码审查
│       └── create-skill/  #   创建新技能
├── doc/
│   ├── README.md          # 文档总索引
│   └── be6500-openclash.md# OpenClash 配置文档
├── CLAUDE.md               # 项目配置（本文件）
└── .claude/
    └── project-lessons.md # 项目经验
```

## 项目架构

### ns.ps1 — 网络状态快照工具

- **功能**: 监控 VPN/代理对 Windows 系统网络设置的修改，支持快照/对比/恢复/实时监控/一键修复
- **监控项**: 25 项网络设置，分为代理(6)、DNS(5)、网络(6)、系统(5)、环境(3) 五大类
- **结构**: 单文件脚本，使用 PowerShell CmdletBinding + ParameterSet 模式
- **存储**: `%LOCALAPPDATA%\network-snapshots\`，JSON 格式快照
- **详细文档**: `ns-doc.md`

### forge-buddy.mjs — Companion 锻造工具

- **功能**: 暴力搜索 seed 使 Claude Code companion 生成指定种类/稀有度/属性的宠物
- **方案**: `companionSeed` 独立字段 + cli.js 最小 patch（不碰认证字段）
- **附加**: 自动注入 companion 中文 personality 指令
- **算法**: FNV-1a 哈希 + Mulberry32 PRNG（逆向自 Claude Code cli.js）
- **结构**: 单文件 ESM 模块，无外部依赖

### repair-openclash.ps1 + openclash_custom_overwrite.sh — OpenClash 路由器管理

- **repair-openclash.ps1**: 一键诊断修复 OpenClash 故障
  - 诊断 GeoIP.dat 是否损坏（正常 ~18MB）
  - 自动下载替换损坏的 GeoIP.dat（GitHub Releases 直链）
  - 解除 OpenClash disabled 状态 + 启动 + 验证
  - 兼容 Dropbear SSH（ASKPASS + pipe 传输，不依赖 sftp-server）
- **openclash_custom_overwrite.sh**: 部署在路由器 `/etc/openclash/custom/` 下
  - OpenClash 每次生成配置后执行，注入自定义规则
  - 本项目用途：注入 `🤖 AI` 代理组 + 21 条 AI 服务域名规则
- **bsc.yaml**: OpenClash 订阅配置（Mihomo 内核）
- **关键路径**: 路由器 `/etc/openclash/` 目录（GeoIP.dat、GeoSite.dat、config/、core/）
- **详细知识**: `.claude/project-lessons.md` OpenClash 章节
- **⚠️ 当用户提及 OpenClash/路由器/翻墙/节点故障时**，优先用 `repair-openclash.ps1` 诊断；如果用户提供的日志含 `GeoIP.dat` / `Parse config error`，是 GeoIP 损坏的明确信号

### setup-claude.ps1 — 个人一键部署

- **功能**: 新电脑一键安装 Node.js/Git + 克隆 `eight13/claude-knowledge` 私有仓库到 `~/.claude/` + 关遥测
- **适用**: 自己的新电脑

### check-proxy.ps1 / diag-network.ps1 / disable-ics — 网络工具箱

- **check-proxy.ps1**: 只读查询当前系统代理状态（Internet Settings），不改动任何设置
- **diag-network.ps1**: 综合网络诊断（网关、DNS、路由器代理端口探测、直连测试）
- **disable-ics.ps1 / disable-ics.bat**: 禁用 Windows ICS (Internet Connection Sharing) 和 HNS (Host Network Service) 服务，解决这些服务干扰网络的问题

### claude-starter/ — 朋友版精简配置

- **功能**: 从公开仓库下载核心 commands/skills 到 `~/.claude/`，无需 GitHub 认证
- **适用**: 分享给朋友

## 编码约定

### PowerShell

- 使用 `$script:` 作用域管理全局变量
- 分类配置使用 `[ordered]@{}` 哈希表
- 中文注释和输出
- 可选参数使用 ParameterSetName 分组

### JavaScript (forge-buddy.mjs)

- ESM 模块（import/export）
- 中文注释和 console 输出
- 常量使用全大写命名
- 无外部依赖，纯 Node.js 内置模块

## 文档规范

- **总索引**: `doc/README.md`
- **模块级文档**: `<模块路径>/doc/README.md` + 具体文档
- **跨模块文档**: `doc/` 根目录
- **写作风格**: 面向不熟悉架构的读者，先现象后原理，用类比解释
- **新建文档流程**: 建 doc 目录 -> 建索引 -> 更新总索引 -> 小修复合并不单开

## 编译验证

本项目为脚本工具集，无编译步骤。验证方式：

- `ns.ps1`: `powershell -Command ".\ns.ps1 -Help"` （语法检查）
- `forge-buddy.mjs`: `node forge-buddy.mjs --help` （语法检查）

## 可用命令

```bash
# 网络快照工具
powershell -File ns.ps1 -Help          # 查看帮助
powershell -File ns.ps1                # 健康检查
powershell -File ns.ps1 -Save          # 保存快照
powershell -File ns.ps1 -Compare       # 对比快照

# Companion 锻造
node forge-buddy.mjs --help            # 查看帮助
node forge-buddy.mjs --show            # 查看当前宠物
node forge-buddy.mjs --patch           # CLI 更新后重新 patch
node forge-buddy.mjs --restore         # 恢复原始状态
node forge-buddy.mjs --species penguin --rarity legendary --peak DEBUGGING --dump PATIENCE  # 完整搜索
node forge-buddy.mjs --species cat --rarity epic --dry-run  # 搜索（不修改）

# OpenClash 修复工具
powershell -File repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass"                 # 诊断+修复
powershell -File repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass" -DiagnoseOnly    # 仅诊断
powershell -File repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass" -ResetGeoIpOnly  # 仅修复 GeoIP
powershell -File repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass" -JustStart       # 仅启动
```
