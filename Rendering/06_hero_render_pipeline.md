# Hero Render Pipeline — End-to-End Call Chain

The complete hero/role render path, traced from `Conquer.exe`'s per-frame
tick through RoleView.dll and Role3D.dll down to the D3D8 draw calls.

## Overview

The native hero render pipeline is a three-layer architecture:

1. **Conquer.exe** — owns the `CRole` object, drives per-frame positioning and action
   dispatch, manages the optional offscreen render target path.
2. **RoleView.dll** — owns the `I3DRole` instance, manages named part slots (body,
   helmet, mount, weapons, misc), builds world transform matrices, dispatches
   per-part render calls.
3. **Role3D.dll** — owns part-info containers with resolved PHY submeshes, applies
   motion matrices, binds textures/materials, issues D3D8 draw calls.

## Entry Point: `CHero_Render` (0x65E472)

Called from the map component render dispatcher as the hero's map component tick.

```
CHero_Render(role, mapComponentRenderContext)
  → CHero_TickAndRenderRoleVisuals(role)      // 0x66F7AB
    → pre-render setup helper (0x674601)
    → position/state update helper (0x66F53F)
    → Role_TickAndRender(role)                // 0x64F5F7 — THE MAIN RENDER
    → post-render name/effect helpers (0x675D61 / 0x6700A2)
    → floating text / HP bar helpers (0x6735AC / 0x66FD71)
  → status overlay helper (0x6F7CC0)
  → additional overlay helper (0x663F87)
  → final overlay helper (0x666A20)
```

## Core Function: `Role_TickAndRender` (0x64F5F7)

This 2KB function is the heart of hero rendering. It:

1. **Checks visibility** — `Role_HasStatusFlag(role, 2)`, vtable+0x60 check
2. **Gets screen position** from map projection:
   ```c
   CGameMap_GetProjectionCenterOffsetFromScreenPoint(
       map, role[0xD4], role[0xD5], &outY, &outX);
   ```
3. **Computes position offsets** — action-specific Y offsets (var_1c, var_20),
   adjusts for `role[0xC3]` (verified vertical render offset term).
   - read-side branches are pinned:
     - actions `0x82`, `0x127`, `0x20F` call `Role_GetMotionArcScreenHeightAnchor` (`0x650583`) and `Role_GetTerrainHeightDeltaFromProjectedScreenPosition` (`0x650903`) when status flag `0x1B` is clear,
     - action `0x38E` uses scapegoat offset Y (`role+0x39C`) when scapegoat offset-Y gate flag (`role+0x394`) is clear and current command type is `0x25` (decimal `37`),
     - `role+0x30C` is always folded into both direct-render vertical terms,
     - additional offset Y (`role+0x3A4`) is added only when additional-offset flag (`role+0x3A8`) is nonzero.
   - startup local-hero consequence:
     - the verified command-type-`0x05` idle family selects only:
       - `0x64`
       - `0x65`
       - `0x66`
       - `0x67`
       - `0x12C`
       - `0x1F5`
       - `0x1F6`
     - none of those ids enter the mounted motion-arc branch above, the projected-path facing override set,
       or the target-entity facing override set below
     - with the verified startup defaults (`role+0x30C = 0`, `role+0x3A4 = 0`, `role+0x3A8 = 0`),
       the startup idle path therefore keeps:
       - `elevation = 0`
       - `adjustedProjectionBaseOffsetY = projectionBaseOffsetY`
   - helper call chain verified in BNinja decompile:
     - `Role_GetMotionArcScreenHeightAnchor` (`0x650583`) calls the role vfunc at `+0x10` to fetch the current projected screen point, then dispatches `Map_ComputeMotionArcScreenHeightOffsetFromProjectedPoints` (`0x6505B3`) with:
       - `role+0x194/+0x198`
       - `role+0x19C/+0x1A0`
       - the current projected screen point returned by the vfunc
     - world-entry/spawn commits seed all four of those cached projected-screen fields at once through
       `Role_SetTilePositionAndProjectScreenCoordinates` (`0x6E4C79`):
       - `role+0x194/+0x198 = projectedScreenX/projectedScreenY`
       - `role+0x19C/+0x1A0 = projectedScreenX/projectedScreenY`
     - `Role_GetTerrainHeightDeltaFromProjectedScreenPosition` (`0x650903`) calls `Role_GetMotionArcScreenHeightAnchor`, projects `role+0x350/+0x354` back to tile coordinates, reads the live tile entry, and subtracts map terrain height from the arc anchor result.
     - `Map_ComputeMotionArcScreenHeightOffsetFromProjectedPoints` (`0x6505B3`) computes the exact terrain-aware arc:
       - inverse-project start/end and walk the rounded tile line excluding the source;
       - choose the resolved tile with the greatest tail-link elevation;
       - use `adjustedElevation = tailLinkElevation - baseTileElevation`;
       - `apexHeight = peakAdjusted + trunc(screenDistance / 3) + 20`;
       - place the apex at the projected peak tile only when `peakAdjusted > startAdjusted`, otherwise at the screen midpoint;
       - interpolate endpoint-adjusted elevation to the apex with a half-sine on each side.
     - the terrain delta passed to RoleView is `currentAdjusted - arcAnchor`; the standard
       non-project setter doubles it. The direct screen-Y terms subtract that delta and the arc,
       cancelling the arc displacement back to the terrain anchor while RoleView receives the
       separate vertical transform.
   - verified write-side producers:
     - `CRole__Init` (`0x64D260`) clears all four fields:
       - `role+0x30C = 0`
       - `role+0x39C = 0`
       - `role+0x3A4 = 0`
       - `role+0x3A8 = 0`
     - `CRole__SetVerticalRenderOffset` (`0x650FEE`) writes both current and target vertical render offsets:
       - `role+0x30C = value`
       - `role+0x310 = value`
       - paired getter: `CRole__GetVerticalRenderOffset` (`0x650FDA`)
       - verified callers are effect/status paths at `0x7C5B0F` and `0x7C645E`; this is not currently the startup-local-hero ingress.
     - `CRole__SetVerticalRenderOffsetTarget` (`0x650FE1`) writes only target vertical render offset (`role+0x310`).
       - `Role_TickCommandStateAndDispatchPlayback` (`0x6725ED`) uses this target setter, then smooths current offset
         `role+0x30C` toward `role+0x310` by `±6` each tick.
     - `CRole__SetScapegoatOffsetY` (`0x651266`) is only called from `CScapegoatRole__RefreshTrackedRoleProjectionAndOffsetY` (`0x7333C3`).
       - source value is global `data_96B3A0`, populated at startup from `ini/Info.ini`, section `[Scapegoat]`, key `OffsetY`.
       - shipped asset value in `10_work/assets/5517/ini/Info.ini` is `100`.
     - `CRole__SetAdditionalOffsetYEnabled` (`0x6513A3`) and `CRole__SetAdditionalOffsetY` (`0x6513B0`) are called by Texas NPC actor builders in `TexasNpc.cpp` at `0x7487AF` and `0x748DAB`.
   - managed mirror status:
     - jump actions now compute the terrain-aware arc from the live motion endpoints/cursor and
       map base/tail elevations, then carry the doubled RoleView elevation through projected role
       state, render submission, scene-object state and the final direct render transform;
     - the unrelated `+0x30C`, scapegoat and Texas-NPC write-side producers remain intentionally
       deferred because their verified callers do not land on this local jump lifecycle.
4. **Gets the RoleView** — `role[0xED]` (byte offset `0x3B4`) is the RoleView
   object, created by `RoleViewCreate()` from RoleView.dll.
5. **Calls RoleView vtable methods** to set up transform, action, and render.

### Verified rotation-only helper branches inside `Role_TickAndRender`

The two helper branches immediately after the always-applied vertical terms do **not**
change elevation or projected Y:

- `Role_IsCurrentActionInProjectedPathFacingOverrideSet` (`0x6E4E5F`)
  - actions:
    - `0x82`
    - `0x83`
    - `0x84`
    - `0x8C`
    - `0x127`
    - `0x1FE`
    - `0x20F`
  - when active and `role[7] == -1`, computes `rotationDegrees` from:
    - `role+0x19C - role+0x194`
    - `role+0x1A0 - role+0x198`

- `Role_IsCurrentActionInTargetEntityFacingOverrideSet` (`0x6E506A`)
  - action-id predicate helper:
    `Role_IsActionInTargetEntityFacingOverrideSet` (`0x6E5038`)
  - actions:
    - `0x191..0x199`
    - `0x1D6`
    - `0x208`
    - `0x26C`
  - when active, resolves the tracked target entity and computes `rotationDegrees`
    from target projected position minus `role+0x350/+0x354`

These branches only replace the local `rotationDegrees` term passed into
`RoleView_SharedSetTransformFromCamera`. They do not write `var_1c` / `var_20`,
`elevation`, or `adjustedProjectionBaseOffsetY`.

### Verified Conquer.exe visual-source reapply order

Outside the transform-look override path, native player equipment / appearance state is pushed
through `CRole__ReapplyAllVisualSources` (`0x650AB9`) and
`CRole__ApplyAllVisualSourcesToRoleView` (`0x650AD0`) in this order:

1. `CRole__ApplyHelmetVariantSourcesToRoleView`
2. `CRole__ApplyBodyVariantSourcesToRoleView`
3. `CRole__ApplyLinkedSourceLookupIdToRoleView`
4. `CRole__ApplyHeadAttachmentSourceToRoleView`
5. `CRole__ApplyLeftWeaponSourcesToRoleView`
6. `CRole__ApplyMiscSourceToRoleView`
7. `CRole__ApplyMountSourceToRoleView`
8. `CRole__ApplyRightWeaponSourcesToRoleView`

This matters for startup parity because fresh player-RoleView creation begins with the base body loads
from key `0`, then this reapply chain overrides specific parts. The primary body-variant source
path is therefore part of normal player startup/reapply behavior, not a transform-look-only seam.

### Verified Render-Scale Inputs And Defaults

The live player-RoleView render scale is not a fixed constant. `Role_TickAndRender` multiplies the
current `CRole` fields below before passing the result to `RoleView_SharedSetTransformFromCamera`:

```
scale = (float)role[0x61] * role[0x62] * 0.75f * 0.01f
```

Verified writers for that state in `Conquer.exe`:

- `CRole__Init` (`0x64D260`)
  - `*(role+0x174) = 0` at `0x64D29A`
  - `*(role+0x184) = 100` at `0x64D2A2`
  - `*(role+0x188) = 1.0f` at `0x64D2AA`
- `CRole__SetTransformLook` (`0x650B58`)
  - clear path: `role[0x5D] = 0`, `role[0x61] = 100`
  - apply path: `role[0x5D] = record.AddSize`, `role[0x61] = record.Scale`
- `Role_SetMountedActionFrameIntervalAndRefreshActionScale` (`0x6E5E80`)
  - no action source: `role[0x62] = 1.0f`
  - active source: `role[0x62] = role[0x11] * 0.01f`
  - mounted helper chain:
    - `Role_UpdateMountActionScaleCacheFromRoleState` (`0x6E5E33`)
    - `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`)
    - `Role_QueryMountActionScaleRecord` (`0x6E6045`)
  - currently mirrored managed scope is restricted to the verified clear/reset side effect
    (`Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, 0)`) because the nonzero native writers are
    not all wired from managed ingress yet.

For the currently verified startup/local-hero slice, the native baseline is therefore:

```
transformLookAddSize = 0
bodyScale = 100
scaleMultiplier = 1.0f
computedScale = 0.75f
```

### RoleView Calls from Role_TickAndRender

| Call | VTable Offset | RoleView Method | Parameters |
|------|--------------|-----------------|------------|
| Position | +0x10 | `SharedSetTransformFromCamera` | projectionBaseOffsetX, adjustedProjectionBaseOffsetY, elevation, rotation, scale |
| Action | +0x0C | `UpdateRolePartMotionsForAction` | actionId, 1, 0, null, 0, 0 |
| Frame | +0x04 | `ApplyPropertyByKey` | key=0x0A, frameIndex |
| Shadow params | +0x14 | `SharedSetShadowRenderParameters` | shadowMode, shadowDirX, shadowDirY, shadowDirZ, shadowScalar (Y/Z negated through to I3DRole; consumed by `C3DObjX_Render` shadow descriptor build for modes 2/3/4) |
| Color | +0x18 | `SharedSetColorRgba` | alpha*a, alpha*r, alpha*g, alpha*b |
| Render | +0x28 | `SharedRenderComposite` | caller passes 2 ints, but the player-RoleView implementation renders from the fields already stored by `SharedSetTransformFromCamera` |

Managed parity consequence for the current slice:

- local-hero action/motion playback belongs in the same live render chain as the player RoleView
  transform and draw calls above.
- a playback host created only from CLI motion-lookup arguments is a harness path, not the
  native startup/world-entry orchestration.
- the current startup-local-hero scene-object state already mirrors the verified fresh
  player-RoleView motion lookup fields needed for body/mount/misc/primary-helmet/weapon
  action dispatch, so the live managed playback host can be rebuilt from current scene data
  during the render pass rather than from startup arguments.
- the later property write `ApplyPropertyByKey(key=0x0A, frameIndex)` must remain a separate
  runtime stage even when action-motion lookup misses:
  - action dispatch can reset body-family meshes back to their default bound motion trackers,
  - the subsequent `0x0A` frame push is what advances those already-bound default motions on
    startup-idle frames,
  - omitting that second stage leaves the local hero frozen at bind/frame `0` even though the
    mesh and default motion payloads are present.

### Observed managed-runtime defects (2026-08-29)

A live OpenConquerPublic smoke test confirmed world entry, but also showed that movement and turning
are not yet functionally correct in the reconstructed client:

- clicking a map destination turns the local hero in place but does not translate the hero;
- the visible turn is horizontally inverted (a click to the right produces a left-facing turn); and
- the turn briefly exposes an invalid bind/T-pose-like frame before returning to an animated pose.

These are observations of the managed runtime, not native-client facts and not yet diagnoses. They
invalidate any broad claim that click-to-move, direction presentation, or turn-transition animation
has reached functional parity. The exact fault boundary still requires a dedicated evidence-driven
slice across click projection, direction encoding, command ingress/playback, motion rebinding, and
frame selection.

#### Eliminated as the cause of the inverted turn (2026-09-06)

Three of those five areas are now ruled out for the **horizontal inversion** specifically. Each was
checked against the binary, not reasoned about:

- **Facing rotation formula.** Native is `(-1 - directionIndex) * 45` (`or edi, -1` at `0x64F6CF`,
  `sub edi, [role+0x17C]` at `0x64F6D8`, `imul edi, edi, 45` at `0x64F6E6`). Managed carries the
  same expression in both `Role3DClientSceneMultiPartRenderStage` and
  `PlayerRoleViewDirectRenderTransform`.
- **Rotation matrix convention.** The transform builds `CreateRotationZ`, and `D3DXMatrixRotationZ`
  and `System.Numerics.Matrix4x4.CreateRotationZ` produce identical matrices for the same angle —
  both are row-vector. No negation is missing. A left/right-handed mismatch would have to come from
  the camera, not this rotation.
- **Direction delta tables.** All four managed tables are byte-identical to the binary's, found as
  dword arrays in `.rdata`:

  | Table | VA |
  |---|---|
  | 8-direction ΔX | `0x869EAC` |
  | 8-direction ΔY | `0x869ECC` |
  | 24-direction ΔX | `0x86ABFC` |
  | 24-direction ΔY | `0x86AC5C` |

  Each also appears at further duplicate sites, and the ΔX/ΔY pairs sit adjacent as expected.

- **Screen→tile inverse.** The managed inverse (`tileX = dx/64 + dy/32`, `tileY = dy/32 - dx/64`)
  is the exact algebraic inverse of the verified forward projection
  (`screenX = (tileX - tileY) * 32`, `screenY = (tileX + tileY) * 16`).

That left **command ingress/playback** and **motion rebinding** as the remaining candidates.

#### Found in command ingress: facing was one octant short (fixed 2026-09-06)

`Role_SelectDirectionIndexTowardTile` (`0x6E4ACC`) is
`(Direction_Select8WayFromPoints(role, target) + 1) % 8`. The managed
`RoleCommandType03TargetStaging.SelectDirectionIndexTowardTargetTile` reproduced the octant helper
faithfully but **dropped that `+ 1`**, so every click-derived facing was one octant (45°)
anticlockwise of native.

The `+ 1` is not redundant with the helper's own `+ 7`: `Direction_Select8WayFromDelta`
(`0x61E487`) rotates its raw sector back by one and the caller rotates it forward again, so the
tile-facing result is the raw sector. Its thresholds — `-241`, `-41`, `41`, `241` per 100 units of
slope, the tangents of 22.5° and 67.5° — match the managed ones exactly, as does every
sector-to-value mapping and both degenerate axes.

`Role_SelectDirectionIndexTowardTargetEntity` (`0x6E4B04`) resolves the target's tile and delegates
to the same function, so the entity path carried the same error.

Independent confirmation, without reference to the decompile: stepping one tile along direction
*d*'s own entry in the verified delta table and asking which direction that was must return *d*.
The pre-fix mapping failed that for all eight directions; the corrected one passes. A round-trip
test now pins it, and the jump-preparation path — which shares the selector — moved from 6 to 7 for
a `(+4, +5)` delta, matching direction 7's `(1, 1)` diagonal rather than direction 6's `(1, 0)`.

This is a genuine facing defect on the click path. Whether it is *the* reported inversion is not
yet established: a 45° error is not a mirror.

#### Every geometric candidate for a mirror is now eliminated

Checked against the binary this pass, in addition to the four above:

- **Rotation composition.** `Common_Rotate` (`C3_CORE_DLL.dll:0x10001450`) is
  `mat = mat * RotX(x) * RotY(y) * RotZ(z)`, a right-multiply chain. Managed builds
  `Scale * Translate * RotZ` in the same order.
- **Rotation matrix sign.** `D3DXMatrixRotationZ` and `Matrix4x4.CreateRotationZ` are the same
  matrix for the same angle — both row-vector, `[cos, sin; -sin, cos]`. No negation is missing.
- **Camera handedness.** Managed uses `CreateLookAtLeftHanded` and
  `CreateOrthographicLeftHanded`, matching D3D8's left-handed convention. A left/right flip would
  need a right-handed camera; there isn't one.

So nothing in the projection, direction-selection, rotation or camera path can mirror the facing.
The one confirmed defect on that path was the missing octant rotation, now fixed.

**The 2026-08-29 observations predate that fix and need re-taking before anything further is
inferred from them.** A facing that was consistently 45° off would be easy to report as "turning
the wrong way", so the inversion may not survive re-observation. If it does, motion rebinding —
which clip and frame get bound for a turn — is the remaining mechanism, and it is not geometric.

#### "Turns but does not translate" — the translation path, traced statically

An earlier version of this section said the remaining question needed a runtime trace. It does not:
the whole chain is readable, and it is now covered by tests.

`RoleCommandStatePerRoleTickPump` commits a role's tile through `TrySetRoleTile` only while
`motionWasActive`, which requires a motion state whose start and end differ. For a ground move the
only writer that makes them differ is
`RoleCommandStateTickSnapshotState.StageGroundMoveStepEndpointsFromPathCursor`, which projects
`ProtectedTile + tileDelta[direction]` into `MotionEndX/Y`.

The pump calls it behind four gates (`PrepareSelectedMovement`):

1. active command type is `0x11` or `0x12`;
2. the selected action is one of the four run actions — `0x6E`/`0x6F` for type 11, `0x78`/`0x79`
   for type 12;
3. `_mapProjectionState` is non-null;
4. `HasInitializedProtectedTilePair && HasInitializedDirection`.

Any one failing leaves facing set by `SetSteeredDirectionIndex` while the tile never advances —
exactly the reported shape. Gate 3 holds in production: `SceneComposition` constructs the pump with
`mapProjectionState: runtimeServices.MapServices.ProjectionState`.

Tests in `tests/Conquer.Tests/Client/RoleCommandStateGroundMoveTranslationTests.cs` pin the staging
for all eight directions — end differs from start, and lands on the tile the direction points at —
plus the pump leaving a role still when nothing has been staged.

**The direction gate is in the pump, not the stager.** `CurrentDirectionIndex` defaults to `0`,
which is a valid index, so calling the stager directly on a role that has never had a direction set
stages a step along direction 0 rather than refusing. A test records that, because a future caller
reaching the stager without the pump's `HasInitializedDirection` check would silently walk the role
one tile.

#### The chain already passes end to end in tests — so the fault is data, not logic

`LocalHeroMovementCommandProcessingTests.MultiFrameType11Walk_...` already drives a full local-hero
walk through the real pump, selector and path service, and asserts the hero arrives at tile
`(12, 10)`. Translation therefore works whenever the inputs the fixture supplies are present.

The fixture supplies a synthetic fully-passable grid: `GridTileLinkNodeSourceRuntime(32, 32)`.
Production instead builds `CGameMapPathService(groundEntityLayerTileAttachmentStore)`
(`MapServicesBuilder`), so the probe resolves against real loaded map data.

That isolates the gate that decides translate-versus-idle. `IsGroundMoveStepWithinElevationLimit`
needs a **tail link node for the destination tile**; without one it returns false, `stepPassed`
stays false, `RoleCommandType11SelectionContext.IsProbeHeightDeltaWithin25` is false, and the
type-11 selector takes its failed-probe branch — dispatching an idle action and marking the command
complete. The role turns and stays put. That is the reported symptom, reached without any logic
error.

`MovementPreparation_WithoutTileLinkNodes_ReportsAFailedHeightProbe` pins exactly that: the same
walk preparation reports a passing probe against a populated grid and a failing one against a grid
whose nodes are absent.

**So the next question is not in the command chain at all** — it is whether the ground entity layer
tile attachment store is populated with tail link nodes for the map the client actually loads. That
is a map-loading question, and it is where this thread should continue.

### Verified Type-1 Transform Input Mapping

BNinja evidence from `Role_TickAndRender` (`Conquer.exe:0x64F811..0x64F854`) and
`RoleView_SharedSetTransformFromCamera` (`RoleView.dll:0x1000327E`) shows the
live player-RoleView path uses the earlier projection-base-offset coordinate space, not the
later scaled-viewport composite point:

```asm
; Conquer.exe:0x64F811
mov  eax, [ebp-0x40]          ; projectionBaseOffsetX
mov  ecx, [esi+0x3B4]         ; RoleView*
sub  eax, [ebp-0x1C]          ; projectionBaseOffsetY - elevation
...
sub  eax, [ebp-0x18]          ; adjustedProjectionBaseOffsetY
...
fld  [ebp-0x28]               ; scale
fld  [ebp-0x30]               ; elevation
push edi                      ; rotation
fld  [ebp-0x34]               ; adjustedProjectionBaseOffsetY
fld  [ebp-0x38]               ; projectionBaseOffsetX
call dword [eax+0x10]         ; RoleView_SharedSetTransformFromCamera

; RoleView.dll:0x10003287
mov [esi+0x04], eax           ; this->screenX = projectionBaseOffsetX
mov [esi+0x08], eax           ; this->screenY = adjustedProjectionBaseOffsetY
mov [esi+0x0C], eax           ; this->elevation = elevation (or doubled in ortho path)
mov [esi+0x18], eax           ; this->rotation = rotationDegrees
mov [esi+0x1C], eax           ; this->scale = computedScale
```

Verified argument meanings at this call-site:

| RoleView arg | Native value | Notes |
|---|---|---|
| `this+0x04` | `projectionBaseOffsetX` | `CGameMap_GetProjectionCenterOffsetFromScreenPoint(role+0x350, role+0x354).x` |
| `this+0x08` | `adjustedProjectionBaseOffsetY` | base-offset Y minus the verified per-action/per-role vertical terms |
| `this+0x0C` | `elevation` | separate vertical term used by Matrix A translate-Z |
| `this+0x18` | `rotationDegrees` | facing angle, normally `(0xFFFFFFFF - role[0x5F]) * 45` unless target/turn helpers override it |
| `this+0x1C` | `scale` | see `09_role_scale_formula.md` |

The unsigned-looking `0xFFFFFFFF` is the x86 representation of signed `-1`: the baseline
formula is `(-1 - directionIndex) * 45`. In `Role_TickAndRender`, `or edi, -1` at `0x64F6CF`,
`sub edi, [role+0x17C]` at `0x64F6D8`, and `imul edi, edi, 45` at `0x64F6E6` prove the complete
calculation before the optional projected-path and target-facing overrides.

### Two Render Paths

**Direct render** (`role[0x108]` == 0 or 2):
- Calls vtable+0x10 (position), +0x0C (action), +0x04 (frame)
- Calls vtable+0x14 (shadow render parameters), +0x18 (color)
- Calls vtable+0x28 (`SharedRenderComposite`) to draw

### Verified Direct-Render Camera Dependency

The live player-RoleView render path does not use a viewport-centered camera after the map has
been projected. The camera is already built earlier in the world-frame chain:

- `Exe_TickMapProjectionAndDispatchMapRender` calls
  `CGameMap_UpdateProjectionAndCameraFromScreenCenter` at `0x5ACB4A`
- `CGameMap_UpdateProjectionAndCameraFromScreenCenter` calls
  `CGameMap_UpdateGameCameraFromProjectionCenter` at `0x61E30D`
- `CGameMap_UpdateGameCameraFromProjectionCenter` computes:
  - `camX = GetScreenWidth()*0.5f + (projectionCenterX - originX)`
  - `camY = GetScreenHeight()*0.5f + (projectionCenterY - originY)`
  - `camZ = -1000.0f`
  - `mode = 3`
- it dispatches `CMyBitmap::GameCameraSet(camX, camY, -1000.0f, 3)` at `0x61E73D`

BNinja verification in `graphic.dll`:

- `CMyBitmap::GameCameraSet` (`0x1000F0C0`) writes the orthographic camera state,
  then tail-calls `CMyBitmap::GameCameraBuild()` (`0x1000F155`)
- for orthographic mode (`g_GameCameraProjectionModeFlag == 0`) with mode bitmask `3`:
  - eye = `(camX, camZ, camY)` = `(camX, -1000.0f, camY)`
  - target = `(camX, 0, camY)`
- `CMyBitmap::GameCameraBuild(CMySize)` (`0x1000EF20`) then rebuilds the current
  view/projection matrices from that stored camera state

Consequence for managed parity:

- `RoleView_SharedSetTransformFromCamera` receives projection-base offsets in the
  role-local anchor space
- `RoleView_SharedRenderComposite` draws those world matrices through the current
  `CMyBitmap` orthographic camera
- once the role anchor is corrected to projection-base offsets, a renderer that still
  synthesizes `eye=(W/2,-1000,H/2)` and `target=(W/2,0,H/2)` will not match native
  placement unless the map camera also happens to be centered there

### Verified Render-Time Action Playback Ordering

The live local-hero motion path is part of the same render function:

1. `Role_TickAndRender` computes current transform inputs.
2. `Role_UpdateActionAndDispatchRoleViewMotion` updates `role+0x1A4`, `+0x1AC`,
   `+0x1B4`, and `+0x1B8`.
3. `Role_TickAndRender` calls RoleView slot `+0x0C` with the current action id.
4. `Role_TickAndRender` calls RoleView slot `+0x04` with property key `0x0A`
   and the sampled primary frame.
5. `Role_TickAndRender` then performs RoleView transform/color/render calls.

This ordering is the native reason the live playback bridge must run inside the real
hero render path, after current-frame role scene submission exists and before the
multi-part draw consumes the part transforms.

**Offscreen render** (`role[0x108]` == 1):
- Allocates offscreen render target: `role[0x109]` = 0x100 (256×256)
- Calls `CMyBitmap::ClearBuffer`, `CMyBitmap::GameCameraBuild(256)`
- Sets up dedicated camera via `CMyBitmap::GameCameraSet`
- Renders 3D model to offscreen target
- Creates `MyBitmapCreateEx` at `role[0x10B]` from texture
- Sets `role[0x108]` = 2 (has pre-rendered bitmap)
- Future frames blit the stored bitmap via vtable+0x28

### Shadow Rendering

After the main render, loads `"ani/common.ani"` → `"SimpleShadow"` via GameDataSet
string-keyed request. Renders the shadow sprite at the hero's feet position, scaled
by projection and opacity.

## RoleView Layer (RoleView.dll)

### `RoleView_SharedSetTransformFromCamera` (0x1000327E)

Stores position fields into the RoleView object:

| Field | Offset | Source |
|-------|--------|--------|
| screenX | +0x04 | projectionBaseOffsetX (float) |
| screenZ | +0x08 | adjustedProjectionBaseOffsetY (float) |
| elevation | +0x0C | elevation (float); doubled if perspective projection |
| rotation | +0x18 | rotationDegrees (int, degrees) |
| scale | +0x1C | computedScale (float) |

### `RoleView_SharedRenderComposite` (0x100038A9)

The main rendering dispatch. This is the function that actually draws the hero.

Important implementation detail from `RoleView.dll`: the function returns with `retn 0x8`
but does not read those stack arguments in the player-RoleView body. The live transform comes from
`this+0x04/+0x08/+0x0C/+0x18/+0x1C`, which were populated earlier by
`RoleView_SharedSetTransformFromCamera`.

1. **Guard checks**: requires `I3DRole` at `this+0xD8` (= `this[0x36]`), requires
   "body" part loaded via `I3DRole_IsPartLoadedAndReady("body")`.
2. **Calls `CMyBitmap::PrepareModle()`** — sets D3D8 device state for 3D rendering.
3. **Builds two 4×4 world matrices** (same logic as the slot-9 hit test
   `RoleView_SharedScreenPickHitTestAgainstBoundingBox`):
   - Matrix A: Scale(scale) → RotateZ(rotation) → TranslateZ(elevation)
   - Matrix B: RotateXY(oblique) → Translate(screenX, screenZ)
   - If perspective projection: single combined matrix path
   - If orthographic: split scale+rotZ+translateZ and rotXY+translateXY
   - the resulting world matrices are rendered against the current global camera that
     was already rebuilt by `CGameMap_UpdateGameCameraFromProjectionCenter` /
     `CMyBitmap::GameCameraSet`, not against a fresh viewport-centered camera
4. **Sets color** on I3DRole for "mount" part if mounted.
5. **Renders parts in order** via `I3DRole_RenderPartByName_WithMotions`:

```
Render order:
  1. "mount"              (if equipped, renderFlag=0)
  2. body/helmet variants (from RolePartNameTable, renderFlag=0 or 1)
  3. "misc"               (renderFlag=1, renders with effects)
  4. "r_weapon"           (renderFlag=1)
  5. "l_weapon"           (renderFlag=1)
```

6. **Calls I3DRole vtable+0x38** (`I3DRole_ResetPartRenderStateByName`) per
   body/helmet variant part. This clears transient submesh color/matrix state and
   does not reset motion.
7. **Returns 1** on success, 0 if body not loaded.

### `RoleView_SharedSetColorRgba` (0x1000334F)

Forwards RGBA floats to `I3DRole` vtable+0x4C (color setter for all part meshes).

### `RoleView_SharedScreenPickHitTestAgainstBoundingBox` (0x10003640)

Used by vtable slot 9. Builds the role's world transform from `this+0x04..+0x1C`,
inverse-transforms a screen-space ray (`CMyBitmap::ScrRayBuild(arg2, arg3)`) into the role's
local space, then tests it against a fixed local AABB `[-40,-40,-90]..[40,40,-10]` via
`RoleView_RayAabbSlabIntersectionTest` (`0x10005E7A`). Returns a clamped boolean (hit / no-hit).
This is a screen-pick hit test, not a tick or render path. (Previous slices misnamed it
`RoleView_SharedTickAndRender`.)

## Role3D Layer (Role3D.dll)

### `I3DRole_RenderPartByName_WithMotions` (0x100035D0, vtable+0x0C)

For each named part:

1. **Resolves part** via `PartMap_FindEntryByName(partName)`.
2. **Builds motion link chain** via `I3DRole_AppendLinkedPartMotionLinksRecursive`.
3. **Applies motion matrices** — iterates motion links, calls
   `CMyBitmap::Motion_GetMatrix_Blend` for each, multiplies into cumulative matrix.
4. **Multiplies transform matrices** — combines motion chain with world matrices.
5. **Calls `CMyBitmap::PrepareModle()`** — D3D8 state setup.
6. **Calls `PartInfo_BindPerPartTexturesAndMaterial`** — binds textures per submesh.
7. **Calls `PartInfo_RenderAllParts`** — issues the actual draw calls.
8. **Optionally resets transient render state** via
   `PartInfo_ResetAllMeshSubmeshColorAndMatrices` when
   `resetPerPartStateOnExit != 0`. This restores submesh color to white and clears
   temporary matrices without changing motion.

### `PartInfo_RenderAllParts` (0x10005EB0)

Iterates all PHY submeshes in the part:

```
for (i = 0; i < partInfo[0x100/4]; i++) {
    mesh = PartInfo_ResolvePartMesh(partInfo, partRecord[-0x1C]);
    if (mesh) {
        mesh->vtable[0x60/4](stepValue, 0);              // C3DObjX_SetStepAndRenderFlags
        mesh->vtable[0x54/4](preparedDrawInputs);         // D3D DRAW
    }
    // clear per-mesh flags
}
PartInfo_TickEffectsAndRender(partInfo + 0x84, partInfo);  // particle effects
```

The vtable+0x60 call is `C3DObjX_SetStepAndRenderFlags` (verified target `0x10007250` in
graphic.dll, see `graphic_dll/12_meshcreate_and_c3dobjx.md`). It sets `mesh[1]` to either
the supplied step value or the default `4`, and stores the second arg into `mesh[2]`.

The `vtable+0x54` call on the mesh object is the final D3D8 `DrawIndexedPrimitive`
dispatch through the C3 engine's `C3Phy_DrawNormal` path.

## CRole Object Field Map (Hero-Relevant)

| Field | Byte Offset | Type | Purpose |
|-------|------------|------|---------|
| role[0x02] | 0x008 | uint32 | ARGB color tint |
| role[0x07] | 0x01C | int32 | frame index (negative = use role[0x6A]) |
| role[0x0A] | 0x028 | byte | debug mode flag |
| role[0x18] | 0x060 | int32 | render state (0=normal, 1=first-frame setup) |
| role[0x19] | 0x064 | uint32 | timestamp for frame interval calculation |
| role[0x33] | 0x0CC | int32 | entity type ID |
| role[0x53] | 0x14C | int32 | mesh/model ID |
| role[0x5D] | 0x174 | int32 | transform-look AddSize value |
| role[0x5F] | 0x17C | int32 | direction index (0-7, used for 2D fallback) |
| role[0x61] | 0x184 | int32 | bodyScale |
| role[0x62] | 0x188 | float | actionScaleMultiplier |
| role[0x69] | 0x1A4 | int32 | action ID (current) |
| role[0x6A] | 0x1A8 | int32 | frame count for current action |
| role[0x6B] | 0x1AC | int32 | total frame count |
| role[0xC3] | 0x30C | int32 | verticalRenderOffset |
| role[0xC4] | 0x310 | int32 | targetVerticalRenderOffset |
| role[0xD0] | 0x340 | int32 | appearance source ID |
| role[0xD4] | 0x350 | int32 | screen X position |
| role[0xD5] | 0x354 | int32 | screen Y position |
| role[0xD6] | 0x358 | int32 | phase-dependent effective mesh-transform / later projection-relative X |
| role[0xD7] | 0x35C | int32 | projected screen Y |
| role[0xD9] | 0x364 | int32 | RoleView type |
| role[0xDE] | 0x378 | uint32 | fade-in timestamp (0 = fully visible) |
| role[0xE5] | 0x394 | byte | scapegoatOffsetYGateFlag |
| role[0xE7] | 0x39C | int32 | scapegoatOffsetY |
| role[0xE8] | 0x3A0 | int32 | skip-render flag |
| role[0xE9] | 0x3A4 | int32 | additionalOffsetY |
| role[0xEA] | 0x3A8 | byte | additionalOffsetYEnabledFlag |
| role[0xED] | 0x3B4 | ptr | **RoleView object** (created by RoleViewCreate) |
| role[0x108] | 0x420 | int32 | offscreen render state (0=init, 1=rendering, 2=done) |
| role[0x109] | 0x424 | int32 | offscreen target size (256) |
| role[0x10B] | 0x42C | ptr | MyBitmap offscreen result |
| role[0x10C] | 0x430 | ptr | name label bitmap |
| role[0x10D] | 0x434 | ptr | guild label bitmap |
| role[0x130] | 0x4C0 | uint32 | last render timestamp |

## RoleView Type 1 Object Layout

| Offset | Type | Purpose |
|--------|------|---------|
| +0x00 | ptr | vtable (`0x100151B8`) |
| +0x04 | float | screenX |
| +0x08 | float | screenZ |
| +0x0C | float | elevation |
| +0x10 | float | rotationX (oblique angle from CMyBitmap) |
| +0x14 | float | rotationY |
| +0x18 | int32 | rotationZ (degrees) |
| +0x1C | float | scale |
| +0x20 | int32 | current action ID |
| +0x24..+0x30 | int32[4] | part source IDs (body variants) |
| +0x3C | int32 | left weapon source |
| +0x40 | int32 | right weapon source |
| +0x44 | int32 | mount source |
| +0x48 | int32 | misc source |
| +0xA8 | int32 | body appearance source ID |
| +0xCC | uint32 | ARGB color tint |
| +0xD8 | ptr | **I3DRole object** (from `I3DRoleCreate()`) |

## Managed Rewrite Mapping

The native three-layer architecture maps to our managed code as follows:

| Native | Managed | Status |
|--------|---------|--------|
| CRole + Role_TickAndRender | `ClientWorldRoleViewSceneObjectStoreRuntime` | Position/state capture done |
| RoleViewCreate + RoleView vtable | `PlayerRoleViewVisualPlanRuntime` | Visual plan resolution done |
| RoleView_SharedRenderComposite | `Role3DClientSceneMultiPartRenderStageRuntime` | Multi-part render done |
| I3DRole part map | `Role3DPartContainer` | Named part slots done |
| PartInfo per-part record | `Role3DPartSlot` | Per-part state done |
| Role3D matrix compute helper (`0x10006520`) | `Role3DPartTransformResolver` | Transform computation done |
| PartInfo_RenderAllParts | `Role3DMultiPartMeshRenderer` | Multi-part GL draw done |
| Part loading (GameDataSet type 2/3) | `GameDataSetPerFramePumpRuntime` | Asset pipeline done |
| Motion/animation | `Role3DPartInfoMotionRuntime` et al. | State machines done |
| D3D8 draw | OpenGL 4.1 VAO/VBO/EBO | Draw path done |

## Startup-local-hero composite seed boundary

Verified startup order in `CMsgUserInfo__Process` for the local hero:

1. `CRole__CreateRoleView(hero, appearanceCompositeId % 1000, 1)`
2. `CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform(hero, (appearanceCompositeId / 10000) % 1000, 0)`
3. `hero+0x178 = (appearanceCompositeId / 1000) % 10`
4. `CRole__SetTransformLookSourceId(hero, packet+0x08, 1)`
5. `CRole__SetLinkedSourceLookupId(hero, hairCompositeId % 1000, 1)`
6. `CRole__SetHeadAttachmentSource(hero, hairCompositeId / 1000, 1)`

`CMsgPlayerSpawn__Process` explicitly ignores the local hero and returns before any tile/direction or
appearance writes from `10014`, so this `1006` chain is the verified
native startup seed for local-hero body appearance, mesh-transform seed, and transform flag.

Verified refresh boundary at startup:

- `CRole__SetTransformLookSourceId(hero, packet+0x08, 1)` stores the source id and immediately
  calls `CRole__ReapplyAllVisualSources`
- `CRole__ReapplyAllVisualSources` immediately calls
  `CRole__ApplyAllVisualSourcesToRoleView(hero, hero->RoleView)` and then
  `Role_UpdateMountActionScaleCacheFromRoleState(hero)`

So the startup local-hero seed already reaches RoleView during `1006`. The current missing
hero parity is downstream of this boundary, not a skipped visual-source reapply call.

Verified live render-time lookup-cache push:

- `Role_TickAndRender` calls
  `CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView(role)` immediately before the
  current RoleView draw/setup sequence.
- That helper does not build new lookup ids; it only pushes the role-side cached values
  already stored at:
  - `role+0x104`, `role+0x108`, `role+0x10C` (helmet lookup caches)
  - `role+0x110` (primary body lookup cache)
  - `role+0x114` (left-weapon lookup cache)
- So the remaining missing startup-local-hero parity is not explained by a skipped call to
  this helper.

**Corrected 2026-09-06.** The earlier wording — "does not mirror the runtime lookup-cache table
rooted at `0x96AE88`" — was wrong on both halves. `data_96AE88` is the `ItemType.dat` singleton,
and the managed client *does* mirror it (`ItemTypeDataCatalog`, `ItemTextureIniTable`,
`ItemFuseIniTable`). The caches at `role+0x104`..`+0x114` are outputs of that singleton, not a
table of their own.

The actual gap is narrower: `role+0x110` and `role+0x114` are produced, `role+0x104` is produced
for its plain path, and `role+0x108` / `role+0x10C` are **structurally unreachable** rather than
unimplemented. `CRole__ApplyHelmetVariantSourcesToRoleView` only fills layers 1 and 2 when
`role+0xE0 != 0`, from a **`CSuitStatusMgr`** record looked up by `role+0xCC`
(identified 2026-09-06; manager RTTI `".?AVCSuitStatusMgr@@"`, singleton at `data_956068`).
The blocker is now two narrower questions: the exact per-layer seeding in
`0x6E5824`..`0x6E5988`, and what fills the record vector. Full loop
semantics — including a family-class guard that compares every layer against the *primary* source
family and `break`s the whole loop on mismatch — are in
`02_roleview_object_interface.md`, "Verified loop body (2026-09-06)".

### Multi-Part Render Pipeline (Implemented 2026-03-15)

The role render pipeline uses a multi-part architecture that matches the native I3DRole
structure. Each role entity has a `Role3DPartContainer` with named part slots for the
loaded player-RoleView family:

- `mount`
- body variants: `body`, `mix_body`, `mix2_body`
- helmet variants: `armet`, `mix_armet`, `mix2_armet`
- `misc`
- `r_weapon`
- `l_weapon`

1. **Scene composition**: `SceneComposition` creates a `HeroBodyRenderStageRouterRuntime`
   and wires it into `Role3DClientMapRenderExecutorRuntime`.
2. **GL init**: `GameApplicationLifecycleRuntime.EnsureHeroBodyRenderStageInitialized`
   creates the `Role3DMultiPartMeshRenderer` and `Role3DClientSceneMultiPartRenderStageRuntime`
   once the GL context is available (deferred-init router pattern).
3. **Per-frame**: `ExecuteRenderSubpasses` calls `CaptureCurrentFrameRoleVisualPlans()`,
   then `RenderHeroBodyMeshes()` which:
   - Iterates visual plans → ensures a `Role3DPartContainer` per entity
   - Reconciles current part-slot sources from the visual plan's property-source loads,
     clearing any stale slot whose latest native reload would have removed the old entry
   - Reapplies the current frame's attached-part resolutions (for example the body-hosted
     head attachment)
   - For each resolved part in render order: computes world matrix via
     `Role3DPartTransformResolver.ComputePartWorldMatrix()`, draws via
     `Role3DMultiPartMeshRenderer.DrawPart(meshPath, mvp)`
4. **Render order** (verified from `RoleView_SharedRenderComposite`,
   `RoleView.dll:0x10003baf..0x10003cf8`):
   mount → mix2_body → mix2_armet → mix_body → mix_armet → body → armet →
   misc → r_weapon → l_weapon
   - the body-family loop is interleaved per layer, not grouped as all bodies then all helmets:
     - `0x10003bd7`: `vtable+0x0C("mix2_body", matA, matB, 0)`
     - `0x10003c1e`: `vtable+0x0C("mix2_armet", matA, matB, 1)`
     - `0x10003bd7`: same call-site family with table base `0x10017048` and loop index `-4`
       resolves `"mix_body"`
     - `0x10003c1e`: same call-site family with table base `0x10017054` and loop index `-4`
       resolves `"mix_armet"`
     - layer `0` uses loop index `-8`, resolving `"body"` / `"armet"`
   - phase-specific gates stay verified:
     - right weapon class-`0x69` (`(PlayerRoleView+0x40) / 10000 == 0x69`) only draws for
       action ids `{0x191, 0x192, 0x193, 0x194, 0x208, 0x26C}` at
       `0x10003c87..0x10003cb2`
     - layer-0 body/helmet always bypass the zero-source field check through the
       `i == -8` branch at `0x10003bbd` / `0x10003be8`
5. **Per-part render-state reset timing** (verified from
   `RoleView_SharedRenderComposite` +
   `I3DRole_RenderPartByName_WithMotions` /
   `I3DRole_ResetPartRenderStateByName`):
   - mount and body-family draws pass `a5 = 0` to `I3DRole_RenderPartByName_WithMotions`,
     so they do **not** reset inline:
     - mount draw: `0x10003b9b..0x10003ba9`
     - body-family draws: `0x10003bce..0x10003bdd`
   - helmet, misc, right-weapon, and left-weapon draws pass `a5 = 1`, so
     `I3DRole_RenderPartByName_WithMotions` immediately calls
     `PartInfo_ResetAllMeshSubmeshColorAndMatrices` after the draw:
     - helmet draw: `0x10003c15..0x10003c24`
     - misc draw: `0x10003c54..0x10003c5e`
     - right weapon draw: `0x10003cc0..0x10003cca`
     - left weapon draw: `0x10003cee..0x10003cf8`
   - after all phases complete, the composite performs the delayed reset calls:
     - `0x10003d00..0x10003d16`: `vtable+0x38("body" | "mix_body" | "mix2_body")`
     - `0x10003d18..0x10003d29`: `vtable+0x38("mount")` when `PlayerRoleView+0x44 != 0`
   - every immediate and delayed call above resets only transient submesh color and
     matrices. The active action motion remains bound across frames.
   - default motion is restored by the separate `PartInfo_ResetPerPartState`
     (`0x10006750`) only when the primary-motion setter receives a null tracker.
6. **Transform pipeline** per part: `partLocal × worldMatrix × posMatrix`
   where worldMatrix accumulates:
   - every ancestor bone-0 matrix from the linked motion chain;
   - before accumulation, native transforms that bone matrix's translation row
     through the ancestor `PartInfo+0x44` local matrix with
     `D3DXVec3TransformCoord` (`Role3D.dll:0x1000370B`)
   - the direct target-part lookup at `Role3D.dll:0x100034C4..0x10003504`
     belongs to the separate vtable `+0x7C` transform-query helper and is not
     executed by the vtable `+0x0C` RoleView draw path
7. **Shader**: shared GLSL 4.10 vertex+fragment shaders, per-part MVP upload,
   per-submesh texture binding, N·L diffuse lighting.

Managed parity consequence from the verified native loop:

- player-RoleView action playback already drives `body` / `mix_body` / `mix2_body` and
  `armet` / `mix_armet` / `mix2_armet`
- that layered playback split is asymmetric:
  - visual-track configuration is only proven for primary `body` and primary `armet`
  - motion fan-out is then applied across the layered body/helmet families by the `I3DRole`
    motion setters
- the managed multi-part stage must reconcile slot state from the **current** visual plan each
  frame rather than leaving old resolved slots alive:
  - native draw/load gates read the live `PlayerRoleView` source fields at
    `+0x40`, `+0x44`, `+0x48`, `+0x60..+0x74`
  - the loaded body-source caches at `+0x24/+0x28/+0x2c` are distinct from the phase-5
    body variant draw gates at `+0x60/+0x64/+0x68`; loading `mix_body` or `mix2_body`
    does not make that optional layer drawable while its corresponding variant source is zero
  - the managed scene snapshot therefore carries the body variant gate fields separately;
    the currently verified startup/reapply chain writes only primary `+0x60`, leaving optional
    `+0x64/+0x68` at their constructor-zeroed values
  - `I3DRole_LoadPartByName` first removes the existing part entry before rebuilding it
  - a later unresolved reload therefore clears the old part instead of preserving stale geometry
- a managed render container that only enumerates `body` / `armet` cannot show
  the full native body-family playback path even when the motion bridge is correct

### Body Mesh Structure (Verified 2026-05-01)

The hero body mesh (model ID 2000000) resolves via the 3DObj database to
`c3/mesh/002000000.c3`. This is an **effect container** (not a plain mesh container)
with the following structure:

- Effect header (16 bytes) with type flag `'E'`
- **4 StaticSparse PHY submeshes**:

| Index | Submesh Name | Vertices | Faces | Purpose |
|-------|-------------|----------|-------|---------|
| 0 | `v_body` | 520 | 680 | Main body geometry |
| 1 | `v_armet` | 24 | 12 | Helmet placeholder |
| 2 | `v_l_weapon` | 6 | 8 | Left weapon placeholder |
| 3 | `v_r_weapon` | 6 | 8 | Right weapon placeholder |

**Key architectural facts:**
- All 4 submeshes are `PhyType.StaticSparse` on disk.
- This does **not** mean the role body is rigid:
  - normalized `PhyVertex` payload for `v_body` still carries live bone indices/weights,
  - clean 5517 sample dump for `002000000.c3` `v_body` shows non-zero weighted vertices,
    e.g. `idx1=0 idx2=6 w1=0.0 w2=1.0`,
  - `graphic.dll` `C3DObjX_Render` + `c3_core_dll.dll` `Phy_Calculate_CPU` consume those
    same weight/index slots without a verified branch on the original PHY discriminator.
- Equipment placeholder submeshes (armet, weapons) are embedded in the body container
  as low-poly stubs. They are replaced at runtime when equipment is equipped via the
  part system (`I3DRole_SetPartMeshOrDefault`).
- The body mesh is not proven rigid. For the role body path, deformation can still come from
  `Phy_Calculate_CPU` bone sampling even though the container is `StaticSparse`.
- `Phy_Calculate_Lite` + `Phy_DrawNormal_CPU` is therefore only a rigid-mesh path; it is not
  sufficient to explain live hero body animation by itself.
- Different actions (stand, walk, attack) may load different `.C3` files via the motion
  key system, but the body mesh geometry itself does not change per-action.

### Motion Pipeline Wiring Status

The motion pipeline components are **built but not wired to the renderer**:

| Component | File | Status |
|-----------|------|--------|
| Action motion resolver | `RoleViewBodyActionMotionTrackerResolver` | Built |
| Part-name dispatch | `Role3DRolePartMotionInterfaceRuntime` | Built |
| PartInfo motion apply | `Role3DPartInfoMotionRuntime` | Built |
| Mesh motion binding | `C3DObjXPartMeshMotionRuntime` | Built |
| Frame records | `RolePartMotionTrackerFrameRecords` | Built |
| Playback orchestrator | `Role3DClientRolePlaybackRuntime` | Built |
| Per-part transform | `Role3DPartTransformResolver` | **Done** for verified draw path (ancestor walk, bone sampling, and per-link translation-coordinate transform) |
| Multi-part renderer | `Role3DMultiPartMeshRenderer.DrawPart()` | **Done** |

The multi-part render stage now accepts per-part world matrices through
`Role3DPartTransformResolver`. Motion wiring is complete:
1. `WalkMotionLinkChain` calls `tryResolveBone0Matrix` delegate per ancestor ✓
2. `Role3DClientSceneMultiPartRenderStage` passes `meshRenderer.TryResolveBone0Matrix` as that delegate ✓
3. `TickLiveLocalHeroPlaybackIfNeeded` threads action state + frame index through playback each render pass ✓
4. The playback orchestrator (`LocalHeroRoleViewRenderPlayback`) handles action → motion resolution once a nonzero action is selected ✓

Fresh-role command initialization is now supplied to production playback before the first local-role
tick. It preserves the native `CRole+0x1A4 = 0` constructor state, then runs type `5` / progress `0`
through the existing command selector with the verified constructor inputs. The unsigned 10-second
window is refreshed before every selector tick because active movement handlers can invoke CRole's
type-5 virtual callback internally; random idle inputs remain limited to active command type `5`.
This includes progress `6`, and selector mutations are written back to the live managed command-state mirror.

**Current limitation**: motion ticking only runs for the local hero entity (`plan.IsLocalHero`).
Non-local hero parts render without motion data — ancestor bone matrices are identity, so attachment
part offsets (armet at v_armet, weapons at v_weapon) are not applied for other visible players.
