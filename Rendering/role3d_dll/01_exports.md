# `Role3D.dll` — Exports

Export table (verified from `Role3D.dll` export directory):

| Ord | Address | Name |
|---:|---:|---|
| 1 | `0x10008700` | `Game3DEffectCreate` |
| 2 | `0x10007EC0` | `GetC3TechnicProcessorInstance` |
| 3 | `0x10004570` | `I3DRoleCreate` |
| 4 | `0x1000D660` | `LimitGame3DEffectLevel` |
| 5 | `0x10004590` | `LoadAdjustConfig` |
| 6 | `0x10007C00` | `Simple3DObjCreate` |
| 7 | `0x10007CC0` | `Simple3DObjCreate2` |
| 8 | `0x10007D90` | `Simple3DProcedureObjCreate` |
| 9 | `0x10004610` | `SyncObliqueAngle` |

## `I3DRoleCreate`

- Allocates `0x3C` bytes and constructs the object at `0x10001060`.
- Returns `NULL` on allocation failure.

## `Simple3DObjCreate`

- Allocates `0x54` bytes, constructs via `Simple3DObj_Ctor` (`0x100069E0`).
- If `a1 != 0`, calls vtable slot 1 (offset `+0x04`) with `a1` and returns `NULL` if that call fails.

## `Simple3DObjCreate2`

- Same allocation/construction as `Simple3DObjCreate`.
- Calls `Simple3DObjCreate2_InitPartInfoFromArgs(a1..a6)` (`0x10007450`); returns `NULL` if that fails (then invokes vtable cleanup at offset `+0x88` with arg `1`).

## `Simple3DProcedureObjCreate`

- Same allocation/construction as `Simple3DObjCreate`.
- Calls `Simple3DProcedureObjCreate_InitProcedureMeshFromArgs(a1..a5)` (`0x10007570`); returns `NULL` if that fails (then invokes vtable cleanup at offset `+0x88` with arg `1`).

## `LoadAdjustConfig` / `SyncObliqueAngle`

Both write four globals:

- `dword_10022D60`
- `dword_10022D64`
- `dword_10022D68`
- `dword_10022D6C`

`LoadAdjustConfig` tries to read them from a config file; on failure it sets all three oblique-angle fields from `CMyBitmap::GetObliqueAngle()` and zeros `dword_10022D6C`.

`SyncObliqueAngle` unconditionally sets the three oblique-angle fields from `CMyBitmap::GetObliqueAngle()` and zeros `dword_10022D6C`.
