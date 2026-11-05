import struct,zlib,hashlib,sys
def load(p):
    b=open(p,'rb').read()
    d=b if b[:3]==b'FWS' else b[:8]+zlib.decompress(b[8:])
    nb=d[8]>>3; off=8+(5+4*nb+7)//8+4
    return d,off
def tags(d,off,end=None):
    end=end or len(d)
    while off<end:
        h=struct.unpack_from('<H',d,off); code=h[0]>>6; ln=h[0]&63; off+=2
        if ln==63: ln=struct.unpack_from('<I',d,off)[0]; off+=4
        yield code,off,ln; off+=ln
        if code==0: break
class Bits:
    def __init__(s,d,o): s.d=d; s.p=o*8
    def u(s,n):
        v=0
        for _ in range(n): v=(v<<1)|((s.d[s.p>>3]>>(7-(s.p&7)))&1); s.p+=1
        return v
    def sg(s,n):
        v=s.u(n); return v-(1<<n) if n and v>>(n-1) else v
    def byte(s): return (s.p+7)>>3
def matrix(bt):
    sx=sy=1.0; r0=r1=0.0
    if bt.u(1): n=bt.u(5); sx=bt.sg(n)/65536; sy=bt.sg(n)/65536
    if bt.u(1): n=bt.u(5); r0=bt.sg(n)/65536; r1=bt.sg(n)/65536
    n=bt.u(5); tx=bt.sg(n)/20; ty=bt.sg(n)/20
    return (round(sx,5),round(sy,5),round(r0,5),round(r1,5),tx,ty)
def cxform(bt):
    ha=bt.u(1); hm=bt.u(1); n=bt.u(4); m=a=None
    if hm: m=[bt.sg(n) for _ in range(4)]
    if ha: a=[bt.sg(n) for _ in range(4)]
    return (m,a)
def place2(d,o,ln):
    f=d[o]; depth=struct.unpack_from('<H',d,o+1)[0]; p=o+3; r={'depth':depth,'move':bool(f&1)}
    if f&2: r['ch']=struct.unpack_from('<H',d,p)[0]; p+=2
    if f&4: bt=Bits(d,p); r['m']=matrix(bt); p=bt.byte()
    if f&8: bt=Bits(d,p); r['cx']=cxform(bt); p=bt.byte()
    if f&16: r['ratio']=struct.unpack_from('<H',d,p)[0]; p+=2
    if f&32: e=d.index(b'\0',p); r['name']=d[p:e].decode('latin1'); p=e+1
    if f&64: r['clip']=struct.unpack_from('<H',d,p)[0]
    return r
def index(d,off):
    chars={}
    for code,o,ln in tags(d,off):
        if code in (2,22,32,83,6,21,35,90,20,36,39,37,46,84,11,33,10,48,75,7,34):
            cid=struct.unpack_from('<H',d,o)[0]; chars[cid]=(code,o,ln)
    return chars
def sprite_timeline(d,chars,sid):
    code,o,ln=chars[sid]; fc=struct.unpack_from('<H',d,o+2)[0]; frame=1; ev=[]
    for c,oo,l in tags(d,o+4,o+ln):
        if c==1: frame+=1
        elif c==26: ev.append((frame,place2(d,oo,l)))
        elif c==28: ev.append((frame,{'remove':struct.unpack_from('<H',d,oo)[0]}))
        elif c==12: ev.append((frame,'DoAction'))
    return fc,ev
def deps(d,chars,cid,seen=None):
    seen=seen if seen is not None else set()
    if cid in seen or cid not in chars: return seen
    seen.add(cid); code,o,ln=chars[cid]
    if code==39:
        for f,e in sprite_timeline(d,chars,cid)[1]:
            if isinstance(e,dict) and 'ch' in e: deps(d,chars,e['ch'],seen)
    elif code in (2,22,32,83):
        body=d[o:o+ln]
        for bid,(c2,o2,l2) in chars.items():
            if c2 in (6,21,35,90,20,36) and struct.pack('<BH',0x41,bid) in body or struct.pack('<BH',0x40,bid) in body or struct.pack('<BH',0x42,bid) in body or struct.pack('<BH',0x43,bid) in body:
                if c2 in (6,21,35,90,20,36): seen.add(bid)
    return seen
def chash(d,chars,cid):
    code,o,ln=chars[cid]; return hashlib.sha256(d[o+2:o+ln]).hexdigest()[:16]
