<#
.SYNOPSIS
    网络状态快照工具 (Network Snapshot) - 监控VPN/代理对系统的修改并恢复
.DESCRIPTION
    监控25项网络设置变化，支持快照/对比/恢复/实时监控/一键修复
.NOTES
    Author: Claude Code
    Version: 1.0.0
    Date: 2026-03-12
#>

[CmdletBinding(DefaultParameterSetName = 'HealthCheck')]
param(
    [Parameter(ParameterSetName = 'Save')][switch]$Save,
    [Parameter(ParameterSetName = 'Compare')][switch]$Compare,
    [Parameter(ParameterSetName = 'Restore')][switch]$Restore,
    [Parameter(ParameterSetName = 'Watch')][switch]$Watch,
    [Parameter(ParameterSetName = 'List')][switch]$List,
    [Parameter(ParameterSetName = 'FixProxy')][switch]$FixProxy,
    [Parameter(ParameterSetName = 'FixDNS')][switch]$FixDNS,
    [Parameter(ParameterSetName = 'FixAll')][switch]$FixAll,
    [Parameter(ParameterSetName = 'Help')][switch]$Help,

    [string]$Name,
    [string[]]$Only,
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$Full,
    [switch]$Brief,
    [int]$Interval = 5,
    [string]$Lang = "cn"
)

# ============================================================================
#  全局配置
# ============================================================================

$script:Version = "1.0.0"
$script:SnapshotDir = Join-Path $env:LOCALAPPDATA "network-snapshots"
$script:MaxSnapshots = 20
$script:MaxSnapshotAgeDays = 30

# 分类定义
$script:Categories = [ordered]@{
    # 代理类
    "SystemProxy"      = @{ Group = "代理"; Name = "系统代理 (System Proxy)"; Tier = 1; DangerRestore = $false }
    "ProxyBinaryBlob"  = @{ Group = "代理"; Name = "代理二进制设置 (Proxy Blob)"; Tier = 3; DangerRestore = $false }
    "WinHTTPProxy"     = @{ Group = "代理"; Name = "WinHTTP代理 (WinHTTP)"; Tier = 2; DangerRestore = $false }
    "PACConfig"        = @{ Group = "代理"; Name = "PAC自动代理 (PAC)"; Tier = 2; DangerRestore = $false }
    "GroupPolicyProxy" = @{ Group = "代理"; Name = "组策略代理 (GP Proxy)"; Tier = 2; DangerRestore = $false }
    "PortProxy"        = @{ Group = "代理"; Name = "端口转发 (PortProxy)"; Tier = 2; DangerRestore = $true }

    # DNS类
    "DNSServers"       = @{ Group = "DNS"; Name = "DNS服务器 (DNS Servers)"; Tier = 1; DangerRestore = $false }
    "NRPTPolicy"       = @{ Group = "DNS"; Name = "NRPT策略 (NRPT Policy)"; Tier = 2; DangerRestore = $true }
    "DoHSettings"      = @{ Group = "DNS"; Name = "DoH设置 (DNS over HTTPS)"; Tier = 2; DangerRestore = $true }
    "DNSServices"      = @{ Group = "DNS"; Name = "DNS相关服务 (DNS Services)"; Tier = 3; DangerRestore = $true }
    "SMHNRSwitch"      = @{ Group = "DNS"; Name = "多宿主名称解析 (SMHNR)"; Tier = 3; DangerRestore = $true }

    # 网络类
    "RoutingTable"     = @{ Group = "网络"; Name = "路由表 (Routing Table)"; Tier = 1; DangerRestore = $true }
    "AdapterConfig"    = @{ Group = "网络"; Name = "网卡配置 (Adapter Config)"; Tier = 1; DangerRestore = $true }
    "InterfaceMetrics" = @{ Group = "网络"; Name = "接口度量值 (Interface Metrics)"; Tier = 2; DangerRestore = $true }
    "NetworkProfiles"  = @{ Group = "网络"; Name = "网络配置文件 (Network Profiles)"; Tier = 3; DangerRestore = $true }
    "WFPFilters"       = @{ Group = "网络"; Name = "WFP内核过滤器 (WFP Filters)"; Tier = 2; DangerRestore = $true }
    "AdapterMTU"       = @{ Group = "网络"; Name = "MTU设置 (MTU)"; Tier = 3; DangerRestore = $true }

    # 系统类
    "FirewallRules"    = @{ Group = "系统"; Name = "防火墙规则 (Firewall Rules)"; Tier = 2; DangerRestore = $true }
    "WinsockCatalog"   = @{ Group = "系统"; Name = "Winsock目录 (Winsock)"; Tier = 2; DangerRestore = $true }
    "HostsFile"        = @{ Group = "系统"; Name = "hosts文件 (Hosts)"; Tier = 2; DangerRestore = $true }
    "RootCerts"        = @{ Group = "系统"; Name = "根证书 (Root Certs)"; Tier = 2; DangerRestore = $true }
    "UWPLoopback"      = @{ Group = "系统"; Name = "UWP回环豁免 (UWP Loopback)"; Tier = 3; DangerRestore = $true }

    # 环境类
    "EnvVars"          = @{ Group = "环境"; Name = "环境变量 (Env Vars)"; Tier = 2; DangerRestore = $false }
    "StartupEntries"   = @{ Group = "环境"; Name = "开机启动项 (Startup)"; Tier = 2; DangerRestore = $true }
    "IPStackFlags"     = @{ Group = "环境"; Name = "IP栈标志 (IP Stack Flags)"; Tier = 2; DangerRestore = $true }
}

# ============================================================================
#  输出辅助函数
# ============================================================================

function Write-C {
    param([string]$Text, [string]$Color = "White", [switch]$NoNewline)
    $params = @{ Object = $Text; ForegroundColor = $Color; NoNewline = $NoNewline }
    Write-Host @params
}

function Write-Header { param([string]$Text) Write-C "`n=== $Text ===" "Cyan" }
function Write-OK { param([string]$Text) Write-C "  ✓ $Text" "Green" }
function Write-Warn { param([string]$Text) Write-C "  ⚠ $Text" "Yellow" }
function Write-Err { param([string]$Text) Write-C "  ✗ $Text" "Red" }
function Write-Info { param([string]$Text) Write-C "  · $Text" "Gray" }
function Write-Change {
    param([string]$Label, [string]$Old, [string]$New)
    Write-C "  " -NoNewline; Write-C "$Label`:" "White" -NoNewline
    Write-C " $Old" "Red" -NoNewline; Write-C " → " "Gray" -NoNewline; Write-C "$New" "Green"
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SafeTimestamp { return (Get-Date -Format "yyyyMMdd-HHmmss") }

# ============================================================================
#  分类数据采集函数 (25项)
# ============================================================================

function Collect-SystemProxy {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    return [PSCustomObject]@{
        ProxyEnable   = [int]($props.ProxyEnable)
        ProxyServer   = [string]($props.ProxyServer)
        ProxyOverride = [string]($props.ProxyOverride)
        AutoDetect    = [int]($props.AutoDetect)
    }
}

function Collect-ProxyBinaryBlob {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
    try {
        $blob = (Get-ItemProperty -Path $regPath -Name "DefaultConnectionSettings" -ErrorAction Stop).DefaultConnectionSettings
        return [PSCustomObject]@{
            BlobBase64 = [Convert]::ToBase64String($blob)
            BlobLength = $blob.Length
        }
    } catch {
        return [PSCustomObject]@{ BlobBase64 = ""; BlobLength = 0 }
    }
}

function Collect-WinHTTPProxy {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections"
    try {
        $blob = (Get-ItemProperty -Path $regPath -Name "WinHttpSettings" -ErrorAction Stop).WinHttpSettings
        # 解析 WinHTTP 二进制设置
        if ($blob -and $blob.Length -gt 12) {
            $proxyLen = [BitConverter]::ToInt32($blob, 12)
            if ($proxyLen -gt 0 -and (16 + $proxyLen) -le $blob.Length) {
                $proxy = [Text.Encoding]::ASCII.GetString($blob, 16, $proxyLen)
            } else { $proxy = "" }
        } else { $proxy = "" }
        return [PSCustomObject]@{
            ProxyServer = $proxy
            BlobBase64  = [Convert]::ToBase64String($blob)
        }
    } catch {
        return [PSCustomObject]@{ ProxyServer = ""; BlobBase64 = "" }
    }
}

function Collect-PACConfig {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $props = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    $url = [string]($props.AutoConfigURL)
    $hash = ""
    if ($url) {
        try {
            $wc = New-Object System.Net.WebClient
            $wc.Proxy = $null
            $content = $wc.DownloadString($url)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $hash = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))
            $wc.Dispose(); $sha.Dispose()
        } catch { $hash = "FETCH_FAILED" }
    }
    return [PSCustomObject]@{ AutoConfigURL = $url; ContentHash = $hash }
}

function Collect-GroupPolicyProxy {
    $paths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
        "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        "HKLM:\SOFTWARE\Policies\Google\Chrome"
    )
    $results = @()
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $props = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
            $results += [PSCustomObject]@{
                Path        = $p
                ProxyEnable = $props.ProxyEnable
                ProxyServer = $props.ProxyServer
            }
        }
    }
    return $results
}

function Collect-PortProxy {
    $output = netsh interface portproxy show all 2>$null
    $rules = @()
    $parsing = $false
    foreach ($line in $output) {
        if ($line -match "^\s*\d") {
            $parts = $line -split "\s+" | Where-Object { $_ }
            if ($parts.Count -ge 4) {
                $rules += [PSCustomObject]@{
                    ListenAddress  = $parts[0]
                    ListenPort     = $parts[1]
                    ConnectAddress = $parts[2]
                    ConnectPort    = $parts[3]
                }
            }
        }
    }
    return $rules
}

function Collect-DNSServers {
    try {
        $dns = Get-DnsClientServerAddress -ErrorAction Stop | Where-Object { $_.ServerAddresses.Count -gt 0 }
        return $dns | ForEach-Object {
            [PSCustomObject]@{
                InterfaceAlias = $_.InterfaceAlias
                InterfaceIndex = $_.InterfaceIndex
                AddressFamily  = $_.AddressFamily.ToString()
                ServerAddresses = ($_.ServerAddresses -join ",")
            }
        }
    } catch { return @() }
}

function Collect-NRPTPolicy {
    try {
        $nrpt = Get-DnsClientNrptPolicy -ErrorAction Stop
        return $nrpt | ForEach-Object {
            [PSCustomObject]@{
                Namespace       = $_.Namespace
                NameServers     = ($_.NameServers -join ",")
                DnsSecEnable    = $_.DnsSecEnable
            }
        }
    } catch { return @() }
}

function Collect-DoHSettings {
    try {
        $servers = Get-DnsClientDohServerAddress -ErrorAction Stop
        return $servers | ForEach-Object {
            [PSCustomObject]@{
                ServerAddress  = $_.ServerAddress
                DohTemplate    = $_.DohTemplate
                AllowFallback  = $_.AllowFallbackToUdp
                AutoUpgrade    = $_.AutoUpgrade
            }
        }
    } catch { return @() }
}

function Collect-DNSServices {
    $serviceNames = @("Dnscache", "iphlpsvc", "WinHttpAutoProxySvc", "WinNat", "RemoteAccess", "BFE", "SharedAccess", "mpssvc")
    return $serviceNames | ForEach-Object {
        $svc = Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($svc) {
            [PSCustomObject]@{
                Name      = $svc.Name
                Status    = $svc.Status.ToString()
                StartType = $svc.StartType.ToString()
            }
        }
    } | Where-Object { $_ }
}

function Collect-SMHNRSwitch {
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    $val = $null
    if (Test-Path $regPath) {
        $val = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).DisableSmartNameResolution
    }
    return [PSCustomObject]@{ DisableSmartNameResolution = $val }
}

function Collect-RoutingTable {
    try {
        $routes = Get-NetRoute -ErrorAction Stop | Where-Object {
            $_.DestinationPrefix -ne "ff00::/8" -and
            $_.DestinationPrefix -notmatch "^fe80:" -and
            $_.InterfaceAlias -ne "Loopback Pseudo-Interface 1"
        }
        return $routes | ForEach-Object {
            [PSCustomObject]@{
                DestinationPrefix = $_.DestinationPrefix
                NextHop           = $_.NextHop
                InterfaceAlias    = $_.InterfaceAlias
                InterfaceIndex    = $_.InterfaceIndex
                RouteMetric       = $_.RouteMetric
                AddressFamily     = $_.AddressFamily.ToString()
            }
        }
    } catch { return @() }
}

function Collect-AdapterConfig {
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -ne "Not Present" }
        $result = @()
        foreach ($a in $adapters) {
            $ips = Get-NetIPAddress -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue
            $gw = Get-NetIPConfiguration -InterfaceIndex $a.InterfaceIndex -ErrorAction SilentlyContinue
            $isVirtual = $a.InterfaceDescription -match "(?i)(wintun|tun|tap|sing|clash|wireguard|hyper-v|virtual)"
            $result += [PSCustomObject]@{
                Name                = $a.Name
                InterfaceDescription = $a.InterfaceDescription
                Status              = $a.Status.ToString()
                MacAddress          = $a.MacAddress
                InterfaceIndex      = $a.InterfaceIndex
                IsVirtual           = $isVirtual
                IPv4Addresses       = ($ips | Where-Object { $_.AddressFamily -eq "IPv4" } | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" }) -join ","
                IPv6Addresses       = ($ips | Where-Object { $_.AddressFamily -eq "IPv6" -and $_.IPAddress -notmatch "^fe80" } | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" }) -join ","
                DefaultGateway      = ($gw.IPv4DefaultGateway.NextHop) -join ","
            }
        }
        return $result
    } catch { return @() }
}

function Collect-InterfaceMetrics {
    try {
        return Get-NetIPInterface -ErrorAction Stop | Where-Object { $_.InterfaceAlias -ne "Loopback Pseudo-Interface 1" } | ForEach-Object {
            [PSCustomObject]@{
                InterfaceAlias  = $_.InterfaceAlias
                InterfaceIndex  = $_.InterfaceIndex
                AddressFamily   = $_.AddressFamily.ToString()
                InterfaceMetric = $_.InterfaceMetric
                Dhcp            = $_.Dhcp.ToString()
            }
        }
    } catch { return @() }
}

function Collect-NetworkProfiles {
    try {
        return Get-NetConnectionProfile -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                InterfaceAlias  = $_.InterfaceAlias
                NetworkCategory = $_.NetworkCategory.ToString()
                IPv4Connectivity = $_.IPv4Connectivity.ToString()
                IPv6Connectivity = $_.IPv6Connectivity.ToString()
            }
        }
    } catch { return @() }
}

function Collect-WFPFilters {
    # 用 netsh 获取非系统 WFP sublayer 和 filter 计数
    try {
        $sublayers = netsh wfp show sublayers 2>$null
        $filterCount = 0
        $customSublayers = @()
        $inSublayer = $false
        $currentName = ""

        foreach ($line in $sublayers) {
            if ($line -match "sublayerKey\s*=\s*(.+)") { $currentKey = $Matches[1].Trim() }
            if ($line -match "displayData\.name\s*=\s*(.+)") {
                $currentName = $Matches[1].Trim()
                if ($currentName -notmatch "(?i)(microsoft|windows|wfp|ipsec|rpc|tcp|stealth)") {
                    $customSublayers += [PSCustomObject]@{ Name = $currentName; Key = $currentKey }
                }
            }
        }
        # 获取过滤器总数
        $state = netsh wfp show state 2>$null
        $filterCount = ($state | Select-String "filterKey").Count

        return [PSCustomObject]@{
            TotalFilterCount  = $filterCount
            CustomSublayers   = $customSublayers
            CustomSublayerCount = $customSublayers.Count
        }
    } catch {
        return [PSCustomObject]@{ TotalFilterCount = 0; CustomSublayers = @(); CustomSublayerCount = 0 }
    }
}

function Collect-AdapterMTU {
    try {
        return Get-NetIPInterface -ErrorAction Stop | Where-Object {
            $_.InterfaceAlias -ne "Loopback Pseudo-Interface 1"
        } | ForEach-Object {
            [PSCustomObject]@{
                InterfaceAlias = $_.InterfaceAlias
                AddressFamily  = $_.AddressFamily.ToString()
                NlMtu          = $_.NlMtu
            }
        }
    } catch { return @() }
}

function Collect-FirewallRules {
    try {
        # 只采集非微软默认规则，提高性能
        $rules = Get-NetFirewallRule -ErrorAction Stop | Where-Object {
            $_.DisplayGroup -eq $null -or $_.DisplayGroup -eq "" -or
            $_.DisplayGroup -match "(?i)(v2ray|xray|clash|sing|wireguard|proxy|vpn|zion|tun)"
        } | Select-Object -First 500
        return $rules | ForEach-Object {
            [PSCustomObject]@{
                Name        = $_.Name
                DisplayName = $_.DisplayName
                Enabled     = $_.Enabled.ToString()
                Direction   = $_.Direction.ToString()
                Action      = $_.Action.ToString()
                Profile     = $_.Profile.ToString()
            }
        }
    } catch { return @() }
}

function Collect-WinsockCatalog {
    $output = netsh winsock show catalog 2>$null
    $nonMS = @()
    $currentEntry = @{}
    foreach ($line in $output) {
        if ($line -match "^\s*$" -and $currentEntry.Count -gt 0) {
            if ($currentEntry["Path"] -and $currentEntry["Path"] -notmatch "(?i)\\windows\\system32\\") {
                $nonMS += [PSCustomObject]@{
                    Description = $currentEntry["Description"]
                    Path        = $currentEntry["Path"]
                }
            }
            $currentEntry = @{}
        }
        if ($line -match "Description\s*:\s*(.+)") { $currentEntry["Description"] = $Matches[1].Trim() }
        if ($line -match "Provider Path\s*:\s*(.+)") { $currentEntry["Path"] = $Matches[1].Trim() }
    }
    # 同时记录目录条目总数
    $totalCount = ($output | Select-String "Catalog Entry Id").Count
    return [PSCustomObject]@{
        TotalEntries      = $totalCount
        NonSystemEntries  = $nonMS
        NonSystemCount    = $nonMS.Count
    }
}

function Collect-HostsFile {
    $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
    try {
        $bytes = [System.IO.File]::ReadAllBytes($hostsPath)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hash = [Convert]::ToBase64String($sha.ComputeHash($bytes))
        $sha.Dispose()
        # 提取非注释非空行
        $content = [System.IO.File]::ReadAllText($hostsPath)
        $activeLines = $content -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch "^\s*#" }
        # 检查 DataBasePath 是否被改
        $dbPath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ErrorAction SilentlyContinue).DataBasePath
        return [PSCustomObject]@{
            Hash         = $hash
            ActiveLines  = $activeLines
            ActiveCount  = $activeLines.Count
            DataBasePath = $dbPath
        }
    } catch {
        return [PSCustomObject]@{ Hash = ""; ActiveLines = @(); ActiveCount = 0; DataBasePath = "" }
    }
}

function Collect-RootCerts {
    $stores = @("LocalMachine\Root", "CurrentUser\Root", "LocalMachine\CA", "LocalMachine\AuthRoot")
    $results = @()
    foreach ($store in $stores) {
        try {
            $certs = Get-ChildItem "Cert:\$store" -ErrorAction Stop | Where-Object {
                $_.Issuer -notmatch "(?i)(Microsoft|DigiCert|VeriSign|Comodo|Let's Encrypt|GlobalSign|Entrust|GeoTrust|Symantec|Thawte|GoDaddy|Go Daddy|Baltimore|Starfield|Amazon|Google Trust|ISRG)" -and
                $_.Issuer -notmatch "(?i)(USERTrust|QuoVadis|Buypass|Certum|T-Systems|Actalis|Trustwave|Sectigo|IdenTrust|SECOM|CFCA|GDCA|WoSign)" -and
                $_.Issuer -notmatch "(?i)(SSL\.com|Hellenic|AddTrust|Root Agency|Hongkong Post|TWCA|eMudhra|Autoridad|Certigna|Izenpe|NetLock|OISTE|SwissSign|Microsec|ANF|D-TRUST|Chunghwa|AC RAIZ|ACCV|Atos|Dhimyotis|Firmaprofesional|HARICA|TunTrust|vTrus)"
            }
            foreach ($c in $certs) {
                $results += [PSCustomObject]@{
                    Store      = $store
                    Subject    = $c.Subject
                    Issuer     = $c.Issuer
                    Thumbprint = $c.Thumbprint
                    NotAfter   = $c.NotAfter.ToString("yyyy-MM-dd")
                }
            }
        } catch {}
    }
    return $results
}

function Collect-UWPLoopback {
    try {
        $output = CheckNetIsolation.exe LoopbackExempt -s 2>$null
        $sids = @()
        foreach ($line in $output) {
            if ($line -match "SID:\s*(.+)") { $sids += $Matches[1].Trim() }
            elseif ($line -match "^S-\d") { $sids += $line.Trim() }
        }
        return [PSCustomObject]@{ ExemptSIDs = $sids; Count = $sids.Count }
    } catch {
        return [PSCustomObject]@{ ExemptSIDs = @(); Count = 0 }
    }
}

function Collect-EnvVars {
    $varNames = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy")
    $results = @()
    foreach ($name in $varNames) {
        $userVal = [Environment]::GetEnvironmentVariable($name, "User")
        $machVal = [Environment]::GetEnvironmentVariable($name, "Machine")
        if ($userVal -or $machVal) {
            $results += [PSCustomObject]@{
                Name         = $name
                UserValue    = [string]$userVal
                MachineValue = [string]$machVal
            }
        }
    }
    return $results
}

function Collect-StartupEntries {
    $paths = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    )
    $results = @()
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $props = Get-ItemProperty -Path $p -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object {
                $_.Name -notmatch "^PS" -and $_.Value -match "(?i)(v2ray|xray|clash|sing|wireguard|proxy|vpn|zion|ladder|tun|trojan|shadowsocks|ss-|ssr)"
            } | ForEach-Object {
                $results += [PSCustomObject]@{
                    RegistryPath = $p
                    Name         = $_.Name
                    Value        = $_.Value
                }
            }
        }
    }
    return $results
}

function Collect-IPStackFlags {
    $tcpipParams = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -ErrorAction SilentlyContinue
    $ipv6Params = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -ErrorAction SilentlyContinue
    # IP 转发状态
    $forwarding = @()
    try {
        $forwarding = Get-NetIPInterface -ErrorAction Stop | Where-Object { $_.Forwarding -eq "Enabled" } | ForEach-Object {
            [PSCustomObject]@{ InterfaceAlias = $_.InterfaceAlias; AddressFamily = $_.AddressFamily.ToString() }
        }
    } catch {}
    return [PSCustomObject]@{
        IPEnableRouter     = [int]($tcpipParams.IPEnableRouter)
        DisabledComponents = [int]($ipv6Params.DisabledComponents)
        ForwardingEnabled  = $forwarding
    }
}

# ============================================================================
#  快照采集总入口
# ============================================================================

function Collect-AllCategories {
    param([string[]]$FilterCategories)

    $data = [ordered]@{}
    $errors = @()

    $categoryList = if ($FilterCategories -and $FilterCategories.Count -gt 0) {
        # 支持按组名过滤
        $expanded = @()
        foreach ($f in $FilterCategories) {
            $matched = $script:Categories.Keys | Where-Object {
                $_ -eq $f -or $script:Categories[$_].Group -match "(?i)$f" -or $script:Categories[$_].Name -match "(?i)$f"
            }
            $expanded += $matched
        }
        $expanded | Select-Object -Unique
    } else {
        $script:Categories.Keys
    }

    foreach ($cat in $categoryList) {
        try {
            $funcName = "Collect-$cat"
            $data[$cat] = & $funcName
        } catch {
            $errors += "$cat`: $($_.Exception.Message)"
            $data[$cat] = $null
        }
    }

    return @{
        Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        OSVersion  = [Environment]::OSVersion.Version.ToString()
        PSVersion  = $PSVersionTable.PSVersion.ToString()
        IsAdmin    = (Test-IsAdmin)
        Data       = $data
        Errors     = $errors
    }
}

# ============================================================================
#  快照存储
# ============================================================================

function Save-Snapshot {
    param([string]$SnapshotName, [hashtable]$SnapshotData)

    if (-not (Test-Path $script:SnapshotDir)) {
        New-Item -Path $script:SnapshotDir -ItemType Directory -Force | Out-Null
    }

    $ts = Get-SafeTimestamp
    if (-not $SnapshotName) { $SnapshotName = $ts }
    $folderName = "${SnapshotName}_${ts}"
    $folder = Join-Path $script:SnapshotDir $folderName
    New-Item -Path $folder -ItemType Directory -Force | Out-Null

    # 保存主数据为 JSON
    $jsonPath = Join-Path $folder "snapshot.json"
    $SnapshotData | ConvertTo-Json -Depth 15 -Compress:$false | Out-File -FilePath $jsonPath -Encoding UTF8

    # 生成紧急恢复批处理
    Generate-EmergencyBat -Folder $folder -SnapshotData $SnapshotData

    # 清理旧快照
    Cleanup-OldSnapshots

    return $folder
}

function Load-Snapshot {
    param([string]$SnapshotName)

    if (-not (Test-Path $script:SnapshotDir)) { return $null }

    $folders = Get-ChildItem -Path $script:SnapshotDir -Directory | Sort-Object LastWriteTime -Descending

    if ($SnapshotName) {
        $match = $folders | Where-Object { $_.Name -like "*${SnapshotName}*" } | Select-Object -First 1
    } else {
        $match = $folders | Select-Object -First 1
    }

    if (-not $match) { return $null }

    $jsonPath = Join-Path $match.FullName "snapshot.json"
    if (-not (Test-Path $jsonPath)) { return $null }

    $raw = Get-Content -Path $jsonPath -Raw -Encoding UTF8
    $data = $raw | ConvertFrom-Json

    # ConvertFrom-Json 返回 PSCustomObject，需转换 Data 为 hashtable
    $dataHT = [ordered]@{}
    if ($data.Data) {
        $data.Data.PSObject.Properties | ForEach-Object { $dataHT[$_.Name] = $_.Value }
    }

    return @{
        Timestamp  = $data.Timestamp
        OSVersion  = $data.OSVersion
        PSVersion  = $data.PSVersion
        IsAdmin    = $data.IsAdmin
        Data       = $dataHT
        Errors     = @($data.Errors)
        FolderName = $match.Name
        FolderPath = $match.FullName
    }
}

function Cleanup-OldSnapshots {
    if (-not (Test-Path $script:SnapshotDir)) { return }
    $folders = Get-ChildItem -Path $script:SnapshotDir -Directory | Sort-Object LastWriteTime -Descending

    # 按数量清理
    if ($folders.Count -gt $script:MaxSnapshots) {
        $folders | Select-Object -Skip $script:MaxSnapshots | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    # 按时间清理
    $cutoff = (Get-Date).AddDays(-$script:MaxSnapshotAgeDays)
    $folders | Where-Object { $_.LastWriteTime -lt $cutoff } | Select-Object -Skip 1 | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
#  紧急恢复批处理生成
# ============================================================================

function Generate-EmergencyBat {
    param([string]$Folder, [hashtable]$SnapshotData)

    $proxy = $SnapshotData.Data["SystemProxy"]
    $batContent = @"
@echo off
chcp 65001 >nul
echo ========================================
echo  网络紧急恢复工具 (Emergency Restore)
echo  基于快照: $(Split-Path $Folder -Leaf)
echo ========================================
echo.

echo [1/5] 恢复系统代理设置...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d $([int]$proxy.ProxyEnable) /f >nul 2>&1
$(if ($proxy.ProxyServer) {
    "reg add ""HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"" /v ProxyServer /t REG_SZ /d ""$($proxy.ProxyServer)"" /f >nul 2>&1"
} else {
    "reg delete ""HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings"" /v ProxyServer /f >nul 2>&1"
})
echo   完成

echo [2/5] 重置DNS为自动获取...
for /f "tokens=1,2,3*" %%a in ('netsh interface show interface ^| findstr /R "已连接 Connected"') do (
    netsh interface ip set dns "%%d" dhcp >nul 2>&1
)
echo   完成

echo [3/5] 刷新DNS缓存...
ipconfig /flushdns >nul 2>&1
echo   完成

echo [4/5] 重置WinHTTP代理...
netsh winhttp reset proxy >nul 2>&1
echo   完成

echo [5/5] 测试网络连通性...
ping -n 1 -w 3000 www.baidu.com >nul 2>&1
if %errorlevel%==0 (
    echo   ✓ 网络连通正常
) else (
    echo   ✗ 网络仍不通，可能需要重启网络适配器或重启电脑
)

echo.
echo ========================================
echo  恢复完成！
echo ========================================
pause
"@
    $batPath = Join-Path $Folder "emergency-restore.bat"
    [System.IO.File]::WriteAllText($batPath, $batContent, [System.Text.Encoding]::GetEncoding(936))
}

# ============================================================================
#  对比逻辑
# ============================================================================

function Compare-Snapshots {
    param([hashtable]$OldSnap, [hashtable]$NewSnap, [switch]$ShowAll)

    $changes = [ordered]@{}
    $totalChanges = 0
    $groupChanges = [ordered]@{}

    foreach ($cat in $script:Categories.Keys) {
        $old = $OldSnap.Data[$cat]
        $new = $NewSnap.Data[$cat]

        if ($null -eq $old -and $null -eq $new) { continue }

        $catChanges = Compare-CategoryData -Category $cat -Old $old -New $new
        if ($catChanges.Count -gt 0) {
            $changes[$cat] = $catChanges
            $totalChanges += $catChanges.Count
            $group = $script:Categories[$cat].Group
            if (-not $groupChanges[$group]) { $groupChanges[$group] = 0 }
            $groupChanges[$group] += $catChanges.Count
        }
    }

    return @{
        Changes      = $changes
        TotalChanges = $totalChanges
        GroupChanges = $groupChanges
    }
}

function Compare-CategoryData {
    param([string]$Category, $Old, $New)

    $changes = @()

    # 处理简单对象（PSCustomObject）
    if ($Old -is [PSCustomObject] -and $New -is [PSCustomObject]) {
        foreach ($prop in $New.PSObject.Properties) {
            $oldVal = $Old.PSObject.Properties[$prop.Name].Value
            $newVal = $prop.Value
            $oldStr = Stringify-Value $oldVal
            $newStr = Stringify-Value $newVal
            if ($oldStr -ne $newStr) {
                $changes += [PSCustomObject]@{
                    Property = $prop.Name
                    OldValue = $oldStr
                    NewValue = $newStr
                }
            }
        }
    }
    # 处理数组
    elseif ($Old -is [System.Array] -or $New -is [System.Array]) {
        $oldArr = @($Old)
        $newArr = @($New)
        if ($oldArr.Count -ne $newArr.Count) {
            $changes += [PSCustomObject]@{
                Property = "Count"
                OldValue = "$($oldArr.Count) 条"
                NewValue = "$($newArr.Count) 条"
            }
        }
        # 尝试按关键字段对比
        $keyField = Get-KeyField -Category $Category
        if ($keyField) {
            $oldKeys = $oldArr | ForEach-Object { Stringify-Value $_.$keyField }
            $newKeys = $newArr | ForEach-Object { Stringify-Value $_.$keyField }
            $added = $newKeys | Where-Object { $_ -notin $oldKeys }
            $removed = $oldKeys | Where-Object { $_ -notin $newKeys }
            foreach ($a in $added) {
                $changes += [PSCustomObject]@{ Property = "新增"; OldValue = ""; NewValue = $a }
            }
            foreach ($r in $removed) {
                $changes += [PSCustomObject]@{ Property = "移除"; OldValue = $r; NewValue = "" }
            }
        }
    }
    else {
        $oldStr = Stringify-Value $Old
        $newStr = Stringify-Value $New
        if ($oldStr -ne $newStr) {
            $changes += [PSCustomObject]@{ Property = "Value"; OldValue = $oldStr; NewValue = $newStr }
        }
    }

    return $changes
}

function Get-KeyField {
    param([string]$Category)
    switch ($Category) {
        "DNSServers"       { "InterfaceAlias" }
        "RoutingTable"     { "DestinationPrefix" }
        "AdapterConfig"    { "Name" }
        "InterfaceMetrics" { "InterfaceAlias" }
        "FirewallRules"    { "Name" }
        "RootCerts"        { "Thumbprint" }
        "EnvVars"          { "Name" }
        "StartupEntries"   { "Name" }
        "DNSServices"      { "Name" }
        "PortProxy"        { "ListenPort" }
        default            { $null }
    }
}

function Stringify-Value {
    param($Value)
    if ($null -eq $Value) { return "(空)" }
    if ($Value -is [System.Array]) { return ($Value | ForEach-Object { Stringify-Value $_ }) -join "; " }
    if ($Value -is [PSCustomObject]) { return ($Value | ConvertTo-Json -Depth 5 -Compress) }
    return [string]$Value
}

# ============================================================================
#  恢复逻辑
# ============================================================================

function Restore-Category {
    param([string]$Category, $TargetData, [switch]$DryRun)

    $catInfo = $script:Categories[$Category]
    $actionsTaken = @()

    switch ($Category) {
        "SystemProxy" {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            if ($DryRun) {
                $actionsTaken += "将设置 ProxyEnable=$($TargetData.ProxyEnable), ProxyServer=$($TargetData.ProxyServer)"
            } else {
                Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value ([int]$TargetData.ProxyEnable) -Force
                if ($TargetData.ProxyServer) {
                    Set-ItemProperty -Path $regPath -Name "ProxyServer" -Value $TargetData.ProxyServer -Force
                } else {
                    Remove-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue
                }
                if ($TargetData.ProxyOverride) {
                    Set-ItemProperty -Path $regPath -Name "ProxyOverride" -Value $TargetData.ProxyOverride -Force
                }
                # 通知系统设置已更改
                $signature = '[DllImport("wininet.dll", SetLastError=true)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
                $type = Add-Type -MemberDefinition $signature -Name "WinInet" -Namespace "PInvoke" -PassThru -ErrorAction SilentlyContinue
                $type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null  # INTERNET_OPTION_SETTINGS_CHANGED
                $type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null  # INTERNET_OPTION_REFRESH
                $actionsTaken += "已恢复代理设置: ProxyEnable=$($TargetData.ProxyEnable)"
            }
        }
        "DNSServers" {
            foreach ($dns in @($TargetData)) {
                $alias = $dns.InterfaceAlias
                $servers = $dns.ServerAddresses
                if ($DryRun) {
                    $actionsTaken += "将设置 $alias DNS=$servers"
                } else {
                    try {
                        if ($servers -and $servers -ne "(空)") {
                            $addrs = $servers -split ","
                            Set-DnsClientServerAddress -InterfaceAlias $alias -ServerAddresses $addrs -ErrorAction Stop
                        } else {
                            Set-DnsClientServerAddress -InterfaceAlias $alias -ResetServerAddresses -ErrorAction Stop
                        }
                        $actionsTaken += "已恢复 $alias DNS"
                    } catch {
                        $actionsTaken += "恢复 $alias DNS 失败: $_"
                    }
                }
            }
            if (-not $DryRun) { Clear-DnsClientCache -ErrorAction SilentlyContinue }
        }
        "EnvVars" {
            $allVarNames = @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy")
            foreach ($name in $allVarNames) {
                $target = @($TargetData) | Where-Object { $_.Name -eq $name }
                $currentUser = [Environment]::GetEnvironmentVariable($name, "User")
                $currentMachine = [Environment]::GetEnvironmentVariable($name, "Machine")

                if ($target) {
                    $targetUser = $target.UserValue
                    $targetMachine = $target.MachineValue
                } else {
                    $targetUser = $null
                    $targetMachine = $null
                }

                if ($currentUser -ne $targetUser) {
                    if ($DryRun) {
                        $actionsTaken += "$name (User): $currentUser → $targetUser"
                    } else {
                        [Environment]::SetEnvironmentVariable($name, $targetUser, "User")
                        $actionsTaken += "已恢复 $name (User)"
                    }
                }
            }
        }
        "WinHTTPProxy" {
            if ($DryRun) {
                $actionsTaken += "将重置WinHTTP代理"
            } else {
                netsh winhttp reset proxy 2>$null | Out-Null
                $actionsTaken += "已重置WinHTTP代理"
            }
        }
        "PACConfig" {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            if ($DryRun) {
                $actionsTaken += "将设置 AutoConfigURL=$($TargetData.AutoConfigURL)"
            } else {
                if ($TargetData.AutoConfigURL) {
                    Set-ItemProperty -Path $regPath -Name "AutoConfigURL" -Value $TargetData.AutoConfigURL -Force
                } else {
                    Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue
                }
                $actionsTaken += "已恢复PAC设置"
            }
        }
        default {
            if ($DryRun) {
                $actionsTaken += "该类别需要手动恢复，请参考对比结果"
            } else {
                $actionsTaken += "⚠ 该类别暂不支持自动恢复，请参考对比结果手动处理"
            }
        }
    }

    return $actionsTaken
}

# ============================================================================
#  快捷修复
# ============================================================================

function Fix-Proxy {
    param([switch]$DryRun)

    Write-C "`n正在修复代理设置..." "Cyan"

    # 先备份
    if (-not $DryRun) {
        $current = Collect-AllCategories -FilterCategories @("SystemProxy", "PACConfig", "WinHTTPProxy", "EnvVars")
        $backupFolder = Save-Snapshot -SnapshotName "pre-fix-proxy" -SnapshotData $current
        Write-Info "已备份当前状态到: $(Split-Path $backupFolder -Leaf)"
    }

    # 清除系统代理
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if ($DryRun) {
        Write-Info "[预览] 将设置 ProxyEnable=0, 清除 ProxyServer"
        Write-Info "[预览] 将清除 AutoConfigURL"
        Write-Info "[预览] 将重置 WinHTTP 代理"
        Write-Info "[预览] 将清除代理环境变量"
    } else {
        Set-ItemProperty -Path $regPath -Name "ProxyEnable" -Value 0 -Force
        Remove-ItemProperty -Path $regPath -Name "ProxyServer" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name "AutoConfigURL" -ErrorAction SilentlyContinue

        # 通知系统
        try {
            $sig = '[DllImport("wininet.dll")] public static extern bool InternetSetOption(IntPtr h, int o, IntPtr b, int l);'
            $t = Add-Type -MemberDefinition $sig -Name "WinInet2" -Namespace "PInvoke" -PassThru -ErrorAction SilentlyContinue
            $t::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
            $t::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null
        } catch {}

        netsh winhttp reset proxy 2>$null | Out-Null

        # 清除环境变量
        foreach ($v in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy")) {
            [Environment]::SetEnvironmentVariable($v, $null, "User")
        }

        Write-OK "代理设置已清除"
    }
}

function Fix-DNS {
    param([switch]$DryRun)

    Write-C "`n正在修复DNS设置..." "Cyan"

    if (-not $DryRun) {
        $current = Collect-AllCategories -FilterCategories @("DNSServers")
        $backupFolder = Save-Snapshot -SnapshotName "pre-fix-dns" -SnapshotData $current
        Write-Info "已备份当前状态到: $(Split-Path $backupFolder -Leaf)"
    }

    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }
        foreach ($a in $adapters) {
            if ($DryRun) {
                Write-Info "[预览] 将重置 $($a.Name) DNS为自动获取"
            } else {
                Set-DnsClientServerAddress -InterfaceAlias $a.Name -ResetServerAddresses -ErrorAction SilentlyContinue
            }
        }
        if (-not $DryRun) {
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            Write-OK "DNS已恢复为自动获取，缓存已刷新"
        }
    } catch {
        Write-Err "DNS修复失败: $_"
    }
}

function Test-Connectivity {
    Write-C "`n测试网络连通性..." "Cyan"

    $tests = @(
        @{ Name = "百度 (国内)"; Host = "www.baidu.com" }
        @{ Name = "GitHub (国外)"; Host = "github.com" }
    )

    foreach ($t in $tests) {
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $result = $tcp.BeginConnect($t.Host, 443, $null, $null)
            $ok = $result.AsyncWaitHandle.WaitOne(3000, $false)
            if ($ok -and $tcp.Connected) {
                Write-OK "$($t.Name) - 连通"
            } else {
                Write-Warn "$($t.Name) - 超时"
            }
            $tcp.Close()
        } catch {
            Write-Err "$($t.Name) - 失败"
        }
    }
}

# ============================================================================
#  Watch 模式
# ============================================================================

function Start-Watch {
    param([int]$PollInterval, [string[]]$FilterCategories)

    Write-C "`n实时监控模式 (每${PollInterval}秒检查，Ctrl+C退出)" "Cyan"
    Write-C "─────────────────────────────────────────────" "Gray"

    $baseline = Collect-AllCategories -FilterCategories $FilterCategories
    $iteration = 0

    try {
        while ($true) {
            Start-Sleep -Seconds $PollInterval
            $iteration++

            $current = Collect-AllCategories -FilterCategories $FilterCategories
            $diff = Compare-Snapshots -OldSnap $baseline -NewSnap $current

            if ($diff.TotalChanges -gt 0) {
                $ts = Get-Date -Format "HH:mm:ss"
                Write-C "[$ts] 检测到 $($diff.TotalChanges) 处变化：" "Yellow"
                foreach ($cat in $diff.Changes.Keys) {
                    $catName = $script:Categories[$cat].Name
                    foreach ($c in $diff.Changes[$cat]) {
                        if ($c.OldValue -and $c.NewValue) {
                            Write-C "  [$catName] $($c.Property): $($c.OldValue) → $($c.NewValue)" "Yellow"
                        } elseif ($c.NewValue) {
                            Write-C "  [$catName] + $($c.Property): $($c.NewValue)" "Green"
                        } else {
                            Write-C "  [$catName] - $($c.Property): $($c.OldValue)" "Red"
                        }
                    }
                }
                # 更新基线为当前状态
                $baseline = $current
            }
        }
    } catch {
        if ($_.Exception -is [System.Management.Automation.PipelineStoppedException]) {
            Write-C "`n监控已停止" "Gray"
        } else { throw }
    }
}

# ============================================================================
#  显示函数
# ============================================================================

function Show-HealthCheck {
    param([hashtable]$Snapshot)

    $issues = 0

    Write-C "`n=== 系统网络健康检查 ===" "Cyan"
    Write-C "  时间: $($Snapshot.Timestamp) | 管理员: $(if($Snapshot.IsAdmin){'是'}else{'否'})" "Gray"
    Write-C ""

    # 代理检查
    $proxy = $Snapshot.Data["SystemProxy"]
    if ($proxy.ProxyEnable -eq 1) {
        Write-Warn "系统代理: 已启用 → $($proxy.ProxyServer)"
        $issues++
    } else {
        Write-OK "系统代理: 未启用"
    }

    $pac = $Snapshot.Data["PACConfig"]
    if ($pac.AutoConfigURL) {
        Write-Warn "PAC自动代理: $($pac.AutoConfigURL)"
        $issues++
    } else {
        Write-OK "PAC自动代理: 未设置"
    }

    $winhttp = $Snapshot.Data["WinHTTPProxy"]
    if ($winhttp.ProxyServer) {
        Write-Warn "WinHTTP代理: $($winhttp.ProxyServer)"
        $issues++
    } else {
        Write-OK "WinHTTP代理: 直连"
    }

    # DNS检查
    $dns = @($Snapshot.Data["DNSServers"])
    $suspiciousDNS = $dns | Where-Object {
        $_.ServerAddresses -and $_.ServerAddresses -match "(198\.18\.|127\.0\.0\.|10\.10\.10\.)"
    }
    if ($suspiciousDNS) {
        foreach ($d in $suspiciousDNS) {
            Write-Warn "DNS ($($d.InterfaceAlias)): $($d.ServerAddresses) (可能是代理残留)"
            $issues++
        }
    } else {
        Write-OK "DNS服务器: 正常"
    }

    # 环境变量检查
    $envs = @($Snapshot.Data["EnvVars"])
    if ($envs.Count -gt 0) {
        foreach ($e in $envs) {
            $val = if ($e.UserValue) { $e.UserValue } else { $e.MachineValue }
            Write-Warn "环境变量 $($e.Name)=$val (可能是代理残留)"
            $issues++
        }
    } else {
        Write-OK "代理环境变量: 未设置"
    }

    # IP转发检查
    $ipstack = $Snapshot.Data["IPStackFlags"]
    if ($ipstack.IPEnableRouter -eq 1) {
        Write-Warn "IP转发: 已启用 (安全隐患，可能是TUN模式残留)"
        $issues++
    } else {
        Write-OK "IP转发: 已禁用"
    }

    # 虚拟网卡检查
    $adapters = @($Snapshot.Data["AdapterConfig"])
    $virtualAdapters = $adapters | Where-Object { $_.IsVirtual -eq $true -and $_.Status -eq "Up" }
    if ($virtualAdapters) {
        foreach ($va in $virtualAdapters) {
            Write-Warn "虚拟网卡: $($va.Name) ($($va.InterfaceDescription)) 活跃中"
            $issues++
        }
    } else {
        Write-OK "虚拟网卡: 无活跃的VPN/TUN网卡"
    }

    # 启动项检查
    $startup = @($Snapshot.Data["StartupEntries"])
    if ($startup.Count -gt 0) {
        foreach ($s in $startup) {
            Write-Warn "代理启动项: $($s.Name) = $($s.Value)"
            $issues++
        }
    } else {
        Write-OK "代理启动项: 未检测到"
    }

    # 根证书检查
    $certs = @($Snapshot.Data["RootCerts"])
    if ($certs.Count -gt 0) {
        Write-Warn "非常见根证书: $($certs.Count) 个 (请确认是否为已知软件安装)"
        foreach ($c in $certs) {
            Write-Info "  [$($c.Store)] $($c.Subject) (到期: $($c.NotAfter))"
        }
        $issues++
    } else {
        Write-OK "根证书: 正常"
    }

    # Winsock检查
    $winsock = $Snapshot.Data["WinsockCatalog"]
    if ($winsock.NonSystemCount -gt 0) {
        Write-Warn "Winsock: 发现 $($winsock.NonSystemCount) 个非系统条目"
        $issues++
    } else {
        Write-OK "Winsock目录: 正常"
    }

    # 总结
    Write-C ""
    if ($issues -eq 0) {
        Write-C "  ✓ 系统网络状态正常，未发现代理/VPN残留" "Green"
    } else {
        Write-C "  ⚠ 发现 $issues 处异常，可用 -FixAll 一键修复常见问题" "Yellow"
    }
}

function Show-CompareResult {
    param([hashtable]$DiffResult, [string]$SnapshotName, [string]$SnapshotTime, [switch]$ShowFull, [switch]$ShowBrief)

    $totalChanges = $DiffResult.TotalChanges
    $groupChanges = $DiffResult.GroupChanges
    $changes = $DiffResult.Changes

    Write-C ""
    if ($totalChanges -eq 0) {
        Write-C "✓ 当前状态与快照 ($SnapshotName) 完全一致，无变化" "Green"
        return
    }

    # 总结行
    $groupSummary = ($groupChanges.Keys | ForEach-Object { "$_ $($groupChanges[$_])处" }) -join "，"
    Write-C "检测到 $totalChanges 处变化（$groupSummary）" "Yellow"
    Write-C "对比基准: $SnapshotName ($SnapshotTime)" "Gray"

    if ($ShowBrief) { return }

    # 按组显示变化
    $currentGroup = ""
    foreach ($cat in $changes.Keys) {
        $catInfo = $script:Categories[$cat]

        # Tier过滤：非Full模式只显示Tier 1和2
        if (-not $ShowFull -and $catInfo.Tier -gt 2) { continue }

        if ($catInfo.Group -ne $currentGroup) {
            $currentGroup = $catInfo.Group
            Write-Header "$currentGroup"
        }

        Write-C "  [$($catInfo.Name)]" "White"
        foreach ($c in $changes[$cat]) {
            if ($c.Property -eq "新增") {
                Write-C "    + $($c.NewValue)" "Green"
            } elseif ($c.Property -eq "移除") {
                Write-C "    - $($c.OldValue)" "Red"
            } else {
                Write-Change -Label "    $($c.Property)" -Old $c.OldValue -New $c.NewValue
            }
        }
    }

    if (-not $ShowFull) {
        $hiddenCount = ($changes.Keys | Where-Object { $script:Categories[$_].Tier -gt 2 }).Count
        if ($hiddenCount -gt 0) {
            Write-C "`n  ($hiddenCount 个低优先级分类有变化，使用 -Full 查看全部)" "Gray"
        }
    }
}

function Show-List {
    if (-not (Test-Path $script:SnapshotDir)) {
        Write-Warn "暂无快照记录"
        return
    }

    $folders = Get-ChildItem -Path $script:SnapshotDir -Directory | Sort-Object LastWriteTime -Descending

    if ($folders.Count -eq 0) {
        Write-Warn "暂无快照记录"
        return
    }

    Write-Header "已保存的快照"
    Write-C "  存储位置: $script:SnapshotDir" "Gray"
    Write-C ""

    $i = 0
    foreach ($f in $folders) {
        $i++
        $jsonPath = Join-Path $f.FullName "snapshot.json"
        $hasBat = Test-Path (Join-Path $f.FullName "emergency-restore.bat")
        $size = "{0:N1} KB" -f (($f | Get-ChildItem -Recurse | Measure-Object -Property Length -Sum).Sum / 1KB)

        $mark = if ($hasBat) { "📋" } else { "  " }
        Write-C "  $i. $mark $($f.Name)  ($size)" "White"
    }

    Write-C ""
    Write-Info "📋 = 含紧急恢复批处理 (emergency-restore.bat)"
    Write-Info "使用 -Compare -Name `"名称关键字`" 对比指定快照"
}

function Show-Help {
    Write-C @"

网络状态快照工具 v$($script:Version) (Network Snapshot)
监控VPN/代理对系统的修改，支持快照/对比/恢复/一键修复

日常使用:
  .\ns.ps1                          健康检查（推荐首次运行）
  .\ns.ps1 -FixProxy                一键清除所有代理设置
  .\ns.ps1 -FixDNS                  一键恢复DNS为自动获取
  .\ns.ps1 -FixAll                  全部修复 + 连通性测试

快照管理:
  .\ns.ps1 -Save                    保存当前网络状态快照
  .\ns.ps1 -Save -Name "开VPN前"    保存并命名
  .\ns.ps1 -Compare                 对比当前状态与最近快照
  .\ns.ps1 -Compare -Full           显示所有分类的详细对比
  .\ns.ps1 -Compare -Brief          仅显示摘要
  .\ns.ps1 -Restore                 恢复到最近快照
  .\ns.ps1 -Restore -WhatIf         预览恢复操作（不实际执行）
  .\ns.ps1 -Restore -Only Proxy,DNS 仅恢复指定分类
  .\ns.ps1 -List                    查看所有已保存快照

高级:
  .\ns.ps1 -Watch                   实时监控网络设置变化
  .\ns.ps1 -Watch -Interval 10      每10秒检查一次
  .\ns.ps1 -Watch -Only 代理,DNS    仅监控指定分类

监控项 (25项):
  代理(6): 系统代理|二进制blob|WinHTTP|PAC|组策略代理|端口转发
  DNS(5):  DNS服务器|NRPT策略|DoH设置|DNS服务状态|多宿主名称解析
  网络(6): 路由表|网卡配置|接口度量值|网络配置文件|WFP过滤器|MTU
  系统(5): 防火墙规则|Winsock目录|hosts文件|根证书|UWP回环豁免
  环境(3): 环境变量|开机启动项|IP栈标志

存储位置: $script:SnapshotDir

"@ "White"
}

# ============================================================================
#  主流程
# ============================================================================

# 首次运行检查
$isFirstRun = -not (Test-Path $script:SnapshotDir) -or (Get-ChildItem $script:SnapshotDir -Directory -ErrorAction SilentlyContinue).Count -eq 0

# 路由分发
switch ($PSCmdlet.ParameterSetName) {

    "Help" {
        Show-Help
    }

    "Save" {
        Write-C "`n正在采集网络状态 (25项)..." "Cyan"
        $snapshot = Collect-AllCategories
        $folder = Save-Snapshot -SnapshotName $Name -SnapshotData $snapshot
        if ($snapshot.Errors.Count -gt 0) {
            Write-Warn "以下分类采集失败:"
            foreach ($e in $snapshot.Errors) { Write-Info "  $e" }
        }
        Write-OK "快照已保存: $(Split-Path $folder -Leaf)"
        Write-Info "存储位置: $folder"
        Write-Info "紧急恢复: $folder\emergency-restore.bat"
    }

    "Compare" {
        $saved = Load-Snapshot -SnapshotName $Name
        if (-not $saved) {
            if ($isFirstRun) {
                Write-Warn "暂无快照记录，将以"干净系统默认值"为基准进行健康检查"
                Write-C ""
                $current = Collect-AllCategories
                Show-HealthCheck -Snapshot $current
            } else {
                Write-Err "未找到匹配的快照$(if($Name){" (关键字: $Name)"})。使用 -List 查看所有快照"
            }
            break
        }

        Write-C "`n正在采集当前状态..." "Cyan"
        $current = Collect-AllCategories
        $diff = Compare-Snapshots -OldSnap $saved -NewSnap $current
        Show-CompareResult -DiffResult $diff -SnapshotName $saved.FolderName -SnapshotTime $saved.Timestamp -ShowFull:$Full -ShowBrief:$Brief
    }

    "Restore" {
        $saved = Load-Snapshot -SnapshotName $Name
        if (-not $saved) {
            Write-Err "未找到匹配的快照。使用 -List 查看所有快照"
            break
        }

        # 先对比
        Write-C "`n正在分析差异..." "Cyan"
        $current = Collect-AllCategories
        $diff = Compare-Snapshots -OldSnap $saved -NewSnap $current

        if ($diff.TotalChanges -eq 0) {
            Write-OK "当前状态与快照一致，无需恢复"
            break
        }

        Show-CompareResult -DiffResult $diff -SnapshotName $saved.FolderName -SnapshotTime $saved.Timestamp

        # 过滤要恢复的分类
        $categoriesToRestore = if ($Only) {
            $diff.Changes.Keys | Where-Object {
                $cat = $_
                $Only | Where-Object { $cat -match $_ -or $script:Categories[$cat].Group -match $_ -or $script:Categories[$cat].Name -match $_ }
            }
        } else {
            $diff.Changes.Keys
        }

        # 检查危险分类
        $dangerCats = $categoriesToRestore | Where-Object { $script:Categories[$_].DangerRestore }
        if ($dangerCats -and -not $Force -and -not $WhatIf) {
            Write-C ""
            Write-Warn "以下分类为高风险恢复操作，需要 -Force 参数："
            foreach ($dc in $dangerCats) {
                Write-Info "  $($script:Categories[$dc].Name)"
            }
            $categoriesToRestore = $categoriesToRestore | Where-Object { -not $script:Categories[$_].DangerRestore }
            if ($categoriesToRestore.Count -eq 0) {
                Write-Info "没有可安全恢复的分类。添加 -Force 以恢复高风险分类"
                break
            }
            Write-C ""
            Write-C "将仅恢复以下安全分类:" "Cyan"
            foreach ($sc in $categoriesToRestore) { Write-Info "  $($script:Categories[$sc].Name)" }
        }

        if ($WhatIf) {
            Write-C "`n=== 预览模式 (不实际执行) ===" "Cyan"
        } else {
            # 恢复前备份
            Write-C "`n正在备份当前状态..." "Gray"
            Save-Snapshot -SnapshotName "pre-restore" -SnapshotData $current | Out-Null
            Write-Info "已自动备份当前状态 (pre-restore)"
        }

        Write-C ""
        foreach ($cat in $categoriesToRestore) {
            $catName = $script:Categories[$cat].Name
            Write-C "  恢复 $catName..." "White" -NoNewline
            $actions = Restore-Category -Category $cat -TargetData $saved.Data[$cat] -DryRun:$WhatIf
            foreach ($a in $actions) { Write-C " $a" "Gray" }
        }

        if (-not $WhatIf) {
            Write-C ""
            Write-OK "恢复完成"
        }
    }

    "Watch" {
        Start-Watch -PollInterval $Interval -FilterCategories $Only
    }

    "List" {
        Show-List
    }

    "FixProxy" {
        Fix-Proxy -DryRun:$WhatIf
        if (-not $WhatIf) { Test-Connectivity }
    }

    "FixDNS" {
        Fix-DNS -DryRun:$WhatIf
        if (-not $WhatIf) { Test-Connectivity }
    }

    "FixAll" {
        Fix-Proxy -DryRun:$WhatIf
        Fix-DNS -DryRun:$WhatIf
        if (-not $WhatIf) {
            # 额外：刷新DNS缓存
            Write-C "`n刷新DNS缓存..." "Cyan"
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            ipconfig /flushdns 2>$null | Out-Null
            Write-OK "DNS缓存已刷新"
            Test-Connectivity
        }
    }

    # 默认：健康检查
    "HealthCheck" {
        Write-C "网络状态快照工具 v$script:Version" "Cyan"

        if ($isFirstRun) {
            Write-C ""
            Write-C "  首次运行，正在采集基线快照..." "Gray"
            $snapshot = Collect-AllCategories
            $folder = Save-Snapshot -SnapshotName "baseline" -SnapshotData $snapshot
            Write-OK "已自动保存基线快照 (baseline)"
            Write-Info "存储位置: $folder"
            Write-C ""
            Show-HealthCheck -Snapshot $snapshot
        } else {
            $snapshot = Collect-AllCategories
            Show-HealthCheck -Snapshot $snapshot
        }

        Write-C ""
        Write-C "提示:" "Gray"
        Write-C "  开VPN前: .\ns.ps1 -Save" "Gray"
        Write-C "  关VPN后: .\ns.ps1 -Compare (查看变化) 或 .\ns.ps1 -FixAll (一键修复)" "Gray"
        Write-C "  更多帮助: .\ns.ps1 -Help" "Gray"
    }
}
