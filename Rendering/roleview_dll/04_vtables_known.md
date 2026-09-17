# `RoleView.dll` — Known VTables

Vtable pointers found in `RoleView.dll` with their decoded function-pointer arrays, extracted from `.rdata`.

Method meanings are correlated against:

- `analysis/conquer_docs/Rendering/02_roleview_object_interface.md`

## VTable: `0x100156C0` (type 9)

`RoleViewCreate(type=9)` allocates `0x10` bytes and calls a constructor at `0x10005E0F` which sets:

- `[this+0] = 0x100156C0` (vtable pointer)
- `[this+4] = 0`

### Slots

Decoded from `.rdata` at `0x100156C0`:

| Slot | Target | IDA name | Notes (directly from code) |
|---:|---:|---:|---|
| 0 | `0x10005E1C` | `RoleView_Release_Thunk_Return0` | checks `this`; calls virtual at `+0x30` with arg `1`; returns `0` |
| 1 | `0x10005E6E` | `RoleView_Type9_ReturnsTrueWhenSelfIsNull` | returns `1` iff `this` is `0` |
| 2 | `0x10002D2F` | `DllMain_ReturnTrue` | returns `1` |
| 3 | `0x10005E68` | `RoleView_Type9_Method3_Return100` | returns `100` |
| 4 | `0x10005E4D` | `RoleView_Type9_Method4_Stub` | stub (`ret 0x14`) |
| 5 | `0x10005E50` | `RoleView_Type9_Method5_Stub` | stub (`ret 0x20`) |
| 6 | `0x10005E53` | `RoleView_Type9_Method6_Stub` | stub (`ret 0x10`) |
| 7 | `0x100042C2` | (stub `ret 8`) | stub (`ret 0x08`) |

## VTable: `0x100151B8` (player RoleView / factory type 1)

Initialized by `PlayerRoleView_Ctor` (`0x10001000`).

Decoded slots (in order):

| Slot | Target | Function |
|---:|---:|---|
| 0 | `0x10005E1C` | `RoleView_Release_Thunk_Return0` |
| 1 | `0x10002779` | `PlayerRoleView_SetPropertyByKey` |
| 2 | `0x10002D2F` | `RoleView_ReturnTrue` |
| 3 | `0x10002DC8` | `PlayerRoleView_UpdateRolePartMotionsForAction` |
| 4 | `0x1000327E` | `RoleView_SharedSetTransformFromCamera` |
| 5 | `0x100032BB` | `RoleView_SharedSetShadowRenderParameters` |
| 6 | `0x1000334F` | `RoleView_SharedSetColorRgba` |
| 7 | `0x10003486` | `PlayerRoleView_EnsurePartEffectInstanceBySelectorAndName` |
| 8 | `0x100035B4` | `PlayerRoleView_RemovePartEffectInstanceBySelectorAndName` |
| 9 | `0x10003640` | `RoleView_SharedScreenPickHitTestAgainstBoundingBox` |
| 10 | `0x100038A9` | `RoleView_SharedRenderComposite` |
| 11 | `0x10002BFC` | `PlayerRoleView_GetPropertyByKey` |
| 12 | `0x10001123` | `PlayerRoleView_Dtor` |

Correction (slot 9): a previous slice named slot 9 `RoleView_SharedTickAndRender`. That name
is wrong. Direct disassembly proves slot 9 only:

1. composes a world transform from `this+0x04..+0x1C` (position, X/Y/Z rotation in degrees, scale)
2. builds a screen-space ray via `CMyBitmap::ScrRayBuild(arg2, arg3)` from screen coordinates
3. inverse-transforms the ray into the role's local space
4. tests it against a fixed local AABB `[-40,-40,-90]..[40,40,-10]` using
   `RoleView_RayAabbSlabIntersectionTest` (`0x10005E7A`)
5. returns a clamped boolean (hit / no-hit)

It does not perform any rendering or simulation tick. Slot 10 (`RoleView_SharedRenderComposite`)
is the verified per-frame render dispatch.

Verified shared shadow-parameters / color forwarders (slot 5 / slot 6):

- slot 5 `RoleView_SharedSetShadowRenderParameters` (`0x100032BB`): caches its
  8 args at `RoleView+0x98..+0xC8` (with `arg4`/`arg5` negated as
  `*(this+0x9C) = -arg4`, `*(this+0xA0) = -arg5`), then forwards
  `(arg2, arg3, -arg4, -arg5, arg6, arg7, arg8, arg9)` to `I3DRole vtable+0x3C`
  (`I3DRole_StoreShadowRenderParameters`, `Role3D.dll 0x10004820`).
  The Y/Z negation is the coordinate-frame conversion of the incoming light
  vector before it is handed to `I3DRole`.
  - cached field meanings (write-only on the `RoleView.dll` side):
    - `+0x98` = shadow direction X (`arg3`)
    - `+0x9C` = shadow direction Y (`-arg4`, negated on store)
    - `+0xA0` = shadow direction Z (`-arg5`, negated on store)
    - `+0xA4` = shadow mode integer (`arg2`, clamped `>=1` on the I3DRole side;
      meaningful values 2/3/4 build a `C3_SHADOW_RENDER_DESC`)
    - `+0xBC` = shadow scalar (`arg6`)
    - `+0xC0..+0xC8` = `arg7..arg9`, forwarded but discarded by I3DRole
  - the cached fields at `RoleView+0x98..+0xC8` are **write-only** on the
    `RoleView.dll` side: `PlayerRoleView_GetPropertyByKey` (`0x10002BFC`)
    does not read them, and `RoleView_SharedRenderComposite` (`0x100038A9`)
    only reads `+0x04..+0x1C`, `+0x20..+0x44`, `+0x74`-area, `+0xA8`, `+0xCC`,
    and `+0xD8` — never anything in `+0x98..+0xC8`
  - downstream, `I3DRole_StoreShadowRenderParameters` keeps only the 5 args it
    stores at `I3DRole+0x14..+0x24` (mode at `+0x24`, dirX/dirY/dirZ at
    `+0x18/+0x1C/+0x20`, scalar at `+0x14`); the remaining 3 caller args are
    popped by `retn 0x20` and discarded. Those 5 fields are then read by
    `PartInfo_RenderAllParts` (`Role3D.dll 0x10005EB0`) and forwarded to per-part
    `C3DObjX_Render` (`vtable+0x54`, `graphic.dll 0x10004330`), where the mode
    selects the shadow descriptor build path.
- slot 6 `RoleView_SharedSetColorRgba` (`0x1000334F`): pure forwarder that
  reads `I3DRole` at `RoleView+0xD8` and dispatches `vtable+0x4C(arg2..arg5)`.
  - the I3DRole side is `I3DRole_ApplyColorToAllParts` (`0x10001770`, slot 19),
    which iterates the part map and calls
    `Role3DObject_ApplyColorToAllMeshes(r, g, b, a)` (`0x10005B80`) on every
    loaded part, which then forwards 4 floats to per-mesh
    `C3DObjX_SetColorForAllSubmeshes` (`vtable+0x24`, `graphic.dll 0x10004150`),
    which in turn calls `Phy_SetColor` per submesh.
  - no fields are cached on the RoleView side.

Verified `Conquer.exe` caller boundary for slot 5 / slot 6:

- `CRole__SetTransformLook` (`Conquer.exe 0x650B58`) does **not** call slot 5
  or slot 6 of any RoleView vtable. It only invokes the property setter at
  vtable `+0x04` (slot 1, `PlayerRoleView_SetPropertyByKey`).
- No `Conquer.exe` caller is currently pinned for either slot 5 or slot 6 on
  the player RoleView path; the only `RoleView.dll`-internal caller of
  `RoleView_SharedSetShadowRenderParameters` is
  `RoleView_Type10_SetShadowRenderParameters` (`0x10004C03`), which is itself
  slot 5 of the type-10 vtable.

Verified player-RoleView property-key anchors used by player `1006/10014` processing:

- key `0` -> `PlayerRoleView_SetBodyAppearanceSource`: stores `bodyAppearanceSourceId` at `this+0xA8` and rewrites body/helmet source ids as `bodyAppearanceSourceId * 1_000_000 + existing_low_6_digits`.
  - new-player body-load helper: `PlayerRoleView_LoadPartSourceIntoI3DRole` (`0x10003381`)
  - new-player calls:
    - `("body", "v_mount", "mount", bodyAppearanceSourceId * 1_000_000, 0)`
    - `("mix_body", "v_mount", "mount", bodyAppearanceSourceId * 1_000_000, 0)`
    - `("mix2_body", "v_mount", "mount", bodyAppearanceSourceId * 1_000_000, 0)`
- key `1` -> `PlayerRoleView_SetLinkedSourceFromLookupId`: stores `this+0xB0` and dispatches `PlayerRoleView_ReloadHelmetVariantAtLayer(this, arg + 0x1D0D8, 0)`.
- key `2` -> `PlayerRoleView_SetHeadAttachmentSource`: updates the `"body"` -> `"head"` attachment, storing the attached source at `this+0xAC`.
- key `3` -> `PlayerRoleView_ResetSourcesAndRebuildBodyAppearance`: clears current body/helmet/misc/weapon/mount source fields and then re-enters key `0`.
- key `5` -> `PlayerRoleView_SetPrimaryHelmetVariantSourceAndReload`: stores `this+0x6C`, then reloads the primary helmet variant via `PlayerRoleView_ReloadHelmetVariantAtLayer(this, value, 0)`.
- key `6` -> `PlayerRoleView_SetRightWeaponSource`: updates the right-weapon source family (`this+0x40`) and the verified override swap path.
- key `7` -> `PlayerRoleView_SetLeftWeaponSource`: updates the left-weapon source family (`this+0x3C`) and the verified override swap path.
- key `8` -> `PlayerRoleView_SetMountSource`: updates the mount source family (`this+0x44`) and refreshes `"mount"`.
- key `9` -> `PlayerRoleView_SetMiscSource`: updates the misc source family (`this+0x48`) and rebuilds it against `bodyAppearanceSourceId`.
- key `0x34` -> `PlayerRoleView_SetPrimaryBodyVariantOverrideAndReload`: stores `this+0x78`, then refreshes the current `this+0x24` source.
- key `4` -> `PlayerRoleView_SetPrimaryBodyVariantSourceAndReload`: stores `this+0x60`, then reloads the primary body variant via `PlayerRoleView_ReloadBodyVariantAtLayerAndRefreshHelmetFamily(this, value, 0, 0)`.
- key `0x37` -> `PlayerRoleView_SetPrimaryHelmetVariantOverrideAndReload`: stores `this+0x84`, then refreshes the current `this+0x30` source.
- key family `0x27/0x2B` -> `PlayerRoleView_SetHelmetVariantSourceAndReloadAtLayer`.
- key family `0x35/0x36` -> `PlayerRoleView_SetBodyVariantOverrideAndReloadAtLayer`.
- key family `0x38/0x39` -> `PlayerRoleView_SetHelmetVariantOverrideAndReloadAtLayer`.
- key family `0x3C/0x3D/0x3E` -> `PlayerRoleView_SetBodyVariantSourceAndReloadAtLayer(..., useStoredOverride=1, layer)`.
- key `0x3A` -> `PlayerRoleView_SetLeftWeaponOverrideSource`: stores `this+0x90`, then refreshes the current left-weapon source at `this+0x3C`.
- key `0x3B` -> `PlayerRoleView_SetRightWeaponOverrideSource`: stores `this+0x94`, then refreshes the current right-weapon source at `this+0x40`.
- constructor evidence for new-player startup planning:
  - `PlayerRoleView_Ctor` (`0x10001000`) zeros `+0x90` and `+0x94`
  - therefore new player-RoleView startup calls into `SetRightWeaponSource` / `SetLeftWeaponSource` begin with override lookup ids `0`
- Conquer.exe caller evidence:
  - `CRole__ApplyBodyVariantSourcesToRoleView` is part of the normal
    `CRole__ApplyAllVisualSourcesToRoleView` chain
  - `CRole__SetTransformLook` does not call key `4`; it only drives keys `3`, `0x34`,
    `5`, `0x37`, `6`, `0x3B`, `7`, `0x3A`, `9`, and `8`
- slot `7` selector map for `PlayerRoleView_EnsurePartEffectInstanceBySelectorAndName` (`0x10003486`):
  - `1 -> ("armet", "v_armet", "body", 0, 0)`
  - `4 -> ("body", "v_mount", "mount", 0, 0)`
  - `6 -> ("r_weapon", "v_r_weapon", "body", 0, 0)`
  - `7 -> ("l_weapon", "v_l_weapon", "body", 0, 0)`
  - `8 -> ("mount", "none", "none", 0, 0)`
  - `9 -> ("misc", "v_misc", "body", 0, 0)`
- verified generic `Conquer.exe` slot forwarders:
  - `CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName` (`0x651232`) -> slot `7` / `+0x1C`
  - `CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName` (`0x65124C`) -> slot `8` / `+0x20`
- verified current caller boundary:
  - slot `7` callers in `Conquer.exe` are the status/effect-track string paths in
    `Role_TickAndRender` plus the slash-command dispatcher path in
    `Conquer_DispatchSlashCommandText` (`0x659126`)
  - slot `8` callers currently proven in `Conquer.exe` are `(0x3F, 0)`, the same
    status/effect string tokens, and the interaction-path `(4, "iarrow_916")` caller at
    `0x6FDCEF`
  - an additional raw disassembly sweep over the role-subsystem range
    `0x640000..0x660000`, re-verified in BNinja, did not produce any extra direct
    `m_pIRoleView` slot `+0x1C` / `+0x20` callsites beyond the two generic forwarders
    at `0x651232` / `0x65124C`
  - slot `8` removes named effects; it is not a mesh-instance or body/helmet variant selector

Verified player-RoleView getter anchors:

- key `0` -> body appearance source (`this+0xA8`)
- key `0x0C` -> right-weapon source family (`this+0x40`)
- key `0x0D` -> left-weapon source family (`this+0x3C`)
- key `0x0E/0x2A/0x2E` -> helmet source layers (`this+0x30/+0x34/+0x38`)
- key `0x0F` -> body source layers (`this+0x24/+0x28/+0x2C`)
- key `0x10` -> mount source family (`this+0x44`)
- key `0x11` -> misc source low-six-digit family tail (`this+0x48 % 1_000_000`)
- key `0x12` -> `RoleView_ComputeBodyMotionSubActionKey(this)`
- key `0x1E` -> `PlayerRoleView_BuildCurrentBodyMotionLookupKey(this)`
- key `0x31` -> boolean success result from the `I3DRole` vtable `+0x70` query using `this+0xB4/+0xB8`
- keys `>= 0xBB8` -> query `GameDataSetQuery()->vtable+0x20("body", ...)` using
  `PlayerRoleView_BuildBodyMotionLookupKey(this, key - 0xBB8)` and return the resolved
  record vtable `+0x0C` result on hit

## VTable: `0x10015334` (type 4)

Initialized by `RoleView_Type4_Ctor` (`0x100042C5`).

Decoded slots (in order):

| Slot | Target | IDA name |
|---:|---:|---|
| 0 | `0x10005E1C` | `RoleView_Release_Thunk_Return0` |
| 1 | `0x100043B5` | `RoleView_Type4_SetProperty` |
| 2 | `0x10004431` | `RoleView_Type4_Method2_Key48` |
| 3 | `0x1000526F` | `RoleView_Type4_Method3_Return10` |
| 4 | `0x10004453` | `RoleView_Type4_SetTransform` |
| 5 | `0x100044DF` | `RoleView_Type4_Method5_CallSimple3DObj_Vtbl32` |
| 6 | `0x1000453D` | `RoleView_Type4_SetColor` |
| 7 | `0x100042C2` | (stub `ret 8`) |
| 8 | `0x100042C2` | (stub `ret 8`) |
| 9 | `0x10004583` | `RoleView_Type4_RenderOrHitTest` |
| 10 | `0x10004844` | `RoleView_Type4_TickAndRender` |
| 11 | `0x10004A31` | `RoleView_Type4_GetProperty` |
| 12 | `0x1000437D` | `RoleView_Type4_Dtor` |

## VTable: `0x1001524C` (type 2)

Initialized by `RoleView_Type2_Ctor` (`0x10003D8E`).

Decoded slots (in order):

| Slot | Target | Function |
|---:|---:|---|
| 0 | `0x10005E1C` | `RoleView_Release_Thunk_Return0` |
| 1 | `0x10003DE6` | `RoleView_Type2_SetProperty` |
| 2 | `0x10002D2F` | `RoleView_ReturnTrue` |
| 3 | `0x10003E39` | `RoleView_Type2_UpdateRolePartMotionsForAction` |
| 4 | `0x1000327E` | `RoleView_SharedSetTransformFromCamera` |
| 5 | `0x100032BB` | `RoleView_SharedSetShadowRenderParameters` |
| 6 | `0x1000334F` | `RoleView_SharedSetColorRgba` |
| 7 | `0x10003486` | `PlayerRoleView_EnsurePartEffectInstanceBySelectorAndName` |
| 8 | `0x100035B4` | `PlayerRoleView_RemovePartEffectInstanceBySelectorAndName` |
| 9 | `0x10003640` | `RoleView_SharedScreenPickHitTestAgainstBoundingBox` |
| 10 | `0x10003E69` | `RoleView_Type2_TickAndRender` |
| 11 | `0x10002BFC` | `RoleView_QueryPropertyByKey` |
| 12 | `0x10003DBF` | `RoleView_Type2_Dtor` |

## VTable: `0x100153A8` (type 10)

Initialized by `RoleView_Type10_Ctor` (`0x10004B4D`).

Decoded slots (in order):

| Slot | Target | Function |
|---:|---:|---|
| 0 | `0x10005E1C` | `RoleView_Release_Thunk_Return0` |
| 1 | `0x10004C9F` | `RoleView_Type10_SetProperty` |
| 2 | `0x10002D2F` | `RoleView_ReturnTrue` |
| 3 | `0x10004B9B` | `RoleView_Type10_UpdateRolePartMotionsForAction` |
| 4 | `0x10004BB9` | `RoleView_Type10_SetTransform` |
| 5 | `0x10004C03` | `RoleView_Type10_SetShadowRenderParameters` |
| 6 | `0x10004C43` | `RoleView_Type10_SetColorRgba` |
| 7 | `0x10003486` | `PlayerRoleView_EnsurePartEffectInstanceBySelectorAndName` |
| 8 | `0x100035B4` | `PlayerRoleView_RemovePartEffectInstanceBySelectorAndName` |
| 9 | `0x10004C6B` | `RoleView_Type10_TickAndRender` |
| 10 | `0x10004C83` | `RoleView_Type10_RenderOnly` |
| 11 | `0x10004C93` | `RoleView_Type10_GetProperty` |
| 12 | `0x10004B74` | `RoleView_Type10_Dtor` |

## VTable: `0x1001568C` (type 5)

Initialized by `RoleView_Type5_Ctor` (`0x100058FB`).

Decoded slots (in order):

| Slot | Target | IDA name |
|---:|---:|---|
| 0 | `0x10005E1C` | `RoleView_Release_Thunk_Return0` |
| 1 | `0x10005B64` | `RoleView_Type5_SetProperty` |
| 2 | `0x10002D2F` | `DllMain_ReturnTrue` (vtable points at this) |
| 3 | `0x10005E09` | `RoleView_Type5_Method3_Return5` |
| 4 | `0x10005C8F` | `RoleView_Type5_SetTransform` |
| 5 | `0x10005CE6` | `RoleView_Type5_Method5_CallSimple3DObj_Vtbl32` |
| 6 | `0x10005D3F` | `RoleView_Type5_SetColor` |
| 7 | `0x100042C2` | (stub `ret 8`) |
| 8 | `0x100042C2` | (stub `ret 8`) |
| 9 | `0x10005D80` | `RoleView_Type5_RenderOrHitTest` |
| 10 | `0x10005DB1` | `RoleView_Type5_Render` |
| 11 | `0x10005DDE` | `RoleView_Type5_GetProperty` |
| 12 | `0x1000594E` | `RoleView_Type5_Dtor` |
