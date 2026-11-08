"""Verify off-map static instruction evidence against the clean PE; no target execution."""
import hashlib
import json
from pathlib import Path
import re
import struct

here = Path(__file__).resolve().parent
data = (here.parents[3] / '00_clean/clean/5517-bninja/Conquer.exe').read_bytes()
digest = hashlib.sha256(data).hexdigest()
assert digest == 'b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62'
pe = struct.unpack_from('<I', data, 0x3c)[0]
count = struct.unpack_from('<H', data, pe + 6)[0]
opt = struct.unpack_from('<H', data, pe + 20)[0]
base = struct.unpack_from('<I', data, pe + 52)[0]

def read(va, length):
    for index in range(count):
        _, virtual, size, raw = struct.unpack_from('<IIII', data, pe + 24 + opt + index * 40 + 8)
        rva = va - base
        if virtual <= rva and rva + length <= virtual + size:
            start = raw + rva - virtual
            return data[start:start + length]
    raise AssertionError(hex(va))

verified = {}
for path in sorted(here.glob('*.asm')):
    rows = []
    for line in path.read_text().splitlines():
        match = re.match(r'^([0-9a-fA-F]{8})\s+((?:[0-9a-fA-F]{2}\s+)+)', line)
        if match:
            address = int(match[1], 16)
            expected = bytes.fromhex(match[2])
            assert read(address, len(expected)) == expected, (path.name, hex(address))
            rows.append({'address': hex(address), 'bytes': expected.hex()})
    assert rows, path
    verified[path.name] = rows
assert read(0x64f832, 3).hex() == 'db45e4'
assert read(0x64f854, 3).hex() == 'ff5010'
fixture = json.loads((here / 'golden-cases.json').read_text())
assert fixture['binarySha256'] == digest
print(json.dumps({'binarySha256': digest, 'kind': 'static-byte-verification',
                  'instructionCount': sum(map(len, verified.values())), 'windows': verified}, indent=2))
