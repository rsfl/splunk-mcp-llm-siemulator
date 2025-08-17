# Debug HEC - Send test logs and verify they appear in Splunk
param(
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7",
    [string]$SplunkUrl = "https://localhost:8089"
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

Write-Host "=== HEC Debug Test ===" -ForegroundColor Green

# 1. Test HEC Health
Write-Host "`n1. Testing HEC Health..." -ForegroundColor Yellow
try {
    $healthHeaders = @{"Authorization" = "Splunk $HecToken"}
    $health = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/health" -Headers $healthHeaders -UseBasicParsing
    Write-Host "✅ HEC Health: $($health.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ HEC Health failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Send a simple test event
Write-Host "`n2. Sending test event..." -ForegroundColor Yellow
try {
    $testEvent = @{
        event = "DEBUG TEST - $(Get-Date)"
        index = "main"
        sourcetype = "debug_test"
        source = "hec_debug_script"
    } | ConvertTo-Json -Compress
    
    $hecHeaders = @{
        "Authorization" = "Splunk $HecToken"
        "Content-Type" = "application/json"
    }
    
    $response = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/event" -Method Post -Headers $hecHeaders -Body $testEvent -UseBasicParsing
    Write-Host "✅ Event sent: $($response.Content)" -ForegroundColor Green
} catch {
    Write-Host "❌ Event send failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Check if we can query Splunk directly
Write-Host "`n3. Testing Splunk Search API..." -ForegroundColor Yellow
try {
    # Create a search job
    $searchData = @{
        search = "search index=main sourcetype=debug_test | head 10"
        output_mode = "json"
        earliest_time = "-5m"
    }
    
    $searchHeaders = @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:Password1")))"
        "Content-Type" = "application/x-www-form-urlencoded"
    }
    
    $searchBody = ($searchData.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
    
    $searchJob = Invoke-WebRequest -Uri "$SplunkUrl/services/search/jobs" -Method Post -Headers $searchHeaders -Body $searchBody -UseBasicParsing
    
    if ($searchJob.StatusCode -eq 201) {
        $jobResponse = $searchJob.Content | ConvertFrom-Json
        $sid = $jobResponse.sid
        Write-Host "✅ Search job created: $sid" -ForegroundColor Green
        
        # Wait for job to complete
        Start-Sleep 3
        
        # Get results
        $results = Invoke-WebRequest -Uri "$SplunkUrl/services/search/jobs/$sid/results" -Headers $searchHeaders -UseBasicParsing
        $resultsJson = $results.Content | ConvertFrom-Json
        
        Write-Host "Search Results:" -ForegroundColor Cyan
        if ($resultsJson.results -and $resultsJson.results.Count -gt 0) {
            $resultsJson.results | ForEach-Object {
                Write-Host "  Time: $($_._time) Event: $($_._raw)" -ForegroundColor White
            }
        } else {
            Write-Host "  No events found in last 5 minutes" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "❌ Search API failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check available indexes
Write-Host "`n4. Checking available indexes..." -ForegroundColor Yellow
try {
    $indexHeaders = @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:Password1")))"
    }
    
    $indexes = Invoke-WebRequest -Uri "$SplunkUrl/services/data/indexes?output_mode=json" -Headers $indexHeaders -UseBasicParsing
    $indexData = $indexes.Content | ConvertFrom-Json
    
    Write-Host "Available indexes:" -ForegroundColor Cyan
    $indexData.entry | ForEach-Object {
        Write-Host "  - $($_.name)" -ForegroundColor White
    }
} catch {
    Write-Host "❌ Index check failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Debug Complete ===" -ForegroundColor Green
Write-Host "If test event was sent successfully, search in Splunk Web:" -ForegroundColor Yellow
Write-Host "  index=main sourcetype=debug_test" -ForegroundColor White