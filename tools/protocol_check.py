#!/usr/bin/env python3
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',default=os.getenv('GODOT','godot'));p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);project=Path(__file__).resolve().parents[1]/'game/avia';port=24575
files=[];procs=[]
def run(name,args):
 f=(a.out/(name+'.log')).open('w');files.append(f);proc=subprocess.Popen([a.godot,'--headless','--path',str(project)]+args,stdout=f,stderr=subprocess.STDOUT);procs.append(proc);return proc
server=run('server',['--','--server',f'--port={port}','--duration=60',f'--stats={a.out.resolve()}/progress.json']);time.sleep(1);actors=[]
for scenario in ['invalid','replay','expired','plain','wrong-cert','held-recovery','rapid-leave','version']:
 actor=run(scenario,['--script','res://tests/protocol_actor.gd','--',f'--port={port}',f'--scenario={scenario}']);actors.append((scenario,actor));actor.wait(timeout=15)
server.wait(timeout=15)
for f in files:f.close()
checks=[]
for name,proc in actors:
 lines=(a.out/(name+'.log')).read_text().splitlines();summary={}
 for line in lines:
  try:
   item=json.loads(line)
   if item.get('event')=='actor_summary':summary=item
  except ValueError:pass
 checks.append({'scenario':name,'exit':proc.returncode,'summary':summary,'ok':proc.returncode==0 and summary.get('status')=='PASS'})
health=[]
for line in (a.out/'server.log').read_text().splitlines():
 try:
  item=json.loads(line)
  if item.get('event')=='health':health.append(item)
 except ValueError:pass
rejects=max((x['rejected'] for x in health),default=0)
report={'checks':checks,'server_rejected':rejects,'status':'PASS' if all(x['ok'] for x in checks) and rejects>=9 else 'FAIL','scope':'Real localhost ENet/DTLS processes; invalid numeric/position/sequence/ticket packets and admission replay/expiry/plaintext rejection'}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if report['status']=='PASS' else 1)
