##############################################
#       DaUfooo´s Windows Proxy Checker      #
##############################################

# Arrays für Daten
$DetectedProxies = @()
$ProxyExceptions = @()
$PACFiles = @()

# ============================================
# Funktion: Proxy-Erreichbarkeit testen
# ============================================
function Test-ProxyReachability($proxy) {
    if ($proxy -match "^(.*):(\d+)$") {
        $host = $matches[1]
        $port = [int]$matches[2]
    } else {
        $host = $proxy
        $port = 80
    }

    try {
        $conn = New-Object System.Net.Sockets.TcpClient
        $async = $conn.BeginConnect($host, $port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(2000)
        if ($wait -and $conn.Connected) {
            $conn.Close()
            return "Erreichbar"
        } else {
            return "Nicht erreichbar"
        }
    } catch {
        return "Nicht erreichbar"
    }
}

# ============================================
# Funktion: WinHTTP Proxy
# ============================================
function Show-WinHttpProxy {
    Write-Host "=== WinHTTP Proxy ===" -ForegroundColor Cyan
    try {
        $output = netsh winhttp show proxy
        Write-Host $output
        if ($output -match 'Proxy Server\s*: (.+)') { $DetectedProxies += $matches[1] }
        if ($output -match 'Proxy Bypass List\s*: (.+)') { $ProxyExceptions += $matches[1].Split(';') | ForEach-Object { $_.Trim() } }
        if ($output -match 'Auto Config URL\s*: (.+)') { $PACFiles += $matches[1].Trim() }
    } catch { Write-Warning "Fehler beim Abfragen von WinHTTP Proxy." }

    Write-Host "`n=== WinHTTP Advanced Proxy ===" -ForegroundColor Cyan
    try {
        $output = netsh winhttp show advancedproxy
        Write-Host $output
        if ($output -match 'Proxy Server\s*: (.+)') { $DetectedProxies += $matches[1] }
        if ($output -match 'Proxy Bypass List\s*: (.+)') { $ProxyExceptions += $matches[1].Split(';') | ForEach-Object { $_.Trim() } }
        if ($output -match 'Auto Config URL\s*: (.+)') { $PACFiles += $matches[1].Trim() }
    } catch { Write-Warning "Fehler beim Abfragen von Advanced Proxy." }
}

# ============================================
# Funktion: Registry Proxy & PAC
# ============================================
function Show-RegistryProxy {
    Write-Host "`n=== Registry Proxy Settings ===" -ForegroundColor Cyan

    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings",
        "HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings",
        "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
    )

    foreach ($path in $regPaths) {
        if (Test-Path $path) {
            Write-Host "`nRegistry Path: $path" -ForegroundColor Yellow
            $props = Get-ItemProperty -Path $path | Select-Object ProxyEnable, ProxyServer, ProxyOverride, AutoConfigURL
            Write-Host $props

            if ($props.ProxyEnable -eq 1 -and $props.ProxyServer) { $DetectedProxies += $props.ProxyServer }
            if ($props.ProxyOverride) { $ProxyExceptions += $props.ProxyOverride.Split(';') | ForEach-Object { $_.Trim() } }
            if ($props.AutoConfigURL) { $PACFiles += $props.AutoConfigURL }
        }
    }
}

# ============================================
# Funktion: Umgebungsvariablen
# ============================================
function Show-EnvironmentProxy {
    Write-Host "`n=== Environment Variables ===" -ForegroundColor Cyan
    $envVars = @("HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY")
    foreach ($var in $envVars) {
        $value = (Get-Item -Path "Env:$var" -ErrorAction SilentlyContinue).Value
        if ($value) {
            Write-Host "$var = $value"
            if ($var -ne "NO_PROXY") { $DetectedProxies += $value }
            else { $ProxyExceptions += $value.Split(',') | ForEach-Object { $_.Trim() } }
        }
    }
}

# ============================================
#               Hauptprogramm
# ============================================
Clear-Host
Write-Host "*** DaUfooo´s Windows Proxy Checker ***`n" -ForegroundColor Magenta

# ============================================
# Daten sammeln
# ============================================
Show-WinHttpProxy
Show-RegistryProxy
Show-EnvironmentProxy

# Doppelte entfernen
$DetectedProxies = $DetectedProxies | Sort-Object -Unique
$ProxyExceptions = $ProxyExceptions | Sort-Object -Unique
$PACFiles = $PACFiles | Sort-Object -Unique

# ============================================
# Erreichbarkeitstest
# ============================================
Write-Host "`n=== Proxy Erreichbarkeitstest ===" -ForegroundColor Green
if ($DetectedProxies.Count -gt 0) {
    foreach ($proxy in $DetectedProxies) {
        $status = Test-ProxyReachability $proxy
        Write-Host "$proxy => $status"
    }
} else {
    Write-Host "Keine Proxies erkannt." -ForegroundColor Yellow
}

# ============================================
# Proxy-Ausnahmen
# ============================================
Write-Host "`n=== Proxy-Ausnahmen ===" -ForegroundColor Cyan
if ($ProxyExceptions.Count -gt 0) {
    foreach ($ex in $ProxyExceptions) { Write-Host "- $ex" }
} else { Write-Host "Keine Ausnahmen erkannt." -ForegroundColor Yellow }

# ============================================
# PAC-Dateien
# ============================================
Write-Host "`n=== PAC-Dateien / AutoConfig URLs ===" -ForegroundColor Cyan
if ($PACFiles.Count -gt 0) {
    foreach ($pac in $PACFiles) { Write-Host "- $pac" }
} else { Write-Host "Keine PAC-Dateien erkannt." -ForegroundColor Yellow }

# ============================================
# Skriptende: Auf Tastendruck warten
# ============================================
Write-Host "`nDrücken Sie die Eingabetaste, um das Skript zu beenden..."
Read-Host
