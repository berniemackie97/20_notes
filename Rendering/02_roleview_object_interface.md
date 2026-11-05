# `RoleView.dll` Object Interface (Observed via EXE Call-Sites)
The *minimum* interface of objects returned by `RoleViewCreate(...)`, reconstructed from how `CQ2ClientRelease-42.0.1.exe` calls their vtable methods.

We do **not** assume we know the full `RoleView.dll` implementation. This is a "black-box ABI" spec derived from the EXE's decompiled calls and vtable offsets.

## PlayerRoleView vtable quick-reference (slice 11 — all 13 slots verified)

Vtable at `RoleView.dll!0x100151b8`. Assigned by `PlayerRoleView_Ctor` (`0x10001000`)
inside `RoleViewCreate` case 1 (0xF8-byte allocation). All names verified via BNinja
decompilation + disassembly; no guesses.

| Slot | Offset | Address | Verified name | Signature / Notes |
|---|---|---|---|---|
| 0 | `+0x00` | `0x10005e1c` | `PlayerRoleView_VirtualDestroyAndFree` | thiscall(this). Null-checks this, dispatches `vtable[+0x30](1)` = ScalarDeletingDestructor with flags=1 (destroy + free). Returns 0. Used by CRole to tear down its role view. |
| 1 | `+0x04` | `0x10002779` | `PlayerRoleView_SetPropertyByKey` | thiscall(this, uint key, uint value). Giant switch on key (cases 0..0x3E). Documented in detail under "Property keys" section below. |
| 2 | `+0x08` | `0x10002d2f` | `RoleView_ReturnTrue` | thiscall(this, arg1, arg2, arg3), `retn 0xc`. Always returns 1. Shared stub across all 8+ RoleView vtable types. Purpose TBD (capability/readiness check?). |
| 3 | `+0x0C` | `0x10002dc8` | `PlayerRoleView_UpdateRolePartMotionsForAction` | thiscall(this, uint actionId, ...). The per-frame "push current action" entry, invoked by the native game loop each tick. Writes `m_idLastAction` at `+0x20` (see slice 10). Handles action-change detection, transition-duration lookup, motion-track rebinding. |
| 4 | `+0x10` | `0x1000327e` | `RoleView_SharedSetTransformFromCamera` | Shared across types. Sets the world/camera transform matrix for rendering. |
| 5 | `+0x14` | `0x100032bb` | `RoleView_SharedSetShadowRenderParameters` | Shared across types. Forwards shadow-rendering parameters to `I3DRole vtable+0x3C`. |
| 6 | `+0x18` | `0x1000334f` | `RoleView_SharedSetColorRgba` | Shared across types. Sets ARGB modulation color for the role view. |
| 7 | `+0x1C` | `0x10003486` | `PlayerRoleView_EnsurePartEffectInstanceBySelectorAndName` | Shared by PlayerRoleView (type 1) and Type2. Lazily loads the selector-mapped part, then ensures the named effect instance. |
| 8 | `+0x20` | `0x100035b4` | `PlayerRoleView_RemovePartEffectInstanceBySelectorAndName` | Shared by PlayerRoleView (type 1) and Type2. Removes the named effect from the selector-mapped part; selector `0x3F` clears all part effects. |
| 9 | `+0x24` | `0x10003640` | `RoleView_SharedScreenPickHitTestAgainstBoundingBox` | Shared across types. Screen-space pick / hit-test against the role's bounding box (for mouse-click targeting). Type10 uses `RoleView_Type10_TickAndRender` at this slot instead. |
| 10 | `+0x28` | `0x100038a9` | `RoleView_SharedRenderComposite` | The main per-frame render entry. Composes and draws all role parts (body, helmet layers, weapons, mount, misc, garment). Contains the class-0x69 right-weapon bow-action gate (see slice 10). Type10 uses `RoleView_Type10_RenderOnly` at this slot. |
| 11 | `+0x2C` | `0x10002bfc` | `PlayerRoleView_GetPropertyByKey` | thiscall(this, uint key). Companion to slot 1. Returns the current value for a given property key. |
| 12 | `+0x30` | `0x10001123` | `PlayerRoleView_ScalarDeletingDestructor` | thiscall(this, uint flags), `retn 0x4`. MSVC scalar-deleting destructor: calls `PlayerRoleView_Dtor`, then conditionally `operator delete(this)` when `(flags & 1)`. Invoked by slot 0 with flags=1. |

**Cross-reference with Type10 vtable** (`0x100153a8`, assigned by `RoleView_Type10_Ctor`
at `0x10004b4d`): shares slots 0, 2, 7, 8 with PlayerRoleView. Slots 1/3/4/5/6/9/10/11/12
have type-specific implementations (`RoleView_Type10_*`).

## Factory
- Import: `RoleViewCreate(int type)` (from `RoleView.dll`)
- Observed call-sites:
  - `CRole__CreateRoleView` (0x64D5A1)
  - `CRole__CreateRoleViewWithPos` (0x64D9A4)
  - `CPlayer__AddVisualEffect` (0x67430C)

The EXE stores the returned pointer in:
- role instance: `this + 237` (seen as `*((_DWORD*)role + 237)`)
- some "effect container" entries also store RoleView pointers.

## Lifecycle (vtable[0])
**Destructor / Release**
The EXE repeatedly destroys existing role views like:
```c
if (role_view) {
  (*role_view->vtable[0])(role_view);
  role_view = 0;
}
```
This strongly implies `vtable[0]` is a destructor or `Release()`-like method.

Verified in `RoleView.dll` (updated slice 11):

- All known RoleView vtables use `PlayerRoleView_VirtualDestroyAndFree` (`0x10005E1C`) as slot 0.
- `PlayerRoleView_VirtualDestroyAndFree(this)` null-checks this, then calls `vtable[+0x30]` = `PlayerRoleView_ScalarDeletingDestructor` (`0x10001123`) with flags=1 (destroy + free memory). Returns 0.
- The scalar-deleting destructor calls `PlayerRoleView_Dtor` (`0x1000113f`), then conditionally `operator delete(this)` when `(flags & 1)`. Standard MSVC pattern, `retn 0x4`.

## Initialization (vtable[1] @ +0x04)
**Set property (key/value)**
Observed in `CRole__CreateRoleView`:
```c
role_view = RoleViewCreate(type);
role_view->vtable[1](role_view, 0, look_id);
```
Same call is repeated in `CRole__CreateRoleViewWithPos` and for effects in `CPlayer__AddVisualEffect`.

Verified in `RoleView.dll`:

- For player RoleView objects, vtable[1] is `PlayerRoleView_SetPropertyByKey` (`0x10002779`).
- For type 4 objects, vtable[1] is `RoleView_Type4_SetProperty` (`0x100043B5`).
- For type 5 objects, vtable[1] is `RoleView_Type5_SetProperty` (`0x10005B64`).

## Transform / Placement (vtable @ +0x10, stdcall-like)
**Set transform (position/rotation/scale)**
Observed in `CRole__CreateRoleViewWithPos`:
```c
// vtable + 16
role_view->SetTransform(x, y, z, rot, scale);
```
Also observed in `CPlayer__AddVisualEffect`:
```c
role_view->SetTransform(screen_x, screen_y, 0.0, angle, scale);
```
And in `CRole__Render3D` (for live role views):
```c
role_view->SetTransform(screen_x, screen_y, screen_z_or_0, facing_angle, scale);
```

Exact parameter meanings still need confirmation, but the EXE consistently passes:
- 3 floats that look like a position (often screen-space after world→screen conversion)
- 1 int-ish angle (e.g., `45 * (-1 - direction)` and other angles)
- 1 float scale (often derived from a "percent" * constant)

Verified in `RoleView.dll`:

- Type 4: vtable slot 4 is `RoleView_Type4_SetTransform` (`0x10004453`).
- Type 5: vtable slot 4 is `RoleView_Type5_SetTransform` (`0x10005C8F`).

## Render Parameter Update (vtable[1] again @ +0x04)
In `CRole__Render3D` the EXE also calls:
```c
role_view->vtable[1](role_view, 10, some_value);
```
This is implemented as a generic `(key, value)` property setter in `RoleView.dll`.

## Color / Modulation (vtable @ +0x18, stdcall-like)
`CRole__Render3D` calls a vtable function at `+0x18` (24):
```c
role_view->SetColor(r, g, b, a);
```
The arguments are floats derived from bytes scaled by `1/255`, including an alpha-like term.

This is a parity-critical behavior (tints, fade, invisibility, status effects).

Verified in `RoleView.dll`:

- Type 4: vtable slot 6 is `RoleView_Type4_SetColor` (`0x1000453D`).
- Type 5: vtable slot 6 is `RoleView_Type5_SetColor` (`0x10005D3F`).

## Draw (vtable @ +0x28 / +0x2C? observed +40)
`CRole__Render3D` invokes:
```c
role_view->Render(screen_x_int, screen_y_int);
```
via `vtable + 40` in at least one path.

This likely triggers the actual draw of the model/sprite/equipment and requires that `SetTransform` and relevant properties have already been applied.

Verified in `RoleView.dll`:

- Type 5: vtable slot 10 is `RoleView_Type5_Render` (`0x10005DB1`).
- Type 4: vtable slot 10 is `RoleView_Type4_TickAndRender` (`0x10004844`) (updates internal state using `timeGetTime()` and then renders).

## Effect Setup (vtable @ +0x0C, observed in AddVisualEffect)
`CPlayer__AddVisualEffect` calls vtable `+0x0C` (12) with 7 args:
```c
role_view->Configure(effect_id, 1, 0, some_arg, x, y, 1);
```
This looks like a "play animation/effect" configuration call (effect id, loop flags, layer, etc.).

Verified in `RoleView.dll` (type 4):

- vtable slot 3 is `RoleView_Type4_Method3_Return10` (`0x1000526F`) which returns constant `10`.
  - This is consistent with the EXE passing 7 arguments at this slot in some paths; additional RoleView types may provide non-trivial implementations.

## Notes on observed usage
Even without reversing `RoleView.dll`, the EXE defines a stable ABI surface that drives rendering:
- factory + destruction semantics
- property setting (including the "key=10" path)
- transform + color modulation
- a draw call that consumes those state changes

## Property keys (verified implementations)

### Type 4 (`RoleView_Type4_SetProperty`, `0x100043B5`)

- key `0`: `RoleView_Type4_SetLookId_LoadRoleData(lookId)` (loads role data via `RoleDataQuery`)
  - helper address: `0x10004A68`
  - writes cached raw look id to `this+0x24`
  - resolves the standard NPC role-data record through
    `RoleDataSingleton_FindNpcTypeRecord` (`GameData.dll`, `0x10004D63`) via
    `RoleDataQuery()->vtable+0x30(lookId / 10)`
  - ensures internal `Simple3DObj` at `this+0x94` and feeds the record model id at `record+0x50`
  - copies the role-data payload fields into the Type-4 object:
    - `record+0x50` -> `this+0x48` (`SimpleObjID`)
    - `record+0x58/+0x5C` -> `this+0x38/+0x3C` (`BlazeMotion`)
    - `record+0x60/+0x64` -> `this+0x30/+0x34` (`RestMotion`)
    - `record+0x68/+0x6C` -> `this+0x40/+0x44` (`StandByMotion`)
    - `record+0x70/+0x74/+0x78` -> `this+0x84/+0x88/+0x8C` (`ASB` / `ADB` / `FixDir`)
  - copies the role-data name buffer from `record+4` into `this+0x58`
  - stores `lookId % 10` at `this+0x28`
  - seeds the live current-motion pair from the **standby** motion:
    - `this+0x50/+0x54 = this+0x40/+0x44`
  - clears the current-motion frame-start tick:
    - `this+0x7C = 0`
  - clears byte flag `this+0x7B`
  - the underlying role-data table is loaded by `GameData.dll::RoleDataSingleton_LoadNpcTypeAndNpcVariantTables` (`0x100044BF`) from `ini/Npc.ini`
- key `11`: ensures internal `Simple3DObj` exists at object offset `+0x94`, then calls vtable `+0x18` with `value`
- key `19` / `20`: if `*(this+0x28) == -1` or `*(this+0x8C) == 0`, writes `value` into `*(this+0x28)`
- key `64`: sets byte flag at `*(this+0x10)` to `value != 0`

Type 4 also has a getter:

- `RoleView_Type4_GetProperty` (`0x10004A31`): key `0` returns a derived look-id; key `19` returns the stored look-id.

### Type 4 transform / render loop

Verified from `RoleView_Type4_SetTransform` (`0x10004453`) and
`RoleView_Type4_TickAndRender` (`0x10004844`):

- `SetTransform(this, x, y, heightLike, rotateLike, scale)` stores:
  - `this+0x14 = x`
  - `this+0x18 = y`
  - `this+0x1C = heightLike` when `CMyBitmap::GameCameraIsProject() != 0`
  - `this+0x1C = 2 * heightLike` when `CMyBitmap::GameCameraIsProject() == 0`
  - `this+0x0C = rotateLike`
  - `this+0x20 = scale`
- The live facing fed into the internal `Simple3DObj` is derived from the cached look
  direction remainder at `this+0x28`, not directly from `rotateLike`:
  - `directionDegrees = (0xFFFFFFFF - this+0x28) * 45`
- The internal `Simple3DObj` is created on demand at `this+0x94` and receives that transform
  through vtable slot `+0x10` (`Simple3DObj_SetTransform_Ints`).
- The slot-4 caller contract still comes from `Conquer.exe::Role_TickAndRender`
  (`0x64F5F7`), which first converts the role's absolute projected screen point through
  `CGameMap_GetProjectionCenterOffsetFromScreenPoint`. So the stored `x/y` pair is the
  live projection-base offset relative to the map camera, not the raw absolute projected
  map coordinate.

Verified `TickAndRender(this, arg2, arg3)` flow:

- clears byte flag `this+0x10`
- reads `now = timeGetTime()`
- if `this+0x90 != 0` and `now >= this+0x80 + 0x4E20`, forces the current motion pair
  to blaze (`this+0x38/+0x3C`) and restarts both timers at `this+0x80` and `this+0x7C`
- resolves the active motion only through:
  - `GameDataSetQuery()->vtable+0x20("body", this+0x50, this+0x54, 1, 0)`
- missing motion is a hard failure path with the source string
  `F:\CQ2ClientRelease-42.0.1\RoleView\3DTaskNpc.cpp`
- frame duration is fixed at `0x21` ms (`33` ms)
- `frameCount = max(motion->vtable+0x0C(), 1)`
- if `now < this+0x7C + frameCount * 33`, the frame index is:
  - `(now - this+0x7C) / 33`
- otherwise the frame index resets to `0`, `this+0x7C = now`, and the motion pair advances:
  - when current motion == blaze (`this+0x38/+0x3C`), fallback target is standby
    (`this+0x40/+0x44`)
  - otherwise the default completion target is standby (`this+0x40/+0x44`)
  - on non-blaze completion, the helper at `0x1001496E` is queried with
    `(0x1E, 0)` and only `== 0x0F` swaps current motion to rest (`this+0x30/+0x34`)
- before the final draw, the internal `Simple3DObj` receives:
  - vtable `+0x3C`: the currently resolved `"body"` motion record
  - vtable `+0x38`: the current frame index
  - vtable `+0x08`: final render call `(arg2, arg3, this+0x84, this+0x88)`

### `0x1001496E` helper used by Type 4

Verified body:

- `arg1 == 0` -> returns `0`
- if `arg2 != 0`, calls `srand(timeGetTime())`
- returns `rand() % arg1`

So the type-4 blaze branch is literally gated by `rand() % 30 == 15` when the helper is
called with `(0x1E, 0)`.

### Managed reconstruction boundary for standard type-4 bodies

For the current cross-platform render slice, the verified 5517 type-4 path maps cleanly to a
single `"body"` slot rendered through the shared GL multipart pass:

1. `MsgNpcInfo(2030)` materializes a standard type-4 visual plan with:
   - projected screen X/Y from the live map projection
   - RoleView projection-base offset X/Y derived from that projected point through
     `CGameMap_GetProjectionCenterOffsetFromScreenPoint` semantics
   - `look_direction_index = look_composite % 10`
   - `Npc.ini::SimpleObjID`
   - `Npc.ini::StandByMotion / BlazeMotion / RestMotion`
2. The renderer resolves that `SimpleObjID` through the same native lookup order proven above:
   - `3DSimpleObjEx.dbc` inline lookup first
   - `3DSimpleObj.dbc` pointer-map fallback second
3. The current managed implementation only instantiates the verified pointer-map branch
   (`3DSimpleObj.dbc`) because the `3DSimpleObjEx.dbc` item-row semantics are not fully pinned yet.
4. The body draw mirrors `RoleView_Type4_SetTransform` by feeding the projection-base offset,
   not the raw absolute projected point, into the simple-object transform builder.
   - the resolved `3DSimpleObj.dbc` pair `SecondaryResourceId` is also a live native texture-binding input
   - `Role3D.dll::Simple3DObj_Render` always calls `PartInfo_BindPerPartTexturesAndMaterial`
     before `PartInfo_RenderAllParts`
   - `Role3D.dll::PartInfo_BindPerPartTexturesAndMaterial` resolves the copied per-part
     `primaryTextureId` stream and binds it on the mesh object before draw
   - managed implication: the standard type-4 path must not ignore
     `RolePartResolvedPart.PrimaryTextureId` when no explicit higher-level texture override exists
5. Motion binding uses only the verified `"body"` lookup:
   `GameDataSetQuery()->vtable+0x20("body", currentLow, currentHigh, 1, 0)`.
   - `GraphicData.dll::ResourceExecute_LoadStringKeyed` (`0x10007090`) performs an exact
     compound-key lookup in the loaded motion DB and does not normalize the key on request.
   - Real 5517 asset evidence: `Npc.ini` stores `Guide` rest/standby as
     `9990070101` / `9990070100`, while runtime `c3.wdb:ini/3dmotion.dbc` stores the
     matching body motions as `999007101` / `999007100` with secondary key `0`.
   - Therefore the type-4/simple-object path must consume a pre-normalized pair before the
     RoleView render loop uses it. The managed runtime mirrors this only for standard
     type-4/simple-object NPC body motions by probing the raw split-64 key first and the
     stripped 10-digit fallback second.
   - Old-source hint, not primary evidence: `40_tools/C3Studio-master`
     `GameDataService.ResolveMotion` uses the same direct-then-strip fallback for `3dmotion`.
6. Frame stepping mirrors the native 33 ms cadence and the current-motion fallback rules:
   - `RoleView_Type4_SetLookId_LoadRoleData` seeds the live current motion pair from standby
     (`record+0x68/+0x6C`) and zeros the frame timer field at `type4+0x7C`
   - `RoleView_Type4_TickAndRender` treats `type4+0x7C` as the per-motion frame timer and
     resets it when a motion completes
   - the completion branch is:
     - completed blaze -> standby
     - every other completion defaults to standby
     - on non-blaze completion, `RoleView_RandModuloOptionalReseed(0x1E, 0) == 0x0F`
       promotes the next motion to rest instead of standby
   - the separate 20-second timeout is guarded by `type4+0x90 != 0` and restarts both
     `type4+0x80` and `type4+0x7C` when it forces current motion to blaze
   - the producer for the live `type4+0x90` gate is `RoleView_Type4_RenderOrHitTest`
     (`0x10004583`):
     - the direct internal `Simple3DObj` hit-test path arms the flag when `type4+0x10 == 0`
     - the manual ray/AABB fallback path arms it when `type4+0x10 != 0`
   - the optional `rand()%30==15` standby->rest branch is verified inside the live type-4 render
     loop, but the shared CRT-rand seed/state seam that feeds it is not yet pinned tightly enough
     to reconstruct the runtime random source without guesswork

### Type 5 (`RoleView_Type5_SetProperty`, `0x10005B64`)

- key `0`: `RoleView_Type5_SetLookId_LoadNpcExIni(lookId)` (loads `ini/npcex.ini` and applies `Look0`)
  - this is a RoleView-local variant table and is **not** the same file as `GameData.dll`'s `ini/NpcX.ini`
- key `11`: ensures internal `Simple3DObj` exists at object offset `+0x34`, then calls vtable `+0x18` with `value`
- key `21`: `RoleView_Type5_SetValue21_RecomputeVariantLook(value21)` (recomputes variant based on `MulDiv(value22,100,value21)`)
- key `22`: `RoleView_Type5_SetValue22_RecomputeVariantLook(value22)` (recomputes variant based on `MulDiv(value22,100,value21)`)

See also:

- `analysis/conquer_docs/Rendering/roleview_dll/05_type5_npcex_ini.md`

### Player RoleView (`PlayerRoleView_SetPropertyByKey`, `0x10002779`)

Verified shared transform/render fields used by the slot-9 hit test
(`RoleView_SharedScreenPickHitTestAgainstBoundingBox`, `0x10003640`) and the slot-10 render
composition (`RoleView_SharedRenderComposite`, `0x100038A9`):

| Offset | Init | Meaning | Setter |
|---:|---|---|---|
| `+0x04` | `0` | screen X position | slot 4 (`SetTransformFromCamera` arg2) |
| `+0x08` | `0` | screen Y position | slot 4 arg3 |
| `+0x0C` | `0` | depth / Z position | slot 4 arg4 (doubled in non-project camera) |
| `+0x10` | `CMyBitmap::GetObliqueAngle()` | X-axis rotation in degrees | key `0xB` |
| `+0x14` | `0` | Y-axis rotation in degrees | key `0x21` |
| `+0x18` | `0` | Z-axis rotation in degrees | key `0x22`, also slot 4 arg5 |
| `+0x1C` | `1.0f` | scale factor | slot 4 arg6 |
| `+0xCC` | `-1` (`0xFFFFFFFF`) | packed ARGB tint color (8 bpp) | key `0x2F` |

The two slot-9 / slot-10 rotation paths apply `Common_Rotate(X, Y, Z)` with the angles
multiplied by `pi/180`. In the non-project camera branch, the Z angle is wrapped through
`mod(Z, 360)` first.

Verified slot-5 (`RoleView_SharedSetShadowRenderParameters`, `0x100032BB`) ABI cache
fields. These fields are written by the shared shadow-parameters setter but are **not read**
by any `RoleView.dll` consumer (neither `PlayerRoleView_GetPropertyByKey` nor
`RoleView_SharedRenderComposite` touches them). The setter additionally forwards its 8 args
to `I3DRole vtable+0x3C` (`I3DRole_StoreShadowRenderParameters`), which is the proven
downstream consumer:

| Offset | Source | Meaning |
|---:|---|---|
| `+0x98` | `arg3` | shadow direction X |
| `+0x9C` | `-arg4` | shadow direction Y (negated on store, mirrors forwarded value) |
| `+0xA0` | `-arg5` | shadow direction Z (negated on store, mirrors forwarded value) |
| `+0xA4` | `arg2` | shadow mode (clamped `>= 1` on the I3DRole side; meaningful values 2/3/4) |
| `+0xBC` | `arg6` | shadow scalar |
| `+0xC0` | `arg7` | unused at the I3DRole layer (forwarded but discarded) |
| `+0xC4` | `arg8` | unused at the I3DRole layer (forwarded but discarded) |
| `+0xC8` | `arg9` | unused at the I3DRole layer (forwarded but discarded) |

The Y/Z negation is the coordinate-frame conversion of the incoming light vector before it
is handed to `I3DRole`. The forwarded `I3DRole vtable+0x3C` call uses
`(arg2, arg3, -arg4, -arg5, arg6, arg7, arg8, arg9)`. The I3DRole side keeps only the first
5 of those 8 args (storing them at `I3DRole+0x14..+0x24`) and discards the other 3 via
`retn 0x20`. Those cached `I3DRole` fields are then read by `PartInfo_RenderAllParts`
(`Role3D.dll 0x10005EB0`) and forwarded to per-part-mesh `C3DObjX_Render` (`vtable+0x54`,
`graphic.dll 0x10004330`), where they are consumed as the shadow descriptor inputs (mode 2/3/4
build a `C3_SHADOW_RENDER_DESC` via `D3dxShadowRenderDescriptorBuild_DelayLoadThunk`). See
`role3d_dll/04_i3drole_object.md` "I3DRole_StoreShadowRenderParameters (slot 15)" for the full
consumer chain.

`RoleView_SharedSetColorRgba` (slot 6, `0x1000334F`) is a pure forwarder that reads the
`I3DRole` pointer at `RoleView+0xD8` and dispatches `vtable+0x4C(arg2, arg3, arg4, arg5)`
(four floats interpreted as RGBA). No fields are cached on the RoleView side. The downstream
target is `I3DRole_ApplyColorToAllParts` (`Role3D.dll 0x10001770`, slot 19), which iterates
the part map and walks per-mesh color setters
(`C3DObjX_SetColorForAllSubmeshes` → `Phy_SetColor` per submesh).

Verified `Conquer.exe` caller boundary for slot 5 / slot 6:

- `CRole__SetTransformLook` (`Conquer.exe 0x650B58`) does **not** call slot 5 or slot 6 of
  any RoleView vtable. It only invokes the property setter at vtable `+0x04` (slot 1).
- No `Conquer.exe` caller is currently pinned for either slot 5 or slot 6 on the player
  RoleView path; the only `RoleView.dll`-internal caller of
  `RoleView_SharedSetShadowRenderParameters` is `RoleView_Type10_SetShadowRenderParameters`
  (`0x10004C03`), which is itself slot 5 of the type-10 vtable.

### Verified slot-10 (`RoleView_SharedRenderComposite`) field-read map

`RoleView_SharedRenderComposite` (`0x100038A9`) is the per-frame draw composer that
`Role_TickAndRender` (`Conquer.exe 0x64F811`) reaches via the player-RoleView vtable slot
`+0x28`. The decompile pins exactly the following `arg1` (PlayerRoleView) reads — anything
not in this list is **not consumed** by the slot-10 draw path:

| Offset | Use |
|---:|---|
| `+0x04` | screen X (final translate, `Common_Translate(model, x, 0, +0x08)`) |
| `+0x08` | screen Y (final translate Y component) |
| `+0x0c` | depth / elevation (Z translate after rotations, both project and non-project branches) |
| `+0x10` | X-axis rotation in degrees (`Common_Rotate`, multiplied by `pi/180`) |
| `+0x14` | Y-axis rotation in degrees (`Common_Rotate`, multiplied by `pi/180`) |
| `+0x18` | Z-axis rotation in degrees (project: direct `* pi/180`; non-project: wrapped through `mod(value, 360)` first) |
| `+0x1c` | scale (`Common_Scale(model, s, s, s)`) |
| `+0x20` | `m_idLastAction` — the currently-playing action id written by `PlayerRoleView_UpdateRolePartMotionsForAction` at `0x10003113` (main path) and `0x10002e6e` (mount-only fast path). Read by the render composite at `0x10003c87` *only* when the class-0x69 right-weapon gate triggers, and compared against the action whitelist `{0x191, 0x192, 0x193, 0x194, 0x208, 0x26c}` = `{401, 402, 403, 404, 520, 620}` at `0x10003cb2` to decide whether the class-0x69 right-weapon mesh is drawn for this animation action. Also consumed intra-function by the action-change detection at `0x10002f53` and the previous-action blend-duration query at `0x10002f8e`. See slice 10 below. |
| `+0x24` `+0x28` `+0x2c` | loaded body source ids per layer (the 3-iteration `var_8_1` walk at `0x10003a9a..0x10003af0` feeds the per-layer enable flags `var_18 / var_1c / var_20`; see "Per-layer body-loaded enable formula" below) |
| `+0x40` | right-weapon source family (`(value / 0x2710) == 0x69` selects the override branch above; otherwise the right-weapon draw runs unconditionally) |
| `+0x44` | mount source family (final `vtable+0x38("mount")` render-state reset is gated on this being non-zero) |
| `+0x60` `+0x64` `+0x68` | body variant source layers (read via `var_8_4[-3]` in the 3-iteration helmet loop, paired with the helmet layers below — used as the per-layer body-loaded gate via `vtable+0x08(BodyAndHelmetVariants[i])`) |
| `+0x6c` `+0x70` `+0x74` | helmet variant source layers (read via `var_8_4` walking from `arg1+0x74` down by 4 per iteration; gates the per-layer helmet draw via `vtable+0x08(HelmetVariants[i])`) |
| `+0xa8` | body appearance source id, **also** read at function entry as a flat `== 0x3e6` (`998`) compare (see special case below) |
| `+0xcc` | packed ARGB tint color (unpacked `(eax >> 24).b / (>> 16).b / (>> 8).b / .b`, each multiplied by `1/255`, forwarded to `I3DRole vtable+0x80` with target `"mount"`/`"none"`) |
| `+0xd8` | `I3DRole` pointer (every part-load query and per-layer draw goes through it) |

**`+0xa8 == 998` (`0x3e6`) special case (`0x100038cf..0x100038ff`):**
The function entry compares `*(arg1+0xa8)` against `0x3e6`. The two paths are:
- `+0xa8 == 0x3e6`: skip the `vtable+0x08("body")` "is body part loaded" gate entirely and
  go straight to `vtable+0x08("mount")`. If mount is not loaded, return 0 (nothing to draw).
- `+0xa8 != 0x3e6`: require **both** `vtable+0x08("body")` and `vtable+0x08("mount")` to
  succeed before composing the draw.

Body appearance source id `998` is therefore the verified mount-only render path: it
disables the "must have a body part loaded" precondition because the appearance is
expected to consist of only the mount mesh. Setter side this is configured through key `0`
(`PlayerRoleView_SetBodyAppearanceSource`), which still passes the `0 < nLook < 1000`
assertion since `998 < 1000`.

Field offsets explicitly **not** read by slot 10: `+0x30..+0x38` (loaded helmet source ids
— those are texture-binding inputs only), `+0x3c` (left-weapon source family — left-weapon
gating uses `vtable+0x08("l_weapon")` directly), `+0x48` (misc source family — the misc
draw is gated only on `vtable+0x08("misc")`), `+0x50..+0x5c` (texture overrides),
`+0x78..+0x94` (variant overrides), `+0x98..+0xc4` (slot-5 shadow cache), `+0xb0..+0xb8`
(linked source / screen pick coords), `+0xd0/+0xd4` (key `0x1F` low/high half).

**Per-layer body-loaded enable formula (`0x10003a7e..0x10003af0`):**

Right before the body+helmet draw loop, slot 10 builds a 3-element local enable-flag array
(`var_18 / var_1c / var_20`) and runs a 3-iteration sub-loop to decide whether to draw each
body layer. Verified disassembly control flow:

```
enableFlag[0..2] = {1, 1, 1}                       ; default: enabled
cursor = arg1 + 0x24                                ; loaded body source layer 0
for layer in [0..2]:
    id = *cursor                                    ; loadedBodySourceId
    bodyClass3   = (id / 1000) % 1000               ; "1000-place" 3-digit field
    if bodyClass3 == 137:                           ; 0x89
        bodyVariant2 = id % 100                     ; lowest 2 digits
        if 20 <= bodyVariant2 <= 90:                ; 0x14..0x5a
            enableFlag[layer] = 0                   ; DISABLE
    bodyType2 = (id / 10000) % 100                  ; "10000-place" 2-digit field
    if bodyType2 == 18:                             ; 0x12
        enableFlag[layer] = 0                       ; DISABLE
    cursor += 4
```

The flags are then read at `0x10003bed` inside the body+helmet draw loop as
`*(&var_18 + i_1)`, where `i_1` walks `0, -4, -8` over 3 iterations — gating the per-layer
**helmet** draw. (The body draw on the same iteration is gated only on the body source field
itself being non-zero, plus `vtable+0x08(BodyAndHelmetVariants[i])`.)

The encoding interpretation (digits within the 9-digit body source id):

```
loadedBodySourceId  =  bodyAppearanceSourceId * 1_000_000  +  variantFamily
                       └── digits [6..8] ──┘                  └── digits [0..5] ──┘

bodyClass3    = digits [3..5]   (the 3-digit "middle field" inside variantFamily)
bodyVariant2  = digits [0..1]   (the lowest 2 digits; lowest digit is always 0 from the
                                 setter normalization formula)
bodyType2     = digits [4..5]   (the lowest 2 digits of bodyClass3)
```

Two distinct disable rules are pinned today:

- `bodyClass3 == 137` AND `bodyVariant2 ∈ [20..90]` → suppresses the helmet draw on this
  body layer (one specific class+variant range)
- `bodyType2 == 18` → suppresses the helmet draw on this body layer (one specific type code)

Both rules **only** suppress the per-layer helmet draw — they do not unload the body source
or affect the body draw itself. The setter side of these encodings is not yet pinned;
deciphering what `bodyClass3 == 137` and `bodyType2 == 18` mean semantically (e.g., "wearing
a helmet would clip into this body class") requires tracing the writers of `+0x24..+0x2c`
in a future slice.

**Slice 9 — server-grounded proof of `+0x24..+0x2c` writers and `MsgSpawnPlayer` slot map.**

The 4-writer set that feeds the per-layer body source `view[+0x24..+0x2c]` (and therefore
the disable rules above) is now fully pinned in `RoleView.dll`:

- `PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily` @ `0x10001E58` —
  reload helper, success branch at `0x10001E58`, failure (zero) branch at `0x10001E8A`
- `PlayerRoleView_SetBodyAppearanceSource` rebase pass @ `0x10001F6A`
- `PlayerRoleView_ResetSourcesAndRebuildBodyAppearance` zero-clear
- `PlayerRoleView` ctor zero-init @ `0x100010E4`

The reload formula is:

```
loadedSource = bodyAppearanceSourceId * 1_000_000
             + ((sourceFamily % 1_000_000) / 10) * 10
```

`sourceFamily` is the value the role-side cluster `role[+0x11C/+0x134/+0xF4]` is asked to
reload from when key `4` is dispatched on the RoleView.

The end-to-end upstream chain is now verified in `Conquer.exe`:

```
spawn_packet_frame[+0x30]                                       ; body offset 44
    → CMsgPlayer__Process @ 0x756a88
    → CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView      ; writes role[+0x11C]
    → CRole__RefreshPrimaryBodyVariantSourcesToRoleView
    → key 4 dispatch on PlayerRoleView
    → PlayerRoleView_SetPrimaryBodyVariantSourceAndReload(this, role[+0x11C], 0)
    → PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily
    → view[+0x24..+0x2c] = loadedSource          ; the disable-rule input
```

The same chain is exercised by `CHeroItem__SetEquipSlot` @ `0x6da910`. Its case dispatch
proves the per-slot semantic (`arg2 - 1 == ItemPosition`):

| case | ItemPosition | Setter called | Arg2 (role/body-variant input) |
|------|--------------|---------------|--------------------------------|
| 0 | Headwear (1) | `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView` | `headwear[+0x1c]` |
| 8 | Garment (9) | `CRole__SetSharedBodyHelmetVariantLookupSourceAndRefreshRoleView` | `garment[+0x1c]` |
| 2 | Armor (3) | `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView` | `armor[+0x1c]` |
| 4 | LeftHand (5) | `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView` | `leftHand[+0x1c]` |
| 3 | RightHand (4) | `CRole__SetRightWeaponVisualInputsAndRefreshRoleView` | `rightHand[+0x1c]` |

Each setter is therefore consuming the equipped item's `[+0x1c]` field — the catalog
**Itemtype** id, the same digit-decomposed value the per-layer disable rules check —
**not** the inventory row Uid.

**Slot map for `MsgSpawnPlayer` (10014).** The call sites in
`CMsgPlayer__Process` @ `0x755F64..0x756B43` read from
`*(esi+0x404)` (the spawn frame, which includes the 4-byte header — so
`frame[N] = body[N-4]`). Each per-slot setter is fed two slices of the frame:
`arg2` from the per-slot body-variant input region, and `arg3` from the per-slot
lookup-override region. The verified mapping is:

| Body off | Frame off | Setter / consumer | Slot |
|----------|-----------|-------------------|------|
| 36  | `+0x28` | `SetPrimaryHelmetVariantInputs` arg2          | Headwear `[+0x1c]` |
| 40  | `+0x2c` | `SetSharedBodyHelmetVariantLookupSource` arg2 | Garment  `[+0x1c]` |
| 44  | `+0x30` | `SetPrimaryBodyVariantInputs` arg2            | Armor    `[+0x1c]` |
| 48  | `+0x34` | `SetLeftWeaponVisualInputs` arg2              | LeftHand `[+0x1c]` |
| 52  | `+0x38` | `SetRightWeaponVisualInputs` arg2             | RightHand`[+0x1c]` |
| 56  | `+0x3c` | `SetExtraLeftWeaponOverrideLookupId`          | ExtraLeftWeapon `[+0x1c]`  (TODO) |
| 60  | `+0x40` | `SetExtraRightWeaponOverrideLookupId`         | ExtraRightWeapon `[+0x1c]` (TODO) |
| 64  | `+0x44` | `Role_UpdateMountActionScale` arg1            | mount-action-scale primary (TODO) |
| 68  | `+0x48` | `Role_UpdateMountActionScale` arg4            | mount-action-scale variant (TODO) |
| 178 | `+0xb6` | `SetPrimaryHelmetVariantInputs` arg3          | Headwear ItemType (lookup override) |
| 182 | `+0xba` | `SetPrimaryBodyVariantInputs` arg3            | Armor ItemType    (lookup override) |
| 186 | `+0xbe` | `SetLeftWeaponVisualInputs` arg3              | LeftHand ItemType (lookup override) |
| 190 | `+0xc2` | `SetRightWeaponVisualInputs` arg3             | RightHand ItemType (lookup override) |

Garment has no lookup-override slot in the body 178-190 region — its setter only takes
`(view, value, refresh)`. Body offsets 56-72 are zero-pending (the
`ExtraLeftWeapon`/`ExtraRightWeapon` and Steed mount-cache fields are not yet plumbed
through the OpenConquer domain model). Body 178-190 is the per-slot validation that
`CItemData__QueryByItemId` performs in the type-1 setup path before stamping the
`var_1c_6 / var_20_2` overrides into the corresponding setter calls.

**Server-side fix landed.** The OpenConquer reference server
(`50_server/OpenConquer5517v3`) was previously sending inventory row Uids in slot order
`Headwear/Armor/RightHand/LeftHand/Steed` at body 36-52, and a parallel mis-ordered
`Steed/RightHand/LeftHand/Headwear` ItemType set at body 178-190. With the auto-increment
inventory counter feeding directly into `view[+0x24..+0x2c]`, any right-hand row whose
low six digits matched `137xxx` with variant ∈ [20..90] (or `18xxx`) would silently
disable the local hero's layer-1 body draw via the formula above. The fix in
`OpenConquer.Protocol/Game/Packets/Writers/SpawnPlayerWriter.cs` rewires both regions to
the verified `H/G/A/LH/RH` ordering and to `ItemType` (catalog id, the same value
`item[+0x1c]` carries on the native side). Verified by:

- `dotnet build` clean (0 warnings, 0 errors)
- `dotnet test` clean: 15 / 7 / 105 = 127 tests passing across the three suites
- `PlayerVisualPacketWriterTests.SpawnPlayerWriter_WritesVerifiedAppearanceAndEquipmentOffsets`
  rewritten to assert the verified slot mapping (with a Garment fixture added) — the
  prior assertions had enshrined the bug.

**Caveat — slice 9 only ground-truths the body 36-52 / 178-190 regions.** Body 56-72
(extra-weapon overrides + mount-cache primaries) and the catalog-ItemType slot for the
Steed mount remain TODOs. The test now asserts that body 56-68 stay zero so a future
slice that wires them up will fail loudly until the assertions are updated alongside
the wiring. Slice 7's earlier framing of the disable rules as "dormant" is formally
retracted: with the server fix in place they remain inert *only* because no equipped
catalog Itemtype currently lands in the `137/[20..90]` or `18xxx` buckets — the
mechanism is fully active.

**Slice 10 — `PlayerRoleView +0x20` is `m_idLastAction`, not a body-id whitelist.**

Earlier notes on this page (now corrected) claimed that `role[+0x20]` was a body-id
whitelist cross-checked by the class-0x69 right-weapon draw. That framing was wrong.
Slice 10 walks the full read/write chain end-to-end in the decompiler and proves the
field is simply the **current playing action id** (`m_idLastAction`). The only thing
the render composite gate does is decide whether to draw the class-0x69 right-weapon
mesh *for this particular animation action*.

Verified read site — `RoleView_SharedRenderComposite` @ `0x10003c85..0x10003cca`:

```
10003c74  if ((*(**(this + 0xd8) + 8))("r_weapon") != 0)     ; "r_weapon" part registered
10003c85  if ((this->m_idWeaponRightSource@+0x40 / 10000) == 0x69)
10003c87      eax_38 = this->m_idLastAction@+0x20            ; load action id
10003cb2  if ((this->m_idWeaponRightSource@+0x40 / 10000) != 0x69
          || eax_38 == 0x191 || eax_38 == 0x192
          || eax_38 == 0x193 || eax_38 == 0x194
          || eax_38 == 0x208 || eax_38 == 0x26c)
10003cca      (*(**(this + 0xd8) + 0xc))("r_weapon", &transformBody, &transformWorld, 1)
```

Semantics, in plain terms:
- If the equipped right weapon is **not** class 0x69 (i.e. `m_idWeaponRightSource / 10000 != 105`)
  the r_weapon draw happens unconditionally, and `m_idLastAction` is never consulted.
- If the right weapon **is** class 0x69, the draw is gated on the currently-playing
  action id being one of `{0x191, 0x192, 0x193, 0x194, 0x208, 0x26c}` = `{401, 402, 403,
  404, 520, 620}`. These are the bow/shoot-style combat actions. During any other
  action (idle, walk, run, sit, cast, etc.) the class-105 right-weapon mesh is
  suppressed — i.e. the bow is only visually held during the actual shoot animations.

Verified writers — `PlayerRoleView_UpdateRolePartMotionsForAction` @ `0x10002dc8`:

- **`0x10003113`** `mov [esi+0x20], ebx` where `ebx = [ebp+8] = actionId`
  — main update path, after all body/helmet/weapon visual-track refreshes have been
  queued. This is the "normal" assignment point.
- **`0x10002e6e`** `mov [esi+0x20], eax` where `eax = [ebp+8] = actionId`
  — mount-only fast path (taken when `this[+0xa8] == 0x3e6` and `this[+0x44] != 0`).
  Returns early via `RoleView_ResolveMountMotionRequest`; only the mount motion and
  the last-action bookkeeping run.

Verified intra-function readers of `+0x20`:
- `0x10002f53` `mov eax, [esi+0x20]; cmp eax, [ebp+8]` — action-change detection.
  If the action is the same as last frame, the function jumps past the blend-state
  reset at `0x10002f5e..0x10002f6a` and the prev→curr motion blend setup at
  `0x10002f72..0x10002fb0`.
- `0x10002f8e` `push [esi+0x20]` — passes the previous action id to
  `GameDataSet` vtable `+0x6c` as the "from-action" argument for computing the
  motion blend duration, stored at `this->m_motionBlendDurationMs@+0xec`.

**No server-visible surface.** `m_idLastAction` is driven entirely by the client game
loop's action-state machine; the spawn/update packets already carry the weapon id and
the action id separately (via `MsgAction` / `MsgPlayerInvokeSpell` / etc.), and the
client composes them locally. There is **no** MsgSpawnPlayer field that needs to feed
`+0x20`. The server-side fix made for slice 9 is sufficient; slice 10 is a pure
client-local interpretation change — the earlier "body whitelist" framing on this page
implied a missing server field, which does not exist. OpenConquer therefore needs no
further change for slice 10.

Parity check for managed code (OpenConquer, future server features): if a class-105
(arrow/bow-family, `itemType / 10000 == 105`) right-weapon source is ever exposed via
a new packet path, remember that the native client will **only show its mesh during
actions 401-404, 520, 620**. This is not a bug — it's the designed visual for ranged
weapons, and managed simulations should not try to "fix" it.

Associated `Conquer.exe` seam (verified during slice 10): the mount/body-look catalog
path routes the look's built-in misc source id via
`CRole__SetMiscSourceAndRefreshRoleView` (`0x006e6083`, previously `sub_6e6083`), which
writes `role->m_nMiscSourceLookupId@+0x12c` and, on a non-zero refresh flag, tailcalls
`CRole__RefreshRoleViewMiscSourceFromCurrent` (`0x006e609c`, previously `sub_6e609c`).
The refresh pushes `this->m_pRoleView@+0x3b4` into
`CRole__ApplyMiscSourceToRoleView`, which invokes
`(*(*roleView + 4))(propertyKey=9, value=this->+0x12c)` — dispatch key 9 =
`PlayerRoleView_SetMiscSource` (slice 9). Call site
`CMsgPlayer__Process @ 0x7564bf` passes `lookRecord[+0x40]` as the look's default
misc source. This field comes from the client-side look catalog; MsgSpawnPlayer does
not carry a misc source over the wire.

**Slice 12 — `RoleView_SharedRenderComposite` full 11-phase body walk.**

Slice 10 pinned the class-0x69 bow gate inside the render composite. Slice 12 walks the
entire function top-to-bottom so the full draw order, every gate, and every matrix branch
are explicitly documented in one place. Every address below was verified against the
decompile and disassembly of `RoleView_SharedRenderComposite` (`0x100038A9`). The section
above (`### Verified slot-10 … field-read map` and `Per-layer body-loaded enable formula`)
covers the field reads and disable formula; this section covers the control-flow phases
and per-phase draw dispatch.

The function takes `(this, *matBodyOut, *matWorldOut)` and returns 1 on success, 0 on
failure. The two output matrices (`matA` = body/model, `matB` = world/position in the
field-read map above) are caller-provided out params used to re-seed later pick and debug
passes.

**Phase 1 — visibility gates (`0x100038b6..0x100038f8`).**

```
i3DRole = *(this + 0xd8)                            ; 0x100038b6
if (i3DRole == 0)            return 0               ; null guard
if (*(this + 0xa8) == 0x3e6) goto mount_only        ; class-998 fast path
if ((*(i3DRole->vtable + 0x08))("body") == 0) return 0
mount_only:
if ((*(i3DRole->vtable + 0x08))("mount") == 0) return 0
```

Body-appearance id `998` (`0x3e6`) is the mount-only render path: the "body must be
loaded" precondition is skipped, but the mount must still be loaded or the composite
bails. For any other appearance id, **both** `body` and `mount` must be loaded. This
matches the `+0xa8 == 0x3e6` special case already captured in the field-read map.

**Phase 2 — transform matrix build (`0x10003903..0x10003a7e`).**

```
CMyBitmap::PrepareModle()                           ; sync camera state
RoleView_SetIdentityMatrix4x4(matA)                 ; model init
RoleView_SetIdentityMatrix4x4(matB)                 ; world init

if (CMyBitmap::GameCameraIsProject() != 0)          ; orthographic branch
    matA = Scale(s, s, s)
         · Translate(0, 0, +0x0c)
         · Rotate(0, 0, +0x18 * pi/180)
    matB = Rotate(0, +0x14 * pi/180, 0)
         · Rotate(+0x10 * pi/180, 0, 0)             ; the oblique isometric tilt
         · Translate(+0x04, 0, +0x08)
else                                                ; projection branch
    matA = Scale(s, s, s)
         · Rotate(+0x10 * pi/180, +0x14 * pi/180,
                  mod(+0x18, 360) * pi/180)
         · Translate(0, 0, +0x0c)
    matB = Translate(+0x04, +0x08, 0)
```

Notes:
- Scale `s = *(this + 0x1c)`.
- The orthographic branch splits the final oblique tilt across matA and matB — matA
  holds model-local scale / Z-depth / Z-spin, matB holds the isometric tilt and the
  screen-space position. The projection branch keeps all rotations on matA and uses
  matB only as a plain `(X, Y)` screen translate.
- `CMyBitmap::GameCameraIsProject()` is the singleton camera-mode query — this is the
  same branch the slot-9 hit test uses, so pick and render stay in lockstep.

**Phase 3 — helmet pre-check loop (`0x10003a7e..0x10003af0`).**

Builds a 3-element local enable-flag array for the per-layer **helmet** draws (the body
draw itself is gated separately in phase 5):

```
enableFlag[0..2] = {1, 1, 1}
cursor = this + 0x24                                ; layer-0 loaded body source
for layer in 0..2:
    id = *cursor
    if ((id / 1000) % 1000) == 137 AND (id % 100) in [20..90]:   ; 0x89, 0x14..0x5a
        enableFlag[layer] = 0
    if ((id / 10000) % 100) == 18:                               ; 0x12
        enableFlag[layer] = 0
    cursor += 4
```

The flag buffer is then consumed in phase 5 via `*(&var_18 + i_1)` where `i_1` walks
`0, -4, -8` (reverse iteration). The digit-decomposition interpretation and the full
encoding rationale are already captured in the "Per-layer body-loaded enable formula"
section above — slice 12 does not alter those facts, only surfaces them as phase 3 of
the composite.

**Phase 4 — mount draw (`0x10003b05..0x10003ba9`).**

```
if ((*(i3DRole->vtable + 0x08))("mount") != 0):
    packed = *(this + 0xcc)
    A = ((packed >> 24) & 0xff) * 0.00392156886f    ; 1/255
    R = ((packed >> 16) & 0xff) * 0.00392156886f
    G = ((packed >> 8)  & 0xff) * 0.00392156886f
    B = ( packed        & 0xff) * 0.00392156886f
    (*(i3DRole->vtable + 0x80))(A, R, G, B, "mount", "none", 0)    ; set tint
    (*(i3DRole->vtable + 0x0c))("mount", matA, matB, 0)            ; draw mount
```

Mount is always drawn first — it is the root of the bind-pose attachment chain for the
body and its variants. The tint is applied exclusively to the mount mesh; body/helmet
layers inherit it through the attachment graph, not through repeated `vtable+0x80` calls.

**Phase 5 — body + helmet layer loop (`0x10003baf..0x10003c31`).**

Iterates layers 2 → 1 → 0 via `i_1 = 0; i_1 -= 4` with loop condition `i_1 >= 0xfffffff8`
(signed -8), and `var_8_4 = arg1 + 0x74` (layer-2 helmet source field) walking down by 4.
Each iteration draws body-then-helmet for that layer. The **name-table base pointers**
are not `BodyAndHelmetVariants` / `HelmetVariants` — they are the **layer-2** entries
`Mix2Body` (`0x10017048`) for the body draw and `Mix2Armet` (`0x10017054`) for the
helmet draw, read via `*(i_1 + &Mix2Body)` / `*(i_1 + &Mix2Armet)`. With `i_1` = 0/-4/-8
this resolves to:

| iter | i_1 | layer | body name                   | helmet name                  |
|-----:|----:|------:|---|---|
| 0    |   0 |   2   | `*0x10017048 = "mix2_body"` | `*0x10017054 = "mix2_armet"` |
| 1    |  -4 |   1   | `*0x10017044 = "mix_body"`  | `*0x10017050 = "mix_armet"`  |
| 2    |  -8 |   0   | `*0x10017040 = "body"`      | `*0x1001704c = "armet"`      |

Gate logic (verified from the decompile at `0x10003bc0` and `0x10003bf2`):

```
bodyLayerSourceField   = *(var_8_4 - 12)            ; this+0x68/0x64/0x60
helmetLayerSourceField = *var_8_4                   ; this+0x74/0x70/0x6c

; Body draw gate — note the "|| i_1 == -8" layer-0 override
if bodyLayerSourceField != 0 OR i_1 == 0xfffffff8:
    (*(i3DRole->vtable + 0x0c))(*(i_1 + &Mix2Body), matA, matB, 0)

; Helmet draw gate — same layer-0 override on the source field; enable flag still gates
if (helmetLayerSourceField != 0 OR i_1 == 0xfffffff8)
   AND enableFlag[i_1 byte-index] != 0
   AND (*(i3DRole->vtable + 0x08))(*(i_1 + &Mix2Armet)) != 0:
    (*(i3DRole->vtable + 0x0c))(*(i_1 + &Mix2Armet), matA, matB, 1)
```

**Layer-0 override:** on the final iteration (`i_1 = -8`), the body-source field check
is bypassed entirely. The native draw therefore treats layer-0 body (`"body"`) and
layer-0 helmet (`"armet"`) as **always attempted** regardless of whether `+0x60` /
`+0x6c` are non-zero — they still go through the i3drole load query on the helmet side
(`vtable+0x08("armet")`) and the usual per-part enable flag. The body draw on layer 0
has no further gate once the source-field check is bypassed. This matches the concept
that the primary body / helmet slot is the "always-visible" layer while
`mix_body/mix2_body` and `mix_armet/mix2_armet` are optional overlays.

The `enableFlag` index is `*(&var_18 + i_1)`. `var_20 / var_1c / var_18` were written
in that order inside the phase-3 loop as layer `0 / 1 / 2` flags — i.e. `&var_18` is
the layer-2 flag, `&var_18 - 4` is the layer-1 flag, `&var_18 - 8` is the layer-0 flag —
so indexing by `i_1 ∈ {0, -4, -8}` picks the correct per-layer flag on each iteration.

Body draws pass `arg4 = 0`; helmet draws pass `arg4 = 1`.

**Output render order** (flattened across phases 4-8):

```
mount  →  mix2_body  →  mix2_armet  →  mix_body  →  mix_armet  →  body  →  armet  →  misc  →  r_weapon  →  l_weapon
```

Note the interleaving: body-then-helmet is preserved **per layer**, but bodies are
not all drawn before helmets across layers. Any managed code that groups all body
variants before all helmet variants (e.g. flattening the native order into
`body, mix_body, mix2_body, armet, mix_armet, mix2_armet`) is **not a parity match**
and will produce different alpha-blended results when the variant layers visually
overlap.

**Phase 6 — misc draw (`0x10003c46..0x10003c5e`).**

```
if ((*(i3DRole->vtable + 0x08))("misc") != 0):
    (*(i3DRole->vtable + 0x0c))("misc", matA, matB, 1)
```

Misc is gated only on the I3DRole load check — no field read on `+0x48`. The `*(this+0x48)`
misc source family is a setter-side cache only; once the part is loaded, the draw uses
`vtable+0x08` as its sole gate.

**Phase 7 — right weapon draw with class-0x69 bow gate (`0x10003c61..0x10003cca`, slice 10).**

```
if ((*(i3DRole->vtable + 0x08))("r_weapon") != 0):
    rightSourceFamily = *(this + 0x40)
    if (rightSourceFamily / 10000) == 0x69:
        currentAction = *(this + 0x20)              ; m_idLastAction
    if (rightSourceFamily / 10000) != 0x69
       OR currentAction in {0x191, 0x192, 0x193, 0x194, 0x208, 0x26c}:
        (*(i3DRole->vtable + 0x0c))("r_weapon", matA, matB, 1)
```

Non-bow right weapons draw unconditionally. Class-0x69 (bow family,
`itemType / 10000 == 105`) right weapons are drawn only during actions
`{401, 402, 403, 404, 520, 620}` (the bow/shoot animations). See the slice 10 section
above for the full server-parity implication.

**Phase 8 — left weapon draw (`0x10003ce0..0x10003cf8`).**

```
if ((*(i3DRole->vtable + 0x08))("l_weapon") != 0):
    (*(i3DRole->vtable + 0x0c))("l_weapon", matA, matB, 1)
```

No class gate on the left weapon. `*(this + 0x3c)` (left-weapon source family) is not
read by the composite — loading gate only.

**Phase 9 — per-layer body finalize loop (`0x10003cfb..0x10003d16`).**

```
i_2 = &RoleView_RolePartNameTable_BodyAndHelmetVariants
while i_2 < &HelmetVariants:
    (*(i3DRole->vtable + 0x38))(*i_2)               ; finalize "body" / "mix_body" / "mix2_body"
    i_2 += 4
```

`&HelmetVariants = &BodyAndHelmetVariants + 12`, so the loop covers exactly the 3 body
variant names. I3DRole slot `+0x38` is
`I3DRole_ResetPartRenderStateByName`: it restores each submesh color to white and clears
its temporary matrix without changing motion. This is the verified native call site for
body render-state finalization after draw (not helmet).

**Phase 10 — mount finalize (`0x10003d1c..0x10003d29`).**

```
if (*(this + 0x44) != 0):
    (*(i3DRole->vtable + 0x38))("mount")
```

Mount render-state finalization is gated on the cached mount source family being
non-zero (`+0x44`), not on the load query. This is the only composite-level read of
`+0x44`.

**Phase 11 — return 1 (`0x10003d2e..`).**

Epilogue.

**Consolidated per-part dispatch table for the composite.**

| Phase | Part family                      | Load gate                         | Extra gate                                                               | Draw flags | Finalize |
|------:|---|---|---|---:|---|
| 4  | `mount`                             | `vtable+0x08("mount")`            | —                                                                        | 0 | phase 10 (if `+0x44 != 0`) |
| 5  | body layer 2 (`mix2_body`)          | —                                 | `+0x68 != 0`                                                             | 0 | phase 9 loop |
| 5  | helmet layer 2 (`mix2_armet`)       | `vtable+0x08("mix2_armet")`       | `+0x74 != 0 AND phase3.enableFlag[2] != 0`                               | 1 | none |
| 5  | body layer 1 (`mix_body`)           | —                                 | `+0x64 != 0`                                                             | 0 | phase 9 loop |
| 5  | helmet layer 1 (`mix_armet`)        | `vtable+0x08("mix_armet")`        | `+0x70 != 0 AND phase3.enableFlag[1] != 0`                               | 1 | none |
| 5  | body layer 0 (`body`)               | —                                 | **always** (source-field check bypassed by `i_1 == -8`)                  | 0 | phase 9 loop |
| 5  | helmet layer 0 (`armet`)            | `vtable+0x08("armet")`            | `phase3.enableFlag[0] != 0` (source-field check bypassed by `i_1 == -8`) | 1 | none |
| 6  | `misc`                              | `vtable+0x08("misc")`             | —                                                                        | 1 | none |
| 7  | `r_weapon`                          | `vtable+0x08("r_weapon")`         | class-0x69 bow gate (slice 10)                                           | 1 | none |
| 8  | `l_weapon`                          | `vtable+0x08("l_weapon")`         | —                                                                        | 1 | none |

The draw-flag column pins the verified `arg4` to `vtable+0x0c`: mount and body use `0`,
everything else uses `1`. The finalize column pins the exact finalize-after-draw set: the
composite only finalizes body layers and mount, nothing else.

No `sub_*` helpers remain in this function — every callee (i3DRole vtable slots, the
`CMyBitmap::*` camera helpers, `RoleView_SetIdentityMatrix4x4`) is already named.

**Cross-reference to `PlayerRoleView` field map.** Every field read in the composite is
captured in the existing slot-10 field-read map (lines ~288-325 above). Slice 12 adds
no new field discoveries; it is a control-flow consolidation pass. Fields explicitly
*not* read by the composite remain: `+0x30..+0x38`, `+0x3c`, `+0x48`, `+0x50..+0x5c`,
`+0x78..+0x94`, `+0x98..+0xc4`, `+0xb0..+0xb8`, `+0xd0/+0xd4`.

- key `0`: body-appearance-source update (`PlayerRoleView_SetBodyAppearanceSource`, `0x10001EB8`)
  - asserts `0 < nLook < 1000`
  - stores `nLook` at `this+0xA8`
  - rewrites already-loaded body/helmet part source ids as `nLook * 1_000_000 + existing_low_6_digits`
  - on a fresh player RoleView (body/helmet source fields still zero), it emits:
    - `PlayerRoleView_LoadPartSourceIntoI3DRole(this, "body", "v_mount", "mount", nLook * 1_000_000, 0)`
    - `PlayerRoleView_LoadPartSourceIntoI3DRole(this, "mix_body", "v_mount", "mount", nLook * 1_000_000, 0)`
    - `PlayerRoleView_LoadPartSourceIntoI3DRole(this, "mix2_body", "v_mount", "mount", nLook * 1_000_000, 0)`
- key `1`: stores `this+0xB0` and updates one linked source through
  `PlayerRoleView_ReloadHelmetVariantAtLayer` (`0x10002036`)
  - `Conquer.exe` feeds this from `CRole__SetLinkedSourceLookupId` (`0x64DB3C`)
  - the packet source is `HairCompositeId % 1000`
  - native `CRole__ApplyLinkedSourceLookupIdToRoleView` zeroes values where
    `linkedSourceLookupId % 100 == 0` before dispatching key `1`
- key `2`: `PlayerRoleView_SetHeadAttachmentSource` (`0x100024A7`)
  - compares the incoming head-attachment source against the cached value at `this+0xAC`
  - when the cached source is non-zero, calls `I3DRole_RemovePartRecordsFromGameData("body", "head", oldSource)`
  - clears `this+0xAC`
  - when the new source is non-zero, calls `I3DRole_AddPartRecordsFromGameData("body", "head", newSource)`
  - stores the new attachment source at `this+0xAC` only when the add call succeeds
  - this is not a standalone top-level `"head"` part load; it mutates the existing `"body"` `PartInfo`
    record list by appending/removing `"head"` records from game data
  - `Conquer.exe` feeds this from `CRole__SetHeadAttachmentSource` (`0x64DC01`)
  - the packet source is `HairCompositeId / 1000`
- key `3`: `PlayerRoleView_ResetSourcesAndRebuildBodyAppearance` (`0x100024F9`)
  - clears loaded body/helmet/misc/weapon/mount source fields, clears the i3drole links, then re-enters key `0`
- key `5`: `PlayerRoleView_SetPrimaryHelmetVariantSourceAndReload` (`0x10001FE2`)
  - stores the incoming primary helmet source family at `this+0x6C`
  - then reloads layer `0` through `PlayerRoleView_ReloadHelmetVariantAtLayer(this, value, 0)`
- key `6`: `PlayerRoleView_SetRightWeaponSource` (`0x10001AEC`)
  - stores the right-weapon source family used by `PlayerRoleView_UpdateRolePartMotionsForAction`
  - updates `"r_weapon"` and handles the verified `0x69` override swap path before optional left-weapon cleanup
- key `7`: `PlayerRoleView_SetLeftWeaponSource` (`0x10001A08`)
  - stores the left-weapon source family used by `PlayerRoleView_UpdateRolePartMotionsForAction`
  - updates `"l_weapon"` and handles the verified `0x69` override swap path before optional right-weapon cleanup
- key `8`: `PlayerRoleView_SetMountSource` (`0x10001BE2`)
  - stores the mount source family and refreshes `"mount"`
- key `9`: `PlayerRoleView_SetMiscSource` (`0x10001C2D`)
  - stores the misc source family and rebuilds it as `bodyAppearanceSourceId * 1_000_000 + low_6_digits`
- slot `7`: `PlayerRoleView_EnsurePartEffectInstanceBySelectorAndName` (`0x10003486`)
  - selector `1` → ensure `armet` exists with `v_armet -> body`, then ensure the named effect
  - selector `4` → ensure `body` exists with `v_mount -> mount`, then ensure the named effect
  - selector `6` → ensure `r_weapon` exists with `v_r_weapon -> body`, then ensure the named effect
  - selector `7` → ensure `l_weapon` exists with `v_l_weapon -> body`, then ensure the named effect
  - selector `8` → ensure `mount` exists with `none -> none`, then ensure the named effect
  - selector `9` → ensure `misc` exists with `v_misc -> body`, then ensure the named effect
  - fresh player-RoleView ctor zeroes `+0x90/+0x94`, so a brand-new player RoleView reaches this path with weapon override lookup ids `0`
- key `0x34`: `PlayerRoleView_SetPrimaryBodyVariantOverrideAndReload` (`0x100023A5`)
  - stores the override value at `this+0x78`
  - immediately refreshes the currently loaded source stored at `this+0x24`
- key `0x37`: `PlayerRoleView_SetPrimaryHelmetVariantOverrideAndReload` (`0x10002389`)
  - stores the override value at `this+0x84`
  - immediately refreshes the currently loaded source stored at `this+0x30`
- key `0x3A`: `PlayerRoleView_SetLeftWeaponOverrideSource` (`0x100023C0`)
  - stores the left-weapon override value at `this+0x90`
  - immediately refreshes the current left-weapon source stored at `this+0x3C`
- key `0x3B`: `PlayerRoleView_SetRightWeaponOverrideSource` (`0x100023DA`)
  - stores the right-weapon override value at `this+0x94`
  - immediately refreshes the current right-weapon source stored at `this+0x40`
- key `0xA`: `PlayerRoleView_SetPrimaryFrameForAllRoleParts(this, value)` (`0x100028B6`)
- key `0xB`: stores value at `this+0x10`
  - verified meaning: **X-axis rotation in degrees** for the role's world transform
  - ctor default: `CMyBitmap::GetObliqueAngle()` (the global oblique camera tilt)
  - consumed by slot 9 (`RoleView_SharedScreenPickHitTestAgainstBoundingBox`) and slot 10
    (`RoleView_SharedRenderComposite`) where both branches multiply it by `pi/180` and feed
    it into `CMyBitmap::Common_Rotate` as the X rotation component
- key `0x1F`: stores value split into two fields:
  - `this+0xD0` = low 16 bits (`value & 0xFFFF`)
  - `this+0xD4` = high 16 bits (`value >> 16`)
- key `0x20`: dispatches to `I3DRole` vtable+0x48 (`I3DRole_ApplyMeshLevelOperationToPartsOrNamed`, `0x10001B00` in Role3D.dll)
  - calls with `(value, 0)` meaning "apply to all parts"
  - the inner helper iterates all loaded parts and applies
    `C3DObjX_SetStepAndRenderFlags(value, 0)` to every mesh instance via mesh vtable `+0x60`
    (verified target `0x10007250` in graphic.dll)
  - `C3DObjX_SetStepAndRenderFlags(arg1, arg2)`:
    - if `arg1 > 0`: stores `mesh[1] = arg1`
    - else: stores `mesh[1] = 4` (default)
    - stores `mesh[2] = arg2`
  - the I3DRole wrapper also marks each part as needing refresh
    (dirty flag at `role3dObj+0xFC+partIndex = 1`)
  - net effect: writes the per-mesh step/render-flag pair `(value or 4, 0)` to every mesh
    of every loaded part of the role; the higher-level meaning of those two fields is the
    `C3DObjX` step counter / render flag pair used by `C3DObjX_Render`
- key `0x21`: stores value at `this+0x14`
  - verified meaning: **Y-axis rotation in degrees** for the role's world transform
  - consumed by slot 9 (`RoleView_SharedScreenPickHitTestAgainstBoundingBox`) and slot 10
    (`RoleView_SharedRenderComposite`) where both branches multiply it by `pi/180` and feed
    it into `CMyBitmap::Common_Rotate` as the Y rotation component
- key `0x22`: stores value at `this+0x18`
  - verified meaning: **Z-axis rotation in degrees** for the role's world transform
  - consumed by slot 9 / slot 10 as the Z rotation component
  - in the non-project camera branch, both consumers wrap it through `mod(value, 360)` first
  - also written by `RoleView_SharedSetTransformFromCamera` (slot 4) as its `arg5` parameter,
    so external camera updates can override the stored value
- key `0x23` / `0x29` / `0x2D`: stores texture/material override at `this+0x50 + layer*4`
  (layered helmet texture override), then looks up current helmet source via
  `GameDataSetQuery()->vtable+0x54("armet", this+0x30+layer*4)`, and if found, calls
  `RoleView_BindPartTextureAndMaterialFromSourceIds(this, helmetVariantPartName, value, record+0x24)`
- key `0x24`: stores texture/material override at `this+0x4C`
  (body texture override), then looks up current body source via
  `GameDataSetQuery()->vtable+0x54("body", this+0x24)`, and if found, calls
  `RoleView_BindPartTextureAndMaterialFromSourceIds(this, bodyPartName, value, record+0x24)`
- key `0x25`: stores texture/material override at `this+0x5C`
  (left-weapon texture override), then looks up current left-weapon source via
  `GameDataSetQuery()->vtable+0x54("l_weapon", this+0x3C)`, and if found, calls
  `RoleView_BindPartTextureAndMaterialFromSourceIds(this, "l_weapon", value, record+0x24)`
- key `0x26`: bulk texture/material refresh for all 11 role part categories
  - uses a lazily-initialized static part name table (`RoleView_BulkRefreshPartNameTable` at `0x10019CA4`):
    `["body", "mix_body", "mix2_body", "armet", "mix_armet", "mix2_armet", "misc", "l_weapon", "r_weapon", "mount", "head"]`
  - parallel source-id array from player RoleView fields:
    `[this+0x24, this+0x28, this+0x2C, this+0x30, this+0x34, this+0x38, this+0x48, this+0x3C, this+0x40, this+0x44, this+0xAC]`
  - parallel texture/material override array:
    `[this+0x4C, this+0x4C, this+0x4C, this+0x50, this+0x54, this+0x58, 0, this+0x5C, 0, 0, 0]`
    (body variants share the primary body override; misc/r_weapon/mount/head have no texture override)
  - for each part: if texture override > 0, uses override; else looks up source record via
    `GameDataSetQuery()->vtable+0x54(partName, sourceId)` and uses `record+0x14` as default texture
  - calls `RoleView_BindPartTextureAndMaterialFromSourceIds(this, partName, textureId, arg3)` for each part
  - `arg3` (the value passed to key 0x26) is the material id propagated to all bind calls
- key `0x27` / `0x2B`: `PlayerRoleView_SetHelmetVariantSourceAndReloadAtLayer` at the mapped layer
- key `0x28` / `0x2C`: `PlayerRoleView_SetBodyVariantSourceAndReloadAtLayer` with `useStoredOverride=0` at the mapped layer
- key `0x2F`: stores value at `this+0xCC`
  - verified meaning: **packed ARGB color tint** (8 bits per channel)
  - ctor default: `0xFFFFFFFF` (white, full alpha)
  - consumed by slot 10 (`RoleView_SharedRenderComposite`): unpacks each byte and divides by `255`
    to produce four floats `(A, R, G, B)`, then calls `I3DRole` vtable slot `+0x80` with
    `(alpha, red, green, blue, "mount", ...)` to apply the tint to the `mount` part
- key `0x32`: stores value at `this+0xB4` (probe/pick screen X coordinate for key 0x31 ray test)
- key `0x33`: stores value at `this+0xB8` (probe/pick screen Y coordinate for key 0x31 ray test)
- key `0x3C`: `PlayerRoleView_SetPrimaryBodyVariantSourceAndReload(this, value, 1)` (with `useStoredOverride=1`)
- key `0x3D` / `0x3E`: `PlayerRoleView_SetBodyVariantSourceAndReloadAtLayer(this, value, 1, layer)` (with `useStoredOverride=1`)
- key `0x35` / `0x36`: `PlayerRoleView_SetBodyVariantOverrideAndReloadAtLayer` at the mapped layer
- key `0x38` / `0x39`: `PlayerRoleView_SetHelmetVariantOverrideAndReloadAtLayer` at the mapped layer

Parity implication for player packets:

- player RoleViews use type `1`, not type `4`
- the low-range player appearance source consumed by player-RoleView key `0` is a separate field from the packed `lookface`
- packet/application code must therefore preserve both:
  - packed `lookface` / hair composites
  - the distinct player-RoleView body appearance source id

Verified player construction call-sites in `Conquer.exe`:

- `CMsgUserInfo__Process` (`0x764276`)
  - reads packet `+0x0A`
  - computes `% 1000`
  - calls `CRole__CreateRoleView(role, remainder, 1)` (`0x64D51F`)
  - then immediately applies packet `+0x08` through the separate refresh path (`CRole__SetTransformLookSourceId`, `0x650B1F`)
- `CMsgPlayer__Process` (`0x755F64`)
  - reads packet `+0x04`
  - computes `% 1000`
  - calls `CRole__CreateRoleView(role, remainder, 1)` (`0x64D51F`)
  - later applies packet `+0x26` through the same refresh helper family

## Conquer.exe player-RoleView visual-source reapply chain

The normal player-role equipment / appearance reapply path is separate from
`CRole__SetTransformLook`.

Verified helper order in `CRole__ApplyAllVisualSourcesToRoleView` (`0x650AD0`):

1. `CRole__ApplyHelmetVariantSourcesToRoleView` (`0x6E57A6`)
2. `CRole__ApplyBodyVariantSourcesToRoleView` (`0x6E60D7`)
3. `CRole__ApplyLinkedSourceLookupIdToRoleView` (`0x64DB63`)
4. `CRole__ApplyHeadAttachmentSourceToRoleView` (`0x64DC28`)
5. `CRole__ApplyLeftWeaponSourcesToRoleView` (`0x6E5CB7`)
6. `CRole__ApplyMiscSourceToRoleView` (`0x6E60A8`)
7. `CRole__ApplyMountSourceToRoleView` (`0x6E5E45`)
8. `CRole__ApplyRightWeaponSourcesToRoleView` (`0x6E5B7C`)

`CRole__ReapplyAllVisualSources` (`0x650AB9`) simply calls that helper with the current
RoleView pointer at `role[0xED]`, then refreshes mounted action-scale state through
`Role_UpdateMountActionScaleCacheFromRoleState`.

### Verified body / helmet variant field groups behind the reapply chain

`CRole__ApplyHelmetVariantSourcesToRoleView` (`0x6E57A6`) is driven by the role-side
primary helmet cluster:

- `role+0x140`: primary helmet variant source family
- `role+0x130`: primary helmet variant override lookup id
- `role+0xF0`: primary helmet texture-variant selector
- local-hero writer: `CHeroItem__SetEquipSlot` slot `1` stores
  `CItem__GetRoleViewTextureVariantSelector(item)` here, else fallback selector `3`

Verified property-key tables used by that helper:

- `0x86B720` -> `{ 5, 0x27, 0x2B }` helmet source keys
- `0x86B72C` -> `{ 0x37, 0x38, 0x39 }` helmet override keys
- `0x86B738` -> `{ 0x0E, 0x2A, 0x2E }` RoleView query keys used before map lookup

Verified outputs:

- the helper writes per-layer helmet lookup caches at `role+0x104`, `role+0x108`, and
  `role+0x10C`
- when `source != 0` and `override == 0`, it queries the current RoleView property from the
  `0x86B738` table and resolves the cache through the `ItemType.dat` singleton rooted at
  `0x96AE88` using:
  - the stored RoleView source as the `ItemTexture.ini` section key
  - `role+0xF0` as the `ColorN` variant selector
  - fallback selector `3` on miss

#### Verified loop body (2026-09-06)

The helper runs one loop over three layers, `i = 0, 4, 8`. It is seeded two different ways and
the loop body is duplicated per path; the bodies are identical apart from one ordering detail.

Guards before either path: `arg2 != 0` (RoleView present) and `role+0xEC == 0`.
`role+0xDC == 3` forces the override input to `0`.

Seeding:

- **`role+0xE0 == 0`** — the plain path. A `memset(&overrides, 0, 0x18)` zeroes both the
  three-entry override array and the three-entry source array, then only layer 0 is filled:
  `overrides[0] = role+0x130`, `sources[0] = role+0x140`. The selector is `role+0xF0` for
  **every** layer. Layers 1 and 2 therefore have `source == 0` and do nothing.
- **`role+0xE0 != 0`** — the layered path, driven by **`CSuitStatusMgr`** (identified 2026-09-06).
  `CSuitStatusMgr_FindRecordByRoleField0xCC(CSuitStatusMgr_GetSingletonPtr(), &rec, role+0xCC)`
  looks up a suit-status record; predicates and accessors on it choose per layer between
  `role+0x130`/`role+0x140` and a source read from the record, with `override = 0`. Selectors come
  from the record, falling back to `3`. **This record is the only producer of non-zero layers 1
  and 2.**

### `CSuitStatusMgr` / `CSuitStatusRecord` (2026-09-06)

Manager identity is from `CSuitStatusMgr_GetSingletonPtr` (`0x4902A3`), whose
`type_info::name(&data_921F48)` resolves to the RTTI descriptor whose name string at `0x921F50`
is `".?AVCSuitStatusMgr@@"`. Singleton pointer at `data_956068`; object `0x10` bytes; constructed
by `sub_6C2ED7`. The clean asset set ships `ini/suittype.dat`.

`CSuitStatusMgr_FindRecordByRoleField0xCC` (`0x6C2F57`) is a linear scan over a
`vector<shared_ptr<CSuitStatusRecord>>` at `mgr+0x04`..`mgr+0x08`, matching
`CSuitStatusRecord_GetKey(rec) == role+0xCC`. It addrefs before each compare and releases on a
miss, so the returned pointer carries a fresh reference.

`CSuitStatusRecord` is `0xD0` bytes, allocated by `CSuitStatusMgr_AddOrUpdateRecord` and built by
`CSuitStatusRecord_Constructor` (`0x7080DF`), which takes the entity id (stored at `+0x84`).

**A record holds two suit slots.** `CSuitStatusRecord_LoadSuitTypeRowIntoSlot` (`0x70856A`) fills
one of them from a row of **`ini/SuitType`** via `CConfigDataTableQueryProvider`, keyed by the row
id the ranking function passed. That table read is what confirms the RTTI class name — the shipped
asset is `ini/suittype.dat`. `CSuitStatusRecord_ResetSlotGroup` (`0x70847E`) clears one slot, and
the two slots' fields do not overlap.

Slot 0 columns:

| Column | Field | Column | Field |
|---|---|---|---|
| `ActionType` | `+0x04` | `Equipshow` | `+0x2C` |
| `Headgear` | `+0x18` | `HeadgearColor` | `+0x1C` |
| `Armor` | `+0x20` | `ArmorColor` | `+0x24` |
| `Mantle` | `+0x48` | `Mount` | `+0x38` |
| `Hair` | `+0x30` | `Lookface` | `+0x34` |
| `Scene` | `+0x60` | `Title` | `+0x74` |
| `WeaponL` | `+0x78` | `WeaponLColor` | `+0x7C` |
| `WeaponR` | `+0x80` | `Headgear_mono` | `+0x14` |
| `Mantle_mono` | `+0x44` | `Scene_mono` | `+0x5C` |
| `Statuseffect_mono` | `+0x68` | `Family_name` | string `+0x88` |
| `Name` | string `+0x94` | `Statuseffect` | string `+0xAC` |
| `Syndicate_name` | string `+0xB8` | | |

Slot 1 is a strict subset: `Equipshow` `+0x28`, `Headgear` `+0x08`, `Mantle` `+0x3C`,
`Scene` `+0x54`, `Headgear_mono` `+0x10`, `Mantle_mono` `+0x40`, `Scene_mono` `+0x58`,
`Statuseffect_mono` `+0x64`, `Statuseffect` string `+0xA0`.

Every colour column is clamped: below `3` or above `9` is forced to `3` — the same fallback variant
selector the helmet resolve loop uses. A slot is only populated when its `Equipshow` is `> 0`.

Accessors the helmet seeder uses, now named for their columns:

| Accessor | Reads |
|---|---|
| `CSuitStatusRecord_GetKey` (`0x6C811A`) | entity id, matched against `role+0xCC` |
| `CSuitStatusRecord_HasSlot0HeadgearMono` (`0x708302`) | `+0x14 > 0` |
| `CSuitStatusRecord_GetSlot0Headgear` (`0x699C75`) | `+0x18` |
| `CSuitStatusRecord_GetSlot0HeadgearColor` (`0x687190`) | `+0x1C` |
| `CSuitStatusRecord_HasSlot1HeadgearMono` (`0x7082F9`) | `+0x10 > 0` |
| `CSuitStatusRecord_GetSlot1HeadgearWhenNoMono` (`0x708268`) | `(+0x14 <= 0 && +0x10 <= 0) ? +0x08 : 0` |

**Correction:** these were first named `IsPrimarySlotPopulated` / `GetPrimarySlotSource` /
`GetIdleFallbackSource` and so on, inferred from how the helmet code consumes them. The SuitType
column map shows they are headgear and headgear-colour fields of two suit slots. The *shape* of the
earlier reading held; the names did not.

### Top-two ranking — `CSuitStatusRecord_AddTitleAndRankTopTwo` (`0x70831D`)

`(rec, titleId, titleSlot)`. Returns `0` for a zero title id, `1` if the title is already in the
record's pair vector (`+0xC4`..`+0xCC`, stride 8, `{titleSlot, titleId}`). Otherwise it appends the
pair and ranks **by `titleSlot`, keeping the best two**:

```
if (titleSlot > rec+0x50):                 ; beats the current best
    rec+0x6C = rec+0x70 ; rec+0x4C = rec+0x50      ; demote best -> second
    rec+0x70 = titleId  ; rec+0x50 = titleSlot     ; install new best
    apply(titleSlot, titleId) ; apply(titleSlot, rec+0x6C)
    return 6
else if (titleSlot > rec+0x4C):            ; beats only the second
    rec+0x6C = titleId ; rec+0x4C = titleSlot
    apply(titleSlot, titleId)
    return 5
else:
    return 3                               ; ranked but not displayed
```

`+0x4C`/`+0x50` are the two slot ranks (both `-1` from the constructor) and `+0x6C`/`+0x70` the two
title ids. **That is the source of the two visual layers** the helmet code reads: a role shows at
most the top two titles by slot, and the primary/secondary field groups above hold their resolved
sources and selectors.

### The producer: `CMsgTitleVisual` (2070), not a suit packet

`CMsgTitleVisual__Process` (`0x707CE4`, already documented in
`Network/10_extended_packets.md`) is what fills and empties the vector. It switches on the
packet's mode word:

| Mode | Call |
|---|---|
| 1 | `CSuitStatusMgr_AddOrUpdateRecord(mgr, entityId, titleId, titleSlot)` (`0x6C3001`) |
| 2 | `CSuitStatusMgr_RemoveRecordByEntityAndTitleId(mgr, entityId, titleId)` (`0x6C3171`) |

Each mode repeats the call with key `1` when the target is the local hero, then refreshes
`CRole3DSceneMgr` and posts UI messages `0xCE9` and `0x3FB`.
`EntityManager_RemoveEntityById` also calls `CSuitStatusMgr_RemoveRecordByEntityId`
(`0x6C30E9`) so records die with their entity.

So the registry is keyed by entity id and carries the packet's `titleId` / `titleSlot`. The class
name is the binary's own — RTTI `".?AVCSuitStatusMgr@@"` — while the existing packet note
describes the same object as a "title manager". Both are the same registry; **suit-set and title
visuals share it**. That is why `CRole__ApplyHelmetVariantSourcesToRoleView` consults it for the
layered helmet caches.

### Verified per-layer seeding (2026-09-06, from disassembly)

Stack arrays: sources `[ebp-0x28/-0x24/-0x20]`, overrides `[ebp-0x34/-0x30/-0x2C]`, selectors
`[ebp-0x40/-0x3C/-0x38]`. All six source/override slots are zeroed at `0x6E57FB`.

**Plain path** (`role+0xE0 == 0`, `0x6E5A54`): layer 0 takes `role+0x140` / `role+0x130`, and the
loop passes `role+0xF0` as the selector for **all three** layers — it never reads the selector
array. Layers 1 and 2 are inert.

**Layered path**: selectors default to `3` (`0x6E5835`). With no record (`0x6E5979`) layer 0 is
seeded exactly as the plain path. With a record it is a **priority cascade**:

| Condition | Layer 0 | Layer 1 | Layer 2 |
|---|---|---|---|
| `IsPrimarySlotPopulated` | primary slot source + its selector | — | — |
| primary source > 0, fallback > 0, secondary not populated | primary slot | idle fallback | role's own helmet |
| primary source > 0, fallback > 0, secondary populated | primary slot | idle fallback | — |
| primary source > 0, fallback == 0, secondary not populated | primary slot | role's own helmet | — |
| primary source == 0, fallback > 0 | idle fallback | — | — |
| both == 0, secondary not populated | role's own helmet | — | — |
| both == 0, secondary populated | — | — | — |

Two behaviours worth naming:

- **A populated primary slot short-circuits everything.** It claims layer 0 and the other two stay
  inert regardless of the fallback source.
- **The role's own helmet only ever fills the first layer the registry has not claimed**, and a
  populated secondary slot suppresses it entirely — the registry sources still claim their layers.
- Without a primary slot source the cascade never advances past layer 0, so an idle fallback alone
  drops the role's own helmet rather than pushing it down.

Managed: `10_work/src/Conquer/Role/Appearance/Loading/CRoleHelmetVariantLayerSeeder.cs`, tests in
`tests/Conquer.Tests/Client/Role/CRoleHelmetVariantLayerSeederTests.cs`.

The `titleSlot` the ranking function carries is the **`ini/SuitType` row id**, and `titleId` is
only the registry key used for dedup and removal — neither is stored in the slot fields directly.

Loop body per layer `i`:

```
role[0x104 + i] = 0
roleView->vt[0x04](sourceKeys[i],   sources[i])      ; 0x86B720 -> { 5, 0x27, 0x2B }
roleView->vt[0x04](overrideKeys[i], overrides[i])    ; 0x86B72C -> { 0x37, 0x38, 0x39 }
if (sources[i] != 0 && overrides[i] == 0):
    stored = roleView->vt[0x2C](queryKeys[i])        ; 0x86B738 -> { 0x0E, 0x2A, 0x2E }
    if ((stored % 1000000) / 1000 != (role+0x140) / 1000):
        break                                        ; stops the WHOLE loop, not just this layer
    cache = ItemTypeDataSingleton_FindItemTextureVariant(&data_96AE88, stored, selectors[i])
    if (cache == 0):
        cache = ItemTypeDataSingleton_FindItemTextureVariant(&data_96AE88, stored, 3)
    role[0x104 + i] = cache
```

Three details not previously recorded:

- **The family-class guard.** `(stored % 1000000) / 1000` must equal `(role+0x140) / 1000` — the
  layer's stored RoleView source must share a family class with the **primary** helmet source
  family, for every layer. Not the layer's own source.
- **A mismatch `break`s.** It abandons the remaining layers rather than skipping one.
- **The two paths push the RoleView properties in opposite order.** The plain path writes the
  override key first (`0x6E5A7A`), the layered path writes the source key first (`0x6E59A5`).

Managed status: `PlayerRoleViewTextureMaterialBindingSourceResolver` covers layer 0 through the
load-request resolvers and leaves layers 1 and 2 at zero, which matches the plain path exactly.
It does **not** model the family-class guard; doing so needs the relationship between the
load-request composed source and the RoleView stored source proven first, which it is not.

`CRole__ApplyBodyVariantSourcesToRoleView` (`0x6E60D7`) is driven by the role-side
primary body cluster:

- `role+0x11C`: primary body variant source family
- `role+0x134`: primary body variant override lookup id
- `role+0xF4`: primary body texture-variant selector
- local-hero writer: `CHeroItem__SetEquipSlot` slot `3` stores
  `CItem__GetRoleViewTextureVariantSelector(item)` here, else fallback selector `3`
- `role+0x144`: shared body/helmet fallback variant selector

Verified property-key table used by that helper:

- `0x86B750` -> `{ 0x3C, 0x3D, 0x3E }` body source keys

Verified primary-body behavior:

- the helper loops the `0x3C/0x3D/0x3E` keys first and zeros key `0x34` in the same pass
- it then dispatches key `4` from `role+0x11C`
- dispatches key `0x34` from `role+0x134`
- when `source != 0` and `override == 0`, it queries RoleView key `0x0F`
- on family-class match, it resolves the primary body lookup cache at `role+0x110`
  through the same `ItemType.dat` singleton, first with the current body texture-variant
  selector and then with fallback selector `3`. The queried RoleView stored source is the
  `ItemTexture.ini` section key; the selector input is the current body selector value
  (`role+0xF4`, or the current equipped-item selector when the helper refreshes from the
  live item object path).

`CRole__ApplyLeftWeaponSourcesToRoleView` (`0x6E5CB7`) adds the fifth cached lookup id used
by the live render path:

- inputs:
  - `role+0x124`: left-weapon source family
  - `role+0x138`: left-weapon override input
  - `role+0xF8`: left-weapon texture-variant selector
  - local-hero writer: `CHeroItem__SetEquipSlot` slot `5` stores
    `CItem__GetRoleViewTextureVariantSelector(item)` here, else fallback selector `3`
  - `role+0xE4`: extra left-weapon override lookup input
- dispatches:
  - RoleView key `0x3A` from the override input
  - RoleView key `7` from the effective left-weapon source
- output:
  - `role+0x114` is the cached left-weapon lookup id
  - when the effective source is non-zero, override input is zero, and the effective family
    class is `6`, native queries RoleView key `0x0D`, resolves through the `ItemType.dat`
    singleton rooted at `0x96AE88`, and writes the result to `role+0x114` with fallback
    selector `3`. The queried RoleView stored source is again the `ItemTexture.ini`
    section key, and `role+0xF8` supplies the variant selector.

`CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView` (`0x6E56D0`) is the verified
live render-time consumer of those role-side caches:

- selector `'#'` <- `role+0x104`
- selector `')'` <- `role+0x108`
- selector `'-'` <- `role+0x10C`
- selector `0x24` <- `role+0x110`
- selector `0x25` <- `role+0x114`

These selector codes enter the separate player-RoleView texture/material rebinding seam, not the
mesh-instance selection seam:

- `0x23..0x26` are verified `PlayerRoleView_SetPropertyByKey` cases that route into
  `RoleView_BindPartTextureAndMaterialFromSourceIds`
- so the `role+0x104/+0x108/+0x10C/+0x110/+0x114` values are texture/material source ids
  derived from `ItemTexture.ini`, not part-mesh-variant indexes

Current boundary for the rewrite:

- these role-side texture/material caches remain separate from the named part-effect seam
- `CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName` (`0x651232`) forwards
  `(selectorCode, effectName)` to RoleView slot `+0x1C`
- `CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName` (`0x65124C`) forwards
  `(selectorCode, effectNameOrNull)` to RoleView slot `+0x20`
- slot `+0x1C` lazily loads the selector-mapped part, checks
  `I3DRole_HasPartEffectInstanceByName`, and ensures a missing named effect through
  `I3DRole_EnsurePartEffectInstanceByName`
- slot `+0x20` removes the first case-sensitive effect-name match from the mapped part;
  selector `0x3F` clears all effects from all loaded parts
- `Role_TickAndRender` uses selectors `4` (`body`) and `8` (`mount`) with
  `flagmanaim`, `flagmountaim`, `WarFlagEscortStatusNoMount`, and
  `WarFlagEscortStatusMount`; `0x6FDCEF` removes `iarrow_916` from selector `4`
- these calls do not select an inner mesh or index `RolePartModelResolution.Parts`
- the managed runtime now carries both 64-bit status words and mirrors the exact four
  post-render ensure/remove operations for the next frame

## `PlayerRoleView_ConfigureRolePartActionEffects` role-data inputs (verified)

The action-effect helper is not driven by ad-hoc hardcoded effect names. Its effect-name and
custom-transform inputs come from `GameData.dll` role-data tables.

Verified `GameData.dll` helpers:

- `RoleDataSingleton_LoadAction3DEffectTables` (`0x10001D99`)
- `RoleDataSingleton_LoadAction3DEffectFile` (`0x10001E26`)
- `RoleDataSingleton_FindAction3DEffectRecord` (`0x100020D4`)
- `RoleDataSingleton_LoadNoArmorSoulEffectActionSet` (`0x100023CF`)
- `RoleDataSingleton_HasNoArmorSoulEffectAction` (`0x10002460`)

Verified table files:

- `ini/Action3DEffect.ini`
- `ini/Action3DEffect1.ini`
- `ini/Action3DEffect2.ini`
- `ini/NoArmorSoulEffectAction.ini`

Verified `Action3DEffect` line format:

- key: `appearanceFamily.actionId.sourceCategoryCode.sourceVariantCode`
- value:
  - `effectName`
  - or `effectName~customTransformPercentX~customTransformPercentY~customTransformPercentZ`

Verified query argument mapping from `PlayerRoleView_ConfigureRolePartActionEffects`:

- `appearanceFamily = (partSourceId / 1_000_000) % 1000`
- `actionId = currentActionId`
- `sourceCategoryCode = (effectiveSourceId / 1000) % 1000`
- `sourceVariantCode = effectiveSourceId % 1000`

Current managed parity boundary for this verified subset:

- the rewrite now carries the packet-fed primary helmet/body override lookup ids all the way
  into the `body` / `armet` startup property-resolution summaries
- `Role3DClientSceneMultiPartRenderStageRuntime` keys body/helmet effect state by the pair
  `(sourceId, roleDataOverrideLookupId)` before calling the verified fresh player-RoleView
  `PlayerRoleView_ConfigureRolePartActionEffects` subset for `body` / `armet`
- `PlayerRoleView_UpdateRolePartMotionsForAction` is now pinned more tightly:
  - it calls `PlayerRoleView_ConfigureRolePartActionEffects` only for primary `body` and primary
    `armet`
  - it then fans motion out across `body` / `mix_body` / `mix2_body` and
    `armet` / `mix_armet` / `mix2_armet` through
    `I3DRole_SetPartMotionAndPrimaryFrameByName` and
    `I3DRole_SetPartBlendMotionAndSecondaryFrameByName`
- this still does **not** claim layered `mix_body` / `mix2_body` or `mix_armet` /
  `mix2_armet` direct visual-track parity; the currently verified RoleView caller only feeds
  the primary `body` and `armet` names into this helper
- `layerBucket = layerIndex % 3`

`effectiveSourceId` is the selected source family for the current part after the optional
weapon-override lookup through `RoleDataSingleton_ResolveWeaponSourceFromSoulPart`.

Verified body-family special case:

- before the effect lookup loop runs for `body`, `mix_body`, and `mix2_body`,
  `PlayerRoleView_ConfigureRolePartActionEffects` unconditionally clears the body-family
  part's named effects through
  `I3DRole_RemovePartEffectInstanceByName(null, partName)`
- `RoleDataSingleton_HasNoArmorSoulEffectAction(currentActionId)` does not gate that clear
- when the no-armor/soul predicate matches and a mount source is active, the helper adds
  `RoleView_ExtractMountEquipmentFamilyCode(this) * 1000` to `appearanceFamily`
  before issuing the `Action3DEffect` queries

Verified refresh cadence:

- `Conquer.exe::Role_UpdateActionAndDispatchRoleViewMotion` (`0x64E2DD`) passes
  `refreshPartActionEffects = 1`
- ordinary `Role_TickAndRender` calls at `0x64FA30` and `0x64FACC` pass
  `refreshPartActionEffects = 0`
- action-effect clear/query/ensure work is therefore part of action dispatch and is not an
  every-render-tick operation

### Packet-fed linked-source / head-attachment writers

Verified `Conquer.exe` setters:

- `CRole__SetLinkedSourceLookupId` (`0x64DB3C`)
  - stores `uint16` at `role+0xD2`
  - with `refresh != 0`, tail-calls `CRole__RefreshLinkedSourceLookupIdToRoleView`
- `CRole__RefreshLinkedSourceLookupIdToRoleView` (`0x64DB57`)
  - dispatches `CRole__ApplyLinkedSourceLookupIdToRoleView(role, roleView)`
- `CRole__SetHeadAttachmentSource` (`0x64DC01`)
  - stores `uint16` at `role+0xD4`
  - with `refresh != 0`, tail-calls `CRole__RefreshAllVisualSourcesToRoleView`
- `CRole__RefreshAllVisualSourcesToRoleView` (`0x64DC1C`)
  - dispatches the full helper order listed above, including key `2`

Verified packet call-sites:

- `CMsgUserInfo__Process` (`0x764276`)
  - `HairCompositeId % 1000` -> `CRole__SetLinkedSourceLookupId(role, linkedSourceLookupId, 1)`
  - `HairCompositeId / 1000` -> `CRole__SetHeadAttachmentSource(role, headAttachmentSource, 1)`
- `CMsgPlayer__Process` (`0x755F64`)
  - `HairCompositeId % 1000` -> `CRole__SetLinkedSourceLookupId(role, linkedSourceLookupId, 1)`
  - `HairCompositeId / 1000` -> `CRole__SetHeadAttachmentSource(role, headAttachmentSource, 1)`

Parity implication for the managed player startup path:

- fresh player-RoleView creation still begins with key `0` body loads from
  `PlayerRoleView_SetBodyAppearanceSource`
- normal equipment/state reapply then runs through the helper order above
- `ArmorIdentity` therefore belongs to the primary body-variant source chain and must
  not be dropped from startup/reapply orchestration
- `CRole__SetTransformLook` remains a separate transform-record path and does not replace
  the normal equipment/body-variant reapply chain

## Layered body / helmet source rebuild helpers (newly pinned)

The generic player-RoleView property switch now has enough verified coverage to deobfuscate the
layered body/helmet source rebuild helpers without placeholder names.

Renamed helpers in the BNinja DB:

- `PlayerRoleView_MapPropertyKeyToVariantLayerIndex` (`0x100011A8`)
- `RoleView_BindPartTextureAndMaterialFromSourceIds` (`0x100011F7`)
- `PlayerRoleView_SetPrimaryBodyVariantSourceAndReload` (`0x10001C88`)
- `PlayerRoleView_SetBodyVariantSourceAndReloadAtLayer` (`0x10001C9E`)
- `PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily` (`0x10001CE4`)
- `PlayerRoleView_SetHelmetVariantSourceAndReloadAtLayer` (`0x10001FF4`)
- `PlayerRoleView_SetHelmetVariantOverrideAndReloadAtLayer` (`0x100023F4`)
- `PlayerRoleView_SetBodyVariantOverrideAndReloadAtLayer` (`0x10002441`)

### Property-key → variant-layer map

`PlayerRoleView_MapPropertyKeyToVariantLayerIndex` returns:

- `0` for the primary layer / non-layered keys.
- `1` for keys `0x27`, `0x28`, `0x35`, `0x38`, `0x3D`.
- `2` for keys `0x2B`, `0x2C`, `0x36`, `0x39`, `0x3E`.

## Player RoleView property getter surface

`PlayerRoleView_GetPropertyByKey` (`0x10002BFC`) is the verified slot-11 query surface paired
with `PlayerRoleView_SetPropertyByKey`.

Verified getter cases:

- key `0`
  - returns `this+0xA8` (body appearance source id)
  - also read directly by slot 10 (`RoleView_SharedRenderComposite`) at function entry
    as a flat `== 998` (`0x3e6`) test; `998` is the verified mount-only render path (no
    `"body"` precondition, only `"mount"` must be loaded)
- key `0x0C`
  - returns `this+0x40` (right-weapon source family)
- key `0x0D`
  - returns `this+0x3C` (left-weapon source family)
- key `0x0E`, `0x2A`, `0x2E`
  - returns `this+0x30 + layer*4` (primary/secondary/tertiary helmet source slots)
- key `0x0F`
  - returns `this+0x24 + layer*4` (primary/secondary/tertiary body source slots)
- key `0x10`
  - returns `this+0x44` (mount source family)
- key `0x11`
  - returns `this+0x48 % 1_000_000` (misc source low-six-digit family tail)
- key `0x12`
  - returns `RoleView_ComputeBodyMotionSubActionKey(this)`
- key `0x1E`
  - returns `PlayerRoleView_BuildCurrentBodyMotionLookupKey(this)`
- key `0x31`
  - queries the current `I3DRole` at `this+0xD8` through vtable slot `+0x70`
    (`I3DRole_ProbeRayHitTestByScreenCoords`, `0x10003950` in Role3D.dll) using the stored
    screen-coordinate pair `this+0xB4` / `this+0xB8`
  - the vtable+0x70 helper builds a probe ray via `CMyBitmap::ProbeRayBuild(screenX, screenY)`
    and tests it against every loaded part (or one named part) using
    `PartInfo_ProbeRayIntersectsAnyPart`
  - returns `1` if any part is hit, else `0`
  - the screen coordinates are written by setter keys `0x32` (X) and `0x33` (Y)
- keys `>= 0xBB8`
  - build a body-motion lookup key through
    `PlayerRoleView_BuildBodyMotionLookupKey(this, key - 0xBB8)`
  - query `GameDataSetQuery()->vtable+0x20("body", keyLow, keyHigh, 1, 0)`
  - return the resolved record's vtable `+0x0C` result on hit, else `0`

### Body-variant rebuild chain

Primary-layer setter:

- `PlayerRoleView_SetPrimaryBodyVariantSourceAndReload(this, sourceFamily, useStoredOverride)`
  - stores `sourceFamily` at `this+0x60`
  - tail-calls `PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily(this, sourceFamily, useStoredOverride, 0)`

Layered setter:

- `PlayerRoleView_SetBodyVariantSourceAndReloadAtLayer(this, sourceFamily, useStoredOverride, layer)`
  - stores `sourceFamily` at `this+0x60 + layer*4`
  - tail-calls the same reload helper for `layer in [0,2]`

Reload helper:

- `PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily`
  - part-name table: `RoleView_RolePartNameTable_BodyAndHelmetVariants[layer]`
    - verified live names: `body`, `mix_body`, `mix2_body`
  - normalized loaded source formula:
    - `loadedSource = bodyAppearanceSourceId * 1_000_000 + ((sourceFamily % 1_000_000) / 10) * 10`
    - evidence: `0x10001E52..0x10001E58`
  - writes `loadedSource` to `this+0x24 + layer*4`
  - loads the part through:
    - `PlayerRoleView_LoadPartSourceIntoI3DRole(this, partName, "v_mount", "mount", loadedSource, overrideOrZero)`
  - when `useStoredOverride == 0`, override arg is zero
  - when `useStoredOverride != 0`, override arg comes from `this+0x78 + layer*4`

Helmet-family side effect:

- if the incoming body variant family class is `0x13`
  (`((sourceFamily / 10000) % 100) == 0x13`),
  the helper also refreshes the helmet-family slots from `this+0xB0` through
  `PlayerRoleView_LoadPartSourceIntoI3DRole(..., "v_armet", "body", bodyAppearanceSourceId * 1_000_000 + linkedSource + 0x1D0D8, 0)`.

Direct linked-source path:

- `PlayerRoleView_SetLinkedSourceFromLookupId(this, linkedSourceLookupId)`
  - stores `linkedSourceLookupId` at `this+0xB0`
  - tail-calls `PlayerRoleView_ReloadHelmetVariantAtLayer(this, linkedSourceLookupId + 0x1D0D8, 0)`
- for a fresh player RoleView, when `linkedSourceLookupId % 100 != 0`, that layer-0 reload emits:
  - `PlayerRoleView_LoadPartSourceIntoI3DRole(this, "armet", "v_armet", "body", bodyAppearanceSourceId * 1_000_000 + linkedSourceLookupId + 0x1D0D8, 0)`

This is the currently representable managed startup subset for key `1`. Key `2` remains a
separate attachment path and cannot be mirrored until the runtime has a verified `"head"` part /
attachment representation.

### Helmet-variant rebuild chain

Primary-layer setter:

- `PlayerRoleView_SetPrimaryHelmetVariantSourceAndReload(this, sourceFamily)`
  - stores `sourceFamily` at `this+0x6C`
  - tail-calls `PlayerRoleView_ReloadHelmetVariantAtLayer(this, sourceFamily, 0)`

Layered setter:

- `PlayerRoleView_SetHelmetVariantSourceAndReloadAtLayer(this, sourceFamily, layer)`
  - stores `sourceFamily` at `this+0x6C + layer*4`
  - reloads `layer in [0,2]`

Reload helper:

- `PlayerRoleView_ReloadHelmetVariantAtLayer`
  - part-name table: `RoleView_RolePartNameTable_HelmetVariants[layer]`
    - verified live names: `armet`, `mix_armet`, `mix2_armet`
  - normal fresh-load branch:
    - `normalizedFamily = ((sourceFamily % 1_000_000) / 10) * 10`
    - `loadedSource = bodyAppearanceSourceId * 1_000_000 + normalizedFamily`
    - loads the layer through:
      - `PlayerRoleView_LoadPartSourceIntoI3DRole(this, partName, "v_armet", "body", loadedSource, helmetOverrideOrZero)`
    - primary evidence: `0x10002345..0x1000237E`
  - stored loaded-source slot:
    - `this+0x30 + layer*4`
  - stored override slot:
    - `this+0x84 + layer*4`
  - special-family branches are separate and must not be collapsed into the normal path:
    - `0x75`, `0x76`, `0x77`, `0x7B`, `0x8D..0x8F`, `0xB1..0xB2`
    - `0x77` is the verified 3-layer helmet-family refresh branch
    - `0x75`, `0x76`, `0x7B`, `0x8D..0x8F`, `0xB1..0xB2` enter fallback / unload logic

### Texture / material binding is a separate seam

`RoleView_BindPartTextureAndMaterialFromSourceIds(this, partName, primarySourceId, secondarySourceId)`
is not the mesh-variant selector path:

- it resolves both source ids through `GameDataSetQuery()->+0x18`
- then calls `I3DRole_BindPerPartTexturesAndMaterial` on Role3D slot `+0x44`
- verified evidence: `0x1000123F`
- `I3DRole_BindPerPartTexturesAndMaterial` then iterates the matching `PartInfo` entries and:
  - resolves the primary texture source through mesh `+0x58`
  - resolves the secondary texture source through mesh `+0x5C`
  - reapplies the already stored per-part material pointer through mesh `+0x64`
- the verified property cases currently pinned on the player RoleView are:
  - `0x23 / 0x29 / 0x2D`
    - store the incoming cached source id at `this+0x50/+0x54/+0x58`
    - query the currently loaded helmet source from `this+0x30/+0x34/+0x38`
    - bind to `armet / mix_armet / mix2_armet`
    - use the incoming cached item-texture result as the primary texture source id
    - use the role-part record `secondaryTextureId` (`record+0x24`) as the secondary source id
  - `0x24`
    - store the incoming cached source id at `this+0x4C`
    - query the currently loaded body source from `this+0x24`
    - bind to `body`
    - use the incoming cached item-texture result as the primary texture source id
    - use the role-part record `secondaryTextureId` (`record+0x24`) as the secondary source id
  - `0x25`
    - store the incoming cached source id at `this+0x5C`
    - query the currently loaded left-weapon source from `this+0x3C`
    - bind to `l_weapon`
    - use the incoming cached item-texture result as the primary texture source id
    - use the role-part record `secondaryTextureId` (`record+0x24`) as the secondary source id
  - `0x26`
    - is the broader multi-part texture/material refresh path and remains a separate seam

So the player-RoleView property cases `0x23..0x26` are texture/material rebinding helpers, not
callers of `I3DRole_RemovePartEffectInstanceByName`.

Current managed boundary for this seam:

- the runtime now applies the verified primary cached item-texture results at the draw boundary for:
  - `armet`
  - `mix_armet`
  - `mix2_armet`
  - `body`
  - `l_weapon`
- the managed renderer uses those ids as primary texture-resource overrides on the already
  resolved part meshes
- the secondary texture stream and stored material reapply behavior are still not consumed by
  the OpenGL mesh path, so this slice does not yet claim full native texture/material parity

Verified transform-look refresh call-sites in `Conquer.exe`:

- `CRole__SetTransformLook` (`0x650B58`)
  - resolves `RoleDataQuery()->vtable+0x28(refreshSourceId)`
  - applies RoleView keys `3`, `5`, `6`, `7`, `9`, `8`
  - then explicitly zeroes the override keys `0x34`, `0x37`, `0x3B`, `0x3A`
- `CRole__SetTransformLookSourceId` (`0x650B1F`)
  - stores the refresh source id at role offset `+0x37`
  - conditionally re-enters `CRole__SetTransformLook`

Verified render-chain anchor for player RoleViews:

- ground/entity-layer map component render callback: `CGameMapGroundEntityLayerComponent_MapComponentRenderTick` (`0x637553`)
- local hero render callback inside that path: `CHero_Render` (`0x65E472`) ->
  `CHero_TickAndRenderRoleVisuals` (`0x66F7AB`) -> `Role_TickAndRender` (`0x66F843`)
- parity implication: local-hero RoleView work runs through the dedicated hero callback before the rest of the
  player-RoleView player/entity render pass; managed player-RoleView composition should therefore preserve a local-hero-first ordering
  boundary even before full RoleView mesh draw parity is complete.

Managed scene-object consequence for this slice:

- `1006/10014` + player-RoleView render submissions are now consumed into persistent managed player RoleView scene objects.
- Each scene object stores:
  - RoleView type `1`
  - `appearanceCompositeId`
  - verified `bodyAppearanceSourceId = appearanceCompositeId % 1000`
  - the separate refresh source id used by `CRole__SetTransformLook`
  - raw equipped-item identities and item-query ids from `10014`
  - current projected screen position and per-frame player-RoleView submission order
- The managed runtime does **not** invent the unresolved `RoleDataQuery()->+0x28` record expansion yet.
  That record is still required before keys `5/6/7/8/9/0x34/0x37/0x3A/0x3B` can be rebuilt with full native fidelity.
