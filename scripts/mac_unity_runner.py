"""Manual Mac proof runner: outbound SSH, exact deployed commit, isolated worktree.

No background service, paid model call or inbound Mac port is created.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time
import uuid

EDITOR = Path.home()/"Applications/Unity/6000.3.28f1/Unity.app/Contents/MacOS/Unity"

def run(commit, target="thunder", editor=EDITOR):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("exact 40-character commit required")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*", target):
        raise ValueError("SSH config alias required")
    repo = Path(__file__).resolve().parents[1]
    private = Path.home()/".codex/tmp/game-avia-unity/runs"
    private.mkdir(parents=True, exist_ok=True, mode=0o700)
    lock = (private/"runner.lock").open("w")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    ssh = ["ssh", "-o", "BatchMode=yes", "-o", "UseKeychain=yes", "-o", "ConnectTimeout=15", target]
    deployed = subprocess.check_output(ssh+["git -C /srv/game-avia/repo rev-parse HEAD"], text=True, timeout=30).strip()
    if deployed != commit:
        raise RuntimeError("requested commit differs from the deployed server checkout")
    subprocess.run(["git", "fetch", "origin", "main"], cwd=repo, check=True, timeout=120)
    remote = subprocess.check_output(["git", "rev-parse", "origin/main"], cwd=repo, text=True).strip()
    if remote != commit:
        raise RuntimeError("requested commit differs from origin/main")
    attempt = private/(commit[:12]+"-"+uuid.uuid4().hex[:8])
    attempt.mkdir(mode=0o700)
    work = attempt/"checkout"
    subprocess.run(["git", "worktree", "add", "--detach", str(work), commit], cwd=repo, check=True)
    subprocess.run(["git", "lfs", "pull"], cwd=work, check=True, timeout=180)
    manifest = json.loads((work/"assets/catalog/blender-fixture/manifest.json").read_text())
    mesh = (work/"assets/catalog/blender-fixture/optimized.glb").read_bytes()
    if hashlib.sha256(mesh).hexdigest() != manifest["files"]["optimized.glb"]["sha256"]:
        raise RuntimeError("fixture LFS object/hash mismatch")
    environment = {k:v for k,v in os.environ.items() if k in ("HOME","PATH","USER","TMPDIR","LANG","SHELL")}
    environment.update(GAME_AVIA_UNITY_REPORT=str(attempt/"editor-result.json"),
                       GAME_AVIA_UNITY_BUILD_DIR=str(attempt/"build"))
    log = attempt/"editor.log"
    started = time.time()
    with (attempt/"console.log").open("wb") as output:
        try:
            process = subprocess.Popen([str(editor), "-batchmode", "-projectPath", str(work/"unity/AviaProof"),
                "-executeMethod", "AviaProof.Build", "-logFile", str(log)], env=environment,
                cwd=work/"unity/AviaProof", stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            code = process.wait(timeout=900)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            code = 124
    raw = log.read_text(errors="replace") if log.exists() else ""
    details = json.loads((attempt/"editor-result.json").read_text()) if (attempt/"editor-result.json").exists() else {}
    built = code == 0 and details.get("passed") is True and (attempt/"build/AviaTechnicalProof.app").is_dir()
    licensing = any(s in raw.lower() for s in ("no valid unity editor license", "license is not active", "no valid license", "failed to activate/update license"))
    report = {"commit":commit, "editor":"6000.3.28f1", "urp":"17.3.0", "gltfast":"6.15.1",
              "installed":editor.is_file(), "tested":True, "build_passed":built,
              "status":"passed" if built else ("blocked_license" if licensing else "failed"),
              "exit_code":code, "elapsed_seconds":round(time.time()-started, 1),
              "source_kind":"procedural_test_fixture_not_TRELLIS", "details":details,
              "screenshot_tested":False, "android_tested":False, "ios_tested":False,
              "log_sha256":hashlib.sha256(log.read_bytes()).hexdigest() if log.exists() else None}
    (attempt/"report.json").write_text(json.dumps(report, indent=2)+"\n")
    # Only the structured non-secret report travels back; private raw logs stay on Mac.
    destination = "/srv/game-avia/artifacts/unity-"+commit
    subprocess.run(ssh+["umask 077; mkdir -p "+destination+"; cat > "+destination+"/report.json"],
                   input=json.dumps(report).encode(), check=True, timeout=30)
    print(json.dumps({**report,"local_evidence":str(attempt)}, indent=2))
    return 0 if built else 1

if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--commit", required=True)
    parser.add_argument("--target", default="thunder")
    args=parser.parse_args()
    raise SystemExit(run(args.commit,args.target))
