# validate-raw-hec.ps1
# Windows validation script for Raw HEC setup Splunk MCP LLM SIEMulator

param(
    [string]$HecUrl = "http://localhost:8088",
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7"
)

Write-Host "Validating Raw HEC Setup" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Test HEC health
Write-Host "Checking HEC health..." -ForegroundColor Blue
try {
    $healthResponse = Invoke-RestMethod -Uri "$HecUrl/services/collector/health" -Headers @{'Authorization' = "Splunk $HecToken"} -Method Get
    if ($healthResponse -match "HEC is available") {
        Write-Host "HEC health check passed" -ForegroundColor Green
    } else {
        Write-Host "HEC health check failed" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "HEC health check failed: $_" -ForegroundColor Red
    exit 1
}

# Test raw endpoint
Write-Host "Testing raw endpoint..." -ForegroundColor Blue
$testData = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] Raw HEC validation test - $(Get-Date -UFormat %s)"
$uri = "$HecUrl/services/collector/raw/1.0?index=ollama_logs&sourcetype=test:validation&source=validation_script"

try {
    $response = Invoke-RestMethod -Uri $uri -Headers @{'Authorization' = "Splunk $HecToken"; 'Content-Type' = 'text/plain'} -Body $testData -Method Post
    Write-Host "Raw endpoint test passed" -ForegroundColor Green
}
catch {
    Write-Host "Raw endpoint test failed: $_" -ForegroundColor Red
    exit 1
}


Write-Host ""
Write-Host "Raw HEC validation completed!" -ForegroundColor Green
Write-Host "   Check Splunk for test events:" -ForegroundColor Yellow
Write-Host "   - index=ollama_logs source=validation_script" -ForegroundColor Yellow
