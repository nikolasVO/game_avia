import importlib.metadata
import json
import os
import platform
import shutil
import subprocess
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.assets.pipeline import readiness

def doctor():
    load_environment()
    base=Path(os.getenv("GAME_AVIA_ROOT","/srv/game-avia"))
    s=Store(state_dir()/"coordinator.sqlite3")
    result={"python":{"installed":True,"version":platform.python_version(),"tested":True},
            "budget":{"configured":bool(os.getenv("GAME_AVIA_DAILY_COST_LIMIT")),"status":"budget_not_configured" if not os.getenv("GAME_AVIA_DAILY_COST_LIMIT") else "configured"},
            "trellis":readiness(base/"models/trellis512"),"disk":{"free_bytes":shutil.disk_usage(base).free,"reserve_bytes":10*1024**3},
            "unity":json.loads(s.kv("unity_readiness") or '{"installed":false,"tested":false,"blocked":"No Mac runner evidence recorded"}'),
            "backup":{"local_tested":s.kv("backup_tested")=="true","off_server_configured":s.kv("off_server_backup_tested")=="true"},
            "providers":{"configured":[],"agent_tested":[]}}
    for k,v in os.environ.items():
        if k.endswith("_API_KEY") and len(v)>15:result["providers"]["configured"].append(k[:-8])
    with s.db() as c:
        result["providers"]["agent_tested"]=[dict(r) for r in c.execute("SELECT id,state,evidence FROM provider_routes WHERE state='agent_ready'")]
        result["notifications"]={r[0]:r[1] for r in c.execute("SELECT status,COUNT(*) FROM notification_outbox GROUP BY status")}
    try:
        r=subprocess.run(["nvidia-smi","--query-gpu=name,memory.free,utilization.gpu","--format=csv,noheader,nounits"],capture_output=True,text=True,timeout=10)
        result["gpu"]={"installed":r.returncode==0,"measurement":r.stdout.strip()}
    except OSError:result["gpu"]={"installed":False}
    result["sandbox"]=json.loads(s.kv("sandbox_probe") or "{}")
    result["hf_dino_access"]=s.kv("hf_dino_access") or "unverified"
    result["trellis"]["tested"]=not result["trellis"]["blocked"] and s.kv("trellis_inference_tested")=="true"
    result["local_worker"]=json.loads((base/"state/local-smoke.json").read_text()) if (base/"state/local-smoke.json").is_file() else {"tested":False}
    result["image_generation"]=json.loads((base/"state/image-smoke.json").read_text()) if (base/"state/image-smoke.json").is_file() else {"tested":False}
    result["official_codex_runtime"]={"installed":(base/"tools/codex/node_modules/.bin/codex").exists(),"agent_tested":False,"blocked":"Responses route not validated within bootstrap cap"}
    with s.db() as c:
        usage=c.execute("SELECT COALESCE(SUM(requests),0),COALESCE(SUM(tokens),0) FROM usage_ledger WHERE created>?",(__import__("time").time()-86400,)).fetchone()
    result["budget"]["attempts_24h"]=usage[0]
    result["budget"]["reserved_tokens_24h"]=usage[1]
    s.kv("models",json.dumps(result["providers"],ensure_ascii=False)[:3500])
    s.kv("doctor",json.dumps(result,ensure_ascii=False))
    s.kv("disk",json.dumps(result["disk"]))
    s.kv("gpu",json.dumps(result.get("gpu")))
    s.kv("providers",json.dumps(result["providers"],ensure_ascii=False)[:3500])
    return result
if __name__=="__main__":print(json.dumps(doctor(),ensure_ascii=False,indent=2))

