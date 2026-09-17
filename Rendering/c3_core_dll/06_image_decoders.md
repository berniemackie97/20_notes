# Image decoding and container support (textures)

This document describes the internal image decoding stack used to populate textures in `c3_core_dll.dll`, as invoked by:

- `Texture_Load`
- `Texture_Reload`
- `Sprite_ReLoadNoFilter`

## Entry points

The decoding stack is reached via:

- `Image_LoadFromPath_Thunk` (`0x1001BD6B`) — resolves a path into an in-memory buffer, then calls `Image_LoadFromMemory_Thunk`.
- `Image_LoadFromMemory_Thunk` (`0x1001BD2B`) — calls `D3DTexture_LoadFromDecodedImage` with fixed parameters.
- `D3DTexture_LoadFromDecodedImage` (`0x1001B6B8`) — decodes and uploads texture content.

The dispatcher that probes multiple codecs is:

- `ImageDecoder_TryDecode` (`0x1001E957`)

## Codec probe order (as implemented)

`ImageDecoder_TryDecode` tries these decoders in this fixed order until one succeeds:

1. BMP file (`ImageDecoder_Decode_BMP_File`, `0x1001E927`)
2. PPM P3/P6 (`ImageDecoder_Decode_PPM_P3_P6`, `0x1001D809`)
3. DDS (`ImageDecoder_Decode_DDS`, `0x1001E075`)
4. JPEG (`ImageDecoder_Decode_JPEG`, `0x1001D0F2`)
5. PNG (`ImageDecoder_Decode_PNG`, `0x1001DADF`)
6. TGA (`ImageDecoder_Decode_TGA`, `0x1001D362`)
7. BMP DIB (`ImageDecoder_Decode_BMP_DIB`, `0x1001C6B6`)

The exact probe sequence comes from the local array initialized in `ImageDecoder_TryDecode` (`{0, 5, 4, 1, 3, 2, 6}` at `0x1001E96A`).

Each failed probe releases any decoder-owned allocation before continuing. The TGA call is at
`0x1001EA08`; it is reached after PNG failure and before the final BMP-DIB probe.

## TGA (`ImageDecoder_Decode_TGA`, `0x1001D362`)

### Header and accepted image families

The decoder requires the fixed 18-byte header and nonzero little-endian width/height values at
offsets `0x0C`/`0x0E`. Color-map type at byte `1` must be `0` or `1`. The accepted image types are:

| Base family | Raw | RLE | Pixel/index requirement |
|---|---:|---:|---|
| Color mapped | `1` | `9` | 8-bit indices; color-map entries may be 15, 16, 24, or 32 bits |
| True color | `2` | `10` | 15, 16, 24, or 32 bits per pixel |
| Grayscale | `3` | `11` | 8 bits per pixel |

The decoder bounds-checks the image-ID skip, palette payload, raw pixel payload, and every RLE
packet. A palette range (`firstIndex + length`) greater than 256 is rejected. The 256-entry palette
workspace is initialized to white before the declared range is copied.

### Output format tags

| Input depth/family | Engine format tag |
|---|---:|
| 15-bit color | `24` (`X1R5G5B5`) |
| 16-bit color | `25` (`A1R5G5B5`) |
| 24-bit color | `20` (`R8G8B8`) |
| 32-bit color | `21` (`A8R8G8B8`) |
| 8-bit grayscale | `50` (`L8`) |

Image descriptor bit `4` controls right-versus-left origin and bit `5` controls
top-versus-bottom origin. The decode/copy loops use both bits when placing output pixels. RLE packet
length is `(header & 0x7F) + 1`; bit `7` distinguishes one repeated pixel from a raw packet.

The function returns `0` on success, `0x80004005` (`E_FAIL`) for malformed or unsupported input,
and `0x8007000E` (`E_OUTOFMEMORY`) when allocation fails.

### Clean v5517 corpus and managed parity

The clean client contains eight loose `.tga` files. All are 32-bit BGRA with descriptor `0x08`
(bottom origin, eight attribute bits). Seven use raw true-color type `2`; `data/pic/Syndicate.tga`
uses RLE true-color type `10`. Their observed dimensions are 64x32, 113x147, and 14x14.

The managed `TgaReader` mirrors the verified accepted families, format tags, RLE packets, palette
range, strict bounds, and origin transforms. `TextureUploadPlanBuilder.BuildFromEncodedDdsOrTga`
provides the bounded DDS/TGA content probe used by ANI frame metadata and OpenGL upload. Real-client
tests compare canonical BGRA bytes for all eight files against hashes independently produced by
ImageMagick 7. The production-path `R2D-003` harness additionally renders the TGA-only
`Common.Ani` `Syndicate` frame into the real internal OpenGL framebuffer. Its macOS readback exactly
matches the independently composed 32x32 RGBA golden; Windows execution remains pending.

## DDS (`ImageDecoder_Decode_DDS`, `0x1001E075`)

### Container identification

- Requires the 4-byte magic `DDS ` (`0x20534444`).
- Requires at least 0x7C bytes of header following the magic.

### Mip levels and “faces”

The decoder constructs a linked structure representing one or more:

- mip levels per “face”
- faces (for cubemap-like or array-like content)

The loops in the implementation indicate:

- `v24` is a “mip level count” value read from the header (defaulting to 1 when missing/0).
- `v27` is a “face count” derived from header flags; it is either `1` or `6`.

### Supported FourCC (block/compressed and packed YUV)

The pixel format is treated as a FourCC when present; the following FourCC values are explicitly handled:

- `DXT1` (`0x31545844`)
- `DXT2` (`0x32545844`)
- `DXT3` (`0x33545844`)
- `DXT4` (`0x34545844`)
- `DXT5` (`0x35545844`)
- `YUY2` (`0x32595559`)
- `UYVY` (`0x59565955`)

Block sizing / pitch computation is visible in the code:

- `DXT1` uses 8 bytes per 4x4 block:
  - bytesPerRow = `8 * ceil(width / 4)`
  - bytesPerImage = `bytesPerRow * ceil(height / 4)`
- `DXT2/DXT3/DXT4/DXT5` use 16 bytes per 4x4 block:
  - bytesPerRow = `16 * ceil(width / 4)`
  - bytesPerImage = `bytesPerRow * ceil(height / 4)`
- `YUY2` / `UYVY` are treated as packed 4 bytes per 2 pixels:
  - bytesPerRow = `4 * ceil(width / 2)`
  - bytesPerImage = `bytesPerRow * height`

### Uncompressed DDS

For non-FourCC DDS formats, the decoder uses the DDS pixel-format masks and a device-format mapping table to choose a texture format and compute row stride as:

- bytesPerRow = `width * (bitsPerPixel / 8)`
- bytesPerImage = `bytesPerRow * height`

#### Pixel-format mapping table (`dword_100AA530`)

The DDS decoder uses a built-in table located at `dword_100AA530` to match the DDS `DDS_PIXELFORMAT` fields (flags, fourCC, RGB bit count, and masks) to an output “format tag” (`outTag`).

Matching logic (as implemented) checks:

- `ddspf.dwSize == 32`
- `ddspf.dwFlags == out.ddpfFlags`
- and then conditionally compares fourCC / bit count / masks depending on which bits are set in `ddpfFlags`.

Extracted table entries (in order):

| outTag | ddpfFlags | fourCC | rgbBits | rMask | gMask | bMask | aMask |
|---:|---:|:---:|---:|---:|---:|---:|---:|
| `20` | `0x40` | `` | `24` | `0xFF0000` | `0xFF00` | `0xFF` | `0x0` |
| `21` | `0x41` | `` | `32` | `0xFF0000` | `0xFF00` | `0xFF` | `0xFF000000` |
| `22` | `0x40` | `` | `32` | `0xFF0000` | `0xFF00` | `0xFF` | `0x0` |
| `23` | `0x40` | `` | `16` | `0xF800` | `0x7E0` | `0x1F` | `0x0` |
| `24` | `0x40` | `` | `16` | `0x7C00` | `0x3E0` | `0x1F` | `0x0` |
| `40` | `0x21` | `` | `16` | `0x0` | `0x0` | `0x0` | `0xFF00` |
| `41` | `0x20` | `` | `8` | `0x0` | `0x0` | `0x0` | `0x0` |
| `25` | `0x41` | `` | `16` | `0x7C00` | `0x3E0` | `0x1F` | `0x8000` |
| `26` | `0x41` | `` | `16` | `0xF00` | `0xF0` | `0xF` | `0xF000` |
| `27` | `0x40` | `` | `8` | `0xE0` | `0x1C` | `0x3` | `0x0` |
| `28` | `0x2` | `` | `8` | `0x0` | `0x0` | `0x0` | `0xFF` |
| `29` | `0x41` | `` | `16` | `0xE0` | `0x1C` | `0x3` | `0xFF00` |
| `30` | `0x40` | `` | `16` | `0xF00` | `0xF0` | `0xF` | `0x0` |
| `31` | `0x41` | `` | `32` | `0x3FF00000` | `0xFFC00` | `0x3FF` | `0xC0000000` |
| `34` | `0x40` | `` | `32` | `0xFFFF` | `0xFFFF0000` | `0x0` | `0x0` |
| `50` | `0x20000` | `` | `8` | `0xFF` | `0x0` | `0x0` | `0x0` |
| `51` | `0x20001` | `` | `16` | `0xFF` | `0x0` | `0x0` | `0xFF00` |
| `52` | `0x20001` | `` | `8` | `0xF` | `0x0` | `0x0` | `0xF0` |
| `60` | `0x80000` | `` | `16` | `0xFF` | `0xFF00` | `0x0` | `0x0` |
| `61` | `0x40000` | `` | `16` | `0x1F` | `0x3E0` | `0xFC00` | `0x0` |
| `62` | `0x40000` | `` | `32` | `0xFF` | `0xFF00` | `0xFF0000` | `0x0` |
| `63` | `0x80000` | `` | `32` | `0xFF` | `0xFF00` | `0xFF0000` | `0xFF000000` |
| `64` | `0x80000` | `` | `32` | `0xFFFF` | `0xFFFF0000` | `0x0` | `0x0` |
| `65` | `0x80000` | `` | `32` | `0x3FF` | `0x1FFC00` | `0xFFE00000` | `0x0` |
| `67` | `0x80001` | `` | `32` | `0x3FF00000` | `0xFFC00` | `0x3FF` | `0xC0000000` |
| `1498831189` | `0x4` | `UYVY` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `844715353` | `0x4` | `YUY2` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `827611204` | `0x4` | `DXT1` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `844388420` | `0x4` | `DXT2` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `861165636` | `0x4` | `DXT3` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `877942852` | `0x4` | `DXT4` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `894720068` | `0x4` | `DXT5` | `0` | `0x0` | `0x0` | `0x0` | `0x0` |
| `70` | `0x400` | `` | `16` | `0x0` | `0xFFFF` | `0x0` | `0x0` |

`outTag` is used downstream by the DDS decoder to decide:

- how many bytes per row/image to consume from the DDS data stream
- how to interpret the data (block-compressed vs uncompressed)

Further mapping from `outTag` to a concrete D3D texture format for creation goes through `C3FormatDesc_LookupByTag(outTag)`.

#### Format descriptor lookup (`C3FormatDesc_LookupByTag`, `0x1001A58C`)

The engine has an internal format descriptor table at `0x100A1800` with 43 entries of 9 dwords each. The lookup routine:

- returns a pointer to the matching 9-dword entry when `entry[0] == tag`
- returns a default descriptor at `0x100A17D8` when the tag is not found

This format descriptor is used by the DDS decoder (and other image decode paths) to:

- decide whether the format is block-compressed or linear
- compute derived properties like “bits per pixel” for upload and lock/stride
- select the D3D format to request from the device when creating textures

The exact meaning of the 9 descriptor fields is documented in `Rendering/c3_core_dll/03_textures.md` (format descriptor table section).
