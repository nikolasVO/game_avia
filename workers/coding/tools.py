import hashlib
import json
import os
import subprocess
from pathlib import Path

TOOLS=[{"type":"function","function":{"name":"read_file","description":"Read a UTF-8 file in the task workspace","parameters":{"type":"object","properties":{"path":{"type":"string"}},"required":["path"],"additionalProperties":False}}},
{"type":"function","function":{"name":"write_file","description":"Write UTF-8 text in the task workspace","parameters":{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"],"additionalProperties":False}}},
{"type":"function","function":{"name":"list_files","description":"List workspace files","parameters":{"type":"object","properties":{},"additionalProperties":False}}},
{"type":"function","function":{"name":"run_tests","description":"Run the configured Python test suite","parameters":{"type":"object","properties":{},"additionalProperties":False}}}]

class Tools:
    def __init__(self,store,tid,root,owner=None):
        self.store=store;self.tid=tid;self.root=Path(root).resolve();self.owner=owner
    def path(self,name):
        rel=Path(name)
        if rel.is_absolute() or ".." in rel.parts or any(p.startswith(".") for p in rel.parts):
            raise ValueError("path_not_allowed")
        p=(self.root/rel).resolve()
        if self.root not in p.parents or any(part in ("node_modules","Library") for part in rel.parts):
            raise ValueError("path_outside_workspace")
        return p
    def run(self,name,args,operation_id=None):
        self.store.assert_active(self.tid,self.owner)
        if name not in {t["function"]["name"] for t in TOOLS}: raise ValueError("tool_not_allowed")
        if name in ("write_file","read_file"): p=self.path(args["path"])
        if name=="write_file" and len(args["content"].encode())>100000: raise ValueError("file_too_large")
        snapshot=""
        if name in ("read_file","list_files","run_tests"):
            snapshot=hashlib.sha256("".join(str(p.relative_to(self.root))+hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(self.root.rglob("*")) if p.is_file() and not p.is_symlink() and not any(x.startswith(".") for x in p.relative_to(self.root).parts) and p.stat().st_size<100000).encode()).hexdigest()
        opid=hashlib.sha256((self.tid+name+(operation_id or json.dumps(args,sort_keys=True)+snapshot)).encode()).hexdigest()
        cached=self.store.prepare_tool(self.tid,opid,name,args)
        if cached is not None:return cached
        try:
            if name=="read_file":
                if p.stat().st_size>100000: raise ValueError("file_too_large")
                result={"content":p.read_text()[:16000]}
            elif name=="write_file":
                p.parent.mkdir(parents=True,exist_ok=True)
                tmp=p.with_suffix(p.suffix+".writing");tmp.write_text(args["content"]);tmp.replace(p)
                result={"written":args["path"],"sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
            elif name=="list_files":
                result={"files":[str(p.relative_to(self.root)) for p in self.root.rglob("*")
                         if p.is_file() and not any(x.startswith(".") for x in p.relative_to(self.root).parts)][:200]}
            else:
                from workers.coding.sandbox import run_tests
                result=run_tests(self.root)
        except (OSError,ValueError,subprocess.TimeoutExpired) as e:
            result={"error":type(e).__name__}
        self.store.finish_tool(opid,result)
        return result

