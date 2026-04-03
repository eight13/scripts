# 网络状态快照工具 (Network Snapshot)

> 监控 VPN/代理工具对 Windows 系统网络设置的修改，支持快照、对比、恢复、一键修复。

## 快速开始

```powershell
# 1. 首次运行 - 自动保存基线并检查系统健康状态
.\ns.ps1

# 2. 开VPN前 - 保存快照
.\ns.ps1 -Save

# 3. 关VPN后 - 查看被改了什么
.\ns.ps1 -Compare

# 4. 网断了？一键修复
.\ns.ps1 -FixAll
```

## 所有命令

### 日常使用（不需要懂技术细节）

| 命令 | 说明 |
|------|------|
| `.\ns.ps1` | 健康检查：当前系统网络是否正常 |
| `.\ns.ps1 -FixProxy` | 一键清除所有代理设置 |
| `.\ns.ps1 -FixDNS` | 一键恢复 DNS 为自动获取 |
| `.\ns.ps1 -FixAll` | 全部修复（代理+DNS+缓存）并测试连通性 |

### 快照管理

| 命令 | 说明 |
|------|------|
| `.\ns.ps1 -Save` | 保存当前网络状态快照（自动命名） |
| `.\ns.ps1 -Save -Name "开VPN前"` | 保存并自定义名称 |
| `.\ns.ps1 -Compare` | 对比当前状态与最近的快照 |
| `.\ns.ps1 -Compare -Name "baseline"` | 对比指定快照 |
| `.\ns.ps1 -Compare -Full` | 显示所有 25 项的详细对比 |
| `.\ns.ps1 -Compare -Brief` | 仅显示一行摘要 |
| `.\ns.ps1 -Restore` | 恢复到最近的快照 |
| `.\ns.ps1 -Restore -WhatIf` | 预览恢复操作（不实际执行） |
| `.\ns.ps1 -Restore -Only Proxy,DNS` | 仅恢复指定分类 |
| `.\ns.ps1 -Restore -Force` | 恢复包括高风险项（路由/防火墙/证书等） |
| `.\ns.ps1 -List` | 查看所有已保存的快照 |
| `.\ns.ps1 -Watch` | 实时监控网络设置变化（Ctrl+C 退出） |
| `.\ns.ps1 -Watch -Interval 10` | 每 10 秒检查一次（默认 5 秒） |
| `.\ns.ps1 -Watch -Only 代理` | 仅监控指定分类组 |

### 帮助

```powershell
.\ns.ps1 -Help
```

## 典型场景

### 场景 1：开VPN → 关VPN → 网断了

```powershell
# 开VPN前（养成习惯）
.\ns.ps1 -Save -Name "干净状态"

# ...使用VPN...

# 关VPN后发现网断了
.\ns.ps1 -Compare         # 先看哪些被改了
.\ns.ps1 -FixAll           # 一键修复
# 或者
.\ns.ps1 -Restore          # 恢复到快照状态
```

### 场景 2：不知道网络为什么不正常

```powershell
# 直接运行，查看系统健康状态
.\ns.ps1

# 输出示例：
# === 系统网络健康检查 ===
#   ✓ 系统代理: 未启用
#   ⚠ DNS (以太网): 198.18.0.1 (可能是代理残留)
#   ✓ IP转发: 已禁用
#   ⚠ 发现 1 处异常，可用 -FixAll 一键修复
```

### 场景 3：卸载VPN后检查是否清理干净

```powershell
.\ns.ps1 -Compare -Full    # 与基线对比，查看所有25项
```

### 场景 4：想看VPN到底改了什么

```powershell
# 终端1：开始监控
.\ns.ps1 -Watch

# 终端2（或GUI）：开启VPN
# 终端1会实时显示：
# [14:32:05] 检测到 3 处变化：
#   [系统代理 (System Proxy)] ProxyEnable: 0 → 1
#   [系统代理 (System Proxy)] ProxyServer: (空) → 127.0.0.1:10888
#   [DNS服务器 (DNS Servers)] Count: 2 条 → 3 条
```

## 监控的 25 项设置

### 代理类 (6 项)

| 项目 | 说明 | 常见问题 |
|------|------|----------|
| 系统代理 | IE/系统代理设置 | VPN关了但代理没清 → 浏览器断网 |
| 代理二进制Blob | DefaultConnectionSettings | 底层代理配置，有些工具直接写这里 |
| WinHTTP代理 | 机器级HTTP代理 | 影响 Windows Update 等系统服务 |
| PAC自动代理 | PAC脚本URL及内容 | PAC指向已关闭的本地服务 → 断网 |
| 组策略代理 | 策略级代理设置 | 优先级高于用户设置，容易被忽略 |
| 端口转发 | netsh portproxy规则 | 隐蔽的流量重定向 |

### DNS 类 (5 项)

| 项目 | 说明 | 常见问题 |
|------|------|----------|
| DNS服务器 | 每个网卡的DNS配置 | DNS指向VPN的假地址(如198.18.0.1) → 无法解析域名 |
| NRPT策略 | 名称解析策略表 | 静默将特定域名的DNS查询发到VPN |
| DoH设置 | DNS over HTTPS (Win11) | DoH指向不可达的服务器 → DNS超时 |
| DNS相关服务 | DNS Client等服务状态 | 服务被停用 → 各种网络异常 |
| SMHNR开关 | 多宿主名称解析 | 被禁用可能导致DNS行为异常 |

### 网络类 (6 项)

| 项目 | 说明 | 常见问题 |
|------|------|----------|
| 路由表 | IPv4/IPv6路由 | 默认路由指向已删除的TUN网卡 → **完全断网** |
| 网卡配置 | 网卡列表、IP地址、网关 | 残留的虚拟网卡(wintun/tap) |
| 接口度量值 | 网卡优先级 | 度量值被改 → 流量走错网卡 |
| 网络配置文件 | Public/Private/Domain | 配置文件变化影响防火墙规则生效范围 |
| WFP内核过滤器 | Windows过滤平台 | TUN模式在内核层劫持流量，防火墙看不到 |
| MTU设置 | 最大传输单元 | MTU被改小 → 大文件传输异常 |

### 系统类 (5 项)

| 项目 | 说明 | 常见问题 |
|------|------|----------|
| 防火墙规则 | VPN/代理相关的防火墙规则 | 残留的允许/阻止规则 |
| Winsock目录 | 网络协议栈 | 损坏可导致全面断网，需 `netsh winsock reset` |
| hosts文件 | DNS静态映射 | 被添加了重定向条目 |
| 根证书 | 非常见CA证书 | MITM代理安装的根证书 → 安全隐患 |
| UWP回环豁免 | UWP应用访问localhost的权限 | 残留豁免，影响应用隔离 |

### 环境类 (3 项)

| 项目 | 说明 | 常见问题 |
|------|------|----------|
| 环境变量 | HTTP_PROXY等 | git/curl/npm等CLI工具走已关闭的代理 |
| 开机启动项 | 代理相关自启动 | 卸载后残留的自启动项 |
| IP栈标志 | IPv6开关、IP转发 | IP转发被开启 → 安全隐患 |

## 安全机制

### 恢复安全

- **恢复前自动备份**：每次 `-Restore` 前自动保存当前状态为 `pre-restore` 快照
- **危险分类保护**：路由表/防火墙/证书/Winsock 等高风险项需要 `-Force` 才能恢复
- **预览模式**：`-WhatIf` 参数预览所有操作但不执行
- **分类恢复**：`-Only` 参数只恢复指定分类

### 紧急恢复

每次 `-Save` 都会自动生成 `emergency-restore.bat`，在 PowerShell 无法运行时也能恢复：

```
%LOCALAPPDATA%\network-snapshots\<快照名>\emergency-restore.bat
```

双击运行即可恢复代理和DNS设置。

### 快捷修复

`-FixProxy`、`-FixDNS`、`-FixAll` 在修复前也会自动备份，可以回滚：

```powershell
# 如果 -FixAll 修复后反而出问题了
.\ns.ps1 -Restore -Name "pre-fix"  # 恢复到修复前的状态
```

## 存储说明

- **位置**: `%LOCALAPPDATA%\network-snapshots\`
- **格式**: JSON 快照 + bat 紧急恢复
- **自动清理**: 保留最近 20 个快照，超过 30 天的自动清理
- **单个快照大小**: 约 10-50 KB

## 权限说明

| 操作 | 需要管理员？ |
|------|------------|
| 健康检查（无参数） | 否 |
| `-Save` | 否（部分项如WFP信息更完整需要管理员） |
| `-Compare` | 否 |
| `-List` | 否 |
| `-Watch` | 否 |
| `-FixProxy` | 部分（WinHTTP重置需要） |
| `-FixDNS` | 是 |
| `-FixAll` | 是 |
| `-Restore` | 取决于恢复的分类 |

**建议：** 以管理员身份运行可获得最完整的信息和修复能力。

## 已知限制

1. **WSL2 内部网络**不在监控范围内（WSL2 有独立的网络栈）
2. **Firefox** 使用独立的代理设置（不走系统代理），不在监控范围内
3. **WFP 过滤器**的详细信息需要管理员权限才能获取
4. **Winsock 重置**需要重启电脑才能生效
5. 部分分类（如防火墙规则、路由表）暂不支持自动恢复，会提示手动处理

## 常见问题

### Q: 我没有保存快照，能用吗？

可以。直接运行 `.\ns.ps1` 会进行健康检查，首次运行自动保存基线。`-FixProxy`/`-FixDNS`/`-FixAll` 不需要事先保存快照。

### Q: 执行脚本报错 "无法加载文件...未经数字签名"

运行以下命令解除限制：
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

### Q: -FixAll 修复后还是上不了网

1. 尝试运行 `.\ns.ps1 -Compare -Full` 查看是否有更深层的异常（路由表、虚拟网卡等）
2. 查看紧急恢复批处理：`%LOCALAPPDATA%\network-snapshots\` 下找到最近的 `emergency-restore.bat`
3. 最终手段：`netsh winsock reset` + `netsh int ip reset` + 重启电脑

### Q: 快照占空间大吗？

每个快照约 10-50 KB，20 个快照约 1 MB。脚本会自动清理超过 30 天的旧快照。
