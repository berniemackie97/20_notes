# Rendering / UI / Animation — Index

This section documents the client’s rendering stack, UI drawing paths, and visual object integration.

## Subsections
- `00_rendering_gap_analysis.md` — Windows-specific and DLL boundary observations (verified)
- `01_graphic_dll_api_surface.md` — EXE import surface into `graphic.dll` (verified)
- `02_roleview_object_interface.md` — EXE-side observed `RoleViewCreate` object interface (verified)
- `03_targetbmp_and_mybitmap_object_interfaces.md` — EXE-side observed TargetBmp/MyBitmap object interfaces (verified)
- `04_static_mesh_baseline_runtime.md` — deterministic static mesh baseline runtime selection and real-client topology evidence

## DLL deep-dives
- `graphic_dll/README.md` — internal behavior of `graphic.dll` (device, camera, fonts, etc.)
- `c3_core_dll/README.md` — internal behavior of `c3_core_dll.dll` (C3 engine primitives)
- `graphicdata_dll/README.md` — internal behavior of `GraphicData.dll` (`GameDataSetQuery` and render-driving data access)
- `roleview_dll/README.md` — internal behavior of `RoleView.dll` (exports/imports + `RoleViewCreate` dispatch)
- `role3d_dll/README.md` — internal behavior of `Role3D.dll` (exports + runtime object interfaces)
- `ndsound_dll/README.md` — internal behavior of `NDsound.dll` (legacy `DX*` audio wrapper contracts)
