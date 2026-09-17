# `Role3D.dll` — Effect instance list and render paths

`Role3D.dll` owns and updates a per-`PartInfo` “effect instance” list. Each effect instance is updated on a frame-rate gate and then rendered using parameters sourced from the active render context.

This document defines:
- how effect instances are stored and iterated
- the gating rules that decide whether an effect is rendered this frame
- the two concrete render paths used by the engine
- the native creation/append path that populates the effect list

## Creation chain (native)

Verified Role3D call chain:

- `Role3DObject_EnsureEffectInstanceByName` (`0x10005FF0`)
- `PartInfo_CreateAndAppendEffectInstanceByName` (`0x1000AC40`)
- `Game3DEffectCreate` export (`0x10008700`) -> `Game3DEffect_ConstructHeader` (`0x10008770`) (separate small header object; not the list instance below)

`Role3DObject_EnsureEffectInstanceByName` behavior:

1. if `effectName == null`, return
2. if `_stricmp(effectName, "none") == 0`, call `(*(partInfo->vtable)+0x08)()` and return
3. otherwise, create when:
   - `forceCreate != 0`, or
   - `effectOwnerLabel != null`, or
   - `Game3DEffect_HasEffectInstanceByExactName(effectName) == 0`

The helper does not trim the supplied name and does not reject an empty string. The
existing-name query at producer vtable `+0x60` compares names case-sensitively.

Creation target is `PartInfo_CreateAndAppendEffectInstanceByName`, which allocates and appends the runtime effect instance to `PartInfo`.

## Named removal and clear-all chain

The embedded `Game3DEffect` producer vtable has two distinct removal paths:

- vtable `+0x08` -> `Game3DEffect_ClearAllEffectInstancesAndResetHeader`
  (`0x1000A660`)
  - sends the owner/event-sink `+0x10(categoryId)` notification for every instance when
    configured
  - releases every effect instance
  - erases the complete instance list
  - restores `+0x04/+0x08 = 0`, `+0x0C = 1`, position/rotation = zero, and scale = one
  - preserves the local-transform-enabled byte at `+0x6C`
- vtable `+0x18` -> `Game3DEffect_RemoveEffectInstanceByName`
  (`0x1000A870`)
  - compares names case-sensitively
  - removes only the first matching instance
  - sends the owner-sink category notification when configured
  - releases the instance and erases that one list entry

The Role3D forwarding chain is:

1. `I3DRole_RemovePartEffectInstanceByName` (`0x10001FB0`, slot `+0x5C`)
2. `PartInfo_RemoveEffectInstanceByNameOrClearAll` (`0x10005FC0`)
3. embedded producer at `partInfo+0x84`

A non-null effect name selects named removal. A null effect name selects clear-all.
A null part name makes the I3DRole wrapper iterate all loaded parts; otherwise it targets
one named part.

## `PartInfo_CreateAndAppendEffectInstanceByName` summary

Call shape:

- `ecx = partInfo`
- stack args:
  - `effectName`
  - `ownerLabelOrTag` (optional, duplicated with `_strdup` into instance `+0x1EC`)
  - `spawnFlagsByte` (instance `+0x1F0`)
  - `completionNotifyEnabled` (instance `+0x70`)
- return:
  - success: newly assigned runtime category id (`instance + 0x1E4`)
  - failure: `-1` or `0` on specific reject branches

Verified steps:

1. rejects null or `"none"` effect names
2. resolves effect template via `GameDataSetQuery()->vtable+0x48(effectName)` (`GameDataSet_FindEffectTemplateByName`)
3. applies effect-level gate:
   - template `+0x1E4 <= data_100202F0`
   - `LimitGame3DEffectLevel` (`0x1000D660`) writes `data_100202F0`
4. applies reslimit gate through `GetResLimitInterface()->vtable+0x28(templatePartCount, effectName)`
5. allocates effect instance object (`0x1F4` bytes) and zeros it
6. allocates per-part record array with header:
   - allocation size: `(partCount * 0x24) + 4`
   - first dword stores count
   - `instance + 0x00` points to first 36-byte record
7. for each part, initializes part record and per-part streams:
   - record dword0 `resourceId` from template `+0x24[i]`
   - record dword1 `secondaryId` from template `+0x64[i]`
   - record dword3 `variantOrIndex = -1`
   - stream `instance + 0x74[i]` from template `+0xA4[i]`
   - stream `instance + 0xB4[i]` from template `+0xE4[i]`
   - stream `instance + 0xF4[i]` from template `+0x124[i]`
   - stream `instance + 0x154[i]` from template `+0x164[i]`
   - byte stream `instance + 0x134[i]` from template `+0x1A4[i]`
   - byte stream `instance + 0x144[i]` from template `+0x1B4[i]`
8. eagerly requests draw resource (`GameDataSet vtable+0x1C`) and calls `EffectPart_EnsureRuntimeData` when non-null
9. copies scalar timing/transform gate fields:
   - `instance + 0x48` <- template `+0x1C4`
   - `instance + 0x54` <- template `+0x1CC`
   - `instance + 0x58` <- template `+0x1C8`
   - `instance + 0x5C` <- template `+0x1D0`
   - `instance + 0x60` <- template `+0x1D4`
   - `instance + 0x64` <- template `+0x1D8`
   - `instance + 0x68` <- template `+0x1DC`
   - `instance + 0x1BC` <- template `+0x1E0`
   - `instance + 0x1C0` <- template `+0x1E8` (byte)
   - `instance + 0x1C4` <- template `+0x1E4`
10. stamps runtime fields:
   - `instance + 0x50 = timeGetTime()`
   - `instance + 0x1E4 = data_10022E38` and increments global counter
11. appends pointer into `PartInfo` effect pointer list rooted at `partInfo + 0x38` and increments `*(partInfo + 0x64)`

## Storage: `PartInfo` effect instance list

`PartInfo` maintains an array of effect-instance pointers plus a paging indirection layer:

- `this[25]` = `effectCount`
- `this[17]` = base pointer to the first effect pointer slot (dword pointers)
- `this[15]` = base pointer used to compute an index into the paging table
- `this[18]` = paging table (each entry points to a 1024-element page of effect pointers)

During iteration, the code computes:

1) `v5 = (this[17] + 4*i)` (address of the ith pointer slot)
2) `slotIndex = (v5 - this[15]) / 4`
3) `page = slotIndex >> 10` (divide by 1024)
4) if `page != 0`, it reads `pageBase = *(this[18] + 4*page)` and re-bases the slot pointer:
   - `v5 = pageBase + 4*(slotIndex - (page<<10))`

Then `effect = *v5`.

This structure allows the effect pointer list to exceed a single contiguous allocation.

## Frame-rate gating: `EffectShouldRenderForFPS`

Before rendering, each effect instance is gated by a simple FPS policy:

- `EffectShouldRenderForFPS(effect->fpsClass, currentFps)` is implemented by `EffectShouldRenderForFPS` (`0x1000CEE0`).
- `currentFps` comes from `GetCurrentFPS()`.

Observed behavior:

- If `effect->fpsClass <= 1`, always render.
- If `currentFps < 20`, do not render.
- If `20 <= currentFps < 30`, render only if `effect->fpsClass < 3`.
- If `30 <= currentFps <= 40`, render only if `effect->fpsClass < 4`.
- If `currentFps > 40`, always render.

Verified call sites (all pass `effect + 0x1C4` as the first argument):

- `PartInfo_TickEffectsAndRender` at `0x10008BFE`
- `PartInfo_RenderEffectsWithOffsetsFiltered` at `0x10008A14`
- `PartInfo_RenderEffectsScreenSpaceFiltered` at `0x10008B40`

## Render path A: `PartInfo_TickEffectsAndRender`

`PartInfo_TickEffectsAndRender` (`0x10008B80`) is called at the end of `PartInfo_RenderAllParts`.

For each effect instance in the effect list:

- If `EffectShouldRenderForFPS(effect->fpsClass, currentFps)` returns true:
  - Call `Effect_RenderWithContext(effect, renderContext)`

Extra verified control-flow details:

- if `renderContext == 0`, returns `0` immediately (`0x10008B8C..0x10008C2A`)
- otherwise iterates effect slots via the shared helper `PartInfo_EffectSlotPointerAtIndex` (`0x1000DBC0`)
- after iteration, calls `(*this->vtable)[1]` and returns that value (`0x10008C1E..0x10008C25`)

## Render path B: “UI/overlay” render variants

Two additional iterators exist that render effect instances in alternative coordinate spaces:

- `PartInfo_RenderEffectsWithOffsetsFiltered` (`0x10008930`) iterates effects and calls `Effect_RenderWithOffsets(effect, a2, basePtr + a3)` when an optional filter matches `effect->categoryId` at offset `+484`.
- `PartInfo_RenderEffectsScreenSpaceFiltered` (`0x10008A60`) iterates effects and calls `Effect_RenderScreenSpace(effect, a2)` when an optional filter matches `effect->categoryId` at offset `+484`.

Both functions perform a strict two-phase flow:

1. Readiness pass over all effect slots (`PartInfo_AreEffectResourcesReady`):
   - any null/not-ready effect returns `0` immediately
   - this early-return path does not call `(*this->vtable)[1]`
2. Render pass:
   - applies optional category filter (`-1` means select all)
   - applies `EffectShouldRenderForFPS(effect+0x1C4, currentFps)`
   - dispatches to backend (`Effect_RenderWithOffsets` or `Effect_RenderScreenSpace`)
   - after full pass, calls and returns `(*this->vtable)[1]`

Shared slot-resolution helper used in both passes:

- `PartInfo_EffectSlotPointerAtIndex` (`0x1000DBC0`, renamed in BNinja from `sub_1000dbc0`)

## Effect render backends

`Role3D.dll` implements three effect render backends (only two are used by the public iterators above):

- `Effect_RenderWithContext` (`0x10008C30`)
- `Effect_RenderWithOffsets` (`0x10009140`)
- `Effect_RenderScreenSpace` (`0x10009570`)

All three backends ultimately:

- request draw resource via `GameDataSetQuery()->vfn_1C(resourceId, 0, 0)` and abort render call on null
- resolve variant/secondary texture branch:
  - `variantOrIndex >= 0` -> draw-resource slot `+0x14(variant)`
  - `variantOrIndex < 0` -> `GameDataSetQuery()->vfn_18(secondaryId,0,0)`, texture readiness check via texture `+0x10`, then draw-resource `+0x18(texture)`
- apply frame/part runtime state before draw:
  - frame guard via draw-resource `+0x4C`
  - frame set via `+0x50(currentFrameIndex - partFrameBaseOffset[i])` when non-negative
  - per-part runtime handle feeds:
    - `+0x60(part[7])`
    - `+0x68(part[5])`
    - `+0x70(part[6])`
  - effect triplets:
    - `+0x74(effect[0x1C8..0x1D0])`
    - `+0x78(effect[0x1D4..0x1DC])`
- apply transforms (`+0x20/+0x24/+0x28/+0x2C`) based on backend coordinate mode
- issue draw via draw-resource `+0x10(...)`
- call draw-resource `+0x5C(part[7])` post-draw

Disassembly evidence:
- `Effect_RenderWithContext` (`0x10008C30`): slots at `0x10008DD0..0x10008E32`, draw at `0x100090ED`, post-draw at `0x100090FC`
- `Effect_RenderWithOffsets` (`0x10009140`): slots at `0x100092B6..0x10009318`, draw at `0x10009529`, post-draw at `0x10009534`
- `Effect_RenderScreenSpace` (`0x10009570`): slots at `0x100096FD..0x1000975F`, draw at `0x1000987D`, post-draw at `0x10009888`

### Backend-specific transform/render-param feeds (verified)

`Effect_RenderWithContext` (`0x10008C30`):

- Uses draw-resource slot `+0x2C(matrix)` and slot `+0x0C(mesh, ownerLabel, spawnFlags, optionalLocalMatrix)` depending on part-info-root mesh availability:
  - if `PartInfo_GetPartMeshArrayHeader(partInfoRoot)->count > 0`:
    - resolves first part mesh via `PartInfo_ResolvePartMesh(partInfoRoot, header[1])`
    - calls draw-resource `+0x0C` with:
      - mesh pointer
      - `effect(+0x1EC)` owner label pointer
      - `effect(+0x1F0)` spawn flags byte
      - matrix pointer = local matrix buffer when `partInfo(+0x6C) != 0`, else `null`
  - else:
    - builds base matrix via `PartInfo_BuildPartMatrixForFrame(partInfoRoot, outMatrix, 0, 0)`
    - if `partInfo(+0x6C) != 0`, multiplies `outMatrix = localMatrix * outMatrix`
    - uploads `outMatrix` through draw-resource `+0x2C`
- local matrix construction when `partInfo(+0x6C) != 0`:
  - starts with identity
  - `CMyBitmap::Common_Scale` with:
    - `sx = effect(+0x1A0) * partInfo(+0x2C)`
    - `sy = effect(+0x1A4) * partInfo(+0x30)`
    - `sz = effect(+0x1A8) * partInfo(+0x34)`
  - tilt/rotation order branches on global `data_10022d6c`:
    - `data_10022d6c == 0`:
      1. `Common_Translate(0, -effect(+0x68), partInfo(+0x08) * 1.4f)`
      2. `Common_Rotate(effect(+0x1AC)+partInfo(+0x20), effect(+0x1B0)+partInfo(+0x24), effect(+0x1B4)+partInfo(+0x28))`
    - `data_10022d6c != 0`:
      1. same `Common_Rotate(...)`
      2. same `Common_Translate(0, -effect(+0x68), partInfo(+0x08) * 1.4f)`
  - final world translate:
    - `x = (int)effect(+0x60) + effect(+0x194) + partInfo(+0x14)`
    - `y = effect(+0x198) + partInfo(+0x18)`
    - `z = (int)effect(+0x64) + effect(+0x19C) + partInfo(+0x1C)`
    - applied through `Common_Translate(localMatrix, x, y, z)`
- No draw-resource `+0x30(renderParam1)` feed in this backend.

### Producer header fields consumed by `Effect_RenderWithContext` (verified)

`Effect_RenderWithContext` reads the embedded `Game3DEffect` producer header directly from
the `PartInfo` root passed in as its second argument. This means the producer header state
written by `PlayerRoleView_ConfigureRolePartActionEffects` is a live render-time input; it is not
required to be copied into every effect instance at creation time.

Verified producer header construction defaults from `Game3DEffect_ConstructHeader`
(`0x10008770`):

| Producer header field | Offset | Default |
|---|---:|---:|
| `ownerObjectPtr` | `+0x68` | caller-owned `PartInfo` root |
| `localTransformEnabled` | `+0x6C` | `0` |
| `pitchValue` | `+0x08` | `0.0f` |
| `headerTranslateX/Y/Z` | `+0x14/+0x18/+0x1C` | `0.0f` |
| `headerRotateX/Y/Z` | `+0x20/+0x24/+0x28` | `0.0f` |
| `headerScaleX/Y/Z` | `+0x2C/+0x30/+0x34` | `1.0f` |

Verified producer header setters:

- `Game3DEffect_SetLocalTransformEnabledFlag` (`0x1000D0E0`)
  - writes the one-byte gate at `producer+0x6C`
  - returns the written byte
- `Game3DEffect_SetRotationForSelection` (`0x10009C50`)
  - with selector `-1`, writes producer header rotation `+0x20/+0x24/+0x28`
- `Game3DEffect_SetScaleForSelection` (`0x10009E00`)
  - with selector `-1`, writes producer header scale `+0x2C/+0x30/+0x34`

Verified render-time consumption in `Effect_RenderWithContext`:

- `producer+0x6C` gates whether a local matrix is built at all
- `producer+0x2C/+0x30/+0x34` multiply the per-effect runtime scale values
- `producer+0x20/+0x24/+0x28` add to the per-effect runtime rotation values
- `producer+0x14/+0x18/+0x1C` add to the final world translate
- `producer+0x08 * 1.4f` becomes the Z component of the tilt/oblique translate

Practical parity consequence:

- the rewrite can safely model the producer header as per-part persistent state
- a bounded managed `PlayerRoleView_ConfigureRolePartActionEffects` mirror only needs to set the
  producer header fields and ensure the effect instance by name
- no guessed per-instance copy step should be added

### Visual-track refresh hook (verified)

`Role3DObject_RefreshEffectVisualTrackConfigByName` (`0x10005810`) is the verified
refresh/rebuild seam for already-created part effect instances:

1. calls `GameDataSetQuery()->+0x54(effectName, effectInstancePointer)`
2. on hit, copies `0x74` bytes from the returned record into `effectInstance+0x40`
3. calls producer vfunc `+0x7C`, now renamed
   `Game3DEffect_RebuildPerEffectPartRuntimeFromTemplate` (`0x1000CAD0`)

`Game3DEffect_RebuildPerEffectPartRuntimeFromTemplate` behavior:

- iterates the producer-owned effect-instance list
- re-resolves effect template data by effect name
- destroys/rebuilds per-part runtime data from the refreshed template-backed state
- refreshes runtime counters/timestamps before returning

Current rewrite boundary:

- this refresh hook is verified and documented
- `Conquer.exe::Role_UpdateActionAndDispatchRoleViewMotion` (`0x64E2DD`) is now verified to
  call `PlayerRoleView_UpdateRolePartMotionsForAction` with its final
  `refreshPartActionEffects` argument set to `1`
- ordinary `Role_TickAndRender` calls at `0x64FA30` and `0x64FACC` pass that final argument
  as `0`
- managed action-effect configuration must therefore run on the action-dispatch refresh
  path, not unconditionally on every render tick

Anchors:
- transform-gate branch: `0x10008E35..0x10008FFC`
- `+0x0C` mesh bind path: `0x10009022..0x10009043`
- `+0x2C` matrix upload path: `0x10009048..0x1000907C`
- part-root mesh/matrix helpers:
  - `PartInfo_GetPartMeshArrayHeader`: `0x10009005`
  - `PartInfo_ResolvePartMesh`: `0x10009015`
  - `PartInfo_BuildPartMatrixForFrame`: `0x10009053`
  - `j_MatrixMultiplyDispatch`: `0x1000906E`

Verified `C3_CORE_DLL` transform helper semantics used above:

- `Common_Translate` (`0x10001420`): adds into matrix `M41/M42/M43`
- `Common_Rotate` (`0x10001450`): `M = M * RotX(rx)`, then `M = M * RotY(ry)`, then `M = M * RotZ(rz)`
- `Common_Scale` (`0x100014B0`): multiplies matrix columns X/Y/Z (including translation terms `M41/M42/M43`)

`Effect_RenderWithOffsets` (`0x10009140`):

- scale feed to draw-resource `+0x28`:
  - `sx = effect(+0x1A0) * partInfo(+0x2C) * (partFrameScale100[i] * 0.01f)`
  - `sy = effect(+0x1A4) * partInfo(+0x30) * (partFrameScale100[i] * 0.01f)`
  - `sz = effect(+0x1A8) * partInfo(+0x34) * (partFrameScale100[i] * 0.01f)`
- rotation/tilt calls:
  - always uses runtime rotation overrides `effect(+0x1AC/+0x1B0/+0x1B4)` + `partInfo(+0x20/+0x24/+0x28)` for draw-resource `+0x24`
  - also uses draw-resource `+0x20` with `(0, signed(effect(+0x68)), partInfo(+0x08) * 1.4f)`; sign depends on global `data_10022d6c`
  - when `partInfo(+0x0C) != 0`, applies extra `+0x24` angle with `degrees * 0.0174532924f` from either `data_10022d68` or `CMyBitmap::GetObliqueAngle()`
- translate feed to draw-resource `+0x20`:
  - `x = (int)effect(+0x60) + effect(+0x194) + partInfo(+0x14) + offsetX`
  - `y = effect(+0x198) + partInfo(+0x18)`
  - `z = (int)effect(+0x64) + effect(+0x19C) + partInfo(+0x1C) + offsetZ`
- render param feed:
  - `drawResource +0x30(effect(+0x1B8))` before draw call

Anchors:
- scale `+0x28`: `0x10009338..0x1000936E`
- rotation `+0x24`: `0x1000939D..0x100093C8`, `0x100093CD..0x100093F6`
- tilt `+0x20`: `0x1000937C..0x1000939A`, `0x100093F9..0x10009413`
- extra oblique `+0x24`: `0x1000942C..0x10009469`
- translate `+0x20`: `0x10009470..0x100094A9`
- render param `+0x30`: `0x100094AC..0x100094B7`

`Effect_RenderScreenSpace` (`0x10009570`):

- builds a local matrix via `j_MatrixScaleDispatch` using:
  - `uniformScale = partFrameScale100[i] * 0.01f`
- adjusts matrix translation with effect template offsets:
  - `+0x60` and `+0x64` added directly
  - `+0x68` added with sign flip when `data_10022d6c == 0`
- multiplies local matrix with caller `viewProjectionMatrix` via `j_MatrixMultiplyDispatch`
- uploads matrix with draw-resource `+0x2C(localMatrix)`
- sets render param with draw-resource `+0x30(effect(+0x1B8))`

Anchors:
- scale matrix build: `0x1000976E..0x1000978F`
- translation offset inject: `0x10009794..0x100097E1`
- matrix multiply: `0x100097B9..0x100097E8`
- matrix upload `+0x2C`: `0x100097ED..0x100097F6`
- render param `+0x30`: `0x100097F9..0x10009804`

## Header-vtable producer/update mutators (newly verified)

`Game3DEffect_ConstructHeader` produces an object whose vtable methods mutate active effect instances in `PartInfo`.
The following methods are now fully named and verified in BNinja:

| Function | Address | Verified writes/behavior |
|---|---:|---|
| `Game3DEffect_ResetHeaderAndPerEffectTransformOverrides` | `0x100098D0` | Resets header transforms (`+0x14..+0x34`) and every effect runtime transform override (`+0x194..+0x1B4`) to default (0,0,0 / 1,1,1 / 0,0,0). |
| `Game3DEffect_SetResourceMatrixForCategorySelection` | `0x10009A60` | For selected effects, iterates part draw resources and calls draw-resource slot `+0x2C(matrix4x4)`. |
| `Game3DEffect_SetPositionForSelection` | `0x10009B40` | `selector == -1` writes header `+0x14..+0x1C`; otherwise writes selected effect `+0x194..+0x19C` (index/category mode). |
| `Game3DEffect_SetRotationForSelection` | `0x10009C50` | `selector == -1` writes header `+0x20..+0x28`; otherwise writes selected effect `+0x1AC..+0x1B4` (index/category mode). |
| `Game3DEffect_SetRotationZDegreesForCategorySelection` | `0x10009D60` | Writes selected effect `+0x1B4 = degrees * 0.0174532924f` (category/all selector). |
| `Game3DEffect_SetScaleForSelection` | `0x10009E00` | `selector == -1` writes header `+0x2C..+0x34`; otherwise writes selected effect `+0x1A0..+0x1A8` (index/category mode). |
| `Game3DEffect_SetRenderParam1ForSelection` | `0x10009F10` | Writes selected effect `+0x1B8`; writes are gated by `templateEnabledFlagBool` (`effect+0x1C0 != 0`). Supports all/index/category selectors. |
| `Game3DEffect_SetPerPartBlendModesForCategorySelection` | `0x10009FC0` | Writes selected effects’ per-part blend streams: `+0x74[i]` and `+0xB4[i]`; optional part-index filter. |
| `Game3DEffect_SetTripletAForCategorySelection` | `0x1000C970` | Writes selected effect `+0x1C8/+0x1CC/+0x1D0` (category/all selector). |
| `Game3DEffect_SetTripletBForCategorySelection` | `0x1000CA20` | Writes selected effect `+0x1D4/+0x1D8/+0x1DC` (category/all selector). |

## Tick/update lifecycle

Effect render is paired with a separate tick/update lifecycle:

- `Effect_TickUpdateStateMachine` (`0x1000A280`)
- `PartInfo_TickEffectsAndCleanupCompleted` (`0x1000A480`)

Those paths advance `currentFrameIndex`, drive `playbackState` transitions (`0/1/2/3/4`), and remove completed effects.

Full formulas, callback transitions, and cleanup behavior are documented in:

- `analysis/conquer_docs/Rendering/role3d_dll/13_effect_tick_state_machine.md`
