# CP2.5c — playable map texture streaming

OCC baseline `db3e47d4`, with the catalog worker from #272. The playable
map used the same synchronous image preparation path as the Studio preview.
`WorldMapTextureRenderer.EnsureTexture` resolved, read and decoded ANI
images and uploaded them on the context thread. A cache miss during play
had no per-frame upload limit.

Native background request and completion boundaries are already established:
DataThread.dll `0x1000113A`, GraphicData.dll frame drain `0x10003A32`,
finalization `0x10003F1C/44`. The texture request can return null while an
async request is queued, as recorded in `graphicdata_dll/03_resource_request_semantics.md`.
Those facts do not establish how the original presents an incomplete map
viewport. The playable client's coherent-view handoff and decode/upload
budgets are modern design decisions. Studio's synchronous preview contract
and public limits carry forward.

Baseline on Apple M4, actual curated 5517 map 1010, 640×480 RGBA8 with a fixed
animation time. Camera at (61,101), (64,105), (72,116), (90,120). Context
thread preparation took 25.108, 0.079, 6.545 and 1.201 ms, respectively.
The same views provide framebuffer comparisons after the worker move.

## Worker comparison

One world-owned job at a time, up to eight distinct paths per batch. Decode
uses the original ANI lookup mode. Batches stop after crossing 8 MiB of
decoded pixels. The caller uploads up to four images per frame. A pending
view retains its animation choice until its camera, facing or dimensions
change. An obsolete result or failure cannot replace the displayed view.
The renderer and cache are released on the context thread during world
close. The loader observes cancellation separately. The resident GPU cache
is scoped to the world and has no intra-world eviction policy in this slice.

| Camera | Baseline prepare (ms) | Max caller prepare per quiet worker run (ms) | View ready elapsed with 1 ms polling (ms) |
|---|---:|---:|---:|
| (61,101) | 25.108 | 5.976–6.333 | 23.126–30.948 |
| (64,105), cached | 0.079 | 0.059–0.075 | 0.059–0.075 |
| (72,116) | 6.545 | 0.247–0.309 | 5.656–12.258 |
| (90,120) | 1.201 | 0.086–0.146 | 4.072–4.740 |

All four hashes matched in three serial runs. An earlier run concurrent
with builds/tests took 33.217 ms for a cold caller poll. These are local
prepare measurements, not a whole-frame pacing guarantee. The worker probe
checked that rendering an incomplete next view retained the preceding
framebuffer hash. Baseline and completed worker RGBA8 SHA-256:

- (61,101) `8ba4b7dc598f0c25c2244e68061f307bb6b051edf89ef8d75e59f1a88db8d3f7`
- (64,105) `b62c696a0302a3ce7b1001143e65a66dae06b544b7f217343b461950538cc7b2`
- (72,116) `9f04be8cdb593391694c2cf450ccd5df0a1100ec9655bd478ff5fd38aaf51efc`
- (90,120) `0061be3e895f8d6aada5670a614738f631a2cf7e08a6ed52e8c79fb31ebcf6b6`

OCC #273 at `af4a43c7` is ready for review. Locked restore, zero-warning
Release build, format, 2,987 focused tests and Build Bouncer passed. CI
passed on Linux, Windows and macOS with CodeQL and dependency review.

#273 merged as `f5b016fb`. The merged tree matches the reviewed head,
all final checks passed and local main is synced.
