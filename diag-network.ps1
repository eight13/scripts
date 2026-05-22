# 网络诊断：检查为何需要 ZionLadder 才能连通
Write-Host "=== 系统代理 ==="
$proxy = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Write-Host "  ProxyEnable : $($proxy.ProxyEnable)"
Write-Host "  ProxyServer : $($proxy.ProxyServer)"
Write-Host "  ProxyOverride: $($proxy.ProxyOverride)"

Write-Host "`n=== 默认网关 ==="
Get-NetRoute -DestinationPrefix '0.0.0.0/0' | ForEach-Object {
    Write-Host "  $($_.NextHop) via $($_.InterfaceAlias) (metric=$($_.RouteMetric))"
}

Write-Host "`n=== 网卡 DNS ==="
Get-DnsClientServerAddress -AddressFamily IPv4 | Where-Object { $_.ServerAddresses.Count -gt 0 } | ForEach-Object {
    Write-Host "  $($_.InterfaceAlias): $($_.ServerAddresses -join ', ')"
}

Write-Host "`n=== 路由器代理端口探测 ==="
$ports = @(7890, 7891, 7892, 7893, 9090)
foreach ($p in $ports) {
    $r = Test-NetConnection -ComputerName 192.168.8.1 -Port $p -WarningAction SilentlyContinue -InformationLevel Quiet
    $status = if ($r) { "open" } else { "closed" }
    Write-Host "  192.168.8.1:$p : $status"
}

Write-Host "`n=== nslookup 测试 ==="
Write-Host "--- 默认 DNS ---"
nslookup api.anthropic.com 2>&1 | Select-String -Pattern "Address:|Name:"
Write-Host "--- 114 DNS (对比) ---"
nslookup api.anthropic.com 114.114.114.114 2>&1 | Select-String -Pattern "Address:|Name:"

Write-Host "`n=== 直连测试(无代理) ==="
$env:NO_PROXY = "*"
try {
    $r = Invoke-WebRequest -Uri "https://api.anthropic.com" -TimeoutSec 5 -UseBasicParsing
    Write-Host "  api.anthropic.com: 直连可达 (status=$($r.StatusCode))"
} catch {
    Write-Host "  api.anthropic.com: 直连失败 ($($_.Exception.Message -replace '\n',' '))"
}
