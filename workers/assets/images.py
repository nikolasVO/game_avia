import base64
import hashlib
import json
import os
import time
import uuid
from pathlib import Path
import httpx
from workers.coding.routes import classify

# Separate catalog-only groups. Nano/Seedream intentionally require their own contract.
CATALOG={
"GPTGE_IMAGE":["gpt-image-2","gpt-image-2.5-flare","gpt-image-2.5-sunburst"],
"OPENLUX_IMAGE":["gpt-image-2","gpt-image-2.5-flare","gpt-image-2.5-sunburst"],
"WHATSTOKEN_IMAGE":["gpt-image-2-special","gpt-image-2.5-flare","gpt-image-2.5-sunburst","seedream-5.5"],
"XYC_IMAGE":["gpt-image-2.5-flare","gpt-image-2.5-sunburst"],
"SIX666_IMAGE":["gpt-image-2","gpt-image-2 2K","gpt-image-2 4K","gpt-image-2.5-sunburst"],
"JUNWUSHEN_IMAGE":["gpt-image-2","gpt-image-2-1k","gpt-image-2-2k","gpt-image-2-4k","gpt-image-2.5-flare","gpt-image-2.5-sunburst"]}

async def generate_reference(store,prefix,model,prompt,output):
    if prefix not in CATALOG or model not in CATALOG[prefix] or model.startswith("seedream"):raise ValueError("unverified_image_contract")
    with store.db() as c:
        c.execute("BEGIN IMMEDIATE")
        if c.execute("SELECT 1 FROM kv WHERE key='bootstrap_image_reserved'").fetchone() or c.execute("SELECT COUNT(*) FROM tool_operations WHERE tool='image_generation'").fetchone()[0]>=1:
            raise RuntimeError("bootstrap_image_cap")
        c.execute("INSERT INTO kv VALUES('bootstrap_image_reserved','1')")
    task=store.create_task("Neutral technical image reference smoke",kind="diagnostic")
    store.transition(task["id"],"paused","Image generation smoke: one paid request maximum.")
    operation="image:"+uuid.uuid4().hex
    store.prepare_tool(task["id"],operation,"image_generation",{"prefix":prefix,"model":model,"idempotency_supported":False})
    base=os.environ[prefix+"_BASE_URL"].rstrip("/")
    key=os.environ[prefix+"_API_KEY"]
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(240,connect=10)) as client:
            r=await client.post(base+"/images/generations",headers={"Authorization":"Bearer "+key},
                json={"model":model,"prompt":prompt,"n":1,"size":"1024x1024"})
            d=r.json()
            if r.status_code>=400 or d.get("error"):
                code=classify(r.status_code,d).code
                store.finish_tool(operation,{"status":"failed","error":code})
                store.transition(task["id"],"blocked",code)
                return {"status":"blocked","error":code,"model":model,"requests":1}
            item=(d.get("data") or [{}])[0]
            if item.get("b64_json"):data=base64.b64decode(item["b64_json"],validate=True)
            elif item.get("url"):
                # Provider-returned URL is not logged. Downloads are size-bounded and public HTTPS only.
                from urllib.parse import urlparse
                import socket,ipaddress
                u=urlparse(item["url"])
                if u.scheme!="https" or not u.hostname:raise ValueError("unsafe_result_url")
                if any(not ipaddress.ip_address(a[4][0]).is_global for a in socket.getaddrinfo(u.hostname,None)):
                    raise ValueError("unsafe_result_host")
                async with client.stream("GET",item["url"]) as download:
                    download.raise_for_status()
                    data=b""
                    async for chunk in download.aiter_bytes():
                        data+=chunk
                        if len(data)>20*1024**2:raise ValueError("image_too_large")
            else:
                store.transition(task["id"],"blocked","Image API accepted request without a known synchronous result; outcome_unknown, no resubmit.")
                return {"status":"outcome_unknown","requests":1,"model":model}
        from PIL import Image
        import io
        im=Image.open(io.BytesIO(data));im.verify()
        output=Path(output);output.parent.mkdir(parents=True,exist_ok=True)
        output.write_bytes(data)
        report={"status":"passed","requests":1,"model":model,"sha256":hashlib.sha256(data).hexdigest(),"bytes":len(data),"generation_verified":True,"edit_verified":False,"cost_status":"cost_unknown"}
        store.finish_tool(operation,report)
        store.transition(task["id"],"completed","Image generation reference saved; 3D inference remains a separate step.")
        return report
    except (httpx.HTTPError,ValueError) as e:
        # The journal remains started: never automatically resubmit a possibly charged operation.
        store.transition(task["id"],"blocked","outcome_unknown: "+type(e).__name__)
        return {"status":"outcome_unknown","requests":1,"model":model,"error":type(e).__name__}

