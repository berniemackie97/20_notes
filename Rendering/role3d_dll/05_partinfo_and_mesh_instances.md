# `Role3D.dll` — `PartInfo` and the per-part "mesh instance" interface

The internal `PartInfo` container `Role3D.dll` uses to manage a set of renderable "parts" (sub-meshes), and the virtual-method interface it expects each part to expose.

`PartInfo` is the implementation detail behind:
- `I3DRole` (multi-part "role" objects)
- `Simple3DObj` (single-model "simple object" rendering)

## `PartInfo` responsibilities

`PartInfo` owns a list of part records. At render time, it:

1. Validates that the part is available via `GraphicData.dll` (`GameDataSetQuery`).
2. Resolves/caches a per-part "mesh instance" pointer (stored in the part record).
3. Optionally applies a per-part "state/offset" value (only when a per-part dirty flag is not set).
4. Calls the mesh instance's render method with a set of integer render parameters.

After iterating all parts, it clears two per-part byte flags and then invokes the "effects + render" stage.

### Record-list mutation from game data

`PartInfo` is not limited to the records loaded by the initial `I3DRole_LoadPartByName(...)` call.
Two verified helpers mutate the existing record list in place:

- `PartInfo_AddRecordsFromGameData(sourcePartName, sourceId)` (`0x10005920`)
- `PartInfo_RemoveRecordsFromGameData(sourcePartName, sourceId)` (`0x100059C0`)

Both helpers query `GameDataSetQuery()->vtable+0x54(sourcePartName, sourceId)` for additional
part-record payloads. The add path appends returned records into the current `PartInfo` arrays
(up to the verified native cap of four records total). The remove path finds matching record
headers, clears them, compacts the surviving records down, and updates the same in-place count.

This is the verified storage model behind `PlayerRoleView_SetHeadAttachmentSource`:

- `I3DRole_AddPartRecordsFromGameData("body", "head", sourceId)`
- `I3DRole_RemovePartRecordsFromGameData("body", "head", sourceId)`

So the player-role head attachment is rendered as extra `"head"` records inside the existing
`"body"` `PartInfo`, not as a separate top-level `I3DRole` part entry.

### Render loop entry point

The main part-render loop lives in `PartInfo_RenderAllParts` (`0x10005EB0`).

At a high level, it iterates `partCount = this[64]` part records and for each record:

- Calls `GameDataSetQuery()->vfn_24(partId, 0, 0)` and skips the part if the return value is `0`.
- Resolves `mesh = part.meshInstance` or, if null, `mesh = PartInfo_ResolvePartMesh(part.partModelId)` (`0x10006820`).
- If `mesh != 0`:
  - If `partDirtyFlag == 0`, calls `mesh->vfn_96(partStateOrOffset, 0)`.
  - Chooses two render parameters:
    - If `a5 == -1`, uses `part.defaultA5`, else uses caller-provided `a5`.
    - If `a6 == -1`, uses `part.defaultA6`, else uses caller-provided `a6`.
  - Calls `mesh->vfn_84(a2, a3, a4, resolvedA5, resolvedA6, a7, a8)`.
- Clears two per-part byte flags (one at `+248` and one at `+252` relative to the start of the per-part flag arrays).

After all parts:
- Calls a small cleanup virtual on an internal member at `this + 33`.
- Calls `PartInfo_TickEffectsAndRender` (`0x10008B80`).

## Resolving mesh instances (`PartInfo_ResolvePartMesh`)

`PartInfo_ResolvePartMesh` (`0x10006820`) resolves the per-part "mesh instance" pointer by calling into `GraphicData.dll`:

1. `ds = GameDataSetQuery()`
2. `record = ds->vfn_116(partModelId, this[61])`
3. `ds = GameDataSetQuery()` (queried again)
4. `mesh = ds->vfn_20(record, 0, 0)`
5. returns `mesh`

This establishes a concrete dependency chain:
- Role3D part resolution is mediated by the `GraphicData.dll` `GameDataSetQuery` interface.
- The actual "mesh instance" pointer is returned by a `GraphicData.dll` virtual method (vtable offset `+20`).

## The per-part "mesh instance" virtual interface (as used by `Role3D.dll`)

`Role3D.dll` treats each part's `meshInstance` as an object with a vtable and invokes the following slots (vtable byte offsets shown):

### Iterating per-submesh bounds for hit-testing

`PartInfo_ProbeRayIntersectsAnyPart` (`0x10006210`) uses the mesh instance as an iterator over submeshes:

- `count = mesh->vfn_48()` returns the number of sub-items.
- For `index` in `[0, count)`:
  - If `mesh->vfn_8(index) == 0` (not skipped):
    - `mesh->vfn_52(index, outMinVec3, outMaxVec3)`
    - Performs a ray-vs-AABB style test against those bounds.

### Applying primary motion and frame positions

`PartInfo_SetPrimaryFrameForAllPartMeshes` (`0x10005CF0`):
- Iterates every part record and resolves its mesh through the normal cached-field /
  `PartInfo_ResolvePartMesh` path.
- Calls mesh virtual `+0x4C(primaryFramePosition)` for each resolved mesh.

`PartInfo_SetMotionForAllPartMeshesOrResetPerPartState` (`0x10006070`):
- With a non-null tracker, iterates every part record and calls mesh virtual
  `+0x38(motionTracker)`.
- With a null tracker, calls `PartInfo_ResetPerPartState` (`0x10006750`).

`PartInfo_SetPrimaryAndSecondaryFramesForAllPartMeshes` (`0x10006140`):
- Iterates every part record and resolves its mesh through the same path.
- Calls mesh virtual `+0x3C(primaryFramePosition, secondaryFramePosition)` for each
  resolved mesh.

The earlier `PartInfo_SetMeshOrDefault` / `PartInfo_SetParamPairAllParts` labels for
`0x10006070` and `0x10006140` were incorrect. The call sites and C3DObjX vtable targets
prove these are motion/frame fan-out helpers.

### Applying motion tracker + explicit sample frame

`PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes` (`0x100060D0`):
- If `motionTracker == 0`, calls `PartInfo_ResetPerPartState(partInfo)` (`0x10006750`) and returns `1`.
- Else iterates all part records (`partCount` at `partInfo+0x100`, ids at `partInfo+0x104`).
- Resolves mesh pointer from cached field (`record+0x70`) or `PartInfo_ResolvePartMesh`.
- Calls mesh virtual `+0x9C`:
  - `mesh->vfn_0x9C(motionTracker, primaryFramePosition)`
- Returns `1` even when some/all meshes are unresolved (no failure short-circuit).

Disassembly evidence:
- `0x1000611E: call dword [edx+0x9c]`
- arguments prepared from wrapper inputs at `0x10006114..0x1000611C`

`PartInfo_SetBlendMotionAndSecondaryFrameForAllPartMeshes` (`0x100061A0`):
- Iterates all part records with the same mesh resolution path as above.
- Calls mesh virtual `+0xA0`:
  - `mesh->vfn_0xA0(motionTracker, secondaryFramePosition, blendAlpha)`
- Returns `1` unconditionally after iteration (including zero-part case).

Disassembly evidence:
- `0x100061E0: call dword [edx+0xa0]`
- pushes at `0x100061D7..0x100061DE` show `(motionTracker, frame, blendAlpha)` call shape.

`PartInfo_ResetAllMeshSubmeshColorAndMatrices` (`0x100065D0`):
- Iterates all part records and resolves each C3DObjX mesh through the normal cached
  field / `PartInfo_ResolvePartMesh` path.
- Calls mesh virtual `+0x68`, identified in `graphic.dll` as
  `C3DObjX_ResetAllSubmeshColorAndMatrices` (`0x10004660`).
- The C3DObjX method iterates every PHY submesh, calls
  `Phy_SetColor(1.0f, 1.0f, 1.0f, 1.0f)`, then `Phy_ClearMatrix`.
- This path does not bind a motion tracker and does not update animation frames.

`PartInfo_ResetPerPartState` (`0x10006750`):
- Iterates all part records and resolves mesh from cached field (`record+0x70`) or `PartInfo_ResolvePartMesh`.
- Queries `GameDataSetQuery()->+0x24(partModelId)`; on hit reads pointer at `+0x08` (default motion tracker).
- If default motion tracker is non-null, calls mesh virtual `+0x38`:
  - `mesh->vfn_0x38(defaultMotionTracker)` (maps to `graphic.dll::C3DObjX_SetMotion`).
- If `+0x24` lookup fails or `record+8` is null, native logs and continues.
- Function returns after full iteration; no per-part failure return path.
- This default-motion reset is distinct from the render-state reset at `0x100065D0`.
  `PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes` reaches it only when its requested
  motion tracker is null.

Cross-reference evidence:
- `I3DRole_SetPartMotionAndPrimaryFrameByName` (`0x100026B1`) calls `0x100060D0`.
- `I3DRole_SetPartBlendMotionAndSecondaryFrameByName` (`0x100026E5`) calls `0x100061A0`.

Parity implication:

- any extra records appended through `PartInfo_AddRecordsFromGameData(...)` participate in the
  same motion/bone/frame dispatch loop as the base records already loaded for that part entry.
- these `PartInfo` fan-out setters only prove that motion/blend state is written onto each
  resolved mesh instance through `C3DObjX_SetMotionAndPrimaryFrame` /
  `C3DObjX_SetBlendMotionAndSecondaryFrame`
- for static body-family meshes, the later `graphic.dll` render path still chooses the CPU
  branch (`C3DObjX_Render -> Phy_Calculate_Lite -> Phy_DrawNormal_CPU`), so the bound motion
  state is consumed by linked motion-chain sampling and world-matrix setup, not by per-vertex
  skinning of the body mesh itself

### Rendering

`PartInfo_RenderAllParts` (`0x10005EB0`) calls:
- `mesh->vfn_96(partStateOrOffset, 0)` (only when a per-part dirty flag is not set)
- `mesh->vfn_84(a2, a3, a4, a5, a6, a7, a8)` (per-part draw call)

Parity implication:

- any extra records appended into a `PartInfo` are rendered as part of the same named `I3DRole`
  part draw. For the player head-attachment path, drawing `"body"` therefore draws both the
  base body records and any attached `"head"` records currently stored in the same `PartInfo`.

## What's intentionally not assumed here

This document describes only what `Role3D.dll` itself does and the *exact* virtual-call shapes it performs.

In the stock client, the mesh-instance object returned through `GraphicData.dll` is constructed via `graphic.dll!MeshCreate(...)` and is the `C3DObjX` object documented in `analysis/conquer_docs/Rendering/graphic_dll/12_meshcreate_and_c3dobjx.md`.

## Rewrite mapping (2026-03-04)

Managed parity runtime introduced for this call surface:

- `10_work/src/Conquer/Graphics/IRole3DPartMeshMotionRuntime.cs`
  - mirrors mesh vtable slots `+0x38`, `+0x9C`, `+0xA0`.
- `10_work/src/Conquer/Graphics/C3DObjXPartMeshMotionRuntime.cs`
  - adapter for `C3DObjXMotionBindingRuntime`.
- `10_work/src/Conquer/Graphics/Role3DPartInfoMotionRuntime.cs`
  - mirrors `PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes`,
    `PartInfo_SetBlendMotionAndSecondaryFrameForAllPartMeshes`,
    and `PartInfo_ResetPerPartState`.
- `10_work/src/Conquer/Graphics/Role3DRolePartMotionInterfaceRuntime.cs`
  - mirrors `I3DRole` slot wrappers by part name.
- `10_work/src/Conquer/Graphics/RolePartMotionTrackerFrameRecords.cs`
  - managed slot-43/slot-44 record inputs.
- `10_work/src/Conquer/Client/Role3DClientRoleRuntime.cs`
  - non-baseline client host that applies RoleView part-tracker sets through the interface.
- `10_work/src/Conquer/Client/Role3DClientRolePlaybackRuntime.cs`
  - non-baseline per-tick orchestration layer for action feed, transition state,
    primary-frame sampling, and part-name motion dispatch.
