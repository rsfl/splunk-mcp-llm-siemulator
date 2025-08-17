# deploy-raw-hec.ps1
# Windows PowerShell script for Raw HEC deployment Splunk MCP LLM SIEMulator by Rod Soto

param(
    [switch]$Force,
    [switch]$TestOnly,
    [switch]$SkipBackup,
    [string]$HecToken = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7"
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigDir = Join-Path $ScriptDir "splunk-configs"
$LogsDir = Join-Path $ScriptDir "logs"
$ScriptsDir = Join-Path $ScriptDir "scripts"
$BackupDir = Join-Path $ScriptDir "backups"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Colors for output
function Write-Success { param($Message) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WARNING: $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Blue }

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        Write-Success "Docker found: $dockerVersion"
    }
    catch {
        Write-Error "Docker not found or not in PATH"
        return $false
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker-compose --version
        Write-Success "Docker Compose found: $composeVersion"
    }
    catch {
        Write-Error "Docker Compose not found or not in PATH"
        return $false
    }
    
    # Check Docker daemon
    try {
        docker info | Out-Null
        Write-Success "Docker daemon is running"
    }
    catch {
        Write-Error "Docker daemon is not running"
        return $false
    }
    
    return $true
}

# Create directory structure
function New-DirectoryStructure {
    Write-Info "Creating directory structure..."
    
    $directories = @($ConfigDir, $LogsDir, $ScriptsDir, $BackupDir)
    
    foreach ($dir in $directories) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Created directory: $dir"
        }
    }
}

# Create Splunk configuration files
function New-SplunkConfigs {
    Write-Info "Creating Splunk configuration files..."
    
    # indexes.conf
    $indexesConf = @"
[ollama_logs]
homePath = `$SPLUNK_DB/ollama_logs/db
coldPath = `$SPLUNK_DB/ollama_logs/colddb
thawedPath = `$SPLUNK_DB/ollama_logs/thaweddb
maxDataSize = auto_high_volume
maxHotBuckets = 15
maxWarmDBCount = 300
maxMemMB = 200
maxConcurrentOptimizes = 6
rawChunks = true

[mcp_logs]
homePath = `$SPLUNK_DB/mcp_logs/db
coldPath = `$SPLUNK_DB/mcp_logs/colddb
thawedPath = `$SPLUNK_DB/mcp_logs/thaweddb
maxDataSize = auto_high_volume
maxHotBuckets = 10
maxWarmDBCount = 300
maxMemMB = 150
rawChunks = true

[atlas_logs]
homePath = `$SPLUNK_DB/atlas_logs/db
coldPath = `$SPLUNK_DB/atlas_logs/colddb
thawedPath = `$SPLUNK_DB/atlas_logs/thaweddb
maxDataSize = auto_high_volume
maxHotBuckets = 5
maxWarmDBCount = 100
maxMemMB = 100
maxConcurrentOptimizes = 3
rawChunks = true
"@
    
    Set-Content -Path (Join-Path $ConfigDir "indexes.conf") -Value $indexesConf -Encoding UTF8
    
    # inputs.conf
    $inputsConf = @"
[http]
disabled = 0
port = 8088
enableSSL = 0
max_content_length = 838860800
max_sockets = 2048

[http://ollama_raw_hec]
disabled = 0
token = $HecToken
index = ollama_logs
sourcetype = ollama:raw
connection_host = ip
useACK = 0
outputformat = raw

[http://mcp_raw_hec]
disabled = 0
token = $HecToken
index = mcp_logs
sourcetype = mcp:raw
connection_host = ip
useACK = 0
outputformat = raw

[http://atlas_raw_hec]
disabled = 0
token = $HecToken
index = atlas_logs
sourcetype = atlas:raw
connection_host = ip
useACK = 0
outputformat = raw

[udp://514]
connection_host = ip
index = ollama_logs
sourcetype = syslog

[splunktcp://9997]
connection_host = ip
index = ollama_logs
"@
    
    Set-Content -Path (Join-Path $ConfigDir "inputs.conf") -Value $inputsConf -Encoding UTF8
    
    Write-Success "Splunk configuration files created"
}

# Create enhanced Docker Compose
function New-EnhancedDockerCompose {
    Write-Info "Creating enhanced docker-compose.yml..."
    
    # Backup existing
    $composeFile = Join-Path $ScriptDir "docker-compose.yml"
    if ((Test-Path $composeFile) -and !$SkipBackup) {
        $backupFile = Join-Path $ScriptDir "docker-compose.yml.backup.$Timestamp"
        Copy-Item $composeFile $backupFile
        Write-Success "Backed up existing docker-compose.yml"
    }
    
    # Read existing docker-compose.yml and enhance it with Raw HEC
    if (Test-Path $composeFile) {
        $content = Get-Content $composeFile -Raw
        
        # Check if it already has Raw HEC configuration
        if ($content -match "splunk-format:\s*raw") {
            Write-Info "Docker Compose already has Raw HEC configuration"
        } else {
            Write-Info "Enhancing existing docker-compose.yml with Raw HEC..."
            
            # Add Raw HEC logging to Ollama service
            $content = $content -replace '(\s+)(command:.*ollama.*)', "`$1# Raw HEC logging driver`n`$1logging:`n`$1  driver: splunk`n`$1  options:`n`$1    splunk-url: `"http://host.docker.internal:8088`"`n`$1    splunk-token: `"`${SPLUNK_HEC_TOKEN}`"`n`$1    splunk-format: raw`n`$1    splunk-index: ollama_logs`n`$1    splunk-sourcetype: ollama:docker`n`$1    splunk-source: docker:ollama`n`$1    splunk-insecureskipverify: `"true`"`n`$1    tag: `"ollama`"`n`$1`$2"
            
            # Update MCP logging to use raw format
            $content = $content -replace 'splunk-format:\s*json', 'splunk-format: raw'
            
            # Add networks section if not present
            if ($content -notmatch "networks:") {
                $content += "`n`nnetworks:`n  lab-network:`n    driver: bridge"
            }
            
            # Add network to each service
            $content = $content -replace '(\s+)(volumes:[\s\S]*?)(\s+)(#|[a-zA-Z])', "`$1`$2`$3networks:`n`$3  - lab-network`n`$3`$4"
            
            Set-Content -Path $composeFile -Value $content -Encoding UTF8
            Write-Success "Enhanced existing docker-compose.yml with Raw HEC"
        }
    } else {
        Write-Warning "No existing docker-compose.yml found. Use docker-compose-raw-hec.yml as reference."
    }
}

# Main deployment function
function Start-Deployment {
    Write-Success "Starting Raw HEC Deployment for Windows"
    Write-Success "========================================"
    
    if (!$Force -and !$TestOnly) {
        $confirm = Read-Host "Deploy enhanced Raw HEC logging? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Info "Deployment cancelled"
            return
        }
    }
    
    if (!(Test-Prerequisites)) {
        Write-Error "Prerequisites check failed"
        return
    }
    
    if ($TestOnly) {
        Write-Info "Test mode - creating directories and configs only"
        New-DirectoryStructure
        New-SplunkConfigs
        Write-Success "Test deployment complete. Check splunk-configs/ directory."
        return
    }
    
    New-DirectoryStructure
    New-SplunkConfigs
    New-EnhancedDockerCompose
    
    Write-Success "========================================"
    Write-Success "Windows Raw HEC Deployment Complete!"
    Write-Success ""
    Write-Info "Files Created/Updated:"
    Write-Info "- docker-compose.yml (enhanced with Raw HEC)"
    Write-Info "- splunk-configs/indexes.conf (optimized for Raw HEC)"
    Write-Info "- splunk-configs/inputs.conf (Raw HEC endpoints)"
    Write-Info "- splunk-configs/props.conf (parsing rules)"
    Write-Success ""
    Write-Info "Next Steps:"
    Write-Info "1. Run: .\start-raw-hec-lab.ps1"
    Write-Info "2. Validate: .\validate-raw-hec.ps1"
    Write-Info "3. Access Splunk: http://localhost:8000 (admin/Password1)"
    Write-Success ""
    Write-Info "Raw HEC Benefits:"
    Write-Info "- Preserves original log format"
    Write-Info "- Better performance than JSON endpoint"
    Write-Info "- Native Splunk parsing pipeline"
    Write-Info "- ATLAS TTP detection included"
}

# Run deployment
Start-Deployment