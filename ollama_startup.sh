#!/bin/bash
echo "Starting Ollama with file logging..."
mkdir -p /var/log/ollama

# Start Ollama in background and capture output
ollama serve --verbose > /var/log/ollama/ollama.log 2>&1 &

# Keep the script running
wait