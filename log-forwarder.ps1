# Windows Log Forwarder for Splunk HEC
# Equivalent to the Linux log-forwarder.sh script
# Author: Splunk MCP LLM SIEMulator Windows Version

param(
    [string]$HecToken = $env:SPLUNK_HEC_TOKEN,
    [string]$HecUrl = "https://localhost:8088/services/collector/event",
    [int]$PollInterval = 10,
    [int]$MaxLogsPerBatch = 5,
    [switch]$Debug
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

# Set error action preference
$ErrorActionPreference = "Continue"

# Function to write debug messages
function Write-DebugMsg {
    param([string]$Message)
    if ($Debug) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [DEBUG] $Message" -ForegroundColor Cyan
    }
}

# Function to send log to Splunk HEC
function Send-ToHec {
    param(
        [string]$Message,
        [string]$Index = "docker_logs",
        [string]$SourceType = "docker:container",
        [string]$Source = "log-forwarder"
    )
    
    try {
        # Escape special characters for JSON
        $EscapedMessage = $Message -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
        
        # Create HEC payload
        $Payload = @{
            event = @{
                message = $EscapedMessage
                container_name = $Source
                log_source = "windows_log_forwarder"
            }
            index = $Index
            sourcetype = $SourceType
            source = $Source
            time = [int64]((Get-Date).ToUniversalTime() - (Get-Date "1970-01-01")).TotalSeconds
        } | ConvertTo-Json -Depth 3 -Compress
        
        # Send to Splunk HEC
        $Headers = @{
            "Authorization" = "Splunk $HecToken"
            "Content-Type" = "application/json"
        }
        
        Write-DebugMsg "Sending log to HEC: $($EscapedMessage.Substring(0, [Math]::Min(100, $EscapedMessage.Length)))..."
        
        # Use WebRequest instead of RestMethod for better error handling
        try {
            $Response = Invoke-WebRequest -Uri $HecUrl -Method Post -Headers $Headers -Body $Payload -TimeoutSec 10 -UseBasicParsing
            if ($Response.StatusCode -ne 200) {
                Write-Warning "HEC returned status code: $($Response.StatusCode)"
            }
        } catch [System.Net.WebException] {
            if ($_.Exception.Message -match "timeout") {
                Write-Warning "HEC request timed out - Splunk may be busy"
            } else {
                throw
            }
        }
        
    } catch {
        Write-Warning "Failed to send log to HEC: $($_.Exception.Message)"
        Write-DebugMsg "Failed payload: $Payload"
    }
}

# Function to get container logs since last check
function Get-ContainerLogsSince {
    param(
        [string]$ContainerName,
        [string]$Since = "1m"
    )
    
    try {
        Write-DebugMsg "Fetching logs from container: $ContainerName"
        # Docker --since can be unreliable on Windows, use --tail instead
        $LogLines = docker logs --tail 20 --timestamps $ContainerName 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $LogLines) {
            foreach ($Line in $LogLines) {
                # Convert to string and check if it's valid
                $LogText = $Line.ToString()
                if ($LogText -and $LogText.Trim() -ne "") {
                    # Send Ollama logs to ollama_logs index, others to docker_logs
                    if ($ContainerName -eq "security-range-ollama") {
                        Send-ToHec -Message $LogText -Source $ContainerName -Index "ollama_logs" -SourceType "ollama:docker"
                    } else {
                        Send-ToHec -Message $LogText -Source $ContainerName -Index "docker_logs" -SourceType "docker:$ContainerName"
                    }
                }
            }
            Write-DebugMsg "Processed $($LogLines.Count) log lines from $ContainerName"
        }
    } catch {
        Write-Warning "Error getting logs from $ContainerName : $($_.Exception.Message)"
    }
}

# Function to check if Docker is running
function Test-DockerConnection {
    try {
        docker version > $null 2>&1
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to check if container exists and is running
function Test-ContainerRunning {
    param([string]$ContainerName)
    
    try {
        $Status = docker inspect --format='{{.State.Running}}' $ContainerName 2>$null
        return $Status -eq "true"
    } catch {
        return $false
    }
}

# Main execution
Write-Host "Starting Windows Log Forwarder for Splunk HEC..." -ForegroundColor Green
Write-Host "HEC URL: $HecUrl" -ForegroundColor Yellow
Write-Host "Poll Interval: $PollInterval seconds" -ForegroundColor Yellow

# Load .env file if HecToken not provided
if (-not $HecToken -and (Test-Path ".env")) {
    Write-Host "Loading HEC token from .env file..." -ForegroundColor Yellow
    Get-Content ".env" | ForEach-Object {
        if ($_ -match "^SPLUNK_HEC_TOKEN=(.*)$") {
            $HecToken = $matches[1]
            Write-DebugMsg "Loaded HEC token from .env file"
        }
    }
}

# Validate required parameters
if (-not $HecToken) {
    Write-Error "SPLUNK_HEC_TOKEN environment variable or .env file is required"
    exit 1
}

# Check Docker connection
if (-not (Test-DockerConnection)) {
    Write-Error "Docker is not running or not accessible"
    exit 1
}

# Test HEC connection
Write-Host "Testing Splunk HEC connection..." -ForegroundColor Yellow
try {
    $TestHeaders = @{"Authorization" = "Splunk $HecToken"}
    $HealthCheck = Invoke-WebRequest -Uri "https://localhost:8088/services/collector/health" -Headers $TestHeaders -TimeoutSec 10 -UseBasicParsing
    if ($HealthCheck.StatusCode -eq 200) {
        Write-Host "✅ HEC connection successful" -ForegroundColor Green
    } else {
        Write-Warning "HEC health check returned: $($HealthCheck.StatusCode)"
    }
} catch {
    Write-Warning "HEC connection test failed: $($_.Exception.Message)"
    Write-Host "Will attempt to continue, but logs may not reach Splunk..." -ForegroundColor Yellow
}

# Define containers to monitor and track last log for deduplication
$ContainersToMonitor = @(
    "security-range-ollama",
    "security-range-ollama-mcp"
)

# Track last log line to prevent duplicates
$LastLogLines = @{}

# Send startup event
Send-ToHec -Message "Windows Log Forwarder started - monitoring containers: $($ContainersToMonitor -join ', ')" -Source "log-forwarder" -Index "system_logs" -SourceType "log_forwarder:startup"

Write-Host "Log forwarder started. Press Ctrl+C to stop." -ForegroundColor Green

# Main monitoring loop
try {
    while ($true) {
        foreach ($Container in $ContainersToMonitor) {
            if (Test-ContainerRunning -ContainerName $Container) {
                Get-ContainerLogsSince -ContainerName $Container -Since "${PollInterval}s"
            } else {
                Write-DebugMsg "Container $Container is not running, skipping..."
            }
        }
        
        # Also check for local log files (like the Linux version)
        $LogsDir = ".\logs"
        if (Test-Path $LogsDir) {
            $LogFiles = Get-ChildItem -Path $LogsDir -Filter "*.log" -File
            foreach ($LogFile in $LogFiles) {
                try {
                    # Get new content since last check (simplified approach)
                    $Content = Get-Content -Path $LogFile.FullName -Tail 10 -ErrorAction SilentlyContinue
                    foreach ($Line in $Content) {
                        # Convert to string and check if it's valid
                        $LogText = $Line.ToString()
                        if ($LogText -and $LogText.Trim() -ne "") {
                            # Send MCP file logs to mcp_logs, others to file_logs
                            if ($LogFile.Name -eq "mcp.log") {
                                Send-ToHec -Message $LogText -Source $LogFile.Name -Index "mcp_logs" -SourceType "mcp:file"
                            } else {
                                Send-ToHec -Message $LogText -Source $LogFile.Name -Index "file_logs" -SourceType "file:log"
                            }
                        }
                    }
                } catch {
                    Write-DebugMsg "Error reading log file $($LogFile.Name): $($_.Exception.Message)"
                }
            }
        }
        
        Start-Sleep -Seconds $PollInterval
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    Write-Host "`nLog forwarder stopped by user." -ForegroundColor Yellow
} catch {
    Write-Error "Unexpected error in main loop: $($_.Exception.Message)"
} finally {
    # Send shutdown event
    Send-ToHec -Message "Windows Log Forwarder stopped" -Source "log-forwarder" -Index "system_logs" -SourceType "log_forwarder:shutdown"
    Write-Host "Log forwarder shutdown complete." -ForegroundColor Green
}