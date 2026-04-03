<#
.SYNOPSIS
    Claude Code 一键部署脚本 — 新电脑开箱即用
.DESCRIPTION
    自动安装 Node.js / Git（如缺失）→ 拉取个人配置 → 关闭遥测
    Claude Code 本体通过 VS Code 扩展手动安装
.NOTES
    用法: irm https://raw.githubusercontent.com/eight13/scripts/main/setup-claude.ps1 | iex
    或者: .\setup-claude.ps1
#>

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "   -- $msg (已存在，跳过)" -ForegroundColor Yellow }
function Write-Warn($msg) { Write-Host "   !! $msg" -ForegroundColor Yellow }

# 刷新当前会话的 PATH（winget 安装后新程序可能不在 PATH 中）
function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

Write-Host "`n===== Claude Code 一键部署 =====`n" -ForegroundColor Magenta

# ── 0. 检查 winget ──
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Host "   未找到 winget（Windows 包管理器），无法自动安装依赖" -ForegroundColor Red
    Write-Host "   请先从 Microsoft Store 安装 '应用安装程序'" -ForegroundColor Yellow
    exit 1
}

# ── 1. Node.js ──
Write-Step "检查 Node.js"
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Skip "Node.js $(node --version)"
} else {
    Write-Host "   未找到 Node.js，正在通过 winget 安装..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   Node.js 安装失败" -ForegroundColor Red
        exit 1
    }
    Refresh-Path
    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        Write-Host "   Node.js 已安装但需要重启终端才能使用，请关闭并重新打开 PowerShell 后再次运行本脚本" -ForegroundColor Yellow
        exit 1
    }
    Write-Ok "Node.js $(node --version) 已安装"
}

# ── 2. Git ──
Write-Step "检查 Git"
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Write-Skip "Git $(git --version)"
} else {
    Write-Host "   未找到 Git，正在通过 winget 安装..." -ForegroundColor Yellow
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   Git 安装失败" -ForegroundColor Red
        exit 1
    }
    Refresh-Path
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Host "   Git 已安装但需要重启终端才能使用，请关闭并重新打开 PowerShell 后再次运行本脚本" -ForegroundColor Yellow
        exit 1
    }
    Write-Ok "Git $(git --version) 已安装"
}

# ── 2.5 Git 用户配置 ──
$gitUser = git config --global user.name 2>$null
$gitEmail = git config --global user.email 2>$null

if (-not $gitUser -or -not $gitEmail) {
    Write-Step "配置 Git 用户信息"
    Write-Host "   Git 需要用户名和邮箱才能提交/克隆（可以是假的，不影响使用）" -ForegroundColor White
    if (-not $gitUser) {
        $inputName = Read-Host "   用户名 (如 eight13)"
        if ($inputName) {
            git config --global user.name $inputName
            Write-Ok "user.name = $inputName"
        }
    } else {
        Write-Skip "user.name = $gitUser"
    }
    if (-not $gitEmail) {
        $inputEmail = Read-Host "   邮箱 (如 you@example.com)"
        if ($inputEmail) {
            git config --global user.email $inputEmail
            Write-Ok "user.email = $inputEmail"
        }
    } else {
        Write-Skip "user.email = $gitEmail"
    }
}

# ── 3. 拉取个人配置 ──
Write-Step "部署个人配置"
$claudeDir = Join-Path $env:USERPROFILE ".claude"

if (Test-Path (Join-Path $claudeDir ".git")) {
    Write-Skip "$claudeDir (已是 Git 仓库)"
    Push-Location $claudeDir
    git pull --ff-only 2>&1 | Out-Null
    Pop-Location
    Write-Ok "已拉取最新"
} else {
    if (Test-Path $claudeDir) {
        $backup = "${claudeDir}_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Rename-Item $claudeDir $backup
        Write-Warn "已备份原有目录到: $backup"
    }
    # 优先 HTTPS（新机器通常没有 SSH 密钥）
    git clone https://github.com/eight13/claude-knowledge.git $claudeDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "HTTPS 克隆失败，尝试 SSH..."
        git clone git@github.com:eight13/claude-knowledge.git $claudeDir 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   克隆失败，请检查网络" -ForegroundColor Red
        exit 1
    }
    Write-Ok "已克隆到 $claudeDir"
}

# ── 4. 关闭遥测 ──
Write-Step "关闭遥测"
$telemetry = [Environment]::GetEnvironmentVariable("DISABLE_TELEMETRY", "User")
if ($telemetry -eq "1") {
    Write-Skip "DISABLE_TELEMETRY=1"
} else {
    [Environment]::SetEnvironmentVariable("DISABLE_TELEMETRY", "1", "User")
    Write-Ok "已设置 DISABLE_TELEMETRY=1"
}

# ── 5. 完成 ──
Write-Host "`n===== 部署完成 =====" -ForegroundColor Green
Write-Host @"

  配置位置: $claudeDir
  包含内容: commands(3) + skills(5) + knowledge(30+) + lessons + 用户画像

  下一步:
    1. 在 VS Code 扩展商店搜索 Claude Code 并安装
    2. 登录后进入项目目录运行 /init-project 初始化项目配置

"@ -ForegroundColor White
