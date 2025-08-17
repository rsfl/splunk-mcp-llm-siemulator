# Create Ollama and MCP specific indexes with proper test data
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

Write-Host "=== Creating Ollama and MCP Indexes ===" -ForegroundColor Green

$hecUrl = "https://localhost:8088/services/collector/event"
$headers = @{
    "Authorization" = "Splunk $HecToken"
    "Content-Type" = "application/json"
}

# 1. Create ollama_logs index with prompt/system information
Write-Host "`n1. Creating ollama_logs index..." -ForegroundColor Yellow

$ollamaEvents = @(
    @{
        event = @{
            event_type = "prompt_request"
            model = "llama3.2:latest"
            prompt = "What are common cybersecurity threats?"
            user_id = "security_analyst"
            session_id = "sess_001"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            system_info = @{
                version = "0.3.12"
                memory_usage = "2.1GB"
                gpu_enabled = $true
            }
        }
        index = "ollama_logs"
        sourcetype = "ollama:prompt"
        source = "ollama_api"
    },
    @{
        event = @{
            event_type = "prompt_response"
            model = "llama3.2:latest"
            response = "Common cybersecurity threats include malware, phishing, ransomware, and social engineering attacks..."
            response_tokens = 156
            processing_time_ms = 2340
            session_id = "sess_001"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        index = "ollama_logs"
        sourcetype = "ollama:response"
        source = "ollama_api"
    },
    @{
        event = @{
            event_type = "system_status"
            status = "healthy"
            models_loaded = @("llama3.2:latest")
            memory_usage = "2.1GB"
            active_sessions = 3
            requests_per_minute = 12
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            system_metrics = @{
                cpu_usage = "45%"
                memory_total = "16GB"
                disk_space = "120GB available"
            }
        }
        index = "ollama_logs"
        sourcetype = "ollama:system"
        source = "ollama_monitor"
    }
)

foreach ($event in $ollamaEvents) {
    try {
        $payload = $event | ConvertTo-Json -Depth 4 -Compress
        $response = Invoke-WebRequest -Uri $hecUrl -Method Post -Headers $headers -Body $payload -UseBasicParsing -TimeoutSec 10
        Write-Host "   ✅ Sent $($event.event.event_type) event" -ForegroundColor Green
        Start-Sleep 1
    } catch {
        Write-Host "   ❌ Failed to send $($event.event.event_type): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 2. Create mcp_logs index with MCP-specific data
Write-Host "`n2. Creating mcp_logs index..." -ForegroundColor Yellow

$mcpEvents = @(
    @{
        event = @{
            event_type = "mcp_connection"
            connection_status = "established"
            client_id = "mcp_client_001"
            protocol_version = "1.0"
            tools_available = @("file_reader", "web_search", "code_analyzer")
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        index = "mcp_logs"
        sourcetype = "mcp:connection"
        source = "mcp_server"
    },
    @{
        event = @{
            event_type = "tool_execution"
            tool_name = "file_reader"
            tool_params = @{
                file_path = "/var/log/ollama/ollama.log"
                lines_requested = 100
            }
            execution_time_ms = 45
            result_status = "success"
            client_id = "mcp_client_001"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        index = "mcp_logs"
        sourcetype = "mcp:tool_execution"
        source = "mcp_server"
    },
    @{
        event = @{
            event_type = "mcp_error"
            error_type = "timeout"
            error_message = "Tool execution timeout after 30s"
            tool_name = "web_search"
            client_id = "mcp_client_001"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            stack_trace = "TimeoutError: Operation timed out"
        }
        index = "mcp_logs"
        sourcetype = "mcp:error"
        source = "mcp_server"
    },
    @{
        event = @{
            event_type = "timer_activity"
            timer_id = "TIMER_20"
            action = "timeout_callback"
            timeout_value = 30000
            current_timestamp = (Get-Date).Ticks
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        index = "mcp_logs"
        sourcetype = "mcp:timer"
        source = "mcp_timers"
    }
)

foreach ($event in $mcpEvents) {
    try {
        $payload = $event | ConvertTo-Json -Depth 4 -Compress
        $response = Invoke-WebRequest -Uri $hecUrl -Method Post -Headers $headers -Body $payload -UseBasicParsing -TimeoutSec 10
        Write-Host "   ✅ Sent $($event.event.event_type) event" -ForegroundColor Green
        Start-Sleep 1
    } catch {
        Write-Host "   ❌ Failed to send $($event.event.event_type): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Index Creation Complete ===" -ForegroundColor Green
Write-Host "Wait 30 seconds, then check these indexes in Splunk:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Ollama Logs:" -ForegroundColor Cyan
Write-Host "  index=ollama_logs | stats count by sourcetype" -ForegroundColor White
Write-Host ""
Write-Host "MCP Logs:" -ForegroundColor Cyan  
Write-Host "  index=mcp_logs | stats count by sourcetype" -ForegroundColor White
Write-Host ""
Write-Host "Combined View:" -ForegroundColor Cyan
Write-Host "  index=ollama_logs OR index=mcp_logs | stats count by index, sourcetype" -ForegroundColor White