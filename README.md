# SPLUNK MCP / LLM SIEMulator by Rod Soto rodsoto.net

# Docker based, developed under Windows 11 Host, Docker 4.42.0, Python 3.13.1

# Includes
# - Ollama 
# - Ollama MCP Server 
# - Promptfoo
# - OpenWebui 
# - Splunk 

![splunkmcpllmsiemulator](https://github.com/user-attachments/assets/c3c04d04-9866-4c37-aba7-8cafbbefe7bb)
![ollamaprompts1](https://github.com/user-attachments/assets/2c126110-b54e-49ac-be65-75138fbe70a5)
![mcp1](https://github.com/user-attachments/assets/1261756c-3755-4147-b324-b9e714c2cad3)

# MITRE ATLAS focused detection development lab

# Raw HEC Log Shipping for Windows 

This setup uses Splunk's `/services/collector/raw` endpoint for optimal log shipping from Ollama and MCP containers.

## 🚀 Quick Start

### Option 1: Batch File (Simplest)
```cmd
quick-start.bat
```

### Option 2: PowerShell (Recommended)
```powershell
# Deploy the setup
.\deploy-raw-hec.ps1

# Start the lab
.\start-raw-hec-lab.ps1

# Validate the setup  
.\validate-raw-hec.ps1
```

## 🔗 Key Benefits of Raw HEC

✅ **Preserves Log Format** - Logs arrive exactly as written to disk
✅ **Better Performance** - Less processing overhead than JSON endpoint
✅ **Native Parsing** - Uses Splunk's props.conf rules

## 📊 Access Points

Once running, access:
- **Splunk Web**: http://localhost:8000 (admin/Password1)
- **Ollama API**: http://localhost:11434  (Version 0.3.12 recommended to obtain prompt info)
- **MCP Service**: http://localhost:3456
- **Raw HEC Health**: http://localhost:8088/services/collector/health
- **Promptfoo** http://localhost:3000 (Promptfoo version 0.115.1)
- **Ollama OpenWebui** http://localhost:3001

**Test Promptfoo with Ollama:**
   ```cmd
   docker cp simple-test.yaml security-range-promptfoo:/tmp/simple-test.yaml
   docker exec security-range-promptfoo promptfoo eval -c /tmp/simple-test.yaml
   ```

![promptfootest](https://github.com/user-attachments/assets/a603ae9b-a53c-41e6-bfe8-bb701a6e4bc0)

![promptfoo11](https://github.com/user-attachments/assets/1bd39123-9c52-4bb1-903a-fd905d766811)

## 🔍 Validation Queries

In Splunk, use these searches to validate:

```spl
# Check log ingestion
index=ollama_logs OR index=mcp_logs 
| stats count by index, sourcetype

# Check Raw vs JSON format
index=ollama_logs OR index=mcp_logs
| eval format=if(match(sourcetype, "docker"), "Raw HEC", "Other")
| stats count by format



## 📋 Configuration Details

### Raw HEC 

### Docker Logging Driver
```yaml
logging:
  driver: splunk
  options:
    splunk-format: raw              
    splunk-url: "http://host.docker.internal:8088"
    splunk-token: "${SPLUNK_HEC_TOKEN}"
    splunk-index: ollama_logs
    splunk-sourcetype: ollama:docker
```

## 🚨 Troubleshooting

1. **Docker not found**: Install Docker Desktop for Windows
2. **HEC not responding**: Check `docker-compose logs splunk`
3. **No log data**: Verify .env file exists with correct token
4. **PowerShell execution**: Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

## Files

- `docker-compose.yml` - Main service definitions
- `simple-test.yaml` - Basic Promptfoo test
- `llama3.2-test.yaml` - Advanced Promptfoo test with assertions
- `quick-start.bat` - One-click startup script
- `.env` - Environment variables


## 📈 Next Steps

1. Monitor logs: `docker-compose logs -f ollama`
2. Check Splunk ingestion: Use the validation queries above
3. Set up alerting for ATLAS TTP detections
4. Customize parsing rules in splunk-configs/props.conf

- **Promptfoo** 
## Promptfoo (upgrade to version 0.115.1)

For prompt foo you will have to run the eval from command or web interface (port:3000)
Example
  - docker cp simple-test.yaml security-range-promptfoo:/tmp/simple-test.yaml && docker exec security-range-promptfoo promptfoo eval -c /tmp/simple-test.yaml 
- No integration with splunk yet, you will have to perform evals or red team and export logs to csv or json 

## Testing

The Promptfoo configurations use HTTP providers to connect to Ollama:

```yaml
providers:
  - id: "http://host.docker.internal:11434/api/generate"
    config:
      method: POST
      headers:
        Content-Type: "application/json"
      body:
        model: "llama3.2"
        prompt: "{{prompt}}"
        stream: false
      responseParser: "json.response"
```

## But wait there is more OLLAMA + SPLUNK 

![ollamasplunkai1](https://github.com/user-attachments/assets/c1347522-7c8a-4152-a17d-1030b5e09946)

![ollamasplunkai3](https://github.com/user-attachments/assets/33b12d0c-85f2-4364-9f95-5a998885a2d6)

I wrote an ollama function that will allow you to query SPLUNK via inputing SPL code, NPL (Natural language i.e what indexes are available?) AND get AI commentary, it is a little rough but it works and can help to simplify queries via NPL and get overviews. 
Due to space and computing constraints (I wanted this setup to run in a 16GB or RAM laptop), I used llama3.2 (2GB). 

- Go to settings --> admin settings --> find function tab --> add function and copy the contents of the python file and save, then select the function when performing query 

- Here is an example "Find errors in ollama_logs **with insights*"

- feel free to extend it or use other models

- file name is ollamafunction.py


## Requirements

- Docker Desktop
- Windows 10/11 or WSL2 (16 GB of RAM + GPU recommended)

## NOTE 
This is a proof of concept and it sill needs a lots of work. For some reason newer versions of ollama proved to be incredibly difficult obtaining prompt logs, so stick with the recommended version. You can also find at times that prompt logs may stop flowing and that will require restarting or troubleshooting. It would be great if all these platforms just set their logs to json format, it would make everyone's life easier. Why on windows? because of the GPU :) . I will try to migrate it to linux on the next version, and also I will try to add Garak, unfortunately it gave me too many errors when trying to join it to the lab. 
