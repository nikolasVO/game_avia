import subprocess
from pathlib import Path

def sync_pending(store,root):
    with store.db() as c:jobs=[dict(r) for r in c.execute("SELECT * FROM sync_jobs WHERE status='pending'")]
    for job in jobs:
        work=Path(root)/"worktrees"/job["task_id"]
        def git(*args):
            r=subprocess.run(["git","-C",str(work),*args],capture_output=True,text=True,timeout=45)
            if r.returncode:raise RuntimeError("github_sync_unavailable")
            return r.stdout.strip()
        try:
            local=git("rev-parse","HEAD")
            remote=git("ls-remote","origin","refs/heads/"+job["branch"])
            if remote and remote.split()[0]!=local:
                # No force-push or overwrite; ordinary push can only fast-forward.
                git("push","origin",job["branch"])
            elif not remote:git("push","origin",job["branch"])
            verified=git("ls-remote","origin","refs/heads/"+job["branch"])
            if not verified or verified.split()[0]!=local:raise RuntimeError("remote_sha_unconfirmed")
            with store.db() as c:
                c.execute("UPDATE sync_jobs SET status='synced',error=NULL WHERE id=?",(job["id"],))
                c.execute("UPDATE tasks SET github_sync_status='synced' WHERE id=?",(job["task_id"],))
            store.event(job["task_id"],"GitHub sync подтверждён: "+job["branch"]+" "+local,"github_synced")
        except (RuntimeError,subprocess.TimeoutExpired):
            with store.db() as c:c.execute("UPDATE sync_jobs SET error='sync_unavailable' WHERE id=?",(job["id"],))

