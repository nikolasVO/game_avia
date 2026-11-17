#!/usr/bin/env python3
"""User-space UDP impairment on private test ports only. Never touches routes, tc or SSH."""
import argparse,heapq,json,os,random,selectors,socket,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',default=os.getenv('GODOT','godot'));p.add_argument('--out',type=Path,required=True);p.add_argument('--seconds',type=int,default=45);p.add_argument('--rtt',type=int,default=100);p.add_argument('--jitter',type=int,default=30);p.add_argument('--loss',type=float,default=.01);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);project=Path(__file__).resolve().parents[1]/'game/avia';base=24600;selector=selectors.DefaultSelector();rng=random.Random(17011+a.rtt);queue=[];procs=[];files=[];counters={'received':0,'dropped':0,'forwarded':0,'bytes':0};nonce=0
for i in range(2):
 sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);sock.bind(('127.0.0.1',base+i));sock.setblocking(False);selector.register(sock,selectors.EVENT_READ,{'client':None})
def run(name,args):
 f=(a.out/(name+'.log')).open('w');files.append(f);proc=subprocess.Popen([a.godot,'--headless','--path',str(project)]+args,stdout=f,stderr=subprocess.STDOUT);procs.append(proc);return proc
server=run('server',['--','--server',f'--port={base+10}',f'--duration={a.seconds+6}',f'--stats={a.out.resolve()}/progress.json']);time.sleep(1)
for i in range(2):run('client-'+str(i),['--','--connect=127.0.0.1',f'--port={base+i}','--bot',f'--duration={a.seconds+i*.4}'])
deadline=time.monotonic()+a.seconds+15
try:
 while time.monotonic()<deadline and any(proc.poll() is None for proc in procs):
  now=time.monotonic()
  for key,_ in selector.select(.002):
   data,addr=key.fileobj.recvfrom(65535);counters['received']+=1;counters['bytes']+=len(data)
   if addr==('127.0.0.1',base+10):dest=key.data['client']
   else:key.data['client']=addr;dest=('127.0.0.1',base+10)
   if not dest:continue
   if rng.random()<a.loss:counters['dropped']+=1;continue
   delay=max(0,a.rtt/2+rng.uniform(-a.jitter,a.jitter))/1000
   nonce+=1;heapq.heappush(queue,(now+delay,nonce,key.fileobj,data,dest))
  while queue and queue[0][0]<=now:
   _,_,sock,data,dest=heapq.heappop(queue);sock.sendto(data,dest);counters['forwarded']+=1
finally:
 for proc in procs:
  if proc.poll() is None:proc.terminate()
  proc.wait(timeout=5)
 for f in files:f.close()
 for key in list(selector.get_map().values()):key.fileobj.close()
summaries=[]
for i in range(2):
 for line in (a.out/f'client-{i}.log').read_text().splitlines():
  try:
   d=json.loads(line)
   if d.get('event')=='summary':summaries.append(d)
  except ValueError:pass
ok=len(summaries)==2 and all(x.get('joined') and x.get('snapshots',0)>a.seconds*5 and x.get('seen_peers')==2 for x in summaries)
report={'status':'PASS' if ok else 'FAIL','scope':'localhost real ENet/DTLS processes through UDP impairment; not carrier/Wi-Fi handover','rtt_base_ms':a.rtt,'per_direction_jitter_uniform_ms':a.jitter,'loss_probability_each_direction':a.loss,'seconds':a.seconds,'proxy':counters,'clients':summaries}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if ok else 1)
