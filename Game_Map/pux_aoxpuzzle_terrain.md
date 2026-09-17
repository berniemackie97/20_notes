# CAoxPuzzle — `.pux` "TqTerrain" terrain puzzle format

Verified in `Conquer.exe` 2026-09-06. Translation unit proven by the assert strings:
`F:\CQ2ClientRelease-42.0.1\3DGameMap\AoxPuzzle.cpp`, header `..\3DGameMap/AoxPuzzle.h`.

## Reachability in 5517 — exhaustively checked 2026-09-06

The dispatch is **not** on `".pux"`. `CMapGroundEntityLayer_LoadGroundPuzzleBitmapFromPath`
(`0x638DBD`) runs `_splitpath` on the puzzle path and compares the extension to `".pul"` with
`_stricmp`; **anything that is not `.pul` — including an empty extension — goes to
`CAoxPuzzle_LoadFromFile`.** So the question is not whether `.pux` files ship, it is whether any
map carries a non-`.pul` puzzle path.

Path provenance is a single chain with one entry point:

    CGameMap_LoadMapFileFromRelativePath  (0x61DDC9)
      -> CMapGroundEntityLayer_SetGroundPuzzleBitmapPathAndLoad  (0x6375C4)   [only caller]
         -> CMapGroundEntityLayer_LoadGroundPuzzleBitmapFromPath (0x638DBD)   [only caller]
            -> .pul  ? CMapPuzzleBitmap_LoadFromPath
                     : CAoxPuzzle_LoadFromFile

The path is the DMap first-section field at payload offset `+0x08`, `0x104` bytes,
zero-terminated (`GameMapFileFirstCellGridSection`, and `05_dmap_positioned_overlay_system.md`).
Nothing else ever sets it.

Every shipped map was decoded at that offset:

| Source | Maps | `.pul` | non-`.pul` |
|---|---|---|---|
| `map/map/*.DMap`, loose, all three asset trees | 543 | 543 | 0 |
| `map/map/*.7z`, unpacked (192 per tree, identical) | 192 | 192 | 0 |

All paths have the form `map\puzzle\<name>.pul`. `map/puzzle/` holds 203 files, every one `.pul`
or `.Pul`. Neither WDF archive contains a `TqTerrain` or a `PUZZLE2` signature anywhere in its
bytes (`c3.wdf` 359 MB, `data.wdf` 392 MB), so no puzzle data hides in the archives either.

**Conclusion: no shipped 5517 map reaches this branch.** It is live, reachable code with no
shipped input — not dead code, and not proof the format is unused by other revisions. The
Preservation client targets 5065, an older revision whose data may well carry `TqTerrain`
terrain; that says nothing about 5517's own assets. The managed reader below therefore exists so
the branch behaves correctly if a map ever supplies such a path.

## Functions

| Address | Name | Was |
|---|---|---|
| `0x648946` | `CAoxPuzzle_LoadFromFile` | `CMapGroundEntityLayer_LoadTerrainCacheDataFromPath` |
| `0x648D12` | `CAoxPuzzle_AllocatePuzzleUnitDataGrid` | `CMapGroundEntityLayer_AllocateTerrainCacheLayerGrid` |
| `0x648DB4` | `CAoxPuzzle_LoadTextureGroups` | `CMapGroundEntityLayer_LoadDirectFrameDescriptorArrayFromTerrainCacheFile` |
| `0x649234` | `CAoxPuzzle_LoadEdgeGroups` | `CMapGroundEntityLayer_LoadTriangleCompositeDescriptorArrayFromTerrainCacheFile` |

## Wire format

| Bytes | Field |
|---|---|
| `char[16]` | signature, `strcmp` against `"TqTerrain"`; mismatch clears the return flag but parsing continues |
| `u32` | token, must be `1000` (`0x3E8`) |
| `u32` | columns → `this+0x08` |
| `u32` | rows → `this+0x0C` |
| — | texture group table (below) → vector at `this+0x34` |
| — | edge group table (same reader) → vector at `this+0x40` |
| `u32` | cell count |
| per cell | `u8` layer count, then per layer `u16 tileId`, `u32 coverageMask` |
| `u32` | edge record count |
| per record | `u32 key`, `u8[4]` |

Cell layers are appended through `sub_64AEDB`; edge records are inserted into the map at
`this+0x28` keyed by the `u32`.

`coverageMask` is a 5×5 vertex grid — 25 significant bits, `0x01FFFFFF`.

### Group record (both tables, `operator new(0x38)`)

Header: `u32` token, `u16` group count. Then per group:

| Wire | Struct offset | Field |
|---|---|---|
| `u16` len + bytes | `+0x00` | label (`std::string`) |
| `u16` len + bytes | `+0x04` | ANI path (`std::string`) |
| `u16` len + bytes | `+0x08` | ini section, `Puzzle<n>`; `n` is the tile id |
| `u32` | `+0x0C` | |
| `u32` | `+0x28` | |
| `u32` | `+0x2C` | |
| `u32` | `+0x10` | |
| `u32` | `+0x34` | |

The five dwords are read in that wire order into those scattered struct offsets.

Strings land in a `0x400` stack buffer NUL-terminated at the read length — a group string over
1023 bytes overruns it. Shipped data stays far under.

## `CAoxPuzzle` members seen

| Offset | Member |
|---|---|
| `+0x08` | columns |
| `+0x0C` | rows |
| `+0x1C` | `std::vector` of per-cell records — the loader's CHECK calls it `m_vSetPuzzleUnitData` |
| `+0x28` | edge record map, `u32` key → `u8[4]` |
| `+0x34` | texture group vector |
| `+0x40` | edge group vector |

Per-cell record is `0x14` bytes, initialised to `+0x00 = 0xFFFF` (u16 tile id, `-1` = empty),
`+0x04 = 0`, `+0x06 = 0` (byte), `+0x08 = 0xFFFFFFFF`, `+0x0D = 1` (byte), `+0x10 = 0`.
Its CHECK name is `pLayer`; the group pointer's is `pGroup`.

## Open: `CMapGroundEntityLayer_` conflates two classes

The 32 functions carrying that prefix span two translation units:

- `0x637xxx`–`0x63Axxx` asserts `TerrainLayer.cpp` → `CTerrainLayer`
- `0x648xxx`–`0x64Axxx` asserts `AoxPuzzle.cpp` → `CAoxPuzzle`

Only the four AoxPuzzle functions above are renamed. The rest still need per-function TU proof
before renaming — assert-string xrefs give it cheaply.

## Managed implementation

`10_work/src/Conquer.Assets/Map/GameMapTerrainPuzzleFile.cs`, tests in
`tests/Conquer.Tests/Assets/Map/GameMapTerrainPuzzleFileTests.cs` (synthetic tier only — no
shipped payload exists in this format to hash against).

Two native behaviours are deliberately not reproduced, both latent faults that fire only on
malformed input:
- signature mismatch: native skips its token read and keeps parsing from a misaligned offset;
- declared cell count past the allocated grid: native skips that cell's layer reads, desyncing
  the stream.

Both throw `InvalidDataException` in the managed reader. Everything else — including the absence
of any coverage-mask validation — matches the native loader exactly.

## Cross-check

`40_tools/Preservation-CO-Client-main/crates/sandbox-data/src/map/pux.rs` reads the same layout:
token 1000, the three-string + five-dword group record, and the 25-bit coverage mask. It was a
lead; the proof above is the 5517 binary. Their reader additionally rejects overlapping coverage
between layers of one cell and any trailing bytes — neither check exists in the native loader.
