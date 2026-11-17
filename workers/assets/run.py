import json
import os
import subprocess
import time
from pathlib import Path
from workers.assets.pipeline import AssetRunner,AssetSpec,disk_guard,gpu_guard,readiness,sha256

def run_process(store,task,owner,fence,argv,log,deadline):
    with open(log,"ab") as f:
        process=subprocess.Popen(argv,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        store.kv("gpu_process",process.pid)
        try:
            while process.poll() is None:
                store.assert_active(task["id"],owner)
                if time.monotonic()>deadline or not store.renew_gpu(task["id"],fence,seconds=300):
                    raise RuntimeError("gpu_deadline_or_lease_lost")
                time.sleep(1)
            if process.returncode:raise RuntimeError("asset_process_failed; private log retained")
        except BaseException:
            if process.poll() is None:
                import signal
                os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=20)
            raise
        finally:
            if process.poll() is not None:store.kv("gpu_process","")

def run_asset(store,task,owner,root):
    root=Path(root);spec=AssetSpec.model_validate(task["spec"])
    request=AssetRunner(store,root).prepare(task)
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
            run_process(store,task,owner,fence,[str(root/"venvs/trellis/bin/python"),str(root/"repo/scripts/trellis_generate.py"),
                "--request",str(generation),"--models",str(root/"models/trellis512"),"--output",str(original)],
                out/"trellis.private.log",deadline)
            if not original.is_file():raise RuntimeError("trellis_output_missing")
            store.finish_tool(operation,{"sha256":sha256(original)})
        run_process(store,task,owner,fence,[str(root/"tools/blender-5.2.4-linux-x64/blender"),"--background","--factory-startup",
            "--python",str(root/"repo/scripts/blender_optimize.py"),"--","--input",str(original),"--output-dir",str(out),
            "--triangles",str(spec.triangle_budget),"--texture-size",str(spec.texture_budget)],out/"blender.private.log",deadline)
        manifest=json.loads((out/"manifest.json").read_text())
        manifest["generation"]={"pipeline_type":"512","seed":spec.seed,"original_sha256":sha256(original),
            "models":json.loads((root/"models/trellis512/model-manifest.json").read_text())["revisions"]}
        manifest["reference"]=request["references"]
        manifest["source_kind"]="TRELLIS.2_image_to_3D"
        (out/"manifest.json").write_text(json.dumps(manifest,indent=2))
        return {"status":"verified" if manifest["verified"] else "failed","artifact_dir":str(out),"manifest":manifest}
    finally:store.release_gpu(task["id"],fence)

