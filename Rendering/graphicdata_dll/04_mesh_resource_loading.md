# `GraphicData.dll` — Mesh resource loading (`MeshCreate` path)

The `GraphicData.dll` path that constructs - or retrieves - a 3D mesh object through `graphic.dll`'s `MeshCreate(...)`.

## Entry point

`GraphicData_LoadMeshResource` (`0x10005960`) is a worker-style routine that:

- resolves a mesh path/name for a mesh ID,
- returns an already-loaded mesh object when present in cache,
- otherwise creates and initializes a new mesh object via `graphic.dll`.

This routine is part of the internal machinery behind `GameDataSet_RequestMesh(...)`.

## Observed behavior

When the mesh is not already loaded:

1. Calls `MeshCreate(meshPath)` (import from `graphic.dll`).
2. Calls `GraphicData_GetOrCreateMotion(meshPath, ...)` to obtain a "default motion" object for the mesh; if that fails, the mesh is released and the load fails.
3. Inserts the mesh into an internal string-keyed cache so subsequent requests return the existing mesh pointer.
4. Calls a virtual method on the mesh with the default motion object (mesh vtable slot used at index `14` in this context).
5. Iterates the mesh's sub-items and conditionally toggles per-sub-item flags using mesh virtual methods (mesh vtable slots used at indices `11`, `12`, and `28` in this context).

When the mesh is already loaded:

- increments a refcount on the cached entry,
- optionally returns an associated secondary pointer (stored alongside the mesh in the cache entry),
- calls a mesh virtual method at vtable offset `+0x38` with that associated pointer.

## Notes

`GraphicData.dll` treats the mesh object returned by `MeshCreate(...)` as a polymorphic object and uses it through its vtable. The concrete mesh object is `graphic.dll`'s `C3DObjX` (returned by `MeshCreate`), and its vtable layout and per-method semantics are documented in `analysis/conquer_docs/Rendering/graphic_dll/12_meshcreate_and_c3dobjx.md`.
