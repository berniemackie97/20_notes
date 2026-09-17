# `graphic.dll` — `MotionCreate` and the `C3MotionTracker` object

`graphic.dll` provides `MotionCreate(...)`, which constructs the motion container object used by `C3DObjX` to bind per-submesh motions (and optional blend motions) for animated meshes.

## `MotionCreate(...)`

Entry point:
- `MotionCreate` (`0x10004FB0`)

Behavior:

1. Allocates `0x54` bytes from `graphic.dll`’s heap wrapper.
2. Constructs a `C3MotionTracker` instance (`C3MotionTracker_Ctor` at `0x10004A70`).
3. Calls the object’s virtual init method at vtable offset `+0x04` (index `1`) with `(path, enableNameHash)`.
4. If init succeeds (non-zero), returns the object pointer.
5. If init fails (zero), calls the object’s scalar-deleting destructor (`C3MotionTracker_ScalarDeletingDtor`, vtable offset `+0x4C`) with argument `1` and returns `0`.

The init routine and file format are documented in `analysis/conquer_docs/Rendering/graphic_dll/14_motion_file_loading.md`.

## `C3MotionTracker` vtable and method semantics used by the client

`C3MotionTracker`’s primary vtable is `g_C3MotionTracker_Vtbl` (`0x100395AC`).

The following methods are the ones exercised by the mesh object (`C3DObjX`) when binding motions:

### Motion count

`C3MotionTracker_GetMotionCount` (vtable offset `+0x10`, index `4`) → `0x10007140`
- Returns tracker motion slot count at `this+0x04`.

`C3DObjX_SetMotion` and `C3DObjX_SetBlendMotion` require `GetMotionCount() >= submeshCount` and log a debug message when the count is too small.

### Motion-by-index

`C3MotionTracker_GetMotionByIndex` (vtable offset `+0x14`, index `5`) → `0x10007190`
- Returns motion entry pointer at `this+0x08 + index*4`.

`C3DObjX_SetMotion` and `C3DObjX_SetBlendMotion` assign the returned pointers into each submesh/phy record.

### Locking (lifetime / usage guard)

`C3MotionTracker_LockLife` (vtable offset `+0x28`, index `10`) → `0x100071D0`

Inputs:
- `lock` (byte)

Behavior:
- If `lock != 0`: increments counter at `this+0x48`.
- If `lock == 0`:
  - if counter `<= 0`, logs `"Invalid LockLife(false)!"`,
  - otherwise decrements `this[18]`.

`C3DObjX_SetMotion` and `C3DObjX_SetBlendMotion` use this lock handoff explicitly:
- lock incoming tracker with `LockLife(true)`,
- unlock previously-bound tracker with `LockLife(false)`,
- then store new tracker pointer (`this+0xA8` for primary, `this+0xAC` for blend).

### Verified MOTI-to-PHY binding contract (cross-file slice)

#### Slot index mapping rule (fully pinned)

From `C3DObjX_SetMotion` (`0x10003D70`) and `C3DObjX_SetBlendMotion` (`0x10003E10`):

1. capacity gate (before any write):
   - `motionCount = motionTracker->vtable+0x10()` (`C3MotionTracker_GetMotionCount`)
   - compare against `phyCount = this+0x10`
   - fail fast when `motionCount < phyCount` (`0x10003D93..0x10003DB3`, `0x10003E23..0x10003E43`)
2. per-submesh loop uses direct ordinal mapping:
   - `motion = motionTracker->vtable+0x14(i)` (`C3MotionTracker_GetMotionByIndex`)
   - `phy = *(this + 0x14 + i*4)`
   - primary bind: `*(phy+0x40) = motion` (`0x10003DD7`)
   - blend bind: `*(phy+0x44) = motion` (`0x10003E62`)
3. blend path writes motion state:
   - `*(motion+0x18) = blendAlpha` (`0x10003E6E`)
   - `*(motion+0x14) = 0` (`0x10003E76`)

No name lookup/remap exists in these binders; binding is index-to-index (`i -> i`).

#### Stop conditions that determine tracker slot density

From `C3MotionTracker_InitFromMotionFile` (`0x10004AD0`):

- only `MOTI` chunks are loaded (`0x10004B95..0x10004BB8`, `0x10004BC7`)
- first `Motion_Load` failure exits chunk scan immediately (`je 0x10004C6A` at `0x10004BD0..0x10004BD2`)
- loaded motion count increments densely (`count++` at `0x10004C34`) with hard cap `16` (`0x10004C3A..0x10004C3D`)

So tracker slots are always dense `0..motionCount-1`, and `C3DObjX` capacity gating is the sole guard against undersized trackers at bind time.

Clarification (verified cross-file, 2026-03-04):
- `phyCount` here is `C3DObjX` loaded PHY slot count (`this+0x10`), not raw PHY descriptor/chunk count in the file.
- `C3DObjX_Create` can terminate early on first `Phy_Load` failure, so loaded `phyCount` may be lower than parse-visible descriptor count.

#### Rewrite parity mapping (implemented)

- loader-side resolver returns a tracker whenever at least one dense motion slot loads (native init success condition),
- bind-time swap gate enforces native rule `motionCount >= phyCount` before replacing active primary tracker,
- managed `C3DObjXMotionBindingRuntime` now mirrors all verified binder entry points:
  - `SetMotion`
  - `SetBlendMotion`
  - `SetMotionAndPrimaryFrame`
  - `SetBlendMotionAndSecondaryFrame`
  - `SetPrimaryFrameForAllSubmeshes`
  - `SetSecondaryFrameForAllSubmeshes`

#### Frame-update wrappers (`SetMotionAndPrimaryFrame` / `SetBlendMotionAndSecondaryFrame`)

`C3DObjX_SetMotionAndPrimaryFrame` (`0x10003ED0`) preserves the same slot mapping/capacity contract and adds:

- null tracker early-out (`0x10003EDA..0x10003EE0`),
- same-tracker short-circuit to `this->vtable+0x4C(frame)` without lock handoff (`0x10003EE6..0x10003EFF`),
- otherwise: assign `phy[i]+0x40 = tracker->GetMotionByIndex(i)`, call `Phy_SetFrame(phy, frame)`, then lock/unlock/store tracker (`0x10003F3A..0x10003F81`).

`C3DObjX_SetBlendMotionAndSecondaryFrame` (`0x10003F90`) similarly:

- allows null blend tracker (clears `phy[i]+0x44`) (`0x10004008..0x1000400B`),
- applies the same `motionCount >= phyCount` gate only when tracker is non-null (`0x10003F99..0x10003FC9`),
- for non-null tracker: assigns `phy[i]+0x44`, writes `motion+0x18 = blendAlpha`, then `Phy_SetBlendFrame(phy, secondaryFrame)` (`0x10003FDE..0x10003FFF`),
- then performs lock/unlock/store at `this+0xAC` (`0x10004025..0x10004047`).

### Verified motion-channel to bone-application chain (graphic.dll -> c3_core_dll.dll)

This is the fully pinned runtime path from tracker slot index to per-vertex bone deformation:

1. `C3DObjX` binds tracker slot `i` to loaded PHY slot `i`
   - primary: `phy[i]+0x40 = tracker->GetMotionByIndex(i)` (`0x10003DD7`, `0x10003F45`)
   - blend: `phy[i]+0x44 = tracker->GetMotionByIndex(i)` (`0x10003E62`, `0x10003FF2`)
2. frame fan-out writes per-PHY motion sample frame state
   - `Phy_SetFrame(phy, frame)` from:
     - `C3DObjX_SetMotionAndPrimaryFrame` (`0x10003F4E`)
     - `C3DObjX_SetPrimaryFrameForAllSubmeshes` (`0x1000429A`)
   - `Phy_SetBlendFrame(phy, frame)` from:
     - `C3DObjX_SetBlendMotionAndSecondaryFrame` (`0x10003FF9`)
     - `C3DObjX_SetSecondaryFrameForAllSubmeshes` (`0x100042DA`)
3. render loop consumes those fields per submesh
   - `C3DObjX_Render` calls `Phy_Calculate(..., sampleMotion=1, frame=this+0x04)` (`0x100044B3`)
4. skinning path samples only used bones for this PHY
   - `Phy_Calculate_CPU` iterates used-bone vector (`C3Phy+0x154/+0x158`)
   - calls `C3MotionTracker_GetBlendedBoneMatrixAtFrame` per bone (`0x1000C03E`)
5. per-vertex deformation uses skinned source fields
   - bone indices: source `+0x1C` and `+0x18`
   - bone weights: source `+0x24` and `+0x20`
   - element-wise 4x4 blend + position/normal transform

No name-based remap exists anywhere in this path. Runtime contract is strict ordinal slot mapping (`trackerSlot[i] -> phySlot[i] -> bone matrix sample for that PHY`).

### Verified frame/blend state field writes in `C3Motion`

`c3_core_dll.dll` confirms the exact fields consumed by the sampler path:

- `Phy_SetFrame` (`0x1000DEF0`):
  - reads `phy->primaryMotion` (`C3Phy+0x40`)
  - writes `primaryMotion->primarySampleFramePosition` (`C3Motion+0x10`) as unsigned
    `frame % frameCount`
  - writes `0` when `frameCount==0`; returns without writing when the bound motion is null
- `Phy_SetBlendFrame` (`0x1000DF20`):
  - reads `phy->secondaryMotion` (`C3Phy+0x44`)
  - writes `secondaryMotion->secondarySampleFramePosition` (`C3Motion+0x14`) as unsigned
    `frame % frameCount`
  - writes `0` when `frameCount==0`; returns without writing when the bound motion is null
- blend weight feed from graphic binder:
  - `C3DObjX_SetBlendMotion*` writes `motion->blendAlpha` (`C3Motion+0x18`)

The `graphic.dll` bind/fan-out loops invoke these setters once per PHY, so motions with
different frame counts normalize the same incoming frame independently.

`C3MotionTracker_GetBlendedBoneMatrixAtFrame` (`0x10009E70`) then samples:
- primary at `primaryMotion+0x10`,
- secondary at `secondaryMotion+0x14`,
- blends as `(1 - blendAlpha) * primary + blendAlpha * secondary`.

## Destruction

`C3MotionTracker_Dtor` (`0x10004AC0`) unloads all tracked motions and clears the motion count:

- For each motion pointer in `this[2 .. 2 + count)`:
  - calls `Motion_Unload(&motionPtr)`.
- Sets `this[1] = 0`.

The scalar-deleting destructor is `C3MotionTracker_ScalarDeletingDtor` (`0x10004AA0`), which calls `C3MotionTracker_Dtor` and frees the object when the low bit of the destructor argument is set.
