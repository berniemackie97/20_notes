# `Role3D.dll` — index

3D entity objects and their attached effects. Driven by
[`RoleView.dll`](../roleview_dll/README.md), fed by
[`GraphicData.dll`](../graphicdata_dll/README.md).

- [00_overview.md](00_overview.md) — module role.
- [01_exports.md](01_exports.md) — exports.
- [02_imports.md](02_imports.md) — imports and external dependencies.

## Objects

- [03_simple3dobj_object.md](03_simple3dobj_object.md) — `Simple3DObj`.
- [04_i3drole_object.md](04_i3drole_object.md) — `I3DRole`, the multi-part entity
  object.

## Parts

- [05_partinfo_and_mesh_instances.md](05_partinfo_and_mesh_instances.md) —
  `PartInfo` and the per-part mesh-instance interface.
- [06_part_record_layout.md](06_part_record_layout.md) — the per-part record
  layout as used by render and hit-test.
- [07_part_stream_mutators.md](07_part_stream_mutators.md) — gate, state and
  default stream mutators.
- [12_linked_motion_chain_resolution.md](12_linked_motion_chain_resolution.md) —
  how a linked part resolves its motion through the chain.

## Effects

- [08_effect_instances.md](08_effect_instances.md) — the effect instance list and
  its render paths.
- [09_effect_instance_layout.md](09_effect_instance_layout.md) — instance object
  layout; creation, tick and render all proven.
- [11_effect_part_record_layout.md](11_effect_part_record_layout.md) — effect
  per-part record, 36-byte stride.
- [13_effect_tick_state_machine.md](13_effect_tick_state_machine.md) — the
  tick/update state machine.
- [10_effect_draw_resource_interface.md](10_effect_draw_resource_interface.md) —
  the virtual methods used on the draw resource.
