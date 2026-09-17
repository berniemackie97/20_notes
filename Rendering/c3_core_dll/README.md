# `c3_core_dll.dll` (C3 engine core) — documentation index

## Scope

This section documents `c3_core_dll.dll` as used by the Conquer Online 5517 client, with focus on the functionality that other modules call into (notably `graphic.dll`, `RoleView.dll`, and `Role3D.dll`).

In 5517, `c3_core_dll.dll` supplies most low-level rendering entry points: device lifecycle (`Init3DEx`, `Begin3D/End3D`, `Flip`), device-loss probing (`IfDeviceLost`) and reset (`ResetDevice`), plus sprite/texture/font primitives used by `graphic.dll` objects such as `CMyBitmap`.

## Documents

- `00_overview.md`
- `01_device_lifecycle.md`
- `02_sprites.md`
- `03_textures.md`
- `04_fonts.md`
- `05_phy.md`
- `06_image_decoders.md`
- `07_texture_upload.md`
- `08_depth_stencil_and_presentation.md`
- `10_exports.md`
- `11_datafile_and_wdf.md`
- `12_motion_load_formats.md`
- `13_motion_sampling_and_blend.md`
- `14_simple_motion_load_formats.md`
- `15_shape_load_formats.md`
- `16_particle_load_formats.md`
- `17_particle_draw_sampling.md`
- `18_sprite_rotate_native_contract.md` — integer degrees, current-vertex pivot, in-place rotation, callers, and CPU-specific numerical behavior.

## Naming and evidence rules

- Keep names consistent with IDA renames once verified.
- Do not use placeholder names in the docs; if an item cannot be verified yet, keep it referenced by module+address and list the concrete call-sites that demonstrate its effects.
