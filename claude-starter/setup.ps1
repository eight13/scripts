<#
.SYNOPSIS
    Claude Code Starter — 一键部署精简配置
.DESCRIPTION
    自动安装 Node.js / Git（如缺失）→ 部署 commands + skills 到 ~/.claude/
.NOTES
    用法: irm https://raw.githubusercontent.com/eight13/scripts/main/claude-starter/setup.ps1 | iex
    或者: .\setup.ps1
#>

# TLS 1.2（Windows PowerShell 5.1 默认 TLS 1.0，GitHub 要求 1.2）
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# 跳过证书验证（代理环境下 GitHub CDN 证书可能不被信任）
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

Write-Host "`n===== Claude Code Starter 部署 =====`n" -ForegroundColor Magenta

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
    if ($LASTEXITCODE -ne 0) { Write-Warn "winget 退出码: $LASTEXITCODE（可能需要管理员权限）" }
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Warn "Node.js 已安装但需要重启终端，请重新打开 PowerShell 后再次运行本脚本"
        Read-Host "`n按回车退出"
        exit 1
    }
    Write-Ok "Node.js $(node --version)"
}

# ── 2. Git ──
Write-Step "检查 Git"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Skip "Git $(git --version)"
} else {
    $gitInstalled = $false

    # 优先 winget
    Write-Host "   正在安装 Git（winget）..." -ForegroundColor Yellow
    winget install Git.Git --accept-source-agreements --accept-package-agreements
    $wingetExit = $LASTEXITCODE
    if ($wingetExit -ne 0) {
        Write-Warn "winget 失败（退出码 $wingetExit，VPN 环境常见），改为直接下载安装包..."
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    if ((Get-Command git -ErrorAction SilentlyContinue) -or (Find-GitAndAddToPath)) {
        $gitInstalled = $true
    }

    # Fallback: 通过 GitHub API 查最新 release，直接下载安装包静默安装
    # （winget 内部用 WinINet，无视 ServerCertificateValidationCallback；
    #   Invoke-RestMethod/WebRequest 走 .NET 栈，能吃到前面设的 SSL 跳过）
    if (-not $gitInstalled) {
        try {
            Write-Host "   查询 git-for-windows 最新版本..." -ForegroundColor Yellow
            $api = "https://api.github.com/repos/git-for-windows/git/releases/latest"
            $release = Invoke-RestMethod -Uri $api -UseBasicParsing -Headers @{ "User-Agent" = "claude-starter" }
            $asset = $release.assets | Where-Object { $_.name -match '^Git-.*-64-bit\.exe$' } | Select-Object -First 1
            if (-not $asset) { throw "未找到 64-bit 安装包资源" }

            $installer = Join-Path $env:TEMP $asset.name
            Write-Host "   下载 $($asset.name) ..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer -UseBasicParsing

            Write-Host "   静默安装中（约 30 秒）..." -ForegroundColor Yellow
            $proc = Start-Process -FilePath $installer -ArgumentList "/VERYSILENT","/NORESTART","/SUPPRESSMSGBOXES","/NOCANCEL" -Wait -PassThru
            if ($proc.ExitCode -ne 0) { Write-Warn "安装程序退出码: $($proc.ExitCode)" }
            Remove-Item $installer -ErrorAction SilentlyContinue

            $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            $env:Path = "$machinePath;$userPath"
            if ((Get-Command git -ErrorAction SilentlyContinue) -or (Find-GitAndAddToPath)) {
                $gitInstalled = $true
            }
        } catch {
            Write-Fail "直接下载失败: $($_.Exception.Message)"
        }
    }

    if (-not $gitInstalled) {
        Write-Fail "Git 安装后仍找不到，请手动安装: https://git-scm.com/downloads/win"
        Read-Host "`n按回车退出"
        exit 1
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
        else { Write-Warn "已跳过，后续 git commit 可能会提示设置" }
    }
    if (-not $gitEmail) {
        $inputEmail = Read-Host "   邮箱"
        if ($inputEmail) { git config --global user.email $inputEmail; Write-Ok "user.email = $inputEmail" }
        else { Write-Warn "已跳过，后续 git commit 可能会提示设置" }
    }
}

# Git 通用配置
Write-Step "配置 Git 通用设置"
$vscode = Get-Command code -ErrorAction SilentlyContinue
if ($vscode) {
    git config --global core.editor "`"$(($vscode).Source)`" --wait"
    Write-Ok "core.editor = VS Code"
} else {
    Write-Skip "VS Code 未找到，跳过 editor 设置"
}

# ── 3. 部署配置 ──
Write-Step "部署 Claude Code 配置"
$claudeDir = Join-Path $env:USERPROFILE ".claude"

if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }

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

$downloadFailed = 0
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
            Write-Fail "下载失败: $($f.Remote)"
            $downloadFailed++
        }
    }
}

if ($downloadFailed -eq $files.Count) {
    Write-Fail "所有配置文件下载失败，请检查网络/代理设置"
} elseif ($downloadFailed -gt 0) {
    Write-Warn "$downloadFailed 个文件下载失败，部分配置可能不完整"
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
    if ($proxyPort -match '^\d{1,5}$' -and [int]$proxyPort -ge 1 -and [int]$proxyPort -le 65535) {
        $proxyUrl = "http://127.0.0.1:$proxyPort"
        [Environment]::SetEnvironmentVariable("HTTP_PROXY", $proxyUrl, "User")
        [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $proxyUrl, "User")
        Write-Ok "已设置 HTTP(S)_PROXY = $proxyUrl"
    } elseif ($proxyPort) {
        Write-Fail "端口号无效（需要 1-65535 的数字），跳过代理配置"
    } else {
        Write-Warn "跳过代理配置，如需设置可手动运行："
        Write-Host '   [Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://127.0.0.1:端口", "User")' -ForegroundColor Gray
        Write-Host '   [Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://127.0.0.1:端口", "User")' -ForegroundColor Gray
    }
}

# ── 6. 完成 ──
# 恢复证书验证
[Net.ServicePointManager]::ServerCertificateValidationCallback = $null

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
    1. 重启 VS Code（让 PATH 生效）
    2. 在 VS Code 扩展商店搜索 Claude Code 并安装
    3. 进入项目目录，运行 /init-project 初始化项目配置
    4. 用 /task <描述> 开始工作

"@ -ForegroundColor White

Read-Host "按回车退出"
