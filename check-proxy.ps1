$p = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Write-Host "ProxyEnable : $($p.ProxyEnable)"
Write-Host "ProxyServer : $($p.ProxyServer)"
Write-Host "ProxyOverride: $($p.ProxyOverride)"
