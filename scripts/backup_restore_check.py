import json
import sqlite3
import tempfile
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store

load_environment()
source=Store(state_dir()/"coordinator.sqlite3")
dest=state_dir()/"coordinator.backup.sqlite3"
source.backup(dest)
with tempfile.TemporaryDirectory() as d:
    restored=Path(d)/"restore.sqlite3"
    with sqlite3.connect(dest) as a,sqlite3.connect(restored) as b:a.backup(b)
    with sqlite3.connect(restored) as c:
        assert c.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
        count=c.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
source.kv("backup_tested","true")
print(json.dumps({"local_backup_restore":"passed","restored_tasks":count,"off_server_backup":"not_configured"}))

