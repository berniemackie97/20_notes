import os,re,json,math,sys,collections
scan=json.load(open(sys.argv[1]))
NR="/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/20_notes"
roots={"OCC":"/Volumes/EnderChest/Development/Repos/DotNet/Conquer/OpenConquerClient/docs","OCS":"/Volumes/EnderChest/Development/Repos/DotNet/Conquer/OpenConquerServer/docs"}
modern=re.compile(r"^(development|studio-integration|README|content/(local-content|retail-5517-content-plan|base-terrain-format|collision-format|item-type-catalog-v2|README)|architecture/|operations/|reviews/|startup/(README|STARTUP-001[GIJNSU]|LOADING-001)|networking/README)")
native_os={"status.md","protocol/README.md","protocol/framing.md","protocol/text-encoding.md","architecture/networking.md","content/historical-source-reconciliation.md","architecture/authentication.md","architecture/world-execution.md"}
notes={}
for dp,dn,fn in os.walk(NR):
    if "/.git" in dp or "evidence" in dp or "_archive" in dp: continue
    for f in fn:
        if f.endswith(".md"): p=os.path.join(dp,f); notes[os.path.relpath(p,NR)]=open(p,encoding="utf-8").read()
allnotes="\n".join(notes.values())
tok=lambda t:set(re.findall(r"`([^`\s]{4,60})`|\b([A-Za-z][\w.]{5,40}\.(?:dat|ini|c3|ani|dds|tga|wdf|dmap|pux|7z|swf|phy|wav|msk|bmp))\b|\b(\d{4,5})\b",t))
def toks(t):
    s=set()
    for a,b,c in re.findall(r"`([^`\s]{4,60})`|\b([A-Za-z][\w.]{3,40}\.(?:dat|ini|c3|ani|dds|tga|wdf|dmap|pux|7z|swf|phy|wav|msk|bmp))\b|\b(\d{4,5})\b",t):
        for x in (a,b,c):
            if x: s.add(x.lower())
    return s
df=collections.Counter()
nt={k:toks(v) for k,v in notes.items()}
for v in nt.values(): df.update(v)
N=len(notes); res={}
for d in scan:
    key=d["doc"]; cited=bool(d["addrs"] or d["notes"] or d["syms"])
    cls="modern" if (d["repo"]=="OCC" and modern.match(key)) or (d["repo"]=="OCS" and key not in native_os and modern.match(key)) else "native"
    if d["repo"]=="OCS" and key in native_os: cls="native"
    t=open(os.path.join(roots[d["repo"]],key),encoding="utf-8").read(); dt=toks(t)
    sc=[]
    for k,v in nt.items():
        inter=dt&v
        if inter: sc.append((sum(math.log(N/df[x]) for x in inter),k,sorted(inter,key=lambda x:df[x])[:4]))
    sc.sort(reverse=True)
    res[d["repo"]+":"+key]={"cls":cls,"cited":cited,"top":[(round(a,1),b,c) for a,b,c in sc[:3]]}
json.dump(res,open(sys.argv[2],"w"),indent=0)
for k,v in res.items():
    if v["cls"]=="native" and not v["cited"]:
        print(k,"->",[(a,b) for a,b,c in v["top"][:2]])
print("modern",sum(v["cls"]=="modern" for v in res.values()),"native",sum(v["cls"]=="native" for v in res.values()),"native uncited",sum(v["cls"]=="native" and not v["cited"] for v in res.values()))
