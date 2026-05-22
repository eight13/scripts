# GL-BE6500 OpenClash 配置速查

个人路由器：**GL.iNet Flint 3e (GL-BE6500)** + **OpenClash** + **Mihomo (Meta) 内核**

## 🎯 当前方案

**用 [Aethersailor/Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules) 订阅转换模板一键搞定**，全程 UI 点击 + 复制粘贴，**无需 SSH、无需写 Ruby 脚本、无需自建 Docker**。

模板自带：
- 🤖 ChatGPT 独立分组
- 🤖 AI服务 独立分组（Claude / Gemini / Perplexity 等）
- 🎮 Steam、📹 YouTube、🎥 Netflix/HBO/Disney、🇬 谷歌服务、🍎 苹果服务 等 30+ 分组
- 每个组都能在控制面板里**单独挑节点**
- DNS 防泄漏、Fake-IP、绕过中国大陆
- **每日自动更新规则**，长期无人值守

公共转换后端 `api.asailor.org` 由项目方提供（普通用户不用搭 Docker，这是它区别于普通 subconverter 方案的最大亮点）。

---

## 📋 踩坑时间线（保留警示）

| 走过的弯路 | 为什么不行 |
|------------|------------|
| 覆写设置 → 规则设置"优先匹配"加规则指向自建组名 | 规则是规则，**不会自动生成代理组**，面板里看不到新组 |
| SSH 写 `/etc/openclash/custom/openclash_custom_proxy_group.list` | 此版本 OpenClash **不识别**这个路径 |
| 覆写设置 → 覆写模块 → Ruby 脚本注入 proxy-groups | Clash 加载 yaml 时报错启动失败 → **断网**（issue #5032、#3296 同款坑） |
| 复用 Microsoft 组当 AI 组（临时方案） | 能用，但名字难听 + 规则要手动维护 |

以上方案现在**全部作废**，下面这套才是正解。

---

## 🛠️ 完整设置步骤

> 严格按顺序做，有一步跳过都可能踩坑。整个过程大约 15 分钟。

### 步骤 0：前置确认

- [ ] OpenClash 已安装、能启动、订阅已经拉下来（你现在的状态就是这样）
- [ ] 路由器能访问 GitHub（如果不能，先搞定；第 1.3 步会通过改 CDN 提速）

> **注意：项目 README 明确写了"未基于任何 YouTube 视频整理，出问题不受理视频教程反馈"**。如果出问题只能看 Wiki 自己排查。

---

### 步骤 1：准备工作

**1.1 查看运营商 DNS**

OpenWrt 首页 → 确认 WAN 口已经拿到运营商下发的 IPv4 DNS。
如果你打算用第三方 DNS（比如 AliDNS DoH），跳过。

**1.2 关闭 DNS 重定向**

`网络` → `DHCP/DNS` → **关闭"DNS 重定向"选项**（某些固件可能没这个选项，没看到就跳过）。

> ⚠️ 不关的话广告拦截和部分规则会失效。

**1.3 启用 GitHub 加速 CDN**

`OpenClash` → `覆写设置` → `常规设置`
→ `GitHub 地址修改` 下拉选 **testingcf**（jsDelivr 的 Cloudflare 线路）
→ 页面底部 **"应用配置"**

---

### 步骤 2：OpenClash 常规设置

#### 2.1 模式设置

`OpenClash` → `插件设置` → `常规设置`

- 页面下方切换到 **Fake-IP 模式**
- 上方运行模式选 **`Fake-IP（增强）`**
- 若发现 NAT 问题可改成 `Fake-IP（混合）`+启用 UDP 转发

#### 2.2 流量控制

同页面内：
- ✅ 启用 **实验性：绕过指定区域 IP**
- 下拉选 **绕过中国大陆**

> 🔑 **关键**：这是整个方案的核心。国内流量不进内核，直连，性能最好。

#### 2.3 DNS 设置（常规设置标签）

- 使用 **Dnsmasq 进行转发**
- 点一下 **"Fake-IP 持久化缓存清理"** 按钮（提示错误无视）
- 启用 **"禁止 Dnsmasq 缓存 DNS"**（新版没这个选项就跳过）
- 点底部 **保存配置**

#### 2.4 IPv6 设置

如果你的机场**不支持 IPv6 出站**（大多数机场都不支持）：
- ❌ **禁用** `IPv6 流量代理`
- ❌ **禁用** `允许 IPv6 类型 DNS 解析`

#### 2.5 GEO 数据库订阅

`插件设置` → `GEO 数据库订阅`
- **所有数据库全部开启自动更新**
- 更新时间建议设成凌晨
- 保存 → **把 4 个"检查并更新"按钮都点一遍**（顺便验证能否连到 GitHub）

#### 2.6 白名单订阅

`插件设置` → `白名单订阅` → **启用自动更新** → 保存 → 点 **"检查并更新"**

#### 2.7 版本更新

`插件设置` → `版本更新` → 选 **`master`** 分支 → **一键更新**（内核 + 插件本体更新到最新）

---

### 步骤 3：覆写设置

`OpenClash` → `覆写设置`

#### 3.1 常规设置 · CDN

找到 CDN 相关下拉，选 **`https://testingcf.jsdelivr.net/`**（和步骤 1.3 呼应）

#### 3.2 DNS 设置（覆写设置里的 DNS 标签）

- ✅ 启用 **"自定义上游 DNS 服务器"**

**推荐方案（主路由 + 运营商 DNS）**：
- ✅ 启用 **"追加上游 DNS"**
- ❌ 禁用 NameServer 组**所有**服务器
- ❌ 禁用 Fallback 组**所有**服务器

**备选方案（运营商 DNS 不稳或不想用）**：
- ❌ 禁用 "追加上游 DNS"
- ✅ Nameserver 启用 AliDNS + DNSPod 的 **DoH**（地址带 `https`）
- ✅ Default-Nameserver 至少启 1 个
- ❌ 禁用 Fallback 所有服务器

> 🔑 **重点**：**取消所有 Fallback**。Fake-IP 模式下 Fallback 会干扰远端解析，导致 DNS 泄漏。

保存配置。

#### 3.3 Meta 设置

- ✅ **启用 GeoIP Dat 版数据库**
- 其他按默认

#### 3.4 规则设置

`覆写设置` → `规则设置`

- **"优先匹配"框**：**全部清空**（之前粘的 Microsoft 规则全删）
- **"候补匹配"框**：**全部清空**（有空也清）
- 底部 **保存配置**

> ⚠️ 重要：**模板会自动生成所有规则**，你自己加的反而会打架。

---

### 步骤 4：配置订阅（核心步骤）

`OpenClash` → `配置订阅` → 编辑现有订阅项（或删掉重新添加）

填写：
| 字段 | 值 |
|------|------|
| 配置文件名 | 随意，比如 `bsc` |
| 订阅链接 | 你的机场 Clash 订阅 URL |
| **订阅转换** | **✅ 启用** |
| **订阅转换服务地址** | **`https://api.asailor.org/sub`** |
| **订阅转换模板** | **`Custom_Clash.ini`** |
| 其他选项 | 按默认 |

**订阅转换模板选哪个：**

| 模板 | 适合 |
|------|------|
| **`Custom_Clash.ini`** ✅ 推荐 | 大多数用户 |
| `Custom_Clash_Lite.ini` | 轻量需求 / 低性能设备 |
| `Custom_Clash_Full.ini` | 重度分流需求 |

> 如果下拉里**没有**对应模板，先回步骤 2.7 把 OpenClash 更新到较新版本。

底部 **保存配置**。

---

### 步骤 5：启动并验证

#### 5.1 更新配置

回到 `配置订阅` 页 → 对着刚才那个订阅项点 **"更新配置"**
→ 自动开始下载 + 转换 + 启动，大约 20-30 秒

#### 5.2 看运行日志

`运行状态` → `运行日志`

看到 **"OpenClash 启动成功，请等待服务器上线！"** 即 OK。

如果看到报错，最常见原因：
- `api.asailor.org` 暂时连不上 → 切订阅转换后端到 OpenClash 内置的其他两个
- 模板拉不下来 → 确认步骤 1.3 和 3.1 的 CDN 都改好了

#### 5.3 打开控制面板验证分组

`运行状态` → 右上角蓝色的 **控制面板** 按钮

应该能看到这些分组（每个都独立可选节点）：

- 🚀 手动选择 / ♻️ 自动选择
- **🤖 ChatGPT**
- **🤖 AI服务**
- 🚀 GitHub、💬 即时通讯、🌐 社交媒体
- 📹 YouTube、🎥 Netflix / HBO / Disney+ / AppleTV+ / PrimeVideo / Emby
- 🇬 谷歌服务、🍎 苹果服务、Ⓜ️ 微软服务
- 🎮 Steam、🎮 游戏平台、🎻 Spotify、🎶 TikTok
- 🎯 全球直连、🐟 漏网之鱼

---

## 🎯 给 AI 分组挑节点

进控制面板 → 点 🤖 ChatGPT → 选节点

### 节点优先级（从好到差）

1. 🥇 名字含 **`ChatGPT`** / **`GPT`** / **`AI`** / **`原生 IP`** / **`家宽`** / **`Residential`**
2. 🥈 **`美国-纯净`** / **`美国-流媒体`** / **`美国-解锁`**
3. 🥉 普通美国节点（玄学）
4. ❌ 避免：共享 HK/JP 节点、`入门` / `基础` 最低档、名字含 `BGP`

🤖 AI服务 也按同样方式选（Claude 对 IP 要求比 OpenAI 松一些，不强求 `ChatGPT` 专属节点）。

### 验证

- 开 `https://chat.openai.com/` → 正常进登录页 = 可用
- 显示 "Unable to load site" / "Not available in your country" = 换节点

---

## 🏆 最终验证

### DNS 泄漏检测

访问 [https://ipleak.net/](https://ipleak.net/) 或 [https://browserleaks.com/dns](https://browserleaks.com/dns)

- ✅ 页面顶部显示的是**出口节点**的 IP
- ✅ 下方 DNS 服务器列表**不应该**出现你本地运营商的 DNS

> ⚠️ **控制面板里 `漏网之鱼` 不要选 DIRECT！** 选直连会导致 DNS 泄漏检测不通过。

### 访问测试

| 站 | 预期 |
|---|---|
| `baidu.com` / `taobao.com` | 秒开，像没开代理一样 |
| `github.com` / `youtube.com` | 走 🚀 GitHub / 📹 YouTube 分组 |
| `chat.openai.com` | 走 🤖 ChatGPT 分组 |
| `claude.ai` | 走 🤖 AI服务 分组 |

---

## 🚨 常见坑

| 症状 | 解决 |
|------|------|
| `"更新配置"` 一直转圈 | 换订阅转换后端（内置另外两个）或检查 CDN 设置 |
| 启动失败日志报 `proxy group 'xx' not found` | 模板和订阅不匹配，换回 `Custom_Clash.ini` |
| 控制面板看不到 🤖 ChatGPT 分组 | 模板没选对，或订阅没刷新，重新"更新配置" |
| ChatGPT 打不开 | 节点问题不是规则问题，换 AI 专用节点 |
| 国内网站变卡 | DNS 设置不对，回到步骤 3.2 重新检查 |
| `api.asailor.org` 挂了 | 临时切换 OpenClash 内置的其他订阅转换后端 |

---

## 🔄 日常维护

**几乎不用管**。设置完成后：
- 规则每日自动从 GitHub 更新
- GEO 数据库每日自动更新
- 订阅定时自动刷新（默认时间在 `配置订阅` 页可改）

**需要手动维护的场景**：
- 机场换了订阅链接 → 回 `配置订阅` 改 URL
- 发现某个站没代理好 → `覆写设置` → `规则设置` → `自定义规则`（不是改覆写，是加单行规则）

---

## 🔐 安全提醒

1. 订阅链接 = 密钥，截图/分享时打码 token
2. 用一阵子后去机场后台重置订阅链接
3. 路由器管理后台密码不要跟 WiFi 密码一样

---

## 🛠 SSH 路径备忘

平时用不到，排错时才用。

```bash
ssh root@192.168.8.1
# 密码 = 路由器管理员密码

# 订阅配置（自动下载，别手改，改了订阅刷新就没）
/etc/openclash/config/bsc.yaml

# 自定义覆写（本方案下一般不用）
/etc/openclash/custom/openclash_custom_rules.list       # 优先匹配
/etc/openclash/custom/openclash_custom_rules_2.list     # 候补匹配
/etc/openclash/custom/openclash_custom_overwrite.sh     # 覆写脚本 ⚠️ 别塞 Ruby！

# 日志
/tmp/openclash.log
```

---

## 📚 参考资料

- 项目主页：[Aethersailor/Custom_OpenClash_Rules](https://github.com/Aethersailor/Custom_OpenClash_Rules)
- 官方 Wiki：[OpenClash 设置方案](https://github.com/Aethersailor/Custom_OpenClash_Rules/wiki/OpenClash-设置方案)
- 故障排除：[Wiki / 故障排除](https://github.com/Aethersailor/Custom_OpenClash_Rules/wiki/故障排除)
- 参考视频：《这可能是最干净实用的一套 OpenClash 分流模版》(@SYXJ555)
