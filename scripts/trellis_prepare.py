"""Pinned compact 512 metadata/weights preparation. No gated access bypass."""
import argparse
import json
import os
import urllib.request
from pathlib import Path
from orchestrator.settings import load_environment
from workers.assets.pipeline import compact_config,disk_guard

REVISIONS={"microsoft/TRELLIS.2-4B":"af44b45f2e35a493886929c6d786e563ec68364d",
"microsoft/TRELLIS-image-large":"25e0d31ffbebe4b5a97464dd851910efc3002d96",
"facebook/dinov3-vitl16-pretrain-lvd1689m":"ea8dc2863c51be0a264bab82070e3e8836b02d51",
"ZhengPeng7/BiRefNet":"e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4"}

def prepare(root,download=False):
    root=Path(root);root.mkdir(parents=True,exist_ok=True)
    repo="microsoft/TRELLIS.2-4B";rev=REVISIONS[repo]
    with urllib.request.urlopen(f"https://huggingface.co/{repo}/resolve/{rev}/pipeline.json",timeout=20) as r:cfg=json.load(r)
    paths={}
    selected=[]
    for key,value in cfg["args"]["models"].items():
        if any(x in key for x in ("1024","1536","encoder","_enc")):continue
        source=repo;prefix=value
        if value.startswith("microsoft/"):
            parts=value.split("/");source="/".join(parts[:2]);prefix="/".join(parts[2:])
        local=root/("trellis" if source==repo else "sparse")/prefix
        paths[key]=str(local)
        for suffix in (".json",".safetensors"):
            selected.append({"repo":source,"revision":REVISIONS[source],"file":prefix+suffix,"local":str(local)+suffix})
    for source,folder in [("facebook/dinov3-vitl16-pretrain-lvd1689m","dino"),("ZhengPeng7/BiRefNet","birefnet")]:
        with urllib.request.urlopen("https://huggingface.co/api/models/"+source+"?blobs=true",timeout=20) as r:meta=json.load(r)
        for f in meta["siblings"]:
            n=f["rfilename"]
            allowed=(n in ("config.json","model.safetensors","pytorch_model.bin","preprocessor_config.json") or
                     (folder=="birefnet" and n.endswith(".py")))
            if allowed:selected.append({"repo":source,"revision":REVISIONS[source],"file":n,"local":str(root/folder/n)})
    # Prefer safetensors over a duplicate pickle checkpoint.
    for source in REVISIONS:
        if any(x["repo"]==source and x["file"]=="model.safetensors" for x in selected):
            selected=[x for x in selected if not(x["repo"]==source and x["file"]=="pytorch_model.bin")]
    metadata={}
    for source in {x["repo"] for x in selected}:
        with urllib.request.urlopen("https://huggingface.co/api/models/"+source+"?blobs=true",timeout=20) as r:m=json.load(r)
        metadata[source]={f["rfilename"]:f.get("size",f.get("lfs",{}).get("size",0)) for f in m["siblings"]}
    for x in selected:x["bytes"]=metadata[x["repo"]].get(x["file"],0)
    result={"revisions":REVISIONS,"pipeline_type":"512","files":selected,
            "selected_bytes":sum(x["bytes"] for x in selected),"downloaded":False,"dino_access":"unverified"}
    token=os.getenv("HF_TOKEN")
    req=urllib.request.Request("https://huggingface.co/facebook/dinov3-vitl16-pretrain-lvd1689m/resolve/"+REVISIONS["facebook/dinov3-vitl16-pretrain-lvd1689m"]+"/model.safetensors",method="HEAD",
        headers={"Authorization":"Bearer "+token} if token else {})
    try:
        with urllib.request.urlopen(req,timeout=20) as r:result["dino_access"]="authorized" if r.status==200 else "blocked"
    except urllib.error.HTTPError as e:result["dino_access"]="blocked_http_"+str(e.code)
    (root/"model-manifest.json").write_text(json.dumps(result,indent=2))
    final=compact_config(cfg,paths,root/"dino",root/"birefnet")
    (root/"pipeline512.metadata.json").write_text(json.dumps(final,indent=2))
    if download:
        if result["dino_access"]!="authorized":raise RuntimeError("blocked_gated_dino_access; metadata preserved; no weights downloaded")
        disk_guard(root,additional=result["selected_bytes"]+2*1024**3)
        from huggingface_hub import hf_hub_download
        import shutil
        for x in selected:
            dest=Path(x["local"]);dest.parent.mkdir(parents=True,exist_ok=True)
            # local_dir avoids a second full weight copy in a separate cache.
            hf_hub_download(x["repo"],x["file"],revision=x["revision"],token=token,local_dir=dest.parents[len(Path(x["file"]).parts)-1])
        (root/"pipeline512.json").write_text(json.dumps(final,indent=2))
        result["downloaded"]=True
        (root/"model-manifest.json").write_text(json.dumps(result,indent=2))
    return {k:v for k,v in result.items() if k!="files"}

if __name__=="__main__":
    load_environment()
    p=argparse.ArgumentParser();p.add_argument("--root",default="/srv/game-avia/models/trellis512");p.add_argument("--download",action="store_true")
    a=p.parse_args();print(json.dumps(prepare(a.root,a.download),indent=2))

