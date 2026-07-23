# custom_callbacks.py - LiteLLM -> Splunk HEC callback for TA-llmgateway
# Mounted at /app/custom_callbacks.py inside the litellm container.
# Referenced in config.yaml as:
#   litellm_settings:
#     callbacks: custom_callbacks.proxy_handler_instance

from litellm.integrations.custom_logger import CustomLogger
import litellm
import json
import urllib.request

HEC_URL   = "http://security-range-splunk:8088/services/collector/event"
HEC_TOKEN = "f4e45204-7cfa-48b5-bfbe-95cf03dbcad7"


def _safe(obj):
    try:
        json.dumps(obj)
        return obj
    except Exception:
        if isinstance(obj, dict):
            return {k: _safe(v) for k, v in obj.items()}
        if isinstance(obj, (list, tuple)):
            return [_safe(x) for x in obj]
        if hasattr(obj, "model_dump"):
            try:
                return _safe(obj.model_dump())
            except Exception:
                pass
        return str(obj)


class SplunkHECHandler(CustomLogger):
    def log_success_event(self, kwargs, response_obj, start_time, end_time):
        self._send(kwargs, response_obj, start_time, end_time, "success")

    def log_failure_event(self, kwargs, response_obj, start_time, end_time):
        self._send(kwargs, response_obj, start_time, end_time, "error")

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        self._send(kwargs, response_obj, start_time, end_time, "success")

    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        self._send(kwargs, response_obj, start_time, end_time, "error")

    def _send(self, kwargs, response_obj, start_time, end_time, status):
        try:
            slo = kwargs.get("standard_logging_object", {}) or {}
            litellm_params = kwargs.get("litellm_params", {}) or {}
            metadata = litellm_params.get("metadata", {}) or {}
            usage = getattr(response_obj, "usage", None) if response_obj else None
            messages = kwargs.get("messages", [])

            input_prompt = ""
            system_prompt = ""
            for m in messages:
                if isinstance(m, dict):
                    if m.get("role") == "system" and not system_prompt:
                        system_prompt = str(m.get("content", ""))
                    if m.get("role") == "user" and not input_prompt:
                        input_prompt = str(m.get("content", ""))

            output_text = ""
            tool_calls = None
            finish_reason = ""
            if response_obj and hasattr(response_obj, "choices") and response_obj.choices:
                try:
                    choice = response_obj.choices[0]
                    output_text = choice.message.content or ""
                    finish_reason = getattr(choice, "finish_reason", "")
                    if hasattr(choice.message, "tool_calls") and choice.message.tool_calls:
                        tool_calls = _safe(choice.message.tool_calls)
                except Exception:
                    pass

            event = {
                "timestamp": start_time.isoformat() + "Z",
                "gateway": "litellm",
                "status": status,
                "model": kwargs.get("model", ""),
                "model_group": metadata.get("model_group", ""),
                "deployment": metadata.get("deployment", ""),
                "custom_llm_provider": litellm_params.get("custom_llm_provider", ""),
                "api_base": kwargs.get("api_base", "") or litellm_params.get("api_base", ""),
                "call_type": kwargs.get("call_type", ""),
                "stream": kwargs.get("stream", False),
                "input_prompt": input_prompt,
                "system_prompt": system_prompt,
                "output_text": output_text,
                "finish_reason": finish_reason,
                "tool_calls": json.dumps(tool_calls) if tool_calls else None,
                "num_messages": len(messages),
                "prompt_tokens": getattr(usage, "prompt_tokens", 0) if usage else slo.get("prompt_tokens", 0),
                "completion_tokens": getattr(usage, "completion_tokens", 0) if usage else slo.get("completion_tokens", 0),
                "total_tokens": getattr(usage, "total_tokens", 0) if usage else slo.get("total_tokens", 0),
                "response_cost": kwargs.get("response_cost", slo.get("response_cost", 0)),
                "cache_hit": kwargs.get("cache_hit", False),
                "request_id": slo.get("id", ""),
                "call_id": kwargs.get("litellm_call_id", ""),
                "trace_id": metadata.get("trace_id", ""),
                "user": kwargs.get("user", "") or slo.get("end_user", ""),
                "api_key_alias": metadata.get("user_api_key_alias") or "",
                "team_alias": metadata.get("user_api_key_team_alias") or "",
                "latency_ms": int((end_time - start_time).total_seconds() * 1000),
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "exception": str(kwargs.get("exception", "")) if status == "error" else "",
                "standard_logging_object": _safe(slo),
            }

            payload = json.dumps({
                "event": event,
                "index": "llmgateway",
                "sourcetype": "llmgateway:litellm",
                "source": "litellm:proxy",
            }).encode("utf-8")

            req = urllib.request.Request(
                HEC_URL,
                data=payload,
                headers={
                    "Authorization": "Splunk " + HEC_TOKEN,
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            urllib.request.urlopen(req, timeout=5)
            print(
                "[SplunkHEC] OK model="
                + str(event["model"])
                + " tokens="
                + str(event["total_tokens"])
            )
        except Exception as e:
            print("[SplunkHEC] Error: " + str(e))


proxy_handler_instance = SplunkHECHandler()
