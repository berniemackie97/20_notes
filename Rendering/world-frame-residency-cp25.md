# CP2.5e — map GPU residency and world frame pacing

OCC base `a78e0b8f` includes the quickbar image worker from #277. The
playable map retains every uploaded texture for the world lifetime. Each
pending view must preserve the prior complete view, which can still draw
textures the pending view no longer needs. A frame may share paths across
layers and multiple animation frames.

Native background request and completion boundaries are recorded in
`graphicdata_dll/19_datathread_dll.md` and `03_resource_request_semantics.md`.
Native GraphicData texture requests refresh the type 0 cache timestamp,
and its cleanup function at `0x10008280` releases expired entries. These
are resource lifetime observations. They do not establish a playable map
residency budget. The rewrite uses count and RGBA pixel-byte targets for
idle textures and protects both live view working sets.

Validation compares the desktop loop with curated content, including
admission preparation, movement, and repeated equipment changes through
the production inbound handlers. Asset opens on the context thread are
rejected. Network authentication and the display compositor are outside
the probe.

## Residency pressure

Apple M4 OpenGL 4.1 Metal. Curated 5517 map 1010, 640×480 RGBA8, fixed
animation tick 1000. View tiles (61,101), (64,105), (72,116), (90,120),
(128,143), (114,57), (52,61), (61,101), repeated three times. Test targets
24 textures and 6 MiB. All 24 completed SHA-256 values matched the
synchronous reference. All 99 pending captures retained the prior view.
The return to (61,101) reopened 12 art paths per pass on the worker.
The initial hash was
`8ba4b7dc598f0c25c2244e68061f307bb6b051edf89ef8d75e59f1a88db8d3f7`.

## Desktop trace

420 world draws per run using `DesktopWindow` and the production
`ClientWorld` update, prepare, draw and present calls at 1024×768.
The target frame interval was 25 ms. The harness delivered 40 corrections
(10010/108) and 20 armor switches (1009/46) through `WorldFrameIngress`,
using the same admitted role and retail map. Context-thread content opens
throw. The worker read the C3 catalog twice at admission (probe + load).
The base reopened it twice per switch (42 total). The final worker reused
the catalog (2 total). Total content opens fell from 326 to 246.

| Measurement (ms) | Base a78e0b8f | With cache and catalog reuse |
|---|---:|---:|
| First world callback | 46.577 | 44.689 |
| Warm callback median / p95 / max, 410 samples | 5.306 / 8.199 / 19.988 | 5.752 / 9.105 / 13.844 |
| Equipment-change callback p95 / max, 80 samples | 10.971 / 19.988 | 9.901 / 13.844 |
| Equipment-change frame interval p95 / max | 27.419 / 34.921 | 25.956 / 34.970 |

Equipment windows cover the four frames after each injected change.
Callback timing includes ingress, world load polling, appearance and map
preparation, HUD, map and role draws, and presentation submission.
It excludes authentication and compositor timing. The first world draw
still takes about 45 ms in this environment with no context-thread content
opens. The two runs are local traces and do not establish cross-platform
frame-time guarantees.

Reproducers and raw traces are local in the client checkout under
`artifacts/cp25e-world-probe/` and `artifacts/cp25e-map-pressure/`.

A second desktop pass directly checked installed body IDs. Admission
and all 20 armor switches installed the expected models. That pass's
first callback took 25.319 ms, so the cold cost varied between runs.
The checked-in OpenGL residency mode reproduced all 24 completed hashes,
preserved 47 pending views on that run, and reloaded the return view.
The pressure test held 24 textures / 6,094,848 RGBA bytes after handoff,
compared with 49 / 11,862,016 without eviction.

OCC #278 at `311fb432` passed 3,755 local tests, locked restore, Release
build with zero warnings and errors, format, and Build Bouncer. The local
gate passed on retry with the same commit. Linux, macOS, dependency review
and CodeQL passed. Windows passed on its same-commit rerun. The first
Windows job failed in an unchanged launcher test during Avalonia headless
setup, tracked in OCC #279.

#278 merged as `ae739cb8`. The merged tree matches the reviewed commit,
local main is synced, and OCC #241 closed.
