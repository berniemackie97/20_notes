"""Execute captured retail x86 reader bytes; hook only CRT memcpy/memset.
This is isolated instruction execution, not a full-client network/runtime test.
Run with Python + unicorn==2.1.4 from this directory.
"""
import json, re, struct, pathlib
from unicorn import Uc, UC_ARCH_X86, UC_MODE_32, UC_HOOK_CODE
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_ECX, UC_X86_REG_ESP, UC_X86_REG_EIP

ROOT = pathlib.Path(__file__).resolve().parent
ENTRY, COUNT = 0x771f57, 0x771fc0
PACKET, LIST, DEST, STACK, STOP = 0x100000, 0x110000, 0x120000, 0x130800, 0x780000
code = {}
for name in ('0x771f57.txt', '0x771fc0.txt'):
    for line in (ROOT/'native'/name).read_text().splitlines():
        m = re.match(r'^([0-9a-f]{8})  ((?:[0-9a-f]{2} )+)', line)
        if m: code[int(m[1],16)] = bytes.fromhex(m[2])
calls = {a: a+5+struct.unpack('<i', b[1:])[0] for a,b in code.items() if b[0]==0xe8}
MEMSET, MEMCPY = calls[0x771f6c], calls[0x771fb3]
u=Uc(UC_ARCH_X86, UC_MODE_32)
u.mem_map(0x770000,0x20000)
u.mem_map(PACKET,0x40000)
for a,b in code.items(): u.mem_write(a,b)
u.mem_write(MEMSET,b'\xc3');u.mem_write(MEMCPY,b'\xc3')
reads=[]
def word(a): return struct.unpack('<I',u.mem_read(a,4))[0]
def hook(uc,a,size,data):
    if a not in (MEMSET,MEMCPY): return
    sp=uc.reg_read(UC_X86_REG_ESP);dst,src,n=struct.unpack('<III',uc.mem_read(sp+4,12))
    if a==MEMSET: uc.mem_write(dst,bytes([src&255])*n)
    else:
        reads.append([src-PACKET,n]);uc.mem_write(dst,bytes(uc.mem_read(src,n)))
    uc.reg_write(UC_X86_REG_EAX,dst)
u.hook_add(UC_HOOK_CODE,hook)

def run(packet,offset,index,capacity):
    u.mem_write(PACKET,bytes(1024)+bytes([0xcc])*128)
    u.mem_write(PACKET,packet)
    u.mem_write(LIST,struct.pack('<III',0,PACKET+offset,1024-offset))
    u.mem_write(DEST,bytes([0xa5])*256)
    u.mem_write(STACK,struct.pack('<IIII',STOP,index,DEST,capacity))
    u.reg_write(UC_X86_REG_ESP,STACK);u.reg_write(UC_X86_REG_ECX,LIST)
    reads.clear();u.emu_start(ENTRY,STOP,count=10000)
    b=bytes(u.mem_read(DEST,capacity)); copied=list(reads)
    return {'return':u.reg_read(UC_X86_REG_EAX),'c_string_hex':b.split(b'\0',1)[0].hex(),
            'destination_hex':b.hex(),'copy_ranges':copied,
            'crosses_packet_storage':any(a+n>1024 for a,n in copied)}

def packet(kind,entries,count=None,tail=b''):
    off=24 if kind==1004 else 110
    b=bytearray(off)+bytes([len(entries) if count is None else count])
    for s in entries: b+=bytes([len(s)])+s
    b+=tail;struct.pack_into('<HH',b,0,len(b),kind)
    return bytes(b)

cases=[
 ('1004_missing_message',1004,packet(1004,[b'',b'',b''])),
 ('1004_extra_unread_entry',1004,packet(1004,[b'',b'',b'',b'ANSWER_OK'],5,b'\xff')),
 ('1004_zero_length_message',1004,packet(1004,[b'',b'',b'',b''])),
 ('1004_oversized_ignored_sender',1004,packet(1004,[b'x'*255,b'',b'',b'ANSWER_OK'])),
 ('1004_embedded_nul_message',1004,packet(1004,[b'',b'',b'',b'ANSWER_OK\0junk'])),
 ('1004_undefined_ignored_suffix',1004,packet(1004,[b'',b'',b'\x81\x8d\x8f\x90\x9d',b'ANSWER_OK'])),
 ('1004_trailing_bytes',1004,packet(1004,[b'',b'',b'',b'ANSWER_OK'],tail=b'\xffjunk')),
 ('1006_missing_all',1006,packet(1006,[])),
 ('1006_missing_spouse',1006,packet(1006,[b'Ada',b''])),
 ('1006_oversized_name',1006,packet(1006,[b'a'*16,b'',b'Eve'])),
 ('1006_oversized_ignored',1006,packet(1006,[b'Ada',b'x'*255,b'Eve'])),
 ('1006_embedded_nul',1006,packet(1006,[b'Ada\0tail',b'',b'Eve\0tail'])),
 ('1006_undefined_bytes',1006,packet(1006,[b'\x81\x8d\x8f\x90\x9d',b'',b'\x81\x40'])),
 ('1006_count255_no_payload',1006,packet(1006,[],255)),
]
# Claimed entry payload extends beyond the actual copied packet. Reset supplies zeros.
p=bytearray(packet(1006,[b'Ada',b'',b'Eve'])); p[111]=15
cases.append(('1006_wrong_name_length_walk',1006,bytes(p)))
p=bytearray(packet(1006,[b'Ada',b'',b'Eve'])); p=p[:115]+bytes([255]);struct.pack_into('<H',p,0,len(p))
cases.append(('1006_truncated_ignored_length255',1006,bytes(p)))
p=bytearray(packet(1004,[b'',b'',b'',b'ANSWER_OK']));p[28]=255
cases.append(('1004_truncated_message_zerofill',1004,bytes(p)))
p=bytearray(packet(1004,[b'x'*255]*4));p=p[:1024];struct.pack_into('<H',p,0,1024)
cases.append(('1004_cross_storage_boundary',1004,bytes(p)))
results=[]
for name,kind,p in cases:
    rs=[run(p,24 if kind==1004 else 110,i,256 if kind==1004 and i==3 else 16) for i in range(4 if kind==1004 else 3)]
    results.append({'case':name,'packet_hex':p.hex(),'entries':rs})
by={r['case']:r for r in results}
assert by['1004_oversized_ignored_sender']['entries'][0]['return']==0
assert bytes.fromhex(by['1004_oversized_ignored_sender']['entries'][3]['c_string_hex'])==b'ANSWER_OK'
assert by['1004_cross_storage_boundary']['entries'][3]['copy_ranges']==[[794,255]]
assert by['1004_cross_storage_boundary']['entries'][3]['crosses_packet_storage']
assert by['1006_oversized_name']['entries'][0]['c_string_hex']==''
assert bytes.fromhex(by['1006_oversized_name']['entries'][2]['c_string_hex'])==b'Eve'
# Exhaustive selected length and count, raw reader execution (no model under test).
for n in range(256):
    p=packet(1006,[b'A'*n,b'',b'Eve'])
    r=run(p,110,0,16)
    assert r['return']==(n<16)
    assert r['c_string_hex']==(b'A'*n).hex() if n<16 else r['c_string_hex']==''
    assert run(p,110,2,16)['c_string_hex']==b'Eve'.hex()
    p=packet(1004,[b'',b'',b'',b'A'*n])
    assert run(p,24,3,256)['c_string_hex']==(b'A'*n).hex()
    p=packet(1006,[b'Ada',b'',b'Eve'],n)
    assert run(p,110,2,16)['return']==(n>2)
report={'method':'retail x86 bytes captured through Binary Ninja; Unicorn 2.1.4; only memcpy/memset are host hooks; no full client execution',
        'exhaustive_cases':256*4,'named_cases':results,'proof_bounds':{'1006_latest_selected_length_offset':111+2*256,'1006_latest_successful_copy_end_exclusive':111+2*256+1+15,'1004_latest_copy_end_exclusive':25+3*256+1+255}}
(ROOT/'string-reader-replay.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: 18 named cases and 1024 exhaustive raw-instruction reader checks')
