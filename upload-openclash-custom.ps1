# 上传 openclash_custom_overwrite.sh 到路由器并重启 OpenClash
# 用法：.\upload-openclash-custom.ps1 -Password "yourpass"
#       .\upload-openclash-custom.ps1 -Password "yourpass" -LocalPath "other.sh"

param(
    [Parameter(Mandatory=$true)][string]$Password,
    [string]$RouterIp = "192.168.8.1",
    [string]$LocalPath = "D:/workspace/scripts/openclash_custom_overwrite.sh",
    [string]$RemotePath = "/etc/openclash/custom/openclash_custom_overwrite.sh"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$WorkDir = Join-Path $env:TEMP "oclash-upload"
$AskPassBat = Join-Path $WorkDir "askpass.bat"

# 准备 ASKPASS
if (Test-Path $WorkDir) { Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null

@"
@echo off
<NUL set /p="$Password"
"@ | Out-File -FilePath $AskPassBat -Encoding ASCII

$env:SSH_ASKPASS = $AskPassBat
$env:DISPLAY = "dummy:0"
$env:SSH_ASKPASS_REQUIRE = "force"

$sshOpts = "-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no"

# 上传
Write-Host "Uploading to $RouterIp ..." -ForegroundColor Cyan
$args = "$sshOpts `"$LocalPath`" root@$RouterIp`:`"$RemotePath`""

$psi = [System.Diagnostics.ProcessStartInfo]::new()
$psi.FileName = "scp"
$psi.Arguments = $args
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$proc = [System.Diagnostics.Process]::Start($psi)
$stderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit(15000) | Out-Null

if ($stderr -and $stderr -notmatch "WARNING.*post-quantum") {
    Write-Warning $stderr.Trim()
}

if ($proc.ExitCode -ne 0) {
    Write-Host "Upload FAILED (exit=$($proc.ExitCode))" -ForegroundColor Red
    Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "Upload OK. Restarting OpenClash..." -ForegroundColor Green

# 重启
$psi2 = [System.Diagnostics.ProcessStartInfo]::new()
$psi2.FileName = "ssh"
$psi2.Arguments = "$sshOpts root@$RouterIp `"/etc/init.d/openclash restart`""
$psi2.RedirectStandardError = $true
$psi2.UseShellExecute = $false
$psi2.CreateNoWindow = $true
$proc2 = [System.Diagnostics.Process]::Start($psi2)
$stderr2 = $proc2.StandardError.ReadToEnd()
$proc2.WaitForExit(15000) | Out-Null

if ($stderr2) {
    $clean = $stderr2 -split "`n" | Where-Object { $_ -notmatch "WARNING.*post-quantum" }
    if ($clean) { Write-Host $clean }
}

Write-Host "Done. Test the game now." -ForegroundColor Green

Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
