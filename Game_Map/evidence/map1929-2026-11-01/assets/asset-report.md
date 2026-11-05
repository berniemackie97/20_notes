# MapDataId 1929: supplied retail asset evidence

Verified 2026-11-01. Scope is exactly `/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517`.
No other client tree, server package, or reconstructed content is substituted. This is a filesystem-byte audit using layouts and the WDF hash previously proven in the native 5517 notes; it performs no new Binary Ninja calls and does not establish runtime rendering by itself.

## Map identity and requested resource

`ini/GameMap.dat` is 8,131 bytes, SHA-256 `0676b7d6969dd8277438704a289b1f57e8debb89fe5d3f912819c3a7880686a0`.
All 262 counted rows were parsed to EOF. Exactly one row has MapDataId 1929:

| Field | Exact value |
|---|---|
| Zero-based row index | 182 |
| Row byte offset | 5655 (`0x1617`) |
| Path byte count | 19 |
| Path | `map/map/arenamap.7z` |
| Companion component-link dword | 256 |

No second row refers to an `arenamap` path. The path's 19 bytes contain no terminal NUL; this is the table's length-delimited path representation.
The established native table reader is `GameData.dll!RoleDataSingleton_LoadGameMapDatTable`, `0x10007678`; the map-row data layout is recorded in `20_notes/Game_Map/cgamemap_class.md`.

`map/map/arenamap.7z` is 3,394 bytes, SHA-256 `67c5d818fcc7a8ae8ec11bb45bf039f46e34ff32d4bc2df911791d218e668c81`.
Its only member, `arenamap.DMap`, extracts to 107,308 bytes, SHA-256 `8ade4316514cd151bfe01ad3be339b1b5982c13e6415bc9a7d68e7fdab4b1de0`.
The loose `map/map/arenamap.DMap` is byte-identical. The compressed path remains the table-selected source.
Extraction used installed `7zz`; its member listing is retained in `arenamap-7z-listing.txt`.

At DMap payload offset `+0x08`, the fixed 260-byte puzzle-path field begins with the NUL-terminated string:

```text
map\puzzle\arenamap.pul
```

The field has nonzero bytes after the terminating NUL near its end. The complete 260 bytes are retained in `asset-audit.json`; they are not part of the requested C-string.
Header dwords are `1004, 0`; width and height at `+0x10C/+0x110` are `100, 100`.

## Remaining DMap sections are structurally valid

`dmap-validation.json` preserves every row checksum and every subsequent record, with offsets.
The checks use the previously documented native first-grid layout and wrapping 32-bit row accumulator:

```text
rowSum += ((surfaceId + y + 1) * passabilityFlag)
        + ((surfaceId + x + 1) * (signedElevation + 2))
```

- All 100 stored row checksums match.
- All 10,000 base elevations are zero. Passability counts: zero 3,723; one 6,277.
- Exit count at byte 60,676 is zero.
- Scenery count at byte 60,680 is 111. Every entry is subtype 4, 420 bytes including its four-byte discriminator.
- The post-scenery positioned-record count at byte 107,304 is zero.
- Parsing consumes exactly 107,308 bytes, with no trailing bytes and no unknown record type.
- There are no subtype-1 external `.scene` references or positioned puzzle overlays in this DMap.

These are data prerequisites for the native continuation path. They do not prove successful allocation, file I/O, or rendering in a running process.

The 111 scenery entries reference 34 distinct ANI sections across two ANI files. All sections exist, each declares `FrameAmount=1`, and all 34 declared frame resources resolve within the supplied corpus through their routed WDF entry. `scenery-resource-validation.json` records exact file/section names, frame paths, UID, archive offsets, hashes, and DDS dimensions. This verifies that the missing ground-puzzle path does not imply missing scenery frame resources.

## Requested loose file is absent; `arena.pul` is a different path

The source inventory contains 26,847 files. A complete relative-path inventory was lowercased and normalized from backslashes to slashes for this exact-path check.
There is no loose file matching `map/puzzle/arenamap.pul`, including a case-only spelling variant.
The original relative path list is retained in `relative-path-inventory.txt`.

There **is** a distinct `map/puzzle/arena.pul`:

| Property | Value |
|---|---|
| Size | 412 bytes |
| SHA-256 | `5336a4a8d714c32a36521c3075307f99c0bffeda8be10b826689097789d5cff5` |
| Signature | `PUZZLE` |
| ANI path | `ani\room.ani` |
| Grid | 10 × 7 |
| Empty `0xFFFF` entries | 0 |
| PUZZLE2 scrolling fields | Absent |

The entire 412-byte file parses to EOF under the documented puzzle layout. Similar naming does not establish an alias, fallback, or intended replacement. This audit does not authorize renaming, copying, rewriting the DMap path, or substituting that puzzle.

## Registered WDF package/index checks

Native package registration/routing/hash behavior is already documented in `20_notes/Rendering/c3_core_dll/11_datafile_and_wdf.md`:

- `GraphicData.dll 0x1001A390` reads whitespace-delimited `ini/package.ini` tokens.
- `TqPackageWdf.dll 0x10009890` normalizes ASCII case and slashes.
- `0x100098F0` hashes normalized bytes; `0x100099D0` is normalize-and-hash.
- `0x10003C80/0x10003C30` route by first path segment; `0x10003CD0` selects a registered prefix.
- `0x10002BD0/0x10003A10` find the full-path UID in the selected index.

`ini/package.ini` is 29 bytes, SHA-256 `511028e125d43635d90f777806b0f0fee65895b5b1a604cf278001fee536a8f2`.
Its exact tokens are `data.wdf`, `c3.wdf`, `data3.wdf`.

| Token | On disk | Entry count | Full-file SHA-256 |
|---|---:|---:|---|
| `data.wdf` | yes | 14,739 | `fc628e4adeb7de48b0b7cde3c7793c7177a289a6defe9b90a33a1f683dcdb132` |
| `c3.wdf` | yes | 10,274 | `ab68f57cc24ae10052031583ce7aa4676247fe8dde5a7bdd98e572adcf7b7243` |
| `data3.wdf` | no | no on-disk index | — |

Both present WDF headers, table bounds, and every entry payload bound were checked.
Full table hashes and offsets are retained in `asset-audit.json`.

- Requested normalized path `map/puzzle/arenamap.pul` hashes to **`0x4E85865D`**. It has zero entries in either complete present index.
- `map/puzzle/arena.pul` hashes to `0x456CA21F`. It also has zero entries in those indexes; its supplied file is loose.
- Prefix `map` hashes to **`0xA070FEF8`**. No listed package has that prefix hash. Registered prefixes are `data=0xE28E6E42`, `c3=0x13C60262`, `data3=0x4F0B9715`.
- Two known frame paths were positive controls for the ported, previously verified hash algorithm: `data/map/puzzle/newbie/newbie004.dds` resolves UID `0xDE0B31DF`; `data/map/mapobj/newbie/newbie01.dds` resolves `0x58517C18`. Both entries yield DDS payloads and have recorded byte hashes.

This is exact index membership checking, not a strings-based absence claim. It does not assert absence from every archive ever shipped.
The native puzzle loader's actual I/O path is a separate code question. If that loader opens the puzzle directly with CRT `fopen`, these package results are corroborating corpus inventory, not an invoked fallback mechanism.

## Bounded configuration reference search

All source files with extensions `.ani`, `.cfg`, `.conf`, `.csv`, `.ini`, `.json`, `.lst`, `.lua`, `.txt`, `.xml`, plus non-NUL `.dat` files beneath `ini/`, were searched for `arenamap`, numeric-token `1929`, and `map/puzzle/arena.pul` with either slash direction. Files with those explicit text/config extensions were scanned even when they contained NUL bytes. Twenty-four NUL-bearing `ini/*.dat` files were excluded from this text search and inventoried separately; `GameMap.dat` was parsed structurally above.

There were 226 scanned files and 12 matching lines. Every scanned and skipped file has a size/hash record in `configuration-inventory.json`.
The only map-specific text reference found is:

```ini
; ani/MiniMap.Ani, lines 709-711
[1929]
FrameAmount=1
Frame0=data/MiniMap/arenamap.jpg
```

That loose JPEG exists; its identity is recorded in `asset-audit.json`.
The remaining matches are `Puzzle1929` ANI section identifiers, GUI control IDs ending in `1929`, and `MissionId=1929`; they are not map-path aliases.
No `arenamap.pul` replacement rule was found in this bounded text/config search. This does not prove absence of native hardcoded remapping, encrypted/configuration data rules, or runtime patches; those require the separate native trace.

## Evidence files and limits

- `asset-audit.json`: table row, source hashes, exact DMap path field, loose absence, candidate puzzle, complete package results, text-search hits.
- `dmap-validation.json`: all row checksums, 111 scenery records, section offsets and EOF.
- `scenery-resource-validation.json`: declared ANI sections and all corresponding routed frame entries.
- `configuration-inventory.json`: full search boundary with hashes, including skipped binary `.dat` files.
- `relative-path-inventory.txt`: complete supplied-root file path inventory for case-normalized absence checking.
- `arenamap-7z-listing.txt`: archive member inventory.

No source asset, content manifest, implementation, test, or database was modified. Only research notes/evidence and task scratch were written. Native failure propagation, empty-ground behavior, and any runtime remapping remain the responsibility of the accompanying native trace.
