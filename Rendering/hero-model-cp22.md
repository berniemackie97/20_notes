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

Target: WorldHeroModel owns hero attributes/equipment/revision, pending equipment
clamp and followers. WorldInboundState remains the current wire adapter. The model
returns a world-owned resolved vitals value; ClientWorld only maps it to HUD input
at the existing guarded draw point after scene.Draw. Keep initial transform-source
zero guard, neutral life-tier input, catalog-loading point and follower cadence.
Reuse existing item/max-stat formulas with native citations beside their constants.

Known residual for CP2.3: one deferred snapshot-clamp flag loses inter-packet order
when a later life update arrives in the same ingress batch. Native clamps inside
the snapshot handler; managed content tables are unavailable during early loading.
This slice fixes signed clamp/reset semantics at the existing consumption boundary;
it does not add a queue, reorder ingress/loading or claim full packet-order parity.

Also defer the inconsistent snapshot-slot ordering descriptions in old note 14
versus the current ascending-slot implementation to the typed 1009 audit. No
unverified slot-order change is needed for the summed stat calculation here.
