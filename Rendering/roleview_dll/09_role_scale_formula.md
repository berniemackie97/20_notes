# Role Scale Formula — `Role_TickAndRender` (Conquer.exe:0x64F5F7)

## Overview

The character rendering scale is computed per-frame in `Role_TickAndRender` and passed to the
RoleView's `SetTransform` (vf_4) as the 5th parameter. This scale determines the visual size of
the 3D character model in the world.

## Native Assembly (Conquer.exe 0x64F7EB–0x64F803)

```asm
0064f607  mov     esi, ecx              ; ESI = Role* (this pointer, NOT CGameMap!)
...
0064f7eb  mov     dword [ebp-0x4c], eax ; var = role[0x61] = *(int32*)(role+0x184)
0064f7ee  fild    st0, dword [ebp-0x4c] ; push as float (int→float conversion)
0064f7f1  fmul    st0, dword [esi+0x188]; × *(float*)(role+0x188)
0064f7f7  fmul    st0, dword [0x93e90c] ; × 0.75f (verified: 0x3F400000)
0064f7fd  fmul    st0, dword [0x845dc8] ; × 0.01f (verified: 0x3C23D70A)
0064f803  fstp    dword [ebp-0x28], st0 ; store final scale float
```

## Formula

```
scale = (float)(int)role[0x184] * (float)role[0x188] * 0.75f * 0.01f
```

Where:
- `role+0x184` (role[0x61]) — **bodyScale** (int32): body size value from RoleData lookup
- `role+0x188` (role[0x62]) — **scaleMultiplier** (float): per-role scale multiplier

## Field: `role+0x184` — bodyScale (int32)

### Writers

1. **`CRole__Init`** (0x64D260):
   - Fresh role default: `*(role+0x184) = 100` at `0x64D2A2`
   - This is the verified pre-transform baseline for a newly constructed `CRole`.

2. **`CRole__SetTransformLook`** (0x650B58):
   - When `refreshSourceId != 0`: `role[0x61] = transformRecord.Scale` (record offset 0x08)
   - When `refreshSourceId == 0` (clear): `role[0x61] = 100` (0x64 = default)
   - See `08_transform_look_record.md` for the Transform.ini record layout.

3. **`CMsgPlayer__Process`** (0x755F64):
   - From RoleData record: `role[0x61] = *(roleDataRecord + 0x0C)` (at 0x756478)
   - From RoleData query (human male/female): `role[0x61] = RoleDataQuery()->GetBodyScale()` (at 0x75720B)

### Default Value: **100**

When no transform look is active, bodyScale resets to 100. This represents the "normal"
character body size.

## Field: `role+0x188` — scaleMultiplier (float)

### Writers

1. **`CRole__Init`** (0x64D260):
   - Fresh role default: `*(role+0x188) = 1.0f` at `0x64D2AA`

2. **`Role_SetMountedActionFrameIntervalAndRefreshActionScale`** (0x6E5E80)

This function sets both `role[0x128]` (mounted action frame interval) and `role[0x188]` (scale multiplier):

```c
// Decompiled logic (0x6E5F1C–0x6E5F2F):
if (mountedActionFrameInterval == 0)
    role[0x188] = 1.0f;                              // no action → default multiplier
else
    role[0x188] = (float)(int)role[0x44] * 0.01f;    // action active → scale from role[0x44]
```

Mounted helper chain verified in `Conquer.exe`:

- `Role_UpdateMountActionScaleCacheFromRoleState` (`0x6E5E33`)
  - tail-calls `Role_UpdateMountActionScaleCacheFromSources(role+0x50, role+0x3C, role+0x58, role+0x54)`
    with all args sourced from the currently-cached CRole fields — this is an idempotent refresh
    path, not an initial writer (see `CMsgPlayer__Process` + `CHeroItem__SetEquipSlot` below).
- `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`)
  - writer body verified at `0x6E5F5C..0x6E6020`:
    - `0x6E5F5C`: `CRole+0x48 = 0` (accumulator init)
    - `0x6E5F66`: `CRole+0x54 = mountActionScaleVariantSource` (arg4)
    - `0x6E5F6C`: `CRole+0x58 = mountActionScaleSecondarySource` (arg3)
    - `0x6E5F72`: `CRole+0x50 = role` (arg1) — primary source role pointer used as base factor in key build
    - `0x6E5F75`: `CRole+0x3C = mountActionScalePrimarySource` (arg2) — byte (0..12), the MOUNT PLUS
      LEVEL / speed class index consumed as the low 2 digits of the record key and as the index
      into the cap table at `0x86aa30` in
      `Role_ApplyMountedSpeedClassScaleToFrameInterval` (`0x65127A`)
    - `0x6E5FD0..0x6E5FD9`: if `ItemTypeDataSingleton_TryGetItemRecordByTypeId(&data_96ae88, role, &var_e0)`
      succeeds, `CRole+0x48 += sx.d(*(var_e0 + 0x30.w))` (signed 16-bit item-record field — the
      first speed percent offset contribution). The +0x30 offset corresponds to text field
      index 18 in the `@@`-delimited `Itemtype.dat` record, verified by tracing the sequential
      tokenizer at `ItemTypeDataSingleton_LoadItemRecordTableFromDecodedTextDat` (`0x677A95`).
    - `0x6E5FED..0x6E5FF3`: if `GameDataSingleton_TryGetActionTypeRecordByDualKey(&data_96ae88, role, mountActionScalePrimarySource, &var_20) != 0`,
      `CRole+0x48 += zx.d(*(var_20 + 0x0E.w))` (unsigned 16-bit field at output+0x0E — the
      second speed percent offset contribution, which maps to payload word index 7, i.e. the
      10th whitespace-separated column of the corresponding `ItemAdd.ini` line). The dual-key
      composes `(mountTypeId << 32) | mountPlusLevel` (arg2 is the `role` parameter which
      `CMsgPlayer__Process` populates from packet byte 0x44 — the mount *item type id*,
      not the CRole pointer; arg3 is the `mountPlusLevel` byte at packet+0x85) and looks up
      the singleton's composite-record tree at `+0x1C` via
      `TileCoordinateAttachmentLookup_FindByTileCoordinates`, copying a 16-byte record from
      node+0x18 to the output buffer. That tree is populated by
      `ItemTypeDataSingleton_LoadItemAddTable` (`0x678FE7`) from `ini/ItemAdd.ini`: each line
      is 10 whitespace-separated unsigned integers where cols 0/1 form the dual key and
      cols 2..9 become payload words at byte offsets 0x00, 0x02, …, 0x0E of the record.
    - `0x6E5FF8..0x6E6010`: queries `Role_QueryMountActionScaleRecord(role)` and on hit writes:
      - `CRole+0x44 = record[1]` (percent used by `CRole+0x188`),
      - `CRole+0x4C = record[2]` (mount offset later mirrored to `CRole+0x314`),
    - `0x6E601A..0x6E6020`: if `Role_HasStatusFlag(0x32)` (mounted), immediately calls
      `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, record[0])`.
- `Role_QueryMountActionScaleRecord` (`0x6E6045`)
  - resolves the mounted action-scale record through `RoleDataQuery()->vfunc(+0xA8)`.
  - key build at `0x6E6052..0x6E606C`: `key = base * 100 + CRole+0x3C` where
    `base = CRole+0x54` when `CRole+0x54 != 0 && CRole+0xDC != 3`, else `base = CRole+0x50`.
    Second arg to the vtable is `CRole+0x58` (primary path) or `0` (variant path).

### Verified initial writers (not refresh-only)

- `CMsgPlayer__Process` (`0x756B1D`): pushes packet fields as
  `Role_UpdateMountActionScaleCacheFromSources(*(packet+0x44), zx.d(*(packet+0x85)),
  *(packet+0x8b), *(packet+0x48))`. Packet byte `0x85` = `MsgPlayerSpawn10014Packet.MountPlusLevelOffset`
  = `MountPlusLevel`; this byte becomes the mount-speed-class index stored at `CRole+0x3C`.
- `CHeroItem__SetEquipSlot` (`0x6DACDC`, `0x6DACF4`): pushes item-derived values
  `Role_UpdateMountActionScaleCacheFromSources(role_4, sub_67cc54(item), sub_67d75d(item), item_subfield)`.
  The primary source comes from `sub_67cc54(item)` on the equipped mount record.

Verified nonzero callers for the currently traced slice:

- `CMsgPlayer__Process` (`0x755F64`)
  - direct `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, *(record+0x44))` at `0x7564B2`.
- `Role_ApplyStatusFlagBitfieldAndDispatchEffects` (`0x6729B5`)
  - on gaining status `0x32`, queries `Role_QueryMountActionScaleRecord(role)` and applies `record[0]`.

Verified clear callers:

- `Role_TryApplyIncomingActionInfo` (`0x64DD38`) at `0x64DDB7`
- `Role_ApplyStatusFlagBitfieldAndDispatchEffects` (`0x6729B5`) on ride-down at `0x672E32`
- helper at `0x67563F` clear branch at `0x675666`
- command-type-`0x29` handler at `0x735BFD` clear branch at `0x735C69`

### Default Value: **1.0f**

For a basic character with no active mounted action frame interval (`role+0x128 = 0`), the multiplier is 1.0.

## Computed Scale Values

| bodyScale | scaleMultiplier | Computed Scale | Context                          |
|----------:|----------------:|---------------:|:---------------------------------|
| 100       | 1.0             | **0.75**       | Default new character            |
| 100       | 0.84            | 0.63           | ≈ BADimguiCO default (0.63)     |
| 40        | 1.0             | 0.30           | Tiny character (our old default) |

### **Default new character scale = 0.75** (100 × 1.0 × 0.75 × 0.01)

Our hardcoded `0.3f` was 2.5× too small, producing a tiny figure.

## Scale Delivery to RoleView

At 0x64F854, the computed scale is passed to the RoleView's SetTransform (vtable slot 4):

```c
// Verified call-site mapping:
//   projectionBaseOffsetX
//   adjustedProjectionBaseOffsetY
//   elevation
//   directionAngle
//   computedScale
role[0xED]->vf_4(projectionBaseOffsetX,
                 adjustedProjectionBaseOffsetY,
                 elevation,
                 directionAngle,
                 computedScale);
```

Evidence from `RoleView_SharedSetTransformFromCamera` (`RoleView.dll:0x1000327E`):

```asm
mov [esi+0x04], eax   ; screenX  = projectionBaseOffsetX
mov [esi+0x08], eax   ; screenY  = adjustedProjectionBaseOffsetY
mov [esi+0x0C], eax   ; elevation= elevation (or doubled when not projecting)
mov [esi+0x18], eax   ; rotation = directionAngle
mov [esi+0x1C], eax   ; scale    = computedScale
```

The `projectionBaseOffsetX/Y` pair comes from
`CGameMap_GetProjectionCenterOffsetFromScreenPoint` (`0x61E319`) on the role's absolute
projected point (`role+0x350/+0x354`). The separate scaled-viewport composite point is used
later by the offscreen bitmap blit path, not by the live type-1 RoleView transform call.

In BADimguiCO's `Simple3DObj::vf_4` (SetTransform), the scale parameter becomes uniform
scale on all three axes:
```cpp
*(float*)(base + 0x20) = s;   // scaleX
*(float*)(base + 0x24) = s;   // scaleY
*(float*)(base + 0x28) = s;   // scaleZ (UNIFORM)
```

## Critical Correction: ESI Register

**Previous sessions incorrectly assumed `esi` = CGameMap pointer** because `CGameMap_GetSingletonPtr`
is called nearby. The actual disassembly at 0x64F607 shows:

```asm
0064f607  mov     esi, ecx    ; ECX = this pointer = Role*
```

Both `role[0x184]` and `role[0x188]` are fields on the **CRole object**, not CGameMap.

## BNinja Renames Applied

- `Conquer.exe`:
  - `0x64D260` → `CRole__Init`
  - `0x651616` → `CRole__InitProperties`
  - `0x6E5E80` → `Role_SetMountedActionFrameIntervalAndRefreshActionScale`

## Slice 20 — Per-role `CRole+0x188` multiplier pipeline + consumer cash-in

**Scope:** Replace the hardcoded `1.0f` in
`PlayerRoleViewRenderScaleRuntime.ComputeBaselineScale` with the per-role
`ActionScaleMultiplier` threaded end-to-end from
`ClientWorldRoleStateSnapshot.MountActionScaleSourceState` down to
`PlayerRoleViewDirectRenderTransform.Scale`, so that a non-default
`CRole+0x188` observed by the native cache writer is actually visible in the
computed render scale. Before this slice, the full accumulator and derivation
chain was populated on the authoritative state record, but the consumer at the
render boundary ignored the field and always passed `1.0f` to the formula.

### Pre-slice consumer state

`PlayerRoleViewDirectRenderTransformResolverRuntime.ResolveBaselineFromVisualPlan`
invoked `ComputeBaselineScale(bodyScalePercent)` with the optional
`actionScaleMultiplier` parameter defaulted to
`PlayerRoleViewRenderScaleRuntime.VerifiedDefaultActionScaleMultiplier = 1.0f`.
That meant even a packet-derived non-default `CRole+0x188` value would collapse
back to the fresh-role baseline `bodyScale * 1.0f * 0.75f * 0.01f` at the render
boundary.

### Pipeline wiring (5 hops)

Each hop is a distinct `internal readonly record struct` with a new
`float ActionScaleMultiplier` field defaulted to
`ClientWorldRoleMountActionScaleSourceState.VerifiedDefaultActionScaleMultiplier`
(= `1.0f`, see note on the `default(T)` trap below):

| Hop | From type → To type | Writer | File |
|----:|---------------------|--------|------|
| 1 | `ClientWorldRoleStateSnapshot.MountActionScaleSourceState.ActionScaleMultiplier` → `ClientWorldProjectedRoleStateSnapshot.ActionScaleMultiplier` | `ClientWorldProjectedRoleStateStore.ReplaceProjectedRoles` | `src/Conquer/Role/ClientWorldProjectedRoleState.cs` |
| 2 | `ClientWorldProjectedRoleStateSnapshot.ActionScaleMultiplier` → `ClientWorldRoleRenderSubmissionRuntime.ActionScaleMultiplier` | `ClientWorldRoleRenderSubmissionStage.SubmitCurrentFrameRoleRenderSubmissions` | `src/Conquer/Role/ClientWorldRoleRenderSubmissionStage.cs` |
| 3 | `ClientWorldRoleRenderSubmissionRuntime.ActionScaleMultiplier` → `ClientWorldRoleViewSceneObjectSnapshot.ActionScaleMultiplier` | `ClientWorldRoleViewSceneObjectStore.Submit` | `src/Conquer/Role/ClientWorldRoleViewSceneObjectStore.cs` |
| 4 | `ClientWorldRoleViewSceneObjectSnapshot.ActionScaleMultiplier` → `ClientWorldRoleViewVisualPlanSnapshot.ActionScaleMultiplier` | `PlayerRoleViewVisualPlanResolverRuntime.Resolve` | `src/Conquer/Role/PlayerRoleViewVisualPlan.cs` |
| 5 | `ClientWorldRoleViewVisualPlanSnapshot.ActionScaleMultiplier` → `PlayerRoleViewDirectRenderTransform.Scale` (via `ComputeBaselineScale`) | `PlayerRoleViewDirectRenderTransformResolverRuntime.ResolveBaselineFromVisualPlan` | `src/Conquer/Role/PlayerRoleViewDirectRenderTransform.cs` |

Every intermediate record threads the field via a primary-constructor parameter
with a literal-1.0f default (because primary-constructor defaults must be
compile-time constant expressions and cannot reference type-member constants
defined in the same declaration, including the struct's own
`VerifiedDefaultActionScaleMultiplier`). The single source of truth for the
`1.0f` value remains
`ClientWorldRoleMountActionScaleSourceState.VerifiedDefaultActionScaleMultiplier`
and the mirrored constant on `PlayerRoleViewRenderScaleRuntime`; the literal is
commented with a pointer back to that constant at each use.

### Consumer cash-in

`PlayerRoleViewRenderScaleRuntime.ComputeBaselineScale` is now called with the
per-role multiplier threaded through the pipeline:

```csharp
Scale: PlayerRoleViewRenderScaleRuntime.ComputeBaselineScale(
    visualPlan.BodyScalePercent,
    visualPlan.ActionScaleMultiplier)
```

The signature still exposes the optional `actionScaleMultiplier` parameter with
the `VerifiedDefaultActionScaleMultiplier` default, so older call sites and
unit tests that compute the scale directly from a body-scale percent continue
to observe the native fresh-role baseline (`bodyScale * 1.0f * 0.75f * 0.01f`).

### `FreshRoleDefault` guard — the `default(T)` trap

`ClientWorldRoleMountActionScaleSourceState` is a C# `readonly record struct`
with `ActionScaleMultiplier` defaulted to `1.0f` via its primary constructor.
However, `default(ClientWorldRoleMountActionScaleSourceState)` bypasses
primary-constructor defaults — the struct is zero-initialized, so
`default(T).ActionScaleMultiplier == 0.0f`. Before Slice 20 this was latent and
invisible because the consumer used a hardcoded `1.0f`, but once the consumer
starts honoring the field, any code path that seeded a fresh role via
`default(ClientWorldRoleStateSnapshot)` (e.g. `Dictionary.TryGetValue` miss)
would drop `CRole+0x188` from `1.0f` to `0.0f`, collapsing the scale formula
to zero — i.e. an invisible sprite.

Guards introduced this slice:

- `ClientWorldRoleMountActionScaleSourceState.FreshRoleDefault` — a static
  factory that constructs the record through the primary constructor, so all
  primary-constructor defaults (including `ActionScaleMultiplier = 1.0f`) are
  applied. This mirrors what `CRole__Init` (`0x64D260`) leaves at the relevant
  CRole offsets before any packet writes: `CRole+0x44 = 100`,
  `CRole+0x4C = 50`, `CRole+0x118 = 0`, `CRole+0x128 = 0`, and
  `CRole+0x188 = 1.0f`.
- `ClientWorldRoleStateStore.PreserveOrFreshDefault(in existingState)` — used
  by both `ApplyUserInfo` and `ApplyServerEnterMap` to decide whether to carry
  forward the existing role's `MountActionScaleSourceState` or seed the fresh
  default. A first-time-seen role (`existingState.EntityId == 0` from a
  `Dictionary.TryGetValue` miss) seeds `FreshRoleDefault`; a subsequent update
  that preserves the role carries its existing mount state forward.
  `ApplyPlayerSpawn` already constructs the mount state explicitly from packet
  fields, so it doesn't need the guard.

This is a purely defensive fix — before Slice 20 it was unreachable because
the consumer hardcoded `1.0f`. With the consumer now reading the field,
`default(T)` on the authoritative state would be a live bug. The three-test
`DefaultStruct_ActionScaleMultiplier_IsZero_WhyFreshRoleDefaultExists` +
`ApplyUserInfo_FirstTimeSeenRole_...` + `ApplyServerEnterMap_FirstTimeSeenRole_...`
coverage pins this invariant.

### Current cache population

The `GameData.dll` provider and `ini/mounttype.dat` lookup are now plumbed.
Remote spawn state resolves `CRole+0x44` through
`Role_QueryMountActionScaleRecord` (`0x6E6045`), while local equipment changes
resolve the same record through `ClientWorldLocalHeroMountActionScaleRuntime`.
The local runtime also owns `CRole+0x4C`, cached/active frame intervals
`CRole+0x118`/`+0x128`, and the derived `CRole+0x188` multiplier used by the
render boundary.

### Test coverage

Three new/extended test classes in `tests/Conquer.Tests/Client/`:

- `PlayerRoleViewActionScaleMultiplierPipelineTests.cs` (new, 2 tests) —
  end-to-end regression probe walking all 5 pipeline hops. The synthetic-value
  test uses `0.84f` (chosen to be neither the `1.0f` default nor the `0.0f`
  degenerate value, so it is observable at each hop) and asserts the
  multiplier is preserved at every hop plus lands in the final
  `PlayerRoleViewDirectRenderTransform.Scale`. It also asserts the final scale
  is *not* equal to the pre-Slice-20 `1.0f` baseline, proving the consumer
  cash-in actually bit. The default-value test reconstructs the verified
  fresh-role baseline of `0.75f` (from `bodyScale=100 * 1.0f * 0.75f * 0.01f`).
- `ClientWorldRoleMountActionScaleSourceStateFreshRoleDefaultTests.cs` (new,
  5 tests) — pins `FreshRoleDefault.ActionScaleMultiplier == 1.0f`, proves
  `default(T).ActionScaleMultiplier == 0.0f` (the exact trap `FreshRoleDefault`
  exists to avoid), and verifies that `ApplyUserInfo` + `ApplyServerEnterMap`
  seed the fresh default on first observation of a role.
- `PlayerRoleViewDirectRenderTransformResolverRuntimeTests.cs` (extended,
  +8 tests) — 2 new resolver tests pinning the visual-plan-to-transform
  propagation (default + synthetic multiplier paths), plus 6 new tests in a
  sibling `PlayerRoleViewRenderScaleRuntimeTests` class pinning the raw
  `ComputeBaselineScale(int, float)` formula and its three verified float
  constants (`0.75f` base factor, `0.01f` percent unit, `1.0f` fresh-role
  multiplier) against native-verified inputs/outputs.

Full suite: 1880/1880 tests pass.

### BNinja renames applied this slice

None — the native side was already fully mapped by prior slices. Slice 20 is
purely a managed-pipeline wiring slice.

## Slice 21 — `MountTypeDatTable` (managed mirror of `GameData.dll` mount action-scale provider)

**Scope:** Unblock the "plumbed but dry" Slice 20 pipeline by providing the
managed mirror of the `RoleDataQuery()->vfunc(+0xA8)` call. Slice 21 produces a
loader + query API for `ini/mounttype.dat`; wiring into
`ClientWorldRoleStateStore` to populate `CachedActionScalePercent` is deferred
to Slice 22.

### Native provider chain (GameData.dll)

The Slice-20 `Role_QueryMountActionScaleRecord` (`Conquer.exe:0x6E6045`) tail
call is a virtual dispatch:
`RoleDataQuery()->vfunc(+0xA8)(bucketKey, mountColorIdentity, &outRecord)`.
The singleton + vtable live in `GameData.dll`:

| Native address | Role |
|:---|:---|
| `GameData.dll:sub_10003544` (`RoleDataSingleton_LoadMountTypeDat`) | Populator. Opens encoded `ini/mounttype.dat` through the shared `DecodedTextDatReader` path with seed `0x2537` (verified at `0x10003568`), parses classic `[sectionId] / Key=Value` blocks via the MyIni helper, and inserts each record into a `std::map<uint32, std::vector<Record>>` at `singleton+0x1BC`. |
| `GameData.dll:sub_100038eb` (vtable slot `+0xA8`) | Query. Two-stage lookup: (1) bucket by numeric key, (2) pick the record with the smallest byte-wise squared Euclidean distance between the caller's query color and the record's packed color, with a `0x4F605` penalty applied to any non-exact score when `RareFlag != 0`. |
| `GameData.dll:sub_10011bbd` | Scoring. Byte-wise squared Euclidean distance on two packed `uint32` values, treating each byte as an independent channel. Range `0..0x3F804` (= `4 * 255^2 = 260100`). |
| `GameData.dll:sub_10008dc5` | `std::map<K,V>::find_or_insert` (returns a ref to the vector at node+0x14). Used by the loader to accumulate records sharing a bucket key in insertion order. |
| `GameData.dll:sub_10012efc` | `MyIni::GetProfileInt` (case-insensitive key lookup, `atoi` of value; missing key → `0`). |

### Native record layout (0x50 bytes)

Verified from the `sub_10003544` stack-to-record insertion at
`sub_10008f3d(sub_10008dc5(singleton+0x1BC), &var_70)`:

| Offset | Bytes | INI field | Semantics |
|:---|---:|:---|:---|
| `+0x00` | 4 | `armor` | Mount action frame interval. Consumed as `record[0]` by `Role_UpdateMountActionScaleCacheFromSources` at `Conquer.exe:0x6E601C`. |
| `+0x04` | 4 | `Showrate` | Mount action scale percent. Consumed as `record[1]` at `Conquer.exe:0x6E6010`, written to `CRole+0x44` — the source for the non-trivial `CRole+0x188 = CRole+0x44 * 0.01f` branch. |
| `+0x08` | 4 | `Offset` | Mount vertical offset. Consumed as `record[2]` at `Conquer.exe:0x6E6008`, written to `CRole+0x4C`. |
| `+0x0C` | 4 | `Rare` | Scoring penalty gate (non-exact penalty at `0x10003928..0x1000392E`). |
| `+0x10` | 4 | `IconId` | UI icon lookup. Defaults to `0x493E0` (300000) when field is absent (`0x10003690..0x10003692`). |
| `+0x14` | 4 | `Color1/2/3` packed | `((Color1 << 8) \| Color2) << 8 \| Color3`; top byte always zero (loader never writes it). Scoring key. |
| `+0x18..+0x50` | 56 | — | Three `std::string` sound paths + title. Not consumed by the render-scale pipeline; omitted from the managed record. |

### Bucket key transform

```
bucketKey = (sectionId / 10000) * 100 + sectionId % 100
```

Native at `0x10003787..0x1000378E`. This strips the middle 4 digits of the
10-digit section id, leaving `(base) * 100 + (plusLevel)`. For example,
`[3000000000]`, `[3000000600]`, and `[3000004000]` all live in bucket
`30000000` — representing the Steed mount family (base `300000`) at plus-levels
`0`, `6`, and `40` respectively. The caller-built query key at
`Conquer.exe:0x6E6052..0x6E606C` — `base * 100 + CRole+0x3C` — is a byte-exact
match to this bucketing.

### Scoring algorithm

```
score = byteWiseSquaredDistance(queryColor, record.PackedColor)
if score != 0 AND record.RareFlag != 0:
    score = 0x4F605                # == 325125, the rare-mismatch penalty
```

The native query seeds `best = bucket[0]` and competes via **strict** `eax u< ebx`
(unsigned less-than). Ties therefore never displace the first-inserted record;
a bucket of all-`Rare=1` records (all scores penalized to `0x4F605`) always
returns `bucket[0]` for any non-exact query. Exact-color matches short-circuit
the penalty because `score == 0`, so a `Rare=1` record can still win if the
query hits its exact color.

### File format — reuses `DecodedTextDatReader`

`mounttype.dat` uses the identical XOR + MSVC-rand seed-table + ROTR8 transform
as `itemtype.dat` with seed `0x2537`. The managed
`Conquer.Assets.IO.DecodedTextDatReader` (already in use for `itemtype.dat`,
`itemadd.ini`, and `itemfuse.ini`) handles the decode verbatim. After decoding,
the payload is a plain-text INI file with classic `[sectionId] / Key=Value`
blocks. Real-client 5517 file: 1300 sections, 676 unique bucket keys.

### Managed implementation

Two new public types in `Conquer.Assets.GraphicDb`:

| Type | File |
|:---|:---|
| `MountTypeDatRecord` (readonly record struct) | `src/Conquer.Assets/GraphicDb/MountTypeDatRecord.cs` |
| `MountTypeDatTable` (sealed class) | `src/Conquer.Assets/GraphicDb/MountTypeDatTable.cs` |

Public surface:

- `MountTypeDatRecord.ComputeBucketKey(long sectionId) → uint` — mirrors
  `(sectionId / 10000) * 100 + sectionId % 100`.
- `MountTypeDatRecord.PackColor(byte, byte, byte) → uint` — mirrors the native
  shift-combine at `0x10003643`.
- `MountTypeDatRecord.VerifiedDefaultIconId = 0x493E0` — the native
  `IconId`-absent fallback.
- `MountTypeDatTable.Open(string path)` + `OpenFromClientRoot(string)` +
  `TryOpen` / `TryOpenFromClientRoot` — same factory pattern as
  `ItemTypeDatTable`.
- `MountTypeDatTable.Parse(byte[] encoded)` → decodes via
  `DecodedTextDatReader` then `ParseDecodedText(string)`.
- `MountTypeDatTable.TryQueryRecord(uint bucketKey, uint mountColorIdentity, out MountTypeDatRecord)`
  — the Slice-22 consumption entry point. Byte-exact mirror of the two-stage
  `sub_100038eb` lookup, including the first-record `strict <` tie-break.
- `MountTypeDatTable.ComputeByteWiseSquaredDistance(uint, uint) → int` — the
  `sub_10011bbd` standalone, exposed for diagnostics/tests.
- `MountTypeDatTable.VerifiedRareMismatchPenalty = 0x4F605` — the documented
  native penalty constant.
- `MountTypeDatTable.GetBucket(uint) → IReadOnlyList<MountTypeDatRecord>` — for
  diagnostics; returns empty when absent.
- `MountTypeDatTable.Empty` + `RecordCount` / `BucketCount` — empty-instance /
  stats surface.

The parser reuses the `pendingLine` lookahead pattern from the existing INI
tables (for recovery when a new `[section]` header appears mid-field-stream),
strips `//` line comments, and treats keys case-insensitively. Fields missing
from an INI block default to `0` (matching native `atoi("") == 0` fall-through
at `0x100130BB`); `IconId == 0` falls through to `VerifiedDefaultIconId`.

### Test coverage

Two new test classes:

- `tests/Conquer.Tests/Assets/GraphicDb/MountTypeDatTableTests.cs` — 22 synthetic
  tests pinning:
  - `ComputeBucketKey` + `PackColor` byte-exactness across edge cases
  - `ComputeByteWiseSquaredDistance` symmetry, exact-match zero, single-channel
    difference, max-value (`0x3F804`), and signed high-bit handling
  - `ParseDecodedText` empty input, missing fields, `IconId=0` → default,
    case-insensitive keys, comment stripping (leading/inline/trailing/mid),
    malformed section header recovery, missing `=` line recovery, consecutive
    sections without blank separator
  - `TryQueryRecord` missing bucket, exact-color match, non-exact closest-by-
    distance, Rare-penalty gating of inexact matches, Rare-exact-match still
    wins, all-Rare bucket → `bucket[0]` survives via strict `<`
  - `GetBucket` insertion-order preservation + missing-bucket empty
  - `Parse(byte[])` encoded-payload round-trip through the
    `DecodedTextDatReader` (XOR+ROTR8 seed `0x2537`)
  - `TryOpen` missing-file path → `Empty` singleton
- `tests/Conquer.Tests/Assets/GraphicDb/MountTypeDatTableRealClientTests.cs` —
  9 real-fixture tests against `assets/5517/ini/mounttype.dat` (all guarded by
  `File.Exists` so CI still runs without the client):
  - `RecordCount == 1300`, `BucketCount == 676`
  - Bucket `30000000` (Steed family) has exactly 49 records with
    `[3000000000]` at insertion index 0
  - Exact-color queries resolve to `[3000000000]` (Showrate=100),
    `[3000000600]` (Showrate=110), `[3000004000]` (Rare=1, Showrate=120) —
    these are pre-computed from the decoded file and are unique within the
    bucket, so the result is deterministic
  - **Rare-penalty regression sensor:** near-miss query
    `(187,135,200)` against `[3000004000]`'s `(187,135,201)` returns
    `[3000003000]` (raw distance `1875`, Rare=0) instead of `[3000004000]`
    (raw distance `1`, Rare=1 → penalized to `0x4F605 = 325125`). If the
    penalty gate is ever dropped, this test fails immediately.
  - `Slice-20→21 pipeline sensor:` the `[3000000600]` Showrate=110 assertion
    is the observable proof that the lookup **can** return a
    `CachedActionScalePercent != 100` once Slice 22 wires the loader into
    `ClientWorldRoleStateStore.ApplyPlayerSpawn`.

### Follow-on: Slice 22 wiring

**Landed** in the Slice 22 section below. `ClientWorldRoleStateStore` now
loads `MountTypeDatTable` via `StartupComposition`, queries it in
`ApplyPlayerSpawn`, and writes both `CachedActionScalePercent` (always on a
hit) and `ActionScaleMultiplier` (gated on `HasMountedStatus(0x32)` + non-zero
`ActionFrameInterval`) onto `ClientWorldRoleMountActionScaleSourceState`. No
changes to the render boundary were needed — the consumer cash-in from
Slice 20 already reads `visualPlan.ActionScaleMultiplier`.

### BNinja renames applied this slice

- `GameData.dll:sub_10003544` → `RoleDataSingleton_LoadMountTypeDat` (pending;
  native singleton populator for `mounttype.dat`). Decomp confirmed via string
  xref on `"ini/MountType.dat"` at `GameData.dll:0x1001C488`.

## Slice 22 — Wire `MountTypeDatTable` into `ClientWorldRoleStateStore`

**Scope:** Consume the Slice-21 loader from the managed spawn path so that
`MsgPlayer` writes a non-default `CachedActionScalePercent` and
`ActionScaleMultiplier` onto `ClientWorldRoleMountActionScaleSourceState`. The
Slice-20 pipeline was already threaded end-to-end; Slice 22 flips the
upstream source from the native cached-percent default to the actual
`Role_QueryMountActionScaleRecord` result.

### Native call the managed code mirrors

The full native cache-writer sequence in
`Role_UpdateMountActionScaleCacheFromSources` (`Conquer.exe:0x6E5F41`) at
`0x6E5FF8..0x6E6020`:

```c
// Query the action-scale record (cross-binary vfunc into GameData.dll).
record = Role_QueryMountActionScaleRecord(role);
if (record != 0) {
    // Always write the two cache mirrors on a hit.
    role[0x4C/4] = record[2];                    // CRole+0x4C ← Offset  (mount vert. offset)
    role[0x44/4] = record[1];                    // CRole+0x44 ← Showrate (percent)
    // Multiplier derivation is gated on the mounted bit.
    if (Role_HasStatusFlag(role, 0x32))
        Role_SetMountedActionFrameIntervalAndRefreshActionScale(
            role, record[0]);                    // CRole+0x128 ← armor, CRole+0x188 derived
}
```

And inside
`Role_SetMountedActionFrameIntervalAndRefreshActionScale` (`0x6E5F1C..0x6E5F2F`):

```c
role[0x128/4] = frameInterval;                   // CRole+0x128 ← record[0] = armor
role[0x188/4] = (frameInterval == 0)
    ? 1.0f
    : (float)(int)role[0x44/4] * 0.01f;          // CRole+0x188 derived
```

The original Slice 22 writer surfaced the two values
the Slice-20 pipeline already threads: `CachedActionScalePercent` (mirror of
`CRole+0x44`) and `ActionScaleMultiplier` (mirror of `CRole+0x188`). The mount
vertical offset (`CRole+0x4C`) and cached/active frame intervals
(`CRole+0x118`/`+0x128`) are now modeled for the local hero by the later local
equipment/status writer described below.

### Managed wiring

#### 1. `ClientWorldRoleStateStore` gains a 3rd optional dependency

```csharp
public ClientWorldRoleStateStore(ItemTypeDatTable? itemTypeTable = null,
    ItemAddIniTable? itemAddTable = null,
    MountTypeDatTable? mountTypeTable = null)
```

All three tables stay optional so existing unit tests and the composition-free
code paths (which inject `null`/`null`/`null` or any subset) continue to work.
When the mount-type table is absent, the store returns the native fresh-role
defaults `(CachedActionScalePercent=100, ActionScaleMultiplier=1.0f)` — the same
values Slice 20 was already emitting before the table was plumbed in.

#### 2. `ApplyPlayerSpawn` calls `ResolveMountActionScaleFromPacket`

The store's spawn handler now runs a helper method that mirrors the native
query-key build at `Conquer.exe:0x6E6052..0x6E606C`:

```csharp
bool usePreferredPath = preferredSourceId != 0 &&
    appearanceRefreshSourceId != TransformLookInhibitsPreferredSourceId; // == 3
uint baseSourceId = usePreferredPath ? preferredSourceId : primarySourceId;
uint bucketKey = baseSourceId * 100u + mountPlusLevel;
uint queryColor = usePreferredPath ? 0u : mountColorIdentity;

if (!_mountTypeTable.TryQueryRecord(bucketKey, queryColor, out MountTypeDatRecord record))
    return (100, 1.0f);                           // miss → fresh-role defaults

int cachedActionScalePercent = record.ActionScalePercent;    // always writes on hit
float actionScaleMultiplier =
    hasMountedStatus && record.ActionFrameInterval != 0
        ? record.ActionScalePercent * 0.01f       // non-shortcut branch
        : 1.0f;                                   // shortcut (not mounted OR frameInterval=0)
```

Two native gates are reproduced:

1. **Preferred-vs-primary source gate** (`0x6E6063`):
   `preferredSourceId != 0 && appearanceRefreshSourceId != 3`. The
   `AppearanceRefreshSourceId == 3` sentinel is `CRole+0xDC`, the
   transform-look source id from `TransForm.ini`; when `3`, the query falls
   back to the primary path even if a preferred source is set. The `!= 0`
   half of the gate guards against an uninitialized preferred slot.
2. **Mount-bit gate** (`0x6E601A`): `Role_HasStatusFlag(0x32)` decides whether
   the multiplier derivation runs. A query hit still updates
   `CachedActionScalePercent` unconditionally — only the multiplier is gated.

Inside the multiplier branch, the `record.ActionFrameInterval != 0` check is
the native short-circuit from `0x6E5F1C`: a zero `armor` clamps
`CRole+0x188` to `1.0f` regardless of `Showrate`.

#### 3. `StartupComposition` loads the table at process start

`StartupComposition.Compose` now calls
`MountTypeDatTable.TryOpenFromClientRoot(clientRootPath, out …)` before
constructing the world-state context, then threads the loaded table (or
`null` when missing) into `CreateWorldStateContext`. A
`LogMountTypeDatDiagnostics` helper mirrors the existing
`LogActionTransitionDiagnostics` pattern — missing or failed-load emits a
prominent `[MountTypeDat] … NOT-LOADED; CRole+0x44 and CRole+0x188 stay at
fresh-role defaults` warning so a silent regression to `1.0f` never flies
under the radar.

### Byte-exact match table

| Managed site | Native equivalent | Verified match |
|:---|:---|:---|
| `ResolveMountActionScaleFromPacket` preferred gate | `Conquer.exe:0x6E6063` (`if (+0x54 != 0 && +0xDC != 3)`) | ✓ |
| `bucketKey = base * 100 + plus` | `Conquer.exe:0x6E605C..0x6E606C` | ✓ |
| `queryColor = preferred ? 0 : color` | `Conquer.exe:0x6E6019..0x6E6022` (`xor edi, edi` on preferred path) | ✓ |
| `HasMountedStatus(0x32)` gate | `Conquer.exe:0x6E601A` (`Role_HasStatusFlag(0x32)`) | ✓ |
| `armor != 0 ? percent * 0.01 : 1.0f` | `Conquer.exe:0x6E5F1C..0x6E5F2F` | ✓ |
| Miss → leaves CRole+0x44 / CRole+0x188 at previous | Native `if (record != 0)` at `0x6E5FFD` | ✓ (fresh-role 100 / 1.0f for a first-spawn role) |

### Test coverage

One new test class in `tests/Conquer.Tests/Client/`:

- `ClientWorldRoleStateStoreMountActionScaleDerivationTests.cs` — 11 tests
  (9 `[Fact]` + 3 `[Theory]` rows) covering every branch of
  `ResolveMountActionScaleFromPacket`:
  - `WithNoMountTypeTable_LeavesActionScaleAtFreshDefaults` — null-table
    degraded mode returns (100, 1.0f).
  - `WithMountTableMissingBucketKey_LeavesActionScaleAtFreshDefaults` —
    bucket miss returns (100, 1.0f).
  - `WithQueryHitNotMounted_WritesCachedPercentAndLeavesMultiplierAtDefault`
    — hit + `StatusFlag0 = 0` → `CachedActionScalePercent=150`,
    `ActionScaleMultiplier=1.0f`. Proves the mount-bit gate only guards the
    multiplier, not the cached percent.
  - `WithQueryHitMountedButZeroFrameInterval_ForcesMultiplierToOne` —
    `armor=0` takes the `1.0f` shortcut even when mounted and `Showrate=999`.
  - `WithQueryHitMountedBaselineShowrate_ProducesUnitMultiplier` —
    `Showrate=100 * 0.01 = 1.0f` on the non-shortcut branch (exercises the
    derivation even though the result coincides with the default).
  - `WithQueryHitMountedShowrate110_ProducesOnePointOneMultiplier` — **the
    Slice-20→22 regression sensor:** `Showrate=110 * 0.01 = 1.10f`. This is
    the first observable non-default multiplier value that the whole
    Slice-20 pipeline was built to carry.
  - `WithPreferredPathActive_QueryColorIsZero` — two records in the same
    bucket, one with `PackedColor=0` and one with `(100,100,100)`. Preferred
    path should pick the zero-color record (exact match against `queryColor=0`).
  - `WithAppearanceRefreshSourceIdThree_FallsBackToPrimaryAndColor` —
    inhibits preferred path; store falls back to `primarySourceId * 100 + plus`
    bucket and queries with `MountColorIdentity`. The color-matched record
    wins over the `PackedColor=0` record.
  - `WithZeroPreferredSourceId_FallsBackToPrimaryAndColor` — second half of
    the gate: `preferredSourceId=0` alone forces the primary path regardless
    of `AppearanceRefreshSourceId`.
  - `BucketKeyConstruction_MatchesBaseTimesHundredPlusLevel` (`[Theory]`,
    3 rows) — pins `bucketKey = base * 100 + plus` with `(base,plus)` ranging
    over `(7,0)`, `(7,42)`, `(1234,56)`, each verified against a
    pre-computed `sectionId` that round-trips to the expected bucket via
    `MountTypeDatRecord.ComputeBucketKey`.

### BNinja renames applied this slice

None — the remaining native code was already fully mapped by Slices 17/18/20/21.
Slice 22 is purely a managed-wiring slice.

## Local equipment/status writer and production frame step 14

The local hero now has a shared `RoleMountedActionScaleState` populated from
equipment and status ingress, rather than only from the remote-spawn projection.
The relevant v5517 facts are:

- `CRole__Init` (`0x64D260`) initializes `CRole+0x44 = 100`,
  `CRole+0x4C = 50`, `CRole+0x118 = 0`, `CRole+0x128 = 0`, and
  `CRole+0x188 = 1.0f`.
- `CHeroItem__SetEquipSlot` (`0x6DA906`) refreshes the mount tuple after either
  equipment slot 12 (Steed) or 17 (SteedArmor) changes. The primary source is
  the Steed item type; the preferred source is the SteedArmor item type; the
  plus key comes from `CItem+0x61`; the primary color comes from `CItem+0x14C`.
- `CMsg1008__Process` writes packet byte `+33` to `CItem+0x61` and packet dword
  `+20` to `CItem+0x14C`. Packet byte `+34` is a different field and is not the
  mount lookup plus level.
- `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`) always writes
  `record[1]` to `CRole+0x44` and `record[2]` to `CRole+0x4C` on a query hit.
  It applies `record[0]` through the interval setter only while status bit
  `0x32` is active. A query miss preserves the previous cache and interval.
- `Role_ApplyStatusFlagBitfieldAndDispatchEffects` (`0x6729B5`) applies
  `record[0]` on the rising edge of bit `0x32`. On the falling edge it clears
  only after a successful record query. Exit variants 0 and 1 clear; variant 2
  clears only when the incoming replacement status word also has bit 5 or
  bit `0xA`. Every falling-edge path resets the variant to 0.
- `Role_SetMountedActionFrameIntervalAndRefreshActionScale` writes the requested
  interval to cached `CRole+0x118` because the initialized cache-enable byte
  `CRole+0xE0` is 1. It then checks `CHero_GetIdleState` (`0x650447`): while
  idle, the effective interval is forced to zero before `CRole+0x128`,
  `CRole+0x314`, and `CRole+0x188` are written, while the requested nonzero
  cache at `CRole+0x118` remains available for idle exit. When not idle, the
  requested/effect-adjusted interval becomes the active interval normally.

Managed ingress refreshes this state after `MsgUserInfo`, `Msg1008`, and
equipment-changing `MsgItem` packets and applies the exact bit-`0x32` edge
semantics after `MsgUserAttrib`. `RuntimeServices` reuses that same instance
for command-state, idle, diagnostics, and rendering. The production pre-map
service now runs frame step 14
(`CHero_TickPreFrameAutoRunAndIdleDecision`, `0x65CC70`) before frame step 15.

### Remaining boundary

The status-exit variant is modeled, but the managed producers that set variants
1 and 2 from their respective interaction/effect paths are not wired yet. The
interval setter also searches a per-role auxiliary collection keyed by
`CRole+0xCC` and replaces the requested interval with a positive entry field
`+0x38` when one exists (`0x6E5E91..0x6E5EC9`). That auxiliary owner's exact
semantics and producers remain unresolved, so managed currently preserves the
base mounttype interval when no such override is represented. The
full pre-map composite is also not activated: concrete native-parity work for
steps 16 and 17–22 remains separate. Production intentionally activates only
the completed step-14/step-15 subset.
