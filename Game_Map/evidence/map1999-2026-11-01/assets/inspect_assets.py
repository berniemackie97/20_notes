from pathlib import Path
import struct,json,hashlib,subprocess
ROOT=Path('/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517');WORK=Path('/Users/bernie/Documents/Codex/2026-10-30/rem/work/map1999');OUT=ROOT.parents[2]/'20_notes/Game_Map/evidence/map1999-2026-11-01/assets';OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
def sha(b):return hashlib.sha256(b).hexdigest()
def info(p):
 b=p.read_bytes();return {'path':str(p.relative_to(ROOT)),'size':len(b),'sha256':sha(b)}
def words(b,o,n):return [{'offset':o+i*4,'offset_hex':hex(o+i*4),'u32':struct.unpack_from('<I',b,o+i*4)[0],'hex':b[o+i*4:o+i*4+4].hex()} for i in range(min(n,(len(b)-o)//4))]
def inspect(b,label):
 version,other=struct.unpack_from('<II',b);path=b[8:268].split(b'\0')[0].decode('ascii');w,h=struct.unpack_from('<II',b,268);off=276;checks=[]
 for y in range(h):
  total=0
  for x in range(w):
   pas,surf,z=struct.unpack_from('<HHh',b,off);off+=6;total=(total+(surf+y+1)*pas+(surf+x+1)*(z+2))&0xffffffff
  actual=struct.unpack_from('<I',b,off)[0];checks.append({'row':y,'offset':off,'stored':actual,'computed':total,'matches':actual==total});off+=4
 tail=b[off:];return {'label':label,'size':len(b),'sha256':sha(b),'header':[version,other],'puzzle_path':path,'grid':[w,h],'grid_start':276,'tail_start':off,'tail_start_hex':hex(off),'tail_size':len(tail),'tail_sha256':sha(tail),'all_row_checksums_match':all(x['matches'] for x in checks),'checksum_failures':[x for x in checks if not x['matches']],'first_tail_words':words(b,off,32),'tail_prefix_hex':tail[:256].hex()}
b=(ROOT/'ini/GameMap.dat').read_bytes();count=struct.unpack_from('<I',b)[0];o=4;selected=[]
for i in range(count):
 at=o;mid,n=struct.unpack_from('<II',b,o);o+=8;path=b[o:o+n].split(b'\0')[0].decode('ascii');o+=n;link=struct.unpack_from('<I',b,o)[0];o+=4
 if mid==1999 or 'icecrypt' in path.lower():selected.append({'index':i,'offset':at,'map_data_id':mid,'path':path,'path_length':n,'link':link})
assert o==len(b)
res={'source_root':str(ROOT),'gamemap':{**info(ROOT/'ini/GameMap.dat'),'declared_count':count,'all_bytes_consumed':True,'selected_rows':selected},'maps':[]}
for level in range(1,7):
 stem=f'icecrypt-lev{level}';arc=ROOT/f'map/map/{stem}.7z';ls=subprocess.run(['/opt/homebrew/bin/7zz','l','-slt',str(arc)],check=True,stdout=subprocess.PIPE).stdout.decode();(OUT/f'{stem}-listing.txt').write_text(ls)
 payload=subprocess.run(['/opt/homebrew/bin/7zz','x','-so',str(arc),f'{stem}.DMap'],check=True,stdout=subprocess.PIPE).stdout;(WORK/f'{stem}-archive.DMap').write_bytes(payload)
 loose=(ROOT/f'map/map/{stem}.DMap').read_bytes();a=inspect(payload,stem+' archive');l=inspect(loose,stem+' loose');common=min(len(payload),len(loose));diffs=[i for i in range(common) if payload[i]!=loose[i]]
 d={'archive':info(arc),'payload':a,'loose':l,'equal':payload==loose,'comparison':{'common_length':common,'different_bytes_in_common_range':len(diffs),'first_difference':diffs[0] if diffs else None,'first_32_difference_offsets':diffs[:32]}}
 if level==3:
  assert d['archive']['sha256']=='8ddb39291d1a8aea31ab1c7df6be0083b35b7da43939c8a9255d98db54809cb8'
  (OUT/'icecrypt-lev3-tail-archive.hex.txt').write_text('\n'.join(f'{i:08x}  '+payload[i:i+16].hex(' ') for i in range(a['tail_start'],len(payload),16))+'\n');(OUT/'icecrypt-lev3-tail-loose.hex.txt').write_text('\n'.join(f'{i:08x}  '+loose[i:i+16].hex(' ') for i in range(l['tail_start'],len(loose),16))+'\n')
 res['maps'].append(d)
(OUT/'artifact-comparison.json').write_text(json.dumps(res,indent=2))
for d in res['maps']:
 print(d['archive']['path'],d['archive']['sha256'])
 for k in ['payload','loose']:
  j=d[k];print(k,{x:j[x] for x in ['size','sha256','header','grid','tail_start','tail_size','all_row_checksums_match']});print('tailwords',[(x['offset_hex'],x['u32']) for x in j['first_tail_words'][:16]])
 print('diff',d['comparison'])
print('ROWS',selected)
