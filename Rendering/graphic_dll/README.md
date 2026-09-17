# `graphic.dll` Documentation Index
Start here.

- `00_overview.md` — scope and goals
- `01_logging.md` — debug log file behavior (`./debug/YYYY_M_D.log`)
- `02_init_and_device_reset.md` — Init3DEx/Begin3D/End3D/Flip/IfDeviceLost/ResetDevice behavior
- `../c3_core_dll/08_depth_stencil_and_presentation.md` — exact depth/stencil, multisample, screen-mode, and presentation contract beneath the wrappers
- `03_camera.md` — camera state and projection/ortho behavior
- `04_fonts_and_text.md` — font ini parsing, font cache, text draw entry points
- `05_render_targets_and_textures.md` — TargetTexture/TargetBmp lifecycle and D3D render target binding
- `06_targetbmp.md` — TargetBmpCreate/TargetBmpCreateEx object construction and initialization
- `07_mybitmap.md` — MyBitmapCreate/MyBitmapCreateEx object construction, loading, and sprite backing
- `10_exports.md` — exported symbols (API surface of the DLL)
- `11_c3_core_dll_imports.md` — `graphic.dll` imports from `c3_core_dll.dll` (dependency map)
- `12_meshcreate_and_c3dobjx.md` — MeshCreate and the `C3DObjX` mesh object used by `GraphicData.dll` / `Role3D.dll`
- `13_motioncreate_and_c3motiontracker.md` — MotionCreate and the motion container used by `C3DObjX` (`C3MotionTracker`)
- `14_motion_file_loading.md` — motion file parsing (`MOTI` chunks) and resource-limit validation
- `15_effect_file_loading.md` — effect C3 chunk parsing (`SMOT`/`SHAP`/`MOTI`/`PTC*`/`PHY*`) and simple-motion wiring
