#!/usr/bin/env python3
import argparse,json,os,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--pid',type=int,required=True);p.add_argument('--seconds',type=int,default=1800);p.add_argument('--out',type=Path,required=True);a=p.parse_args();clock=os.sysconf('SC_CLK_TCK');start=time.monotonic();last=None;samples=[]
while time.monotonic()-start<a.seconds:
 try:
  stat=Path(f'/proc/{a.pid}/stat').read_text().rsplit(')',1)[1].split();ticks=int(stat[11])+int(stat[12]);status=Path(f'/proc/{a.pid}/status').read_text();rss=next(int(l.split()[1]) for l in status.splitlines() if l.startswith('VmRSS:'))
 except (OSError,StopIteration):break
 now=time.monotonic();cpu=(ticks-last[1])/clock/(now-last[0])*100 if last else 0;last=(now,ticks)
 samples.append({'seconds':round(now-start,3),'cpu_percent_one_core_100':round(cpu,3),'rss_kib':rss})
 a.out.write_text(json.dumps({'scope':'Thunder dedicated server only; active clients separately logged','pid':a.pid,'samples':samples},indent=2)+'\n');time.sleep(5)
print('samples',len(samples))
