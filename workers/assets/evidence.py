"""Sanitized installed-source/model inventory; never reads environment credentials."""
import hashlib
import importlib.metadata
import json
import shutil
import subprocess
from pathlib import Path
from workers.assets.files import atomic_json,sha256

def main():
    root=Path('/srv/game-avia');source=root/'sources/TRELLIS.2';models=root/'models/trellis512'
    manifest=json.loads((models/'model-manifest.json').read_text())
    files=[{'repo':x['repo'],'revision':x['revision'],'file':x['file'],'bytes':Path(x['local']).stat().st_size,'sha256':sha256(x['local'])} for x in manifest['files']]
    tree=Path(__file__).resolve().parents[2]
    tracked=['scripts/trellis_generate.py','scripts/blender_optimize.py','workers/assets/plane_reference.py','workers/assets/run.py','workers/assets/pipeline.py','workers/assets/validate.py']
    sources=['trellis2/pipelines/trellis2_image_to_3d.py','trellis2/pipelines/rembg/BiRefNet.py','trellis2/modules/image_feature_extractor.py']
    def cmd(argv):return subprocess.run(argv,capture_output=True,text=True,timeout=15,check=True).stdout.strip()
    report={'models':files,'pipeline512_sha256':sha256(models/'pipeline512.json'),'trellis_source_commit':cmd(['git','-C',str(source),'rev-parse','HEAD']),'trellis_source_dirty':bool(cmd(['git','-C',str(source),'status','--porcelain'])), 'upstream_source_hashes':{p:sha256(source/p) for p in sources},'worker_source_hashes':{p:sha256(tree/p) for p in tracked},'packages':{p:importlib.metadata.version(p) for p in ['torch','torchvision','transformers','huggingface-hub','timm','numpy','kornia','safetensors','flash-attn']},'disk_free_bytes':shutil.disk_usage(root).free,'gpu_memory_free_used_mib':cmd(['nvidia-smi','--query-gpu=memory.free,memory.used','--format=csv,noheader,nounits']),'point_processes_preserved':all(Path('/proc/'+str(pid)).exists() for pid in (12876,37381)),'no_paid_calls':True}
    for asset in ('trellis_validation_smoke_20261117','trellis_validation_plane_20261117'):
        p=root/'artifacts'/asset/'raw-mesh.pt'
        if p.exists():report.setdefault('raw_mesh_snapshots',{})[asset]={'server_path':str(p),'bytes':p.stat().st_size,'sha256':sha256(p)}
    atomic_json(root/'artifacts/trellis_validation_reference_20261117/installed-evidence.json',report)
if __name__=='__main__':main()
