# `RoleView.dll` — Action Playback + Transition State (Type 2 / Type 10)

This document pins the BNinja-verified body-motion playback transition path used by:

- `RoleView_UpdateRolePartMotionsForAction` (`0x10002DC8`)
- `RoleView_Type2_UpdateRolePartMotionsForAction` (`0x10003E39`)
- `RoleView_SetPrimaryFrameForAllRoleParts` (`0x10002756`)
- shared part update calls on `roleView->+0xD8` vtable (`+0x2C`, `+0x34`, `+0x54`)

## Verified state fields (RoleView object)

| Offset | Type | Meaning |
|---:|---|---|
| `+0x20` | `int32` | Current action id (`m_currentActionId`). |
| `+0xE0` | `uint32` | Previous body-motion lookup key low32 (active transition source). |
| `+0xE4` | `uint32` | Previous body-motion lookup key high32 (active transition source). |
| `+0xE8` | `uint32` | Transition start tick (`timeGetTime()` snapshot). |
| `+0xEC` | `uint32` | Transition duration in ms (`GameDataSetQuery()->+0x6C(oldAction,newAction)`). |
| `+0xF0` | `int32` | Current primary frame index (written by `RoleView_SetPrimaryFrameForAllRoleParts`). |
| `+0xF4` | `int32` | Secondary-frame index used for previous-motion blend sampling. |
| `+0xF8` | `int32` | Type-2 latched action id (`-1` sentinel until first update call). |
| `+0x100` | `int32` | Type-2 latched primary-frame property value (`-1` sentinel until first property `0xA`). |

## Transition-start path (verified)

In `RoleView_UpdateRolePartMotionsForAction`, when `newActionId != m_currentActionId`:

1. Clear transition source state first:
   - `mov [esi+0xE0], 0`
   - `mov [esi+0xE4], 0`
   - `mov [esi+0xEC], 0`
   - evidence: `0x10002F5E..0x10002F6A`.
2. If the newly requested action's current body motion resolved successfully:
   - read duration: `GameDataSetQuery()->+0x6C(oldAction,newAction)` into `+0xEC`
   - (`GraphicData.dll` names this method `GameDataSet_GetActionTransitionTime`)
   - evidence: the `currentBodyMotion != null` gate at `0x10002F70`, followed by
     `0x10002F72..0x10002F83`.
3. If duration > 0:
   - `+0xE8 = nowTick`
   - `+0xF4 = +0xF0`
   - `(+0xE0,+0xE4) = RoleView_BuildBodyMotionLookupKey(oldAction)`
   - evidence: `0x10002F8B..0x10002FB0`.

The new motion is the eligibility gate; the previous motion is only the blend source.
A resolved previous motion must not start a transition when the new body motion is missing.

## Transition blend formula (verified)

While transition source key exists and duration is non-zero:

- `blendAlpha = 1.0f - (nowTick - transitionStartTick) / transitionDurationMs`
- evidence: `fild/fidiv/fsubr` at `0x1000302D..0x10003039`.

Clamp/termination rule:

- if `blendAlpha < 0`:
  - clear `+0xE0`, `+0xE4`, `+0xEC`
  - force `blendAlpha = 0`
  - evidence: `0x10003045..0x10003058`.

## Body part application order (verified)

Loop over 3 part names from `RoleView_RolePartNameTable_BodyAndHelmetVariants`:

1. Set current motion pointer:
   - call `(*roleInterface+0x2C)(partName, currentBodyMotion)`
   - evidence: `0x10002FEC..0x10002FF0`.
2. If transition active:
   - resolve previous body motion by key (`"body"`, `+0xE0/+0xE4`)
   - call `(*roleInterface+0x34)(partName, previousBodyMotion, blendAlpha)`
   - call `(*roleInterface+0x54)(secondaryFrameIndex=+0xF4)`
   - evidence: `0x1000306C..0x100030B2`.
3. If transition inactive:
   - call `(*roleInterface+0x34)(partName, 0, 0.0f)`
   - call `(*roleInterface+0x54)(0)`
   - evidence: `0x100030DD..0x100030FB`.

Role3D-side confirmation for slot `+0x54`:

- `I3DRole_SetSecondaryFrameForAllParts` (`Role3D.dll:0x100014A0`) walks every loaded
  named part.
- `PartInfo_SetSecondaryFrameForAllPartMeshes` (`Role3D.dll:0x10005D40`) forwards the
  frame to each `C3DObjX` through its vtable slot `+0x50`.
- Therefore each `+0x54` call is a global secondary-frame push, not a write limited to
  the body-family name processed by the current loop iteration.

## Action playback stays on already-loaded body-family parts (verified)

`RoleView_UpdateRolePartMotionsForAction` does **not** reload body/helmet sources on
action change:

- no call to `PlayerRoleView_ReloadHelmetVariantAtLayer`
- no call to `PlayerRoleView_LoadPartSourceIntoI3DRole`

Instead, the action update path operates on the existing type-1 part family:

- current body motion is resolved once from the `"body"` motion key
- when `refreshPartActionEffects != 0`, the dispatcher runs
  `PlayerRoleView_ConfigureRolePartActionEffects(roleView, "body", roleView+0x24, roleView+0x78, actionId)`
  exactly once before the body-family motion fan-out
- `I3DRole_SetPartMotionAndPrimaryFrameByName` then applies that same current body motion
  across the full body-variant table:
  - `body`
  - `mix_body`
  - `mix2_body`
- when blend state is active, `I3DRole_SetPartBlendMotionAndSecondaryFrameByName` applies the
  previous body motion across that same three-name body family
- the primary-frame increment on the previous blended motion is only advanced from the
  `body` iteration; `mix_body` / `mix2_body` reuse that shared blended body-family state
- the normal player-RoleView path applies the same split for helmet variants:
  - `PlayerRoleView_ConfigureRolePartActionEffects(roleView, "armet", roleView+0x30, roleView+0x84, actionId)`
    is called exactly once
  - `I3DRole_SetPartMotionAndPrimaryFrameByName` then fans helmet motion out across:
    - `armet`
    - `mix_armet`
    - `mix2_armet`
- `misc`, `mount`, `r_weapon`, and `l_weapon` still use the direct one-name visual-track +
  motion update path
- the currently proven direct caller set into `PlayerRoleView_ConfigureRolePartActionEffects` remains:
  - mount-only action path: `mount`
  - normal player-RoleView path: `body`, `misc`, `mount`, `armet`, `r_weapon`, `l_weapon`

Verified Role3D-side work done by `PlayerRoleView_ConfigureRolePartActionEffects`:

- body-family parts first clear all named effects unconditionally through
  `I3DRole_RemovePartEffectInstanceByName(null, partName)`
- `RoleDataSingleton_HasNoArmorSoulEffectAction(actionId)` gates only the mounted
  appearance-family adjustment; it does not gate the clear
- the helper then fetches the per-part effect producer through
  `I3DRole_GetPartEffectProducer(partName)`
- writes effect-producer state on every resolved role-data layer:
  - `Game3DEffect_SetLocalTransformEnabledFlag(1)`
  - optional `Game3DEffect_SetScaleForSelection(..., -1, 0)` from record percentages
  - `Game3DEffect_SetRotationForSelection(..., -1, 0)` only for `body` / `mix_body` / `mix2_body`
- finally ensures the named part effect instance through
  `I3DRole_EnsurePartEffectInstanceByName(effectName, partName, 0)`

Current managed parity boundary for this slice:

- the rewrite now mirrors this verified helper only for the newly constructed player-RoleView
  primary `body` and primary `armet` paths, including packet-fed override lookup ids from the `10014` startup
  state
- the effect-runtime cache is keyed by `(part source id, role-data override lookup id)` so a
  changed override input rebuilds the managed producer state even when the base source id is
  unchanged
- the layered body/helmet families are already proven on the motion side through
  `I3DRole_SetPartMotionAndPrimaryFrameByName` /
  `I3DRole_SetPartBlendMotionAndSecondaryFrameByName`
- they are still **not** proven as direct visual-track callers; the verified native dispatcher
  configures visual tracks only for primary `body` and primary `armet`
- the hypothesized downstream all-part Role3D refresh path is also still unproven in the live
  client: `I3DRole_RefreshAllPartEffectVisualTrackConfigs` is real, but the current
  `RoleView.dll` scan does not show any `m_pIRole` slot `+0x68` ingress into it

Verified loop contract:

- `PlayerRoleView_ConfigureRolePartActionEffects(partName, partSourceId, overrideLookupId, actionId)`
  performs its own internal `layerIndex = 0..2` loop
- each iteration queries one `Action3DEffect` layer bucket
- the first lookup miss breaks the loop immediately
- mount, misc, right weapon, and left weapon all use that same internal three-layer loop;
  the caller does not pass a precomputed layer index

### `RoleDataQuery` action-effect tables consumed by `PlayerRoleView_ConfigureRolePartActionEffects` (verified)

`PlayerRoleView_ConfigureRolePartActionEffects` uses two `GameData.dll` role-data queries:

- `RoleDataQuery()->+0x10`:
  `RoleDataSingleton_FindAction3DEffectRecord` (`0x100020D4`)
- `RoleDataQuery()->+0x18`:
  `RoleDataSingleton_HasNoArmorSoulEffectAction` (`0x10002460`)

Verified load chain in `GameData.dll`:

- `RoleDataSingleton_LoadAction3DEffectTables` (`0x10001D99`)
  - probes three files in order:
    - `ini/Action3DEffect.ini`
    - `ini/Action3DEffect1.ini`
    - `ini/Action3DEffect2.ini`
  - always iterates all three layer buckets rooted at the role-data singleton table base
    `+ ((layerIndex * 3 + 0x5D) << 2)`
  - ignores the per-file return value, so missing numbered files leave those buckets empty
- `RoleDataSingleton_LoadAction3DEffectFile` (`0x10001E26`)
  - skips lines whose first byte is `/`, `;`, `0x0D`, or `0x0A`
  - parses keys with `"%I64d.%I64d.%I64d.%I64d=%s"`
  - when the effect token contains `~`, rewrites `~` to spaces and parses
    `"%s %d %d %d"`
- `RoleDataSingleton_LoadNoArmorSoulEffectActionSet` (`0x100023CF`)
  - scans `ini/NoArmorSoulEffectAction.ini` with repeated `fscanf("%d")`
  - inserts every parsed integer into the set rooted at `RoleDataSingleton + 0x1D4`

Verified `Action3DEffect` record payload stored by
`RoleDataAction3DEffectRecord_Assign` (`0x10002096`):

| Payload field | Default | Native source |
|---|---:|---|
| `customTransformPercentX` | `100` | first `%d` after `~` |
| `customTransformPercentY` | `100` | second `%d` after `~` |
| `customTransformPercentZ` | `100` | third `%d` after `~` |
| `hasCustomTransformPercent` | `0` | set to `1` only when the `~` parse succeeds |
| `effectName` | `""` | `%s` token before optional `~` fields |

Verified caller-side query arguments from `PlayerRoleView_ConfigureRolePartActionEffects`:

- `appearanceFamily = (partSourceId / 1_000_000) % 1000`
- `actionId = currentActionId`
- `sourceCategoryCode = (effectiveSourceId / 1000) % 1000`
- `sourceVariantCode = effectiveSourceId % 1000`
- `layerBucket = internalLayerIndex % 3`

`effectiveSourceId` is the currently selected part source family, optionally replaced by
`RoleDataQuery()->+0x14` (`RoleDataSingleton_ResolveWeaponSourceFromSoulPart`) when a
weapon override lookup id is present.

Verified packed lookup key formula used both by the loader and the query:

- `packedKey = (((appearanceFamily * 10000) + actionId) * 1000 + sourceCategoryCode) * 1000 + sourceVariantCode`

Verified fallback order inside `RoleDataSingleton_FindAction3DEffectRecord`:

1. exact key
2. `appearanceFamily = (appearanceFamily / 1000) * 1000 + 999`
3. same wildcarded `appearanceFamily`, plus `actionId = 9999`
4. same wildcarded `appearanceFamily`, plus `sourceCategoryCode = 999`
5. same wildcarded `appearanceFamily`, plus `sourceVariantCode = 999`
6. original `appearanceFamily`, plus `actionId = 9999`
7. original `appearanceFamily`, plus `sourceCategoryCode = 999`
8. original `appearanceFamily`, plus `sourceVariantCode = 999`

Verified body-family handling in `PlayerRoleView_ConfigureRolePartActionEffects`:

- for `body`, `mix_body`, and `mix2_body`, the helper clears the part's named effects
  through `I3DRole_RemovePartEffectInstanceByName(null, partName)` before querying
  `RoleDataQuery()->+0x18(actionId)`
- when the action id is present in `NoArmorSoulEffectAction.ini` and a mount source is
  active, the helper adds `RoleView_ExtractMountEquipmentFamilyCode(this) * 1000` to
  `appearanceFamily`
- the no-armor/soul predicate gates only that mounted-family adjustment, not the clear

Practical parity consequence:

- for the startup local hero, missing visible motion is not explained by action-time
  body source reloads
- `I3DRole` slots `+0x58` / `+0x60` / `+0x78` are part-effect paths, not body-motion
  binders
- RoleView slot `+0x20` is a named part-effect removal path, not a mesh-instance selector
- the selector chooses the target part; the string argument chooses the effect name

## Secondary-frame increment rule (verified)

Increment happens once per update, only on body variant index `0`, and only when previous-body motion exists:

- compare `+0xF4` against `previousBodyMotion->GetFrameCount() - 1`
- increment only when `<`
- evidence: `0x100030C2..0x100030D3`.

The first body iteration pushes the pre-increment value globally at `0x100030B2`, then
increments `+0xF4`. The following `mix_body` iteration repeats the global slot-`+0x54`
push with the incremented value. Consequently the effective frame present when rendering
begins is the incremented, capped value. The previous-motion secondary frame is monotonic
and never wraps in this function.

## Type-2 wrapper behavior (verified)

`RoleView_Type2_UpdateRolePartMotionsForAction` (`0x10003E39`):

- uses `+0xF8` as a latched action id:
  - if `+0xF8 == -1`, stores requested action id into `+0xF8`;
  - always dispatches shared updater with that latched value.
- evidence: `0x10003E39..0x10003E61`.

`RoleView_SetPrimaryFrameForAllRoleParts` (`0x10002756`):

- forwards frame index to `(*roleInterface+0x50)(frame)`;
- mirrors frame into `+0xF0`.
- evidence: `0x1000276B` and `0x1000276E`.

Managed parity consequence for startup-local-hero playback:

- this primary-frame property write is a separate per-tick stage from
  `RoleView_UpdateRolePartMotionsForAction`; it is not folded into the slot-43
  `SetPartMotionAndPrimaryFrameByName` dispatch.
- inference from the verified bridge above plus the verified `PartInfo_ResetPerPartState`
  path in `Role3D.dll`:
  - when a body action lookup misses and the null-motion path resets the mesh back to its
    default motion tracker, the same tick still pushes property key `0x0A`,
  - so the already-bound default tracker continues advancing through the
    `(*roleInterface+0x50)(frame)` fan-out instead of freezing at frame `0`.
- managed playback that only mirrors slot `+0x0C` action dispatch and omits the later
  property-key `0x0A` frame push will therefore render a bind/static body pose for clean
  5517 startup-idle cases where the body action lookup itself does not resolve a tracker.

## `Conquer.exe` feed cadence into RoleView (verified bridge)

`RoleView` transition state is driven by `Conquer.exe` `3DRole\\Role.cpp` tick/update calls.

Renamed verified caller functions in `Conquer.exe` BNinja DB:

- `Role_UpdateActionAndDispatchRoleViewMotion` (`0x64E2DD`)
- `Role_TickAndRender` (`0x64F5F7`)
- `CRole__Init` (`0x64D260`)
- `CRole__InitProperties` (`0x651616`)
- `CRole_InitializeCommandStateType05` (`0x64DC52`)
- `Role_TickCommandStateAndDispatchPlayback` (`0x6725F3`)
- `Role_ComputeFrameIntervalFromAction` (`0x64DE0E`)
- `Role_GetCurrentActionId` (`0x65138A`)
- `Role_GetActionType` (`0x64DDE6`)
- `Role_SetActionType` (`0x64DDD9`)
- `Role_GetStateCode1EC` (`0x64DE07`)
- `Role_GetStateCode1E8WithCompleteFallback` (`0x64DDED`)
- `Role_HasStatusFlag` (`0x6E50D4`)
- `Role_TryApplyIncomingActionInfo` (`0x64DD38`)
- `RoleActionCommandState_ResetBlock0x11C` (`0x64D033`)
- `Role_SetMountedActionFrameIntervalAndRefreshActionScale` (`0x6E5E75`)
- `Role_UpdateMountActionScaleCacheFromRoleState` (`0x6E5E33`)
- `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`)
- `Role_QueryMountActionScaleRecord` (`0x6E6045`)
- `Role_SelectActionFromCommandStateSwitch` (`0x64F154`)
- `Role_ProcessCommandStateAndCombatPackets` (`0x65C0F5`)
- `Role_CommandType04_SelectActionFromCommandPayload` (`0x7344B7`)
- `Role_CommandType06_SelectActionFromCommandPayloadMap` (`0x73450B`)
- `Role_CommandType07_SelectActionFromCommandPayloadAndComplete` (`0x7371C0`)
- `Role_CommandType02_UpdateMotionPathAndSelectAction` (`0x7379A2`)
- `Role_CommandType03_UpdateMotionPathAndSelectAction` (`0x7350B3`)
- `Role_CommandType11_UpdateMotionPathAndSelectAction` (`0x7363A9`)
- `Role_CommandType12_UpdateMotionPathAndSelectAction` (`0x7365F3`)
- `Role_CommandType13_UpdateMotionPathAndSelectAction` (`0x736B14`)
- `Role_SelectDirectionIndexTowardTargetEntity` (`0x6E4B04`)
- `Role_SelectDirectionIndexTowardTile` (`0x6E4ACC`)
- `Direction_Select8WayFromPoints` (`0x61E45E`)
- `Direction_Select8WayFromDelta` (`0x61E478`)
- `Role_GetField2DA8StatusValue` (`0x7178D5`)
- `Map_AreProbeEndpointsHeightDeltaLe25` (`0x61EB65`)
- `Map_CoordinateGateCheckValue` (`0x713315`)
- `Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`)
- `MotionPath_ClearNodes` (`0x6406A3`)
- `MotionPath_GetNodeCount` (`0x6406BB`)
- `MotionPath_ReadAndAdvanceDirectionIndex` (`0x640651`)
- `MapPathService_TryBuildPath` (`0x6208E2`)
- `MapPathService_GetFallbackTargetTile` (`0x6208B4`)
- `Map_GetTileEntryByCoordinates` (`0x61D9C8`)
- `MapTileEntry_GetTailLinkNode` (`0x61EAEE`)
- `MapTileEntry_GetTailLinkElevation` (`0x61EBC5`)
- `MapTileEntry_GetTailLinkPassabilityFlag` (`0x61EBE5`)
- `Map_ProjectTileToScreenCoordinates` (`0x61D850`)
- `Conquer_GetRandomModuloWithOptionalTimeReseed` (`0x769250`)
- `Role_IsSpecialIdleActionWindowActive` (`0x6E4FA1`)
- `Role_SetActionAndOptionalDirection` (`0x733499`)

Verified `MapPathService` behavior used by command types `0x12`/`0x13` and pending mutual interaction:

- eight-neighbor order is south, southwest, west, northwest, north, northeast, east, southeast
- destination tail passability must be zero and signed tail elevation delta must be `<=25`
- first discovery marks a tile visited permanently for that search; there is no cost relaxation
- cardinal/diagonal cost is `10`/`14`; heuristic is `10 * ChebyshevDistance`
- the min-heap compares total estimated cost only and preserves the native equal-cost child/parent choices
- limited searches stop before expansion once created-node count is greater than `360`
- exact target discovery alone returns true; a supplied `MotionPath` is cleared and reconstructed to
  the closest discovered tile on failure

Fresh-role startup ordering:

1. `CRole__Init` calls `CRole__InitProperties(role+0xCC)` at `0x64D277..0x64D27D`.
2. `CRole__InitProperties` clears `roleProperties+0xC0` for `0x24` bytes at
   `0x6516DA`. In `CRole` coordinates this is `role+0x18C..+0x1AF`, so it clears
   `currentActionId` at `role+0x1A4` to `0`.
3. `CRole__Init` calls `CRole_InitializeCommandStateType05` at `0x64D282..0x64D284`.
   That helper writes command type `5` to `role+0x1E8` and progress `0` to
   `role+0x1EC` at `0x64DC54..0x64DC5E`.
4. `Role_TickCommandStateAndDispatchPlayback` invokes the vtable `+0x84`
   command-state selector at `0x6726D8`, then calls
   `Role_UpdateActionAndDispatchRoleViewMotion` at `0x6726E0`.
5. The type-5 selector writes the first idle action during that command-state
   selection. `0x64` is therefore a first-tick default, not a constructor seed.

Completed-state recurrence:

- `Role_SelectActionFromCommandStateSwitch` checks `role+0x1EC` first. When progress
  is `6`, `0x64F160..0x64F16D` invokes CRole vtable slot `+0x6C` and returns.
- CRole vtable slot `+0x6C` is `Role_CommandType05_SelectActionAndMarkComplete`, so
  completed command state re-enters type-5 idle selection on every selector tick.
- the same virtual callback handles command types `5`, `0x0B`, `0x1C`, `0x23`, and
  out-of-range command types in the non-complete switch path.

Fresh-role type-5 external input defaults:

- `role+0x2C = -1` and `role+0x30 = -1`: `0x64D2C2..0x64D2C5`.
- `role+0x30C = 0` (vertical render offset): `0x64D2E0`.
- `role+0x37C = 0` (special-idle action start tick): `0x64D2B6`.
- when command type is `5`, the handler requests `rand()%10` and requests
  `rand()%3` only when the first result is `1`: `0x73352A..0x733565`.
- `Role_IsSpecialIdleActionWindowActive` evaluates the unsigned expression
  `timeGetTime() - role+0x37C < 0x2710`: `0x6E4FA1..0x6E4FB9`.
- `Role_SetActionAndOptionalDirection` refreshes `role+0x37C` when the selected
  action is in `0x191..0x194`: `0x7334E0..0x7334F4`.

Managed consequence:

- `LocalHeroRoleViewRenderPlayback` must initialize its action feed to `0`, matching
  the native `CRole+0x1A4` constructor state.
- `RoleCommandStateTickSnapshotState.TryInitializeFreshRoleCommandState` now supplies
  type `5`, progress `0`, and the verified constructor defaults before the first
  local-role playback tick.
- initialization is one-shot and does not replace a command state already accepted
  from packet ingress.
- `PrepareCommandStatePlaybackTick` captures the unsigned `0x2710` time-window
  result before every managed selector tick because movement handlers can invoke
  CRole's type-5 virtual callback internally on path depletion or probe failure.
  This includes progress `6` and active command `0x11`/`0x12` ticks; these values
  are not one-time startup inputs. Random modulo calls remain restricted to an
  active command type `5`, matching the native branch.
- `RoleCommandStateActionSelection` routes progress `6` through the type-5 selector,
  matching the CRole vtable call at `0x64F166`.
- after selection, `Role3DClientRolePlaybackHost` writes the modeled command type,
  progress, data, and payload fields back to `RoleCommandStateTickSnapshotState`.
  Native handlers mutate the live `CRole+0x1E8` block directly, so discarding these
  bridge mutations would incorrectly rerun stale progress on the next tick.
- the modulo generator is injected for deterministic verification; production uses
  a process random source because the retail global CRT `rand()` sequence depends on
  prior runtime `srand()` and `rand()` calls throughout login and world startup.
- hard-seeding action `0x64` remains incorrect because it skips valid native first-tick
  outcomes `0x65..0x67`, `0x12C`, `0x1F5`, and `0x1F6`.

Per-tick normal branch in `Role_TickAndRender`:

1. dispatch action update:
   - `Role_GetCurrentActionId(this)` then `call [roleViewVtable+0x0C]`
   - evidence: `0x64FA24..0x64FA30`.
2. push primary-frame property:
   - `call [roleViewVtable+0x04](0x0A, frame)`
   - evidence: `0x64FA40..0x64FA4B`.

Native orchestration consequence:

- action dispatch and primary-frame sampling are part of the live render path itself,
  not a startup/bootstrap helper and not a one-off model init phase.
- for the local hero, the native ordering is:
  - map-component render callback
  - `Role_TickAndRender`
  - RoleView slot `+0x0C` action dispatch
  - RoleView slot `+0x04` primary-frame property write
  - RoleView transform/color/render calls
- any managed playback path that is only constructed from CLI harness arguments or only
  ticked before current-frame role scene submission is therefore non-native for the live
  world-entry/local-hero path.

The Shuriken Vortex branch (`CRole+0x60 == 1` and
`Role_HasStatusFlag(this, 0x2E) != 0`) dispatches action `0x390`, then computes:

- `frame = ((timeGetTime() - startTick) / frameInterval) % frameAmount`
- evidence: `0x64FA7C` (slot `+0x0C`), `0x64FA8F..0x64FAA1` (div/mod), `0x64FADD..0x64FADF` (slot `+0x04`, key `0x0A`).

`Role_UpdateActionAndDispatchRoleViewMotion` writes action playback state before regular tick sampling:

- action dispatch via slot `+0x0C`:
  - `currentAction`: `0x64E662`
  - branch action `0x390`: `0x64E63B`
- frame-interval setup:
  - `+0x1B8 = Role_ComputeFrameIntervalFromAction(...)`
  - evidence: `0x64E6FD`.
- action start tick:
  - `+0x1B4 = timeGetTime()`
  - evidence: `0x64E6E0..0x64E6ED`.

## New player-RoleView motion lookup fields already mirrored for the startup local hero

The current startup-local-hero slice already mirrors enough verified player-RoleView state to build
the live RoleView motion lookup inputs used by `PlayerRoleView_UpdateRolePartMotionsForAction`,
without inventing new packet semantics.

Verified native field meanings from `PlayerRoleView_SetPropertyByKey` / `PlayerRoleView_Set*Source`
and `PlayerRoleView_UpdateRolePartMotionsForAction`:

| RoleView offset | Native field | Verified live managed source for current slice |
|---:|---|---|
| `+0xA8` | body appearance source | `appearanceCompositeId % 1000` |
| `+0x44` | mount source family | transform-expanded `SteedIdentity` |
| `+0x40` | right-weapon source family | transform-expanded `RightHandIdentity % 1_000_000` |
| `+0x3C` | left-weapon source family | transform-expanded `LeftHandIdentity % 1_000_000` |
| `+0x48` | misc source family | `bodyAppearanceSourceId * 1_000_000 + (MiscSourceId % 1_000_000)` |
| `+0x30` | primary helmet source family | transform-expanded `HeadwearIdentity % 1_000_000` |
| `+0x90` | left-weapon override lookup id | `0` on new player-RoleView constructor path |
| `+0x94` | right-weapon override lookup id | `0` on new player-RoleView constructor path |

Evidence chain:

- `CMsgUserInfo__Process` creates a new player RoleView through `CRole__CreateRoleView`.
- `CRole__SetTransformLook` then applies the verified key sequence `3/5/6/7/9/8` and
  explicitly clears override keys `0x34/0x37/0x3B/0x3A`.
- `RoleView_UpdateRolePartMotionsForAction` consumes the stored type-1 fields above when
  building body/misc/helmet/weapon motion requests.

Current managed boundary for this slice:

- the startup-local-hero path now has enough verified state to drive live body/mount/misc/
  primary-helmet/weapon motion lookup.
- the layered helmet/body source writer helpers are now pinned in `RoleView.dll`
  (`SetPrimaryHelmetVariantSourceAndReload`, `SetHelmetVariantSourceAndReloadAtLayer`,
  `SetPrimaryBodyVariantOverrideAndReload`, `SetPrimaryHelmetVariantOverrideAndReload`).
- current managed startup parity still mirrors only the verified normal primary-helmet mesh
  branch; special helmet family branches (`0x75`, `0x76`, `0x77`, `0x7B`, `0x8D..0x8F`,
  `0xB1..0xB2`) remain deferred until their linked-source/fallback behavior is wired.

## `CRole` action-command state block (`+0x1E8`) and incoming gate (verified)

The role action-command block is a contiguous `0x11C` bytes rooted at `CRole+0x1E8`:

| Role offset | Block offset | Type | Meaning |
|---:|---:|---|---|
| `+0x1E8` | `+0x00` | `uint32` | command type code |
| `+0x1EC` | `+0x04` | `uint32` | command progress-state code |
| `+0x224` | `+0x3C` | `uint32` | command data code (branch discriminator in incoming gate) |
| `+0x228` | `+0x40` | `uint32` | command payload action id used by command-type action handlers |

Reset helper:

- `RoleActionCommandState_ResetBlock0x11C` zeroes this entire `0x11C` block.
- evidence: `0x64D03D` (`memset(..., 0, 0x1C)`) and `0x64D056` (`memset(..., 0, 0x100)`).

Accessor helpers:

- `Role_GetStateCode1EC(role)` returns `*(role + 0x1EC)`.
  - evidence: `0x64DE07..0x64DE0D`.
- `Role_GetStateCode1E8WithCompleteFallback(role)` returns:
  - `5` when `Role_GetStateCode1EC(role) == 6`,
  - otherwise `*(role + 0x1E8)`.
  - evidence: `0x64DDF8..0x64DE06`.

Incoming-state gate (`Role_TryApplyIncomingActionInfo`):

- null incoming pointer rejects immediately (`return 0`).
  - evidence: `0x64DD40..0x64DD42` and `0x64DD99`.
- on accept, copies exactly `0x11C` bytes into `role+0x1E8` and returns `1`.
  - evidence: `0x64DDBC..0x64DDD3`.
- reject branches:
  - when current command type (with complete fallback) is `0x20`, `0x21`, or `0x28` and incoming command type is `0x2F`.
    - evidence: `0x64DD4E..0x64DD56`, `0x64DD72`, `0x64DD97`.
  - when current command type is `0x2D`, current command data is `0x1F2` or `0x1F3`, incoming command type is not `0x2F`, and incoming command data is `0x1F4`.
    - evidence: `0x64DD77..0x64DD90`.
  - when current command type is `0x2E`, current progress-state is `0`, and incoming command type is `0x2F`.
    - evidence: `0x64DD67..0x64DD72`, `0x64DD97`.
- additional side-effect branch:
  - when current command type is `0x29`, status flag `0x32` is clear, and the active mounted action frame interval at `role+0x128` is non-zero, native calls `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, 0)` before applying incoming block.
  - evidence: `0x64DD9D..0x64DDB7`.

### Mounted action-scale cache chain (`role+0x128`, `role+0x188`, `role+0x314`)

Verified native write/update path for mounted action-scale state:

1. `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`)
   - clears the cached auxiliary lookup accumulator at `role+0x48` before rebuilding mounted action-scale state,
   - stores the incoming source tuple:
     - `role+0x50 = mountActionScalePrimarySource`
     - `role+0x3C = mountActionScaleSecondarySource`
     - `role+0x58 = mountActionScaleVariantSource`
     - `role+0x54 = mountActionScalePreferredSource`,
   - queries `Role_QueryMountActionScaleRecord(role)`,
   - on hit:
     - writes `role+0x44 = record[1]` (scale-percent source later consumed by `Role_SetMountedActionFrameIntervalAndRefreshActionScale`),
     - writes `role+0x4C = record[2]` (mount Y-offset source later mirrored to `role+0x314`),
     - if mounted (`Role_HasStatusFlag(role, 0x32) != 0`), immediately calls `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, record[0])`.
   - evidence: `0x6E5F5C..0x6E6020`.
2. `Role_QueryMountActionScaleRecord` (`0x6E6045`)
   - builds the lookup key from cached role sources at `+0x3C`, `+0x50`, `+0x54`, `+0x58`, `+0x370`,
   - dispatches `RoleDataQuery()->vfunc(+0xA8)` and returns the mounted action-scale record.
   - evidence: `0x6E604C..0x6E6082`.
3. `Role_SetMountedActionFrameIntervalAndRefreshActionScale` (`0x6E5E75`)
   - writes `role+0x128 = mountedActionFrameInterval`,
   - writes `role+0x314 = (mountedActionFrameInterval == 0) ? 0 : role+0x4C`,
   - writes `role+0x188 = (mountedActionFrameInterval == 0) ? 1.0f : role+0x44 * 0.01f`.
   - evidence: `0x6E5E9A`, `0x6E5F0B..0x6E5F16`, `0x6E5F1C..0x6E5F2F`.

Verified callers in currently traced native paths:

- `CMsgPlayerSpawn__Process` (`0x755F64`)
  - direct set from role-data record: `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, *(record+0x44))` at `0x7564B2`,
  - then refreshes mounted cache from packet fields via
    `Role_UpdateMountActionScaleCacheFromSources(role, packet+0x44, packet+0x85, packet+0x8B, packet+0x48)` at
    `0x756B1D`, where:
    - `packet+0x44` = `MountActionScalePrimarySourceId`
    - `packet+0x48` = `MountActionScalePreferredSourceId`
    - `packet+0x85` = `MountPlusLevel`
    - `packet+0x8B` = `MountColorIdentity`
- `Role_ApplyStatusFlagBitfieldAndDispatchEffects` (`0x6729B5`)
  - on gaining status flag `0x32`: queries `Role_QueryMountActionScaleRecord(role)` and, on hit, calls `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, record[0])`,
  - on losing status flag `0x32`: calls `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, 0)` before dispatching `"ride_down"`.
  - evidence: `0x672D64..0x672DC9`, `0x672DDB..0x672E32`.
- `Role_TryApplyIncomingActionInfo` (`0x64DD38`)
  - only the clear path is reachable from the currently mirrored incoming-block gate:
    `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, 0)` at `0x64DDB7`.

Current implementation boundary:

- The clear/reset side effect is fully pinned and safe to mirror now.
- Nonzero `role+0x128` writers are verified in native code, but their managed ingress sources are not all mirrored yet, so they remain intentionally unimplemented outside the documented clear path in this slice.

## Command-state action selector into `+0x1A4` (verified subset)

Selector entry:

- `Role_SelectActionFromCommandStateSwitch` (`0x64F154`) dispatches by command type `role+0x1E8` (`switch` jump table at `0x64F1B8`).
- call path in tick/update host:
  - `Role_ProcessCommandStateAndCombatPackets` calls selector at `0x65C540`,
  - `Role_UpdateActionAndDispatchRoleViewMotion` then consumes `role+0x1A4`.

Top-level gate:

- if `role+0x1EC == 6`, selector bypasses per-command handlers and calls virtual slot `+0x6C`.
- evidence: `0x64F157..0x64F16D`.

Verified mirrored command handlers in this slice:

1. command type `0x04`:
   - handler: `Role_CommandType04_SelectActionFromCommandPayload` (`0x7344B7`)
   - writes:
     - `role+0x1A4 = role+0x228`
     - `role+0x1EC = 2`
   - evidence: `0x7344D1`, `0x7344E3`.

2. command type `0x07`:
   - handler: `Role_CommandType07_SelectActionFromCommandPayloadAndComplete` (`0x7371C0`)
   - writes:
     - `role+0x1A4 = role+0x228`
     - `role+0x1EC = 6`
   - evidence: `0x73720B`, `0x737222`.

3. command type `0x06`:
   - handler: `Role_CommandType06_SelectActionFromCommandPayloadMap` (`0x73450B`)
   - primary source: payload action id at `role+0x228`
   - selected branch outputs include:
     - interaction-aware payload `0xFA`:
       - progress `0`: sets progress `2`; selects `0x1DD` for interaction type `100004`,
         `0x1D9` for `100007`, or `0xFA` otherwise
       - progress `2`: sets progress `3`; selects `0x1DE` for interaction type `100004`,
         `0x1DA` for `100007`, or `0xFA` otherwise
       - every other progress uses the ordinary fallback (`action=0x64`, progress `6`)
       - helper callbacks: `Role_SelectCommandType06PayloadFAFirstStageAction` (`0x64F0D5`)
         and `Role_SelectCommandType06PayloadFASecondStageAction` (`0x64F102`)
     - direct progress-2 actions for payloads:
       - `0x01..0x11`, `0x96`, `0xA0`, `0xAA`, `0xBE`, `0xC8`, `0xD2`, `0x1DE`
     - staged pairs using current progress-state (`role+0x1EC`):
       - `0x10E -> 0x10F`, `0x1D9 -> 0x1DA`, `0x0E6 -> 0x0E7`
     - complete-state direct actions (`role+0x1EC = 6`) for payloads:
       - `0x387`, `0x391`, `0x393..0x395`
     - fallback/default:
       - `role+0x1EC = 6`, `role+0x1A4 = 0x64`
   - evidence:
     - default complete/fallback: `0x7346E9..0x7346F3`
     - payload write-through complete branch: `0x7346FF..0x734709`
     - staged transitions:
       - `0x10E/0x10F`: `0x734699..0x7346B2`
       - `0x1D9/0x1DA`: `0x734656..0x73467A`
       - `0x0E6/0x0E7`: `0x7345A3..0x7345C7`.

4. command type `0x02` movement path:
   - handler: `Role_CommandType02_UpdateMotionPathAndSelectAction` (`0x7379A2`)
   - mirrored action-write subset:
     - when `role+0x1EC == 2` and `MotionPath_GetNodeCount(role+0x1BC) > 0`:
       - action write follows `Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`):
         - `role+0x1A4 = 0x6F` when `role+0x398` is `0x6E` or `0x78`
         - otherwise `role+0x1A4 = 0x6E`
     - when `role+0x1EC == 2` and node count is depleted (`<= 0`):
       - native calls command-type-5 selector, then forces `role+0x1EC = 3`.
       - managed mirror calls command-type-5 selector when `RoleCommandType05SelectionContext`
         is fully populated, then applies the verified `+0x1EC = 3` transition.
   - evidence:
     - progress `2` gate and node-count branch: `0x737B99..0x737BC7`
     - depleted branch: `0x737BC9..0x737BDE`
     - helper action write: `0x73632B..0x736333`.

5. command type `0x03` movement path selector:
   - handler: `Role_CommandType03_UpdateMotionPathAndSelectAction` (`0x7350B3`)
   - mirrored pre-stage branch table (before action-write branch):
     - target-entity acquisition:
       - resolves by command target id (`role+0x204`) via
         `EntityRef_ResolveByIdOrLocalHero` (`0x6E847D`).
       - lookup miss with non-local command target id:
         - sets `role+0x1EC = 6`
         - dispatches command-type-5 selector path
       - lookup miss with local command target id (`g_objHero.GetID() == role+0x204`):
         - uses local hero reference fallback and continues into staged target / path-build branch.
     - staged target world-cell validation:
       - if either staged coordinate fails `Map_CoordinateGateCheckValue` (`0x713315`), forces `role+0x1EC = 0`
     - progress-0 path-build branch:
       - path-build mode argument is computed from local-role autorun gate:
         - `0` when `g_objHero.GetID() == role+0xCC` and `Role_GetAutoRunActiveState(g_objHero) != 0`
         - `1` otherwise.
       - when rebuilt path node count `> 0`: sets `role+0x1EC = 2` and continues into same-tick action-selection branch
       - when rebuilt path node count `<= 0`: dispatches command-type-5 selector, then forces `role+0x1EC = 3`
     - temporary staged command-target tile writes:
       - `role+0x208/+0x20C` are staged during pre-branch math and restored before return.
   - mirrored boosted branch gate:
     - enters boosted flow when both are true:
       - `Role_HasStatusFlag(role, 0x32) != 0`
       - `Role_GetField2DA8StatusValue(role) > 1`
     - boosted branch outcomes:
       - first probe (`Map_AreProbeEndpointsHeightDeltaLe25`) fails:
         - local-active path:
           - `role+0x1EC = 0`
           - dispatches `Role_CommandType13_UpdateMotionPathAndSelectAction(role)`.
           - verified entry semantics at this callsite:
             - command-type-13 entry checks:
               - when status flag `0x32` is clear: writes `role+0x1E8 = 0x12`, `role+0x1EC = 0`, dispatches command-type-12 handler.
               - when status flag `0x32` is set and `Role_GetField2DA8StatusValue(role) <= 1`: writes `role+0x1E8 = 0x11`, `role+0x1EC = 0`, dispatches command-type-11 handler.
               - otherwise requires command type `0x13` at CHECKF gate before entering command-type-13 body.
             - from this command-type-3 boosted callsite, preconditions enforce status flag set and field `+0x2DA8 > 1`, while command type remains `0x03`; this hits the CHECKF path and returns without a direct action write.
         - non-local path:
           - `role+0x1EC = 6`
           - falls through command-type-5 selector path
       - first probe passes and `MotionPath_GetNodeCount(role+0x1BC) <= 0`:
         - toggle progress `2 <-> 3`
         - write ground action pair (`0x6E/0x6F`)
       - first probe passes and node count `> 0`, then second probe:
         - fail:
           - toggle progress `2 <-> 3`
           - write ground action pair (`0x6E/0x6F`)
         - pass:
           - toggle progress `2 <-> 3`
           - write boosted stride pair (`0x7A/0x7B`)
   - mirrored non-boosted simple stride subset:
     - with `role+0x1EC` in `{2,3}` and `MotionPath_GetNodeCount(role+0x1BC) > 1`:
       - toggle progress:
         - `2 -> 3`
         - `3 -> 2`
       - write stride action:
         - `role+0x1A4 = 0x79` when `role+0x398 == 0x78`
         - otherwise `role+0x1A4 = 0x78`
     - with `MotionPath_GetNodeCount(role+0x1BC) <= 1`:
       - native calls command-type-5 selector and forces `role+0x1EC = 3`.
       - managed mirror calls command-type-5 selector when `RoleCommandType05SelectionContext`
         is fully populated, then applies the verified `+0x1EC = 3` transition.
   - evidence:
     - target lookup by `role+0x204`: `0x73510B..0x73512F`
     - lookup miss + non-local fallback to command-type-5: `0x735135..0x7352AA`
     - lookup miss + local-hero fallback branch: `0x73514C..0x7351C4`
     - unresolved-target non-local fallback: `0x735299..0x7352AA`
     - staged world-cell validation force-zero: `0x73523E..0x73525C`
     - path-build mode gate from local-role autorun state: `0x735270..0x7352B5`
     - progress-0 path-build branch: `0x735263..0x7352FF`
     - progress-0 depleted branch to command-type-5 and force-3: `0x735301..0x73530F`
     - progress-0 success continue into action branch: `0x7352F6..0x735348`
     - staged coordinate restore before return: `0x735319..0x735334`, `0x7356C1..0x7356DF`
     - boosted gate and status checks: `0x73536E..0x735393`
     - first-probe setup/call: `0x735399..0x7353E7`
     - first-probe fail local-active: `0x73560B..0x735614`
     - command-type-13 entry dispatch and CHECKF gate: `0x736B42..0x736BB9`
     - first-probe fail non-local -> command-type-5 path: `0x73561E..0x735635`
     - first-probe pass with depleted path: `0x73559A..0x7355CE`
     - second probe call (path count > 0): `0x73544D`
     - second-probe fail: `0x73555A..0x73558B`
     - second-probe pass: `0x73552A..0x73554B`
     - simple branch entry: `0x73563C`
     - node-count `> 1` branch/toggle/write: `0x735663..0x735697`
     - depleted branch to command-type-5: `0x7356A3..0x7356AA`.

6. command type `0x03` use of `role+0x224` (command data):
   - direction index source:
     - `Role_SelectDirectionIndexTowardTargetEntity` (`0x6E4B04`) calls
       `Role_SelectDirectionIndexTowardTile` (`0x6E4ACC`) when target is resolved.
     - `Role_SelectDirectionIndexTowardTile` computes `deltaX/deltaY` and quantizes to 8-way direction (`(dir + 7) % 8`), using slope thresholds in `Direction_Select8WayFromDelta` (`0x61E478`).
   - staged offset tables:
     - `data_86C608` (`int32[8]`) = `[0, -1, -1, -1, 0, 1, 1, 1]`
     - `data_86C628` (`int32[8]`) = `[1, 1, 0, -1, -1, -1, 0, 1]`
   - target-position staging multiplies direction table coefficients by `role+0x224` before path build:
     - `role+0x208 = data_86C608[dirIndex] * (role+0x224) + baseX`
     - `role+0x20C = data_86C628[dirIndex] * (role+0x224) + baseY`
   - if either staged coordinate fails `Map_CoordinateGateCheckValue` (`0x713315`), handler forces `role+0x1EC = 0` and rebuilds path.
   - evidence: `0x6E4ACC..0x6E4B01`, `0x73520C..0x73525C`, `0x86C608`, `0x86C628`.

7. command type `0x11` movement path selector:
   - handler: `Role_CommandType11_UpdateMotionPathAndSelectAction` (`0x7363A9`)
   - mirrored subset:
     - progress-0 path-prep:
       - clear/rebuild path via `MotionPath_ClearNodes` + `MapPathService_TryBuildPath`;
       - when rebuilt node count `> 0`: sets `role+0x1EC = 2` and continues into same-tick active branch;
       - when rebuilt node count `<= 0`: clears path, forces `role+0x1EC = 6`, dispatches command-type-5 selector.
     - active branch (`role+0x1EC == 2`):
       - with `MotionPath_GetNodeCount(role+0x1BC) <= 0`: dispatches command-type-5 selector, then forces `role+0x1EC = 6`;
       - with node count `> 0` and probe gate pass:
         - calls `Role_ApplyGroundMoveActionAndPoseFromPathCursor`;
         - action result follows ground helper pair (`0x6E/0x6F`);
         - progress remains `2`.
       - with probe gate fail:
         - dispatches command-type-5 selector, then forces `role+0x1EC = 6`.
   - verified side-effect note:
     - this handler does **not** execute the local-player autorun stop/event block;
       fallback paths go directly to command-type-5.
   - evidence:
     - progress-0 path-prep and success set-2: `0x7363C5..0x73646E`
     - progress-0 failure path to command-type-5: `0x736468..0x73658A`
     - active `role+0x1EC == 2` gate: `0x736481`
     - active depleted path branch: `0x736494..0x7365B4`
     - active probe-gated success (`Role_ApplyGroundMoveActionAndPoseFromPathCursor`): `0x73659F..0x7365A6`
     - active probe-gated fail to command-type-5: `0x7365A4..0x7365B4`.

8. command type `0x12` movement path selector:
   - handler: `Role_CommandType12_UpdateMotionPathAndSelectAction` (`0x7365F3`)
   - mirrored subset:
     - progress-0 path-prep:
       - clear/rebuild path via `MotionPath_ClearNodes` + `MapPathService_TryBuildPath`;
       - when rebuilt node count `> 0`: sets `role+0x1EC = 2` and continues into same-tick active branch;
       - when rebuilt node count `<= 0`: clears path, forces `role+0x1EC = 6`, dispatches command-type-5 selector.
     - active branch (`role+0x1EC in {2,3}`):
       - with `MotionPath_GetNodeCount(role+0x1BC) <= 0`:
         - clears path, forces `role+0x1EC = 6`, dispatches command-type-5 selector.
       - with node count `> 0` and probe gate pass:
         - calls `Role_ApplyGroundMoveActionAndPoseFromPathCursor`;
         - toggles `role+0x1EC` (`2 -> 3`, `3 -> 2`);
         - writes stride pair:
           - when prior progress is `2`: `role+0x1A4 = 0x78`
           - when prior progress is `3`: `role+0x1A4 = 0x79`.
       - with probe gate fail:
         - local-active path: sets `role+0x1EC = 0`, then recursively re-enters command-type-12 handler in the same tick;
         - non-local path: clears path, forces `role+0x1EC = 6`, dispatches command-type-5 selector.
   - verified local-player autorun fallback side-effects (executed only in fallback-to-type-5 blocks):
     - helper/function map (renamed in BNinja):
       - `Role_GetAutoRunActiveState` (`0x6626DD`) reads `localRole+0x2E14`.
       - `Role_SetAutoRunActiveState` (`0x662740`) writes `localRole+0x2E14`.
       - `Role_IsWithinAutoRunAnchorWindow` (`0x6626E4`) checks tile window against `localRole+0x2E18/+0x2E1C` with clamped radius from `+0x2E10`.
       - `Role_GetAutoRunAnchorTile` (`0x662761`) copies `localRole+0x2E18/+0x2E1C`.
       - `Role_GetAutoRunUiLockState` (`0x667430`) reads `localRole+0x2FA8`.
       - `Role_SetAutoRunUiLockState` (`0x667423`) writes `localRole+0x2FA8`.
       - `Role_SetAutoRunStateByteAndResetTextOnZero` (`0x6669CC`) writes `localRole+0x2E15` and resets default text at `+0x2E20` when zero.
       - `Role_DispatchNamedUiEvent` (`0x651205`) dispatches named event through callback slots `+0x430/+0x434`.
       - `Conquer_PostMainWindowMessage464` (`0x64D015`) posts `PostMessageA(mainWnd, 0x464, wParam, lParam)`.
       - `Role_StopAutoRunAndDispatchStopEvents` (`0x66279B`) performs stop/reset dispatch including `"autorun"` and `wParam=0x47C`.
       - `GameMsg_DispatchByCode` (`0x5D231F`) dispatches system message packet by queue/code.
     - entry gates:
       - execute local autorun block only when `localRole+0xCC == role+0xCC` and `Role_GetAutoRunActiveState(localRole) != 0`.
     - fallback side-effect order:
       1. `Role_StopAutoRunAndDispatchStopEvents(localRole)`:
          - `Role_SetAutoRunActiveState(localRole, 0)`,
          - `Role_DispatchNamedUiEvent(localRole, "autorun")`,
          - `Conquer_PostMainWindowMessage464(0x47C, 0)`.
       2. evaluate window/lock gates:
          - if `Role_IsWithinAutoRunAnchorWindow(localRole, currentTile)` and `Role_GetAutoRunUiLockState(localRole) == 0`:
            - optional callback `localRole+0x430` dispatch: `("autorun_end", 1)`,
            - `Conquer_PostMainWindowMessage464(0x478, 0)`,
            - no `GameMsg_DispatchByCode`.
          - if `Role_IsWithinAutoRunAnchorWindow(localRole, currentTile)` and `Role_GetAutoRunUiLockState(localRole) != 0`:
            - `Conquer_PostMainWindowMessage464(0x478, 0)`,
            - no callback and no `GameMsg_DispatchByCode`.
          - if outside window and lock is clear (`== 0`):
            - `GameMsg_DispatchByCode(CGameMsg_GetSingletonPtr(), GameDataSetQuery()->vfunc(0x2B78), 0x7D5, 0xFFFF0000, 0, 0)`.
          - if outside window and lock is set (`!= 0`):
            - no additional autorun-end message dispatches.
   - managed mirror notes:
     - local-active recursion is mirrored with explicit two-phase probe context
       (`IsProbeHeightDeltaWithin25`, `IsProbeHeightDeltaWithin25AfterLocalRetry`)
       to keep branch behavior evidence-driven and deterministic.
     - fallback side-effects are mirrored through `RoleCommandType12AutoRunSideEffectRuntime`
       + `IRoleCommandType12AutoRunSideEffectSinkRuntime` with explicit gate context.
   - evidence:
     - progress-0 path-prep and success set-2: `0x73660F..0x7366B8`
     - progress-0 failure path to command-type-5 + local autorun side-effects: `0x7367CE..0x7368DB`
     - active `role+0x1EC in {2,3}` gate: `0x7366C4..0x7366D2`
     - active depleted path branch + local autorun side-effects: `0x73698C..0x736AAA`
     - active probe pass toggle/write (`0x78/0x79`): `0x73694C..0x73697D`
     - active probe fail local recursion: `0x736902..0x736928`
     - active probe fail non-local fallback + local autorun side-effects: `0x736932..0x736AAA`.

9. command type `0x05` fallback selector:
   - handler: `Role_CommandType05_SelectActionAndMarkComplete` (`0x7334FE`)
   - branch order:
     1. if `role+0x2C == 7`:
        - `role+0x1E8 = 7`
        - `role+0x228 = role+0x30`
        - dispatches type-7 helper (`Role_CommandType07_SelectActionFromCommandPayloadAndComplete`).
     2. otherwise:
        - sets `role+0x1EC = 6`
        - initializes `role+0x1A4 = 0x64`
        - optional idle-random variant branch when current command type is `5` and
          `Conquer_GetRandomModulo(0xA, 0) == 1`:
          - `Conquer_GetRandomModulo(3, 0) == 0` -> `0x65`
          - `== 1` -> `0x66`
          - else -> `0x67`
        - override branch by `role+0x30C` and `Role_IsSpecialIdleActionWindowActive(role)`:
          - if `role+0x30C != 0`:
            - `0x1F5`, upgraded to `0x1F6` when window check is true
          - else:
            - `0x12C` when window check is true
            - otherwise retains `0x64/0x65/0x66/0x67` result from prior branch
        - mirrors position pair:
          - `role+0x19C/+0x1A0 = role+0x350/+0x354`
          - `role+0x194/+0x198 = role+0x350/+0x354`
          - rendering consequence: the subsequent multi-frame idle RoleView dispatch has
            stationary endpoints at the live cursor and cannot interpolate back across a stale
            walk or jump segment.
       - these selected action ids are the idle ids later fed into the already-verified
         RoleView body-motion dispatch chain:
         - `0x64` = decimal `100`
         - `0x65` = decimal `101`
         - `0x66` = decimal `102`
         - `0x67` = decimal `103`
       - after command-type-5 selects one of those ids, `Role_TickAndRender` still follows the
         normal render-time ordering:
         - `Role_UpdateActionAndDispatchRoleViewMotion`
         - RoleView slot `+0x0C` with the current action id
         - RoleView slot `+0x04` with property key `0x0A` and the sampled primary frame
       - body-motion lookup for that startup idle path therefore stays downstream of the same
         verified `RoleView_BuildBodyMotionLookupKey` / fallback body key chain documented above;
         command type `0x05` only chooses the action id and mirrors the projected-screen caches.
       - direct-render consequence:
         - these startup idle ids do **not** enter the `Role_TickAndRender` mounted motion-arc
           branch (`0x82`, `0x127`, `0x20F`)
         - they also do **not** enter the rotation-only override sets:
           - `Role_IsCurrentActionInProjectedPathFacingOverrideSet`
           - `Role_IsCurrentActionInTargetEntityFacingOverrideSet`
         - for the verified startup-local-hero slice, the direct-render transform therefore
           remains the zero-elevation baseline until a different upstream projected-screen /
           placement producer is proven
   - evidence:
     - type-7 redirect branch: `0x733507`, `0x7335DF..0x7335F0`
     - default `0x64` + progress complete: `0x733514..0x73351E`
     - random variant gate: `0x73352A..0x733565`
     - `+0x30C`/window overrides: `0x73356F..0x7335A4`
     - position mirrors: `0x7335BA..0x7335D6`.

9a. command type `0x25` (decimal `37`) scapegoat action selector:
   - handler: `Role_CommandType37_SelectScapegoatActionSequence` (`0x733DAC`)
   - verified branch table:
     - progress `0`:
       - clears scapegoat offset-Y gate flag (`role+0x394 = 0`)
       - clears MotionPath nodes
       - mirrors current projected screen point (`role+0x350/+0x354`) into both
         projected-point caches (`role+0x194/+0x198`, `role+0x19C/+0x1A0`)
       - sets skip-render flag (`role+0x3A0 = 1`)
       - writes action `0x38D`
       - advances to progress `2`
     - progress `2`:
       - clears skip-render flag and keeps scapegoat offset-Y gate flag clear
       - writes action `0x38E`
       - projects staged tile (`role+0x208/+0x20C`) to screen and mirrors the result into:
         - `role+0x194/+0x198`
         - `role+0x19C/+0x1A0`
         - `role+0x350/+0x354`
       - copies staged direction `role+0x210` to `role+0x17C`
       - advances to progress `3`
     - progress `3`:
       - while action is still active: keeps skip-render clear and returns `0`
       - when action completes:
         - sets skip-render flag (`role+0x3A0 = 1`)
         - sets scapegoat offset-Y gate flag (`role+0x394 = 1`)
         - returns `1`
     - terminal fallback branch:
       - clears skip-render flag
       - writes action `0x191`
       - sets progress `6`
   - verified writer tie-ins used by `Role_TickAndRender`:
     - action `0x38E` consumes scapegoat offset Y (`role+0x39C`) only while
       `role+0x394 == 0`
     - `role+0x39C` is written by `CRole__SetScapegoatOffsetY` (`0x651266`)
       from `CScapegoatRole__RefreshTrackedRoleProjectionAndOffsetY` (`0x7333C3`)
     - the scapegoat offset-Y source is `ini/Info.ini` `[Scapegoat].OffsetY`
       through global `data_96B3A0`
   - evidence:
     - progress-0 init branch: `0x733DB1..0x733E19`
     - progress-2 branch: `0x733E20..0x733E99`
     - progress-3 / terminal branch: `0x733E9D..0x733ECE`
     - scapegoat offset-Y writer: `0x733412`

10. command type `0x13` ride movement selector:
   - handler: `Role_CommandType13_UpdateMotionPathAndSelectAction` (`0x736B14`)
   - verified full branch table:
     - local-role entry redirects before ride body:
       - when `role+0xCC == localRole+0xCC` and `Role_HasStatusFlag(localRole, 0x32) == 0`:
         - writes `role+0x1EC = 0`, `role+0x1E8 = 0x12`,
         - immediately dispatches `Role_CommandType12_UpdateMotionPathAndSelectAction`.
       - when `role+0xCC == localRole+0xCC`, status `0x32` is set, and
         `Role_GetField2DA8StatusValue(localRole) <= 1`:
         - writes `role+0x1EC = 0`, `role+0x1E8 = 0x11`,
         - immediately dispatches `Role_CommandType11_UpdateMotionPathAndSelectAction`.
     - CHECKF gate for ride body:
       - requires `role+0x1E8 == 0x13`; mismatch returns `0`.
     - progress-0 path-build stage:
       - clears `MotionPath` at `role+0x1BC`,
       - builds path through `MapPathService_TryBuildPath` with fallback target from
         `MapPathService_GetFallbackTargetTile`,
       - when rebuilt node count `<= 0`: clears path, sets `role+0x1EC = 6`, then dispatches command-type-5 fallback path,
         - local autorun-active branch mirrors command-type-12 fallback side-effect order:
           - stop/autorun dispatch (`"autorun"`, `PostMessageA(...,0x47C,0)`),
           - anchor-window/ui-lock branch:
             - in anchor: optional `"autorun_end"` callback (`arg=1`) then `PostMessageA(...,0x478,0)`,
             - out of anchor and ui-lock clear: `GameMsg_DispatchByCode(..., 0x2B78, 0x7D5, 0xFFFF0000, 0, 0)`,
             - ui-lock set: no extra message dispatch.
       - when rebuilt node count `> 0`: sets `role+0x1EC = 2`.
     - active stage (`role+0x1EC in {2,3}`):
       - if node count `<= 0`: clears path, sets `role+0x1EC = 6`, dispatches command-type-5 fallback path.
         - local autorun-active branch dispatches:
           - `Role_StopAutoRunAndDispatchStopEvents(localRole)` (includes `"autorun"` + `0x47C` post),
           - explicit `Role_SetAutoRunActiveState(localRole, 0)`,
           - `Role_DispatchNamedUiEvent(localRole, "autorun")`,
           - `PostMessageA(..., 0x478, 0)`.
       - otherwise reads first direction index via `MotionPath_ReadAndAdvanceDirectionIndex`, writes `role+0x17C = dir1 % 8`, and runs first probe (`Map_AreProbeEndpointsHeightDeltaLe25`).
       - first-probe fail:
         - local-active: writes `role+0x1EC = 0` and re-enters command-type-13 handler in the same tick.
         - non-local: clears path, writes `role+0x1EC = 6`, dispatches command-type-5 fallback.
       - first-probe pass:
         - if remaining node count `<= 0`:
           - applies ground move helper (`Role_ApplyGroundMoveActionAndPoseFromPathCursor`),
           - toggles progress `2 <-> 3`,
           - writes ground pair from pose action `role+0x398`:
             - `role+0x1A4 = 0x6F` when pose is `0x6E` or `0x78`,
             - otherwise `role+0x1A4 = 0x6E`,
           - clears path.
         - if remaining node count `> 0`:
           - reads second direction index (`dir2 % 8`), runs second probe.
           - second-probe fail:
             - toggles progress `2 <-> 3`,
             - writes ground pair (`0x6E/0x6F`) by same pose-action rule.
           - second-probe pass:
             - steering delta uses `delta = (dir2 - dir1 + 8) % 8`:
               - `delta == 1`: `role+0x17C = dir1 + 8`
               - `delta == 2 || delta == 6`: average steering; when `abs(avg-dir1) >= 3`, applies `(+4) % 8`
               - `delta == 7`: `role+0x17C = dir2 + 16`
               - otherwise keeps `role+0x17C = dir1`
             - updates staged tile/screen coordinates through direction tables (`data_86C648` / `data_86C6A8`) and `Map_ProjectTileToScreenCoordinates`,
             - toggles progress `2 <-> 3`,
             - writes boosted ride pair from pose action `role+0x398`:
               - `role+0x1A4 = 0x7B` when pose is `0x7A`,
               - otherwise `role+0x1A4 = 0x7A`.
   - function return:
     - returns `1` only when final `role+0x1EC == 6`, else `0`.
   - evidence:
     - local-role redirect gates: `0x736B32..0x736B85`
     - CHECKF gate and return: `0x736B8F..0x736BB9`
     - progress-0 path build + fallback target + set-2: `0x736BCE..0x736C71`
     - progress-0 depleted fallback to command-type-5: `0x736D94..0x736E6E`
     - active-range gate (`2..3`): `0x736C7D..0x736C8F`
     - active depleted fallback to command-type-5: `0x737022..0x73708D`
     - first direction read and first probe: `0x736CB7..0x736CFB`
     - first-probe fail local recurse: `0x736FFD..0x737005`
     - first-probe fail non-local fallback: `0x73700F..0x73708D`
     - first-probe pass with depleted remaining path (`0x6E/0x6F`): `0x736D01..0x736FCE`
     - second probe fail (`0x6E/0x6F`): `0x736D47..0x736F7B`
     - second probe pass steering + (`0x7A/0x7B`): `0x736D5B..0x736F43`
     - return-value write (`progress == 6`): `0x737092..0x73709B`.
   - helper names resolved in BNinja for this path:
     - `CHero_GetSingletonPtr` (`0x404460`)
     - `CHero_PerFrameTickAndSubsystemUpdate` (`0x65E070`)
     - `CGameMap_GetSingletonPtr` (`0x410685`)
     - `CGameMsg_GetSingletonPtr` (`0x4043BC`)
     - `Role_TickCommandStateAndDispatchPlayback` (`0x6725ED`)
     - `Role_TryApplyDueQueuedActionEntries` (`0x6724C6`)
     - `Role_HandleIncomingActionStateBatch` (`0x6720EE`)
     - `Role_ResetCommandStateToType05AndRefreshPositionCaches` (`0x67544A`)
     - `MapPathService_TryBuildPath` (`0x6208E2`)
     - `MapPathService_BuildPathNodesAndUpdateNearestTile` (`0x634279`)
     - `MotionPath_ClearNodes` (`0x6406A3`)
     - `MotionPathNodeDeque_ClearAndResetCursors` (`0x6228A0`)
     - `MotionPath_GetNodeCount` (`0x6406BB`)
     - `MotionPathNodeDeque_ComputeNodeCountFromCursorSpan` (`0x6406C3`)
     - `Map_AreProbeEndpointsHeightDeltaLe25` (`0x61EB65`)
     - `XteaProtectedInt_Get` (`0x713482`)
     - `XteaProtectedInt_GetPlusOffset` (`0x7132FD`)
     - `XteaProtectedInt_GetMinusOffset` (`0x713309`)
     - `Role_SetTilePositionAndProjectScreenCoordinates` (`0x6E4C79`)
     - `Role_SetFieldA88A8CFromActionParamPair` (`0x741C09`)
     - `Role_RequestCommandType12MoveToTile` (`0x657CD6`)
     - `Role_QueueCommandType13MoveToTile` (`0x65833B`)
     - `CHero_QueueCommandType07Action278WhenFollowWindowExpires` (`0x664505`)
     - `MsgRoleBatch_DispatchCommandType14FromDirectionAndTile` (`0x762844`)
     - `MsgRoleBatch_DispatchCommandType16Or17FromDirection` (`0x762619`)
   - second-probe-pass state write detail (`0x736EB4..0x736F15`):
     - persistent position mirrors:
       - `role+0x194 = role+0x350`
       - `role+0x198 = role+0x354`
     - staged coordinate updates use steered direction index `d = role+0x17C`:
       - `tileX = XteaProtectedInt_GetPlusOffset(role+0x318, data_86C648[d])`
       - `tileY = XteaProtectedInt_GetPlusOffset(role+0x334, data_86C6A8[d])`
     - screen projection write:
       - `Map_ProjectTileToScreenCoordinates(CGameMap_GetSingletonPtr(), tileX, tileY, &role+0x19C, &role+0x1A0)`
     - `Map_ProjectTileToScreenCoordinates` equation (`0x61D850..0x61D885`):
       - `role+0x19C = (((tileX - tileY) << 6) / 2) + map+0x40`
       - `role+0x1A0 = (((tileX + tileY) << 5) / 2) + map+0x44`
     - steered-direction offset tables (24 entries each, index range `0..23`):
       - `data_86C648` (`0x86C648`):
         - `[0, -2, -2, -2, 0, 2, 2, 2, -1, -2, -2, -1, 1, 2, 2, 1, -1, -2, -2, -1, 1, 2, 2, 1]`
       - `data_86C6A8` (`0x86C6A8`):
         - `[2, 2, 0, -2, -2, -2, 0, 2, 2, 1, -1, -2, -2, -1, 1, 2, 2, 1, -1, -2, -2, -1, 1, 2]`
     - table/read evidence:
       - table reads in command-type-13: `0x736ED8`, `0x736EF2`
       - table dump ranges: `0x86C648..0x86C6A7`, `0x86C6A8..0x86C707`.

### Caller-chain verification for per-tick snapshot source (2026-03-05)

- verified dispatch chain that feeds command-type action selection:
  - `Role_ProcessCommandStateAndCombatPackets` (`0x65C0F5`):
    - call site `0x65C540`: `Role_SelectActionFromCommandStateSwitch(role)`
  - `Role_SelectActionFromCommandStateSwitch` (`0x64F154`):
    - command-type-13 dispatch call `0x64F1D9`: `Role_CommandType13_UpdateMotionPathAndSelectAction(role)`
- verified command-state reads in selector entry:
  - `role+0x1EC` progress read: `0x64F157`
  - `role+0x1E8` command-type read: `0x64F177`, switch dispatch root `0x64F1A7`
- verified producer stage that populates selector input block (`role+0x1E8..+0x303`):
  - `Role_TryApplyIncomingActionInfoWithConditionalStateSync` (`0x65C079`)
    - conditional pre-apply state sync calls:
      - `Role_RecomputeCoordinateGateCacheFromProjectedPosition(role)` at `0x65C096`, `0x65C0D7`, `0x65C0E3`
    - incoming action-info apply call:
      - `Role_TryApplyIncomingActionInfo(role, incoming)` at `0x65C0EB`
  - `Role_TryApplyIncomingActionInfo` (`0x64DD38`)
    - accepted path copies exactly `0x11C` bytes into `role+0x1E8`:
      - `memcpy(role+0x1E8, incoming, 0x11C)` at `0x64DDBC..0x64DDC9`
  - per-tick selector consumption then occurs in:
    - `Role_ProcessCommandStateAndCombatPackets` call site `0x65C540`
    - `Role_SelectActionFromCommandStateSwitch` entry reads at `0x64F157` / `0x64F177`
- verified command-type-13 producer reads for path-count/probe branch inputs:
  - path-count reads (`MotionPath_GetNodeCount`):
    - progress-0 build path result: `0x736C6B`
    - active first-probe gate: `0x736CB1`
    - active second-probe gate: `0x736D0A`
  - probe outcome reads (`Map_AreProbeEndpointsHeightDeltaLe25`):
    - first probe: call `0x736CFB` (staged endpoints at `0x736CD9..0x736CEA`)
    - second probe: call `0x736D55` (staged endpoints at `0x736D2F..0x736D46`)
  - write sites feeding those producer reads:
    - path build write path:
      - `MapPathService_TryBuildPath` call at `0x736C46`
      - backend writer call `0x6208F9`: `MapPathService_BuildPathNodesAndUpdateNearestTile`
    - path clear/reset write path:
      - `MotionPath_ClearNodes` at `0x736BD4`, `0x736D96`, `0x736FD0`, `0x737011`, `0x737022`
      - clear/reset backend `MotionPathNodeDeque_ClearAndResetCursors` (`0x6228A0`)
    - node-count backend:
      - `MotionPath_GetNodeCount` tailcall backend `MotionPathNodeDeque_ComputeNodeCountFromCursorSpan` (`0x6406C3`)
- verified command-type-13 inputs used for second-probe-pass write block:
  - first direction read: `MotionPath_ReadAndAdvanceDirectionIndex` at `0x736CB7`
  - second direction read: `MotionPath_ReadAndAdvanceDirectionIndex` at `0x736D18`
  - coordinate-gate roots:
    - `lea ecx,[role+0x318]` at `0x736EBA`
    - `lea ecx,[role+0x334]` at `0x736EEC`
  - table offset reads:
    - `push [role+0x17C*4 + data_86C648]` at `0x736ED8`
    - `push [role+0x17C*4 + data_86C6A8]` at `0x736EF2`
  - screen projection call:
    - `Map_ProjectTileToScreenCoordinates(CGameMap_GetSingletonPtr(), tileX, tileY, &role+0x19C, &role+0x1A0)` at `0x736F0E..0x736F15`
  - map projection offsets consumed by callee:
    - `map+0x40` and `map+0x44` in `Map_ProjectTileToScreenCoordinates` (`0x61D86A`, `0x61D87B`)

### Per-tick caller path that feeds selector snapshot input (2026-03-05)

- verified role tick caller sequence:
  - `Role_TickCommandStateAndDispatchPlayback` (`0x6725ED`)
    - applies oldest queued incoming `0x11C` action-info block:
      - copy oldest queued block: `0x672682..0x67268D`
      - apply gate call: `Role_TryApplyIncomingActionInfo(role, copiedBlock)` at `0x67268D`
      - pop oldest queue entry regardless of accept/reject:
        - front-pointer advance: `0x6726AE..0x6726B3`
        - wrap/pop helper: `0x6726B7`
    - dispatches per-tick command-state processing via vtable slot `+0x84`:
      - indirect call: `0x6726D8`
      - role vptr write in ctor path: `*role = data_86AD08` at `0x655730`
      - table entry at `data_86AD08 + 0x84 = 0x86AD8C` contains `0x65C0F5` (`Role_ProcessCommandStateAndCombatPackets`)
    - then dispatches roleview playback update:
      - direct call `Role_UpdateActionAndDispatchRoleViewMotion(role)` at `0x6726E0`
- verified split from the immediate ingress vtable path:
  - `Role_TickCommandStateAndDispatchPlayback` does **not** call role vtable `+0x80`
    / `Role_TryApplyIncomingActionInfoWithConditionalStateSync`
  - the oldest-queued-entry branch at `0x67268D` calls `Role_TryApplyIncomingActionInfo` directly
  - therefore the conditional projected-position commit at `0x65C096` / `0x65C0D7` / `0x65C0E3`
    belongs to immediate ingress callers, not to the `0x6725ED` oldest-queued-entry branch
- verified companion ingress paths that also feed `Role_TryApplyIncomingActionInfo`:
  - `Role_HandleIncomingActionStateBatch` (`0x6720EE`)
  - `Role_TryApplyDueQueuedActionEntries` (`0x6724C6`)
  - `Role_ResetCommandStateToType05AndRefreshPositionCaches` (`0x67544A`)
  - `CHero_PerFrameTickAndSubsystemUpdate` (`0x65E070`) caller of `Role_TickCommandStateAndDispatchPlayback` at `0x65E097`.

### MsgAction/role ingress command-block writers (2026-03-05)

- verified vtable slot mapping for role ingress apply call:
  - role vtable entry `+0x80` (`data_86AD08 + 0x80 = 0x86AD88`) points to
    `Role_TryApplyIncomingActionInfoWithConditionalStateSync` (`0x65C079`).
  - evidence:
    - role vptr write: `0x655730`
    - vtable bytes at `0x86AD88`: `79 C0 65 00` (`0x65C079`)
    - `Role_TryApplyIncomingActionInfoWithConditionalStateSync` tail call:
      `Role_TryApplyIncomingActionInfo(role, incoming)` at `0x65C0EB`.
  - verified conditional pre-apply commit gates in `0x65C079`:
    - gate A: current command type with complete fallback in `{0x04..0x0B, 0x0E}` via
      `Role_IsCommandType04To0BOr0EWithCompleteFallback` (`0x6E4F55`)
      -> commit staged projected position before apply at `0x65C096`
    - gate B: current raw command type in `{0x1A, 0x1B, 0x1C}` and incoming type in
      `{0x11, 0x12, 0x13, 0x14, 0x15, 0x2B, 0x2E}`
      -> commit staged projected position before apply at `0x65C0D7`
    - gate C: incoming type `0x2F`
      -> commit staged projected position before apply at `0x65C0E3`
  - `Role_IsCommandType04To0BOr0EWithCompleteFallback` (`0x6E4F55`) body is only:
    - `state = Role_GetStateCode1E8WithCompleteFallback(role)`
    - return `1` when `state >= 4 && (state <= 0x0B || state == 0x0E)`

Managed parity note for this caller seam:

- native live movement-center commits depend on continued world-frame packet ingress after startup:
  - immediate ingress path: packet decode -> role vtable `+0x80` -> `0x65C079`
  - per-tick role tick path: `0x6725ED`
- the managed non-playback scene previously dropped the startup ingress context after bootstrap and replaced it
  with a no-op world-frame network stage plus a dead command-state snapshot source
- current managed composition now keeps the real startup ingress context alive for non-playback runtime frames;
  this restores the verified native prerequisite that world-frame packet ingress continues after `0x483`.
- the per-role queued ingress path now passes the live map projection into its state apply and reproduces all three
  verified `0x65C079` staged-position commit gates before copying the incoming block.
- locally synthesized immediate command-state callers still use the direct apply entry point; each must be classified
  against the native caller path before claiming the complete `0x65C079` surface for those commands.

- verified `CMsgAction__Process` subtype `0x89` (jump request/echo) ingress handling:
  - branch root: `0x700352`
  - local entity branch:
    - call `CHero_ProcessMovementAcknowledgementTimestamp(msg+0x10)` at `0x700368`
    - join `Role_UpdateCoordinateGateAndMapFromTilePair(hero, zx(msg+0x08), zx(msg+0x0A))`
      at `0x7002E3`
    - do not build, enqueue, or replace a local command block
  - the block below belongs only to a resolved non-local role
  - block reset: `RoleActionCommandState_ResetBlock0x11C` at `0x70039C`
  - command type write:
    - `commandType = 0x14 + (msg+0x24 != 0)` via `setne` + `add 0x14` at `0x7003B2..0x7003C2`
  - progress write:
    - `block+0x04 = 0` at `0x7003B5`
  - tile writes:
    - `block+0x20 = zx(msg+0x08)` at `0x7003C8..0x7003CC`
    - `block+0x24 = zx(msg+0x0A)` at `0x7003D2..0x7003D6`
  - ingress dispatch:
    - `call [roleVtable+0x80](role, &block)` at `0x7003DE`.

- verified `CMsgAction__Process` subtype `0x4A` ingress block build:
  - branch root: `0x6FF44A`
  - block reset: `RoleActionCommandState_ResetBlock0x11C` at `0x6FF4EE`
  - block writes (offsets from block base):
    - `+0x00 = 0x05` at `0x6FF4F3`
    - `+0x04 = 0` at `0x6FF4FD`
  - ingress dispatch:
    - hero path: `call [CHeroVtable+0x80](hero, &block)` at `0x6FF513`
  - companion side effects in this branch:
    - map create/load call `CGameMap_CreateFromDataId(CGameMap_GetSingletonPtr(), msg+0x08)` at `0x6FF468..0x6FF47F`
    - hero tile set + projected position feed from `msg+0x18/+0x1A` at `0x6FF4A2..0x6FF4CC`
    - hero coordinate gate/map sync `Role_UpdateCoordinateGateAndMapFromTilePair(hero, tileX, tileY)` at `0x6FF4CC`

Managed parity note for the current client slice:

- decoded server `MsgAction(10010)` subtype `0x4A` still feeds:
  - map-create ingress (`CGameMapMsgActionIngressRuntime`)
  - command-state type-`05` ingress (`RoleCommandStateMsgActionIngressRuntime`)
- the visible-world gap was the missing projection-side equivalent of the native
  `Role_SetTilePositionAndProjectScreenCoordinates` feed.
- current managed bridge now closes that specific gap by:
  - seeding each local/remote role position carrier with the exact tile -> cursor -> relative-position mirrors
    from `Role_SetTilePositionAndProjectScreenCoordinates`
  - materializing the live `role+0x350/+0x354` cursor through
    `ClientWorldRoleSceneMaterializationRuntime`, rather than reprojecting a static packet tile while motion is active
  - using the local hero’s projected screen pair as the projection-center base input for
    `Role3DClientSceneProjectionTickSnapshotFromCommandStateOrProjectedWorldStateSourceRuntime`
- this is intentionally narrower than full native role object construction: it mirrors the verified tile -> screen
  projection side effect needed for first world-frame centering, without claiming full `CRole` entity or RoleView
  parity yet.

- verified `CMsgAction__Process` subtype `0x51` ingress block builds:
  - branch root: `0x6FF5B6`
  - shared source reads:
    - `memcpy(tmp4, msg+0x08, 4)` at `0x6FF8D0..0x6FF8D7`, command data source `zx(tmp4.low16)`
    - direction source `zx(msg+0x16)` at `0x6FF931..0x6FF937`, `0x6FF9BE..0x6FF9C4`, `0x6FFA0E`
  - block writes (offsets from block base):
    - `+0x00 = 0x06` at `0x6FF917`, `0x6FF9A4`, `0x6FF9F0`
    - `+0x04 = 0` at `0x6FF921`, `0x6FF9AE`
    - `+0x04 = 7` at `0x6FF9FA`
    - `+0x18 = 0` at `0x6FF927`, `0x6FF9B4`, `0x6FFA04`
    - `+0x24 = zx(msg+0x16)` at `0x6FF937`, `0x6FF9C4`, `0x6FFA0E`
    - `+0x3C = zx(msg+0x08)` at `0x6FF90B..0x6FF911`, `0x6FF998..0x6FF99E`, `0x6FF9E4..0x6FF9EA`
  - dispatch:
    - source-role path: `call [roleVtable+0x80]` at `0x6FF940`
    - action-param resolved role path: `call [roleVtable+0x80]` at `0x6FF9CD`
    - action-param hero path: `CHero +0x80` at `0x6FFA24`

- verified `CMsgAction__Process` subtype `0x9C` ingress block build:
  - branch root: `0x7003E9`
  - block reset: `RoleActionCommandState_ResetBlock0x11C` at `0x70040E`
  - block writes:
    - `+0x00 = 0x28` at `0x700416`
    - `+0x04 = 0` at `0x700420`
    - `+0x20 = zx(msg+0x18)` at `0x70043E..0x700442`
    - `+0x24 = zx(msg+0x1A)` at `0x700448..0x70044C`
    - `+0x28 = Role_SelectDirectionIndexTowardTile(resolvedRole, pos_x, pos_y)` result at `0x700457..0x70045C`
    - `+0x40 = Conquer_GetRandomModulo(3, 0) + 0x393` at `0x700426..0x700431`
  - ingress dispatch:
    - hero path: `Role_HandleIncomingActionStateBatch` at `0x70047E..0x70048C`
    - non-hero path: `call [roleVtable+0x80]` at `0x70049F`
  - non-block companion side effects in this branch:
    - `"move_end"` callback/event checks at `0x7004A5..0x7004DC`
    - hero tile sync call `Role_UpdateCoordinateGateAndMapFromTilePair(hero, pos_x, pos_y)` at `0x7004F2..0x700509`

- verified `CMsgAction__Process` subtype `0x82` is non-command-ingress:
  - branch root: `0x7002CD`
  - no `RoleActionCommandState_ResetBlock0x11C` call in this branch.
  - no role/hero vtable `+0x80` ingress dispatch in this branch.
  - behavior in this path:
    - hero-id match -> `Role_UpdateCoordinateGateAndMapFromTilePair(hero, msg+0x08, msg+0x0A)` at `0x7002E3..0x7002FA`
    - non-hero path predicate:
      `Role_IsEntityId700001To799999AndHeroLinked(resolvedRole)` at `0x700307` / `0x700385`
    - predicate true -> `Role_SetFieldA88A8CFromActionParamPair(resolvedRole, msg+0x08, msg+0x0A)` at `0x700310..0x700323`
    - predicate false -> call role vtable `+0x18` with `msg+0x08/+0x0A` at `0x70032D..0x70034A`

- verified role-side command builders that feed the same ingress apply path:
  - `Role_QueueCommandType13MoveToTile` (`0x65833B`):
    - reset block, write `+0x00 = 0x13`, `+0x04 = 0`, `+0x20 = targetTileX`, `+0x24 = targetTileY`,
      then `call [vtable+0x80]` at `0x65851F..0x658529`.
  - `Role_RequestCommandType12MoveToTile` (`0x657CD6`):
    - reset block, write `+0x00 = 0x12`, `+0x04 = 0`, `+0x20 = targetTileX`, `+0x24 = targetTileY`,
      then immediately `call [vtable+0x80]` at `0x657F14..0x657F1E`; this is a request/apply path,
      not insertion into the queued-action deque.
  - `CHero_QueueCommandType07Action278WhenFollowWindowExpires` (`0x664505`):
    - reset block, write `+0x00 = 0x07`, plus action payload constant branch (`0x278`) in this path,
      then `call [vtable+0x80]` at `0x664609`.

Managed runtime mapping from this verified chain:

- per-tick role/map producer snapshot source contract:
  - `10_work/src/Conquer/Client/RoleCommandStateTickSnapshotSourceRuntime.cs`
  - includes verified queued incoming `0x11C` apply mirror:
    - `EnqueueIncomingCommandState(...)`
    - `TryApplyOldestIncomingCommandState(...)`
    - runtime availability gate now enables capture after accepted ingress apply:
      `HasAppliedIncomingCommandState`.
- verified MsgAction ingress mapper:
  - `10_work/src/Conquer/Client/RoleCommandStateMsgActionIngressRuntime.cs`
    - mirrored ingress cases:
      - `0x4A`: enqueue command `0x05` (`progress=0`)
      - `0x89`: local `msg.entity_id` -> timing acknowledgement plus separate local-hero
        coordinate-gate update; resolved non-local entity -> enqueue command `0x14/0x15`
        (`progress=0`, tiles from `msg+0x08/+0x0A`) on that remote role
      - `0x51`: local `msg.action_param` -> enqueue command `0x06` (`progress=7`, data from `msg+0x08`, direction from `msg+0x16`)
      - `0x9C`: local `msg.entity_id` -> enqueue command `0x28` (`progress=0`, tiles from `msg+0x18/+0x1A`, direction selector feed, payload action `0x393 + random%3`)
- decoded inbound packet dispatch to ingress runtime:
  - `10_work/src/Conquer/Client/RoleCommandStateInboundPacketDispatchRuntime.cs`
  - header-validated packet routing:
    - `type == 10010` -> `RoleCommandStateMsgActionIngressRuntime.TryEnqueueFromPacket(...)`
- verified MsgAction packet reader:
  - `10_work/src/Conquer/Client/RoleCommandStateMsgActionIngressRuntime.cs`
  - packet reader:
    `10_work/src/Conquer.Network/Packets/MsgAction10010PacketReader.cs`
- per-tick producer input source contract:
  - `10_work/src/Conquer/Client/RoleCommandStatePlaybackSnapshotInputSourceRuntime.cs`
- per-tick producer snapshot -> bridge input updater:
  - `10_work/src/Conquer/Client/RoleCommandStateSnapshotInputUpdaterRuntime.cs`
- producer input -> bridge snapshot updater:
  - `10_work/src/Conquer/Client/RoleCommandStateSnapshotUpdaterRuntime.cs`
- snapshot state + sink:
  - `10_work/src/Conquer/Client/RoleCommandStatePlaybackSnapshotStateRuntime.cs`
- snapshot source:
  - `10_work/src/Conquer/Client/RoleCommandStatePlaybackSnapshotSourceRuntime.cs`
- non-baseline playback host factory wiring:
  - `10_work/src/Conquer/Client/Role3DClientRolePlaybackFactoryRuntime.cs`
- non-baseline playback host tick wiring:
  - `10_work/src/Conquer/Client/Role3DClientRolePlaybackHostRuntime.cs`
  - `10_work/src/Conquer/Client/GameApplication.cs`
    - per-frame order mirrors native caller:
      - apply oldest queued incoming command-state block,
      - then tick command-state/action playback host.

Not yet mirrored in managed runtime:

- command handlers outside the currently verified selector set remain intentionally unsupported.
- MsgAction ingress mappings outside confirmed subtype set `{0x4A, 0x89, 0x51, 0x9C}` remain intentionally deferred until fully pinned.

This bridge explains why playback still works when blend duration resolves to zero:

- action/motion dispatch and primary-frame updates are always driven each tick from `Conquer.exe`,
- `ActionTransition.ini` only controls transition-duration lookup used by RoleView blend state.

## Bridge note

The part-motion record layouts forwarded further downstream are documented in:

- `20_notes/Rendering/role3d_dll/04_i3drole_object.md`
- `20_notes/Rendering/role3d_dll/05_partinfo_and_mesh_instances.md`

Those docs pin the final Role3D record shapes for slot `43` (`+0xAC`) and slot `44` (`+0xB0`).

## Clean 5517 data note

`00_clean/clean/5517/ini/ActionTransition.ini` is empty (`0` bytes), so this dataset naturally yields no non-zero transition durations from the native lookup path.

## Rewrite baseline harness status (2026-03-04)

`Conquer.Client` no longer boots this baseline renderer path on startup; runtime launch now uses the non-baseline verified client runtime path. Baseline notes below are retained only as historical RE/validation record.

Current .NET baseline renderer (`StaticMeshBaselineRenderer`) now drives a RoleView-style action-dispatch path:

- per model with primary motion, action dispatch now runs every render tick (not only on synthetic action-change points), matching `Role_TickAndRender` slot `+0x0C` cadence;
- ordinary `Role_TickAndRender` passes `refreshPartActionEffects = 0`; the separate
  `Role_UpdateActionAndDispatchRoleViewMotion` action-dispatch path passes `1`, so managed
  action-effect refresh work must not run unconditionally on every render tick;
- the current managed playback exposes the proven action-change subset through
  `DispatchResult.ActionChanged`, and also configures a fresh/changed part-source context
  once before its first draw;
- `CRole+0x60` is the Shuriken Vortex action-override latch, not a generic same-action
  dispatch gate; its status-edge lifecycle and action-`0x390` loop are now modeled by
  `RoleVortexActionOverrideState` and `Role3DClientRolePlayback`;
- action-change path now mirrors native ordering:
  - clear transition source (`+0xE0/+0xE4/+0xEC`),
  - call `TryGetActionTransitionTime(oldAction,newAction)` (native `GameDataSetQuery()->+0x6C` parity),
  - call `BeginTransition(previousTracker, currentPrimaryFrame, duration, now)` only when duration > 0;
- primary frame clock is reset on action change to mirror native `actionStartTick` restart semantics.
- action change now attempts action-keyed tracker resolution through the verified RoleView part-request formulas:
  - managed resolver now exposes all dispatcher parts:
    - `body` / `mix_body` / `mix2_body` (shared body lookup),
    - `misc`,
    - `mount`,
    - `armet` / `mix_armet` / `mix2_armet` (per-variant source ids),
    - `r_weapon` / `l_weapon` (including SoulPart override lookup semantics).
  - baseline renderer currently binds only the body tracker into the single test-model motion path;
    non-baseline per-part binding remains a separate slice.
  - primary lookup key: `RoleViewBodyMotionLookupKeyBuilder.Build(...)`
  - fallback lookup key (native miss path): `bodyAppearanceSourceId * 10000000 + actionId`
  - motion container decode follows native `C3MotionTracker_InitFromMotionFile` shape:
    load MOTI payloads in order, stop on first payload-load failure, max 16.
  - tracker swap applies native bind-time capacity gate:
    `motionCount >= phyCount` (managed mirror of `C3DObjX_SetMotion` guard).
- action source is now configurable:
  - `role-tick-current-action` (default): fixed current action id dispatched each tick.
  - `primary-frame-loop-harness`: synthetic baseline-only sequence advanced on primary-frame wrap.
- non-baseline role playback host now exists as a standalone runtime:
  - `Role3DClientRolePlaybackRuntime` composes:
    - `RoleViewActionFeedDriverRuntime` (per-tick action source),
    - `RoleViewBodyActionDispatchRuntime` (change detection + transition start),
    - `RoleViewBodyMotionTransitionRuntime` (secondary-frame + blend alpha sampling),
    - `RoleViewPrimaryFrameClockRuntime` (primary-frame sampling),
    - `Role3DClientRoleRuntime` (part-name motion dispatch into Role3D wrappers).
  - on action change it resolves a new `RoleViewActionMotionTrackerSet`,
    resets sampled primary frame to `0`,
    and reinitializes the primary-frame clock using the resolved body tracker frame count
    with verified base interval `0x21` ms.
  - when action tracker resolution misses, current per-part tracker set is cleared
    (null pointers are dispatched, matching native null-motion call contracts).
- `CRole` command-state helper runtime is now implemented with parity branch coverage for:
  - block reset (`0x11C` zero),
  - `+0x1E8` complete-fallback accessor,
  - incoming-state accept/reject gate,
  - command payload action accessor (`+0x228`).
- non-baseline action source now includes a command-state selector path:
  - `RoleCommandStateActionSelectionRuntime` mirrors verified selector subset
    (`0x04`, `0x06`, `0x07`) and movement-path subset
    (`0x02`, `0x03` simple-stride branch, `0x03` boosted branch, full command-type `0x13`
    ride branch table including local retry/probe/steering/action-write outcomes,
    command-type-3 pre-stage subset, command-type `0x11` path-prep/probe outcomes, and
    command-type `0x12` path-prep/probe/toggle outcomes including explicit local-retry
    probe context) plus command-type `0x12` and command-type `0x13` local autorun fallback side-effect sink parity with
    explicit movement context inputs
    (`path node count`, `simple-stride branch gate`), plus command-type-5 parity inputs
    (`+0x2C`, `+0x30`, `+0x30C`, random modulo results, and `Role_IsSpecialIdleActionWindowActive`),
    and is wired into `Role3DClientRolePlaybackRuntime`
    before per-tick RoleView dispatch.
  - non-baseline playback host also exposes a command-state motion-state update hook:
    `TryUpdateRoleMotionStateFromCommandStateDelegate` called per tick before action dispatch.
  - `RoleCommandType03TargetStagingRuntime` mirrors verified command-type-3
    direction-index quantization and staged-target table math (`data_86C608`/`data_86C628`)
    used before path build.

Implementation mapping:

- dispatch runtime: `10_work/src/Conquer.Graphics/Role/RoleViewBodyActionDispatchRuntime.cs`
- transition math runtime: `10_work/src/Conquer.Graphics/Role/RoleViewBodyMotionTransitionRuntime.cs`
- action feed runtime: `10_work/src/Conquer.Graphics/Role/RoleViewActionFeedDriverRuntime.cs`
- action feed settings: `10_work/src/Conquer.Graphics/Role/RoleViewActionFeedSettings.cs`
- command-state runtime: `10_work/src/Conquer.Graphics/Role/RoleActionCommandStateRuntime.cs`
- command-state action selector runtime:
  - `10_work/src/Conquer.Graphics/Role/RoleCommandStateActionSelectionRuntime.cs`
  - `10_work/src/Conquer.Graphics/Role/RoleCommandType12AutoRunSideEffectRuntime.cs`
  - `10_work/src/Conquer.Graphics/Role/RoleCommandType13AutoRunSideEffectRuntime.cs`
  - `10_work/src/Conquer.Graphics/Role/RoleCommandType13SecondProbePassMotionStateRuntime.cs`
  - includes `RoleCommandStateMovementSelectionContext` for verified movement-path branch inputs
  - includes `RoleCommandType03SelectionContext` target-acquisition inputs
    (`IsTargetEntityResolvedFromLookup`, `IsCommandTargetEntityLocalRole`)
  - includes `RoleCommandType05SelectionContext` for verified command-type-5 external gate inputs
  - includes `RoleCommandType13SelectionContext` for verified command-type-13 probe/direction/pose branch inputs
  - command-type-3 target staging runtime:
    - `10_work/src/Conquer.Graphics/Role/RoleCommandType03TargetStagingRuntime.cs`
- baseline GL harness renderer was removed from runtime source; client startup now runs non-baseline paths only.
- non-baseline role playback runtime:
  - `10_work/src/Conquer/Client/Role3DClientRolePlaybackRuntime.cs`
- duration source binding: `10_work/src/Conquer/Client/GameApplication.cs` (`GraphicDataAssetResolver.TryGetActionTransitionTime`)
- action feed CLI resolver: `10_work/src/Conquer/Client/RoleViewActionFeedSettingsResolver.cs`
- action tracker resolver:
  - `10_work/src/Conquer/Client/RoleViewBodyActionMotionTrackerResolver.cs`
  - `10_work/src/Conquer/Client/RoleViewActionMotionTrackerSet.cs`
  - `10_work/src/Conquer/Client/RoleViewBodyMotionLookupContext.cs`
  - `10_work/src/Conquer/Client/RoleViewBodyMotionLookupContextResolver.cs`
  - Role3D part-motion dispatch path:
    - `10_work/src/Conquer.Graphics/Motion/RolePartMotionTrackerFrameRecords.cs`
    - `10_work/src/Conquer.Graphics/Motion/Role3DPartInfoMotionRuntime.cs`
    - `10_work/src/Conquer.Graphics/Motion/Role3DRolePartMotionInterfaceRuntime.cs`
    - `10_work/src/Conquer/Client/Role3DClientRoleRuntime.cs`
  - CLI switches:
    - `--roleview-action-feed-mode` (`role-tick` or `primary-loop-harness`)
    - `--roleview-current-action-id` (optional, default `0x390`)
    - `--roleview-harness-action-sequence` (optional CSV action ids for harness mode)
    - `--roleview-body-appearance-source-id` (required to enable body tracker lookup)
    - `--roleview-mount-model-id` (optional, default `0`)
    - `--roleview-left-weapon-source-id` (optional, default `0`)
    - `--roleview-right-weapon-source-id` (optional, default `0`)
    - `--roleview-left-weapon-override-lookup-id` (optional, default `0`)
    - `--roleview-right-weapon-override-lookup-id` (optional, default `0`)
    - `--roleview-misc-source-id` (optional, default `0`)
    - `--roleview-helmet-source-id` (optional, default `0`)
    - `--roleview-mix-helmet-source-id` (optional, default `0`)
    - `--roleview-mix2-helmet-source-id` (optional, default `0`)

Result for clean 5517 remains expected:

1. `ActionTransition.ini` is empty (`0` bytes), so lookup durations are zero and transitions are not started.
2. when motion lookup context is not supplied, renderer keeps mesh-embedded primary tracker (no action-specific body tracker swap).
3. when context is supplied but corresponding role-part motion keys are absent for the chosen ids/actions, tracker resolution for those parts yields null and body swap is skipped when body key lookup misses.
4. in default `role-tick-current-action` mode, no synthetic action changes are generated; transitions only occur when the action source is explicitly changed.
