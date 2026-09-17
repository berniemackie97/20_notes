# `Role3D.dll` — Effect draw resource interface (virtual methods used)

The effect render backends in `Role3D.dll` (`Effect_RenderWithContext`, `Effect_RenderWithOffsets`, `Effect_RenderScreenSpace`) obtain a resource object via:

- `GameDataSetQuery()->GameDataSet_RequestEffectDrawResource(resourceId, 0, 0)`

and then drive that resource exclusively through its virtual method table (vtable). This document records the *exact vtable offsets and call contracts* exercised by `Role3D.dll`.

The concrete implementing class lives outside `Role3D.dll` (it is returned by `GraphicData.dll`'s dataset query), so the most stable representation is an interface defined by vtable slot offsets.

## Method summary (by vtable byte offset)

The following virtual methods are called on the resource object returned from `GameDataSet_RequestEffectDrawResource`:

| Vtable offset | Observed signature (from call sites) | Observable contract in Role3D |
|---:|---|---|
| `+0x0C` | `void BindContextPartMesh(void* mesh, char* ownerLabel, uint8_t spawnFlags, const float* optionalMatrix);` | Used only by `Effect_RenderWithContext` when `PartInfo_GetPartMeshArrayHeader(partInfoRoot)->count > 0`; matrix arg is either local effect matrix pointer or null based on `partInfo+0x6C`. |
| `+0x10` | `bool Draw2D(...);` | Primary draw entry used by all three effect render backends. Verified stack feed includes blend-related dwords, per-part bytes, effect frame counter, and optional accumulator pointer. |
| `+0x14` | `void SetIndexOrVariant(int);` | Called when an effect part record contains a non-negative dword at `part+0x0C`. |
| `+0x18` | `void SetSecondaryResource(void*);` | Called with an object obtained from `GameDataSet_RequestTexture(secondaryId,0,0)` when the effect part record requests a secondary resource rather than an index/variant. |
| `+0x1C` | `void ResetShapeRuntime();` | Used only by `EffectPart_EnsureRuntimeData` (init-only path). |
| `+0x20` | `void SetTranslate(float x, float y, float z);` | Used to position the effect instance in world/UI coordinates. |
| `+0x24` | `void SetRotate(float rx, float ry, float rz);` | Used by the backends that apply rotation. |
| `+0x28` | `void SetScale(float sx, float sy, float sz);` | Used by the backends that apply scaling. |
| `+0x2C` | `void SetMatrix(const float* m4x4);` | Called with a 64-byte matrix buffer (D3DX-style 4×4 float matrix). |
| `+0x30` | `void SetRenderParam1(uint32_t);` | Called with `effect+0x1B8` in `Effect_RenderWithOffsets` and `Effect_RenderScreenSpace`. |
| `+0x4C` | `uint32_t GetFrameCount();` | Compared against `effect->currentFrameIndex`; if `currentFrameIndex >= frameCount`, render backend aborts current effect render call. |
| `+0x50` | `void SetFrameIndex(int);` | Called with `currentFrameIndex - partFrameBaseOffset[i]` when non-negative. |
| `+0x5C` | `void PostDrawShapeInfoHandle(uint32_t);` | Called after draw with `part[7]` (same dword used by slot `+0x60`). |
| `+0x60` | `void SetShapeInfoHandle(uint32_t);` | Called each draw iteration with `part[7]` (`shapeInfoHandle`). |
| `+0x68` | `void SetParticle2InfoHandle(uint32_t);` | Called each draw iteration with `part[5]` (`particle2InfoHandle`). |
| `+0x70` | `void SetParticle3InfoHandle(uint32_t);` | Called each draw iteration with `part[6]` (`particle3InfoHandle`). |
| `+0x74` | `void SetTripletA(uint32_t a, uint32_t b, uint32_t c);` | Called with effect-instance dwords `effect[0x1C8..0x1D0]`. |
| `+0x78` | `void SetTripletB(uint32_t a, uint32_t b, uint32_t c);` | Called with effect-instance dwords `effect[0x1D4..0x1DC]`. |
| `+0x7C` | `bool ProbeOrAccumulate(void* out);` | Called early in some backends with a pointer to a 3-dword local buffer; if the call returns true, the backend stops scanning and transitions to the main render loop. |

Notes:
- Slots `+0x34` and `+0x38` are not called by `Effect_RenderWithContext`, `Effect_RenderWithOffsets`, or `Effect_RenderScreenSpace` in clean 5517.
- `GameDataSet_RequestTexture(...)` result is checked for readiness through texture vtable slot `+0x10` before binding to draw resource slot `+0x18`.
- `Effect_RenderWithContext` additionally calls:
  - `PartInfo_GetPartMeshArrayHeader` (`0x10005FB0`)
  - `PartInfo_BuildPartMatrixForFrame` (`0x100063E0`)
  - `j_MatrixMultiplyDispatch` (`0x1000EB04`)
  before issuing slot `+0x2C` matrix upload.

## Init-only methods used by `EffectPart_EnsureRuntimeData`

`Role3D.dll` calls an additional init surface before first-frame part use:

- `EffectPart_EnsureRuntimeData` (`0x1000A210`) invokes draw-resource vtable slots:
  - `+0x1C` (no args)
  - `+0x54` -> stored to `part[2]`
  - `+0x58` -> stored to `part[7]` when `part[7] == 0`
  - `+0x5C(part[7])`
  - `+0x64` -> stored to `part[5]`
  - `+0x68(part[5])`
  - `+0x6C` -> stored to `part[6]`
  - `+0x70(part[6])`

Clean-5517 concrete mapping (when resource is `graphic.dll` `C3Effect`):

- `+0x1C` -> `C3Effect_ResetShapeRuntime`
- `+0x54` -> `C3MotionTracker_GetMotionCount`
- `+0x58` -> `C3Effect_CreateShapeInfo`
- `+0x5C` -> `C3Effect_ExportShapeInfoToBuffer`
- `+0x64` -> `C3Effect_CreatePtcl2Info`
- `+0x68` -> `C3Effect_BindPtcl2InfoBlocks`
- `+0x6C` -> `C3Effect_CreatePtcl3Info`
- `+0x70` -> `C3Effect_BindPtcl3InfoBlocks`

## Per-part byte parameters supplied to `Draw2D`

All effect render backends supply two per-part bytes to the resource draw call:

- `byteA = effect->byteStreamA[i]` (stored at `effect + 0x134 + i`)
- `byteB = effect->byteStreamB[i]` (stored at `effect + 0x144 + i`)

Observed contract:
- When `effect->renderFlag != 0` (`effect+0x1BC`), the backend allocates/feeds a local accumulator block and substitutes `byteB = 1` when source `byteB == 0`.
- When `effect->renderFlag == 0`, draw call uses raw `byteB` and null accumulator pointer.

The exact meaning of `byteA`/`byteB` is defined by the resource's `Draw2D` implementation, but their storage location and substitution rule are proven by `Role3D.dll`.
