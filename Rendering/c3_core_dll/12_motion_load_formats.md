# `c3_core_dll.dll` — `C3Motion_LoadFromStream` payload formats

The verified on-disk `MOTI` payload decode performed by
`C3Motion_LoadFromStream` (`0x100092F0`).

Verified in BNinja (`C3_CORE_DLL.dll.bndb`) after deobfuscation and type cleanup.

## Function set and roles

- `C3Motion_Reset` (`0x100092D0`)
- `C3Motion_LoadFromStream` (`0x100092F0`)
- `C3Motion_Unload` (`0x100099A0`)
- `C3Motion_GetBoneMatrixAtFrame` (`0x10009A20`)

`graphic.dll` motion tracker loading calls into this path for each `MOTI` chunk
payload extracted from a `.C3` container.

## `C3Motion` runtime layout

Verified field usage in this slice:

- `+0x00` `boneCount` (`uint32`)
- `+0x04` `frameCount` (`uint32`)
- `+0x08` `keyFrameCount` (`uint32`)
- `+0x0C` `keyframes` (`C3MotionKeyframeEntry*`)
- `+0x10` `primarySampleFramePosition` (`int32`) runtime sampling state
- `+0x14` `secondarySampleFramePosition` (`int32`) runtime sampling state
- `+0x18` `blendAlpha` (`float`) runtime blend weight
- `+0x1C` `nameHash` (`uint32`) written by `graphic.dll` when optional name hash is enabled

`C3MotionKeyframeEntry`:

- `+0x00` `keyFrameIndex` (`uint32`)
- `+0x04` `boneMatrices` (`D3DXMATRIX*`) with `boneCount` entries

`C3Motion_LoadFromStream` writes the static keyframe payload fields and leaves
sampling/blend state fields at zero (after `C3Motion_Reset`).

## Stream format (`MOTI` payload body)

Common prefix:

1. `uint32 boneCount`
2. `uint32 frameCount`
3. `uint32 keyEncodingTag`

Guard:

- If `boneCount > 1000`, load fails.

### `KKEY` branch

Tag bytes: `4B 4B 45 59`.

1. `uint32 keyCount`
2. Repeat `keyCount`:
   - `uint32 keyFrameIndex`
   - `D3DXMATRIX[boneCount]` (raw 64-byte matrices)

### `ZKEY` branch

Tag bytes: `5A 4B 45 59`.

1. `uint32 keyCount`
2. Repeat `keyCount`:
   - `uint16 keyFrameIndex` (zero-extended to `uint32`)
   - Repeat `boneCount`:
     - `float quat[4]` (`x,y,z,w`)
     - `float position[3]` (`x,y,z`)
3. For each bone record, loader expands to a 4x4 matrix:
   - rotation from quaternion (`D3dxQuaternionToMatrix_ImportJump`)
   - translation written to `M41/M42/M43`
   - `M44 = 1.0`

### `XKEY` branch

Tag bytes: `58 4B 45 59`.

1. `uint32 keyCount`
2. Repeat `keyCount`:
   - `uint16 keyFrameIndex` (zero-extended to `uint32`)
   - Repeat `boneCount`:
     - `float affine3x4[12]`
3. Loader expands each 12-float record into a 4x4 matrix:
   - `M14 = M24 = M34 = 0`
   - `M44 = 1.0`
   - translation sourced from final three floats (`M41/M42/M43`)

### Fallback branch (unknown tag)

If tag is not `KKEY`, `ZKEY`, or `XKEY`:

1. Seeks stream by `-4` (rewind to where tag bytes started)
2. Uses `keyCount = frameCount`
3. Allocates `keyCount` entries with implicit key indices `0..keyCount-1`
4. Reads matrices in interleaved order:
   - outer loop: `boneIndex`
   - inner loop: `keyIndex`
   - body: one 64-byte matrix write into `[keyIndex][boneIndex]`

## Trailing section

After key payload decoding:

1. Read `int32 extraSectionCount`
2. Branch condition is unsigned (`if ((uint32)extraSectionCount > 0)`).
3. When taken, relative stream seek uses signed 32-bit arithmetic:
   - `seekDeltaBytes = ((int32)frameCount * extraSectionCount) << 2`
   - arithmetic wraps at 32-bit width (native `imul` + `shl`)
   - `seekDeltaBytes` can be positive, zero, or negative depending on values

Then increments global motion counter and returns success.

## Real-file evidence (clean 5517 client)

Verified tag presence in real files:

- `KKEY`: `00_clean/clean/5517/c3/npc/523/1.C3`
- `ZKEY`: `00_clean/clean/5517/c3/2004/410/702.C3`
- `XKEY`: `00_clean/clean/5517/c3/monster/208/401.C3`
