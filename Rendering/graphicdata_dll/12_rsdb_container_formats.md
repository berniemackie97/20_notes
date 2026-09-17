# `GraphicData.dll` — `RSDB` container formats (`*.dbc`)

The verified `RSDB` container formats `GraphicData.dll` loads.

## Verified loader entry points

- `GameDataSet_LoadRsdbSingleKeyIndex` (`0x1001A610`)
- `GameDataSet_LoadRsdbDualKeyIndex` (`0x1001A8F0`)

Both loaders:

1. read payload bytes from `c3.wdb` via:
   - `GameDbPack_GetEntrySizeByName`
   - `GameDbPack_ReadEntryByName`
2. require magic `RSDB` (`0x42445352`)
3. parse an index table
4. keep the trailing data blob and map each index record to a pointer in that blob

## Common header

`RSDB` payload starts with:

- `+0x00` `u32 magic` = `0x42445352` (`"RSDB"`)
- `+0x04` `u32 item_count`

## Format A: single-key index (`8 bytes / item`)

Used by `GameDataSet_LoadRsdbSingleKeyIndex`.

Per-item layout:

- `+0x00` `u32 key`
- `+0x04` `u32 data_offset`

Index byte size:

- `index_size = 8 + item_count * 8`

Validation in loader:

- reject when `index_size > payload_size` (`"Invalid Item Count: %s"`)

Data pointer mapping:

- pointer = `data_blob_base + (data_offset - index_size)`
- where `data_blob_base` is a malloc copy of payload bytes `[index_size..payload_size)`

## Format B: dual-key index (`12 bytes / item`)

Used by `GameDataSet_LoadRsdbDualKeyIndex`.

Per-item layout:

- `+0x00` `u32 key_primary`
- `+0x04` `u32 key_secondary`
- `+0x08` `u32 data_offset`

Index byte size:

- `index_size = 8 + item_count * 12`

Validation in loader:

- reject when `index_size > payload_size` (`"Invalid Item Count: %s"`)

Data pointer mapping is the same:

- pointer = `data_blob_base + (data_offset - index_size)`

## Real-data verification vectors

### Loose fixture: `ini/3DObj.dbc` (single-key)

File:

- `10_work/tests/Conquer.Tests/TestAssets/5517/ini/3DObj.dbc`

Verified values:

- magic `RSDB`
- count `2155`
- payload size `52153`
- index size `8 + 2155*8 = 17248`
- first record: key `0x00987010`, offset `17248`
- first data starts with ASCII path: `c3/effect/lifestone/stone/1.c3`

### `c3.wdb` extracted: `ini/mountmotion.dbc` (dual-key)

From fixture:

- `10_work/tests/Conquer.Tests/TestAssets/5517/ini/c3.wdb`

Verified values:

- magic `RSDB`
- count `174`
- payload size `2602`
- index size `8 + 174*12 = 2096`
- first record: `(0x2FBE4A41, 0x00000000, 2096)`
- first data path: `c3/Mount/801/101.C3`

### `c3.wdb` extracted: `ini/weaponmotion.dbc` (dual-key with non-zero secondary key)

Verified values:

- magic `RSDB`
- count `25944`
- payload size `316740`
- index size `311336`
- first record: `(0x78EFC384, 0x000000F4, 311336)`
- demonstrates active secondary-key dimension (not always zero)

## Practical parsing rule for rewrite

Do not auto-guess format from extension alone.

Use explicit format selection per call site, matching original behavior:

- single-key loader path for core object/effect/texture dbs
- dual-key loader path for motion/config-driven dbs
