# `Role3D.dll` — `PartInfo` per-part record layout (as used by render + hit-test)

`Role3D.dll` copies "part records" out of `GraphicData.dll`'s model→part-info lookup structures and stores them in its own `PartInfo` container. This document defines the *observable* layout of those per-part records as used by the `PartInfo` implementation.

`PartInfo_LoadFromGameData` (`0x100057A0`) is now typed as:

```c
int __thiscall PartInfo_LoadFromGameData(
    RolePartInfo* self,
    const char* partName,
    uint32_t modelId,
    const C3Matrix4x4* optionalLocalTransform);
```

It calls `GameDataSet_FindRolePartMeshModelEntry(partName, modelId)`, copies the
returned `0x74`-byte runtime record to `RolePartInfo+0x100`, stores `modelId` at
`+0x00`, and copies the optional matrix to `+0x44`.

## Storage location

`PartInfo_GetPartRecordArray` (`0x10005FB0`) returns a pointer to the start of the per-part record array:

- `return this + 0x100` (byte offset `0x100`)

The part count is stored at:

- `this[64]` (dword at byte offset `0x100`)

## Per-part record stride

In `PartInfo_RenderAllParts` (`0x10005EB0`), the code iterates per-part records using:

- `int* rec = this + 93;`
- `++rec` per part

This indicates each per-part record is `1` dword wide *in the specific "mesh instance pointer stream"* at `this + 93`, but the record is conceptually a struct spread across multiple parallel arrays inside `PartInfo`.

## Parallel per-part fields used by `PartInfo` render/bind paths

`PartInfo_RenderAllParts(this, a2, a3, a4, a5, a6, a7, a8)` uses the following per-part fields (relative to the `meshInstance` dword slot for that same part):

Let:
- `meshInstance = *(this + 93 + i)` (dword pointer; cached "mesh instance" object)

Then the function reads:

- `partModelId = *(this + 65 + i)`
  Used as input to `PartInfo_ResolvePartMesh(partModelId)` when `meshInstance == 0`.

- `primaryTextureId = *(this + 69 + i)` (accessed as `*(rec - 24)` from `rec=this+93+i`)
  Resolved through `GameDataSetQuery()->vfn_24(primaryTextureId, 0, 0)`.
  In `PartInfo_BindPerPartTexturesAndMaterial` (`0x10006620`), this resolved pointer is bound by mesh `vfn_58`.

- `perPartStateOrOffset = *(this + 77 + i)` (accessed as `*(rec - 16)`)
  When a per-part dirty flag is clear, this is applied via `meshInstance->vfn_96(perPartStateOrOffset, 0)`.

- `defaultRenderArgument5 = *(this + 85 + i)` (accessed as `*(rec - 8)`)
  If caller-provided `a5 == -1`, the draw call uses `defaultRenderArgument5` instead.

- `defaultRenderArgument6 = *(this + 89 + i)` (accessed as `*(rec - 4)`)
  If caller-provided `a6 == -1`, the draw call uses `defaultRenderArgument6` instead.

### Streams copied but not read by the render loop

`Role3D.dll` also carries additional per-part dword streams in the same `PartInfo` storage block that are populated from `GraphicData.dll`'s part-info source records but are not referenced by `PartInfo_RenderAllParts`:

- `this + 73 + i` (dword stream at `dstPartInfo + 0x24 + 4*i`)
  Used as `secondaryTextureId`. In `PartInfo_BindPerPartTexturesAndMaterial`, it is resolved via
  `GameDataSetQuery()->vfn_24(secondaryTextureId, 0, 0)` and bound by mesh `vfn_5C`.
  `PartInfo_SetGateIdAndExtraForAllParts` can overwrite this stream at runtime.

- `this + 81 + i` (dword stream at `dstPartInfo + 0x44 + 4*i`)
  Used as `materialRecordPointer`. In `PartInfo_BindPerPartTexturesAndMaterial`, non-null values are
  passed to mesh `vfn_64` as one complete `D3DMATERIAL8`.

The exact source runtime record copied to `PartInfo+0x100` is:

```c
struct RolePartMeshRuntimeRecord {
    uint32_t partCount;                         // +0x00
    uint32_t objectIds[4];                      // +0x04
    uint32_t primaryTextureIds[4];              // +0x14
    uint32_t secondaryTextureIds[4];            // +0x24
    int32_t textureShaderModes[4];              // +0x34
    const D3DMATERIAL8* materials[4];            // +0x44
    int32_t sourceBlendModes[4];                // +0x54
    int32_t destinationBlendModes[4];           // +0x64
}; // 0x74
```

`GameDataSet_LoadRolePartMeshDbByPath` widens the serialized byte fields into
these dword arrays. For each serialized material index, an in-range index points
at that material; an out-of-range index points at `materialsBegin`, which is the
first material or null when the table is empty.

Even when a stream is not consumed by the `Role3D.dll` implementation, it remains part of the serialized/loaded part-info state that `Role3D.dll` imports and carries.

Additionally, two per-part byte flags are maintained:

- `flagA[i]` stored at `((uint8_t*)this) + 0xF8 + i`
- `flagB[i]` stored at `((uint8_t*)this) + 0xFC + i`

At the end of each per-part iteration, the render loop clears both flags for that index.

## Mesh instance pointer lifetime rules (auto-free)

`PartInfo_ReleaseAutoFreeMeshes` (`0x10005AE0`) iterates all parts and:

- if `*(this + 65 + i) == -1` (the `partModelId` field is `-1`), then:
  - if `meshInstance != 0`, it calls the mesh instance's virtual destructor (`(*mesh->vtable)[0]`) and clears the cached pointer.

This establishes that `partModelId == -1` marks a part whose mesh instance is owned by `PartInfo` and must be released when cleaning up.

## Relationship to `GraphicData.dll` part-info sources

The source of these records is the `GraphicData.dll` model→part-info lookup (`vfn_68` / `vfn_64`), documented in:

- `analysis/conquer_docs/Rendering/graphicdata_dll/07_modelid_to_partinfo_lookup.md`

`Role3D.dll` copies multiple dword fields out of the source array at `ret + 24` into these parallel arrays in its `PartInfo` container. The meaning of the source record fields is derived from how the `PartInfo` consumer uses them (as described above).
