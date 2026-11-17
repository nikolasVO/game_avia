import hashlib

import pytest

from scripts import sequential_cli_handoff as dispatcher


def test_active_writer_prevents_even_reserving_successor(monkeypatch, tmp_path):
    monkeypatch.setattr(dispatcher, "cli_is_running", lambda *args: True)
    def unexpected(*args):
        raise AssertionError("must not reserve while current writer is alive")
    monkeypatch.setattr(dispatcher, "remote", unexpected)
    assert dispatcher.step({"worktree": "game", "session_id": "same-session"}, tmp_path)["status"] == "waiting_for_current_cli"


def test_incomplete_predecessor_cannot_launch(monkeypatch, tmp_path):
    monkeypatch.setattr(dispatcher, "cli_is_running", lambda *args: False)
    calls = []
    def remote(config, command, *args):
        calls.append(command)
        return {"ready": False}
    monkeypatch.setattr(dispatcher, "remote", remote)
    assert dispatcher.step({"worktree": "game", "session_id": "session"}, tmp_path)["status"] == "waiting_for_verified_predecessor"
    assert calls == ["inspect"]


def test_tampered_brief_cannot_reserve_launch(monkeypatch, tmp_path):
    monkeypatch.setattr(dispatcher, "cli_is_running", lambda *args: False)
    calls = []
    def remote(config, command, *args):
        calls.append(command)
        return {"ready": True, "brief_bytes": 7, "brief_sha256": hashlib.sha256(b"original").hexdigest()}
    monkeypatch.setattr(dispatcher, "remote", remote)
    brief = tmp_path / "brief.txt"
    brief.write_bytes(b"changed")
    config = {"worktree": "game", "session_id": "session", "brief_file": str(brief),
              "brief_bytes": 7, "brief_sha256": hashlib.sha256(b"original").hexdigest()}
    with pytest.raises(RuntimeError, match="integrity_failed"):
        dispatcher.step(config, tmp_path)
    assert calls == ["inspect"]


def test_lost_confirmation_retries_same_pid_without_second_launch(monkeypatch, tmp_path):
    import json
    monkeypatch.setattr(dispatcher, "cli_is_running", lambda *args: False)
    monkeypatch.setattr(dispatcher.time, "sleep", lambda _: None)
    raw = "полный следующий промпт".encode()
    brief = tmp_path / "brief.txt"
    brief.write_bytes(raw)
    process_file = tmp_path / "process.json"
    process_file.write_text(json.dumps({"pid": 100, "continuation": 2}))
    config = {"worktree": str(tmp_path), "session_id": "session", "brief_file": str(brief),
              "brief_bytes": len(raw), "brief_sha256": hashlib.sha256(raw).hexdigest(),
              "owner": "dispatcher", "operation_id": "one-launch", "successor_task": "next",
              "prompt_prefix": "next {successor_task}: ", "cli": "codex",
              "implementation_process_file": str(process_file)}
    calls, spawned = [], []
    def remote(config, command, *args):
        calls.append((command, args))
        if command == "inspect":
            return {"ready": True, "brief_bytes": len(raw), "brief_sha256": config["brief_sha256"]}
        if command == "reserve":
            return {"reserved": True}
        raise RuntimeError("reply lost")
    monkeypatch.setattr(dispatcher, "remote", remote)
    class Process:
        pid = 234
    def popen(*args, **kwargs):
        spawned.append(args)
        assert kwargs["stdin"].read() == b"next next: " + raw
        return Process()
    monkeypatch.setattr(dispatcher.subprocess, "Popen", popen)
    result = dispatcher.step(config, tmp_path)
    assert result["status"] == "launched" and not result["confirmed"]
    assert len(spawned) == 1
    confirmations = [args for name, args in calls if name == "confirm"]
    assert len(confirmations) == 3 and all(args[-1] == "234" for args in confirmations)
    assert json.loads(process_file.read_text())["pid"] == 234
