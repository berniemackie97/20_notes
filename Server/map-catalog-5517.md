# 5517 world-map catalog (server working profile)

Built 2026-10-10 (rev 2). Evidence + build: [`10_work/docs/evidence/map-catalog-5517/`](../../10_work/docs/evidence/map-catalog-5517/README.md).
Supersedes the 276-row reconstruction and the zf "practical profile".
Authority: clean 5517 client (what shipped) > TQ server data > emulator data.

## Native anchors (clean 5517 client)

| Fact | Evidence |
|---|---|
| `GameMapEx.ini` keys = **world MapIds** (282) | GameData `0x10007906` (RoleData vtable+0x80, table +0x144) ← Conquer `0x5305B4`/`0x530A3D` (SuperFlag record map id); 108/282 keys are not terrain keys |
| GameMapEx not exhaustive | client data references 6072, 2061, 2065, 2092 |
| Hard-coded world IDs | 601 `0x5C6A36`/`0x5C6B23`; 1002 `0x732DBB`, `0x4884B9`; 1036 `0x5C6BB5`; 1039 `0x620850`; 1858 `0x6F63D4`; 1860 `0x6F63E7` |
| Hard-coded terrain keys | 1037 `faction-black.7z`, 1038 `faction.7z` (`0x6F922C`/`0x6F923C`, getter `0x6E5E2C`=+0xE4) |
| World coordinates | 332 points (`Questinfo.ini`, `MapDestination.dat` seed 0x2537, `MapRelationInfo.ini`) |
| Exits | DMap `count×{x,y,passwayIdx}` after grid; 373 (world, idx) pairs |
| Walkability | base grid + type-1 scenery overlays (tail passability, path rule `tail==0`); 170 terrains, 10,650 groups, 83,650 overlay cells, 0 missing list files, 0 unknown subcomponent types |

Client history (archives 4267–6609): GameMapEx first ships in 5355, identical key set through 5517-2;
6090/6300 = 286, 6609 = 287; none of the 282 removed. Per-version GameMap.dat keys and points:
`client-version-map-data.json`.

## Flag readers (complete census, Conquer.exe `b6ba5ab8…`)

Map object = heap singleton `[0x955F9C]` (accessor `0x410685`). Flags: low `+0xE8`, high `+0xEC`.
- Getter `0x61F2DA`: 33 direct call sites (`map-identity-flags-native-5517.md`).
- Inline `GetType()&mask` (singleton → `+0xE8/+0xEC` → `and`): 18 sites, linear sweep of `.text`
  (1,410,672 instructions). Raw windows: `native-flag-inline-consumers.asm.txt`.
- Inside the CGameMap TU `+0xEC` is touched only by ctor `0x61BB32`, setter `0x61F2D1`, getter `0x61F2E0`.

Bits read in 5517: 0, 3, 4, 6–10, 13, 15, 18, 21, 22, 25–29, 31–40. **No reader of bits ≥ 41.**
New from inline census: 13, 15, 26, 34, 35 (and 31, 36 extra sites).

| Bit | Name (source) | Getter-site | Inline | Maps set (5517) | Maps with bit only in source value |
|---:|---|---|---|---:|---:|
|0|PkField (MAPTYPE_)|`0x6206FD`|—|65|0|
|1|ChangeMapDisable (MAPTYPE_)|—|—|176|0|
|2|RecordDisable (MAPTYPE_)|—|—|115|0|
|3|PkDisable (MAPTYPE_)|`0x620892`|—|38|0|
|4|BoothEnable (MAPTYPE_)|`0x70B00B`|—|1 (1036)|0|
|5|TeamDisable (MAPTYPE_)|—|—|10|0|
|6|TeleportDisable (MAPTYPE_)|`0x6207EE`|—|39|0|
|7|GuildMap (MAPTYPE_SYN_MAP)|`0x62085B`|—|1 (1038)|0|
|8|PrisonMap (MAPTYPE_)|`0x620828`|—|7|0|
|9|WingDisable (MAPTYPE_)|`0x6F52D6`|—|8|0|
|10|Family (MAPTYPE_)|`0x6D9739`|—|0|0|
|11|MineField (server MAPTYPE_)|—|—|48|0|
|13|RebornNowEnable (Long)|—|`0x576B70`, `0x65D858`, `0x65D924`|119|0|
|14|NewbieProtect (Long)|—|—|3|0|
|15|—|—|`0x66F92D`|1|0|
|16, 17, 19, 20, 30|—|—|—|44, 10, 9, 41, 38|0|
|18|—|`0x716FE3`|—|26|0|
|21|ArenicMap (Long)|`0x620785`|—|1|0|
|22|DoublePkMap (Long)|`0x61DFF5`|—|0|0|
|25|RaceTrackMap (Long)|`0x61F2E7`|—|5|0|
|26|—|—|`0x65EC59`, `0x6C4AB5`|0|0|
|27|FamilyArenicMap (Long)|`0x6207CB`|—|1|0|
|28|FactionPkMap (Long)|`0x61F305`|—|5|0|
|29|EliteMap (Long)|`0x6207A8`|—|1|0|
|31|—|`0x732A4D`|`0x62631F`, `0x6E79B3`|0|0|
|32|TeamPkArenicMap (Long)|`0x62080F`|—|0|0|
|33|—|`0x6F6696`|—|0|0|
|34|—|—|`0x5B06B7`, `0x5B31CC`|29|0|
|35|—|—|`0x5B0C7C`|28|0|
|36|—|—|`0x626345`, `0x732CD7`|0|0|
|37|TeamArenaMap (Long)|`0x620693`|—|0|0|
|38|BattleEffectLimitMap (Long)|`0x6206C8`|—|0|0|
|39|TeamPopPkMap (Long)|`0x6206AC`|—|0|0|
|40|NoExpMap (Long)|`0x6206E1`|—|16|0|
|41, 42, 44, 46, 47, 50–54|GoldenLeague…(41), ForbidCamp(44), JiangHu(46) (Long)|—|—|0|1, 4, 3, 10, 7, 6, 8, 9, 12, 1|

MAPTYPE_ names: `40_tools/eosource/soul-code/3dgamemap/3DGameMap.h`, `fight-master/my_server/MapGroupKernel/GameMap.h` (bits 0–11).

### Flag fields per row

| Field | Meaning |
|---|---|
| `flags_source_value` / `_hex` | full 64-bit value of the chosen source row, unaltered; null = no source row |
| `flags_5517` / `_hex` | working wire value = source & (2^41−1); bits ≥41 have no 5517 reader |
| `flags_5517_cleared_ge41` | bits present only in the source value (34 maps) |
| `flags_basis` | `L` 206, `PX` 14, `sibling L <id>` 5, `T7` 3, `Z last resort` 6, `DEFAULT_ZERO_NO_SOURCE` 48 |

48 default-zero rows: 1768, 1769, 1812, 1961–1989 (Mausoleum), 2065, 8822–8839 (FiendLair). Zero = explicit default,
not recovered data. No TQ-lineage `cq_map` row exists for them in any local source (6,553 archives swept) or public code search.

## Sources

| Tag | Source | Class | Rows |
|---|---|---|---:|
| T7 | `ZfServer/MYSQL/data/cq` MyISAM (MsgServer `2007,1210,0,123`, PE 2008-04-18, files 2008-10-26) | TQ Chinese 2007/08 | map 202, passway 273, portal 259, npc 659, trap 424 |
| L | Long v6270 `game_cq.sql` | TQ-English lineage, later | 256 |
| C | Canyon v6192; also Canyon 2023 dump, OpenLong cq6135v2, Comet `conquer.sql` | = L (subsets) | 256 |
| EU/B | Project-X `Database[EU]/maps`, HowmuchConquer 5517 `Database5517/maps` | emulator, TQ-English-derived | 268/250 |
| Q | `client-5517/conquer.sql` (= Fox zf.sql) | community; 73 rows = keys promoted to worlds | 273 |
| Z | `Archives/zf.sql` | Wolf-War private server | 306 |
| A | Albetros 1.1 | 5165 emulator | 216 |

## Rules

MapDataId: L > T7 > sibling/geometry rule > PX > identity > unavailable. Identity base rate: 100 of 112 TQ rows whose
world id is a shipped key bind identity; all 12 exceptions are same-file aliases (1080, 1081, 1511, 5000) or keys owned
by another family (1051, 1500–1502, 2021–2024). No identity row's key is used by another catalog world.
Rejected rows: L 2075 (later CastleWar reuse), EU 1987–1989 (LotteryMap/Quest reuse), Z 1951→1950 (own teleports unwalkable).

## Result (289 world IDs)

| Conf | Meaning | Count |
|---|---|---:|
| A | L and T7 agree | 154 |
| B | L only / L over T7 / T7 only / L geometry | 56 |
| C | sibling rule or Project-X | 19 |
| D | identity, no TQ row | 53 |
| U | unavailable | 7 |

### Fit validation on chosen terrains (base + overlays)

| Point set | Tested | In bounds | Walkable |
|---|---:|---:|---:|
| 5517 client data | 328 | 326 | 301 |
| clients 5355, 5517-2, 5615 | 516 | 514 | 484 |
| clients 6090–6609 (advisory) | 618 | 612 | 412 |
| L placements (npc, dynanpc, trap, portal, action 1003) | 2689 | 2648 | 2275 |
| T7 placements (npc, trap, portal) | 1301 | 1300 | 1237 |

Out of bounds: 1039 TrainingGround — 37 L dynanpc + 1 T7 npc at x/y 496–551 beyond `playground.7z` 496×496
(both TQ lineages bind 1039→1039; 801/838 fit). 2075 — 3 L points belong to L's later CastleWar reuse. 5000 — 1 of 138.
5517 client data defects: MapDestination `1013-3` (55,387) (tiger exit 0 is (55,87)); `2060-1` (567,579) on 264×264.

Long's own placements on catalog-only IDs: 1073 (5 pts) fit only keys 1017, 1090 → sibling 1090 holds; 1074 3/3 on 1091;
1769 8/8 on identity; 1926 10/11 on 1762; race regions 1950, 2061–2065 inside identity terrains.

## Open questions answered

| World | MapDataId | Basis |
|---:|---:|---|
| 1051 | 1079 | A |
| 1500 / 1501 / 1502 | 1734 / 1730 / 1735 | B: L; ClassPKArena4–10 also 1730/1734/1735; 1500–1503 = mine floor terrains of 2000–2053 |
| 2021, 2023 / 2022, 2024 | 1501 / 1500 | A |
| 2080 | — | no client evidence as a world ID (not in GameMapEx, no coordinates, 4267–6609); 2080 ships only as a terrain key (5355+). Held |
| 1778 DangerCave | 1013 | B: L passway/portal geometry (only `tiger.7z` fits) |

## Unavailable (no terrain selected)

Treated as unreleased/dev/unfinished maps (Bernie 2026-10-10): server must not load or route to them. 2092 is not
Desert City (DC = 1000); its candidate stays unapplied.

| World | Name | Evidence state |
|---:|---|---|
| 1807–1810 | LockerRoomA, MalePKArena, LockerRoomB, FemalePKArena | no row, no coordinates, no GameMap key in any client 4267–6609 |
| 1889 | CouplesPKGround | one point NPC 6169 (52,46) (5187–5615); fits 39 terrains |
| 1951 | RockMonsterDen | only Z teleports; fit 1204, 1205, 1360, 1857 |
| 2092 | (unnamed quest map) | 6 points 5355–6609 fit 11 terrains; never a GameMap key; Desert City NPCs; 6090 Nezha (507,725) = 5517 Nezha cell on 1000. Candidate 1000, not applied |

## Passways (one row per native exit index, sources L, T7, Q, Z)

| Status | Count |
|---|---:|
| valid (L 258, Q 62, T7 2) | 322 |
| target base+overlay blocked, all four sources agree: 1015 idx10/15 → 1015 p33 (511,533); 1077 idx0 → 1000 p4 (159,467) | 3 |
| no row, terrain shared with a world that has one: 1073 (1090), 5000 (1025), 5002 idx2/3/7/8/9 (1002) | 7 |
| no row in any source: Mausoleum idx0 ×24, 1769 ×5, 2055 ×2, 601, 1550, 1551, 1765, 1768, 1784, 1791, 1818, 1999, 2054 | 41 |

54 source passways name exit indices absent from the bound 5517 terrain (e.g. 1002 idx 0/1/4/5/6 in all four sources):
inert — the client only sends indices from its DMap exit list (`map-transitions.md`).
Source world 1762 is read as 5517 world 1926 (FrozenGrotto1 renumbering); FG passways validate.
portal0 (`cq_map.portal0_x/y`) base+overlay walkable on 144/282 rows. Consumers (TQ 15.10): `CGameMap__GetRebornMap` reads the
**reborn target** map's portal0 (revive destination), `CUserList__CreateNewUser` map 1010's; see [death/ghost/revive](death-ghost-revive-5517.md#5-revival-destinations).

## Binja

Saved (survived restart): rename `RoleDataSingleton_GetGameMapExNameByWorldMapId` (GameData `0x10007906`) + function
comment; Conquer comments `0x5305B4`, `0x530A3D`, `0x6F63D4`, `0x6F922C`.
Applied 2026-10-10, in memory until GUI save: inline flag-reader comments at `0x576B70`, `0x65D858`, `0x65D924`,
`0x66F92D`, `0x65EC59`, `0x6C4AB5`, `0x62631F`, `0x6E79B3`, `0x5B06B7`, `0x5B31CC`, `0x5B0C7C`, `0x626345`, `0x732CD7`.
Map singleton accessor `0x410685` already named (`…Map_GetSingletonPtr`).
