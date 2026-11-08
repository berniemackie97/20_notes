# CP2.5d4 — quickbar image preparation

Baseline OCC `957ea1d8`. Cache misses for slot content, fixed digits and
cover, and glow frames resolve and decode files inside Draw. The existing
native source and draw order are recorded in
`19_main_hud_quickbar_native_contract.md` §6. In particular Item%d falls
back to ItemDefault, a glow precedes the slot image, and its timer starts
at the first draw. Layout, dimensions, fallback, overlay and timing rules
carry forward.

Managed plan: draw only completed assets. Keep a miss pending until the
worker reports a value or confirmed absence. The CPU worker deduplicates
the current frame's requests, runs one bounded batch, and retains ready
artwork only while relevant. Current GPU caches stay per slot and per HUD.
Upload a bounded number of images per draw and at most one glow set.
A pending slot never displays an older key. The world owns the CPU
worker across graphics recreation and cancels and observes it on close.
No new native claim or annotation is needed.

The baseline probe draws curated 5517 action, magic, fallback item,
quantity, addition, cover and FireLight from a fresh set of caches.

## Verification

Apple M4, OpenGL 4.1 Metal, logical 1024×768 RGBA8, curated 5517 payload.
Six fresh-cache draws on the base code took 37.431–78.208 ms. The final
probe drew bare and complete quantity references before timing the worker.
The first cold worker draw took 1.755 ms. The next five cold draws took
0.013–0.034 ms and maximum draws within those repeats took 0.576–0.766 ms.
Timing covers the quickbar draw, including ready uploads. It excludes
readback, frame presentation and worker time. Under the readback probe,
time to match ranged from 48.389 to 86.211 ms over 10–15 draws.

The content source rejected all opens on the context thread. Every
iteration recorded 21 worker opens and reached the baseline SHA-256
`C605C0D4FF6A0E3FCC144C98FAD65018898C3C8188301949F4ECBC36C9D298BC`.
The cold draws differed from the completed reference. Every frame's
quantity crop matched either an empty slot, the unadorned fallback item or
the complete quantity. No pending digit displayed a partial number. These checks drive
the actual quickbar renderer with controlled slot state and a fixed clock.
Full world pacing and resident map texture eviction remain under OCC #241.

## Ownership review

The worker uses the existing package lookup and decoder limits. It has one
in-flight batch of up to eight distinct keys and a soft 8 MiB decoded
threshold checked after each decode. The context owns all textures and
releases old keys when slots change. Only current requests can claim a
failure. The worker observes cancellation between reads and never touches
OpenGL. A consumed content failure closes through world preparation so
graphics release happens outside the frame. Regression tests cover pending
versus missing, deduplication and batch size, deferred upload, obsolete
failure and close during an active read.

OCC #277 head `08addcca`. Locked restore, Release build with zero warnings
and errors, format verification, all 3,001 Client/Content/Rendering/Platform
tests and Build Bouncer passed locally.
Linux Quality, Windows, macOS, dependency review and CodeQL passed at that
head. [Quality workflow](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42401993823).

#277 merged as `a78e0b8f`. The merged tree matches the reviewed head and
local main is synced.
