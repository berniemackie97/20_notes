# `GraphicData.dll` — Initialization and loaded data files

The one-time initialization the `GameDataSetQuery()` singleton performs, and the on-disk data files it loads to drive the rendering and asset pipeline.

## Initialization entry point

`GameDataSet_Initialize` (`0x10003190`) is the primary initialization routine for the `GameDataSetQuery()` singleton.

On success it:

- installs the resource-limit interface for other modules (`SetResLimitInterface`),
- loads the core 3D object / effect / texture databases,
- loads additional rendering-adjacent databases and tuning files,
- starts background data threads used by the asset pipeline.

## Core databases loaded

During initialization, `GameDataSet_Initialize` calls:

`GameDataSet_LoadCoreRsdbDatabases(0, "ini/3dobj.dbc", "ini/3deffectobj.dbc", "ini/3dtexture.dbc", 0)`

Verified from callsite assembly at `GameDataSet_Initialize` (`0x1000329F..0x100032B4`):

- arg1: `0` (res-lod selector)
- arg2: `ini/3dobj.dbc`
- arg3: `ini/3deffectobj.dbc`
- arg4: `ini/3dtexture.dbc`
- arg5: `0` (optional custom role-part dbc path)

These `.dbc` files contain string paths to `.c3` resources (mesh/effect/etc). For example, `ini/3DObj.dbc` includes `c3/mesh/... .c3` paths.

`ini/3dobj.dbc`, `ini/3deffectobj.dbc`, and `ini/3dtexture.dbc` are `RSDB` containers parsed through the single-key RSDB loader (`GameDataSet_LoadRsdbSingleKeyIndex`).

## `ini/c3.wdb` load/update phase

Before loading the standard `.dbc` set, initialization opens/updates `ini/c3.wdb` through:

- `GameDbPack_GetSingletonState` (`0x10027D40`)
- `GameDbPack_LoadAndUpdateC3Wdb` (`0x100280A0`)

This path builds an in-memory hash index of `c3.wdb` entry descriptors and serves named `.dbc` payload reads through `GameDbPack_GetEntrySizeByName` / `GameDbPack_ReadEntryByName`.

Exact `c3.wdb` format/decrypt/hash details are documented in:
`11_c3_wdb_format_and_decode.md`

`RSDB` payload container layouts (single-key and dual-key index formats) are documented in:
`12_rsdb_container_formats.md`

Typed schemas currently verified (RSDB and non-RSDB `.dbc` payloads) are documented in:
`13_rsdb_typed_schemas.md`

## Additional files loaded

The initialization routine also loads:

- `ini/3DEffect.dbc` (`GameDataSet_Load3DEffectDb` via `GameDataSet_LoadEffectDatabase`)
- `ini/3DSimpleObj.dbc` (`GameDataSet_Load3DSimpleObjDb` via `GameDataSet_LoadSimpleObjectDatabases`)
- `ini/3DSimpleObjEx.dbc` (`GameDataSet_Load3DSimpleObjExDb` via `GameDataSet_LoadSimpleObjectDatabases`)
- `ini/3dscene.dbc` (scene database)
- `ini/sound.dbc` (sound database)
- `ini/3DObjProp.dbc` (3D object properties)
- `ini/ActionTransition.ini` (`GameDataSet_LoadActionTransitionIni`, `0x1001CF90`)
- `ini/immediate.ini` (`GameDataSet_LoadImmediateIni`, `0x1001DC10`)
- `ini/MeshLod.ini` (`GameDataSet_LoadMeshLodIni`, `0x1001E2A0`)
- `ini/BufferMotion.ini` (`GameDataSet_LoadBufferMotionIni`, `0x1001D530`)
- `common.ini` tuning values (`GameDataSet_LoadCommonIniTuning`, `0x10003790`)
- `ini/ResLimit.dat` + `ini/ResLimitExclude.dat` (`GameDataSet_LoadResLimitDatabases`, `0x10029E80`)

Notes for this 5517 build:

- `GameDataSet_LoadRsdbSingleKeyIndex` is tolerant when `GameDbPack_GetEntrySizeByName` returns `0` (it returns early).
- `GameDataSet_LoadSimpleObjectDatabases` and `GameDataSet_LoadEffectDatabase` always return success to the caller; missing/invalid per-file loads are logged inside their leaf loaders.
- `ActionTransition.ini` / `immediate.ini` / `MeshLod.ini` / `BufferMotion.ini` loader return values are not checked by `GameDataSet_Initialize`; startup continues even when these loaders fail.
- `GameDataSet_LoadResLimitDatabases` return value is not checked by `GameDataSet_Initialize`; startup continues if `ResLimit.dat` / `ResLimitExclude.dat` are missing or invalid.
- `ini/3dscene.dbc` and `ini/3DObjProp.dbc` are absent in fixture `ini/c3.wdb`; this follows the optional-file path in the required-file table (`required_flag = 0`).
- `ini/3DSimpleObjEx.dbc` is optional (`required_flag = 0`) and present in this fixture with a valid `SIMX` header and `count = 0`.

`MeshLod.ini` parsing and runtime selector semantics are documented in:
`17_mesh_lod_ini_and_model_variant_resolution.md`

`common.ini` memory-profile tuning and `ResLimit.dat` / `ResLimitExclude.dat` policy formats are documented in:
`18_common_ini_and_reslimit_policy.md`

## How motions relate to these databases

Motion creation in the stock client is driven by the `.c3` resource path:

- `GraphicData.dll` requests a motion by passing a `.c3` resource path into `graphic.dll!MotionCreate(path, ...)`.
- `graphic.dll` loads motions by scanning that same resource for `MOTI` chunks (see `analysis/conquer_docs/Rendering/graphic_dll/14_motion_file_loading.md`).

As a consequence, the database that maps model/object IDs to `.c3` resource paths (notably `ini/3DObj.dbc`) is the key input for both mesh and motion loading.

## Notes on `ini/3dmotion.ini`

The stock client distribution contains `ini/3dmotion.ini`, but `GraphicData.dll` does not reference the literal string `ini/3dmotion.ini` in this build. The mesh/motion pipeline observed in code uses `.dbc` databases and `.c3` resource paths.
