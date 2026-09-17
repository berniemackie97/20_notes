# `C3_CORE_DLL.dll` — `Font_*` subsystem

This note records the verified native font rasterization, glyph-cache, geometry,
and fixed-function draw contract. Addresses are from
`00_clean/clean/5517-bninja/C3_CORE_DLL.dll.bndb`.

## Exported entry points

- ordinal `33`, `0x100028A0`, `Font_AddFontSizeLevel`
- ordinal `34`, `0x100030C0`, `Font_CheckPixel`
- ordinal `35`, `0x10002A70`, `Font_Clear`
- ordinal `36`, `0x10004B00`, `Font_CloseSys`
- ordinal `37`, `0x10002AA0`, `Font_Create`
- ordinal `38`, `0x10004570`, `Font_Draw`
- ordinal `39`, `0x10004700`, `Font_DrawArabic`
- ordinal `40`, `0x100048D0`, `Font_DrawBegin`
- ordinal `41`, `0x100048F0`, `Font_DrawEnd`
- ordinal `42`, `0x10004650`, `Font_DrawW`
- ordinal `43`, `0x10003C80`, `Font_GetStrShowLen`
- ordinal `44`, `0x100047F0`, `Font_GetStrShowLenArabic`
- ordinal `45`, `0x10003D10`, `Font_GetStrShowLenW`
- ordinal `46`, `0x10002F40`, `Font_Prepare`
- ordinal `47`, `0x10002E20`, `Font_Release`
- ordinal `48`, `0x10004A30`, `Font_SaveFontTexture`
- ordinal `49`, `0x100048A0`, `Font_SetTextCornerColor`

## Persistent Binary Ninja model

`C3Font` is `0x20110` bytes:

- `+0x00000` embedded FreeType-style face pointer
- `+0x00004` resolved face/path bytes (`char[256]`)
- `+0x00104` nominal pixel height
- `+0x00108` line height in pixels
- `+0x0010C` `uint16[65536]` glyph-record indices keyed by encoded client bytes
- `+0x2010C` antialias-enabled byte
- `+0x2010D` separate single-byte advance adjustment byte
- `+0x2010E` two reserved bytes

`C3FontGlyphRecord` is `0x18` bytes:

- `+0x00..+0x0F` atlas minimum/maximum UV floats;
- `+0x10` signed 16-bit horizontal bearing;
- `+0x12` signed 16-bit top offset;
- `+0x14` unsigned 16-bit advance;
- `+0x16` signed 16-bit atlas page index.

The database also persists `Font_RasterizeAndCacheGlyph` (`0x10003590`),
`Font_EmitGlyphVerticesByStyle` (`0x10003D80`), the glyph-record pointer-vector
boundaries, `g_FontBatchActive`, `g_BoundFontAtlasTextureHandle`, and four
per-corner colors. Types, signatures, names, and comments were re-read after
writing them.

## Creation and rasterization

`Font_Create` uses an embedded FreeType-style API and allocates the large
encoded-character index table. The antialias Boolean selects rasterization:

- enabled: normal grayscale render mode;
- disabled: monochrome render mode.

`Font_RasterizeAndCacheGlyph` converts one one- or two-byte client-codepage
character to UTF-16, applies the nominal height with the equivalent of
`FT_Set_Char_Size(face, 0, height << 6, 0, 0)`, loads the glyph, and renders it.
It records:

- `bearingXPixels = bitmap_left`;
- `topOffsetPixels = nominalPixelHeight - bitmap_top`;
- `advancePixels = advance26_6 / 64`, with signed division rounded toward zero;
- normalized UVs into a 512x512 atlas page.

Monochrome bitmaps are expanded to zero/fully-set texels. Atlas rows and pages
use two pixels of separation. The helper appends a one-based glyph record index;
zero is the unset/failure sentinel. The public length/draw paths use
`0xFFFF0000` as the missing-glyph result.

No trustworthy string identifies the exact embedded FreeType revision. That
version is an unresolved compatibility variable, not permission to change the
verified surrounding algorithm.

## Glyph geometry and styles

For every non-empty bitmap:

- left = `screenX + bearingX - 0.5`;
- top = `screenY + topOffset - 0.5`;
- width/height come from the UV span multiplied by 512;
- the base quad is two triangles using 28-byte `XYZRHW | DIFFUSE | TEX1`
  vertices.

Verified `RENDER_TEXT_STYLE` behavior:

- `0`, normal: base quad only, two triangles;
- `1`, shadow offset: offset corner-color quad then base, four triangles;
- `2`, multi-offset outline: eight corner-color offset quads then base,
  eighteen triangles;
- `3`, offset trail: interpolated offset quads followed by base; triangle count
  is `2 * (abs(offsetX) + abs(offsetY)) + 2`;
- `4`, per-corner color: base geometry with the four configured vertex colors,
  two triangles.

A space advances without emitting vertices. `Font_Draw` and
`Font_GetStrShowLen` share the encoded-character cache and metric behavior.

## `Font_Prepare` and batching

`Font_Prepare` establishes the complete D3D8 mode-9 baseline:

- alpha blending enabled with source alpha / inverse source alpha;
- depth test, depth write, alpha test, dither, culling, and lighting disabled;
- Gouraud shading and solid fill;
- point minification/magnification and no mip filter;
- FVF `0x144` (`XYZRHW | DIFFUSE | TEX1`);
- texture-stage RGB selects diffuse color;
- texture-stage alpha multiplies texture alpha by diffuse alpha.

Thus the glyph atlas supplies coverage only; vertex diffuse supplies visible
RGB and opacity. In non-batched mode the emitter binds the glyph's atlas page
and draws immediately. Between `Font_DrawBegin`/`Font_DrawEnd`, vertices are
collected per atlas page and flushed as a batch.
