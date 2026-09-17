# `c3_core_dll.dll` — motion matrix sampling and blend parity

This document captures the verified runtime sampling logic for:

- `C3Motion_GetBoneMatrixAtFrame` (`0x10009A20`)
- `C3MotionTracker_GetBlendedBoneMatrixAtFrame` (`0x10009E70`)

Supporting helpers:

- `Matrix4x4_AddElementwise` (`0x1000B520`)
- `Matrix4x4_CreateFromElements` (`0x1000B4A0`)

## `C3Motion_GetBoneMatrixAtFrame`

Signature (BNinja deob):

```
void C3Motion_GetBoneMatrixAtFrame(
    const C3Motion* motion,
    uint32_t boneIndex,
    int32_t framePosition,
    D3DXMATRIX* outMatrix)
```

Behavior:

1. If `motion == null` or `boneIndex >= motion->boneCount`, writes identity matrix.
2. Let `keys = motion->keyframes`.
3. If `framePosition <= keys[0].keyFrameIndex`, copies `keys[0]` bone matrix.
4. Else if `framePosition >= keys[last].keyFrameIndex`, copies `keys[last]` bone matrix.
5. Else finds interval `[prev,next)` where:
   - `keys[prev].keyFrameIndex <= framePosition < keys[next].keyFrameIndex`
6. Computes:
   - `t = (framePosition - prevKey) / (nextKey - prevKey)` as float
   - `out = (1 - t) * prevMatrix + t * nextMatrix` element-wise over all 16 floats

Important parity note:

- No quaternion/matrix decomposition is done here.
- No orthonormalization is done here.
- Interpolation is plain element-wise float lerp of the full 4x4 matrix.

## `C3MotionTracker_GetBlendedBoneMatrixAtFrame`

BNinja deob prototype:

```
void C3MotionTracker_GetBlendedBoneMatrixAtFrame(
    const C3MotionBlendPair* motionPair,
    uint32_t boneIndex,
    D3DXMATRIX* outMatrix)
```

`C3MotionBlendPair` first two fields:

- `primaryMotion`
- `secondaryMotion`

Behavior:

1. If `primaryMotion == null`, returns without writing `outMatrix`.
2. If `secondaryMotion == null`, samples:
   - `C3Motion_GetBoneMatrixAtFrame(primaryMotion, boneIndex, primaryMotion->primarySampleFramePosition, outMatrix)`
3. Else:
   - sample primary using `primarySampleFramePosition`
   - sample secondary using `secondarySampleFramePosition`
   - read `w = secondaryMotion->blendAlpha`
   - blend element-wise:
     - `out = (1 - w) * primary + w * secondary`

No blend-weight clamping was observed in this function.

## Helper semantics

`Matrix4x4_AddElementwise(left, out, right)`:

- `out[i] = left[i] + right[i]` for `i = 0..15`

`Matrix4x4_CreateFromElements(out, m11..m44)`:

- Writes the 16 passed floats directly into contiguous matrix memory.

Both are used as value-construction helpers around the weighted blend terms.

## Struct layouts (verified BNinja 2026-03-15)

### `C3Motion` (32 bytes)

| Offset | Type | Field |
|--------|------|-------|
| `+0x00` | `uint32_t` | `boneCount` |
| `+0x04` | `uint32_t` | `frameCount` |
| `+0x08` | `uint32_t` | `keyFrameCount` |
| `+0x0C` | `C3MotionKeyframeEntry*` | `keyframes` |
| `+0x10` | `int32_t` | `primarySampleFramePosition` |
| `+0x14` | `int32_t` | `secondarySampleFramePosition` |
| `+0x18` | `float` | `blendAlpha` |
| `+0x1C` | `uint32_t` | `nameHash` |

### `C3MotionKeyframeEntry` (8 bytes)

| Offset | Type | Field |
|--------|------|-------|
| `+0x00` | `uint32_t` | `keyFrameIndex` |
| `+0x04` | `D3DXMATRIX*` | `boneMatrices` (array of `boneCount` × 4×4 float matrices) |

Bone matrix access: `keyframes[keyIdx].boneMatrices + (boneIndex << 6)` — each bone matrix is 64 bytes (16 floats).

### `C3MotionBlendPair` (used by `C3MotionTracker_GetBlendedBoneMatrixAtFrame`)

| Offset | Type | Field |
|--------|------|-------|
| `+0x00` | `C3Motion*` | `primaryMotion` |
| `+0x04` | `C3Motion*` | `secondaryMotion` |

The blend pair provides two C3Motion pointers. Each C3Motion carries its own frame position and blend alpha. The blend function reads `secondaryMotion->blendAlpha` for the interpolation weight.

### Managed parity

`C3MotionMatrixSampler` in `Conquer.Assets.Mesh` implements exact parity:
- `TrySampleBoneMatrixAtFrame` — keyframe binary search + element-wise matrix LERP
- `TrySampleBlendedBoneMatrix` — primary/secondary blend with `(1 - alpha) * primary + alpha * secondary`
