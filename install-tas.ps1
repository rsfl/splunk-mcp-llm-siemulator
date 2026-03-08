# install-tas.ps1
# Installs TA-ollama and TA-mcp into the running Splunk container,
# creates the ollama and mcp indexes via REST API, then restarts Splunk.
# Run AFTER docker-compose up -d and Splunk has finished initialising.

param(
    [string]$SplunkHost = "localhost",
    [string]$SplunkMgmtPort = "8089",
    [string]$SplunkUser = "admin",
    [string]$SplunkPassword = "Password1",
    [string]$SplunkContainer = "security-range-splunk"
)

# SSL bypass for self-signed cert
add-type @"
    using System.Net;
    using System.Security.Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$baseUrl = "https://${SplunkHost}:${SplunkMgmtPort}"
$cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${SplunkUser}:${SplunkPassword}"))
$headers = @{ Authorization = "Basic $cred"; "Content-Type" = "application/x-www-form-urlencoded" }

function Invoke-SplunkRest {
    param([string]$Path, [string]$Method = "GET", [hashtable]$Body = @{})
    $uri = "$baseUrl$Path"
    try {
        if ($Method -eq "GET") {
            return Invoke-RestMethod -Uri "$uri`?output_mode=json" -Method GET -Headers $headers
        }
        $form = ($Body.GetEnumerator() | ForEach-Object { "$($_.Key)=$([Uri]::EscapeDataString($_.Value))" }) -join "&"
        return Invoke-RestMethod -Uri "$uri`?output_mode=json" -Method POST -Headers $headers -Body $form
    } catch {
        Write-Host "  [WARN] $Method $Path -> $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

Write-Host "=== TA Installation for Splunk MCP LLM SIEMulator ===" -ForegroundColor Cyan
Write-Host ""

# 1. Wait for Splunk to be ready
Write-Host "1. Waiting for Splunk REST API..." -ForegroundColor Blue
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    $r = Invoke-SplunkRest "/services/server/info"
    if ($r) { $ready = $true; break }
    Start-Sleep 5
}
if (-not $ready) {
    Write-Host "   ERROR: Splunk not reachable at ${baseUrl}" -ForegroundColor Red
    exit 1
}
Write-Host "   Splunk is ready." -ForegroundColor Green

# 2. Verify TAs are mounted
Write-Host ""
Write-Host "2. Verifying TA mounts in container..." -ForegroundColor Blue
$taOllama = docker exec $SplunkContainer test -d /opt/splunk/etc/apps/TA-ollama-releasev1 2>&1
$taMcp    = docker exec $SplunkContainer test -d /opt/splunk/etc/apps/TA-mcp-jsonrpc 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   TA-ollama-releasev1: mounted" -ForegroundColor Green
} else {
    Write-Host "   TA-ollama-releasev1: NOT FOUND - check docker-compose.yml volume mounts" -ForegroundColor Red
}
docker exec $SplunkContainer test -d /opt/splunk/etc/apps/TA-mcp-jsonrpc 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "   TA-mcp-jsonrpc:      mounted" -ForegroundColor Green
} else {
    Write-Host "   TA-mcp-jsonrpc:      NOT FOUND - check docker-compose.yml volume mounts" -ForegroundColor Red
}

# 3. Create indexes via REST API
Write-Host ""
Write-Host "3. Creating indexes via REST API..." -ForegroundColor Blue

$indexes = @(
    @{ name = "ollama";     maxHotBuckets = "15"; maxMemMB = "200" },
    @{ name = "mcp";        maxHotBuckets = "10"; maxMemMB = "150" }
)

foreach ($idx in $indexes) {
    $existing = Invoke-SplunkRest "/services/data/indexes/$($idx.name)"
    if ($existing) {
        Write-Host "   index=$($idx.name): already exists" -ForegroundColor Yellow
    } else {
        $r = Invoke-SplunkRest "/services/data/indexes" -Method POST -Body @{
            name          = $idx.name
            maxHotBuckets = $idx.maxHotBuckets
            maxMemMB      = $idx.maxMemMB
        }
        if ($r) {
            Write-Host "   index=$($idx.name): created" -ForegroundColor Green
        } else {
            Write-Host "   index=$($idx.name): creation failed" -ForegroundColor Red
        }
    }
}

# 4. Restart Splunk to load TAs
Write-Host ""
Write-Host "4. Restarting Splunk to load TAs..." -ForegroundColor Blue
$r = Invoke-SplunkRest "/services/server/control/restart" -Method POST
if ($r) {
    Write-Host "   Restart initiated. Waiting 30s for Splunk to come back up..." -ForegroundColor Green
    Start-Sleep 30
} else {
    Write-Host "   Restart request failed - you may need to restart Splunk manually." -ForegroundColor Yellow
}

# 5. Verify TAs are loaded
Write-Host ""
Write-Host "5. Verifying TAs loaded..." -ForegroundColor Blue
$apps = Invoke-SplunkRest "/services/apps/local"
if ($apps) {
    $appNames = $apps.entry | ForEach-Object { $_.name }
    if ("TA-ollama-releasev1" -in $appNames) {
        Write-Host "   TA-ollama-releasev1: loaded" -ForegroundColor Green
    } else {
        Write-Host "   TA-ollama-releasev1: not found in Splunk apps (check mount and restart)" -ForegroundColor Yellow
    }
    if ("TA-mcp-jsonrpc" -in $appNames) {
        Write-Host "   TA-mcp-jsonrpc: loaded" -ForegroundColor Green
    } else {
        Write-Host "   TA-mcp-jsonrpc: not found in Splunk apps (check mount and restart)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== TA installation complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Indexes created:" -ForegroundColor White
Write-Host "  index=ollama  <- TA-ollama monitors ./logs/ollama.log (sourcetype=ollama:server)" -ForegroundColor White
Write-Host "  index=mcp     <- TA-mcp monitors ./logs/mcp.log (sourcetype=mcp:jsonrpc)" -ForegroundColor White
Write-Host ""
Write-Host "Splunk search to verify ingestion:" -ForegroundColor Yellow
Write-Host "  index=ollama OR index=mcp | stats count by index, sourcetype" -ForegroundColor White
