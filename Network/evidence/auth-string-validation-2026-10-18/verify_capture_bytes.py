"""Compare every captured instruction byte with the original PE files."""
from pathlib import Path
import struct, re, json, hashlib, argparse
ap=argparse.ArgumentParser();ap.add_argument('clean_directory');args=ap.parse_args()
root=Path(__file__).resolve().parent;clean=Path(args.clean_directory);images={}
for n in ('Conquer.exe','graphic.dll','C3_CORE_DLL.dll'):
    b=(clean/n).read_bytes();pe=struct.unpack_from('<I',b,0x3c)[0]
    ns=struct.unpack_from('<H',b,pe+6)[0];sz=struct.unpack_from('<H',b,pe+20)[0]
    opt=pe+24;base=struct.unpack_from('<I',b,opt+28)[0];sects=[]
    for i in range(ns):
        vs,rva,rs,raw=struct.unpack_from('<IIII',b,opt+sz+40*i+8)
        sects.append((rva,max(vs,rs),raw))
    images[n]=(b,base,sects)
checks=[];diffs=[]
for p in sorted((root/'native').glob('*.txt')):
    n='C3_CORE_DLL.dll' if p.name.startswith('c3-') else 'graphic.dll' if p.name.startswith('graphic-') else 'Conquer.exe'
    b,base,sects=images[n];cnt=0
    for line in p.read_text().splitlines():
        m=re.match(r'^([0-9a-f]{8})  ((?:[0-9a-f]{2} )+)',line)
        if not m:continue
        addr=int(m[1],16);expected=bytes.fromhex(m[2]);rva=addr-base
        matches=[(r,s,f) for r,s,f in sects if r<=rva<r+s]
        if not matches:diffs.append([p.name,hex(addr),'unmapped']);continue
        r,s,f=matches[0];actual=b[f+rva-r:f+rva-r+len(expected)]
        if actual!=expected:diffs.append([p.name,hex(addr),expected.hex(),actual.hex()])
        cnt+=1
    checks.append({'capture':p.name,'module':n,'instructions':cnt,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
report={'captures':checks,'instruction_count':sum(x['instructions'] for x in checks),'differences':diffs}
(root/'raw-byte-verification.json').write_text(json.dumps(report,indent=2)+'\n')
assert not diffs,diffs
assert all(x['instructions'] for x in checks), 'A capture has no instruction bytes'
print(f"PASS: {len(checks)} captures; {report['instruction_count']} instructions; zero byte differences")
