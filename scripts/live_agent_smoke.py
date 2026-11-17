"""Bounded paid bootstrap: one official Codex route and explicit cloud tool-loop fallback."""
import asyncio
import json
import os
import tempfile
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.coding.agent import Agent
from workers.coding.routes import Registry,RouteFailure
from workers.coding.codex_runtime import codex_exec

async def cloud_smoke(prefix,family):
    s=Store(state_dir()/"coordinator.sqlite3")
    if s.kv("bootstrap_finished_at"):raise RouteFailure("bootstrap_closed_requires_new_explicit_budget","stop")
    reg=Registry(s)
    task=s.create_task("Use read_file to read evidence.txt. Then reply exactly AVIA_SMOKE_42. Do not write files.",kind="diagnostic")
    s.transition(task["id"],"paused","Живая диагностическая проба.")
    with tempfile.TemporaryDirectory(prefix="agent-smoke-",dir="/srv/game-avia/worktrees") as d:
        Path(d,"evidence.txt").write_text("The required proof is AVIA_SMOKE_42.")
        candidates=[r for r in reg.candidates(family,bootstrap=True) if r["env_prefix"]==prefix]
        if not candidates:return {"prefix":prefix,"status":"no_eligible_route"}
        route=candidates[0]
        original=reg.candidates
        reg.candidates=lambda *a,**k:iter([route])
        try:
            result=await Agent(reg,s).run(task,d,family=family,max_calls=2,bootstrap=True)
            with s.db() as c:
                used=c.execute("SELECT COUNT(*) FROM tool_operations WHERE task_id=? AND status='done' AND tool='read_file'",(task["id"],)).fetchone()[0]
            passed=used>0 and "AVIA_SMOKE_42" in result["text"]
            if passed:reg.ready(route,["chat_tools","tool_result_continuation"])
            s.transition(task["id"],"completed" if passed else "failed","Живая проверка tool-loop: "+str(passed))
            return {"prefix":prefix,"route":route["id"],"status":"passed" if passed else "failed","real_read_tool_calls":used,"calls":result["calls"],"protocol":"chat_completions","codex_runtime":False}
        except RouteFailure as e:
            s.transition(task["id"],"blocked",e.code)
            return {"prefix":prefix,"status":"blocked","error":e.code}

async def codex_smoke(prefix):
    import socket
    import httpx
    import uvicorn
    from fastapi import FastAPI,Request,Response
    s=Store(state_dir()/"coordinator.sqlite3")
    if s.kv("bootstrap_finished_at"):raise RouteFailure("bootstrap_closed_requires_new_explicit_budget","stop")
    cfg=Registry(s).config["providers"][prefix]
    base=os.getenv(prefix+"_BASE_URL",cfg["base_url"]).rstrip("/")
    key=os.environ[prefix+"_API_KEY"]
    task=s.create_task("Official Codex runtime read-tool proof",kind="diagnostic")
    count=0
    errors=[]
    app=FastAPI()
    @app.post("/v1/responses")
    async def proxy(request:Request):
        nonlocal count
        if count>=2:return Response('{"error":{"message":"bootstrap_request_cap"}}',status_code=429,media_type="application/json")
        count+=1
        Agent(Registry(s),s).reserve(task["id"],prefix+":responses",2048)
        body=json.dumps({**(await request.json()),"max_output_tokens":2048}).encode()
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(90,connect=10)) as client:
                r=await client.post(base+"/responses",content=body,headers={"Authorization":"Bearer "+key,"Content-Type":"application/json"})
            if r.status_code>=400:
                from workers.coding.routes import classify
                errors.append(classify(r.status_code,r.text).code)
            return Response(r.content,status_code=r.status_code,media_type=r.headers.get("content-type","application/json"))
        except httpx.HTTPError:
            errors.append("transport");return Response("{}",status_code=502,media_type="application/json")
    sock=socket.socket();sock.bind(("127.0.0.1",0));port=sock.getsockname()[1]
    server=uvicorn.Server(uvicorn.Config(app,log_level="critical",access_log=False))
    serving=asyncio.create_task(server.serve(sockets=[sock]))
    while not server.started:await asyncio.sleep(.05)
    try:
        with tempfile.TemporaryDirectory(prefix="codex-smoke-",dir="/srv/game-avia/worktrees") as d:
            Path(d,"evidence.txt").write_text("AVIA_RUNTIME_PROOF=42\n")
            result=await codex_exec("/srv/game-avia/tools/codex/node_modules/.bin/codex",
                f"http://127.0.0.1:{port}/v1","local-proxy-only", cfg["models"]["gpt-6.1-sol"],d,
                "Use one shell command to read evidence.txt. Do not modify files. Reply AVIA_RUNTIME_PROOF=42.",timeout=120)
        tool=any(i["item_type"]=="command_execution" and i["exit_code"]==0 for i in result["items"])
        passed=result["status"]=="completed" and tool
        report={"prefix":prefix,"protocol":"responses","official_codex_runtime":True,"status":"passed" if passed else "blocked","requests":count,"tool_completed":tool,"runtime":result,"error_codes":errors}
        s.transition(task["id"],"completed" if passed else "blocked","Official Codex runtime: "+report["status"])
        s.kv(prefix+"_codex_evidence",json.dumps(report))
        return report
    finally:
        server.should_exit=True;await serving

async def main():
    load_environment()
    import argparse
    p=argparse.ArgumentParser();p.add_argument("kind",choices=["codex","chat"]);p.add_argument("prefix");p.add_argument("--family",default="gpt")
    a=p.parse_args()
    r=await(codex_smoke(a.prefix) if a.kind=="codex" else cloud_smoke(a.prefix,a.family))
    print(json.dumps(r,ensure_ascii=False,indent=2))
    Path("/srv/game-avia/state/"+a.prefix+"-"+a.kind+"-smoke.json").write_text(json.dumps(r,indent=2))
if __name__=="__main__":asyncio.run(main())

