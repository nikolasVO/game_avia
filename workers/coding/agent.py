import asyncio
import json
import time
import uuid
import httpx
import os
from .routes import RouteFailure, classify
from .tools import Tools,TOOLS

class Agent:
    def __init__(self,registry,store):
        self.registry=registry;self.store=store
    def reserve(self,tid,route,max_tokens=1024):
        # Atomic daily/request budget, not a monetary limit. Reserved tokens cover timeouts.
        with self.store.db() as c:
            c.execute("BEGIN IMMEDIATE")
            start=time.time()-86400
            r=c.execute("SELECT COALESCE(SUM(requests),0),COALESCE(SUM(tokens),0) FROM usage_ledger WHERE created>?",(start,)).fetchone()
            if r[0]>=int(os.getenv("GAME_AVIA_DAILY_REQUESTS","12")) or r[1]+max_tokens>int(os.getenv("GAME_AVIA_DAILY_TOKENS","24576")):
                raise RouteFailure("request_budget_exhausted","stop")
            uid=uuid.uuid4().hex
            c.execute("INSERT INTO usage_ledger VALUES(?,?,?,?,?,?,?)",(uid,tid,route,1,max_tokens,"cost_unknown_reserved",time.time()))
            return uid
    async def chat(self,route,messages,tid,tools=TOOLS,max_tokens=1024):
        self.reserve(tid,route["id"],max_tokens)
        key=os.getenv(route["env_prefix"]+"_API_KEY","")
        payload={"model":route["wire"],"messages":messages,"max_tokens":max_tokens,"tools":tools,"stream":False}
        try:
            async with httpx.AsyncClient(timeout=httpx.Timeout(60,connect=10)) as client:
                r=await client.post(route["base_url"]+"/chat/completions",headers={"Authorization":"Bearer "+key},json=payload)
            d=r.json()
        except (httpx.HTTPError,ValueError):
            raise RouteFailure("transient","route",30) from None
        if r.status_code>=400 or d.get("error") or not d.get("choices"):
            raise classify(r.status_code,d)
        return d
    async def run(self,task,root,family="gpt",max_calls=4,bootstrap=False):
        tid=task["id"];deadline=time.monotonic()+180
        tools=Tools(self.store,tid,root)
        messages=[{"role":"system","content":"You are a bounded coding worker. Work only in provided workspace with tools. Preserve existing files. Never ask for or output secrets. Implement the request and run tests. Do not claim tests passed unless tool results prove it. Return a concise result. Tools are restricted; no publishing or external messaging."},
                  {"role":"user","content":task["goal"]}]
        calls=0;attempts=0
        for route in self.registry.candidates(family,bootstrap=bootstrap):
            if calls>=max_calls or attempts>=32 or time.monotonic()>deadline: break
            attempts+=1
            self.store.event(tid,"Маршрут "+route["id"]+"; протокол chat_completions tool-loop.","route")
            try:
                while calls<max_calls and time.monotonic()<deadline:
                    calls+=1
                    d=await self.chat(route,messages,tid)
                    msg=d["choices"][0]["message"]
                    messages.append({k:v for k,v in msg.items() if k in ("role","content","tool_calls")})
                    tc=msg.get("tool_calls",[])
                    if not tc:
                        return {"text":msg.get("content",""),"route":route["id"],"calls":calls,"completed_claim_only":True}
                    if len(tc)>8: raise RouteFailure("too_many_tools","stop")
                    for call in tc:
                        try:
                            args=json.loads(call["function"]["arguments"])
                            out=tools.run(call["function"]["name"],args)
                        except (ValueError,KeyError,TypeError) as e: out={"error":type(e).__name__}
                        messages.append({"role":"tool","tool_call_id":call["id"],"content":json.dumps(out)})
                    self.registry.ready(route,["chat_tools"])
                raise RouteFailure("task_request_limit","stop")
            except RouteFailure as e:
                self.registry.fail(route,e)
                self.store.event(tid,"Отказ "+route["id"]+": "+e.code+"; изменения и журнал сохранены.","fallback")
                if e.scope=="stop":raise
                # No provider-specific opaque state/hidden reasoning is carried over.
                continue
        raise RouteFailure("no_agent_route_or_budget","stop")

