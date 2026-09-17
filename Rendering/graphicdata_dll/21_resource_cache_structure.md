# GraphicData.dll — Resource Cache BST Structure

## Overview

`GameDataSet` maintains 6 resource caches, each implemented as an MSVC `std::map` red-black tree keyed by integer resource ID. Cache entries are heap-allocated structs pointed to by BST node data pointers. The request path inserts a placeholder entry (null resource), and `FinalizeLoadedResource` fills it in when the async load completes. Eviction runs during the time-gated cleanup phase of the per-frame pump.

## GameDataSet Cache Layout

| Type | Cache Offset | Head Offset | Nil Sentinel | Global Timeout Offset | Category |
|------|-------------|-------------|--------------|----------------------|----------|
| 0 | +0xDC | +0xE0 | `g_MapNil_TextureCache` (0x10035190) | +0x180 | Texture |
| 1 | +0xEC | +0xF0 | `g_MapNil_EffectCache` (0x10035198) | +0x184 | Effect |
| 2 | +0xCC | +0xD0 | `g_MapNil_MeshCache` (0x10035188) | +0x178 | Mesh |
| 3 | +0xBC | +0xC0 | `g_MapNil_StringKeyedOuter` (0x10035180) | +0x17C | String-keyed (two-level) |
| 4 | +0x10C | +0x110 | `g_MapNil_MapAnimCache` (0x100351A8) | (none) | Map/animation |
| 5 | +0xFC | +0x100 | `g_MapNil_Scene3DCache` (0x100351A0) | +0x188 | Scene3D |

All global timeout values are initialized to `0x7530` (30000 ms = 30 seconds) in `GameDataSet_Initialize`.

Type 4 has no global timeout — eviction uses only the per-entry custom timeout.

## MSVC std::map Node Layout (int-keyed, types 0, 1, 2, 4, 5)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0x00 | 4 | _Left | Left child pointer |
| +0x04 | 4 | _Parent | Parent pointer |
| +0x08 | 4 | _Right | Right child pointer |
| +0x0C | 4 | _Key | Integer key (resource ID) |
| +0x10 | 4 | _DataPtr | Pointer to heap-allocated cache entry |

The map header node (at head offset) doubles as the end sentinel. `begin()` = leftmost node via `*head` (head->_Left). `end()` = head node.

## Cache Entry Layouts

### Standard Entry (types 0, 1, 5/Scene3D) — 16 bytes

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0x00 | 4 | key | Resource ID (duplicate of BST node key) |
| +0x04 | 4 | resource | Resource pointer (null until loaded) |
| +0x08 | 4 | timestamp | `timeGetTime()` value, updated on access and finalize |
| +0x0C | 4 | customTimeout | Per-entry timeout in ms (0 = use global, 0xFFFFFFFF = never evict) |

### Mesh Entry (type 2) — 20 bytes

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0x00 | 4 | key | Resource ID |
| +0x04 | 4 | primaryResource | Primary mesh resource pointer |
| +0x08 | 4 | secondaryResource | Secondary mesh resource pointer |
| +0x0C | 4 | timestamp | `timeGetTime()` value |
| +0x10 | 4 | customTimeout | Per-entry timeout (0 = use global, 0xFFFFFFFF = never evict) |

### Type 4 Entry — 20 bytes

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0x00 | 4 | key | Resource ID |
| +0x04 | 4 | resource | Resource pointer |
| +0x08 | 4 | timestamp | `timeGetTime()` value |
| +0x0C | 4 | customTimeout | Per-entry timeout (0xFFFFFFFF = never evict) |
| +0x10 | 4 | loadedFlag | Set to 1 by FinalizeLoadedResource |

### Type 3 (String-keyed) — Two-level structure

Type 3 uses a two-level BST:
- **Outer BST** (`+0xBC`): keyed by string (std::string), sentinel `g_MapNil_StringKeyedOuter`
- **Inner BST** (per outer node): keyed by resource ID pair, sentinel `g_MapNil_StringKeyedInner`

Inner BST nodes have data pointers at node+0x18 (larger node due to pair key at +0x0C..+0x14).

Inner cache entry fields:
- +0x08: resource pointer
- +0x0C: timestamp
- +0x10: custom timeout

Eviction iterates all outer nodes, then processes each inner BST via `CacheType3_EvictInnerEntries`. Before evicting an inner entry, it calls `resource->vtable+0x2C` to check if the resource is currently in use (skips if in-use).

## Eviction Algorithm

Each eviction function iterates its BST in order (`begin()` to `end()`) and evaluates each entry:

```
for each node in BST:
    entry = node->_DataPtr
    if entry is null:
        evict (remove node)
    elif entry.customTimeout == 0xFFFFFFFF:
        skip (never evict)
    elif entry.customTimeout == 0:
        if timeGetTime() > globalTimeout + entry.timestamp:
            evict
    elif entry.customTimeout > 0:
        if timeGetTime() > entry.timestamp + entry.customTimeout:
            evict
```

Type 4 is simpler — no global timeout fallback, uses only `entry.customTimeout + entry.timestamp`.

Type 3 adds a resource-in-use guard (`resource->vtable+0x2C` must return 0) before evicting.

### Eviction Steps

1. Call per-type release function (`CacheEntry_Release*`) to free the resource
2. Free the cache entry allocation (`operator delete`)
3. Erase the BST node from the tree

### Per-Type Release Functions

| Type | Function | Address | Behavior |
|------|----------|---------|----------|
| 0 | `CacheEntry_ReleaseModel` | 0x10009D30 | Release entry+4, zero entry+4 |
| 1 | `CacheEntry_ReleaseEffect` | 0x10009D50 | Release entry+4 via effect release |
| 2 | `CacheEntry_ReleaseMesh` | 0x10009CF0 | Release entry+4, zero entry+4 and entry+8 |
| 3 | `CacheEntry_ReleaseStringKeyed` | 0x10009D10 | Release entry+8 |
| 4 | `CacheEntry_ReleaseMapAnim` | 0x10009D90 | Release entry+4 |
| 5 | `CacheEntry_ReleaseScene3D` | 0x10009D70 | Release entry+4 |

## Request Path: Cache Entry Insertion

When a `GameDataSet_Request*` function encounters a cache miss:

1. Allocate cache entry via `operator new(size)` (size varies by type)
2. Initialize: key = resourceId, resource = null, timestamp = `timeGetTime()`, customTimeout = requestPriority parameter
3. Insert BST node into the type-specific map
4. Store cache entry pointer at node+0x10
5. Allocate 104-byte request object, link to pools
6. Return null to caller (resource not yet available)

On cache hit: update timestamp, return existing resource pointer (may be null if still loading).

## GameDataSet Field Map (resource subsystem)

| Offset | Field | Description |
|--------|-------|-------------|
| +0xBC | cache3 | String-keyed resource cache (std::map, two-level) |
| +0xCC | cache2 | Mesh cache (std::map<int, MeshCacheEntry*>) |
| +0xDC | cache0 | Texture cache (std::map<int, CacheEntry*>) |
| +0xEC | cache1 | Effect cache (std::map<int, CacheEntry*>) |
| +0xFC | cacheScene3D | Scene3D cache (std::map<int, CacheEntry*>) |
| +0x10C | cache4 | Map/animation cache (std::map<int, MapAnimCacheEntry*>) |
| +0x178 | globalTimeout2 | Mesh cache global expiry (default 30000 ms) |
| +0x17C | globalTimeout3 | String-keyed cache global expiry (default 30000 ms) |
| +0x180 | globalTimeout0 | Texture cache global expiry (default 30000 ms) |
| +0x184 | globalTimeout1 | Effect cache global expiry (default 30000 ms) |
| +0x188 | globalTimeoutScene3D | Scene3D cache global expiry (default 30000 ms) |
| +0x2E0 | cleanupIntervalMs | Time-gated cleanup interval (default 30000 ms) |
| +0x2E4 | primaryPool | IDataThread* — primary async work queue |
| +0x2E8 | secondaryPool | IDataThread* — secondary async work queue |
| +0x2EC | primaryPendingDeque | Pending request deque for primary pool |
| +0x318 | primaryPendingCount | Number of pending primary requests |
| +0x320 | secondaryPendingDeque | Pending request deque for secondary pool |
| +0x348 | secondaryPendingCount | Number of pending secondary requests |
| +0x34C | loadingBudgetDeadlineTick | `timeGetTime() + budget_ms` deadline |
| +0x350 | isWithinLoadingBudget | 1 = within budget (force immediate), 0 = expired |

## BNinja Verified Symbols

| Address | Verified Name |
|---------|---------------|
| 0x10009D30 | CacheEntry_ReleaseTexture |
| 0x10009D50 | CacheEntry_ReleaseEffect |
| 0x10009CF0 | CacheEntry_ReleaseMesh |
| 0x10009D10 | CacheEntry_ReleaseStringKeyed |
| 0x10009D90 | CacheEntry_ReleaseMapAnim |
| 0x10009D70 | CacheEntry_ReleaseScene3D |
| 0x100080A0 | CacheType3_EvictInnerEntries |
| 0x10035190 | g_MapNil_TextureCache |
| 0x10035198 | g_MapNil_EffectCache |
| 0x10035188 | g_MapNil_MeshCache |
| 0x10035180 | g_MapNil_StringKeyedOuter |
| 0x100351E8 | g_MapNil_StringKeyedInner |
| 0x100351A8 | g_MapNil_MapAnimCache |
| 0x100351A0 | g_MapNil_Scene3DCache |
| 0x1000D1B0 | MapFind_TextureCache |
| 0x1000CCC0 | MapFind_MeshCache |
| 0x100138E0 | MapInsertOrFind_TextureCache |
| 0x10013500 | MapInsertOrFind_MeshCache |
| 0x10005650 | GameDataSet_GetTexturePathBST |
| 0x10005620 | GameDataSet_GetTexturePathBSTFallback |
| 0x10005630 | GameDataSet_GetMeshPathBST |
| 0x10005600 | GameDataSet_GetMeshPathBSTFallback |
