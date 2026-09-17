# Device lifecycle (`Init3DEx` / `IfDeviceLost` / `ResetDevice` / `Begin3D` / `End3D` / `Flip`)

This document describes the 3D device lifecycle entry points implemented in `c3_core_dll.dll`.

## Globals involved

The following exported globals are directly involved in device lifecycle:

- `?g_D3D@@3PAUIDirect3D8@@A` (ordinal `163`)
- `?g_D3DDevice@@3PAUIDirect3DDevice8@@A` (ordinal `165`)
- `?g_D3DCaps@@3U_D3DCAPS8@@A` (ordinal `164`)
- `?g_Present@@3U_D3DPRESENT_PARAMETERS_@@A` (ordinal `169`)
- `?g_DisplayMode@@3U_D3DDISPLAYMODE@@A` (ordinal `166`)
- `?g_hWnd@@3PAUHWND__@@A` (ordinal `177`)

## `Init3DEx` (ordinal `52`, `0x10008580`)

Prototype (export name):

- `?Init3DEx@@YAHPAUHWND__@@KKHK@Z`

Observed high-level sequence (decompiler):

1. Writes `g_DisplayMode.Width = a2` and stores additional inputs into module globals.
2. Calls `Direct3DCreate8(220)` and stores the result in `g_D3D`.
3. Calls `g_D3D->GetDeviceCaps(...)` into `g_D3DCaps`; failure returns `-1`.
4. Tries to validate adapter format / backbuffer format pairs (tries `23` then `24` as the chosen format); failure returns `-2`.
5. Zeros all 13 DWORDs of `g_Present`, then selects `D3DFMT_D16` unless bit 31 of the independently cached graphic-detail upper flags is set.
6. Calls `g_D3D->CreateDevice(...)`, trying behavior flags `68` then `36`. If those fail it switches only the back-buffer format to `22`, recomputes multisample compatibility against the unchanged depth format, and retries.
7. If `CreateDevice` succeeds and `(byte_100B0234 & 4) != 0`, reads the initial viewport via `g_D3DDevice->GetViewport(&g_Viewport)` and then applies a fixed set of render-state / texture-stage-state defaults.
8. Clears and initializes a large amount of additional module state (including setting several floats to `1.0f`, and initializing `g_IDMatrix` to identity).
9. Calls `ShowWindow(hWnd, 5)` and `UpdateWindow(hWnd)`, then returns `1`.

Return values observed:

- `1` on success
- `0` on some failure paths (including missing `g_D3D` and viewport-get failure)
- `-1` on `GetDeviceCaps` failure
- `-2` on inability to validate formats before device creation
- `-3` if `(byte_100B0234 & 4) == 0` after device creation

The complete present-parameter layout, reachability proof for D16/D24S8, multisample selection,
screen-mode flow, stencil/depth-state audit, and presentation timing are recorded in
`08_depth_stencil_and_presentation.md`.

## `Begin3D` / `End3D`

### `Begin3D` (ordinal `1`, `0x10008A80`)

- `?Begin3D@@YAHXZ`
- Calls `g_D3DDevice->BeginScene()`.
- Returns boolean success (`>= 0`).

### `End3D` (ordinal `31`, `0x10008AA0`)

- `?End3D@@YAHXZ`
- Calls `g_D3DDevice->EndScene()`.
- Returns boolean success (`>= 0`).

## `Flip` (ordinal `32`, `0x10008D60`)

- `?Flip@@YAHPBUtagRECT@@0PAUHWND__@@@Z`
- Calls `g_D3DDevice->Present(srcRect, dstRect, hWnd, 0)`.
- Returns boolean success (`>= 0`).

## `IfDeviceLost` (ordinal `51`, `0x10008AC0`)

- `?IfDeviceLost@@YAHXZ`
- Calls `g_D3DDevice->TestCooperativeLevel()`.

Return mapping (exact HRESULT comparisons in the code):

- returns `0` if `TestCooperativeLevel() >= 0`
- returns `1` if `TestCooperativeLevel() == 0x88760868` (as signed: `-2005530520`)
- returns `2` if `TestCooperativeLevel() == 0x88760869` (as signed: `-2005530519`)
- returns `0` otherwise

## `ResetDevice` (ordinal `124`, `0x10008AF0`)

- `?ResetDevice@@YAHXZ`
- Calls `g_D3DDevice->Reset(&g_Present)`; returns `0` on failure, `1` on success.
- Reuses the existing presentation block unchanged; it cannot alter the depth format,
  multisampling, or presentation interval.
- On success, applies the same fixed set of render-state / texture-stage-state defaults observed in `Init3DEx` after `GetViewport`.
