# CP2.5d2 — HUD font preparation

Baseline OCC `e7af3284`. #274 moved retail HUD assets off the frame
thread. Three HUD text contexts still independently discovered and inspected
the host catalog, opened a FreeType memory face and created the OpenGL atlas.
The isolated macOS probe measured 93.836 ms first and 55.075–61.378 ms on
repeat construction of these contexts.

Keep the three nominal heights, antialias setting, code page, face token
and existing resolver/fallback chain. Prepare three separate rasterizers
from one host catalog on the HUD worker. Each face retains its mapped font
file and a FreeType library lease. The worker completes before any OpenGL
context takes a face. A taken face belongs to its text context. A discarded
or partially built batch disposes the faces it still owns. Context recreation
can reuse static HUD assets and prepare fresh font faces on the worker.

This is managed scheduling. Font selection and text behavior retain the
existing native evidence in `graphic_dll/04_fonts_and_text.md`. No new
retail behavior claim or Binary Ninja annotation is needed. The
[FreeType face contract](https://freetype.org/freetype2/docs/reference/ft2-face_creation.html)
requires exclusive use of each face and serialization of face creation
and destruction on a library. The existing face and library leases provide
those boundaries.

## Worker comparison

Apple M4 OpenGL, configured fonts from the curated 5517 content, 1024×768.
Rendered the same cooldown, status and magic text with the synchronous
constructors and with worker-prepared faces. Six comparisons matched
RGBA8 SHA-256
`ef8d6799d8c3530be6bf74707c321a350b0ee4472fa2a3259efb4fb122318003`.

Five repeat synchronous text-context constructions took 56.308–72.562 ms.
Prepared contexts attached in 0.008–0.009 ms. Worker preparation of the
three faces took 19.041–20.124 ms after the first run. Repeat attachment
of the actual entire HUD with prepared faces took 0.763–0.896 ms.
The first measured HUD attach in that already initialized GL process was
7.540 ms. These results do not represent cold game start or total frame
pacing.

#275 merged as `91175f0f`. The reviewed tree matches the merge and local main
is synced. Final Linux, Windows, macOS, dependency review and CodeQL passed.
