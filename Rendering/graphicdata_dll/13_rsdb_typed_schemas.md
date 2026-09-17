# `GraphicData.dll` — typed DB schemas used by current client data

Typed record schemas implemented in the rewrite on top of the verified on-disk DB formats.

Source format details are in:

- `12_rsdb_container_formats.md`

## Common payload value type (RSDB-only)

For all RSDB tables covered here, each index record points to:

- a NUL-terminated ASCII resource path string

No additional per-record binary struct was observed in these RSDB payloads for the covered DBs.

## Typed schema: `3DObj` (`ini/3DObj.dbc`)

Loader path:

- `GameDataSet_LoadCoreRsdbDatabases` -> `GameDataSet_LoadRsdbSingleKeyIndex`

Index format:

- single-key (`u32 key`, `u32 data_offset`)

Typed record:

- `ObjectId : u32`
- `ResourcePath : string` (typically `.c3`)

Real vectors:

- `0x00987010 -> c3/effect/lifestone/stone/1.c3`
- `0x007A6021 -> C3/MountSaddle/802/8020001.C3`

## Typed schema: `3DTexture` (`ini/3DTexture.dbc`)

Loader path:

- `GameDataSet_LoadCoreRsdbDatabases` -> `GameDataSet_LoadRsdbSingleKeyIndex`

Index format:

- single-key (`u32 key`, `u32 data_offset`)

Typed record:

- `TextureId : u32`
- `TexturePath : string` (typically `.dds`)

Real vectors:

- `0x00000001 -> c3/effect/exit.dds`
- `0x003FD509 -> c3/texture/003183305.dds`

## Typed schema: `3DEffectObj` (`ini/3DEffectObj.dbc`)

Loader path:

- `GameDataSet_LoadCoreRsdbDatabases` -> `GameDataSet_LoadRsdbSingleKeyIndex`

Index format:

- single-key (`u32 key`, `u32 data_offset`)

Typed record:

- `EffectObjectId : u32`
- `ResourcePath : string` (typically `.c3`)

Schema is container-equivalent to `3DObj` (single-key id -> path map); the table remains distinct at runtime and is loaded from its own DB path (`ini/3deffectobj.dbc`).

## Typed schema: `sound` (`ini/sound.dbc`)

Loader path:

- `GameDataSet_Initialize` -> `GameDataSet_LoadRsdbSingleKeyIndex`
- target map root: `GameDataSet + 0x140` (`&arg1[0x50]` at init callsite)

Runtime lookup path:

- `GameDataSet_FindSoundResourcePathById(sound_id)`
  - constructs lookup key `{primary = sound_id, secondary = 0}`
  - lower-bound lookup via `DualKeyEntryMap_FindLowerBoundBySecondaryPrimaryKey`
  - exact-match gate returns node `resource_path`

Index format:

- single-key (`u32 key`, `u32 data_offset`)

Typed record:

- `SoundId : u32`
- `ResourcePath : string`

Fixture status (`00_clean/clean/5517/ini/c3.wdb`):

- entry present: `ini/sound.dbc`
- payload length: `8`
- parsed header: `magic = RSDB`, `entry_count = 0`

For this 5517 fixture, the table is empty (no real key->path vectors to assert), but loader and runtime lookup semantics are verified from code and vtable flow.

## Typed schema: motion DB variants

Loader path:

- `GameDataSet_LoadRolePartMotionDbByPath` -> `GameDataSet_LoadRsdbDualKeyIndex`
- startup invocation site: `GameDataSet_LoadRolePartConfigSet` iterates all `RolePart.dbc` config entries and calls `GameDataSet_LoadRolePartMotionDbByPath(motion_db_path)` for each
- duplicate `motion_db_path` values are deduplicated by `RolePartMotionDbMap_InsertOrFindByPath`

Index format:

- dual-key (`u32 key_primary`, `u32 key_secondary`, `u32 data_offset`)

Typed record:

- `PrimaryKey : u32`
- `SecondaryKey : u32`
- `ResourcePath : string` (typically `.c3`)

`SecondaryKey` is kept as a first-class typed field (do not collapse to single-key lookup).

Real vectors:

- `mountmotion`: `(0x2FBE4A41, 0x00000000) -> c3/Mount/801/101.C3`
- `weaponmotion`: `(0x78EFC384, 0x000000F4) -> c3/mesh/1050000401.c3`

Runtime lookup path (verified):

- `GameDataSet_FindRolePartMotionResourcePath(part_name, primary_key, secondary_key)`
  - `GameDataSet_FindRolePartConfigEntryValueByPartName(part_name)` -> role-part config value block
  - read `motion_db_path` from config value block
  - `RolePartMotionDbMap_FindLowerBoundByPath(motion_db_path)` -> loaded motion DB node
  - `DualKeyEntryMap_FindLowerBoundBySecondaryPrimaryKey({primary_key, secondary_key})` on that motion DB index
  - exact-match gate returns `resource_path` only when both key components match

Dual-key comparator in runtime tree index:

- tree sort order is lexicographic by `(secondary_key, primary_key)`
- payload key fields remain `(primary_key, secondary_key)` in RSDB records and rewrite APIs

## Typed schema: `RolePart` (`ini/RolePart.dbc`) — non-RSDB custom binary

Loader path:

- `GameDataSet_LoadRolePartDbc`
- `GameDataSet_LoadRolePartConfigSet`

`c3.wdb` required-table status:

- entry path: `ini/RolePart.dbc`
- `required_flag = 1` in `GameDbRequiredDbFiles`

Header:

- `u32 magic = 0x54504F52` (`"ROPT"`)
- `u32 config_count`
- `u32 custom_count`

Config record layout (`0x220` bytes each):

- `char[0x20] part_name` (NUL-terminated ASCII)
- `char[0x100] mesh_db_path` (NUL-terminated ASCII)
- `char[0x100] motion_db_path` (NUL-terminated ASCII)

Custom record layout (`0x24` bytes each):

- `u32 custom_type`
- `char[0x20] custom_part_name` (NUL-terminated ASCII)

Verified vectors from `00_clean/clean/5517/ini/c3.wdb`:

- header: `len=5704`, `magic=ROPT`, `config_count=10`, `custom_count=7`
- size invariant: `12 + config_count*0x220 + custom_count*0x24 == payload_length`
- configs:
  - `body -> mesh=ini/armor.dbc, motion=ini/3dmotion.dbc`
  - `armet -> mesh=ini/armet.dbc, motion=ini/armetmotion.dbc`
  - `r_weapon -> mesh=ini/weapon.dbc, motion=ini/weaponmotion.dbc`
  - `l_weapon -> mesh=ini/weapon.dbc, motion=ini/weaponmotion.dbc`
  - `mount -> mesh=ini/mount.dbc, motion=ini/mountmotion.dbc`
  - `misc -> mesh=ini/misc.dbc, motion=ini/miscmotion.dbc`
  - `head -> mesh=ini/head.dbc, motion=ini/headmotion.dbc`
  - `shield -> mesh=ini/shield.dbc, motion=ini/weaponmotion.dbc`
  - `mix_body -> mesh=ini/armor.dbc, motion=ini/3dmotion.dbc`
  - `mix_armet -> mesh=ini/armet.dbc, motion=ini/armetmotion.dbc`
- custom entries:
  - `(0, v_armet) (1, v_misc) (2, v_r_weapon) (3, v_l_weapon) (4, v_mount) (5, v_l_shield) (6, v_r_shield)`

## Typed schema: `Material` (`ini/Material.dbc`) — non-RSDB custom binary

Loader path:

- `GameDataSet_LoadMaterialDbc`
- lookup helper: `GameDataSet_GetMaterialByName`

`c3.wdb` required-table status:

- entry path: `ini/Material.dbc`
- `required_flag = 1` in `GameDbRequiredDbFiles`

Header:

- `u32 magic = 0x5254414D` (`"MATR"`)
- `u32 material_count`

Material record layout (`0x34` bytes each):

- `char[0x20] material_name` (NUL-terminated ASCII)
- `u32 ambient_argb`
- `u32 diffuse_argb`
- `u32 specular_argb`
- `u32 emissive_argb`
- `f32 power`

The loader converts each packed ARGB channel to float by dividing by `255` and
stores the runtime `D3DMATERIAL8` fields in Direct3D order:
Diffuse, Ambient, Specular, Emissive, then Power (`0x44` bytes).

Verified vectors from `00_clean/clean/5517/ini/c3.wdb`:

- header: `len=60`, `magic=MATR`, `material_count=1`
- size invariant: `8 + material_count*0x34 == payload_length`
- record[0]:
  - `name=default`
  - `ambient=0xFFFFFFFF`
  - `diffuse=0xFFFFFFFF`
  - `specular=0xFFFFFFFF`
  - `emissive=0x00000000`
  - `power=0.0`

## Typed schema: role-part mesh DBs (`ini/armor.dbc`, `ini/armet.dbc`, etc.) — non-RSDB custom binary

Loader path:

- `GameDataSet_LoadRolePartConfigSet` -> `GameDataSet_LoadRolePartMeshDbByPath`
- runtime lookup: `GameDataSet_FindRolePartMeshModelEntry`

Header:

- `u32 magic = 0x4853454D` (`"MESH"`)
- `u32 model_count`

Model record layout:

- `u32 model_id`
- `u32 part_count`
- `part_count` descriptors of `0x10` bytes:
  - `u32 object_id`
  - `u32 primary_texture_id`
  - `u32 secondary_texture_id`
  - `u8 mesh_state_id`
  - `u8 source_blend_mode`
  - `u8 destination_blend_mode`
  - `u8 material_index`

Notes:

- `primary_texture_id` and `secondary_texture_id` are consumed by `Role3D.dll` in
  `PartInfo_BindPerPartTexturesAndMaterial` (`0x10006620`) through
  `GameDataSetQuery()->vfn_24(texture_id, 0, 0)` and mesh virtual calls `vfn_58` / `vfn_5C`.
- `material_index` is converted to a material pointer during `GameDataSet_LoadRolePartMeshDbByPath`
  (`GraphicData.dll`, `0x1001B6C0`) and later bound by `PartInfo_BindPerPartTexturesAndMaterial` via mesh `vfn_64`.
  In-range indices select `materialsBegin[index]`; out-of-range indices select
  `materialsBegin` itself, i.e. the first material or null when no materials
  were loaded.
- `source_blend_mode` and `destination_blend_mode` are widened into the
  `PartInfo+0x154[]` and `PartInfo+0x164[]` arrays. `PartInfo_RenderAllParts`
  (`0x10005EB0`) selects them when the corresponding draw-call override is
  `UINT32_MAX`, then `C3DObjX_Render` places them in
  `C3_PIPE_RENDER_DESC+0x00/+0x04`.
- `mesh_state_id` is forwarded into Role3D per-part state stream (consumed by mesh `vfn_96` in the render path).

Verified vectors from `00_clean/clean/5517/ini/c3.wdb`:

- `ini/armor.dbc`: `len=23456`, `magic=MESH`, `model_count=977`
- first model:
  - `model_id=1000000`, `part_count=1`
  - part[0]: `object_id=1000000`, `primary_texture_id=1000000`, `secondary_texture_id=0`,
    `mesh_state_id=0`, `source_blend_mode=5`, `destination_blend_mode=6`, `material_index=0`
- clean extracted-client census:
  - seven unique MESH paths are configured by `RolePart.dbc`
  - six load successfully; `ini/shield.dbc` is referenced but absent
  - the six loaded tables contain 12,580 models and 13,558 part descriptors
  - all 13,558 descriptors use `material_index=0`

## Typed schema: `3DEffect` (`ini/3DEffect.dbc`) — non-RSDB custom binary

Loader path:

- `GameDataSet_LoadEffectDatabase` -> `GameDataSet_Load3DEffectDb`

Header:

- `u32 magic = 0x45464645` (`"EFFE"`)
- `u32 effect_count`

Top-level record layout:

- starts at payload `+0x08`
- fixed header bytes: `0x42`
- variable tail: `layer_count * 0x10`
- total record size: `0x42 + layer_count * 0x10`
- `layer_count` source field: `u16` at record offset `+0x20`
- effect identifier string: fixed `char[0x20]` at record offset `+0x00` (NUL-terminated)
- fixed-header scalar fields:
  - `u32 start_delay_ms` (`+0x22`)
  - `u32 loop_count` (`+0x26`)
  - `u32 frame_count` (`+0x2A`)
  - `u32 lifetime_ms` (`+0x2E`)
  - `f32 offset_x` (`+0x32`)
  - `f32 offset_y` (`+0x36`)
  - `f32 offset_z` (`+0x3A`)
  - `u8 render_flag` (`+0x3E`)
  - `u8 enabled_flag` (`+0x3F`)
  - `u8 visible_flag` (`+0x40`)
  - `u8 reserved_flag` (`+0x41`)

Layer item layout (`0x10` bytes each):

- `u32 start_resource_id`
- `u32 end_resource_id`
- `f32 frame_rate_scale`
- `u8 source_blend_mode`
- `u8 destination_blend_mode`
- `u8 reserved_flag_0`
- `u8 reserved_flag_1`

Runtime template expansion (`GameDataSet_Load3DEffectDb`, alloc size `0x1EC`):

- scalar fields:
  - `template+0x20` <- `layer_count`
  - `template+0x1C4` <- `start_delay_ms`
  - `template+0x1C8` <- `loop_count`
  - `template+0x1CC` <- `frame_count`
  - `template+0x1D0` <- `lifetime_ms`
  - `template+0x1D4` <- `_ftol(offset_x)`
  - `template+0x1D8` <- `_ftol(offset_y)`
  - `template+0x1DC` <- `_ftol(offset_z)`
  - `template+0x1E0` <- `render_flag`
  - `template+0x1E4` <- `visible_flag`
  - `template+0x1E8` <- `(enabled_flag != 0)`
- per-layer streams (`i` in `[0, layer_count)`):
  - `template+0x24 + 4*i` <- `start_resource_id`
  - `template+0x64 + 4*i` <- `end_resource_id`
  - `template+0xA4 + 4*i` <- `source_blend_mode`
  - `template+0xE4 + 4*i` <- `destination_blend_mode`
  - `template+0x124 + 4*i` <- `_ftol(frame_rate_scale * 100.0f)`
  - `template+0x164 + 4*i` <- `0`
  - `template+0x1A4 + i` <- `(reserved_flag_0 != 0)`
  - `template+0x1B4 + i` <- `reserved_flag_1`

Map insertion:

- inserted by effect-name key into gameDataSet effect-template map rooted at `this + 0x2C`
- duplicate key replaces existing payload pointer

Verified vectors from fixture `ini/c3.wdb`:

- header: `len=272334`, `magic=EFFE`, `effect_count=2747`
- first records:
  - `M_Fire` (`layer_count=1`, `record_size=0x52`)
  - `Flash4101` (`layer_count=1`, `record_size=0x52`)
- value-pattern evidence:
  - `loop_count` ranges include large sentinels (`99999999`, `999999999`) for persistent effects
  - blend-byte pairs are mostly `(5,6)` with bounded variant sets, consistent with blend-mode enums
- full parse invariant (real data): iterating `effect_count` records by `0x42 + n*0x10` consumes payload exactly.

## Typed schema: `3DSimpleObj` (`ini/3DSimpleObj.dbc`) — non-RSDB custom binary

Loader path:

- `GameDataSet_LoadSimpleObjectDatabases` -> `GameDataSet_Load3DSimpleObjDb`

Header:

- `u32 magic = 0x4F4D4953` (`"SIMO"`)
- `u32 record_count`

Top-level record layout:

- `u32 simple_object_id`
- `u32 pair_count`
- `pair_count` entries of:
  - `u32 primary_resource_id`
  - `u32 secondary_resource_id`

Record size:

- `0x08 + pair_count * 0x08`

Verified vectors from fixture `ini/c3.wdb`:

- header: `len=3440`, `magic=SIMO`, `record_count=210`
- first record: `simple_object_id=1`, `pair_count=1`, pair `(0x00986F7A, 0x00986F7A)`
- full parse invariant (real data): iterating `record_count` records by `0x08 + n*0x08` consumes payload exactly.

## Typed schema: `3DSimpleObjEx` (`ini/3DSimpleObjEx.dbc`) — non-RSDB custom binary

Loader path:

- `GameDataSet_LoadSimpleObjectDatabases` -> `GameDataSet_Load3DSimpleObjExDb`

Header:

- `u32 magic = 0x584D4953` (`"SIMX"`)
- `u32 record_count`

Top-level record layout:

- `u32 simple_object_id`
- `u32 item_count`
- `item_count` entries of `0x10` bytes:
  - `u32 primary_resource_id`
  - `u32 secondary_resource_id`
  - `u32 tertiary_resource_id`
  - `u8 mode`
  - `u8 flag_a`
  - `u8 flag_b`
  - `u8 bucket_index`

Record size:

- `0x08 + item_count * 0x10`

Verified vectors from fixture `ini/c3.wdb`:

- header: `len=8`, `magic=SIMX`, `record_count=0`
- parse invariant holds (`consumed == payload_length`).

## Optional single-key DBs with unresolved record payload schema

The loader table (`GameDbRequiredDbFiles` in `GameDBPack.cpp` path) includes:

- `ini/3dscene.dbc` (required-flag `0`, optional)
- `ini/3DObjProp.dbc` (required-flag `0`, optional)

For this 5517 fixture build, these entries are absent from `ini/c3.wdb` and corresponding loose files are not present in `ini/`.
So record payload semantics are not asserted yet.

Rewrite handling:

- parse as single-key RSDB when present
- expose raw key -> byte-slice access (`SingleKeyRsdbBinaryTable`)
- do not coerce payloads to path strings without direct proof

## Rewrite guidance

- Keep explicit format selection by callsite (single-key vs dual-key), matching original loader paths.
- Keep core DB load order/mapping aligned with `GameDataSet_LoadCoreRsdbDatabases(arg2=obj, arg3=effect, arg4=texture)`.
- Keep non-RSDB decoders (`EFFE`/`SIMO`/`SIMX`) separate from `RSDB` parsing logic.
- For optional DBs without proven record schema, keep raw payload access only.
- Parse path values as NUL-terminated ASCII.
- Preserve case exactly as stored (no forced normalization at decode layer).
- Keep dual-key APIs explicit for motion DBs to avoid accidental key-collision regressions.
