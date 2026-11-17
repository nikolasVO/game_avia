import asyncio
import json
import os
import tempfile
from pathlib import Path

async def codex_exec(binary,base_url,api_key,model,workspace,prompt,timeout=150):
    # Official runtime; Responses provider, no Chat Completions URL substitution.
    with tempfile.TemporaryDirectory(prefix="codex-home-") as home:
        cfg=('model_provider = "route"\nmodel = '+json.dumps(model)+'\n'
             'approval_policy = "never"\nsandbox_mode = "workspace-write"\n'
             '[model_providers.route]\nname = "route"\nbase_url = '+json.dumps(base_url)+'\n'
             'env_key = "GAME_AVIA_ROUTE_KEY"\nwire_api = "responses"\n'
             'requires_openai_auth = false\nrequest_max_retries = 0\nstream_max_retries = 0\n')
        Path(home,"config.toml").write_text(cfg)
        env={k:v for k,v in os.environ.items() if k in ("PATH","LANG","SSL_CERT_FILE")}
        env.update({"CODEX_HOME":home,"HOME":home,"GAME_AVIA_ROUTE_KEY":api_key})
        p=await asyncio.create_subprocess_exec(binary,"exec","--json","--skip-git-repo-check","-C",str(workspace),prompt,
                env=env,stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
        try:out,err=await asyncio.wait_for(p.communicate(),timeout)
        except asyncio.TimeoutError:
            p.kill();await p.wait()
            return {"status":"outcome_unknown","reason":"runtime_deadline"}
        # Raw runtime logs remain private; persist only allowlisted item types, no thinking content.
        items=[]
        for line in out.decode(errors="replace").splitlines():
            try:
                d=json.loads(line)
                if d.get("type") in ("item.completed","turn.completed","turn.failed"):
                    item=d.get("item",{})
                    items.append({"type":d["type"],"item_type":item.get("type"),"exit_code":item.get("exit_code")})
            except ValueError:pass
        return {"status":"completed" if p.returncode==0 else "failed","exit_code":p.returncode,"items":items,
                "sandbox_failure":b"Operation not permitted" in err or b"sandbox" in err.lower()}

