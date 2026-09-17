# `graphic.dll` — Initialization and Device Reset

The `CMyBitmap` device and frame lifecycle entry points in `graphic.dll`.

## `CMyBitmap__Init3DEx` (0x100131E0)
Signature (as decompiled):
```c
int CMyBitmap::Init3DEx(
    HWND windowHandle,
    int backBufferWidth,
    int backBufferHeight,
    int windowed,
    unsigned int backBufferCount);
```

Behavior summary:
- Calls the global exported
  `Init3DEx(windowHandle, backBufferWidth, backBufferHeight, windowed, backBufferCount)`
  and interprets return codes.
- The only retail caller always supplies `windowed=1` and `backBufferCount=1`. Exact C3 device,
  depth/stencil, multisample, reset, and presentation behavior is proven in
  `../c3_core_dll/08_depth_stencil_and_presentation.md`.
- On success:
  - initializes the lighting defaults to disabled, direction `(1,1,1)`,
    diffuse/specular `0xFFFFFFFF`, and ambient `0xFF888888`
  - opens the literal path `ini/graphic.ini`
  - parses exactly seven fields with
    `fscanf("%u %f %f %f %x %x %d")`:
    `lightEnabled`, direction X/Y/Z, combined diffuse-and-specular ARGB,
    ambient ARGB, and direction rotation degrees
  - only when all seven fields parse, normalizes the direction, applies the
    configured rotation matrix, and calls
    `Phy_SetLight(lightEnabled, rotatedDirection.x, rotatedDirection.y,
    rotatedDirection.z, diffuseAndSpecularArgb, ambientArgb, 0.0f)`
  - stores `backBufferWidth/backBufferHeight` into globals
    `g_RenderBackbufferWidthPixels` (0x100441BC) /
    `g_RenderBackbufferHeightPixels` (0x100441C0)
  - calls `CMyBitmap__GameCameraCreate`
  - calls `CMyBitmap::GameCameraBuild(backBufferWidth, backBufferHeight)`
  - calls `Gfx_InitPseudoRandomTable()` (0x10012DE0)

The clean 5517 file contains exactly:

```text
0 1.0 1.0 0.5 ffffffff ff888888 -45
```

It parses successfully and calls `Phy_SetLight` with `lightEnabled=0`. Therefore
the clean target intentionally takes `Phy_DrawNormal_CPU`'s unlit
texture/vertex-diffuse path. Enabling a replacement Lambert/specular shader for
this data would not reproduce the original client.

Error handling:
- On a variety of negative return codes, formats specific error messages via `Gfx_Logf(...)` and returns `0`.

## `CMyBitmap__Begin3D` (0x100134F0)
- Calls exported `Begin3D()`.
- If success, sets `byte_1004ACF0 = 1` and returns `1`; else returns `0`.

## `CMyBitmap__End3D` (0x10013510)
- Resets `g_dwTriTotal = 0`.
- Sets `byte_1004ACF0 = 0`.
- Calls exported `End3D()`.

## `CMyBitmap__ClearBuffer` (0x10013530)
- Thin wrapper around exported `ClearBuffer(a1, a2, color)`.
- The C3 target accepts target/depth clears only; it never sets `D3DCLEAR_STENCIL`.

## `CMyBitmap__Flip` (0x10013550)
- Calls exported `Flip(srcRect, dstRect, hwnd)`.
- Tracks FPS-like metrics:
  - initializes `dword_100496C0 = timeGetTime()` once
  - increments `dword_1004ACF4` each call
  - if elapsed `> dword_100441C8`, computes `dword_100441CC = (1000 * frames) / elapsed_ms` and resets counters.

## `CMyBitmap::IfDeviceLost` (0x10013490)
- Thunk wrapper around exported `IfDeviceLost()`.

## `CMyBitmap__ResetDevice` (0x100134A0)
- Calls `TargetBmp_ReleaseDeviceResources(dword_1004ABB0)` (0x10007770)
- Calls exported `ResetDevice()`:
  - on success:
    - calls `CMyBitmap::GameCameraBuild()` (rebuilds camera projection)
    - sets `dword_1004ACEC = 0`
    - calls `TargetBmp_CreateOrRecreateDeviceResources(0,0)` (0x10007840)
    - returns `1`
  - on failure:
    - logs an error string via `Gfx_LogToDatedDebugFile` callsite (`aCtargetbmpStil...`)
    - returns `0`

The downstream reset reuses its 52-byte `D3DPRESENT_PARAMETERS` block unchanged.
