import asyncio
import json
import os
import re
import subprocess
import time
import uuid
from pathlib import Path
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.coding.agent import Agent
from workers.coding.routes import Registry,RouteFailure
from workers.coding.tools import Tools
from workers.assets.pipeline import AssetRunner

def git(root,*args):
    p=subprocess.run(["git","-C",str(root),*args],capture_output=True,text=True,timeout=45)
    if p.returncode:raise RuntimeError("git_"+args[0]+"_failed")
    return p.stdout.strip()

async def execute(store,task,owner):
    root=Path(os.getenv("GAME_AVIA_ROOT","/srv/game-avia"))
    tid=task["id"]
    if task["kind"]=="asset":
        from workers.assets.run import run_asset
        result=await asyncio.to_thread(run_asset,store,task,owner,root)
        if result["status"]!="verified":
            store.transition(tid,"blocked",result.get("reason","asset_failed"),owner=owner);return
        store.transition(tid,"verifying",owner=owner)
        with store.db() as c:c.execute("UPDATE tasks SET verification_status='passed' WHERE id=?",(tid,))
        store.transition(tid,"blocked","3D и Blender проверены; нужны GitHub/LFS sync и Unity runner: "+result["artifact_dir"],owner=owner);return
    if task["kind"]!="code":
        store.transition(tid,"blocked","Unsupported task kind.",owner=owner);return
    # Large backlog remains blocked until monetary budgets are explicitly configured.
    if len(task["goal"])>3000 and not os.getenv("GAME_AVIA_DAILY_COST_LIMIT"):
        store.transition(tid,"blocked","budget_not_configured: нужно ограниченное техническое задание или денежный бюджет.",owner=owner);return
    registry=Registry(store)
    if not list(registry.candidates("gpt")):
        store.transition(tid,"blocked","Нет проверенного cloud tool-loop маршрута; /providers.",owner=owner);return
    store.assert_active(tid,owner)
    branch="task/"+tid
    work=root/"worktrees"/tid
    if not work.exists():
        git(root/"repo","worktree","add","-b",branch,str(work),"main")
    workspace=work/"game"
    workspace.mkdir(exist_ok=True)
    store.event(tid,"План: ограниченная реализация в game/, изолированные тесты, независимое Claude-ревью, сохранение ветки GitHub. Лимит: 4 генеративных вызова плюс 1 ревью; cost_unknown.","plan")
    result=await Agent(registry,store).run(task,workspace,max_calls=4)
    store.transition(tid,"verifying",owner=owner)
    check=Tools(store,tid,workspace).run("run_tests",{})
    if check.get("exit_code")!=0 or not(check.get("passed") and check.get("tests_run",0)>0):
        store.transition(tid,"blocked","Проверка не подтвердила хотя бы один успешный тест. Изменения сохранены в "+branch,owner=owner);return
    with store.db() as c:c.execute("UPDATE tasks SET verification_status='passed' WHERE id=?",(tid,))
    store.transition(tid,"reviewing",owner=owner)
    reviewer=next(registry.candidates("claude"),None)
    if not reviewer:
        store.transition(tid,"blocked","Тесты прошли, независимое cloud-ревью недоступно. Ветка "+branch,owner=owner);return
    diff=git(work,"diff","--","game")
    untracked=git(work,"ls-files","--others","--exclude-standard","game")
    # Include new files in reviewer context after staging; no credentials exist in game/ sandbox.
    git(work,"add","--","game")
    diff=git(work,"diff","--cached","--","game")
    review=await Agent(registry,store).chat(reviewer,[{"role":"system","content":"Independent code review. Check correctness, tests and task acceptance. First line APPROVE only if no material issue; otherwise REQUEST_CHANGES. Never execute tools."},
        {"role":"user","content":"Task: "+task["goal"]+"\nDiff:\n"+diff[:18000]+"\nTests:\n"+check.get("output","")[-3000:]}],tid,tools=[],max_tokens=1024)
    text=review["choices"][0]["message"].get("content","")
    if not text.strip().startswith("APPROVE"):
        store.transition(tid,"blocked","Ревью требует исправлений: "+text[:1000],owner=owner);return
    store.assert_active(tid,owner)
    git(work,"-c","user.name=game_avia","-c","user.email=game-avia@localhost","commit","-m","Task "+tid+": bounded game change","-m","Updates-Ru: Выполнено ограниченное задание владельца; пройдены изолированные тесты и независимое ревью.")
    sha=git(work,"rev-parse","HEAD")
    with store.db() as c:
        c.execute("INSERT OR REPLACE INTO sync_jobs VALUES(?,?,?,?,?)",(tid,tid,branch,"pending",None))
    try:
        store.assert_active(tid,owner)
        git(work,"push","origin",branch)
        with store.db() as c:
            c.execute("UPDATE sync_jobs SET status='synced' WHERE id=?",(tid,))
            c.execute("UPDATE tasks SET github_sync_status='synced' WHERE id=?",(tid,))
    except RuntimeError:
        store.transition(tid,"blocked","Коммит "+sha+" сохранён локально; GitHub sync ожидает восстановления доступа.",owner=owner);return
    # Game changes stay in a reviewed task branch until the single integrator accepts the milestone.
    store.transition(tid,"completed","Тесты и независимое ревью пройдены. Ветка "+branch+"; SHA "+sha+". Интеграция в main — отдельный этап.",owner=owner)

async def main():
    load_environment()
    import fcntl
    lock=open(state_dir()/"executor.lock","a")
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    store=Store(state_dir()/"coordinator.sqlite3")
    from integrations.github.sync import sync_pending
    owner=uuid.uuid4().hex
    while True:
        store.recover()
        await asyncio.to_thread(sync_pending,store,os.getenv("GAME_AVIA_ROOT","/srv/game-avia"))
        if store.kv("paused")=="true":
            await asyncio.sleep(3);continue
        task=store.claim(owner,seconds=300)
        if not task:
            await asyncio.sleep(3);continue
        async def heartbeat():
            while True:
                await asyncio.sleep(20)
                if not store.heartbeat(task["id"],owner,seconds=300):raise RuntimeError("task_lease_lost")
        beat=asyncio.create_task(heartbeat())
        running=asyncio.create_task(execute(store,task,owner))
        try:
            done,_=await asyncio.wait((beat,running),return_when=asyncio.FIRST_COMPLETED,timeout=240)
            if running in done:await running
            else:
                running.cancel()
                try:await running
                except asyncio.CancelledError:pass
                store.transition(task["id"],"blocked","deadline_or_lease_lost; проверьте журнал до повтора.",owner=owner)
        except (RuntimeError,RouteFailure,ValueError,KeyError) as e:
            current=store.get_task(task["id"])
            if current and current["status"] not in ("cancelled","paused","completed"):
                store.transition(task["id"],"blocked",getattr(e,"code",type(e).__name__),owner=owner)
        finally:
            beat.cancel()
            try:await beat
            except asyncio.CancelledError:pass

if __name__=="__main__":asyncio.run(main())

