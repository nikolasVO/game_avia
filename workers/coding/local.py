import json
import os
import time
import httpx
from workers.coding.tools import Tools,TOOLS
from workers.assets.pipeline import gpu_guard,disk_guard

async def local_smoke(store,root):
    from pathlib import Path
    task=store.create_task("Local tool-use smoke",kind="diagnostic")
    store.transition(task["id"],"paused","Проверка local worker.")
    fence=store.acquire_gpu("local-smoke",seconds=240)
    if fence is None:return {"status":"blocked","reason":"gpu_busy"}
    model=os.getenv("LOCAL_CODE_MODEL","qwen3.5:27b-q4_K_M")
    base=os.getenv("OLLAMA_BASE_URL","http://127.0.0.1:11434").rstrip("/")
    try:
        disk_guard(root)
        gpu_guard(22000)
        workspace=Path(root)/"worktrees/local-smoke"
        workspace.mkdir(exist_ok=True)
        (workspace/"evidence.txt").write_text("AVIA_LOCAL_42")
        tools=Tools(store,task["id"],workspace)
        messages=[{"role":"user","content":"Use read_file to read evidence.txt. Then reply AVIA_LOCAL_42. Do not write files."}]
        used=0
        async with httpx.AsyncClient(timeout=httpx.Timeout(180,connect=10)) as client:
            for _ in range(2):
                r=await client.post(base+"/api/chat",json={"model":model,"messages":messages,"tools":TOOLS,"stream":False,"think":False,"keep_alive":"2m","options":{"num_predict":256,"num_ctx":4096,"temperature":0}})
                r.raise_for_status();d=r.json();msg=d["message"];messages.append(msg)
                calls=msg.get("tool_calls",[])
                if not calls:
                    passed=used>0 and "AVIA_LOCAL_42" in msg.get("content","")
                    store.transition(task["id"],"completed" if passed else "failed","Local tool-use: "+str(passed))
                    return {"status":"passed" if passed else "failed","model":model,"real_tool_calls":used,"eval_count":d.get("eval_count"),"scope":"bounded code/log/document tasks only"}
                for call in calls[:4]:
                    fn=call["function"];args=fn["arguments"]
                    if isinstance(args,str):args=json.loads(args)
                    out=tools.run(fn["name"],args);used+=1
                    messages.append({"role":"tool","tool_name":fn["name"],"content":json.dumps(out)})
        store.transition(task["id"],"failed","No tool-result continuation within call cap.")
        return {"status":"failed","reason":"no_continuation"}
    except (httpx.HTTPError,RuntimeError,ValueError) as e:
        store.transition(task["id"],"blocked",type(e).__name__)
        return {"status":"blocked","reason":type(e).__name__}
    finally:
        try:
            async with httpx.AsyncClient(timeout=20) as client:
                await client.post(base+"/api/generate",json={"model":model,"keep_alive":0})
        finally:store.release_gpu("local-smoke",fence)

