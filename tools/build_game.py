#!/usr/bin/env python3
"""Manual, bounded native exports. No deployment, signing-key creation or account access."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',default=os.getenv('GODOT','godot'));p.add_argument('--out',type=Path,default=Path('builds'));p.add_argument('--target',choices=['apk','aab','server','mac'],required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];project=root/'game/avia';a.out.mkdir(parents=True,exist_ok=True);out=a.out.resolve();version=subprocess.check_output([a.godot,'--version'],text=True).strip()
if version!='4.7.2.stable.official.ed1daf0bf':raise SystemExit('Expected pinned Godot 4.7.2 standard ed1daf0bf; got '+version)
subprocess.run([a.godot,'--headless','--path',str(project),'--editor','--import','--quit'],check=True,timeout=120)
targets={'apk':('--export-debug','Android Debug','game-avia-0.1.0-debug.apk'),'aab':('--export-release','Android AAB Unsigned','game-avia-0.1.0-unsigned.aab'),'server':('--export-release','Linux Server','game-avia-server.x86_64'),'mac':('--export-debug','macOS Test','GameAvia.zip')}
flag,preset,name=targets[a.target];cmd=[a.godot,'--headless','--path',str(project)]
if a.target=='aab' and not (project/'android/build').exists():cmd+=['--install-android-build-template']
cmd += [flag,preset,str(out/name)]
subprocess.run(cmd,check=True,timeout=600)
artifact=out/name
if not artifact.is_file() or artifact.stat().st_size<10000:raise SystemExit('Missing native artifact')
sha=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip();dirty=bool(subprocess.check_output(['git','-C',str(root),'status','--porcelain'],text=True))
source_hashes={str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(project.rglob('*')) if p.is_file() and p.relative_to(project).parts[0] not in ('.godot','android') and p.suffix in ('.gd','.tscn','.godot','.cfg','.crt','.svg','.txt','.glb','.png','.import','.uid','.json')}
manifest={'source_files_sha256':source_hashes,'artifact':name,'bytes':artifact.stat().st_size,'sha256':hashlib.sha256(artifact.read_bytes()).hexdigest(),'engine':version,'commit':sha,'dirty':dirty,'target':a.target,'signature':'debug' if a.target=='apk' else 'unsigned' if a.target=='aab' else 'test','device_tested':False}
(out/(name+'.json')).write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
