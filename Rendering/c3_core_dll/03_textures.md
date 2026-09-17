# Texture subsystem (`Texture_*`)

The `Texture_*` API in `c3_core_dll.dll`, as the client uses it.

## Exported entry points

- ordinal `156` `0x10016340` `?Texture_Clear@@YAXPAUC3Texture@@@Z`
- ordinal `157` `0x100169F0` `?Texture_Create@@YAHPAPAUC3Texture@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@KH@Z`
- ordinal `158` `0x10016360` `?Texture_Load@@YAHPAPAUC3Texture@@PBDKW4_D3DPOOL@@HKK@Z`
- ordinal `159` `0x10016B90` `?Texture_LockRect@@YAHPAUC3Texture@@UtagRECT@@AAU_D3DLOCKED_RECT@@@Z`
- ordinal `160` `0x10016700` `?Texture_Reload@@YA_NPAUC3Texture@@KW4_D3DPOOL@@KK@Z`
- ordinal `161` `0x10016640` `?Texture_Unload@@YAXPAPAUC3Texture@@@Z`
- ordinal `162` `0x10016BD0` `?Texture_Unlock@@YAXPAUC3Texture@@@Z`

## `C3Texture` lifetime and registry behavior (observed)

The module tracks textures globally:

- `g_dwTexCount` (exported as `?g_dwTexCount@@3KA`, ordinal `173`) counts currently allocated `C3Texture` objects.
- `g_pTexDB` (exported as `?g_pTexDB@@3PAPAUC3Texture@@A`, ordinal `184`) is a fixed-size array used as an ID registry.
- `dword_100C653C` (internal global; not exported) tracks how many occupied slots exist in the registry.
- A `CriticalSection` (internal global) guards texture creation/load/unload.

`Texture_Load`/`Texture_Create` both allocate a `C3Texture` object, populate it, and (optionally / always, depending on call) register it into `g_pTexDB` up to a maximum of 10240 entries. On overflow it emits `OutputDebugStringA("Texture ID Over Flow")` and fails.

## Format descriptor table (`0x100A1800`) and lookup

The Sprite_Draw modes audit established a construction-path distinction for
`C3Texture+0x18`: loaded/reloaded textures store post-upload `GetLevelDesc.Format`
(`0x1001650A`, `0x100168E0`), while `Texture_Create` stores its selected request
at `0x10016AE9`, without querying back the created resource. Downstream creation
helpers can adjust their local format. Do not globally label this field as source-file
format, `hasAlpha`, or measured GPU format. See the full provenance and acceptance
limits in [02_sprites.md](02_sprites.md#loaded-versus-created-texture-format-provenance).

Several decode and upload paths (notably DDS) use an internal "format descriptor" table located at `0x100A1800`, which is indexed by a "format tag" value (e.g. `20`, `21`, `DXT1`, `DXT5`).

### Lookup: `C3FormatDesc_LookupByTag` (`0x1001A58C`)

- Scans the 9-dword entries at `0x100A1800` until `entry[0] == tag`.
- If no match is found, returns a default descriptor at `0x100A17D8`.

### Normalization helper: `C3FormatTag_NormalizeForPaletteAnd16BitVariants` (`0x1001A775`)

Some loaders normalize "16-bit variant" tags back to base tags:

- ` L16` (`0x36314C20`) → `50`
- `AL16` (`0x36314C41`) → `51`
- ` R16` (`0x36315220`) → `20`
- `AR16` (`0x36315241`) → `21`
- otherwise returns the input tag unchanged

### Descriptor entries (raw)

Each descriptor is 9 dwords:

`[tag, group, bitsOrBpp, aux, aBits, rBits, gBits, bBits, flags]`

Field meanings are partially inferred from usage:

- `tag` is the format tag used throughout the engine and by DDS.
- `group` is a small integer classifying the format family (observed values: 0..4).
- `bitsOrBpp` appears to be a "bits-per-pixel" or "bits-per-texel" value for linear formats; for DXT/YUV it is set to `16` (treated specially in DDS code paths).
- `flags` is `0` for FourCC/block formats and `1` for most linear formats (as observed in the table).

Raw entries (in table order) are:

- `20` → `[20, 0, 24, 0, 0, 8, 8, 8, 0]`
- `21` → `[21, 0, 32, 0, 8, 8, 8, 8, 1]`
- `22` → `[22, 0, 32, 0, 0, 8, 8, 8, 1]`
- `23` → `[23, 0, 16, 0, 0, 5, 6, 5, 1]`
- `24` → `[24, 0, 16, 0, 0, 5, 5, 5, 1]`
- `40` → `[40, 1, 16, 0, 8, 8, 8, 8, 1]`
- `41` → `[41, 1, 8, 0, 8, 8, 8, 8, 1]`
- `25` → `[25, 0, 16, 0, 1, 5, 5, 5, 1]`
- `26` → `[26, 0, 16, 0, 4, 4, 4, 4, 1]`
- `27` → `[27, 0, 8, 0, 0, 3, 3, 2, 1]`
- `28` → `[28, 0, 8, 0, 8, 0, 0, 0, 1]`
- `29` → `[29, 0, 16, 0, 8, 3, 3, 2, 1]`
- `30` → `[30, 0, 16, 0, 0, 4, 4, 4, 1]`
- `31` → `[31, 0, 32, 0, 2, 10, 10, 10, 1]`
- `34` → `[34, 0, 32, 0, 0, 16, 16, 0, 1]`
- `50` → `[50, 2, 8, 0, 0, 8, 8, 8, 1]`
- `51` → `[51, 2, 16, 0, 8, 8, 8, 8, 1]`
- `52` → `[52, 2, 8, 0, 4, 4, 4, 4, 1]`
- `60` → `[60, 3, 16, 0, 0, 0, 8, 8, 1]`
- `61` → `[61, 3, 16, 6, 0, 0, 5, 5, 1]`
- `62` → `[62, 3, 32, 8, 0, 0, 8, 8, 1]`
- `63` → `[63, 3, 32, 0, 8, 8, 8, 8, 1]`
- `64` → `[64, 3, 32, 0, 0, 0, 16, 16, 1]`
- `65` → `[65, 3, 32, 0, 0, 11, 11, 10, 1]`
- `67` → `[67, 3, 32, 2, 0, 10, 10, 10, 1]`
- `70` → `[70, 4, 16, 1, 0, 0, 0, 16, 1]`
- `71` → `[71, 4, 32, 0, 0, 0, 0, 32, 1]`
- `73` → `[73, 4, 16, 0, 0, 0, 1, 15, 1]`
- `75` → `[75, 4, 32, 0, 0, 0, 8, 24, 1]`
- `77` → `[77, 4, 32, 0, 0, 0, 0, 24, 1]`
- `79` → `[79, 4, 32, 0, 0, 0, 4, 24, 1]`
- `80` → `[80, 4, 16, 0, 0, 0, 0, 16, 1]`
- `UYVY` (`0x59565955`) → `[1498831189, 0, 16, 0, 0, 8, 8, 8, 0]`
- `YUY2` (`0x32595559`) → `[844715353, 0, 16, 0, 0, 8, 8, 8, 0]`
- `DXT1` (`0x31545844`) → `[827611204, 0, 16, 0, 1, 5, 6, 5, 0]`
- `DXT2` (`0x32545844`) → `[844388420, 0, 16, 0, 4, 5, 6, 5, 0]`
- `DXT3` (`0x33545844`) → `[861165636, 0, 16, 0, 4, 5, 6, 5, 0]`
- `DXT4` (`0x34545844`) → `[877942852, 0, 16, 0, 8, 5, 6, 5, 0]`
- `DXT5` (`0x35545844`) → `[894720068, 0, 16, 0, 8, 5, 6, 5, 0]`
- ` L16` (`0x36314C20`) → `[909200416, 2, 16, 0, 0, 16, 16, 16, 0]`
- `AL16` (`0x36314C41`) → `[909200449, 2, 32, 0, 16, 16, 16, 16, 0]`
- ` R16` (`0x36315220`) → `[909201952, 0, 48, 0, 0, 16, 16, 16, 0]`
- `AR16` (`0x36315241`) → `[909201985, 0, 64, 0, 16, 16, 16, 16, 0]`

## Device-driven sizing and format selection

The decode/upload path uses additional internal helpers to select a supported format tag and to adjust dimensions/mip counts based on device caps.

### Choose a supported format tag: `Texture_ChooseSupportedFormatTag` (`0x1001A693`)

Inputs (observed):

- a device-like object `a1` (queried for caps and used to call a `CheckDeviceFormat`-like method)
- flags `a2` and resource-type `a3` (passed through to the device check)
- desired format descriptor `a4` (a 9-dword descriptor, typically from `C3FormatDesc_LookupByTag(desiredTag)`)

Observed behavior:

- Iterates the 43 descriptor entries in the `0x100A1800` table.
- For each candidate descriptor `v6`:
  - if `v6[0]` (tag) is non-zero and the device indicates it supports the candidate tag for the requested usage/type, it is considered.
  - if the candidate tag exactly matches the desired tag (`*a4 == *v6`), the scan stops and returns that tag immediately.
  - otherwise, if `v6[8]` is non-zero, it computes a "conversion cost" between descriptors and keeps the lowest-cost candidate (tie-breaking by smaller `v6[2]`).
- Returns the chosen tag (or a default tag when no candidates qualify).

The cost function is implemented by `C3FormatDesc_ComputeConversionCost` (`0x1001A5B0`).

### Format conversion cost: `C3FormatDesc_ComputeConversionCost` (`0x1001A5B0`)

This routine compares two format descriptors and returns a 32-bit cost value used to choose the "closest" supported format.

Observed behavior (high level):

- First checks a compatibility matrix `dword_100A1E10` indexed by `descA[1]` and `descB[1]`; if incompatible it returns `-1`.
- Then compares five numeric fields starting at `desc[3]` (five dwords) and accumulates a cost:
  - increases in a descriptor field add a large penalty (`<< 16`)
  - decreases add a smaller penalty
  - zero vs non-zero mismatches add fixed penalties
- If the number of non-zero fields matches the high byte of the accumulated cost, it returns `-1` (treated as "no acceptable conversion" by the caller).

### Adjust dimensions / choose mip count / finalize format tag: `Texture_AdjustDimsChooseFormatAndMipCount` (`0x1001A95B`)

This helper is used by the upload path to:

- ensure dimensions meet the device's requirements and maximums (using caps queried from the device)
- optionally round up dimensions to the next power-of-two depending on caps and usage
- clamp mip-count based on the final dimensions
- if the chosen format is block-compressed DXT (`DXT1..DXT5`), rounds width/height up to a multiple of 4

It also enforces the DXT "multiple of 4" rule even when the caller requested arbitrary dimensions.

## `Texture_Clear` (ordinal `156`, `0x10016340`)

Initializes a `C3Texture` struct to a known empty state:

- sets the first dword to `-1` (used as "no registry ID")
- zeros remaining fields observed in the function

## `Texture_Create` (ordinal `157`, `0x100169F0`)

Signature (export name):

- `?Texture_Create@@YAHPAPAUC3Texture@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@KH@Z`

Observed behavior:

- Allocates a `C3Texture` (`operator new(0x1C)`), then calls `Texture_Clear`.
- If `a7 == 1`, maps the requested `D3DFORMAT` through an internal format mapper (`Texture_MapToSupportedD3DFormatOrFallback`). If the mapper returns `D3DFMT_UNKNOWN`, the call fails.
- Creates the underlying D3D texture via an internal helper `D3DDevice_CreateTextureWithAdjustedParams(g_D3DDevice, width, height, levels, usageFlag, format, pool, &tex->d3dTexture)`; on failure frees the object and returns `0`.
- On success, stores:
  - `tex->refcount = 1`
  - `tex->name = NULL` (used by `Texture_Load`/`Texture_Reload`)
  - `tex->width = a2`
  - `tex->height = a3`
  - `tex->format = (mapped or input) D3DFORMAT`
  - `*out = tex`
  - increments `g_dwTexCount`
- If `a8 != 0`, registers the texture into `g_pTexDB` and writes the assigned slot index back into the texture's first dword field (ID). If the registry is full (10240 entries), returns `0`.
- Returns `1` on success, `0` on failure.

### Internal format mapper: `Texture_MapToSupportedD3DFormatOrFallback` (`0x10016910`)

`Texture_Create` calls an internal helper to validate or choose a supported texture format for the current device when `a7 == 1`.

Observed behavior (decompiler):

- Calls `g_D3D->CheckDeviceFormat(adapter=0, deviceType=1, adapterFormat=dword_100B041C, usage=1, rtype=3, checkFormat=inputFormat)`.
- If that succeeds:
  - returns `inputFormat`.
  - Special-case: if the cached fallback format is not set and `inputFormat == 22`, it caches `22` as the fallback for later failures.
- If that fails:
  - if a "fallback chosen" flag is set, returns the cached fallback format (`dword_100C6544`).
  - otherwise tries candidate formats in order: `{ 22, 24, 23, 30 }`, returning the first one accepted by `CheckDeviceFormat`.
    - once it finds one, it marks "fallback chosen" and caches that format for later.
    - if none are supported, returns `0` (treated as `D3DFMT_UNKNOWN` by the caller).

## `Texture_Load` (ordinal `158`, `0x10016360`)

Signature (export name):

- `?Texture_Load@@YAHPAPAUC3Texture@@PBDKW4_D3DPOOL@@HKK@Z`

Observed behavior (high level):

- Enters the texture `CriticalSection`.
- If the "use cache" flag argument is non-null, it attempts to find a matching already-loaded texture by comparing the stored `tex->name` case-insensitively with `_stricmp`.
  - On cache hit, increments refcount and returns with `*out = existing`.
- Otherwise loads texture data through the DataFile system:
  - If `DataFile_UnpackSearch(path)` succeeds, it calls `Image_LoadFromPath_Thunk(g_D3DDevice, path, ...)`.
  - Else it calls `DataFile_Load(path, &buf, &size)` and then calls `Image_LoadFromMemory_Thunk(g_D3DDevice, buf, size, ...)`, then `DataFile_Free(&buf)`.
- After successful load, queries the D3D texture for a `D3DSURFACE_DESC`-like struct via vtable method at +56 and stores the discovered format into `tex->format`.
- Stores width/height from the loader outputs, stores a heap-allocated copy of the path string as `tex->name`, sets refcount to `1`, increments `g_dwTexCount`, and registers into `g_pTexDB` (writing the registry index into the texture's first dword).
- On success returns the assigned registry index; on failure returns `-1`.

### Internal image decoding stack (used by `Texture_Load` / `Texture_Reload` / `Sprite_ReLoadNoFilter`)

The internal loaders used by `Texture_Load` are now named in IDA as:

- `Image_LoadFromPath_Thunk` (`0x1001BD6B`) — resolves a path into an in-memory buffer and then calls `Image_LoadFromMemory_Thunk`.
- `Image_LoadFromMemory_Thunk` (`0x1001BD2B`) — parameter reshuffle wrapper for `D3DTexture_LoadFromDecodedImage`.
- `D3DTexture_LoadFromDecodedImage` (`0x1001B6B8`) — the large implementation that:
  - decodes image/container data into pixel blocks
  - creates a D3D texture/surface/volume texture based on chosen format and parameters
  - uploads decoded pixels (including palette handling when present)

The decode stage is performed by a "try multiple codecs" routine now named `ImageDecoder_TryDecode` (`0x1001E957`). It attempts the following decoders (in a fixed order) until one succeeds:

- `ImageDecoder_Decode_BMP_File` (`0x1001E927`) — checks for the BMP file header (`'BM'`) and then invokes the DIB decode.
- `ImageDecoder_Decode_PPM_P3_P6` (`0x1001D809`) — checks for `P3` (ASCII) or `P6` (binary) portable pixmap and decodes to 32-bit pixels.
- `ImageDecoder_Decode_DDS` (`0x1001E075`) — checks for the `DDS ` magic (`0x20534444`) and parses the DDS header into one or more mip levels; handles block-compressed formats (DXT*) and uncompressed formats based on pixel masks.
- `ImageDecoder_Decode_JPEG` (`0x1001D0F2`) — uses a libjpeg-style setjmp error model; decodes to either 24-bit RGB or 8-bit grayscale (and expands to 32-bit when required by the consumer).
- `ImageDecoder_Decode_PNG` (`0x1001DADF`) — uses libpng (initializes with version string `1.0.5`); supports palettes, transparency, and 16-bit input (with conversion behavior visible in the implementation).
- `ImageDecoder_Decode_TGA` (`0x1001D362`) — parses a TGA header, supports color-mapped and truecolor variants and multiple pixel depths; supports optional RLE and vertical origin handling.
- `ImageDecoder_Decode_BMP_DIB` (`0x1001C6B6`) — decodes a BMP DIB (`BITMAPINFOHEADER` + optional palette + pixel data) without requiring the BMP file header.

Note: `D3DTexture_LoadFromDecodedImage` also accepts DDS data directly and can create multi-level textures (mipmaps) based on the decoded container.

See `Rendering/c3_core_dll/06_image_decoders.md` for container/codec specifics (DDS/PNG/JPEG/TGA/PPM/BMP).

## `Texture_Unload` (ordinal `161`, `0x10016640`)

Decrements the texture's refcount. When it reaches `0`:

- removes the texture from `g_pTexDB` if it has an assigned ID
- frees `tex->name` if present
- releases the underlying D3D texture COM object (`Release()`)
- deletes the `C3Texture` object, clears the caller's pointer, decrements `g_dwTexCount`

## `Texture_LockRect` / `Texture_Unlock` (ordinals `159` / `162`)

`Texture_LockRect`:

- only permits locking if `tex->format` is `21` or `22` (these correspond to `D3DFMT_A8R8G8B8` and `D3DFMT_X8R8G8B8` in Direct3D 8)
- calls the underlying D3D texture's `LockRect(level=0, lockedRectOut, &rect, flags=0)`
- returns true only when the underlying call returns `0`

`Texture_Unlock`:

- calls the underlying D3D texture's `UnlockRect(level=0)`

## `Texture_Reload` (ordinal `160`, `0x10016700`)

Reloads a texture in-place using `tex->name` as its path:

- Uses the DataFile system similarly to `Texture_Load`.
- Creates a new underlying D3D texture object and swaps it into `tex->d3dTexture`, releasing the prior COM object.
- Refreshes `tex->format`, `tex->width`, and `tex->height` from the new data.

## Upload pipeline (decoded image → D3D texture)

The final "decoded pixels into a D3D texture" stage is performed by the internal routine renamed in IDA as:

- `D3DTexture_LoadFromDecodedImage` (`0x1001B6B8`)

This is the implementation reached by both:

- `Image_LoadFromMemory_Thunk` (`0x1001BD2B`)
- `Image_LoadFromPath_Thunk` (`0x1001BD6B`)

### High-level stages (observed via disassembly)

1. Decode the source buffer using `ImageDecoder_TryDecode` (`0x1001E957`) into an internal linked representation containing:
   - one or more faces (e.g. DDS cube-like data)
   - one or more mip levels per face
2. Determine requested/implicit dimensions and levels:
   - if width/height/depth inputs are `0` or `-1`, they are replaced with decoded defaults.
   - validates that cube-like content has exactly 6 faces when the resource type indicates a cube/array-style upload.
3. Optional color-key preprocessing:
   - if a color-key value is present, the routine builds or transforms a 256-entry table used during upload.
4. Choose a supported format tag and finalize dimensions/mip count:
   - if a desired format tag is provided, it is looked up via `C3FormatDesc_LookupByTag`, then a supported tag is chosen via `Texture_ChooseSupportedFormatTag`.
   - the tag is normalized via `C3FormatTag_NormalizeForPaletteAnd16BitVariants`.
   - `Texture_AdjustDimsChooseFormatAndMipCount` is called to enforce device limits and requirements:
     - optional power-of-two rounding based on caps/usage
     - DXT1–DXT5 width/height rounding to multiples of 4
     - clamping mip count to the resulting dimensions
5. Create the destination D3D resource via a vtable call on the device pointer:
   - the exact method selected depends on the resource "kind" argument (2D texture vs volume texture vs cube texture), and is invoked through the device vtable at offsets `+0x50`, `+0x54`, or `+0x58`.
6. Upload decoded pixel data into each face/level:
   - for each face and each mip level, the code obtains a per-level subresource via a vtable call at `+0x3C` on the created resource.
   - it then calls one of two upload helpers:
     - `TextureUpload_CopyToSurfaceLevel` (`0x1001A7A6`)
     - `TextureUpload_CopyToVolumeLevel` (`0x1001A888`)
   - these helpers set up an internal "upload job" structure and forward to a shared implementation (`TextureUpload_ExecuteJob`) that performs the actual lock/copy/unlock and any palette/colorkey transforms.
