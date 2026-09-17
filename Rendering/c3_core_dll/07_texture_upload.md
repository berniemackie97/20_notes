# Texture upload engine (`TextureUpload_ExecuteJob`)

The internal "texture upload job" routine the engine uses to copy and transform decoded pixel data into D3D textures.

## Entry point

- `TextureUpload_ExecuteJob` (`0x100222E7`) is the shared implementation invoked by:
  - `TextureUpload_CopyToSurfaceLevel` (`0x1001A7A6`)
  - `TextureUpload_CopyToVolumeLevel` (`0x1001A888`)

## Verification snapshot (2026-02-27)

The following routines were re-verified in BNinja for this implementation slice:

- `Texture_ChooseSupportedFormatTag` (`0x1001A693`)
- `Texture_AdjustDimsChooseFormatAndMipCount` (`0x1001A95B`)
- `TextureUpload_TryFastPath_CopyDXTBlocks` (`0x1001F2E7`)
- `TextureUpload_TryFastPath_DirectCopySameLayout` (`0x1002044A`)
- `D3DTexture_LoadFromDecodedImage` (`0x1001B6B8`)

### `Texture_ChooseSupportedFormatTag` (`0x1001A693`)

Verified behavior:

- Iterates the format descriptor table at `0x100A1800` in 9-dword (`0x24` byte) records.
- Uses device format checks (vtable call `+0x28`) to skip unsupported candidate tags.
- If candidate tag exactly matches requested descriptor tag, returns immediately.
- Otherwise computes conversion cost via `C3FormatDesc_ComputeConversionCost` (`0x1001A5B0`), tracks best candidate, and uses `bitsOrBpp` as tie-breaker.
- Returns descriptor `entry[0]` (format tag), or default table entry tag when no better match exists.

### `Texture_AdjustDimsChooseFormatAndMipCount` (`0x1001A95B`)

Verified behavior:

- Validates usage flags against mask `0x20B`; invalid combination returns `0x8876086C`.
- Validates pool argument to `{0,1,2,3}`.
- If pool is not `3`, calls `Texture_ChooseSupportedFormatTag` (`0x1001A693`) to select a supported format tag.
- Normalizes dimensions:
  - `-1` defaults to the paired dimension; both `-1` default to `256x256`
  - zero dimensions become `1`
  - cube (`rtype=5`) enforces square dimensions (`max(width,height)`).
- Applies capability-based clamping using caps fetched from device vtable `+0x1C`.
- Applies power-of-two rounding when required by caps (resource-type specific flag tests).
- For DXT tags (`DXT1..DXT5`), rounds width/height up to multiples of 4.
- Computes/normalizes mip count, including a forced `1` level path for pool `3`.

### `TextureUpload_TryFastPath_CopyDXTBlocks` (`0x1001F2E7`)

Verified behavior:

- Validates source and destination copy region coordinates are 4-aligned (`& 3 == 0` checks).
- Supports only DXT tags:
  - `DXT1` => `8` bytes per `4x4` block
  - `DXT2..DXT5` => `16` bytes per `4x4` block
- Computes block-row byte count from block width and performs direct block row copies.
- Returns `E_FAIL` (`0x80004005`) when alignment or format checks fail.

## Rebuild mapping (OpenGL 4.1)

Current implementation uses these engine-tag to OpenGL upload mappings:

| Engine tag | Meaning | OpenGL internalFormat | Upload path |
|---:|:---|:---|:---|
| `DXT1` (`0x31545844`) | BC1 | `COMPRESSED_RGBA_S3TC_DXT1_EXT` | `CompressedTexImage2D` |
| `DXT2` (`0x32545844`) | BC2 variant | `COMPRESSED_RGBA_S3TC_DXT3_EXT` | `CompressedTexImage2D` |
| `DXT3` (`0x33545844`) | BC2 | `COMPRESSED_RGBA_S3TC_DXT3_EXT` | `CompressedTexImage2D` |
| `DXT4` (`0x34545844`) | BC3 variant | `COMPRESSED_RGBA_S3TC_DXT5_EXT` | `CompressedTexImage2D` |
| `DXT5` (`0x35545844`) | BC3 | `COMPRESSED_RGBA_S3TC_DXT5_EXT` | `CompressedTexImage2D` |
| `21` | `A8R8G8B8` | `RGBA8` (`BGRA/UNSIGNED_BYTE`) | `TexImage2D` |
| `22` | `X8R8G8B8` | `RGBA8` (`BGRA/UNSIGNED_BYTE`) | `TexImage2D` |
| `20` | `R8G8B8` | `RGB8` (`BGR/UNSIGNED_BYTE`) | `TexImage2D` |
| `23` | `R5G6B5` | `RGB` (`RGB/UNSIGNED_SHORT_5_6_5`) | `TexImage2D` |
| `25` | `A1R5G5B5` | `RGBA8` (`BGRA/UNSIGNED_SHORT_1_5_5_5_REV`) | `TexImage2D` |
| `26` | `A4R4G4B4` | `RGBA8` (`BGRA/UNSIGNED_SHORT_4_4_4_4_REV`) | `TexImage2D` |
| `28` | `A8` | `R8` (`RED/UNSIGNED_BYTE`) | `TexImage2D` |
| `50` | `L8` | `R8` (`RED/UNSIGNED_BYTE`) | `TexImage2D` |
| `51` | `A8L8` | `RG8` (`RG/UNSIGNED_BYTE`) | `TexImage2D` |

## Inputs (high level)

`TextureUpload_ExecuteJob` receives:

- a job object (`this`) that contains:
  - a destination subresource handle (`this[1]`)
  - a source description / decoded-image handle (`this[0]`)
  - a packed "mode" field (`this[2]`) used for selecting strategies and feature flags
- a "job descriptor" structure (`a2`) built by the caller (contains format tags, dimensions, strides, and per-level pointers)
- a conversion/palette table pointer (`a3`) which may be null
- a small integer mode (`a4`) (validated as 1..5 with additional flag bits)

## Strategy selection (observed)

After basic validation and preparation, `TextureUpload_ExecuteJob` tries a fixed sequence of internal strategies; it returns success as soon as one succeeds:

- `TextureUpload_TryFastPath_DirectCopySameLayout` (`0x1002044A`)
- `TextureUpload_TryFastPath_CopyViaRowFetch_ToTemp16ByteRecords` (`0x10020582`)
- `TextureUpload_TryFastPath_CopyWithZeroPadExtraRowsCols` (`0x10020673`)
- `TextureUpload_TryFastPath_ResampleNearest3D_Fixed16_16` (`0x10020875`)
- `TextureUpload_TryFastPath_GenerateMip_2D_Average2x2` (`0x10020A79`)
- `TextureUpload_TryFastPath_GenerateMip_3D_Average2x2x2` (`0x10020E9C`)
- `TextureUpload_TryPath_Type3_ComputeFromWeightTables_VariantA` (`0x1002142E`)
- `TextureUpload_TryPath_Type3_ComputeFromWeightTables_VariantB` (`0x10021814`)
- `TextureUpload_TryPath_ComposeSlices_2D` (`0x10021F45`)
- `TextureUpload_TryPath_ComposeSlices_3D` (`0x1001EE73`)

## Verified behaviors (subset)

## Helper routines used by upload strategies

### `CallCtorIterator_StrideBytes` (`0x1001ADA9`)

This is a generic helper used throughout the upload code to "construct" (initialize) a sequence of fixed-size records:

- Calls a provided function pointer `count` times, each time advancing the base pointer by `strideBytes`.
- In upload code paths this is typically used with `strideBytes = 16` to initialize arrays of 16-byte records.

### `NoopCtor_ReturnThis` (`0x1001A885`)

A no-op "constructor" callback used with `CallCtorIterator_StrideBytes`. It simply returns `this` and performs no initialization.

### `ResampleTable_CreateLinear2Tap_ClampOrWrap` (`0x1002132E`)

Builds a fixed-size, **2-tap linear** resampling table used by the "type 3" resample strategies.

Inputs (observed):

- `dstCount` (`a1`): number of destination samples.
- `srcCount` (`a2`): number of source samples.
- `wrap` (`a3`): when non-zero, indices wrap around (toroidal); when zero, indices clamp to the edge.

Output:

- Allocates and returns an array of `dstCount` records, each record is **16 bytes**:
  - `int srcIndex0`
  - `float weight0`
  - `int srcIndex1`
  - `float weight1`

Mapping:

- Uses half-texel alignment: `srcX = (dstIndex * (srcCount / dstCount)) - 0.5`.
- `srcIndex0 = floor(srcX)`, `srcIndex1 = srcIndex0 + 1` (then clamp/wrap as needed).
- `weight0 = 1.0 - frac(srcX)`, `weight1 = 1.0 - weight0`.

### Direct copy (same layout)

`TextureUpload_TryFastPath_DirectCopySameLayout` (`0x1002044A`) performs a straight memory copy from the decoded/source surface to the destination surface when the job indicates identical layout.

Verified preconditions (the routine returns failure unless all hold):

- `dst->formatTag == src->formatTag` (compares `dst[1]` vs `src[1]`)
- `src->auxField4 == 0` (the source descriptor's field at index `4` must be zero)
- `dst->width == src->width` (compares `dst[1046]` vs `src[1046]`)
- `dst->height == src->height` and `dst->depth == src->depth` (compares `dst[1047]`/`dst[1048]` vs source)
- If the source has a 256-entry conversion/palette table (`dst[5] != 0`), then:
  - the table pointers must match (`dst+12` vs `src+12`) **or**
  - the table bytes must be identical (memcmp of `0x400` bytes).

Copy behavior (when the above holds):

- If `dst->depth` is zero, it does not copy pixels in this routine and instead delegates to `TextureUpload_TryFastPath_CopyDXTBlocks` (`0x1001F2E7`) for that case.
- Otherwise it copies per-slice:
  - For each slice `z` in `[0 .. depth)`:
    - `dstSliceBase = dst->pixelBase + z * dst->sliceStride`
    - `srcSliceBase = src->pixelBase + z * src->sliceStride`
    - For each row `y` in `[0 .. height)`:
      - copies exactly `dst->rowCopyBytes` bytes from `srcRow` to `dstRow`
      - advances `dstRow += dst->rowStride` and `srcRow += src->rowStride`

This is the pragmatic "happy path" for identical format + identical dimensions, used when no resampling, padding, or format conversion is needed.

### Mipmap generation (2D)

`TextureUpload_TryFastPath_GenerateMip_2D_Average2x2` (`0x10020A79`) computes a 2D downsample by averaging 2x2 blocks (weight 0.25) and writes the result into the destination level.

This path is used when:

- source dimensions are exactly 2x the destination dimensions (with edge cases where width/height are `1`)
- source and destination have exactly one "slice" in the depth dimension

### Copy with zero-padding for mismatched dimensions

`TextureUpload_TryFastPath_CopyWithZeroPadExtraRowsCols` (`0x10020673`) fills the destination by:

1) copying the overlapping rectangle from source to destination, and
2) writing zeros for the remaining rows/columns/slices present in the destination but not in the source.

Verified preconditions:

- upload mode byte must equal `1` (`*((BYTE*)job + 8) == 1`)

Verified overlap computation:

- `copyWidth  = max(dstWidth, srcWidth)` (note: the implementation uses `max` here)
- `copyHeight = min(dstHeight, srcHeight)`
- `copyDepth  = min(dstDepth, srcDepth)`

Verified behavior:

- Allocates two temporary buffers of 16-byte records:
  - a `copyWidth`-sized buffer (zeroed) used as the per-row copy destination for the "overlap copy" step
  - a second buffer sized to the destination "row record count" (also zeroed) used to zero-fill rows when the destination is wider than the copied overlap
- For each slice `z` in `[0 .. copyDepth)`:
  - For each row `y` in `[0 .. copyHeight)`:
    - fetches row records from destination into the temp buffer (vtable call at `+4`)
    - fetches row records from source into the same temp buffer (vtable call at `+8`)
  - For rows `y` in `[copyHeight .. dstDepthOrHeight)` it fetches rows from the source into the "zero row" buffer to ensure the trailing portion is zero-filled.
- Frees both temp buffers and returns success.

Note: this routine's use of `max(dstWidth, srcWidth)` for the "width" dimension is preserved as implemented (even if it appears unintuitive). Downstream correctness relies on the exact same behavior.

### Copy via row-fetch to temp 16-byte records

`TextureUpload_TryFastPath_CopyViaRowFetch_ToTemp16ByteRecords` (`0x10020582`) copies data when source and destination have identical dimensions, but the upload path needs to operate via the "row fetch" vtable interface instead of raw pointer/stride copying.

Verified preconditions:

- `dst->width == src->width`
- `dst->height == src->height`
- `dst->depth == src->depth`

Verified behavior:

1) Allocates a temporary buffer sized `16 * width` bytes.

2) For each slice `z` in `[0 .. depth)`:
   - For each row `y` in `[0 .. height)`:
     - Calls `dst->FetchRow16(y, z, tmp)` (vtable `+4` on `dst` handle).
     - Calls `src->FetchRow16(y, z, tmp)` (vtable `+8` on `src` handle).

3) Frees the temporary buffer and returns success.

This routine is a pragmatic fallback between "raw memcpy" and the more complex resample/compose paths.

### Resample (3D nearest-neighbor; fixed-point 16.16)

`TextureUpload_TryFastPath_ResampleNearest3D_Fixed16_16` (`0x10020875`) performs **nearest-neighbor resampling** from a source volume into a destination volume.

Verified preconditions:

- upload mode byte must equal `2` (`*((BYTE*)job + 8) == 2`)

Allocation:

- Allocates two temporary arrays of 16-byte records:
  - `tmpSrcRow`: `16 * srcWidth` bytes
  - `tmpDstRow`: `16 * dstWidth` bytes

Scale factors (16.16 fixed-point):

- `stepX = (srcWidth  << 16) / dstWidth`
- `stepY = (srcHeight << 16) / dstHeight`
- `stepZ = (srcDepth  << 16) / dstDepth`

Behavior:

- Iterates destination slices `dstZ` in `[0 .. dstDepth)`; maintains `srcZ_fp` in 16.16 and uses `HIWORD(srcZ_fp)` as the selected source slice index.
- Iterates destination rows `dstY` in `[0 .. dstHeight)`; maintains `srcY_fp` in 16.16 and uses `HIWORD(srcY_fp)` as the selected source row index.
- For each destination row:
  - Fetches a source row via the source handle's vtable (call at `+4`):
    - `src->FetchRow16(srcY = HIWORD(srcY_fp), srcZ = HIWORD(srcZ_fp), tmpSrcRow)`
    - The implementation caches the last `srcY_fp` used to avoid re-fetching when adjacent `dstY` map to the same `srcY`.
  - For each destination X:
    - Computes `srcX = HIWORD(srcX_fp)` where `srcX_fp` advances by `stepX` each pixel.
    - Copies the selected 16-byte record from `tmpSrcRow[srcX]` into `tmpDstRow[dstX]`.
  - Writes the destination row via the destination handle's vtable (call at `+8`):
    - `dst->WriteRow16(dstY, dstZ, tmpDstRow)`

Cleanup:

- Frees both temporary arrays and returns success (`0`).

### Mipmap generation (3D / volume)

`TextureUpload_TryFastPath_GenerateMip_3D_Average2x2x2` (`0x10020E9C`) computes a 3D downsample by averaging 2x2x2 blocks (weight 0.125) and writes the result into the destination level.

This path is used when:

- source dimensions are exactly 2x the destination dimensions (with edge cases where a dimension is `1`)
- depth is also downsampled by 2 (volume textures)

### Type 3 resample (float4) from weight tables

Two additional strategies implement resampling using precomputed **2-tap linear** tables (built by `ResampleTable_CreateLinear2Tap_ClampOrWrap`).

Both strategies operate on 16-byte "pixel records" treated as **four floats** (RGBA-like float4). Each output record is computed as a weighted combination of source float4 records.

#### `TextureUpload_TryPath_Type3_ComputeFromWeightTables_VariantA` (`0x1002142E`)

Verified preconditions:

- low byte of `job->mode` must equal `3` (`(BYTE)job->mode == 3`)

Weight table construction (observed flags):

- Builds two `ResampleTable_CreateLinear2Tap_ClampOrWrap` tables:
  - one for the X axis (`dstWidth` from `srcWidth`)
  - one for the Y axis (`dstHeight` from `srcHeight`)
- The `wrap` parameter is controlled by bits in `job->mode`:
  - bit `0x10000` controls one axis' wrap/clamp selection
  - bit `0x20000` controls the other axis' wrap/clamp selection

Row fetch caching:

- Maintains two `srcWidth`-sized float4 row buffers and alternates between them (ping-pong) to avoid redundant fetches.
- Fetches source rows via the source handle's vtable `+4` into one of the row buffers, keyed by the `srcY` indices referenced by the Y table.

Per-output pixel math (exact structure):

- Let the Y table provide two source rows `y0`/`y1` with weights `wy0`/`wy1`.
- Let the X table provide two source columns `x0`/`x1` with weights `wx0`/`wx1`.
- For each destination X:
  - Compute `row(y0, x0)*wx0 + row(y0, x1)*wx1` (float4)
  - Compute `row(y1, x0)*wx0 + row(y1, x1)*wx1` (float4)
  - Combine those with Y weights:
    - `out = (…)*wy0 + (…)*wy1`

Writeback:

- Writes the computed row to the destination via destination vtable `+8` at `z = 0`:
  - `dst->WriteRow16(dstY, 0, outRowFloat4)`

#### `TextureUpload_TryPath_Type3_ComputeFromWeightTables_VariantB` (`0x10021814`)

Verified preconditions:

- low byte of `job->mode` must equal `3` (`(BYTE)job->mode == 3`)

High-level behavior:

- Extends the "2D two-tap" approach of Variant A to an additional dimension, computing output float4 records by combining multiple intermediate weighted sums.
- Builds **three** `ResampleTable_CreateLinear2Tap_ClampOrWrap` tables; the third is controlled by an additional mode bit (`0x40000`).
- Uses four `srcWidth`-sized float4 row buffers (organized as two-by-two groups) and a destination row buffer.
- Iterates over destination slices and rows and writes via destination vtable `+8` with `(dstY, dstZ, outRowFloat4)`.

Note:

- The internal arithmetic is implemented directly as float4 multiply-add chains over the three 2-tap tables (the code is largely unrolled). Implementations should preserve the same multiply/add staging and indexing to match the engine's exact floating-point behavior.

### Compose (general resample via sparse weight tables)

Two "compose slices" strategies implement resampling by accumulating source contributions into destination buffers using sparse weight tables. These paths are distinct from the "type 3" two-tap paths above.

#### `ResampleWeights_Build2PhaseTable` (`0x1001EB6A`) table format

`ResampleWeights_Build2PhaseTable(dstCount, srcCount, wrap)` returns a single allocation that encodes per-destination sparse weights.

Verified layout:

- Byte blob starts with a `u32 totalBytes`.
- Then follows an array of `u32` offsets, one per destination sample, each offset points to the start of that destination's weight list (relative to the beginning of the blob).
- Each destination's weight list is a sequence of `(int srcIndex, float weight)` pairs.
- Iteration pattern used by callers:
  - For a given destination sample, the caller computes `end = (char*)entry + *(u32*)entry` and iterates `for (p = entry + 1; p < end; p += 2)`.

Weight emission characteristics (as implemented):

- Uses a half-texel centered coordinate (`dst - 0.5`) and emits weights for overlapping source samples.
- Drops tiny weights (`<= 1e-5`) before emitting a pair.
- Uses `wrap` to decide whether out-of-range indices wrap or clamp.

#### `TextureUpload_TryPath_ComposeSlices_2D` (`0x10021F45`)

Verified preconditions:

- `srcDepth == 1` and `dstDepth == 1` (both objects' depth fields at offset `4192` equal `1`)

Behavior:

- Builds X and Y sparse weight tables via `ResampleWeights_Build2PhaseTable`:
  - X table maps `dstWidth` from `srcWidth`
  - Y table maps `dstHeight` from `srcHeight`
- Allocates:
  - A pool of per-destination-row accumulation buffers (each buffer holds `dstWidth` float4 records).
  - A metadata array of 12-byte "buckets" (one per destination row) containing:
    - pointer to the row buffer (or null)
    - a free-list link pointer
    - a remaining-reference count
- Initializes each destination row's reference count by counting how many times that row index appears in the Y table.

Accumulation:

- For each source row `srcY`:
  - Fetches the source row float4 array via source vtable `+4` into a temporary `srcWidth` buffer.
  - For each destination X weight list and each destination Y weight list entry:
    - Accumulates `srcPixelFloat4 * (wx * wy)` into the selected destination row buffer at the selected destination X index.

Flush:

- When a destination row's reference count reaches zero (all contributing source rows have been processed), writes the row to the destination via destination vtable `+8` at `z = 0`, then returns the buffer to the free list.

Cleanup:

- Destroys the bucket array and frees temporary allocations.

#### `TextureUpload_TryPath_ComposeSlices_3D` (`0x1001EE73`)

Behavior:

- Extends the 2D compose strategy to a third dimension using three sparse weight tables:
  - X maps `dstWidth` from `srcWidth`
  - Y maps `dstHeight` from `srcHeight`
  - Z maps `dstDepth` from `srcDepth`
- Allocates one 12-byte "bucket" per destination slice. Each bucket holds a pointer to a full `dstWidth * dstHeight` float4 accumulation buffer plus refcount metadata.
- For each source slice and row, fetches source row float4 data and accumulates into all destination slices referenced by the Z table, using `wx * wy * wz` weights.

Flush:

- When a destination slice's reference count reaches zero, writes that slice to the destination by iterating rows and calling destination vtable `+8` per row with pointer offsets:
  - `dst->WriteRow16(dstY, dstZ, sliceBuffer + dstY * dstWidth)`

### `Vector12_DestroyMaybeFree` (`0x1001EE27`)

Upload compose strategies allocate arrays of 12-byte "bucket" records using C++ vector construction helpers. This routine is the corresponding destruction/free helper:

- When called with flag bit `2`, it runs a 12-byte-record destructor iterator over `count = *((int*)this - 1)` and optionally frees the whole allocation when flag bit `1` is set.
- Callers in this module pass `a2 = 3` (destroy elements and free the backing allocation).
