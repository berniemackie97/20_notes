# `RoleView.dll` — Overview

`RoleView.dll` implements the client's **role/effect view objects**: heap-allocated objects created by the factory export `RoleViewCreate(int type)`, configured by the EXE through a stable vtable ABI, and rendered each frame through methods on that object.

From the EXE's perspective, `RoleView.dll` is a black-box component that:

- owns the runtime state for "visual objects" (player/NPC renderers and timed effects),
- uses `Role3D.dll` to create/drive underlying 3D role/simple-object instances, and
- uses `graphic.dll` (`CMyBitmap` statics) for camera/matrix helpers and screen-ray construction.

This folder documents `RoleView.dll` itself (exports/imports and internal behavior as it is deobfuscated).

For the already-reconstructed **EXE-side ABI surface** (vtable offsets and call patterns), see:

- `analysis/conquer_docs/Rendering/02_roleview_object_interface.md`
