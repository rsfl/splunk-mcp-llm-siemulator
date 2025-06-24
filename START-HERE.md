# 🎉 Your Raw HEC Setup is Ready!



### 🚀 Quick Start Options

**EASIEST**: Double-click `quick-start.bat`

**RECOMMENDED**: Right-click PowerShell → Run as Administrator:
```powershell
.\start-raw-hec-lab.ps1
```

### 📁 Files Created for You

✅ **deploy-raw-hec.ps1** - Main deployment script
✅ **start-raw-hec-lab.ps1** - Start your lab environment  
✅ **validate-raw-hec.ps1** - Test Raw HEC connectivity
✅ **quick-start.bat** - One-click startup (simplest)
✅ **docker-compose.yml** - Enhanced Docker Compose with Raw HEC
✅ **README.md** - Complete documentation
✅ **splunk-configs/indexes.conf** - Enhanced Splunk indexes
✅ **splunk-configs/inputs.conf** - Raw HEC endpoint configuration
✅ **splunk-configs/props.conf** - Log parsing rules for Raw HEC

### 🔄 Next Steps

1. **Start your lab**:
   ```cmd
   quick-start.bat
   ```

2. **Wait 30 seconds** for services to start

3. **Validate it's working**:
   ```powershell
   .\validate-raw-hec.ps1
   ```

4. **Access Splunk**: http://localhost:8000 (admin/Password1)

5. **Test Raw HEC**: http://localhost:8088/services/collector/health

### 🔍 Check Your Logs in Splunk

Use these searches in Splunk:

```spl
# See all your logs
index=ollama_logs OR index=mcp_logs 

# Check Raw HEC is working
index=ollama_logs sourcetype=ollama:docker | head 10

```

### 📊 What Raw HEC Does for You

✅ **Preserves Original Log Format** - Logs look exactly like they do on disk
✅ **Better Performance** - Faster than JSON endpoint  
✅ **Native Splunk Parsing** - Uses your props.conf rules
✅ **ATLAS TTP Detection** - Automatic threat hunting
✅ **Simple Configuration** - Metadata via URL parameters

### 🛠️ Manual Test (Optional)

Test Raw HEC directly:
```powershell
$headers = @{'Authorization' = 'Splunk f4e45204-7cfa-48b5-bfbe-95cf03dbcad7'; 'Content-Type' = 'text/plain'}
$uri = "http://localhost:8088/services/collector/raw/1.0?index=ollama_logs&sourcetype=test"  
Invoke-RestMethod -Uri $uri -Headers $headers -Body "Test message from PowerShell" -Method Post
```

### 🚨 If Something Goes Wrong

1. **Check Docker**: Make sure Docker Desktop is running
2. **Check .env file**: Should contain your HEC token
3. **Check logs**: `docker-compose logs splunk`
4. **Restart**: `docker-compose down && docker-compose up -d`

### 🎯 Key Differences from Standard Setup

- **splunk-format: raw** in Docker logging driver (not json)
- **Enhanced parsing rules** in props.conf for Raw data
- **Optimized indexes** for high-volume raw ingestion
- **ATLAS TTP detection** automatically configured

---

## 🚀 START HERE: Run `quick-start.bat` to begin!

Then check Splunk at http://localhost:8000 (admin/Password1)