# Historical reconciliation 5095 → 5517 (OpenConquerServer audit)

Verified 2026-10-12 against OpenConquerServer `935725c` (content + migrations identical at `e3514ed`). Evidence + scripts + machine-readable output:
[`10_work/docs/evidence/historical-reconciliation-5095/`](../../10_work/docs/evidence/historical-reconciliation-5095/README.md)
(`difference-inventory.json` 39 findings, `field-mapping-matrix.csv` 114 rows, `unresolved.json`).
Binary semantics: [tq-server-15.10-runtime-semantics.md](tq-server-15.10-runtime-semantics.md). Read-only audit:
no server code, migration or content changed.

## Classes

| Tag | Meaning |
|---|---|
| C5517 | confirmed 5517 behaviour (5517 client binary or shipped 5517 data) |
| X | corroborated cross-version (15.10 binary/5095 data agrees with 5517 evidence) |
| V5095 | verified 5095-only (15.10 binary or 5095 data; no 5517 proof) |
| U | unresolved |

## Sources

| Tag | Source | Notes |
|---|---|---|
| ZF08 | `ZFSERVER.zip` → `MYSQL/data/zf` (105 MyISAM, MySQL 4.0.17) | data = Z lineage (2012 `zf.sql`), see M-01 |
| 5095ini | `ZFSERVER/GameServer/ini` | CN client copy. Server modules read only `GameMap.dat`, `TerrainNpc.ini`, (Npc) `AdditiveSize.ini` |
| 15.10 | `_re/` MsgServer/NpcServer/DLLs | [census](tq-server-binaries-2008.md) |
| 5517 | `00_clean/clean/5517-loader` | authority |
| OCS | OpenConquerServer `content/`, Game DB (docker `openconquer-mysql`, read-only) | |
| pack | `OpenConquer-5095-Server-Evidence-Analysis.zip` | lead; counts reproduced (E-01) |

## Items

| ID | Class | Fact |
|---|---|---|
| I-01 | C5517 | OCS `item-types.json` = 5517 `itemtype.dat` on its 10 fields (f0,1,4,18,19,20,21,22,39,47), 14,981 types, 0 mismatches |
| I-02 | C5517 | 49 native fields absent from OCS; 43 of them non-zero in 5517 (e.g. f2 req_profession 5,074 rows, f12 price 11,004, f37 emoney_price 662, f10 monopoly 2,771, f32/33 atk_range/speed) |
| I-03 | X | f18 = TQ `dodge` (zf `dodge` = f18 on 100% shared). OCS name `speedPercentOffset`; 5517 proves only mount use (record+0x30). Non-zero on 102 boots `160xxx`, 13 in `824xxx`. Boot consumption in 5517: U |
| I-04 | X | zf column k ↔ native f_k (k≤28), f_{k+1} (k≥29); value-equality ≥0.918 for every non-name column. zf lacks f29, f38–f58 |
| I-05 | V5095 | ids: 5517 14,981; zf 8,201; 5095 dat 7,627; shared 7,453; 5517-only 7,528; zf-only 748 (720–723xxx 646, 710xxx 59, 182xxx 13, 135xxx 11, 2100xxx 4, other 15) |
| I-06 | V5095 | 5517↔zf cell diffs split by 5095 client file: version change (dat=zf) vs zf edit (dat=5517) — table below |
| I-07 | V5095 | 3,915/4,358 name diffs = zf quality suffix `[R] [U] [E] [S] [A+]`; rest renames/`unknown[?]` |
| I-08 | V5095 | `ini/itemtype.dat` (encoded `0x2537`, space-separated, 39 tokens) and `ini/itemtype.ini` (815 rows) unread by 15.10 |

Diff origin (cells, shared types):

| zf column (native f) | version change | zf edit | neither | no 5095 row |
|---|---:|---:|---:|---:|
| type_mask (f36) | 219 | 16 | — | 1 |
| weight (f11) | 89 | — | — | — |
| atk_speed (f33) / atk_range (f32) | 90 / 90 | 1 / 1 | — | 520 / 272 |
| id_action (f13) | 83 | 1 | 1 | — |
| life (f19) | 78 | 3 | — | — |
| monopoly (f10) | 54 | **286** | 4 | 14 |
| emoney_price (f37) | 37 | 31 | 12 | 2 |
| amount / amount_limit (f21/22) | 33 | 4 | — | 258 |
| req_profession (f2) | — | — | — | 536 |
| others | ≤13 | ≤5 | ≤1 | ≤88 |

## Shops

| ID | Class | Fact |
|---|---|---|
| S-01 | V5095 | runtime offerings = `cq_goods` per NPC record (`0x4973AC`); `Shop.dat` unread by server |
| S-02 | V5095 | load rejects unknown/duplicate itemtype rows; zf has 48 duplicate rows; 34 zf goods not in 5517 catalog |
| S-03 | V5095 | moneytype≠0 ⇒ CP at itemtype f36 (= native f37 `emoney_price`); 0 ⇒ silver f12 `price` with conditional 90% |
| S-04 | C5517 | 5517 `Shop.dat`: 67 sections, 63 ids; 5793, 6300, 6301, 6302 defined twice (EN + CN). 34 ids 5517-only; zf-only 432/433/2888/4261 = 5517 `emoneyshop.ini` ids; 24 shared shops differ, 5 identical |
| S-05 | C5517 | 5517-only files: `emoneyshop.ini` (11 shops, 385 entries), `HonorShop.ini` (57 priced), `RacePointShop.ini` (106 priced), `outerwearshop.ini` (86) |
| S-06 | U | OCS has no shop catalog |

## Item additions

| ID | Class | Fact |
|---|---|---|
| A-01 | X | zf `cq_itemaddition` = 5095 `ItemAdd.ini` on all 4,248 keys; columns life, atk_max, atk_min, defense, magic_atk, magic_def, dexterity, dodge = 5517 payload words 0–7 (≥99.7%). vs 5517: 4,248 shared, 36 cell diffs, 6,408 5517-only, 1,062 zf-only keys |
| A-02 | C5517 | OCS has no addition catalog; 5517 reads `ItemAdd.ini` (word0 max life, word7 mount speed) |

## Maps

| ID | Class | Fact |
|---|---|---|
| M-01 | V5095 | ZF08 `cq_map` 240 rows; flags match Z on 172/182, terrain key Z 181/182 ⇒ not independent TQ evidence |
| M-02 | U | no ZF08 row for any of OCS's 48 zero-flag or 7 omitted maps |
| M-03 | C5517 | OCS `flags` = full source value; 34 maps carry bits ≥41 (no 5517 reader, [census](map-catalog-5517.md)) |
| M-04 | V5095 | ZF08 terrain key ≠ OCS: 1550, 1551 (1091), 1858 (1036); low-41 flags equal 139/182 |
| M-05 | C5517 | `GameMap.dat` 5095 169 vs 5517 261 effective; same id, other asset: 1039, 1068, 1766 |
| M-06 | X | 120 OCS terrains have a 5095 DMap: 114 identical (mask, surface, elevation, exits). 1015 redesigned (598,543 passability cells); 1001 (1), 1006/1011/1508 (50); 1039 560² vs 496²; 601/1765 extra 5517 exit (82,58,0) |
| M-07 | X | shared Scene 193 / ScenePart 127 identical, 0 differ; puzzle 148 identical, 2 differ; unresolved 5095 puzzles task03/06/09 |
| M-08 | X | composition = mask≠0 blocked + type-1 scenery layers, top layer wins (15.10 `0x4D4864`) — same rule as the 5517 catalog |
| M-09 | V5095 | 15.10 puzzle-border blocking (`0x4D1777`): on OCS terrains changes 2 cells (1063, 1700); 5517 client equivalent U |
| M-10 | U | OCS has no portal/passway content. ZF08 passways 286: 258 source idx in 5517 exits, 13 not (inert); 4 targets blocked (1015 idx10/15, 1077 idx0, 1211 idx0); 5 disagree with prior `passways-5517.json` |
| M-11 | U | zf `cq_portal` 4 duplicate (map, idx) keys; 15.10 winner not traced |
| M-12 | V5095 | generators 1,846: 1,737 usable on 5517 collision, 99 off-catalog maps, 10 boxes all blocked, 12 npctypes absent from `cq_monstertype`, 6 maxnpc≤0. NPC 716 walkable / 61 blocked / 31 OOB / 376 off-catalog (343 = map 5505). dyn-NPC off-catalog: 332 on instance maps 1,000,647–1,003,480 + 2 on 1552/1553. Traps 473 walkable |
| M-13 | V5095 | 24 `cq_map` names = repeated-UTF-8 mojibake cut at width; unrecoverable |

## Actions, tasks, spawns

| ID | Class | Fact |
|---|---|---|
| T-01 | V5095 | ProcessAction: missing id stops chain (no fail branch); out-of-range type ⇒ fail branch; cap 33 records |
| T-02 | V5095 | TestTask reads f3,f4,f5,f6,f8,f9 (+f14 gate). Unread: sex (999 on 5,318), team (999 on 5,304), marriage (−1 on 8,334), metempsychosis (20), query |
| T-03 | V5095 | 68,017 actions / 170 types; 12 rows types 0/1 undispatched; 93 action links, 1,385 task links, 17 NPC task refs, 51 itemtype `id_action` → missing; 127 success chains cycle; longest acyclic 36 (> cap) |
| T-04 | U | types 501/502/503/519: 2,450 of 9,465 `data` values not in 5517 catalog (479 not in zf); opcode meaning untraced in 15.10 |
| G-01 | V5095 | generator: cap (cx/maxnpc)·(cy/maxnpc); budget max_per_gen per rest period; born override; npctype → `cq_monstertype.id` |

## Database categories (proposal; basis = 15.10 literal SQL + table role)

Generic `UPDATE %s`/`INSERT %s` paths exist: "no literal write" ≠ immutable.

| Category | Tables (zf) | Modern home |
|---|---|---|
| Immutable catalog | itemtype, itemaddition, fuse, item_value_type, magictype, magictypeop, monstertype, traptype, levexp, point_allot, rebirth, region, map (static cols), portal, passway, goods, action, task, npc, trap, generator, lottery, unlawful, forbidname, tutor_type, student_type, tutor_battle_limit_type, dyna_rank_type, cq_dyna_rank_type, sysbuyer, config, rule, fact | versioned content (hash-pinned), one authority per catalog |
| Durable world state | dynanpc (life/owner), dynamap (del_flag), syndicate, synattr, superman, wanted, pk_bonus, pk_item, leaveword, disdain, flower, ghostcontract, dyna_rank_rec, cq_dyna_rank_rec | Game DB, transactional |
| Player state | user, item, magic, weapon_skill, friend, enemy, status, statistic, business, tutor*, pet, card*, bonus, depot, deluser*, *_timeout* | Game DB (exists: characters, items, magic, weapon_skills, social, syndicates) |
| Account / payment / log | account, e_money*, emoney*, cardbalance, cardlastid, ad_log, ad_queue, add_ban, item_log, login_rcd, log, secure, tqelgahed, dynastycms, help_relation, db, db2 | never import |

Unreferenced by all 12 modules: account, add_ban, cardbalance, cardlastid, depot, cq_dyna_rank_rec, cq_dyna_rank_type,
forbidname, log, dynastycms, e_money_month, emoney_card, emoneybak, emoneycount, emoneylastid, emoneysum, help_relation,
secure, tqelgahed, all *_timeout*. Bare name literal only (no SQL text): ad_log, card3, card4, db, db2, disdain, lottery,
region, e_money, emoney_card2.

## Proposed modern additions (for review)

| Artifact | Key / constraints | Validation at import |
|---|---|---|
| `item-types.json` v2 | `itemTypeId` PK; add proven fields + raw indexed values for unproven ones (matrix `status`) | 59 fields, hash of `itemtype.dat`; names only where `proof_5517` set |
| `item-additions.json` | (`itemTypeId`, `level`) UNIQUE; 8 words | key types ∈ catalog after native family normalisation |
| `shops.json` | `shopId` PK; offering (`shopId`,`itemTypeId`) UNIQUE; `kind` ∈ {npc, emoney, honor, racepoint, outerwear}; `moneyType`; optional client price | item ∈ catalog; duplicate client shop ids resolved explicitly, never last-wins by accident |
| `portals.json` / `passways.json` | (`mapId`,`portalIndex`) UNIQUE; (`mapId`,`passwayIndex`) UNIQUE → (`targetMapId`,`targetPortalIndex`) | source idx ∈ terrain exits; target in bounds + walkable on composed collision |
| `monster-types.json`, `spawn-generators.json`, `npcs.json` | id PK; generator → map FK, npctype → monster type FK; index by map | box/born cells walkable; cap formula documented as 5095 provisional |
| `actions.json`, `tasks.json` | id PK | link closure report, dispatchable type, cycle/cap report; unresolved links quarantined, not executed |
| `magic-types.json` | (`type`,`level`) PK | lets `magic` rows be validated like items |

DB: none needed before the catalogs exist; future `shop_purchase` audit / dyn-NPC state tables only with an EF migration once contracts exist.

## Import procedure

1. Pin archive + file SHA-256 (`zf-schema.json` per-file hashes; 5517 file hashes).
2. Read through the isolated reader (MariaDB `--network none`, scratch copy) or native file decoders; keep raw hex.
3. Map fields via `field-mapping-matrix.csv` only; unknown fields stay raw.
4. Cross-check 5517 (catalog ids, terrain bounds, collision) and emit quarantine lists.
5. Publish atomically as a new content revision with manifest; tests pin counts + hashes. `scripts/run_all.sh` reproduces this audit.

## Tasks (priority order)

| P | Task | Findings |
|---|---|---|
| P0 | Item catalog v2 (requirements, prices, monopoly, combat, emoney) + document f18 | I-02, I-03 |
| P0 | 5517 shop catalog from client files + offering rules; buy parity checked in 5517 client | S-02..S-06 |
| P0 | Portal/passway catalog from `passways-5517.json`; fix 1211 idx0 target if chosen from ZF08 | M-10 |
| P0 | Flags policy for bits ≥41 (mask vs inert) | M-03 |
| P1 | ItemAdd catalog | A-01, A-02 |
| P1 | Monster types, generators, NPC placements (5095 semantics provisional; 5517 `Monster.dat` cross-check) | G-01, M-12 |
| P1 | Action/task engine contract tests + import graph validation | T-01..T-03 |
| P1 | Magic-type catalog for `magic` validation | D-03 |
| P2 | Puzzle-border rule decision (2 cells) | M-09 |
| P2 | RE: 5517 duplicate Shop.dat ids; 15.10 portal dup keys; item opcodes; rebate/availability predicates | S-04, M-11, T-04, S-03 |

## Unresolved

S-06, M-02, M-10, M-11, T-04, D-02 (12 tables unreadable: account, cq_user, cq_syndicate, cq_leaveword, cq_deluser*,
cq_user_timeout*, help_relation, secure, tqelgahed — MariaDB error 190), E-02. Plus: 5517 boot use of f18 (I-03),
5517 equivalent of puzzle-border (M-09), `CNpcShop__IsAvailable`/rebate meaning (S-03), `NpcMap__IsCellFree` vt+36.

## Evidence-pack corrections

- Counts reproduced (E-01). `christmas02.pul` resolves case-insensitively: 3 unresolved puzzles, not 4.
- Its cq_map name view truncates multi-byte sequences; raw hex in `zf-rows/cq_map.json`.
