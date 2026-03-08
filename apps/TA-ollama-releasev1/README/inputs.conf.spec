# TA-ollama inputs.conf.spec
# inputs.conf.spec for TA-ollama

# CONFIGURATION NOTES:
#
# This TA uses standard Splunk monitor inputs to collect Ollama server logs.
# To configure, create an inputs.conf file with a monitor stanza.
#
# Example configuration:
# [monitor:///var/log/ollama/ollama.log]
# sourcetype = ollama:server
# index = main
# disabled = false
#
# Common Ollama log paths:
#   Windows: C:\ProgramData\Ollama\logs\ollama.log
#   Linux: ~/.ollama/logs/server.log or /var/log/ollama/ollama.log
# For more linux instructions on how to collect logs please visit github.com/rosplk/ta-ollama

# HTTP Event Collector (HEC) Sourcetypes
# 
# This TA defines additional sourcetypes for use with HTTP Event Collector:
#
# ollama:api
#   * For API telemetry data sent via HEC
#   * Example fields: model, action, host, timestamp
#
# ollama:prompts
#   * For prompt and response data sent via HEC  
#   * Example fields: model, prompt, response, duration_ms
#
# HEC inputs do not require configuration in inputs.conf
# Configure HEC tokens in Splunk Web under Settings > Data Inputs > HTTP Event Collector