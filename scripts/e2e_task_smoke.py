import asyncio,json,time
from orchestrator.settings import load_environment,state_dir
from orchestrator.store import Store
from orchestrator.executor import execute
load_environment()
s=Store(state_dir()/"coordinator.sqlite3")
goal="""Technical bounded smoke, not game design. In your FIRST reply call write_file twice then run_tests, in that order. Write budget_math.py with a function within_triangle_budget(triangles, limit=5000) returning whether 0 <= triangles <= limit. Write tests/test_budget_math.py with unittest.TestCase tests for 5000 accepted and 5001 rejected. Use from budget_math import within_triangle_budget. Then run_tests. After successful tool results reply DONE. Do not call read_file or list_files. Work only in game/ workspace."""
t=s.create_task(goal)
with s.db() as c:
    c.execute("UPDATE tasks SET status='running',owner='bootstrap-e2e',lease_until=? WHERE id=?",(time.time()+300,t["id"]))
t=s.get_task(t["id"])
try:asyncio.run(execute(s,t,"bootstrap-e2e"))
except Exception as e:
    s.transition(t["id"],"blocked",getattr(e,"code",type(e).__name__))
report=s.get_task(t["id"])
print(json.dumps({k:report[k] for k in ("id","status","result","verification_status","github_sync_status")},indent=2,ensure_ascii=False))

