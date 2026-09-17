# `graphic.dll` — Overview (C3-era Rendering Backend)
This section documents the full behavior and API surface of `graphic.dll` as used by the Conquer 5517 client.

## Goal
Provide a self-contained, implementation-ready specification of what `graphic.dll` does: rendering, text, camera, object lifetimes, configuration files, and device-loss/reset behavior.

## Where this fits
In the original client, `CQ2ClientRelease-42.0.1.exe` calls into `graphic.dll` primarily through the `CMyBitmap::*` static API surface (see `analysis/conquer_docs/Rendering/01_graphic_dll_api_surface.md`).

This documentation set focuses on the DLL itself:
- exported entry points (mangled and demangled)
- internal state (global context) and lifetime rules
- object types created by the DLL (e.g., TargetBmp/MyBitmap) and their vtables
- precise semantics for drawing, text measurement, camera transforms
- device-loss/reset and resource recreation behavior

## Documents
- `01_logging.md` — debug log file behavior
- `02_init_and_device_reset.md` — initialization and device lifecycle
- `03_camera.md` — camera globals and projection/ortho behavior
- `04_fonts_and_text.md` — font configuration, caching, and text draw

