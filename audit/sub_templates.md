# OpenClash 订阅转换模板完全指南

> 数据来源：路由器 `/usr/share/openclash/res/sub_ini.list`（40 个模板）

## 模板是什么

订阅转换器（如 `api.wcc.best`）从机场拿到裸节点列表后，按模板生成最终配置。模板决定了：代理组结构、规则数量、分流策略、DNS 设置。**模板不同，最终效果天差地别。**

所有模板文件都托管在 GitHub，转换器在线拉取。墙内转换器经常拉不到 → 退回 10 组默认配置。

---

## 一、ACL4SSR 系列（34 个）

ACL4SSR 是最老牌、用户最多的规则集。所有变体都是从一个基础模板衍生。

### 按规则加载方式

| 类型 | 模板名 | 规则来源 |
|------|--------|---------|
| **本地** | 标准版/Mini/Full 等 | 规则内嵌在模板中，转换器一次生成 |
| **Online** | Online/Online Full 等 | 规则从远程 RULE-SET 实时拉取，Clash 运行时更新 |

**推荐**：Online 系列更适合国内——规则文件走 CDN 更新，不需要转换器每次重新下载。

### 按规则丰富度

| 级别 | 模板 | 代理组数 | 规则数 | 适用 |
|------|------|---------|--------|------|
| **Full** | Online Full / Online Full MultiMode | 30+ | 大量 | 追求完美分流，设备多 |
| **标准** | Online / 标准版 | 20+ | 适中 | **日常首选** |
| **Mini** | Online Mini / Mini | 15+ | 精简 | 性能有限的路由器 |
| **极简(GFW)** | WithGFW | 10+ | 最少 | 只代理被墙网站，其余全直连 |

### 按特殊功能

| 后缀 | 作用 |
|------|------|
| `MultiMode` | 多代理模式（select/url-test/fallback 三选一） |
| `MultiCountry` | 按国家/地区分流节点 |
| `AdblockPlus` | 内置广告过滤规则 |
| `Netflix` | Netflix 专用分流组 |
| `Google` | Google 服务专用分流组 |
| `NoAuto` | 去掉自动选择组，全手动 |
| `NoApple` | Apple 服务不走代理 |
| `NoMicrosoft` | Microsoft 服务不走代理 |
| `NoReject` | 不拦截任何流量（无 REJECT 规则） |
| `Fallback` | 带回退代理组 |
| `BackCN` | 回国模式（适合海外华人访问国内） |
| `WithChinaIp` | 内嵌中国 IP 列表 |
| `WithGFW` | 内嵌 GFW 列表 |

---

## 二、Aethersailor 系列（4 个）

更新更现代的规则集，专门为 OpenClash 优化。

| 模板 | 代理组 | 特点 |
|------|--------|------|
| **标准版** `Custom_Clash` | 30+ | 完整分流，AI/游戏/流媒体分组精细 |
| **轻量版** `Custom_Clash_Lite` | 20+ | 精简但够用，性能好 |
| **极简版(GFW)** `Custom_Clash_GFW` | 10+ | 只代理 GFW 列表 |
| **重度分流版** `Custom_Clash_Full` | 40+ | 最全但性能开销最大 |

**Aethersailor vs ACL4SSR 对比**：

| 维度 | ACL4SSR | Aethersailor |
|------|---------|-------------|
| 维护状态 | 长期稳定，更新慢 | 活跃维护中 |
| 代理组命名 | 英文为主 | 中文+emoji，直观 |
| 规则精度 | 成熟但部分过时 | 较新，域名覆盖更全 |
| AI 分流 | 无 | 有 ChatGPT/Claude 等专用组 |
| 游戏分流 | 基础 | 有 Steam/Epic 等游戏平台组 |
| 适合 | 保守稳定 | 追求精细分流 |

---

## 三、选择建议

```
你的需求 → 推荐模板
────────────────────────────
日常使用，不想折腾  → ACL4SSR Online
想要更多代理组      → ACL4SSR Online Full
路由器性能一般      → ACL4SSR Online Mini
要 AI/游戏分组      → Aethersailor 标准版
只代理被墙网站      → ACL4SSR WithGFW
```

**当前配置**：`ACL4SSR 规则标准版`（本地规则，非 Online）→ 转换器拉不到 GitHub → 退回 10 组。

**建议切换**：`ACL4SSR 规则 Online Full` 或 `Aethersailor 规则 标准版`，配合 `api.asailor.org` 转换器。关键在于**转换器必须能拉到 GitHub**，否则哪个模板都是 10 组。
