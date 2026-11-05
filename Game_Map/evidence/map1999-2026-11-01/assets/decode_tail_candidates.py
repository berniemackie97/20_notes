from pathlib import Path
import struct,json,hashlib,collections
ROOT=Path('/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517');WORK=Path('/Users/bernie/Documents/Codex/2026-10-30/rem/work/map1999');OUT=ROOT.parents[2]/'20_notes/Game_Map/evidence/map1999-2026-11-01/assets';catalog=json.loads((OUT/'artifact-comparison.json').read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
def u(b,o):return struct.unpack_from('<I',b,o)[0]
def cs(b,o,n):return b[o:o+n].split(b'\0')[0].decode('latin1')
def read_scenery(b,start,extra_type4=0):
 o=start;count=u(b,o);o+=4;records=[]
 for index in range(count):
  at=o;t=u(b,o);o+=4;d={'index':index,'offset':at,'offset_hex':hex(at),'type':t};sizes={1:268,4:416+extra_type4,10:72,15:276};n=sizes.get(t,0);d['payload_offset']=o;d['payload_size']=n
  if o+n>len(b):d['short_read']=True;records.append(d);break
  if t==1:d.update(path=cs(b,o,260),tile=list(struct.unpack_from('<ii',b,o+260)))
  elif t==4:
   d.update(path=cs(b,o,260),section=cs(b,o+260,128),field_offsets=[o+388+4*i for i in range(7)],seven_dwords=list(struct.unpack_from('<7i',b,o+388)))
   if extra_type4:d['candidate_extra_dword']={'offset':o+416,'value':u(b,o+416),'semantic_status':'unknown; alignment hypothesis only'}
  elif t==10:d.update(path=cs(b,o,64),point=list(struct.unpack_from('<ii',b,o+64)))
  elif t==15:d.update(path=cs(b,o,260),four_dwords=list(struct.unpack_from('<4i',b,o+260)))
  d['record_sha256']=sha(b[at:o+n]);o+=n;d['end']=o;records.append(d)
 return {'count_offset':start,'count':count,'records':records,'end':o,'remaining':len(b)-o,'next_u32':u(b,o) if o+4<=len(b) else None}
def positioned(b,start):
 o=start;count=u(b,o);o+=4;records=[]
 for ix in range(min(count,1000)):
  if o+8>len(b):return {'count_offset':start,'count':count,'records':records,'first_unavailable_pair_offset':o,'remaining':len(b)-o,'status':'short input; no claimed native rejection'}
  at=o;insert,kind=struct.unpack_from('<II',b,o);o+=8;r={'offset':at,'insert_index':insert,'kind':kind}
  if kind==4:
   if o+12>len(b):r['short_input']=True;records.append(r);break
   a,c,n=struct.unpack_from('<iii',b,o);o+=12;r['headers']=[a,c];r['child_count']=n;r['children']=[]
   for ci in range(n):
    ct=u(b,o);ca=o;o+=4;sz={3:412,8:260}.get(ct,0);ch={'offset':ca,'type':ct,'payload_size':sz}
    if ct==8:ch['path']=cs(b,o,260)
    o+=sz;r['children'].append(ch)
  records.append(r)
 return {'count_offset':start,'count':count,'records':records,'end':o,'remaining':len(b)-o,'status':'bounded parse complete'}
res={'native_lengths_from_parent_trace':'1=268;4=416;10=72;15=276 body bytes, plus discriminator4. Header does not select version in native caller.','maps':[]}
for level in range(1,7):
 stem=f'icecrypt-lev{level}';paths=[('archive',WORK/f'{stem}-archive.DMap')]
 if level==3:paths.append(('loose',ROOT/f'map/map/{stem}.DMap'))
 for source,p in paths:
  b=p.read_bytes();w,h=struct.unpack_from('<II',b,268);tail=276+(w*6+4)*h;n=u(b,tail);exits=[{'index':i,'offset':tail+4+i*12,'values':list(struct.unpack_from('<iii',b,tail+4+i*12))} for i in range(n)];scstart=tail+4+n*12;sc=read_scenery(b,scstart);pos=positioned(b,sc['end']);d={'name':stem,'source':source,'sha256':sha(b),'tail_start':tail,'exit_count':n,'exits':exits,'scenery':sc,'positioned':pos}
  if level==3 and source=='archive':
   alt=read_scenery(b,scstart,4);d['alternative_alignment_extra_type4_dword']={'status':'candidate record boundary fit, not established native layout or meaning','scenery':alt,'positioned':positioned(b,alt['end'])}
  res['maps'].append(d)
a=(WORK/'icecrypt-lev3-archive.DMap').read_bytes();l=(ROOT/'map/map/icecrypt-lev3.DMap').read_bytes();w=h=820;tail=4037956;exitend=4038152;regions=[]
for name,start,end in [('fixed_header',0,276),('cell_grid_and_checksums',276,tail),('exits',tail,exitend)]:regions.append({'name':name,'start':start,'end':end,'archive_sha256':sha(a[start:end]),'loose_sha256':sha(l[start:end]),'equal':a[start:end]==l[start:end],'differing_bytes':sum(x!=y for x,y in zip(a[start:end],l[start:end]))})
changed=[];changedrows=[]
for y in range(h):
 for x in range(w):
  off=276+y*(w*6+4)+x*6
  if a[off:off+6]!=l[off:off+6]:changed.append({'cell':[x,y],'offset':off,'archive_words':list(struct.unpack_from('<HHh',a,off)),'loose_words':list(struct.unpack_from('<HHh',l,off))})
 off=276+y*(w*6+4)+w*6
 if a[off:off+4]!=l[off:off+4]:changedrows.append(y)
res['level3_comparison']={'regions':regions,'changed_cell_count':len(changed),'changed_cells':changed,'changed_checksum_rows':changedrows}
(OUT/'tail-decode-candidates.json').write_text(json.dumps(res,indent=2))
for d in res['maps']:
 print(d['name'],d['source'],'exits',d['exit_count'],'scenery',d['scenery']['count'],dict(collections.Counter(x['type'] for x in d['scenery']['records'])),'sceneend',hex(d['scenery']['end']),'pos',d['positioned'])
 if 'alternative_alignment_extra_type4_dword'in d:print('ALT',d['alternative_alignment_extra_type4_dword']);print('NATIVE RECORDS',d['scenery']['records'])
print('DIFFGRID',len(changed),'rows',changedrows,'regions',regions)
