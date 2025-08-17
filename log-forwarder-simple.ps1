# Simple Windows Log Forwarder - Rate Limited Version
param(
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7",
    [string]$HecUrl = "https://localhost:8088/services/collector/event"
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

# Load .env file if token not provided
if (-not $HecToken -and (Test-Path ".env")) {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^SPLUNK_HEC_TOKEN=(.*)$") {
            $HecToken = $matches[1]
        }
    }
}

Write-Host "Simple Log Forwarder - Testing HEC Connection" -ForegroundColor Green
Write-Host "Using HEC URL: $HecUrl" -ForegroundColor Yellow

# Test a single log entry
function Send-TestLog {
    param([string]$Message)
    
    try {
        $Payload = @{
            event = @{
                message = $Message
                source = "log-forwarder-test"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            index = "test_logs"
            sourcetype = "test:log"
        } | ConvertTo-Json -Depth 2 -Compress
        
        $Headers = @{
            "Authorization" = "Splunk $HecToken"
            "Content-Type" = "application/json"
        }
        
        Write-Host "Sending test message..." -ForegroundColor Cyan
        $Response = Invoke-WebRequest -Uri $HecUrl -Method Post -Headers $Headers -Body $Payload -TimeoutSec 10 -UseBasicParsing
        
        if ($Response.StatusCode -eq 200) {
            Write-Host "✅ SUCCESS: Log sent to Splunk HEC" -ForegroundColor Green
            Write-Host "Response: $($Response.Content)" -ForegroundColor Gray
        } else {
            Write-Host "❌ FAILED: Status $($Response.StatusCode)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Send a few test messages
Send-TestLog "Test message 1 - Log forwarder startup"
Start-Sleep 2
Send-TestLog "Test message 2 - HEC connectivity test"
Start-Sleep 2
Send-TestLog "Test message 3 - Windows log forwarder working"

Write-Host ""
Write-Host "Test complete. Check Splunk for logs in index=test_logs" -ForegroundColor Yellow
Write-Host "Splunk Web: http://localhost:8000" -ForegroundColor White
Write-Host "Search: index=test_logs" -ForegroundColor White