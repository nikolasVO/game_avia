"""Small durable catalog queue adapter over the existing Store. No second scheduler/worker.

Reference authoring/approval and resource guarded AssetSpec submission remain explicit.
Sync is idempotent and never rewinds a running job after interruption.
"""
import json
import time

QUEUE_KEY = "aircraft_production_queue:v1"

def sync_queue(store, manifest, task_id):
    incoming = {job["job_id"]: job for job in manifest["jobs"]}
    if len(incoming) != len(manifest["jobs"]):
        raise ValueError("duplicate_production_job")
    with store.db() as c:
        row = c.execute("SELECT value FROM kv WHERE key=?", (QUEUE_KEY,)).fetchone()
        queue = json.loads(row[0]) if row else {"schema": 1, "jobs": {}}
        added = []
        for jid, job in incoming.items():
            if jid in queue["jobs"]:
                if queue["jobs"][jid]["aircraft_id"] != job["aircraft_id"]:
                    raise ValueError("production_identity_conflict")
                continue
            queue["jobs"][jid] = dict(job, parent_task=task_id, updated=time.time())
            added.append(jid)
        if added:
            c.execute("INSERT INTO kv(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (QUEUE_KEY, json.dumps(queue)))
            store._event(c, task_id, f"Очередь производства: {len(added)} устойчивых заданий добавлено, всего {len(queue['jobs'])}. Это очередь, не готовые самолёты. Платные изображения запрещены; reference/GPU/10GiB guards обязательны.", "asset_queue")
    return {"added": len(added), "total": len(queue["jobs"])}
