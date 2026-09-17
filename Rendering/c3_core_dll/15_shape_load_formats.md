# `c3_core_dll.dll` — `C3Shape_LoadFromStream` (`SHAP`) payload format

Verified `SHAP` payload decode behaviour in:

- `C3Shape_LoadFromStream` (`0x10014E90`)
- `C3Shape_ConfigureSegmentTrail` (`0x10015060`)

Verified in BNinja (`C3_CORE_DLL.dll.bndb`) with deobfuscated names/types.

## Function set and roles

- `C3Shape_Reset` (`0x10014E60`)
- `C3Shape_LoadFromStream` (`0x10014E90`)
- `C3Shape_Unload` (`0x10014FE0`)
- `C3Shape_ConfigureSegmentTrail` (`0x10015060`)
- `C3Shape_Draw` (`0x100150B0`)
- `C3Shape_SetFrameIndex` (`0x10015830`)
- `C3Shape_AdvanceFrame` (`0x10015810`)

`graphic.dll` dispatches `SHAP` chunks to this loader from
`C3Effect_LoadFromResource` and passes `forceTwoPointSets = 0`.

## `C3Shape` runtime layout (verified fields)

- `+0x00` `pointSetCount` (`uint32`)
- `+0x04` `pointSets` (`C3ShapePointSet*`)
- `+0x08` `textureId` (`int32`)
- `+0x0C` `simpleMotion` (`C3SMotion*`)
- `+0x10` `trailVertexBuffer` (`IDirect3DVertexBuffer8*`)
- `+0x14` `trailSegmentSampleCount` (`uint32`)
- `+0x18` `trailVertexCapacity` (`uint32`)
- `+0x1C` `trailActiveVertexCount` (`uint32`)
- `+0x20` `trailSubdivisionStep` (`uint32`)
- `+0x24` `warmupResetFlag` (`uint32`)
- `+0x28..0x3C` cached trail endpoints (`float`)

`C3ShapePointSet`:

- `+0x00` `declaredPointCount` (`uint32`)
- `+0x04` `points` (`D3DXVECTOR3*`)

## Stream format (`SHAP` payload body)

`C3Shape_LoadFromStream` reads:

1. `uint32 shapeNameLength`
2. `shapeNameLength` bytes (seek/skip only)
3. `uint32 pointSetCount`
4. Repeated `pointSetCount` times:
   - `uint32 declaredPointCount`
   - `D3DXVECTOR3[declaredPointCount]` (12 bytes each)
   - if `forceTwoPointSets == 0`, runtime overwrites stored point count to `2`
5. `uint32 texturePathLength`
6. `texturePathLength` bytes (seek/skip only)
7. `uint32 segmentCountRaw`
8. `segmentCountNormalized = (segmentCountRaw == 0) ? 1 : segmentCountRaw`
9. call `C3Shape_ConfigureSegmentTrail(shape, segmentCountNormalized, 1)`

Then increments `g_nShapeCount` and returns success iff `trailVertexBuffer != null`.

## `C3Shape_ConfigureSegmentTrail` derived values

Given `segmentCountNormalized`:

- `trailSegmentSampleCount = min(segmentCountNormalized * 5, 0x320)`
- `trailVertexCapacity = trailSegmentSampleCount + 1`
- `trailSubdivisionStep = 5`
- `trailActiveVertexCount = 0`
- allocates vertex buffer bytes: `trailVertexCapacity * 0x30`

## Runtime link to simple-motion data

`C3Shape_Draw` uses `shape->simpleMotion` (when present) and fetches:

- `simpleMotion->frameMatrices + (currentFrameIndex << 6)` (64-byte matrix stride)

`graphic.dll` sets this pointer post-load:

- `shapeSlots[i]->simpleMotion = simpleMotionSlots[i]`

## Real-file evidence (clean 5517 client)

Verified `SHAP` chunk payload structure in:

- `00_clean/clean/5517/c3/effect/arrow/500029/1.C3`
- `00_clean/clean/5517/c3/effect/weapon/601129/4.C3`
- `00_clean/clean/5517/c3/effect/skill/meteor/1/1.C3`
