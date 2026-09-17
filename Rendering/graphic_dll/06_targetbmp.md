# `graphic.dll` — TargetBmp (`TargetBmpCreate*`)

Behaviour observed in the exported constructors for TargetBmp objects, `TargetBmpCreate` and `TargetBmpCreateEx`.

## `TargetBmpCreateEx` (0x10006610)
Decompiled signature:
```c
int* TargetBmpCreateEx(int width, int height);
```

Behavior:
1) Allocates `0x3FC` bytes.
2) Runs `TargetBmp_Ctor` to zero fields and install the vtable.
3) Calls `TargetBmp_InitCreateTextureAndIndexGrid(this, width, height, 1)`.
4) If initialization fails:
   - calls a virtual method at `vtable + 60` with argument `1` (cleanup/release semantics)
   - returns `NULL`.
5) On success returns the object pointer.

## TargetBmp object construction: `TargetBmp_Ctor` (0x10005560)
Observed effects:
- Writes the object vtable pointer to `off_10039634`.
- Clears a block at `this + 1` of size `0x64` bytes.
- Explicitly zeros several fields near the end of the object and sets `this+1016` (a byte flag) to `0`.

## TargetBmp initialization: `TargetBmp_InitCreateTextureAndIndexGrid` (0x100056A0)
Decompiled signature:
```c
char TargetBmp_InitCreateTextureAndIndexGrid(
    void* this,
    unsigned int width,
    unsigned int height,
    char useAltFormat);
```

Behavior (verified via decompile):
1) Calls `Texture_Create((C3Texture**)(this+996), width, height, 1, format, D3DPOOL_DEFAULT, 1, 1)`.
   - `format` is `(useAltFormat != 0) + 20` as `_D3DFORMAT`.
2) Zeros:
   - `this+1016` (flag byte)
   - `this+1000`, `this+1004`, `this+1008` (COM surface pointers/handle fields used by render-target bind/restore)
3) Increments a global counter (`++*ArgList`) and emits a debug string via:
   - `Gfx_OutputDebugStringf("RenderTarget Increase To: %u", ...)` (format string observed in the DLL strings table)
4) Fills a 4x4 grid of indices starting at `this + 808` (word array), writing 3 indices per cell and then another 3 indices at an offset (`+46`/`+47`/`+48` words relative to the current write pointer).

If `Texture_Create` fails:
- Logs `Create TargetTexture Failed!` via `Gfx_Logf(...)`
- Returns `0`.

## Notes
- The internal fields at `this+1000/1004/1008/1016` are also referenced by:
  - `TargetTexture_BindAsRenderTarget`
  - `TargetTexture_RestorePreviousRenderTarget`
and appear to represent the "saved previous render target", "saved depth/stencil", "target depth/stencil", and a validity flag.

## Verified TargetBmp vtable usage from `Conquer.exe`

The ground/entity-layer non-`.pul` terrain-cache path in `Conquer.exe` now gives us a stable
behavioral picture for the first draw-oriented TargetBmp methods:

- `vtable + 0x04`
  - begin-scene / bind-this-target-for-render
  - used as the success gate before the EXE clears and fills the offscreen tile cache
- `vtable + 0x08`
  - end-scene / restore-previous-render-target
  - called unconditionally after the EXE finishes rasterizing one cached tile
- `vtable + 0x18`
  - returns the texture handle consumed by `MyBitmapCreateEx`

This matches the EXE cache chain:
- create or reuse `TargetBmp(256, 256)`
- call `target->vtable + 0x04`
- `CMyBitmap::ClearBuffer(0, 1, 0xFFFFFFFF)`
- draw the cached quarter-tile mosaic into the target
- call `target->vtable + 0x08`
