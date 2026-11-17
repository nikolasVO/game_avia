#!/usr/bin/env python3
"""Run actual rendered UI regression in copied project/unique test user data.
Never writes the owner's game preferences. Run separately from Android/ADB QA
because the Godot editor may stop/restart ADB during import/shutdown.
"""
import argparse,json,shutil,subprocess,uuid,os,socket,time
from pathlib import Path
from build_validation import checked_godot,check_materialized_assets
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--network',action='store_true',help='Actual UI admission on private UDP24678; requires existing AVIA_DTLS_KEY');a=p.parse_args()
assert not a.out.exists(),'use a new owned evidence directory'
root=Path(__file__).resolve().parents[1];check_materialized_assets(root/'game/avia')
project=a.out.resolve()/'project';shutil.copytree(root/'game/avia',project,ignore=shutil.ignore_patterns('.godot','android'))
config=project/'project.godot';config.write_text(config.read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="game-avia-ui-check-'+uuid.uuid4().hex+'"'))
checked_godot([a.godot,'--headless','--path',str(project),'--editor','--import','--quit'],120)
server=None;server_log=None;env=dict(os.environ)
env.pop('AVIA_UI_NETWORK_CHECK',None)
try:
 if a.network:
  assert env.get('AVIA_DTLS_KEY'),'existing protected AVIA_DTLS_KEY required'
  with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as free:free.bind(('127.0.0.1',24678))
  server_log=(a.out/'server.log').open('w')
  server=subprocess.Popen([a.godot,'--headless','--path',str(project),'--','--server','--port=24678','--duration=30','--stats='+str(a.out.resolve()/'progress.json')],env=env,stdout=server_log,stderr=subprocess.STDOUT)
  deadline=time.monotonic()+10
  while 'server_ready' not in (a.out/'server.log').read_text() and time.monotonic()<deadline:time.sleep(.1)
  assert 'server_ready' in (a.out/'server.log').read_text(),'owned test server did not become ready'
  env['AVIA_UI_NETWORK_CHECK']='1'
 r=subprocess.run([a.godot,'--path',str(project),'--script','res://tests/ui_preferences_check.gd'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
finally:
 if server and server.poll() is None:server.terminate();server.wait(timeout=8)
 if server_log:server_log.close()

(a.out/'runtime.log').write_text(r.stdout);summary={}
for line in r.stdout.splitlines():
 try:e=json.loads(line)
 except ValueError:continue
 if e.get('event')=='ui_preferences_summary':summary=e
ok=r.returncode==0 and summary.get('status')=='PASS' and not any(x in r.stdout for x in ('ERROR:','SCRIPT ERROR'))
report={'status':'PASS' if ok else 'FAIL','exit_code':r.returncode,'summary':summary}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if ok else 1)
