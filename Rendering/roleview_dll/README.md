# `RoleView.dll` — Documentation Index

This folder documents `RoleView.dll` as shipped with the Conquer Online 5517 client.

Start here:

- `analysis/conquer_docs/Rendering/roleview_dll/00_overview.md`
- `analysis/conquer_docs/Rendering/roleview_dll/01_exports.md`
- `analysis/conquer_docs/Rendering/roleview_dll/02_imports.md`
- `analysis/conquer_docs/Rendering/roleview_dll/03_roleviewcreate_dispatch.md`
- `analysis/conquer_docs/Rendering/roleview_dll/04_vtables_known.md`
- `analysis/conquer_docs/Rendering/roleview_dll/05_type5_npcex_ini.md`
- `analysis/conquer_docs/Rendering/roleview_dll/06_motion_lookup_key_construction.md`
- `analysis/conquer_docs/Rendering/roleview_dll/07_action_playback_transition_state.md`
- `analysis/conquer_docs/Rendering/roleview_dll/08_transform_look_record.md`
- `analysis/conquer_docs/Rendering/roleview_dll/09_role_scale_formula.md`
- `analysis/conquer_docs/Rendering/roleview_dll/10_transform_chain_and_rotation_convention.md`
- `analysis/conquer_docs/Rendering/roleview_dll/11_role_tickandrender_caller_walkthrough.md` — slice 13: the EXE-side per-frame hook that drives `RoleView_SharedRenderComposite`
- `analysis/conquer_docs/Rendering/roleview_dll/12_action_id_translation_state_machine.md` — slice 14: jumping remap + paired-interaction override + frame interval
- `analysis/conquer_docs/Rendering/roleview_dll/13_role_compute_frame_interval.md` — slice 15: multi-factor frame interval computation + mounted speed tables

Related (EXE-side ABI surface, already reconstructed):

- `analysis/conquer_docs/Rendering/02_roleview_object_interface.md`
