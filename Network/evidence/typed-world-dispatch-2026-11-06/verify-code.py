"""Verify recorded static Binary Ninja bytes against the clean PE; never executes the target."""
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

here = Path(__file__).resolve().parent
binary = here.parents[3] / '00_clean/clean/5517-bninja/Conquer.exe'
data = binary.read_bytes()
digest = hashlib.sha256(data).hexdigest()
assert digest == 'b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62'
pe = struct.unpack_from('<I', data, 0x3c)[0]
count = struct.unpack_from('<H', data, pe + 6)[0]
optional_size = struct.unpack_from('<H', data, pe + 20)[0]
image_base = struct.unpack_from('<I', data, pe + 24 + 28)[0]
sections = pe + 24 + optional_size

def read(va, length):
    rva = va - image_base
    for index in range(count):
        offset = sections + index * 40
        _, virtual, size, raw = struct.unpack_from('<IIII', data, offset + 8)
        if virtual <= rva and rva + length <= virtual + size:
            start = raw + rva - virtual
            return data[start:start + length]
    raise AssertionError(hex(va))

windows = {}
for path in sorted(here.glob('*.asm')):
    instructions = []
    for line in path.read_text().splitlines():
        match = re.match(r'^([0-9a-fA-F]{8})\s+((?:[0-9a-fA-F]{2}\s+)+)', line)
        if match:
            address = int(match[1], 16)
            expected = bytes.fromhex(match[2])
            assert read(address, len(expected)) == expected, (path.name, hex(address))
            instructions.append({'address': hex(address), 'bytes': expected.hex()})
    assert instructions, path
    windows[path.name] = instructions
native_data = json.loads((here / 'native-data-windows.json').read_text())
assert native_data['binarySha256'] == digest
for window in native_data['windows']:
    expected = bytes.fromhex(window['bytes'])
    assert read(int(window['address'], 16), len(expected)) == expected, window['address']
fixture_verification = None
if len(sys.argv) == 2:
    fixture = json.loads(Path(sys.argv[1]).read_text())
    assert fixture['binarySha256'] == digest
    for window in fixture['nativeCodeWindows']:
        expected = bytes.fromhex(window['bytes'])
        assert read(int(window['address'], 16), len(expected)) == expected, window['address']
    fixture_verification = {'kind': fixture['kind'], 'codeWindows': len(fixture['nativeCodeWindows'])}
else:
    assert len(sys.argv) == 1, 'Optional argument: static-derived managed fixture JSON'
print(json.dumps({'binarySha256': digest, 'kind': 'static-byte-verification',
                  'nativeRuntimeObserved': False, 'fixture': fixture_verification,
                  'dataWindows': native_data['windows'], 'windows': windows}, indent=2))
