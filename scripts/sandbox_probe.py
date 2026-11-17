import json
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.coding.sandbox import probe
load_environment()
report=probe("/srv/game-avia/worktrees")
Store(state_dir()/"coordinator.sqlite3").kv("sandbox_probe",json.dumps(report))
print(json.dumps(report,indent=2))
if not report["passed"]:raise SystemExit(1)

