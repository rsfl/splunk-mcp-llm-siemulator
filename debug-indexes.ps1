# Debug - Check what's actually in Splunk
param(
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7"
)

# SSL bypass
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
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

Write-Host "=== Debugging Index Status ===" -ForegroundColor Green

# 1. Test HEC health
Write-Host "`n1. Testing HEC health..." -ForegroundColor Yellow
try {
    $healthHeaders = @{"Authorization" = "Splunk $HecToken"}
    $health = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/health" -Headers $healthHeaders -UseBasicParsing
    Write-Host "✅ HEC Status: $($health.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ HEC failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Send a test event to main index (we know this works)
Write-Host "`n2. Sending test event to main index..." -ForegroundColor Yellow
try {
    $testEvent = @{
        event = "DEBUG TEST MAIN - $(Get-Date)"
        index = "main"
        sourcetype = "debug_test"
    } | ConvertTo-Json -Compress
    
    $hecHeaders = @{
        "Authorization" = "Splunk $HecToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/event" -Method Post -Headers $hecHeaders -Body $testEvent -UseBasicParsing
    Write-Host "✅ Main index test: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ Main index test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Try sending to ollama_logs
Write-Host "`n3. Sending test event to ollama_logs..." -ForegroundColor Yellow
try {
    $ollamaEvent = @{
        event = "DEBUG TEST OLLAMA_LOGS - $(Get-Date)"
        index = "ollama_logs"
        sourcetype = "debug_test"
    } | ConvertTo-Json -Compress
    
    $response = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/event" -Method Post -Headers $hecHeaders -Body $ollamaEvent -UseBasicParsing
    Write-Host "✅ ollama_logs test: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ ollama_logs test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Try sending to mcp_logs
Write-Host "`n4. Sending test event to mcp_logs..." -ForegroundColor Yellow
try {
    $mcpEvent = @{
        event = "DEBUG TEST MCP_LOGS - $(Get-Date)"
        index = "mcp_logs"
        sourcetype = "debug_test"
    } | ConvertTo-Json -Compress
    
    $response = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/event" -Method Post -Headers $hecHeaders -Body $mcpEvent -UseBasicParsing
    Write-Host "✅ mcp_logs test: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ mcp_logs test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Check what containers are actually running
Write-Host "`n5. Checking container status..." -ForegroundColor Yellow
try {
    $containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Write-Host "Container Status:" -ForegroundColor Cyan
    $containers | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} catch {
    Write-Host "❌ Docker check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Check for recent container logs
Write-Host "`n6. Checking recent container logs..." -ForegroundColor Yellow
$checkContainers = @("security-range-ollama", "security-range-ollama-mcp")

foreach ($container in $checkContainers) {
    try {
        Write-Host "   Checking $container..." -ForegroundColor Cyan
        $logs = docker logs --since 2m $container 2>&1
        if ($logs -and $logs.Count -gt 0) {
            Write-Host "     ✅ $container has $($logs.Count) recent log lines" -ForegroundColor Green
            Write-Host "     Sample: $($logs[0])" -ForegroundColor Gray
        } else {
            Write-Host "     ⚠️  $container has no recent logs" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "     ❌ $container check failed" -ForegroundColor Red
    }
}

Write-Host "`n=== Debug Complete ===" -ForegroundColor Green
Write-Host "Check Splunk Web (http://localhost:8000) for these test events:" -ForegroundColor Yellow
Write-Host "  index=main OR index=ollama_logs OR index=mcp_logs sourcetype=debug_test" -ForegroundColor White
Write-Host "`nIf you see events in main but not in ollama_logs/mcp_logs, the indexes may not exist yet." -ForegroundColor Yellow