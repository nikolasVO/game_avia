#!/usr/bin/env python3
"""Bounded Mac -> Thunder UDP echo probe; no TCP tunnel or localhost substitution."""
import argparse,json,secrets,socket,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--ssh-alias',default='thunder');p.add_argument('--port',type=int,default=24568);p.add_argument('--out',required=True);a=p.parse_args()
cfg=subprocess.check_output(['ssh','-G',a.ssh_alias],text=True,stderr=subprocess.DEVNULL)
host=next(x.split(' ',1)[1] for x in cfg.splitlines() if x.startswith('hostname '))
code='import socket,json; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(("0.0.0.0",'+str(a.port)+')); s.settimeout(12); print("READY",flush=True);\ntry:\n d,addr=s.recvfrom(128); s.sendto(d,addr); print("ECHO",flush=True)\nexcept TimeoutError: print("TIMEOUT",flush=True)\nfinally:s.close()'
remote=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','UseKeychain=yes',a.ssh_alias,'python3 -u -c '+"'"+code.replace("'","'\\''")+"'"],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
ready=remote.stdout.readline().strip();result={'transport':'UDP','probe_port':a.port,'source':'owner Mac outside Thunder','listener':ready,'status':'FAIL','note':'No provider mapping inferred from SSH TCP endpoint.'}
if ready=='READY':
 s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.settimeout(3);nonce=secrets.token_bytes(24)
 try:
  for i in range(3):
   start=time.monotonic();s.sendto(nonce,(host,a.port))
   try:
    data,addr=s.recvfrom(128)
    if data==nonce:result.update(status='PASS',rtt_ms=round((time.monotonic()-start)*1000,2));break
   except socket.timeout:pass
 except OSError as e:result['error_type']=type(e).__name__
 finally:s.close()
try:tail,err=remote.communicate(timeout=15)
except subprocess.TimeoutExpired:remote.terminate();tail,err=remote.communicate(timeout=5)
result['listener_outcome']=tail.strip();result['ssh_exit']=remote.returncode
from pathlib import Path
Path(a.out).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
