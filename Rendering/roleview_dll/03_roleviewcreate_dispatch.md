# `RoleViewCreate` — Type Dispatch and Object Construction

This document describes how the exported factory `RoleViewCreate(int type)` selects and constructs different concrete RoleView object types inside `RoleView.dll`.

Source: decompile of `RoleViewCreate` (`0x100057E4`) in `RoleView.dll`.

## High-level behavior

- Input `type` is treated as a 1-based selector.
- `type` is decremented and range-checked for `type-1 <= 9`.
- A 10-entry jump table selects a per-type allocation size and constructor call.
- Allocation uses `operator new(size)` imported from `MSVCRT`.
- If allocation fails, the function returns `NULL`.

## Type jump table

The jump table begins at `0x100058D3` and contains 10 code pointers.

Mapping:

| `type` | Allocation size | Constructor | Notes |
|---:|---:|---:|---|
| 1 | `0xF8` | `RoleView_Type1_Ctor` (`0x10001000`) |  |
| 2 | `0x108` | `RoleView_Type2_Ctor` (`0x10003D8E`) |  |
| 3 | `0x60` | `RoleView_Type3_Ctor` (`0x10003EA9`) |  |
| 4 | `0x98` | `RoleView_Type4_Ctor` (`0x100042C5`) | vtable `0x10015334` |
| 5 | `0x244` | `RoleView_Type5_Ctor` (`0x100058FB`) | vtable `0x1001568C` |
| 6 | `0xA0` | `RoleView_Type6_Ctor` (`0x10004DC4`) | vtable `0x1001555C` |
| 7 | n/a | n/a | `RoleViewCreate` returns `NULL` |
| 8 | `0x100` | `RoleView_Type8_Ctor` (`0x10004E8D`) | vtable `0x100155D0` |
| 9 | `0x10` | `RoleView_Type9_Ctor` (`0x10005E0F`) | vtable `0x100156C0` |
| 10 | `0x100` | `RoleView_Type10_Ctor` (`0x10004B4D`) | vtable `0x100153A8` |

## Observed constructor pattern (type 5 example)

The type-5 constructor at `0x100058FB` shows the canonical object initialization pattern used by this DLL:

- writes the object’s vtable pointer at `[this+0]` (type 5 uses `0x1001568C`)
- zero-initializes multiple pointer/state fields
- sets a sentinel `-1` into `[this+0x08]`
- calls an internal routine at `0x10014B8E` with `(this+0x0C, 0, 0x24)` which appears to initialize an embedded fixed-size container.

The exact vtable layout and meanings of fields are documented as `RoleView.dll` internals are deobfuscated.
