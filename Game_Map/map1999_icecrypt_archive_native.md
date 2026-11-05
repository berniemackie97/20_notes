# Map-data 1999: `icecrypt-lev3.7z` post-grid parse (native)

Verified 2026-11-01, Binja `Conquer.exe.bndb`. Bytes: [evidence/map1999-2026-11-01/assets/asset-report.md](evidence/map1999-2026-11-01/assets/asset-report.md).
Replay: [evidence/map1999-2026-11-01/replay_native_tail.py](evidence/map1999-2026-11-01/replay_native_tail.py) (instruction-derived cursor model, not runtime).

| Input | Value |
|---|---|
| GameMap.dat row | 198, offset 6209, id 1999, `map/map/icecrypt-lev3.7z` |
| Archive | 19,766 B, SHA-256 `8ddb3929…54809cb8` |
| Member `icecrypt-lev3.DMap` | 4,039,008 B, SHA-256 `08cf96b8…4af9a9d`, header `[1005,0]`, grid 820×820 |
| Loose `.DMap` | 4,106,200 B, header `[1004,0]`; not loaded (row selects `.7z`); 694 cells differ |

## Verdict

> **Runtime disagrees (see Runtime):** retail draws the loose `.DMap` scenery, including the object at (112,422). The static parse below describes the archive bytes; why they are not what gets rendered is unresolved.

- **Accepted.** `CGameMap_LoadMapFileFromRelativePath` returns 1, `map+0xE4 = 1`. No failure branch is reached.
- **Header 1005 ignored.** No field selects a layout.
- **Count 100 is misalignment.** The archive's type-4 records carry one extra dword each; native reads 420 B per record.
- **Result:** scenery object 0 is correct. Object 1 is misread (path `"\x04"`, empty section). The real object at tile (112,422) is lost. Zero positioned records. The exits and grid are correct.

## Call path

`CGameMap_CreateFromDataId` `0x61DA29` → `0x61DACC` `CGameMap_LoadMapFileFromRelativePath` `0x61DC3D`:

| Addr | Step |
|---|---|
| `0x61DC72` / `0x61DC7A` | `CGameMap_ResetAndInitializeDefaultComponents`, `CGameMap_FreeTileCellAttachmentGrid` (old map gone before any read) |
| `0x61DC9E` | `MapFileReaderConstructFromPathAndMode(path, 3)`: mode 3 = by extension, `.7z` → mode 2, `MapFileReader7zBackendConstruct` `0x771323`, vtable `0x86D840` (slot +8 = `0x7714BF`) |
| `0x61DCC4` | `MapFileReaderReadSuccess`; false → log, return 0 |
| `0x61DD00` / `0x61DD0F` | header dwords → `[ebp-4Ch]`, `[ebp-48h]`; never read again in the function |
| `0x61DD78` | 0x104 puzzle path → ground puzzle open (`0x61DDC9`, failure non-fatal, see [map1929](map1929_missing_puzzle_native.md)) |
| `0x61DDDE` / `0x61DDED` | width, height → `CGameMap_SetTileGridDimensionsAndAllocateCells` `0x61DDFA` |
| `0x61DE5A..0x61DEC3` | cells (3× word) + row checksum; mismatch `0x61DECE` → `0x61DFD6` return 0 |
| `0x61DEF4` | `CMapGroundEntityLayer_LoadExitMarkersFromMapReader` `0x637769`: count + 12 B triplets |
| `0x61DF0A` | `CMapSceneryComponent_LoadSubcomponentsFromMapReader` `0x635808` (void) |
| `0x61DF19` | positioned-record count |
| `0x61DF34` / `0x61DF43` | per entry: insert index, kind |
| `0x61DF48` | kind == 4 → alloc 0x34, `CGameMapPositionedOverlayRecord_Ctor` `0x639912`, insert at `map+0x04`, `_LoadFromMapReader` `0x639BD6`; else no bytes |
| `0x61DF70` | alloc failure → `0x61DFD6` return 0 |
| `0x61DFC0` | `map+0xE4 = ebx (1)`; `0x61DFD2` return 1 |

`CreateFromDataId`: nonzero → reset projection, clear players, close booth, rebuild hero/role list, post msg 0x424, return 1. Zero → log `game map %s load failed`, return 0. Old components are already destroyed. There is no rollback.

## Scenery block (`0x635808`)

| Addr | Read |
|---|---|
| `0x635829` | count (signed, `jle`) |
| `0x63584A` | subtype; dispatch 1 / 4 / 10 / 15. Other values consume nothing (`0x635870`). |

Type 4: `CMapType3SubcomponentType04_LoadFromMapReader` `0x645654`. Body is 416 B, so 420 B with the subtype.

| Addr | Size | Dest | Field |
|---|---:|---|---|
| `0x64569F` | 0x104 | +0x14 | ANI path (byte 0x103 forced NUL) |
| `0x6456DB` | 0x80 | +0x20 | section (byte 0x7F forced NUL) |
| `0x645708` / `0x645716` | 4+4 | +0x0C / +0x10 | tile X / Y |
| `0x645724` / `0x645732` | 4+4 | +0x34 / +0x38 | depth span X / Y |
| `0x645740` / `0x64574E` | 4+4 | +0x2C / +0x30 | render offset X / Y |
| `0x64575C` | 4 | +0x40 | frame interval ms |

There is no eighth dword, no seek, no header test and no length check.

## Reader EOF (`MapFileReaderBufferedPayloadRead` `0x7714BF`)

`copy = min(size*count, end − cursor)`, then memcpy, `cursor += copy` (`0x7714FE`), return copy. At EOF the copy is 0: the destination is unchanged and there is no flag or exception. No DMap caller checks the return value.

## Archive tail under native framing

| Offset | Read as | Value |
|---|---|---|
| `0x3D9D44` | exit count + 16 triplets | 16; correct |
| `0x3D9E08` | scenery count | 2 |
| `0x3D9E0C` | rec 0 subtype + body | 4; `ani\mapscene02.ani` / `icecrypt36.tga`, tile (58,372), span (3,6), offset (261,492), 100 ms |
| `0x3D9FB0` | rec 1 subtype | 4 (actually rec 0's extra dword) |
| `0x3D9FB4` | rec 1 body | path `"\x04"` (real subtype bytes), section `""`, tile (0,112), span (422,3), offset (6,261), 492 ms |
| `0x3DA154` | positioned count | **100** (real rec 1 interval) |
| `0x3DA158` / `0x3DA15C` | entry 0 index / kind | 4 / 0 (real extra dword / real count 0) |
| `0x3DA160` | EOF | the other 99 entries read 0 B; locals stay 4/0; kind ≠ 4, so nothing is created |

198 zero-byte reads, final cursor = EOF. Stale locals: `[ebp-14h]` was the grid column counter, `[ebp-28h]` the checksum accumulator (`0x61DF1E`). Both are overwritten by entry 0 before use.

Extra-dword framing (424 B per type-4 record) ends exactly at EOF with positioned count 0. Its meaning and writer are unknown. 5517 never reads it.

## Neighbors / companion

- Levels 1, 2, 4, 5, 6 archives and the loose level 3 are `[1004,0]` and parse to EOF with 420 B type-4 records.
- The loose level 3 has 162 scenery records, and its grid differs from the archive's in 694 cells, so the two files are not interchangeable.
- Only archived level 3 uses `1005` and the extra dword. That correlation is observed, not proof of any 1005 format, because 5517 ignores the header.

## Misread object at runtime

- It is inserted via `CMapSceneryComponent_InsertLoadedSubcomponent` at tile (0,112).
- Render `0x64522E` and Tick `0x64556B` skip the object when the ANI query returns null.

## Runtime (2026-11-01, retail 5517 in Win11 VM) — CONTRADICTS the static verdict

Setup: clean `5517-loader` tree (same `icecrypt-lev3.7z`, `GameMap.dat`, `Conquer.exe` hashes) in a guest scratch dir. OpenConquerServer ran against a throwaway DB clone, with `Probe1999` placed on map 1999. Captures are in [evidence/…/runtime/](evidence/map1999-2026-11-01/runtime/). Template match uses the client area at 2× stage, over opaque sprite pixels only, with the dialog masked out.

| Capture | Hero | Sprite at predicted stage top-left | Mean abs error (pred / shifted +200 px) |
|---|---|---|---|
| `04` | (59,371) | `icecrypt36` (58,372) → (187,−108) | **5.6** / 33.5 |
| `02` | (113,421) | `icecrypt36` (112,422) → (187,−108) | **3.5–8.8** on unoccluded cells / 42.8. The black status bar covers the top-right only. |
| `02` | (113,421) | `icecrypt37` (131,429) → (600,302) | **7.0** / 37.9 |

- The client loads map 1999, draws terrain and HUD, and does not crash.
- `icecrypt37` at (131,429) exists **only in the loose 1004 `.DMap`**, which has 162 records. The archive has 2 records.
- The object at (112,422) that the static analysis says is lost **is drawn**.
- So the retail client renders the loose `.DMap` scenery, not the archive tail. Placement math is confirmed: tile→screen `32(tx−ty)`, `16(tx+ty)`, minus the render offset.
- The cause is unresolved. `GameMap.dat` gives `.7z`. `MapFileReaderCreateBackendByMode` `0x771679` has no `.DMap` fallback, and the 7z backend extracts the archive via `MapArchive7zExtractPayloadToBuffer`. Next test: rename the loose `.DMap` in a scratch client copy and log in again. Also untested: whether the grid comes from the loose file too (694 cells differ).
- Server side: after map entry, OpenConquerServer drops the session ("not a valid action packet: InvalidPacketId" at client-state-applied). That is a server bug, unrelated to the map.
- Server reachability: FrozenGrotto3 (1999) is reachable. Source Q has passway 1927 idx1 → 1999 (410,484) plus nine exits from 1999. OpenConquerServer has map 1999 with mapDataId 1999.

## Open

- **Closed:** misread object 1 is never drawn. `GameDataSet_QueryAniResourceByDualPath` (GraphicData `0x100045E0`) returns 0 when the section is null or empty (`0x1000462D` → `0x10004A1C`), before any cache insert or request. Render `0x64522E` and Tick `0x64556B` then exit, so the object never reaches `CGameMap_NotifySceneryComponentSubcomponentUpdated` (`0x645625`).
- **Partial, extra dword:** eosource `C2DMapCoverObj::SaveDataObj`/`LoadDataObj` has a commented-out trailing `m_dwShowWay` DWORD right after the frame interval. That is the same position as the archive's extra dword. Its value here is 4, while eosource `_SHOWWAY_*` is 0/1 (and `Sprite_Draw` handles 0..2). So the meaning is unproven.
- **Patch history** (Remakes TQ patches): `5012` ships the loose `.DMap`s dated 2004. `5309` introduces the `.7z` archives (level 3: 21,524 B). `5312` reships level 3 (20,243 B). `5376` (2010-12-10) ships level 3 at 19,766 B, the clean-5517 size. Hash not checked.
- Runtime capture and server reachability: done; see Runtime above.
- **Still open:** why retail renders the loose `.DMap` scenery and not the archive tail. Test: rename the loose `.DMap` in a scratch client copy and log in. Also open: whether the grid comes from the loose file too.

## Binja

| Addr | Annotation |
|---|---|
| `0x61DD00` | header locals unused |
| `0x61DF19`, `0x61DF1E`, `0x61DF48` | count 100 misalignment; stale locals; EOF loop |
| `0x61DFD6` | failure boundary, no rollback |
| `0x635870` | unknown subtype consumes nothing |
| `0x64575C` | type-4 body 416 B |
| `0x64522E` | null ANI → no draw |
| `0x7714FE` | EOF copies 0, destination unchanged |
| renames | `sub_61D15B` → `CGameMap_DestroyAndClearComponents`, `sub_771595` → `MapFileReader_Destroy` |
