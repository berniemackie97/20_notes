# `graphic.dll` — index

The `CMyBitmap::*` façade the EXE draws through. Almost every call is a wrapper
over [`c3_core_dll.dll`](../c3_core_dll/README.md); see
[11_c3_core_dll_imports.md](11_c3_core_dll_imports.md) for the dependency map.

- [00_overview.md](00_overview.md) — scope and module role.
- [10_exports.md](10_exports.md) — exported symbols.
- [11_c3_core_dll_imports.md](11_c3_core_dll_imports.md) — what this DLL calls in
  the C3 core.

## Device

- [02_init_and_device_reset.md](02_init_and_device_reset.md) — `Init3DEx`,
  `Begin3D`, `End3D`, `Flip`, `IfDeviceLost`, `ResetDevice`.
- [08_screen_dimensions_and_internal_resolution.md](08_screen_dimensions_and_internal_resolution.md) —
  screen dimensions and the internal render resolution.
- [03_camera.md](03_camera.md) — camera state, projection and ortho behaviour.

The depth, stencil, multisample and presentation contract underneath these
wrappers is in
[../c3_core_dll/08_depth_stencil_and_presentation.md](../c3_core_dll/08_depth_stencil_and_presentation.md).

## Drawing surfaces

- [05_render_targets_and_textures.md](05_render_targets_and_textures.md) —
  TargetTexture and TargetBmp lifecycle, D3D render-target binding.
- [06_targetbmp.md](06_targetbmp.md) — `TargetBmpCreate` / `TargetBmpCreateEx`
  construction and initialization.
- [07_mybitmap.md](07_mybitmap.md) — `MyBitmapCreate` / `MyBitmapCreateEx`
  construction, loading, and sprite backing.
- [04_fonts_and_text.md](04_fonts_and_text.md) — font INI parsing, the font cache,
  and text draw entry points.

## 3D objects

- [12_meshcreate_and_c3dobjx.md](12_meshcreate_and_c3dobjx.md) — `MeshCreate` and
  the `C3DObjX` mesh object used by `GraphicData.dll` and `Role3D.dll`.
- [13_motioncreate_and_c3motiontracker.md](13_motioncreate_and_c3motiontracker.md) —
  `MotionCreate` and the `C3MotionTracker` container `C3DObjX` binds.
- [14_motion_file_loading.md](14_motion_file_loading.md) — `MOTI` chunk parsing
  and resource-limit validation.
- [15_effect_file_loading.md](15_effect_file_loading.md) — effect C3 chunk parsing
  (`SMOT`, `SHAP`, `MOTI`, `PTC*`, `PHY*`) and simple-motion wiring.

## Diagnostics

- [01_logging.md](01_logging.md) — `debug.log` and `./debug/YYYY_M_D.log`.
