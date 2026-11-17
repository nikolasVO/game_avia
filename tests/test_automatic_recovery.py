import json

import pytest

from orchestrator.recovery import (confirm_resume, publication_outcome, reconcile,
                                   record_wait, reserve_resume)
from orchestrator.store import Store
from scripts.cli_recovery_watchdog import failure_policy


ARGS = {"tag": "game-avia-test", "source": "a" * 40,
        "apk_sha256": "b" * 64, "aab_sha256": "c" * 64}


def missing(path):
    return (200, {"full_name": "nikolasVO/game_avia"}) if path == "repos/nikolasVO/game_avia" else (404, {})


def published(path):
    if path.endswith("/git/ref/tags/game-avia-test"):
        return 200, {"object": {"type": "commit", "sha": ARGS["source"]}}
    if "/releases/tags/" in path:
        return 200, {"tag_name": ARGS["tag"], "assets": [
            {"name": "test.apk", "digest": "sha256:" + ARGS["apk_sha256"]},
            {"name": "test.aab", "digest": "sha256:" + ARGS["aab_sha256"]},
        ]}
    return 200, {"full_name": "nikolasVO/game_avia"}


def test_quota_uses_structured_reset_and_never_retries_immediately():
    event = [{"type": "turn.failed", "error": {"message": "You've hit your usage limit"}}]
    result = failure_policy(event, [{"used_percent": 100, "resets_at": 10000}], 100)
    assert result == {"reason": "usage_limit", "retry_at": 10090}


def test_expired_reset_uses_bounded_backoff():
    event = [{"type": "turn.failed", "error": {"message": "usage limit"}}]
    assert failure_policy(event, [{"used_percent": 100, "resets_at": 1}], 100, 20)["retry_at"] == 21700


def test_transient_failure_and_auth_are_not_hot_loops():
    assert failure_policy([], [], 100)["retry_at"] == 400
    result = failure_policy([{"type": "error", "message": "authentication required"}], [], 100)
    assert result == {"reason": "auth_required", "retry_at": 21700}


@pytest.mark.parametrize("code", [401, 403, 429, 500])
def test_missing_repository_access_is_never_treated_as_missing_release(code):
    assert publication_outcome(ARGS, lambda path: (code, {})) is None


def test_absent_and_published_release_are_distinguished():
    assert publication_outcome(ARGS, missing)["outcome"] == "not_published"
    assert publication_outcome(ARGS, published)["outcome"] == "published"


def test_release_without_matching_source_or_hashes_stays_unknown():
    def bad(path):
        status, body = published(path)
        if "/git/ref/" in path:
            body["object"]["sha"] = "d" * 40
        return status, body
    assert publication_outcome(ARGS, bad) is None
    def bad_hash(path):
        status, body = published(path)
        if body.get("assets"):
            body["assets"][0]["digest"] = "sha256:" + "0" * 64
        return status, body
    assert publication_outcome(ARGS, bad_hash) is None


@pytest.fixture
def task(tmp_path):
    store = Store(tmp_path / "state.sqlite3")
    t = store.create_task("development", "manual")
    store.transition(t["id"], "blocked")
    return store, t["id"]


def test_reconciliation_resolves_only_proven_operation_not_task(task):
    store, tid = task
    store.prepare_tool(tid, "publication", "github_prerelease", ARGS)
    result = reconcile(store, tid, missing)
    assert result["resolved"] == [{"id": "publication", "outcome": "not_published"}]
    assert store.get_task(tid)["status"] == "blocked"
    with store.db() as c:
        saved = c.execute("SELECT status,result FROM tool_operations WHERE id='publication'").fetchone()
    assert saved["status"] == "done" and json.loads(saved["result"])["new_operation_id_required"]


def test_unknown_effect_is_never_cleared_or_resumed(task):
    store, tid = task
    store.prepare_tool(tid, "migration", "unrecognized_effect", {})
    assert reconcile(store, tid, missing)["unresolved"] == [{"id": "migration", "tool": "unrecognized_effect"}]
    assert reserve_resume(store, tid, "owner", "resume")["reason"] == "unknown_operation"


@pytest.mark.parametrize("status", ["paused", "cancelled", "completed", "failed"])
def test_explicit_stop_or_terminal_state_is_protected(task, status):
    store, tid = task
    store.transition(tid, status)
    assert not reserve_resume(store, tid, "owner", "resume")["reserved"]
    assert record_wait(store, tid, "usage_limit", 10000)["status"] == "protected_task_state"
    assert store.get_task(tid)["status"] == status


def test_reservation_fences_duplicate_and_confirm_does_not_start_second_process(task):
    store, tid = task
    assert reserve_resume(store, tid, "owner", "resume")["reserved"]
    assert not reserve_resume(store, tid, "owner", "resume2")["reserved"]
    assert confirm_resume(store, tid, "owner", "resume", 123)["started"]
    assert confirm_resume(store, tid, "owner", "resume", 123)["pid"] == 123
    with pytest.raises(RuntimeError, match="pid_mismatch"):
        confirm_resume(store, tid, "owner", "resume", 124)


def test_successor_dependency_cannot_be_bypassed_by_recovery(task):
    store, parent = task
    child = store.create_task("stage3", "manual")["id"]
    store.transition(child, "blocked")
    with store.db() as c:
        c.execute("INSERT INTO dependencies VALUES(?,?)", (child, parent))
    assert reserve_resume(store, child, "owner", "resume")["reason"] == "unfinished_dependency"


def test_repeated_wait_deduplicates_owner_notifications(task):
    store, tid = task
    record_wait(store, tid, "usage_limit", 10000)
    record_wait(store, tid, "usage_limit", 10000)
    with store.db() as c:
        assert c.execute("SELECT count(*) FROM events WHERE task_id=? AND type='automatic_recovery_wait'", (tid,)).fetchone()[0] == 1


@pytest.mark.parametrize("paid_route", [False, True])
def test_controller_waits_for_reset_then_resumes_same_worktree_once(task, tmp_path, monkeypatch, paid_route):
    from scripts import cli_recovery_watchdog as controller
    from orchestrator.recovery import snapshot
    store, tid = task
    runtime = tmp_path / "runtime"
    runtime.mkdir()
    events = runtime / "previous-events.jsonl"
    events.write_text(json.dumps({"type": "turn.failed", "error": {"message": "usage limit"}}) + "\n")
    rollout = runtime / "rollout.jsonl"
    rollout.write_text(json.dumps({"payload": {"rate_limits": {"limit_id": "codex",
                       "primary": {"used_percent": 100, "resets_at": 10000}}}}) + "\n")
    process_file = runtime / "process.json"
    original = {"server_task_id": tid, "worktree": str(tmp_path), "private_events": str(events),
                "cli": "codex", "pid": 100, "brief_sha256": "preserve-original", "continuation": 2}
    process_file.write_text(json.dumps(original))
    unfinished = tmp_path / "unfinished-game.gd"
    unfinished.write_text("preserve existing uncommitted game code")
    config = {"runtime": str(runtime), "implementation_process_file": str(process_file),
              "allowed_tasks": [tid], "owners": {tid: "owner"}, "session_id": "same-session",
              "rollout_file": str(rollout), "launch_lock": str(runtime / "writer.lock"),
              "resume_prompt": "Continue {task_id}, owner {owner}; preserve current brief."}
    if paid_route:
        handoff = runtime / "handoff.txt"
        handoff.write_text("Full preserved owner brief; newly authorized provider work.")
        credentials = runtime / "credentials.json"
        credentials.write_text(json.dumps({"OPENLUX_CODEX": {
            "base_url": "https://api.example.test/v1", "api_key": "private-test-credential-123"}}))
        config.update(paid_work_authorized=True,
                      api_routes=[{"id": "openlux", "env_prefix": "OPENLUX_CODEX", "model": "gpt-6.1-sol"}],
                      provider_credentials_file=str(credentials), provider_handoff_file=str(handoff))
    monkeypatch.setattr(controller, "cli_is_running", lambda *args: False)
    def remote(config, command, task_id, *args):
        values = dict(zip(args[::2], args[1::2]))
        if command == "inspect":
            return snapshot(store, task_id)
        if command == "wait":
            return record_wait(store, task_id, values["--reason"], float(values["--retry-at"]))
        if command == "reserve":
            return reserve_resume(store, task_id, values["--owner"], values["--operation-id"])
        if command == "confirm":
            return confirm_resume(store, task_id, values["--owner"], values["--operation-id"], int(values["--pid"]))
        raise AssertionError(command)
    monkeypatch.setattr(controller, "remote", remote)
    monkeypatch.setattr(controller.subprocess, "check_output", lambda *args, **kw: "unchanged-head\n")
    spawned = []
    class Child:
        pid = 234
    def popen(args, **kwargs):
        spawned.append(args)
        assert tid in kwargs["stdin"].read().decode()
        if paid_route:
            assert "resume" not in args and "same-session" not in args
            assert args[-1] == "-"
            assert kwargs["env"]["GAME_AVIA_ROUTE_API_KEY"] == "private-test-credential-123"
            assert "private-test-credential-123" not in str(args)
        else:
            assert args[-2:] == ["same-session", "-"]
        return Child()
    monkeypatch.setattr(controller.subprocess, "Popen", popen)
    waiting = controller.step(config, {}, now=100, allow_launch=not paid_route)
    assert waiting["retry_at"] == (100 if paid_route else 10090) and not spawned
    if not paid_route:
        assert not controller.step(config, waiting, now=10089).get("pid")
    started = controller.step(config, waiting, now=101 if paid_route else 10091)
    assert started["confirmed"] and started["pid"] == 234 and len(spawned) == 1
    assert json.loads(process_file.read_text())["brief_sha256"] == "preserve-original"
    assert unfinished.read_text() == "preserve existing uncommitted game code"
    assert store.get_task(tid)["status"] == "running"
