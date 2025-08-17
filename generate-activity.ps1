# Generate Activity Script - Create logs from Ollama, n8n, and MCP
Write-Host "=== Generating Activity to Create Logs ===" -ForegroundColor Green

# 1. OLLAMA - Generate API activity
Write-Host "`n1. Testing Ollama API (generates logs)..." -ForegroundColor Yellow
try {
    # Test basic Ollama connectivity
    Write-Host "   - Checking Ollama tags..." -ForegroundColor Cyan
    $tags = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 10
    Write-Host "   ✅ Ollama API responding - $($tags.models.Count) models available" -ForegroundColor Green
    
    # Check if llama3.2:latest model exists
    $hasLlama = $tags.models | Where-Object { $_.name -like "*llama3.2*" }
    if (-not $hasLlama) {
        Write-Host "   - Pulling llama3.2:latest model (this will generate lots of logs)..." -ForegroundColor Cyan
        $pullData = @{ name = "llama3.2:latest" } | ConvertTo-Json
        Invoke-RestMethod -Uri "http://localhost:11434/api/pull" -Method Post -Body $pullData -ContentType "application/json" -TimeoutSec 30
    }
    
    # Generate some chat requests (creates logs)
    Write-Host "   - Sending test prompts to generate logs..." -ForegroundColor Cyan
    $prompts = @(
        "What is cybersecurity?",
        "Explain network security monitoring",
        "What are common attack vectors?"
    )
    
    foreach ($prompt in $prompts) {
        try {
            $chatData = @{
                model = "llama3.2:latest"
                prompt = $prompt
                stream = $false
            } | ConvertTo-Json
            
            Write-Host "     Prompt: $prompt" -ForegroundColor Gray
            $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $chatData -ContentType "application/json" -TimeoutSec 30
            Write-Host "     ✅ Response received ($(($response.response).Length) chars)" -ForegroundColor Green
            Start-Sleep 2
        } catch {
            Write-Host "     ❌ Prompt failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "   ❌ Ollama not responding: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. N8N - Trigger workflows
Write-Host "`n2. Testing n8n workflows (generates logs)..." -ForegroundColor Yellow
try {
    # Test n8n connectivity
    Write-Host "   - Checking n8n health..." -ForegroundColor Cyan
    $n8nHealth = Invoke-WebRequest -Uri "http://localhost:5678/healthz" -UseBasicParsing -TimeoutSec 10
    Write-Host "   ✅ n8n responding (status: $($n8nHealth.StatusCode))" -ForegroundColor Green
    
    # Test webhook endpoints
    Write-Host "   - Triggering test webhooks..." -ForegroundColor Cyan
    $webhookTests = @(
        @{url = "http://localhost:5678/webhook/test"; data = @{message="Test webhook 1"; type="security_alert"}},
        @{url = "http://localhost:5678/webhook/splunk-webhook"; data = @{alert_name="Test Alert"; severity="medium"; search_terms="test"}},
        @{url = "http://localhost:5678/webhook/security-test"; data = @{event="security_test"; timestamp=(Get-Date)}}
    )
    
    foreach ($test in $webhookTests) {
        try {
            $body = $test.data | ConvertTo-Json
            Write-Host "     Testing: $($test.url)" -ForegroundColor Gray
            $response = Invoke-RestMethod -Uri $test.url -Method Post -Body $body -ContentType "application/json" -TimeoutSec 15
            Write-Host "     ✅ Webhook triggered successfully" -ForegroundColor Green
        } catch {
            Write-Host "     ❌ Webhook failed: $($_.Exception.Message)" -ForegroundColor Red
        }
        Start-Sleep 2
    }
    
} catch {
    Write-Host "   ❌ n8n not responding: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. MCP - Generate activity
Write-Host "`n3. Testing MCP service (generates logs)..." -ForegroundColor Yellow
try {
    # Test MCP connectivity
    Write-Host "   - Checking MCP health..." -ForegroundColor Cyan
    $mcpHealth = Invoke-WebRequest -Uri "http://localhost:3456" -UseBasicParsing -TimeoutSec 10
    Write-Host "   ✅ MCP responding (status: $($mcpHealth.StatusCode))" -ForegroundColor Green
    
    # Try to trigger MCP operations (this varies by MCP implementation)
    Write-Host "   - Attempting MCP operations..." -ForegroundColor Cyan
    $mcpRequests = @(
        @{method="GET"; endpoint="/health"},
        @{method="GET"; endpoint="/status"},
        @{method="POST"; endpoint="/tools"; data=@{tool="test"}}
    )
    
    foreach ($req in $mcpRequests) {
        try {
            $url = "http://localhost:3456$($req.endpoint)"
            Write-Host "     Testing: $($req.method) $url" -ForegroundColor Gray
            
            if ($req.method -eq "GET") {
                $response = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing -TimeoutSec 10
            } else {
                $body = $req.data | ConvertTo-Json
                $response = Invoke-WebRequest -Uri $url -Method Post -Body $body -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
            }
            Write-Host "     ✅ MCP request successful (status: $($response.StatusCode))" -ForegroundColor Green
        } catch {
            Write-Host "     ⚠️  MCP endpoint unavailable: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Start-Sleep 1
    }
    
} catch {
    Write-Host "   ❌ MCP not responding: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check container logs to verify activity
Write-Host "`n4. Checking if containers are generating logs..." -ForegroundColor Yellow
$containers = @("security-range-ollama", "security-range-ollama-mcp", "security-range-n8n")

foreach ($container in $containers) {
    try {
        Write-Host "   - Checking $container logs..." -ForegroundColor Cyan
        $logs = docker logs --since 2m $container 2>&1
        if ($logs) {
            $logCount = ($logs | Measure-Object).Count
            Write-Host "     ✅ ${container}: $logCount new log lines" -ForegroundColor Green
        } else {
            Write-Host "     ⚠️  ${container}: No recent logs" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "     ❌ ${container}: Error checking logs" -ForegroundColor Red
    }
}

Write-Host "`n=== Activity Generation Complete ===" -ForegroundColor Green
Write-Host "Now run the log forwarder to capture these activities:" -ForegroundColor Yellow
Write-Host "  .\log-forwarder.ps1 -Debug" -ForegroundColor White
Write-Host "`nThen check Splunk for new logs in:" -ForegroundColor Yellow
Write-Host "  index=docker_logs OR index=n8n_logs OR index=mcp_logs" -ForegroundColor White