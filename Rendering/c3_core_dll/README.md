# `c3_core_dll.dll` — index

The C3 engine core. In 5517 it supplies most low-level rendering entry points and
is called by `graphic.dll`, `RoleView.dll` and `Role3D.dll`. This section covers
the surface those modules actually use, not the DLL's full capability.

- [00_overview.md](00_overview.md) — module role and the shape of the API.
- [10_exports.md](10_exports.md) — exported symbols by ordinal and address.

## Device and presentation

- [01_device_lifecycle.md](01_device_lifecycle.md) — `Init3DEx`, `IfDeviceLost`,
  `ResetDevice`, `Begin3D`, `End3D`, `Flip`.
- [08_depth_stencil_and_presentation.md](08_depth_stencil_and_presentation.md) —
  the exact depth, stencil, multisample and screen-mode contract retail uses.

## 2D

- [02_sprites.md](02_sprites.md) — the `Sprite_*` subsystem.
- [18_sprite_rotate_native_contract.md](18_sprite_rotate_native_contract.md) —
  `Sprite_Rotate`: integer degrees, current-vertex pivot, in-place rotation, and
  its CPU-specific numerical behaviour.
- [03_textures.md](03_textures.md) — the `Texture_*` subsystem.
- [06_image_decoders.md](06_image_decoders.md) — image decoding and container
  support for textures.
- [07_texture_upload.md](07_texture_upload.md) — `TextureUpload_ExecuteJob`.
- [04_fonts.md](04_fonts.md) — the `Font_*` subsystem.

## Meshes and motion

- [05_phy.md](05_phy.md) — the `Phy_*` routines: load order, `C3Phy` layout,
  `C3Key` processing, CPU skinning, render state, per-submesh texture binding.
  The largest document in this section.
- [12_motion_load_formats.md](12_motion_load_formats.md) —
  `C3Motion_LoadFromStream` payload formats.
- [13_motion_sampling_and_blend.md](13_motion_sampling_and_blend.md) — motion
  matrix sampling and blend parity.
- [14_simple_motion_load_formats.md](14_simple_motion_load_formats.md) —
  `C3SimpleMotion_LoadFromStream` (`SMOT`).
- [15_shape_load_formats.md](15_shape_load_formats.md) — `C3Shape_LoadFromStream`
  (`SHAP`).

## Particles

- [16_particle_load_formats.md](16_particle_load_formats.md) — `PTCL`, `PTCX`,
  `PTC3`.
- [17_particle_draw_sampling.md](17_particle_draw_sampling.md) — particle draw
  sampling semantics.

## Storage

- [11_datafile_and_wdf.md](11_datafile_and_wdf.md) — the DataFile system and the
  WDF archive format.

## Naming rules

Names here stay consistent with the IDA renames once verified. An
unverified item is referenced by module and address, with the call sites that
demonstrate its effect — never by a placeholder name.
