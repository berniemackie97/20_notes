# `graphic.dll` — Render Targets, Textures, and Target Surfaces

The internal "target surface" path inside `graphic.dll`: texture creation, and binding and restoring Direct3D render targets.

The EXE uses `TargetBmpCreate*` and `MyBitmapCreateEx`, but the concrete device-level behavior lives in `graphic.dll` and uses `IDirect3DDevice8` calls.

## Global device
- `g_D3DDevice` is a global pointer to `IDirect3DDevice8` (symbol present in the DLL).

## Target texture render-target binding

### `TargetTexture_BindAsRenderTarget` (0x10005A40)
Preconditions:
- Checks `*(this + 1016)` (a byte flag). If non-zero, returns `0`.

Behavior:
1) Calls `g_D3DDevice->GetRenderTarget(...)` and stores the result at `this + 1000`.
   - On failure: logs `TargetTexture GetRenderTarget Error` and returns `0`.
2) Calls `g_D3DDevice->GetDepthStencilSurface(...)` and stores the result at `this + 1004`.
   - On failure: releases the saved render target surface, logs `TargetTexture GetDepthStencilSurface Error`, returns `0`.
3) Calls a virtual method at `(*(*(this+996)+12) + 60)` to obtain a surface into `v22[0]` (likely "get surface level 0").
   - On failure: releases saved surfaces, logs an error, returns `0`.
4) Calls `g_D3DDevice->SetRenderTarget(v22[0], *(this + 1008))`.
   - On failure: releases `v22[0]` and saved surfaces and logs `g_D3DDevice->SetRenderTarget Failed!`.
5) Releases `v22[0]` if present.
6) If `byte_1004ACF0 == 0` (not inside Begin3D), calls `g_D3DDevice->BeginScene()` (vtable + 136).
7) Returns `1` on success.

### `TargetTexture_RestorePreviousRenderTarget` (0x10005CA0)
Preconditions:
- If `*(this + 1016)` is non-zero, returns.
- Requires both `this+1000` and `this+1004` to be non-null.

Behavior:
1) If `byte_1004ACF0 == 0`, calls `g_D3DDevice->EndScene()` (vtable + 140).
2) Calls `g_D3DDevice->SetRenderTarget(*(this+1000), *(this+1004))`.
   - On failure: logs `g_D3DDevice->SetRenderTarget Failed!`.
3) Releases `this+1000` and `this+1004` COM surfaces and clears them.

## Notes
- The BeginScene/EndScene calls are conditional on whether a `CMyBitmap::Begin3D()` has been performed (tracked by `byte_1004ACF0`).
- The render-target swap preserves and restores both color and depth/stencil surfaces.
