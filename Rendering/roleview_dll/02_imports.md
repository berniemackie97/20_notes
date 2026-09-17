# `RoleView.dll` — Imports / External Dependencies

This document enumerates the imported DLLs and imported symbols for `RoleView.dll` as found in the clean 5517 client distribution.

## Imported DLLs

`RoleView.dll` imports from:

- `WINMM.dll`
- `graphic.dll`
- `GraphicData.dll`
- `Role3D.dll`
- `GameData.dll`
- `MSVCRT.dll`
- `KERNEL32.dll`
- `ADVAPI32.dll`

## Imports by module

### `WINMM.dll`

- `timeGetTime`

### `graphic.dll`

`RoleView.dll` uses `graphic.dll` only via `CMyBitmap` static helpers (camera/matrix + ray construction):

- `CMyBitmap::Common_Rotate(D3DXMATRIX*, float, float, float)`
- `CMyBitmap::Common_Scale(D3DXMATRIX*, float, float, float)`
- `CMyBitmap::Common_Translate(D3DXMATRIX*, float, float, float)`
- `CMyBitmap::ScrRayBuild(int x, int y, D3DXVECTOR3& outRayPos, D3DXVECTOR3& outRayDir)`
- `CMyBitmap::GameCameraIsProject() -> int`
- `CMyBitmap::GetObliqueAngle() -> int`
- `CMyBitmap::PrepareModle()`

### `GraphicData.dll`

- `GameDataSetQuery`

### `Role3D.dll`

- `I3DRoleCreate`
- `Simple3DObjCreate`

### `GameData.dll`

- `RoleDataQuery`

### `KERNEL32.dll`

- `OutputDebugStringA`
- `GetVersionExA`
- `IsProcessorFeaturePresent`
- `MulDiv`

### `ADVAPI32.dll`

- `RegOpenKeyA`
- `RegQueryValueExA`
- `RegCloseKey`

### `MSVCRT.dll`

This DLL is built against MSVCRT and imports the expected C runtime surface (allocation, stdio, string routines, exception/runtime support).
The exact import list is intentionally not duplicated here unless needed for a specific behavior claim.

