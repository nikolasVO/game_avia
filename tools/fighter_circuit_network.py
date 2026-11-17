#!/usr/bin/env python3
"""Six command-only development clients land on an actual dedicated native server."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--server',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--seconds',type=int,default=190);p.add_argument('--port',type=int,default=24621);a=p.parse_args()
assert 175<=a.seconds<=300
root=Path(__file__).resolve().parents[1];project=root/'game/avia';a.out.mkdir(parents=True,exist_ok=True)
assert not (a.out/'report.json').exists(),'preserve previous result; reconcile or use a new output directory'
procs=[];files=[]
def launch(name,argv):
 f=(a.out/(name+'.log')).open('w');files.append(f);proc=subprocess.Popen(argv,stdout=f,stderr=subprocess.STDOUT);procs.append((name,proc));return proc

def read_events(path):
 rows=[]
 for line in path.read_text().splitlines():
  try:rows.append(json.loads(line))
  except ValueError:pass
 return rows

try:
 launch('server',['/usr/bin/stdbuf','-oL','-eL',str(a.server.resolve()),'--headless','--','--server',f'--port={a.port}',f'--duration={a.seconds+20}',f'--stats={a.out.resolve()}/progress.json'])
 deadline=time.monotonic()+10
 while 'server_ready' not in (a.out/'server.log').read_text() and time.monotonic()<deadline:time.sleep(.1)
 assert 'server_ready' in (a.out/'server.log').read_text(),'native server not ready'
 for index in range(3,9):
  launch('client-'+str(index),[a.godot,'--headless','--path',str(project),'res://tests/circuit_client.tscn','--','--connect=127.0.0.1',f'--port={a.port}',f'--plane={index}','--bot',f'--duration={a.seconds}'])
  time.sleep(.2)
 deadline=time.monotonic()+a.seconds+35
 while any(proc.poll() is None for _,proc in procs) and time.monotonic()<deadline:time.sleep(.2)
finally:
 for _,proc in procs:
  if proc.poll() is None:proc.terminate()
 for _,proc in procs:
  try:proc.wait(timeout=5)
  except subprocess.TimeoutExpired:proc.kill();proc.wait()
 for f in files:f.close()
server_events=read_events(a.out/'server.log');takeoffs=[e for e in server_events if e.get('event')=='takeoff'];landings=[e for e in server_events if e.get('event')=='landing'];crashes=[e for e in server_events if e.get('event')=='crash'];clients=[];errors=[]
for name,proc in procs:
 text=(a.out/(name+'.log')).read_text()
 errors += [{'process':name,'error':line} for line in text.splitlines() if any(x in line for x in ['ERROR:','SCRIPT ERROR','Parse Error']) and line!='ERROR: TLS handshake error: -30464']
 if name=='server':continue
 events=read_events(a.out/(name+'.log'));summary=next((e for e in reversed(events) if e.get('event')=='summary'),{});stopped=[e for e in events if e.get('event')=='circuit_stopped'];welcome=next((e for e in events if e.get('event')=='welcome'),{});peer=welcome.get('data',{}).get('id');state=summary.get('state',{})
 take=next((e for e in takeoffs if e['data']['id']==peer),{});land=next((e for e in landings if e['data']['id']==peer),{})
 ok=proc.returncode==0 and len(stopped)==1 and summary.get('joined') and summary.get('seen_peers',0)>=6 and summary.get('snapshots',0)>a.seconds*10 and state.get('grounded') and not state.get('crashed',True) and state.get('distance',0)>10000 and take and land and take['tick']<land['tick'] and not any(e.get('event')=='circuit_failed' for e in events)
 clients.append({'name':name,'ok':bool(ok),'exit':proc.returncode,'stopped':stopped,'summary':summary,'takeoff_tick':take.get('tick'),'landing_tick':land.get('tick')})
progress=json.loads((a.out/'progress.json').read_text()) if (a.out/'progress.json').exists() else {}
ok=len(clients)==6 and all(c['ok'] for c in clients) and not errors and not crashes and len(landings)==6 and len(takeoffs)==6 and progress.get('landings')==6
report={'status':'PASS' if ok else 'FAIL','scope':'actual exported native dedicated server +6 headless development clients; full parked takeoff/circuit/landing/braking using only normal control RPCs. Not humans/physical devices/external networks or a new30min load test.','server_binary_sha256':hashlib.sha256(a.server.read_bytes()).hexdigest(),'source_files_sha256':{n:hashlib.sha256((root/n).read_bytes()).hexdigest() for n in ['game/avia/tests/circuit_pilot.gd','game/avia/tests/circuit_client.gd','game/avia/shared/fighter.gd']},'seconds':a.seconds,'clients':clients,'takeoffs':takeoffs,'landings':landings,'crashes':crashes,'errors':errors,'isolated_progress':progress,'health':[e for e in server_events if e.get('event')=='health']}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':report['status'],'clients':[(c['name'],c['ok']) for c in clients],'landings':len(landings),'crashes':len(crashes)}));raise SystemExit(0 if ok else 1)
