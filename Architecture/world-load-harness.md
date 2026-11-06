# World command load harness — CP1.4 pre-flight

2026-11-05. Modern measurement policy (ledger kind M), not native 5517 server
performance or a new wire/gameplay contract. Baseline OCS `718eaf7` after CP1.3.

Pre-flight: `Architecture/implementation-evidence-ledger.md` marks world partitions
and `world-execution.md` modern. Historical thread/timer evidence remains in
`Server/tq-server-binaries-2008.md`; no native lock/allocation equivalence is claimed.
Existing walking orientation: `Network/15_msgwalk_10005_direction_index_order.md`,
client tables `0x86C608` / `0x86C628`: directions 0 and 4 are opposite ground steps.
No new native fact, symbol rename, function comment or BNDB save is required.

Measure the actual WorldRuntime admission/walk path with synthetic, in-process
resident characters across M maps. Each logical session has at most one command
in flight. Alternate opposite steps on a bounded synthetic walkable grid; warm up
before sampling and verify every result and final position. No sockets, WorldSession
pacing, replication, content I/O or database work in this harness.

Record completion and synchronous-submission p50/p99, throughput, current-thread
bytes allocated during submission, and process-wide bytes per completed command.
The process-wide value includes harness/scheduler costs; neither value proves a
particular lock is the bottleneck. Allocate sample arrays before the measurement
window; do not use thread-local counters across an await. Fail a trial on a refused
or lost move rather than silently excluding failures from percentiles.

Run repeated fixed-count scenarios at fixed worker/queue/turn limits, varying
sessions and maps. Include environment/settings/raw results and a short decision
in OCS docs/architecture. Change no production locking or command representation
until measurements justify it. D4 remains a measured decision, not an assumption.

Results: 36 isolated trials, 37,748,736 measured walks, all validated. Apple M4 / 10
logical CPUs / Arm64 macOS 26.6.2 / .NET 10.0.14 / SDK 10.0.403 / workstation GC.
Source `2a406b2387d6d3b7e7fcaa7c825af888a7f15a3c`; starting tree clean.
Synchronous submission ~336 B/walk; process medians 336.0–358.2 B/walk including
harness/scheduler. At 1,024 sessions / 4 workers, median per-trial completion p99:
1 map 1.970 ms; 8 maps 2.921 ms; 32 maps 2.151 ms. Three trials per scenario.

Decision accepted through merged OCS #190: retain the gate, allocating commands and worker policy. This
closed-loop in-process workload has no sockets, pacing, visibility or DB; no
production arrival-rate/latency/allocation budget or gate attribution is established.
No production runtime behavior changes. Raw manifest, reports and summary are in OCS
`docs/architecture/evidence/world-load-2026-11-05/`; interpretation and commands in
`docs/architecture/world-command-load.md`.

Validation: zero-warning Release build, locked restore and format clean; new tool
11 tests and existing GameServer 873 pass. Status: local implementation/measurements
complete; [OCS #190](https://github.com/berniemackie97/OpenConquerServer/pull/190)
opened from `c78b437`; CI passed (Verify including database tests, dependency
review and terrain integration). Bernie confirmed completion and merged #190
(`7407c71`) on 2026-11-05. CP1.4 is closed; CP1.5 is current.
