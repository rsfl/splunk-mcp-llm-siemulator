#!/usr/bin/env python3
# Reads Bifrost logs.db every 30s and ships new rows to Splunk HEC.
# Runs as a sidecar container alongside the Bifrost and Splunk containers.

import json
import os
import sqlite3
import time
import urllib.request

HEC_URL   = os.environ.get("SPLUNK_HEC_URL", "http://security-range-splunk:8088/services/collector/event")
HEC_TOKEN = os.environ.get("SPLUNK_HEC_TOKEN", "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7")
DB_PATH   = os.environ.get("BIFROST_DB_PATH", "/app/data/logs.db")
INTERVAL  = int(os.environ.get("SHIP_INTERVAL", "30"))
CHECKPOINT_FILE = "/tmp/bifrost_checkpoint.txt"


def read_checkpoint():
    try:
        with open(CHECKPOINT_FILE) as f:
            return f.read().strip()
    except FileNotFoundError:
        return "2000-01-01T00:00:00.000Z"


def write_checkpoint(ts):
    with open(CHECKPOINT_FILE, "w") as f:
        f.write(ts)


def flatten(row):
    for field in ("token_usage", "input_history", "output_history", "tool_calls", "selected_key", "metadata"):
        raw = row.get(field)
        if raw and isinstance(raw, str):
            try:
                row[field] = json.loads(raw)
            except Exception:
                pass

    tu = row.pop("token_usage", None)
    if isinstance(tu, dict):
        row["prompt_tokens"]     = tu.get("prompt_tokens", 0)
        row["completion_tokens"] = tu.get("completion_tokens", 0)
        row["total_tokens"]      = tu.get("total_tokens", 0)
    else:
        row["prompt_tokens"] = row["completion_tokens"] = row["total_tokens"] = 0

    ih = row.pop("input_history", None) or []
    row["input_prompt"] = row["system_prompt"] = ""
    for m in (ih if isinstance(ih, list) else []):
        if isinstance(m, dict):
            if m.get("role") == "system" and not row["system_prompt"]:
                row["system_prompt"] = m.get("content", "")
            if m.get("role") == "user" and not row["input_prompt"]:
                c = m.get("content", "")
                row["input_prompt"] = " ".join(x.get("text", "") for x in c if isinstance(x, dict)) if isinstance(c, list) else str(c)

    oh = row.pop("output_history", None) or []
    row["output_text"] = ""
    row["tool_calls"]  = None
    for m in (oh if isinstance(oh, list) else []):
        if isinstance(m, dict) and m.get("role") == "assistant":
            if m.get("content") and not row["output_text"]:
                row["output_text"] = str(m["content"])
            if m.get("tool_calls") and row["tool_calls"] is None:
                row["tool_calls"] = m["tool_calls"]

    sk = row.pop("selected_key", None)
    if isinstance(sk, dict):
        row["selected_key_name"] = sk.get("name", "")

    row["gateway"] = "bifrost"
    row.pop("raw_request", None)
    row.pop("raw_response", None)
    return row


def ship(rows, newest_ts, last_ts):
    if not rows:
        return last_ts
    sent = 0
    for row in rows:
        try:
            record = flatten(dict(row))
            ts = str(record.get("timestamp") or record.get("created_at", ""))
            if ts > newest_ts[0]:
                newest_ts[0] = ts
            payload = json.dumps({
                "event": record,
                "index": "llmgateway",
                "sourcetype": "llmgateway:bifrost",
                "source": "bifrost:sqlite",
            }, default=str).encode()
            req = urllib.request.Request(
                HEC_URL, data=payload,
                headers={"Authorization": "Splunk " + HEC_TOKEN, "Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=5)
            sent += 1
        except Exception as e:
            print(f"[HECShipper] error: {e}")
    if sent:
        print(f"[HECShipper] shipped {sent} bifrost events to Splunk")
    return newest_ts[0]


def run():
    print(f"[HECShipper] starting  db={DB_PATH} hec={HEC_URL} interval={INTERVAL}s")
    while True:
        if not os.path.exists(DB_PATH):
            print(f"[HECShipper] waiting for {DB_PATH}")
            time.sleep(INTERVAL)
            continue
        try:
            last_ts  = read_checkpoint()
            newest   = [last_ts]
            conn     = sqlite3.connect(DB_PATH)
            conn.row_factory = sqlite3.Row
            cur      = conn.cursor()
            cur.execute("SELECT * FROM logs WHERE created_at > ? ORDER BY created_at ASC LIMIT 500", (last_ts,))
            rows = cur.fetchall()
            conn.close()
            ship(rows, newest, last_ts)
            if newest[0] != last_ts:
                write_checkpoint(newest[0])
        except Exception as e:
            print(f"[HECShipper] db error: {e}")
        time.sleep(INTERVAL)


if __name__ == "__main__":
    run()
