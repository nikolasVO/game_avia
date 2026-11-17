import os
from pathlib import Path
from dotenv import load_dotenv

def load_environment(path=None):
    load_dotenv(path or os.getenv("GAME_AVIA_ENV", "/etc/game-avia/environment"), override=False)

def state_dir():
    p = Path(os.getenv("GAME_AVIA_STATE_DIR", "/srv/game-avia/state/runtime"))
    p.mkdir(parents=True, exist_ok=True, mode=0o700)
    return p

def owner_id():
    ids = [os.getenv(k, "") for k in ("TELEGRAM_ADMIN_ID", "TELEGRAM_CHAT_ID", "TELEGRAM_ALLOWED_USER_IDS")]
    if not ids[0].isdigit() or any(v and v != ids[0] for v in ids):
        raise RuntimeError("invalid_pinned_telegram_owner")
    return int(ids[0])

