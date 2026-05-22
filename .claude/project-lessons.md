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
- **本项目的作用**：注入 `🤖 AI` 代理组 + 21 条 AI 服务域名规则
- **维护**：如果规则被跳过（"未找到对应的策略组"），说明 `🤖 AI` 代理组注入未生效，检查 overwrite 脚本是否正确部署

### 修复脚本

- `repair-openclash.ps1` — 一键诊断修复工具
  - `-DiagnoseOnly` 仅诊断不修复
  - `-ResetGeoIpOnly` 仅替换 GeoIP.dat
  - `-JustStart` 仅启用并启动服务
  - 无开关 = 诊断 + 自动修复
