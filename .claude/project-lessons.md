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
