# `GraphicData.dll` — Part-info source record layout (`ret + 24` entries)

`GraphicData.dll` exposes per-model “part-info source” structures through the model-id lookup vtable methods documented in:

- `analysis/conquer_docs/Rendering/graphicdata_dll/07_modelid_to_partinfo_lookup.md`

The returned structure has:

- `*(ret + 4)` = `partCount`
- an array of per-part source records starting at `ret + 24`

This document defines the *field offsets that are observable from consumers* (currently `Role3D.dll`) by analyzing the exact copy loop used when `Role3D.dll` imports those records into its own `PartInfo` container.

## Source record stride

`Role3D.dll` iterates the source records by doing `src += 4` bytes per part (dword stride) and reading multiple fields at fixed byte offsets from that moving base pointer.

This establishes that the per-part source record is laid out as *multiple parallel dword arrays* rather than a single contiguous struct-per-part.

## Fields consumed by `Role3D.dll` (Type A path: `vfn_68`)

In `Simple3DObj_SetModelId_LoadPartInfo` (Role3D, `0x10007230`), when `GameDataSetQuery()->vfn_68(modelId)` returns non-null:

The copy loop initializes Role3D’s destination part arrays and then, for each part index `i`:

- Reads `srcBase = (ret + 24) + 4*i` and copies these *streams* into Role3D’s `PartInfo` storage:

| Source dword (relative to `srcBase`) | Destination stream | Role3D semantic name (from use sites) |
|---:|---:|---|
| `-0x10` | `dstPartInfo + 0x04 + 4*i` | `partModelId` (used by `PartInfo_ResolvePartMesh`) |
| `+0x00` | `dstPartInfo + 0x14 + 4*i` | `primaryTextureId` (resolved through `GameDataSetQuery()->vfn_24`, bound via mesh `vfn_58`) |
| `+0x10` | `dstPartInfo + 0x24 + 4*i` | `secondaryTextureId` (resolved through `GameDataSetQuery()->vfn_24`, bound via mesh `vfn_5C`; stream can be overridden by `PartInfo_SetGateIdAndExtraForAllParts`) |
| `+0x20` | `dstPartInfo + 0x34 + 4*i` | `perPartStateOrOffset` (passed to mesh `vfn_96` when not dirty) |
| `+0x30` | `dstPartInfo + 0x44 + 4*i` | `materialRecordPointer` (bound via mesh `vfn_64` in `PartInfo_BindPerPartTexturesAndMaterial`) |
| `+0x40` | `dstPartInfo + 0x54 + 4*i` | `defaultRenderArgument5` (used when caller `a5 == -1`) |
| `+0x50` | `dstPartInfo + 0x64 + 4*i` | `defaultRenderArgument6` (used when caller `a6 == -1`) |

Where:
- `dstPartInfo` is the pointer returned by `PartInfo_GetPartRecordArray(partInfo)` (i.e. `partInfo + 0x100`).

These seven source-field streams are exactly the streams that drive Role3D’s render/hit-test behavior documented in:

- `analysis/conquer_docs/Rendering/role3d_dll/06_part_record_layout.md`

## Fields consumed by `Role3D.dll` (Type B path: `vfn_64`)

If `vfn_68(modelId)` returns null, `Role3D.dll` falls back to `GameDataSetQuery()->vfn_64(modelId)` and uses a reduced copy:

For each part index `i`:

- Copies:
  - `*(srcBase - 0x10)` → `dstPartInfo + 0x04 + 4*i` (`partModelId`)
  - `*(srcBase + 0x00)` → `dstPartInfo + 0x14 + 4*i` (`primaryTextureId`)
- And forces two destination fields to constant values:
  - `dstPartInfo + 0x54 + 4*i` (`defaultRenderArgument5`) = `5`
  - `dstPartInfo + 0x64 + 4*i` (`defaultRenderArgument6`) = `6`

## Notes

This document describes the layout in terms of *streams* (parallel arrays) because that is how the consumer’s copy loop proves the data is arranged. For the streams that are exercised by `PartInfo_RenderAllParts`, the semantic names are taken directly from how those streams are used (mesh resolution, gate check, per-part state apply, default render parameters).
