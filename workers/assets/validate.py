"""Bounded external validation using the sole Store and GPU lease manager."""
import argparse
import json
import threading
import time
from pathlib import Path
from orchestrator.store import Store
from workers.assets.run import run_asset
from workers.assets.files import atomic_json


def reserve(store, key, spec, owner):
    with store.db() as c:
        c.execute('BEGIN IMMEDIATE')
        old = c.execute('SELECT value FROM kv WHERE key=?', (key,)).fetchone()
        if old:
            return old[0], False
        tid = store._task(c, 'TRELLIS live validation: ' + spec['asset_id'], 'asset', spec)
        c.execute("UPDATE tasks SET status='running',execution_status='running',owner=?,lease_until=? WHERE id=?", (owner, time.time()+300, tid))
        c.execute('INSERT INTO kv VALUES(?,?)', (key, tid))
        store._event(c, tid, 'Изолированная GPU-проверка; без платных API, игровые службы сохранены.', 'running')
    return tid, True


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--spec', required=True);p.add_argument('--root', default='/srv/game-avia')
    p.add_argument('--repo', required=True);p.add_argument('--key', required=True)
    a=p.parse_args();root=Path(a.root)
    store=Store(root/'state/runtime/coordinator.sqlite3')
    owner='trellis-validation-20261117'
    tid, fresh=reserve(store,a.key,json.loads(Path(a.spec).read_text()),owner)
    print(json.dumps({'task_id':tid,'fresh':fresh}),flush=True)
    if not fresh:
        print('Existing task preserved; reconcile files/process/tool journal before any retry.',flush=True)
        return
    stop=threading.Event()
    def beat():
        while not stop.wait(20):
            if not store.heartbeat(tid,owner,seconds=300):return
    thread=threading.Thread(target=beat,daemon=True);thread.start()
    try:
        result=run_asset(store,store.get_task(tid),owner,root,repo_root=Path(a.repo))
        out=root/'artifacts'/store.get_task(tid)['spec']['asset_id']
        atomic_json(out/'validation-result.json',result)
        store.transition(tid,'blocked',json.dumps({'status':result['status'],'artifact_dir':str(out),'remaining':'isolated Godot import, visual review and Git/LFS sync'}),owner=owner)
    except Exception as e:
        store.transition(tid,'blocked','Validation stopped: '+type(e).__name__+': '+str(e)[:200],owner=owner)
        raise
    finally:stop.set();thread.join(timeout=2)


if __name__=='__main__':main()
