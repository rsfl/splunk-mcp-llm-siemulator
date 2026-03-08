#!/bin/sh
mkdir -p /var/log/ollama
echo 'Starting Ollama with file logging...'
exec ollama serve > /var/log/ollama/ollama.log 2>&1
