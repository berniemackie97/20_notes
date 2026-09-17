# `Role3D.dll` — Linked-part motion chain resolution

The verified path `I3DRole` takes to resolve and apply linked-part motion transforms before rendering.

## Primary functions

- `PartMap_FindEntryByName` (`0x10002140`)
- `I3DRole_AppendLinkedPartMotionLinksRecursive` (`0x100030B0`)
- `PartInfo_TryResolveMotionLinkBySubmeshName` (`0x10006310`)
- `PartInfo_ComputeWorldAndSetSubmeshMatrices` (`0x10006520`) — renamed from `PartInfo_ComputeWorldAndSetSubmeshMatrices`
- `MotionLinkCursor_InitFromNode` (`0x100053A0`)
- `MotionLinkCursor_SeekElementByIndex` (`0x100053D0`)
- `I3DRole_RenderPartByName_WithMotions` (`0x100035D0`)
- `I3DRole_BuildPartTransformByName_WithMotions` (`0x10003350`)

## Part-entry link fields

`I3DRole_AppendLinkedPartMotionLinksRecursive(partEntry, motionLinkBuffer)` gates recursion on two non-empty `std::string` fields in the role part-entry record:

- `linked_part_name`
- `linked_submesh_name`

If either string is empty, recursion stops.

If both are present:

1. `linked_part_name` is resolved via `PartMap_FindEntryByName`.
2. The resolved part's `PartInfo*` is queried using `linked_submesh_name` through `PartInfo_TryResolveMotionLinkBySubmeshName`.
3. A 12-byte motion-link record is appended to the internal chain buffer.
4. The function recurses using the linked part-entry, building an ancestor chain.

## Motion-link record contract (`12` bytes)

`PartInfo_TryResolveMotionLinkBySubmeshName(partInfo, outMotionLink, submeshName)` writes:

- `outMotionLink[0]`: primary motion blend-state pointer
- `outMotionLink[1]`: secondary motion blend-state pointer
- `outMotionLink[2]`: pointer to `partInfo` base transform matrix (`partInfo + 0x44`)

Verified source of those motion-state pointers:

- `PartInfo_SetMotionAndPrimaryFrameForAllPartMeshes` fans out to each resolved mesh instance,
  which calls `C3DObjX_SetMotionAndPrimaryFrame`
- `PartInfo_SetBlendMotionAndSecondaryFrameForAllPartMeshes` fans out to each resolved mesh
  instance, which calls `C3DObjX_SetBlendMotionAndSecondaryFrame`
- `C3DObjX_SetMotionAndPrimaryFrame` writes `phy[i]+0x40 = tracker->GetMotionByIndex(i)` and
  then `Phy_SetFrame(phy, primaryFrameIndex)`
- `C3DObjX_SetBlendMotionAndSecondaryFrame` writes `phy[i]+0x44 = tracker->GetMotionByIndex(i)`
  and then `Phy_SetBlendFrame(phy, secondaryFrameIndex)`
- `PartInfo_TryResolveMotionLinkBySubmeshName` later reads those exact per-submesh channels
  back through mesh virtual `+0x40` / `+0x44`

The function resolves `submeshName` by iterating part meshes and calling mesh virtual methods:

- `vtable[0x28]` = `C3DObjX_FindSubmeshIndexByName` (graphic.dll `0x100041A0`) — case-insensitive match
- `vtable[0x40]` = get primary blend state by submesh index
- `vtable[0x44]` = get secondary blend state by submesh index

If resolution fails (no submesh with that name found), all three output fields are set to `0`.

### Submesh name = texture name (verified BNinja 2026-03-16)

`C3DObjX_FindSubmeshIndexByName` iterates the submesh array at `meshObject+0x14` (up to `meshObject+0x10` entries). For each `C3Phy*` pointer, it dereferences `C3Phy+0x00` as a `char*` (the `textureNamePtr` field) and does `_stricmp(phy->textureNamePtr, submeshName)`.

**The texture name string embedded in each PHY chunk IS the submesh identifier.** In role body meshes, submeshes have names like `"v_armet"`, `"v_r_weapon"`, `"v_l_weapon"`, `"v_mount"`, `"v_misc"` — these are virtual attachment points that exist in the motion data to provide bone anchor positions for attached parts. The `"v_"` prefix stands for "virtual".

This was verified by tracing:
1. `Phy_LoadFromStream` (`c3_core_dll` `0x1000A300`): reads length-prefixed string → stores at `C3Phy+0x00` (`textureNamePtr`).
2. `Phy_Clear` (`c3_core_dll` `0x1000A1C0`): at `0x1000A211`, `mov dword [esi], eax` — zeros offset `0x00`.
3. `C3DObjX_FindSubmeshIndexByName`: `_stricmp(**edi_1, submeshName)` — `**edi_1` dereferences `C3Phy*` then dereferences offset `0x00`.

**Managed parity**: `PhySubmesh.TextureName` already stores this field. It must be preserved through the mesh loading pipeline and exposed for name-based submesh lookup in the motion link chain.

## Render usage

`I3DRole_RenderPartByName_WithMotions` and
`I3DRole_BuildPartTransformByName_WithMotions` share the recursive ancestor-chain
logic, but they are separate vtable operations with different tails:

- vtable `+0x0C`, `I3DRole_RenderPartByName_WithMotions`, is the draw path used
  directly by `RoleView_SharedRenderComposite`. It accumulates the recursive
  ancestor links only.
- vtable `+0x7C`, `I3DRole_BuildPartTransformByName_WithMotions`, is a separate
  transform-query helper. After the ancestor chain, it performs one additional
  lookup against the target `PartInfo` using its `targetSubmeshName` argument.

For every resolved ancestor link, both functions:

1. call `CMyBitmap::Motion_GetMatrix_Blend(link, boneIndex=0, &boneMatrix)`;
2. call `D3DXVec3TransformCoord(&boneMatrix._41, &boneMatrix._41,
   link.partLocalMatrix)` where `link.partLocalMatrix` is the stored
   `PartInfo+0x44` pointer;
3. multiply the adjusted bone matrix into the accumulated matrix.

Verified address range for the direct target-part leg in
`I3DRole_BuildPartTransformByName_WithMotions`:
- `0x100034C4..0x100034CD` — `PartInfo_TryResolveMotionLinkBySubmeshName(partInfo, &outMotionLink, arg2)`
- `0x100034CD..0x10003504` — `Motion_GetMatrix_Blend(&outMotionLink, 0, &boneMatrix)` then
  `MatrixMultiplyDispatch(arg3, &boneMatrix, arg3)`

## Transform accumulation detail (verified BNinja 2026-03-14)

### `I3DRole_RenderPartByName_WithMotions` (`0x100035D0`)

This is the vtable `+0x0C` animation/draw entry point. For each part being rendered:

1. Builds the linked motion-link chain via `I3DRole_AppendLinkedPartMotionLinksRecursive`.
2. Iterates motion links from chain with `MotionLinkCursor_SeekElementByIndex`:
   - For each link, calls `CMyBitmap::Motion_GetMatrix_Blend(link, boneIndex=0, &boneMatrix)`.
   - Transforms only `boneMatrix._41/_42/_43` through the link-owning
     `PartInfo+0x44` matrix with `D3DXVec3TransformCoord` (`0x1000370B`).
   - Accumulates: `worldMatrix = boneMatrix × worldMatrix` (bone matrix applied BEFORE existing world matrix).
3. Calls `PartInfo_ComputeWorldAndSetSubmeshMatrices` with the accumulated world matrix and position matrix.

`RoleView_SharedRenderComposite` calls this vtable slot directly with the model
and position matrices it builds at `RoleView.dll:0x10003903..0x10003A79`. It does
not call the vtable `+0x7C` transform-query helper first. Therefore the direct
target-submesh leg below is not part of the RoleView render path.

### `I3DRole_BuildPartTransformByName_WithMotions` (`0x10003350`)

This is the separate vtable `+0x7C` transform-query helper. It is not a preparatory
call made by `RoleView_SharedRenderComposite` before vtable `+0x0C` rendering.

Verified flow from the current BNinja decompile:

1. Initializes `arg3` to identity (`0x1000337D..0x100033B3`).
2. Builds the linked ancestor chain via `I3DRole_AppendLinkedPartMotionLinksRecursive`
   (`0x10003436`).
3. Iterates each ancestor link:
   - `MotionLinkCursor_SeekElementByIndex` (`0x1000346A`)
   - `CMyBitmap::Motion_GetMatrix_Blend(var_90, 0, &boneMatrix)` (`0x1000347A`)
   - `D3DXVec3TransformCoord(&boneMatrix._41, &boneMatrix._41,
     link.partLocalMatrix)` (`0x10003497`)
   - `MatrixMultiplyDispatch(arg3, &boneMatrix, arg3)` (`0x100034A3`)
4. Resolves the target part's own requested submesh name on the current `PartInfo`:
   - `PartInfo_TryResolveMotionLinkBySubmeshName(partInfo, &outMotionLink, arg2)` (`0x100034C4`)
5. When that direct lookup succeeds:
   - `CMyBitmap::Motion_GetMatrix_Blend(&outMotionLink, 0, &boneMatrix)` (`0x100034DA`)
   - `MatrixMultiplyDispatch(arg3, &boneMatrix, arg3)` (`0x10003504`)

Managed parity consequence:

- the RoleView render implementation must accumulate recursive ancestor links only;
- each sampled ancestor bone matrix must have its translation transformed by the
  ancestor slot's `PartInfo+0x44` local matrix before accumulation;
- the direct target-submesh lookup belongs only to a managed equivalent of the
  separate transform-query helper and must not be inserted into the draw path.

### `PartInfo_ComputeWorldAndSetSubmeshMatrices` (Role3D.dll) — Per-part matrix computation

Computes the final matrices and applies them to all PHY submeshes:

```
result = partLocal(+0x44) × worldMatrix × posMatrix
```

Then calls `C3DObjX` vtable `+0x6C` (`SetMatrices`) with three matrices for all PHY submeshes:
- `arg2` → `phy+0x74` (objectToWorldMatrix)
- `arg3` → `phy+0xB4` (localMatrix)
- `arg4` → `phy+0xF4` (worldMatrix — used by `SetTransform(D3DTS_WORLD)`)

### `PartInfo_SetMotionMatrixOrReset` (`0x100058C0`)

Sets or resets the per-part local transform matrix at `partInfo+0x44` (`partLocal`):

- When `matrixOrNull != null`: copies the 4x4 matrix to `partInfo+0x44`.
- When `matrixOrNull == null`: sets `partInfo+0x44` to **identity matrix** (4x4 with 1.0 on diagonal).

This means the default `partLocal` is identity — it has no effect on the final transform unless explicitly set.

### `PartInfo_BuildPartMatrixForFrame` (`0x100063E0`)

Builds the per-part transform for a specific frame by:
1. Sampling the bone matrix from the motion link chain (bone 0 of each ancestor).
2. Multiplying into the part's world matrix.
3. Applying `partLocal` as a prefix: `partLocal × accumulated`.

### Static body mesh animation architecture

For a **single-part body mesh** (StaticPacked `'4'` type, no per-vertex bone weights):

1. The 84-bone motion is the **shared role skeleton motion** used by the PartInfo multi-part system.
2. Individual parts (head, weapon, armor body) are driven by specific bones via motion link chains.
3. `I3DRole_RenderPartByName_WithMotions` samples bone 0 from each resolved ancestor link.
4. Each sampled bone translation is transformed by the ancestor `PartInfo+0x44`
   local matrix before the bone matrix is accumulated.
5. `PartInfo_ComputeWorldAndSetSubmeshMatrices` computes `partLocal × worldMatrix × posMatrix` and copies to all PHY submeshes.
6. `Phy_DrawNormal_CPU` uses `SetTransform(D3DTS_WORLD, &phy->worldMatrix)` at `C3Phy+0xF4`.
7. Vertex positions in the GPU buffer are NOT modified — they stay in bind pose.

**Without the full multi-part system** (linked motion chains per part), a body mesh stays in bind pose. The motion data alone (84 bones, 21 frames) is not useful as a rigid-body transform for the whole mesh — bone 0 at frame 0 has `row0=(0.12,0.22,0.97)` `row3=(16.3,27.3,-112.3)`, which is the root bone's world-space pose with major rotation and large translation, NOT a valid rigid-body transform.

### Render path selection for static meshes

The earlier claim that Role3D selects the lite path through its final byte argument was
incorrect. The verified call chain is:

- `I3DRole_RenderPartByName_WithMotions` calls `PartInfo_RenderAllParts(..., 0, role+0x34)`;
- `PartInfo_RenderAllParts` forwards those final two arguments unchanged;
- `C3DObjX_Render` tests the preceding integer argument, so the literal zero selects
  `Phy_Calculate` followed by `Phy_DrawNormal`;
- the final byte from `role+0x34` is copied to a local but not consumed.

Therefore Role3D's draw path reaches `Phy_Calculate_CPU` for these mesh instances. No
static-versus-skinned selection may be inferred from the final role byte.
