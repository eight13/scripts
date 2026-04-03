<#
.SYNOPSIS
    Claude Code Starter — 一键部署精简配置
.DESCRIPTION
    自动安装 Node.js / Git（如缺失）→ 部署 commands + skills 到 ~/.claude/
.NOTES
    用法: irm https://raw.githubusercontent.com/eight13/scripts/main/claude-starter/setup.ps1 | iex
    或者: .\setup.ps1
#>

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "   -- $msg (已存在，跳过)" -ForegroundColor Yellow }

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

Write-Host "`n===== Claude Code Starter 部署 =====`n" -ForegroundColor Magenta

# ── 0. 检查 winget ──
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Host "   未找到 winget（Windows 包管理器）" -ForegroundColor Red
    Write-Host "   请先从 Microsoft Store 安装 '应用安装程序'" -ForegroundColor Yellow
    exit 1
}

# ── 1. Node.js ──
Write-Step "检查 Node.js"
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Skip "Node.js $(node --version)"
} else {
    Write-Host "   正在安装 Node.js..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Host "   安装失败" -ForegroundColor Red; exit 1 }
    Refresh-Path
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Host "   已安装，请重启终端后再次运行本脚本" -ForegroundColor Yellow; exit 1
    }
    Write-Ok "Node.js $(node --version)"
}

# ── 2. Git ──
Write-Step "检查 Git"
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Write-Skip "Git $(git --version)"
} else {
    Write-Host "   正在安装 Git..." -ForegroundColor Yellow
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Write-Host "   安装失败" -ForegroundColor Red; exit 1 }
    Refresh-Path
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "   已安装，请重启终端后再次运行本脚本" -ForegroundColor Yellow; exit 1
    }
    Write-Ok "Git $(git --version)"
}

# ── 2.5 Git 用户配置 ──
$gitUser = git config --global user.name 2>$null
$gitEmail = git config --global user.email 2>$null

if (-not $gitUser -or -not $gitEmail) {
    Write-Step "配置 Git 用户信息（随便填，不影响使用）"
    if (-not $gitUser) {
        $inputName = Read-Host "   用户名"
        if ($inputName) { git config --global user.name $inputName; Write-Ok "user.name = $inputName" }
    }
    if (-not $gitEmail) {
        $inputEmail = Read-Host "   邮箱"
        if ($inputEmail) { git config --global user.email $inputEmail; Write-Ok "user.email = $inputEmail" }
    }
}

# ── 3. 部署配置 ──
Write-Step "部署 Claude Code 配置"
$claudeDir = Join-Path $env:USERPROFILE ".claude"

# 确保目录存在
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }

# 下载配置文件
$baseUrl = "https://raw.githubusercontent.com/eight13/scripts/main/claude-starter"
$files = @(
    @{ Remote = "base-style.md";                   Local = "base-style.md" }
    @{ Remote = "settings.json";                   Local = "settings.json" }
    @{ Remote = "commands/task.md";                Local = "commands/task.md" }
    @{ Remote = "commands/init-project.md";        Local = "commands/init-project.md" }
    @{ Remote = "skills/analyze/SKILL.md";         Local = "skills/analyze/SKILL.md" }
    @{ Remote = "skills/review/SKILL.md";          Local = "skills/review/SKILL.md" }
    @{ Remote = "skills/create-skill/SKILL.md";    Local = "skills/create-skill/SKILL.md" }
)

foreach ($f in $files) {
    $localPath = Join-Path $claudeDir $f.Local
    $localDir = Split-Path $localPath -Parent
    if (-not (Test-Path $localDir)) { New-Item -ItemType Directory -Path $localDir -Force | Out-Null }

    if (Test-Path $localPath) {
        Write-Skip $f.Local
    } else {
        try {
            Invoke-WebRequest -Uri "$baseUrl/$($f.Remote)" -OutFile $localPath -UseBasicParsing
            Write-Ok $f.Local
        } catch {
            Write-Host "   下载失败: $($f.Remote)" -ForegroundColor Red
        }
    }
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
  包含内容:
    - /task    统一任务入口（分析/修复/开发/探讨）
    - /init-project  项目初始化
    - /analyze 深度代码分析
    - /review  代码审查
    - /create-skill  创建新技能

  下一步:
    1. 在 VS Code 扩展商店搜索 Claude Code 并安装
    2. 进入项目目录，运行 /init-project 初始化项目配置
    3. 用 /task <描述> 开始工作

"@ -ForegroundColor White
