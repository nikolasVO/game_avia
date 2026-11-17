#!/usr/bin/env python3
"""Check real rendered aircraft assemblies and capture gear endpoints/travel."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
project=Path(__file__).resolve().parents[1]/'game/avia'
env=dict(os.environ,AVIA_SYSTEMS_CHECK_DIR=str(a.out.resolve()))
try:
 r=subprocess.run([a.godot,'--rendering-method','gl_compatibility','--resolution','640x360','--path',str(project),'--script','res://tests/aircraft_systems_check.gd'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
except subprocess.TimeoutExpired as exc:
 output=exc.stdout or b''
 if isinstance(output,bytes):output=output.decode(errors='replace')
 r=subprocess.CompletedProcess(exc.cmd,124,output+'\nAircraft systems check deadline exceeded\n')
(a.out/'runtime.log').write_text(r.stdout);summary={}
for line in r.stdout.splitlines():
 try:event=json.loads(line)
 except ValueError:continue
 if event.get('event')=='aircraft_systems':summary=event
images={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in a.out.glob('*.png')}
distinct=all(len({images.get(f'{plane}-{stage}-{angle}.png') for stage in range(3)})==3 for plane in ['f16c','su27','f15c','su35s','rafale','gripen'] for angle in range(2))
ok=r.returncode==0 and summary.get('status')=='PASS' and len(images)==36 and distinct and not any(s in r.stdout for s in ['ERROR:','SCRIPT ERROR','Parse Error'])
report={'status':'PASS' if ok else 'FAIL','exit_code':r.returncode,'summary':summary,'preview_sha256':images,'all_three_gear_states_differ_in_each_view':distinct,'scope':'desktop renderer, deterministic flags and image captures; device/recognition/aircraft acceptance remains open'}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':report['status'],'checks':len(summary.get('checks',[])),'previews':len(images),'distinct_states':distinct}))
raise SystemExit(0 if ok else 1)
