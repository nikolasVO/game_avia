#!/usr/bin/env python3
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);project=Path(__file__).resolve().parents[1]/'game/avia';procs=[];handles=[]
def start(name,args):
 f=(a.out/(name+'.log')).open('w');handles.append(f);proc=subprocess.Popen([a.godot,'--headless','--path',str(project),'--']+args,stdout=f,stderr=subprocess.STDOUT);procs.append(proc)
start('server',['--server','--port=24591','--duration=155',f'--stats={a.out.resolve()}/progress.json']);time.sleep(1)
for i in range(2):start('client-'+str(i),['--connect=127.0.0.1','--port=24591','--bot','--route','--mode=race','--duration=145'])
try:
 for proc in procs:proc.wait(timeout=180)
finally:
 for proc in procs:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
 for f in handles:f.close()
events=[]
for line in (a.out/'server.log').read_text().splitlines():
 try:
  d=json.loads(line)
  if d.get('event') in ['finish','checkpoint','respawn']:events.append(d)
 except ValueError:pass
finishes=[e for e in events if e['event']=='finish'];counts={}
for e in finishes:counts[e['data']['id']]=counts.get(e['data']['id'],0)+1
report={'status':'PASS' if len(counts)==2 and min(counts.values())>=2 else 'FAIL','scope':'Real protocol3 control bots complete and repeat server-authoritative race','finishes':finishes,'finish_counts':counts,'respawns':sum(e['event']=='respawn' for e in events)}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
