#!/usr/bin/env python3
import argparse,hashlib,json,struct,zipfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('apk',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();libs=[]
with zipfile.ZipFile(a.apk) as z:
 for name in z.namelist():
  if not name.endswith('.so'):continue
  data=z.read(name);assert data[:4]==b'\x7fELF';bits=data[4];end='<' if data[5]==1 else '>'
  assert bits==2
  phoff=struct.unpack_from(end+'Q',data,32)[0];entry_size,count=struct.unpack_from(end+'HH',data,54)
  aligns=[]
  for i in range(count):
   offset=phoff+i*entry_size;kind=struct.unpack_from(end+'I',data,offset)[0]
   if kind==1:aligns.append(struct.unpack_from(end+'Q',data,offset+48)[0])
  libs.append({'path':name,'load_alignments':aligns,'16kb_elf_alignment':all(n>=16384 for n in aligns)})
 prohibited=[n for n in z.namelist() if any(x in n.lower() for x in ['.keystore','.sqlite3','.env','private.key','/models/','trellis'])]
 result={'artifact':a.apk.name,'bytes':a.apk.stat().st_size,'sha256':hashlib.sha256(a.apk.read_bytes()).hexdigest(),'native_libraries':libs,'prohibited_paths':prohibited,'status':'PASS' if all(x['16kb_elf_alignment'] for x in libs) and not prohibited else 'FAIL','scope':'Static ELF LOAD alignment and package path inspection; not 16KB device runtime'}
a.out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
