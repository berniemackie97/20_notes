# `graphic.dll` — MyBitmap (`MyBitmapCreate*`)

The "MyBitmap" object, as built by `MyBitmapCreate`, `MyBitmapCreateEx`, and the helper constructors that adapt other objects into a MyBitmap.

## MyBitmap object shape (as constructed)
`MyBitmap_Ctor` (0x10011DE0) initializes a 0x28-byte object with:
- vtable: `.rdata:0x10039A34`
- `this+4` (dword): sprite pointer (initialized to 0; later written by `MyBitmap_InitFromTexture_CreateSprite`)
- `this+36` (byte): a flag set to `1` in ctor and overwritten by init routines

## `MyBitmapCreateEx` (0x10012D60)
Decompiled signature:
```c
int MyBitmapCreateEx(int textureHandle, char flag);
```

Behavior:
1) If `textureHandle == 0`, returns `0`.
2) Allocates `0x28` bytes using `HeapWrapper_Alloc` (0x10036FE0).
3) Runs `MyBitmap_Ctor` to initialize the object.
4) Calls `MyBitmap_InitFromTexture_CreateSprite(this, textureHandle, flag)`.
5) On allocation/ctor failure, logs via `Gfx_LogToDatedDebugFile(..., "pbmpx", ...)` and returns 0.

## `MyBitmap_InitFromTexture_CreateSprite` (0x10012590)
Decompiled signature:
```c
C3Sprite* MyBitmap_InitFromTexture_CreateSprite(MyBitmap* this, C3Texture* texture, char flag);
```

Behavior:
- If `this+4` is already set, logs a warning via `Gfx_LogToDatedDebugFile(...)`.
- Calls `Sprite_CreateEx(texture)` and stores it into `this+4`.
- Stores `flag` into `this+36`.

## `MyBitmapCreate_LoadSpriteFromPath` (0x10012C66)
Decompiled signature:
```c
MyBitmap* MyBitmapCreate_LoadSpriteFromPath(const char* path);
```

Behavior:
1) Allocates a `MyBitmap` (same `0x28` allocation + `MyBitmap_Ctor`).
2) If `path == NULL`, returns the newly constructed object without loading.
3) Copies the path into a local buffer and normalizes path separators:
   - `Path_ReplaceCharInPlace(buf, '\\\\', '/')`.
4) Calls `MyBitmap_LoadSpriteAndOptionalMask(this, buf, 1)`.
5) If load fails:
   - calls a virtual method at `vtable + 76` with argument `1` (cleanup/release semantics)
   - returns `NULL`.

## `MyBitmap_LoadSpriteAndOptionalMask` (0x10011EB0)
Decompiled signature:
```c
int MyBitmap_LoadSpriteAndOptionalMask(MyBitmap* this, const char* path, char allowMask);
```

Behavior (verified):
- Releases an existing object at `this+8` (a pointer with `vtable[0]`/release semantics).
- If the file extension matches a specific suffix (compared case-insensitively against `String2`), it:
  - allocates a `DNameNode`
  - constructs a derived filename by overwriting the tail with `DDS` then tries `Sprite_Load(..., D3DPOOL_MANAGED, ...)`
  - if that fails, overwrites the tail with `TGA` and tries again
  - after sprite load, calls `Mask_LoadMskBitsFromResource(width,height,path)` (0x1000B8D0) and validates it
  - on mask load failure, logs `"Fail to load MSK file [%s]"` and clears/unloads
- Otherwise, calls `Sprite_Load((C3Sprite**)this+1, path, D3DPOOL_MANAGED, ...)` directly.

The derived-name fallback and the content decoder are separate layers: `graphic.dll` selects the
applicable `.DDS` then `.TGA` resource names, while `C3_CORE_DLL.dll` `ImageDecoder_TryDecode`
content-probes the loaded bytes. The managed ANI path preserves that separation by enumerating the
native filename candidates and sending either payload through the shared DDS/TGA upload-plan
builder. Clean-client `Common.Ani` section `Syndicate` is the real TGA-only integration fixture
(`data/pic/Syndicate.tga`, RLE BGRA, 14x14).

## Adapter constructors

### `MyBitmapCreateFrom3DObj_GetTextureThenCreate` (0x10006D33)
- Calls `obj->vtable[4](obj)` (offset +16) to get a texture handle, then `MyBitmapCreateEx(handle, 0)`.

### `MyBitmapCreateFromTargetBmp_GetSurfaceThenCreate` (0x10006D73)
- Calls `targetBmp->vtable[6](targetBmp)` (offset +24) to get a texture/surface handle, then `MyBitmapCreateEx(handle, 0)`.

## Notes
- The EXE uses the MyBitmap vtable methods for drawing (documented from EXE call-sites in `analysis/conquer_docs/Rendering/03_targetbmp_and_mybitmap_object_interfaces.md`). The concrete draw implementations inside `graphic.dll` are documented below against the MyBitmap vtable at `.rdata:0x10039A34`.

## MyBitmap vtable methods (implemented in `graphic.dll`)
The MyBitmap vtable lives at `.rdata:0x10039A34` and contains at least the following methods (addresses are `graphic.dll`):

- `MyBitmap_DrawSimple` (0x10012120)
  - Ensures sprite pipeline prepared (`CMyBitmap::PrepareSprite()` when `dword_1004ACEC != 1`).
  - If `arg4 != 0`, calls `Sprite_SetColor(sprite, arg4.b, 0xFF, 0xFF, 0xFF)`.
    - Only the low byte of `arg4` is consumed (alpha byte feed).
    - If `arg4 == 0`, color is not rewritten (sprite keeps previous per-vertex color; default from `Sprite_Clear` is `0xFFFFFFFF`).
  - Sets sprite coordinates and draws via `Sprite_Draw(sprite, flags)`.
- `MyBitmap_DrawWithRectAndRotate` (0x10012190)
  - Same color behavior (`arg7 != 0` => `Sprite_SetColor(sprite, arg7.b, 0xFF, 0xFF, 0xFF)`; `arg7 == 0` => no color write).
  - Draws with optional source rect + target size; optional rotation; uses `Sprite_Draw`.
- `MyBitmap_DrawExWithRectAndRotate` (0x100122C0)
  - Same color behavior (`arg7 != 0` => `Sprite_SetColor(sprite, arg7.b, 0xFF, 0xFF, 0xFF)`; `arg7 == 0` => no color write).
  - Same setup but draws via `Sprite_DrawEx(sprite, arg9, arg10)`.
- `MyBitmap_GetSpriteSize` (0x10012520): writes width/height from the sprite's texture.
- `MyBitmap_GetSpriteArea` (0x10012550): returns width*height.
- `MyBitmap_GetSpriteWidth` (0x10012560)
- `MyBitmap_GetSpriteHeight` (0x10012570)
- `MyBitmap_SetSpriteColorBytes` (0x100125D0)
  - Forwards to `Sprite_SetColor(sprite, alphaByte, redByte, greenByte, blueByte)` unchanged.
  - This is the frame-vtable `+0x20` color-write path used by `Conquer.exe` type-3 subtype-04 hover highlighting (`0x645379`, `0x64539F`) and normal color feed (`0x6452F9`).
- `MyBitmap_GetMaskStatus` (0x10012600)
  - Returns `0/1` based on a sprite/texture field check; returns `2` if `this+8` is non-null.
- `MyBitmap_MaskHitTestOrAlwaysTrue` (0x10012750)
  - If `this+8` exists, calls `Mask_IsTransparentAt(x,y)`; else returns 1.
- `MyBitmap_LockTextureRect` (0x10012640): locks a texture rect via `Texture_LockRect`.
- `MyBitmap_WritePixelIfLocked` (0x100126D0): writes a pixel if lock is active and within bounds.
- `MyBitmap_UnlockTexture` (0x10012720): unlocks via `Texture_Unlock` and clears lock state.
- `MyBitmap_ApplyMaskRegionFromSprites` (0x10012780): combines sprite and mask sprite data into a destination sprite by locking surfaces and AND'ing pixels.
- `MyBitmap_ReloadSpriteNoFilterFromOther` (0x10012AD0): reloads sprite from another MyBitmap's sprite path unless already matching.

## Shared graphics-pipeline prepare mode

The draw-time guard is not an object-local or one-time sprite initialization flag. The dword at
`0x1004ACEC`, now named `g_CurrentGraphicsPipelinePrepareMode`, is shared by the drawing families in
`graphic.dll`:

- `CMyBitmapSpriteFrame_DrawAt` (`0x10012120`) and both branches of
  `CMyBitmapSpriteFrame_DrawSubRectAt` (`0x10012190`) compare it with sprite mode `1` before every
  draw and call `CMyBitmap::PrepareSprite` when it differs.
- `CMyBitmap::PrepareSprite` (`0x100136B0`) calls `Sprite_Prepare` and records mode `1`.
- `CMyBitmap::PrepareModle` (`0x100137A0`) calls `Phy_Prepare` and records model mode `6`.
- xrefs to the same dword also show distinct mix-sprite, linear-sprite, line, 3D-line, and font
  preparation modes.

Consequently, a model/PHY or font draw makes a later sprite draw reapply the complete sprite state
baseline. A managed backend may organize state differently, but renderer-lifetime "prepared once"
state is not behaviorally equivalent when 2D and 3D draws interleave.

Color-write evidence addresses:
- `MyBitmap_DrawSimple`:
  - `0x10012136..0x10012138` (`test eax, eax` / `je`) gates color write on nonzero parameter.
  - `0x1001214E` calls `Sprite_SetColor(sprite, arg4.b, 0xFF, 0xFF, 0xFF)`.
- `MyBitmap_DrawWithRectAndRotate`:
  - `0x100121CA` and `0x10012249` gate writes on `arg7 != 0`.
  - `0x100121E0` and `0x1001225F` call `Sprite_SetColor(sprite, arg7.b, 0xFF, 0xFF, 0xFF)`.
- `MyBitmap_DrawExWithRectAndRotate`:
  - `0x100122FE` and `0x10012382` gate writes on `arg7 != 0`.
  - `0x10012314` and `0x10012398` call `Sprite_SetColor(sprite, arg7.b, 0xFF, 0xFF, 0xFF)`.
- `MyBitmap_SetSpriteColorBytes`:
  - `0x100125E8` calls `Sprite_SetColor(sprite, alphaByte, redByte, greenByte, blueByte)`.

## Canonical ANI framebuffer conformance (`R2D-003`)

The clean-client `Common.Ani` section `Syndicate` is the canonical full-frame `DrawAt` case:

- `CAniX_DrawFrameAt` (`graphic.dll 0x1000BE20`) normalizes the frame index modulo the frame count
  and dispatches frame-vtable `+0x04` with `(screenX, screenY, colorParameter, drawParameter)`.
- It has one frame, `data/pic/Syndicate.tga`, so frame index `0` selects the 14x14 RLE TGA.
- `CMyBitmapSpriteFrame_DrawAt` calls `Sprite_SetCoor(sprite, NULL, x, y, 0, 0)`. In
  `C3_CORE_DLL.dll`, null source rect produces full UVs `(0,0)-(1,1)` and zero target dimensions
  select the texture width/height.
- `Sprite_SetCoor` applies D3D8's API-specific `-0.5` rasterization offset to vertex positions. The
  OpenGL renderer uses pixel-boundary NDC coordinates to preserve the resulting pixel coverage.
- `colorParameter=0` preserves the frame's default white vertex color.
- `drawParameter=0` makes `Sprite_Draw` set source-alpha / inverse-source-alpha blending and emit
  one two-primitive triangle strip.

The standalone managed visual-conformance executable draws this case at `(7,9)` into the production
32x32 internal framebuffer. Its expected image is independently composed using ImageSharp's TGA
decoder and the verified blend equation. On macOS Apple M4 / OpenGL 4.1 Metal, the canonical
top-left RGBA readback exactly matched the golden SHA-256
`fe8e6998cad4c6399059d43ec465837f53a346878f8d69e200bc7005a348a459` with maximum channel delta
`0`. Windows execution remains required before cross-platform parity is closed.

Destruction / unload:
- `MyBitmap_ResetAndUnload` (0x10011E20) sets the vtable and calls `MyBitmap_UnloadSpriteAndMaskIfPresent`.
- `MyBitmap_UnloadSpriteAndMaskIfPresent` (0x10011E30) unloads the sprite and releases the optional mask node at `this+8`.
