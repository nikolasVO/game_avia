"""Conservative automatic reconciliation and recovery of external CLI tasks."""
import argparse
import json
import re
import time
import urllib.error
import urllib.request

from orchestrator.store import Store


def github_read(path):
    request = urllib.request.Request("https://api.github.com/" + path,
                                     headers={"Accept": "application/vnd.github+json",
                                              "User-Agent": "game-avia-operation-reconciler"})
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, {}


def publication_outcome(args, fetch=github_read):
    repository = "repos/nikolasVO/game_avia"
    tag = args.get("tag", "")
    if not re.fullmatch(r"[A-Za-z0-9._-]{1,150}", tag):
        return None
    access, meta = fetch(repository)
    if access != 200 or meta.get("full_name") != "nikolasVO/game_avia":
        return None
    release_status, release = fetch(repository + "/releases/tags/" + tag)
    tag_status, ref = fetch(repository + "/git/ref/tags/" + tag)
    if release_status == tag_status == 404:
        return {"outcome": "not_published", "reconciled": True, "retry_safe": True,
                "new_operation_id_required": True,
                "proof": {"repository_access": 200, "release": 404, "tag": 404}}
    if release_status != 200 or tag_status != 200 or release.get("tag_name") != tag:
        return None
    obj = ref.get("object", {})
    if obj.get("type") == "tag":
        status, annotated = fetch(repository + "/git/tags/" + obj.get("sha", ""))
        if status != 200:
            return None
        obj = annotated.get("object", {})
    if obj.get("type") != "commit" or obj.get("sha") != args.get("source"):
        return None
    assets = release.get("assets", [])
    for extension, field in ((".apk", "apk_sha256"), (".aab", "aab_sha256")):
        expected = args.get(field)
        found = [a for a in assets if a.get("name", "").endswith(extension)]
        if not expected or len(found) != 1 or found[0].get("digest") != "sha256:" + expected:
            return None
    return {"outcome": "published", "reconciled": True, "retry_safe": False,
            "source": obj["sha"], "tag": tag, "url": release.get("html_url")}


def reconcile(store, task_id, fetch=github_read):
    with store.db() as c:
        operations = [dict(r) for r in c.execute(
            "SELECT * FROM tool_operations WHERE task_id=? AND status='started'", (task_id,))]
    resolved, unresolved = [], []
    for op in operations:
        outcome = publication_outcome(json.loads(op["args"]), fetch) if op["tool"] == "github_prerelease" else None
        if outcome is None:
            unresolved.append({"id": op["id"], "tool": op["tool"]})
            continue
        with store.db() as c:
            c.execute("BEGIN IMMEDIATE")
            updated = c.execute("UPDATE tool_operations SET status='done',result=?,updated=? "
                                "WHERE id=? AND status='started' AND args=?", (
                                    json.dumps(outcome), time.time(), op["id"], op["args"],
                                )).rowcount
            if updated:
                store._event(c, task_id, "Автоматическая сверка операции " + op["id"] + ": "
                             + outcome["outcome"] + ". Повторная отправка не выполнялась.", "operation_reconciled")
        resolved.append({"id": op["id"], "outcome": outcome["outcome"]})
    return {"resolved": resolved, "unresolved": unresolved}


def snapshot(store, task_id):
    task = store.get_task(task_id)
    if not task:
        raise KeyError(task_id)
    with store.db() as c:
        unknown = [dict(r) for r in c.execute(
            "SELECT id,tool FROM tool_operations WHERE task_id=? AND status='started'", (task_id,))]
    return {k: task[k] for k in ("id", "status", "owner", "lease_until")} | {"unknown_operations": unknown}


def record_wait(store, task_id, reason, retry_at):
    if reason not in {"usage_limit", "transient_failure", "unknown_operation", "auth_required", "possible_stall"}:
        raise ValueError("invalid_recovery_reason")
    with store.db() as c:
        c.execute("BEGIN IMMEDIATE")
        task = c.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
        if not task or task["status"] in {"paused", "cancelled", "completed", "failed"}:
            return {"status": "protected_task_state"}
        if task["owner"] and (task["lease_until"] or 0) > time.time():
            return {"status": "live_owner_lease_preserved"}
        key = "automatic_recovery:" + task_id
        state = {"reason": reason, "retry_at": retry_at}
        prior = c.execute("SELECT value FROM kv WHERE key=?", (key,)).fetchone()
        encoded = json.dumps(state, sort_keys=True)
        c.execute("INSERT OR REPLACE INTO kv VALUES(?,?)", (key, encoded))
        progress_key = "recovery_last_progress:" + task_id
        c.execute("INSERT OR IGNORE INTO kv VALUES(?,?)", (progress_key, task["result"] or ""))
        result = json.dumps({"automatic_recovery": state, "last_progress_kv": progress_key})
        c.execute("UPDATE tasks SET status='blocked',execution_status='blocked',owner=NULL,lease_until=NULL,result=?,updated=? WHERE id=?",
                  (result, time.time(), task_id))
        if not prior or prior[0] != encoded:
            message = "Автовосстановление: " + reason + ". "
            if reason == "usage_limit":
                from datetime import datetime
                from zoneinfo import ZoneInfo
                when = datetime.fromtimestamp(retry_at, ZoneInfo("Europe/Moscow")).strftime("%d.%m %H:%M МСК")
                message += "Лимит Codex исчерпан; автоматическое продолжение запланировано на " + when + ". Действий владельца не требуется."
            else:
                message += "Состояние сохранено; повтор выполняется только после проверки условий."
            store._event(c, task_id, message, "automatic_recovery_wait")
    return state


def reserve_resume(store, task_id, owner, operation_id):
    with store.db() as c:
        c.execute("BEGIN IMMEDIATE")
        task = c.execute("SELECT * FROM tasks WHERE id=?", (task_id,)).fetchone()
        if not task or task["status"] not in {"blocked", "ready", "planning", "running"}:
            return {"reserved": False, "reason": "protected_task_state"}
        if task["owner"] and (task["lease_until"] or 0) > time.time():
            return {"reserved": False, "reason": "another_live_lease"}
        if c.execute("SELECT 1 FROM dependencies d LEFT JOIN tasks p ON p.id=d.depends_on "
                     "WHERE d.task_id=? AND (p.id IS NULL OR p.status!='completed' "
                     "OR p.verification_status!='passed' OR p.github_sync_status!='synced')", (task_id,)).fetchone():
            return {"reserved": False, "reason": "unfinished_dependency"}
        if c.execute("SELECT 1 FROM tool_operations WHERE task_id=? AND status='started'", (task_id,)).fetchone():
            return {"reserved": False, "reason": "unknown_operation"}
        if c.execute("SELECT 1 FROM tool_operations WHERE id=?", (operation_id,)).fetchone():
            return {"reserved": False, "reason": "resume_already_journaled"}
        now = time.time()
        c.execute("INSERT INTO tool_operations VALUES(?,?,?,?,?,?,?,?)", (
            operation_id, task_id, "local_codex_recovery", json.dumps({"owner": owner}), "started", None, now, now,
        ))
        c.execute("UPDATE tasks SET status='planning',execution_status='planning',owner=?,lease_until=?,updated=? WHERE id=?",
                  (owner, now + 600, now, task_id))
        store._event(c, task_id, "Автоматическое продолжение текущего задания зарезервировано; прежние файлы и журнал сохранены.", "automatic_resume_reserved")
    return {"reserved": True, "operation_id": operation_id}


def confirm_resume(store, task_id, owner, operation_id, pid):
    if pid <= 0:
        raise ValueError("invalid_pid")
    with store.db() as c:
        c.execute("BEGIN IMMEDIATE")
        op = c.execute("SELECT * FROM tool_operations WHERE id=?", (operation_id,)).fetchone()
        if (not op or op["tool"] != "local_codex_recovery" or op["task_id"] != task_id
                or json.loads(op["args"]).get("owner") != owner):
            raise RuntimeError("resume_identity_mismatch")
        if op["status"] == "done":
            result = json.loads(op["result"])
            if result.get("pid") != pid:
                raise RuntimeError("resume_pid_mismatch")
            return result
        task = c.execute("SELECT status,owner FROM tasks WHERE id=?", (task_id,)).fetchone()
        if task["status"] not in {"planning", "running"} or task["owner"] != owner:
            raise RuntimeError("resume_no_longer_reserved")
        result = {"pid": pid, "started": True}
        c.execute("UPDATE tool_operations SET status='done',result=?,updated=? WHERE id=?",
                  (json.dumps(result), time.time(), operation_id))
        c.execute("UPDATE tasks SET status='running',execution_status='running',lease_until=?,updated=? WHERE id=?",
                  (time.time() + 600, time.time(), task_id))
        store._event(c, task_id, "Агент автоматически возобновлён в прежней сессии; полная задача ещё не принята.", "automatic_resume_started")
    return result


def heartbeat(store, task_id, owner):
    # Only the local controller with an observed live CLI may call this.
    with store.db() as c:
        return bool(c.execute("UPDATE tasks SET lease_until=? WHERE id=? AND owner=? "
                              "AND status IN ('running','planning','verifying','reviewing')",
                              (time.time() + 600, task_id, owner)).rowcount)


def main():
    from orchestrator.settings import state_dir
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["inspect", "reconcile", "wait", "reserve", "confirm", "heartbeat"])
    parser.add_argument("task_id")
    parser.add_argument("--owner")
    parser.add_argument("--operation-id")
    parser.add_argument("--pid", type=int)
    parser.add_argument("--reason")
    parser.add_argument("--retry-at", type=float, default=0)
    args = parser.parse_args()
    store = Store(state_dir() / "coordinator.sqlite3")
    if args.command == "inspect":
        result = snapshot(store, args.task_id)
    elif args.command == "reconcile":
        result = reconcile(store, args.task_id)
    elif args.command == "wait":
        result = record_wait(store, args.task_id, args.reason, args.retry_at)
    elif args.command == "reserve":
        if not args.owner or not args.operation_id:
            parser.error("owner and operation-id required")
        result = reserve_resume(store, args.task_id, args.owner, args.operation_id)
    elif args.command == "confirm":
        if not args.owner or not args.operation_id or args.pid is None:
            parser.error("owner, operation-id and pid required")
        result = confirm_resume(store, args.task_id, args.owner, args.operation_id, args.pid)
    else:
        result = {"renewed": heartbeat(store, args.task_id, args.owner)}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
