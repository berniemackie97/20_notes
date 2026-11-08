# Hero model extraction — CP2.2

2026-11-06 pre-flight at OCC `3d7144b6`. Reuse notes 13/14/15; no new
transformation, refinement, life-tier, codec or content-loading feature is opened.

## Native revalidation

Clean Conquer.exe and the BN input-file mirror both SHA-256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Active Binary Ninja view 9 is Conquer.exe.bndb. Recorded instruction bytes were
checked against the on-disk clean PE by `evidence/hero-model-2026-11-06/verify-code.py`.
This is static byte/control-flow verification, not native runtime or framebuffer observation.

| Rule | Native anchor |
| --- | --- |
| Life vitality weight 8, attribute sum multiplier 3 | `0x65D0C6`, `0x65D0DC` |
| Life profession `%1000 /10 ==1`, rank `%10`, percentages 5/8/10/12/15, signed `/100` | `0x65D0D1..0x65D129` |
| Mana default 5; unsigned family `>10`; rank multipliers 10/15/20/25/30 | `0x65D290..0x65D2EA` |
| High map bit 38 override vs low overlay mask `0x400000` | `0x6206C8`, `0x61DFF5` |
| Life override also accepts transform look; mana does not | `0x65D07D..0x65D0AC`, `0x65D25E..0x65D284` |
| Signed item life/mana, unsigned addition life, 18 slots, exclude slot 12 enchantment | `0x65D14B..0x65D1C3`, `0x65D2EC..0x65D309` |
| Life tiers 0/100/200/300/400/500/600/800/1000/1200; final signed floors | `0x65D1DF..0x65D245`, `0x65D30D..0x65D315` |
| Initial stamina base 100; status index 33 selects uint32 `(base*3)>>1`, giving 150 | store `0x6570A9`; `0x66F766`; `0x66F792` |
| Status index 33 selects bit 33 of the low status qword, not the high qword | `Role_HasStatusFlag` `0x6E50D4`: dword index `index>>5`, mask `1<<(index&31)` |
| Current stamina is signed upper-only min; no zero floor | `0x66F77C..0x66F791` |
| HP/MP followers use signed max/80-or-1 and signed min(current), wrapping add | `0x65E128..0x65E167`, `0x65E1C9..0x65E24C` |
| Snapshot life clamp uses signed current>max, no max>=0 guard; actual clamp sets current AND HP follower to max | `0x6EC485..0x6EC4C7`, especially CMP/JLE `0x6EC49A/0x6EC49C` |

The managed baseline's clamp only changed current life, used an unsigned compare
and rejected negative maxima. Correct these proven differences in the extracted
model. Equal/below-maximum snapshots must not reset the follower; MP is not reset.
Native max stamina reads a field initialized to 100; the present managed scope
supports that baseline and its status multiplier, not a newly invented dynamic cap.

## Tool annotations before code

Six function comments updated/read back: effective max life/mana/physical force,
capped physical force, per-frame tick, and CMsgItem__Process. Instruction comment
at `0x6EC485` corrected/read back. Existing proven names reused; zero renames needed.
Old map-helper references in life/mana comments now name the high-bit predicate.
No BNDB save initiated; Bernie retains persistence control.

## Model boundary and limitations

WorldHeroModel owns hero attributes, equipment, revision and followers. At CP2.2
it also held the pending equipment clamp. WorldInboundState is the wire adapter. The model
returns a world-owned resolved vitals value; ClientWorld only maps it to HUD input
at the existing guarded draw point after scene.Draw. Keep initial transform-source
zero guard, neutral life-tier input, catalog-loading point and follower cadence.
Reuse existing item/max-stat formulas with native citations beside their constants.

`AdvanceVitals(ItemStatCatalog, LevelExperienceTable, ...)` accepts already-parsed
tables, mutates model vitals and returns a world DTO. No rendering, I/O, tasks or
HUD dependency. The name describes model work; frame cadence remains a caller
contract. Rules remain in the client's World layer under the existing assembly
structure. `WORLD-027` records the responsibility boundary and per-rule anchors.

**Current snapshot contract.** CP2.3b moved the signed life clamp into the
subtype-46 handler after the equipment changes. A later life update in the
same ingress batch keeps its value. The old CP2.2 pending flag was consumed at
draw time and could clamp that later write. The snapshot's offset-to-slot map
is ascending. Native calls slot 5 before 4 and slot 16 before 15. These are
distinct from the packet's field order. [CP2.3b static audit](../Network/typed-world-dispatch-cp23.md#cp23b-snapshot-slot-audit)
[Accepted CP2.3b](https://github.com/berniemackie97/OpenConquerClient/pull/260)

Two-handed displacement and tracked-item ownership remain separate open work.
[Displacement #262](https://github.com/berniemackie97/OpenConquerClient/issues/262)
[Ownership #264](https://github.com/berniemackie97/OpenConquerClient/issues/264)

## CP2.2 implementation validation

OCC branch `bernie/hero-vitals-model`: 12 new test cases; static-disassembly-derived
fixture covers 20 maxima and 8 stamina vectors. The pinned original encoded
type-50000 row is reused; equipped-armor and experience tables/packets are synthetic
independent encodings. Provenance is explicit in the fixture README. The byte
verifier also checks the five code windows embedded in the managed JSON fixture.
No native runtime execution or running-client smoke is claimed.

Local SDK 10.0.403: locked restore and zero-warning Release build passed;
Client 1,497, Content 750, Rendering 499, Platform 86 tests passed (2,832 total).
Final format verification and self-audit passed at `165e91db`. CI run 1002
passed Quality (Linux), Windows, macOS and dependency review. Private retail-asset
gates were conditionally skipped. [CP2.2 PR #238](https://github.com/berniemackie97/OpenConquerClient/pull/238)
merged as `e6f344c4696ef3de8e46cdcf2e97b47e9491ec83` and the later CP2.3b contract
above supersedes the deferred clamp timing.
