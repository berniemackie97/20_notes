# `GraphicData.dll` — Motion cache and "default motion" creation

`GraphicData.dll` is responsible for creating (and caching) the motion container objects that are bound to meshes during mesh load.

The mesh loader (`GraphicData_LoadMeshResource`) treats motion creation as mandatory: if the default motion cannot be created, mesh creation is treated as a failure.

## Entry point

`GraphicData_GetOrCreateMotion` (`0x100072C0`) returns a motion object for a given mesh path/name.

The stock caller is `GraphicData_LoadMeshResource`:

- `motion = GraphicData_GetOrCreateMotion(meshPath, 0, 0, 0, flag, lpCriticalSection)`
- If `motion == 0`, it logs `C3 default motion [%s] create error.` and releases the mesh.

## Behavior (cache + create)

`GraphicData_GetOrCreateMotion` implements a string-keyed cache guarded by a critical section located at `this + 616` inside the `GameDataSetQuery()` singleton object.

Given `meshPath`:

1. If caching is enabled for the call:
   - Looks up `meshPath` in an internal map.
   - If a cached motion exists:
     - If the call requests "rebind/update": invokes a motion virtual method at vtable index `8` with the `meshPath` string.
     - Otherwise increments a refcount on the cache entry.
     - Returns the cached motion pointer.
2. If no cached motion exists (or caching is disabled for the call):
   - Calls `graphic.dll!MotionCreate(meshPath, ...)`.
   - If creation fails, logs `3DMotion [%s] create error.` and returns `0`.
3. When caching is enabled and the key does not already exist in the map:
   - Inserts a new cache entry for `meshPath` storing:
     - the returned motion pointer,
     - a refcount initialized to `1`,
     - and additional bookkeeping used by other subsystems.

## Relationship to `graphic.dll`

The motion object constructed by `GraphicData.dll` is a `graphic.dll` motion container returned by `MotionCreate(...)` (the concrete type is documented as `C3MotionTracker` in `analysis/conquer_docs/Rendering/graphic_dll/13_motioncreate_and_c3motiontracker.md`).
