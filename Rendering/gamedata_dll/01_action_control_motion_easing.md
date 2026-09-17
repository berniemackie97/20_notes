# `GameData.dll` Action-Control Motion Easing

The native contract used by
`Conquer.exe::Role_AdvanceMotionInterpolationAndRefreshPosition` (`0x64EAB2`) to ease a role's
screen-space motion. The source is `ini/ActionCtrl.ini`; `ini/ActionDelay.ini` is a separate
wound/block/death-delay table and is not the easing source.

## Verified native surface

| Binary | Address | Name | Contract |
|---|---:|---|---|
| `GameData.dll` | `0x10005A0C` | `RoleDataSingleton_LoadActionControlIni` | Loads `ini/ActionCtrl.ini` into the signed-64-bit-key map at `RoleDataSingleton+0x84`. |
| `GameData.dll` | `0x10005C4F` | `RoleDataSingleton_LookupActionControl` | RoleDataSingleton vtable `+0x90`; performs the exact lookup and fallback sequence below. |
| `GameData.dll` | `0x100080AA` | `ActionControlRecordMap_GetOrInsert` | Returns the existing or inserted record payload at map-node `+0x18`. |
| `Conquer.exe` | `0x64EAB2` | `Role_AdvanceMotionInterpolationAndRefreshPosition` | Gets RoleView property `0x1E`, queries vtable `+0x90`, and applies the profile. |

The active `RoleDataSingleton` vtable is `GameData.dll:0x100170E8`; slot `+0x90` is the pointer at
`0x10017178`.

## Record layout

The loader copies exactly `0x48` bytes into each map value:

```c
struct RoleActionControlRecord {
    int32_t sectionCount;      // +0x00: parsed Section, then signed %= 8
    int32_t timePercent[8];    // +0x04..+0x20
    int32_t movePercent[8];    // +0x24..+0x40
    uint32_t visible;          // +0x44
};
```

For each section, the loader:

1. Parses the bracketed decimal key with `_atoi64`.
2. Parses `Section=%d` and applies signed `Section % 8`.
3. Reads paired `TimePercentN` / `MovePercentN` signed integers for `N < sectionCount`.
4. Reads `Visible=%u`.
5. Copies the complete `0x48`-byte record into the map.

Positive source counts therefore produce zero through seven active control points even though each
array reserves eight elements. A duplicate section key overwrites the existing record. The clean
5517 file contains such a duplicate.

`Visible` is stored in the record but is not read by the interpolation branch at
`Conquer.exe:0x64ED52..0x64EE54`.

## Lookup sequence

`RoleDataSingleton_LookupActionControl` treats the key as signed `int64_t`. It tests the exact key,
then mutates the candidate and tests after each of these six transformations, in order:

```text
k = k % 10_000_000 + 9_990_000_000
k = ((k / 10_000_000) % 1_000) * 10_000_000 + k % 10_000 + 9_990_000
k = (k / 10_000) * 10_000 + 9_999
k = k % 10_000 + 9_999_990_000
k = ((k / 10_000) % 1_000) * 10_000 + 9_990_009_999
k = ((k / 10_000_000) % 1_000) * 10_000_000 + 9_999_999
```

All division and remainder operations use the signed 64-bit CRT helpers. The first matching map
record is returned; a complete miss returns null. The clean data includes family fallbacks such as
`09990000340` and the generalized body/sub-action key `09999990919`.

The candidate is the same stack `int64_t` mutated between probes, not a fresh transform of the
original key. Consequently, for ordinary non-overflowing client keys, transform three forces the
low four digits to `9999`, transform four produces `9999999999`, and transforms five and six probe
that same value again. This redundancy is present in the native routine and is retained rather than
normalized away.

## Interpolation contract

The executable starts with unsigned 32-bit timing:

```text
totalDurationMs = max(totalSteps * stepDurationMs, 1)
elapsedMs = min(nowTick - motionStartTick, totalDurationMs)
elapsedPercent = min((elapsedMs * 100) / totalDurationMs, 100)
```

The multiplies are native 32-bit operations and wrap before unsigned division.

If the lookup is null or `sectionCount <= 0`, each axis uses the linear fallback:

```text
start + truncate_toward_zero(delta * elapsedMs / totalDurationMs)
```

Otherwise the eased branch:

1. Selects the first `segmentIndex` for which
   `elapsedPercent < timePercent[segmentIndex]`. Equality advances to the next segment.
2. If no such segment exists, snaps the cursor to the exact motion end.
3. Uses zero as the previous time percentage for segment zero; otherwise uses
   `timePercent[segmentIndex - 1]`.
4. Converts the previous and next time percentages to millisecond boundaries with wrapped 32-bit
   multiplication and unsigned division by 100.
5. Floors the segment duration to one using the native signed comparison.
6. Computes segment progress as
   `truncate_toward_zero(((elapsedMs - previousTimeMs) * 100.0 / segmentDurationMs) + 0.5)` and
   caps only values greater than 100.
7. Uses zero as the previous move percentage for segment zero; otherwise uses
   `movePercent[segmentIndex - 1]`.
8. Computes distance percentage with signed 32-bit integer arithmetic:
   `previousMove + ((nextMove - previousMove) * segmentProgress) / 100`.
9. Writes each cursor axis as
   `start + truncate_toward_zero(delta * distancePercent * 0.01)`.

After interpolation, a completed frame-step count also snaps the cursor to the exact end. The
routine then inverse-projects the cursor into the XTEA-protected tile pair and refreshes the
projection-relative coordinate pair.
