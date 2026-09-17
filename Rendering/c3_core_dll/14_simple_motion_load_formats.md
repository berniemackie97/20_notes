# `c3_core_dll.dll` — `C3SimpleMotion_LoadFromStream` (`SMOT`) payload format

The verified on-disk `SMOT` payload decode performed by
`C3SimpleMotion_LoadFromStream` (`0x10014DA0`).

Verified in BNinja (`C3_CORE_DLL.dll.bndb`) after deobfuscation and type cleanup.

## Function set and roles

- `C3SimpleMotion_Reset` (`0x10014D90`)
- `C3SimpleMotion_LoadFromStream` (`0x10014DA0`)
- `C3SimpleMotion_Unload` (`0x10014E20`)

## `C3SMotion` runtime layout

Verified field usage in this slice:

- `+0x00` `frameCount` (`uint32`)
- `+0x04` `frameMatrices` (`D3DXMATRIX*`) with `frameCount` entries
- `+0x08` `currentFrameIndex` (`uint32`) runtime frame selector

`C3SimpleMotion_Reset` zeroes all three fields.

`C3SimpleMotion_Unload`:

- frees `frameMatrices` when non-null,
- frees the struct when non-null,
- sets caller pointer to null,
- decrements `g_nSMotionCount`.

## Stream format (`SMOT` payload body)

`C3SimpleMotion_LoadFromStream` reads:

1. `uint32 frameCount`
2. `D3DXMATRIX[frameCount]` (raw 64-byte matrices)

Then increments `g_nSMotionCount` and returns success.

## Notes on native behavior

- No explicit max-frame guard was observed.
- No trailing section is parsed.
- Matrix data is copied as raw 4x4 float matrices (no conversion or normalization).

## Real-file evidence (clean 5517 client)

Verified `SMOT` chunk presence in real effect C3 files, for example:

- `00_clean/clean/5517/c3/effect/arrow/500029/1.C3`
- `00_clean/clean/5517/c3/effect/weapon/601129/4.C3`
- `00_clean/clean/5517/c3/effect/skill/meteor/1/1.C3`
