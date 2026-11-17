#!/usr/bin/env python3
"""Sample only this task's Godot processes; no GPU/process mutations."""
import argparse,json,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--seconds',type=int,default=1800);a=p.parse_args();samples=[];start=time.monotonic()
while time.monotonic()-start<a.seconds:
 rows=subprocess.check_output(['ps','-ax','-o','pid=,pcpu=,rss=,command='],text=True)
 for line in rows.splitlines():
  parts=line.split(None,3)
  if len(parts)==4 and 'Godot.app/Contents/MacOS/Godot' in parts[3] and '--port=24570' in parts[3]:
   samples.append({'at':round(time.monotonic()-start,2),'pid':int(parts[0]),'cpu_percent':float(parts[1]),'rss_kib':int(parts[2]),'role':'server' if '--server' in parts[3] else 'bot'})
 if len(samples)>0 and not any('--port=24570' in l and 'Godot.app/Contents/MacOS/Godot' in l for l in rows.splitlines()):break
 a.out.write_text(json.dumps({'scope':'Mac localhost 16 headless protocol bots; ps CPU uses OS averaging','samples':samples})+'\n')
 time.sleep(5)
print('monitor complete',len(samples))
