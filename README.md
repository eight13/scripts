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
| `repair-openclash.ps1` | OpenClash 故障修复 — 诊断/修复 GeoIP 损坏、disabled 状态、启动失败 | `.\repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "pwd"` |
| `diag.py` | OpenClash 诊断（Python） — paramiko SSH，支持 `--check`/`--fix`/`--upload` | `python diag.py -p pwd --check` |
| `upload-openclash-custom.ps1` | 上传 overwrite 脚本到路由器并重启 OpenClash | `.\upload-openclash-custom.ps1 -Password "pwd"` |
| `openclash_custom_overwrite.sh` | OpenClash 自定义规则注入 — 注入 AI/游戏 代理组 + DNS Rescue | 部署在路由器 `/etc/openclash/custom/` |
| `check-proxy.ps1` | 代理状态检查 — 只读查询系统代理设置 | `.\check-proxy.ps1` |
| `diag-network.ps1` | 网络诊断 — 网关/DNS/端口探测/直连测试 | `.\diag-network.ps1` |
| `disable-ics.ps1` | ICS 服务禁用 — 停止并禁用 Windows 网络共享服务 | 管理员运行 |

详见各脚本内文档或 `ns-doc.md`。
