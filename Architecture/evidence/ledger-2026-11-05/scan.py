import os,re,json,sys
roots={"OCC":"/Volumes/EnderChest/Development/Repos/DotNet/Conquer/OpenConquerClient/docs","OCS":"/Volumes/EnderChest/Development/Repos/DotNet/Conquer/OpenConquerServer/docs"}
addr=re.compile(r"\b0x0*([4-8][0-9A-Fa-f]{5})\b")
notes=re.compile(r"20_notes/[\w/\-.]+")
sym=re.compile(r"\b(C[A-Z][A-Za-z0-9]+__\w+|C[A-Z][A-Za-z0-9]+_[A-Z]\w+)\b")
out=[]
for k,r in roots.items():
    for dp,dn,fn in os.walk(r):
        for f in sorted(fn):
            if not f.endswith(".md"): continue
            p=os.path.join(dp,f); t=open(p,encoding="utf-8").read()
            a=sorted(set(int(x,16) for x in addr.findall(t) if 0x401000<=int(x,16)<=0x8fffff))
            out.append({"repo":k,"doc":os.path.relpath(p,r),"title":(t.splitlines() or [""])[0][:90],"addrs":[hex(x) for x in a],"notes":sorted(set(notes.findall(t))),"syms":sorted(set(sym.findall(t)))[:12],"lines":t.count("\n")})
json.dump(out,open(sys.argv[1],"w"),indent=0)
c=lambda x: bool(x["addrs"] or x["notes"] or x["syms"])
print("docs",len(out),"cited",sum(map(c,out)))
for x in out:
    if not c(x): print("UNCITED",x["repo"],x["doc"],"|",x["title"])
