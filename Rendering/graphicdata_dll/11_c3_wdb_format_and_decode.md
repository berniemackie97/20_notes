# `GraphicData.dll` — `ini/c3.wdb` format and decode flow

The fully verified `c3.wdb` decode path used by `GraphicData.dll`.
All details below were re-verified directly in the BNinja database (no speculative parsing).

## Runtime call chain

`GameDataSet_Initialize` (`0x10003190`) performs:

1. `GameDbPack_GetSingletonState` (`0x10027D40`)
2. `GameDbPack_StateCtor` (`0x10027A80`)
3. `GameDbPack_InitializeCryptTable` (`0x10028F10`)
4. `GameDbPack_LoadAndUpdateC3Wdb` (`0x100280A0`)

So crypt-table initialization is guaranteed before `c3.wdb` descriptor hash/decrypt usage.

## File header (`16 bytes`)

`GameDbPack_LoadAndUpdateC3Wdb` reads a 16-byte header:

- `+0x00` `u32 magic` = `0x474D4442` (`"BDMG"` in little-endian)
- `+0x04` `u32 file_size`
- `+0x08` `u32 entry_table_offset`
- `+0x0C` `u32 entry_count`

Then it seeks to `entry_table_offset` and reads `entry_count` descriptors of size `0x54`.

Real fixture (`10_work/tests/Conquer.Tests/TestAssets/5517/ini/c3.wdb`):

- `magic = 0x474D4442`
- `file_size = 3,434,463`
- `entry_table_offset = 3,432,615`
- `entry_count = 22`
- invariant verified: `entry_table_offset + entry_count * 0x54 == file_size`

## Required-file table and optional DB behavior

`GameDbPack_GetEntrySizeByName` looks up by hash in the in-memory c3.wdb index.
If a name is not found, it checks a static `(file_name_ptr, required_flag)` table
(`GameDbRequiredDbFiles`, data around `0x10030360`):

- when `required_flag != 0`, logs: `Error! Can not find %s in c3.wdb`
- when `required_flag == 0`, missing entry is tolerated

Verified required entries used by loader paths in this build (`required_flag = 1`):

- `ini/3DEffect.dbc`
- `ini/3DSimpleObj.dbc`

Verified optional entries (`required_flag = 0`):

- `ini/3dscene.dbc`
- `ini/sound.dbc`
- `ini/3DObjProp.dbc`
- `ini/3DSimpleObjEx.dbc`

For this 5517 fixture, `ini/3dscene.dbc` and `ini/3DObjProp.dbc` are absent from c3.wdb,
which is consistent with this optional-flag path.

## Entry descriptor (`0x54` bytes, encrypted on disk)

For each descriptor, loader does:

1. read `0x54` bytes
2. `GameDbPack_DecryptEntryDescriptor(entry, 0x15)` (`0x15` dwords = `0x54` bytes)
3. insert into RB-tree keyed by descriptor dword 0 (`node+0x0C`)

Post-decrypt descriptor layout:

- `+0x00` `u32 file_name_hash`
- `+0x04` `u32 file_data_offset`
- `+0x08` `u32 logical_size`
- `+0x0C` `u32 stored_size` (used for actual reads)
- `+0x10` `u32 flags` (observed `0` in fixture)
- `+0x14` `char file_name[64]` (NUL-terminated path)

Verified by usage:

- `GameDbPack_GetEntrySizeByName` returns `node+0x1C` (`stored_size`)
- `GameDbPack_ReadEntryByName` seeks to `node+0x14` (`file_data_offset`) and reads `node+0x1C` bytes
- update path checks file existence with `node + 0x24` (string field)

## Crypt table generation (`GameDbPack_InitializeCryptTable`)

`GameDbCryptTable` starts at `0x10035208`, length `0x500` dwords.

Generation loop:

- seed init: `0x00100001`
- recurrence: `seed = (seed * 125 + 3) % 0x2AAAAB`
- each table value:
  - high 16 from first recurrence
  - low 16 from second recurrence
  - `value = (high << 16) | low`
- storage pattern per base index `i in [0,255]`:
  - `table[i + 0x000]`
  - `table[i + 0x100]`
  - `table[i + 0x200]`
  - `table[i + 0x300]`
  - `table[i + 0x400]`

`GameDbPack_HashFileNameCaseInsensitive` uses `table[hashType*0x100 + upper_ascii_char]`.

`GameDbPack_DecryptEntryDescriptor` / `GameDbPack_EncryptEntryDescriptor` use `table[0x400 + (seed2 & 0xFF)]`.

## Filename hash (`GameDbPack_HashFileNameCaseInsensitive`)

State init:

- `seed1 = 0x7FED7FED`
- `seed2 = 0xEEEEEEEE`

Per char:

1. `c = toupper(c)`
2. `seed1 = table[c + hashType*0x100] ^ (seed1 + seed2)`
3. `seed2 = seed2 * 33 + c + seed1 + 3`

Return `seed1`.

In `c3.wdb` lookup, `hashType = 0`.

## Descriptor decrypt (`GameDbPack_DecryptEntryDescriptor`)

State init:

- `seed2 = 0xEFFEAABB`
- `seed1 = 0xEEEEEEEE`

For each `u32 x` in descriptor:

1. `seed1 += table[0x400 + (seed2 & 0xFF)]`
2. `out = x ^ (seed1 + seed2)`
3. `seed2 = (seed2 >> 11) | (((~seed2) << 21) + 0x11111111)`
4. `seed1 = seed1 * 33 + out + 3`

Store `out` back.

`GameDbPack_EncryptEntryDescriptor` is the inverse form used when rewriting descriptors.

## Real-fixture verification (non-speculative)

Using the exact routines above against fixture `ini/c3.wdb`:

- all 22 descriptors decrypt to valid ASCII names
- all 22 descriptor ranges are in-bounds (`offset + stored_size <= file_size`)
- all 22 satisfy `GameDbPack_HashFileNameCaseInsensitive(name, 0) == file_name_hash`

Sample vectors:

- `ini/3DObj.dbc` -> hash `0x05AED9EA`, offset `16`, stored `35937`
- `ini/3DTexture.dbc` -> hash `0x42148A6E`, offset `142296`, stored `290757`
- `ini/sound.dbc` -> hash `0xFD66A6D8`, offset `433053`, stored `8`
