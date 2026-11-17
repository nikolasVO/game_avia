"""Journaled postprocess-only correction of a known completed generation."""
import argparse
import json
import hashlib
import shutil
import threading
import time
from pathlib import Path
from orchestrator.store import Store
from workers.assets.files import atomic_json,sha256
from workers.assets.run import run_process
from workers.assets.pipeline import AssetSpec,disk_guard


def main():
    p=argparse.ArgumentParser();p.add_argument('--task-id',required=True);p.add_argument('--yaw',required=True,type=float);p.add_argument('--symmetry-x',action='store_true')
    a=p.parse_args();root=Path('/srv/game-avia');repo=Path(__file__).resolve().parents[2]
    store=Store(root/'state/runtime/coordinator.sqlite3');task=store.get_task(a.task_id)
    owner='trellis-postprocess-20261117';out=root/'artifacts'/task['spec']['asset_id']
    old=json.loads((out/'geometry-manifest.json').read_text())
    if sha256(out/'original.glb')!=old['generation']['original_sha256']:raise RuntimeError('original_hash_mismatch')
    script_hash=sha256(repo/'scripts/blender_optimize.py')
    desired=AssetSpec.model_validate(dict(task['spec'],source_yaw_degrees=a.yaw,symmetry_policy='mirror_x' if a.symmetry_x else task['spec'].get('symmetry_policy','none')))
    revision=hashlib.sha256(json.dumps({'yaw':a.yaw,'symmetry':desired.symmetry_policy,'script':script_hash},sort_keys=True).encode()).hexdigest()[:12]
    operation='postprocess:'+task['id']+':'+revision
    with store.db() as c:prior=c.execute('SELECT status FROM tool_operations WHERE id=?',(operation,)).fetchone()
    if prior is None:
        if (out/'manifest.json').exists():raise RuntimeError('published_asset_requires_new_revision')
        disk_guard(root,additional=200*1024**2)
    done=store.prepare_tool(task['id'],operation,'postprocess_orientation',{'yaw':a.yaw,'symmetry':desired.symmetry_policy,'original_sha256':old['generation']['original_sha256'],'blender_script_sha256':script_hash})
    if done is not None:
        if sha256(out/'geometry-manifest.json')!=done['geometry_manifest_sha256']:raise RuntimeError('reconciled_output_changed')
        print('already_reconciled');return
    with store.db() as c:
        c.execute('BEGIN IMMEDIATE')
        row=c.execute('SELECT status FROM tasks WHERE id=?',(task['id'],)).fetchone()
        if row['status']!='blocked':raise RuntimeError('task_not_safely_blocked')
        task['spec']=desired.model_dump(mode='json')
        c.execute("UPDATE tasks SET status='running',owner=?,lease_until=?,spec=? WHERE id=?",(owner,time.time()+300,json.dumps(task['spec']),task['id']))
        store._event(c,task['id'],'Blender postprocess: явная ориентация/симметрия; original GLB и inference сохраняются, GPU generation не повторяется.','asset')
    stop=threading.Event()
    def beat():
        while not stop.wait(20):
            if not store.heartbeat(task['id'],owner,seconds=300):return
    thread=threading.Thread(target=beat);thread.start()
    fence=store.acquire_gpu(task['id'],seconds=300)
    if fence is None:
        stop.set();thread.join();store.transition(task['id'],'blocked','waiting_gpu',owner=owner);raise RuntimeError('waiting_gpu')
    try:
        backup=out/('pre-postprocess-'+revision);backup.mkdir(exist_ok=False)
        for path in out.iterdir():
            if path.is_file() and path.suffix in ('.glb','.png','.json'):shutil.copy2(path,backup/path.name)
        run_process(store,task,owner,fence,[str(root/'tools/blender-5.2.4-linux-x64/blender'),'--background','--factory-startup','--threads','2','--python',str(repo/'scripts/blender_optimize.py'),'--','--input',str(out/'original.glb'),'--output-dir',str(out),'--manifest-name','blender-manifest.json',*(['--symmetry-x'] if desired.symmetry_policy=='mirror_x' else []),'--rotate-z-degrees',str(a.yaw),'--triangles',str(task['spec']['triangle_budget']),'--texture-size','1024','--dimensions',*[str(task['spec']['dimensions_m'][i]) for i in (0,2,1)]],out/('blender-postprocess-'+revision+'.private.log'),time.monotonic()+300)
        geometry=json.loads((out/'blender-manifest.json').read_text())
        geometry.update({k:old[k] for k in ('source_kind','generation','reference','license')})
        geometry['godot_import_tested']=False
        geometry['postprocess_revision']=revision
        if desired.symmetry_policy=='mirror_x':geometry['source_kind']+='_Blender_mirror_x_repair'
        atomic_json(out/'geometry-manifest.json',geometry)
        request=json.loads((out/'request.json').read_text());request['spec']=AssetSpec.model_validate(task['spec']).model_dump(mode='json');request['model_revisions']=old['generation']['models']
        identity={k:request[k] for k in ('spec','references','model_revisions')}
        request['input_hash']=hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        atomic_json(out/'request.json',request)
        store.finish_tool(operation,{'geometry_manifest_sha256':sha256(out/'geometry-manifest.json')})
        store.transition(task['id'],'blocked','Orientation postprocess complete; isolated Godot revalidation pending.',owner=owner)
    except Exception as error:
        store.transition(task['id'],'blocked','Postprocess stopped: '+type(error).__name__+': '+str(error)[:180],owner=owner)
        raise
    finally:
        store.release_gpu(task['id'],fence);stop.set();thread.join(timeout=2)

if __name__=='__main__':main()
