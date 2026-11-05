# Map-data ID 1929: missing ground puzzle in retail 5517

Verified 2026-11-01. Research only; no client execution, source changes, content changes, manifest changes, tests, or replacement assets.
Source installation: `/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517`.
Existing Binary Ninja databases under the sibling `5517-bninja` directory were used.
The analyzed executable/DLL input copies match this source installation byte-for-byte.
`Conquer.exe` SHA-256: `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
All addresses below are preferred virtual addresses, qualified by DLL when not in Conquer.exe.

## Conclusion

**The referenced ground puzzle is needed to render the intended ground, but its open failure is not a map-load failure gate.**
The stock code attempts to open the exact DMap filename through `MSVCRT.dll!fopen`.
It logs the failure twice across the puzzle loader and its caller, then continues parsing the DMap.
The fresh puzzle retains an empty index grid. Ordinary ground rendering consequently draws no puzzle tiles.
There is no fallback to `arena.pul`, no package retry, and no native rule making 1929 a deliberately groundless map.

ID 1929 is a valid catalog lookup and has a dedicated minimap declaration and image.
The generic server-driven map-entry paths can select it; whether a matching production server actually did so remains unproven.
Neither an unused-catalog classification nor observed successful gameplay can be established from these client files alone.

## 1. Exact asset identity and references

| Artifact | Verified content |
|---|---|
| `ini/GameMap.dat` | 262 records; exactly one key 1929, zero-based record 182, byte offset 5655 |
| Record | LE32 ID 1929; LE32 path length 19; ASCII `map/map/arenamap.7z`; trailing LE32 value 256 |
| `map/map/arenamap.7z` | 3,394 bytes; member `arenamap.DMap`, 107,308 decoded bytes |
| Decoded DMap | Header dwords 1004, 0; 260-byte puzzle field starts at offset 8; first NUL-terminated string is `map\puzzle\arenamap.pul` |
| DMap grid | 100×100; all 100 native row checksums match |
| Remaining sections | 0 exits; 111 scenery records, all subtype 4; 0 positioned-overlay records; parse ends exactly at EOF |
| Loose companion | `map/map/arenamap.DMap` exactly matches the archive member |
| Required loose puzzle | `map/puzzle/arenamap.pul` absent from all 26,847 inventoried relative file paths, including case/separator-normalized lookup |
| Minimap | `ani/MiniMap.Ani` lines 709–711: section `[1929]`, frame `data/MiniMap/arenamap.jpg`; image exists loose |
| Different puzzle | `map/puzzle/arena.pul`: 412 bytes, `PUZZLE`, 10×7 indices, ANI `ani\room.ani`; no alias or equivalence established |

Hashes:

- `GameMap.dat`: `0676b7d6969dd8277438704a289b1f57e8debb89fe5d3f912819c3a7880686a0`.
- `arenamap.7z`: `67c5d818fcc7a8ae8ec11bb45bf039f46e34ff32d4bc2df911791d218e668c81`.
- Decoded/loose `arenamap.DMap`: `8ade4316514cd151bfe01ad3be339b1b5982c13e6415bc9a7d68e7fdab4b1de0`.
- `arena.pul`: `5336a4a8d714c32a36521c3075307f99c0bffeda8be10b826689097789d5cff5`.

All 111 scenery placements reference 34 distinct ANI sections: 19 in `MapScene.ani`, 15 in `MapScene-snow.ani`.
Each declares one frame, and every frame payload resolves in its routed WDF archive.
This establishes those dependencies' presence, not successful runtime drawing.
There is no external `.scene` or positioned puzzle overlay in this DMap that supplies a substitute ground layer.

The bounded text/configuration scan covered 226 files, with extensions and skipped binary files recorded.
It found the minimap mapping above. Other numeric 1929 hits belong to GUI control IDs, `MissionId`, or `Puzzle1929` sections;
a shared number does not establish a MapDataId reference. Binary/encrypted configuration not decoded by this scan remains outside it.

## 2. Catalog and server-driven selection

`GameData.dll!RoleDataSingleton_LoadGameMapDatTable` (`0x10007678`) reads the record key, length, bytes,
and companion value at `0x10007711`, `0x1000771B`, `0x10007726`, `0x10007738`.
It stores a 0x44-byte value containing path at `+0` and companion value at `+0x40`.
The getter `0x10007776` performs an exact key lookup and returns that record or NULL.
There is no 1929-specific exclusion in the recovered loader/getter.

`CGameMap_CreateFromDataId` (`0x61DA1F`) calls `RoleDataQuery` at `0x61DA3C` and the lookup virtual slot
`+0x7C` at `0x61DA49`. It copies the returned path, forwards the companion value, and calls the DMap loader at `0x61DAD3`.
The two recovered direct callers are in `CMsgAction__Process` (`0x6FED1F`):

| Server action | Call site | Selection and gates |
|---|---:|---|
| MsgAction 10010, action 74 / `0x4A` | `0x6FF478` | passes packet DWORD `+8` directly as MapDataId; the loader result is checked/logged, then the handler proceeds with its entry sequence |
| MsgAction 10010, action 86 / `0x56` | `0x6FF6FB` | first requires packet user ID `+4` to match hero `+0xCC` (`0x6FF663`); passes packet DWORD `+8`; a false map-load result exits this action's transition path |

The nearby action-86 special comparison is **2068 / `0x814`**, at `0x6FF6CA`, not 1929.
For a valid packet selecting 1929, catalog lookup reaches the same loading machinery as other catalog maps.
This is a statically reachable client path conditioned on receiving the packet, not evidence that a server ever sent it.
World MapId and MapDataId must remain distinct; a server's dynamic world instance need not itself have world ID 1929.

The minimap reference has a native consumer: `CRadar_Show` (`0x62621C`) formats its map argument as `%u`
at `0x626269`, then requests that section of `ani/MiniMap.ani` at `0x626294`.
`CGameMap_RenderComponentsAndShowScreenEffects` passes map `+0xE4` to it at `0x61D2AC`.
This proves a meaningful client resource binding for 1929, but does not create a gameplay entry trigger.

An exact LE32 `1929` census over all executable PE sections found three immediate pushes at
`0x438C3C`, `0x48E6F0`, `0x4EC7A5`. All feed UI binding helper `0x5E40DD`, whose `0x5E4116`
call is `CDataExchange::PrepareCtrl`; they are UI control IDs. Three other byte matches are relative CALL displacements.
A resource-section match has no established map-dispatch provenance. No ASCII `arenamap` string was found in the executable scan.
This is a bounded census, not proof that every computed, 16-bit, encoded, or external reference is absent.

## 3. DMap path resolution and exact failure propagation

`CGameMap_LoadMapFileFromRelativePath` starts at **`0x61DC3D`**.
`0x61DDC9` is its ground-setter call site, not the function entry.
The map reader constructed at `0x61DC9E` uses mode 3, the existing extension-selected reader path;
`.7z` supplies the decompressed DMap bytes. The verified archive member, not a guessed loose companion, is the source above.

The ground path is resolved as follows:

1. Reset/recreate the map's default components at `0x61DC72`; free the old cell attachment grid at `0x61DC7A`.
2. Read two header dwords. Obtain the process current directory with `GetCurrentDirectoryA` at `0x61DD66`.
3. Read 0x104 puzzle-path bytes at `0x61DD78`.
4. Format `"%s/%s"` from current directory and that path at `0x61DD9C`, with buffer limit 0x103 and explicit final NUL.
   Resolution is relative to **process current directory**, not the DMap's own `map/map` directory.
5. Find the type-1 ground component at `0x61DDAE`. If missing, set map-load result false.
6. Pass the constructed path to `CMapGroundEntityLayer_SetGroundPuzzleBitmapPathAndLoad` at `0x61DDC9`.
   Execution then reads grid width/height at `0x61DDDE/0x61DDED`, without testing EAX or AL from the setter.

Failure chain:

| Function / site | Exact behavior |
|---|---|
| Setter `0x6375C4` | Copies the path to component `+0xC`; calls internal ground loader on component `+0x18` at `0x6375E7` |
| Ground loader `0x638DBD` | `_splitpath`, case-insensitive extension comparison to `.pul`; selects puzzle mode by setting internal `+4=0` |
| `0x638E14` | Calls `CMapPuzzleBitmap_LoadFromPath` with the unchanged full path and puzzle object at internal `+0xA0` |
| Puzzle loader `0x63A603`, call `0x63A61E` | Direct IAT `0x844770`, verified PE import `MSVCRT.dll!fopen(path, "rb")` |
| `fopen` returns NULL | Logs `ERROR: file %s not found at %s, %d` at `0x63A63E`; returns integer 0 at `0x63A646` |
| Ground loader `0x638E19..0x638E33` | Tests zero and returns false; skips success-only blast-grid allocation at `0x638E37` |
| Setter `0x6375EC..0x637605` | Tests false, logs `PuzzleBmp [%s] Load fail in %s %d` at `0x6375FD`, returns; no propagated failure contract |
| DMap caller after `0x61DDC9` | Continues cells, checksum verification, exits, scenery, and positioned records |

The non-`.pul` extension path calls `CAoxPuzzle_LoadFromFile` at `0x638E28`.
It is selected by extension **before** load, and is not a fallback when a `.pul` fails.
There is no retry, alternate basename, manifest alias, search in sibling puzzle files, or `arena.pul` substitution on this path.
The attempted `.pul` is therefore an unconditional requested dependency for this DMap, with non-fatal failure handling at the caller boundary.

The DMap loader still has independent failure paths, including reader failure, missing ground component,
checksum mismatch, and allocation failure. The supplied 1929 DMap passes the offline structural/checksum checks.
On successful DMap return, `CreateFromDataId` continues state setup, writes `map+0xE4=1929` at `0x61DBE4`,
posts main-window message `0x424` at `0x61DC22`, and returns 1 at `0x61DC29..0x61DC2B`.
**Missing puzzle alone does not cause its `game map %s load failed` branch.**
This is static return-flow evidence, not a claim that all possible allocation, device, or runtime failures were excluded.

## 4. Rendering after the failed open

The reset creates a fresh ground object, so this path does not retain the previous map's populated puzzle.
The ground-component constructor `0x63738F` constructs its internal object at `+0x18` via `0x638B99`;
that constructor creates the puzzle at internal `+0xA0` via `0x638BBF`.
`CMapPuzzleBitmap_Constructor` (`0x639F34`) establishes:

| Puzzle-relative field | Fresh value after missing-file return |
|---|---|
| `+0x04` index count | 0 |
| `+0x10` index-grid pointer | NULL |
| `+0x18`, `+0x1C` dimensions | **20, 20**, not zero |
| `+0x20..+0x11F` ANI path | zero-filled |
| `+0x124` tile size | 256 (`0x93D218`) |
| `+0x128`, `+0x12C` scrolling velocities | 0, 0 |

`ResetPuzzleIndexGrid` (`0x639FE7`) clears only pointer/count; it does not clear the dimensions.
The failed open occurs before payload-driven mutations. Consequently `GetScaledBitmapDimensions`
(`0x63A7DC`) still reports **5120×5120**. These are constructor defaults, not recovered intended arena ground dimensions.
Ground extent getters feed this metadata into projection-base calculations; missing ground is not geometrically equivalent to removing the component.

`CMapGroundEntityLayer_Render` (`0x638E44`) remains in `.pul` mode and calls
`CMapPuzzleBitmap_RenderAtOffset` (`0x63A04B`) with both debug flags zero.
Its preload loop rejects every index against count 0 (`0x63A898..0x63A89B`), before dereferencing the grid.
`GetPuzzleIndexAtOrFFFF` (`0x63A784`) likewise returns `0xFFFF` for every candidate (`0x63A7A6..0x63A7CE`).
At `0x63A2CB`, the draw loop takes the empty-index branch. With debug flags zero, it skips rectangles/text and reaches the next tile;
it never reaches the texture request/draw branch for these entries.

Thus the recovered normal path emits **no ground puzzle tile draws**. It does not synthesize a replacement.
Other component/scenery/role passes remain independently dispatched by `0x61D1F5`; the DMap includes 111 scenery placements.
The exact visible result, camera behavior at a supplied arrival position, and any later exceptional behavior require a native runtime capture.
“No ground tiles from this component” must not be restated as “the whole screen is blank” or “gameplay works.”

## 5. Loose files and registered packages

`GraphicData.dll!GraphicData_OpenPackagesFromPackageIni` (`0x1001A390`) reads whitespace tokens and calls
`TqPackagesOpen` at `0x1001A406`. The supplied file lists `data.wdf`, `c3.wdf`, `data3.wdf`.
Only the first two exist in this installation.

The exact normalized requested path hashes to UID **`0x4E85865D`**.
Complete index scans find no matching UID in `data.wdf` (14,739 entries) or `c3.wdf` (10,274 entries).
`data3.wdf` cannot contain an accessible supplied resource because the file is absent.
WDF records store hashes, not recoverable filenames; this establishes absence under the requested lookup key,
not that no unknown differently named archive payload could resemble a puzzle.

Independently, the native package resolver routes by first path segment:
`TqPackageWdf.dll` `0x10003C30` copies the first segment, `0x10003C80` hashes it,
and `0x10003CD0` finds the registered package prefix hash.
`map` hashes to `0xA070FEF8`; none of `data`, `c3`, `data3` matches it.
There is no registered `map` package in the supplied configuration.

Most decisively, **the ground `.pul` loader does not call this package resolver at all**.
Its direct CRT file open cannot be rescued merely by registering a WDF entry.
The package inventory and routing results corroborate corpus absence; they are not a fallback attempted by `0x63A603`.
Custom runtime hooks, external file virtualization, or another process CWD are not observed and are not stock resolution rules established here.

## 6. Special treatment, reachability, and remaining evidence

No 1929-specific loading or rendering branch appears in the traced catalog lookup, action-74/action-86 dispatch,
DMap loader, ground extension selector, puzzle open, or ground draw chain.
The missing-file behavior is shared with any fresh `.pul` ground whose open fails.
The minimap declaration and decorated DMap support intended client content, but do not prove deployed gameplay access or explain the omission.
The presence of `arena.pul` supplies neither a native alias nor evidence of intended equivalence.

Evidence still needed:

- **Actual server reachability:** matching 5517 server map/dynamic-instance bindings and the active login, teleport, arena,
  NPC/script, or event route that selects MapDataId 1929; or an authenticated native session packet capture showing
  action 74/86 with DWORD `+8=1929`, correlated with world-instance information. A historical 15.10 server cannot establish this.
- **Observed runtime consequence:** unmodified source-matching Windows client, recorded current directory, file-open trace
  for the attempted puzzle, logs, return-state trace, and rendered output after a legitimate entry response.
  This would establish actual transition/UI/camera behavior without altering assets or guessing a replacement.
- **Missing-file provenance:** a version-matched installation/update manifest or authentic deployment package showing whether
  `arenamap.pul` was omitted, retired, or distributed separately. None was established by this slice.
- **Global absence boundary:** bounded config/constant scans do not prove no encoded/computed client reference or external server trigger exists.

## Evidence and preservation

[Asset audit](evidence/map1929-2026-11-01/assets/asset-report.md) links exact hashes, archive listing,
all source paths, configuration inventory, full DMap validation, and scenery resource resolution.
[Native validation](evidence/map1929-2026-11-01/native-validation.json) records source identity,
instruction-byte comparisons and the CRT import binding.
[Bounded executable census](evidence/map1929-2026-11-01/constant-candidates.json) retains candidate classification.
[Annotation readback](evidence/map1929-2026-11-01/annotations.json) records five comments and the justified
`0x638B99` rename to `CMapGroundEntityLayer_Constructor`. No BNDB save was initiated.

Raw assembly/decompilation captures reside beside those records, named by native function.
Priority evidence: `CGameMap_LoadMapFileFromRelativePath.json`, `CMapGroundEntityLayer_SetGroundPuzzleBitmapPathAndLoad.json`,
`CMapGroundEntityLayer_LoadGroundPuzzleBitmapFromPath.json`, `CMapPuzzleBitmap_LoadFromPath.json`,
`CMapPuzzleBitmap_Constructor.json`, `CMapPuzzleBitmap_GetPuzzleIndexAtOrFFFF.json`,
`CMapPuzzleBitmap_RenderAtOffset.json`, and `CMsgAction__Process.json`.
