#!/usr/bin/env python3
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);root=Path(__file__).resolve().parents[1];project=root/'game/avia';procs=[];logs=[]
def run(name,args):
 f=(a.out/(name+'.log')).open('w');logs.append(f);proc=subprocess.Popen([a.godot,'--headless','--path',str(project)]+args,stdout=f,stderr=subprocess.STDOUT);procs.append((name,proc));return proc
run('server',['--','--server','--port=24589','--duration=30',f'--stats={a.out.resolve()}/progress.json']);time.sleep(1)
for i in range(19):run('client-'+str(i),['--','--connect=127.0.0.1','--port=24589','--duration=12']+(['--private','--code=ABCD'] if i<17 else []))
try:
 for _,proc in procs:proc.wait(timeout=45)
finally:
 for _,proc in procs:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
 for f in logs:f.close()
private=0;public=0;full=0;errors=[]
for name,proc in procs[1:]:
 text=(a.out/(name+'.log')).read_text();summary={};events=[]
 for line in text.splitlines():
  try:events.append(json.loads(line))
  except ValueError:pass
 welcome=next((e for e in events if e.get('event')=='welcome'),None)
 if welcome:
  room=welcome['data']['room'];summary=next((e for e in reversed(events) if e.get('event')=='summary'),{})
  if room=='private:ABCD' and summary.get('joined') and summary.get('seen_peers')==16:private+=1
  elif room=='public:free:0' and summary.get('joined') and summary.get('seen_peers')==2:public+=1
 else:
  if any(e.get('event')=='error' and e.get('data',{}).get('reason')=='Room full' for e in events):full+=1
 if proc.returncode!=0 or 'SCRIPT ERROR' in text:errors.append(name)
report={'status':'PASS' if (private,public,full)==(16,2,1) and not errors else 'FAIL','scope':'19 real ENet/DTLS client processes in distinct private/public rooms; no claim of 32 in one room','private_room_joined':private,'public_room_isolated':public,'room_full_rejections':full,'errors':errors}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));raise SystemExit(0 if report['status']=='PASS' else 1)
