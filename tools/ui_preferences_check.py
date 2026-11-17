#!/usr/bin/env python3
"""Run actual rendered UI regression in copied project/unique test user data.
Never writes the owner's game preferences. Run separately from Android/ADB QA
because the Godot editor may stop/restart ADB during import/shutdown.
"""
import argparse,json,shutil,subprocess,uuid
from pathlib import Path
from build_validation import checked_godot,check_materialized_assets
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--godot',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
assert not a.out.exists(),'use a new owned evidence directory'
root=Path(__file__).resolve().parents[1];check_materialized_assets(root/'game/avia')
project=a.out.resolve()/'project';shutil.copytree(root/'game/avia',project,ignore=shutil.ignore_patterns('.godot','android'))
config=project/'project.godot';config.write_text(config.read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="game-avia-ui-check-'+uuid.uuid4().hex+'"'))
checked_godot([a.godot,'--headless','--path',str(project),'--editor','--import','--quit'],120)
r=subprocess.run([a.godot,'--path',str(project),'--script','res://tests/ui_preferences_check.gd'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=45)
(a.out/'runtime.log').write_text(r.stdout);summary={}
for line in r.stdout.splitlines():
 try:e=json.loads(line)
 except ValueError:continue
 if e.get('event')=='ui_preferences_summary':summary=e
ok=r.returncode==0 and summary.get('status')=='PASS' and not any(x in r.stdout for x in ('ERROR:','SCRIPT ERROR'))
report={'status':'PASS' if ok else 'FAIL','exit_code':r.returncode,'summary':summary}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));raise SystemExit(0 if ok else 1)
