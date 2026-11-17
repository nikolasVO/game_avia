import contextlib
import json
import sqlite3
import time
import uuid

STATES = {"queued", "planning", "ready", "running", "verifying", "reviewing", "completed", "failed", "blocked", "paused", "cancelled"}
TERMINAL = {"completed", "failed", "cancelled"}

class Store:
    def __init__(self, path):
        self.path = str(path)
        with self.db() as c:
            c.executescript("""
            CREATE TABLE IF NOT EXISTS tasks(
              id TEXT PRIMARY KEY, goal TEXT NOT NULL, kind TEXT NOT NULL, spec TEXT NOT NULL,
              status TEXT NOT NULL, result TEXT, owner TEXT, lease_until REAL,
              created REAL NOT NULL, updated REAL NOT NULL,
              execution_status TEXT DEFAULT 'pending', verification_status TEXT DEFAULT 'unverified',
              github_sync_status TEXT DEFAULT 'pending', notification_status TEXT DEFAULT 'pending');
            CREATE TABLE IF NOT EXISTS dependencies(task_id TEXT, depends_on TEXT, PRIMARY KEY(task_id,depends_on));
            CREATE TABLE IF NOT EXISTS events(id TEXT PRIMARY KEY, task_id TEXT, type TEXT, text TEXT, created REAL);
            CREATE TABLE IF NOT EXISTS notification_outbox(
              event_id TEXT PRIMARY KEY, text TEXT, status TEXT DEFAULT 'pending',
              message_id INTEGER, attempts INTEGER DEFAULT 0, next_at REAL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS telegram_updates(update_id INTEGER PRIMARY KEY, created REAL);
            CREATE TABLE IF NOT EXISTS kv(key TEXT PRIMARY KEY,value TEXT);
            CREATE TABLE IF NOT EXISTS tool_operations(
              id TEXT PRIMARY KEY, task_id TEXT, tool TEXT, args TEXT, status TEXT,
              result TEXT, created REAL, updated REAL);
            CREATE TABLE IF NOT EXISTS gpu_leases(
              resource TEXT PRIMARY KEY, owner TEXT, fence INTEGER NOT NULL, expires REAL);
            CREATE TABLE IF NOT EXISTS provider_routes(
              id TEXT PRIMARY KEY,state TEXT,until REAL,failures INTEGER DEFAULT 0,evidence TEXT);
            CREATE TABLE IF NOT EXISTS usage_ledger(
              id TEXT PRIMARY KEY, task_id TEXT, route TEXT, requests INTEGER, tokens INTEGER,
              cost_status TEXT, created REAL);
            CREATE TABLE IF NOT EXISTS actual_usage(id TEXT PRIMARY KEY,usage TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS artifacts(id TEXT PRIMARY KEY,task_id TEXT,path TEXT,sha256 TEXT,metadata TEXT);
            CREATE TABLE IF NOT EXISTS sync_jobs(id TEXT PRIMARY KEY,task_id TEXT,branch TEXT,status TEXT,error TEXT);
            CREATE TABLE IF NOT EXISTS decisions(id TEXT PRIMARY KEY,task_id TEXT,text TEXT,created REAL);
            CREATE TABLE IF NOT EXISTS attempts(id TEXT PRIMARY KEY,task_id TEXT,route TEXT,status TEXT,created REAL);
            """)
            columns={r[1] for r in c.execute("PRAGMA table_info(notification_outbox)")}
            for name,definition in (("kind","TEXT DEFAULT 'text'"),("artifact_path","TEXT")):
                if name not in columns:c.execute("ALTER TABLE notification_outbox ADD COLUMN "+name+" "+definition)
    def artifact_event(self,task_id,path,caption,kind="document"):
        if kind not in ("photo","document"):raise ValueError("invalid_artifact_kind")
        from pathlib import Path
        target=Path(path).resolve()
        roots=[Path("/srv/game-avia/artifacts").resolve(),Path("/srv/game-avia/repo/assets").resolve()]
        if not any(root in target.parents for root in roots) or not target.is_file() or target.stat().st_size>49*1024**2:
            raise ValueError("invalid_artifact_path")
        with self.db() as c:
            eid=self._event(c,task_id,caption,"artifact")
            c.execute("UPDATE notification_outbox SET kind=?,artifact_path=? WHERE event_id=?",(kind,str(target),eid))
        return eid
    @contextlib.contextmanager
    def db(self):
        c = sqlite3.connect(self.path, timeout=30)
        c.row_factory = sqlite3.Row
        c.execute("PRAGMA journal_mode=WAL")
        c.execute("PRAGMA foreign_keys=ON")
        try:
            yield c
            c.commit()
        except BaseException:
            c.rollback()
            raise
        finally:
            c.close()
    def _event(self, c, task_id, text, event_type="progress"):
        if task_id:c.execute("UPDATE tasks SET notification_status='pending' WHERE id=?",(task_id,))
        eid = uuid.uuid4().hex
        c.execute("INSERT INTO events VALUES(?,?,?,?,?)", (eid, task_id, event_type, text, time.time()))
        c.execute("INSERT INTO notification_outbox(event_id,text) VALUES(?,?)", (eid, f"[{task_id or 'system'}] {text}"[:3900]))
        return eid
    def event(self, task_id, text, event_type="progress"):
        with self.db() as c:
            return self._event(c, task_id, text, event_type)
    def _task(self, c, goal, kind, spec):
        tid = uuid.uuid4().hex[:12]
        now = time.time()
        c.execute("INSERT INTO tasks(id,goal,kind,spec,status,created,updated) VALUES(?,?,?,?,?,?,?)",
                  (tid, goal, kind, json.dumps(spec or {}), "queued", now, now))
        self._event(c, tid, "Задание принято: " + goal[:1000], "accepted")
        return tid
    def create_task(self, goal, kind="code", spec=None):
        with self.db() as c:
            tid = self._task(c, goal, kind, spec)
        return self.get_task(tid)
    def ingest(self, update_id, goal=None, reply=None):
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            if c.execute("SELECT 1 FROM telegram_updates WHERE update_id=?", (update_id,)).fetchone():
                return None
            c.execute("INSERT INTO telegram_updates VALUES(?,?)", (update_id, time.time()))
            if goal:
                return self._task(c, goal, "code", {})
            if reply:
                self._event(c, None, reply, "command")
        return True
    def ingest_command(self, update_id, text, handler):
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            if c.execute("SELECT 1 FROM telegram_updates WHERE update_id=?",(update_id,)).fetchone():return None
            c.execute("INSERT INTO telegram_updates VALUES(?,?)",(update_id,time.time()))
            reply=handler(text,c)
            self._event(c,None,reply,"command")
        return True
    def get_task(self, tid):
        with self.db() as c:
            row = c.execute("SELECT * FROM tasks WHERE id=?", (tid,)).fetchone()
        if row:
            d = dict(row); d["spec"] = json.loads(d["spec"])
            return d
    def list_tasks(self, limit=30):
        with self.db() as c:
            return [dict(r) for r in c.execute("SELECT * FROM tasks ORDER BY created DESC LIMIT ?", (limit,))]
    def claim(self, owner, seconds=120):
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            row = c.execute("""SELECT * FROM tasks WHERE status IN ('queued','ready')
              AND NOT EXISTS(SELECT 1 FROM dependencies d JOIN tasks t ON t.id=d.depends_on
              WHERE d.task_id=tasks.id AND t.status!='completed') ORDER BY created LIMIT 1""").fetchone()
            if not row: return None
            c.execute("UPDATE tasks SET status='running',execution_status='running',owner=?,lease_until=?,updated=? WHERE id=?",
                      (owner,time.time()+seconds,time.time(),row["id"]))
            self._event(c,row["id"],"Начато выполнение; критерии проверяются перед завершением.","running")
        return self.get_task(row["id"])
    def heartbeat(self, tid, owner, seconds=120):
        with self.db() as c:
            r=c.execute("UPDATE tasks SET lease_until=? WHERE id=? AND owner=? AND lease_until>? AND status IN ('running','planning','verifying','reviewing')",
                        (time.time()+seconds,tid,owner,time.time()))
            return bool(r.rowcount)
    def assert_active(self,tid,owner=None):
        task=self.get_task(tid)
        if not task:return
        if task["kind"]=="diagnostic":return
        if task["status"] not in ("running","planning","verifying","reviewing") or (task["lease_until"] or 0)<time.time():
            raise RuntimeError("task_cancelled_or_lease_lost")
        if owner and task["owner"]!=owner:raise RuntimeError("stale_task_owner")
    def transition(self, tid, status, result=None, owner=None):
        if status not in STATES: raise ValueError("invalid_state")
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            row=c.execute("SELECT * FROM tasks WHERE id=?",(tid,)).fetchone()
            if not row: raise KeyError(tid)
            if row["status"] in TERMINAL and row["status"] != status: raise ValueError("terminal_task")
            if row["status"] in ("paused","cancelled") and owner: raise ValueError("task_not_active")
            if owner and (row["owner"]!=owner or (row["lease_until"] or 0)<time.time()):
                raise ValueError("stale_task_owner")
            c.execute("UPDATE tasks SET status=?,result=?,updated=?,execution_status=? WHERE id=?",
                      (status,result,time.time(),status,tid))
            self._event(c,tid,f"Состояние: {status}. "+(result or "")[:2500],"state")
    def recover(self):
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            rows=c.execute("SELECT id FROM tasks WHERE status IN ('running','planning','verifying','reviewing') AND lease_until<?",(time.time(),)).fetchall()
            for r in rows:
                unknown=c.execute("SELECT 1 FROM tool_operations WHERE task_id=? AND status='started'",(r["id"],)).fetchone()
                status="blocked" if unknown else "ready"
                c.execute("UPDATE tasks SET status=?,owner=NULL,lease_until=NULL WHERE id=?",(status,r["id"]))
                self._event(c,r["id"],"Восстановление после прерывания: "+status+("; требуется сверка незавершённой операции" if unknown else ""),"recovery")
            return len(rows)
    def prepare_tool(self, tid, opid, tool, args):
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            row=c.execute("SELECT * FROM tool_operations WHERE id=?",(opid,)).fetchone()
            if row:
                if row["tool"]!=tool or json.loads(row["args"])!=args:raise RuntimeError("tool_call_id_argument_mismatch")
                if row["status"]=="done": return json.loads(row["result"])
                raise RuntimeError("tool_outcome_unknown")
            c.execute("INSERT INTO tool_operations VALUES(?,?,?,?,?,?,?,?)",
                      (opid,tid,tool,json.dumps(args),"started",None,time.time(),time.time()))
        return None
    def finish_tool(self, opid, result):
        with self.db() as c:
            c.execute("UPDATE tool_operations SET status='done',result=?,updated=? WHERE id=?",
                      (json.dumps(result),time.time(),opid))
    def acquire_gpu(self, owner, seconds=300):
        with self.db() as c:
            c.execute("BEGIN IMMEDIATE")
            busy=c.execute("SELECT value FROM kv WHERE key='gpu_external_busy'").fetchone()
            if busy and busy[0]!='false':return None
            proc=c.execute("SELECT value FROM kv WHERE key='gpu_process'").fetchone()
            if proc and proc[0]:
                import os
                try:
                    os.kill(int(proc[0]),0)
                    return None
                except (ProcessLookupError,ValueError):pass
                except PermissionError:return None
            row=c.execute("SELECT * FROM gpu_leases WHERE resource='gpu0'").fetchone()
            if row and row["expires"]>time.time(): return None
            fence=(row["fence"] if row else 0)+1
            c.execute("INSERT OR REPLACE INTO gpu_leases VALUES('gpu0',?,?,?)",(owner,fence,time.time()+seconds))
            return fence
    def renew_gpu(self, owner, fence, seconds=300):
        with self.db() as c:
            return bool(c.execute("UPDATE gpu_leases SET expires=? WHERE resource='gpu0' AND owner=? AND fence=? AND expires>?",
                        (time.time()+seconds,owner,fence,time.time())).rowcount)
    def release_gpu(self, owner, fence):
        with self.db() as c:
            c.execute("UPDATE gpu_leases SET expires=0 WHERE resource='gpu0' AND owner=? AND fence=?",(owner,fence))
    def kv(self, key, value=None):
        with self.db() as c:
            if value is not None:
                c.execute("INSERT OR REPLACE INTO kv VALUES(?,?)",(key,str(value)))
                return str(value)
            r=c.execute("SELECT value FROM kv WHERE key=?",(key,)).fetchone()
            return r[0] if r else None
    def backup(self, dest):
        with self.db() as source, sqlite3.connect(str(dest)) as target:
            source.backup(target)

