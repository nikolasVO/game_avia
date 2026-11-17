#!/usr/bin/env python3
"""Exercise real Godot audio players and record their digital mix (no device acceptance)."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True)
p.add_argument('--audio-driver',default='CoreAudio',help='Use an installed device driver; headless/Dummy does not capture a mix on the tested build')
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
project=Path(__file__).resolve().parents[1]/'game/avia'
env=dict(os.environ,AVIA_AUDIO_CHECK_DIR=str(a.out.resolve()))
try:
 r=subprocess.run([a.godot,'--rendering-method','gl_compatibility','--resolution','400x240','--audio-driver',a.audio_driver,'--path',str(project),'--script','res://tests/audio_check.gd'],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40)
except subprocess.TimeoutExpired as exc:
 output=exc.stdout or b''
 if isinstance(output,bytes):output=output.decode(errors='replace')
 r=subprocess.CompletedProcess(exc.cmd,124,output+'\nAudio check deadline exceeded\n')
(a.out/'runtime.log').write_text(r.stdout);summary={}
for line in r.stdout.splitlines():
 try:event=json.loads(line)
 except ValueError:continue
 if event.get('event')=='audio_check_summary':summary=event
ok=r.returncode==0 and summary.get('status')=='PASS' and not any(s in r.stdout for s in ['ERROR:','SCRIPT ERROR','Parse Error'])
report={'status':'PASS' if ok else 'FAIL','exit_code':r.returncode,'summary':summary}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));raise SystemExit(0 if ok else 1)
