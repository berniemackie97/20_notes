import re,sys,collections
lines=open(sys.argv[1]).read().splitlines()
keys=[];m={};odd=[]
for ln in lines:
    body=ln[8:].strip() if re.match(r"^[0-9a-f]{8}",ln) else ln.strip()
    c=re.match(r"case (0x[0-9a-f]+|\d+)(?:\s*\.\.\.\s*(0x[0-9a-f]+|\d+))?$",body)
    if c:
        if keys and keys[-1]=="#": keys=[]
        a=int(c.group(1),0); b=int(c.group(2),0) if c.group(2) else a
        keys+=list(range(a,b+1)); continue
    e=re.match(r"if \(eax_1 == (0x[0-9a-f]+|\d+)\)$",body)
    if e: keys=[int(e.group(1),0)]; continue
    r=re.match(r"result_1 = (\w+)\(",body)
    if r and keys:
        for k in keys: m.setdefault(k,set()).add(r.group(1))
        keys=[]; continue
    if body.startswith("default"): keys=[]
for k in sorted(m): print(k, ",".join(sorted(m[k])))
print("count",len(m),file=sys.stderr)
