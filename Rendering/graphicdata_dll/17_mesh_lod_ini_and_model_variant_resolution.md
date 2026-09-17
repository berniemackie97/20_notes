# `GraphicData.dll` — `MeshLod.ini` parser and model-id variant resolution

The verified `ini/MeshLod.ini` load path, and the runtime model-id selector that `Role3D.dll`-driven rendering requests go through.

## Loader entry point

- `GameDataSet_LoadMeshLodIni` (`0x1001E2A0`)

Verified behavior:

1. Opens `ini/MeshLod.ini` in text mode (`fopen("r")`).
2. If open fails, returns immediately (no hard failure propagated to initializer).
3. Clears the MeshLod RB-tree map rooted at `this + 0x374`.
4. Reads lines with `fgets`.
5. Parses each line with `sscanf("%u %u %u %u\n", ...)`.
6. Only lines with exactly 4 parsed unsigned integers are accepted.
7. For accepted lines:
   - key = first value (`modelId`)
   - value triple = second/third/fourth values
   - insert/find via `MeshLodModelVariantMap_InsertOrFindByModelId`
   - write triple into node payload (`+0x10`, `+0x14`, `+0x18`)
8. Closes file and returns.

Duplicate-key behavior:

- insert/find means duplicate keys overwrite the stored value triple for that `modelId`.

## Runtime consumer

- `GameDataSet_ResolveModelIdVariant` (`0x1001DA50`)

Verified flow:

1. Lower-bound lookup by `modelId` using `MeshLodModelVariantMap_FindLowerBoundByModelId(this + 0x374, &modelId)`.
2. Apply exact-match gate:
   - miss/end node => return input `modelId`.
3. On exact hit:
   - `variantSelector == 1` => return node `+0x14`
   - `variantSelector == 2` => return node `+0x18`
   - otherwise => return node `+0x10`

This method is invoked from the `IGameDataSet` base vtable slot `+0x74` and feeds the model id later passed to `GameDataSet_RequestMesh`.

## Initialization linkage

`GameDataSet_Initialize` (`0x10003190`) calls `GameDataSet_LoadMeshLodIni` after `GameDataSet_LoadImmediateIni` and before `GameDataSet_LoadBufferMotionIni`.

The loader return value is not checked by initializer control flow, so startup continues when `MeshLod.ini` is missing or invalid.
