# `GraphicData.dll` — Model ID → 3D object part-info lookup (`vfn_64` / `vfn_68`)

`Role3D.dll` obtains per-model “part-info” records by calling two `GameDataSetQuery()` vtable methods that take a `modelId` and return a pointer to a part-info structure.

These methods are used by `Role3D.dll` when initializing `Simple3DObj` and `I3DRole` part containers.

## `GameDataSet_Find3DObjPartInfoPtrByModelId(modelId)` (vtable offset `+0x40`)

Vtable offset: `+0x40` (index `16` within `g_IGameDataSet_BaseVtbl` at `0x10030190`) →
`GameDataSet_Find3DObjPartInfoPtrByModelId` (`0x1001CCF0`).

Return value:

- returns `0` if `modelId` is not found
- otherwise returns a pointer read from an internal map node field at `node + 16`

Verified backing store:

- `GameDataSet_LoadSimpleObjectDatabases` calls `GameDataSet_Load3DSimpleObjDb`
- `GameDataSet_Load3DSimpleObjDb` (`0x1001C89E`) opens `ini/3DSimpleObj.dbc`
- each accepted record allocates `0x28` bytes and stores:
  - `+0x00` = `simple_object_id`
  - `+0x04` = `pair_count`
  - `+0x08 + 4*i` = pair `primary_resource_id`
  - `+0x18 + 4*i` = pair `secondary_resource_id`
- that allocated pointer is inserted into the RB-tree rooted at `GameDataSet + 0x0C`
- `GameDataSet_Find3DObjPartInfoPtrByModelId(modelId)` is exactly the lookup over that
  pointer-tree and returns the pointer payload from `node + 0x10`

`Role3D.dll` treats the returned pointer as a `PartInfoSource*` and reads:

- `*(ret + 4)` as a part-count
- part records starting at `ret + 24`

## `GameDataSet_Find3DObjPartInfoInlineByModelId(modelId)` (vtable offset `+0x44`)

Vtable offset: `+0x44` (index `17` within `g_IGameDataSet_BaseVtbl` at `0x10030190`) →
`GameDataSet_Find3DObjPartInfoInlineByModelId` (`0x1001C820`).

Return value:

- returns `0` if `modelId` is not found
- otherwise returns `node + 16` (an “inline” part-info structure embedded inside the map node)

`Role3D.dll` treats `node + 16` as a `PartInfoSource*` with the same field usage as above:

- `*(ret + 4)` is the part-count
- part records start at `ret + 24`

## How `Role3D.dll` uses these lookups

In `Simple3DObj_SetModelId_LoadPartInfo` (`Role3D.dll`, `0x10007230`):

1. Calls `GameDataSet_Find3DObjPartInfoInlineByModelId(modelId)` first.
2. If that returns `0`, calls `GameDataSet_Find3DObjPartInfoPtrByModelId(modelId)`.
3. Copies the resulting part records into Role3D’s own `PartInfo` container.

That means the standard `RoleView` type-4 NPC / task-NPC path ultimately resolves
`Npc.ini::SimpleObjID` through the `3DSimpleObj.dbc` pointer-map (`GameDataSet + 0x0C`)
unless a matching `3DSimpleObjEx.dbc` inline entry exists first.

For the current managed client slice, this lookup order matters directly:

- standard type-4 NPC/simple-object rendering is now wired through the shared GL role pass
  as a single `"body"` part
- the managed runtime consumes the verified pointer-map branch (`3DSimpleObj.dbc`) today
- if the inline branch (`3DSimpleObjEx.dbc`) hits, that model remains intentionally unresolved
  until the 16-byte per-item layout is decoded far enough to map it into resolved parts without
  inventing semantics

The resulting `PartInfo` per-part record usage and layout is documented in:

- `analysis/conquer_docs/Rendering/role3d_dll/06_part_record_layout.md`

The source record field layout (as copied by `Role3D.dll`) is documented in:

- `analysis/conquer_docs/Rendering/graphicdata_dll/08_partinfo_source_record_layout.md`

## Notes

These lookup methods do not themselves load meshes/motions; they return a per-model part-record list that `Role3D.dll` later resolves into mesh instances through `GameDataSet_RequestMesh(...)` and related resource-request methods.
