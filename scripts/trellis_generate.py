"""Run under the existing Python 3.10 TRELLIS venv only after preparation succeeds."""
import json
import os
import sys
from pathlib import Path
os.environ["HF_HUB_OFFLINE"]="1"
os.environ["TRANSFORMERS_OFFLINE"]="1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"]="expandable_segments:True"
sys.path.insert(0,"/srv/game-avia/sources/TRELLIS.2")

def main():
    import argparse
    p=argparse.ArgumentParser();p.add_argument("--request",required=True);p.add_argument("--models",required=True);p.add_argument("--output",required=True)
    a=p.parse_args()
    cfg=json.loads(Path(a.models,"pipeline512.json").read_text())
    args=cfg["args"]
    if args["default_pipeline_type"]!="512" or any("1024" in k or "encoder" in k for k in args["models"]):raise RuntimeError("non_compact_pipeline")
    if args["rembg_model"]["name"]!="BiRefNet":raise RuntimeError("only_MIT_BiRefNet_allowed")
    for prefix in args["models"].values():
        for suffix in (".json",".safetensors"):
            if not Path(prefix+suffix).is_file():raise RuntimeError("checkpoint_missing")
    request=json.loads(Path(a.request).read_text())
    from PIL import Image
    from trellis2.pipelines import Trellis2ImageTo3DPipeline
    import o_voxel
    pipeline=Trellis2ImageTo3DPipeline.from_pretrained(a.models,config_file="pipeline512.json")
    pipeline.cuda()
    mesh=pipeline.run(Image.open(request["reference_path"]),seed=request.get("seed",42),pipeline_type="512")[0]
    mesh.simplify(16777216)
    glb=o_voxel.postprocess.to_glb(vertices=mesh.vertices,faces=mesh.faces,attr_volume=mesh.attrs,
        coords=mesh.coords,attr_layout=mesh.layout,voxel_size=mesh.voxel_size,aabb=[[-.5,-.5,-.5],[.5,.5,.5]],
        decimation_target=100000,texture_size=1024,remesh=True,remesh_band=1,remesh_project=0,verbose=False)
    glb.export(a.output,extension_webp=True)
if __name__=="__main__":main()

