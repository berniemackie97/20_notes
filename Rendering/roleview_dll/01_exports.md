# `RoleView.dll` — Exports

This DLL exports a single factory function.

## Export table

- Export DLL name: `RoleView.dll`
- Ordinal base: `1`

| Ord | RVA | Name |
|---:|---:|---|
| 1 | `0x000057E4` | `RoleViewCreate` |

## `RoleViewCreate(int type)`

Signature (as imported by the EXE):

- `void* __cdecl RoleViewCreate(int type)`

Behavior (observed externally):

- Allocates/returns a pointer to a `RoleView` object whose first field is a vtable pointer.
- The returned object is configured and driven exclusively through vtable calls by `conquer.exe`.

The authoritative ABI for the returned object (vtable offsets, parameter shapes, and call sites) is documented in:

- `analysis/conquer_docs/Rendering/02_roleview_object_interface.md`

Internal implementation details (allocation classes, type dispatch, ownership model) must be derived by decompiling `RoleViewCreate` inside `RoleView.dll` and are documented separately as they are verified.
