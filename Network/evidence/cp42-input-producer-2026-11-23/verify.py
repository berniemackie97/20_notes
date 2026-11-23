import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

parser = argparse.ArgumentParser(description="Check retained instruction bytes against the source PE image.")
parser.add_argument("image", type=Path)
args = parser.parse_args()
folder = Path(__file__).resolve().parent
evidence = json.loads((folder / "instructions.json").read_text())
image = args.image.read_bytes()
digest = hashlib.sha256(image).hexdigest()
if digest != evidence["source_sha256"]:
    raise SystemExit("Source image digest differs from the recorded target.")
pe = struct.unpack_from("<I", image, 60)[0]
count = struct.unpack_from("<H", image, pe + 6)[0]
optional_length = struct.unpack_from("<H", image, pe + 20)[0]
image_base = struct.unpack_from("<I", image, pe + 52)[0]
sections = []
for index in range(count):
    section = pe + 24 + optional_length + index * 40
    _, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", image, section + 8)
    sections.append((image_base + virtual_address, raw_size, raw_pointer))
checked = 0
for name, text in evidence["functions"].items():
    for line in text.splitlines():
        match = re.match(r"^([0-9a-fA-F]{8})\s+((?:[0-9a-fA-F]{2} )+)", line)
        if not match:
            continue
        address = int(match[1], 16)
        expected = bytes.fromhex(match[2])
        offset = next((raw + address - start for start, size, raw in sections
                       if start <= address and address + len(expected) <= start + size), None)
        if offset is None or image[offset:offset + len(expected)] != expected:
            raise SystemExit(f"Instruction mismatch: {name} at {address:#x}")
        checked += 1
message_map = json.loads((folder / "message-map.json").read_text())
for entry in message_map["entries"]:
    address = int(entry["address"], 16)
    expected = bytes.fromhex(entry["hex"])
    offset = next((raw + address - start for start, size, raw in sections
                   if start <= address and address + len(expected) <= start + size), None)
    if offset is None or image[offset:offset + len(expected)] != expected:
        raise SystemExit(f"Message-map mismatch at {address:#x}")
capture_path = folder.parent / "cp32-world-entry-2026-11-08" / "capture.json"
capture = json.loads(capture_path.read_text())
frames = []
for session in capture["captures"]:
    for record in session["records"]:
        if record["id"] != 10005 or record["provenance"] != "native-client" or not record["hex"]:
            continue
        packet = bytes.fromhex(record["hex"])
        if hashlib.sha256(packet).hexdigest() != record["sha256"]:
            raise SystemExit("Captured movement digest mismatch.")
        packed, actor, selector, tick, state = struct.unpack_from("<IIIII", packet, 4)
        if selector not in (0, 1) or packed > 247:
            raise SystemExit("Captured ordinary movement exceeds the derived producer range.")
        frames.append({"capture": session["capture"], "sequence": record["sequence"],
                       "packed": packed, "direction": packed % 8, "random_quotient": packed // 8,
                       "selector": selector, "tick": tick, "map_state": state,
                       "sha256": record["sha256"]})
print(json.dumps({"image_sha256": digest, "instruction_records_checked": checked,
                  "instruction_mismatches": 0, "message_map_entries_checked": len(message_map["entries"]),
                  "existing_capture_frames": frames}, indent=2))
