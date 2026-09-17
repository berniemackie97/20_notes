# `Simple3DObj` object (Role3D)

The object `Simple3DObjCreate` returns, and the vtable methods `RoleView.dll` uses on it.

## Construction

- `Simple3DObjCreate` allocates 0x54 bytes and calls `Simple3DObj_Ctor` (`0x100069E0`).
- The ctor stores the vtable pointer `g_Simple3DObj_Vtbl` (`0x1001D2F4`) at `[this+0]`.

## VTable (`g_Simple3DObj_Vtbl` at `0x1001D2F4`)

Slots exercised by `RoleView.dll`:

| Slot | Target | Notes |
|---:|---:|---|
| 0 | `0x10007E60` | destructor (scalar delete pattern) |
| 1 | `0x10007230` | `Simple3DObj_SetModelId_LoadPartInfo` |
| 2 | `0x10006C90` | `Simple3DObj_Render` |
| 3 | `0x10006FF0` | `Simple3DObj_ProbeRayHitTest` |
| 4 | `0x10006C00` | `Simple3DObj_SetTransform_Ints` |
| 7 | `0x10006BC0` | `Simple3DObj_SetEulerAngles` |
| 8 | `0x10007070` | `Simple3DObj_SetRenderState_Offsets` |
| 14 | `0x100078E0` | `Simple3DObj_SetPrimaryFrame` |
| 15 | `0x10007920` | `Simple3DObj_SetMotionAndResetFrames` |

## `Simple3DObj_SetModelId_LoadPartInfo(this, modelId)` (slot 1)

- Frees any existing cached part-info object at `[this+0x48]`.
- Queries `GameDataSetQuery()` for part info by `modelId`:
  - calls `GameDataSetQuery()->vfn_68(modelId)` first
  - if that returns `0`, calls `GameDataSetQuery()->vfn_64(modelId)`
- Allocates a 0x184-byte part-info container and copies the part records from the query result.
- Stores `modelId` into `[this+0x4C]`.
- Returns `1` on success, `0` on failure.

## `Simple3DObj_SetTransform_Ints(this, x, y, angleLike, scale, unk)` (slot 4)

Sets core transform fields:

- `[this+0x10] = (float)x`
- `[this+0x18] = (float)y`
- `[this+0x08] = scale`
- `[this+0x04] = 2 * angleLike`
- `[this+0x1C]`, `[this+0x20]`, `[this+0x24]` are all set to `unk`

Returns `angleLike`.

## `Simple3DObj_SetEulerAngles(this, a2, a3, a4)` (slot 7)

Writes three integers into `[this+0x28..0x30]`.

## `Simple3DObj_SetRenderState_Offsets(this, shadowMode, shadowDirX, shadowDirY, shadowDirZ, shadowScalar, a7, a8, a9)` (slot 8)

Stores render parameters:

- `[this+0x40] = shadowMode`
- `[this+0x34] = shadowDirX`
- `[this+0x38] = -shadowDirY`
- `[this+0x3C] = -shadowDirZ`
- `[this+0x44] = shadowScalar`

Ctor defaults at `Simple3DObj_Ctor` (`0x100069E0`) prove the shipped 5517 object starts with:

- `[this+0x40] = 2`
- `[this+0x34..0x3C] = { 0.0f, 0.0f, 1000.0f }`
- `[this+0x44] = 0.3f`

Returns `shadowScalar`.

## `Simple3DObj_SetPrimaryFrame(this, primaryFrame)` (slot 14)

- Requires a non-null `PartInfo` pointer at `[this+0x48]`.
- Calls `PartInfo_SetPrimaryFrameForAllPartMeshes` (`0x10005CF0`).
- That helper iterates every contained mesh and calls its vtable slot `+0x4C` with
  the same primary frame.

## `Simple3DObj_SetMotionAndResetFrames(this, motionTracker)` (slot 15)

- Requires a non-null `PartInfo` pointer at `[this+0x48]`.
- Calls `PartInfo_SetMotionForAllPartMeshesOrResetPerPartState` (`0x10006070`).
  A non-null tracker is forwarded to every mesh through vtable slot `+0x38`;
  a null tracker follows `PartInfo_ResetPerPartState`.
- Calls `PartInfo_SetPrimaryAndSecondaryFramesForAllPartMeshes`
  (`0x10006140`) with both frame arguments set to zero. Every mesh receives
  those values through vtable slot `+0x3C`.

This is the exact bind/reset sequence used by the type-4 `RoleView` standard-NPC path
before subsequent ticks update the primary frame through slot 14.

## `Simple3DObj_ProbeRayHitTest(this, sx, sy, a4, a5)` (slot 3)

- Requires part-info object at `[this+0x48]` to exist.
- If dependencies are ready (`PartInfo_AllDependenciesReady`, `0x10005DF0`), builds a probe ray using `CMyBitmap::ProbeRayBuild`.
- Calls `PartInfo_ProbeRayIntersectsAnyPart(rayPos, rayDir)` (`0x10006210`) and returns its boolean result.

## `Simple3DObj_Render(this, a2, a3, a4, a5)` (slot 2)

- Requires a non-null pointer at `[this+0x48]`.
- If dependencies are ready (`PartInfo_AllDependenciesReady`, `0x10005DF0`):
  - calls `CMyBitmap::PrepareModle()`
  - builds a scale/rotation/translation matrix using `CMyBitmap::Common_*` helpers
  - calls `PartInfo_BindPerPartTexturesAndMaterial([this+0x48], 0, 0)` before draw
  - calls `PartInfo_RenderAllParts(...)` (`0x10005EB0`) to issue the draw
  - calls `PartInfo_ResetAllMeshSubmeshColorAndMatrices([this+0x48])` (`0x100065D0`)
- Returns `1` on success, `0` otherwise.

Parity implication:

- the post-draw call at `0x100065D0` resets each PHY submesh color to white and clears
  its temporary matrix through `C3DObjX` vtable slot `+0x68`; it does not change motion
  trackers or animation frames
- the copied `primaryTextureId` / `secondaryTextureId` / material streams inside the `PartInfo`
  container are live native draw inputs for `Simple3DObj`; they are not dead serialized payload
- any managed standard-NPC simple-object render path must therefore honor
  `RolePartResolvedPart.PrimaryTextureId` when no stronger runtime texture override exists
