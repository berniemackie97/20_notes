# GraphicData.dll — CDataThreadObj (resource request) & Finalize-to-Cache Dispatch

Class name and member names recovered from the TQ C3 studio build of `GraphicData.dll`
(`40_tools/C3Tools/GraphicData.dll`, 28 mangled exports vs 2 in the shipped client). Every
offset below is re-verified in the 5517 client binary.

Original source path, from an assert string in the client: `F:\Projects\C3Engine_Official\GraphicData\GameDataSet.cpp`.

`CDataThreadObj` is the request object handed to `DataThread.dll`. `GameDataSet_Initialize`
creates two `IDataThread` pools (primary `+0x2E4`, secondary `+0x2E8`); requests go to a pool
asynchronously, or run on the calling thread when exigence is 1.

Build difference vs the studio DLL — do not carry these into 5517:
- studio vftable has 5 slots (adds `LoadFinish`); 5517 has 4 and finalizes in
  `GameDataSet_FinalizeLoadedResource`.
- studio `DataThreadCreateNew` is `(unsigned long, unsigned long)`; 5517's takes no arguments.

## Layout (0x68 = 104 bytes)

| Offset | Size | Member | Accessor | Notes |
|--------|------|--------|----------|-------|
| +0x00 | 4 | vftable | — | → `CDataThreadObj__vftable` (0x10030338) |
| +0x04 | 16 | index string | `GetIndex()` | MSVC `std::string`; char* at +0x08, null → `""` |
| +0x14 | 4 | texture result | `QueryTexture()` | `C3DTexture*`, type 0 |
| +0x18 | 4 | effect result | `QueryEffect()` | `C3DEffect*`, type 1 |
| +0x1C | 4 | motion result | `QueryMotion()` | `C3DMotion*`, type 2 out-param **and** type 3 result |
| +0x20 | 4 | mesh result | `QueryMesh()` | `C3DObj*`, type 2 return value |
| +0x24 | 4 | scene result | `QueryScene()` | `C3DScene*`, type 5 |
| +0x28 | 4 | ani result | `QueryAni()` | `CAni*`, type 4 |
| +0x2C | 4 | exigence | `GetExigence()` | 0 = queue on worker, 1 = load on calling thread; caller value 3 is forced to 0 |
| +0x30 | 4 | type | `GetType()` | 0–5 discriminant for `Load` and finalize |
| +0x34 | 4 | — | — | unused |
| +0x38 | 8 | id | `GetID()` | one `__int64`, returned edx:eax; low +0x38, high +0x3C |
| +0x40 | 16 | string1 | — | `std::string`; char* at +0x44; type 4 arg 1 |
| +0x50 | 16 | string2 | — | `std::string`; char* at +0x54; type 4 arg 2 |
| +0x60 | 1 | forceReload | `IsForceReload()` / `SetForceReload()` | **input**, read by `Load`, passed to the loaders |
| +0x61 | 1 | changeAsset | `IsChangeAsset()` / `SetChangeAsset()` | **input**, read by finalize to decide whether to release the resource already in the cache slot |
| +0x62 | 6 | — | — | padding |

Corrections to the earlier reading of this file, both proven in `CDataThreadObj__Load`
(0x10009E40) and `GameDataSet_FinalizeLoadedResource` (0x10003F50):
- +0x1C and +0x20 were swapped. `ResourceExecute_LoadMesh` **returns** the mesh (stored to
  +0x20) and writes the motion through the out-pointer `this+0x1C`.
- +0x60 is not a failure flag and is never written by `Load`. A failed load leaves the result
  field null. +0x60/+0x61 are both inputs set at request creation.

Result fields are zeroed at allocation. Destructor `CDataThreadObj__destructor` (0x1000A070)
restores the vftable pointer and tears down the three strings (+0x04, +0x40, +0x50).

## vftable (`CDataThreadObj__vftable` @ 0x10030338)

Slot order matches the studio build's `??_7CDataThreadObj@@6B@` (0x100321d8) exactly.

| Slot | Address | Name | Signature |
|------|---------|------|-----------|
| +0x00 | 0x1000A140 | `CDataThreadObj::GetID` | `__int64 (void)` — from +0x38/+0x3C |
| +0x04 | 0x10009E40 | `CDataThreadObj::Load` | `void (void)` — worker-side type switch |
| +0x08 | 0x1000A110 | `CDataThreadObj::GetExigence` | `unsigned long (void)` — returns +0x2C |
| +0x0C | 0x1000A120 | `CDataThreadObj::DataThreadRelease` | `void (void)` — destructor + `operator delete` |

### `Load` type switch (0x10009E40)

The worker calls type-specific loader functions based on `this+0x30`:

| Type | Loader Address | Name | Description | Result Field(s) |
|------|---------------|------|-------------|-----------------|
| 0 | 0x100075F0 | `ResourceExecute_LoadTexture` | Resolves id→path via `+0x388`/`+0x38C` tables, looks up texture registry at `+0x190`, calls `TextureCreate(path)` on miss | +0x14 |
| 1 | vtable+0x2C | (virtual call) | Effect resource loader via GameDataSet virtual method | +0x18 |
| 2 | 0x10005960 | `ResourceExecute_LoadMesh` | Resolves id→path, calls `MeshCreate(path)`, creates default motion | +0x20 mesh (return), +0x1C motion (out-param) |
| 3 | 0x10007090 | `ResourceExecute_LoadStringKeyed` | String-keyed resource loader (uses resourceId, secondaryId, and string key at +0x08) | +0x1C |
| 4 | `GameDataSet_CreateAniResource` | — | Animation/map loader (uses string1 at +0x44 and string2 at +0x54) | +0x28 |
| 5 | 0x10005F80 | `ResourceExecute_LoadScene3D` | 3D scene resource loader | +0x24 |

A failed load leaves the type's result field null; no flag is written.

### Verified `ResourceExecute_LoadStringKeyed` lookup semantics (`0x10007090`)

- resolves the part config by string key (`"body"`, etc.)
- reads the preloaded dual-key motion table for that part config
- probes the table by exact compound-key match through `MapFind_CompoundKey64(...)`
- forwards the matched resource path to `GameDataSet_ResolveMotion(path, 1, ...)`
- does **not** rewrite or normalize the requested low/high key pair during this request-time path

This matters for standard type-4/simple-object NPCs in 5517: real runtime assets store some
`Npc.ini` 10-digit motion ids in `c3.wdb:ini/3dmotion.dbc` under the stripped fallback form
(for example `Guide` rest `9990070101` -> motion DB key `999007101/0`), so any normalization
must occur before the `RoleView` / string-keyed request path reaches this exact-match loader.

## Request Lifecycle

```
1. CREATE  — GameDataSet_Request{Mesh,Texture,...}
   ├─ Check isWithinLoadingBudget (+0x350): if true, force immediate mode
   ├─ BST cache lookup at type-specific cache offset
   ├─ If cache hit: return cached resource pointer
   └─ If cache miss:
       ├─ Allocate cache entry (16 bytes for type 0 texture, 20 bytes for type 2 mesh), insert into BST
       ├─ Allocate 104-byte request object (type, mode, ids)
       └─ Branch on mode:

2. SUBMIT
   ├─ Immediate (mode=1): pool->SubmitRequest(req)
   │   └─ If synchronous result: FinalizeLoadedResource immediately
   └─ Async (mode=0): enqueue to pending request deque
       ├─ Primary pool deque: GameDataSet+0x2EC..+0x30C
       └─ Secondary pool deque: GameDataSet+0x320..+0x33C

3. PUMP (per-frame, GameDataSet_PumpPerFrameResources)
   ├─ ProcessPendingResourceRequests: dequeue pending → pool->SubmitRequest
   ├─ DrainCompletedResources: pool->DequeueCompleted → FinalizeLoadedResource
   └─ RunTimeGatedCleanup: evict expired cache entries (every 30s)

4. EXECUTE (worker thread, DataThread_WorkerThreadProc)
   ├─ req->Execute() — type-specific loader
   ├─ Populates result field(s) in request object
   └─ Enqueues to completed queue

5. FINALIZE (consumer thread, GameDataSet_FinalizeLoadedResource @ 0x10003F50)
   ├─ Switch on request+0x30 (resourceType, 6 cases)
   ├─ Extract result from type-specific field
   └─ Insert into type-specific BST cache
```

## FinalizeLoadedResource Cache Dispatch (0x10003F50)

Switches on `request+0x30` (resourceType). Each case extracts the result pointer from the request's type-specific field and inserts it into the corresponding BST cache at the given `GameDataSet` offset.

| Type | Cache Offset | Resource Field(s) | Category |
|------|-------------|-------------------|----------|
| 0 | +0xDC | +0x14 | Texture |
| 1 | +0xEC | +0x18 | Effect |
| 2 | +0xCC | +0x20 → entry+0x04, +0x1C → entry+0x08 | Mesh + its default motion |
| 3 | +0xBC | +0x1C → entry+0x08 (string key at +0x08) | String-keyed motion |
| 4 | +0x10C | +0x28 | Animation/map |
| 5 | +0xFC | +0x24 | 3D scene |

Cache eviction functions run in the time-gated cleanup phase (see `02_igamedataset_vtable.md`). The eviction order matches the type numbering but is called in native order: 4, 3, 2, 0, 1, 5.

## Pending Request Deques (GameDataSet Object Layout)

Each pool has a deque for pending requests (async mode) and a count field:

| Pool | Deque Offset | Count Offset | Description |
|------|-------------|-------------|-------------|
| Primary | +0x2EC..+0x30C | +0x318 | Primary pool pending requests |
| Secondary | +0x320..+0x33C | +0x348 | Secondary pool pending requests |

Deque entries are pointers to 104-byte request objects. `ProcessPendingResourceRequests` iterates these deques, submitting each to the corresponding pool via `pool->SubmitRequest(requestId)`.

## Mode Override Logic

Before branching on mode, each `GameDataSet_Request*` function applies three overrides in order:

1. If `isWithinLoadingBudget` (`GameDataSet+0x350`) is set → force mode to `1` (immediate)
2. If `GameDataSet_IsImmediateResourceId(typeName, resourceId)` returns true → force mode to `1`
3. If original caller mode was `3` → force mode to `0` (async), regardless of steps 1–2

See `03_resource_request_semantics.md` and `16_immediate_ini_semantics.md` for full override documentation.

## BNinja Renames Applied

| Address | Name |
|---------|------|
| 0x10030338 | `CDataThreadObj__vftable` |
| 0x1000A140 | `CDataThreadObj__GetID` |
| 0x10009E40 | `CDataThreadObj__Load` |
| 0x1000A110 | `CDataThreadObj__GetExigence` |
| 0x1000A120 | `CDataThreadObj__DataThreadRelease` |
| 0x1000A070 | `CDataThreadObj__destructor` |
| 0x100075F0 | `ResourceExecute_LoadTexture` |
| 0x10005960 | `ResourceExecute_LoadMesh` |
| 0x10007090 | `ResourceExecute_LoadStringKeyed` |
| 0x10005F80 | `ResourceExecute_LoadScene3D` |

Superseded names (do not reuse): `g_ResourceRequest_Vtbl`, `ResourceRequest_GetId`,
`ResourceRequest_Execute`, `ResourceRequest_GetRequestMode`, `ResourceRequest_Release`.
