# `GraphicData.dll` — index

The data layer between a model or effect id and the bytes the render stack needs.
Everything enters through the `GameDataSetQuery()` singleton.

- [00_overview.md](00_overview.md) — module role and the shape of the API.
- [01_gamedatasetquery_singleton.md](01_gamedatasetquery_singleton.md) — the
  singleton itself.
- [02_igamedataset_vtable.md](02_igamedataset_vtable.md) — the `IGameDataSet`
  vtable as `Role3D.dll` uses it.
- [06_initialization_and_data_files.md](06_initialization_and_data_files.md) —
  initialization order and every data file loaded.

## Resolution pipeline

- [14_asset_resolution_pipeline.md](14_asset_resolution_pipeline.md) — the core
  `id -> path -> bytes` path. Start here.
- [03_resource_request_semantics.md](03_resource_request_semantics.md) — request
  semantics for `mesh` and `texture`.
- [07_modelid_to_partinfo_lookup.md](07_modelid_to_partinfo_lookup.md) — model id
  to 3D object part-info (`vfn_64` / `vfn_68`).
- [08_partinfo_source_record_layout.md](08_partinfo_source_record_layout.md) — the
  part-info source record layout (`ret + 24` entries).
- [17_mesh_lod_ini_and_model_variant_resolution.md](17_mesh_lod_ini_and_model_variant_resolution.md) —
  `MeshLod.ini` and model-id variant resolution.

## Resource types

- [04_mesh_resource_loading.md](04_mesh_resource_loading.md) — the `MeshCreate`
  path.
- [09_texture_resource_object.md](09_texture_resource_object.md) — the object
  `GameDataSet_RequestTexture` returns.
- [05_motion_cache_and_default_motion.md](05_motion_cache_and_default_motion.md) —
  the motion cache and "default motion" creation.
- [10_effect_draw_resource_request.md](10_effect_draw_resource_request.md) —
  `GameDataSet_RequestEffectDrawResource`.

## Async and caching

- [19_datathread_dll.md](19_datathread_dll.md) — `DataThread.dll`, the
  `IDataThread` async work queue.
- [20_resource_request_object.md](20_resource_request_object.md) —
  `CDataThreadObj` and the finalize-to-cache dispatch.
- [21_resource_cache_structure.md](21_resource_cache_structure.md) — the resource
  cache BST.

## On-disk formats

- [11_c3_wdb_format_and_decode.md](11_c3_wdb_format_and_decode.md) — `ini/c3.wdb`
  format and decode flow.
- [12_rsdb_container_formats.md](12_rsdb_container_formats.md) — the `RSDB`
  container (`*.dbc`).
- [13_rsdb_typed_schemas.md](13_rsdb_typed_schemas.md) — the typed schemas the
  current client data actually uses.

## INI tuning files

- [15_action_transition_and_buffer_motion_ini.md](15_action_transition_and_buffer_motion_ini.md) —
  `ActionTransition.ini` and `BufferMotion.ini`.
- [16_immediate_ini_semantics.md](16_immediate_ini_semantics.md) —
  `immediate.ini`.
- [18_common_ini_and_reslimit_policy.md](18_common_ini_and_reslimit_policy.md) —
  `common.ini` tuning and the resource-limit policy files.
