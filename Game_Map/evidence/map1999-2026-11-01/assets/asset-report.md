# MapDataId 1999 / IceCrypt level 3: artifact and tail-alignment evidence

Verified 2026-11-01. Source is exactly `/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517`.
No applicable `AGENTS.md` was found in this source ancestry. Source files were read only. Extraction and probes use task scratch; copies of both reproduction scripts are retained beside this note.
This subtask makes filesystem-byte observations. Native body sizes supplied by the accompanying Binary Ninja trace are applied explicitly below; an alternate alignment is labeled a hypothesis, not a new format contract.

## Identity and map selection

`ini/GameMap.dat`: 8,131 bytes; SHA-256 `0676b7d6969dd8277438704a289b1f57e8debb89fe5d3f912819c3a7880686a0`.
All 262 rows consume the table exactly. There is one row with MapDataId 1999:

| Field | Value |
|---|---|
| Row index, zero-based | 198 |
| Row byte offset | 6209 |
| MapDataId | 1999 |
| Path byte length | 24 |
| Path | `map/map/icecrypt-lev3.7z` |
| Companion component-link dword | 128 |

`map/map/icecrypt-lev3.7z` is 19,766 bytes and matches the requested SHA-256:
`8ddb39291d1a8aea31ab1c7df6be0083b35b7da43939c8a9255d98db54809cb8`.
The one archive member `icecrypt-lev3.DMap` extracts to 4,039,008 bytes, SHA-256
`08cf96b84fd0ad8a17a833d80925c8686940498d2c0fbfe68bb17095c4af9a9d`.

The separate loose `map/map/icecrypt-lev3.DMap` is 4,106,200 bytes, SHA-256
`bd3c075d818ad6de21db9a8c1363b5172da723af56bdb5104a83b41dd44b029a`.
It is not the archive payload and is not selected by this table row.

## Header, grid and exits

Both payloads contain the C-string `map\puzzle\icecrypt-lev3.pul` in the fixed field at `+0x08`.
Both grids are 820 × 820. Archive header dwords are `[1005, 0]`; loose header dwords are `[1004, 0]`.
The native trace reports that this header value is read without selecting a different record layout; the artifact alone cannot establish native version dispatch.

The standard first-grid read block ends at:

```text
276 + 820 * (820 * 6 + 4) = 4,037,956 = 0x003D9D44
```

All 820 row checksums match independently in each payload. The checks use the already documented cell-word ordering and wrapping 32-bit accumulator. They do not demonstrate equality between the two grids.

| File range | Meaning | Archive vs loose |
|---|---|---|
| `[0, 276)` | fixed header/path/dimensions | 22 differing bytes |
| `[276, 4037956)` | cells and row checksums | 2,418 differing bytes |
| `[4037956, 4038152)` | exit count and 16 triplets | identical |

There are **694 changed cells** and 128 changed row checksum values. For example, cell `(384,156)` at file offset 770,724 is `(passability,surface,elevation)=(0,0,0)` in the archive and `(1,0,300)` in the loose file. Therefore replacing the archive with the loose companion would change map data, not merely fix a version marker or record alignment.

The common exit block is:

| Offset | Bytes | Value |
|---|---:|---|
| `0x3D9D44` | 4 | count 16 |
| `0x3D9D48..0x3D9E08` | 192 | sixteen `(x,y,id)` int32 triplets |
| `0x3D9E08` | 4 | following scenery count: archive 2; loose 162 |

Every exit triplet is retained in `tail-decode-candidates.json`. Exit IDs include a repeated 8 and no 7; this is observed data, not normalization performed by the probe.

## Exact archive tail under the native 416-byte subtype-4 body

The accompanying native trace supplies these scenery **body** lengths, excluding the four-byte subtype: type 1 = 268, type 4 = 416, type 10 = 72, type 15 = 276. The archive's two entries are both read as type 4 under that sequence.

The first subtype is at `0x3D9E0C` and body starts at `0x3D9E10`:

| Field | Offset | Value |
|---|---|---|
| subtype | `0x3D9E0C` | 4 |
| path field, 260 bytes | `0x3D9E10` | `ani\mapscene02.ani` |
| section field, 128 bytes | `0x3D9F14` | `icecrypt36.tga` |
| seven int32 fields | `0x3D9F94..0x3D9FB0` | `58,372,3,6,261,492,100` |

With a 416-byte body, the second subtype lands at `0x3D9FB0`:

| Field | Offset | Native-length interpretation |
|---|---|---|
| subtype | `0x3D9FB0` | 4 |
| path field | `0x3D9FB4` | first bytes `04 00 00 00`; C-string consists of byte `0x04` |
| section field | `0x3DA0B8` | begins with NUL; empty C-string |
| seven int32 fields | `0x3DA138..0x3DA154` | `0,112,422,3,6,261,492` |
| following positioned count | `0x3DA154` | 100 |
| first positioned insert index | `0x3DA158` | 4 |
| first positioned kind | `0x3DA15C` | 0 |
| EOF | `0x3DA160` | 4,039,008 |

The next positioned pair has no source bytes. **This is not proof that the native loader rejects the file.** The parent trace reports unchecked read lengths and EOF reads that leave the destination unchanged. The bounded probe stops when bytes end; it does not model that native stale-local behavior or assert the loader's eventual return value.

The complete 1,052-byte post-grid tail is retained as address-tagged hexadecimal in `icecrypt-lev3-tail-archive.hex.txt`.

## Alternate alignment candidate: one extra dword per subtype-4 record

Adding exactly four bytes to each subtype-4 body creates the following coherent boundary fit:

| Candidate record | Subtype offset | Body size | Path / section | Seven existing dwords | Extra dword |
|---|---|---:|---|---|---|
| 0 | `0x3D9E0C` | 420 | `ani\mapscene02.ani` / `icecrypt36.tga` | `58,372,3,6,261,492,100` | 4 at `0x3D9FB0` |
| 1 | `0x3D9FB4` | 420 | same path / same section | `112,422,3,6,261,492,100` | 4 at `0x3DA158` |

That candidate places a zero positioned-record count at `0x3DA15C` and reaches EOF exactly.
Its tail accounting is `196 exit bytes + 4 scenery-count bytes + 2*(4 subtype + 420 body) + 4 positioned-count bytes = 1052`.

This establishes a possible serialized alignment, not the purpose of the extra dword, its writer, a native 1005 parser, or permission to consume it in 5517. Both raw 4 values and both competing offset interpretations are preserved. The probe does not label the extra value as color, flags, version, or depth.

## Loose companion and adjacent IceCrypt archives

All five neighboring archives have header `[1004,0]` and payloads byte-identical to their corresponding loose files.
Using the standard native body lengths, every neighbor and the loose level-3 file parses to EOF without needing extra bytes after subtype 4.

| Input | Grid | Post-grid start | Exit count | Scenery count/type | Positioned records | Exact end offset |
|---|---|---:|---:|---|---:|---:|
| level 1 archive | 688 × 688 | 2,843,092 | 2 | 325 / all 4 | 0 | 2,979,628 |
| level 2 archive | 704 × 704 | 2,976,788 | 1 | 282 / all 4 | 0 | 3,095,252 |
| level 3 loose | 820 × 820 | 4,037,956 | 16 | 162 / all 4 | 0 | 4,106,200 |
| level 4 archive | 688 × 688 | 2,843,092 | 2 | 95 / all 4 | 0 | 2,883,028 |
| level 5 archive | 740 × 740 | 3,288,836 | 43 | 55 / all 4 | 2 | 3,313,032 |
| level 6 archive | 808 × 808 | 3,920,692 | 1 | 62 / all 4 | 1 | 3,947,040 |

Level 5's positioned children reference `icecrypt-lev5bg01.pul` and `icecrypt-lev5bg02.pul`; level 6 references `icecrypt-lev6bg.pul`. These comparisons constrain the artifact anomaly; they do not provide a fallback source for map 1999.
The GameMap table maps level 1 to 1762, level 3 to 1999, level 4 to 2054, level 5 to 2055, and level 6 to 2056. No selected table row references the level-2 archive. Exact rows, every archive/member hash, section offsets, and record data are retained in the JSON evidence.

## Reproduction and remaining gaps

Run `inspect_assets.py`, then `decode_tail_candidates.py`, using Python 3 and installed `/opt/homebrew/bin/7zz`.
Both scripts pin the stated source root, write extracted payloads only under `/Users/bernie/Documents/Codex/2026-10-30/rem/work/map1999`, and write research evidence beside this report.
They do not edit source assets, production code, content manifests, or tests.

- `artifact-comparison.json`: exact selected table rows, all six archive/member identities, headers, dimensions, row-checksum results, initial tail words and archive/loose comparisons.
- `tail-decode-candidates.json`: exact exits, every scenery field/offset, both level-3 alignment interpretations, neighbor positioned records, and all 694 changed cells.
- `icecrypt-lev3-tail-archive.hex.txt`, `icecrypt-lev3-tail-loose.hex.txt`: complete post-grid tails with absolute file offsets.
- `icecrypt-lev1-listing.txt` through `icecrypt-lev6-listing.txt`: archive member inventories.
- `evidence-file-hashes.json`: evidence and reproduction-script identities.

Open beyond these byte observations: the extra dword's producing format/meaning; native behavior following unchecked EOF reads; whether malformed paths are fatal in later loading/ticking; and observed runtime rendering. The accompanying native trace must decide those code-path questions. Header 1005, byte misalignment, or a bounded parser's short-input stop alone is not sufficient to claim rejection.

Native trace and verdict: [../../../map1999_icecrypt_archive_native.md](../../../map1999_icecrypt_archive_native.md).
