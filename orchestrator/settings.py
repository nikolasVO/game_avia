import os
from pathlib import Path
from dotenv import dotenv_values

def load_environment(path=None,role=None):
    import logging
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    values=dotenv_values(path or os.getenv("GAME_AVIA_ENV", "/etc/game-avia/environment"))
    for key,value in values.items():
        allowed=True
        if role=="api":allowed=key.startswith("GAME_AVIA_")
        elif role=="coordinator":allowed=key.startswith("TELEGRAM_") or (key.startswith("GAME_AVIA_") and key!="GAME_AVIA_API_TOKEN")
        elif role=="executor":allowed=(("_CODEX_" in key or "_CLAUDE_" in key) and key.endswith(("_API_KEY","_BASE_URL"))) or key in ("OLLAMA_BASE_URL","LOCAL_CODE_MODEL") or (key.startswith("GAME_AVIA_") and key!="GAME_AVIA_API_TOKEN")
        if allowed and value is not None:os.environ.setdefault(key,value)
        elif not allowed:os.environ.pop(key,None)

def state_dir():
    p = Path(os.getenv("GAME_AVIA_STATE_DIR", "/srv/game-avia/state/runtime"))
    p.mkdir(parents=True, exist_ok=True, mode=0o700)
    return p

def owner_id():
    ids = [os.getenv(k, "") for k in ("TELEGRAM_ADMIN_ID", "TELEGRAM_CHAT_ID", "TELEGRAM_ALLOWED_USER_IDS")]
    if not ids[0].isdigit() or any(v and v != ids[0] for v in ids):
        raise RuntimeError("invalid_pinned_telegram_owner")
    return int(ids[0])



def environment_proof(role):
    keys=set(os.environ)
    provider_keys={k for k in keys if k.endswith("_API_KEY")}
    if role=="api":scoped=not provider_keys and "TELEGRAM_BOT_TOKEN" not in keys
    elif role=="coordinator":scoped=not provider_keys and "GAME_AVIA_API_TOKEN" not in keys
    else:scoped=("TELEGRAM_BOT_TOKEN" not in keys and "GAME_AVIA_API_TOKEN" not in keys and all("_CODEX_" in k or "_CLAUDE_" in k for k in provider_keys))
    return {"pid":os.getpid(),"release":os.getenv("GAME_AVIA_RELEASE_SHA"),"role":role,"scoped":scoped}

def record_environment_proof(store,role):
    import json
    store.kv("environment_proof:"+role,json.dumps(environment_proof(role)))
