# scripts

个人脚本工具集。

## 新电脑一键部署 Claude Code

```powershell
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback={$true}; irm https://raw.githubusercontent.com/eight13/scripts/main/setup-claude.ps1 | iex
```

自动完成：安装 Node.js/Git（如缺失） + 拉取个人配置（commands/skills/knowledge） + 关闭遥测。

## 分享给朋友：Claude Code Starter

```powershell
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback={$true}; irm https://raw.githubusercontent.com/eight13/scripts/main/claude-starter/setup.ps1 | iex
```

精简版配置，包含 `/task`、`/init-project`、`/analyze`、`/review` 等核心功能。无需 GitHub 认证。详见 [claude-starter/README.md](claude-starter/README.md)。

## 脚本列表

| 脚本 | 说明 | 用法 |
|------|------|------|
| `setup-claude.ps1` | Claude Code 一键部署 — 新电脑开箱即用 | 见上方 |
| `ns.ps1` | 网络状态快照 — 监控 VPN/代理对系统网络的修改，支持对比/恢复/修复 | `.\ns.ps1 -Help` |
| `forge-buddy.mjs` | Claude Code 宠物更换 — 暴力破解 salt 生成指定种类/稀有度的 companion | `node forge-buddy.mjs --help` |

详见各脚本内文档或 `ns-doc.md`。
