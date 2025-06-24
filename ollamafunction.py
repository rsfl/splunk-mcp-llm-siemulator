"""
title: Splunk + NLP + AI (Smart Mode)
author: MCP Lab by Rod Soto
requirements: requests, urllib3
"""

import time
import re
import requests
import urllib3
from typing import List
from pydantic import BaseModel, Field
from fastapi import Request

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


class Pipe:
    # ────────────────────────────────────────────────────────────────────────
    # Configuration
    # ────────────────────────────────────────────────────────────────────────
    class Valves(BaseModel):
        # Splunk
        splunk_host: str = Field("splunk")
        splunk_port: str = Field("8089")
        splunk_username: str = Field("admin")
        splunk_password: str = Field("Password1")

        # Ollama / LLM
        ollama_host: str = Field("host.docker.internal")
        ollama_port: str = Field("11434")
        ollama_path: str = Field("/api/generate")
        ai_model: str = Field("llama3.2")
        ai_timeout: int = Field(20)
        ai_enabled: bool = Field(True)
        skip_connection_test: bool = Field(False)

    def __init__(self):
        self.valves = self.Valves()

    # ────────────────────────────────────────────────────────────────────────
    # OLLAMA utilities
    # ────────────────────────────────────────────────────────────────────────
    def _pick_ollama_url(self) -> str | None:
        """Return first reachable Ollama /api/generate URL or None."""
        hosts = [
            self.valves.ollama_host,
            "localhost",
            "127.0.0.1",
            "security-range-ollama",
        ]
        for host in hosts:
            if not host:
                continue
            base = f"http://{host}:{self.valves.ollama_port}"
            try:
                if not self.valves.skip_connection_test:
                    probe = requests.get(f"{base}/api/tags", timeout=3)
                    if probe.status_code != 200:
                        continue
                    tags = {m["name"] for m in probe.json().get("models", [])}
                    if self.valves.ai_model not in tags and tags:
                        self.valves.ai_model = sorted(tags)[0]
                return f"{base}{self.valves.ollama_path}"
            except requests.exceptions.RequestException:
                continue
        return None

    # ────────────────────────────────────────────────────────────────────────
    # AI helpers
    # ────────────────────────────────────────────────────────────────────────
    def get_ai_analysis(self, splunk_results: str, query: str) -> str:
        if not self.valves.ai_enabled:
            return ""
        ollama_url = self._pick_ollama_url()
        if not ollama_url:
            return "\n[ERROR] AI: cannot reach Ollama"

        prompt = (
            "Analyze these Splunk logs:\n\n"
            f"Query: {query}\n"
            f"Results: {splunk_results[:400]}\n\n"
            "Provide a brief security analysis (max 30 words):"
        )
        payload = {
            "model": self.valves.ai_model,
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "num_predict": 60,
                "top_p": 0.9,
                "repeat_penalty": 1.1,
                "stop": ["\n\n", "Query:", "Results:"],
            },
        }
        try:
            r = requests.post(ollama_url, json=payload, timeout=self.valves.ai_timeout)
            if r.ok:
                text = (r.json().get("response") or "").strip()
                if text and not text.lower().startswith("error"):
                    return f"\n[AI ANALYSIS]:\n{text}"
            return "\n[ERROR] AI: no usable model reply"
        except requests.exceptions.RequestException as e:
            return f"\n[ERROR] AI: {e}"

    def ask_model(self, question: str) -> str:
        if not self.valves.ai_enabled:
            return "AI is disabled."
        ollama_url = self._pick_ollama_url()
        if not ollama_url:
            return "[ERROR] AI: cannot reach Ollama"

        payload = {
            "model": self.valves.ai_model,
            "prompt": question,
            "stream": False,
            "options": {"temperature": 0.7, "num_predict": 200},
        }
        try:
            r = requests.post(ollama_url, json=payload, timeout=self.valves.ai_timeout)
            if r.ok:
                ans = (r.json().get("response") or "").strip()
                return f"[AI] {ans}" if ans else "[ERROR] AI: empty response"
            return f"[ERROR] AI: HTTP {r.status_code}"
        except requests.exceptions.RequestException as e:
            return f"[ERROR] AI: {e}"

    # ────────────────────────────────────────────────────────────────────────
    # Splunk helpers
    # ────────────────────────────────────────────────────────────────────────
    def splunk_test(self) -> str:
        try:
            base = f"https://{self.valves.splunk_host}:{self.valves.splunk_port}"
            r = requests.get(
                f"{base}/services/server/info",
                auth=(self.valves.splunk_username, self.valves.splunk_password),
                params={"output_mode": "json"},
                verify=False,
                timeout=10,
            )
            if r.ok:
                ver = (
                    r.json()["entry"][0]["content"].get("version", "unknown")
                    if r.json().get("entry")
                    else "unknown"
                )
                return (
                    "SUCCESS: Splunk connection\n"
                    f"Host: {self.valves.splunk_host}:{self.valves.splunk_port}\n"
                    f"Version: {ver}"
                )
            return f"ERROR: status {r.status_code}"
        except Exception as e:
            return f"ERROR: {e}"

    def splunk_search(
        self,
        query: str,
        earliest_time: str = "0",
        latest_time: str = "now",
        count: int = 20,
        add_ai: bool = False,
    ) -> str:
        try:
            base = f"https://{self.valves.splunk_host}:{self.valves.splunk_port}"
            if not query.strip().startswith("search "):
                query = f"search {query}"

            job = requests.post(
                f"{base}/services/search/jobs",
                auth=(self.valves.splunk_username, self.valves.splunk_password),
                data={
                    "search": query,
                    "earliest_time": earliest_time,
                    "latest_time": latest_time,
                    "output_mode": "json",
                },
                verify=False,
                timeout=30,
            )
            if job.status_code != 201:
                return f"ERROR: job status {job.status_code}"
            sid = job.json()["sid"]

            job_url = f"{base}/services/search/jobs/{sid}"
            for _ in range(30):
                j = requests.get(
                    job_url,
                    auth=(self.valves.splunk_username, self.valves.splunk_password),
                    params={"output_mode": "json"},
                    verify=False,
                )
                if j.ok and j.json()["entry"][0]["content"]["isDone"]:
                    break
                time.sleep(1)

            res = requests.get(
                f"{job_url}/results",
                auth=(self.valves.splunk_username, self.valves.splunk_password),
                params={"output_mode": "json", "count": count},
                verify=False,
            )
            if not res.ok:
                return f"ERROR: results status {res.status_code}"
            rows = res.json().get("results", [])
            if not rows:
                return "INFO: no results"

            out = [f"SPLUNK RESULTS ({len(rows)})", ""]
            for i, row in enumerate(rows[:5], 1):
                out.append(f"Result {i}:")
                for k, v in row.items():
                    if k.startswith("_") and k not in {"_time", "_raw"}:
                        continue
                    v = str(v) if len(str(v)) <= 80 else str(v)[:80] + "..."
                    out.append(f"  {k}: {v}")
                out.append("")
            if len(rows) > 5:
                out.append(f"... {len(rows)-5} more")

            if add_ai:
                out.append(self.get_ai_analysis("\n".join(out), query))
            return "\n".join(out)
        except Exception as e:
            return f"ERROR: {e}"

    def splunk_indexes(self) -> str:
        try:
            base = f"https://{self.valves.splunk_host}:{self.valves.splunk_port}"
            r = requests.get(
                f"{base}/services/data/indexes",
                auth=(self.valves.splunk_username, self.valves.splunk_password),
                params={"output_mode": "json"},
                verify=False,
            )
            if not r.ok:
                return f"ERROR: status {r.status_code}"
            idx = sorted(e["name"] for e in r.json().get("entry", []))
            return "AVAILABLE INDEXES:\n" + "\n".join(f"  {n}" for n in idx)
        except Exception as e:
            return f"ERROR: {e}"

    # ────────────────────────────────────────────────────────────────────────
    # Chat entrypoint
    # ────────────────────────────────────────────────────────────────────────
    async def pipe(self, body: dict, __user__: dict, __request__: Request) -> str:
        if not (msg := body.get("messages", [{}])[-1].get("content", "").strip()):
            return "No message provided"

        text = msg.lower()
        ai_words = {"analysis", "analyze", "insights", "commentary", "explain",
                    "interpret", "assessment", "review", "summary"}
        want_ai = any(w in text for w in ai_words)

        # ── Natural-language patterns that mention index=foo ──────────────
        m = re.search(r"\bindex=([a-zA-Z0-9_]+)\b", text)
        if m:
            idx = m.group(1)

            # "what is in index=foo"
            if "what" in text and "in" in text:
                spl = f"index={idx} | sort - _time | head 20"
                return self.splunk_search(spl, "0", "now", 20, want_ai)

            # "search for errors in index=foo"
            if "error" in text or "errors" in text or "exception" in text or "failed" in text:
                spl = (
                    f"index={idx} "
                    "(error OR Error OR ERROR OR failed OR Failed OR exception OR Exception)"
                    " | sort - _time | head 20"
                )
                return self.splunk_search(spl, "0", "now", 20, want_ai)

        # ── Raw SPL heuristic ────────────────────────────────────────────
        if any(t in text for t in ("index=", "|", "search ")):
            return self.splunk_search(msg, "0", "now", 20, want_ai)

        # ── Quick commands ───────────────────────────────────────────────
        if "test" in text and "splunk" in text:
            return self.splunk_test()
        if "index" in text and ("available" in text or "list" in text):
            return self.splunk_indexes()

        # NL shortcuts
        if any(w in text for w in ("error", "exception", "fail")):
            q = (
                "index=* (error OR Error OR ERROR OR failed OR Failed "
                "OR exception OR Exception)"
            )
            return self.splunk_search(q, "0", "now", 15, want_ai)
        if any(w in text for w in ("nginx", "web", "access")):
            q = (
                'index=* (source="*nginx*" OR source="*access*" '
                'OR sourcetype=access_combined)'
            )
            return self.splunk_search(q, "0", "now", 10, want_ai)

        # fallback: direct chat
        return self.ask_model(msg)
