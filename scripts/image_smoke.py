import asyncio,json
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.assets.images import generate_reference
load_environment()
r=asyncio.run(generate_reference(Store(state_dir()/"coordinator.sqlite3"),"OPENLUX_IMAGE","gpt-image-2",
    "A simple matte orange wooden toy cube with beveled edges, one object centered, three-quarter view, neutral white background, even studio lighting, no text or symbols. Technical 3D reference.",
    "/srv/game-avia/artifacts/reference-smoke.png"))
Path("/srv/game-avia/state/image-smoke.json").write_text(json.dumps(r,indent=2))
print(json.dumps(r,indent=2))

