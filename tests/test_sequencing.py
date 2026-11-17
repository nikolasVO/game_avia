import concurrent.futures

import pytest

from orchestrator.sequencing import confirm, inspect, reserve
from orchestrator.store import Store


@pytest.fixture
def sequence(tmp_path):
    s = Store(tmp_path / "tasks.sqlite3")
    with s.db() as c:
        parent = s._task(c, "current brief", "manual", {})
        child = s._task(c, "next brief", "manual", {
            "brief_sha256": "full-brief-hash", "brief_bytes": 56012,
            "sequential_handoff": {"enabled": True, "predecessor": parent},
        })
        c.execute("INSERT INTO dependencies VALUES(?,?)", (child, parent))
        c.execute("UPDATE tasks SET status='blocked',result='waiting_for_verified_predecessor' WHERE id=?", (child,))
    return s, parent, child


@pytest.mark.parametrize("status,verification,sync", [
    ("running", "passed", "synced"), ("blocked", "passed", "synced"),
    ("failed", "passed", "synced"), ("paused", "passed", "synced"),
    ("cancelled", "passed", "synced"), ("completed", "unverified", "synced"),
    ("completed", "passed", "pending"),
])
def test_incomplete_or_unverified_predecessor_never_releases(sequence, status, verification, sync):
    s, parent, child = sequence
    with s.db() as c:
        c.execute("UPDATE tasks SET status=?,verification_status=?,github_sync_status=? WHERE id=?",
                  (status, verification, sync, parent))
    assert not reserve(s, child, "dispatcher", "launch")['reserved']
    assert s.get_task(child)["status"] == "blocked"
    with s.db() as c:
        assert c.execute("SELECT count(*) FROM tool_operations").fetchone()[0] == 0


def accept(s, parent):
    with s.db() as c:
        c.execute("UPDATE tasks SET status='completed',verification_status='passed',github_sync_status='synced' WHERE id=?", (parent,))


def test_single_claim_under_concurrent_dispatchers(sequence):
    s, parent, child = sequence
    accept(s, parent)
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        outcomes = list(pool.map(lambda n: reserve(s, child, f"owner{n}", f"launch{n}"), [1, 2]))
    assert sum(r["reserved"] for r in outcomes) == 1
    assert s.get_task(child)["status"] == "planning"


def test_reserved_unknown_launch_is_not_retried_and_confirmation_is_idempotent(sequence):
    s, parent, child = sequence
    accept(s, parent)
    assert reserve(s, child, "dispatcher", "launch")["reserved"]
    assert not reserve(s, child, "dispatcher", "launch")["reserved"]
    assert not reserve(s, child, "other", "other-launch")["reserved"]
    assert confirm(s, child, "dispatcher", "launch", 123)["status"] == "running"
    assert confirm(s, child, "dispatcher", "launch", 123)["pid"] == 123
    with pytest.raises(RuntimeError, match="pid_mismatch"):
        confirm(s, child, "dispatcher", "launch", 124)
    assert s.get_task(child)["status"] == "running"


def test_without_dependency_or_with_cancelled_successor_never_releases(sequence):
    s, parent, child = sequence
    accept(s, parent)
    with s.db() as c:
        c.execute("DELETE FROM dependencies WHERE task_id=?", (child,))
    assert not inspect(s, child)["ready"]
    with s.db() as c:
        c.execute("INSERT INTO dependencies VALUES(?,?)", (child, parent))
        c.execute("UPDATE tasks SET status='cancelled' WHERE id=?", (child,))
    assert not reserve(s, child, "dispatcher", "launch")["reserved"]


def test_all_dependencies_must_be_verified(sequence):
    s, parent, child = sequence
    accept(s, parent)
    second = s.create_task("another required check", "manual")["id"]
    with s.db() as c:
        c.execute("INSERT INTO dependencies VALUES(?,?)", (child, second))
    assert not inspect(s, child)["ready"]
    accept(s, second)
    assert inspect(s, child)["ready"]


def test_bounded_worker_cannot_claim_waiting_or_reserved_successor(sequence):
    s, parent, child = sequence
    accept(s, parent)
    assert s.claim("bounded-worker") is None
    assert reserve(s, child, "dispatcher", "launch")["reserved"]
    assert s.claim("bounded-worker") is None


def test_missing_dependency_record_cannot_be_silently_ignored(sequence):
    s, parent, child = sequence
    accept(s, parent)
    with s.db() as c:
        c.execute("INSERT INTO dependencies VALUES(?,?)", (child, "missing-parent"))
    assert not inspect(s, child)["ready"]
    assert not reserve(s, child, "dispatcher", "launch")["reserved"]
