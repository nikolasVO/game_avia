import json
import pytest
from orchestrator.store import Store
from workers.coding.routes import Registry,classify
from workers.coding.tools import Tools

def registry(tmp_path,monkeypatch):
    for p in ("OPENLUX","WHATSTOKEN","XINFENG","XYC","SIX666","JUNWUSHEN","TOPGO"):
        monkeypatch.setenv(p+"_CODEX_API_KEY","sk-"+"a"*30)
    return Registry(Store(tmp_path/"s.db"))
def test_deterministic_wire_order(tmp_path,monkeypatch):
    r=registry(tmp_path,monkeypatch)
    rows=list(r.candidates(bootstrap=True))
    assert [x["provider"] for x in rows[:4]]==["OPENLUX","WHATSTOKEN","XINFENG","XYC"]
    assert rows[1]["wire"]=="gpt-6.1-sol-pro"
    assert rows[4]["logical"]=="gpt-6-sol"
    assert not list(r.candidates())
def test_balance_blocks_whole_group(tmp_path,monkeypatch):
    r=registry(tmp_path,monkeypatch);route=next(r.candidates(bootstrap=True))
    r.fail(route,classify(200,{"error":"insufficient balance"}))
    assert all(x["provider"]!="OPENLUX" for x in r.candidates(bootstrap=True))
    assert next(r.candidates(bootstrap=True))["provider"]=="WHATSTOKEN"
def test_ready_evidence(tmp_path,monkeypatch):
    r=registry(tmp_path,monkeypatch);route=next(r.candidates(bootstrap=True))
    r.ready(route,["chat_tools"])
    assert [x["id"] for x in r.candidates()]==[route["id"]]
def test_403_is_not_balance():
    assert classify(403,{}).code=="forbidden"
def test_tool_escape_and_replay(tmp_path):
    s=Store(tmp_path/"s.db");root=tmp_path/"work";root.mkdir()
    tools=Tools(s,"task1",root)
    with pytest.raises(ValueError):tools.run("read_file",{"path":"../secret"})
    a=tools.run("write_file",{"path":"hello.py","content":"ok"})
    (root/"hello.py").unlink()
    assert tools.run("write_file",{"path":"hello.py","content":"ok"})==a
    assert not (root/"hello.py").exists()

