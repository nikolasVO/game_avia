"""Journaled postprocess-only correction of a known completed generation."""
import argparse
import json
import shutil
import threading
import time
from pathlib import Path
from orchestrator.store import Store
from workers.assets.files import atomic_json,sha256
from workers.assets.run import run_process
from workers.assets.pipeline import AssetSpec


def main():
    p=argparse.ArgumentParser();p.add_argument('--task-id',required=True);p.add_argument('--yaw',required=True,type=float)
    a=p.parse_args();root=Path('/srv/game-avia');repo=Path(__file__).resolve().parents[2]
    store=Store(root/'state/runtime/coordinator.sqlite3');task=store.get_task(a.task_id)
    owner='trellis-postprocess-20261117';out=root/'artifacts'/task['spec']['asset_id']
    old=json.loads((out/'geometry-manifest.json').read_text())
    assert sha256(out/'original.glb')==old['generation']['original_sha256']
    script_hash=sha256(repo/'scripts/blender_optimize.py')
    operation='orientation:'+task['id']+':'+str(a.yaw)+':'+script_hash[:12]
    done=store.prepare_tool(task['id'],operation,'postprocess_orientation',{'yaw':a.yaw,'original_sha256':old['generation']['original_sha256'],'blender_script_sha256':script_hash})
    if done is not None:print('already_reconciled');return
    with store.db() as c:
        c.execute('BEGIN IMMEDIATE')
        row=c.execute('SELECT status FROM tasks WHERE id=?',(task['id'],)).fetchone()
        if row['status']!='blocked':raise RuntimeError('task_not_safely_blocked')
        task['spec']['source_yaw_degrees']=a.yaw
        c.execute("UPDATE tasks SET status='running',owner=?,lease_until=?,spec=? WHERE id=?",(owner,time.time()+300,json.dumps(task['spec']),task['id']))
        store._event(c,task['id'],'Контрольный верхний вид выявил нос вдоль -X. Исправляется только Blender orientation; original GLB и inference сохранены.','asset')
    stop=threading.Event()
    def beat():
        while not stop.wait(20):
            if not store.heartbeat(task['id'],owner,seconds=300):return
    thread=threading.Thread(target=beat);thread.start()
    fence=store.acquire_gpu(task['id'],seconds=300)
    if fence is None:
        stop.set();thread.join();store.transition(task['id'],'blocked','waiting_gpu',owner=owner);raise RuntimeError('waiting_gpu')
    try:
        backup=out/('pre-orientation-'+script_hash[:12]);backup.mkdir(exist_ok=False)
        for path in out.iterdir():
            if path.is_file() and path.suffix in ('.glb','.png','.json'):shutil.copy2(path,backup/path.name)
        run_process(store,task,owner,fence,[str(root/'tools/blender-5.2.4-linux-x64/blender'),'--background','--factory-startup','--threads','2','--python',str(repo/'scripts/blender_optimize.py'),'--','--input',str(out/'original.glb'),'--output-dir',str(out),'--manifest-name','blender-manifest.json','--rotate-z-degrees',str(a.yaw),'--triangles',str(task['spec']['triangle_budget']),'--texture-size','1024','--dimensions',*[str(task['spec']['dimensions_m'][i]) for i in (0,2,1)]],out/('blender-oriented-'+script_hash[:12]+'.private.log'),time.monotonic()+300)
        geometry=json.loads((out/'blender-manifest.json').read_text())
        geometry.update({k:old[k] for k in ('source_kind','generation','reference','license')})
        geometry['godot_import_tested']=False
        atomic_json(out/'geometry-manifest.json',geometry)
        request=json.loads((out/'request.json').read_text());request['spec']=AssetSpec.model_validate(task['spec']).model_dump(mode='json');atomic_json(out/'request.json',request)
        store.finish_tool(operation,{'geometry_manifest_sha256':sha256(out/'geometry-manifest.json')})
        store.transition(task['id'],'blocked','Orientation postprocess complete; isolated Godot revalidation pending.',owner=owner)
    finally:
        store.release_gpu(task['id'],fence);stop.set();thread.join(timeout=2)

if __name__=='__main__':main()
