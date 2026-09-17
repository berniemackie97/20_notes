# `c3_core_dll.dll` — overview

## What this module is

`c3_core_dll.dll` is the core runtime of the client’s legacy “C3” engine. In the 5517 client it supplies most low-level rendering entry points that `graphic.dll` and other modules wrap or orchestrate:

- 3D device initialization and per-frame presentation
- device-loss probing and device reset flows
- sprite creation and sprite-based drawing helpers
- texture creation/locking/unlocking and render-target helpers
- font creation and text drawing
- additional `Phy_*` routines used by the client

## Relationship to `graphic.dll`

In 5517, `graphic.dll` is not the full renderer. It hosts:

- higher-level object glue (e.g. `CMyBitmap`, `TargetBmp`), config parsing, and wrappers
- imports from `c3_core_dll.dll` for the majority of underlying sprite/texture/font/device operations

This means a large portion of the “rendering behavior” observed at the game level is implemented in `c3_core_dll.dll`, with `graphic.dll` primarily shaping inputs and managing higher-level resources.
