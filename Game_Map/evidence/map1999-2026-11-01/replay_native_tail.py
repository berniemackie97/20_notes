"""Source-bound replay of recovered 5517 tail reads, not native client execution.
Models only normal allocation/component availability and successful helper returns.
No source files are written. Run from any cwd; results go beside this script.
"""
from pathlib import Path
import hashlib, json, struct, subprocess
ROOT = Path('/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517')
archive = ROOT / 'map/map/icecrypt-lev3.7z'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '8ddb39291d1a8aea31ab1c7df6be0083b35b7da43939c8a9255d98db54809cb8'
b = subprocess.check_output(['7zz', 'x', '-so', str(archive)])
assert hashlib.sha256(b).hexdigest() == '08cf96b84fd0ad8a17a833d80925c8686940498d2c0fbfe68bb17095c4af9a9d'
w,h = struct.unpack_from('<II', b, 268)
cursor = 276+h*(6*w+4)
events = []
def read(n, dest, site):
    global cursor
    start = cursor
    copied = min(n, len(b)-cursor)
    dest[:copied] = b[cursor:cursor+copied]
    cursor += copied
    events.append(dict(call_site=site, offset=start, requested=n, copied=copied, cursor_after=cursor, destination_hex=dest.hex()))
    return dest

def u32(site, previous=0):
    return struct.unpack('<I', read(4, bytearray(struct.pack('<I',previous)), site))[0]

exit_count = u32('0x63777D')
exits = [list(struct.unpack('<III', read(12,bytearray(12),'0x637799'))) for _ in range(exit_count)]
scenery_count = u32('0x635829')
records=[]
for index in range(scenery_count):
    start=cursor
    kind=u32('0x63584A')
    assert kind==4, 'This focused replay only models the observed subtype4 path'
    path=read(260,bytearray(260),'0x64569F'); path[-1]=0
    section=read(128,bytearray(128),'0x6456DB'); section[-1]=0
    offsets=['0x0C','0x10','0x34','0x38','0x2C','0x30','0x40']
    sites=['0x645708','0x645716','0x645724','0x645732','0x645740','0x64574E','0x64575C']
    fields={off:u32(site) for off,site in zip(offsets,sites)}
    records.append(dict(index=index,start=start,end=cursor,kind=kind,path=path.split(b'\0',1)[0].decode('latin1'),section=section.split(b'\0',1)[0].decode('latin1'),fields=fields))
count_offset=cursor
count=u32('0x61DF19')
insert_index=0;kind=0;overlay_calls=0
for index in range(count):
    insert_index=u32('0x61DF34',insert_index)
    kind=u32('0x61DF43',kind)
    assert kind != 4, 'Unexpected allocation/load path beyond this focused replay'
assert count==100 and cursor==len(b) and insert_index==4 and kind==0
assert sum(e['copied']==0 for e in events)==198
result=dict(evidence_type='Offline instruction-derived read/cursor replay, not native runtime', assumptions=['normal allocation','expected default components exist','external helpers return normally'],payload_sha256=hashlib.sha256(b).hexdigest(),exit_count=exit_count,exits=exits,scenery_count=scenery_count,records=records,positioned_count_offset=count_offset,positioned_count=count,positioned_iterations=count,positioned_objects_created=overlay_calls,zero_byte_reads=198,final_cursor=cursor,native_normal_return_path=['0x61DFC0 map+E4=1','0x61DFCD reader destructor','0x61DFD2 EAX=EBX=1'],events=events)
Path(__file__).with_name('native-tail-replay.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['events','exits']},indent=2))
