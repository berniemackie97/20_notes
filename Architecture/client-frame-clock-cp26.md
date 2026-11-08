# CP2.6 — client frame clock

Base OCC `ae739cb8`. Game code used the desktop render delta, operating
system tick counters, Stopwatch and separate default time providers.

Native packet timestamps use wrapping unsigned milliseconds
(`Network/bootstrap-tolerance-cp24d.md`, action builder 0x6FE99C,
heartbeat 0x661ADD, item reply subtype 27 and report builder 0x743FED).
The same origin must reach existing-character and character-creation
bootstrap, echoed latency and the client-start report timer. Packet
stamps are sampled when generated. World presentation and ingress use
a single monotonic sample per frame. The native PK phase and expiry
reads stay independent. UTC still gates signed discovery and its
rollback protection. Host event scheduling and low-level socket
deadlines retain their existing platform behavior.

The frame sample is taken at the client session boundary. Its elapsed
time drives the login and role timelines. Its wrapping milliseconds
drive ingress and world preparation/draw. The map scene uses the sample
from world handoff as its scenery epoch so background completion cannot
put the epoch ahead of the first presented sample. Independent native
PK blink reads still come from the same provider. Render-context setup
and view recreation do not reset the clock.

Signed catalog fetch and the overall world-entry deadline use
provider-driven timers. External cancellation still wins over timeout
translation. A canceled bootstrap cannot leave a partial ladder reusable,
even when the cancellation arrives between socket operations.

PK phase and expiry anchors are recorded in
`Rendering/17_main_hud_action_strip_native_contract.md` (phase frame
0x4BCAE4, expiry frame 0x4BCB04). No native database edits were needed.
The new tests exercise fractional monotonic conversion and wrap, the
530/1000 ms caret cycle, deterministic deadline vs. caller cancellation,
and exact world-entry +16 stamps across wrap. The socket peer still
checks 408's zero and 251's version word. Full OpenGL conformance passed
against the read-only clean 5517 payload, including 18 quickbar hashes.

Local Release build, format, and 3,764 tests passed. A 420-frame
desktop probe used the new clock with the production admitted world,
injected movement and equipment packets, and verified all 20 armor
switches. It rejected context-thread content opens. It does not cover
external authentication. Logs are in the ignored client
`artifacts/cp26-world-probe/` directory.

OCC #280 at `242d5a47` passed Build Bouncer, Linux, Windows, macOS,
dependency review and CodeQL. It merged as `ce70e61b`. Local main
matches the reviewed tree and #242 closed.
