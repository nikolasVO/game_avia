"""Import a GLB into an isolated Godot project, measure it, optionally render it."""
import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from workers.assets.files import atomic_json,sha256

def checked_geometry(out):
    manifest=json.loads((out/'geometry-manifest.json').read_text())
    if not manifest.get('verified') or not manifest.get('checks') or not all(manifest['checks'].values()):
        raise RuntimeError('unverified_geometry_cannot_be_published')
    for name,record in manifest['files'].items():
        path=(out/name).resolve()
        if not path.is_relative_to(out.resolve()) or not path.is_file() or sha256(path)!=record['sha256']:
            raise RuntimeError('geometry_artifact_hash_mismatch')
    return manifest


def main():
    p=argparse.ArgumentParser();p.add_argument('--artifact-dir',required=True);p.add_argument('--godot',required=True)
    p.add_argument('--dimensions',type=float,nargs=3,required=True);p.add_argument('--render',action='store_true')
    p.add_argument('--disable-mesh-compression',action='store_true',help='Use when actual imported vertices collapse; record the matching game import setting')
    a=p.parse_args();out=Path(a.artifact_dir).resolve()
    manifest=checked_geometry(out)
    with tempfile.TemporaryDirectory(prefix='avia-asset-import-') as tmp:
        project=Path(tmp)
        shutil.copy2(out/'optimized.glb',project/'optimized.glb')
        shutil.copy2(Path(__file__).with_suffix('.gd'),project/'validate.gd')
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Isolated asset validation"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[display]\nwindow/size/viewport_width=768\nwindow/size/viewport_height=768\n')
        commands=[[a.godot,'--headless','--path',tmp,'--editor','--import'],[a.godot,*([] if a.render else ['--headless']),'--path',tmp,'--script','res://validate.gd','--',str(out/'godot-validation.json'),*[str(x) for x in a.dimensions]]]
        first=subprocess.run(commands[0],capture_output=True,text=True,timeout=180)
        (out/'godot-initial-import.log').write_text(first.stdout+first.stderr)
        if first.returncode or any(x in first.stdout+first.stderr for x in ('SCRIPT ERROR','ERROR:','Parse Error')):raise RuntimeError('godot_initial_import_failed')
        import_settings=project/'optimized.glb.import'
        text=import_settings.read_text().replace('meshes/generate_lods=true','meshes/generate_lods=false')
        if a.disable_mesh_compression:text=text.replace('meshes/force_disable_compression=false','meshes/force_disable_compression=true')
        import_settings.write_text(text)
        for i,command in enumerate(commands):
            result=subprocess.run(command,capture_output=True,text=True,timeout=180)
            (out/('godot-import.log' if i==0 else 'godot-validation.log')).write_text(result.stdout+result.stderr)
            if result.returncode or any(x in result.stdout+result.stderr for x in ('SCRIPT ERROR','ERROR:','Parse Error')):raise RuntimeError('godot_validation_failed; see isolated log')
        result=json.loads((out/'godot-validation.json').read_text())
        result.update(mesh_compression_disabled=a.disable_mesh_compression,explicit_lods_preserved=True)
        result["validator_files_sha256"]={"workers/assets/godot_validate.py":sha256(Path(__file__)),"workers/assets/godot_validate.gd":sha256(Path(__file__).with_suffix(".gd"))}
        atomic_json(out/'godot-validation.json',result)
        if not result['import_passed'] or (a.render and not result['preview_rendered']):raise RuntimeError('godot_geometry_or_preview_failed')
        checked_geometry(out)
        manifest.update({'asset_id':out.name,'source_type':'AI','godot_import_tested':True,'godot_import':result,'pipeline_verified':True,'production_accepted':False})
        for name in ('original.glb','godot-validation.json','inference-evidence.json',*result.get("preview_files",[])):
            manifest['files'][name]={'sha256':sha256(out/name),'bytes':(out/name).stat().st_size}
        if (out/'provenance.json').is_file():
            manifest['provenance_file']='provenance.json'
            manifest['forward_axis']=json.loads((out/'provenance.json').read_text()).get('forward_axis','not_verified')
            manifest['files']['provenance.json']={'sha256':sha256(out/'provenance.json'),'bytes':(out/'provenance.json').stat().st_size}
        atomic_json(out/'manifest.json',manifest)
        print(json.dumps({'pipeline_verified':True,'production_accepted':False,'artifact_dir':str(out)}))

if __name__=='__main__':main()
