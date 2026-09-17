# `GraphicData.dll` — Effect draw resource request (`GameDataSet_RequestEffectDrawResource`)

`Role3D.dll` obtains effect draw resources by calling the `GameDataSetQuery()` interface method:

- `res = ds->GameDataSet_RequestEffectDrawResource(resourceId, mode, maxAgeMs)`

Entry point:
- `GameDataSet_RequestEffectDrawResource` (`0x10006A90`) (base vtable offset `+0x1C`)

*Externally observable* behaviour, as exercised by `Role3D.dll`'s effect render backends.

## Return value and readiness

Return value:

- `0` if the requested effect draw resource is not ready (and a load is scheduled), or
- a non-zero pointer to the effect draw resource object when available.

`Role3D.dll` treats a return value of `0` as "not ready" and aborts the current effect render path.

## Scheduling vs immediate load (`mode`)

The `mode` argument controls how the request is serviced:

- `mode == 0`: schedule for load (asynchronous); returns `0` until ready.
- `mode == 1`: immediate load path (synchronous); returns a non-zero pointer on success.

`Role3D.dll` uses `mode = 0` in the render backends.

### Verified mode rewrite ordering (`0x10006A90`)

Before queue/immediate branch selection, native code applies request-mode rewriting in this order:

1. if `force_immediate_load` (`byte [this+0x350]`) is set, mode becomes `1`,
2. if `GameDataSet_IsImmediateResourceId("effect", resourceId)` returns true, mode becomes `1`,
3. if the **original caller mode** was `3`, final mode is forced to `0`.

Important parity point:
- step (3) is unconditional with respect to immediate-section membership.
- in other words, caller mode `3` is always rewritten to queued mode `0` for this API.

## Request aging (`maxAgeMs`)

The request tracks a `lastTouchMs` timestamp and a maximum "age" value:

- each request refreshes `lastTouchMs = timeGetTime()`
- if `maxAgeMs` passed to the request is larger than the stored maximum, the stored maximum is raised

This allows the resource manager to keep frequently-touched effect resources resident longer.

## Internal cache entry layout (observable fields)

`GameDataSet_RequestEffectDrawResource` maintains a per-`resourceId` cache entry with an observable 4-dword layout:

| Dword index | Name | Notes |
|---:|---|---|
| `0` | `resourceId` | Key value (the requested id). |
| `1` | `resourcePtr` | Returned as the non-zero result when the resource is ready. |
| `2` | `lastTouchMs` | Updated to `timeGetTime()` on each request. |
| `3` | `maxAgeMs` | Raised to the maximum `maxAgeMs` value ever requested for this id. |

When an entry exists, the function returns `entry->resourcePtr` (unless `mode == 1` and the pointer is still null, in which case it proceeds down the immediate-load path).

## Managed parity slice (`2026-03-04`)

Non-baseline Role3D effect runtime now uses a resolver-backed gateway that mirrors the verified request-cache contract above:

- `10_work/src/Conquer/Graphics/Role3DEffectResolverResourceGateway.cs`
- `10_work/src/Conquer/Graphics/Role3DEffectResourceResolverRuntime.cs`
- wired in `10_work/src/Conquer/Client/GameApplication.cs`

Implemented parity points:

- per-resource cache entry fields (`resourceId`, `resourcePtr`, `lastTouchMs`, `maxAgeMs`),
- mode rewrite order (including unconditional caller-mode-3 -> queued rewrite),
- queued mode returns `0` and enqueues request,
- immediate mode attempts synchronous load and stores pointer in cache entry.

BNinja rename applied for this slice:

- `sub_10009770` -> `GameDataSet_ReleaseEffectResourceById`
  - used by resource-request completion flow when replacing/discarding effect entries.

## Returned object interface

The returned pointer is the "effect draw resource object" driven through a vtable by `Role3D.dll`. The exact vtable methods and call contracts used by the effect backends are documented in:

- `analysis/conquer_docs/Rendering/role3d_dll/10_effect_draw_resource_interface.md`
