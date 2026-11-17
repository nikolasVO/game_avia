#!/usr/bin/env python3
"""Reject Godot runtime errors even when the process exits0 and prints a partial PASS."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
project=Path(__file__).resolve().parents[1]/'game/avia';results=[]
for script in ['flight_check','fighter_check','fighter_geometry_check']:
 r=subprocess.run([a.godot,'--headless','--path',str(project),'--script',f'res://tests/{script}.gd'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
 (a.out/(script+'.log')).write_text(r.stdout)
 events=[]
 for line in r.stdout.splitlines():
  try:events.append(json.loads(line))
  except ValueError:pass
 ok=r.returncode==0 and events and not any(x in r.stdout for x in ['ERROR:','SCRIPT ERROR','Parse Error']) and not any(e.get('status')=='FAIL' or e.get('failed',0) for e in events)
 results.append({'script':script,'ok':bool(ok),'exit':r.returncode,'events':events})
report={'status':'PASS' if all(r['ok'] for r in results) else 'FAIL','scope':'actual Godot shared simulation/synthetic input and mesh inspection, not physical aircraft acceptance','results':results}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':report['status'],'scripts':[(r['script'],r['ok']) for r in results]}));raise SystemExit(0 if report['status']=='PASS' else 1)
