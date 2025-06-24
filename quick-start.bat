@echo off
REM Quick start for Raw HEC Lab - Windows Batch Version

echo.
echo 🚀 Quick Start - Raw HEC Lab Environment
echo ========================================

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker not found. Please install Docker Desktop.
    pause
    exit /b 1
)

REM Check if .env exists
if not exist ".env" (
    echo 📝 Creating .env file...
    echo SPLUNK_PASSWORD=Password1 > .env
    echo SPLUNK_HEC_TOKEN=f4e45204-7cfa-48b5-bfbe-95cf03dbcad7 >> .env
    echo ✅ .env file created
)

REM Stop existing services
echo 🔄 Stopping existing services...
docker-compose down --remove-orphans >nul 2>&1

REM Start services
echo 🚀 Starting services...
docker-compose up -d

if errorlevel 1 (
    echo ❌ Failed to start services
    pause
    exit /b 1
)

echo ⏳ Waiting for services to start...
timeout /t 30 /nobreak >nul

echo.
echo 🎉 Environment Started!
echo.
echo 📊 Access Points:
echo    Splunk Web:  http://localhost:8000 (admin/Password1)
echo    Ollama API:  http://localhost:11434
echo    MCP Service: http://localhost:3456
echo.
echo 🔍 Raw HEC Endpoints:
echo    Health:      http://localhost:8088/services/collector/health
echo 
echo 📝 To validate setup run: PowerShell -File validate-raw-hec.ps1
echo.
pause