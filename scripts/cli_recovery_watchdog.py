"""Resume the same external CLI task after interruptions, without buying quota.

Uses existing Store/outbox, the same task/worktree and a shared local writer lock.
Config/state/logs belong outside Git; this is not an automatic deploy worker.
"""
import argparse
import fcntl
import json
from pathlib import Path
import shlex
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scripts.sequential_cli_handoff import cli_is_running, write_json
from workers.coding.provider_runtime import configure_provider, select_route


def tail_json(path, maximum=4 * 1024 * 1024):
    path = Path(path)
    if not path.exists():
        return []
    with path.open("rb") as stream:
        stream.seek(max(0, path.stat().st_size - maximum))
        lines = stream.read().splitlines()
    result = []
    for line in lines:
        try:
            result.append(json.loads(line))
        except (ValueError, UnicodeDecodeError):
            pass
    return result


def failure_policy(events, rates, now, attempts=0):
    failures = [e for e in events if e.get("type") in {"error", "turn.failed"}]
    if not failures:
        return {"reason": "transient_failure", "retry_at": now + min(300 * 2 ** min(attempts, 6), 21600)}
    error = failures[-1].get("error", failures[-1].get("message", ""))
    if isinstance(error, dict):
        error = error.get("message", "")
    message = str(error).lower()
    if any(x in message for x in ("usage limit", "quota exceeded", "insufficient_quota")):
        reset = max([bucket.get("resets_at", 0) for bucket in rates if bucket.get("used_percent", 0) >= 100] or [0])
        retry_at = reset + 90 if reset > now else now + min(3600 * 2 ** min(attempts, 4), 21600)
        return {"reason": "usage_limit", "retry_at": retry_at}
    if any(x in message for x in ("unauthorized", "authentication", "login required", "invalid api key")):
        return {"reason": "auth_required", "retry_at": now + 21600}
    return {"reason": "transient_failure", "retry_at": now + min(300 * 2 ** min(attempts, 6), 21600)}


def remote(config, command, task_id, *args):
    argv = [config["remote_python"], "-m", "orchestrator.recovery", command, task_id, *args]
    script = "cd " + shlex.quote(config["remote_repo"]) + " && " + shlex.join(argv)
    result = subprocess.run(config["ssh_argv"] + [script], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, timeout=50)
    if result.returncode:
        raise RuntimeError("remote_recovery_" + command + "_failed")
    return json.loads(result.stdout.strip().splitlines()[-1])


def quota_buckets(config):
    latest = {}
    for event in tail_json(config["rollout_file"]):
        payload = event.get("payload", {})
        value = payload.get("rate_limits") if isinstance(payload, dict) else None
        if value and value.get("limit_id") == "codex":
            latest = value
    return [latest[k] for k in ("primary", "secondary") if isinstance(latest.get(k), dict)]


def step(config, state, now=None, allow_launch=True):
    now = time.time() if now is None else now
    runtime = Path(config["runtime"])
    process_file = Path(config["implementation_process_file"])
    process = json.loads(process_file.read_text())
    task_id = process["server_task_id"]
    if task_id not in config["allowed_tasks"]:
        return {"status": "unmanaged_task", "task_id": task_id}
    owner = config["owners"][task_id]
    if cli_is_running(process["worktree"], config["session_id"]):
        if state.get("operation_id") and state.get("pid") == process["pid"] and not state.get("confirmed"):
            remote(config, "confirm", task_id, "--owner", owner,
                   "--operation-id", state["operation_id"], "--pid", str(process["pid"]))
            state = dict(state, confirmed=True)
        renewed = remote(config, "heartbeat", task_id, "--owner", owner)
        if renewed.get("renewed"):
            return dict(state, status="running", task_id=task_id, pid=process["pid"], attempts=state.get("attempts", 0))
        # Never steal another writer's task or clear unknown effects to extend a lease.
        return {"status": "live_cli_lease_needs_reconciliation", "task_id": task_id}
    task = remote(config, "inspect", task_id)
    if task["status"] in {"completed", "cancelled", "paused", "failed"}:
        return {"status": "protected_task_state", "task_id": task_id, "task_status": task["status"]}
    if task["unknown_operations"]:
        reconciliation = remote(config, "reconcile", task_id)
        if reconciliation["unresolved"]:
            retry = state.get("retry_at") if state.get("reason") == "unknown_operation" and state.get("retry_at", 0) > now else now + 3600
            remote(config, "wait", task_id, "--reason", "unknown_operation", "--retry-at", str(retry))
            return {"status": "waiting", "task_id": task_id, "reason": "unknown_operation", "retry_at": retry}
    event_file = process["private_events"]
    events = tail_json(event_file)
    signature = event_file + ":" + str(Path(event_file).stat().st_mtime_ns)
    api_route, cooldowns = (None, {})
    if config.get("api_routes") and config.get("paid_work_authorized"):
        api_route, cooldowns = select_route(config["api_routes"], process, state, events, signature, now)
        if api_route is None:
            retry_at = min(cooldowns.values()) if cooldowns else now + 3600
            remote(config, "wait", task_id, "--reason", "transient_failure", "--retry-at", str(retry_at))
            return dict(state, status="waiting", task_id=task_id, reason="providers_in_cooldown",
                        retry_at=retry_at, api_cooldowns=cooldowns, api_failure_signature=signature)
        # A subscription quota does not hold an independent, owner-authorized API route.
        policy = {"reason": "provider_ready", "retry_at": now}
    elif state.get("failure_signature") == signature and state.get("status") == "waiting":
        policy = {"reason": state["reason"], "retry_at": state["retry_at"]}
    else:
        policy = failure_policy(events, quota_buckets(config), now, state.get("attempts", 0))
    if now < policy["retry_at"] or not allow_launch:
        if policy["reason"] != "provider_ready":
            remote(config, "wait", task_id, "--reason", policy["reason"], "--retry-at", str(policy["retry_at"]))
        return dict(policy, status="waiting", task_id=task_id, failure_signature=signature,
                    attempts=state.get("attempts", 0))
    # The stage dispatcher uses the same lock. Recheck process and durable state inside it.
    with Path(config["launch_lock"]).open("a") as writer_lock:
        fcntl.flock(writer_lock, fcntl.LOCK_EX)
        if cli_is_running(process["worktree"], config["session_id"]):
            return {"status": "writer_appeared", "task_id": task_id}
        attempt = state.get("attempts", 0) + 1
        operation_id = "automatic-cli-resume-" + task_id + "-" + str(time.time_ns())
        reservation = remote(config, "reserve", task_id, "--owner", owner, "--operation-id", operation_id)
        if not reservation["reserved"]:
            return {"status": "resume_not_reserved", "task_id": task_id, "reason": reservation["reason"]}
        checkpoint = runtime / ("checkpoint-" + str(attempt) + ".json")
        write_json(checkpoint, {"process": process, "task_id": task_id,
                               "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=process["worktree"], text=True).strip(),
                               "worktree_status": subprocess.check_output(["git", "status", "--short"], cwd=process["worktree"], text=True),
                               "operation_id": operation_id})
        launch_state = {"status": "launch_reserved", "task_id": task_id, "operation_id": operation_id,
                        "owner": owner, "attempts": attempt, "checkpoint": str(checkpoint)}
        write_json(runtime / "state.json", launch_state)
        prompt = runtime / ("resume-" + str(attempt) + ".txt")
        text = config["resume_prompt"].replace("{task_id}", task_id).replace("{owner}", owner)
        if api_route:
            text = Path(config["provider_handoff_file"]).read_text() + "\n\n" + text
        prompt.write_text(text)
        prompt.chmod(0o600)
        events_path = runtime / ("resume-" + str(attempt) + "-events.jsonl")
        args = [process["cli"], "-a", "never", "exec", "--sandbox", "danger-full-access", "--cd", process["worktree"],
                "--json", "--output-last-message", str(runtime / ("resume-" + str(attempt) + "-last-message.txt"))]
        child_env = None
        if api_route:
            args, child_env = configure_provider(args, api_route, config["provider_credentials_file"])
            # Fresh provider context: do not transfer account-specific encrypted reasoning.
            args.append("-")
            launch_state.update(api_route=api_route["id"], api_cooldowns=cooldowns,
                                api_failure_signature=signature)
        else:
            args.extend(["resume", config["session_id"], "-"])
        with prompt.open("rb") as incoming, events_path.open("wb") as outgoing, (runtime / ("resume-" + str(attempt) + "-stderr.log")).open("wb") as errors:
            child = subprocess.Popen(args, cwd=process["worktree"], stdin=incoming, stdout=outgoing,
                                     stderr=errors, env=child_env, start_new_session=True)
        launch_state.update(status="running", pid=child.pid)
        write_json(runtime / "state.json", launch_state)
        process.update(pid=child.pid, started=time.time(), private_events=str(events_path),
                       continuation=process.get("continuation", 0) + 1)
        if api_route:
            process.update(account_mode="provider_api", api_route=api_route["id"], api_model=api_route["model"])
        write_json(process_file, process)
        # A lost response only retries confirmation of this PID, never Popen.
        for index in range(3):
            try:
                remote(config, "confirm", task_id, "--owner", owner, "--operation-id", operation_id, "--pid", str(child.pid))
                launch_state["confirmed"] = True
                break
            except (RuntimeError, subprocess.TimeoutExpired):
                if index < 2:
                    time.sleep(5)
        return launch_state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--no-launch", action="store_true")
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    runtime = Path(config["runtime"])
    lock = (runtime / "controller.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    state_file = runtime / "state.json"
    state = json.loads(state_file.read_text()) if state_file.exists() else {}
    if state.get("status") == "launch_reserved":
        raise RuntimeError("unknown_local_launch_reconcile_before_retry")
    while True:
        try:
            result = step(config, state, allow_launch=not args.no_launch)
        except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
            persisted = json.loads(state_file.read_text()) if state_file.exists() else {}
            if persisted.get("status") == "launch_reserved":
                raise
            result = dict(state, controller_error=type(error).__name__)
        if result != state:
            write_json(state_file, result)
            print(json.dumps(result, sort_keys=True), flush=True)
            state = result
        if args.once:
            return
        time.sleep(120)


if __name__ == "__main__":
    main()
