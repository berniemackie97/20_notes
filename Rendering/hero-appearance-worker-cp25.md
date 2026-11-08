# CP2.5a — hero appearance loading

OCC baseline `11a7a1c1`. ClientWorld synchronously loaded C3 catalogs, mesh
sections, motion tracks and DDS textures for the first role and on equipment
changes. Item and experience catalogs and map/HUD texture paths are separate
CP2.5 work.

## Native boundary

Existing evidence is in `graphicdata_dll/19_datathread_dll.md`,
`20_resource_request_object.md` and `02_igamedataset_vtable.md`.
Verified 600 DataThread instructions and 181 GraphicData instructions against
the 5517 PE bytes. DataThread SHA-256
`af2a283415b3279b677c71581dd75e297d240b5384aef0805f15edca0a33dcc2`;
GraphicData SHA-256
`d5a7685aac412a96374deb3c8a42a62827a705d4d66d4ab4f475fba2c09619ee`.

- DataThread (BNDB view 33): worker takes the critical section at
  `0x1000107B`, executes the request at `0x1000113A`, publishes the completed
  pointer/count at `0x1000117B..0x10001186` and unlocks at `0x10001191`.
  It reacquires per request. Dtor signals and waits at `0x10001356/65`.
- GraphicData (view 63): request load vtable target `0x10009E40` runs on the
  worker. The frame pump calls the drain at `0x10003A32`. Both pool drains
  query +0x18, take a completed request via +0x0C, then finalize at
  `0x10003F1C/44` into the caller's cache.
- Added and read back comments on `DataThread_WorkerThreadProc` and
  `GameDataSet_DrainCompletedResources`. Existing names retained. BNDBs unsaved.

OCC uses one outstanding CPU preparation per world and retains the displayed
role while a new appearance is prepared. Only the current appearance can be
installed. OpenGL creation, swap and disposal stay on the context thread.
This is a managed ownership policy inspired by the native handoff.

## Baseline

Production OpenGL conformance host on Apple M4 with local curated 5517
content. Called the actual renderer load and previous renderer disposal,
alternating body 2000000 and 2130000 at appearance 1002. First load was
49.020 ms. The following 30 swaps ranged 3.725–14.269 ms. These are
appearance operations on the context thread, excluding frame pacing and
unrelated world work.

## Worker comparison

The same 31-swap OpenGL probe measured 3.762 ms for the initial upload/swap.
Thirty repeat upload/swaps took 0.081–0.603 ms, and pending polls took at most
0.048 ms after the first request. Elapsed repeat preparation-to-install time
was 3.492–9.125 ms including 1 ms poll waits. The old synchronous operation
and new context-thread operation are comparable as frame work; the latter
excludes worker work. No full game frame-time or VM comparison is implied.

Map 1010 at (61, 101), direction 3, 640×480 logical RGBA8, fixed 1000 ms,
Apple M4 OpenGL 4.1. Framebuffer SHA-256 matched baseline for all three
inputs, with distinct hashes for each input:

| Role | SHA-256 |
|---|---|
| None | `8ba4b7dc598f0c25c2244e68061f307bb6b051edf89ef8d75e59f1a88db8d3f7` |
| Body 2000000 | `ce71b2311c4083f3c78f6f650c0692e5fb423463435ab4da99000dbbe556b534` |
| Armor 2130000 | `57e1b4cdec30607d854e15d3482ba6b8e88e2830fbf2f651008abaa33ef0c550` |

## Remaining CP2.5 reads at the #271 boundary

- `ClientWorld` still reads `ItemStatCatalog` before building the hydrated
  hero and `LevelExperienceTable` on map completion. Item stats must be
  ready before any queued equipment packet applies. `WorldFrameIngress`
  holds one outstanding receive and drains at most 32 frames per tick.
- `WorldMapTextureRenderer.EnsureTexture` decodes an animation image on a
  texture cache miss, then uploads it on the same thread. World and preview
  callers share this renderer, so their missing-texture and cache policies
  need to be checked before changing that boundary.
- `WorldHudRuntime` loads its asset and font settings during construction
  from `ClientWorld.GetRenderer`. Audit lazy HUD images separately from the
  entry catalog reads.

OCC #271 merged as `72aa22f9`. The merged tree matches the tested branch.
Linux Quality, Windows, macOS, CodeQL and dependency review passed. The
world-owned, bounded worker and OpenGL context ownership are managed design
choices. Native code establishes the worker-to-frame handoff, and the retail
framebuffer comparison checks the visible result.
