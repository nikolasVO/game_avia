"""Read-only live operational evidence; no paid calls."""
import json
import os
import stat
import subprocess
import urllib.request
import urllib.error
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store

def check():
    load_environment()
    s=Store(state_dir()/"coordinator.sqlite3")
    report={}
    report["checkout"]=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
    report["health"]=json.load(urllib.request.urlopen("http://127.0.0.1:8787/health",timeout=10))
    try:
        urllib.request.urlopen("http://127.0.0.1:8787/tasks",timeout=10)
        report["api_rejects_unauthorized"]=False
    except urllib.error.HTTPError as e:report["api_rejects_unauthorized"]=e.code==401
    req=urllib.request.Request("http://127.0.0.1:8787/tasks",headers={"Authorization":"Bearer "+os.environ["GAME_AVIA_API_TOKEN"]})
    with urllib.request.urlopen(req,timeout=10) as r:report["api_authorized_get"]=r.status==200
    status=subprocess.check_output(["/srv/game-avia/venvs/core/bin/supervisorctl","-c","deploy/supervisord.conf","status"],text=True)
    report["services"]={line.split()[0]:line.split()[1] for line in status.splitlines()}
    report["runtime_children"]={}
    from pathlib import Path
    for name in ("api","coordinator","executor"):
        pid=subprocess.check_output(["/srv/game-avia/venvs/core/bin/supervisorctl","-c","deploy/supervisord.conf","pid",name],text=True).strip()
        values=Path("/proc/"+pid+"/environ").read_bytes().split(b"\0")
        sha=next((x.split(b"=",1)[1].decode() for x in values if x.startswith(b"GAME_AVIA_RELEASE_SHA=")),None)
        report["runtime_children"][name]={"release":sha,"uid":Path("/proc/"+pid).stat().st_uid}
    report["private_environment_mode"]=oct(stat.S_IMODE(Path("/etc/game-avia/environment").stat().st_mode))
    with s.db() as c:
        report["bootstrap_text_attempts"]=c.execute("SELECT COALESCE(SUM(requests),0) FROM usage_ledger").fetchone()[0]
        report["bootstrap_image_operations"]=c.execute("SELECT COUNT(*) FROM tool_operations WHERE tool='image_generation'").fetchone()[0]
        report["outbox"]={r[0]:r[1] for r in c.execute("SELECT status,COUNT(*) FROM notification_outbox GROUP BY status")}
        report["artifact_messages"]=[dict(r) for r in c.execute("SELECT kind,status,message_id FROM notification_outbox WHERE kind!='text'")]
    report["sandbox"]=json.loads(s.kv("sandbox_probe") or "{}")
    report["restart_recovery"]=s.kv("restart_recovery")
    report["off_server_backup_tested"]=s.kv("off_server_backup_tested")
    report["owner_live_incoming_update_verified"]=False
    report["remaining_blockers"]=["gated_dino_access","Unity_Editor_license_runner_and_Xcode","official_Codex_Responses_route_unverified","bootstrap_paid_probe_cap_reached","unattended_E2E_retest_pending"]
    assert report["health"]["release"]==report["checkout"]
    assert report["api_rejects_unauthorized"] and report["api_authorized_get"]
    assert all(x=="RUNNING" for x in report["services"].values())
    assert all(x["release"]==report["checkout"] and x["uid"]!=0 for x in report["runtime_children"].values())
    assert report["bootstrap_text_attempts"]<=12 and report["bootstrap_image_operations"]<=1
    assert report["sandbox"].get("passed")
    return report
if __name__=="__main__":print(json.dumps(check(),indent=2,ensure_ascii=False))

