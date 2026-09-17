# `Role3D.dll` — Effect per-part record layout (36-byte stride)

Effect instances in `Role3D.dll` contain a per-part record array at:

- `partsBase = *(uint8_t**)effect` (i.e. `*(_DWORD*)effect`)
- `part = partsBase + 36 * i`

All three effect render backends consume the same record layout:

- `Effect_RenderWithContext` (`0x10008C30`)
- `Effect_RenderWithOffsets` (`0x10009140`)
- `Effect_RenderScreenSpace` (`0x10009570`)

This document defines each field that is *proven by use sites*.

## Record shape

The stride is exactly 36 bytes:

- 9 dwords (`uint32_t` / `int32_t`)

The render backends treat the record as `_DWORD part[9]` and read the following indices:

## Field map (dword indices)

| Dword index | Byte offset | Type | Name | Usage |
|---:|---:|---|---|---|
| `0` | `+0x00` | `uint32_t` | `resourceId` | Passed to `GameDataSet_RequestEffectDrawResource(resourceId, 0, 0)` to obtain the draw resource object. |
| `1` | `+0x04` | `uint32_t` | `secondaryId` | Passed to `GameDataSet_RequestTexture(secondaryId, 0, 0)` when `variantOrIndex < 0` (see dword 3). |
| `2` | `+0x08` | `uint32_t` | `runtimeShapeSlotCount` | Set by `EffectPart_EnsureRuntimeData` from draw-resource vtable `+0x54` (in clean 5517 `C3Effect` this resolves to `this+0x04` slot count getter). Not read by the current Role3D render/tick loops. |
| `3` | `+0x0C` | `int32_t` | `variantOrIndex` | If `>= 0`, passed to the resource as `SetIndexOrVariant(variantOrIndex)` (vtable `+0x14`). If `< 0`, the backend loads a secondary object from `secondaryId` and passes it to `SetSecondaryResource(obj)` (vtable `+0x18`). |
| `4` | `+0x10` | `uint32_t` | `unused1` | Not referenced by any effect render backend in this build. Preserve for parity. |
| `5` | `+0x14` | `uint32_t` | `particle2InfoHandle` | Init path: set from draw-resource vtable `+0x64`, then init-fed into `+0x68`. Render path: fed every draw iteration into draw-resource slot `+0x68(part[5])`. |
| `6` | `+0x18` | `uint32_t` | `particle3InfoHandle` | Init path: set from draw-resource vtable `+0x6C`, then init-fed into `+0x70`. Render path: fed every draw iteration into draw-resource slot `+0x70(part[6])`. |
| `7` | `+0x1C` | `uint32_t` | `shapeInfoHandle` | If zero, set by init path from draw-resource `+0x58`; init path calls `+0x5C(part[7])`. Render path feeds `part[7]` into draw-resource slot `+0x60` before draw, then calls slot `+0x5C(part[7])` after draw. |
| `8` | `+0x20` | `uint32_t` | `enabled` | If zero, the part is skipped and is also used as a termination condition in the per-part scan loops. |

## Creation-time initialization (`PartInfo_CreateAndAppendEffectInstanceByName`)

Per record, native creation sets:

- dword `0` (`resourceId`) from effect template `+0x24[i]`
- dword `1` (`secondaryId`) from effect template `+0x64[i]`
- dword `3` (`variantOrIndex`) to `-1`
- all remaining dwords zeroed initially

Immediately after each record is initialized, creation requests draw resource:

- `draw = GameDataSet_RequestEffectDrawResource(resourceId, 0, 0)`
- if `draw != 0`, it calls `EffectPart_EnsureRuntimeData(draw, record)`

`EffectPart_EnsureRuntimeData` then fills runtime-calculated dwords (`2`, `5`, `6`, `7`) and sets dword `8` (`enabled`) to `1`.

## Termination / skipping rule

In all effect render backends:

- If `enabled == 0`, the part is not processed.
- Some scan loops stop at the first record with `enabled == 0` (treating the array as “shortened” even if `partCount` is larger).

## Relationship to `GraphicData.dll` lookups

Two dataset queries are exercised by the effect part record:

- `GameDataSet_RequestEffectDrawResource(resourceId, 0, 0)` → returns the primary draw resource object (interface documented in `10_effect_draw_resource_interface.md`).
- `GameDataSet_RequestTexture(secondaryId, 0, 0)` → returns a secondary texture resource object; it must be non-null and must pass a readiness check via its vtable `+0x10` (`TextureResource_IsReady`) before being bound to the draw resource.
