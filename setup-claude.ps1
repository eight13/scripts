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

# TLS 1.2（Windows PowerShell 5.1 默认 TLS 1.0，GitHub 要求 1.2）
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# 不用 Stop，避免 winget 非致命错误直接闪退
$ErrorActionPreference = "Continue"

function Write-Step($msg) { Write-Host "`n=> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "   -- $msg (已存在，跳过)" -ForegroundColor Yellow }
function Write-Warn($msg) { Write-Host "   !! $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "   X $msg" -ForegroundColor Red }

# 从注册表 / 常见路径查找 Git 并加入 PATH
function Find-GitAndAddToPath {
    $regPaths = @(
        "HKLM:\SOFTWARE\GitForWindows",
        "HKLM:\SOFTWARE\WOW6432Node\GitForWindows",
        "HKCU:\SOFTWARE\GitForWindows"
    )
    foreach ($rp in $regPaths) {
        $installPath = (Get-ItemProperty $rp -ErrorAction SilentlyContinue).InstallPath
        if ($installPath -and (Test-Path "$installPath\cmd\git.exe")) {
            $gitCmd = "$installPath\cmd"
            $env:Path = "$gitCmd;$env:Path"
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$gitCmd*") {
                [Environment]::SetEnvironmentVariable("Path", "$gitCmd;$userPath", "User")
            }
            return $true
        }
    }
    $commonPaths = @(
        "$env:ProgramFiles\Git\cmd",
        "${env:ProgramFiles(x86)}\Git\cmd",
        "$env:LOCALAPPDATA\Programs\Git\cmd"
    )
    foreach ($p in $commonPaths) {
        if (Test-Path "$p\git.exe") {
            $env:Path = "$p;$env:Path"
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$p*") {
                [Environment]::SetEnvironmentVariable("Path", "$p;$userPath", "User")
            }
            return $true
        }
    }
    return $false
}

Write-Host "`n===== Claude Code 一键部署 =====`n" -ForegroundColor Magenta

# ── 0. 检查 winget ──
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Write-Fail "未找到 winget（Windows 包管理器）"
    Write-Host "   请先从 Microsoft Store 安装 '应用安装程序'" -ForegroundColor Yellow
    Read-Host "`n按回车退出"
    exit 1
}

# ── 1. Node.js ──
Write-Step "检查 Node.js"
if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Skip "Node.js $(node --version)"
} else {
    Write-Host "   正在安装 Node.js..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Warn "Node.js 已安装但需要重启终端，请重新打开 PowerShell 后再次运行本脚本"
        Read-Host "`n按回车退出"
        exit 1
    }
    Write-Ok "Node.js $(node --version) 已安装"
}

# ── 2. Git ──
Write-Step "检查 Git"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Skip "Git $(git --version)"
} else {
    Write-Host "   正在安装 Git（winget）..." -ForegroundColor Yellow
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "   PATH 未自动生效，正在查找 Git 安装路径..." -ForegroundColor Yellow
        if (-not (Find-GitAndAddToPath)) {
            Write-Fail "Git 安装后仍找不到，请手动安装: https://git-scm.com/downloads/win"
            Read-Host "`n按回车退出"
            exit 1
        }
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fail "Git 安装后仍找不到，请手动安装: https://git-scm.com/downloads/win"
        Read-Host "`n按回车退出"
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

# Git 通用配置
Write-Step "配置 Git 通用设置"
$vscode = Get-Command code -ErrorAction SilentlyContinue
if ($vscode) {
    git config --global core.editor "`"$(($vscode).Source)`" --wait"
    Write-Ok "core.editor = VS Code"
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
    git clone https://github.com/eight13/claude-knowledge.git $claudeDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "HTTPS 克隆失败，尝试 SSH..."
        git clone git@github.com:eight13/claude-knowledge.git $claudeDir 2>&1
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "克隆失败，请检查网络"
        Read-Host "`n按回车退出"
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

# ── 5. 代理配置 ──
Write-Step "检查代理设置"
$httpProxy = [Environment]::GetEnvironmentVariable("HTTP_PROXY", "User")
if ($httpProxy) {
    Write-Skip "HTTP_PROXY = $httpProxy"
} else {
    Write-Host "   Claude Code 需要代理才能访问 API（如果你在国内）" -ForegroundColor White
    $proxyPort = Read-Host "   代理端口号（如 1099、7890，直接回车跳过）"
    if ($proxyPort) {
        $proxyUrl = "http://127.0.0.1:$proxyPort"
        [Environment]::SetEnvironmentVariable("HTTP_PROXY", $proxyUrl, "User")
        [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $proxyUrl, "User")
        Write-Ok "已设置 HTTP(S)_PROXY = $proxyUrl"
    } else {
        Write-Warn "跳过代理配置，如需设置可手动运行："
        Write-Host '   [Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://127.0.0.1:端口", "User")' -ForegroundColor Gray
        Write-Host '   [Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://127.0.0.1:端口", "User")' -ForegroundColor Gray
    }
}

# ── 6. 完成 ──
Write-Host "`n===== 部署完成 =====" -ForegroundColor Green
Write-Host @"

  配置位置: $claudeDir
  包含内容: commands(3) + skills(5) + knowledge(30+) + lessons + 用户画像

  下一步:
    1. 重启 VS Code（让 PATH 生效）
    2. 在 VS Code 扩展商店搜索 Claude Code 并安装
    3. 登录后进入项目目录运行 /init-project 初始化项目配置

"@ -ForegroundColor White

Read-Host "按回车退出"
