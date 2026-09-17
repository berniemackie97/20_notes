# Handoff: Skeletal Animation Pipeline — BNinja Verified, Ready for Docs+Impl

## Status
- **BNinja verification: DONE** for `Phy_Calculate_CPU` (the core skinning function)
- **Docs update: DONE** — CPU skinning section added to `Rendering/c3_core_dll/05_phy.md`
- **Implementation: DONE** — see `CpuSkinning.cs`, `Role3DMultiPartMeshRenderer.cs`, `Role3DPartTransformResolver.cs`
- **Motion chain wiring: DONE** — `Role3DClientSceneMultiPartRenderStage` passes `meshRenderer.TryResolveBone0Matrix` delegate into `ComputePartWorldMatrix`
- BNinja DB saved with all renames applied

**This handoff is fully closed.** See `06_hero_render_pipeline.md` for current outstanding items.

## What Was Verified (c3_core_dll.dll)

### Phy_Calculate (0x1000C7B0) — Thin Wrapper
Just calls `Phy_Calculate_CPU(arg1, arg2, arg3, arg4, arg5)` directly. No extra logic.

### Phy_SetFrame (0x1000DEF0)
Sets `motion->primarySampleFramePosition = frame % motion->frameCount`
- Motion ptr at `phy+0x40`
- Frame count at `motion+0x04`
- Writes to `motion+0x10`

### Phy_SetBlendFrame (0x1000DF20)
Sets `motion->secondarySampleFramePosition = frame % motion->frameCount`
- Motion ptr at `phy+0x44` (secondary/blend motion)
- Frame count at `motion+0x04`
- Writes to `motion+0x14`

### Phy_Calculate_CPU (0x1000BAE0) — The Core Skinning Function

**Signature:** `int Phy_Calculate_CPU(C3Phy* phy, int hasNormals, int frameIdx, D3DXVECTOR3 lightDir, bool sampleMotion)`

**High-level flow:**
1. Process animation keys (alpha/draw/texture change) from `phy+0x5C` key system
2. If draw flag (`phy+0x06`) is 0, return early (invisible)
3. Lock D3D8 vertex buffer (`phy+0x10`) with D3DLOCK_DISCARD (0x800)
4. Pack `lightColor{R,G,B}` (+0x48/4C/50) and `alphaOpacity` (+0x54) into ARGB uint32 diffuse color
5. **If `sampleMotion` is true**: iterate bone index array, call `C3MotionTracker_GetBlendedBoneMatrixAtFrame` for each bone, store in global `g_BoneMatrices` (0x100b4540)
6. **If `sampleMotion` is false**: initialize all bone matrices to identity
7. Compute UV step offsets from STEP tag params (+0x134/0x138/0x13C/0x140)
8. **For each vertex** (source stride 0x34, output stride 0x24): CPU skinning
9. Unlock vertex buffer

### Verified Internal Skinned Vertex Layout (stride 0x34 / 52 bytes)

This is the IN-MEMORY format used by Phy_Calculate_CPU. Both SkinnedPacked ('3') and SkinnedSparse ('2') end up in this same layout after Phy_Load.

| Offset | Size | Type     | Field        | Disasm Evidence |
|--------|------|----------|--------------|-----------------|
| +0x00  | 12   | float[3] | position xyz | `mov eax,[edx]; [edx+4]; [edx+8]` |
| +0x0C  | 4    | float    | UV.u         | `fadd [eax+edi+0xc]` at 0x1000C57D |
| +0x10  | 4    | float    | UV.v         | `fadd [ecx+edi-0x24]` at 0x1000C596 (after edi+=0x34) |
| +0x14  | 4    | `float`  | reservedAt0x14 | Not accessed in verified skinning loop |
| +0x18  | 4    | uint32   | boneIndex2   | `mov eax,[ecx+0x18]; shl eax,6; add eax,0x100b4540` |
| +0x1C  | 4    | uint32   | boneIndex1   | `mov eax,[ecx+0x1c]; shl eax,6; add eax,0x100b4540` |
| +0x20  | 4    | float    | boneWeight2  | `fld st0,[ecx+0x20]` |
| +0x24  | 4    | float    | boneWeight1  | `fld st0,[ecx+0x24]` |
| +0x28  | 12   | float[3] | normal xyz   | `lea eax,[edx+edi+0x28]` for Vec3TransformNormal |

### Skinning Math (per vertex)
```
blendedMatrix = boneWeight1 * g_BoneMatrices[boneIndex1]
              + boneWeight2 * g_BoneMatrices[boneIndex2]

// Element-wise 4x4 matrix blend (16 float muls + 16 float adds per bone)
// NO quaternion decomposition, NO slerp, NO orthonormalization

transformedPos    = Vec3TransformCoord(position, blendedMatrix)
transformedNormal = Vec3TransformNormal(normal, blendedMatrix)  // only if hasNormals
```

**Key: exactly 2 bones per vertex. Always.**

### Bone Index Array (NEW field discovery)
- `phy+0x154`: bone index array start pointer (uint32*)
- `phy+0x158`: bone index array end pointer
- This is a `std::vector<uint32_t>` — the set of bone indices referenced by this submesh
- Separate from the 3 bone groups at +0x5C..+0x70 (those have element size 0x10, different purpose)
- Used to know which bones to sample from the motion data before the skinning loop

### Motion Pair (passed to bone sampling)
- `phy+0x40`: primary motion pointer (C3Motion*)
- `phy+0x44`: secondary/blend motion pointer (C3Motion*)
- Constructed as `C3MotionBlendPair` on stack, passed to `C3MotionTracker_GetBlendedBoneMatrixAtFrame`

### Output Vertex (stride 0x24 / 36 bytes) — SAME as static mesh GPU vertex
| Offset | Size | Type     | Field   |
|--------|------|----------|---------|
| +0x00  | 12   | float[3] | transformed position |
| +0x0C  | 12   | float[3] | transformed normal |
| +0x18  | 4    | uint32   | packed ARGB diffuse |
| +0x1C  | 4    | float    | UV.u + step_u_offset |
| +0x20  | 4    | float    | UV.v + step_v_offset |

### UV Step Animation
STEP tag values at +0x13C (u_scale) and +0x140 (v_scale) combined with step count (+0x134) and current frame (+0x138) compute per-frame UV offsets added to each vertex's UV. This is texture scrolling/tiling animation.

## What Still Needs Doing

### 1. Update docs (05_phy.md)
Add a "Skeletal animation / CPU skinning" section with the above findings.

### 2. Verify PhySubmeshReader alignment
Check that our existing `PhySubmeshReader.cs` stores skinned vertex data in a layout compatible with the above. The parser already handles all 4 PHY types — verify the bone index/weight field offsets match.

Key question: does our parser store SkinnedSparse ('2') vertices as 0x58 bytes (raw disk) or 0x34 bytes (internal)? The native engine uses 0x34 stride for ALL skinned types in Phy_Calculate_CPU.

### 3. Implement skinned mesh pipeline
- Parse bone indices/weights from PhySubmesh vertex data
- Load MOTI chunks from C3 containers (parsers exist: `C3Motion_LoadFromStream` in doc 12)
- Sample bone matrices at a given frame (logic in doc 13)
- CPU skinning: blend 2 bone matrices per vertex, transform pos+normal
- Feed transformed vertices into existing GPU vertex format (same as static)
- Animation loop: advance frame, re-skin, update VBO

### 4. BNinja work remaining (separate slice)
- graphic.dll `C3MotionTracker_Ctor` and motion loading orchestration — how MOTI chunks connect to PHY submeshes
- The bone index vector at +0x154 — where/when it gets populated (likely during mesh load or motion bind)
- Key_Process* functions (alpha/draw/texture animation keys) — lower priority

## Existing Docs to Read
- `Rendering/c3_core_dll/12_motion_load_formats.md` — MOTI payload parsing (KKEY/ZKEY/XKEY)
- `Rendering/c3_core_dll/13_motion_sampling_and_blend.md` — bone matrix interpolation + blend
- `Rendering/c3_core_dll/14_simple_motion_load_formats.md` — SMOT (simple motion)
- `Rendering/c3_core_dll/05_phy.md` — full PHY struct layout + render state

## Existing Code
- `PhySubmeshReader.cs` — already parses all 4 PHY types including skinned
- `C3MeshContainerReader.cs` / `C3EffectContainerReader.cs` — container parsers (PHY + MOTI chunks)
- `FirstStaticMeshAssetLoader.cs` — static-only pipeline, has `IsStaticPhyType` filter that skips skinned
- Coverage tests found exactly 3 skinned PHY chunks across 606 mesh files (rare in loose files, common in character C3s)
- 617 tests passing, 0 failures

## Key Architectural Decision
Native does CPU skinning (transforms every vertex every frame on CPU). For managed rewrite options:
1. **CPU skinning** (parity-first): same approach, update VBO each frame
2. **GPU skinning** (modern): upload bone matrices as uniform, skin in vertex shader
   - Better performance but different code path from native
   - User preference was parity-first approach
