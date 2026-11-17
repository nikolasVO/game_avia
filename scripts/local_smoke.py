import asyncio,json
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.coding.local import local_smoke
load_environment()
report=asyncio.run(local_smoke(Store(state_dir()/"coordinator.sqlite3"),"/srv/game-avia"))
Path("/srv/game-avia/state/local-smoke.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

