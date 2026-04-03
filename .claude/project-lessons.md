# 项目经验

## ns.ps1

- ns.ps1 文件很大（~1900 行），修改时务必先用 Grep 定位目标函数/代码段，再用 offset+limit 精确读取
- 涉及 Windows 系统网络配置的修改，不可在 CI 或自动化环境中直接执行测试
- 25 项监控分类定义在文件头部的 `$script:Categories` 哈希表中
- 恢复操作有安全分级：`DangerRestore = $true` 的分类需要 `-Force` 参数

## forge-buddy.mjs

- 算法逆向自 Claude Code cli.js，如果 Claude Code 更新了 companion 生成算法，此工具需要同步更新
- salt 长度固定为 15 字符，搜索空间受限于固定前缀 + 3 字符变体
- `ORIGINAL_SALT` 常量随 Claude Code 版本变化，需要及时更新
