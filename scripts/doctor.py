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
            "unity":{"installed":False,"configured":False,"tested":False,"blocked":"Unity Editor and full Xcode not found on inspected Mac"},
            "backup":{"local_tested":s.kv("backup_tested")=="true","off_server_configured":False},
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
    s.kv("doctor",json.dumps(result,ensure_ascii=False))
    s.kv("disk",json.dumps(result["disk"]))
    s.kv("gpu",json.dumps(result.get("gpu")))
    s.kv("providers",json.dumps(result["providers"],ensure_ascii=False)[:3500])
    return result
if __name__=="__main__":print(json.dumps(doctor(),ensure_ascii=False,indent=2))

