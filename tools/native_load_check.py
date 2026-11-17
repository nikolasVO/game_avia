#!/usr/bin/env python3
"""Manual bounded load test against an actual exported server binary, never a hosted player."""
import argparse,json,os,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--server',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--seconds',type=int,default=1860);p.add_argument('--port',type=int,default=24588);p.add_argument('--planes',default='0');p.add_argument('--systems-cycle',action='store_true');a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);root=Path(__file__).resolve().parents[1]
with (a.out/'native-server.log').open('w') as log:
 server=subprocess.Popen([str(a.server.resolve()),'--headless','--','--server',f'--port={a.port}',f'--duration={a.seconds+40}',f'--stats={a.out.resolve()}/progress.json'],stdout=log,stderr=subprocess.STDOUT)
 monitor=subprocess.Popen(['python3',str(root/'tools/monitor_linux_server.py'),'--pid',str(server.pid),'--seconds',str(a.seconds+45),'--out',str(a.out.resolve()/'resources.json')])
 try:
  time.sleep(1)
  clients=subprocess.run(['python3',str(root/'tools/game_check.py'),'--godot',a.godot,'--external','--host','127.0.0.1','--port',str(a.port),'--clients','16','--planes',a.planes,*(['--systems-cycle'] if a.systems_cycle else []),'--seconds',str(a.seconds),'--out',str(a.out.resolve()/'clients')],stdout=(a.out/'client-runner.log').open('w'),stderr=subprocess.STDOUT,timeout=a.seconds+60)
  server.wait(timeout=50);monitor.wait(timeout=15)
 finally:
  for proc in [server,monitor]:
   if proc.poll() is None:proc.terminate();proc.wait(timeout=10)
health=[];errors=[]
for line in (a.out/'native-server.log').read_text().splitlines():
 if 'ERROR:' in line:errors.append(line[line.index('ERROR:'):])
 try:
  event=json.loads(line)
  if event.get('event')=='health':health.append(event)
 except ValueError:pass
longest=0;begin=None
for row in health:
 if row['connections']==16:
  if begin is None:begin=row['tick']
  longest=max(longest,row['tick']-begin)
 else:begin=None
active=[row for row in health if row['connections']==16]
accepted_during_16=(active[-1]['accepted']-active[0]['accepted']) if len(active)>1 else 0
active_seconds=(active[-1]['tick']-active[0]['tick'])/30 if len(active)>1 else 0
input_rate=accepted_during_16/max(active_seconds,1)/16
p95=max((row['tick_p95_ms'] for row in health),default=1000)
valid_errors=all(e=='ERROR: TLS handshake error: -30464' for e in errors)
report={'accepted_inputs_per_second_per_client':input_rate,'accepted_inputs_during_16':accepted_during_16,'status':'PASS' if clients.returncode==0 and longest>=54000 and p95<25 and input_rate>=20 and valid_errors else 'FAIL','scope':'Thunder loopback, 16 active protocol bots, actual exported dedicated server; not humans/phones/external network','server_exit':server.returncode,'requested_client_seconds':a.seconds,'planes':a.planes,'systems_cycle':a.systems_cycle,'continuous_16_connections_seconds_conservative':longest/30,'max_reported_simulation_tick_p95_ms':p95,'server_engine_errors':errors,'known_dtls_shutdown_diagnostic':bool(errors) and valid_errors,'health':health}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='health'},indent=2));raise SystemExit(0 if report['status']=='PASS' else 1)
