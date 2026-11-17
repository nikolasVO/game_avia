#!/usr/bin/env python3
"""Isolated, manual debug APK or unsigned AAB with Android surface recovery.
Copies materialized game files into an owned output directory. Does not alter
installed export templates, the working game project, server or release signing.
"""
import argparse,hashlib,json,os,shutil,subprocess,sys,zipfile
from pathlib import Path
from build_validation import checked_godot,check_materialized_assets

def hashes(root):
 return {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(root.rglob('*')) if p.is_file() and p.relative_to(root).parts[0] not in ('.godot','android')}

def main():
 p=argparse.ArgumentParser(description=__doc__)
 for name in ('godot','jdk','sdk','templates','out'):p.add_argument('--'+name,type=Path,required=True)
 p.add_argument('--target',choices=['apk','aab'],default='apk')
 a=p.parse_args();root=Path(__file__).resolve().parents[1];source=root/'game/avia';out=a.out.resolve()
 assert not out.exists(),'use a new owned output directory; never overwrite an earlier build'
 assert source not in out.parents and root!=out,'output must be outside the game project'
 assert subprocess.check_output([str(a.godot),'--version'],text=True).strip()=='4.7.2.stable.official.ed1daf0bf'
 check_materialized_assets(source);original_hashes=hashes(source)
 commit=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
 dirty=bool(subprocess.check_output(['git','-C',str(root),'status','--porcelain'],text=True))
 out.mkdir(parents=True);project=out/'project';shutil.copytree(source,project,ignore=shutil.ignore_patterns('.godot','android','.DS_Store'))
 android=project/'android';build=android/'build';build.mkdir(parents=True);(android/'.gdignore').write_text('')
 with zipfile.ZipFile(a.templates/'android_source.zip') as z:
  assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in z.namelist())
  z.extractall(build)
 (android/'.build_version').write_text('4.7.2.stable\n');(build/'gradlew').chmod(0o755)
 variant='debug' if a.target=='apk' else 'release'
 library=build/('libs/'+variant+'/godot-lib.template_'+variant+'.aar');stock=out/('official-'+variant+'.aar');shutil.copy2(library,stock)
 patch_root=root/'third_party/godot_android_surface'
 licenses=project/'licenses/godot_android_surface';licenses.mkdir(parents=True)
 for name in ('NOTICE','LICENSE-2.0.txt','GODOT-LICENSE.txt'):shutil.copy2(patch_root/name,licenses/(name if name.endswith('.txt') else name+'.txt'))
 subprocess.run([sys.executable,str(patch_root/'build_library.py'),'--aar',str(stock),'--variant',variant,'--jdk',str(a.jdk),'--android-jar',str(a.sdk/'platforms/android-35/android.jar'),'--out',str(out/('surface-'+variant+'.aar'))],check=True,timeout=120)
 shutil.copy2(out/('surface-'+variant+'.aar'),library)
 preset=project/'export_presets.cfg';text=preset.read_text();assert 'gradle_build/use_gradle_build=false' in text
 # Only the requested target is exported. Native compression controls size, not code.
 assert 'licenses/*.txt' in text
 text=text.replace('licenses/*.txt','licenses/*.txt,licenses/godot_android_surface/*.txt')
 text=text.replace('gradle_build/use_gradle_build=false','gradle_build/use_gradle_build=true')
 text=text.replace('gradle_build/use_gradle_build=true','gradle_build/use_gradle_build=true\ngradle_build/compress_native_libraries=true')
 preset.write_text(text)
 props=build/'gradle.properties';import re
 text=re.sub(r'org.gradle.jvmargs=.*','org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8',props.read_text());props.write_text(text+'\norg.gradle.workers.max=2\n')
 os.environ['JAVA_HOME']=str(a.jdk);os.environ['ANDROID_HOME']=str(a.sdk)
 checked_godot([str(a.godot),'--headless','--path',str(project),'--editor','--import','--quit'],120)
 apk=out/('game-avia-surface-debug.apk' if a.target=='apk' else 'game-avia-surface-unsigned.aab')
 checked_godot([str(a.godot),'--headless','--path',str(project),'--export-debug' if a.target=='apk' else '--export-release','Android Debug' if a.target=='apk' else 'Android AAB Unsigned',str(apk)],600)
 assert hashes(source)==original_hashes,'source changed during build'
 staged_hashes=hashes(project);assert all(staged_hashes[n]==h for n,h in original_hashes.items() if n!='export_presets.cfg'),'staged game source mismatch'
 java=json.loads((out/('surface-'+variant+'.aar.json')).read_text())
 with zipfile.ZipFile(apk) as z:
  native={n:hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.endswith('.so')}
  assert len(native)==4 and all(java['native_libraries_unchanged']['jni/'+n.partition('lib/')[2]]==h for n,h in native.items())
 manifest={'target':a.target,'commit':commit,'dirty':dirty,'engine':'4.7.2.stable.official.ed1daf0bf','android_java':'custom SurfaceHolder generation recovery; not stock Java','source_files_sha256':original_hashes,'java_build':java,'artifact':apk.name,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),'bytes':apk.stat().st_size,'signature':'existing external debug key' if a.target=='apk' else 'unsigned; no release key configured','runtime':'NOT VERIFIED by export; keep separate actual scenario evidence','installed_templates_modified':False,'working_game_modified':False,'native_libraries':native}
 (out/(apk.name+'.json')).write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:manifest[k] for k in ('commit','dirty','sha256','bytes','android_java')}))
if __name__=='__main__':main()
