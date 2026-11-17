import hmac
import os
from pathlib import Path
from fastapi import Depends,FastAPI,Header,HTTPException
from pydantic import BaseModel,ConfigDict,Field
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from workers.assets.pipeline import AssetSpec

load_environment()
app=FastAPI(title="game_avia local coordinator",docs_url=None,redoc_url=None)
def get_store():return Store(state_dir()/"coordinator.sqlite3")
def auth(authorization:str=Header(default="")):
    token=os.getenv("GAME_AVIA_API_TOKEN","")
    if not token or not hmac.compare_digest(authorization,"Bearer "+token):
        raise HTTPException(401,"unauthorized")
class TaskInput(BaseModel):
    model_config=ConfigDict(extra="forbid")
    goal:str=Field(min_length=1,max_length=12000)
@app.get("/health")
def health():
    s=get_store()
    return {"status":"ok","service":"game_avia","release":os.getenv("GAME_AVIA_RELEASE_SHA","unversioned"),
            "budget":s.kv("budget_status") or "budget_not_configured"}
@app.post("/tasks",dependencies=[Depends(auth)])
def create(t:TaskInput):return get_store().create_task(t.goal)
@app.get("/tasks",dependencies=[Depends(auth)])
def tasks():return get_store().list_tasks()
@app.get("/tasks/{tid}",dependencies=[Depends(auth)])
def task(tid:str):
    r=get_store().get_task(tid)
    if not r:raise HTTPException(404,"not_found")
    return r
@app.post("/assets",dependencies=[Depends(auth)])
def request_asset(spec:AssetSpec):
    return get_store().create_task(spec.description,"asset",spec.model_dump())
@app.get("/assets/{tid}",dependencies=[Depends(auth)])
def get_asset(tid:str):
    r=task(tid)
    if r["kind"]!="asset":raise HTTPException(404,"not_asset")
    return r
@app.post("/assets/{tid}/cancel",dependencies=[Depends(auth)])
def cancel_asset(tid:str):
    get_asset(tid);get_store().transition(tid,"cancelled","Отменено через локальный API.")
    return get_asset(tid)

