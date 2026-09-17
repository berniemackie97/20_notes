# `graphic.dll` — Camera (`CMyBitmap::GameCamera*`)

Verified in BNinja (`graphic.dll.bndb`) and cross-checked with imports from `C3_CORE_DLL.dll`.

This path is a runtime writer for `c3_core_dll` matrix globals used by particle type-3 basis logic:

1. `graphic.dll` camera APIs update camera globals.
2. They call imported `Camera_BuildView`.
3. In `c3_core_dll`, `Camera_BuildView` writes `g_ViewMatrix` and `g_InvViewMatrix`.
4. `C3ParticleType3_Draw` reads matrix components from those globals.

## Global camera state

- `g_GameCameraProjectionModeFlag` (`0x10049424`)
  - `0` => orthographic path
  - non-zero => perspective/project path
- Perspective camera fields (`0x100493b0` base):
  - `g_GameCameraPerspectiveState` (`+0x00`)
  - `g_GameCameraPerspectiveEyeY` (`+0x04`)
  - `g_GameCameraPerspectiveEyeZ` (`+0x08`)
  - `g_GameCameraPerspectiveTargetX/Y/Z` (`+0x0C/+0x10/+0x14`)
  - `g_GameCameraPerspectiveUpX/Y/Z` (`+0x18/+0x1C/+0x20`)
  - `g_GameCameraPerspectiveNearPlane` (`+0x24`)
  - `g_GameCameraPerspectiveFarPlane` (`+0x28`)
  - `g_GameCameraPerspectiveFieldOfViewRadians` (`+0x2C`)
- Orthographic camera fields (`0x100493f0` base):
  - `g_GameCameraOrthographicState` (`+0x00`)
  - `g_GameCameraOrthographicEyeY` (`+0x04`)
  - `g_GameCameraOrthographicEyeZ` (`+0x08`)
  - `g_GameCameraOrthographicTargetX/Y/Z` (`+0x0C/+0x10/+0x14`)
  - `g_GameCameraOrthographicUpX/Y/Z` (`+0x18/+0x1C/+0x20`)
  - `g_GameCameraOrthographicNearPlane` (`+0x24`)
  - `g_GameCameraOrthographicFarPlane` (`+0x28`)
- Ortho viewport cache:
  - `g_GameCameraOrthographicWidth` (`0x100493e8`)
  - `g_GameCameraOrthographicHeight` (`0x100493ec`)

## `CMyBitmap::GameCameraCreate` (`0x1000edb0`) — BNinja-verified values

- Calls `Camera_Clear` for both camera globals.
- **Orthographic camera** (from BNinja decompilation):
  - Eye: `(W/2, -1000.0f, H/2)` — EyeY=0xC47A0000=-1000.0f
  - Target: `(W/2, 0.0f, H/2)`
  - Up: `(0, 0, -1)` — from Camera_Clear default at C3Camera+0x20
  - Near: `0x3F800000` = **1.0f** (NOTE: BADimguiCO uses 0.0f — incorrect)
  - Far: `0x461C4000` = **10000.0f**
- **Perspective camera**:
  - Eye: `(0, -800.0f, computed)` — EyeY=0xC4480000=-800.0f
  - Near: `0x42C80000` = **100.0f** (NOTE: BADimguiCO uses 70.0f — incorrect)
  - Far: `0x45FA0000` = **8000.0f**
  - FOV: `0x3F490FDB` = **π/4 ≈ 0.7854 rad**

## `CMyBitmap::GameCameraBuild(CMySize)` (`0x1000ef20`)

- If `g_GameCameraProjectionModeFlag != 0`:
  - `Camera_BuildView(&g_GameCameraPerspectiveState)`
  - `Camera_BuildProject(&g_GameCameraPerspectiveState)`
- Else:
  - caches width/height in `g_GameCameraOrthographicWidth/Height`
  - `Camera_BuildView(&g_GameCameraOrthographicState)`
  - `Camera_BuildOrtho(&g_GameCameraOrthographicState, width, height)`

## `CMyBitmap::GameCameraBuild()` (`0x1000ef90`)

- Rebuild variant used after camera mutations/device reset.
- If perspective mode: `Camera_BuildView + Camera_BuildProject`.
- If orthographic mode: `Camera_BuildView + Camera_BuildOrtho` using cached width/height.

## Direct `Camera_BuildView` writer callsites

Verified from xrefs to import slot `0x100390bc`:

- `CMyBitmap::GameCameraBuild(CMySize)` (`0x1000ef2f`, `0x1000ef66`)
- `CMyBitmap::GameCameraBuild()` (`0x1000ef9e`, `0x1000efb8`)
- `CMyBitmap::GameCameraMove` (`0x1000f236`, `0x1000f29a`)
- `CMyBitmap::GameCameraRotate` (`0x1000f400`)
- `CMyBitmap::GameCameraCircum` (`0x1000f4a7`)
- `CMyBitmap::GameCameraPitch` (`0x1000f55b`)
- `CMyBitmap::CameraLook` (`0x1000fb65`, `0x1000fbc5`)

`GameCameraRotate/Circum/Pitch` use delay-loaded D3DX helpers:

- `D3dxMatrixRotationY_DelayLoadThunk`
- `D3dxQuaternionRotationAxis_DelayLoadThunk`
- `D3dxMatrixTransformation_DelayLoadThunk`
- `D3dxVec3TransformCoord_DelayLoadThunk`
- `D3dxVec3Normalize_DelayLoadThunk`
