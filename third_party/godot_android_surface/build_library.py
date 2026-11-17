#!/usr/bin/env python3
"""Build only the pinned Android GL Java classes; preserve every native library.
Experimental until the accompanying runtime evidence says otherwise.
Requires an existing official Godot4.7.2 debug AAR, JDK17, Android35 android.jar.
No download, deployment, credentials or installed-template mutation.
"""
import argparse,hashlib,io,json,subprocess,tempfile,zipfile
from pathlib import Path
PREFIX='org/godotengine/godot/gl/GLSurfaceView'
def sha(data):return hashlib.sha256(data).hexdigest()
def replace_zip(data,replacements):
 out=io.BytesIO()
 with zipfile.ZipFile(io.BytesIO(data)) as old,zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as new:
  assert set(replacements)<=set(old.namelist())
  for info in old.infolist():
   # Fixed original metadata makes repeat builds reproducible with the same JDK.
   new.writestr(info,replacements.get(info.filename,old.read(info.filename)))
 return out.getvalue()
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--aar',type=Path,required=True);p.add_argument('--jdk',type=Path,required=True);p.add_argument('--android-jar',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 assert a.aar.resolve()!=a.out.resolve(),'never overwrite the input AAR'
 source=Path(__file__).with_name('GLSurfaceView.java');data=source.read_bytes()
 assert sha(data)=='ab21e6cafd19a4acc39d90f78e3aaedb94491eec0f9e6cb6e78960821d0d3b92','modified patch source'
 original=a.aar.read_bytes()
 assert sha(original)=='9cfb115e508ce98e8cf9b655927ef894cdfc2fede18a82f995842388f7754102','expected official pinned debug AAR; never patch an unknown library'
 version=subprocess.check_output([str(a.jdk/'bin/javac'),'-version'],stderr=subprocess.STDOUT,text=True).strip();assert version.startswith('javac 17.'),version
 with zipfile.ZipFile(io.BytesIO(original)) as z:jar=z.read('classes.jar')
 with tempfile.TemporaryDirectory(prefix='avia-android-java-') as temp:
  td=Path(temp);(td/'original.jar').write_bytes(jar)
  subprocess.run([str(a.jdk/'bin/javac'),'-J-Xmx512m','--release','17','-classpath',str(a.android_jar)+':'+str(td/'original.jar'),'-d',str(td/'classes'),str(source)],check=True,timeout=60)
  compiled={str(f.relative_to(td/'classes')):f.read_bytes() for f in (td/'classes').rglob('*.class')}
  with zipfile.ZipFile(io.BytesIO(jar)) as z:
   expected={n for n in z.namelist() if n==PREFIX+'.class' or n.startswith(PREFIX+'$')}
   assert set(compiled)==expected,'unexpected class changes or incompatible AAR'
  result=replace_zip(original,{'classes.jar':replace_zip(jar,compiled)})
 with zipfile.ZipFile(io.BytesIO(original)) as old,zipfile.ZipFile(io.BytesIO(result)) as new:
  natives={n:sha(old.read(n)) for n in old.namelist() if n.endswith('.so')};assert natives
  assert all(new.read(n)==old.read(n) for n in old.namelist() if n!='classes.jar')
 a.out.parent.mkdir(parents=True,exist_ok=True);tmp=a.out.with_suffix(a.out.suffix+'.tmp');tmp.write_bytes(result);tmp.replace(a.out)
 report={'engine_commit':'ed1daf0bf001b61586d9930840f2f1394092c079','compiler':version,'source_sha256':sha(data),'input_aar_sha256':sha(original),'output_aar_sha256':sha(result),'classes_recompiled':sorted(compiled),'native_libraries_unchanged':natives,'runtime':'NOT VERIFIED by this build tool; see separate scenario evidence'}
 a.out.with_suffix(a.out.suffix+'.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'sha256':sha(result),'classes':len(compiled),'unchanged_native_libraries':len(natives)}))
if __name__=='__main__':main()
