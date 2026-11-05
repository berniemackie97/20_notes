import re,struct,json,sys
S=sys.argv[1]; PE=sys.argv[2]
asm=open(f"{S}/dispatch.asm").read().splitlines()
n2a={}
for ln in asm:
    m=re.match(r"^([0-9a-f]{8})\s+e8 ((?:[0-9a-f]{2} ){4})\s*call\s+(\S+)",ln)
    if m:
        a=int(m.group(1),16); rel=struct.unpack("<i",bytes.fromhex(m.group(2).replace(" ","")))[0]
        n2a[m.group(3)]=(a+5+rel)&0xffffffff
tmap={}
for ln in open(f"{S}/dispatch_map.txt"):
    k,v=ln.split(); tmap[int(k)]=v
data=open(PE,"rb").read()
e=struct.unpack_from("<I",data,0x3c)[0]; nsec=struct.unpack_from("<H",data,e+6)[0]; opt=struct.unpack_from("<H",data,e+20)[0]
base=struct.unpack_from("<I",data,e+24+28)[0]; secs=[]
for i in range(nsec):
    o=e+24+opt+40*i; name=data[o:o+8].rstrip(b"\0").decode(); vs,va,rs,rp=struct.unpack_from("<IIII",data,o+8)
    secs.append((name,base+va,vs,rp,rs))
def off(v):
    for n,va,vs,rp,rs in secs:
        if va<=v<va+max(vs,rs): return rp+(v-va),n
    return None,None
def u32(v):
    o,_=off(v); return struct.unpack_from("<I",data,o)[0]
def text(v): return off(v)[1]==".text"
rows={}
for t,name in sorted(tmap.items()):
    ctor=n2a.get(name)
    if ctor is None and name.startswith("sub_"): ctor=int(name[4:],16)
    vt=None
    if ctor:
        o,_=off(ctor); code=data[o:o+200]
        full=code
        r=re.search(rb"\xc3|\xc2[\x00-\x20]\x00",code)
        code=code[:r.end()] if r else code
        cands=[]
        for m in re.finditer(rb"\xc7[\x00\x01\x06\x07]",code):
            imm=struct.unpack_from("<I",code,m.end())[0] if m.end()+4<=len(code) else 0
            if off(imm)[1] in (".rdata",".data") and text(u32(imm)): cands.append(imm)
        vt=cands[-1] if cands else None
        if vt is None:
            for m in re.finditer(rb"\xc7[\x00\x01\x06\x07]",full):
                imm=struct.unpack_from("<I",full,m.end())[0] if m.end()+4<=len(full) else 0
                if off(imm)[1] in (".rdata",".data") and text(u32(imm)): vt=imm; break
    slots=[]
    if vt:
        for i in range(8):
            s=u32(vt+4*i)
            if not text(s): break
            slots.append(s)
    rows[t]={"ctor_name":name,"ctor":hex(ctor) if ctor else None,"vtable":hex(vt) if vt else None,"slots":[hex(s) for s in slots]}
json.dump(rows,open(f"{S}/registry.json","w"),indent=0)
for t in (1006,1008,1009,1012,1014,1052,1102,10005):
    print(t,rows.get(t))
print("no vtable:",[t for t,r in rows.items() if not r["vtable"]][:30])
