# Native 5517 map identity, flags and catalog evidence

Verified 2026-10-09. Scope: original **5517**, documentation only. Native function names are analyst
labels unless explicitly identified as exports. This audit supersedes the retail-identity claims
in [map-catalogue-corrections.md](map-catalogue-corrections.md), while preserving its historical migration.

## Verdict

**The native client proves the wire fields, flag consumers, and terrain index. It does not supply a
retail server MapId → MapDataId catalog or a retail per-map flag table.** The reconstructed 276 rows
are reproducible legacy server data, not a verified complete retail catalog. All 276 selected terrain
keys exist and resolve to supplied terrain; that is a different claim from authentic server assignments.

- **MapId 1501: unresolved.** MapDataId **1501** certainly resolves to `map/map/mine-b.7z` (184×184).
  MapDataId **1730** certainly resolves to `map/map/fairylandPK-02.7z` (96×96). Neither proves which
  terrain the retail server assigned to **world MapId 1501**.
- Eight migration changes reproduce their coordinate-fit results. They are **legacy-data-supported
  candidate assignments**, not native-proven retail bindings.
- Flags are **64 bits**. The old `0x6206C8` low-`0x40` claim was wrong: the function tests
  **`0x0000004000000000` (bit 38)**. A separate function `0x6207EE` tests low `0x40`.
- `GameMap.dat`: **262 records, 261 effective keys, 179 distinct effective paths**. Duplicate ID 1067
  is last-record-wins. Nine effective paths (`kunlun1.7z` through `kunlun9.7z`) are absent from the
  supplied original archive. They are not used by the reconstructed 276 rows.

## Original binary and asset identity

Fresh selective extraction from `00_clean/clean/5517.7z`, size **444752639**, SHA-256
`e44d7a30cfdf3ad3af79ea123599ebbcfe85786493ae24a5a3a3ac2a4014c080`. No BNDB save, executable change, implementation change, migration execution,
commit or PR was performed.

| File | Bytes | SHA-256 |
|---|---:|---|
| `Conquer.exe` | 5880840 | `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62` |
| `GameData.dll` | 131072 | `8168fd126234cbda52442dced750770ecf40d861d4b2aa483f08b91efa8c5077` |
| `ini/GameMap.dat` | 8131 | `0676b7d6969dd8277438704a289b1f57e8debb89fe5d3f912819c3a7880686a0` |

All selected extracted files and clean/loader-copy comparisons: [retail-provenance.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/retail-provenance.json).
Every terrain archive has its encoded and decoded hashes, dimensions, member name and checksum result
in [terrain-assets.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/terrain-assets.json). These hashes identify bytes, not world-map ownership.

## 1. World MapId and terrain MapDataId are separate server inputs

| Native address / field | Direct observation | Consequence |
|---|---|---|
| EXE `0x732B6F/74` → `0x61F185` | packet 1110 `+4` u 32 → map `+0xE0` | server world MapId |
| EXE `0x732B84/89` → `0x61F2B6` | packet 1110 `+8` u 32 → map `+0xE4` | independent terrain/document ID |
| EXE `0x732B99/9C/A1` → `0x61F2C3` | packet 1110 `+0xC/+0x10` → `+0xE8/+0xEC` | replace low/high halves of flags |
| EXE `0x4F6569` | `mov eax,[ecx+0xE0]; ret` | actual world-ID getter; old `0x61F172` entry claim withdrawn |
| EXE `0x6E5E2C` | `mov eax,[ecx+0xE4]; ret` | actual terrain-ID getter; old “no accessor” claim withdrawn |
| EXE `0x61F2DA` | EAX=`+0xE8`, EDX=`+0xEC` | flags returned as EDX:EAX |
| EXE `0x61BB05/0B/2C/32` | constructor zeroes flagsLow, worldId, dataId, flagsHigh | initial zeros, not retail per-map defaults |

The 1110 handler consumes a 20-byte prefix. Its parse wrapper `0x732AED` calls inherited parsing,
then checks packet type `0x456`; it does not itself establish retail field values or a mapping table.
The identity setters perform no MapId/data-key equality check. `0x61F185` always stores and refreshes;
only `+0x2E4 = 1` is conditional on world-ID change. Do not turn repeated IDs into a no-op.

`CMsgAction__Process` `0x6FED1F`, action **0x4A** branch at `0x6FF44A`, calls terrain creation at
`0x6FF478` with **packet+8**, and action **0x56** calls it at `0x6FF6FB` with the same field.
The received terrain key is used directly. No `MapId == MapDataId` default follows from these paths.
Packet 1110 applies identity/flags; terrain creation is a separate action path.

Sources: [0x732B10 ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x732b10.asm.txt), [0x61F185 ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x61f185.asm.txt),
[0x6FED1F ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x6fed1f.asm.txt), [xref census](../../10_work/docs/evidence/map-identity-flags-catalog-5517/xrefs.json).
The singleton/getter census is a direct-xref census, not a claim to have identified every possible
inline/indirect access to a similarly offset field in the executable.

## 2. Flags: width, exact masks, and the limit of recovered meanings

`0x61F2C3` is `thiscall SetFlags(low:u32, high:u32)`, `ret 8`. Its known direct caller is
`0x732BA1`; the full field is replaced without masking. The original constructor also zeroes it.
Neither `GameMap.dat` nor the DMap base-grid header contains this server-supplied flags word.

The following are **proven mask operations**, not a reconstructed retail enum. A consumer description
states what was observed, not a universal gameplay meaning for that bit.

| Qword mask / bit | Native predicate or consumer | Proven operation / consequence |
|---|---|---|
| `0x1` /0 | `0x6206FD` | boolean low-bit 0 predicate; participates in `0x62087E` classification |
| `0x8` /3 | `0x620892` | classification returns 2 before testing low `0x81` |
| `0x10` /4 | `0x70B00B`, `0x70B0F1` | booth open predicate true when manager+8=0; close predicate true when +8!=0; otherwise false |
| `0x40` /6 | `0x6207EE` | boolean low-bit 6 predicate; **not** the stat-refresh flag |
| `0x80` /7 | `0x62085B` | boolean low-bit 7; also `0x62087E` classification |
| `0x100` /8 | `0x620828` | boolean low-bit 8 predicate |
| `0x200` /9 | `0x6F52D6` | magic-path gate branch; retail enum name not established |
| `0x400` /10 | `0x6D9739` | message-producing branch of `sub_6D9702`; retail enum name not established |
| `0x40000` /18 | `0x716FE3` | gates the block ending at `0x71702C`; retail enum name not established |
| `0x200000` /21 | `0x620785` | boolean; contributes to composite `0x62071E` |
| `0x400000` /22 | `0x61DFF5` | posts main-window `0xBF9` when set, `0xDDC` when clear in 1110 |
| `0x02000000` /25 | `0x61F2E7`, `0x658C4A..6C` | rejects jump request, emits `STR_RIDE_MATCH_MSG_FORBID_JUMP`; also charge/magic gates, so “jump forbidden” is not its only effect |
| `0x08000000` /27 | `0x6207CB` | boolean; composite `0x62071E` |
| `0x10000000` /28 | `0x61F305` | current-set 1110 path calls `0x69770A`; set→clear calls `0x697719` |
| `0x20000000` /29 | `0x6207A8` | boolean; composite `0x62071E`, transition pattern `0x732A44` |
| `0x80000000` /31 | `0x732A4D` | transition pattern `0x732A44` |
| `0x0000000100000000` /32 | `0x62080F` | boolean; both composites |
| `0x0000000200000000` /33 | `0x6F6696` | when reached, set-bit branch emits `STR_MAGIC_GHOSTLOCK_FORBIDDEN` |
| `0x0000001000000000` /36 | `0x732CD7` | posts `0xDE1` when set, `0xDE2` when clear |
| `0x0000002000000000` /37 | `0x620693` | boolean; composite `0x62071E` |
| `0x0000004000000000` /38 | `0x6206C8` | see correction and transition below |
| `0x0000008000000000` /39 | `0x6206AC` | boolean; both composites |
| `0x0000010000000000` /40 | `0x6206E1` | boolean high-bit 8 predicate |

`0x62071E` is OR of bits 21, 29, 27, 37, 32, 39. `0x732A44` is OR of bits 31, 32, 39, 29
(mask `0x00000081A0000000`), **not just high `0x81`**.
`0x62087E`: low bit 3→2; otherwise any low `0x81`→0; otherwise 1. Its 1110 caller emits localized
messages only on the matching language branch. Numeric results are not invented PvP-mode names.
No “unused” assertion is made for other bits; their retail meanings remain unproven here.

### High-bit correction and exact transition

At `0x6206C8`, call getter; `0x6206CD xor eax,eax`; `0x6206CF and edx,0x40`.
The new analyst name is `CGameMap_HasFlags64HighBit6_Analyst`. One-hot execution of original x86
returns false for flags=`0x40`, true for flags=`0x0000004000000000`.

1110 snapshots this predicate at `0x732B4A` and tests it again at `0x732CF8`.
`0x732CFD/0x732D00` compares them: **equal jumps to `0x732D6F`**, skipping the entire refresh/send
block. On a change it calls `CHero__RefreshEquipmentDerivedStats` at `0x732D09`, posts
`0x445`, `0x446`, `0xDA4`, then builds MsgAction **0x198 (408)** at `0x732D4C` and sends only if
that builder succeeds (`0x732D51..5B`). The send is conditional on the bit transition.

Sources: [0x6206C8 ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x6206c8.asm.txt), [0x732B10 ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x732b10.asm.txt),
[33 getter callsite windows](../../10_work/docs/evidence/map-identity-flags-catalog-5517/flags-getter-callsite-census.json),
[original-x86 one-hot tests](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native-validation.json).

**Per-map flags:** none of the 276 legacy values can be promoted to retail 5517 authority from these
client files. Their exact legacy values are preserved in [reconstructed-catalog-276.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/reconstructed-catalog-276.json).
A transmitted zero is valid; zero chosen because no evidence exists is an **unresolved placeholder**.

## 3. GameMap.dat layout, duplicate handling and terrain lookup

Little-endian stream, byte 0 u 32 count; records begin byte 4:

```
u32 MapDataId
u32 pathByteCount
byte path[pathByteCount]     // no on-disk terminator is consumed separately
u32 companionValue         // historical analyst label: componentLinkId
```

GameData `0x10007678` opens `ini/GameMap.dat` in `rb`. It clears a stack value of **0x44 bytes**,
reads key (`0x10007711`), length (`0x1000771B`), path (`0x10007726`), writes a NUL at path[length]
(`0x1000772F`), then reads companion at value+0x40 (`0x10007738`). `fread` return counts are ignored.
There is no length cap enforced. The path region is 64 bytes; an in-region terminating NUL requires
length≤63. At length 64 or greater the terminator/path can overlap companion storage; still larger
lengths can overwrite the stack. Retail lengths are 13..28. This is not a robust malformed-input contract.

Table is `RoleData+0x138`. At `0x1000774A`, find-or-insert returns value storage; `0x1000775D`
copies **17 DWORDs** into it. Existing key storage is reused (`0x10008781..B7`), so the final row wins.
Exact-key getter `0x10007776` uses `0x100104EE`, which rejects a greater lower-bound candidate at
`0x1001051B/1E`. Missing returns NULL, never a neighbor. Key comparisons are unsigned 32-bit.

| Duplicate 1067 (zero-based ordinal) | File offset | Path | Companion |
|---:|---:|---|---:|
|140|`0x1090` (4240)|`map/map/qiling-z.7z`|256|
|185, winner|`0x1679` (5753)|`map/map/09Christmas02.7z`|128|

All 262 records, precise offsets and trailing-data check: [gamemap-records.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/gamemap-records.json).
All 261 winners: [gamemap-effective-index.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/gamemap-effective-index.json).
Same-path alias groups and missing paths: [gamemap-summary.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/gamemap-summary.json).
These are **terrain-key→path** mappings, not world-ID mappings.

`CGameMap_CreateFromDataId` **0x61DA1F** queries RoleData vtable+0x7C (`0x61DA49`), whose entry
GameData:`0x10017164` is `0x10007776`. Missing key logs and returns 0. It copies the path at
`0x61DAA3`, reads companion+0x40 at `0x61DAA9`, forwards through `0x638EF1`→`0x63A961`, then
loads it at `0x61DACC`. Companion is stored to global `0x93D218` and type 1 component+`0x1DC`
(the chained offsets are +0x18,+0xA0,+0x124); it is **not packet 1110 flags**. The retail values
are 128 or 256; a more specific meaning than this consumer chain is not assigned in this audit.
The grid loader writes temporary dataId 1 at `0x61DFC0`; successful outer creation replaces it with
its actual input key at `0x61DBE4`. This is not worldMapId/dataId equivalence.

Reader mode 3 invokes **0x7715A8**, which lowercases a path and searches for **substring** `.7z`
first, then `.gz`, returning 2/1/0. It is not a strict suffix test. `0x771679` chooses 7z/gzip/raw.
The 7z backend `0x771323` uses ordinary `fopen(path,"rb")` (`0x77135E`), checks signature
`37 7A BC AF 27 1C` through `0x771426`, and extracts through `0x771498`→`0x7BD830`.
There is no demonstrated WDF or alternate-terrain fallback in this path.

DMap grid loader **0x61DC3D** reads twoDWORD header fields, 260-byte puzzle path, signed-loop width
and height at file offsets 268/272, then each row of `width × (u16 passability,u16 surface,s16 elevation)`
and a u 32 checksum. First cell starts offset 276. Header fields are not assigned to map flags.
Per-row checksum is `sum((surface+y+1)*passability + (surface+x+1)*(elevation+2)) mod 2^32`.
Signed elevation is established by `movsx` at `0x61DE7B`; row mismatch at `0x61DECE` takes failure.
After the base grid it loads exit markers, scenery and positioned overlays. Base passability alone
is not a proof of all runtime movement behavior.

Sources: [0x10007678 ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/GameData.dll/0x10007678.asm.txt), [0x100104EE ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/GameData.dll/0x100104ee.asm.txt),
[0x61DA1F ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x61da1f.asm.txt), [0x61DC3D ASM](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x61dc3d.asm.txt),
[reader captures](../../10_work/docs/evidence/map-identity-flags-catalog-5517/native/Conquer.exe/0x7715a8.asm.txt).

## 4. Recheck of the eight migration assignments and map 1501

These tests combine **legacy** placed-content coordinates from `conquer.sql` with pristine 5517
base terrain. They verify geometric compatibility, not that either the legacy coordinates or
candidate binding came from the retail 5517 server. Native NPC/trap placement is not in general
required to occupy a walkable base tile; even an incompatible coordinate cannot identify which
input is wrong or rule out deliberate placement/runtime overlays.

| World MapId | Old dataId | Candidate dataId | Compatible base cells, old→candidate |
|---:|---:|---:|---|
|1051|1051|1079|portals 0/6→6/6|
|1500|1500|1734|NPC 0/1→1/1|
|1502|1502|1735|NPC 0/1→1/1|
|2021|2021|1501|traps 0/16→16/16|
|2022|2022|1500|traps 12/16→16/16|
|2023|2023|1501|traps 0/16→16/16|
|2024|2024|1500|traps 0/16→16/16|
|2080|2080|700|type 1003 action destinations 2/8→8/8|

[legacy-coordinate-recheck.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/legacy-coordinate-recheck.json) records table/row IDs,
coordinates, candidate dataId, bounds, decoded cell triples and verdict for each point.
Terrain hashes/dimensions are in [terrain-assets.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/terrain-assets.json).

For **1501**, NPC 664 at (84, 60) and action 3554691 at (78, 59) pass under both 1501/mine-b and 1730/fairylandPK-02.
Pristine `GameMapEx.ini` names 1500/1501/1502 `ClassPKArena1/2/3`; it has no 1730/1734/1735 section.
This is supporting thematic evidence only. The name table does not bind world IDs to terrain keys.
The checked-in 273-row baseline retains 1501→1501; the migration leaves it unchanged. This audit neither
certifies that assignment nor substitutes 1730.

## 5. What the 276-map reconstruction actually proves

The two checked-in SQL snapshots (`conquer.sql`, `ConquerServerDB.sql`) each have 273 `cq_map` rows.
Applying only the eight mapdoc changes and three additions 1782→1004, 1783→1004, 1794→1028 from
migration `20260818_04_correct_map_catalogue.sql` reproduces **276 distinct world IDs**, **243 distinct
terrain IDs**, and **38 non-identical pairs**. This is an offline reconstruction of identity/flags,
not a live database export or proof the migration was applied. Revive-point changes are outside this
identity/flags projection. Original-source hashes: [legacy-sql-map-snapshots.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/legacy-sql-map-snapshots.json).

All 276 selected keys resolve to archive-present terrain, but the complete retail world-map set,
instance allocations, intended bindings, and per-map flags remain unknown. GameMap.dat's 261 keys and
this catalog's 276 worldIDs count different things. Additional unreferenced files/name records do not
prove additional live retail world maps. Conversely, absence of a world ID from GameMap.dat does
not prove the world ID invalid: it may use another terrain key.

The older `Archives/zf.sql` has 306 map rows and does not equal the checked-in 273-row projection.
Later/private-server datasets are corroboration only. No private-server MapType enum is promoted
to a native enum. The migration's type 0 values for the three additions remain placeholders.

**Complete non-identical list in this reconstruction — all retail bindings unproven:**

| World MapId | MapDataId | Legacy flags (hex) | Selected retail path |
|---:|---:|---|---|
|1051|1079|`0x0000000000000000`|`map/map/mys-island.7z`|
|1052|1082|`0x0000000000002000`|`map/map/idland-map.7z`|
|1217|1075|`0x0000000000000002`|`map/map/newcanyon.7z`|
|1219|1212|`0x0000000000008042`|`map/map/island-snail.7z`|
|1300|1001|`0x0000000000002002`|`map/map/d_antre01.7z`|
|1500|1734|`0x0000000000000000`|`map/map/fairylandPK-06.7z`|
|1502|1735|`0x0000000000000000`|`map/map/fairylandPK-07.7z`|
|1782|1004|`0x0000000000000000`|`map/map/forum.7z`|
|1783|1004|`0x0000000000000000`|`map/map/forum.7z`|
|1794|1028|`0x0000000000000000`|`map/map/mine-four.7z`|
|1927|1762|`0x0000000000002000`|`map/map/icecrypt-lev1.7z`|
|2021|1501|`0x0000000000000000`|`map/map/mine-b.7z`|
|2022|1500|`0x0000000000000000`|`map/map/mine-a.7z`|
|2023|1501|`0x0000000000000000`|`map/map/mine-b.7z`|
|2024|1500|`0x0000000000000000`|`map/map/mine-a.7z`|
|2080|700|`0x0000000000000000`|`map/map/arena-none.7z`|
|4021|2021|`0x0000000000002006`|`map/map/Dgate.7z`|
|4022|2022|`0x0000000000002006`|`map/map/Dsquare.7z`|
|4023|2023|`0x0000000000002006`|`map/map/Dcloister.7z`|
|4024|2023|`0x0000000000002006`|`map/map/Dcloister.7z`|
|4025|2024|`0x0000000000002047`|`map/map/Dsigil.7z`|
|6003|6000|`0x000000000001A043`|`map/map/prison.7z`|
|6072|1004|`0x0000000000010008`|`map/map/forum.7z`|
|7000|1730|`0x0000000000000007`|`map/map/fairylandPK-02.7z`|
|7001|1730|`0x0000000000000007`|`map/map/fairylandPK-02.7z`|
|7002|1732|`0x0000000000000007`|`map/map/fairylandPK-04.7z`|
|7003|1731|`0x0000000000000007`|`map/map/fairylandPK-03.7z`|
|7004|1731|`0x0000000000000007`|`map/map/fairylandPK-03.7z`|
|7005|1730|`0x0000000000000007`|`map/map/fairylandPK-02.7z`|
|7006|1730|`0x0000000000000007`|`map/map/fairylandPK-02.7z`|
|7500|1734|`0x0000000000000007`|`map/map/fairylandPK-06.7z`|
|7501|1734|`0x0000000000028005`|`map/map/fairylandPK-06.7z`|
|7503|1090|`0x0000000000000007`|`map/map/parena-m.7z`|
|7504|1616|`0x000000000001020C`|`map/map/tiemfiles.7z`|
|7505|900000|`0x0000000000040225`|`map/map/newarena.7z`|
|7600|2071|`0x0000000000030084`|`map/map/bp-kingfight.7z`|
|7601|6000|`0x0000000000018163`|`map/map/prison.7z`|
|8000|1001|`0x0000000000002000`|`map/map/d_antre01.7z`|

The other 238 identical pairs are retained, also explicitly unverified as retail bindings.
Machine-readable all 276 rows and flags: [reconstructed-catalog-276.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/reconstructed-catalog-276.json).

### Other client map files are not the missing server catalog

- `ini/GameMapEx.ini`:282 sections, only `Name` keys. GameData `0x100077A1` converts section name
  to an integer and stores its Name in a separate table at+0x144. No dataId or flags mapping.
- `ini/MapRelationInfo.ini`:8 route records (`MapID`, `LinkMapID`, link indices, cell coordinates).
  EXE `0x624750` loads these; a link to another world map is not a terrain assignment.
- `ini/MapDestination.dat`: encoded 48898 bytes; native `0x6E361A` uses seed 0x2537. Decoded 271 sections
  contain title/id/mapid/position/radius/npcid/mark/parentid, with missing keys in some sections.
  `0x6E3736..3820` reads them as destination/UI data, not MapDataId/flags. No corresponding mapdoc field.

See [auxiliary-map-configs.json](../../10_work/docs/evidence/map-identity-flags-catalog-5517/auxiliary-map-configs.json) and preserved encoded/decoded inputs.
These checks do not claim an exhaustive absence proof over every possible retail resource.
They establish that the indexed terrain path and relevant map-config readers do not provide the
requested authoritative server mapping table.

## 6. Verification, corrections and remaining limits

- **67 function captures / 11418 instruction rows** matched bytes in freshly extracted native binaries.
- Original-x86 replay:17 flag predicates ×69 inputs; classification 69; setter/getter sequences 69;
  full 262-record loader;386 exact-key lookup cases;261 original existing-key find-or-insert cases.
  Stdio/allocation boundaries are explicit stubs; original Windows process/gameplay was not run.
- **192 single-file 7z archives** decoded; all base-grid row checksums pass. Their 170 effectively
  referenced distinct paths plus 9 absent paths account for all 179 winning paths.
- All eight geometry comparisons and map 1501's two-candidate tie independently reproduced.
- Binary Ninja:3 clearly labeled analyst renames and 10 address comments; restorable before/after
  ledger, no database save. Historical raw captures retain earlier labels/comments; instruction
  bytes and this correction contract take precedence.

Corrected maintained Network/HUD notes: bit 38 vs lowbit 6, accessor/entry addresses, and overclaims
that geometric fit proves a retail mapping. Existing legacy `10_work/src/Conquer/World/State/Map/CGameMapState.cs`
and `CGameMapStateFlags64Tests.cs` still encode low 0x40 and high-word irrelevance. **They are stale
for 0x6206C8 and must not be used as native evidence.** No production/test source was edited here.

**Still not established:** retail server MapId→MapDataId assignments (including 1501 and all 38
non-identical legacy pairs); exact per-map 64-bit flags; a complete named enum for every bit;
completeness/retail accuracy of 276 world maps; missing kunlun assets in another distribution; full
runtime passability/rendering from base-grid checks alone. Closing the server-data questions needs
authentic 5517 server data or appropriately proven contemporaneous server packet captures. A capture
can prove the particular observed assignment/flags, not automatically the entire server catalog.

## Catalog follow-up — 2026-10-10

- `GameMapEx.ini` keys are **world MapIds**: GameData `0x10007906` (`RoleDataSingleton_GetGameMapExNameByWorldMapId`,
  vtable+0x80) is called from Conquer `0x5305B4`/`0x530A3D` with the SuperFlag record map id; 108/282 keys are not terrain keys.
- Hard-coded world IDs 601, 1002, 1036, 1039, 1858, 1860; terrain keys 1037/1038 (`0x6F922C`).
- Working catalog, 1501→1730 (TQ-English data), flags and passways: [map-catalog-5517.md](map-catalog-5517.md).
- **Census addition (rev 2):** 18 inline `GetType()&mask` sites read the singleton (`0x410685` → `[0x955F9C]`) fields
  directly, bypassing getter `0x61F2DA`: bit 13 (`0x576B70`, `0x65D858`, `0x65D924`), 15 (`0x66F92D`), 26 (`0x65EC59`,
  `0x6C4AB5`), 31 (`0x62631F`, `0x6E79B3`), high 34 (`0x5B06B7`, `0x5B31CC`), 35 (`0x5B0C7C`), 36 (`0x626345`, `0x732CD7`).
  `0x732CD7` is inline (reads `+0xEC` at `0x732CD1`), not a getter site. Readers ≥ bit 41: none found by either census.

## zf.sql follow-up — 2026-10-10

The [complete SQL reconciliation](zf-map-reconciliation-5517.md) identifies Wolf-War customizations
in the supplied306-row zf dump, corroborates five of the eight historical terrain candidates, and
records candidate flags for1782/1783/1794. It does not resolve1501 or retail high flags. It also records
two additional non-coordinate references to1501 and two dangling passway joins produced by the
historical portal deletion. The earlier one-line zf classification was not a provenance audit; use
the new report and exact row evidence. No retail-authority conclusion above changes.
