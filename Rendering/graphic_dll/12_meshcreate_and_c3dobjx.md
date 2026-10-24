# `graphic.dll` — `MeshCreate` and the `C3DObjX` mesh object

`graphic.dll` provides `MeshCreate(...)`, which constructs the mesh object used by the 3D pipeline for per-part rendering and hit-testing.

`GraphicData.dll` calls `MeshCreate(...)` to construct mesh objects, caches them, and then returns the resulting pointer to `Role3D.dll`. `Role3D.dll` treats that pointer as its per-part "mesh instance" object.

## `MeshCreate(meshPath)`

Entry point:
- `MeshCreate` (`0x10004960`)

Behavior:

1. Allocates `0xB0` bytes from `graphic.dll`'s heap wrapper.
2. Constructs a `C3DObjX` instance (`C3DObjX_Ctor` at `0x10003690`).
3. Calls the object's virtual init method at vtable offset `+0x0C` (index `3`) with `meshPath`.
4. If init succeeds (non-zero), returns the object pointer.
5. If init fails (zero), calls the object's scalar-deleting destructor (`C3DObjX_ScalarDeletingDtor`, vtable offset `+0xA4`) with argument `1` and returns `0`.

## C3 Mesh Container File Format (verified via Binja 2026-02-26)

The init method `C3DObjX::Create` (`0x10003830`) parses mesh files using the following format:

### File Layout
```
Offset  Size    Description
------  ------  -----------
0x00    16      File header (skipped by loader -- purpose TBD, possibly version/magic)
0x10    ...     PHY chunk stream (sequential chunks until EOF or max 16 submeshes)
```

### PHY Chunk Header (`ChunkHeader` struct, 8 bytes)
```c
struct ChunkHeader {
    char magic[3];    // Must be "PHY" (0x50, 0x48, 0x59)
    char type;        // Submesh variant (see table below)
    uint32_t size;    // Size of chunk data following this header (LE)
};
```

### PHY Type Variants
| Type byte | ASCII | Phy_Load args (skeleton, normals, UV) | Description |
|-----------|-------|---------------------------------------|-------------|
| `0x20`    | `' '` | `(0, 1, 1)` | Static mesh with normals and UV |
| `0x32`    | `'2'` | `(1, 0, 1)` | Skinned mesh with UV (no normals) |
| `0x33`    | `'3'` | `(1, 0, 0)` | Skinned mesh (skeleton only, no normals/UV) |
| `0x34`    | `'4'` | `(0, 1, 0)` | Static mesh with normals (no UV) |

### Parsing Flow (from `C3DObjX::Create`)
1. Opens file via `Common_OpenRes(path, &fileSize, 1)` -- imported from `c3_core_dll.dll`
2. Validates file size against resource limit via `g_ResLimitInterfacePtr` vtable slot `+0x00` (method index `0`, `category 0` in `GraphicData.dll` policy)
3. Records current seek position, then seeks forward 16 bytes (skip header)
4. Loop (max 16 iterations):
   a. Read 8-byte `ChunkHeader` via `Common_GetChunk(handle, &header)`
   b. If magic != "PHY", seek forward by `header.size` (skip unknown chunk)
   c. Based on `header.type`, call `Phy_Load(submeshSlotPtr, handle, skeleton, normals, uv)`
   d. If `Phy_Load` fails, break; else increment submesh count
   e. Check if seek position >= (startPos + fileSize), if so break
5. Close file via `Common_CloseRes(handle)`
6. Validate submesh count against phy limit callback via `g_ResLimitInterfacePtr` vtable slot `+0x20` (method index `8`, `category 8` in `GraphicData.dll` policy)

### Verified load-loop contract details (BNinja refresh 2026-03-04)

From `C3DObjX_Create` disassembly:

- loaded-submesh counter is `this+0x10`, initialized to `0` (`mov [esi+0x10], ebx` at `0x10003878`)
- hard cap is enforced on loaded count, not raw descriptor count:
  - `cmp dword [esi+0x10], 0x10` at `0x10003907`
- all four PHY type branches stop the entire load loop on first `Phy_Load` failure:
  - `' '` branch: `test eax,eax ; je 0x100039f7` at `0x1000395E..0x10003960`
  - `'2'` branch: `test eax,eax ; je 0x100039f7` at `0x10003983..0x10003985`
  - `'3'` branch: `test eax,eax ; je 0x100039f7` at `0x100039A4..0x100039A6`
  - `'4'` branch: `test eax,eax ; je 0x100039f7` at `0x100039C5..0x100039C7`
- unknown/non-PHY chunks are skipped with `Common_SeekRes(..., chunkHeader.size, 1)` (`0x100039D6`)

This `this+0x10` loaded-count is the same value consumed by `C3DObjX_SetMotion` capacity guard (`trackerMotionCount >= phyCount`).

### Managed parser guardrails (`Conquer.Assets`)

The managed reader (`C3MeshContainerReader`) keeps native chunk semantics but enforces strict bounds checks:
- chunk payload size must fit within remaining file bytes (`offset + 8 + size <= fileLength`);
- descriptor offsets/lengths are recorded only for fully in-range chunks;
- malformed/truncated chunk headers or payload sizes raise `InvalidDataException`.

These checks are defensive hardening for cross-platform tooling and do not change valid-file behavior.

### Resource I/O API (all imported from `c3_core_dll.dll`)
```c
void* Common_OpenRes(const char* path, long& size, int mode);  // IAT 0x1003912c
void  Common_CloseRes(void* handle);                            // IAT 0x100390e4
void  Common_SeekRes(void* handle, int offset, int whence);     // IAT 0x10039124
long  Common_GetSeek(void* handle);                             // IAT 0x10039128
void  Common_GetChunk(void* handle, ChunkHeader* out);          // IAT 0x1003911c
ulong Common_ReadRes(void* handle, void* buf, ulong size);      // (string at 0x1003fa76)
```

### `Phy_Load` Signature (imported from `c3_core_dll.dll`)
```c
int Phy_Load(C3Phy** out, void* stream, int hasSkeleton, int hasNormals, int hasUV);
```
## PHY Submesh Binary Format (verified via Binja on `c3_core_dll.dll`, 2026-02-26)

`Phy_Load` at `0x1000a300` in `c3_core_dll.dll` reads the following from the file stream
for each PHY chunk payload (i.e. the bytes *after* the 8-byte chunk header).

### C3Phy struct

Allocated size: `0x160` (352) bytes. Key field offsets:

| Offset | Type | Description |
|--------|------|-------------|
| `+0x00` | `char*` | Texture name (heap-allocated, null-terminated) |
| `+0x04` | `byte` | `hasSkeleton` flag (set to `arg3 == 1`) |
| `+0x05` | `byte` | `has2SidTag` (set only by the `"2SID"` trailing magic) |
| `+0x07` | `byte` | Normals-valid flag (set to 1 after normal computation) |
| `+0x08` | `uint32` | Total vertex count (`skinnedVerts + staticVerts`) |
| `+0x0C` | `void*` | Internal vertex array pointer (stride `0x34` = 52 bytes) |
| `+0x10` | `IDirect3DVertexBuffer8*` | GPU vertex buffer (stride `0x24` = 36 bytes) |
| `+0x14` | `uint32` | Total face/triangle count |
| `+0x18` | `uint16*` | Face index array (system memory copy) |
| `+0x1C` | `IDirect3DIndexBuffer8*` | GPU index buffer |
| `+0x28` | `vec3` | AABB min (3 floats, may be swapped per-component) |
| `+0x34` | `vec3` | AABB max (3 floats) |
| `+0x5C` | `uint32` | Bone group 1 count |
| `+0x60` | `void*` | Bone group 1 data pointer (16 bytes/entry) |
| `+0x64` | `uint32` | Bone group 2 count |
| `+0x68` | `void*` | Bone group 2 data pointer (16 bytes/entry) |
| `+0x6C` | `uint32` | Bone group 3 count |
| `+0x70` | `void*` | Bone group 3 data pointer (16 bytes/entry) |
| `+0x134` | `uint32` | Unknown (read before bone groups) |
| `+0x13C` | `uint32` | Step min (from "STEP" trailing magic) |
| `+0x140` | `uint32` | Step max (from "STEP" trailing magic) |
| `+0x144` | `uint32` | Billboard mode (0=none, 1=BILB, 2=BIL2, 3=BIL3, 4=BIL4) |
| `+0x14C` | `void*` | Smooth-group/normal-sharing set (internal std::set) |
| `+0x150` | `std::vector<int>` | Vertex-to-smooth-group mapping |

### Internal Vertex Format (52 bytes / 13 dwords)

The internal vertex array stores per-vertex data at stride `0x34`:

| Dword Index | Byte Offset | Field | Notes |
|-------------|-------------|-------|-------|
| [0] | 0x00 | pos.x | float |
| [1] | 0x04 | pos.y | float |
| [2] | 0x08 | pos.z | float |
| [3] | 0x0C | uv.u | float (bone data in `StaticPacked` layout) |
| [4] | 0x10 | uv.v | float (bone data in `StaticPacked` layout) |
| [5] | 0x14 | bone[0] | float (blend weight / index) |
| [6] | 0x18 | bone[1] | float |
| [7] | 0x1C | bone[2] | float |
| [8] | 0x20 | bone[3] | float |
| [9] | 0x24 | bone[4] | float |
| [10] | 0x28 | normal.x | float (may be zero for layouts without on-disk normals) |
| [11] | 0x2C | normal.y | float |
| [12] | 0x30 | normal.z | float |

### GPU Vertex Format (36 bytes / `D3DFVF_XYZ|NORMAL|DIFFUSE|TEX1`)

The GPU vertex buffer has stride `0x24` and is built from the internal array:

| Byte Offset | Size | Source | Field |
|-------------|------|--------|-------|
| 0x00 | 12 | internal[0..2] | pos (xyz) |
| 0x0C | 12 | internal[10..12] | normal (xyz) |
| 0x18 | 4 | hardcoded `0xFFFFFFFF` | diffuse color (white) |
| 0x1C | 4 | internal[3] | uv.u |
| 0x20 | 4 | internal[4] | uv.v |

Vertices are transformed by an internal 4x4 matrix helper before copying to GPU buffer.
For static meshes with normals (`arg3==0 && arg4!=0`), face normals are computed from
triangle cross products and accumulated per-vertex, then smoothed by merging co-located
vertices (within epsilon `0.01`).

### On-Disk Vertex Layouts Per PHY Type

| PHY Type | On-Disk Bytes/Vertex | Read Pattern | Internal Slots Filled |
|----------|---------------------|--------------|----------------------|
| `' '` `StaticSparse` | 76 | read(12) + skip(36) + read(28) | [0..9] pos+uv+bone; normals initially zero |
| `'2'` `SkinnedSparse` | 88 | read(12) + skip(36) + read(40) | [0..12] all 13 fields |
| `'3'` `SkinnedPacked` | 52 | read(52) contiguous | [0..12] all 13 fields |
| `'4'` `StaticPacked` | 40 | read(40) contiguous | [0..9] pos+bone (UV slots carry bone data) |

**UV variants (`' '` and `'2'`) skip 36 bytes** between position and the remaining data.
These 36 bytes are opaque on-disk data not loaded by the engine (possibly pre-baked GPU
vertex data or tangent/binormal vectors from the exporter; 36 = GPU vertex stride `0x24`).

Detailed per-type on-disk vertex structure:

**SkinnedPacked (`'3'`, 52 bytes, contiguous):**
```
[pos.x(f) pos.y(f) pos.z(f)] [uv.u(f) uv.v(f)] [bone0..4(5f)] [norm.x(f) norm.y(f) norm.z(f)]
 ↑ 12 bytes                    ↑ 8 bytes           ↑ 20 bytes     ↑ 12 bytes = 52 total
```

**StaticSparse (`' '`, 76 bytes, split read):**
```
[pos.x(f) pos.y(f) pos.z(f)] [36 bytes SKIPPED] [uv.u(f) uv.v(f)] [bone0..4(5f)]
 ↑ 12 bytes (read)             ↑ seek(36)          ↑ 28 bytes (read) = 76 total
```

**SkinnedSparse (`'2'`, 88 bytes, split read):**
```
[pos.x(f) pos.y(f) pos.z(f)] [36 bytes SKIPPED] [uv.u(f) uv.v(f)] [bone0..4(5f)] [norm.x(f) norm.y(f) norm.z(f)]
 ↑ 12 bytes (read)             ↑ seek(36)          ↑ 40 bytes (read) = 88 total
```

**StaticPacked (`'4'`, 40 bytes, contiguous):**
```
[pos.x(f) pos.y(f) pos.z(f)] [bone_data(7f)]
 ↑ 12 bytes                    ↑ 28 bytes = 40 total
 No on-disk normal block; internal[3..4] (UV slots) are populated from these first two bone floats
```

### PHY Submesh Data Order (sequential reads from file stream)

```
1.  Texture name length    uint32 (LE)
2.  Texture name           char[length] (null-terminated by loader)
3.  Vertex section flags   uint32 (named `vertexSectionFlags` in BNinja)
4.  Skinned vertex count   uint32
5.  Static vertex count    uint32
    → total = skinned + static
6.  Vertex data            (per type, see table above) × total vertices
7.  Skinned face count     uint32
8.  Static face count      uint32
    → total faces = skinned + static
9.  Face indices           uint16[totalFaces × 3] (triangle index triples)
10. Opaque section size    uint32
11. Opaque section bytes   byte[size] (skipped via seek)
12. AABB min               float[3] (x, y, z)
13. AABB max               float[3] (x, y, z)
    → loader swaps min/max per component if min > max
14. Transform matrix       float[16] (4×4, native file order)
--- GPU vertex buffer built here (D3D CreateVertexBuffer + copy loop) ---
--- Face normal computation for static+normals types ---
15. Unknown u32            uint32 (stored at C3Phy+0x134)
16. Bone group 1 count     uint32
17. Bone group 1 data      byte[count × 16] (if count > 0)
18. Bone group 2 count     uint32
19. Bone group 2 data      byte[count × 16] (if count > 0)
20. Bone group 3 count     uint32
21. Bone group 3 data      byte[count × 16] (if count > 0)
--- Trailing optional sections (magic-tagged, each 4 bytes) ---
22. "STEP" magic?          → if yes: read step_min(u32) + step_max(u32)
                           → if no:  seek back 4 bytes
23. "2SID" magic?          → if yes: set has2SidTag, read next 4 bytes
                           → if no:  seek back 4 bytes
24. Billboard magic?       "BILB"→mode 1, "BIL2"→mode 2, "BIL3"→mode 3, "BIL4"→mode 4
                           → if no match: seek back 4 bytes
```

## `C3DObjX` vtable and method semantics used by the client

`C3DObjX`'s primary vtable is `g_C3DObjX_Vtbl` (`0x10039504`).

Only the methods that are exercised by `GraphicData.dll` and `Role3D.dll` are documented here.

### Full vtable summary (verified BNinja 2026-03-14)

`g_C3DObjX_Vtbl` at `0x10039504`, 32+ entries:

| Index | Offset | Address | Name |
|-------|--------|---------|------|
| 0 | +0x00 | — | ScalarDeletingDtor (at +0xA4 in some layouts) |
| 2 | +0x08 | `0x10007230` | GetSubmeshSkipFlag |
| 10 | +0x28 | `0x100041A0` | FindSubmeshIndexByName |
| 11 | +0x2C | `0x10004200` | GetSubmeshId |
| 12 | +0x30 | `0x10007240` | GetSubmeshCount |
| 13 | +0x34 | `0x10004220` | GetSubmeshAabb |
| 14 | +0x38 | `0x10003D70` | SetMotion |
| 15 | +0x3C | `0x10003E10` | SetBlendMotion |
| 16 | +0x40 | `0x10004060` | GetPrimaryMotionBlendStateBySubmeshIndex |
| 17 | +0x44 | `0x10004090` | GetSecondaryMotionBlendStateBySubmeshIndex |
| 19 | +0x4C | `0x10004280` | SetPrimaryFrameForAllSubmeshes |
| 20 | +0x50 | `0x100042C0` | SetSecondaryFrameForAllSubmeshes |
| 21 | +0x54 | `0x10004330` | Render |
| 22 | +0x58 | `0x10004500` | SetPrimaryTexture |
| 23 | +0x5C | `0x100045A0` | SetMixTexture |
| 24 | +0x60 | `0x10007250` | SetTextureShaderDescriptor |
| 27 | +0x6C | `0x100046B0` | SetMatrices (3 matrices → all PHY submeshes) |
| 28 | +0x70 | `0x10007280` | SetSubmeshSkipFlag |
| 34 | +0x88 | `0x100047E0` | LoadFacePropertyFile |
| 39 | +0x9C | `0x10003ED0` | SetMotionAndPrimaryFrame |
| 40 | +0xA0 | `0x10003F90` | SetBlendMotionAndSecondaryFrame |

### Submesh enumeration and skipping

`C3DObjX_GetSubmeshCount` (vtable offset `+0x30`, index `12`) → `0x10007240`
- Returns `this[4]` (the number of submeshes / phys).

`C3DObjX_GetSubmeshSkipFlag` (vtable offset `+0x08`, index `2`) → `0x10007230`
- Returns the byte flag stored at `this + 84 + index`.
- The render loop skips submeshes where this flag is non-zero.

`C3DObjX_SetSubmeshSkipFlag` (vtable offset `+0x70`, index `28`) → `0x10007280`
- Writes `this + 84 + index = (value != 0)`.

`C3DObjX_GetSubmeshId` (vtable offset `+0x2C`, index `11`) → `0x10004200`
- Returns the first dword of the selected submesh/phy object:
  - `return *(this[5 + (index % this[4])])`.

### Submesh bounds (used for ray hit-testing)

`C3DObjX_GetSubmeshAabb` (vtable offset `+0x34`, index `13`) → `0x10004220`

Inputs:
- `index`
- `outMinVec3` (3 dwords)
- `outMaxVec3` (3 dwords)

Behavior:
- Selects the submesh record pointer: `phy = this[5 + (index % max(1, this[4]))]`
- Copies:
  - `outMinVec3 = *(phy + 40)` (3 dwords)
  - `outMaxVec3 = *(phy + 52)` (3 dwords)

### Motion binding

`C3DObjX_SetMotion` (vtable offset `+0x38`, index `14`) → `0x10003D70`

Verified behavior (BNinja refresh 2026-03-04):
- early-out if `motionTracker == 0` or `motionTracker == this+0xA8`
- capacity guard:
  - `motionTracker->GetMotionCount()` (vtable `+0x10`) must be `>= this+0x10` (`phyCount`)
  - on failure logs: `"Fail to C3DObjX::SetMotion due to PhyNum %d but MotionNum %d!"`
- for each submesh `i`:
  - `phy = *(this + 0x14 + i*4)`
  - `phy+0x40 = motionTracker->GetMotionByIndex(i)` (vtable `+0x14`)
  - disassembly write: `mov [ecx+0x40], eax` at `0x10003DD7`
- lifecycle lock handoff:
  - `motionTracker->LockLife(true)` (vtable `+0x28`)
  - previous tracker at `this+0xA8` gets `LockLife(false)` when non-null
- stores current tracker pointer at `this+0xA8`

The concrete motion container constructed by the client is `C3MotionTracker` (returned by `MotionCreate`), documented in `13_motioncreate_and_c3motiontracker.md`.

`C3DObjX_SetBlendMotion` (vtable offset `+0x3C`, index `15`) → `0x10003E10`

Verified behavior (BNinja refresh 2026-03-04):
- capacity guard mirrors `SetMotion` using `motionTracker->GetMotionCount()`
  - failure log: `"Fail to C3DObjX::SetBlendMotion due to PhyNum %d but MotionNum %d!"`
- for each submesh `i`:
  - when tracker is non-null:
    - `phy+0x44 = motionTracker->GetMotionByIndex(i)` (`mov [ecx+0x44], eax` at `0x10003E62`)
    - writes two fields in the returned motion entry:
      - `motionEntry+0x18 = blendAlpha` (`mov [eax+0x18], ecx` at `0x10003E6E`)
      - `motionEntry+0x14 = 0` (`mov dword [eax+0x14], 0` at `0x10003E76`)
  - when tracker is null:
    - `phy+0x44 = 0` (`mov dword [ecx+0x44], 0` at `0x10003E81`)
- lifecycle lock handoff mirrors `SetMotion`:
  - lock new tracker `LockLife(true)` (vtable `+0x28`)
  - unlock previous tracker from `this+0xAC` with `LockLife(false)`
- stores current blend tracker pointer at `this+0xAC`

### Primary/secondary frame propagation helpers (verified, BNinja 2026-03-04)

`C3DObjX_SetPrimaryFrameForAllSubmeshes` (vtable offset `+0x4C`, index `19`) → `0x10004280`
- loops `i in [0, phyCount)` and calls:
  - `Phy_SetFrame(phy[i], primaryFrameIndex)` (`call ... ?Phy_SetFrame` at `0x1000429A`)

`C3DObjX_SetSecondaryFrameForAllSubmeshes` (vtable offset `+0x50`, index `20`) → `0x100042C0`
- loops `i in [0, phyCount)` and calls:
  - `Phy_SetBlendFrame(phy[i], secondaryFrameIndex)` (`call ... ?Phy_SetBlendFrame` at `0x100042DA`)

`C3DObjX_SetMotionAndPrimaryFrame` (vtable offset `+0x9C`, index `39`) → `0x10003ED0`
- if `motionTracker == this+0xA8`, it forwards directly to `this->vtable[+0x4C](primaryFrameIndex)` and returns
- otherwise it mirrors `C3DObjX_SetMotion` binding (`phy[i]+0x40 = tracker->GetMotionByIndex(i)`) and then calls:
  - `Phy_SetFrame(phy[i], primaryFrameIndex)` (`call ... ?Phy_SetFrame` at `0x10003F4E`)
- lifecycle lock/unlock mirrors `C3DObjX_SetMotion`

`C3DObjX_SetBlendMotionAndSecondaryFrame` (vtable offset `+0xA0`, index `40`) → `0x10003F90`
- mirrors `C3DObjX_SetBlendMotion` binding (`phy[i]+0x44 = tracker->GetMotionByIndex(i)`)
- writes runtime blend state on each bound motion entry:
  - `motionEntry+0x18 = blendAlpha`
- then applies blend sample frame per submesh:
  - `Phy_SetBlendFrame(phy[i], secondaryFrameIndex)` (`call ... ?Phy_SetBlendFrame` at `0x10003FF9`)
- lifecycle lock/unlock mirrors `C3DObjX_SetBlendMotion`

Practical parity note:
- `C3DObjX_Render` itself does not call `Phy_SetFrame`/`Phy_SetBlendFrame`; frame position updates are performed through these frame helper methods before/around render.

Related helper (same frame API surface, different class):
- `C3PhyVector_SetPrimaryFrameForAll` (`0x100081B0`, renamed from `sub_100081b0`)
  - iterates pointer range `[this+0x08, this+0x0C)` as `C3Phy*` entries
  - calls `Phy_SetFrame(entry[i], primaryFrameIndex)` (`call ... ?Phy_SetFrame` at `0x100081DC`)

### Texture binding surface (verified, Binja 2026-02-28)

`C3DObjX_SetPrimaryTexture` (vtable offset `+0x58`, index `22`) → `0x10004500`

Behavior:
- Accepts:
  - `arg2`: texture resource object (nullable)
  - `arg3`: optional submesh selector object (nullable)
- If `arg3 == 0`, iterates all submeshes and updates each phy primary texture id.
- If `arg3 != 0`, resolves one submesh index via `arg1->vfn_40(arg3)` and applies only to that submesh.
- Texture id source:
  - `arg2 != 0` -> calls texture object virtual `+0x0C` to read numeric texture id.
  - `arg2 == 0` -> uses `-1` (unbind/sentinel).
- Applies the id via `Phy_ChangeTexture(phy, textureId)`.

`C3DObjX_SetMixTexture` (vtable offset `+0x5C`, index `23`) → `0x100045A0`

Behavior mirrors `C3DObjX_SetPrimaryTexture`, but calls `Phy_ChangeMixTexture(phy, textureId)`.

Implication:
- Render-time texture binding for `C3DObjX` is id-driven (`Phy_ChangeTexture`/`Phy_ChangeMixTexture`).
- PHY on-disk texture token strings are not directly bound at draw time in this path.

### Texture object creation bridge (verified, Binja 2026-02-28)

`TextureCreate` (`0x10005470`) allocates a `C3DTextureX` object and invokes its create virtual method.

`C3DTextureX_Create` (`0x100050F0`) is the concrete load path:
- checks global D3D device state,
- calls `Texture_Load(arg1+4, path, 8, 1, 0, 0, -1)` from `c3_core_dll.dll`,
- updates internal ready-state and resource-limit bookkeeping.

This confirms the `graphic.dll` boundary:
- texture object creation is path-based (`Texture_Load`),
- mesh-submesh binding is texture-id-based (`C3DObjX_SetPrimaryTexture` / `C3DObjX_SetMixTexture`).

### Submesh motion-link lookup helpers (used by `Role3D.dll`)

`Role3D.dll` resolves named submesh motion links through three `C3DObjX` virtual methods:

- `C3DObjX_FindSubmeshIndexByName` (vtable offset `+0x28`, index `10`) → `0x100041A0`
  - case-insensitive `_stricmp` match against submesh name strings
  - returns submesh index on hit, `-1` on miss
- `C3DObjX_GetPrimaryMotionBlendStateBySubmeshIndex` (vtable offset `+0x40`, index `16`) → `0x10004060`
  - returns submesh `primary` motion-blend pointer (`phy[index] + 0x40`)
- `C3DObjX_GetSecondaryMotionBlendStateBySubmeshIndex` (vtable offset `+0x44`, index `17`) → `0x10004090`
  - returns submesh `secondary` motion-blend pointer (`phy[index] + 0x44`)

These methods are consumed by `Role3D.dll` `PartInfo_TryResolveMotionLinkBySubmeshName` when building linked-part motion chains.

### Per-submesh matrix copy (`SetMatrices`, vtable offset `+0x6C`)

`sub_100046b0` (vtable offset `+0x6C`, index `27`) → `0x100046B0`

Verified behavior (BNinja 2026-03-14):
- Accepts three 4x4 matrix pointers: `arg2`, `arg3`, `arg4`.
- Iterates all PHY submeshes (`this+0x14`, count `this+0x10`):
  - Copies `arg2` (64 bytes) → `phy+0x74` (`objectToWorldMatrix`)
  - Copies `arg3` (64 bytes) → `phy+0xB4` (`localMatrix`)
  - Copies `arg4` (64 bytes) → `phy+0xF4` (`worldMatrix`)

This is the primary matrix injection point used by `Role3D.dll`. The caller `sub_10006520` in `Role3D.dll` computes:
```
result = partLocal(+0x44) × worldMatrix × posMatrix
```
then passes the three matrices to all PHY submeshes via this vtable call:
- `arg2` = `objectToWorldMatrix` (bind-pose transform)
- `arg3` = `localMatrix` (bone/local transform)
- `arg4` = `worldMatrix` (final world transform for `SetTransform(D3DTS_WORLD)`)

The `worldMatrix` at `C3Phy+0xF4` is what `Phy_DrawNormal_CPU` uses with `SetTransform(D3DTS_WORLD, &phy->worldMatrix)`.

### Render entry point

`C3DObjX_Render` (vtable offset `+0x54`, index `21`) → `0x10004330`

This is the primary draw method called by `Role3D.dll` (via its per-part "mesh instance" interface).

Verified control contract from disassembly (`0x10004330..0x100044fa`):

1. Calls `CMyBitmap::PrepareModle()` at function entry.
2. Iterates submesh pointers from `this + 0x14` up to count `this + 0x10`.
3. Per-submesh skip gate:
   - checks byte flag array at `this + 0x54 + submeshIndex`;
   - non-zero flag skips all work for that submesh.
4. Optional shadow descriptor path:
   - runs only when `shadowMode in {2,3,4}`;
   - builds a `C3_SHADOW_RENDER_DESC` via `j_D3dxShadowRenderDescriptorBuild_DelayLoadThunk`
     from the supplied direction vector and mode-specific basis constants.
5. Per-submesh step sync:
   - calls `Phy_SetStepCount(phy, this->stepFramePosition)` for each enabled submesh;
   - `stepFramePosition` is the unsigned field at `this+0x0C`, initialized to zero by
     `C3DObjX_Ctor`;
   - all enabled submeshes receive the same pre-increment value.
6. Render path split by the sixth stack argument (verified BNinja 2026-07-26, see also `c3_core_dll/05_phy.md`):
   - `useLiteRenderPath == 0` (full calculation path):
     - `Phy_Calculate(phy, 1, this+4, direction)` → thin wrapper calling `Phy_Calculate_CPU` (per-vertex skinning)
     - `Phy_DrawNormal(phy, this+0x64, this+4, &pipeRenderDesc, optionalShadowDesc)`
   - `useLiteRenderPath != 0` (lite calculation path):
     - `Phy_Calculate_Lite(phy)` → color-only update (diffuse ARGB), NO position/animation work
     - `Phy_DrawNormal_CPU(phy, this+0x64, this+4, &pipeRenderDesc, optionalShadowDesc)` → uses `SetTransform(D3DTS_WORLD, &phy->worldMatrix)` at `C3Phy+0xF4`
7. Increments `this->stepFramePosition` once after the loop and returns the incremented value.
   The 32-bit `inc` wraps naturally.

Notes:

- `C3DObjX_Render` constructs an exact `0x0C`-byte `C3_PIPE_RENDER_DESC`:
  source blend mode from stack arg 4, destination blend mode from stack arg 5,
  forced `depthWriteAndLightingEnabled=1`, and
  `useCounterClockwiseCullMode` from stack arg 7.
- Descriptor byte `+0x08` is passed to `D3DRS_ZWRITEENABLE` and also gates the
  material/lighting branch. Alpha testing is separate global device state:
  `Init3DEx` enables it and fixes `ALPHAREF=8`,
  `ALPHAFUNC=D3DCMP_GREATEREQUAL`.
- `Phy_DrawNormal[_CPU]` consumes that selector only when `has2SidTag==0`:
  selector zero requests `D3DCULL_CW(2)`, nonzero requests
  `D3DCULL_CCW(3)`. A `2SID`-tagged PHY requests `D3DCULL_NONE(1)`
  (core `0x1000CD0F..0x1000CD3D`; corrected 2026-10-11, previously inverted).
- The render-path branch at `0x10004459..0x10004465` tests the low byte of
  `useLiteRenderPath`.
- `I3DRole_RenderPartByName_WithMotions` passes `useLiteRenderPath=0` to
  `PartInfo_RenderAllParts`; that function forwards all seven arguments unchanged to
  `C3DObjX_Render`. The separate role byte at `I3DRole+0x34` is the cull selector
  and defaults to zero.
- The shadow descriptor build thunk (`0x1001b5d6`) is a delay-load dispatcher and is only used by `C3DObjX_Render`.
- Real-client hero correction:
  - role body meshes `002000000.c3` / `003000000.c3` are `StaticSparse` on disk,
  - but their normalized vertex payload still contains live bone indices/weights,
  - so the managed port must not treat `StaticSparse` as automatically rigid when building Role3D render data.

### Per-part texture-shader descriptor

`C3DObjX_SetTextureShaderDescriptor` (vtable offset `+0x60`, index `24`) ->
`0x10007250`

The first two fields after the vtable form the exact descriptor forwarded to
`Phy_DrawNormal[_CPU]`:

```c
struct C3_TEX_SHADER_DESC {
    uint32_t mode;       // C3DObjX+0x04
    uint32_t parameter;  // C3DObjX+0x08
};
```

Behavior:
- a positive `textureShaderMode` is stored unchanged;
- a nonpositive mode stores the default value `4`;
- `textureShaderParameter` is always stored unchanged.

`C3DObjX_Render` passes `&this->textureShader` to every enabled PHY draw. Role3D
calls this method immediately before each part draw with the file-backed MESH
`meshStateId` and parameter `0`.

### Per-object material

`C3DObjX_SetMaterial` (vtable offset `+0x64`, index `25`) -> `0x10004640`
copies exactly one `D3DMATERIAL8` (`0x44` bytes) into `C3DObjX+0x64`.
`C3DObjX_Render` passes that stored material to every submesh draw.

`C3DObjX_Ctor` initializes:

- Diffuse `(1,1,1,1)`
- Ambient `(0.5,0.5,0.5,0.5)`
- Specular `(1,1,1,1)`
- Emissive `(0,0,0,0)`
- Power `0`

The normal Role3D bind path replaces this default from the material pointer
resolved for each serialized MESH part.

`C3DObjX_SetPrimaryTexture` (`+0x58`) and `C3DObjX_SetMixTexture` (`+0x5C`)
independently populate each selected PHY's `baseTextureId` and `mixTextureId`.
Therefore the texture descriptor does not carry either texture ID.

### Face property file loading

`C3DObjX_LoadFacePropertyFile` (vtable offset `+0x88`, index `34`) → `0x100047E0`

Behavior:
- Opens the specified property file as a resource stream.
- Verifies the property file's phy/submesh count matches `this[4]`.
- For each phy/submesh:
  - reads a small header (`faceCount` and a `seek` value),
  - verifies the face count matches the phy's face count field,
  - seeks, then calls `Phy_LoadFaceProperty(phy, stream)`.
- Logs detailed mismatch/read errors and returns `0` on failure; returns `1` on success.
