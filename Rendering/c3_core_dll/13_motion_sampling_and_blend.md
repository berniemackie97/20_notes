# `c3_core_dll.dll` — motion matrix sampling and blend parity

## 2026-11-02: Studio importer range and validity clarification

Fresh raw-assembly verification used the existing `C3_CORE_DLL.dll.bndb`, view 21.
Every displayed instruction byte was compared against the clean input DLL:
SHA-256 `f5bbe1d408320de33c17422b58576d3e883fa6f93830fe159ac27f3396551a7b`.
The [capture and verification manifest](../evidence/studio-motion-contract-2026-11-02/verification.json)
retains 298 sampler instructions and 214 blend instructions. This was static
verification; no native process was executed and no BNDB was saved.

New precision beyond the earlier high-level description:

- The first-key boundary at `0x10009A59` uses `cmp edx,ebp` followed by signed
  `jg` at `0x10009A5B`. The last-key boundary at `0x10009A64` uses signed `jl`
  at `0x10009A68`. Interior interval tests at `0x10009A7F..0x10009A86` also use
  signed `jl`. Serialized DWORD key-index width does not imply unsigned comparison
  semantics in this consumer.
- `motion+0x0C` is loaded at `0x10009A4A`, and the first key is dereferenced at
  `0x10009A54`, before reading `keyFrameCount` at `0x10009A61`. There is no
  preceding nonempty-key guard on the valid-motion/valid-bone path. This does
  not establish how every caller validates its input.
- The sampler has a plain `ret` and its caller releases four arguments with
  `add esp,0x10` at `0x10009EA9`. Keep the four-argument caller-cleaned ABI.
- Full-matrix interpolation remains confirmed: the fraction is formed at
  `0x10009B00..0x10009B35`; both matrices are multiplied component by component,
  combined through `Matrix4x4_AddElementwise`, and copied as 16 DWORDs at
  `0x10009E0A..0x10009E11`. No quaternion decomposition is present in this path.

Studio consequences are design constraints, not claims of implemented support:

1. Validate key presence, bounded counts, nonnegative supported frame ranges,
   and strictly increasing keys before constructing an imported motion resource.
   Reject inputs outside that explicit import policy rather than relying on native
   out-of-contract behavior. The native routine itself does not enforce this policy.
2. Preserve a full 4x4 matrix-track representation with declared element-wise
   interpolation. A TRS/quaternion-only saved model cannot automatically preserve
   this sampling behavior.
3. Any resampling, decomposition, reduction, or GPU representation change needs
   measured pose/error conformance before compiled assets replace client motion data.
4. This sampling evidence does not establish a serialized bone-name table,
   parent hierarchy, complete character composition, or world placement contract.

The existing function comments were retained. Three focused address comments were
added in memory for the key-pointer and signed boundary observations.

Verified runtime sampling logic for:

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

## Studio corpus check: body and attachment clip lengths (2026-11-03)

The source body-2 initial-idle MOTI has 16 frames; the selected hair-335 embedded
MOTI has 61. Paths, SHA-256 hashes and section offsets are recorded in
[`studio-c3-clock-2026-11-03.json`](../evidence/studio-c3-clock-2026-11-03.json).
This is source-file metadata, not a new native control-flow finding. WORLD-021/022
use the primary body action as the shared clock; choosing the maximum frame count
across body and attachment would extend body idle incorrectly. Studio now tests
that case while preserving the attachment's complete original motion data.
