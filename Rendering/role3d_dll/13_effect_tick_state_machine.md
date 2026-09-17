# `Role3D.dll` — Effect tick/update state machine

The verified tick and update logic driving effect-instance frame progression and completion.

Primary functions:

- `PartInfo_AreEffectResourcesReady` (`0x1000A0A0`)
- `Effect_TickUpdateStateMachine` (`0x1000A280`)
- `EffectPart_EnsureRuntimeData` (`0x1000A210`)
- `PartInfo_TickEffectsAndCleanupCompleted` (`0x1000A480`)
- `EffectShouldRenderForFPS` (`0x1000CEE0`) (render-gate helper used by iterators)

## `PartInfo_AreEffectResourcesReady` (`0x1000A0A0`)

Call shape:

- `ecx = partInfo`
- stack arg = `effectInstance`
- return: `int` (`1` ready, `0` not ready)

High-level behavior:

1. returns `0` if `effectInstance == 0`
2. returns `1` if `effectInstance->partCount <= 0`
3. loops part records with verified 36-byte stride (`0x24`)
4. for each part:
   - requests draw resource:
     `GameDataSetQuery()->RequestEffectDrawResource(part.resourceId, 0, 0)` (`vtable +0x1C`)
   - returns `0` immediately if draw resource is null
   - requests secondary texture/resource:
     `GameDataSetQuery()->RequestTexture(part.secondaryId, 0, 0)` (`vtable +0x18`)
   - returns `0` immediately if texture resource is null
5. returns `1` only when all part requests succeed

Verified xrefs:

- `PartInfo_RenderEffectsWithOffsetsFiltered` call site: `0x1000897C`
- `PartInfo_RenderEffectsScreenSpaceFiltered` call site: `0x10008AAC`

## `Effect_TickUpdateStateMachine` (`0x1000A280`)

Call shape:

- `ecx = partInfo`
- stack arg = `effectInstance`
- return: `int` (`1` when effect is finished/non-active path, otherwise `0`)

High-level behavior:

1. early return `1` when:
   - `effectInstance == 0`, or
   - `effectInstance->partCount <= 0`, or
   - `effectInstance->playbackState == 4`
2. early return `0` when `effectInstance->probeOrTickGateFlag != 0`
3. computes `elapsedSinceStart = timeGetTime() - effectInstance->startTickMs`
4. if unsigned `elapsedSinceStart <= effectInstance->delayMs`:
   - sets `playbackState = 1`
   - returns `0`
5. if `playbackState` is `0` or `1`:
   - sets `playbackState = 2`
   - emits callback via `partInfo->effectEventSink->vfn_00(categoryId)` (if sink present)
6. computes `elapsedAfterDelay = elapsedSinceStart - delayMs`
7. computes `maxFrameWithBase` from part resources (details below), with fallback `0x64` (`100`)
8. computes:
   - `cycleFrameWindow = frameScale * maxFrameWithBase + holdOffset`
   - `finishThreshold = repeatCount * cycleFrameWindow - holdOffset`
9. if unsigned `elapsedAfterDelay > finishThreshold`:
   - sets `playbackState = 4`
   - emits callback `vfn_0C(categoryId)` (if sink present)
   - returns `1`
10. otherwise samples frame:
    - `safeCycleFrameWindow = (cycleFrameWindow == 0) ? 1 : cycleFrameWindow`
    - `sampledFrame = ((uint32)elapsedAfterDelay % (uint32)safeCycleFrameWindow) / (uint32)frameScale`
11. state transitions around `sampledFrame`:
    - if `sampledFrame >= maxFrameWithBase`:
      - if `playbackState == 2`, set `playbackState = 3`, emit `vfn_08(categoryId)`
      - return `0`
    - else:
      - if `playbackState == 3`, set `playbackState = 2`, emit `vfn_04(categoryId)`
      - writes `effectInstance->currentFrameIndex = sampledFrame`
      - return `0`

## Part-frame bound accumulation (`maxFrameWithBase`)

Inside `Effect_TickUpdateStateMachine`, for each part index `i`:

1. resolve `effectPartRecord = effectInstance->partsBase + (i * 0x24)` (36-byte part record)
2. request draw resource:
   - `drawResource = GameDataSetQuery()->RequestEffectDrawResource(effectPartRecord->resourceId, 0, 0)`
3. if resource exists:
   - if `effectPartRecord->runtimePrepared == 0`, call `EffectPart_EnsureRuntimeData(drawResource, effectPartRecord)`
   - read `resourceFrameCount = drawResource->vfn_4C()`
   - candidate bound = `resourceFrameCount + effectInstance->partFrameBaseOffsets[i]`
   - signed max update against `maxFrameWithBase`
4. after each iteration: if `maxFrameWithBase == 0`, set `maxFrameWithBase = 100`

This fallback value (`100`) is not guessed; it is written literally at `0x1000A37E`.

## `EffectPart_EnsureRuntimeData` (`0x1000A210`)

Called lazily once per part (guarded by `effectPartRecord[8]`).

Verified writes/calls:

- sets `effectPartRecord[2]` from draw-resource vtable `+0x54`
- initializes `effectPartRecord[7]` from draw-resource vtable `+0x58` when zero
- applies `effectPartRecord[7]` through draw-resource vtable `+0x5C`
- writes `effectPartRecord[5]` from draw-resource vtable `+0x64`, then calls `+0x68`
- writes `effectPartRecord[6]` from draw-resource vtable `+0x6C`, then calls `+0x70`
- sets `effectPartRecord[8] = 1`

Verified 5517 concrete mapping (draw-resource object backed by `graphic.dll` `C3Effect` vtable):

- `+0x1C` -> `C3Effect_ResetShapeRuntime`
- `+0x54` -> `C3MotionTracker_GetMotionCount` (returns `this+0x04`, reused in `C3Effect` vtable)
- `+0x58` -> `C3Effect_CreateShapeInfo`
- `+0x5C` -> `C3Effect_ExportShapeInfoToBuffer`
- `+0x64` -> `C3Effect_CreatePtcl2Info`
- `+0x68` -> `C3Effect_BindPtcl2InfoBlocks`
- `+0x6C` -> `C3Effect_CreatePtcl3Info`
- `+0x70` -> `C3Effect_BindPtcl3InfoBlocks`

## Completion cleanup path (`PartInfo_TickEffectsAndCleanupCompleted`)

`PartInfo_TickEffectsAndCleanupCompleted` iterates effect instances in reverse index order and calls `Effect_TickUpdateStateMachine` on each.

When tick returns `1`:

- if `effectInstance->completionNotifyEnabled` (byte at `+0x70`) is non-zero, appends `&effectInstance->categoryId` to an internal list
- calls effect teardown path (`EffectInstance_ReleaseResources`, `0x10008640`) and releases the effect instance
- after reverse iteration completes, dispatches accumulated completion ids through
  `partInfo->effectEventSink->vfn_10(categoryId)` when sink is present

The same function also updates per-effect transform streams each iteration, but that transform-write path is documented separately from the tick state machine.

## Callback slot mapping from `partInfo->effectEventSink` (`partInfo + 0x68`)

These callbacks are emitted directly by the state machine:

- `vfn_00(categoryId)`: state `0/1 -> 2` transition
- `vfn_04(categoryId)`: state `3 -> 2` transition
- `vfn_08(categoryId)`: state `2 -> 3` transition
- `vfn_0C(categoryId)`: state `* -> 4` (completed)
