# CP2.5d1 — HUD startup content

OCC baseline `f5b016fb`. The first render target created `WorldHudRuntime`,
which read and decoded the static HUD artwork, settings, status text and
magic metadata on the frame thread before building the OpenGL resources.
On Apple M4 with the curated 5517 content and actual OpenGL, the first
constructor took 692.870 ms, followed by 90.481–133.178 ms across ten repeats.

Move that existing CPU preparation into a world-owned job. The map and HUD
can prepare independently. The first gameplay frame waits for the first
map view, appearance and HUD resources. The HUD's OpenGL resources and
host font contexts remain context-owned. The same prepared content can
be used if the context is recreated.

This is managed scheduling. Native HUD order and asset semantics carry
forward from `19_main_hud_quickbar_native_contract.md` and
`21_main_hud_magic_status_hint_native_contract.md`. The earlier DataThread
evidence covers the worker/completion boundary (`0x1000113A`, `0x10003A32`).
It does not specify the managed HUD preparation schedule. No new native
annotation is needed.

Lazy quickbar and selected skill image requests remain separate. They
need a way to distinguish a pending image from a missing one before their
GPU caches can consume asynchronous results. System font discovery and
full frame timing are outside the static content handoff measurement.

## Worker probe

Actual OpenGL context and curated content, 1024×768, Apple M4. A recording
source counted 76 game-content opens in each prepared HUD and rejected
any open during the context-side construction. No such open occurred.
Ten repeat context-side constructions took 56.502–68.520 ms, compared
with 90.481–133.178 ms for the old combined constructor. Worker repeats
took 30.889–37.181 ms with 1 ms polls. Cold attach was 507.381 ms, so
host font setup and texture creation still need attention. The probe
does not measure time to admission or general frame pacing.

Chrome and vitals used the same asset and rendering rules. The 1024×768
RGBA8 framebuffer SHA-256 matched both paths:
`c42771ff0a3aa87b82674b7e4ad0a7f7f48b4e7681c8ed514f427db4fe2591d5`.

An isolated probe constructed the same three HUD text contexts on the actual
OpenGL device without the HUD textures. It took 93.836 ms on the first call
and 55.075–61.378 ms in five repeats. Font contexts account for most of the
warm attachment time in this probe. This does not attribute the full cold
HUD attach cost to fonts.

OCC #274 at `e3d27754` is ready for review. Locked restore, zero-warning
Release build, format, 2,989 focused tests and Build Bouncer passed. CI
passed Linux, Windows, macOS, dependency review and CodeQL.

#274 merged as `e7af3284`. The reviewed tree matches the merge and local main
is synced. Final CI passed.
