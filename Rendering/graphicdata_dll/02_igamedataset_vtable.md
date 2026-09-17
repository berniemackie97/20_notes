# `GraphicData.dll` — `IGameDataSet` vtable (as used by `Role3D.dll`)

`Role3D.dll` calls `GraphicData.dll` through the interface pointer returned by `GameDataSetQuery()`.

`GameDataSetQuery()` returns a `GameDataSet` object that implements multiple interfaces. `Role3D.dll` calls through the **base interface vtable** stored at `*(void**)ds`:

- base vtable: `g_IGameDataSet_BaseVtbl` (`0x10030190`)

This document names and describes the vtable methods that are *directly exercised* by the rendering stack (`Role3D.dll`) and the main frame loop (`Conquer.exe`).

## `GameDataSet_Initialize` (vtable offset `+0x00`)

Vtable offset: `+0x00` (index `0`) → `GameDataSet_Initialize` (`0x10003190`).

Called from `ConquerApp_InitInstance` (Conquer.exe `0x5AA87C`): `(**GameDataSetQuery(0))()`.

### Initialization sequence

1. **Per-cache fallback timeouts** (`+0x178..+0x188`): all set to `0x7530` (30000 ms = 30 seconds)
2. **Cleanup interval threshold** (`+0x2E0`): set to `0x7530` (30000 ms = 30 seconds)
3. **DB packing mutex**: `CreateEventA("#C3_GAME_DB_PACKING#")` → mutual exclusion for `GameDbPack_LoadAndUpdateC3Wdb`; on failure logs "Game DB Pack Update Failed!" and returns early
4. **Package system**: `GraphicData_OpenPackagesFromPackageIni()` → opens WDF/data archives
5. **INI tuning**: `GameDataSet_LoadCommonIniTuning` → loads `ini/common.ini` params
6. **Resource limit interface**: `SetResLimitInterface(&this+0x08)` → registers third vtable interface
7. **Resource limit databases**: `GameDataSet_LoadResLimitDatabases`
8. **Core RSDB databases**: `GameDataSet_LoadCoreRsdbDatabases(this, nullptr, "ini/3dobj.dbc", "ini/3deffectobj.dbc")` with `"ini/3dtexture.dbc"` on stack
9. **LOD level**: `GameDataSet_SetResLodLevel` after setting `+0x384 = 0xFFFFFFFF`
10. **RSDB single-key indices**: `"ini/3dscene.dbc"` → `+0x120`, `"ini/sound.dbc"` → `+0x140`, `"ini/3DObjProp.dbc"` → `+0x3D8`
11. **Additional databases**: materials, simple objects, effects, emotion icons, role parts, action transitions, immediate ini, mesh LOD, buffer motion
12. **Initialization timestamp** (`+0x11C`): `timeGetTime()`
13. **Resource pools** (`+0x2E4` / `+0x2E8`): two `IDataThread` objects created via `DataThreadCreateNew()` (imported from `DataThread.dll`), each started via `vtable+0x04(0)`
14. **Loading budget**: `vtable+0x70(0x3E8)` → `GameDataSet_SetLoadingBudgetDeadline(1000)` = initial 1-second budget
15. Logs: `"CGameDataSetX::Init took %d ms"`

### Key finding: resource pool type

The pools at `+0x2E4` and `+0x2E8` are **`IDataThread`** COM-like objects created by `DataThreadCreateNew()` (exported from `DataThread.dll`, mangled: `?DataThreadCreateNew@@YAPAVIDataThread@@XZ`). The same `IDataThread` vtable exposes the 4 pool methods used by the per-frame pump (vtable `+0x0C`/`+0x10`/`+0x14`/`+0x18`).

## `GameDataSet_Shutdown` (vtable offset `+0x08`)

Vtable offset: `+0x08` (index `2`) → `GameDataSet_Shutdown` (`0x100033F0`).

Shutdown sequence:
1. Calls 8 internal shutdown sub-functions
2. Drains both pending request deques (destroys all pending request objects)
3. Destroys primary pool: `pool->vtable[0]()` then sets `+0x2E4 = 0`
4. Destroys secondary pool: `pool->vtable[0]()` then sets `+0x2E8 = 0`
5. `TqPackagesClose(nullptr)` — closes all package archives
6. Frees a dynamic array at `+0x3CC..+0x3D0`
7. `CMyBitmap::Quit3D()`
8. Logs: `"C3 Quit Successfully"`

## `GameDataSet_IsInitialized` (vtable offset `+0x98`)

Vtable offset: `+0x98` (index `38`) → `GameDataSet_IsInitialized` (`0x10009FE0`).

Returns `1` if both pools (`+0x2E4` and `+0x2E8`) are non-null, otherwise `0`. Called from `ConquerApp_InitInstance` (`0x5AA8A3`) as the init success gate.

## `GameDataSet_SetLoadingBudgetDeadline` (vtable offset `+0x70`)

Vtable offset: `+0x70` (index `28`) → `GameDataSet_SetLoadingBudgetDeadline` (`0x10009DF0`).

Sets `+0x350 = 1` (within budget) and `+0x34C = timeGetTime() + arg` (deadline tick). Called during Initialize with `0x3E8` (1000 ms). Called from the pump to refresh the budget window.

## `GameDataSet_PumpPerFrameResources` (vtable offset `+0x0C`)

Vtable offset: `+0x0C` (index `3`) → `GameDataSet_PumpPerFrameResources` (`0x10003A00`).

Called once per frame by `CMyShellDlg_TickMapRoleAndEffectPipeline` (Conquer.exe `0x5AFEB3`) AFTER `CMyShellDlg_RunFrameTick` completes. This is the per-frame resource management pump.

### Prerequisites

Returns immediately if either resource pool pointer is null:
- `this+0x2E4` — primary resource pool (mesh/texture cache)
- `this+0x2E8` — secondary resource pool (effect/sound cache)

### Always-run phase

| Order | Callee | Address | Behavior |
|---:|---|---:|---|
| 1 | `GameDataSet_UpdateLoadingBudgetFlag` | `0x10009E10` | Compares `timeGetTime()` against deadline at `this+0x34C`; sets `this+0x350` to 0 (expired) or 1 (within budget) |
| 2 | `GameDataSet_ProcessPendingResourceRequests(this, 0)` | `0x10003AC0` | Iterates pending request deques at `this+0x2EC..0x30C` and `this+0x320..0x33C`; calls pool vtable `+0x10` per request ID; calls `GameDataSet_FinalizeLoadedResource` for each non-null result |
| 3 | `GameDataSet_DrainCompletedResources(this, 0)` | `0x10003EF0` | Checks pool vtable `+0x18` (has-completed), loops vtable `+0x0C` (dequeue) until empty; calls `GameDataSet_FinalizeLoadedResource` for each |

### Time-gated cleanup phase

On first call: initializes `g_resourcePumpTimerInitialized` (`0x10035120`) and stores `timeGetTime()` to `g_resourcePumpLastCleanupTick` (`0x10035124`).

Cleanup guard:
1. Check `pool1->vtable+0x14()` returns non-zero (pool 1 ready)
2. Check `pool2->vtable+0x14()` returns non-zero (pool 2 ready)
3. Check `timeGetTime() - g_resourcePumpLastCleanupTick > this+0x2E0` (cleanup interval threshold)

When all three pass, resets `g_resourcePumpLastCleanupTick` and runs 6 cleanup functions in order:

| Order | Callee | Address | Cache offset | FinalizeLoadedResource case | Behavior |
|---:|---|---:|---:|---:|---|
| 1 | `GameDataSet_EvictExpiredResourceCache4` | `0x10007DB0` | `+0x10C` | 4 | Iterates BST, evicts entries where `timeGetTime() > entry.timestamp + entry.timeout`; skips permanent (`0xFFFFFFFF`) |
| 2 | `GameDataSet_ProcessResourceCache3` | `0x10008220` | `+0xBC` | 3 | Iterates BST, calls processing callback per entry (does NOT evict) |
| 3 | `GameDataSet_EvictExpiredResourceCache2` | `0x10007F10` | `+0xCC` | 2 | Iterates BST, dual-timeout eviction: per-entry timeout at `entry+0x10` or fallback `this+0x178` |
| 4 | `GameDataSet_EvictExpiredResourceCache0` | `0x10008280` | `+0xDC` | 0 | Iterates BST, dual-timeout eviction: per-entry timeout at `entry+0xC` or fallback `this+0x180` |
| 5 | `GameDataSet_EvictExpiredEffectCache` | `0x10008410` | `+0xEC` | 1 | Iterates BST, dual-timeout eviction: per-entry timeout at `entry+0xC` or fallback `this+0x184` |
| 6 | `GameDataSet_EvictExpiredScene3DCache` | `0x100085A0` | `+0xFC` | 5 | Iterates BST, dual-timeout eviction: per-entry timeout at `entry+0xC` or fallback `this+0x188` |

All eviction functions share the same pattern: iterate a resource cache BST, check per-entry expiry against `timeGetTime()`, release + remove expired entries. Function #2 is the exception — it processes entries rather than evicting them.

### Resource pool vtable interface

Both primary (`this+0x2E4`) and secondary (`this+0x2E8`) pools are accessed through the same vtable-driven interface. The pump calls these 4 methods:

| Vtable offset | Signature | Called from | Semantics |
|---:|---|---|---|
| `+0x0C` | `int DequeueCompleted()` | `DrainCompletedResources` | Returns loaded resource ptr; 0 = empty |
| `+0x10` | `int SubmitRequest(int requestId)` | `ProcessPendingResourceRequests` | Returns resource ptr if immediately loaded; 0 = pending |
| `+0x14` | `int IsReady()` | `ProcessPendingResourceRequests`, `PumpPerFrameResources` (cleanup guard) | Non-zero = pool ready to accept requests |
| `+0x18` | `int HasCompleted()` | `DrainCompletedResources` | Non-zero = pool has completed items to drain |

Evidence: verified from decompiled `GameDataSet_ProcessPendingResourceRequests` (`0x10003AC0`) and `GameDataSet_DrainCompletedResources` (`0x10003EF0`). Both pools use identical vtable call patterns.

### Key GameDataSet fields (this slice)

| Offset | Type | Name | Evidence |
|---:|---|---|---|
| `+0x2E0` | uint32 | cleanupIntervalThresholdMs | compared against elapsed time at `0x10003A88` |
| `+0x2E4` | IDataThread* | primaryResourcePool | Created by `DataThreadCreateNew()` in Initialize; null-guarded at `0x10003A04` |
| `+0x2E8` | IDataThread* | secondaryResourcePool | Created by `DataThreadCreateNew()` in Initialize; null-guarded at `0x10003A12` |
| `+0x2EC..0x30C` | deque | primaryPendingRequestDeque | iterated in `GameDataSet_ProcessPendingResourceRequests` |
| `+0x320..0x33C` | deque | secondaryPendingRequestDeque | iterated in `GameDataSet_ProcessPendingResourceRequests` |
| `+0x34C` | uint32 | loadingBudgetDeadlineTick | compared with `timeGetTime()` in `GameDataSet_UpdateLoadingBudgetFlag` |
| `+0x350` | byte | loadingBudgetExpiredFlag | 0 = expired, 1 = within budget |
| `+0x11C` | uint32 | initTimestamp | `timeGetTime()` captured at end of Initialize |
| `+0x178` | uint32 | cacheEvictionFallbackTimeout_Type2 | default 30000 ms; used by `EvictExpiredResourceCache2` |
| `+0x180` | uint32 | cacheEvictionFallbackTimeout_Type0 | default 30000 ms; used by `EvictExpiredResourceCache0` |
| `+0x184` | uint32 | cacheEvictionFallbackTimeout_Type1 | default 30000 ms; used by `EvictExpiredEffectCache` |
| `+0x188` | uint32 | cacheEvictionFallbackTimeout_Scene3D | default 30000 ms; used by `GameDataSet_EvictExpiredScene3DCache` |
| `+0x18C` | uint32 | (cleared to 0 in Initialize) | unknown purpose |
| `+0x384` | int32 | (set to 0xFFFFFFFF in Initialize) | used by `SetResLodLevel` |

### BNinja renames applied in this slice (`GraphicData.dll.bndb`)

| Address | Verified name |
|---:|---|
| `0x10003A00` | `GameDataSet_PumpPerFrameResources` |
| `0x10009E10` | `GameDataSet_UpdateLoadingBudgetFlag` |
| `0x10003AC0` | `GameDataSet_ProcessPendingResourceRequests` |
| `0x10003EF0` | `GameDataSet_DrainCompletedResources` |
| `0x10003F50` | `GameDataSet_FinalizeLoadedResource` |
| `0x10035120` | `g_resourcePumpTimerInitialized` (data) |
| `0x10035124` | `g_resourcePumpLastCleanupTick` (data) |
| `0x10007DB0` | `GameDataSet_EvictExpiredResourceCache4` |
| `0x10008220` | `GameDataSet_ProcessResourceCache3` |
| `0x10007F10` | `GameDataSet_EvictExpiredResourceCache2` |
| `0x10008280` | `GameDataSet_EvictExpiredResourceCache0` |
| `0x10008410` | `GameDataSet_EvictExpiredEffectCache` |
| `0x100085A0` | `GameDataSet_EvictExpiredScene3DCache` |
| `0x10003190` | `GameDataSet_Initialize` |
| `0x100033F0` | `GameDataSet_Shutdown` |
| `0x10009DF0` | `GameDataSet_SetLoadingBudgetDeadline` |
| `0x10009FE0` | `GameDataSet_IsInitialized` |

## `GameDataSet_RequestMesh` (vtable offset `+0x14`)

Vtable offset: `+0x14` (index `5`) → `GameDataSet_RequestMesh` (`0x10005670`).

`Role3D.dll` uses this method to obtain (or schedule/ensure) a runtime per-model "mesh instance" object for a given model record.

In the `Role3D.dll` part-resolution path:

1. `record = ds->GameDataSet_ResolveModelIdVariant(modelId, variantSelector)`
2. `mesh = ds->GameDataSet_RequestMesh(record, 0, 0)`

The returned pointer is stored by `Role3D.dll` in its per-part record and is treated as a polymorphic "mesh instance" object (see `analysis/conquer_docs/Rendering/role3d_dll/05_partinfo_and_mesh_instances.md`).

## `GameDataSet_RequestTexture` (vtable offset `+0x18`)

Vtable offset: `+0x18` (index `6`) → `GameDataSet_RequestTexture` (`0x100067A0`).

`Role3D.dll` calls this method as a gating check before rendering a part. The return value is used as a boolean-style "available" result (non-zero means the part proceeds to render; zero aborts the loop).

## `GameDataSet_ResolveModelIdVariant` (base vtable offset `+0x74`)

`GameDataSet_ResolveModelIdVariant` is invoked via a secondary base-interface vtable (`g_IGameDataSet_BaseVtbl` at `0x10030190`).

Vtable offset: `+0x74` (index `29` within `g_IGameDataSet_BaseVtbl`) → `GameDataSet_ResolveModelIdVariant` (`0x1001DA50`).

Signature (as decompiled):

- inputs:
  - `modelId` (unsigned integer)
  - `variantSelector` (integer; observed values `0`, `1`, `2`)
- output:
  - a (possibly remapped) model ID

Behavior:

- Looks up `modelId` in the internal MeshLod map at `this + 0x374`.
- The MeshLod map is populated by `GameDataSet_LoadMeshLodIni` from `ini/MeshLod.ini`.
- If no mapping exists, returns the input `modelId`.
- If a mapping exists:
  - `variantSelector == 1` returns the map entry value at node `+0x14`
  - `variantSelector == 2` returns the map entry value at node `+0x18`
  - otherwise returns the map entry value at node `+0x10`

Verified lookup flow in `GraphicData.dll`:

1. `MeshLodModelVariantMap_FindLowerBoundByModelId(this + 0x374, &modelId)`
2. exact-key gate (`lower_bound != end` and `modelId >= node_key`)
3. selector-based return of one of three stored model ids

`Role3D.dll` passes a `variantSelector` owned by its `PartInfo` instance (stored at `this[61]` inside Role3D's `PartInfo` layout).

## `GameDataSet_RequestEffectDrawResource` (vtable offset `+0x1C`)

Vtable offset: `+0x1C` (index `7`) → `GameDataSet_RequestEffectDrawResource` (`0x10006A90`).

`Role3D.dll` uses this method in the effect render backends to obtain the draw resource object for a given effect part record:

- `res = ds->GameDataSet_RequestEffectDrawResource(resourceId, 0, 0)`

The returned object's vtable-driven interface (the methods `Role3D.dll` calls on it) is documented in:

- `analysis/conquer_docs/Rendering/role3d_dll/10_effect_draw_resource_interface.md`

## `GameDataSet_FindEffectTemplateByName` (vtable offset `+0x48`)

Vtable offset: `+0x48` (index `18`) -> `GameDataSet_FindEffectTemplateByName` (`0x1001C5A0`).

Role3D caller linkage:

- `Role3D.dll!PartInfo_CreateAndAppendEffectInstanceByName` (`0x1000AC40`) calls
  `(*(*GameDataSetQuery()) + 0x48)(effectName)` to resolve the effect template pointer used for instance construction.

Behavior:

1. builds a temporary `std::string` from input `effectName`
2. lower-bound lookup in the `this + 0x2C` effect-template RB-tree
3. exact-key check against node key
4. returns node payload pointer at `node + 0x1C` on hit, otherwise `0`

Companion slot:

- vtable `+0x4C` points to `GameDataSet_FindEffectTemplateByNameAlt` (`0x1001C490`), an alternate lookup variant that resolves the same payload pointer shape (`node + 0x1C`).

## `GameDataSet_FindSoundResourcePathById` (base vtable offset `+0x30`)

Vtable offset: `+0x30` (index `12`) -> `GameDataSet_FindSoundResourcePathById` (`0x1001DAD0`).

Signature (decompiled and renamed):

- inputs:
  - `soundId : u32`
- output:
  - `const char*` sound resource path on exact hit, otherwise `0`

Verified internal flow:

1. Uses the single-key sound index rooted at `this + 0x140`.
2. Builds a composite lookup key `{ primary = soundId, secondary = 0 }`.
3. Calls `DualKeyEntryMap_FindLowerBoundBySecondaryPrimaryKey` for lower-bound lookup.
4. Applies exact-match gating and returns node field `+0x18` (path pointer) on hit.

Initialization linkage:

- `GameDataSet_Initialize` loads `ini/sound.dbc` via `GameDataSet_LoadRsdbSingleKeyIndex(gameDataSet, "ini/sound.dbc", gameDataSet + 0x140)`.
- The third argument points to byte offset `+0x140`, matching this lookup method.

Verified runtime caller linkage:

- `Conquer.exe` `CMsgAction__Process` (`0x6FED1F`) subtype `0x7C` calls this slot at `0x6FFED4`/`0x6FFEF4`.
- The returned path is passed into `_DXPlaySound@24` at `0x7001D4` with defaults `(0, 0, 0, 0, 100)`.

## `GameDataSet_FindRolePartMotionResourcePath` (base vtable offset `+0x38`)

Vtable offset: `+0x38` (index `14`) -> `GameDataSet_FindRolePartMotionResourcePath` (`0x1001D8F0`).

Signature (decompiled and renamed):

- inputs:
  - `partName : const char*`
  - `primaryKey : u32`
  - `secondaryKey : u32`
- output:
  - `const char*` motion resource path on exact hit, otherwise `0`

Verified internal flow:

1. `GameDataSet_FindRolePartConfigEntryValueByPartName(partName)` finds the role-part config value.
2. Reads `motion_db_path` from that config value.
3. Finds loaded motion table by path using `RolePartMotionDbMap_FindLowerBoundByPath`.
4. Resolves in-table dual key by `DualKeyEntryMap_FindLowerBoundBySecondaryPrimaryKey`.
5. Returns path only when both key components match exactly.

Comparator detail:

- the internal dual-key RB-tree is ordered by `(secondary_key, primary_key)`.
- API semantics remain `(primaryKey, secondaryKey)`.

Caller linkage status (current BNinja evidence):

- `RoleView.dll` does not call base-slot `+0x38` directly.
- `RoleView.dll` calls slot `+0x20` with `(partName, keyLow32, keyHigh32, 1, 0)`, where `keyLow32/keyHigh32` are caller-built composite motion keys.
- direct code xrefs to `GameDataSet_FindRolePartMotionResourcePath` inside `GraphicData.dll` are not present; it is currently referenced through the exported vtable slot.

## `GameDataSet_GetStringById` (vtable offset `+0x3C`)

Vtable offset `+0x3C` → `GameDataSet_GetStringById` (`0x1000A030`). `__thiscall` with one
stack argument, the string id, and `retn 4`. The body adjusts `this` to the string table
embedded at `this+0x150` and tail-calls `StringTable_LookupById` (`0x1002C030`).

`StringTable_LookupById` resolves against a two-tier table:

| Offset (from `this+0x150`) | Meaning |
|---|---|
| `+0x00` | DB-string-resource-initialized flag (see `GameDataSet_InitStrRes` below) |
| `+0x08` / `+0x0C` | ini-backed `std::map`; node key at `+0x0C`, value `std::string` at node `+0x14` |
| `+0x18` / `+0x1C` | DB-backed `std::map`; value at node `+0x10` |

Order of resolution:

1. when the `+0x00` flag is non-zero, `lower_bound` the DB-backed map and return node `+0x10`
   on an exact-key hit;
2. otherwise `lower_bound` the primary map and return node `+0x14` on a hit, or the empty
   string when that pointer is null;
3. on a miss, enter `g_MissingStringFallbackLock` (`0x10036730`), format
   `sprintf(g_MissingStringFallbackBuffer, "SE:%u", id)` into the static buffer at
   `0x10036630`, leave the section, and return that buffer.

Two consequences the reconstruction must preserve. A missing string is **not** empty and does
not throw: it renders literally as `SE:<id>`. And the miss result is a single process-wide
static buffer, so the returned pointer is only valid until the next miss on any thread —
managed code returns an owned string instead, which is a safe divergence because the native
buffer's lifetime is an artifact of the C API, not observable behaviour.

Known caller ids from `Conquer.exe` `CMyShellDlg__RenderStatusHintPanel`: `0x2754`, `0x2755`,
`0x2756`–`0x275A`, `0x2873`, `0x2875`, `0x2882`, `0x288B`, `0x289C`, `0x28F6`.

## `GameDataSet_QueryDataIconInterface` (vtable offset `+0x5C`)

Vtable offset `+0x5C` → `GameDataSet_QueryDataIconInterface` (`0x10008740`). The entire body is
`if (index == 0 && this != 0) return this + 4; else return 0;`.

`IDataIcon` is therefore not a separate object: it is a secondary base embedded at
`GameDataSet+4`, and its vtable is `*(GameDataSet+4)`. Only index `0` is valid. Any other index
returns null, which the `CMyBitmap` text paths treat as "no data icon provider" and which
disables the `#NN` branch documented in
[`../graphic_dll/04_fonts_and_text.md`](../graphic_dll/04_fonts_and_text.md).

## `GameDataSet_InitStrRes` (vtable offset `+0x04`)

Vtable offset `+0x04` → `GameDataSet_InitStrRes` (`0x1001DBA0`). This is the load entry point for
the numeric string table read by `GameDataSet_GetStringById`.

1. Guard: when the byte at `this+0x150` (string table `+0x00`) is already non-zero, it logs
   `InitDBStrRes had been called, DO NOT call InitStrRes again!` and returns without loading.
   That byte is the DB-string-resource-initialized flag: it both locks out the ini loader and
   makes `StringTable_LookupById` prefer the DB-backed map at table `+0x18`.
2. `StringTable_LoadStrResIni(this+0x150)` (`0x1002BD00`) fills the ini-backed map at table
   `+0x08` from `ini/StrRes.ini`.
3. It then queries its own vtable `+0x3C` for id `0x28BA` (10426) and `_stricmp`s the result
   against `"Arabic"`, calling `SetAsArabicClientVersion()` only on an exact match.

`ini/StrRes.ini` in the clean set contains `10426=English`, so the comparison fails and
`SetAsArabicClientVersion` is never called. This is the mechanism behind the already-recorded
observation that `graphic.dll`'s `g_ArabicClientTextLayoutEnabled` stays `0`: the Arabic layout
switch is **data-driven from `StrRes.ini`**, not a build-time flag. See
[`../graphic_dll/04_fonts_and_text.md`](../graphic_dll/04_fonts_and_text.md).

No `Cn_Res` string exists in `GraphicData.dll`, so the shipped `ini/Cn_Res.ini` is not read by
this module; the DB-backed tier's loader has not been located and is not exercised by the clean
ini path.

### `ini/StrRes.ini` format (`StringTable_LoadStrResIni`)

`fopen(path, "r")` — **text mode**, so on the native Windows target the CRT translates CRLF to LF
before the buffer is seen. The shipped file mixes CRLF and LF; a managed reader working on raw
bytes must strip a trailing `\r` itself to match. On open failure the loader logs
`Error! Can't open file:%s!` and returns `0`.

Per line:

- `fgets` with a `0x400` buffer, so a line longer than 1023 bytes is split and its tail is parsed
  as a fresh line;
- a trailing `\n` is stripped;
- a line whose **first** byte is `;` is a comment; `;` anywhere else is ordinary text;
- `strchr(line, '=')` finds the separator, and a line without `=` is skipped;
- `atoi` parses the left side as the id, so non-numeric text yields id `0` (the file's own
  `0=ERROR` entry occupies that slot);
- everything after the **first** `=` is the value, so embedded `=` characters survive; an empty
  remainder clears the string;
- later duplicate ids overwrite earlier ones.

Values are client-code-page bytes and are not transcoded by the loader. The file header documents
the id spaces: UI `10000`-`50000`, 3DRole `100000`-`200000`, map `300000`-`400000`, 3DBaseCode
`500000`-`600000`.

Verified ids used by `CMyShellDlg__RenderStatusHintPanel`:

| Id | Hex | Value |
|---|---|---|
| 10068 | `0x2754` | `Change Avatar` |
| 10069 | `0x2755` | `It will cost you 500 silver to change your avatar.` |
| 10070 | `0x2756` | `Walk/Run` |
| 10071 | `0x2757` | `Chat On/Off` |
| 10072 | `0x2758` | `Map On/Off` |
| 10073 | `0x2759` | `Shift Screen: Off` |
| 10074 | `0x275A` | `Shift Screen: On` |
| 10355 | `0x2873` | `Revive` |
| 10357 | `0x2875` | `Settle` |
| 10370 | `0x2882` | `View Equipment` |
| 10379 | `0x288B` | `Restore Appearance` |
| 10396 | `0x289C` | `Descend` |
| 10486 | `0x28F6` | `Revive Here` |

## `IDataIcon` — the `#NN` data-icon interface

`GameDataSet` exposes three vtables. The constructor (`0x100010A0`) ends by storing:

| Member | Value | Meaning |
|---|---|---|
| `this[0]` | `0x10030190` | `g_IGameDataSet_BaseVtbl` |
| `this[1]` | `0x1003018C` | `g_IDataIconVtable` — the `IDataIcon` secondary base at `GameDataSet+4` |
| `this[2]` | `g_ResLimitInterfaceVtable` | resource-limit interface at `GameDataSet+8` |

`g_IDataIconVtable` sits immediately below the base vtable and holds exactly **one** slot, so
`IDataIcon` is a single-method interface. `GameDataSet_QueryDataIconInterface` (vtable `+0x5C`)
hands out `GameDataSet+4`.

### `IDataIcon_GetEmotionIconAniByIndex` (`0x1001D9D0`)

1. `arg1 - 4` readjusts to the `GameDataSet` base and calls base vtable `+0x60`
   (`GameDataSet_GetEmotionIconCount`, `0x1001CF20`), which returns
   `(*(this+0x94) - *(this+0x90)) >> 4` — the element count of a contiguous 16-byte-entry table,
   or `0` when the begin pointer is null. A count `<= 0` returns null and disables `#NN` entirely.
2. `sprintf(buffer, "ICON%d", index % count)` using a **signed** modulo, so an index past the end
   of the table wraps instead of failing. A `#NN` escape can only produce `0`–`99`.
3. Returns base vtable `+0x10` — the ANI section resource lookup — called with
   `("ani/EmotionIco.ani", "ICON<n>", 1, 0x7530)`. That is the same call shape and 30000 ms
   timeout used for `("ani/Control.ani", "Dialog21", 1, 0x7530)` in
   `CMyShellDlg__RenderStatusHintPanel`.

The caller then reads the returned ANI object's vtable `+0x18` for the icon width, falling back to
`0x10` pixels when the lookup fails or reports zero. See the `#NN` measurement contract in
[`../graphic_dll/04_fonts_and_text.md`](../graphic_dll/04_fonts_and_text.md).

### Count source and the icon-set mismatch

The count comes from `GameDataSet_LoadEmotionIcoDb` (`0x1001CD50`), which reads
`ini/EmotionIco.dbc` out of the c3.wdb game DB pack. The payload starts with the identifier
`EMOI` (`0x494F4D45`), the record count at `+0x04`, and fixed `0x24`-byte records from `+0x0C`,
each beginning with a NUL-terminated name. The loader pushes those names into a
`vector<std::string>` (16-byte elements), and `GameDataSet_GetEmotionIconCount` reports that
vector's element count.

Clean v5517 data carries a discrepancy worth preserving: `ini/EmotionIco.dbc` holds **67**
records, while `ani/EmotionIco.ani` defines **68** sections, `ICON0` through `ICON67`. Because the
modulus is the table count and not the section count, the reachable indices are `0`-`66`:
`#67` wraps back to `ICON0`, and **`ICON67` cannot be addressed by any `#NN` escape at all**. A
reconstruction that took the count from the `.ani` file would silently shift every escape from
`#67` upward.

The width accessor on the resolved ANI object is already recorded as `CAni` vtable `+0x18`
`GetSize(out CMySize*, frame)` in
[`../07_ani_frame_animation_runtime.md`](../07_ani_frame_animation_runtime.md).
