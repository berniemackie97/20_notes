# Map catalogue: what was wrong and how it was proven

## Method

Every conclusion here comes from testing coordinates **this database already places on a map** —
traps, NPCs, portals and type-1003 teleport actions — against the client's own DMap terrain, read
through `OpenConquer.MapAssets`. A coordinate that is impassable (`PassabilityFlag != 0`) or out of
bounds proves that either the map identity or the coordinate is wrong. That is a decidable test, not
a preference.

A later 6270-era reference database was used only to *propose* candidates. It was never trusted:
the terrain test rejected most of what it offered.

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
| `flags_high & 0x81` | delayed transition-gate predicate |

Widened to `BIGINT UNSIGNED` / `ulong` by migration
`20260818_03_widen_map_flags_to_64_bit`. Values were preserved exactly (checksum compared across the
`ALTER`), and readiness now pins the width.

## Eight mapdoc values were wrong

In each case our own placed content is impassable under the mapdoc we recorded and fully walkable
under the corrected one. Counts are walkable/total:

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

In every wrong row `mapdoc` equalled `id`, which is what the fallback looks like.

**A filename reading was overturned by this test.** Maps 2021–2024 pointed at `Dgate`, `Dsquare`,
`Dcloister` and `Dsigil` — a coherent-looking family, which is why they initially read as correct.
The terrain says otherwise: the 16 traps on each map are *entirely* impassable under those docs and
entirely walkable under the mine docs, and a trap layout spanning x 12–168 fits a 184×184 map rather
than occupying the corner of a 550×550 one. Plausible naming lost to measured geometry.

### Four apparent conflicts are not conflicts

Maps 1080, 1081, 1511 and 5000 disagree on the mapdoc *number* but both values resolve through
`GameMap.dat` to the **identical map file** (`p-arena.7z`, `p-arena.7z`, `forum.7z`, `mine-one.7z`).
Ours is already correct; nothing was changed.

### Map 1501 is unresolved, deliberately

Only two coordinates exist for it — one NPC and one teleport — and both are walkable under either
candidate (1501 `mine-b` 184×184, or 1730 `fairylandPK-02` 96×96). Its name is the column default,
and no other table references it. Its two siblings 1500 and 1502 are proven to be fairylandPK maps,
which makes 1730 *likely*, but likely is not proven and it was left alone.

## Revive points

`cq_map.portal0_x/y` is the revive coordinate. Of the 73 maps that defined one, **only 41 were
walkable** — 13 blocked and 19 out of bounds, mostly one coordinate copy-pasted across maps of
different sizes (`566,565` onto maps 550, 424 and 302 wide). Those 32 were cleared: a revive point
inside geometry is worse than none.

The reference database offered candidates for 53 of the 200 maps with none. **Only 24 survived the
terrain test** — 13 blocked, 16 out of bounds. Those 24 were added; the rest were discarded. Valid
coverage went 41 → 65 of 276 maps. 147 maps still have no candidate from any source.

`reborn_portal` is `0` on every row and is not used as a `cq_portal` index anywhere.

## Portals

Four portal coordinates differ from the reference database. **Ours are right**: three of its four
land on impassable tiles (map 1002 idx 4 and 5, map 1212 idx 32), and the fourth is a tie. Nothing
was changed. Importing them unvalidated would have broken three working portals.

Six map ids had portal rows but no `cq_map` row, and they split cleanly:

- **1782, 1783, 1794** carry our own NPCs and traps and were simply missing from `cq_map`. Their
  identity is proven by that content fitting the native terrain (5/6, 15/15 and 1/1 walkable under
  docs 1004, 1004 and 1028). Rows were restored with `type = 0`, because no evidence establishes
  their flags — only the identity was recovered.
- **1778, 2204, 7007** exist nowhere: no `cq_map` row, no `GameMap.dat` entry, absent from the
  reference database. Their 7 portal rows were deleted.

`cq_portal` now has no row referencing an undefined map, and readiness enforces that.

## Still open

- Map 1501's mapdoc, as above.
- 149 map ids exist here and not in the 6270 reference, and 132 the other way; the two catalogues
  share only 124 ids, so that database is not a source for map *content* at this version.
- `cq_map.name` is the column default on nearly every row — the names carry no information. Only
  map 5000 (`NPCJail`) has a real one.
- 147 maps have no revive point and no candidate anywhere.
