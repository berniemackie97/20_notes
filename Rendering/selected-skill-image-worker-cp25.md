# CP2.5d3 — selected skill image preparation

Baseline OCC `91175f0f`. Selected skill image and its independent cover
resolve their ANI index and decode the requested frame during Draw.
Quickbar has separate per-slot image and glow caches and is a later slice.

Existing native evidence in `20_main_hud_selected_skill_native_contract.md`:
selected frame 0 is resolved from the section, then drawn at `0x5A2961`
using the 50×50 source. The independent cover is Control.ani Image0, frame
0, with a 64×64 source. The cover can draw when the selected image is clear.
Those asset, order and geometry rules carry forward. No new native claim.

One world-owned job decodes the requested selection and/or cover. A result
can be pending, present, missing or failed. The current selection shows no
image while pending, and an older result cannot populate a new selection.
The independent cover can still become ready. GPU upload happens before
drawing; graphics recreation can use the same CPU loader. Closing the world
cancels the outstanding batch and observes it after closing the socket.

The Apple M4 baseline uses the actual renderer, curated Magic0 and Image0,
and the 1024×768 production OpenGL render target.

## Probe results

Apple M4 OpenGL, 1024×768 RGBA8, fresh image caches and the same direct
selected/covered state. The first synchronous draw took 16.353 ms. Five
repeat synchronous cache misses took 5.443–9.148 ms. The worker version's
maximum prepare-plus-draw cost per repeat was 0.237–0.468 ms per poll.
The first worker caller peak was 8.651 ms. Results became visible after
three or four polls in the probe. It includes readbacks and 1 ms waits
between polls, so its wall time is not game frame pacing.

The guard rejected any content open on the context thread. Each batch
made four open attempts on the worker. All six final RGBA8 framebuffer
hashes matched:
`93120782cf6239bab955b30a5a461b908a97c722f26c31ae7b8032d3685cc42c`.
The first pending poll drew no completed image. The probe drives the
renderer state directly and is not a live skill-selection smoke test.

OCC #276 at `c67b8c59` is ready for review. Locked restore, zero-warning
Release build, format, 2,997 focused tests and Build Bouncer passed. CI is
green after rerunning the Windows job for an unchanged launcher headless
setup failure on the same commit.

#276 merged as `957ea1d8`. The reviewed tree matches the merge and local
main is synced. Windows passed on attempt 2 and all final gates were green.
