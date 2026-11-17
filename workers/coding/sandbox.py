import json
import os
import subprocess
import sys
from pathlib import Path

def bubblewrap_command(workspace,command):
    prefix=Path(sys.base_prefix).resolve()
    argv=["prlimit","--as=805306368","--nproc=128","--cpu=30","--fsize=16777216","--",
          "bwrap","--unshare-all","--die-with-parent","--new-session","--cap-drop","ALL",
          "--ro-bind","/usr","/usr","--symlink","usr/lib","/lib","--symlink","usr/lib64","/lib64",
          "--ro-bind",str(prefix),str(prefix),"--proc","/proc","--dev","/dev","--tmpfs","/tmp","--dir","/etc",
          "--ro-bind",str(Path(workspace).resolve()),"/work",
          "--ro-bind",str(Path(__file__).resolve().parents[2]/"scripts/isolated_test_runner.py"),"/runner.py",
          "--clearenv","--setenv","LANG","C.UTF-8","--setenv","PATH","/usr/bin:/bin","--setenv","HOME","/tmp",
          "--chdir","/work",str(prefix/"bin/python3.12"),"-I","-B"]
    return argv+command

def run_tests(workspace):
    if os.getenv("GAME_AVIA_TEST_SANDBOX")!="bubblewrap":
        return {"error":"verified_sandbox_not_configured","exit_code":1}
    try:
        r=subprocess.run(bubblewrap_command(workspace,["/runner.py"]),capture_output=True,text=True,timeout=45,
                         env={"PATH":"/usr/bin:/bin"},start_new_session=True)
    except subprocess.TimeoutExpired:return {"exit_code":1,"error":"sandbox_deadline"}
    proof={"exit_code":r.returncode,"output":(r.stdout+r.stderr)[-6000:]}
    rows=[x.split("=",1)[1] for x in r.stdout.splitlines() if x.startswith("GAME_AVIA_TEST_RESULT=")]
    if rows:
        try:proof.update(json.loads(rows[-1]))
        except ValueError:proof["error"]="invalid_test_evidence"
    return proof

def probe(workspace):
    code="""import json,pathlib,socket,os
result={'secret_visible':pathlib.Path('/etc/game-avia/environment').exists(),'host_home_visible':pathlib.Path('/home/ubuntu').exists(),'host_root_via_proc':pathlib.Path('/proc/1/root/etc/game-avia/environment').exists(),'network_reachable':False,'workspace_writable':False}
try:
 socket.create_connection(('1.1.1.1',443),timeout=1).close();result['network_reachable']=True
except OSError:pass
try:
 pathlib.Path('/work/SHOULD_NOT_WRITE').write_text('unsafe');result['workspace_writable']=True
except OSError:pass
print(json.dumps(result))
"""
    r=subprocess.run(bubblewrap_command(workspace,["-c",code]),capture_output=True,text=True,timeout=15,env={"PATH":"/usr/bin:/bin"})
    if r.returncode:return {"passed":False,"exit_code":r.returncode,"error":r.stderr[-1000:]}
    d=json.loads(r.stdout);d["passed"]=not any(d.values());return d

