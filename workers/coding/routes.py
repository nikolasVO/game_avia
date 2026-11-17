import json
import os
import time
from pathlib import Path
import yaml

class RouteFailure(Exception):
    def __init__(self, code, scope="route", retry_after=60):
        super().__init__(code); self.code=code; self.scope=scope; self.retry_after=retry_after

def classify(status, body):
    text=str(body).lower()
    if any(x in text for x in ("insufficient balance","insufficient_quota","quota exhausted","insufficient_user_quota","余额不足","balance is insufficient")):
        return RouteFailure("blocked_balance","billing",3600)
    if status==401 or "invalid_api_key" in text: return RouteFailure("disabled_auth","billing",86400)
    if any(x in text for x in ("content_policy_violation","content_filter","safety refusal")):
        return RouteFailure("policy_refusal","stop",86400)
    if status==429: return RouteFailure("cooldown","billing",60)
    if status==403: return RouteFailure("forbidden","route",300)
    if status in (404,405) or "get_channel_failed" in text: return RouteFailure("capability_unavailable","route",3600)
    if status>=500: return RouteFailure("transient","route",30)
    return RouteFailure("invalid_response","route",300)

class Registry:
    def __init__(self, store, config=None):
        self.store=store
        self.config=yaml.safe_load(Path(config or Path(__file__).resolve().parents[2]/"config/providers.yaml").read_text())
    def candidates(self,family="gpt",bootstrap=False):
        cfg=self.config
        for pool in (cfg[family+"_primary"],cfg[family+"_reserve"]):
            for logical in cfg["gpt_models" if family=="gpt" else "claude_models"]:
                for provider in pool:
                    prefix=provider+("_CODEX" if family=="gpt" else "_CLAUDE")
                    group=cfg["providers"].get(prefix,{})
                    if logical not in group.get("models",{}): continue
                    key=os.getenv(prefix+"_API_KEY","")
                    if len(key)<15 or key in ("sk-","CHANGE_ME"): continue
                    route={**group,"id":prefix+":"+logical,"logical":logical,"wire":group["models"][logical],
                           "base_url":os.getenv(prefix+"_BASE_URL",group["base_url"]).rstrip("/")}
                    with self.store.db() as c:
                        rows=c.execute("SELECT * FROM provider_routes WHERE id IN (?,?)",(route["id"],"scope:"+group["billing_scope"])).fetchall()
                    blocked=False
                    state="agent_ready" if self.store.kv("capability:"+route["id"]) else group["state"]
                    for r in rows:
                        if r["state"]=="agent_ready" and r["id"]==route["id"]: state="agent_ready"
                        elif r["state"] in ("blocked_balance","disabled_auth","quarantined","cooldown","transient","capability_unavailable","forbidden","invalid_response"):
                            if r["until"]>time.time(): blocked=True
                            elif r["id"]==route["id"]: route["breaker"]="half-open"
                    if blocked or state in ("blocked_balance","disabled_auth","quarantined"): continue
                    if not bootstrap and state!="agent_ready": continue
                    route["state"]=state
                    yield route
    def fail(self,route,error):
        if error.scope=="stop": return
        key="scope:"+route["billing_scope"] if error.scope=="billing" else route["id"]
        with self.store.db() as c:
            c.execute("""INSERT INTO provider_routes(id,state,until,failures,evidence) VALUES(?,?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET state=excluded.state,until=excluded.until,failures=provider_routes.failures+1,evidence=excluded.evidence""",
            (key,error.code,time.time()+error.retry_after,1,json.dumps({"error_code":error.code,"at":time.time(),"breaker":"open"})))
    def ready(self,route,capabilities):
        with self.store.db() as c:
            c.execute("INSERT OR REPLACE INTO provider_routes VALUES(?,?,?,?,?)",
                      (route["id"],"agent_ready",0,0,json.dumps({"capabilities":capabilities,"at":time.time(),"breaker":"closed"})))
            c.execute("INSERT OR REPLACE INTO kv VALUES(?,?)",("capability:"+route["id"],json.dumps(capabilities)))

