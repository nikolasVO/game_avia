#!/usr/bin/env python3
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',default=os.getenv('GODOT','godot'));p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);project=Path(__file__).resolve().parents[1]/'game/avia';port=24575
files=[];procs=[]
def run(name,args):
 f=(a.out/(name+'.log')).open('w');files.append(f);proc=subprocess.Popen([a.godot,'--headless','--path',str(project)]+args,stdout=f,stderr=subprocess.STDOUT);procs.append(proc);return proc
server=run('server',['res://tests/audit_main.tscn','--',f'--stats={a.out.resolve()}/progress.json']);deadline=time.monotonic()+15
while 'server_ready' not in (a.out/'server.log').read_text() and time.monotonic()<deadline:time.sleep(.1)
actors=[]
for scenario in ['invalid','replay','expired','plain','wrong-cert','held-recovery','rapid-leave','version']:
 actor=run(scenario,['--script','res://tests/protocol_actor.gd','--',f'--port={port}',f'--scenario={scenario}']);actors.append((scenario,actor));actor.wait(timeout=15)
server.wait(timeout=15)
for f in files:f.close()
checks=[]
for name,proc in actors:
 text=(a.out/(name+'.log')).read_text();lines=text.splitlines();summary={}
 for line in lines:
  try:
   item=json.loads(line)
   if item.get('event')=='actor_summary':summary=item
  except ValueError:pass
 checks.append({'scenario':name,'exit':proc.returncode,'summary':summary,'ok':proc.returncode==0 and summary.get('status')=='PASS' and 'SCRIPT ERROR' not in text and 'Parse Error' not in text})
health=[];receipts=[];ticket_receipts=[];sent=[]
for line in (a.out/'invalid.log').read_text().splitlines():
 try:
  item=json.loads(line)
  if item.get('event')=='sent_attack':sent.append(item)
 except ValueError:pass
for line in (a.out/'server.log').read_text().splitlines():
 try:
  item=json.loads(line)
  if item.get('event')=='health':health.append(item)
  if item.get('event')=='input_receipt':receipts.append(item)
  if item.get('event')=='ticket_receipt':ticket_receipts.append(item)
 except ValueError:pass
rejects=max((x['rejected'] for x in health),default=0)
delivery=[]
for attack in sent:
 expected='replayed_sequence' if attack['label']=='replay' else 'sequence_jump' if attack['label']=='sequence_jump' else 'invalid_input'
 matches=[r for r in receipts if r['peer']==attack['peer'] and r['number']==attack['number']]
 delivery.append(dict(attack,expected=expected,received=matches,ok=len(matches)==1 and matches[0]['result']==expected))
invalid_peer=sent[0]['peer'] if sent else -1
ticket_rejected=any(t['peer']==invalid_peer and t['result']=='missing_ticket' for t in ticket_receipts)
report={'packet_delivery':delivery,'ticket_receipts':ticket_receipts,'invalid_ticket_rejected':ticket_rejected,'checks':checks,'server_rejected':rejects,'status':'PASS' if all(x['ok'] for x in checks) and len(delivery)==6 and all(d['ok'] for d in delivery) and ticket_rejected else 'FAIL','scope':'Real localhost ENet/DTLS; opt-in server observer records actual production handler receipt/rejection by peer and unique sequence. Missing delivery fails; no rejection inferred from stationary aircraft.'}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if report['status']=='PASS' else 1)
