import concurrent.futures
import sqlite3
import time
import pytest
from orchestrator.store import Store

@pytest.fixture
def store(tmp_path):return Store(tmp_path/"state.db")
def test_transaction_and_update_dedup(store):
    tid=store.ingest(17,goal="test")
    assert tid and store.ingest(17,goal="duplicate") is None
    with store.db() as c:
        assert c.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]==1
        assert c.execute("SELECT COUNT(*) FROM notification_outbox").fetchone()[0]==1
    assert Store(store.path).get_task(tid)["goal"]=="test"
def test_claim_race(store):
    store.create_task("one")
    with concurrent.futures.ThreadPoolExecutor(2) as p:
        claims=list(p.map(store.claim,["a","b"]))
    assert sum(x is not None for x in claims)==1
def test_unknown_tool_requires_reconciliation(store):
    tid=store.create_task("one")["id"]
    store.claim("a",seconds=-1)
    store.prepare_tool(tid,"op1","write_file",{"path":"a"})
    assert store.recover()==1
    assert store.get_task(tid)["status"]=="blocked"
    with pytest.raises(RuntimeError):store.prepare_tool(tid,"op1","write_file",{"path":"a"})
def test_backup_restore(store,tmp_path):
    t=store.create_task("saved")
    dest=tmp_path/"backup.db";store.backup(dest)
    assert Store(dest).get_task(t["id"])["goal"]=="saved"
    with sqlite3.connect(dest) as c: assert c.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
def test_gpu_fencing(store):
    fence=store.acquire_gpu("a",seconds=-1)
    next_fence=store.acquire_gpu("b")
    assert next_fence>fence
    assert not store.renew_gpu("a",fence)
    store.release_gpu("a",fence)
    assert store.acquire_gpu("c") is None

