# `Role3D.dll` — Part stream mutators (gate/state/default streams)

Helper routines in `Role3D.dll` that write per-part streams in the `PartInfo` container.

These routines are important for parity even when the written streams are not immediately consumed by `PartInfo_RenderAllParts`.

## `PartInfo_SetPerPartStateForAllParts(partInfo, value)`

`PartInfo_SetPerPartStateForAllParts` (`0x100069B0`) writes the same dword value into the per-part stream used by `PartInfo_RenderAllParts` as `perPartStateOrOffset`:

- stream: `dstPartInfo + 0x34 + 4*i` (Role3D `this + 77 + i`)

## `PartInfo_SetGateIdAndExtraForAllParts(partInfo, gateId, extra)`

`PartInfo_SetGateIdAndExtraForAllParts` (`0x10006970`) writes two per-part streams in lockstep for every part index `i`:

- `partIdOrTextureGateId` stream (used by `PartInfo_RenderAllParts`):
  - `dstPartInfo + 0x14 + 4*i` (Role3D `this + 69 + i`) is set to `gateId`
- an additional per-part stream currently not consumed by `PartInfo_RenderAllParts`:
  - `dstPartInfo + 0x24 + 4*i` (Role3D `this + 73 + i`) is set to `extra`

The semantic meaning of the `extra` stream is not established by the render loop; it must be named based on its first concrete use site outside `PartInfo_RenderAllParts`.

## Call sites

### `Simple3DObj_SetGateAndExtraAndState`

`Simple3DObj_SetGateAndExtraAndState` (`0x10007A00`) is a `Simple3DObj` method that:

- requires a non-null part-info pointer at `[this+0x48]`,
- calls `PartInfo_SetGateIdAndExtraForAllParts(partInfo, gateId, extra)`,
- then calls `PartInfo_SetPerPartStateForAllParts(partInfo, stateValue)`.

### `I3DRole_ApplyGateExtraState_ByPartNameOrAll`

`I3DRole_ApplyGateExtraState_ByPartNameOrAll` (`0x10004100`) applies the same two writes across one or more `PartInfo` instances owned by the role:

- for each targeted `PartInfo*`, it calls:
  - `PartInfo_SetGateIdAndExtraForAllParts(partInfo, gateId, extra, ...)`
  - `PartInfo_SetPerPartStateForAllParts(partInfo, stateValue)`

Selection can be "all parts" or by a specific part-name key, depending on whether a name string argument is provided.
