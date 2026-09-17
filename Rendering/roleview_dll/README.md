# `RoleView.dll` — index

Builds and drives the visual for an entity: picks the object type, resolves which
motion to play, and composes the transform. Sits above
[`Role3D.dll`](../role3d_dll/README.md).

The EXE-side view of this DLL's objects — the vtable surface reconstructed from
call sites — is in
[../02_roleview_object_interface.md](../02_roleview_object_interface.md).

- [00_overview.md](00_overview.md) — module role.
- [01_exports.md](01_exports.md) — exports.
- [02_imports.md](02_imports.md) — imports and external dependencies.

## Construction

- [03_roleviewcreate_dispatch.md](03_roleviewcreate_dispatch.md) —
  `RoleViewCreate` type dispatch and object construction.
- [04_vtables_known.md](04_vtables_known.md) — known vtables.
- [05_type5_npcex_ini.md](05_type5_npcex_ini.md) — type 5 variant selection from
  `ini/npcex.ini`.
- [08_transform_look_record.md](08_transform_look_record.md) — the transform look
  record from `ini/Transform.ini`.

## Motion and action

- [06_motion_lookup_key_construction.md](06_motion_lookup_key_construction.md) —
  how the motion lookup key is built for `GameDataSetQuery()->+0x20`.
- [07_action_playback_transition_state.md](07_action_playback_transition_state.md) —
  action playback and transition state for type 2 and type 10.
- [12_action_id_translation_state_machine.md](12_action_id_translation_state_machine.md) —
  action-id translation: jumping remap, paired-interaction override, frame
  interval.
- [13_role_compute_frame_interval.md](13_role_compute_frame_interval.md) —
  `Role_ComputeFrameIntervalFromAction`, multi-factor, including the mounted speed
  tables.

## Transform and render

- [10_transform_chain_and_rotation_convention.md](10_transform_chain_and_rotation_convention.md) —
  `RoleView_SharedRenderComposite`: the transform chain and rotation convention.
- [09_role_scale_formula.md](09_role_scale_formula.md) — the scale formula in
  `Role_TickAndRender` (`Conquer.exe` `0x64F5F7`).
- [11_role_tickandrender_caller_walkthrough.md](11_role_tickandrender_caller_walkthrough.md) —
  the EXE-side per-frame hook that drives `RoleView_SharedRenderComposite`.
