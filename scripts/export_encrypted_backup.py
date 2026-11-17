"""Run on the owner's separate trusted machine. Key material never leaves that machine."""
import argparse
import json
import os
import sqlite3
import subprocess
import tempfile
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

def main():
    p=argparse.ArgumentParser();p.add_argument("--target",required=True);p.add_argument("--destination",required=True);p.add_argument("--key-file",required=True)
    a=p.parse_args()
    destination=Path(a.destination);destination.mkdir(parents=True,exist_ok=True,mode=0o700);destination.chmod(0o700)
    keyfile=Path(a.key_file).expanduser();keyfile.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
    if not keyfile.exists():keyfile.write_bytes(AESGCM.generate_key(bit_length=256));keyfile.chmod(0o600)
    if keyfile.stat().st_mode & 0o077:raise RuntimeError("backup_key_permissions_must_be_0600")
    key=keyfile.read_bytes()
    subprocess.run(["ssh","-o","BatchMode=yes","-o","UseKeychain=yes",a.target,
        "cd /srv/game-avia/repo && /srv/game-avia/venvs/core/bin/python -m scripts.backup_restore_check"],
        check=True,capture_output=True,timeout=60)
    with tempfile.TemporaryDirectory(dir=destination) as temp:
        plain=Path(temp)/"snapshot.sqlite3"
        subprocess.run(["scp","-q","-o","BatchMode=yes","-o","UseKeychain=yes",a.target+":/srv/game-avia/state/runtime/coordinator.backup.sqlite3",str(plain)],
                       check=True,capture_output=True,timeout=60)
        plain.chmod(0o600)
        nonce=os.urandom(12)
        encrypted=nonce+AESGCM(key).encrypt(nonce,plain.read_bytes(),b"game_avia_sqlite_backup_v1")
        final=destination/"coordinator.sqlite3.aesgcm"
        candidate=destination/"coordinator.sqlite3.aesgcm.candidate"
        candidate.write_bytes(encrypted);candidate.chmod(0o600)
        # Verify the saved ciphertext before replacing the previous good snapshot.
        saved=candidate.read_bytes()
        restored=Path(temp)/"restored.sqlite3"
        restored.write_bytes(AESGCM(key).decrypt(saved[:12],saved[12:],b"game_avia_sqlite_backup_v1"));restored.chmod(0o600)
        with sqlite3.connect(restored) as c:
            assert c.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
            count=c.execute("SELECT COUNT(*) FROM tasks").fetchone()[0]
        if final.exists():final.replace(destination/"coordinator.sqlite3.aesgcm.previous")
        candidate.replace(final)
    report={"off_server_encrypted_backup":"passed","restore_integrity":"ok","restored_tasks":count,"key_outside_git":True}
    (destination/"restore-check.json").write_text(json.dumps(report,indent=2))
    print(json.dumps(report))
if __name__=="__main__":main()

