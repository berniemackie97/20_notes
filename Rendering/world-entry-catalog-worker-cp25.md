# CP2.5b — world entry catalogs

Baseline OCC `72aa22f9`. `ClientWorld` opened and decoded the item tables in
its frame-thread constructor, before replaying the authenticated entry
snapshot. It loaded the experience table on map completion, also on the
frame thread.

This slice changes managed scheduling. The parsers, source selection,
bounds and hydration rules carry forward. Existing item semantics are in
`../Network/inbound-tolerance-cp24.md` (native `0x67AD6B`, H4/H7).
Experience provenance is in OCC WORLD-028 and `../Network/01_core_packets.md`.
No new native claim or database annotation is needed.

One world-owned job loads both catalogs while the existing map job runs
independently. The frame observes completion before constructing the hero and
replaying hydration. The ingress retains its single prefetched frame until
hydration is complete and surfaces an early receive failure. The world retains
both jobs through cancellation and reaping.

Baseline probe on Apple M4 used the installed curated 5517 content and the
production catalog APIs. First item-table load took 41.229 ms, followed by
1.189 ms for experience. Each was previously synchronous frame work. Input
files and lookups are verified with the same probe after the move.

## Retail handoff comparison

Twenty repeat runs on Apple M4. Synchronous caller 20.020–32.568 ms.
With the worker, the maximum per-repeat submit/poll/take call was
0.003–0.020 ms. Worker elapsed 20.075–32.688 ms with 1 ms poll waits.
First call in each process was 43.770 ms synchronous and 0.796 ms
caller time with the worker. This excludes hydration and all drawing.

Both paths matched the same curated-file lookups: item 130003 requires
level 15, item 120020 addition 9 gives 239 life, and level 1 / 100
experience requirements are 120 / 68391931.

| Input | SHA-256 |
|---|---|
| `ini/itemtype.dat` | `90e9c983b0f78337f20720a3cf61d8f1392f23979565da14eb01dc514e3a71e7` |
| `ini/ItemAdd.ini` | `eeaf14aa1657869f8a0217a9775815757dd17992f39b242a7fb0e6e641da51f8` |
| `ini/levexp.dat` | `df41c576aa47dda77bb8d02b434cdee2b9deac32f2c34934aa2faae1f2c28283` |

OCC #272 at `43e36af3` is ready for review. Local locked restore, zero-warning
Release build, format verification and 2,983 focused tests passed. CI passed
Linux Quality, Windows, macOS, dependency review and CodeQL.

#272 merged as `db3e47d4`. Local main matches the merged tree, and the
final checks passed.
