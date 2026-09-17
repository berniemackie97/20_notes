# `GraphicData.dll` — Resource request semantics (`mesh` / `texture`)

`GraphicData.dll` exposes "resource request" style methods on the `GameDataSetQuery()` interface that are used by `Role3D.dll` to ensure required assets are available before a draw.

Externally observable behaviour for the specific call shapes `Role3D.dll` uses.

## `GameDataSet_RequestTexture(resourceId, mode, customTimeoutMs)`

Entry point:
- `GameDataSet_RequestTexture` (`0x100067A0`) (`IGameDataSet` vtable offset `+0x18`)

Observed `Role3D.dll` usage:
- `ds->GameDataSet_RequestTexture(textureId, 0, 0)` as a gating check inside `PartInfo_RenderAllParts`.
- `secondary = ds->GameDataSet_RequestTexture(secondaryId, 0, 0)` as a "secondary resource" provider in the effect render backends (see below).

Behavior (as exercised by the gating call above):

- If the requested texture is already present / available, returns a non-null pointer to a texture resource object.
- If the texture is not present / not yet available, allocates internal bookkeeping and enqueues a load job, and returns `0` immediately.

As a consequence:
- `Role3D.dll` treats a return value of `0` as "not ready" and aborts the current part-render loop iteration sequence.

### `immediate.ini` mode override in request path

Before queue/immediate branch selection, `GameDataSet_RequestTexture` applies:

1. if `force_immediate_load` (`byte [this+0x350]`) is set, mode becomes `1`,
2. if `GameDataSet_IsImmediateResourceId("texture", textureId)` is true, mode becomes `1`,
3. if original caller mode was `3`, final mode is forced to `0`.

This exactly matches the assembly sequence at `0x10006851` (immediate lookup) and `0x1000685B` (mode-3 special case).

Clarification:
- step (3) uses the original caller mode and applies even when the id is not in `immediate.ini`.

### Secondary texture usage (effects)

In the effect render backends (`Role3D.dll`):

- `secondary = ds->GameDataSet_RequestTexture(secondaryId, 0, 0)`
- If `secondary == 0`, the backend returns immediately.
- Otherwise, the backend calls `secondary->vfn_16()` (vtable offset `+0x10`) and returns immediately if it returns `0`.
- If the readiness check passes, the backend binds the secondary texture object into the primary draw resource object via `primary->SetSecondaryResource(secondary)` (primary vtable offset `+0x18`).

The minimal vtable surface proven for this returned texture object is documented in:

- `09_texture_resource_object.md`

### Internal implementation (deep trace)

`GameDataSet_RequestTexture` uses resource type 0 and the BST cache at `GameDataSet+0xDC`.

**Signature**: `GameDataSet_RequestTexture(this, textureResourceId, requestMode, customTimeoutMs)`

The third parameter (`customTimeoutMs`) controls per-entry cache eviction timeout. `Role3D.dll` always passes 0, which means "use global timeout" (30000 ms). On cache hit, the entry's custom timeout is updated to the caller's value (unless the entry is marked `NeverEvict`).

**Cache entry**: 16 bytes — `[key(4), resource(4), timestamp(4), customTimeout(4)]`.

**Cache hit path**:
1. Update `entry.timestamp` to `timeGetTime()`
2. Return `entry.resource` (may be null if async load still pending)
3. If `entry.customTimeout != NeverEvict`: set `entry.customTimeout = customTimeoutMs`

**Cache miss path**:
1. Apply mode overrides (see above)
2. `operator new(0x10)` — allocate 16-byte cache entry
3. Initialize: `key = textureResourceId, resource = 0, timestamp = timeGetTime(), customTimeout = max(customTimeoutMs, 0)`
4. BST insert into cache at `+0xDC` via `MapInsertOrFind_TextureCache` (0x100138E0)
5. `operator new(0x68)` — allocate 104-byte request object (type = 0, mode, resourceId)
6. Branch on mode:
   - **Immediate (mode=1)**: `primaryPool->SubmitRequest(req)` (via `*(gameDataSet+0x2E4)`)
     - If synchronous result: copy `req+0x14` to `entry.resource`, release request object
   - **Async (mode=0)**: enqueue request pointer to primary pool deque (`+0x2EC`, count `+0x318`)
7. Return `entry.resource` (0 on miss, since async load hasn't completed)

**Execute handler** (`ResourceExecute_LoadTexture` at 0x100075F0):
1. Resolve `textureResourceId` → path string via resource path tables at `+0x388`/`+0x38C`
   - Primary: `GameDataSet_GetTexturePathBST` (0x10005650), returns `*(this+0x388) + 0x14`
   - Fallback: `GameDataSet_GetTexturePathBSTFallback` (0x10005620), returns `*(this+0x38C) + 0x14`
   - Both access a compound resource path table object, offset +0x14 selects the texture sub-table
2. Look up path in texture registry BST at `+0x190` (under critical section `+0x250`)
   - Registry hit: increment refcount, return existing texture object
   - Registry miss: call `TextureCreate(pathString)` (import from `graphic.dll`, resolved via GetProcAddress)
3. Insert new texture into registry at `+0x190` and secondary registry at `+0x1F0`
4. Store returned texture object pointer in `req+0x14` (result0)

**Resource path tables**:
Both mesh and texture path resolvers use the same compound table objects at `+0x388` (primary) and `+0x38C` (fallback). Sub-offset `+0x04` selects the mesh BST, `+0x14` selects the texture BST.

## `GameDataSet_RequestMesh(resourceRecord, mode, customTimeoutMs)`

Entry point:
- `GameDataSet_RequestMesh` (`0x10005670`) (`IGameDataSet` vtable offset `+0x14`)

Observed `Role3D.dll` usage:
- `mesh = ds->GameDataSet_RequestMesh(record, 0, 0)` where `record` is obtained from a prior `GameDataSet_ResolveModelIdVariant` call.

Behavior (as exercised by the call above):

- If the requested mesh/model is already present in the internal cache, returns a non-zero pointer to the per-model runtime "mesh instance" object.
- If the mesh/model is not present, allocates internal bookkeeping and enqueues a load job, and returns `0` immediately.

### `immediate.ini` mode override in request path

Before queue/immediate branch selection, `GameDataSet_RequestMesh` applies:

1. if `force_immediate_load` (`byte [this+0x350]`) is set, mode becomes `1`,
2. if `GameDataSet_IsImmediateResourceId("mesh", meshResourceId)` is true, mode becomes `1`,
3. if original caller mode was `3`, final mode is forced to `0`.

This matches the assembly sequence at `0x10005710` (immediate lookup) and `0x10005721` (mode-3 special case).

Clarification:
- step (3) uses the original caller mode and applies even when the id is not in `immediate.ini`.

The returned "mesh instance" pointer is the object that `Role3D.dll` later calls through its own expected per-part vtable (render, hit-test, param setting).

### Internal implementation (deep trace)

`GameDataSet_RequestMesh` uses resource type 2 and the BST cache at `GameDataSet+0xCC`.

**Cache entry**: 20 bytes — `[key(4), primaryResource(4), secondaryResource(4), timestamp(4), customTimeout(4)]`.

**Execute handler** (`ResourceExecute_LoadMesh` at 0x10005960):
1. Resolve `meshResourceId` → path string via resource path tables at `+0x388`/`+0x38C`
   - Primary: `GameDataSet_GetMeshPathBST` (0x10005630), returns `*(this+0x388) + 0x04`
   - Fallback: `GameDataSet_GetMeshPathBSTFallback` (0x10005600), returns `*(this+0x38C) + 0x04`
2. Calls `MeshCreate(pathString)` (import from `graphic.dll`)
3. Creates default motion via `GameDataSet_ResolveMotion` (`0x100072C0`)
4. Stores results in `req+0x1C` (primary mesh pointer) and `req+0x20` (default motion pointer)

**Immediate finalize**: copies `req+0x1C` → `entry.primaryResource`, `req+0x20` → `entry.secondaryResource`.
