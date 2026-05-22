sc config SharedAccess start=disabled
net stop SharedAccess
if ($LASTEXITCODE -ne 0) {
    Write-Host "net stop failed, force killing..."
    $p = (Get-WmiObject Win32_Service -Filter "Name='SharedAccess'").ProcessId
    if ($p) { Stop-Process -Id $p -Force -ErrorAction Stop }
}
Get-Service SharedAccess | Format-Table Name,Status,StartType
