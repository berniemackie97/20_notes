# Slice 13 — `Role_TickAndRender` caller walkthrough

**Binary:** `Conquer.exe`
**Function:** `Role_TickAndRender` at `0x64f5f7`
**Role in pipeline:** per-frame per-entity hook. Called by the game loop for every visible `CRole`. It is the **only caller in-process of `RoleView_SharedRenderComposite`** (vtable slot `+0x28`, `RoleView.dll!0x100038a9`, verified in slice 12). It is also the call site where the action id that feeds `PlayerRoleView_UpdateRolePartMotionsForAction` (vtable slot `+0x0C`, `RoleView.dll!0x10002dc8`) is sampled each frame.

The complete per-frame dispatch walk, from the entry guards down to the final per-frame selector writes.

## Entry guards (0x64f611 → 0x64f643)

```
0064f611  Role_HasStatusFlag(role, 0x02) != 0       → early-return (hidden/not-on-map)
0064f622  (role->vtable + 0x60)() != 0              → early-return (subclass veto)
0064f62d  role[0xe8] != 0 || role[0xed] == 0        → early-return (no RoleView attached)
```

`role[0xed]` (byte offset `+0x3b4`) is the `m_pIRoleView` pointer — confirmed in
`CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView` (`0x6e56da` checks
`*(arg1+0x3b4)==0`, debug path says `m_pIRoleView`).

## Phase 1 — projection + elevation sample (0x64f649 → 0x64f83e)

1. `CGameMap_GetProjectionCenterOffsetFromScreenPoint(map, role[0xd4], role[0xd5], &var_40, &var_44)` — projects the role's world anchor to screen space.
2. `Role_GetCurrentActionId(role)` — reads `role+0x1a4`.
3. If current action ∈ {`0x82`, `0x127`, `0x20f`} **and** status flag `0x1b` (jumping/flying) is **not** set:
   - `Role_GetMotionArcScreenHeightAnchor(role)` → `var_1c`
   - `Role_GetTerrainHeightDeltaFromProjectedScreenPosition(role)` → `var_20`
   - Else if action `0x38e` and `role[0xe5].b == 0` and `role[0x7a] == 0x25`: `var_1c = role[0xe7]` (projectile override).
4. Apply `var_1c += role[0xc3]`, `var_20 -= role[0xc3]` (per-class Z bias).
5. Facing override chain:
   - `Role_IsCurrentActionInProjectedPathFacingOverrideSet`: facing = `atan2(role[0x68]-role[0x66], role[0x67]-role[0x65])` scaled and biased.
   - `Role_IsCurrentActionInTargetEntityFacingOverrideSet`: resolves target entity via `EntityRef_ResolveByIdOrLocalHero(&data_96b018, ..., role[0x81], 1)`, gets its world position from vtable `+0x10`, and re-computes atan2 facing.
   - Otherwise: `(0xffffffff - role[0x5f]) * 0x2d` (the "latched" facing pre-scaled in native 8-point units).
6. `Role_ComputeFrameIntervalFromAction` runs against the current action, then a scaled frame-index factor is baked into `var_2c`.
7. If `role[0xea].b != 0`: `var_20 += role[0xe9]` (one-shot elevation offset).
8. `(*(role[0xed]->vtable + 0x10))(x, y, facing, scale, ?)` — `RoleView` vtable slot `+0x10` = "set pose/transform" (position + facing + per-frame scale). See slice 10 for the transform record definition this feeds into.

## Phase 2 — optional shadow draw (0x64f85e → 0x64fa0e)

Gated by `data_93e908 == 1` (global "shadows enabled"), `Role_HasStatusFlag(role, 0x0a) == 0` (not invisible/cloaked), and `role[0xd9] != 9` (not some special state).

When all three pass:
1. Looks up `"SimpleShadow"` in `ani/common.ani` via the GameDataSetQuery's cached-ani loader (vtable `+0x10`).
2. Computes screen position from projection center + role's offset.
3. Fetches the first frame (vtable `+0x10`), reads frame dimensions (vtable `+0x14`), applies `CGameMap_ApplyProjectionScaleAroundViewportCenter` and `CGameMap_GetProjectionClampScaleDivisor`-normalized scale.
4. Fades the shadow if `role[0xde] != 0`: `alpha = 0xff - (timeGetTime() - role[0xde]) * 50 / 1000`, clamped to ≥ 0.
5. Calls frame draw vtable `+0x08` with `(x, y, 0, w, h, alpha, …)`.

This is a 2D billboard shadow drawn under the 3D role — the only 2D splat in the per-role render phase.

## Phase 3 — action dispatch + Vortex override state machine (0x64fa0e → 0x64fae2)

This is the slice-13 keystone. Decoded from the verified disassembly around `0x64fa0e..0x64fae2`:

```
test role->m_bVortexActionOverrideActive (dword at role+0x60):
  • == 0 (normal frame):
      RoleView.vtable+0x0c(currentActionId)       ; UpdateRolePartMotionsForAction
      facing = role[0x1c] >= 0 ? role[0x1c] : role[0x1a8]
      RoleView.vtable+0x04(0x0a, facing)          ; set selector code 0x0A = movement/pose
      goto 0x64fae2
  • == 1 (Shuriken Vortex override active):
      if Role_HasStatusFlag(0x2e) != 0:
          // Keep the underlying CRole action unchanged and loop the Vortex action.
          now = timeGetTime()
          interval = Role_ComputeFrameIntervalFromAction(role, 0x390)
          frameAmount = RoleView.vtable+0x0c(0x390)       ; Shuriken Vortex loop action
          wrappedFrame = ((now - role[0x64]) / interval) % frameAmount
          RoleView.vtable+0x04(0x0a, wrappedFrame)
      else:
          role->m_bVortexActionOverrideActive = 0         ; clear stale latch
          Role_UpdateActionAndDispatchRoleViewMotion(role)
          RoleView.vtable+0x0c(Role_GetCurrentActionId(role))
          RoleView.vtable+0x04(0x0a, role[0x1a8])
```

### Role_UpdateActionAndDispatchRoleViewMotion (0x64e2dd)

`Role_UpdateActionAndDispatchRoleViewMotion` independently honors the same Vortex latch at
`0x64e5c0`. This is separate from the `Role_TickAndRender` wall-clock override above. With
latch `1` and status `0x2e` set, it:

1. calls `PlayerRoleView_GetPropertyByKey` through RoleView vtable `+0x2c` with
   `currentAction + 3000` and uses that property value as the frame count;
2. dispatches action `0x390` through RoleView vtable `+0x0c`, ignoring that call's return;
3. computes timing from the unchanged current action, not action `0x390`; and
4. writes the action start tick and interval even when the property query returned zero.

A stale latch with status `0x2e` clear is reset before the function resumes its regular
action path. On that path it runs the client-side action-id translation state machine.
Verified behaviour:
- If status flag `0x1b` is set (jumping), it remaps `role+0x1a4` to one of
  `{0x1f5, 0x1f6, 0x1fe, 0x208, 0x212, 0x230, 0x230, 0x1f5, …}` based on the source action
  (normal walk/run actions get remapped to their jumping variants).
- Then `Role_GetActionType(role)` is consulted; `0x186a4` (hold hands) and `0x186a7`
  (hug walk / Love Stroll) remap the action again based on the current action value plus
  `role+0x398` (previous action snapshot), producing the `0x123..0x127` and
  `0x20b..0x20f` paired-interaction families.
- After translation it calls `RoleView.vtable+0x0c(translatedAction, 1, eax_23, role[0xd4], role[0xd5], 1)`
  and writes the resulting **frame count** into `role+0x1ac`.
- If `role+0x368 == 0xc` (state "using skill") and `sub_6e4e98() != 0`, it also kicks
  `sub_6639db(CHero, 1)` / `sub_6666a9(CHero, tileX, var_1c)` (hero state hooks).
- Frame interval gets recomputed and written into `role+0x1b8`; optional frame jitter via
  `Conquer_GetRandomModulo(role+0x1ac, 0)` → `role+0x1b0`.

`CRole+0x60` is therefore not a generic action-refresh request. It is the Shuriken Vortex
action-override latch, and `CRole+0x64` is the wall-clock tick captured when that status
begins.

### Verified Vortex producers and exit command

`Role_ApplyStatusFlagBitfieldAndDispatchEffects` (`0x6729b5`) owns the status transition:

- rising native status index `0x2e` at `0x672ca1` calls
  `Shared_SetDwordFieldAtOffset60(role, 1)` and
  `Shared_SetDwordFieldAtOffset64(role, timeGetTime())`;
- falling status at `0x672cc9` resets the command block at `CRole+0x11c`, writes command
  type `6`, progress `0`, and payload action `0x391`, applies it through the `CRole`
  vtable slot `+0x80`, then clears `CRole+0x60`.

The clean 5517 data corroborates those identities: `ini/ActionSound.ini` maps action
`912` (`0x390`) to `Ninjamagic-02B-loop.wav`, while `ini/MagicEffect.ini` names magic
record `60100` `ShurikenVortex` and sets `ActOfAttacker=913` (`0x391`).

## Phase 4 — render target switch (0x64fae2 → 0x65008c)

Gated by `role[0x108]` (byte `+0x420`):

| value | path       | what happens                                                                                         |
|-------|------------|------------------------------------------------------------------------------------------------------|
| `0`   | `0x64ff45` | Normal path: `CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView`, then vtable `+0x28`.    |
| `1`   | `0x64fd20` | Offscreen render target path (see below). Transitions to `2` when done.                             |
| `2`   | `0x64ff45` | Offscreen target already populated → re-uses it on normal path, still calls vtable `+0x28`.         |

### Offscreen target construction (role[0x108] == 1 → 0x64fd20..0x64ff44)

```
role[0x109] = 0x100                                  ; store requested target size
if g_OffscreenTargetPoolSingleton == nullptr:
    OffscreenRenderTargetPool_CreateSingleton()
target = OffscreenRenderTargetPool_GetByRequestedSize(pool, 0x100)
if target->vtable+4() == 0:                          ; BeginScene failed
    Debug_LogMessageToDailyFileWithDedup("pTargetBmp->BeginScene()", ...)
CMyBitmap::ClearBuffer(1, 1, 0)                       ; clear to key color
CMyBitmap::GameCameraBuild(0x100)                     ; re-build camera for 256×256 RT
CMyBitmap::GameCameraGetPos(&pos)                     ; save current camera
CMyBitmap::GameCameraSet(0, 0, 0, 3)                  ; override with centered ortho camera
CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView(role)
RoleView.vtable+0x10(transform…)                      ; re-pose the role centered
RoleView.vtable+0x20(2, 0)                            ; "prepare render" variant
RoleView.vtable+0x28(0)                               ; SHARED RENDER COMPOSITE (slice-12 entry)
CMyBitmap::GameCameraSet(savedPos)                    ; restore camera
CMyBitmap::GameCameraBuild(screenW, screenH)          ; rebuild for screen
RoleView.vtable+0x10(original transform…)             ; restore pose
target->vtable+0x8()                                  ; EndScene()
target->vtable+0x28()                                 ; get bitmap pointer
MyBitmapCreateEx(bitmap, 1) → role[0x10b]             ; snapshot into role's cached bitmap
role[0x108] = 2                                        ; sticky: future frames use the cache
goto 0x64ff45
```

This is the classic "render a 256×256 preview/portrait bitmap of the role to be pasted
somewhere else in UI" path (character select, party frame, etc.). The role's 3D draw
then happens **again** on screen via the fall-through.

## Phase 5 — fallback/direct render (0x64ff45 → 0x650033)

Falls through from either `role[0x108] == 0` or the offscreen-target tail. Does:
1. `CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView(role)` — pushes cached
   helmet/body/l_weapon/misc/r_weapon lookup ids from `role+0x104/+0x108/+0x10c/+0x110/+0x114`
   into the RoleView via vtable `+0x04` using selector codes `{0x23, 0x29, 0x2d, 0x24, 0x25}`.
2. `RoleView.vtable+0x28()` — the real slice-12 `RoleView_SharedRenderComposite` dispatch.
3. Optional cached-bitmap overlay path (`role[0x10b] != 0`): projects the cached snapshot
   back into screen space via `CGameMap_GetProjectionCenterWithOffset` +
   `CGameMap_MapScreenPointToVirtualViewportCoordinates(eax_103, ...)`, re-clamps to the
   projection divisor `data_93c6c0`, and dispatches either vtable `+0x4` (pre-blend) or
   vtable `+0x8` (blit) on the bitmap — this is the "draw the cached 256×256 RT back onto
   the screen" branch, used when the first frame has finished populating the target.

## Phase 6 — secondary render pass for `role[0x7c] == 1` (0x650033 → 0x650108)

When `role[0x7c] == 1` (byte `+0x1f0`, a "do extra pass" flag):
1. Re-pose via vtable `+0x10` using the scaled-down transform (`[0x86ab84]` multiplier).
2. vtable `+0x04(0xa, role[0x6c])` — selector push using `role+0x1b0` (the jittered frame).
3. vtable `+0x18(tintR, tintG, tintB, alpha * scale)` — tint override for this pass.
4. `CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView(role)` again.
5. vtable `+0x28()` — second `RoleView_SharedRenderComposite` call.

Used for ghost/afterimage effects, or double-render for reflective surfaces.

## Phase 7 — attached effect overlays + HP/name bar (0x650108 → 0x6501e0)

1. `Role_DrawAllAttachedEffectAniOverlays(role, role[0xd6], role[0xd7] - var_1c_2)` —
   iterates the `std::deque<RoleEffectEntry*>` at `role+0xa4` and draws each via
   `Role_DrawAttachedEffectAniOverlay` (backed by `ani/effect.ani`).
2. If `role[0xd6]` near-edge clamp: applies a left (`ebx_3 = 1`) or right (`ebx_3 = 5`) screen-edge nudge.
3. `Role_ComputeStatusBarOverheadScreenOffsetY(screenW, screenH, role)` — computes the Y offset
   (accounts for jumping, mounted, flying, motion arc).
4. `Role_DrawSayHelloDialogBubbleOverhead(&role[0xee])` — optional chat bubble (5-second timeout),
   uses `ani/common.ani!Dialog` frame and `CMyBitmap::ShowEmotionStringCommon` with the font-set
   from `Load_FontSetting_Ini`.
5. `Role_DrawAllFloatingStringOverlays(&role[0xf2], ...)` — iterates `std::deque<FloatingStr*>`
   at `role+0xf2` (byte `+0x3c8`) and draws each via `CMyBitmap::ShowStringCommon`.
6. HP bar draws via `role[0x10c]` (bar frame vtable `+0xc`) and name bar via `role[0x10d]`
   (name frame vtable `+0xc`), with `role[0xc5]` spacing between them. Status flag `0x1b`
   adds `role[0xc3] / 2` to the Y anchor.

## Phase 8 — deferred named part effects for next frame (0x6501e0 → 0x650298)

Not a draw: these are named effect removals/ensures performed after the current composite,
so the resulting body/mount effect list is consumed by the next frame:

```
if Role_HasStatusFlag(role, 0x5f) != 0:                ; "aiming" status
    if Role_HasStatusFlag(role, 0x32) != 0:            ; "mounted"
        CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(role, 4, "flagmanaim")
        CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName(role, 8, "flagmountaim")
    else:
        CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(role, 8, "flagmountaim")
        CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName(role, 4, "flagmanaim")
else:
    CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(role, 8, "flagmountaim")
    CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(role, 4, "flagmanaim")

if Role_HasStatusFlag(role, 0x76) != 0:
    if Role_HasStatusFlag(role, 0x32) != 0:
        CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(
            role, 4, "WarFlagEscortStatusNoMount")
        CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName(
            role, 8, "WarFlagEscortStatusMount")
    else:
        CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(
            role, 8, "WarFlagEscortStatusMount")
        CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName(
            role, 4, "WarFlagEscortStatusNoMount")
else:
    CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(
        role, 8, "WarFlagEscortStatusMount")
    CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(
        role, 4, "WarFlagEscortStatusNoMount")
```

The two helpers resolve to:
- `CRole__RemoveRoleViewPartEffectInstanceBySelectorAndName(role, selector, effectName)` →
  `role[0xed]->vtable+0x20(selector, effectName)`
- `CRole__EnsureRoleViewPartEffectInstanceBySelectorAndName(role, selector, effectName)` →
  `role[0xed]->vtable+0x1c(selector, effectName)`

The takeaway: status flags `0x5f` (aim), `0x32` (mount), and `0x76` (escort) drive
four named `3DEffect.dbc` effects. Selector `4` targets `body`; selector `8` targets
`mount`. Removal is case-sensitive and erases the first matching effect instance.

## Key CRole byte offsets discovered (native)

| byte offset | decompile name | meaning                                                                 |
|-------------|----------------|-------------------------------------------------------------------------|
| `+0x28`     | `role[0xa].b`  | byte flag — enables debug overlay print of action frame info            |
| `+0x60`     | `role[0x18]`   | Shuriken Vortex action-override latch (dword, `1` while active)          |
| `+0x64`     | `role[0x19]`   | Shuriken Vortex entry tick (`timeGetTime`), used by action `0x390`      |
| `+0x70`     | `role[0x1c]`   | facing-override primary (signed; `< 0` means fall back)                 |
| `+0x1a4`    | `role[0x69]`   | current action id (m_iCurActType), read by `Role_GetCurrentActionId`   |
| `+0x1a8`    | `role[0x6a]`   | facing value (0..7) consumed as vtable+4 code-0xa argument             |
| `+0x1ac`    | `role[0x6b]`   | current action frame count (written by `Role_UpdateActionAndDispatchRoleViewMotion`) |
| `+0x1b0`    | `role[0x6c]`   | randomized frame-start offset                                           |
| `+0x1b4`    |                | action start tick snapshot (written in `Role_UpdateAction...`)          |
| `+0x1b8`    |                | computed frame interval (milliseconds)                                  |
| `+0x3b4`    | `role[0xed]`   | **m_pIRoleView** (the `I3DRole`/`IRoleView` COM-ish pointer)            |
| `+0x420`    | `role[0x108]`  | render target state: 0=direct, 1=build offscreen, 2=use cached          |
| `+0x424`    | `role[0x109]`  | offscreen target requested edge size (0x100 = 256)                      |
| `+0x42c`    | `role[0x10b]`  | cached offscreen bitmap pointer                                         |
| `+0x430`    | `role[0x10c]`  | HP bar widget pointer (vtable+0xc draws)                                |
| `+0x434`    | `role[0x10d]`  | name bar widget pointer (vtable+0xc draws)                              |
| `+0x104`    |                | cached helmet lookup id (pushed via selector code 0x23)                 |
| `+0x108`    |                | cached mix helmet id (selector code 0x29)                               |
| `+0x10c`    |                | cached mix2 helmet id (selector code 0x2d)                              |
| `+0x110`    |                | cached body lookup id (selector code 0x24)                              |
| `+0x114`    |                | cached l_weapon lookup id (selector code 0x25)                          |

The body/helmet/l_weapon lookup ids come from `CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView`
(`0x6e56da`) — the helmet loop iterates 3 entries using the code string `"#)-"`
(`0x23, 0x29, 0x2d`) and skips each if the cached id is `<= 0`.

## Sub_* renames landed this slice

| old                     | new                                                         | purpose                                                              |
|-------------------------|-------------------------------------------------------------|----------------------------------------------------------------------|
| `sub_769018`            | `Debug_LogMessageToDailyFileWithDedup`                      | CHECK/ASSERT logging to `./debug/YYYY_M_D.log`                      |
| `sub_769197`            | `Debug_OutputDebugStringFormatted`                          | vsnprintf + `OutputDebugStringA`                                    |
| `sub_404ce4`            | `SharedPtrControlBlock_DecrementStrongReference`            | MSVC shared-pointer strong/weak control-block release                |
| `sub_6e54ef`            | `Role_DrawAllAttachedEffectAniOverlays`                     | iterate deque at `role+0xa4`                                        |
| `sub_71e96d`            | `Role_DrawAttachedEffectAniOverlay`                         | single effect.ani entry draw                                        |
| `sub_650980`            | `Role_ComputeStatusBarOverheadScreenOffsetY`                | HP/name bar Y-anchor offset                                         |
| `sub_6d85eb`            | `Role_DrawSayHelloDialogBubbleOverhead`                     | 5-sec chat bubble via Dialog frame in common.ani                    |
| `sub_7380a5`            | `Role_DrawAllFloatingStringOverlays`                        | iterate floating-string deque                                        |
| `sub_61d77f`            | `CGameMap_MapScreenPointToVirtualViewportCoordinates`       | screen→virtual-viewport mapping for cached RT blit                  |
| `sub_72cb28`            | `OffscreenRenderTargetPool_GetByRequestedSize`              | tier lookup by size (<=128/<=256/<=512)                             |
| `sub_59db7f`            | `OffscreenRenderTargetPool_CreateSingleton`                 | pool singleton create (once)                                        |
| `sub_5d29ca`            | `CGameMsg_PostFormattedByCode`                              | vsnprintf + `GameMsg_DispatchByCode`                                |
| `sub_69a51d`            | `Shared_SetDwordFieldAtOffset60`                            | shared-object dword setter; Vortex latch when object is `CRole`     |
| `sub_6c7be3`            | `Shared_SetDwordFieldAtOffset64`                            | shared-object dword setter; Vortex entry tick when object is `CRole` |

## Managed parity status

| native behaviour                                             | managed status                                                                                     |
|--------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Phase 3 current-action dispatch                              | Modeled by `RoleViewBodyActionDispatchRuntime.DispatchAction` (slice 10).                          |
| Phase 3 Vortex latch and entry tick (`role+0x60/+0x64`)      | Modeled by `RoleVortexActionOverrideState`; `ClientWorldRoleStateStore` arms it only on the status-`0x2e` rising edge and preserves the entry tick across repeated active updates. |
| Phase 3 Vortex action `0x390` wall-clock loop                | Modeled by `Role3DClientRolePlayback`; the underlying `CRole` action remains unchanged while RoleView receives `0x390`, sampled from the captured status-entry tick. |
| `Role_UpdateActionAndDispatchRoleViewMotion` Vortex property query and dispatch | Modeled by `RoleCommandStatePerRoleTickPump` through `IRoleViewMotionDispatchRuntime.GetPropertyByKey` followed by action `0x390` dispatch; timing retains the current action and is written on a zero frame count. |
| Status-`0x2e` exit command action `0x391`                    | Modeled for the local hero by `ClientWorldInboundPacketApply` and `RoleCommandStateTickSnapshotState.ApplyShurikenVortexExitCommandState`. |
| Phase 5 `ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView` | **Implicit** — managed `Role3DClientSceneMultiPartRenderStageRuntime` reads resolved sources directly from the visual plan rather than round-tripping through a selector-code sink. See `Role3DPartContainer.SetPartSource`. The native selector codes `{0x23, 0x24, 0x25, 0x29, 0x2d}` are documented here as the RoleView sink that the managed plan bypasses. |
| Phase 5 `RoleView.vtable+0x28` composite                     | Modeled by `Role3DClientSceneMultiPartRenderStageRuntime` (slice 12).                              |
| Phase 4 offscreen render target path                         | **Not modeled** — managed client has no portrait/preview render target yet. Pure deferred work.   |
| Phase 6 `role[0x7c] == 1` secondary pass                     | **Not modeled** — ghost/afterimage pass, deferred.                                                |
| Phase 7 overlays (shadow, attached effects, chat, HP bar)    | Separate slices (shadow = slice ?, overlays = HUD pipeline, deferred).                            |
| Phase 8 deferred named part effects (`flagmountaim`, …)      | Modeled by `PlayerRoleViewDeferredStatusEffectRuntime` and the live multi-part render stage. Both 64-bit status words are retained. |

## Code-actionable findings applied

- `RoleViewActionFeedSettings.VerifiedVortexLoopActionId` records action `0x390`.
- `ClientWorldRoleStateSnapshot` retains both status words and the verified Vortex
  latch/start-tick state.
- `Role3DClientRolePlayback` keeps the underlying role action separate from the temporary
  RoleView Vortex action and samples the Vortex frame from the status-entry clock.
- Vortex exit applies the verified type-`6`, progress-`0`, action-`0x391` command state for
  the local hero.
