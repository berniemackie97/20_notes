# `Phy_*` routines

The `Phy_*` API in `c3_core_dll.dll`, as the client uses it.

## Exported entry points

- ordinal `65` `0x1000C7B0` `?Phy_Calculate@@YAHPAUC3Phy@@HHUD3DXVECTOR3@@@Z`
- ordinal `66` `0x1000BAE0` `?Phy_Calculate_CPU@@YAHPAUC3Phy@@HHUD3DXVECTOR3@@_N@Z`
- ordinal `67` `0x1000C630` `?Phy_Calculate_Lite@@YAHPAUC3Phy@@@Z`
- ordinal `68` `0x1000E100` `?Phy_ChangeMixTexture@@YAXPAUC3Phy@@H@Z`
- ordinal `69` `0x1000E0F0` `?Phy_ChangeTexture@@YAXPAUC3Phy@@H@Z`
- ordinal `70` `0x1000A1C0` `?Phy_Clear@@YAXPAUC3Phy@@@Z`
- ordinal `71` `0x1000DFC0` `?Phy_ClearMatrix@@YAXPAUC3Phy@@@Z`
- ordinal `72` `0x1000DC00` `?Phy_DrawNormal@@YAHPAUC3Phy@@ABU_D3DMATERIAL8@@ABUC3_TEX_SHADER_DESC@@ABUC3_PIPE_RENDER_DESC@@PBUC3_SHADOW_RENDER_DESC@@@Z`
- ordinal `73` `0x1000CC90` `?Phy_DrawNormal_CPU@@YAHPAUC3Phy@@ABU_D3DMATERIAL8@@ABUC3_TEX_SHADER_DESC@@ABUC3_PIPE_RENDER_DESC@@PBUC3_SHADOW_RENDER_DESC@@@Z`
- ordinal `74` `0x1000DC30` `?Phy_DrawUp@@YAHPAUPhyOutVertex@@PAGKKPAUC3Texture@@PBU_D3DMATERIAL8@@ABUC3_PIPE_RENDER_DESC@@H@Z`
- ordinal `75` `0x1000E7E0` `?Phy_DynamicCreate@@YAPAUC3Phy@@KPAUD3DXVECTOR3@@PAUD3DXVECTOR2@@@Z`
- ordinal `76` `0x1000EC00` `?Phy_GetFaceProperty@@YAEPAUC3Phy@@H@Z`
- ordinal `77` `0x1000C9D0` `?Phy_LightEnable@@YAXHH@Z`
- ordinal `78` `0x1000A300` `?Phy_Load@@YAHPAPAUC3Phy@@PAXHHH@Z`
- ordinal `79` `0x1000EBA0` `?Phy_LoadFaceProperty@@YA_NPAUC3Phy@@PAX@Z`
- ordinal `80` `0x1000DF70` `?Phy_Muliply@@YAXPAUC3Phy@@PBUD3DXMATRIX@@@Z`
- ordinal `81` `0x1000B9A0` `?Phy_Prepare@@YAXXZ`
- ordinal `82` `0x1000E110` `?Phy_ProbeIntersection@@YA_NPAUC3Phy@@ABUD3DXVECTOR3@@1_NAAMPAH@Z`
- ordinal `83` `0x1000DF20` `?Phy_SetBlendFrame@@YAXPAUC3Phy@@K@Z`
- ordinal `84` `0x1000EC40` `?Phy_SetCartoonSilhouetteColor@@YAXK@Z`
- ordinal `85` `0x1000EC30` `?Phy_SetCartoonSilhouetteWidth@@YAXM@Z`
- ordinal `86` `0x1000DF90` `?Phy_SetColor@@YAXPAUC3Phy@@MMMM@Z`
- ordinal `87` `0x1000CC70` `?Phy_SetFluidReflectSpeed@@YAXMM@Z`
- ordinal `88` `0x1000DEF0` `?Phy_SetFrame@@YAXPAUC3Phy@@K@Z`
- ordinal `89` `0x1000C7F0` `?Phy_SetLight@@YAXHMMMKKM@Z`
- ordinal `90` `0x1000CAF0` `?Phy_SetLightAmbient@@YAXHK@Z`
- ordinal `91` `0x1000CA20` `?Phy_SetLightDiffuse@@YAXHK@Z`
- ordinal `92` `0x1000C9F0` `?Phy_SetLightDir@@YAXHMMM@Z`
- ordinal `93` `0x1000CBC0` `?Phy_SetLightPosition@@YAXHMMM@Z`
- ordinal `94` `0x1000CC50` `?Phy_SetLightType@@YAXHW4C3_RENDER_LIGHT_TYPE@@@Z`
- ordinal `95` `0x1000CBF0` `?Phy_SetPointLightAttenuation@@YAXHMMM@Z`
- ordinal `96` `0x1000CC20` `?Phy_SetSpotLightFalloff@@YAXHMMM@Z`
- ordinal `97` `0x1000DF50` `?Phy_SetStepCount@@YAXPAUC3Phy@@K@Z`
- ordinal `98` `0x1000B730` `?Phy_Unload@@YAXPAPAUC3Phy@@@Z`

## BNinja deob summary (updated 2026-07-25)

`Phy_LoadFromStream` (`0x1000A300`, formerly `?Phy_Load@@YAHPAPAUC3Phy@@PAXHHH@Z`) now has named parameters/locals in the BNinja DB:
- params: `outPhy`, `streamHandle`, `hasSerializedNormals`, `generateNormals`, `usesSplitVertexRecord`
- key locals: `vertexSectionFlags`, `serializedVertexCount0`, `serializedVertexCount1`, `serializedFaceCount0`, `serializedFaceCount1`, `transientLength`, `objectToWorldMatrix`, `optionalSectionTag`

The neutral count names are intentional. The 5517 binary immediately sums each serialized
pair into the retained total and does not preserve a per-partition meaning.

`Phy_DrawSubmeshPrimitives` (`0x1000DC30`, formerly `?Phy_DrawUp@@...`) is deobfuscated and commented:
- indexed draw path uses triangle-list semantics (`D3DPT_TRIANGLELIST`) with `uint16` index payload
- non-indexed path is only used when index pointer/count are absent
- world matrix is set to identity in this helper (vertices are expected pre-transformed)

Related helper/function names deobfuscated in the same DB:
- `Vector3DefaultCtor_NoInit` (`0x1000B490`)
- `UInt32CopyAssign` (`0x10007B90`)
- `UInt32Vector_Size` (`0x1000ED00`)
- `RbTree_LeftMostNode` (`0x1000FE50`)
- `RbTree_IteratorIncrement` (`0x1000F0A0`)
- `RbTree_EraseNodeAndRebalance` (`0x1000F710`)
- `RbTree_DeleteSubtreeRecursive` (`0x1000FB10`)
- `RuntimeDispatch_Vec3Normalize` / `_InitThunk` (`0x10016F8D` / `0x10016F80`)
- `Vec3Normalize_Scalar` (`0x100197E1`, scalar target used by the runtime dispatch table)
- `FloatWithinMachineEpsilon` (`0x10016D16`, inclusive `+/-1.1920929e-7` comparison)
- `RuntimeDispatch_Vec3TransformCoord` / `_InitThunk` (`0x10017297` / `0x1001728A`)
- `Vec3TransformCoord_Scalar` (`0x10019881`, scalar target used by the runtime dispatch table)
- `RuntimeDispatch_Vec3TransformNormal` (`0x1001729D`)
- `Vec3TransformNormal_Scalar` (`0x100172B0`, scalar target used by the runtime dispatch table)

Verified local types now defined in the BNinja DB:
- `D3DXVECTOR2`: two floats, size `0x08`
- `D3DXVECTOR3`: three floats, size `0x0C`
- `PhyOutVertex`: position, normal, packed diffuse ARGB, and UV at offsets
  `+0x00/+0x0C/+0x18/+0x1C`, total size `0x24`

Notes:
- `RuntimeDispatch_*` names are behavior-based from call signatures and use sites (2-arg normalize, 3-arg vec3+matrix transform) in `Phy_Load`, `BuildRay`, and particle/shape draw paths.

## Verified `Phy_Load` file parse order

Order below is from the cleaned `Phy_Load` decompile/disassembly (not speculative):

1. `int32 textureNameLength`
2. `textureNameLength` bytes (ASCII), then native writes null terminator in allocated buffer
3. `uint32 vertexSectionFlags` (read and preserved; native local `vertexSectionFlags`)
4. `int32 serializedVertexCount0`
5. `int32 serializedVertexCount1`
6. Vertex payload (`serializedVertexCount0 + serializedVertexCount1` entries), layout selected by
   `hasSerializedNormals`/`usesSplitVertexRecord`
7. `int32 serializedFaceCount0`
8. `int32 serializedFaceCount1`
9. Face index payload (`uint16`, `3 * (serializedFaceCount0 + serializedFaceCount1)`)
10. `int32 opaqueSectionLength` and `opaqueSectionLength` bytes skipped by native
11. `Vector3 boundsMin` then `Vector3 boundsMax`; native swaps per-axis when inverted
12. `float[16] objectToWorldMatrix` (0x40 bytes)
13. `uint32` at `C3Phy+0x134` (`stepFrameCount` in managed model)
14. Embedded `C3Key` at `C3Phy+0x5C`, serialized as three `count + payload`
    groups:
    - alpha keys: count at `+0x5C`, ptr at `+0x60`, element size `0x10`
    - draw keys: count at `+0x64`, ptr at `+0x68`, element size `0x10`
    - texture-change keys: count at `+0x6C`, ptr at `+0x70`, element size `0x10`
15. Optional trailing tags:
    - `"STEP"` + two `uint32` (`C3Phy+0x13C`, `C3Phy+0x140`)
    - optional `"2SID"` sets `has2SidTag` (`C3Phy+0x05`); the draw path does
      not interpret absence of this tag as ordinary backface culling
    - optional `"BILB"|"BIL2"|"BIL3"|"BIL4"` maps to `C3Phy+0x144` values `1..4`

## Verified `Phy_LoadFromStream` post-parse processing

After raw payload parse, native always performs runtime conversion steps before render:

1. Stores only the sum of the two serialized vertex counts in `C3Phy+0x08`
   (`vertexCount`) and only the sum of the two face counts in `C3Phy+0x14`
   (`faceCount`).
2. Copies the complete face index payload into one D3D index buffer (and mirrors it
   into heap memory at `C3Phy+0x18`).
3. Applies `objectToWorldMatrix` to every vertex position
   (`RuntimeDispatch_Vec3TransformCoord`), mutating loaded vertices. Its verified scalar
   implementation computes row-vector `x/y/z/w`, then divides `x/y/z` by `w` unless
   `w` is within inclusive `+/-1.1920929e-7` of `1.0`.
4. Builds one GPU output vertex buffer (stride `0x24`) with:
   - transformed position
   - UV from source vertex offsets `+0x0C/+0x10`
   - diffuse color `0xFFFFFFFF`
   - normal fields populated from source vertex offset `+0x28` (later updated as needed)
5. If `hasSerializedNormals==0` and `generateNormals!=0`, computes a unit normal for
   every indexed face, accumulates equal-weight face normals per vertex, normalizes each
   vertex, then smooths vertices whose transformed position components match within
   inclusive tolerance `0.01`. The smoothing pass processes vertices in ascending order,
   adds every matching earlier vertex, and normalizes after each addition. It writes the
   result to the GPU vertex and source vertex normal slot (`+0x28`).
6. Marks phy as initialized and ready for draw.

Practical parity implication:
- the serialized count pair does not define separately retained normal/alpha,
  skinned/static, or otherwise independently drawable partitions in this runtime
- `Phy_Calculate_CPU` processes all `vertexCount` vertices and
  `Phy_DrawNormal_CPU` submits all `faceCount` triangles in one indexed draw

## Verified vertex payload branch matrix

`hasSerializedNormals` and `usesSplitVertexRecord` decide the exact on-disk read pattern.
The argument tuples below are verified at all four `C3DObjX_Create` call sites in
`graphic.dll`; they do not classify runtime skinning capability:

- `(hasSerializedNormals=0, generateNormals=1, usesSplitVertexRecord=0)`
  (`PhyType.GeneratedNormalsPacked` / `'4'`):
  - contiguous `0x28` bytes per vertex
- `(hasSerializedNormals=0, generateNormals=1, usesSplitVertexRecord=1)`
  (`PhyType.GeneratedNormalsSplit` / `' '`):
  - read `0x0C`, seek `0x24`, read `0x1C` (total `0x4C`)
- `(hasSerializedNormals=1, generateNormals=0, usesSplitVertexRecord=0)`
  (`PhyType.SerializedNormalsPacked` / `'3'`):
  - contiguous `0x34` bytes per vertex
- `(hasSerializedNormals=1, generateNormals=0, usesSplitVertexRecord=1)`
  (`PhyType.SerializedNormalsSplit` / `'2'`):
  - read `0x0C`, seek `0x24`, read `0x28` (total `0x58`)

## Verified C3Phy struct layout (BNinja, corrected 2026-07-26)

Defined in BNinja DB as `struct C3Phy` (0x160 / 352 bytes):

| Offset | Size | Field | Notes |
|--------|------|-------|-------|
| +0x00 | 4 | textureNamePtr | `char*` — texture name string from PHY payload. **Also the submesh identifier** used by `C3DObjX_FindSubmeshIndexByName` (case-insensitive `_stricmp`). Role body meshes use names like `"v_armet"`, `"v_r_weapon"` for virtual attachment submeshes. Verified 2026-03-16. |
| +0x04 | 1 | hasNormals | Initially set from `hasSerializedNormals`; set to 1 after generated normals are written. |
| +0x05 | 1 | has2SidTag | Cleared by `Phy_Clear` and set to 1 only when the optional `2SID` tag is consumed. This is not a skeleton flag. |
| +0x06 | 1 | drawEnabled | Default 1. Validity/draw-enable flag. Verified via `Phy_Clear` asm: `mov byte [esi+0x6], 0x1` |
| +0x07 | 1 | vertexCacheDirty | Cleared by `Phy_Clear`, set to 1 after VB unlock in `Phy_LoadFromStream` |
| +0x08 | 4 | vertexCount | Total vertex count |
| +0x0C | 4 | internalVertexBuffer | Heap-resident native vertex records |
| +0x10 | 4 | pVertexBuffer | `IDirect3DVertexBuffer8*` |
| +0x14 | 4 | faceCount | Triangle count |
| +0x18 | 4 | cpuIndexMirror | Heap mirror of index data (`uint16*`) |
| +0x1C | 4 | pIndexBuffer | `IDirect3DIndexBuffer8*` |
| +0x20 | 4 | baseTextureId | Texture DB index into `g_pTexDB` (-1 = none). Set by `Phy_ChangeTexture`. Verified: `mov [ecx+0x20], eax` |
| +0x24 | 4 | mixTextureId | Mix/blend texture DB index (-1 = none). Set by `Phy_ChangeMixTexture`. Verified: `mov [ecx+0x24], eax` |
| +0x28-0x33 | 12 | boundsMin | AABB minimum xyz |
| +0x34-0x3F | 12 | boundsMax | AABB maximum xyz |
| +0x40 | 4 | primaryMotion | `C3Motion*` used by `Phy_SetFrame` / `Phy_Calculate_CPU` |
| +0x44 | 4 | secondaryMotion | `C3Motion*` used by `Phy_SetBlendFrame` / `Phy_Calculate_CPU` |
| +0x48 | 4 | lightColorR | Light/color R multiplier |
| +0x4C | 4 | lightColorG | Light/color G multiplier |
| +0x50 | 4 | lightColorB | Light/color B multiplier |
| +0x54 | 4 | alphaOpacity | Alpha/opacity value |
| +0x58 | 4 | cachedDiffuseColor | Per-submesh packed ARGB written by `Phy_Calculate_CPU` |
| +0x5C | 24 | keys | Embedded `C3Key`: alpha, draw, and texture-change count/pointer pairs |
| +0x74 | 64 | objectToWorldMatrix | 4x4 object-to-world matrix (renamed from `localMatrix`) |
| +0xB4 | 64 | localMatrix | 4x4 local/bone matrix (renamed from `invBindMatrix`) |
| +0xF4 | 64 | worldMatrix | 4x4 world transform (used with `D3DTS_WORLD`). Verified: `lea eax,[ebp+0xf4]` |
| +0x134 | 4 | stepFrameCount | Used by UV step animation math in `Phy_Calculate_CPU` |
| +0x138 | 4 | stepFramePosition | Unsigned fallback STEP position when the texture-key frame is negative |
| +0x13C | 4 | stepUScale | UV step scale U (read as float bits) |
| +0x140 | 4 | stepVScale | UV step scale V (read as float bits) |
| +0x144 | 4 | billboardMode | Optional billboard mode token result |
| +0x148 | 4 | motionCacheMapPtr | Runtime cache map pointer used by `Phy_Calculate_CPU` |
| +0x14C | 4 | motionCacheKey | Runtime key used for cache lookup/insert |
| +0x154 | 4 | usedBoneIndicesBegin | `uint32*` begin for per-submesh used-bone index vector |
| +0x158 | 4 | usedBoneIndicesEnd | `uint32*` end for used-bone index vector |

Field rename changelog:
- `+0x00`: was `field_0x00` → `textureNamePtr` (verified 2026-03-16: `Phy_Clear` asm `mov dword [esi], eax`, `C3DObjX_FindSubmeshIndexByName` dereferences as string)
- `+0x04`: was `field_0x04` → `hasNormals` (verified 2026-03-16: `Phy_Clear` asm `mov byte [esi+0x4], al`)
- `+0x06`: was `isValid` → `drawEnabled` (verified 2026-03-16: `Phy_Clear` asm `mov byte [esi+0x6], 0x1`)
- `+0x07`: was `pad` → `vertexCacheDirty` (verified 2026-03-16: `Phy_LoadFromStream` sets to 1 after VB processing)
- `+0x20`: was `primaryTextureId` → `baseTextureId` (verified 2026-03-01 via `Phy_ChangeTexture` disassembly)
- `+0x24`: was `secondaryTextureId` → `mixTextureId` (verified 2026-03-01 via `Phy_ChangeMixTexture` disassembly)
- `+0x5C..+0x73`: was three speculative `boneGroup` count/pointer pairs → embedded
  `C3Key` (verified 2026-07-26 from `Phy_LoadFromStream`, `Phy_Calculate_CPU`,
  and all three `Key_Process*` functions)
- `+0x74`: was `localMatrix` → `objectToWorldMatrix` (load-time transform applied to vertices)
- `+0xB4`: was `invBindMatrix` → `localMatrix` (runtime bone/local transform)

## Verified C3Key layout and processing

`C3Phy+0x5C` is an embedded 0x18-byte `C3Key`:

| C3Key offset | C3Phy offset | Type | Field |
|--------------|--------------|------|-------|
| +0x00 | +0x5C | `int32` | `alphaKeyCount` |
| +0x04 | +0x60 | `C3AlphaKeyEntry*` | `alphaKeys` |
| +0x08 | +0x64 | `int32` | `drawKeyCount` |
| +0x0C | +0x68 | `C3DrawKeyEntry*` | `drawKeys` |
| +0x10 | +0x6C | `int32` | `textureChangeKeyCount` |
| +0x14 | +0x70 | `C3TextureChangeKeyEntry*` | `textureChangeKeys` |

Each array entry is exactly 0x10 bytes:

| Entry | +0x00 | +0x04 | +0x08 | +0x0C |
|-------|-------|-------|-------|-------|
| `C3AlphaKeyEntry` | signed frame position | float alpha opacity | opaque `uint32` | opaque `uint32` |
| `C3DrawKeyEntry` | signed frame position | opaque `uint32` | signed raw draw value | opaque `uint32` |
| `C3TextureChangeKeyEntry` | signed frame position | opaque `uint32` | opaque `uint32` | signed texture frame index |

`Key_ProcessAlpha` (`0x10008130`) uses signed frame comparisons. It selects the last
array index whose frame is at or before the sample and the first array index whose
frame is after the sample. These are array-index selections, not nearest-frame
searches, so serialized order is significant. With one available side it copies
that key's alpha; with both it linearly interpolates by frame position. No keys
returns false without writing the output. The exported `motionFrameCount` parameter
is not read.

`Key_ProcessDraw` (`0x10008240`) changes draw state only on an exact frame match,
writing `drawEnabledRaw != 0`. A null array, a nonpositive count, or no match returns
false without writing the output.

`Key_ProcessChangeTex` (`0x10008290`) walks the serialized array order:

1. An exact signed frame match writes the current key's texture frame index.
2. Otherwise, when the key index is greater than zero and the signed sample frame
   is less than the current key frame, it writes the previous array entry's texture
   frame index.
3. Reaching the end returns false without writing the output.

This produces native edge behavior that must be preserved: an empty array, a
nonmatching sample after the last key, and a sample before the first of a one-key
array do not resolve. A sample before the first of an array with at least two keys
resolves the first key when the loop reaches the second entry. `Phy_Calculate_CPU`
initializes the output to `-1`, so a false result retains the fallback STEP path.

`Phy_Calculate_CPU` calls the processors in alpha, draw, texture-change order using
`primaryMotion->primarySampleFramePosition`. Its alpha and draw temporary outputs
start at `1.0` and `true`, but it copies either value into `C3Phy` only when that
processor returns true. Consequently, both fields are persistent per-submesh state
between keyed frames. After all three processors run, a false `drawEnabled` returns
success before the vertex buffer is locked or updated.

## Verified `Phy_Calculate` wrapper (0x1000C7B0)

`Phy_Calculate` is a thin wrapper that forwards to `Phy_Calculate_CPU`:

```c
int Phy_Calculate(C3Phy* phy, int hasNormals, int frameIndex, D3DXVECTOR3 lightDirection);
```

Behavior (verified BNinja 2026-07-26):
- Calls `Phy_Calculate_CPU(phy, hasNormals, frameIndex, lightDirection, true)` — the extra
  `sampleMotion` parameter is hardcoded `true` (`push 1` at `0x1000C7B8`).
- Returns `Phy_Calculate_CPU`'s return value.

This is the full calculation path used by `C3DObjX_Render` when `useLiteRenderPath == 0`.

For meshes whose normalized internal vertices carry **live bone indices/weights** in source slots
`+0x18/+0x1C/+0x20/+0x24`, `Phy_Calculate_CPU` will skin them regardless of the original on-disk
PHY discriminator. There is no verified skinning branch here on `C3Phy+0x05 has2SidTag`.

Verified real-client correction for the hero path:
- `c3/mesh/002000000.c3` and `c3/mesh/003000000.c3` body-role PHY chunks are tagged
  `GeneratedNormalsSplit (' ')` on disk,
- but their normalized `PhyVertex.Bone` payload is live (non-zero indices/weights),
- so the Role3D path can still animate them through `Phy_Calculate_CPU` when
  `useLiteRenderPath == 0`.

Only truly static meshes with zero effective bone weights should be treated as rigid in the managed port.

## Verified `Phy_Calculate_Lite` (0x1000C630)

`Phy_Calculate_Lite` is the **color-only** calculation path — it performs NO position/animation work.

```c
int Phy_Calculate_Lite(C3Phy* phy);
```

Behavior (verified BNinja 2026-07-26):
- Reads `phy->lightColor{R,G,B}` and `phy->alphaOpacity` (`+0x48..+0x54`).
- Converts every component independently:
  - value `>= 1.0f` becomes `255`
  - value `<= 0.0f` or unordered/NaN becomes `0`
  - otherwise `_ftol(value * 255.0f + 0.5f)` supplies the byte
- Packs the four bytes as `0xAARRGGBB`.
- If the packed value equals `phy->cachedDiffuseColor` (`+0x58`), returns success
  without locking the vertex buffer.
- Otherwise locks the D3D vertex buffer with discard (`flag 0x800`), writes only
  `PhyOutVertex.diffuseColorArgb` at destination offset `+0x18` for every `0x24`-byte
  vertex, unlocks, then stores the packed value in `cachedDiffuseColor`.
- Lock failure returns false and does not update `cachedDiffuseColor`.

`Phy_Calculate_Lite` does **not** inspect `drawEnabled`, process key arrays, or alter
position, normal, or UV.

This is the lite calculation step. `C3DObjX_Render` calls it when `useLiteRenderPath != 0`.

**Critical implication for rigid meshes**: `Phy_Calculate_Lite` leaves vertex positions untouched in the GPU buffer. The world-space positioning is handled entirely by `Phy_DrawNormal_CPU`'s `SetTransform(D3DTS_WORLD, &phy->worldMatrix)` at `C3Phy+0xF4`.

This path is correct for rigid/non-deforming meshes only. It cannot supply skeletal deformation for role body PHYs whose animation depends on the live bone payload above.

## Verified skeletal CPU skinning pipeline (`Phy_Calculate_CPU`, 0x1000BAE0)

### High-level flow

Verified by disassembly:

- alpha/draw/texture key processing precedes vertex-buffer work
  (`0x1000BAEF..0x1000BB59`)
- draw flag gate: `test byte [phy+0x06]` early success return
  (`0x1000BB64..0x1000BB78`)
- D3D8 vertex lock with discard: VB vtable `+0x2C`, flag `0x800` (`0x1000BB79..0x1000BB94`)
- diffuse conversion is identical to `Phy_Calculate_Lite` and packs
  `lightColorR/G/B/alphaOpacity` as `0xAARRGGBB` (`0x1000BD0C..0x1000BE28`)
- optional motion sampling:
  - used-bone vector range: `phy+0x154` / `phy+0x158` (`0x1000C009..0x1000C024`)
  - call `C3MotionTracker_GetBlendedBoneMatrixAtFrame` per bone (`0x1000C03E`)
  - destination matrix cache `g_BoneMatrices`: `0x100B4540 + (boneIndex << 6)`
    (`0x1000C02B..0x1000C02E`) - a module-global array of 64-byte 4x4 matrices, not a
    per-`C3Phy` allocation
  - the motion pair is built on the stack as `C3MotionBlendPair { primary, secondary }`
    from `C3Phy+0x40` / `C3Phy+0x44` before the per-bone call
- fallback (no motion sampling): identity-fill all `primaryMotion->boneCount` matrices (`0x1000C051..0x1000C095`)
- per-vertex loop:
  - source stride `0x34`, destination stride `0x24` (`add edi, 0x34` at `0x1000C593`, `add ebx, 0x24` at `0x1000C586`)

### Verified internal skinned vertex layout (source stride 0x34)

This is the in-memory vertex format consumed by `Phy_Calculate_CPU` for skinned PHY variants:

| Offset | Size | Type | Field | Disassembly evidence |
|--------|------|------|-------|----------------------|
| +0x00 | 12 | `float[3]` | position xyz | `mov [edx]`, `[edx+4]`, `[edx+8]` (`0x1000C1C4..0x1000C1DA`) |
| +0x0C | 4 | `float` | uv.u | `fadd dword [eax+edi+0xc]` (`0x1000C57D`) |
| +0x10 | 4 | `float` | uv.v | `fadd dword [ecx+edi-0x24]` after `edi += 0x34` (`0x1000C593..0x1000C596`) |
| +0x14 | 4 | `float` | reservedAt0x14 | carried through from load-time vertex payload; not consumed in verified skinning/runtime paths |
| +0x18 | 4 | `uint32` | boneIndex2 | `mov eax,[ecx+0x18] ; shl eax,6 ; add eax,0x100b4540` (`0x1000C29E..0x1000C2A4`) |
| +0x1C | 4 | `uint32` | boneIndex1 | `mov eax,[ecx+0x1c] ; shl eax,6 ; add eax,0x100b4540` (`0x1000C1E4..0x1000C1EA`) |
| +0x20 | 4 | `float` | boneWeight2 | `fld dword [ecx+0x20]` (`0x1000C2AD`) |
| +0x24 | 4 | `float` | boneWeight1 | `fld dword [ecx+0x24]` (`0x1000C1E1`) |
| +0x28 | 12 | `float[3]` | normal xyz | normal transform source `lea eax,[edx+edi+0x28]` (`0x1000C561`) |

Additional verification from `Phy_LoadFromStream` (`0x1000A300`, 2026-03-04 refresh):
- per-submesh used-bone index vector (`C3Phy+0x154/+0x158`) is populated from:
  - source vertex `+0x18` (always),
  - source vertex `+0x1C` only when weight at `+0x24 > 0`.
- no extraction/read path in this verified logic uses source `+0x14`, so this field remains documented as reserved.

### Matrix blend and transform math

For each vertex, native performs element-wise 4x4 blending of two bone matrices:

```
blended = boneWeight1 * boneMatrix[boneIndex1]
        + boneWeight2 * boneMatrix[boneIndex2]
```

Evidence:
- first weighted matrix term (`+0x1C`, `+0x24` path): `0x1000C1E1..0x1000C29C`
- second weighted matrix term (`+0x18`, `+0x20` path): `0x1000C2AD..0x1000C387`
- element-wise addition: `0x1000C38D..0x1000C467`

Then:
- `RuntimeDispatch_Vec3TransformCoord` for position (`0x1000C53F`)
- `RuntimeDispatch_Vec3TransformNormal` for normal when normals are enabled (`0x1000C554..0x1000C56A`)

The scalar coordinate transform (`Vec3TransformCoord_Scalar`, `0x10019881`) computes
`x/y/z/w` and performs the same conditional homogeneous divide documented for
`Phy_LoadFromStream`. The scalar normal transform (`Vec3TransformNormal_Scalar`,
`0x100172B0`) applies only the matrix 3x3 linear portion: it adds no translation,
performs no homogeneous divide, and is not followed by normalization.

No quaternion decomposition, slerp, orthonormalization, or post-transform normal
normalization is used in this path.

### Output GPU vertex (destination stride 0x24)

Writes the same runtime GPU vertex layout used by static meshes:

| Offset | Size | Field | Evidence |
|--------|------|-------|----------|
| +0x00 | 12 | transformed position | `Vec3TransformCoord` destination pointer (`0x1000C53A..0x1000C53F`) |
| +0x0C | 12 | transformed normal | normal destination `esi+0x0c` (`0x1000C566`) |
| +0x18 | 4 | packed diffuse ARGB | `mov [esi+0x18], eax` (`0x1000C577`) |
| +0x1C | 4 | `uv.u + stepUOffset` | write at `0x1000C589` |
| +0x20 | 4 | `uv.v + stepVOffset` | write at `0x1000C59E` |

The packed diffuse write occurs in both CPU paths:
- cached-vertex copy path: `0x1000BF92`
- freshly skinned path: `0x1000C577`

The freshly generated result is also copied into `C3Phy.cachedDiffuseColor`
(`0x1000C5B4..0x1000C5B8`).

### Verified STEP UV selection

`Key_ProcessChangeTex` may write a signed texture frame index initialized to `-1`.
Both the
freshly skinned path (`0x1000C0EF..0x1000C1AB`) and cached-vertex path
(`0x1000BEC1..0x1000BF76`) select offsets identically:

```c
if (textureKeyFrameIndex >= 0) {
    stepUOffset = (textureKeyFrameIndex % stepFrameCount) * (1.0f / stepFrameCount);
    stepVOffset = (textureKeyFrameIndex / stepFrameCount) * (1.0f / stepFrameCount);
} else {
    stepUOffset = stepFramePosition * stepUScale;
    stepVOffset = stepFramePosition * stepVScale;
}
```

The modulo and division use unsigned `stepFrameCount`. The fallback
`stepFramePosition` is also unsigned. `Phy_SetStepCount` (`0x1000DF50`) performs only a
null check and a direct store to `C3Phy+0x138`; it does not normalize the position by
`stepFrameCount`.

### Cross-DLL bind/source contract (graphic.dll -> c3_core_dll.dll)

Bone sampling inputs consumed above are fed by `graphic.dll` `C3DObjX` bind/frame methods:

- motion slot bind:
  - primary `C3DObjX_SetMotion*`: `phy+0x40 = tracker->GetMotionByIndex(i)` (`graphic.dll` `0x10003DD7`, `0x10003F45`)
  - blend `C3DObjX_SetBlendMotion*`: `phy+0x44 = tracker->GetMotionByIndex(i)` (`graphic.dll` `0x10003E62`, `0x10003FF2`)
- per-submesh frame writes:
  - `Phy_SetFrame` (`c3_core_dll.dll` `0x1000DEF0`; called from `graphic.dll` `0x10003F4E`,
    `0x1000429A`) writes `primaryMotion+0x10`, reading the bound motion from `C3Phy+0x40`
    and its `frameCount` from `motion+0x04`
  - `Phy_SetBlendFrame` (`c3_core_dll.dll` `0x1000DF20`; called from `graphic.dll` `0x10003FF9`,
    `0x100042DA`) writes `secondaryMotion+0x14`, reading the bound motion from `C3Phy+0x44`
  - both setters normalize independently against the bound motion's own `frameCount`:
    `uint32 frame % uint32 frameCount`; a zero `frameCount` writes frame position `0`,
    while a null bound motion returns without writing
- blend alpha write:
  - `C3DObjX_SetBlendMotion*` writes `motion+0x18` (`graphic.dll` `0x10003E6E`, `0x10003FF6`)

`Phy_Calculate_CPU` uses this exact pair (`C3Phy+0x40/+0x44`) with `C3MotionTracker_GetBlendedBoneMatrixAtFrame` (`0x10009E70`) for each used bone.

## Verified render state pipeline (BNinja, verified through 2026-07-26)

### `Phy_Prepare` global defaults (0x1000B9A0)

Called once before any PHY draw calls. Sets global D3D8 render state:

| D3D State | Value | Meaning |
|-----------|-------|---------|
| D3DRS_ZENABLE (7) | D3DZB_TRUE (1) | Depth testing enabled |
| D3DRS_ZWRITEENABLE (0xE) | TRUE (1) | Depth writes enabled |
| D3DRS_SHADEMODE (9) | D3DSHADE_GOURAUD (2) | Per-vertex color interpolation |
| D3DRS_FILLMODE (8) | D3DFILL_SOLID (3) | Solid fill mode |
| D3DRS_CULLMODE (0x16) | D3DCULL_CW (2) | Baseline cull clockwise |
| D3DRS_DITHERENABLE (0x1A) | FALSE (0) | Dithering disabled |
| D3DRS_ALPHATESTENABLE (0xF) | TRUE (1) | Alpha testing enabled |

It also restores stage-0 `COLOROP` and `ALPHAOP` to
`D3DTOP_MODULATE (4)`.

`Init3DEx` establishes the texture-stage defaults used by mode 17:

- `D3DRS_NORMALIZENORMALS (0x8F)` is enabled, so vertex normals are normalized
  after the inverse-transpose world-view transformation to camera space;
- stage 0 minification, magnification, and mip filtering are linear;
- stage 1 minification/magnification are linear and mip filtering is disabled;
- stage 0 and stage 1 `ADDRESSU`/`ADDRESSV` are `D3DTADDRESS_WRAP (1)`;
- stage 1 `TEXCOORDINDEX` starts at pass-through `0`.

### `C3_PIPE_RENDER_DESC` struct layout

Passed as `arg4` to `Phy_DrawNormal_CPU`. Constructed by callers (game-level code) and passed through `C3Effect_Render` / `C3DObjX_Render`.

```c
struct C3_PIPE_RENDER_DESC {
    uint32_t sourceBlendMode;                // +0x00 -> D3DRS_SRCBLEND
    uint32_t destinationBlendMode;           // +0x04 -> D3DRS_DESTBLEND
    uint8_t  depthWriteAndLightingEnabled;   // +0x08 -> D3DRS_ZWRITEENABLE and lighting gate
    uint8_t  useCounterClockwiseCullMode;    // +0x09 -> tagged-PHY cull selector
    uint8_t  reserved[2];                    // +0x0A
};
```

`C3DObjX_Render` constructs this exact `0x0C`-byte descriptor from its fourth,
fifth, and seventh stack arguments. It always writes
`depthWriteAndLightingEnabled=1`.
The Role3D path supplies source/destination blend modes from each part's MESH
record and initializes `useCounterClockwiseCullMode=0`.

`GraphicData.dll`'s MESH loader proves that serialized record bytes `+0x0D` and
`+0x0E` are the source and destination D3D blend modes. All available records
from the configured MESH tables supplied with the clean client data use
`D3DBLEND_SRCALPHA(5)` and
`D3DBLEND_INVSRCALPHA(6)`.

`Init3DEx` fixes the alpha-test comparison globally to
`D3DRS_ALPHAREF=8` and `D3DRS_ALPHAFUNC=D3DCMP_GREATEREQUAL(7)`. With
global `D3DRS_ALPHATESTENABLE=1`, fragments therefore pass at byte alpha `>= 8`,
equivalent to normalized alpha `>= 8/255`. This state is independent of
`C3_PIPE_RENDER_DESC+0x08`.

### `C3_TEX_SHADER_DESC` (texture mode)

Passed as `arg3` to `Phy_DrawNormal_CPU`:

```c
struct C3_TEX_SHADER_DESC {
    uint32_t mode;       // +0x00
    uint32_t parameter;  // +0x04
};
```

Default mode = **4** (initialized in `C3DObjX_Ctor` at `C3DObjX+0x04`).
`C3DObjX_SetTextureShaderDescriptor` stores a positive caller mode unchanged,
falls back to `4` for nonpositive input, and always stores the caller parameter.

### Per-submesh draw state (`Phy_DrawNormal_CPU`, 0x1000CC90)

#### Draw gates
```c
if (!phy->drawEnabled) return;
if (phy->faceCount == 0) return;
if (!(phy->alphaOpacity > 0.0f)) return; // also rejects unordered/NaN
```

#### Render state overrides (per-submesh)
1. `SetRenderState(D3DRS_ZWRITEENABLE, pipeRender->depthWriteAndLightingEnabled)` — from desc byte +0x08
2. `SetRenderState(D3DRS_SRCBLEND, pipeRender->sourceBlendMode)` — from desc dword +0x00
3. `SetRenderState(D3DRS_DESTBLEND, pipeRender->destinationBlendMode)` — from desc dword +0x04
4. `SetRenderState(D3DRS_CULLMODE, ...)`:
   - `has2SidTag==0`: **D3DCULL_NONE (1)**
   - `has2SidTag!=0 && useCounterClockwiseCullMode==0`: **D3DCULL_CW (2)**
   - `has2SidTag!=0 && useCounterClockwiseCullMode!=0`: **D3DCULL_CCW (3)**

#### Material and lighting modifiers
- This branch runs only when light slot 0 is enabled and
  `pipeRender->depthWriteAndLightingEnabled != 0`.
- `material.Diffuse.a *= phy->alphaOpacity` scales material alpha by per-submesh opacity.
- `light[0].Ambient.{r,g,b} *= phy->lightColor{R,G,B}` applies the per-submesh tint.
- `SetRenderState(D3DRS_SPECULARENABLE, material.Power > 0.0f)` conditionally enables specular.
- `SetRenderState(D3DRS_LIGHTING, TRUE)` enables lighting only inside this branch.
- Otherwise the function explicitly sets `D3DRS_LIGHTING=FALSE`.
- The clean `ini/graphic.ini` enables slot 0 with value `0`, so clean role draws
  take the unlit texture/vertex-diffuse path.

#### Default material (`C3DObjX_Ctor`, at C3DObjX+0x64)

```c
D3DMATERIAL8 material = {
    .Diffuse  = {1.0, 1.0, 1.0, 1.0},  // full white
    .Ambient  = {0.5, 0.5, 0.5, 0.5},  // half gray
    .Specular = {1.0, 1.0, 1.0, 1.0},  // full white
    .Emissive = {0.0, 0.0, 0.0, 0.0},  // none
    .Power    = 0.0                      // no specular highlight
};
```

#### Default C3Phy render fields (`Phy_Clear`)
- `alphaOpacity` = 1.0 (fully opaque)
- `lightColorR` = 1.0, `lightColorG` = 1.0, `lightColorB` = 1.0 (no tint)

### Texture and material setup
- Primary texture from `g_pTexDB[phy->baseTextureId]` (+0xC for D3D texture ptr)
- In the enabled-lighting branch, material is applied via `SetMaterial`
  (vtable `+0xA8`) with `material.Diffuse.a` scaled by `phy->alphaOpacity`.
- Light 0 ambient RGB is scaled by `phy->lightColor{R,G,B}`.
- The module stores eight `0x6C`-byte light slots: slot 0 plus slots 1 through 7.
  The additional-light loop enables contiguous slots beginning at 1 and stops
  at the first disabled slot. Cleanup disables the enabled additional slots and
  turns device lighting off.

### Draw call
```
SetTransform(D3DTS_WORLD=0x100, &phy->worldMatrix)    // +0xF4
SetVertexShader(0x152)                                  // FVF = D3DFVF_XYZ|NORMAL|DIFFUSE|TEX1
SetStreamSource(0, phy->pVertexBuffer, 0x24)           // stride = 36 bytes
SetIndices(phy->pIndexBuffer, 0)
DrawIndexedPrimitive(D3DPT_TRIANGLELIST=4, 0, phy->vertexCount, 0, phy->faceCount)
```

### GPU vertex buffer layout (stride 0x24 / 36 bytes)

| Offset | Size | Type | Source |
|--------|------|------|--------|
| 0x00 | 12 | `float[3]` pos | Internal vertex [0,1,2] pre-transformed by `objectToWorldMatrix` |
| 0x0C | 12 | `float[3]` normal | Internal vertex [10,11,12] (serialized or generated according to PHY layout) |
| 0x18 | 4 | `uint32` diffuse | Initialized to `0xFFFFFFFF`; calculation writes packed ARGB from clamped `lightColorR/G/B/alphaOpacity` |
| 0x1C | 8 | `float[2]` UV | Internal vertex [3,4] |

FVF `0x152` = `D3DFVF_XYZ(0x002)` | `D3DFVF_NORMAL(0x010)` | `D3DFVF_DIFFUSE(0x040)` | `D3DFVF_TEX1(0x100)`

## Verified `Phy_SetColor` (0x1000DF90)

```c
void Phy_SetColor(
    C3Phy* phy,
    float lightColorR,
    float lightColorG,
    float lightColorB,
    float alphaOpacity);
```

The function directly copies the four float arguments to `C3Phy+0x48..+0x54`.
It performs no clamping, packing, vertex-buffer update, or draw-state change.

### Normal generation (`hasSerializedNormals==0 && generateNormals!=0`)
1. Per-face cross product uses the transformed positions and the exact expression
   `faceNormal = (v2-v1) cross (v1-v0)`. This is the opposite sign from
   `(v1-v0) cross (v2-v0)`.
2. The face normal is normalized before accumulation through
   `RuntimeDispatch_Vec3Normalize`, so adjacent faces have equal weight regardless of area.
3. The unit face normal is added to all three indexed vertices.
4. Every accumulated vertex normal is normalized.
5. For each vertex in ascending order, native collects earlier vertices whose x, y, and z
   components each differ by at most `0.01`. Starting with the current normal, it adds each
   matched normal and normalizes after every addition, then assigns that result to the full
   matched-position group.
6. `Vec3Normalize_Scalar` leaves a vector unchanged when its length-squared is within
   `+/-1.1920929e-7` of 1, maps length-squared values at or below
   `1.17549435e-38` (including unordered comparisons) to `(0,0,0)`, and otherwise
   multiplies by `1/sqrt(lengthSquared)`. Native does not substitute an arbitrary up vector.

### Alternative draw path (`Phy_DrawSubmeshPrimitives`, 0x1000DC30)
- Sets world matrix to identity (`g_IDMatrix`)
- Uses `DrawIndexedPrimitive` or `DrawPrimitive` (raw vertices, no D3D VB)
- Same FVF `0x152` and stride `0x24`
- Used when vertex/index data is passed directly (not from D3D buffers)

## Managed implementation parity

- Parser: `10_work/src/Conquer.Assets/Mesh/PhySubmeshReader.cs`
- Model: `10_work/src/Conquer.Assets/Mesh/PhySubmesh.cs`

Current managed model now preserves all file-sourced fields above:
- texture name, `vertexSectionFlags`
- split skinned/static vertex and face counts
- vertex/index payloads
- opaque section length and bytes
- AABB bounds, matrix, `stepFrameCount`
- embedded alpha, draw, and texture-change key arrays
- optional `STEP`, `2SID`, billboard mode

The managed motion path mirrors all three key processors, including persistent
per-instance alpha/draw state and texture-key STEP selection.

`Conquer.Graphics.Mesh.StaticMeshVertex` now mirrors the verified `PhyOutVertex`
layout exactly: position at `+0x00`, normal at `+0x0C`, packed diffuse ARGB at
`+0x18`, and UV at `+0x1C`, total size `0x24`. `C3PhyDiffuseColor` mirrors the
native component conversion and ARGB packing, and both CPU-skinned output and
rigid/static vertex-buffer updates write that packed value. The OpenGL vertex
declaration reads the little-endian D3DCOLOR bytes as normalized BGRA and the
vertex shader swizzles them back to RGBA.

The managed renderer caches the last uploaded rigid-mesh diffuse value alongside
the shared GPU submesh resource. This is the cross-instance adaptation of native
`C3Phy.cachedDiffuseColor`: a shared VBO must be refreshed whenever the next
rendered entity needs a different per-instance color.

Real-client E2E coverage:
- `10_work/tests/Conquer.Tests/Assets/Mesh/PhySubmeshReaderRealClientTests.cs`
- Parses all PHY chunks from full loose client C3 fixtures and asserts structural parity invariants.

## Per-submesh texture binding (verified via BNinja 2026-03-01)

### Texture change API

```c
// Phy_ChangeTexture (ordinal 69, 0x1000E0F0)
void Phy_ChangeTexture(C3Phy* phy, int textureId);
// Assembly: mov [ecx+0x20], eax  →  writes phy->baseTextureId

// Phy_ChangeMixTexture (ordinal 68, 0x1000E100)
void Phy_ChangeMixTexture(C3Phy* phy, int textureId);
// Assembly: mov [ecx+0x24], eax  →  writes phy->mixTextureId
```

- `textureId` is an index into the global `g_pTexDB` texture database array.
- Value `-1` means no texture bound (sentinel).
- On-disk PHY payload contains a texture *name string* (parsed at load time), but the actual texture binding at draw time is entirely id-driven through these functions.

### Texture binding in `Phy_DrawNormal_CPU`

`Phy_DrawNormal_CPU` reads each C3Phy's `baseTextureId` (+0x20) and
`mixTextureId` (+0x24) to look up D3D texture pointers at `g_pTexDB[id]+0x0C`.

Verified base cases:

- `baseTextureId == -1`: disable stage-0 color and bind no stage-0 texture;
- valid base with `mixTextureId == -1`: bind the base texture to stage 0;
- valid base and mix IDs: dispatch by `C3_TEX_SHADER_DESC.mode`.

Verified mode `17` branch (`0x1000D0FF`):

1. Bind the base texture to stage 0.
2. Bind the mix/secondary texture to stage 1.
3. Set stage-1 `COLOROP = D3DTOP_MODULATE2X (5)`.
4. Set stage-1 `ALPHAOP = D3DTOP_SELECTARG2 (3)`.
5. Set stage-1 `TEXCOORDINDEX = D3DTSS_TCI_CAMERASPACENORMAL (0x10000)`.

With the native default stage arguments, the resulting RGB is the saturated
`2 * current/base * secondary` modulation. Stage-1 alpha selects the incoming
current/base alpha, so the secondary texture does not replace alpha. The
secondary 2D texture is sampled with the transformed camera-space normal and
the stage-1 wrap addressing established by `Init3DEx`.

After the draw, modes `>=17` reset stage 0 and stage 1 texture-coordinate
indices to pass-through. When a mix texture was bound, the common cleanup
disables stage-1 color/alpha operations and unbinds stage 1.

Each submesh in a C3DObjX container independently holds its own `baseTextureId` and `mixTextureId`, enabling per-submesh texturing within a single mesh file.

Clean loose 5517 client data confirms this path is live:

- `ini/armor.dbc`: one mode-17 descriptor
  (`model/object/primary=950000000`, `secondary=999950000`);
- `ini/weapon.dbc`: fifty mode-17 descriptors across five shared object/texture
  groups;
- every nonzero secondary texture ID in the configured loose MESH tables has
  `meshStateId=17`, and every mode-17 descriptor has a nonzero secondary ID
  (51 total).

### Texture resolution flow

1. **Load time**: `Phy_Load` reads the texture name string from the PHY payload; the name is stored at `C3Phy+0x00` (`textureNamePtr`). This string also serves as the **submesh identifier** for `C3DObjX_FindSubmeshIndexByName` (verified 2026-03-16). No texture DB lookup happens here.
2. **Bind time**: Higher-level code (e.g. `C3DObjX_SetPrimaryTexture`) calls `Phy_ChangeTexture(phy, id)` to set the numeric texture DB index.
3. **Draw time**: `Phy_DrawNormal_CPU` reads `phy->baseTextureId` and fetches the D3D texture from `g_pTexDB`.

### Multi-submesh iteration (see also `12_meshcreate_and_c3dobjx.md`)

`C3DObjX_Render` iterates all submesh pointers (`C3DObjX+0x14`, count at `C3DObjX+0x10`, max 16):

```
for i in 0..submeshCount:
    if skipFlag[i] (byte at C3DObjX+0x54+i): continue
    Phy_SetStepCount(phy[i], stepFramePosition)
    Phy_Calculate(phy[i], ...)       // consumes live bone weights when motion is bound
    Phy_DrawNormal(phy[i], material, texShaderDesc, pipeRenderDesc, shadowDesc)

stepFramePosition++
```

`C3DObjX_Ctor` initializes the unsigned position at `C3DObjX+0x0C` to zero. Every
enabled submesh receives the same pre-increment value, then `C3DObjX_Render` increments
the position exactly once after the complete submesh loop and returns the incremented
value. The 32-bit `inc` wraps naturally. Each submesh gets its own draw call with its
own texture state. The material (`D3DMATERIAL8` at `C3DObjX+0x64`) is shared across all
submeshes.

### Managed implementation implications

For multi-submesh rendering in the managed rewrite:
- Load ALL PHY submeshes from the container (not just the first renderable one)
- Each submesh has its own texture name → resolve independently via WDF/DDS pipeline
- Each submesh gets its own VAO/VBO/EBO and texture binding
- Render loop iterates all submeshes, binding per-submesh texture before each draw call
- Shared material/lighting state can be set once before the loop

### Managed render state parity (verified 2026-03-01)

OpenGL 4.1 equivalents for the native D3D8 render state pipeline:

| Native D3D8 | OpenGL 4.1 | Notes |
|-------------|-----------|-------|
| D3DRS_ALPHABLENDENABLE=TRUE | `glEnable(GL_BLEND)` | Global, set once |
| D3DRS_SRCBLEND=SRCALPHA(5) | `glBlendFunc(GL_SRC_ALPHA, ...)` | Per-submesh via desc |
| D3DRS_DESTBLEND=INVSRCALPHA(6) | `glBlendFunc(..., GL_ONE_MINUS_SRC_ALPHA)` | Per-submesh via desc |
| D3DRS_ALPHATESTENABLE + ref | Fragment shader `discard` | Core profile has no fixed alpha test |
| D3DRS_CULLMODE=NONE (`has2SidTag==0`) | `glDisable(GL_CULL_FACE)` | Selected from `C3Phy+0x05`, not the PHY discriminator |
| D3DRS_LIGHTING | Shader-based only when native light slot 0 and descriptor `+0x08` are enabled | Clean 5517 config disables this path |
| D3DRS_SPECULARENABLE | Conditional in shader | `if (power > 0) apply specular` |

Key invariants for managed baseline renderer:
- Alpha blending: always enabled with SRC_ALPHA / ONE_MINUS_SRC_ALPHA
- Alpha test: fragment shader discards fragments with normalized alpha `< 8/255`
- Depth writes: enabled for normal Role3D draws because `C3DObjX_Render` writes descriptor `+0x08 = 1`
- Backface culling: disabled when `has2SidTag==0` (D3DCULL_NONE)
- Depth sorting: submeshes should be drawn back-to-front for correct transparency (future enhancement)
- Per-submesh key state: alpha interpolates, draw changes only on exact keyed frames,
  and both persist when their processors return false
- Material opacity: `Diffuse.a *= alphaOpacity`; skip draw unless
  `drawEnabled && faceCount > 0 && alphaOpacity > 0`
- Lighting: remain unlit for the clean 5517 target because its parsed
  `graphic.ini` sets `lightEnabled=0`; do not inject an unverified Lambert term
