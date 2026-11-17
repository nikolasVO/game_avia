"""One-shot local task dispatcher; never interrupts the current CLI writer.

Configuration and logs live outside Git. This does not deploy game services.
It starts one successor only after durable acceptance of every predecessor.
"""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import time


def write_json(path, value):
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    tmp.chmod(0o600)
    tmp.replace(path)


def cli_is_running(worktree, session_id):
    rows = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True)
    for line in rows.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2:
            continue
        command = fields[1]
        try:
            argv = shlex.split(command)
        except ValueError:
            continue
        if (argv and Path(argv[0]).name == "codex" and "exec" in argv
                and (session_id in argv or worktree in argv)):
            return True
    return False


def remote(config, command, *args):
    argv = [config["remote_python"], "-m", "orchestrator.sequencing", command,
            config["successor_task"], *args]
    script = "cd " + shlex.quote(config["remote_repo"]) + " && " + shlex.join(argv)
    result = subprocess.run(config["ssh_argv"] + [script], text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=40)
    if result.returncode:
        raise RuntimeError(f"remote_{command}_failed_exit_{result.returncode}")
    return json.loads(result.stdout.strip().splitlines()[-1])


def step(config, runtime):
    if cli_is_running(config["worktree"], config["session_id"]):
        return {"status": "waiting_for_current_cli"}
    state = remote(config, "inspect")
    if not state["ready"]:
        return {"status": "waiting_for_verified_predecessor", "state": state}
    if state["brief_sha256"] != config["brief_sha256"] or state["brief_bytes"] != config["brief_bytes"]:
        raise RuntimeError("successor_task_brief_mismatch")
    brief = Path(config["brief_file"]).read_bytes()
    if len(brief) != config["brief_bytes"] or hashlib.sha256(brief).hexdigest() != config["brief_sha256"]:
        raise RuntimeError("successor_brief_integrity_failed")
    owner, opid = config["owner"], config["operation_id"]
    reservation = remote(config, "reserve", "--owner", owner, "--operation-id", opid)
    if not reservation["reserved"]:
        return {"status": "reservation_not_granted", "state": reservation}
    write_json(runtime / "dispatcher-state.json", {"status": "launch_reserved", "reservation": reservation})
    if cli_is_running(config["worktree"], config["session_id"]):
        raise RuntimeError("writer_appeared_after_reservation_reconcile_before_retry")
    prefix = config["prompt_prefix"].replace("{successor_task}", config["successor_task"])
    prompt = runtime / "stage3-prompt.txt"
    prompt.write_bytes(prefix.encode() + brief)
    prompt.chmod(0o600)
    events, stderr = runtime / "stage3-events.jsonl", runtime / "stage3-stderr.log"
    args = [config["cli"], "-a", "never", "exec", "--sandbox", "danger-full-access",
            "--cd", config["worktree"], "--json", "--output-last-message",
            str(runtime / "stage3-last-message.txt"), "resume", config["session_id"], "-"]
    with prompt.open("rb") as incoming, events.open("wb") as outgoing, stderr.open("wb") as errors:
        process = subprocess.Popen(args, stdin=incoming, stdout=outgoing, stderr=errors,
                                   cwd=config["worktree"], start_new_session=True)
    launched = {"status": "launched", "pid": process.pid, "task_id": config["successor_task"],
                "session_id": config["session_id"], "brief_sha256": config["brief_sha256"]}
    write_json(runtime / "dispatcher-state.json", launched)
    process_file = Path(config["implementation_process_file"])
    prior = json.loads(process_file.read_text())
    write_json(runtime / "process-before-stage3.json", prior)
    updated = dict(prior, pid=process.pid, started=time.time(), private_events=str(events),
                   brief_sha256=config["brief_sha256"], brief_bytes=config["brief_bytes"],
                   server_task_id=config["successor_task"], scope="stage 3 after verified predecessor",
                   continuation=prior.get("continuation", 0) + 1)
    write_json(process_file, updated)
    # Confirming the same PID is idempotent; never start another process on a lost reply.
    for attempt in range(3):
        try:
            remote(config, "confirm", "--owner", owner, "--operation-id", opid, "--pid", str(process.pid))
            return dict(launched, confirmed=True)
        except (RuntimeError, subprocess.TimeoutExpired):
            if attempt < 2:
                time.sleep(5)
    return dict(launched, confirmed=False, reason="reconcile_existing_pid_do_not_relaunch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--once", action="store_true", help="Inspect once; launch only if every gate passes")
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    runtime = args.config.parent
    lock = (runtime / "dispatcher.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    marker = runtime / "dispatcher-state.json"
    if marker.exists() and json.loads(marker.read_text()).get("status") in ("launch_reserved", "launched"):
        raise RuntimeError("prior_launch_record_exists_reconcile_before_restart")
    previous = None
    while True:
        try:
            result = step(config, runtime)
        except (RuntimeError, subprocess.TimeoutExpired, OSError) as exc:
            if marker.exists() and json.loads(marker.read_text()).get("status") in ("launch_reserved", "launched"):
                raise
            result = {"status": "waiting_after_error", "error_type": type(exc).__name__}
        fingerprint = json.dumps(result, sort_keys=True)
        if fingerprint != previous:
            write_json(marker, result)
            print(fingerprint, flush=True)
            previous = fingerprint
        if args.once or result["status"] in ("launched", "reservation_not_granted"):
            return
        time.sleep(30)


if __name__ == "__main__":
    main()
