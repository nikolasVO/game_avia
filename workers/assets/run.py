import json
import os
import subprocess
import time
from pathlib import Path
from workers.assets.pipeline import AssetRunner,AssetSpec,disk_guard,gpu_guard,readiness,sha256

def run_process(store,task,owner,fence,argv,log,deadline):
    from workers.assets.files import sha256 as file_hash
    operation="asset-process:"+task["id"]+":"+Path(log).name
    args={"argv":argv,"scripts":{p:file_hash(p) for p in argv if p.endswith(".py") and Path(p).is_file()}}
    completed=store.prepare_tool(task["id"],operation,"asset_subprocess",args)
    if completed is not None:
        raise RuntimeError("completed_process_requires_output_reconciliation")
    store.assert_active(task["id"],owner)
    if not store.renew_gpu(task["id"],fence,seconds=300):
        raise RuntimeError("gpu_lease_lost_before_spawn")
    with open(log,"ab") as f:
        allowed={k:v for k,v in os.environ.items() if k in ("PATH","LANG","LD_LIBRARY_PATH","CUDA_HOME","CUDA_VISIBLE_DEVICES","NVIDIA_VISIBLE_DEVICES","NVIDIA_DRIVER_CAPABILITIES")}
        allowed["HOME"]=str(Path(log).parent)
        allowed.update({k:"2" for k in ("OMP_NUM_THREADS","OPENBLAS_NUM_THREADS","MKL_NUM_THREADS","NUMEXPR_NUM_THREADS")})
        allowed["HF_HUB_OFFLINE"]="1"
        allowed["TRANSFORMERS_OFFLINE"]="1"
        process=subprocess.Popen(["nice","-n","10",*argv],stdout=f,stderr=subprocess.STDOUT,start_new_session=True,env=allowed)
        store.kv("gpu_process",process.pid)
        try:
            while process.poll() is None:
                store.assert_active(task["id"],owner)
                if time.monotonic()>deadline or not store.renew_gpu(task["id"],fence,seconds=300):
                    raise RuntimeError("gpu_deadline_or_lease_lost")
                time.sleep(1)
            store.finish_tool(operation,{"exit_code":process.returncode,"log_sha256":file_hash(log)})
            if process.returncode:raise RuntimeError("asset_process_failed; private log retained")
        except BaseException:
            if process.poll() is None:
                import signal
                os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=20)
            raise
        finally:
            if process.poll() is not None:
                with store.db() as c:c.execute("UPDATE kv SET value='' WHERE key='gpu_process' AND value=?",(str(process.pid),))

def run_asset(store,task,owner,root,repo_root=None):
    root=Path(root);repo_root=Path(repo_root or root/"repo");spec=AssetSpec.model_validate(task["spec"])
    request=AssetRunner(store,root,repo_root).prepare(task)
    if request["state"]=="reused":return {"status":"verified","artifact_dir":str(root/"artifacts"/spec.asset_id),"manifest":request["existing_manifest"]}
    if request["readiness"]["blocked"]:
        return {"status":"blocked","reason":request["readiness"]["reason"]}
    fence=store.acquire_gpu(task["id"],seconds=300)
    if fence is None:return {"status":"blocked","reason":"waiting_gpu"}
    out=root/"artifacts"/spec.asset_id
    deadline=time.monotonic()+spec.deadline_seconds
    try:
        disk_guard(root,additional=2*1024**3);gpu_guard(24000)
        store.event(task["id"],"Начало TRELLIS 512; исходник и подготовленные ассеты сохраняются раздельно.","asset")
        generation=out/"generation.json"
        generation.write_text(json.dumps({"reference_path":request["reference_path"],"seed":spec.seed}))
        original=out/"original.glb"
        operation="trellis:"+task["id"]
        cached=store.prepare_tool(task["id"],operation,"trellis_generation",{"seed":spec.seed,"pipeline":"512","asset":spec.asset_id})
        if cached is None:
            run_process(store,task,owner,fence,[str(root/"venvs/trellis/bin/python"),str(repo_root/"scripts/trellis_generate.py"),
                "--request",str(generation),"--models",str(root/"models/trellis512"),"--output",str(original)],
                out/"trellis.private.log",deadline)
            if not original.is_file():raise RuntimeError("trellis_output_missing")
            store.finish_tool(operation,{"sha256":sha256(original)})
        elif not original.is_file() or sha256(original)!=cached["sha256"]:
            raise RuntimeError("cached_generation_hash_mismatch")
        run_process(store,task,owner,fence,[str(root/"tools/blender-5.2.4-linux-x64/blender"),"--background","--factory-startup","--threads","2","--python-exit-code","1",
            "--python",str(repo_root/"scripts/blender_optimize.py"),"--","--input",str(original),"--output-dir",str(out),
            "--manifest-name","blender-manifest.json",*(["--symmetry-x"] if spec.symmetry_policy=="mirror_x" else []),"--rotate-z-degrees",str(spec.source_yaw_degrees),"--triangles",str(spec.triangle_budget),"--texture-size",str(spec.texture_budget),"--dimensions",*[str(spec.dimensions_m[i]) for i in (0,2,1)]],out/"blender.private.log",deadline)
        manifest=json.loads((out/"blender-manifest.json").read_text())
        manifest["generation"]={"pipeline_type":"512","seed":spec.seed,"original_sha256":sha256(original),
            "models":json.loads((root/"models/trellis512/model-manifest.json").read_text())["revisions"]}
        manifest["reference"]=request["references"]
        manifest["source_kind"]="TRELLIS.2_image_to_3D"
        manifest["license"]="TRELLIS.2 MIT; DINOv3 custom license; BiRefNet MIT; reference terms apply; see provenance"
        manifest["godot_import_tested"]=False
        from workers.assets.files import atomic_json
        atomic_json(out/"geometry-manifest.json",manifest)
        return {"status":"verified" if manifest["verified"] else "failed","artifact_dir":str(out),"manifest":manifest}
    finally:store.release_gpu(task["id"],fence)

