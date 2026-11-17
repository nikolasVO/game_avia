import json
import pytest
from orchestrator.store import Store
from orchestrator.aircraft_production import sync_queue, QUEUE_KEY

def test_restart_preserves_generation_stage_and_notification(tmp_path):
    path=tmp_path/'state.db';store=Store(path)
    spec={'jobs':[{'job_id':'aircraft-f16c-v1','aircraft_id':'f16c','state':'queued'}]}
    assert sync_queue(store,spec,None)=={'added':1,'total':1}
    with store.db() as c:
        q=json.loads(c.execute('select value from kv where key=?',(QUEUE_KEY,)).fetchone()[0]);q['jobs']['aircraft-f16c-v1']['state']='generating'
        c.execute('update kv set value=? where key=?',(json.dumps(q),QUEUE_KEY))
    restarted=Store(path)
    assert sync_queue(restarted,spec,None)['added']==0
    with restarted.db() as c:
        assert json.loads(c.execute('select value from kv where key=?',(QUEUE_KEY,)).fetchone()[0])['jobs']['aircraft-f16c-v1']['state']=='generating'
        assert c.execute('select count(*) from notification_outbox').fetchone()[0]==1

def test_identity_conflict_rolls_back_whole_sync(tmp_path):
    store=Store(tmp_path/'state.db')
    sync_queue(store,{'jobs':[{'job_id':'plane','aircraft_id':'f16c'}]},None)
    with pytest.raises(ValueError,match='identity_conflict'):
        sync_queue(store,{'jobs':[{'job_id':'new','aircraft_id':'su27'},{'job_id':'plane','aircraft_id':'wrong'}]},None)
    with store.db() as c:
        assert set(json.loads(c.execute('select value from kv where key=?',(QUEUE_KEY,)).fetchone()[0])['jobs'])=={'plane'}
