#!/usr/bin/env python3
# Sends a lightweight heartbeat to Bifrost every 20 minutes so the
# web UI (which defaults to period=1h) always shows recent activity.

import json
import os
import time
import urllib.request

BIFROST_URL = os.environ.get("BIFROST_URL", "http://security-range-bifrost:8080/v1/chat/completions")
INTERVAL    = int(os.environ.get("KEEPALIVE_INTERVAL", str(20 * 60)))

PROMPT = "Respond with only the word: HEARTBEAT"

def ping():
    body = json.dumps({
        "model": "ollama/llama3.2",
        "messages": [{"role": "user", "content": PROMPT}],
        "stream": False,
    }).encode()
    req = urllib.request.Request(
        BIFROST_URL, data=body,
        headers={"Content-Type": "application/json", "Authorization": "Bearer dummy"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
        return d["choices"][0]["message"]["content"].strip()[:20]

print(f"[keepalive] starting  interval={INTERVAL}s  target={BIFROST_URL}", flush=True)
while True:
    try:
        result = ping()
        print(f"[keepalive] OK  {result}", flush=True)
    except Exception as e:
        print(f"[keepalive] warn: {e}", flush=True)
    time.sleep(INTERVAL)
