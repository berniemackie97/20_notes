# `Role3D.dll` — Imports / External Dependencies

`Role3D.dll` imports from:

- `KERNEL32.dll` (heap + interlocked primitives, debug output)
- `ADVAPI32.dll` (registry reads)
- `WINMM.dll` (`timeGetTime`)
- `MSVCRT.dll` / `MSVCP60.dll` (CRT + `std::string`)
- `GraphicData.dll` (`GameDataSetQuery`)
- `graphic.dll` (render/camera/matrix helpers and 3D support glue)

Notable imported `graphic.dll` symbols used by Role3D:

- `CMyBitmap::QueryDevice() -> IDirect3DDevice8*`
- `CMyBitmap::GetObliqueAngle() -> int`
- `CMyBitmap::PrepareModle()`
- `CMyBitmap::Common_Scale/Rotate/Translate(D3DXMATRIX*, ...)`
- `CMyBitmap::ProbeRayBuild(...)`
- `CMyBitmap::GameCameraIsProject() -> int`
- `CMyBitmap::Motion_GetMatrix_Blend(...)`
- `GetC3Camera`, `GetResLimitInterface`, `GetCurrentFPS`
- `BeginProjectiveShadowMap`, `EndProjectiveShadowMap`, `ClearBuffer`
- `DestroyShapeInfo`, `DestroyPtclInfo`, `DestroyPtcl3Info`
