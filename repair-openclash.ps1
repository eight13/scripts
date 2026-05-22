# OpenClash 故障修复工具
# 兼容 OpenWrt Dropbear SSH（无需 sftp-server）
#
# 用法：
#   .\repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass"
#   .\repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass" -DiagnoseOnly
#   .\repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass" -ResetGeoIpOnly
#   .\repair-openclash.ps1 -RouterIp 192.168.8.1 -Password "yourpass" -JustStart

param(
    [Parameter(Mandatory=$true)][string]$RouterIp,
    [Parameter(Mandatory=$true)][string]$Password,
    [switch]$DiagnoseOnly,
    [switch]$ResetGeoIpOnly,
    [switch]$JustStart,
    [string]$GeoIpUrl = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat",
    [string]$GeoIpUrlBackup = "https://github.com/MetaCubeX/meta-rules-dat/releases/latest/download/geoip.dat"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$WorkDir = Join-Path $env:TEMP "openclash-repair"
$AskPassBat = Join-Path $WorkDir "askpass.bat"
$GeoIpLocal = Join-Path $WorkDir "GeoIP.dat"
$GeoIpRemote = "/etc/openclash/GeoIP.dat"

# ========== SSH 基础设施 ==========

function Initialize-SSH {
    if (Test-Path $WorkDir) { Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

    # SSH_ASKPASS 批处理：Windows OpenSSH 要求 askpass 程序不依赖 stdin
    # 用 <NUL 阻断 stdin，set /p 输出密码不带换行
    @"
@echo off
<NUL set /p="PASSWORD_PLACEHOLDER"
"@.Replace("PASSWORD_PLACEHOLDER", $Password) | Out-File -FilePath $AskPassBat -Encoding ASCII

    $env:SSH_ASKPASS = $AskPassBat
    $env:DISPLAY = "dummy:0"
    $env:SSH_ASKPASS_REQUIRE = "force"

    # SSH 公共参数
    $script:sshOpts = "-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no"
    $script:sshTarget = "root@$RouterIp"
}

function Invoke-SSH {
    param([string]$Command, [int]$TimeoutSec = 15)
    $cmd = "ssh $script:sshOpts $script:sshTarget `"$Command`""
    $outFile = Join-Path $WorkDir "ssh_out.txt"
    $errFile = Join-Path $WorkDir "ssh_err.txt"

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "ssh"
    $psi.Arguments = "$script:sshOpts $script:sshTarget `"$Command`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit($TimeoutSec * 1000) | Out-Null

    if ($stderr -and $stderr -notmatch "WARNING.*post-quantum") {
        Write-Warning $stderr.Trim()
    }
    return $stdout.Trim()
}

function Send-FileToRouter {
    param([string]$LocalPath, [string]$RemotePath)
    Write-Host "  传输 $LocalPath -> $RemotePath ..."

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c ssh $script:sshOpts $script:sshTarget `"cat > $RemotePath`" < `"$LocalPath`""
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit(120000) | Out-Null

    if ($stderr -and $stderr -notmatch "WARNING.*post-quantum") {
        Write-Warning $stderr.Trim()
    }
}

# ========== 诊断 ==========

function Test-GeoIp {
    Write-Host "[GeoIP.dat]" -NoNewline
    $out = Invoke-SSH "ls -la $GeoIpRemote 2>&1"
    if ($out -match "No such file") {
        Write-Host " 不存在"
        return "missing"
    }
    if ($out -match "\s(\d+)\s+\S+\s+root") {
        $size = [int64]$Matches[1]
        Write-Host " $size bytes"
        if ($size -lt 10000) { return "corrupted" }
        if ($size -lt 5000000) { return "suspicious" }
        return "ok"
    }
    Write-Host " 无法解析"
    return "unknown"
}

function Test-OpenClashStatus {
    Write-Host "[OpenClash]" -NoNewline
    $out = Invoke-SSH "uci get openclash.config.enable 2>&1; echo '--PROC--'; ps | grep '/etc/openclash/clash' | grep -v grep | wc -l"

    if ($out -match "--PROC--") {
        $parts = $out -split "--PROC--"
        $enabled = $parts[0].Trim() -eq "1"
        $procCount = [int]$parts[1].Trim()
        $label = if ($enabled) { "已启用" } else { "已禁用" }
        Write-Host " $label, 进程数=$procCount"
        return @{ Enabled = $enabled; Running = ($procCount -gt 0) }
    }
    Write-Host " 无法获取状态"
    return @{ Enabled = $false; Running = $false }
}

# ========== 修复 ==========

function Repair-GeoIp {
    Write-Host "[修复] GeoIP.dat"

    # 下载
    Write-Host "  下载 (~18MB) ..."
    $ok = $false
    foreach ($url in @($GeoIpUrl, $GeoIpUrlBackup)) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $GeoIpLocal -TimeoutSec 60
            $size = (Get-Item $GeoIpLocal).Length
            if ($size -gt 100000) {
                Write-Host "  下载完成: $([math]::Round($size/1MB,1)) MB"
                $ok = $true
                break
            }
            Write-Host "  文件太小 ($size bytes), 尝试备用源..."
        } catch {
            Write-Host "  源失败: $url"
        }
    }
    if (-not $ok) { throw "所有下载源均失败" }

    Write-Host "  删除损坏文件..."
    Invoke-SSH "rm -f $GeoIpRemote" 10

    Write-Host "  上传..."
    Send-FileToRouter -LocalPath $GeoIpLocal -RemotePath $GeoIpRemote

    Write-Host "  验证..." -NoNewline
    $out = Invoke-SSH "ls -la $GeoIpRemote 2>&1"
    if ($out -match "\s(\d+)\s") {
        $newSize = [int64]$Matches[1]
        Write-Host " $newSize bytes"
        if ($newSize -lt 100000) { Write-Warning "文件可能损坏!" }
    }
}

function Start-OpenClash {
    Write-Host "[启动] OpenClash"

    $st = Test-OpenClashStatus
    if (-not $st.Enabled) {
        Write-Host "  解除 disabled 状态..."
        Invoke-SSH "uci set openclash.config.enable=1 && uci commit openclash" 5
    }

    Write-Host "  启动服务..."
    Invoke-SSH "/etc/init.d/openclash start" 10

    Write-Host "  等待启动 (15s)..." -NoNewline
    for ($i = 0; $i -lt 15; $i++) { Write-Host "." -NoNewline; Start-Sleep 1 }
    Write-Host ""

    $st = Test-OpenClashStatus
    if ($st.Running) {
        Write-Host "  OpenClash 启动成功" -ForegroundColor Green
    } else {
        Write-Host "  启动失败，查看日志..."
        Invoke-SSH "tail -20 /tmp/openclash.log" 10
    }
}

# ========== 诊断报告 ==========

function Show-Diagnose {
    Write-Host "`n========== OpenClash 诊断 =========="
    Write-Host "路由器: $RouterIp`n"

    $geoip = Test-GeoIp
    Write-Host ""
    $status = Test-OpenClashStatus
    Write-Host ""

    Write-Host "[磁盘]" -NoNewline
    $disk = Invoke-SSH "df -h /overlay 2>&1 | tail -1"
    Write-Host " $disk"

    Write-Host "`n[最近日志]"
    Invoke-SSH "tail -15 /tmp/openclash.log" 10

    Write-Host "====================================`n"

    return @{ GeoIp = $geoip; Status = $status }
}

# ========== 主流程 ==========

Write-Host "OpenClash 修复工具`n" -ForegroundColor Cyan

Initialize-SSH

if ($JustStart) {
    Start-OpenClash
    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
    exit
}

if ($ResetGeoIpOnly) {
    Repair-GeoIp
    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
    exit
}

$diag = Show-Diagnose

if ($DiagnoseOnly) {
    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
    exit
}

# 修复模式
if ($diag.GeoIp -in @("missing", "corrupted", "suspicious")) {
    Repair-GeoIp
    if (-not $diag.Status.Running) {
        $ans = Read-Host "`nGeoIP.dat 已修复，启动 OpenClash? [Y/n]"
        if ($ans -ne "n") { Start-OpenClash }
    }
} elseif (-not $diag.Status.Running) {
    Write-Host "GeoIP.dat 正常但 OpenClash 未运行。"
    $ans = Read-Host "启动? [Y/n]"
    if ($ans -ne "n") { Start-OpenClash }
} else {
    Write-Host "`nOpenClash 状态正常，无需修复。" -ForegroundColor Green
}

Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
Write-Host "完成。"
