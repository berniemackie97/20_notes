# Static Mesh Baseline Runtime

## Scope
Deterministic mesh selection for the OpenGL baseline runtime in `10_work/src/Conquer`.

## Verified behavior
- Runtime accepts optional mesh override: `--mesh-path=<virtual-path>` or `--mesh-path <virtual-path>`.
- When `--mesh-path` is supplied, load is strict and deterministic:
  - runtime attempts that path only;
  - no silent fallback to a different mesh.
- When no override is supplied:
  - runtime first attempts deterministic default path `c3/mesh/001132000.c3`;
  - if unavailable, runtime falls back to object DB scan and scoring.

## Real-client evidence (clean 5517 dataset)
E2E test coverage in `Conquer.Tests.Graphics.FirstStaticMeshAssetLoaderRealClientTests` verifies:
- `TryLoadByVirtualPath("c3/mesh/001132000.c3")` succeeds.
- Parsed topology for that specific asset is:
  - vertices: `24`
  - indices: `36` (`12` triangles)
  - used vertices: `24`
  - bounds extent: `20`
  - bounds size: `(20, 20, 20)`

Interpretation:
- A coarse shape for this asset can still be valid even when parser/runtime are correct.
- This does not by itself indicate a parser failure.

## Texture slot contract (verified)

- The selected PHY for `c3/mesh/001132000.c3` exposes `SourceTextureName = "v_armet"` (token slot, not a virtual `.dds` path).
- Verified native bind path:
  - `TextureCreate -> C3DTextureX_Create -> Texture_Load(path, ...)` creates a texture object from a resolved path.
  - `C3DObjX_SetPrimaryTexture` reads the texture object id and applies it through `Phy_ChangeTexture`.
- Therefore, standalone baseline rendering cannot treat PHY texture tokens as loadable paths directly; it must resolve token/part context to an actual texture path/id first, then upload/bind.

## Verified draw-path parity (2026-02-28)

### Native vs managed vertex layout comparison

| Aspect | Native (D3D8) | Managed (OpenGL 4.1) |
|--------|---------------|----------------------|
| Position | float3 at +0x00 | float3 at offset 0 (location 0) |
| Normal | float3 at +0x0C | float3 at offset 12 (location 1) |
| Diffuse | uint32 at +0x18 (=0xFFFFFFFF) | **omitted** (shader uses constant albedo) |
| UV | float2 at +0x1C | float2 at offset 24 (location 2) |
| Stride | 36 bytes (0x24) | 32 bytes (sizeof StaticMeshVertex) |
| Index type | uint16 | uint32 (widened during load) |
| Primitive | D3DPT_TRIANGLELIST | GL_TRIANGLES |

Diffuse omission is intentional: native uses fixed `0xFFFFFFFF` for static meshes, so the managed shader hardcodes white albedo (or texture color when textured).

### Known implementation gaps (pre-fix)
1. **Normal computation**: native normalizes face normals **before** accumulating per-vertex; managed code accumulates unnormalized face normals (area-weighted). Fix: normalize each face normal before adding to vertex accumulators.
2. **Smooth-group averaging**: native uses `SmoothGroupSet` to average normals across grouped vertices; managed code is missing this entirely. Impact: subtle lighting differences on meshes with smooth groups. Deferred until smooth-group data is fully decoded.
3. **Cull mode**: native forces `D3DCULL_CW` for static meshes; managed disables culling entirely. Acceptable for baseline bring-up.

## Practical usage
- Deterministic repro command (example):
  - `dotnet run --project src/Conquer -- --mesh-path c3/mesh/001132000.c3`
- To inspect a different asset end-to-end without changing code:
  - pass a different virtual path with `--mesh-path`.
