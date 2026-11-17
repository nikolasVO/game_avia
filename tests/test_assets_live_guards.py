import pytest
def test_external_reservation_is_atomic_and_not_claimable(tmp_path):
    from orchestrator.store import Store
    from workers.assets.validate import reserve
    store=Store(tmp_path/'state.db')
    tid,fresh=reserve(store,'unique-validation',{'asset_id':'test'},'external')
    assert fresh and isinstance(tid,str)
    assert store.claim('executor') is None
    assert store.get_task(tid)['owner']=='external'
    assert store.heartbeat(tid,'external')
    assert reserve(store,'unique-validation',{'asset_id':'test'},'external')==(tid,False)
    assert len(store.list_tasks())==1

def test_external_reservation_rollback(tmp_path,monkeypatch):
    from orchestrator.store import Store
    from workers.assets.validate import reserve
    store=Store(tmp_path/'state.db')
    original=store._event
    def fail(c,tid,text,event_type='progress'):
        if event_type=='running':raise RuntimeError('interrupted transaction')
        return original(c,tid,text,event_type)
    monkeypatch.setattr(store,'_event',fail)
    with pytest.raises(RuntimeError):reserve(store,'validation',{'asset_id':'test'},'external')
    assert store.list_tasks()==[]
    assert store.kv('validation') is None
    with store.db() as c:
        assert c.execute('SELECT COUNT(*) FROM notification_outbox').fetchone()[0]==0

def test_atomic_manifest_keeps_old_until_replace(tmp_path,monkeypatch):
    from workers.assets.validate import atomic_json
    from pathlib import Path
    path=tmp_path/'manifest.json';path.write_text('{"old":true}')
    def fail(*args):raise OSError('interrupted publish')
    monkeypatch.setattr(Path,'replace',fail)
    with pytest.raises(OSError):atomic_json(path,{'verified':True})
    assert path.read_text()=='{"old":true}'

def test_inference_child_has_no_secrets(tmp_path,monkeypatch):
    import json,sys,time
    from orchestrator.store import Store
    from workers.assets.run import run_process
    from workers.assets.validate import reserve
    store=Store(tmp_path/'state.db')
    tid,_=reserve(store,'env-check',{'asset_id':'test'},'owner')
    fence=store.acquire_gpu(tid)
    for key in ('HF_TOKEN','OPENLUX_CODEX_API_KEY','TELEGRAM_BOT_TOKEN','GAME_AVIA_API_TOKEN'):
        monkeypatch.setenv(key,'must-not-inherit')
    log=tmp_path/'child.log'
    run_process(store,store.get_task(tid),'owner',fence,[sys.executable,'-c','import os,json;print(json.dumps(dict(os.environ)))'],log,time.monotonic()+30)
    env=json.loads(log.read_text())
    assert not any(k in env for k in ('HF_TOKEN','OPENLUX_CODEX_API_KEY','TELEGRAM_BOT_TOKEN','GAME_AVIA_API_TOKEN'))
    assert env['OMP_NUM_THREADS']=='2'
    assert env['HF_HUB_OFFLINE']=='1'
    assert store.kv('gpu_process')==''

def test_process_unknown_outcome_does_not_repeat(tmp_path):
    import sys,time
    from orchestrator.store import Store
    from workers.assets.run import run_process
    from workers.assets.validate import reserve
    store=Store(tmp_path/'state.db');tid,_=reserve(store,'unknown',{'asset_id':'test'},'owner')
    argv=[sys.executable,'-c','raise Exception("must not run")'];log=tmp_path/'test.log'
    store.prepare_tool(tid,'asset-process:'+tid+':test.log','asset_subprocess',{'argv':argv,'scripts':{}})
    fence=store.acquire_gpu(tid)
    with pytest.raises(RuntimeError,match='tool_outcome_unknown'):
        run_process(store,store.get_task(tid),'owner',fence,argv,log,time.monotonic()+30)
    assert not log.exists()

def test_cached_artifact_corruption_rejected(tmp_path,monkeypatch):
    import json
    from workers.assets.pipeline import AssetRunner,sha256
    import workers.assets.pipeline as pipeline
    refs=tmp_path/'repo/assets/source';refs.mkdir(parents=True);(refs/'test.png').write_bytes(b'reference')
    monkeypatch.setattr(pipeline,'disk_guard',lambda *a,**k:True)
    task={'spec':{'asset_id':'cache','purpose':'test','description':'test','reference_images':['test.png']}}
    runner=AssetRunner(None,tmp_path);runner.prepare(task)
    out=tmp_path/'artifacts/cache';(out/'optimized.glb').write_bytes(b'mesh')
    (out/'manifest.json').write_text(json.dumps({'verified':True,'files':{'optimized.glb':{'sha256':sha256(out/'optimized.glb')}}}))
    assert runner.prepare(task)['state']=='reused'
    request=json.loads((out/'request.json').read_text());request['spec']=task['spec']
    (out/'request.json').write_text(json.dumps(request))
    assert runner.prepare(task)['state']=='reused'
    (out/'optimized.glb').write_bytes(b'corrupted')
    with pytest.raises(RuntimeError,match='cached_artifact_hash_mismatch'):runner.prepare(task)

def test_generation_refuses_model_substitution_before_import(tmp_path):
    from scripts.trellis_generate import validate_compact
    with pytest.raises(RuntimeError,match='non_compact_pipeline'):
        validate_compact({'args':{'default_pipeline_type':'512','models':{}}},tmp_path)
    models={k:str(tmp_path/'checkpoint') for k in ('sparse_structure_flow_model','sparse_structure_decoder','shape_slat_flow_model_512','shape_slat_decoder','tex_slat_flow_model_512','tex_slat_decoder')}
    with pytest.raises(RuntimeError,match='only_pinned_local_BiRefNet_allowed'):
        validate_compact({'args':{'default_pipeline_type':'512','models':models,'rembg_model':{'name':'Other'}}},tmp_path)
