#!/usr/bin/env python3
"""Real admission/reconnect plus synthetic lifecycle and scene cleanup; no phone claim."""
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);project=Path(__file__).resolve().parents[1]/'game/avia'
with (a.out/'server.log').open('w') as log:
 server=subprocess.Popen([a.godot,'--headless','--path',str(project),'--','--server','--port=24576','--duration=20',f'--stats={a.out.resolve()}/progress.json'],stdout=log,stderr=subprocess.STDOUT)
 try:
  deadline=time.monotonic()+10
  while 'server_ready' not in (a.out/'server.log').read_text() and time.monotonic()<deadline:time.sleep(.1)
  with (a.out/'actor.log').open('w') as actor_log:actor=subprocess.run([a.godot,'--headless','--path',str(project),'--script','res://tests/lifecycle_actor.gd'],stdout=actor_log,stderr=subprocess.STDOUT,timeout=18)
  server.wait(timeout=25)
 finally:
  if server.poll() is None:server.terminate();server.wait(timeout=5)
text=(a.out/'actor.log').read_text();summary={}
for line in text.splitlines():
 try:
  row=json.loads(line)
  if row.get('event')=='lifecycle_summary':summary=row
 except ValueError:pass
ok=actor.returncode==0 and summary.get('status')=='PASS' and not any(x in text for x in ['ERROR:','SCRIPT ERROR'])
report={'status':'PASS' if ok else 'FAIL','actor_exit':actor.returncode,'summary':summary}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if ok else 1)
