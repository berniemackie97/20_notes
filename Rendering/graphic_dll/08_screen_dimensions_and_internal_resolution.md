# `graphic.dll` — Screen Dimensions and Internal Render Resolution

## Overview

The native Conquer 5517 client renders all game content at a **fixed internal resolution**
(the D3D8 backbuffer), then D3D8 `Present()` stretches the backbuffer to fill the actual
window. All game logic — projection, tile positioning, overlay centering, visibility culling —
operates exclusively in backbuffer pixel coordinates, never in window or display coordinates.

## Native Screen Mode Resolutions

The client supports two internal resolutions, selected via `ini/GameSetup.Ini` `[ScreenMode]ScreenModeRecord`:

| Mode | Resolution | Window Style | Notes |
|------|-----------|-------------|-------|
| 0    | 800×600   | Windowed    | Default if mode 2/3 not supported |
| 1    | 800×600   | Fullscreen  | `ChangeDisplaySettings` to 800×600 |
| 2    | 1024×768  | Windowed    | Requires display ≥ 1024×768 |
| 3    | 1024×768  | Fullscreen  | `ChangeDisplaySettings` to 1024×768 |

Set in `CMyShellDlg_ApplyScreenMode` (`Conquer.exe:0x5D7C51`):
- `g_ScreenModeWidthPixels` (`0x93FD7C`) = width (0x320=800 or 0x400=1024)
- `g_ScreenModeHeightPixels` (`0x93FD80`) = height (0x258=600 or 0x300=768)

These values are passed to `CMyBitmap::ChangeDisplayResolution(width, height)` which stores
them in graphic.dll globals.

All four modes pass `Windowed=TRUE` to the sole D3D device-creation call. Modes 1 and 3 use
`ChangeDisplaySettingsA` and window movement for their fullscreen shell behavior; they do not
create D3D fullscreen swap chains. See `../c3_core_dll/08_depth_stencil_and_presentation.md`.

## Global Storage (graphic.dll)

```
0x100441BC  g_RenderBackbufferWidthPixels   (int32)
0x100441C0  g_RenderBackbufferHeightPixels  (int32)
```

Written by:
- `CMyBitmap::Init3DEx` (0x100131E0) — arg2/arg3 → globals (one-time init)
- `CMyBitmap::ChangeDisplayResolution` (0x100135E8) — arg1/arg2 → globals (mode switch)

Both also call `CMyBitmap::GameCameraBuild(width)` to rebuild the D3D camera projection.

## Accessor Functions (graphic.dll exports)

```c
// 0x10013F80 — writes both dimensions via out-params
void CMyBitmap::GetScreenSize(int& outWidth, int& outHeight) {
    outWidth  = g_RenderBackbufferWidthPixels;   // [0x100441BC]
    outHeight = g_RenderBackbufferHeightPixels;   // [0x100441C0]
}

// 0x10013FC0 — returns width
int CMyBitmap::GetScreenWidth() {
    return g_RenderBackbufferWidthPixels;
}

// 0x10013FD0 — returns height
int CMyBitmap::GetScreenHeight() {
    return g_RenderBackbufferHeightPixels;
}
```

These are resolved at runtime via `GetProcAddress` by Conquer.exe and other DLLs.

## Usage in Projection System

`CGameMap_UpdateProjectionAndCameraFromScreenCenter` (0x61E0E7) calls
`CMyBitmap::GetScreenWidth()` / `GetScreenHeight()` directly for:

1. **Edge-scroll cursor thresholds** — offsets ±6 pixels based on cursor proximity to
   screen edge, measured against backbuffer dimensions
2. **Scaled viewport delta** — `SignedHalf(screenWidth - ScaledViewportWidthField14C)`
   for zoom-relative offset
3. **Projection center clamping** — min/max bounds computed from
   `projectionBaseCenter ± SignedHalf(screenWidth - scaledViewportWidth)`
4. **Camera build** — final projection center passed to `CGameMap_UpdateGameCameraFromProjectionCenter`

Every consumer of screen dimensions in the rendering pipeline uses these accessors.
The actual window size and display resolution are irrelevant to the rendering math.

## Verified Orthographic Camera State

BNinja verification in `graphic.dll` ties the projection system directly to the live
3D camera state used by role rendering:

- `CMyBitmap::GameCameraCreate()` (`0x1000EDB0`) seeds the orthographic camera to:
  - eye = `(backbufferWidth/2, -1000.0f, backbufferHeight/2)`
  - target = `(backbufferWidth/2, 0, backbufferHeight/2)`
  - near/far = `1.0f / 10000.0f`
- `CMyBitmap::GameCameraSet(float x, float y, float z, uint mode)` (`0x1000F0C0`)
  overrides that stored state and then tail-calls `CMyBitmap::GameCameraBuild()`
- in orthographic mode with `mode == 3`:
  - eye becomes `(x, z, y)`
  - target becomes `(x, 0, y)`
- `CGameMap_UpdateGameCameraFromProjectionCenter` (`Conquer.exe:0x61E6C6`) supplies:
  - `x = camX`
  - `y = camY`
  - `z = -1000.0f`
  - `mode = 3`

Managed implication:

- the map projection runtime is the authoritative producer of the current 3D camera
- role rendering must consume that committed camera state
- a fixed viewport-centered orthographic camera is only the startup default from
  `GameCameraCreate`; it is not the steady-state world-render camera once map
  projection begins

## Managed Rewrite: Internal Render Target Architecture

The cross-platform rewrite uses OpenGL 4.1 Core Profile (Silk.NET) instead of D3D8.
To maintain parity with the native fixed-resolution rendering:

1. **Internal FBO** — an offscreen framebuffer object at the game logic resolution
   (1024×768 default, matching native mode 2/3)
2. **Game logic resolution** — `PrepareFrame()`, projection tick, tile renderers,
   overlay positioning all receive the internal resolution, not the window/framebuffer size
3. **Final present** — `glBlitFramebuffer` from internal FBO to the default framebuffer
   (window surface), with `GL_LINEAR` filtering for upscale
4. **Window independence** — the window can be any size; the internal resolution is
   decoupled from both logical window size and physical framebuffer size

This matches the native D3D8 architecture: fixed backbuffer → `Present()` stretch to window.

### Intentional managed divergence: resizable host window

The reconstructed client intentionally allows its host window to be resized. This is a product
decision for the cross-platform client, not a claim that the retail v5517 shell exposed arbitrary
runtime window resizing.

Resizing changes only presentation:

- game simulation, projection, culling, UI layout, and input hit regions remain in the selected
  fixed logical backbuffer coordinate space;
- the internal FBO is not recreated to match each host-window size;
- the completed internal frame is scaled into the current window framebuffer at present time; and
- pointer coordinates are mapped from the current window extent back into logical backbuffer
  coordinates before native game/UI routing.

This boundary is deliberate and load-bearing. Future work must not feed the resized host-window or
physical framebuffer dimensions into native world/UI calculations merely to make content occupy the
new window size. Any aspect-ratio, letterboxing, or presentation-filter policy may evolve as managed
host behavior while the logical client coordinate contract remains native-compatible.

## Binja Renames Applied

| Binary | Address | Old Name | New Name |
|--------|---------|----------|----------|
| graphic.dll | 0x100441BC | dword_100441BC | g_RenderBackbufferWidthPixels |
| graphic.dll | 0x100441C0 | dword_100441C0 | g_RenderBackbufferHeightPixels |
