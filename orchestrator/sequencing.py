"""Explicit, one-shot handoff between externally executed manual tasks.

Waiting successors stay blocked so the bounded code executor cannot claim them.
A reserved launch is never retried automatically after an unknown outcome.
"""
import argparse
import json
import time

from orchestrator.settings import state_dir
from orchestrator.store import Store


def _inspect(c, task_id):
    row = c.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
    if row is None:
        raise KeyError(task_id)
    task = dict(row)
    spec = json.loads(task["spec"])
    sequence = spec.get("sequential_handoff", {})
    parents = [dict(r) for r in c.execute(
        "SELECT d.depends_on AS id,t.status,t.verification_status,t.github_sync_status "
        "FROM dependencies d LEFT JOIN tasks t ON t.id=d.depends_on WHERE d.task_id=?",
        (task_id,),
    )]
    completed = bool(parents) and all(
        p["status"] == "completed" and p["verification_status"] == "passed"
        and p["github_sync_status"] == "synced" for p in parents
    )
    valid = (task["kind"] == "manual" and sequence.get("enabled") is True
             and sequence.get("predecessor") in {p["id"] for p in parents})
    return {
        "task_id": task_id, "status": task["status"], "parents": parents,
        "ready": valid and completed and task["status"] == "blocked"
        and task["result"] == "waiting_for_verified_predecessor",
        "brief_path": spec.get("brief_path"), "brief_sha256": spec.get("brief_sha256"),
        "brief_bytes": spec.get("brief_bytes"),
    }


def inspect(store, task_id):
    with store.db() as c:
        return _inspect(c, task_id)


def reserve(store, task_id, owner, operation_id):
    with store.db() as c:
        c.execute("BEGIN IMMEDIATE")
        state = _inspect(c, task_id)
        op = c.execute("SELECT * FROM tool_operations WHERE id=?", (operation_id,)).fetchone()
        if op:
            args = json.loads(op["args"])
            if (op["tool"] != "local_codex_resume" or op["task_id"] != task_id
                    or args.get("owner") != owner):
                raise RuntimeError("handoff_operation_identity_mismatch")
            return dict(state, reserved=False, reason="launch_already_journaled_reconcile_before_retry")
        if not state["ready"]:
            return dict(state, reserved=False, reason="waiting_for_verified_predecessor")
        now = time.time()
        c.execute("INSERT INTO tool_operations VALUES(?,?,?,?,?,?,?,?)", (
            operation_id, task_id, "local_codex_resume",
            json.dumps({"owner": owner, "brief_sha256": state["brief_sha256"]}),
            "started", None, now, now,
        ))
        c.execute("UPDATE tasks SET status='planning',execution_status='planning',owner=?,"
                  "lease_until=?,result=?,updated=? WHERE id=?", (
                      owner, now + 1800, "successor_launch_reserved", now, task_id,
                  ))
        store._event(c, task_id, "Предыдущий этап завершён и проверен; зарезервирован запуск следующего полного ТЗ.",
                     "successor_reserved")
        return dict(state, reserved=True, operation_id=operation_id)


def confirm(store, task_id, owner, operation_id, pid):
    if pid <= 0:
        raise ValueError("invalid_local_pid")
    with store.db() as c:
        c.execute("BEGIN IMMEDIATE")
        op = c.execute("SELECT * FROM tool_operations WHERE id=?", (operation_id,)).fetchone()
        if (not op or op["tool"] != "local_codex_resume" or op["task_id"] != task_id
                or json.loads(op["args"]).get("owner") != owner):
            raise RuntimeError("handoff_operation_identity_mismatch")
        if op["status"] == "done":
            prior = json.loads(op["result"])
            if prior.get("pid") != pid:
                raise RuntimeError("handoff_pid_mismatch")
            return prior
        t = c.execute("SELECT status,owner FROM tasks WHERE id=?", (task_id,)).fetchone()
        if t["status"] not in ("planning", "running") or t["owner"] != owner:
            raise RuntimeError("successor_no_longer_reserved")
        now = time.time()
        result = {"task_id": task_id, "pid": pid, "status": "running", "receipt_pending": True}
        c.execute("UPDATE tool_operations SET status='done',result=?,updated=? WHERE id=?",
                  (json.dumps(result), now, operation_id))
        c.execute("UPDATE tasks SET status='running',execution_status='running',lease_until=?,"
                  "result=?,updated=? WHERE id=?", (now + 1800, "CLI started; awaiting full-brief receipt", now, task_id))
        store._event(c, task_id, "Исполнитель следующего этапа запущен; получение полного текста проверяется отдельно.",
                     "successor_started")
        return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("command", choices=["inspect", "reserve", "confirm"])
    p.add_argument("task_id")
    p.add_argument("--owner")
    p.add_argument("--operation-id")
    p.add_argument("--pid", type=int)
    a = p.parse_args()
    store = Store(state_dir() / "coordinator.sqlite3")
    if a.command == "inspect":
        result = inspect(store, a.task_id)
    else:
        if not a.owner or not a.operation_id:
            p.error("reserve/confirm require owner and operation-id")
        if a.command == "reserve":
            result = reserve(store, a.task_id, a.owner, a.operation_id)
        else:
            if a.pid is None:
                p.error("confirm requires pid")
            result = confirm(store, a.task_id, a.owner, a.operation_id, a.pid)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
