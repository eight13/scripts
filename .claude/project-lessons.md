# 项目经验

## ns.ps1

- ns.ps1 文件很大（~1900 行），修改时务必先用 Grep 定位目标函数/代码段，再用 offset+limit 精确读取
- 涉及 Windows 系统网络配置的修改，不可在 CI 或自动化环境中直接执行测试
- 25 项监控分类定义在文件头部的 `$script:Categories` 哈希表中
- 恢复操作有安全分级：`DangerRestore = $true` 的分类需要 `-Force` 参数

## forge-buddy.mjs

- 算法逆向自 Claude Code cli.js（FNV-1a + Mulberry32），如果 Claude Code 更新了 companion 生成算法需同步更新
- 使用 `companionSeed` 独立字段 + cli.js 最小 patch 方案，不碰 `oauthAccount` 认证字段
- CLI 更新会覆盖 cli.js patch，需重新运行 `--patch`；`companionSeed` 和 personality 中文指令存在 `.claude.json` 中不受影响
- companion 视觉属性（species/rarity/stats）不存储，每次从 userId 重新生成；只有 name/personality/hatchedAt 持久化
- companion 对话走服务端 `buddy_react` API，personality 字段（200 字符）是唯一可控输入

## OpenClash 路由器管理

### 连接方式

- **SSH 服务器是 Dropbear**，不支持 sftp-server → `scp` 不可用
- **paramiko 对 Dropbear 密码认证有兼容问题**，Windows 上优先用原生 `ssh` + `SSH_ASKPASS` 机制
- **文件传输用 pipe**：`ssh root@ip 'cat > /etc/openclash/GeoIP.dat' < localfile`
- **ASKPASS 设置**：创建批处理文件输出密码，设 `$env:SSH_ASKPASS` + `$env:DISPLAY=dummy:0` + `$env:SSH_ASKPASS_REQUIRE=force`

### GeoIP.dat 损坏诊断

- **症状**：OpenClash 启动后立即关闭，日志显示 `fatal msg="Parse config error: rules[1] [GEOIP,...] error: [GeoIP] failed to decode geodata file: GeoIP.dat"`
- **根因**：`/etc/openclash/GeoIP.dat` 异常小（通常 < 1KB，正常 ~18MB）
- **原因**：OpenClash 自动下载 GeoIP.dat 时，CDN (jsDelivr) 可能返回 429 限速页面（199 字节），被当作成功保存
- **修复**：从 GitHub Releases 直链下载（不走 CDN）后替换
  - 主源: `https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat`
  - 备源: `https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat`

### OpenClash 启用/启动

- **disabled 状态**：`openclash.config.enable=0` → `init.d start` 只输出 "Need Start From Luci Page, Exit..." 然后退出
- **修复**：`uci set openclash.config.enable=1 && uci commit openclash` 然后再 start
- **验证**：`ps | grep '/etc/openclash/clash'` 应有进程；`tail /tmp/openclash.log` 应显示 "Start Successful"

### openclash_custom_overwrite.sh

- **位置**：`/etc/openclash/custom/openclash_custom_overwrite.sh`（在路由器上）
- **功能**：在 OpenClash 每次生成配置后、启动前注入自定义规则
- **本项目的作用**：
  - 注入 `🤖 AI` 代理组 + 17 条 AI 服务域名规则
  - 注入 `🎮 游戏` 代理组 + Ubisoft/Rockstar 游戏规则 + 反作弊直连规则
  - Steam/Epic/GOG/Battle.net 游戏下载 CDN 直连规则（满速下载）
  - 奇游加速器中继 IP 直连规则
  - DNS Rescue：修复 dnsmasq → clash DNS 死循环
  - 清理损坏的订阅 Provider（Provider_9B46AF）
- **维护**：
  - 如果规则被跳过（"未找到对应的策略组"），检查代理组名是否匹配
  - 不要硬编码具体节点名（如 `🇭🇰 香港节点`），改用代理组名（如 `🔰 节点选择`）
  - 修改后上传：`python -c "import paramiko..."` pipe + cat 方式（见连接诊断）

### 修复脚本

- `repair-openclash.ps1` — 一键诊断修复工具
  - `-DiagnoseOnly` 仅诊断不修复
  - `-ResetGeoIpOnly` 仅替换 GeoIP.dat
  - `-JustStart` 仅启用并启动服务
  - 无开关 = 诊断 + 自动修复

### DNS 死循环（🔴 高频故障）

- **症状**：OpenClash 启动后所有 DNS 超时，`nslookup` 到 `127.0.0.1:53` 返回 "No answer" 或 "connection timed out"
- **根因链路**：
  1. OpenClash 将 dnsmasq 上游设为 `127.0.0.1#7874`（clash DNS）
  2. clash 在 fake-ip 模式下对直连（DIRECT）域名的 DNS 请求不响应 → 全部超时
  3. 同时 nftables `nat_output` 规则将 `127.0.0.1:53` 的 DNS 请求重定向回自身 → 形成环路
  4. OpenClash watchdog 每 5 分钟 "Force Reset DNS Hijack" 会覆盖手动修复
- **诊断**：
  ```bash
  uci show dhcp.@dnsmasq[0] | grep server    # 看到 127.0.0.1#7874 即为故障
  nslookup baidu.com 127.0.0.1               # 超时
  nslookup baidu.com 192.168.1.1             # 正常（绕过 dnsmasq）
  ```
- **修复**（已集成到 overwrite 脚本）：
  ```bash
  uci -q del_list dhcp.@dnsmasq[0].server='127.0.0.1#7874'
  uci -q add_list dhcp.@dnsmasq[0].server='192.168.1.1'
  uci commit dhcp
  /etc/init.d/dnsmasq restart
  ```
- **持久化**：overwrite 脚本末尾的 "DNS Rescue" 段在首次运行时自动应用上述修复

### overwrite 脚本 YAML.dump 陷阱

- **症状**：overwrite 运行后 `/etc/openclash/config/bsc.yaml` 丢失 DNS 设置（`enhanced-mode`、`nameserver` 等）
- **原因**：Ruby 的 `YAML.dump(Value, f)` 写入时可能重排/丢失部分字段
- **修复**：在 Ruby 代码中显式写入 DNS 设置：
  ```ruby
  Value['dns']['enable'] = true;
  Value['dns']['enhanced-mode'] = 'fake-ip';
  Value['dns']['nameserver'] = ['192.168.1.1'];
  # ... 其他必要字段
  ```
- **验证**：`grep "enhanced-mode" /etc/openclash/config/bsc.yaml` 应有输出

### 代理组引用不存在节点

- **症状**：`Parse config error: proxy group[12]: 🎮 游戏: '🇭🇰 香港节点' not found`
- **原因**：overwrite 脚本中的 `proxies` 数组引用了固定节点名，但订阅更新后节点名称已变更
- **修复**：引用代理**组**名（如 `♻️ 自动选择`、`🔰 节点选择`）而非具体节点名，因为组名由订阅模板定义不会变
- **教训**：`proxies` 列表中不要硬编码 `🇭🇰 香港节点` 这类具体节点名，改用 `filter` + `use` 按地区筛选

### 自动禁用保护

- **现象**：OpenClash 多次启动失败后会被自动设 `enable=0`，日志显示 "Need Start From Luci Page"
- **绕过**：`uci set openclash.config.enable=1 && uci commit openclash` 后立即 `start`
- **修复后会自动恢复**：只要一次启动成功，后续重启不会再触发

### 连接诊断（Python paramiko）

- **方法**：直接 SSH 手动诊断比 PowerShell 脚本快（避免编码/ASKPASS 问题）
- **文件传输**：用 `channel.exec_command('cat > /path')` + `channel.sendall(content)` pipe 方式，因为 Dropbear 无 SFTP
- **路由结构**：`eth0 (192.168.1.2)` → 光猫 `(192.168.1.1)`，`br-lan (192.168.8.1)` → 局域网设备
- **DNS 上游**：光猫 `192.168.1.1:53`（不是 `114.114.114.114`）

### 游戏下载慢

- **原因**：Steam/Epic 等 CDN 流量走代理（MATCH → 漏网之鱼 → 节点选择 → 代理节点），受节点带宽限制
- **修复**：在 overwrite 中添加游戏 CDN 域名 → DIRECT 规则，直连满速
  - Steam: `steamcontent.com`, `steamcdn.com`, `steamstatic.com`
  - Epic: `epicgames.com`, `download*.epicgames.com`
  - 其他: `gog.com`, `battle.net`, `blizzard.com`
- **验证**：`grep -c "DIRECT" /etc/openclash/config/bsc.yaml` 应 ≥ 25 条
