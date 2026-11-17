"""Launch the installed Codex runtime against a verified Responses provider."""
import json
import os
from pathlib import Path


def configure_provider(args, route, credentials_path, environment=None):
    credentials = json.loads(Path(credentials_path).read_text())
    entry = credentials[route["env_prefix"]]
    if not entry["base_url"].startswith("https://") or len(entry["api_key"]) < 15:
        raise ValueError("invalid_provider_credentials")
    provider_id = "game_avia_" + route["env_prefix"].lower()
    options = {
        "name": route["env_prefix"], "base_url": entry["base_url"].rstrip("/"),
        "env_key": "GAME_AVIA_ROUTE_API_KEY", "wire_api": "responses",
        "requires_openai_auth": False, "request_max_retries": 0,
        "stream_max_retries": 0, "stream_idle_timeout_ms": 120000,
    }
    result = list(args)
    for key, value in {"model_provider": provider_id, "model": route["model"],
                       "model_reasoning_effort": "high", "model_context_window": 128000}.items():
        result.extend(["-c", key + "=" + json.dumps(value)])
    for key, value in options.items():
        result.extend(["-c", "model_providers." + provider_id + "." + key + "=" + json.dumps(value)])
    result.extend(["-c", 'shell_environment_policy.exclude=["*API_KEY*","*TOKEN*","*SECRET*"]'])
    env = {k: v for k, v in (os.environ if environment is None else environment).items()
           if not k.endswith(("_API_KEY", "_TOKEN"))}
    env["GAME_AVIA_ROUTE_API_KEY"] = entry["api_key"]
    return result, env


def select_route(routes, process, state, events, signature, now):
    """Rotate after a failed provider turn; retain cooldowns across restarts."""
    cooldowns = dict(state.get("api_cooldowns", {}))
    failures = [e for e in events if e.get("type") in ("error", "turn.failed")]
    route_id = process.get("api_route")
    if (process.get("account_mode") == "provider_api" and failures and route_id
            and state.get("api_failure_signature") != signature):
        message = str(failures[-1].get("error", failures[-1].get("message", ""))).lower()
        quota = any(x in message for x in ("usage limit", "quota", "balance", "429", "402"))
        auth = any(x in message for x in ("401", "unauthorized", "authentication", "invalid_api_key"))
        cooldowns[route_id] = now + (86400 if auth else 3600 if quota else 120)
    eligible = [r for r in routes if cooldowns.get(r["id"], 0) <= now]
    if not failures and route_id:
        eligible.sort(key=lambda r: r["id"] != route_id)
    return (eligible[0] if eligible else None), cooldowns


def save_reported_usage(runtime, process, events):
    """Keep actual per-turn counters privately; no inferred HTTP count or price."""
    if process.get("account_mode") != "provider_api":
        return
    turns = []
    for event in events:
        if event.get("type") != "turn.completed" or not isinstance(event.get("usage"), dict):
            continue
        turns.append({key: value for key, value in event["usage"].items()
                      if key.endswith("_tokens") and isinstance(value, int) and value >= 0})
    if not turns:
        return
    from scripts.sequential_cli_handoff import write_json
    write_json(Path(runtime) / ("usage-" + str(process["pid"]) + ".json"), {
        "task_id": process["server_task_id"], "provider": process.get("api_route"),
        "wire_model": process.get("api_model"), "source_events": process["private_events"],
        "turns": turns, "cost_status": "cost_unknown", "http_requests": None})
