# Map catalogue: historical reconstruction and evidence limits

Current server map list: [map-catalog-5517.md](map-catalog-5517.md) (2026-10-10).

## Authority correction — 2026-10-09

The [native identity/flags audit](map-identity-flags-native-5517.md) supersedes this document's earlier
claims of retail map-identity proof. All eight base-terrain coordinate comparisons were reproduced,
but **fitting legacy server coordinates to native terrain does not establish a retail server binding**.
The client receives world MapId, terrain MapDataId and 64-bit flags independently. GameMap.dat indexes
terrain keys; it is not the retail server's world-map catalog.

The historical276-row reconstruction is reproducible from the checked-in273-row SQL baseline plus
three migration additions. All selected terrain keys resolve. Its retail completeness, assignments
and per-map flags remain unverified. The migration and implementation are unchanged by this audit.

## Method and its limits

The historical work tested database trap/NPC/portal/type1003 action coordinates against DMap base
terrain. This can show a candidate is geometrically compatible or expose an inconsistency; it cannot
prove that the coordinates or candidate assignment came from the retail 5517 server. Native placement
need not always use a walkable base cell, and runtime overlays also exist. Later6270 data supplied
candidates only; it does not close the authority gap.

## Map flags were truncated to 32 bits

`MsgMapInfo` (1110) sends map flags as two dwords, and the client keeps them as one 64-bit value
across `CGameMap+0xE8` (low) and `CGameMap+0xEC` (high). `cq_map.type` was `INT UNSIGNED`, so the
high dword could never hold anything, and the whole managed chain (`MapDefinition.Flags`,
`MapProperties`) was `uint`.

Bits above the low dword have verified consumers in this build:

| bit | effect |
|---|---|
| high `0x10` | selects UI post `0xDE1` vs `0xDE2` |
| qword `0x0000004000000000` | `CHero__RefreshEquipmentDerivedStats`, posts `0x445`/`0x446`/`0xDA4`, client replies MsgAction 408 |
| qword mask `0x00000081A0000000` | delayed transition predicate `0x732A44`: low bits 31/29 OR high bits 0/7 |

Widened to `BIGINT UNSIGNED` / `ulong` by migration
`20260818_03_widen_map_flags_to_64_bit`. Values were preserved exactly (checksum compared across the
`ALTER`), and readiness now pins the width.

## Eight historical mapdoc corrections — candidate retail bindings

Each candidate improves compatibility with the legacy placed coordinates. The original 5517 terrain
recheck reproduced the following counts; it did not authenticate those world-ID assignments. Counts
are walkable base cells/total:

| map | was | now | evidence |
|---:|---:|---:|---|
| 1051 | 1051 `riskisland` | 1079 `mys-island` | portals 0/6 → 6/6 |
| 1500 | 1500 `mine-a` | 1734 `fairylandPK-06` | NPC 0/1 → 1/1 |
| 1502 | 1502 `mine-c` | 1735 `fairylandPK-07` | NPC 0/1 → 1/1 |
| 2021 | 2021 `Dgate` | 1501 `mine-b` | traps 0/16 → 16/16 |
| 2022 | 2022 `Dsquare` | 1500 `mine-a` | traps 12/16 → 16/16 |
| 2023 | 2023 `Dcloister` | 1501 `mine-b` | traps 0/16 → 16/16 |
| 2024 | 2024 `Dsigil` | 1500 `mine-a` | traps 0/16 → 16/16 |
| 2080 | 2080 `Nhouse03` | 700 `arena-none` | teleports 2/8 → 8/8 |

Before these changes all eight rows had `mapdoc == id`. Equality alone is not proof that a fallback
created them or that an identical pair is wrong.

The old text incorrectly said all traps on2021–2024 were blocked under the old terrain. Map2022
already had12/16 walkable points. The revised mine candidates fit16/16 on all four maps. This supports
a candidate; it does not uniquely identify the retail binding or prove the old coordinates authoritative.

### Four same-path aliases do not prove equal world identities

Maps 1080, 1081, 1511 and 5000 disagree on the mapdoc *number* but both values resolve through
`GameMap.dat` to the **identical map file** (`p-arena.7z`, `p-arena.7z`, `forum.7z`, `mine-one.7z`).
This is a terrain-path equivalence observation, not proof of the server-sent numeric key or world
identity. Nothing was changed; the native index and companion values must still be kept distinct.

### Map 1501 is unresolved, deliberately

The historical audit identified an NPC at (84,60) and a type1003 action destination at (78,59).
Both were rechecked and are walkable under either candidate (1501 `mine-b` 184×184, or
1730 `fairylandPK-02` 96×96). The legacy map-row name is the column default. The sibling candidates and retail `GameMapEx.ini` names `ClassPKArena1/2/3` are thematic support
only. Neither 1501 nor 1730 is a proven retail assignment for world 1501; the migration left it alone.

## Historical revive-point changes (not re-audited in the identity slice)

`cq_map.portal0_x/y` is the revive coordinate **of maps used as a `reborn_map` target** (TQ 15.10 `CGameMap__GetRebornMap`; other rows' portal0 is unused for revive — see [death/ghost/revive](death-ghost-revive-5517.md#5-revival-destinations)). Of the 73 maps that defined one, **only 41 were
walkable** — 13 blocked and 19 out of bounds, mostly one coordinate copy-pasted across maps of
different sizes (`566,565` onto maps 550, 424 and 302 wide). Those 32 were cleared: a revive point
inside geometry is worse than none.

The reference database offered candidates for 53 of the 200 maps with none. **Only 24 survived the
terrain test** — 13 blocked, 16 out of bounds. Those 24 were added; the rest were discarded. Valid
coverage went 41 → 65 of 276 maps. 147 maps still have no candidate from any source.

`reborn_portal` is `0` on every row and is not used as a `cq_portal` index anywhere.

## Historical portal changes and withdrawn authority claims

The earlier report rejected three of four later-source portal candidates using base-cell passability
(map1002 indices4/5 and1212 index32), with a tie for the fourth. This records the historical selection
method; it does not prove the retained coordinates were retail 5517 values. They were not changed.

Six world IDs had portal rows but no `cq_map` row. The historical migration treated them as follows:

- **1782, 1783, 1794** carry our own NPCs and traps and were simply missing from `cq_map`. Their
  candidate terrain assignments were supported by that content fitting the native terrain (5/6, 15/15 and 1/1 walkable under
  docs 1004, 1004 and 1028). Rows were restored with `type = 0`, because no evidence establishes
  their flags. The 0 values are placeholders, and retail identity remains unproven.
- **1778, 2204, 7007** were absent from the checked catalog/index/reference and their 7 portal
  rows were deleted. The earlier “exist nowhere” claim is withdrawn: a world ID need not have an
  equal GameMap.dat key, and absence from these datasets does not prove absence from retail.

`cq_portal` now has no row referencing an undefined map, and readiness enforces that.

## Still open

- Map 1501's mapdoc, as above.
- 149 map ids exist here and not in the 6270 reference, and 132 the other way; the two catalogues
  share only 124 ids, so that database is not a source for map *content* at this version.
- `cq_map.name` is the column default on nearly every row — the names carry no information. Only
  map 5000 (`NPCJail`) has a real one.
- 147 maps have no revive point and no candidate anywhere.

## Additional source reconciliation — 2026-10-10

The [full zf audit](zf-map-reconciliation-5517.md) supplies new legacy evidence, not retail authentication:

- zf agrees with1051 and2021–2024 candidates;1500,1501,1502 and2080 are absent.
- Its1782/1783/1794 rows agree on terrain keys and contain flags14/14/70, whereas the reconstruction
  uses zero placeholders. Their retail flags remain unproven.
- It defines1778→1013,2204→1734,7007→1762. The earlier absolute absence claim was false.
- Deleting the seven historical portal rows leaves passways160/161 with missing map1778 destinations
  at portal indices1/2. The remaining-portal catalog check does not cover this relationship.
- Legacy actions3000124/type302/data1501 and3000298/type303/data1501 also reference1501. They add
  PK-war usage context but no coordinate that distinguishes mine-b from fairylandPK-02.

The migration remains unchanged. Statements above about absent candidates or current readiness are
historical observations of the earlier dataset, not assertions about every available source or a live
database. In particular,32-bit SQL capacity does not itself prove that any given stored low-word value
was truncated from a nonzero retail high word.
