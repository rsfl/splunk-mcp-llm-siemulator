# start-raw-hec-lab.ps1
# Start Splunk Raw HEC MCP LLM SIEMulator on Windows by Rod Soto

param([switch]$SkipValidation)

Write-Host "Starting Raw HEC Lab Environment" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Check environment file
if (!(Test-Path ".env")) {
    Write-Host ".env file not found" -ForegroundColor Red
    Write-Host "Creating default .env file..." -ForegroundColor Yellow
    
    $envContent = @"
SPLUNK_PASSWORD=Password1
SPLUNK_HEC_TOKEN=f4e45204-7cfa-48b5-bfbe-95cf03dbcad7
"@
    Set-Content -Path ".env" -Value $envContent -Encoding UTF8
    Write-Host "Default .env file created" -ForegroundColor Green
}

# Stop existing services
Write-Host "Stopping existing services..." -ForegroundColor Blue
docker-compose down --remove-orphans 2>$null

# Start services
Write-Host "Starting services..." -ForegroundColor Blue
docker-compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start services" -ForegroundColor Red
    exit 1
}

Write-Host "Waiting for services to start..." -ForegroundColor Blue
Start-Sleep 30

# Validate setup
if (!$SkipValidation) {
    Write-Host "Validating setup..." -ForegroundColor Blue
    if (Test-Path "./validate-raw-hec.ps1") {
        & "./validate-raw-hec.ps1"
    } else {
        Write-Host "Validation script not found, manual validation required" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Raw HEC Lab Environment Started!" -ForegroundColor Green
Write-Host ""
Write-Host "Access Points:" -ForegroundColor Cyan
Write-Host "   Splunk Web:  http://localhost:8000 (admin/Password1)" -ForegroundColor White
Write-Host "   Ollama API:  http://localhost:11434" -ForegroundColor White
Write-Host "   MCP Service: http://localhost:3456" -ForegroundColor White
Write-Host "   Promptfoo:   http://localhost:3000" -ForegroundColor White
Write-Host "   OpenWebUI:   http://localhost:3001" -ForegroundColor White
Write-Host ""
Write-Host "Raw HEC Endpoints:" -ForegroundColor Cyan
Write-Host "   Health:      http://localhost:8088/services/collector/health" -ForegroundColor White
Write-Host "   Raw Event:   http://localhost:8088/services/collector/raw/1.0" -ForegroundColor White
Write-Host ""
Write-Host "Monitoring:" -ForegroundColor Cyan
Write-Host "   docker-compose logs -f ollama" -ForegroundColor White
Write-Host "   PowerShell ./scripts/raw-hec-shipper.ps1" -ForegroundColor White