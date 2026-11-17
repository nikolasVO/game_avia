import pytest
from orchestrator.store import Store
from workers.coding.routes import Registry,RouteFailure
from workers.coding.agent import Agent
from workers.coding.tools import Tools

async def test_live_task_identity_survives_mocked_provider_failure(tmp_path,monkeypatch):
    s=Store(tmp_path/"s.db")
    for p in ("OPENLUX_CODEX","WHATSTOKEN_CODEX"):monkeypatch.setenv(p+"_API_KEY","sk-"+"x"*30)
    reg=Registry(s)
    rows=list(reg.candidates(bootstrap=True))
    for p in ("OPENLUX","WHATSTOKEN"):
        reg.ready(next(r for r in rows if r["provider"]==p),["chat_tools","tool_result_continuation"])
    task=s.create_task("read existing evidence",kind="diagnostic")
    work=tmp_path/"work";work.mkdir();(work/"evidence.txt").write_text("preserved")
    agent=Agent(reg,s);calls=[]
    async def fake_chat(route,messages,tid,**kwargs):
        calls.append((route["provider"],tid))
        if route["provider"]=="OPENLUX":raise RouteFailure("blocked_balance","billing")
        if len(calls)==2:
            return {"choices":[{"message":{"role":"assistant","content":None,"tool_calls":[{"id":"proof1","type":"function","function":{"name":"read_file","arguments":'{"path":"evidence.txt"}'}}]}}]}
        assert messages[-1]["role"]=="tool" and "preserved" in messages[-1]["content"]
        return {"choices":[{"message":{"role":"assistant","content":"verified"}}]}
    agent.chat=fake_chat
    result=await agent.run(task,work)
    assert result["route"].startswith("WHATSTOKEN_CODEX")
    assert {t for _,t in calls}=={task["id"]}
    assert (work/"evidence.txt").read_text()=="preserved"
    assert len(calls)==3

def test_intentional_same_write_has_distinct_tool_identity(tmp_path):
    s=Store(tmp_path/"s.db");work=tmp_path/"work";work.mkdir();t=Tools(s,"task",work)
    for i,value in enumerate(("A","B","A")):
        t.run("write_file",{"path":"file.txt","content":value},operation_id=str(i))
    assert (work/"file.txt").read_text()=="A"

def test_reads_are_not_cached_across_file_changes(tmp_path):
    s=Store(tmp_path/"s.db");work=tmp_path/"work";work.mkdir();t=Tools(s,"task",work)
    p=work/"file.txt";p.write_text("A")
    assert t.run("read_file",{"path":"file.txt"})["content"]=="A"
    p.write_text("B")
    assert t.run("read_file",{"path":"file.txt"})["content"]=="B"

def test_cancelled_task_cannot_write(tmp_path):
    s=Store(tmp_path/"s.db");task=s.create_task("write");s.claim("worker");s.transition(task["id"],"cancelled")
    work=tmp_path/"work";work.mkdir()
    with pytest.raises(RuntimeError):Tools(s,task["id"],work,"worker").run("write_file",{"path":"forbidden.txt","content":"x"})
    assert not (work/"forbidden.txt").exists()


async def test_closed_bootstrap_cannot_issue_another_paid_probe(tmp_path,monkeypatch):
    from scripts.live_agent_smoke import cloud_smoke,codex_smoke
    monkeypatch.setenv("GAME_AVIA_STATE_DIR",str(tmp_path))
    s=Store(tmp_path/"coordinator.sqlite3");s.kv("bootstrap_finished_at","1")
    for probe in (cloud_smoke("OPENLUX_CODEX","gpt"),codex_smoke("WHATSTOKEN_CODEX")):
        with pytest.raises(RouteFailure,match="bootstrap_closed"):
            await probe
    with s.db() as c:assert c.execute("SELECT COUNT(*) FROM usage_ledger").fetchone()[0]==0
