# Map assets — native formats and server contract

Server side: `50_server/OpenConquerPublic/src/OpenConquer.MapAssets`.

## `ini/GameMap.dat` index

Verified in `RoleDataSingleton_LoadGameMapDatTable` (GameData.dll `0x10007680`).

```
u32 recordCount
recordCount x {
    u32 mapDataId
    u32 pathLength
    pathLength bytes   ; relative container path, ASCII, backslash or forward slash
    u32 componentLinkId
}
```

Native loader detail:

- Each record is copied into a **0x44-byte** slot: path at `+0`, `componentLinkId` at `+0x40`.
  Hence the 0x40 path cap. Confirmed from the consumer side too — `CGameMap_CreateFromDataId`
  (Conquer.exe `0x61DA2F`) does `strncpy(dest, record, 0xff)` from `+0` and reads `*(record + 0x40)`.
- `memset(buf, 0, 0x44)` per record, then `buf[pathLength] = 0`.
- **No bounds check on `pathLength`** — a long path overflows the native stack buffer.
- Insert is `UInt32ToGameMapInfoTable_FindOrInsertValueByKey` followed by `memcpy 0x44`, i.e.
  **find-or-insert then overwrite → last record wins** on a duplicate map-data ID.

### Shipped 5517 file, measured

| Property | Value |
|---|---|
| Declared records | 262 |
| Bytes consumed / file size | 8131 / 8131 (**no trailing bytes**) |
| Zero map-data IDs | 0 |
| Path length min/max | 13 / 28 (cap 0x40) |
| Duplicate map-data IDs | `1067` |
| Referenced extensions | `.7z` × 262 (**nothing else**) |

## `.DMap` base terrain

Verified in `CGameMap_LoadMapFileFromRelativePath` (Conquer.exe `0x61DC3D`).

```
u32   header field 0        ; read, unused by the grid loader
u32   header field 1        ; read, unused by the grid loader
byte  puzzlePath[0x104]     ; -> CMapGroundEntityLayer_SetGroundPuzzleBitmapPathAndLoad
u32   width
u32   height
height x {
    width x { u16 passability; u16 surfaceId; s16 elevation }
    u32 rowChecksum
}
; then exit markers, scenery subcomponents, positioned overlay records — not read by the server
```

Field order and widths are exact: `0x61DE5A` passability, `0x61DE66` surfaceId (struct base),
`0x61DE76` elevation. Elevation is sign-extended (`sx.d`); the other two are zero-extended.

Row checksum, accumulated per cell and reset per row (`0x61DE0E`), compared at `0x61DECE`:

```
acc += (surfaceId + y + 1) * passability
     + (surfaceId + x + 1) * (elevation + 2)
```

Note the asymmetry — `y` in the first term, `x` in the second. It is what the native does.

## Server contract — deliberate divergences from the client

The server is stricter than the client **by design**. Different failure semantics: the client is a
renderer where tolerating odd data costs one player a visual artefact; the server is the authority
for collision, pathing and position for everyone on the map. Loading an asset it does not fully
understand means serving world state derived from unvalidated bytes. Failing at startup, before
the listener opens, is strictly safer than starting wrong.

**No lenient mode is provided.** An option to accept unvalidated world data is the kind of switch
that gets enabled during an incident and never disabled again.

| Rule | Native | Server | Why |
|---|---|---|---|
| `pathLength > 0x40` | overflows its buffer | reject | native bug; the slot is 0x40 |
| `mapDataId == 0` | accepted | reject | zero is the server's "no map data" sentinel |
| Bytes after last record | ignored | reject | file is not the file we think it is |
| Duplicate map-data ID | last wins | **last wins** | matched deliberately; 1067 depends on it |
| Path escaping root, `:`; `.`/`..` segments | unchecked | reject | untrusted-path containment |

## Container allow-list

Only `.7z` and `.DMap` are accepted. Anything else is rejected by extension.

Previously any unrecognised extension fell through to the raw reader, so an index naming a `.zip`
would have had it parsed as an uncompressed grid.

`.7z` is opened with `SevenZipArchive`, not `ArchiveFactory` — the factory sniffs content and would
decode a ZIP/RAR/TAR named `.7z`, reaching decoders the server has no reason to expose. A 7-Zip
signature check runs before any decoder sees the stream.

Measured: all 192 `.7z` files on disk carry a genuine 7z signature; zero mismatches. No `.gz` file
exists anywhere under the asset root, so the former GZip branch was dead code and was removed.

## Resource limits

| Limit | Bounds |
|---|---|
| `MaximumCellsPerMap` | **the real decompression bound** — dimensions are rejected before allocation, and the reader then reads only what they require |
| `MaximumContainerBytes` | on-disk compressed size; file I/O only |
| `MaximumMapPayloadBytes` | archive's **declared** payload size — attacker-controlled metadata, early reject only, not a security bound |

## Startup

`GameMapAssetCatalog` loads everything before the listener starts, and is fail-closed: state moves
`Uninitialized → Loading → Ready | Failed`, never retried. `TryGet` throws unless `Ready`.
Publication uses a release/acquire pair — the frozen dictionary is written before
`Volatile.Write(state, Ready)`, and `TryGet` reads the state with `Volatile.Read` first.

Terrain is shared by map-data ID, so several world maps referencing one grid hold one copy.
