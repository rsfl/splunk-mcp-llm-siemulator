# validate-raw-hec.ps1
# Windows validation script for Raw HEC setup Splunk MCP LLM SIEMulator

param(
    [string]$HecUrl = "https://localhost:8088",
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7"
)

# Ignore SSL certificate errors for self-signed certificates
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

Write-Host "Validating Raw HEC Setup" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Load .env file if token not provided
if (-not $HecToken -and (Test-Path ".env")) {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^SPLUNK_HEC_TOKEN=(.*)$") {
            $HecToken = $matches[1]
            Write-Host "Loaded HEC token from .env file" -ForegroundColor Gray
        }
    }
}

# Test HEC health
Write-Host "Checking HEC health..." -ForegroundColor Blue
try {
    $healthResponse = Invoke-RestMethod -Uri "$HecUrl/services/collector/health" -Headers @{'Authorization' = "Splunk $HecToken"} -Method Get -UseBasicParsing
    if ($healthResponse.text -eq "HEC is healthy" -or $healthResponse -match "HEC is healthy") {
        Write-Host "✅ HEC health check passed" -ForegroundColor Green
    } else {
        Write-Host "❌ HEC health response: $healthResponse" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ HEC health check failed: $_" -ForegroundColor Red
    exit 1
}

# Test raw endpoint
Write-Host "Testing raw endpoint..." -ForegroundColor Blue
$testData = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [INFO] Raw HEC validation test - $(Get-Date -UFormat %s)"
$uri = "$HecUrl/services/collector/raw?index=ollama_logs&sourcetype=test:validation&source=validation_script"

try {
    $response = Invoke-RestMethod -Uri $uri -Headers @{'Authorization' = "Splunk $HecToken"; 'Content-Type' = 'text/plain'} -Body $testData -Method Post -UseBasicParsing
    Write-Host "✅ Raw endpoint test passed" -ForegroundColor Green
}
catch {
    Write-Host "❌ Raw endpoint test failed: $_" -ForegroundColor Red
    exit 1
}


Write-Host ""
Write-Host "Raw HEC validation completed!" -ForegroundColor Green
Write-Host "   Check Splunk for test events:" -ForegroundColor Yellow
Write-Host "   - index=ollama_logs source=validation_script" -ForegroundColor Yellow
