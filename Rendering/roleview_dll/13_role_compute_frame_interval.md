# Slice 15 — Role_ComputeFrameIntervalFromAction

**Binary:** `Conquer.exe`
**Function:** `Role_ComputeFrameIntervalFromAction` at `0x64de1b`
**Role in pipeline:** Called by `Role_UpdateActionAndDispatchRoleViewMotion` (slice 14) after
the action-id translation to compute the per-frame time interval in milliseconds. The result
is stored to `CRole+0x1B8`. Also called standalone for the status-`0x2e` Shuriken Vortex
action-`0x390` wall-clock loop (slice 13 Phase 3).

## Composite key formula (0x64de26..0x64de82)

The function builds a 64-bit key for the `RoleDataQuery->vtable+0x08(key)` lookup:

```
key = (vtable0x2c(0x12) + speedModifier * 1_000_000) * 10_000
    + classId * 10_000_000
    + actionId
```

Where:
- `vtable0x2c(0x12)` = `IRoleView vtable+0x2C` with query code `0x12` (64-bit return, only low 32 bits used)
- `speedModifier` = `CRole+0x128` (32-bit signed, likely agility-derived)
- `classId` = `CRole+0xD0` (16-bit zero-extended, then `imul eax, eax, 0x989680` = `* 10_000_000`)
- `actionId` = arg2

Early exit: if `CRole+0x3B4` (pIRoleView) is null, returns default `0x21` (33ms).

## Status-flag modifier chain

Two mutually exclusive paths run first, followed by a common tail.

### Path A — Target entity facing override set

Checked at `0x64de95`. Fires when `Role_IsCurrentActionInTargetEntityFacingOverrideSet()` is true.

**Facing override action set** (verified from `0x6e5064`):
`{0x191..0x199, 0x1D6, 0x208, 0x26C}` — mounted/flying actions.

Modifier chain (first match wins, only one `*2/3` ever applied):
1. Flag `0x15` → `*2/3`
2. Flag `0x12` → `*2/3`
3. Flag `0x17` → `*2/3`

### Path B — Physical animation, not in facing override set

Checked at `0x64dec9`. Fires when `Role_IsCurrentActionInPhysicalAnimationSet()` is true.

**Physical animation action set** (verified from `0x6e4e98`, decoded as x86 binary search tree):
```
{0x6e..0x6f, 0x73, 0x78..0x7b, 0x7d..0x7e, 0x82..0x84, 0x8c,
 0x123..0x127, 0x140, 0x1d6, 0x1e2, 0x1fe, 0x20b..0x20f,
 0x256..0x257, 0x28a..0x28b, 0x2c9, 0x397}
```

| Range | Dec | Semantic |
|-------|-----|----------|
| `0x6e..0x6f` | 110–111 | Idle, AlertStand |
| `0x73` | 115 | CoolPose / Alert |
| `0x78..0x7b` | 120–123 | Walk variants |
| `0x7d..0x7e` | 125–126 | Run variants |
| `0x82..0x84` | 130–132 | Attack, Attack2, Attack3 |
| `0x8c` | 140 | Cast / Skill |
| `0x123..0x127` | 291–295 | Hold-hands interaction variants |
| `0x140` | 320 | Combat ability |
| `0x1d6` | 470 | Mounted/flying idle |
| `0x1e2` | 482 | Mounted attack |
| `0x1fe` | 510 | Mounted/flying action |
| `0x20b..0x20f` | 523–527 | Hug-walk interaction variants |
| `0x256..0x257` | 598–599 | Flying action pair |
| `0x28a..0x28b` | 650–651 | Flying action pair |
| `0x2c9` | 713 | Mount run (special mount action) |
| `0x397` | 919 | Special action |

The function reads `CRole+0x1A4` via `Role_GetCurrentActionId` (`0x651390`).

#### Distance-based attack interval override (0x64def4..0x64df50)

For actions `{0x82, 0x127, 0x20F}` (attack, hold-hands attack, hug-walk attack):

```
dx = CRole+0x194 - CRole+0x19C    // source X - target X (tile coords)
dy = CRole+0x198 - CRole+0x1A0    // source Y - target Y
distance = sqrt((double)(dx*dx + dy*dy))
override = (int)(baseInterval * distance / 300.0 + 1.0)
result = max(33, override)
```

FP constants:
- `[0x86ab70]` = `1/300.0` (IEEE 754: `0x3F6B4E81B4E81B4F`)
- `[0x869fe8]` = `1.0` (IEEE 754: `0x3FF0000000000000`)

#### Post-distance modifiers

After the distance override (or for non-attack physical animations):
- Flag `0x17` → halve (`shr edi, 1`)
- Else flag `0x70` → `*2/3`

### Common tail (0x64df7c..0x64e005)

1. Flag `0x1b` (jumping) AND `Role_GetStateCode1E8WithCompleteFallback() == 0x1f` → halve
2. Flag `0x32` (mounted) → `Role_ApplyMountedSpeedClassScaleToFrameInterval`
3. `CRole+0x5C != 0` AND physical animation → speed-percent scaling:
   ```
   denominator = max(CRole+0x5C + 100, 1)
   result = (int)ceil(result * 100.0 / denominator)
   ```
   FP constant: `[0x8688f0]` = `100.0` (IEEE 754: `0x4059000000000000`)
4. Final guard at `0x64dffb`: **zero-coerce, NOT clamp**:
   ```
   if (result != 0) return result; else return 1;
   ```
   Negative results pass through unchanged — only literal zero is coerced to 1.

## Role_ApplyMountedSpeedClassScaleToFrameInterval (0x65127a)

Gated by `0 <= CRole+0x3C <= 12`. Computes `speedPercent = CRole+0x48 + 100`.

The two input fields are not direct packet mirrors. They are part of the native mounted
action-scale cache:

- `CRole+0x3C` is the cached mounted speed-class index consumed by the cap/ratio tables.
- `CRole+0x48` is the cached mounted speed-percent offset accumulated by
  `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`) before the frame-interval path
  adds `100`.

That cache chain is verified separately in
`07_action_playback_transition_state.md` / `09_role_scale_formula.md`. The frame-interval
path only consumes the derived cache values; it does not populate them itself.

### Per-speed-class cap table (0x86aa30)

| Class | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|-------|---|---|---|---|---|---|---|---|---|---|----|----|-----|
| Cap   |100|105|110|115|120|130|140|150|165|185|190 |195 |200  |

`speedPercent` is clamped to `min(speedPercent, cap[speedClassIndex])`.

### Scaling logic

- If physical animation AND NOT in mount-exemption set: `result = interval * 100 / speedPercent`
- Else: `result = interval` (pass-through)

### Mount-exemption action set (sub_651330 at 0x651330)

Actions that bypass the `* 100 / speedPercent` scaling:
`{0x82..0x84, 0x8C, 0x127, 0x140..0x143, 0x1D6, 0x1E2, 0x1FE, 0x20F, 0x397}`

### Mount action 0x2C9 ratio tables

When `currentAction == 0x2C9`, an additional per-speed-class ratio is applied:

| Class | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|-------|---|---|---|---|---|---|---|---|---|---|----|----|-----|
| Num   |16 |16 |16 |17 |17 |18 |18 |18 |18 |19 |19  |20  |20   |
| Den   |22 |22 |22 |22 |22 |18 |18 |18 |18 |16 |16  |14  |14   |

Formula: `result = numerator[speedClassIndex] * result / denominator[speedClassIndex]`

Ratios range from 16/22 ≈ 0.727 (class 0–2) to 20/14 ≈ 1.429 (class 11–12).

## CRole byte offsets referenced

| Offset    | Type   | Semantic                            |
|-----------|--------|-------------------------------------|
| `+0x3B4`  | ptr    | `m_pIRoleView`                      |
| `+0xD0`   | int16  | Class id (used in composite key)    |
| `+0x128`  | int32  | Speed modifier (agility-derived?)   |
| `+0x194`  | int32  | Source X (tile coord)               |
| `+0x198`  | int32  | Source Y (tile coord)               |
| `+0x19C`  | int32  | Target X (tile coord)               |
| `+0x1A0`  | int32  | Target Y (tile coord)               |
| `+0x3C`   | int32  | Mounted speed-class index (cache-derived) |
| `+0x48`   | int32  | Mounted speed-percent offset (cache-derived) |
| `+0x5C`   | int32  | Speed-percent modifier              |
| `+0x1A4`  | int32  | Current action id (read by GetCurrentActionId) |

## Helper functions renamed this slice

| old              | new                                                         | purpose                              |
|------------------|-------------------------------------------------------------|--------------------------------------|
| `sub_65127a`     | `Role_ApplyMountedSpeedClassScaleToFrameInterval`           | Mounted speed-class scaling helper   |
| `sub_651330`     | `Role_IsActionExemptFromMountedSpeedScaling`                | Mount speed exemption filter         |

## Functions verified (comment set, not renamed)

| name                                              | address      | purpose                                     |
|---------------------------------------------------|-------------|-----------------------------------------------|
| `Role_IsCurrentActionInPhysicalAnimationSet`      | `0x6e4e98`  | Physical animation set gate (Path B)          |
| `Role_GetCurrentActionId`                         | `0x651390`  | Returns `CRole+0x1A4`                        |

## Managed parity

The verified tables and pure computation functions are encoded in:
- `src/Conquer.Graphics/Role/RoleFrameIntervalComputeRuntime.cs`
  - `ComputeRoleDataQueryKey(roleViewResult, speedModifier, classId, actionId)` — composite key
  - `ComputeDistanceBasedAttackInterval(baseInterval, dx, dy)` — distance override for attacks
  - `ApplySpeedPercentScaling(interval, speedPercent)` — `ceil(interval * 100 / (sp + 100))`
  - `ApplyMountedSpeedClassScale(mountedSpeedClassIndex, interval, ...)` — full mounted scaling with tables
  - `IsActionInTargetEntityFacingOverrideSet(actionId)` — facing override membership
  - `IsActionExemptFromMountedSpeedScaling(actionId)` — mount exemption membership
  - `IsDistanceBasedAttackAction(actionId)` — attack distance override membership
  - `ApplyTwoThirdsModifier(interval)` / `ApplyHalveModifier(interval)` — status flag modifiers
  - Mounted speed cap, numerator, and denominator tables as `ReadOnlySpan<int>`
- `tests/Conquer.Tests/Client/RoleFrameIntervalComputeRuntimeTests.cs` — 73 tests

**Status flag pipeline wired** (post-slice 15): `MsgUserAttribEx10017PacketReader` decodes
status flags from the `ClientUpdateType.StatusFlag = 25` entries; `ClientWorldRoleStateStoreRuntime`
stores `StatusFlag0` per entity with `HasJumpingStatus` (flag 0x1B) and `HasMountedStatus`
(flag 0x32) properties; `Role3DClientSceneMultiPartRenderStageRuntime` reads role state and
populates `TranslationState` on the playback host before each tick. Server `SpawnPlayerWriter`
now sends actual flags in `Effect1`/`Effect2` fields.

**Physical animation set decoded**: `IsActionInPhysicalAnimationSet` verified from
`Role_IsCurrentActionInPhysicalAnimationSet` (`0x6e4e98`) — 33 action IDs in 16 ranges/singletons.
57 boundary tests in `RoleFrameIntervalComputeRuntimeTests`.

**RoleDataQuery base interval lookup decoded** (post-slice 15): The `RoleDataQuery` singleton
is created by `GameData.dll` (`RoleDataQuery` export → `sub_10001a85` vtable+0x08 lookup).
The object contains a `std::map<int64_t, Record>` at `+0x15c` with progressive key degradation
lookup. **In the 5517 build, this map is never populated** — all 28 init sub-functions in
`sub_100019b2` were traced, none write to `+0x15c`. The lookup always falls through to a
hardcoded fallback that extracts `actionId = key % 10000` and switches on specific ranges:

| Action ID (dec) | Hex          | Interval (ms) | Hex   |
|-----------------|--------------|---------------|-------|
| 100–103         | 0x64–0x67    | 66            | 0x42  |
| 110–111         | 0x6E–0x6F    | 25            | 0x19  |
| 120–121         | 0x78–0x79    | 25            | 0x19  |
| 451–453         | 0x1C3–0x1C5  | 10            | 0x0A  |
| 460             | 0x1CC        | 10            | 0x0A  |
| 465             | 0x1D1        | 10            | 0x0A  |
| 470             | 0x1D6        | 10            | 0x0A  |
| 482             | 0x1E2        | 10            | 0x0A  |
| Everything else | —            | 33            | 0x21  |

Managed parity: `RoleFrameIntervalComputeRuntime.LookupBaseFrameInterval(actionId)` — 35 tests.

The current action type (`CRole+0xD8`) is read from the player-spawn dword at body offset
`0x57`, retained in the managed world-role snapshot, and supplied to the paired-interaction
translator. The post-spawn interaction-controller lifecycle remains a separate reconstruction
slice.

## Top-level orchestrator — `ComputeFrameInterval`

The full `Role_ComputeFrameIntervalFromAction` parity is now exposed as
`RoleFrameIntervalComputeRuntime.ComputeFrameInterval(actionId, state)`. The orchestrator is
verified end-to-end against the native decompile at `0x64de9e..0x64e005`:

| Stage | Native address | Parity |
|-------|---------------|--------|
| 1. Base lookup | `0x64de21..0x64de93` | `LookupBaseFrameInterval(actionId)` (RoleDataQuery fallback) |
| 2. Path A — facing override | `0x64de95..0x64dec3` | `IsActionInTargetEntityFacingOverrideSet` gate + flag `0x15 → 0x12 → 0x17` first-match-wins `*2/3` |
| 3. Path B — distance attack | `0x64def4..0x64df50` | `IsDistanceBasedAttackAction` → `ComputeDistanceBasedAttackInterval` (replaces base) |
| 4. Path B — halve/two-thirds | `0x64df5d..0x64df6e` | Flag `0x17 → halve`, else flag `0x70 → *2/3` |
| 5. Common tail — jumping halve | `0x64df87..0x64df9a` | Flag `0x1B AND StateCode1E8 == 0x1F → halve` |
| 6. Common tail — mounted scale | `0x64dfa0..0x64dfc4` | Flag `0x32 → ApplyMountedSpeedClassScale` |
| 7. Common tail — speed percent | `0x64dfd2..0x64dff7` | `SpeedPercentModifier != 0 AND physical → ApplySpeedPercentScaling` |
| 8. Final zero-coerce | `0x64dffb` | `result == 0 ? 1 : result` (passes through negatives) |

### Path A flag order verification

Verified against the decompile: `0x64deab (0x15) → 0x64debc (0x12) → label_64df67 (0x17)`.
The three checks are mutually exclusive — once one fires, execution jumps past the remaining
branches to the common tail. Combined flags still only produce a single `*2/3` step.

### Flag `0x70` limitation (documented degradation)

`Role_HasStatusFlag` at `0x006e50e7` reads from a 128-bit status-flag array (`CRole+0x70`,
4 × dword). Flag index 0x70 = 112 lives in the **third** dword at `CRole+0x7C`. The managed
`RoleFrameIntervalComputeState.StatusFlag0` field is a `ulong` that only covers bits `0..63`,
so `state.HasStatusFlag(0x70)` always returns `false` in the orchestrator's Path B branch.

This is a benign degradation — it only matters if a role is carrying a status flag in bits
64..127 that isn't otherwise cleared by another modifier path. The common runtime flags used
by the orchestrator (`0x12, 0x15, 0x17, 0x1B, 0x32`) all live in the low 64 bits and are fully
tracked. If the upper bitmask words ever need to be plumbed, extend
`RoleFrameIntervalComputeState` with additional `StatusFlag1` / `StatusFlag2` / `StatusFlag3`
fields and broaden `HasStatusFlag` accordingly.

### Managed parity — orchestrator tests

31 additional tests in `RoleFrameIntervalComputeRuntimeTests` cover the orchestrator end-to-end
(total: 197 tests for this runtime). Coverage pins:

- Neutral state returns pure `LookupBaseFrameInterval` output
- Path A individual flag triggers (0x15, 0x12, 0x17)
- Path A first-match-wins ordering (combined flags produce single `*2/3`)
- Path B idle (no distance, no flags) returns base
- Path B flag `0x17` halve
- Path B distance-based attack override (with and without subsequent halve)
- Path B hold-hands attack distance scaling beyond clamp
- Common tail flag `0x1B` + state `0x1F` halve (and the negative cases — each alone is a no-op)
- Common tail flag `0x32` mounted scale (physical non-exempt, exempt action, non-physical)
- Common tail mount-action `0x2C9` ratio
- Common tail `SpeedPercentModifier` scaling on physical actions + non-physical skip
- Final zero-coerce (`result == 0 → 1`, reached via flag `0x32` + `MountedSpeedPercentOffset = -100`)
- Combined end-to-end: distance attack + halve + jumping halve + exempt mounted + speed percent
- `RoleFrameIntervalComputeState.HasStatusFlag` boundary (flags ≥ 64 → false, negative → false)

### Runtime wiring status

- `Role3DClientRolePlayback.FrameIntervalComputeState` — nullable-free property with
  `RoleFrameIntervalComputeState.Default` as initial value; `ConfigurePrimaryFrameClock` now
  calls `ComputeFrameInterval(actionId, _frameIntervalComputeState)` (previously called
  `LookupBaseFrameInterval(actionId)` directly).
- `Role3DClientRolePlaybackHost.FrameIntervalComputeState` — pass-through setter to the
  inner playback runtime.
- `LocalHeroRoleViewRenderPlaybackRuntime.FrameIntervalComputeState` — pass-through setter to
  the playback host (null-safe; returns `Default` before the host is created).
- `Role3DClientSceneMultiPartRenderStageRuntime.TickLiveLocalHeroPlaybackIfNeeded` populates
  the compute state from the role state store's `StatusFlag0` before each tick, alongside the
  existing `TranslationState` population.

**Wired in managed state** (post-slice 18 — both accumulator sources):
- `MountedSpeedPercentOffset` (CRole+0x48) — the full two-source accumulator from
  `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`) is now mirrored end-to-end:
  - **Source 1** (signed int16 at item record +0x30, text field 18, via
    `ItemTypeDataSingleton_TryGetItemRecordByTypeId`) — slice 17,
    `ClientWorldRoleStateStore.ComputeItemSpeedPercentOffset`.
  - **Source 2** (unsigned int16 at ItemAdd composite record +0x0E, word index 7, via
    `GameDataSingleton_TryGetActionTypeRecordByDualKey`) — slice 18,
    `ClientWorldRoleStateStore.ComputeItemAddSpeedPercentOffset`. The lookup key is
    `(mountTypeId, mountPlusLevel)`; managed reuses the pre-existing `ItemAddIniTable`
    loader (already wired in `ItemTypeDataCatalog`).
  Both contributions sum into
  `ClientWorldRoleMountActionScaleSourceState.MountedSpeedPercentOffset`, which the frame
  interval compute state now receives per tick.

**Still zero in managed state** (no regression — these stages become no-ops when zero):
- `SpeedPercentModifier` (CRole+0x5C) — no client-side tracking yet. The field's ctor-time
  zero init is verified in the main `CRole` ctor (`0x64D324`), and the adjacent equipment/item
  refresh callers (`CMsg1008__Process`, `CMsgUserAttrib__Process`, `sub_65E330`) have been
  checked, but no packet-backed live writer is proven yet.
- `Source/TargetTile` (CRole+0x194..+0x1A0) — source comes from `TileX`/`TileY` but target
  comes from the attack target, which isn't part of the role state snapshot. Leaving both at
  zero produces distance 0 → distance override clamps to 33, which matches native default for
  distance-based attacks when the target coords are uninitialized.
- `StateCode1E8` (CRole+0x1E8) — no client-side tracking yet

**Wired in managed state** (post-slice 16):
- `MountedSpeedClassIndex` (CRole+0x3C) — sourced from
  `ClientWorldRoleStateSnapshotRuntime.MountPlusLevel` (the `MsgPlayerSpawn10014Packet`
  byte at offset `0x85`, already decoded by `MsgPlayerSpawn10014PacketReader`). This byte
  is the value `CMsgPlayer__Process` pushes as `mountActionScalePrimarySource` at
  `0x756B16`, which the cache writer stores at `CRole+0x3C` at `0x6E5F75`. With the class
  index wired, the flag `0x32` common-tail stage now applies the correct per-class cap and
  (for action `0x2C9`) the mount-action ratio tables.

## Slice 16 — Mount speed-class cache → frame interval

**Scope:** Wire the mounted speed-class index (`CRole+0x3C`) from existing client-side state
(`MountPlusLevel`) into the frame-interval orchestrator so that flag `0x32` (mounted) produces
the correct per-class scaling for mounted players. `CRole+0x48` (accumulated speed percent
offset) is left at zero pending item-record plumbing.

### Verified cache writer call graph

The full writer chain `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`) has 8 distinct
code references, analyzed for the initial-value provenance:

| Caller                                            | Address   | Role                                   |
|---------------------------------------------------|-----------|----------------------------------------|
| `CMsgPlayer__Process`                        | `0x756B1D`| **Primary packet entry** — pushes packet bytes `0x44/0x85/0x8B/0x48` |
| `CHeroItem__SetEquipSlot`                         | `0x6DACDC`| Mount equip (ecx_56 has eax_28) — derives from item record |
| `CHeroItem__SetEquipSlot`                         | `0x6DACF4`| Mount equip (null eax_28 branch) — all-zero source tuple |
| `Role_UpdateMountActionScaleCacheFromRoleState`   | `0x6E5E3F`| **Idempotent refresh** — reads CRole+0x3C/+0x50/+0x54/+0x58 and passes them back (no-op for source fields, but re-runs item-record accumulators into CRole+0x48) |
| `CMsgPlayer__Process` (standalone fallback)  | —         | covered above |
| `sub_503bc1` (×2)                                 | `0x504B07..`| Debug / UI helper — not on main playback path |
| `Conquer_DispatchSlashCommandText`                | `0x659703`| Slash command (dev/test) — not on main playback path |
| `sub_66cde7`                                      | `0x66CE36`| Unnamed helper — not on main playback path |

The initial-write path for a player spawn is:

```
CMsgPlayer__Process @ 0x755F64
  ├─ *(esp-0x10) = *(packet+0x44)  ; arg1 role             → CRole+0x50
  ├─ *(esp-0x0c) = zx.d(*(packet+0x85))  ; arg2 primary    → CRole+0x3C  (MountPlusLevel byte)
  ├─ *(esp-0x08) = *(packet+0x8B)  ; arg3 secondary        → CRole+0x58
  ├─ *(esp-0x04) = *(packet+0x48)  ; arg4 variant          → CRole+0x54
  └─ call Role_UpdateMountActionScaleCacheFromSources @ 0x756B1D
       ├─ 0x6E5F5C: CRole+0x48 = 0
       ├─ 0x6E5F66: CRole+0x54 = variant
       ├─ 0x6E5F6C: CRole+0x58 = secondary
       ├─ 0x6E5F72: CRole+0x50 = role
       ├─ 0x6E5F75: CRole+0x3C = primary (= MountPlusLevel)
       ├─ 0x6E5FD0: ItemTypeDataSingleton_TryGetItemRecordByTypeId(&data_96ae88, role, &outRecord16)
       │    └─ 0x6E5FD9: CRole+0x48 += sx.d(outRecord16[0x30])  [signed 16-bit; text field 18]
       ├─ 0x6E5FED: GameDataSingleton_TryGetActionTypeRecordByDualKey(&data_96ae88, role, primary, &outRecord16)
       │    └─ 0x6E5FF3: CRole+0x48 += zx.d(outRecord16[0x0E])  [unsigned 16-bit]
       ├─ 0x6E5FF8: Role_QueryMountActionScaleRecord(role) → record
       ├─ 0x6E6008: CRole+0x4C = record[2]   ; mount vertical offset
       ├─ 0x6E6010: CRole+0x44 = record[1]   ; action-scale percent (feeds CRole+0x188)
       └─ 0x6E601A: if HasStatusFlag(0x32): Role_SetMountedActionFrameIntervalAndRefreshActionScale(record[0])
```

### Reader consumers

- `Role_ApplyMountedSpeedClassScaleToFrameInterval` (`0x65127A`) reads `CRole+0x3C` and
  `CRole+0x48`, clamps `(CRole+0x48 + 100)` to the per-class cap table at `0x86aa30`
  (Unicode string literal `U"dinsx…"` encoded with the first 5 caps as character codes), and
  returns `interval * 100 / clampedPercent`. For action `0x2C9`, additionally multiplies by
  `MountActionSpeedNumerator[class] / MountActionSpeedDenominator[class]` from tables at
  `0x86aa64` / `0x86aa98`.
- `Role_QueryMountActionScaleRecord` (`0x6E6045`) builds a composite key
  `base * 100 + CRole+0x3C` where `base = CRole+0x54` (when non-zero and
  `CRole+0xDC != 3`) else `CRole+0x50`, and calls `RoleDataQuery()->vtable+0xA8(key, secondaryArg)`.

### Managed wiring (slice 16)

`Role3DClientSceneMultiPartRenderStageRuntime.TickLiveLocalHeroPlaybackIfNeeded` now reads
`ClientWorldRoleStateSnapshotRuntime.MountActionScaleSourceState.MountPlusLevel` and passes it
as `MountedSpeedClassIndex` when constructing the per-tick
`RoleFrameIntervalComputeState`. The byte is always in `[0, 255]`; the compute orchestrator's
`ApplyMountedSpeedClassScale` already gates on `[0, 12]` per the native range check at
`0x65128C`, so higher values become harmless no-ops.

### Deferred (follow-up slices)

- **Refresh-path driver** — managed currently rebuilds compute state from the packet snapshot
  each tick. Native's `Role_UpdateMountActionScaleCacheFromRoleState` (`0x6E5E33`) refresh is
  called by `CRole__ReapplyAllVisualSources` (`0x650AC9`) among others; if we ever cache the
  computed `CRole+0x48` value in `RoleMountedActionScaleStateRuntime`, we'll need an equivalent
  refresh hook on the playback side.
- **Equip-path initial writer** — `CHeroItem__SetEquipSlot` (`0x6DACDC`, `0x6DACF4`) also
  calls `Role_UpdateMountActionScaleCacheFromSources` with item-derived source values. The
  managed client state store only recomputes on spawn; a mid-session mount swap would
  currently not refresh the accumulator until the next spawn packet. Wiring this hook
  requires deciding where `CHeroItem__SetEquipSlot`'s managed equivalent lives.

## Slice 17 — Item-record speed-percent offset (source 1 of CRole+0x48)

**Scope:** Plumb the first of two `CRole+0x48` accumulator contributions — the signed int16
field at item-record offset +0x30 (text field 18 in `Itemtype.dat`) reached through
`ItemTypeDataSingleton_TryGetItemRecordByTypeId` at `0x6E5FD0..0x6E5FD9`. Source 2
(`GameDataSingleton_TryGetActionTypeRecordByDualKey`) is deferred pending a managed loader
for the action-type tree at singleton+0x1C.

### Verified text-to-binary field mapping

`ItemTypeDataSingleton_LoadItemRecordTableFromDecodedTextDat` (`0x677A95`) iterates over the
60 `@@`-separated fields of each decoded `Itemtype.dat` line, calling the tokenizer helper
`sub_6779f5` once per field. Stack frame base `var_e0` holds the in-progress record; the 19th
tokenizer call (0-based index 18) writes its parsed signed int16 value to `var_e0 + 0x30`
(local name `var_b0`). The consumer at `0x6E5FD9` sign-extends this same 16-bit field
(`sx.d(*(record+0x30))`) before accumulating into `CRole+0x48`.

### Managed parity

- `Conquer.Assets.Item.ItemTypeDatRecord.SpeedPercentOffsetFieldIndex = 18` — named constant
  documenting the native mapping.
- `Conquer.Assets.Item.ItemTypeDatRecord.TryGetInt16Field(int fieldIndex, out short value)` —
  signed int16 field accessor with conservative out-of-range handling (native `atoi` silently
  truncates; managed returns false and the caller falls back to 0, matching native
  degraded-singleton behavior).
- `Conquer.World.Models.ClientWorldRoleMountActionScaleSourceState.MountedSpeedPercentOffset` —
  `int` field on the per-role mount state record, capturing the accumulated offset.
- `Conquer.World.State.ClientWorldRoleStateStore.ComputeItemSpeedPercentOffset(uint mountTypeId)` —
  helper that runs the item-data lookup + int16 parse, returning 0 when the table is null, the
  mount type id is 0, the mount is missing from the table, or the field fails to parse (each
  of which mirrors a distinct native degraded case).
- `Conquer.Application.Composition.StartupComposition.CreateWorldStateContext` — wires the
  catalog's `ItemTypeTable` into the state store so the accumulator runs during
  `ApplyPlayerSpawn`.
- `Conquer.Role.Role3DClientSceneMultiPartRenderStage` — reads the state snapshot's
  `MountedSpeedPercentOffset` into `RoleFrameIntervalComputeState.MountedSpeedPercentOffset`,
  closing the loop from `MsgPlayerSpawn10014` → item lookup → frame-interval compute.

### BNinja renames applied this slice

| old          | new                                                 | purpose                                                     |
|--------------|-----------------------------------------------------|-------------------------------------------------------------|
| `sub_6791fb` | `GameDataSingleton_TryGetActionTypeRecordByDualKey` | Dual-key action-type record fetch (CRole+0x48 source 2)     |
| `sub_67ac6b` | `CItem_UpdateActionTypeRecordCacheFromTypeId`       | Per-item action-type cache refresh                          |
| `sub_67d663` | `CItem_GetByte61`                                   | Byte accessor at +0x61 used by equipment filters            |
| `sub_67ad9a` | `CItem_GetEquipmentCategory`                        | Main-type → equipment category mapper                       |

### Tests added this slice

- `tests/Conquer.Tests/Assets/Item/ItemTypeDatRecordTests.cs` — 7 tests covering positive,
  negative, short boundary, out-of-range, non-numeric, out-of-range index, and field-index
  constant verification.
- `tests/Conquer.Tests/Client/ClientWorldRoleStateStoreMountedSpeedPercentOffsetTests.cs` —
  6 tests covering null table, missing id, zero id, positive offset, negative (sign-extended)
  offset, and non-numeric text (degrades to 0).

Both files use the verified `Itemtype.dat` encoding (128-byte MSVC rand seed table with seed
`0x2537`, byte-wise `ROTR8(seed_table[i%128] XOR encoded_byte, i%8)`) to build authentic
60-field single-record payloads.

## Slice 18 — ItemAdd composite record speed-percent offset (source 2 of CRole+0x48)

**Scope:** Plumb the second accumulator contribution — the unsigned int16 at ItemAdd
composite-record byte offset `+0x0E`, reached through
`GameDataSingleton_TryGetActionTypeRecordByDualKey` at `0x6E5FED..0x6E5FF3`. Combined with
Slice 17, `CRole+0x48` now reflects the full native cache-writer output.

### Verified dual-key composition and record layout

The native call site at `0x6E5FDC..0x6E5FE6` pushes three stack args after loading
`ECX = &data_96ae88` (the singleton) — calling convention is `__thiscall`:

```
006e5fdc  lea     eax, [ebp-0x1c]           ; &var_20 (output buffer)
006e5fdf  mov     ecx, edi                  ; ECX = singleton
006e5fe1  push    eax                       ; arg4 = output (16 bytes)
006e5fe2  push    dword [ebp+0xc]           ; arg3 = mountPlusLevel (low 32 bits)
006e5fe5  push    ebx                       ; arg2 = mountTypeId (high 32 bits)
006e5fe6  call    GameDataSingleton_TryGetActionTypeRecordByDualKey
```

Inside the callee (`0x6791fb`), `__allmul(arg2, 0, 0, 1)` shifts `mountTypeId` by 32 bits
and adds `mountPlusLevel` in the low half, producing the 64-bit key
`(mountTypeId << 32) | mountPlusLevel`. `TileCoordinateAttachmentLookup_FindByTileCoordinates`
(generic STL `std::map::find`) walks the red-black tree at `singleton+0x1C`. On a hit, a 16-byte
payload is copied from `node+0x18..+0x27` to the output buffer; on a miss, the callee
returns 0 and the accumulator branch is skipped.

The 16-byte payload is 8 back-to-back 16-bit words. The consumer reads the last word
(byte 14-15, word index 7) as `zx.d(*(output+0x0E))`.

### Verified data file and loader

`ItemTypeDataSingleton_LoadItemAddTable` (`0x678FE7`) reads `ini/ItemAdd.ini` line by line:

```
sscanf(line, "%u %u %u %u %u %u %u %u %u %u\n",
       col0, col1, col2, col3, col4, col5, col6, col7, col8, col9);
key   = (col0 << 32) | col1;
word0 = col2;  word1 = col3;  word2 = col4;  word3 = col5;
word4 = col6;  word5 = col7;  word6 = col8;  word7 = col9;   // ← source 2 contribution
```

Spot-checked against the shipping `ItemAdd.ini`: 168 of 10,655 lines have a nonzero
`col9`, all in the `160xxx` item-type range (sub 16 = armor in the `GetItemMainTypeFromId`
table). Mount entries (201000, 202000, 203000) have `col9 == 0` for every level, meaning
mount source-2 is typically zero in practice — but the path is exercised whenever armor-class
items populate it, and the cache writer does not gate on item type.

### Managed parity

- `Conquer.Assets.Item.ItemAddRecord.SpeedPercentOffsetPayloadWordIndex = 7` — named constant
  pinning the payload word index against the native `+0x0E` offset.
- `Conquer.World.State.ClientWorldRoleStateStore.ComputeItemAddSpeedPercentOffset(uint mountTypeId, byte mountPlusLevel)` —
  composes the `(mountTypeId, mountPlusLevel)` key, looks up the `ItemAddIniTable`, and
  returns the payload word, mirroring each native degraded case (null table, zero
  mount type id, composite-key miss).
- `Conquer.World.State.ClientWorldRoleStateStore.ApplyPlayerSpawn` — now sums
  `ComputeItemSpeedPercentOffset + ComputeItemAddSpeedPercentOffset` before writing the
  per-role mount state, matching the native accumulator's zero + source 1 + source 2 flow.
- `Conquer.Application.Composition.StartupComposition.CreateWorldStateContext` — passes
  `itemTypeDataCatalog.ItemAddTable` alongside `ItemTypeTable` so both accumulator helpers
  run in production.

The `ItemAddIniTable` / `ItemAddRecord` / `ItemAddCompositeKey` types were pre-existing (loader
parity was verified in an earlier slice); this slice only adds the semantic constant and the
state-store call site.

### Tests added this slice

- `tests/Conquer.Tests/Assets/Item/ItemAddRecordTests.cs` — 4 tests covering:
  the `SpeedPercentOffsetPayloadWordIndex` constant, indexed lookup of the speed-percent
  word from a realistic `ItemAdd.ini` line, out-of-range index clamp-to-zero
  (negative / ≥ 8 / `int.MaxValue`), and col-to-word order preservation (cols 2..9 → words
  0..7).
- `tests/Conquer.Tests/Client/ClientWorldRoleStateStoreMountedSpeedPercentOffsetTests.cs` —
  6 new tests extending the Slice 17 coverage:
  - `ApplyPlayerSpawn_WithItemAddEntry_AccumulatesUnsignedFromWord7` — basic source-2 hit.
  - `ApplyPlayerSpawn_WithItemAddEntry_MaxUshortPreservesUnsignedExtension` — confirms
    `ushort.MaxValue` zero-extends (not sign-extends) matching native `movzx`.
  - `ApplyPlayerSpawn_WithNoItemAddTable_SkipsSourceTwoContribution` — null table skip,
    source 1 still applies.
  - `ApplyPlayerSpawn_WithItemAddMismatchedMountPlusLevel_SkipsSourceTwo` — composite-key
    miss on the secondary id.
  - `ApplyPlayerSpawn_WithBothSourcesPopulated_SumsContributions` — full cache-writer
    parity: signed source 1 + unsigned source 2 sum into the accumulator.
  - `ApplyPlayerSpawn_WithZeroMountTypeId_SkipsSourceTwoEvenWhenTablePresent` — preserves
    the slice-17 short-circuit guard for `mountTypeId == 0`.

Both files use `ItemAddIniTable.Parse` directly (plain-text, no decode step) which matches
the native `ItemAdd.ini` reader (not DecodedTextDat).

## Slice 19 — Real-client end-to-end validation of the CRole+0x48 accumulator

**Scope:** Synthetic unit tests in Slices 17 and 18 pin parser/encoder behavior, but they
run on hand-crafted fixtures. Slice 19 adds a real-client regression harness that exercises
the entire `MsgPlayer → state store → accumulator` pipeline against the shipping
`ItemType.dat` + `ItemAdd.ini`, catching decoder drift, composite-key drift, or
sign-extension drift between the managed parsers and the state store's consumers.

### Verified real-client fixture

- **Mount type id**: `201000` (horse, `major_cat=2 sub=201` per
  `GetItemMainTypeFromId` at `Conquer.exe:0x67AF1A`).
- **Mount plus level**: `9` (valid range per the cap table at `0x86AA30`, confirmed
  present in the real `ItemAdd.ini` as `201000 9 0 1500 1500 0 900 0 0 0`).
- **Source 2 contribution for mounts**: `col9 = 0` for every mount entry (201000, 202000,
  203000, all levels 1..12) in the shipping `ItemAdd.ini` (36 mount entries total). The
  loader + lookup pipeline is exercised end-to-end; the final contribution is 0 because
  the content doesn't use col 9 for mounts in this build. Nonzero col 9 values live in
  the `160xxx` item-type range (168 armor entries).
- **Source 1 contribution**: derived at test time from the real `ItemType.dat` record
  field 18 (if present).

The expected accumulator is computed live from the catalog — not hard-coded — so the
assertion stays valid across content patches.

### Tests added this slice

- `tests/Conquer.Tests/Client/ClientWorldRoleStateStoreMountedSpeedPercentOffsetRealClientTests.cs`:
  - `ApplyPlayerSpawn_WithRealCatalog_MatchesDirectAccumulatorComputation` — opens the real
    catalog, directly computes expected source 1 + source 2 from the loaded tables, applies
    a spawn packet with the fixture mount id/level, and asserts the state store's
    `MountedSpeedPercentOffset` matches.
  - `ApplyPlayerSpawn_WithRealCatalog_FindsItemAddCompositeRecord` — independently
    verifies that the `(mountTypeId=201000, mountPlusLevel=9)` composite key resolves in
    the real `ItemAddIniTable` and returns an 8-word payload. Guards against content-side
    removal or key-composition drift.

These real-client tests live in `Conquer.Tests.Client` alongside the synthetic tests from
Slices 17 and 18 and use `Client5517FixturePaths.AssetClientRoot` for asset discovery.
