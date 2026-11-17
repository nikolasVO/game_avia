import hashlib
import json
import math
import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import Literal
from pydantic import BaseModel,ConfigDict,Field,field_validator

class AssetSpec(BaseModel):
    model_config=ConfigDict(extra="forbid")
    asset_id:str=Field(pattern=r"^[a-zA-Z0-9_-]{1,64}$")
    purpose:str
    description:str
    style:str="technical test prop"
    reference_images:list[str]=Field(min_length=1,max_length=4)
    dimensions_m:tuple[float,float,float]=(1,1,1)
    source_yaw_degrees:float=Field(default=0,ge=-180,le=180,allow_inf_nan=False)
    orientation:Literal["Y-up"]="Y-up"
    pivot:Literal["bottom_center"]="bottom_center"
    triangle_budget:int=Field(default=5000,ge=100,le=100000)
    texture_budget:int=Field(default=1024,ge=128,le=4096)
    lod_policy:Literal["LOD0,LOD1,LOD2"]="LOD0,LOD1,LOD2"
    collision_policy:Literal["box"]="box"
    output_formats:list[Literal["glb"]]=Field(default_factory=lambda:["glb"],min_length=1,max_length=1)
    license_constraints:str="owned_or_permitted"
    deadline_seconds:int=Field(default=1800,ge=30,le=7200)
    cost_limit:float|None=Field(default=None,ge=0,allow_inf_nan=False)
    seed:int=42
    pipeline_type:str="512"
    @field_validator("pipeline_type")
    @classmethod
    def only_512(cls,v):
        if v!="512":raise ValueError("only_compact_512_installed")
        return v
    @field_validator("dimensions_m")
    @classmethod
    def finite_dimensions(cls,v):
        if any(not math.isfinite(x) or x<=0 or x>100 for x in v):raise ValueError("invalid_dimensions")
        return v

def reference_path(root,name):
    root=Path(root).resolve()
    p=(root/name).resolve()
    if root not in p.parents or not p.is_file() or p.suffix.lower() not in (".png",".jpg",".jpeg",".webp"):
        raise ValueError("invalid_reference_path")
    if p.stat().st_size>20*1024*1024:raise ValueError("reference_too_large")
    return p

def disk_guard(path,additional=0,reserve=10*1024**3):
    if shutil.disk_usage(path).free<additional+reserve:raise RuntimeError("low_disk")
    return True

def gpu_guard(required_mb=24000):
    r=subprocess.run(["nvidia-smi","--query-gpu=memory.free","--format=csv,noheader,nounits"],
                     capture_output=True,text=True,timeout=10,check=True)
    if int(r.stdout.strip().splitlines()[0])<required_mb:raise RuntimeError("insufficient_free_vram")
    return True

def compact_config(config, model_paths, dino_path, birefnet_path):
    # Called BEFORE the upstream from_pretrained loader: never instantiate BRIA.
    config=json.loads(json.dumps(config))
    args=config["args"]
    args["models"]={k:model_paths[k] for k in args["models"] if not any(x in k for x in ("1024","1536","encoder","_enc"))}
    if len(args["models"])!=6:raise ValueError("unexpected_compact_model_set")
    args["default_pipeline_type"]="512"
    args["image_cond_model"]["args"]["model_name"]=str(dino_path)
    args["rembg_model"]={"name":"BiRefNet","args":{"model_name":str(birefnet_path)}}
    return config

def readiness(models_root):
    root=Path(models_root)
    required=["pipeline512.json","dino/config.json","dino/model.safetensors","birefnet/config.json"]
    missing=[n for n in required if not (root/n).is_file()]
    manifest=root/"model-manifest.json"
    if manifest.exists():
        data=json.loads(manifest.read_text())
        missing.extend(x["local"] for x in data.get("files",[]) if not Path(x["local"]).is_file())
    return {"configured":not missing,"tested":False,"blocked":missing,"reason":"weights_or_gated_dino_access_missing" if missing else "inference_not_yet_tested"}

def sha256(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):h.update(chunk)
    return h.hexdigest()

class AssetRunner:
    def __init__(self,store,root="/srv/game-avia",repo_root=None):
        self.store=store;self.root=Path(root);self.repo_root=Path(repo_root or self.root/"repo")
    def prepare(self,task):
        spec=AssetSpec.model_validate(task["spec"])
        refs=[reference_path(self.repo_root/"assets/source",n) for n in spec.reference_images]
        disk_guard(self.root)
        status=readiness(self.root/"models/trellis512")
        out=self.root/"artifacts"/spec.asset_id
        out.mkdir(parents=True,exist_ok=True)
        manifest={"spec":spec.model_dump(mode="json"),"references":[{"name":p.name,"sha256":sha256(p)} for p in refs],
                  "state":"prepared","readiness":status,"generated":False,"reference_path":str(refs[0])}
        previous=out/"manifest.json"
        if previous.is_file() and json.loads(previous.read_text()).get("verified"):
            old=json.loads((out/"request.json").read_text()) if (out/"request.json").is_file() else {}
            if AssetSpec.model_validate(old.get("spec",{})).model_dump(mode="json")!=manifest["spec"] or old.get("references")!=manifest["references"]:
                raise RuntimeError("asset_id_conflict; existing verified artifact preserved")
            accepted=json.loads(previous.read_text())
            for name,info in accepted.get("files",{}).items():
                path=(out/name).resolve()
                if out.resolve() not in path.parents or not path.is_file() or sha256(path)!=info["sha256"]:
                    raise RuntimeError("cached_artifact_hash_mismatch")
            manifest["state"]="reused"
            manifest["existing_manifest"]=json.loads(previous.read_text())
            return manifest
        (out/"request.json").write_text(json.dumps(manifest,indent=2))
        return manifest

