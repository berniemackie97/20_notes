# `Role3D.dll` — Overview

`Role3D.dll` provides the client’s 3D “role” and “simple 3D object” runtime objects.

Primary entry points:

- `I3DRoleCreate()` → creates the role/model driver object used by higher-level systems.
- `Simple3DObjCreate(...)` / `Simple3DObjCreate2(...)` / `Simple3DProcedureObjCreate(...)` → create simple 3D objects used for rendering and hit-testing.

`RoleView.dll` uses these objects via their vtables; parity requires reproducing their exact method semantics, including:

- model/part data lookup through `GraphicData.dll` (`GameDataSetQuery`) and config files,
- adjustment configuration loaded from `ini/role3d.ini` (see `LoadAdjustConfig()`),
- transforms/angles/oblique-angle synchronization (`CMyBitmap::GetObliqueAngle`),
- rendering state and camera-projection dependent behavior (`graphic.dll` / `CMyBitmap`).

## `ini/role3d.ini` (adjust configuration)

`LoadAdjustConfig()` (`0x10004590`) reads `ini/role3d.ini` as four integers:

```
<int> <int> <int> <int>
```

If the file cannot be opened or the four integers cannot be parsed, the first three values are set to `CMyBitmap::GetObliqueAngle()` and the fourth value is set to `0`.
