# Create Splunk Indexes via HEC
param(
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7",
    [string]$HecUrl = "https://localhost:8088/services/collector/event"
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

Write-Host "Creating Splunk indexes by sending test events..." -ForegroundColor Green

$indexes = @(
    @{name="ollama_logs"; event="Ollama prompt and system log test - $(Get-Date)"},
    @{name="mcp_logs"; event="MCP service log test - $(Get-Date)"},
    @{name="docker_logs"; event="Docker container log test - $(Get-Date)"},
    @{name="file_logs"; event="File log test - $(Get-Date)"},
    @{name="system_logs"; event="System log test - $(Get-Date)"},
    @{name="n8n_logs"; event="n8n workflow log test - $(Get-Date)"},
    @{name="security_reports"; event="Security report test - $(Get-Date)"}
)

foreach ($idx in $indexes) {
    try {
        $payload = @{
            event = @{
                message = $idx.event
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                source = "index-creator"
            }
            index = $idx.name
            sourcetype = "test:create_index"
        } | ConvertTo-Json -Depth 2 -Compress
        
        $headers = @{
            "Authorization" = "Splunk $HecToken"
            "Content-Type" = "application/json"
        }
        
        Write-Host "Creating index: $($idx.name)..." -ForegroundColor Yellow
        $response = Invoke-WebRequest -Uri $HecUrl -Method Post -Headers $headers -Body $payload -TimeoutSec 10 -UseBasicParsing
        
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Successfully sent event to $($idx.name)" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to create $($idx.name): $($response.StatusCode)" -ForegroundColor Red
        }
        
        Start-Sleep 1
        
    } catch {
        Write-Host "❌ Error creating $($idx.name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Index creation complete!" -ForegroundColor Green
Write-Host "Wait 30 seconds, then search in Splunk:" -ForegroundColor Yellow
Write-Host "  index=* | stats count by index" -ForegroundColor White