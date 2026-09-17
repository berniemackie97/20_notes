# `GraphicData.dll` — Core asset-resolution pipeline (`id -> path -> bytes`)

This document pins the end-to-end flow we use in the rewrite for deterministic asset resolution.

## Verified runtime flow

1. `GameDataSet_Initialize` calls `GameDbPack_LoadAndUpdateC3Wdb` to open/decode `ini/c3.wdb`.
2. `GameDataSet_LoadCoreRsdbDatabases` loads three single-key RSDB maps from `c3.wdb`:
- `ini/3dobj.dbc`
- `ini/3deffectobj.dbc`
- `ini/3dtexture.dbc`
3. Dedicated non-RSDB loaders also read:
- `ini/3DEffect.dbc` (`EFFE`)
- `ini/3DSimpleObj.dbc` (`SIMO`)
- `ini/3DSimpleObjEx.dbc` (`SIMX`, optional)
4. Additional single-key DBs are loaded through `GameDataSet_LoadRsdbSingleKeyIndex`:
- `ini/3dscene.dbc`
- `ini/sound.dbc`
- `ini/3DObjProp.dbc`
5. Required custom DBs are loaded:
- `ini/RolePart.dbc` (`ROPT`)
- `ini/Material.dbc` (`MATR`)
6. Text INI policy loaders are called:
- `ini/ActionTransition.ini` (action transition map)
- `ini/MeshLod.ini` (model-id variant map)
- `ini/BufferMotion.ini` (buffer-motion name set)
7. Runtime requests resolve IDs to virtual paths via RSDB maps and role-part mesh/material maps.
8. Virtual paths are loaded through package/loose file lookup (`DataFile_*` wrappers over WDF packages and loose files).
9. Role-part motion DBs are loaded during startup by `GameDataSet_LoadRolePartConfigSet`:
- each config record from `RolePart.dbc` calls `GameDataSet_LoadRolePartMotionDbByPath(motion_db_path)`
- each motion DB payload is parsed through `GameDataSet_LoadRsdbDualKeyIndex`
- repeated DB paths are deduplicated by the path-keyed map insert/find step
10. Role-part motion requests use `GameDataSet_FindRolePartMotionResourcePath`:
- `part_name -> RolePart.dbc config -> motion_db_path -> dual-key motion lookup -> .c3 path`

## Rewrite contract (`Conquer.Assets`)

`GraphicDataAssetResolver` mirrors this split explicitly:

- core table load from `C3WdbArchive`:
  - `ObjDbTable` (`3dobj`)
  - `ObjDbTable` (`3deffectobj`)
  - `TextureDbTable` (`3dtexture`)
- always-loaded non-RSDB support tables:
  - `EffectDbTable` (`3DEffect`)
  - `SimpleObjectDbTable` (`3DSimpleObj`)
  - `RolePartDbTable` (`RolePart`)
  - `MaterialDbTable` (`Material`)
- optional non-RSDB support table:
  - `SimpleObjectExDbTable` (`3DSimpleObjEx`)
- optional single-key raw tables:
  - `SingleKeyRsdbBinaryTable` (`3dscene`)
  - `SingleKeyRsdbBinaryTable` (`3dobjprop`)
- single-key typed sound table:
  - `SoundDbTable` (`sound`)
- optional text policy tables from client root:
  - `ActionTransitionIniTable` (`ActionTransition.ini`)
  - `MeshLodIniTable` (`MeshLod.ini`)
  - `BufferMotionIniTable` (`BufferMotion.ini`)
  - `ImmediateIniTable` (`immediate.ini`)
  - `GraphicIniLightingSettings` (`graphic.ini`; native defaults when absent
    or when fewer than seven fields parse)
- startup-loaded role-part motion DB cache from `C3WdbArchive`:
  - `MotionDbTable` by DB entry path (for example `ini/mountmotion.dbc`)
- startup-loaded role-part mesh DB cache from `C3WdbArchive`:
  - `RolePartMeshDbTable` by DB entry path (for example `ini/armor.dbc`)
- payload load from `DataFilePackageIndex`:
  - `TryLoad*` methods perform path-to-bytes via loose/package modes

## API shape used in rewrite

- object/effect/texture:
  - `TryResolveObjectPath`
  - `TryResolveEffectObjectPath`
  - `TryResolveTexturePath`
  - `TryResolveMeshTexturePath(mesh_path, texture_slot_token)`:
    - direct path probe for slot values that are already concrete paths,
    - role-part mesh back-reference probe
      (`mesh object id -> role-part model record -> primary/secondary texture id -> 3dtexture path`)
      with model-id exact match preferred before broad fallback scan,
    - texture-db basename probe for token-stem matches (last-resort fallback),
    - DDS payload validation gate before returning a concrete path
  - `TryLoadObject` / `TryLoadEffectObject` / `TryLoadTexture`
- sound:
  - `TryResolveSoundPath`
  - `TryLoadSound`
- motion-policy INI:
  - `TryGetActionTransitionTime`
  - `TryGetMeshLodEntry`
  - `ResolveModelIdVariant`
  - `IsBufferedMotionName`
  - `TryGetImmediateSection`
  - `IsImmediateResourceId`
  - `ResolveEffectiveRequestModeWithImmediatePolicy`
  - `ResolveEffectiveMeshRequestMode`
  - `ResolveEffectiveTextureRequestMode`
  - `ResolveEffectiveEffectRequestMode`
  - `ResolveEffectiveSceneRequestMode`
- optional raw DB access:
  - `TryGetSceneData`
  - `TryGetObjectPropertyData`
- non-RSDB support DB access:
  - `TryGetEffect`
  - `TryGetSimpleObject`
  - `TryGetSimpleObjectEx`
  - `TryGetRolePartConfig`
  - `TryGetMaterialByName`
  - `TryGetMaterialByIndex`
- role-part mesh resolution:
  - `TryGetRolePartMeshTable`
  - `TryResolveRolePartModel(part_name, model_id)` -> role-part config + mesh model + object/material projection
- motion:
  - `TryGetMotionTable`
  - `TryResolveMotionPath(motion_db_path, primary, secondary)`
  - `TryLoadMotion(motion_db_path, primary, secondary)`
  - `TryResolveRolePartMotionPath(part_name, primary, secondary)`
  - `TryLoadRolePartMotion(part_name, primary, secondary)`
  - `TryGetMotionContainer*` and `TryGetMotionPayload*` (runtime typed decode from resolved `.c3`)
  - `TrySampleMotionBoneMatrix*` (runtime matrix sampling parity with `Motion_GetMatrix`)
  - `TrySampleBlendedMotionBoneMatrix*` (runtime blend parity with `Motion_GetMatrix_Blend`)

## Motion runtime decode/sampling boundary

Verified split across modules:

- `GraphicData.dll` resolves motion DB keys to a virtual `.c3` path (`GameDataSet_FindRolePartMotionResourcePath`).
- `graphic.dll` parses that `.c3` file as a motion container (`C3MotionTracker_InitFromMotionFile`) and loads `MOTI` chunks.
- `c3_core_dll.dll` decodes each `MOTI` payload (`C3Motion_LoadFromStream`) and samples matrices (`Motion_GetMatrix`, `Motion_GetMatrix_Blend` exports).

Rewrite contract for this boundary:

1. Resolve `(motion_db_path, primary_key, secondary_key)` to motion resource path.
2. Load and parse the `.c3` container (`C3MotionContainerReader`) once per motion resource path.
3. Decode one `MOTI` payload (`C3MotionPayloadReader`) once per `(motion path, chunk index)`.
4. Sample matrices using `C3MotionMatrixSampler` for deterministic parity math.
5. Blend matrices by supplying two chunk/frame references from the resolved motion container:
   - primary sample uses its own frame position
   - secondary sample uses its own frame position
   - blend uses secondary blend alpha (`(1 - w) * primary + w * secondary`).

This keeps transport/path resolution in `GraphicDataAssetResolver` while preserving engine motion semantics in dedicated motion decode/sampling types.

This keeps table decode concerns separate from file transport concerns and matches original client boundaries while remaining backend-agnostic for cross-platform runtime.
