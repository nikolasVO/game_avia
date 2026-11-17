"""Run under the existing Python 3.10 TRELLIS venv only after preparation succeeds."""
import json
import os
import sys
import time
import hashlib
from pathlib import Path
os.environ["HF_HUB_OFFLINE"]="1"
os.environ["TRANSFORMERS_OFFLINE"]="1"
os.environ["PYTORCH_CUDA_ALLOC_CONF"]="expandable_segments:True"
sys.path.insert(0,"/srv/game-avia/sources/TRELLIS.2")

def validate_compact(cfg,root):
    args=cfg["args"]
    expected={"sparse_structure_flow_model","sparse_structure_decoder","shape_slat_flow_model_512","shape_slat_decoder","tex_slat_flow_model_512","tex_slat_decoder"}
    if args["default_pipeline_type"]!="512" or set(args["models"])!=expected:
        raise RuntimeError("non_compact_pipeline")
    if args["rembg_model"]!={"name":"BiRefNet","args":{"model_name":str(root/"birefnet")}}:
        raise RuntimeError("only_pinned_local_BiRefNet_allowed")
    if args["image_cond_model"]["name"]!="DinoV3FeatureExtractor" or args["image_cond_model"]["args"]["model_name"]!=str(root/"dino"):
        raise RuntimeError("only_pinned_local_DINOv3_allowed")
    for prefix in args["models"].values():
        for suffix in (".json",".safetensors"):
            path=Path(prefix+suffix).resolve()
            if root.resolve() not in path.parents or not path.is_file():raise RuntimeError("checkpoint_missing_or_external")
    # Custom model Python is executable: inspected files from the pinned BiRefNet revision.
    custom={"birefnet.py":"208771ae626f653d64128fbf2d6ac9f8e645c5cc5e286258a73ec3322bbfe5ef","BiRefNet_config.py":"e7b8c2a74f6cea6a59553d517f71d47f2c1d90e670a13416af17c25fe2f3dc52"}
    for name,digest in custom.items():
        if hashlib.sha256((root/"birefnet"/name).read_bytes()).hexdigest()!=digest:
            raise RuntimeError("pinned_custom_model_code_mismatch")

def main():
    import argparse
    p=argparse.ArgumentParser();p.add_argument("--request",required=True);p.add_argument("--models",required=True);p.add_argument("--output",required=True)
    a=p.parse_args()
    cfg=json.loads(Path(a.models,"pipeline512.json").read_text())
    args=cfg["args"]
    validate_compact(cfg,Path(a.models))
    request=json.loads(Path(a.request).read_text())
    from PIL import Image
    from trellis2.pipelines import Trellis2ImageTo3DPipeline
    import o_voxel
    started=time.monotonic()
    import torch
    torch.set_num_threads(2)
    torch.cuda.reset_peak_memory_stats()
    pipeline=Trellis2ImageTo3DPipeline.from_pretrained(a.models,config_file="pipeline512.json")
    pipeline.cuda()
    mesh=pipeline.run(Image.open(request["reference_path"]),seed=request.get("seed",42),pipeline_type="512")[0]
    evidence={"inference_succeeded":True,"seconds":time.monotonic()-started,"vertices":int(mesh.vertices.shape[0]),"faces":int(mesh.faces.shape[0]),"peak_vram_allocated_bytes":torch.cuda.max_memory_allocated(),"peak_vram_reserved_bytes":torch.cuda.max_memory_reserved(),"reference_sha256":hashlib.sha256(Path(request["reference_path"]).read_bytes()).hexdigest()}
    output=Path(a.output)
    torch.save({"vertices":mesh.vertices.cpu(),"faces":mesh.faces.cpu(),"attrs":mesh.attrs.cpu(),"coords":mesh.coords.cpu(),"layout":mesh.layout,"voxel_size":mesh.voxel_size},output.with_name("raw-mesh.pt"))
    output.with_name("inference-evidence.json").write_text(json.dumps(evidence,indent=2))
    print("INFERENCE_SUCCEEDED="+json.dumps(evidence),flush=True)
    mesh.simplify(16777216)
    glb=o_voxel.postprocess.to_glb(vertices=mesh.vertices,faces=mesh.faces,attr_volume=mesh.attrs,
        coords=mesh.coords,attr_layout=mesh.layout,voxel_size=mesh.voxel_size,aabb=[[-.5,-.5,-.5],[.5,.5,.5]],
        decimation_target=100000,texture_size=1024,remesh=True,remesh_band=1,remesh_project=0,verbose=False)
    glb.export(str(output.with_suffix(".tmp.glb")),extension_webp=False)
    output.with_suffix(".tmp.glb").replace(output)
if __name__=="__main__":main()

