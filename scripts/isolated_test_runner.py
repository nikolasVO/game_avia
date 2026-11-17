"""Trusted harness mounted read-only outside generated workspace."""
import json
import sys
import unittest
import resource
resource.setrlimit(resource.RLIMIT_NPROC,(32,32))

sys.path.insert(0,"/work")
suite=unittest.defaultTestLoader.discover("/work/tests")
result=unittest.TextTestRunner(verbosity=1).run(suite)
proof={"tests_run":result.testsRun,"failures":len(result.failures),"errors":len(result.errors),"passed":result.wasSuccessful() and result.testsRun>0}
print("GAME_AVIA_TEST_RESULT="+json.dumps(proof),flush=True)
sys.exit(0 if proof["passed"] else 1)

