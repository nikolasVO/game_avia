"""Native build preconditions; an exit code alone does not prove a Godot export."""
from pathlib import Path
import subprocess


def check_materialized_assets(project):
    for path in (Path(project)/'assets').rglob('*'):
        if path.is_file():
            with path.open('rb') as source:head=source.read(128)
            if head.startswith(b'version https://git-lfs.github.com/spec/v1'):
                raise RuntimeError('unmaterialized_LFS_asset: '+str(path)+'; run git lfs install --local && git lfs pull')


def checked_godot(argv,timeout):
    result=subprocess.run(argv,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout)
    print(result.stdout,end='',flush=True)
    if result.returncode or any(marker in result.stdout for marker in ('ERROR:','SCRIPT ERROR','Parse Error','Export failed')):
        raise RuntimeError('Godot import/export failed; no build manifest will be published')
    return result
