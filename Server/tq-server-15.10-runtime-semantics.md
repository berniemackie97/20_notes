# TQ server 15.10 — runtime semantics proven in the binaries

Verified 2026-10-12, headless IDA 9.3 on `50_server/binaries/_re/` ([census](tq-server-binaries-2008.md)).
MsgServer `48749fc1…f726`, NpcServer `8c98ffec…664f` (CQServer 15.10, 2008-10-21). All names below are
saved in the `.i64`. **5095-era behaviour; 5517 parity needs its own proof.** Addresses: MsgServer unless marked.
World/AccountServer link, identity, capacity, login/logout: [historical topology](historical-multi-server-topology.md).

## Shops

| Address | Name | Proven |
|---|---|---|
| `0x457143` | `CNpc__CreateFeatureObjects` | npc vt+20 true → `CNpcShop` at npc+0x18 via `CNpcShop__Create_LoadGoods(idProcess, npc, recordId)` |
| `0x4973AC` | `CNpcShop__Create_LoadGoods` | `SELECT * FROM cq_goods WHERE ownerid=<npc record id>`; f2 itemtype must exist in item-type set and not already be in shop, else log `0x51CB90` (GBK: shop[%u] illegal or duplicate itemtype[%u]) and skip; map[itemtype]=f3 moneytype |
| `0x4974BD` | `CNpcShop__IsEmoneyGoods` | itemtype in map and moneytype≠0 |
| `0x4974E3` | `CNpcShop__IsAvailable` | false only when `0x459E52(owner)` and `0x42AAE7(owner vt+136)`; meaning not traced |
| `0x497515` | `CNpcShop__ApplyPriceRebate90` | `MulDiv(price,90,100)` when owner vt+140 ≠0 and == arg; meaning of compared value not traced |
| `0x487F5E` | `CMsgItem__Process` | action 1 buy, 2 sell `0x46D3C2`, 4 use `0x46C7D1` |
| `0x46CF00` | `CUser__BuyItem` | needs shop + available + itemtype in shop. Emoney: price = itemtype field 36, qty loop, bag cap 40, `gmlog/emoney_buy`. Silver: price = rebate(field 12) |

No server module (12 checked) names `Shop.dat`. Client shop files are UI data only for this build.

## Action / task engine

| Address | Name | Proven |
|---|---|---|
| `0x40D6FD` | (GameData load) | task set `0x5269FC`, action set `0x526A00`, monstertype set `0x526A1C` |
| `0x44778C` | `CGameAction__ProcessAction` | args (idAction, user, role, item, accept). Missing id → `Error: game action %u not found.`, **return 1, chain stops**. Param f5 expanded (`0x4455BD`, 255 B). Next = success ? f1 : f2. Type outside every range → assert `Error action type!`, failure branch. Cap: after 33 records `too many game action, last action:%u`, return 1. Returns 0 only for initial id 0 |
| `0x412637` | `GameData__GetActionSet` | |
| `0x4941B7` | `GameData__GetTaskSet` | |
| `0x493B7A` | `CUser__TestTask` | `TestTaskItems` ∧ money ≥ f5 ∧ (f6==0 ∨ user+0x7B2 == f6) ∧ f8 ≤ user int16 +0x7B8 ≤ f9 |
| `0x493C79` | `CUser__TestTaskItems` | f3 non-empty → item by name (`0x46AE62`); f4 only if f3 set |
| `0x493CDE` | `CUser__ProcessClientTask` | requires f14 (client_active) ≠0. pass → f1 (0 ⇒ return 1); fail → f2 (0 ⇒ `STR_UNQUALIFIED`, return 0); else ProcessAction |
| `0x493E38` | `CUser__ProcessTaskByIndex` | task id from user array +0x5F8/+0x5FC by index; f14==0 ⇒ current NPC (+0x610) in range (`0x432275`, 4160) required |

cq_task fields **not read** by 15.10: f7 sex, f10 team, f11 metempsychosis, f12 query, f13 marriage.

Dispatch (exclusive bounds; handler names from fight-master `GameAction.cpp`, order/bounds identical):

| Type | Handler | | Type | Handler |
|---|---|---|---|---|
| 101–198 | `ProcessActionSys` `0x447E5D` | | 801–898 | `ProcessActionMonster` `0x447C46` |
| 201–298 | `ProcessActionNpc` `0x448AA7` | | 1001–1998 | `ProcessActionUser` `0x44F228` |
| 301–398 | `ProcessActionMap` `0x4499A9` | | 2001–2098, 2101–2198 | `ProcessActionEvent` `0x454094` |
| 401–498 | `ProcessActionItemOnly` `0x44AA85` | | 2201–2298 | `ProcessActionMagic` `0x455D75` |
| 501–598 | `ProcessActionItem` `0x44B387` | | 3001–3098 | `ProcessActionWanted` `0x4550F5` |
| 601–698 | `ProcessActionNpcOnly` `0x44CA7D` | | | |
| 701–798 | `ProcessActionSyn` `0x44D00F` | | | |

Binary Magic bound is `>2200`; fight-master source text reads `> ACTION_MAP_FIRST`. Handler bodies not traced.

## Spawn generators (NpcServer)

cq_generator fields: f0 id, f1 mapid, f2 bound_x, f3 bound_y, f4 bound_cx, f5 bound_cy, f6 maxnpc, f7 rest_secs,
f8 max_per_gen, f9 npctype, f10 timer_begin, f11 timer_end, f12 born_x, f13 born_y.

| Address | Name | Proven |
|---|---|---|
| `0x40EED9` | `CNpcGenerator__Create` | cap +0x24 = (f4/f6)·(f5/f6), forced 1 if f6≤0 or ≤0 result (**f6 = grid divisor**); rest timer f7+rand(f7); unknown map → `npc generator [%u] got invalid map [%u]`, fail |
| `0x40F036` | `CNpcGenerator__Generate` | f10≠0 ⇒ `IsTimeInWindow(f10,f11)`. Stop at alive ≥ cap. Timer expiry: f7≥600 ⇒ re-arm; budget = f8. Tries f4·f5 per spawn; none ⇒ `Bad NPC generator` (≥1200 s apart) |
| `0x40EFB4` | `CNpcGenerator__GetSpawnPos` | f12>0 ⇒ (f12,f13); else (f2+rand(f4), f3+rand(f5)) |
| `0x4102BE` | `NpcMap__IsCellFree` | in bounds and map vt+36(x,y)==0 (vt+36 not traced) |
| `0x406F0B` | `IsTimeInWindow` | now = sec+100·(min+100·(hour+X)); X=10000·mday if begin≥1e8 else 100·wday |
| `0x406EE2` | `IsValueInWrappedRange` | b≤e: b≤v<e; b>e: v<e ∨ v≥b |
| `0x407063` | `RandomBelow` | ((rand()<<15)+rand()) % n; 0 if n≤0 |
| `0x41277B` | `CMsgAiNpcInfo__CreateNew` | msg 20001, 32 B: +0 npc id, +4 map, +8 generator, +20 x, +22 y, +24 action 1, +26 type (f9) |
| MsgServer `0x439C55` | `AiNpcInfo__CreateMonsterFromType` | `MonsterTypeSet.GetObj(msg+26)` ⇒ f9 = `cq_monstertype.id` |

## Map data / collision

| Address | Name | Proven |
|---|---|---|
| `0x4D2739` | `MapData__CreateByMapDataId` | reads `ini/GameMap.dat` (id, len, path, **field4**) once; field4 → `CreateNew` arg 3 |
| `0x4D159A` | `CMapData__CreateNew` | DMap: 8 B header, puzzle[0x104], cells, passways, layers; puzzle ≠ `none` ⇒ `BlockPuzzleBorder` |
| `0x4D1A7A` | `CMapData__LoadCellData` | u16 mask, u16 surface (**discarded**), i16 alt; row checksum read, **not verified** |
| `0x4D468D` | `CCell__Init` | +0 7-bit counter, +2 layer index 0xFFFF, +4 (alt<<1)\|(mask≠0) |
| `0x4D1BDF` | `CMapData__LoadPassways` | 12 B {x,y,idx}; no effect on masks |
| `0x4D1C3B` | `CMapData__LoadLayers` | type 1 scenery → collision layers; 3/4/10/15 skipped (fixed sizes in IDB comment); other type ⇒ load fails |
| `0x4D4864` | `CCell__GetFloorMask` | no layer ⇒ base bit0; else **top layer** mask |
| `0x4D48D1` / `0x4D4934` | `CCell__GetFloorAttr` / `GetFloorAlt` | top layer word +0 / int16 +2; base alt when no layer |
| `0x4D1777` | `CMapData__BlockPuzzleBorder` | puzzle: magic[8], name[0x100], u32 W, u32 H. s = field4. a=s·W/64, b=s·H/32, h=N/2, p=a/2+(h−b)/2, q=b/2+(h−a)/2, assert p+q==h, map must be square. Blocks x+y<p, (N−1−x)+(N−1−y)<p, x+(N−1−y)<q, (N−1−x)+y<q |

GameMap.dat field4 (256/128) = puzzle tile size in 15.10. Client use of the same field: [map-assets.md](map-assets.md).

Other renames in MsgServer IDB: `CCell__SetBaseBlocked 0x4D46EE`, `CCell__IncCounter7 0x4D49BA`,
`CCell__DecCounter7 0x4D46B2`, `CCell__PopLayer 0x4D4799`, `CTerrainObj__CreateNew 0x4D51D1`,
`CTerrainObjPart__Load 0x4D56D0`, `CMapData__AddTerrainObj 0x4D239A`, `CMapData__RemoveTerrainObjLayers 0x4D2054`,
`CMapData__AddPasswayRecord 0x4D22E6`, `CMapData__GetCell 0x4D22A2`, `GameData__GetMonsterTypeSet 0x42EE48`,
`CMsgAiNpcInfo__CreateFromInfo 0x48EDF5`.

## Movement, visibility, kickback

Verified 2026-10-14 (headless IDA). MsgAction subtype numbers below are **15.10**; 5517 renumbers several
(5517: jump 137, leave 135, sync 146; 108 and 102 unchanged). Walk 1005 payload (after the 4-byte header): `+0` id, `+4` u8 dir,
`+5` u8 mode, `+8` client timestamp.

| Address | Name | Proven |
|---|---|---|
| `0x492816` | `CMsgWalk__Process` | dead∧¬ghost ⇒ `STR_DIE`; transformed∧¬move ⇒ `STR_YOUR_CANNOT_WALK`+KickBack; `CheckWalkTimeStamp` fail ⇒ "invalid walk" + **socket kicked**. Then `ProcessOnMove(mode)` (mode≠2), **`BroadcastRoomMsg(walk, includeSelf)` before the move**, `MoveToward(dir%8)`. No altitude / occupancy test |
| `0x416A26` | `CUser__CheckWalkTimeStamp` | exempt: status `0x2000`, `0x40000`, transformation (`CUser+0x634`) type 2020–2024. Ring of 4 client timestamps; first 3 pass; pass iff status `0x400000` or avg of last 3 intervals **≥ 187 ms** |
| `0x4168DF` | `CUser__CheckJumpTimeStamp` | same shape, own ring, avg **≥ 643 ms** |
| `0x420275` | `CUser__MoveToward` | ¬`IsValidPoint` ⇒ fail; ¬`IsStandEnable` ⇒ `STR_INVALID_COORDINATE`+KickBack. `MoveTo`, pos+=δ. **Edge show**: things in 9 blocks exactly 18 ahead on a moving axis with other axis ≤18 ⇒ mutual `SendShow`. `ProcessAfterMove` (traps on tile) |
| `0x4333DB` | `CGameMap__IsStandEnable` | `IsValidPoint` ∧ `CMapData__GetFloorMask` (`0x4D29A5`, top layer) == 0 |
| `0x41FF7C` | `CUser__BroadcastRoomMsg` | → `CGameMap__BroadcastBlockMsg` `0x432B1F` (`…AtPos` `0x432E1A`): **stateless**; roles in 9 blocks (18-cell) with `GetDistance ≤ 18`; self only if includeSelf. Newbie map (`map+0x30`, set for id **1010** in `CMapManager__LoadMapsForServerIndex`) ∧ includeSelf ⇒ self only |
| `0x429B6A` / `0x487ABF` | `CRole__GetDistanceToThing` / `…ToPos` | `max(|dx|,|dy|)` |
| `0x42A517` | `CUser__KickBack` | if `IsKickBackAllowed` (`0x42A621`): MsgAction **108** (x,y,dir) to self; then `SetKickBackSuppression` (`0x42A5EA`) = 5 s window |
| `0x42A640` | `CUser__SynchroPos` | MsgAction 138 with `CUser__GetMapId` (`0x420D1C`) |
| `0x41A18A` | `CUser__LeaveMap` | MsgAction **132** to room, excluding self |
| `0x420C0A` / `0x433A6A` | `CUser__ChangeMap` / `CGameMap__GetPassageMap` | case 0x55 (85): alive else `STR_DIE`; 9 tiles around the **server** position (client candidate ignored); first passway → `FlyMap`; none or fly error ⇒ talk "no map passway!" only. Map id > 1,000,000 ⇒ map fields 17/18/19. Detail: [portal transition](portal-transition-5517.md) |
| `0x420F48` | `CUser__FlyMap` | other group ⇒ `CUser__ChangeMapGroup` `0x425827`; bad point ⇒ "FLY " log; `LeaveMap` → set pos → MsgAction **86** `{data = mapdoc}` to self → `EnterMap` |
| `0x417CF7` | `CUser__EnterMap` (order) | `CUser__SendLight` 104 `0x429E26` → `CGameMap__EnterRoom` `0x433027` → `CGameMap__SendRegionInfo` `0x433272` (1016 via `CWeather__SendWeather` `0x48BD75` / `CMsgWeather__Create` `0x492454`) → `CGameMap__SendMapInfo` `0x433DF0` (1110, `CMsgMapInfo__Create` `0x48DA46`, 12-B body) → `CUser__SendSelfToBlock` `0x417DE3` → lock |
| `0x467157` | `CMsgAction__Create` | type 1010, body `{+0 time,+4 id,+8 data,+12 x,+14 y,+16 dir,+18 action}` — not the 5517 layout |
| `0x4672AE` | `CMsgAction__Process` | 102 query: target alive ∧ dist ≤18 ∧ ¬newbie ⇒ `SendShow`. 133 jump: timestamp, Chebyshev ≤18 (else `STR_INVALID_MSG` + kick), broadcast incl. self, `CUser__IsJumpLineAltitudeEnable` (`0x42792E`: **map 1038 only**; line cells vs start alt + 200, or 356 with status `0x400000`) else KickBack. 138 synchro reply: no pending KickBack ⇒ socket kicked; else clears window; payload `+0x14` must equal the map id; server then **adopts the client tile** (dist <18 via vt+348, else `TransPos` vt+344) and broadcasts to others |
| `0x42082D` | `CUser__JumpPos` | per-axis ≤18; landing ¬`IsStandEnable` ⇒ `STR_INVALID_COORDINATE`, fly to fallback, **socket kicked**. After move: things in 9 blocks with (\|x−oldX\|>18 ∧ \|x−newX\|≤18) ∨ (same for y) ⇒ mutual `SendShow` — jump broadcast goes from the origin, newcomers get spawns, no intermediate points |
| `0x420641` | `CUser__TransPos` | `IsStandEnable` else same teleport-and-kick path |
| `0x469B17` / `0x492B59` | `CUser__TransformationCanJump` / `…CanMove` | transformation monster type field 21 (`attack_user`): `0x20` ATKUSER_JUMP allows jump (else socket kicked in 133); `0x40` ATKUSER_FIXED forbids walk (`STR_YOUR_CANNOT_WALK` + KickBack). Enum names: fight-master `AINpc.h` |
| — | (absence) | no freeze/stun/lock status test in walk or jump; no steed/vigor/ride code or strings |
| `0x41CDBD` / `0x422FCC` / `0x422CFA` | `CUser__BeKill` / `__SetGhost` / `__Reborn` | death: revive timeout 20 s, record = reborn point; actionGhost **137** ⇒ ghost byte, status bit 10, lookface 98/99·10⁷; actionReborn 94 ⇒ Reborn (early ⇒ "Cheat" log + 60 s re-arm). Detail: [death/ghost/revive](death-ghost-revive-5517.md) |
| `0x42669F` / `0x42AB09` | `CUser__SetStatus` / `__AddEffect` | DIE(1): effect := (old & 0xC040) \| 0x20 (+bit 33 if blessed); NORMAL(0): rebuilt; sync ⇒ attr 25 to room. AddEffect ORs the keep-effect mask (ghost 0x400) |
| `0x417CF7` / `0x42B09C` / `0x418D12` | `CUser__EnterMap` / `__IsBeAtkable` / `__ProcessOnAttack` | `m_tLock` (CUser+2372/+2376, TQ `CHGMAP_LOCK_SECS`=10): started by EnterMap and Reborn, blocks being attacked, cleared by ProcessOnMove/ProcessOnAttack |
| `0x4AA79A` | `CUserList__CreateNewUser` | map 1010 at `cq_map.portal0` (`CMapInfoSet__GetById` `0x4ABB61`; 5095 row: (60,108)). Allot S/A/V/Sp: 10,20 → 5/2/3/0; 40 → 2/7/1/0; 50 → 1/8/1/0; 100 → 0/2/3/5. life = 3·(S+A+Sp+8V); mana = 5·Sp; money 100; hair = 100·rand(7)+310; lookface = body+10000 (male, face 1) / body+2010000 (female, face 201) |

Death record (binary-traced 2026-10-16): `CUser__BeKill` sets the record to the current map's `reborn_mapid` at that
map's `portal0` via `CGameMap__GetRebornMap` / `CUser__SetRecordPos`; see [death/ghost/revive](death-ghost-revive-5517.md).
Record position on leave-map (fight-master, not binary-traced): `SetRecordPos(current)` only if `IsStandEnable` ∧
¬`MAPTYPE_RECORD_DISABLE` (`0x4`); otherwise the record keeps the previous/reborn point.

## Creation decision-path addendum (2026-10-30)

[Character-creation decisions](character-creation-decision-15.10.md) adds upstream validation, generic refusal mapping, ownership, and persistence boundaries. Unsupported professions normalize to 20; they are not rejected. Existing attribute/spawn evidence above is unchanged.
