#!/usr/bin/env python3
"""Bounded probe of an explicitly installed isolated diagnostic package.
No game/server operations, install, root, global log clearing or other app stop.
"""
import argparse,hashlib,json,subprocess,time
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--adb',required=True);p.add_argument('--serial',required=True);p.add_argument('--package',required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--cycles',type=int,default=20);p.add_argument('--cold',action='store_true');a=p.parse_args()
 assert a.package.startswith('com.nikolasvo.gameavia.surface'),'diagnostic packages only'
 assert 1<=a.cycles<=30 and not a.out.exists()
 a.out.mkdir(parents=True)
 def adb(*args,**kw):return subprocess.run([a.adb,'-s',a.serial,*args],check=True,timeout=30,**kw)
 def output(*args):return subprocess.check_output([a.adb,'-s',a.serial,*args],text=True,timeout=20)
 adb('shell','am','force-stop',a.package);adb('shell','run-as',a.package,'mkdir','-p','files')
 adb('shell','run-as',a.package,'sh','-c','"cat > files/surface.cfg"',input='[test]\nmode="3d"\n',text=True)
 adb('shell','am','start','-n',a.package+'/com.godot.game.GodotAppLauncher')
 deadline=time.monotonic()+30;pid=''
 while time.monotonic()<deadline:
  pid=subprocess.run([a.adb,'-s',a.serial,'shell','pidof',a.package],text=True,stdout=subprocess.PIPE,timeout=20).stdout.strip()
  if pid.isdigit():break
  time.sleep(.2)
 assert pid.isdigit(),'launch PID timeout'
 def logs():return output('logcat','-d','--pid='+pid,'-s','godot:I','GLThread:I','EGL_emulation:E')
 def frames():
  values=[]
  for line in logs().splitlines():
   if 'godot   : {' not in line:continue
   try:e=json.loads(line.split('godot   : ',1)[1])
   except ValueError:continue
   if e.get('event')=='surface_frame':values.append(e)
  return values
 def wait_for(predicate,seconds):
  deadline=time.monotonic()+seconds;value=[]
  while time.monotonic()<deadline:
   value=frames()
   if value and predicate(value[-1]):return value[-1]
   time.sleep(.2)
  return value[-1] if value else {}
 def home_resume():
  adb('shell','input','keyevent','3');time.sleep(.7);adb('shell','am','start','-n',a.package+'/com.godot.game.GodotAppLauncher')
 initial=wait_for(lambda e:e['frames']>=1,90);assert initial,'initial frame timeout'
 cold={}
 if a.cold:
  home_resume();after=wait_for(lambda e:e['draws']>=30 and e['frames']>initial['frames']+30,120)
  cold={'before':initial,'after':after,'advanced':bool(after and after['draws']>=30),'actual_cold':initial['draws']==0}
 warm=wait_for(lambda e:e['draws']>=30,30);cycles=[]
 if warm and warm['draws']>=30:
  for i in range(a.cycles):
   before=frames()[-1];home_resume();after=wait_for(lambda e:e['draws']>before['draws']+3,10)
   row={'cycle':i+1,'before':before,'after':after,'advanced':bool(after and after['draws']>before['draws']+3)};cycles.append(row);print(json.dumps(row),flush=True)
   if not row['advanced']:break
 text=logs();(a.out/'runtime.log').write_text(text)
 with (a.out/'screen.png').open('wb') as f:adb('exec-out','screencap','-p',stdout=f)
 apk_path=output('shell','pm','path',a.package).strip().splitlines()[0].removeprefix('package:')
 installed_hash=output('shell','sha256sum',apk_path).split()[0]
 ok=(not a.cold or cold.get('advanced',False)) and len(cycles)==a.cycles and all(c['advanced'] for c in cycles)
 report={'status':'PASS tested fixture scenarios' if ok else 'FAIL','package':a.package,'pid':int(pid),'installed_apk_sha256':installed_hash,'cold':cold,'warm_cycles':cycles,'recovery_markers':[l for l in text.splitlines() if 'GAME_AVIA_SURFACE_RECOVERY' in l],'log_sha256':hashlib.sha256(text.encode()).hexdigest(),'limits':'isolated diagnostic on specified device; not gameplay/phone FPS acceptance; inspect screenshot too'}
 (a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],flush=True)
 # Leave a failed fixture alive for read-only stack investigation; stop only our package on success.
 if ok:adb('shell','am','force-stop',a.package)
 return 0 if ok else 1
if __name__=='__main__':raise SystemExit(main())
