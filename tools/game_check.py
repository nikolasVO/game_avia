#!/usr/bin/env python3
"""Run actual separate Godot processes. Bots are explicitly labelled; never human/device proof."""
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',default=os.getenv('GODOT','godot'));p.add_argument('--clients',type=int,default=2);p.add_argument('--seconds',type=int,default=20);p.add_argument('--render',action='store_true');p.add_argument('--out',type=Path,required=True);p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=24567);p.add_argument('--external',action='store_true');p.add_argument('--mode',default='free');a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True);project=Path(__file__).resolve().parents[1]/'game/avia'
processes=[];handles=[]
def run(name,args):
 f=(a.out/(name+'.log')).open('w');handles.append(f)
 proc=subprocess.Popen([a.godot,'--path',str(project)]+args,stdout=f,stderr=subprocess.STDOUT)
 processes.append((name,proc));return proc
try:
 if not a.external:
  run('server',['--headless','--','--server',f'--port={a.port}',f'--duration={a.seconds+5}',f'--stats={a.out.resolve()}/progress.json']);time.sleep(1)
 for i in range(a.clients):
  args=[] if a.render else ['--headless']
  args+=['--',f'--connect={a.host}',f'--port={a.port}','--bot',f'--mode={a.mode}',f'--duration={a.seconds}']
  if a.render:args += [f'--capture={a.out.resolve()}/client-{i}.png']
  run(f'client-{i}',args)
 deadline=time.monotonic()+a.seconds+30
 while any(proc.poll() is None for _,proc in processes) and time.monotonic()<deadline:time.sleep(.2)
finally:
 for _,proc in processes:
  if proc.poll() is None:proc.terminate()
 for _,proc in processes:
  try:proc.wait(timeout=5)
  except subprocess.TimeoutExpired:proc.kill();proc.wait()
 for f in handles:f.close()
report={'environment':'desktop-rendered-bots' if a.render else 'headless-protocol-bots','host_kind':'external' if a.external else 'localhost','clients':a.clients,'requested_seconds':a.seconds,'processes':[],'status':'PASS'}
for name,proc in processes:
 text=(a.out/(name+'.log')).read_text();events=[]
 for line in text.splitlines():
  try:events.append(json.loads(line))
  except ValueError:pass
 summary=next((e for e in reversed(events) if e.get('event')=='summary'),{})
 ok=proc.returncode==0 and not any(x in text for x in ['SCRIPT ERROR','Parse Error','ERROR:']) and bool(summary)
 if name.startswith('client'):ok=ok and summary.get('joined') and summary.get('snapshots',0)>a.seconds*5 and summary.get('seen_peers',0)>=a.clients
 if not ok:report['status']='FAIL'
 report['processes'].append({'name':name,'exit':proc.returncode,'ok':bool(ok),'summary':summary,'events':sorted({e.get('event','') for e in events}),'health':[e for e in events if e.get('event')=='health']})
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if report['status']=='PASS' else 1)
