# `Role3D.dll` — Effect instance object layout (creation + tick + render proven)

The effect-instance object, as observed from the native creation, render and tick paths:

- `PartInfo_CreateAndAppendEffectInstanceByName` (`0x1000AC40`)
- `Effect_RenderWithContext` (`0x10008C30`)
- `Effect_RenderWithOffsets` (`0x10009140`)
- `Effect_RenderScreenSpace` (`0x10009570`)
- `Effect_TickUpdateStateMachine` (`0x1000A280`)

The object is a C++ class (passed as `this`), with a fixed header and several embedded per-part arrays.

## Header fields (proven)

Offsets are byte offsets from the start of the effect instance object.

| Offset | Type | Name | Evidence |
|---:|---|---|---|
| `+0x04` | `int` | `partCount` | Loops iterate `for (i=0; i<this->partCount; ++i)` and step a `36`-byte per-part record in `(*this->partsBase + 36*i)`. |
| `+0x00` | `void*` | `partsBase` | Set by `PartInfo_CreateAndAppendEffectInstanceByName` to `&partArray[1]` where allocation is `(partCount*0x24)+4`. |
| `+0x48` | `uint32_t` | `delayMs` | `Effect_TickUpdateStateMachine` compares unsigned `elapsedSinceStart` against `this[0x48]` and keeps state `1` while `elapsed<=delay`. |
| `+0x4C` | `int` | `currentFrameIndex` | Updated from sampled frame (`esi[0x13] = sampledFrame`) in `Effect_TickUpdateStateMachine`. |
| `+0x50` | `uint32_t` | `startTickMs` | `timeGetTime() - this[0x50]` in `Effect_TickUpdateStateMachine`. |
| `+0x54` | `int` | `frameScale` | Divisor/multiplier in frame-time formula: `cycleWindow = frameScale*maxFrame + holdOffset`; `sampled = (elapsed%cycleWindow)/frameScale`. |
| `+0x58` | `int` | `repeatCount` | Used in finish threshold: `finishThreshold = repeatCount*cycleWindow - holdOffset`. |
| `+0x5C` | `int` | `holdOffset` | Added into `cycleWindow` and subtracted in finish threshold. |
| `+0x60` | `int` | `templateOffsetXInt` | Loaded at create-time from template `+0x1D4`; consumed by `Effect_RenderWithOffsets` and `Effect_RenderScreenSpace` transform feeds. |
| `+0x64` | `int` | `templateOffsetYInt` | Loaded at create-time from template `+0x1D8`; consumed by `Effect_RenderWithOffsets` and `Effect_RenderScreenSpace` transform feeds. |
| `+0x68` | `int` | `templateOffsetZInt` | Loaded at create-time from template `+0x1DC`; consumed by `Effect_RenderWithOffsets` and `Effect_RenderScreenSpace` transform feeds. |
| `+0x6C` | `int` | `playbackState` | State machine values used in tick/update path (`0/1/2/3/4` transitions in `Effect_TickUpdateStateMachine`). |
| `+0x70` | `byte` | `completionNotifyEnabled` | Set from create arg (`completionNotifyEnabled`); checked by cleanup path before enqueueing completion callback list. |
| `+0x1C` | `float` | `posX` | Used as `this[5]` in `Effect_RenderWithContext` world translate. |
| `+0x20` | `float` | `posY` | Used as `this[6]` in `Effect_RenderWithContext` world translate. |
| `+0x24` | `float` | `posZ` | Used as `this[7]` in `Effect_RenderWithContext` world translate. |
| `+0x2C` | `float` | `rotX` | Used as `this[8]` in `Effect_RenderWithContext` rotation. |
| `+0x30` | `float` | `rotY` | Used as `this[9]` in `Effect_RenderWithContext` rotation. |
| `+0x34` | `float` | `rotZ` | Used as `this[10]` in `Effect_RenderWithContext` rotation. |
| `+0x38` | `float` | `scaleX` | Used as `this[11]` in `Effect_RenderWithContext` scale. |
| `+0x3C` | `float` | `scaleY` | Used as `this[12]` in `Effect_RenderWithContext` scale. |
| `+0x40` | `float` | `scaleZ` | Used as `this[13]` in `Effect_RenderWithContext` scale. |
| `+0x74` | `int[partCount]` | `partSourceBlendModes` | Filled at create-time from effect template `+0xA4[i]` (loaded from 3DEffect layer `source_blend_mode`). |
| `+0xB4` | `int[partCount]` | `partDestinationBlendModes` | Filled at create-time from effect template `+0xE4[i]` (loaded from 3DEffect layer `destination_blend_mode`). |
| `+0xF4` | `int[partCount]` | `partFrameScale100` | Filled at create-time from effect template `+0x124[i]` (`_ftol(frame_rate_scale * 100.0f)`). |
| `+0x154` | `int[partCount]` | `partFrameBaseOffsets` | `Effect_TickUpdateStateMachine` iterates `&this[0x154]` and adds `partFrameBaseOffsets[i]` to each part draw-resource frame count. |
| `+0x194` | `float` | `runtimePositionOffsetX` | Written by `Game3DEffect_SetPositionForSelection` (`0x10009B40`) for selected effect instances. |
| `+0x198` | `float` | `runtimePositionOffsetY` | Written by `Game3DEffect_SetPositionForSelection` (`0x10009B40`) for selected effect instances. |
| `+0x19C` | `float` | `runtimePositionOffsetZ` | Written by `Game3DEffect_SetPositionForSelection` (`0x10009B40`) for selected effect instances. |
| `+0x1A0` | `float` | `runtimeScaleMultiplierX` | Written by `Game3DEffect_SetScaleForSelection` (`0x10009E00`) for selected effect instances. |
| `+0x1A4` | `float` | `runtimeScaleMultiplierY` | Written by `Game3DEffect_SetScaleForSelection` (`0x10009E00`) for selected effect instances. |
| `+0x1A8` | `float` | `runtimeScaleMultiplierZ` | Written by `Game3DEffect_SetScaleForSelection` (`0x10009E00`) for selected effect instances. |
| `+0x1AC` | `float` | `runtimeRotationOffsetX` | Written by `Game3DEffect_SetRotationForSelection` (`0x10009C50`) for selected effect instances. |
| `+0x1B0` | `float` | `runtimeRotationOffsetY` | Written by `Game3DEffect_SetRotationForSelection` (`0x10009C50`) for selected effect instances. |
| `+0x1B4` | `float` | `runtimeRotationOffsetZ` | Written by `Game3DEffect_SetRotationForSelection` (`0x10009C50`) and `Game3DEffect_SetRotationZDegreesForCategorySelection` (`0x10009D60`, `degrees * 0.0174532924f`). |
| `+0x1B8` | `uint32_t` | `renderParam1` | Passed to draw-resource vtable slot `+0x30` in `Effect_RenderWithOffsets` and `Effect_RenderScreenSpace`. |
| `+0x1BC` | `int` | `templateRenderFlag` | Copied at create-time from template `+0x1E0` (loaded from 3DEffect record `render_flag`). |
| `+0x1C0` | `byte` | `templateEnabledFlagBool` | Copied at create-time from template `+0x1E8` (`enabled_flag != 0`). |
| `+0x1C4` | `int` | `fpsClassOrLevelClass` | Read at `this + 452` and passed to `EffectShouldRenderForFPS` by `PartInfo_TickEffectsAndRender`, `PartInfo_RenderEffectsWithOffsetsFiltered`, and `PartInfo_RenderEffectsScreenSpaceFiltered`; populated at create-time from template `+0x1E4` (loaded from 3DEffect `visible_flag`). |
| `+0x1C8` | `uint32_t[3]` | `tripletA` | Fed to draw-resource vtable slot `+0x74` on each rendered part. |
| `+0x1D4` | `uint32_t[3]` | `tripletB` | Fed to draw-resource vtable slot `+0x78` on each rendered part. |
| `+0x1E0` | `int` | `probeOrTickGateFlag` | If non-zero, `Effect_TickUpdateStateMachine` returns `0` immediately (no frame/state updates). |
| `+0x1E4` | `int` | `categoryId` | Runtime unique id assigned from `data_10022E38`; filtered by callers (`... == -1 || *(this+484) == filter`). |
| `+0x1E8` | `uint32_t` | `renderFrameCounter` | Incremented once at end of each successful `Effect_Render*` call; passed as draw arg to draw-resource slot `+0x10`. |
| `+0x1EC` | `char*` | `ownerLabelDup` | Optional duplicated string from create arg via `_strdup`; freed by `EffectInstance_ReleaseResources`; fed to draw-resource slot `+0x0C` in `Effect_RenderWithContext` mesh-bind path. |
| `+0x1F0` | `byte` | `spawnFlagsByte` | Copied from create arg (`arg4`) when provided; fed to draw-resource slot `+0x0C` in `Effect_RenderWithContext` mesh-bind path. |

## Producer mutator write paths (verified)

`Game3DEffect` header-vtable methods write effect-instance runtime fields directly with selector semantics:

- `Game3DEffect_SetPositionForSelection` (`0x10009B40`)
  - `selector == -1`: writes header defaults `this+0x14/+0x18/+0x1C`, returns
  - else writes selected effect `+0x194/+0x198/+0x19C`
  - `selectorIsCategoryId` flag chooses index-vs-category match
- `Game3DEffect_SetRotationForSelection` (`0x10009C50`)
  - `selector == -1`: writes header defaults `this+0x20/+0x24/+0x28`, returns
  - else writes selected effect `+0x1AC/+0x1B0/+0x1B4`
  - `selectorIsCategoryId` flag chooses index-vs-category match
- `Game3DEffect_SetScaleForSelection` (`0x10009E00`)
  - `selector == -1`: writes header defaults `this+0x2C/+0x30/+0x34`, returns
  - else writes selected effect `+0x1A0/+0x1A4/+0x1A8`
  - `selectorIsCategoryId` flag chooses index-vs-category match
- `Game3DEffect_SetRotationZDegreesForCategorySelection` (`0x10009D60`)
  - writes selected effect `+0x1B4 = zDegrees * 0.0174532924f`
  - selector is `categoryIdOrAll` only (no index mode)
- `Game3DEffect_SetRenderParam1ForSelection` (`0x10009F10`)
  - writes selected effect `+0x1B8 = renderParam1`
  - write is gated by `templateEnabledFlagBool` (`effect + 0x1C0 != 0`)
  - supports all/index/category via `selector` + `selectorIsCategoryId`
- `Game3DEffect_SetTripletAForCategorySelection` (`0x1000C970`)
  - writes selected effect `+0x1C8/+0x1CC/+0x1D0`
  - selector is `categoryIdOrAll`
- `Game3DEffect_SetTripletBForCategorySelection` (`0x1000CA20`)
  - writes selected effect `+0x1D4/+0x1D8/+0x1DC`
  - selector is `categoryIdOrAll`
- `Game3DEffect_SetPerPartBlendModesForCategorySelection` (`0x10009FC0`)
  - per selected effect: writes per-part arrays
    - `sourceBlendModes[i]` at `effect + 0x74 + 4*i`
    - `destinationBlendModes[i]` at `effect + 0xB4 + 4*i`
  - selector is `categoryIdOrAll` + optional `partIndexOrAll`

Disassembly anchors:
- `0x10009C1F..0x10009C28` (`+0x194/+0x198/+0x19C`)
- `0x10009D2F..0x10009D38` (`+0x1AC/+0x1B0/+0x1B4`)
- `0x10009EDF..0x10009EE8` (`+0x1A0/+0x1A4/+0x1A8`)
- `0x10009DE2` (`+0x1B4` radians conversion)
- `0x10009F9D` (`+0x1B8`)
- `0x1000C9E5..0x1000C9FA` (`+0x1C8..+0x1D0`)
- `0x1000CA95..0x1000CAAA` (`+0x1D4..+0x1DC`)
- `0x1000A051` and `0x1000A058` (`+0x74`/`+0xB4` per-part streams)

## Per-part record array (36-byte stride)

All three render backends iterate a per-part record list at:

- `partsBase = *(uint8_t**)this + 0x00` (i.e. `*(_DWORD*)this` is treated as a base pointer)
- `part = partsBase + 36 * i`

The record's full layout (including unused/reserved dwords that must still be preserved) is documented in:

- `analysis/conquer_docs/Rendering/role3d_dll/11_effect_part_record_layout.md`

## Per-part byte streams embedded in the effect instance

The render backends also read two per-part byte arrays embedded directly in the effect instance object:

- `byteStreamA[i]` at `((uint8_t*)this) + 0x134 + i` (offset `+308`)
  create source: effect template `+0x1A4[i]` (`reserved_flag_0 != 0` from 3DEffect layer)
- `byteStreamB[i]` at `((uint8_t*)this) + 0x144 + i` (offset `+324`)
  create source: effect template `+0x1B4[i]` (`reserved_flag_1` from 3DEffect layer)

These bytes are passed into the resource object draw call as small per-part parameters:

- When `templateRenderFlag != 0`, code uses an accumulator pointer and substitutes `byteStreamB[i] = 1` if source byte is `0`.
- When `templateRenderFlag == 0`, code passes raw `byteStreamB[i]` and null accumulator pointer.

The exact meaning of these bytes should be named once the target resource object interface is fully documented (they are consumed by the resource object's virtual draw method).
