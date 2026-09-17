# `c3_core_dll.dll` — particle draw sampling semantics

Verified in BNinja (`C3_CORE_DLL.dll.bndb`) from:

- `C3ParticleType12_SetFrameIndex` (`0x10013070`)
- `C3ParticleType12_AdvanceFrame` (`0x10013040`)
- `C3ParticleType3_Draw` (`0x10012230`)

This document records only scalar/runtime math that is fully visible in disassembly and now implemented in `Conquer.Assets`.

## Frame index normalization

From `C3ParticleType12_SetFrameIndex`:

- if `timelineFrameCount == 0`: `currentFrameIndex = 0`
- else: `currentFrameIndex = requestedFrameIndex % timelineFrameCount` (unsigned modulo)

From `C3ParticleType12_AdvanceFrame`:

- if `timelineFrameCount == 0`: `currentFrameIndex = 0`
- else: `currentFrameIndex = (currentFrameIndex + frameDelta) % timelineFrameCount` (unsigned add + modulo)

## Type-3 frame envelope (`+0x30..+0x40`)

`C3ParticleType3_Draw` computes a frame-driven scalar using:

- values: `frameEnvelopeStart` (`+0x30`), `frameEnvelopeMiddle` (`+0x34`), `frameEnvelopeEnd` (`+0x38`)
- frame boundaries: `frameEnvelopeRampInEndFrame` (`+0x3C`), `frameEnvelopeRampOutStartFrame` (`+0x40`)
- current frame: `currentFrameIndex` (`+0x14`)
- stream frame count: `timelineFrameCount` (`+0x18`)

Piecewise behavior:

1. if `currentFrameIndex < frameEnvelopeRampInEndFrame`:
   - `t = currentFrameIndex / frameEnvelopeRampInEndFrame`
   - `v = lerp(frameEnvelopeStart, frameEnvelopeMiddle, t)`
2. else if `currentFrameIndex < frameEnvelopeRampOutStartFrame`:
   - `v = frameEnvelopeMiddle`
3. else:
   - `t = (currentFrameIndex - frameEnvelopeRampOutStartFrame) / (timelineFrameCount - frameEnvelopeRampOutStartFrame)`
   - `v = lerp(frameEnvelopeMiddle, frameEnvelopeEnd, t)`

Then clamp with x87 compare behavior:

- NaN or `< 0` => `0`
- `> 1` => `1`
- else unchanged

## Type-3 sample envelope (`+0x44..+0x54`)

Per sample, `C3ParticleType3_Draw` reinterprets `sampleValuesA[i]` as float and computes:

- values: `sampleEnvelopeStart` (`+0x44`), `sampleEnvelopeMiddle` (`+0x48`), `sampleEnvelopeEnd` (`+0x4C`)
- boundaries: `sampleEnvelopeRampInEnd` (`+0x50`), `sampleEnvelopeRampOutStart` (`+0x54`)

Piecewise behavior:

1. if `sample < sampleEnvelopeRampInEnd`:
   - `t = sample / sampleEnvelopeRampInEnd`
   - `u = lerp(sampleEnvelopeStart, sampleEnvelopeMiddle, t)`
2. else if `sample < sampleEnvelopeRampOutStart`:
   - `u = sampleEnvelopeMiddle`
3. else:
   - `t = (sample - sampleEnvelopeRampOutStart) / (1 - sampleEnvelopeRampOutStart)`
   - `u = lerp(sampleEnvelopeMiddle, sampleEnvelopeEnd, t)`

Comparison parity note: x87 `fcomp` + `test ah, 1` treats unordered (NaN) as the `<` branch.

## Final alpha byte

`C3ParticleType3_Draw` multiplies both envelopes:

- `combined = frameEnvelope * sampleEnvelope`

Then clamps + converts to byte:

- if `combined > 1` => `255`
- else if `combined <= 0` => `0`
- else `alpha = _ftol(combined * 255.0f)`

Observed conversion parity is implemented as round-to-nearest-even (`_ftol` equivalent).

## Type-3 transform cache orientation (`mode == 1 || mode == 4`)

Verified from `C3ParticleType3_Draw` (`0x10012748..0x100127fe`) and helper calls:

- `RbTreeLowerBoundByIntKey` (`0x100145f0`)
- `RbTreeInsertOrFindIntKey` (`0x100143b0`)
- `RbTreeIteratorPairCopy` (`0x10014750`)
- `Vec3StoreXYZ` (`0x10013020`)

On a cache hit, the payload pointer is `cacheNode + 0x10`, and this branch uses:

- `+0x44..+0x4C`: cached previous sample position
- `+0x50..+0x58`: cached normalized orientation vector
- `+0x60`: cached per-sample rotation scalar

Behavior for `transformMode in {1, 4}`:

1. Compare current transformed sample position (`x,y,z`) against cached `+0x44/+0x48/+0x4C`.
2. If any component comparison does not have x87 `C3` set, recompute orientation:
   - `delta = current - cachedPrevious`
   - `cachedOrientation = normalize(delta)` written to `+0x50/+0x54/+0x58`
3. Else, reuse cached orientation from `+0x50/+0x54/+0x58`.
4. Always write current position back to `+0x44/+0x48/+0x4C`.
5. Load rotation scalar from `+0x60`.

For a cache miss in `transformMode in {1, 4}`, after insertion the function jumps directly to loop advance (`0x10012dbc`) and does not emit geometry for that sample in that iteration.

### Cache-miss initialization (`0x10012818..0x10012968`)

On cache miss, `C3ParticleType3_Draw` initializes a cache payload (`cacheNode + 0x10`, 0x64 bytes):

- `+0x40` active flag = `1`
- `+0x44..+0x4C` previous sample position = current transformed sample position
- `+0x50..+0x58` cached orientation vector = `(0,0,0)` on first insert
- `+0x5C` last-touched tick = `timeGetTime()` sampled at function start
- `+0x60` cache-miss rotation scalar (formula below)

Cache-miss rotation scalar formula (verified from x87 sequence at `0x1001286e..0x1001289f`):

- `rotationRandomRangeMin = -rotationAngleRandomRange`
- `randomUnit = randomInteger * 0.001f`
- `randomOffset = ((rotationAngleRandomRange - rotationRandomRangeMin) * randomUnit) + rotationRandomRangeMin`
- `cacheMissRotationScalar = randomOffset + rotationAngleBase`

`randomInteger` comes from the call at `0x1001286e` (modeled as rand-like integer source).

`useAlternateTransformBasis` (`+0x24`) behavior on miss:

- if non-zero, the current frame transform matrix is copied into cache payload matrix bytes (`+0x00..+0x3F`)
- if zero, this matrix copy branch is skipped (runtime path uses current frame matrix directly on hit)

Cache-miss render behavior by mode:

- `transformMode in {1,4}`: miss sample is not emitted in that frame (`0x1001294d -> 0x10012dbc`)
- all other modes: miss sample continues into emission path using `cacheMissRotationScalar`

### Post-draw cache sweep (`0x10012e0a..0x10012ea5`)

After sample iteration completes, `C3ParticleType3_Draw` sweeps the RB-tree cache:

1. If entry active flag (`payload + 0x40`) is non-zero:
   - set it to zero
   - keep entry
2. If entry active flag is zero:
   - erase entry from RB tree (`RbTreeEraseAtIterator_IntKey`)

This yields one-frame liveness:

- touched this draw -> retained, but flagged inactive for next draw
- untouched for one full draw -> erased

## Type-3 basis construction (`0x10012968..0x10012b3e`)

Angle generation:

- `angleRadians = (currentFrameIndex * rotationScalar * PI) / 180.0f`
- `sin/cos` produced via `fsincos`.

Let:

- `B = (bx, by, bz)` = orientation vector (`var_2c,var_28,var_24`)
- `A = (ax, ay, az)` = mode-dependent reference vector (`var_48,var_44,var_40`)

### Mode-dependent source for `A` and `B`

Branch split at `0x100129a1..0x100129b0`:

- if `transformMode in {1, 4}` -> `0x10012a44` path
- else -> `0x100129b6` path

Verified source vectors:

1. `transformMode in {1, 4}` (`0x10012a44`):
   - `A = normalize(mode14ReferencePosition - currentSamplePosition)`
   - `mode14ReferencePosition` comes from runtime globals:
     - `g_ParticleType3_Mode14ReferencePositionX` (`0x100b03c8`)
     - `g_ParticleType3_Mode14ReferencePositionY` (`0x100b03c4`)
     - `g_ParticleType3_Mode14ReferencePositionZ` (`0x100b03c0`)
   - `B` is the orientation value already prepared by the cache path (`+0x50..+0x58` on cache entry).

2. `transformMode not in {1, 4}` (`0x100129b6`):
   - `B` is loaded directly from runtime globals:
     - `g_ParticleType3_DefaultOrientationVectorX` (`0x100b030c`)
     - `g_ParticleType3_DefaultOrientationVectorY` (`0x100b031c`)
     - `g_ParticleType3_DefaultOrientationVectorZ` (`0x100b032c`)
   - `A` is loaded as negated globals:
     - `A.x = -g_ParticleType3_DefaultReferenceVectorX` (`0x100b0310`)
     - `A.y = -g_ParticleType3_DefaultReferenceVectorY` (`0x100b0320`)
     - `A.z = -g_ParticleType3_DefaultReferenceVectorZ` (`0x100b0330`)

### Matrix-component provenance for the nine runtime globals

All nine globals above alias components of exported matrices in `c3_core_dll`:

- `g_ParticleType3_DefaultOrientationVector*` map to `g_ViewMatrix`:
  - `x/y/z` = `(_12, _22, _32)` at `0x100b030c/0x100b031c/0x100b032c`
- `g_ParticleType3_DefaultReferenceVector*` map to `g_ViewMatrix`:
  - `x/y/z` = `(_13, _23, _33)` at `0x100b0310/0x100b0320/0x100b0330`
- `g_ParticleType3_Mode14ReferencePosition*` map to `g_InvViewMatrix`:
  - `x/y/z` = `(_41, _42, _43)` at `0x100b03c0/0x100b03c4/0x100b03c8`

Writer chain verified end-to-end:

1. `graphic.dll` camera APIs (`CMyBitmap::GameCameraBuild*`, `GameCameraMove/Rotate/Circum/Pitch`, `CameraLook`) call imported `Camera_BuildView`.
2. `c3_core_dll::Camera_BuildView` builds `g_ViewMatrix`, computes `g_InvViewMatrix`, and sets the device view transform.
3. `C3ParticleType3_Draw` reads the matrix components above when resolving type-3 basis vectors.

All nine globals are zero-initialized in the file image and read-only in `C3ParticleType3_Draw`; runtime values are injected through the camera writer path above.

The first orthogonal vector is:

- `C = B x A`
- `cx = (az * by) - (ay * bz)`
- `cy = (ax * bz) - (az * bx)`
- `cz = (ay * bx) - (ax * by)`

The second orthogonal vector is:

- `D = C x B`
- `dx = (cz * by) - (cy * bz)`
- `dy = (cx * bz) - (cz * bx)`
- `dz = (cy * bx) - (cx * by)`

This produces the per-sample billboard basis vectors consumed by the subsequent vertex write path.

## Type-3 corner scalar and corner-vector transform stage (`0x10012968..0x10012d48`)

Verified from raw disassembly (`0x10012968..0x10012bbd`, `0x10012c6b..0x10012d48`):

1. `fsincos` output storage order:
   - `cos` stored at `[ebp-0x5c]`
   - `sin` stored at `[ebp-0x64]`
2. Frame rotation angle:
   - `angleRadians = (currentFrameIndex * rotationScalar * PI) / 180.0f`
3. Corner scalar magnitudes (`sampleScale = reinterpret_float(sampleValuesB[i])`):
   - `cornerScaleA = (sin + cos) * rotationScalar * sampleScale`
   - `cornerScaleB = (cos - sin) * rotationScalar * sampleScale`
4. Local corner vectors before basis transform:
   - `localCornerA = (-cornerScaleB, -cornerScaleA, 0)`
   - `localCornerB = ( cornerScaleA, -cornerScaleB, 0)`
5. Corner transform matrix rows (written at `[ebp-0x114]`):
   - row1: `C` (`firstCross`)
   - row2: `B` (`orientation`)
   - row3: `D` (`secondCross`)
   - row4: `(0,0,0,1)`
6. Both local corners are transformed through `RuntimeDispatch_Vec3TransformCoord` before vertex emission.

This stage is now implemented in `Conquer.Assets` as typed runtime APIs:

- `ComputeType3CornerScales`
- `ComputeType3LocalCornerVectors`
- `BuildType3CornerTransformMatrix`
- `TransformType3CornerVectors`
- `ComputeType3TransformedCornerVectors`

## Type-3 vertex emission contract (`0x10012c97..0x10012db6`)

Verified in `C3ParticleType3_Draw` from raw disassembly and decompiled SSA.

Per rendered sample, native code writes exactly 4 vertices at 24-byte stride (`XYZ + ARGB + UV`):

- `+0x00` float `x`
- `+0x04` float `y`
- `+0x08` float `z`
- `+0x0C` uint32 diffuse color (ARGB)
- `+0x10` float `u`
- `+0x14` float `v`

Quad write order in one sample block (`0x60` bytes total):

1. vertex0 at `base + 0x00`
2. vertex1 at `base + 0x48`
3. vertex2 at `base + 0x18`
4. vertex3 at `base + 0x30`

Equivalent semantic order:

- `vertex0 = center + transformedCornerVectorA`
- `vertex1 = center - transformedCornerVectorA`
- `vertex2 = center + transformedCornerVectorB`
- `vertex3 = center - transformedCornerVectorB`

This is now implemented as typed emission in `Conquer.Assets` (`EmitType3QuadVertices`).

## Type-3 UV tile mapping (`0x10012566..0x100125d7`, `0x10012cc2..0x10012d1f`)

Verified flow:

1. `uvStep = 1.0f / uvFrameDivisor`
2. `uvFrameIndex = _ftol(sampleControlFloat * (uvFrameDivisor * uvFrameDivisor))`
3. unsigned split:
   - `frameColumn = uvFrameIndex % uvFrameDivisor`
   - `frameRow = uvFrameIndex / uvFrameDivisor`
4. tile coordinates:
   - `u0 = frameColumn * uvStep`
   - `v0 = frameRow * uvStep`
   - `u1 = u0 + uvStep`
   - `v1 = v0 + uvStep`

Per-vertex UVs in native order:

- `vertex0: (u0, v1)`
- `vertex1: (u1, v0)`
- `vertex2: (u1, v1)`
- `vertex3: (u0, v0)`

## Type-3 diffuse color packing (`0x10012c57..0x10012cab`)

After envelope multiply+clamp, alpha byte is produced via `_ftol(combined * 255.0f)` and packed as:

- `packedColorArgb = (alphaByte << 24) | 0x00FFFFFF`

Implemented in `PackType3DiffuseColorArgb`.

## Type-3 indexed draw batching (`0x10012f3d..0x10013005`)

Verified draw plan from emitted quad count `emittedQuadCount` (`var_6c`):

- `fullBatchCount = emittedQuadCount >> 8` (256 quads per full batch)
- `tailQuadCount = emittedQuadCount & 0xFF`

For each full batch:

- `SetIndices(ParticleQuadIndexBuffer_GetOrCreate(...), baseVertexIndex = batchIndex * 0x400)`
- `DrawIndexedPrimitive(D3DPT_TRIANGLELIST, minIndex=0, numVertices=0x400, startIndex=0, primitiveCount=0x200)`

For tail batch (if `tailQuadCount > 0`):

- `baseVertexIndex = fullBatchCount * 0x400`
- `numVertices = tailQuadCount * 4`
- `primitiveCount = tailQuadCount * 2`

Shared index-buffer helper chain for this path is now deobfuscated as:

- `ParticleQuadIndexTemplate_EnsureInitialized`
- `ParticleQuadIndexBuffer_GetOrCreate`
- `g_particleQuadIndexTemplate`
- `g_particleQuadIndexBuffer`
