# Map assets — native formats and server contract

Server side: `50_server/OpenConquerPublic/src/OpenConquer.MapAssets`.

## `ini/GameMap.dat` index

Verified in `RoleDataSingleton_LoadGameMapDatTable` (GameData.dll `0x10007678`).

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
  This is64 bytes of path storage, not an enforced cap. An in-region NUL needs length≤63.
  Confirmed from the consumer side too — `CGameMap_CreateFromDataId`
  (Conquer.exe `0x61DA1F`) does `strncpy(dest, record, 0xff)` from `+0` and reads `*(record + 0x40)`.
- `memset(buf, 0, 0x44)` per record, then `buf[pathLength] = 0`.
- **No bounds check on `pathLength`** — a long path overflows the native stack buffer.
- `componentLinkId` (4th field): 5517 client meaning not traced here. TQ server 15.10 passes it as the puzzle tile size
  (256/128) to its puzzle-border blocking (`0x4D1777`, [runtime semantics](tq-server-15.10-runtime-semantics.md)) — 5095 only.
- Insert is `UInt32ToGameMapInfoTable_FindOrInsertValueByKey` followed by `memcpy 0x44`, i.e.
  **find-or-insert then overwrite → last record wins** on a duplicate map-data ID.

### Shipped 5517 file, measured

| Property | Value |
|---|---|
| Declared records | 262 |
| Bytes consumed / file size | 8131 / 8131 (**no trailing bytes**) |
| Zero map-data IDs | 0 |
| Path length min/max | 13 / 28 (native does not enforce a cap) |
| Duplicate map-data IDs | `1067` |
| Referenced extensions | `.7z` × 262 (**nothing else**) |

The [2026-10-09 audit](map-identity-flags-native-5517.md) pins the8131-byte retail file hash,
all 262 record offsets,261 winning keys,179 effective paths and both1067 records. The later1067 record
changes both path (`qiling-z.7z`→`09Christmas02.7z`) and companion (256→128). Nine indexedkunlun
archives are absent from the supplied retail distribution. This index does not contain worldMapId
bindings or per-map flags. `0x100104EE` requires exact key equality, not nearest-key fallback.

Native auto classification `0x7715A8` searches the lowercased **whole path for substrings** `.7z`
then `.gz`; it is not strict suffix matching. Backend selection is `0x771679`,7z file open is
`0x77135E`, and signature validation is `0x771426`. All192supplied7z maps are single-file archives;
all decoded base-grid row checksums passed the new audit. Successful terrain resolution alone does
not authenticate the server's choice of terrain key.

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
| `pathLength > 0x40` | unchecked; overlaps companion storage, with larger values overflowing the stack | reject |64-byte path region; length 64 also lacks an in-region NUL |
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
