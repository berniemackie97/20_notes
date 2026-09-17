# `I3DRole` object (Role3D)

This document describes the object returned by `I3DRoleCreate()` and the subset of its interface that is currently verified.

## Construction

- `I3DRoleCreate` allocates `0x3C` bytes and constructs via `I3DRole_Ctor` (`0x10001060`).
- The ctor first initializes an internal vtable `off_1001D23C`, then switches the object vtable to `g_I3DRole_Vtbl` (`0x1001D180`).

The ctor also initializes a process-wide container rooted at `dword_10022D74` (guarded by `std::_Lockit`) and uses it to allocate/insert nodes used by parts/effects.

## VTable (`g_I3DRole_Vtbl` at `0x1001D180`)

First 16 slots (decoded):

| Slot | Target | IDA name |
|---:|---:|---|
| 0 | `0x10004800` | `I3DRole_Release_Thunk_Return0` |
| 1 | `0x10003870` | `I3DRole_ProbeRayHitTest` |
| 2 | `0x10002CB0` | `I3DRole_IsPartLoadedAndReady` |
| 3 | `0x100035D0` | `I3DRole_RenderPartByName_WithMotions` |
| 4 | `0x10002790` | `I3DRole_LoadPartByName` |
| 5 | `0x10002C50` | `I3DRole_AddPartRecordsFromGameData` |
| 6 | `0x10002C80` | `I3DRole_RemovePartRecordsFromGameData` |
| 7 | `0x10002740` | `I3DRole_SetPartTransformMatrixOrReset` |
| 8 | `0x10002E20` | `I3DRole_RemovePartByNameOrClearAll` |
| 9 | `0x10002FA0` | `I3DRole_HasPartByName` |
| 10 | `0x10002250` | `I3DRole_SetPartTexturePaths` |
| 11 | `0x10002620` | `I3DRole_SetPartMeshOrDefault` |
| 12 | `0x10002700` | `I3DRole_ApplyDefaultMeshesFromObjInfo` |
| 13 | `0x10002660` | `I3DRole_SetPartParamPair` |
| 14 | `0x10002720` | `I3DRole_ResetPartRenderStateByName` |
| 15 | `0x10004820` | `I3DRole_StoreShadowRenderParameters` |

Additional verified slots in the same vtable block:

| Slot | Offset | Target | IDA name |
|---:|---:|---:|---|
| 17 | `+0x44` | `0x10001970` | `I3DRole_BindPerPartTexturesAndMaterial` |
| 18 | `+0x48` | `0x10001B00` | `I3DRole_ApplyMeshLevelOperationToPartsOrNamed` |
| 19 | `+0x4C` | `0x10001770` | `I3DRole_ApplyColorToAllParts` |
| 22 | `+0x58` | `0x10001E20` | `I3DRole_EnsurePartEffectInstanceByName` |
| 23 | `+0x5C` | `0x10001FB0` | `I3DRole_RemovePartEffectInstanceByName` |
| 24 | `+0x60` | `0x10003CC0` | `I3DRole_HasPartEffectInstanceByName` |
| 26 | `+0x68` | `0x10002B60` | `I3DRole_RefreshAllPartEffectVisualTrackConfigs` |
| 28 | `+0x70` | `0x10003950` | `I3DRole_ProbeRayHitTestByScreenCoords` |
| 30 | `+0x78` | `0x10003E70` | `I3DRole_GetPartEffectProducer` |
| 43 | `+0xAC` | `0x10002690` | `I3DRole_SetPartMotionAndPrimaryFrameByName` |
| 44 | `+0xB0` | `0x100026C0` | `I3DRole_SetPartBlendMotionAndSecondaryFrameByName` |

Evidence:

- PE/vtable decode from `g_I3DRole_Vtbl` (`0x1001D180`) confirms:
  - slot 17 `+0x44` -> `0x10001970`
  - slot 22 `+0x58` -> `0x10001E20`
  - slot 23 `+0x5C` -> `0x10001FB0`
  - slot 24 `+0x60` -> `0x10003CC0`
  - slot 26 `+0x68` -> `0x10002B60`
  - slot 30 `+0x78` -> `0x10003E70`
- vtable hexdump at `0x1001D220`:
  - `0x1001D1E8 = 0x10002B60`
  - `0x1001D22C = 0x10002690`
  - `0x1001D230 = 0x100026C0`
- xrefs:
  - `0x10001970` data xref at `0x1001D1C4`
  - `0x10002B60` data xref at `0x1001D1E8`
  - `0x10002690` data xref at `0x1001D22C`
  - `0x100026C0` data xref at `0x1001D230`

## `I3DRole_ApplyMeshLevelOperationToPartsOrNamed(this, value, partNameOrNull)` (slot 18)

Applies a per-mesh operation either to one named part or to every loaded part:

- if `partNameOrNull == 0`: iterates the internal part map and, for every entry whose
  associated `Role3DObject` pointer is non-null, calls
  `Role3DObject_ApplyMeshLevelOperationToAllMeshes(role3dObject, value, 0)`
- if `partNameOrNull != 0`: resolves that one named part entry and calls the same helper
  on its `Role3DObject`

`Role3DObject_ApplyMeshLevelOperationToAllMeshes` (`0x100066F0`) iterates every mesh
instance inside the `Role3DObject` and:

- calls each mesh's vtable slot `+0x60` (verified target
  `C3DObjX_SetTextureShaderDescriptor` at `0x10007250` in graphic.dll) with `(value, 0)`
- writes a dirty marker byte at `role3dObject + 0xFC + meshIndex = 1`

`C3DObjX_SetTextureShaderDescriptor(textureShaderMode, textureShaderParameter)`:

- if `textureShaderMode > 0`, stores it at `C3DObjX+0x04`
- otherwise stores default mode `4`
- stores `textureShaderParameter` at `C3DObjX+0x08`

So the wrapper writes the texture-shader descriptor `(value or 4, 0)` to every mesh
of every part of the role and marks each part for the associated one-shot state path.

Verified caller from `RoleView.dll`:

- `PlayerRoleView_SetPropertyByKey` case `0x20` calls slot `+0x48` as
  `(value, 0)` (i.e. apply value to all parts).

## `I3DRole_ProbeRayHitTestByScreenCoords(this, screenX, screenY, hitDataOut, partNameOrNull)` (slot 28)

Builds a probe ray from screen coordinates and tests it against role parts:

- `CMyBitmap::ProbeRayBuild(screenX, screenY, &rayOrigin, &rayDir)` constructs the world-space ray
- if `partNameOrNull != 0`: resolves the one named part via `PartMap_FindEntryByName`
  and tests only that part using `PartInfo_ProbeRayIntersectsAnyPart(rayOrigin, rayDir)`
- if `partNameOrNull == 0`: iterates the entire part map and tests each part with
  the same helper, returning `1` on the first hit
- returns `1` on hit, `0` on miss

Verified caller from `RoleView.dll`:

- `PlayerRoleView_GetPropertyByKey` case `0x31` calls slot `+0x70` as
  `(this+0xB4, this+0xB8, &outHit, 0)` to test whether the cached screen coordinates
  hit any loaded part of the role.
- The screen coordinates are written by setter keys `0x32` (X) and `0x33` (Y).

## `I3DRole_BindPerPartTexturesAndMaterial(this, primaryRecord, secondaryRecord, partNameOrNull)` (slot 17)

- if `partNameOrNull == 0`, iterates every loaded part and calls
  `PartInfo_BindPerPartTexturesAndMaterial(partInfo, primaryRecord, secondaryRecord)`
- if `partNameOrNull != 0`, resolves that one named part and applies the same bind helper
- verified `RoleView.dll` pairing:
  - `RoleView_BindPartTextureAndMaterialFromSourceIds`
  - resolves both source ids through `GameDataSetQuery()->+0x18`
  - then calls slot `+0x44`

`PartInfo_BindPerPartTexturesAndMaterial` (`0x10006620`) proves the default
file-backed path:

- a null primary override resolves `PartInfo+0x114[partIndex]` and calls the
  C3DObjX `+0x58` primary-texture setter;
- a null secondary override resolves `PartInfo+0x124[partIndex]` and calls the
  C3DObjX `+0x5C` mix-texture setter;
- `PartInfo+0x144[partIndex]`, when non-null, is applied through C3DObjX
  vtable `+0x64`, proven in `graphic.dll` as
  `C3DObjX_SetMaterial(C3DObjX*, const D3DMATERIAL8*)`;
- `I3DRole_RenderPartByName_WithMotions` calls the helper with both overrides
  null immediately before rendering.

Thus the normal role path consumes both texture IDs serialized in each MESH part
descriptor. A zero secondary ID resolves to no texture; it is not replaced with
the primary texture.

`PartInfo_LoadFromGameData` (`0x100057A0`) obtains the `0x74`-byte runtime
role-part model record from `GameDataSet` vtable slot `+0x54` and copies it
verbatim to `PartInfo+0x100`. `GraphicData.dll` has already converted each MESH
`material_index` byte into a `D3DMATERIAL8*`. An in-range index selects that
record; an out-of-range index selects the first material record. If the material
table is empty, the same base pointer is null.

Parity consequence:

- RoleView property cases `0x23..0x26` are texture/material rebinding,
  not part-effect removal through `I3DRole_RemovePartEffectInstanceByName`.

## `I3DRole_LoadPartByName(this, partName, linkedSubmeshName, linkedPartName, sourceId, roleDataLookupIdOrZero)` (slot 4)

This method is part of the “role part” pipeline:

- validates `partName` is non-null
- calls vtable slot `+0x20` (`I3DRole_RemovePartByNameOrClearAll`) with `partName`
  before rebuilding the entry
- allocates a `0x184` part-info container and initializes it (`PartInfo_Ctor`, `0x100056A0`)
- attempts to populate the part-info via
  `PartInfo_LoadFromGameData(partInfo, sourceId, roleDataLookupIdOrZero)` (`0x100057A0`)
- allocates a `0x28` metadata record containing:
  - pointer to the part-info object
  - `linkedPartName`
  - `linkedSubmeshName`
  - a flag byte at offset `+0x24` set to `1`
- inserts the record into an internal map keyed by `partName`

Verified caller usage from `PlayerRoleView_LoadPartSourceIntoI3DRole`:

- body-family loads:
  - `("body" | "mix_body" | "mix2_body", "v_mount", "mount", loadedSource, overrideLookupIdOrZero)`
- helmet-family loads:
  - `("armet" | "mix_armet" | "mix2_armet", "v_armet", "body", loadedSource, overrideLookupIdOrZero)`
- weapon loads:
  - `("r_weapon" | "l_weapon", "v_r_weapon" | "v_l_weapon", "body", sourceId, 0)`
- mount loads:
  - `("mount", "none", "none", sourceId, 0)`
- misc loads:
  - `("misc", "v_misc", "body", sourceId, 0)`

## `I3DRole_AddPartRecordsFromGameData(this, hostPartName, sourcePartName, sourceId)` (slot 5)

- Looks up `hostPartName` in the internal map.
- If found and the entry has a non-null part-info pointer, calls
  `PartInfo_AddRecordsFromGameData(sourcePartName, sourceId)` (`0x10005920`).
- Returns `1` on success, otherwise `0`.

Verified key-2 `RoleView` usage:

- `PlayerRoleView_SetHeadAttachmentSource` removes/attaches `"head"` records on the existing
  `"body"` part entry through:
  - `I3DRole_RemovePartRecordsFromGameData("body", "head", oldSource)`
  - `I3DRole_AddPartRecordsFromGameData("body", "head", newSource)`

## `I3DRole_RemovePartRecordsFromGameData(this, hostPartName, sourcePartName, sourceId)` (slot 6)

- Looks up `hostPartName` in the internal map.
- If found and the entry has a non-null part-info pointer, calls
  `PartInfo_RemoveRecordsFromGameData(sourcePartName, sourceId)` (`0x100059C0`).
- Returns `1` on success, otherwise `0`.

## `I3DRole_SetPartTransformMatrixOrReset(this, partName, matrixOrNull)` (slot 7)

- Validates `partName` is non-null.
- Looks up `partName` in the internal map and requires a non-null part-info pointer.
- Calls `PartInfo_SetMotionMatrixOrReset(matrixOrNull)` (`0x100058C0`) on the part-info.
- Returns `1` on success, otherwise `0`.

## `I3DRole_RemovePartByNameOrClearAll(this, partNameOrNull)` (slot 8)

- If `partNameOrNull` is non-null: finds the matching map entry and releases its associated part-info.
- If `partNameOrNull` is null: iterates all entries and releases their associated part-info, then clears the container.

## `I3DRole_IsPartLoadedAndReady(this, partName)` (slot 2)

- Returns `0` if `partName` is null.
- Looks up `partName` in the internal map.
- Returns `0` if not found or if the part-info pointer is null.
- Returns `1` if the part-info has a non-null first field and `PartInfo_AllDependenciesReady(partInfoFirstField)` (`0x10005DF0`) reports ready.

## `I3DRole_ProbeRayHitTest(this, sx, sy, ..., partIdOrNull)` (slot 1)

- Builds a probe ray via `CMyBitmap::ProbeRayBuild`.
- If `partIdOrNull == 0`: iterates the internal map and tests each loaded part using `PartInfo_ProbeRayIntersectsAnyPart(rayPos, rayDir)` (`0x10006210`).
- If `partIdOrNull != 0`: resolves a part pointer via `PartMap_FindEntryByName(partIdOrNull)` (`0x10002140`) and tests only that part.

## `I3DRole_RenderPartByName_WithMotions(this, partId, motionData, transform, a5)` (slot 3)

Renders a part resolved from `partId`:

- Resolves the part via `PartMap_FindEntryByName(partId)` (`0x10002140`); returns early if not found.
- Builds a transform matrix from `transform` (optionally negates basis vectors depending on a flag at `[this+0x34]`).
- Applies a sequence of motion matrices via `CMyBitmap::Motion_GetMatrix_Blend` and multiplies them into the transform.
- Multiplies an additional 4x4 matrix from `motionData`.
- Calls `CMyBitmap::PrepareModle`, then `PartInfo_RenderAllParts(...)` (`0x10005EB0`) to issue the draw.
- Optionally calls `PartInfo_ResetAllMeshSubmeshColorAndMatrices(part)` (`0x100065D0`)
  when `a5 != 0`.

## `I3DRole_StoreShadowRenderParameters` (slot 15)

`I3DRole_StoreShadowRenderParameters(this, shadowMode, shadowDirX, shadowDirY,
shadowDirZ, shadowScalar, ignored1, ignored2, ignored3)`
at `0x10004820` (calling convention `retn 0x20` — 8 stack args).

Stores 5 of its 8 args into per-`I3DRole` shadow-render cache fields:

| `I3DRole` field | Source | Default (from `I3DRole_Ctor`) | Meaning |
|---:|---|---|---|
| `+0x14` | `arg5` | `0x3E99999A` = `0.3f` | shadow scalar (passed as `C3DObjX_Render` arg4) |
| `+0x18` | `arg2` | `0` (uninit) | shadow direction X |
| `+0x1C` | `arg3` | `0` (uninit) | shadow direction Y |
| `+0x20` | `arg4` | `0xC47A0000` = `-1000.0f` | shadow direction Z |
| `+0x24` | `arg1` (clamped `max(arg1, 1)`) | `2` | shadow mode (`2`/`3`/`4` build a `C3_SHADOW_RENDER_DESC`; else no shadow desc) |

Args `arg6`, `arg7`, `arg8` are popped by `retn 0x20` but not used. The
mesh-level draw overrides and cull selector consumed downstream are separate
`I3DRole` fields:

| `I3DRole` field | Constructor default | Verified meaning |
|---:|---:|---|
| `+0x28` | `UINT32_MAX` | source blend override; sentinel selects the part's MESH byte `+0x0D` |
| `+0x2C` | `UINT32_MAX` | destination blend override; sentinel selects the part's MESH byte `+0x0E` |
| `+0x34` | `0` | tagged-PHY cull selector; zero requests `D3DCULL_CW`, nonzero requests `D3DCULL_CCW` |

### Verified consumer chain (now fully grounded to `C3DObjX_Render`)

`I3DRole_RenderPartByName_WithMotions` (slot 3) calls
`PartInfo_RenderAllParts` (`0x10005EB0`):

```c
PartInfo_RenderAllParts(
    partInfo,
    *(this + 0x24),    // shadowMode
    this + 0x18,       // shadow direction vec3 pointer
    *(this + 0x14),    // shadow scalar
    *(this + 0x28),    // sourceBlendModeOverride (UINT32_MAX = part default)
    *(this + 0x2C),    // destinationBlendModeOverride (UINT32_MAX = part default)
    0,                 // useLiteRenderPath
    *(this + 0x34).b)  // useCounterClockwiseCullMode
```

`PartInfo_RenderAllParts` resolves each part's mesh through
`PartInfo_ResolvePartMesh` (which goes through `GameDataSetQuery()->vtable+0x74`
then `vtable+0x14`). For each part, a `UINT32_MAX` source/destination override
selects the widened MESH-record values in the `PartInfo+0x154[]` and
`PartInfo+0x164[]` arrays. The resolved values and cull selector are forwarded
to **`mesh->vtable+0x54`**.

Immediately before that draw, `mesh->vtable+0x60` receives
`PartInfo+0x134[partIndex]` and parameter `0`. The target is
`C3DObjX_SetTextureShaderDescriptor`, so the MESH `meshStateId` is the native
texture-shader mode. Positive mode `17` reaches `Phy_DrawNormal[_CPU]`
unchanged.

The mesh class is **`C3DObjX`** (graphic.dll). `C3DObjX_Ctor` writes the
vtable address `0x10039504` at `[this+0x00]`, so the C3DObjX vtable starts at
`0x10039504` (one dword past the symbol at `0x10039500`).

C3DObjX vtable slot 21 (`+0x54`) = `0x10004330` = `C3DObjX_Render`
(`retn 0x1c` = 7 stack args), confirmed by data xref to `C3DObjX_Render` at
`0x10039558` (= `0x10039504 + 0x54`).

`C3DObjX_Render(this, shadowMode, shadowDirVec3, shadowScalar, sourceBlendMode,
destinationBlendMode, useLiteRenderPath, useCounterClockwiseCullMode)` does
exactly what the I3DRole field meanings predict:

- compares `shadowMode` against `2`, `3`, `4`; on match, loads
  `shadowDirVec3[0..2]` into a local `D3DXVECTOR3` and calls
  `D3dxShadowRenderDescriptorBuild_DelayLoadThunk` to construct a
  `C3_SHADOW_RENDER_DESC` for the draw call
- constructs a `C3_PIPE_RENDER_DESC` containing `sourceBlendMode`,
  `destinationBlendMode`, forced `depthWriteAndLightingEnabled=1`, and
  `useCounterClockwiseCullMode`, then forwards it with the shadow descriptor to
  `Phy_DrawNormal` / `Phy_DrawNormal_CPU`
- picks the full versus lite calculation path from `useLiteRenderPath`, which this
  Role3D caller supplies as literal zero
- uses the final byte when tagged PHY submeshes select `D3DCULL_CW` versus
  `D3DCULL_CCW`; untagged PHY submeshes use `D3DCULL_NONE`

This pins the slot-15 (`+0x3C`) ABI definitively as the shadow-render-parameter
setter for the role's parts.

### Verified caller from `RoleView.dll`

- `RoleView_SharedSetShadowRenderParameters` (slot 5 of player/Type-2/Type-10
  RoleView, `0x100032BB`) caches its 8 args at `RoleView+0x98..+0xC8` (with
  `arg4`/`arg5` negated), then forwards
  `(arg2, arg3, -arg4, -arg5, arg6, arg7, arg8, arg9)` to
  `I3DRole vtable+0x3C`. The Y/Z negation in the RoleView wrapper is the
  RoleView-coordinate-frame conversion of the incoming light vector before it
  reaches the I3DRole shadow-direction cache.
- The cached fields at `RoleView+0x98..+0xC8` are write-only on the
  `RoleView.dll` side: neither `PlayerRoleView_GetPropertyByKey`
  (`0x10002BFC`) nor `RoleView_SharedRenderComposite` (`0x100038A9`) reads
  them. They are pure ABI cache.

## `I3DRole_ApplyColorToAllParts(this, r, g, b, a)` (slot 19)

`I3DRole_ApplyColorToAllParts` at `0x10001770` (vtable `+0x4C`).

- iterates the internal part map (the same red-black tree walked by slots 1, 8,
  17, 18, etc.)
- for each entry whose `Role3DObject` pointer is non-null, calls
  `Role3DObject_ApplyColorToAllMeshes(role3dObject, r, g, b, a)` (`0x10005B80`)

`Role3DObject_ApplyColorToAllMeshes` (`0x10005B80`):

- iterates every mesh slot in the `Role3DObject` (`role3dObject+0x100` =
  `meshCount`, `role3dObject+0x104` = mesh-slot array base)
- for each slot, prefers the wrapper pointer at `slot+0x70` if present;
  otherwise resolves the underlying mesh via `PartInfo_ResolvePartMesh`
- calls `mesh->vtable+0x24(r, g, b, a)` (4-arg color setter — `retn 0x10`)

### Verified caller from `RoleView.dll`

- `RoleView_SharedSetColorRgba` (slot 6 of player/Type-2 RoleView,
  `0x1000334F`) is a pure forwarder: it reads `I3DRole` at `RoleView+0xD8`
  and dispatches `vtable+0x4C(arg2, arg3, arg4, arg5)`. No fields are cached
  on the RoleView side.

## `I3DRole_HasPartByName(this, partName)` (slot 9)

- Returns `0` if `partName` is null.
- Performs a lookup in the internal map and returns `1` if the entry exists, else `0`.

## `I3DRole_SetPartTexturePaths(this, partName, texPathA, texPathB)` (slot 10)

If `texPathA`/`texPathB` are non-empty and not equal to `""`, stores them into two `std::string` fields associated with the part entry.
If either is null/empty, sets both strings to a default global string.

## `I3DRole_SetPartMeshOrDefault(this, partName, meshIdOrZero)` (slot 11)

- Looks up the part entry; if found:
  - when `meshIdOrZero != 0`, calls a per-part mesh setter on all resolved meshes
  - when `meshIdOrZero == 0`, falls back to `I3DRole_ApplyDefaultMeshesFromObjInfo`

## `I3DRole_ApplyDefaultMeshesFromObjInfo(this, partName)` (slot 12)

- Resolves each part’s mesh and uses `GraphicData` `p3DObjInfo` data to apply a default mesh id where available.

## `I3DRole_SetPartParamPair(this, partName, a2, a3)` (slot 13)

- Applies a pair of integer parameters to all meshes belonging to the part (vtable `+0x3C` on the mesh object).

## `I3DRole_EnsurePartEffectInstanceByName(this, effectName, partNameOrNull, forceCreate)` (slot 22)

- Resolves either a named part entry or, when `partNameOrNull == null`, iterates all part entries.
- For each resolved part entry with a non-null `Role3DObject`, calls
  `Role3DObject_EnsureEffectInstanceByName(effectName, effectOwnerLabel, forceCreate, spawnFlags)`
  (`0x10005FF0`).
- That helper ignores only a null effect name; it does not trim or reject empty text.
- A case-insensitive `"none"` match dispatches producer clear-all.
- Otherwise, a nonzero `forceCreate` or any non-null `effectOwnerLabel` forces creation.
  With both absent, creation is suppressed only by
  `Game3DEffect_HasEffectInstanceByExactName` (`0x1000C5C0`), whose comparison is
  case-sensitive.
- This is a part-attached effect-instance path, not a body-motion or mesh-variant path.

Verified call-site usage:

- `PlayerRoleView_ConfigureRolePartActionEffects` uses slot `+0x58` after it configures the
  per-part effect producer state.

## `I3DRole_RemovePartEffectInstanceByName(this, effectNameOrNull, partNameOrNull)` (slot 23)

- Resolves one named part or, when `partNameOrNull == null`, iterates every loaded part.
- Calls `PartInfo_RemoveEffectInstanceByNameOrClearAll` (`0x10005FC0`) for each target.
- That concrete helper dispatches through the embedded `Game3DEffect` producer at
  `partInfo+0x84`:
  - non-null `effectNameOrNull` -> producer vtable `+0x18`,
    `Game3DEffect_RemoveEffectInstanceByName`
  - null `effectNameOrNull` -> producer vtable `+0x08`,
    `Game3DEffect_ClearAllEffectInstancesAndResetHeader`
- Named removal compares effect names case-sensitively, sends the owner/event-sink
  `+0x10(categoryId)` notification when configured, releases the first match, erases that
  one list entry, and then returns.
- Clear-all sends the same notification for every instance before release, erases the list,
  resets producer fields `+0x04/+0x08` to zero and `+0x0C` to one, restores header
  position/rotation to zero and scale to one, and preserves the local-transform-enabled
  field at `+0x6C`.

Verified call-site usage:

- `PlayerRoleView_ConfigureRolePartActionEffects` clears every effect on a body-family part
  by passing a null effect name and that part name before its role-data lookup loop.
- `PlayerRoleView_RemovePartEffectInstanceBySelectorAndName` maps selectors
  `1/4/6/7/8/9` to `armet/body/r_weapon/l_weapon/mount/misc` and removes a named effect.
- Selector `0x3F` in that RoleView helper passes both names as null, clearing all effects
  from all loaded parts.
- `Conquer.exe` uses this path for `flagmanaim`, `flagmountaim`,
  `WarFlagEscortStatusMount`, `WarFlagEscortStatusNoMount`, and `iarrow_916`.

## `I3DRole_HasPartEffectInstanceByName(this, effectName, partName)` (slot 24)

- Resolves the named part entry.
- Calls `Role3DObject_HasEffectInstanceByName(effectName)` (`0x100067F0`) on the
  underlying `Role3DObject`.
- Returns `0` when the part is missing or when the effect instance is not present.

## `I3DRole_GetPartEffectProducer(this, partName)` (slot 30)

- Resolves the named part entry.
- Returns `Role3DObject_GetEffectProducer(role3DObject)` (`0x10006960`).
- `Role3DObject_GetEffectProducer` is a single `lea eax, [ecx+0x84]` helper, so slot
  `+0x78` returns the embedded per-part effect producer/controller object at
  `role3DObject + 0x84`.
- The returned producer is the same header object consumed directly by
  `Effect_RenderWithContext`; producer header fields are not just setup-time metadata.

### Verified producer methods used by `PlayerRoleView_ConfigureRolePartActionEffects`

When `PlayerRoleView_ConfigureRolePartActionEffects` gets a role-data hit for one layer, it
uses the returned producer like this:

1. `producer + 0x8C` -> `Game3DEffect_SetLocalTransformEnabledFlag(1)`
2. when the role-data record carries custom transform percentages:
   - `producer + 0x30` -> `Game3DEffect_SetScaleForSelection(scaleX, scaleY, scaleZ, -1, 0)`
3. for `body` / `mix_body` / `mix2_body` only:
   - `producer + 0x2C` -> `Game3DEffect_SetRotationForSelection(0, 0, zRadians, -1, 0)`
4. then slot `+0x58` -> `I3DRole_EnsurePartEffectInstanceByName(effectName, partName, 0)`

This is a producer/effect-instance path, not a mesh-variant or resolved-part-selection path.

## `I3DRole_RefreshAllPartEffectVisualTrackConfigs(this)` (verified helper)

Verified internal helper:

- `I3DRole_RefreshAllPartEffectVisualTrackConfigs` (`0x10002B60`)

Behavior:

- iterates all loaded part entries in the `I3DRole` part map
- for each part with a non-null `Role3DObject`, calls
  `Role3DObject_RefreshEffectVisualTrackConfigByName`

Current rewrite boundary:

- the helper exists and is verified
- `get_xrefs_to(0x10002B60)` currently shows no direct code callers, only the vtable/data
  reference at `0x1001D1E8`
- `I3DRole_RefreshAllPartEffectVisualTrackConfigs` is slot `26` / `+0x68` in the
  `I3DRole` vtable
- a raw disassembly sweep over `RoleView.dll` did not surface any `m_pIRole` virtual calls at
  slot `+0x68`
- a wider raw sweep over the live client binaries
  (`Conquer.exe`, `RoleView.dll`, `GameRole.dll`, `Role3D.dll`) found `+0x68` virtual calls
  only in unrelated `Conquer.exe` interface users and internal `Role3D.dll` effect/runtime
  objects, not in the verified `RoleView -> m_pIRole` path
- the current live local-hero render path does not yet have a fully proven caller chain for
  this refresh helper
- managed runtime work should therefore stay bounded to the verified
  `PlayerRoleView_ConfigureRolePartActionEffects` producer/update path until that caller is
  pinned

## `I3DRole_SetPartMotionAndPrimaryFrameByName(this, partName, primaryMotionFrameRecord)` (slot 43)

Resolves `partName` and forwards one verified 8-byte record to `PartInfo`:

`RolePartPrimaryMotionFrameRecord` layout:

| Offset | Type | Meaning |
|---:|---|---|
| `+0x00` | pointer | `motionTracker` |
| `+0x04` | `int32` | `primaryFramePosition` |

Disassembly evidence (`0x10002690`):

- `mov ecx, [esp+0x8]` (record pointer)
- `mov edx, [ecx+0x4]` (frame)
- `mov ecx, [ecx]` (motionTracker)
- `push edx`, `push ecx`
- `call PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes`

Returns `0` when part lookup fails; otherwise returns callee result.

Wrapper return semantics in clean 5517:

- success path returns the `PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes` return byte,
- that callee returns `1` in all observed branches (including null-primary reset path).

## `I3DRole_SetPartBlendMotionAndSecondaryFrameByName(this, partName, blendMotionFrameRecord)` (slot 44)

Resolves `partName` and forwards one verified 12-byte record to `PartInfo`:

`RolePartBlendMotionFrameRecord` layout:

| Offset | Type | Meaning |
|---:|---|---|
| `+0x00` | pointer | `motionTracker` |
| `+0x04` | `int32` | `secondaryFramePosition` |
| `+0x08` | `float` bits | `blendAlpha` |

Disassembly evidence (`0x100026C0`):

- `mov ecx, [esp+0x8]` (record pointer)
- `mov edx, [ecx+0x8]` (blendAlpha bits)
- `mov edx, [ecx+0x4]` (frame)
- `mov ecx, [ecx]` (motionTracker)
- `push blendAlpha`, `push frame`, `push motionTracker`
- `call PartInfo_SetBlendMotionAndSecondaryFrameForAllPartMeshes`

Returns `0` when part lookup fails; otherwise returns callee result.

Wrapper return semantics in clean 5517:

- success path returns the `PartInfo_SetBlendMotionAndSecondaryFrameForAllPartMeshes` return byte,
- that callee returns `1` after iteration (including zero-part case).

## `I3DRole_ResetPartRenderStateByName(this, partName)` (slot 14)

- Resolves the named part and calls
  `PartInfo_ResetAllMeshSubmeshColorAndMatrices` (`0x100065D0`) on its `PartInfo`.
- That helper calls C3DObjX vtable slot `+0x68` for every mesh. The graphic-layer
  implementation restores every PHY submesh color to `(1,1,1,1)` and clears its
  temporary matrix.
- It does not change the active motion tracker or either animation frame. The separate
  `PartInfo_ResetPerPartState` function at `0x10006750` restores default motion and is
  reached by the null-motion branch of
  `PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes`.

## Rewrite mapping (2026-03-04)

- `10_work/src/Conquer/Graphics/RolePartMotionTrackerFrameRecords.cs`
  - managed slot-43/slot-44 record shapes.
- `10_work/src/Conquer/Graphics/Role3DRolePartMotionInterfaceRuntime.cs`
  - part-name wrapper parity for slot `+0xAC` and `+0xB0`.
- `10_work/src/Conquer/Client/Role3DClientRoleRuntime.cs`
  - non-baseline client path applying RoleView trackers through this interface.
- `10_work/src/Conquer/Client/Role3DClientRolePlaybackRuntime.cs`
  - composes RoleView action feed/transition/frame-clock runtimes with
    `Role3DClientRoleRuntime` to mirror per-tick non-baseline action dispatch.
