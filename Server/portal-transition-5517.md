# Connected portal transition — 5517

Verified 2026-10-24. Client: Binja `Conquer.exe` 5517 (`b6ba5ab8…8a62`; renames/comments in memory until GUI
save). Older server: TQ CQServer 15.10 `MsgServer.exe.i64` (`48749fc1…f726`, headless IDA, saved). Community:
FoxConquer5517 (`Remakes/Conquer/Servers/FoxConquer5517-master`). Ancestor names: eosource `3drole/Network/MsgAction.cpp`
(`actionFlyMap`), `3drole/Hero.cpp` (`ProcessChgMap`), `MyShell/MyShellDlg.cpp` (`_STATUS_WAITING`), `3dgamemap/3DGameMap.cpp`
(`Create`), `3drole/GamePlayerSet.cpp` (`DelAllPlayer`). Names only.

Prerequisite (not repeated): [map transitions](map-transitions.md) — 85 request `0x65DD3B`, candidate tile in the
parameter pair, DMap exit section. [Map identity](map-identity-flags-native-5517.md) — 1110 fields.
[World entry](world-entry-bootstrap.md) — 74 at login. [Core packets](../Network/01_core_packets.md) — MsgAction layout,
entity gate `0x6FF173`.

Tags: **C** native 5517 client · **S** TQ 15.10 server (5095 era) · **T** TQ source lineage (`40_tools/fight-master`; names
only) · **X** community (Fox 5517) · **U** unresolved retail 5517 server.

## 1 Frame modes (C)

`CLoginFlashCallbackState_SetModeHandlerByCode` `0x5782A6` selects the per-frame handler. Codes are eosource `g_uStatus`
(`_STATUS_NONE` = 1000). The same code twice is a no-op (`0x5782C6`). Jump table `0x5788F7`, index = code − 0x3E8.
Each frame `CMyShellDlg_TickMapRoleAndEffectPipeline` `0x5AFEA4` → `0x5789A2` → handler vf+0x10(shell).

| Code | eosource | Frame function | Packets dispatched |
|---|---|---|---|
| `0x3F0` | `_STATUS_WAITING` | `CMyShellDlg_RunWaitingStatusFrame` `0x5DCF87`: StrRes 10057 "Connecting to the server... Please wait..." centred, then `CNetMsg__ProcessMsg` | yes |
| `0x3F2` | `_STATUS_NORMAL` | `CMyShellDlg_RunFrameTick(shell,1)` `0x5DCFAA` (returns at once unless world gate `+0x179AB9`) | yes |
| `0x3F5` | — | `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` `0x5DCEA3` (PROGRESS / LOADING_TRACE to the visible login or role-create host only) | **no** |
| `0x44C` | — | `CMyShellDlg_ResetRuntimeAndDisableWorldFrameGate` `0x5DC783` | — |

- `CNetMsg__ProcessMsg` `0x6DEBA5` callers: frames 0x3E9/0x3EB/0x3EC/0x3EE/0x3F0/0x3F2 only.
- One call drains the socket (loop `0x6DEBE7..0x6DED9A`). A mode change inside a handler does not stop the drain.
- Socket dead: `CLoginFlashDlg_OnConnectionLost` `0x578995` → handler vf+4 → mode 0x44C.
- The 0x3F0 frame never ticks the hero. So no second 85 is sent while waiting.

| Setter | Code | Site |
|---|---|---|
| client 85 sent | 0x3F0 | `0x65DE0E` |
| inbound 86 start / success | 0x3F0 / **0x3F2** | `0x6FF69A` / `0x6FF897` |
| inbound 74 | 0x3F5 | `0x6FF456` |
| login / role-create Flash `CMD_CLOSE` | 0x3F2 | `0x4AC6BB` / `0x51C320` |
| login packets 1052 / 1057 / 1203 | 0x3EB | `0x75461C`, `0x754872`, `0x754EEF`, `0x755848`, `0x755B85` |
| other setters (account connect, login UI) | 0x3E9 / 0x3EC / 0x3EE / 0x3EF | `0x66D497`, `0x5DCD27`, `0x51C74E`, `0x4AF72B`, `0x4AF5D4` |

## 2 Inbound 86 `actionFlyMap` (C)

Branch `0x6FF652` in `CMsgAction__Process`. It must first pass the common entity gate (`+4` resolves, `0x6FF173`). 86 is
not in the unresolved-continue set. The branch reads only `+4`, `+8`, `+0x14`, `+0x16`, `+0x18`, `+0x1A`. Timestamp `+0x10`
is not read.

| Step | Address | Effect |
|---:|---|---|
| 1 | `0x6FF663` | `+4` ≠ `CHero+0xCC` ⇒ CHECK `m_pInfo->idUser == g_objHero.GetID()` (MsgAction.cpp `0x32B`), exit. Nothing applied |
| 2 | `0x6FF68E` | mode 0x3F0 (no-op after 85) |
| 3 | `0x6FF6A8/BB` | `Role_IsInBusyCommand20_21_28_2E` ⇒ vf+0x6C `Role_AbortCommandToStandbyUnlessType07` |
| 4 | `0x6FF6C5..E4` | old doc id (`+0xE4`, getter `0x6E5E2C`) == 0x814 ∧ `+8` ≠ 0x814 ⇒ post 0xC98 (hide dialog `shell+0x13C4C4`, `0x5C9592`) |
| 5 | `0x6FF6FB` | `CGameMap_CreateFromDataId(+8)`. Fail ⇒ CHECK `g_objGameMap.Create(m_pInfo->dwData)` (`0x33C`), exit, **mode stays 0x3F0** |
| 6 | `0x6FF72F/4B` | hero tile (`+0x18`, `+0x1A`): `Role_SetTilePositionAndProjectScreenCoordinates` + `Role_UpdateCoordinateGateAndMapFromTilePair` |
| 7 | `0x6FF762` | `CRole_SetDirectionFromPacked8(+0x16)` |
| 8 | `0x6FF767..7FD` | every `Role_IsHeroOwnedPetEntity` in `g_objPlayerSet`: gate recompute, tile + `Role_SetTileXYPairA88` = hero tile |
| 9 | `0x6FF806/13` | hero gate cache recompute; `CHero_SetDword0FC0(0)` |
| 10 | `0x6FF825..55` | camera: hero projected (`+0x350/+0x354`) − screen/2 → `CGameMap_UpdateProjectionAndCameraFromScreenCenter(x,y,0,1)` |
| 11 | `0x6FF860..85` | 0x11C block type 5 → hero vf+0x80 |
| 12 | `0x6FF88B` | **mode 0x3F2: this is what ends 0x3F0** |
| 13 | `0x6FF8AA/B5/C0` | post 0x477 (lParam `+8`), 0xC03, 0x516 |

- No packet is sent.
- Map create (`0x61DA1F`, eosource `CGameMap::Create`), in order: `CGamePlayerSet_DelAllPlayer(1)` `0x61DB0C` drops every role
  except hero-owned pets; booth close; re-add; `+0xE4` = `+8`; post 0x424.
- It never writes `+0xE0` or the flags, and has no same-key short-circuit.

Posted handlers (0x464 switch `0x5BB79D`; pumped after the current drain):

| wParam | Case | Effect |
|---|---|---|
| 0x477 | `0x5C5ED1` | hide `shell+0xED70C`; auto-run lock ∧ extended path ⇒ `CHero_StartOrAdvanceAutoRunPath`, else active auto-run ⇒ stop |
| 0x516 | `0x5C6B9B` | `CHero_ClearFlagBits2E60(1)`; world id (`+0xE0`, getter `0x4F6569`) == 0x40C ⇒ extra UI (not traced) |
| 0xC03, 0x424 | none | default `CWnd::WindowProc` `0x5CD96E` |

## 3 Ordering the client imposes (C)

| # | Requirement | Evidence |
|---:|---|---|
| 1 | 86 `+4` = hero id. No overwrite (74 is overwritten at `0x6FEE14`; 86 is not) | step 1 |
| 2 | 86 `+8` = GameMap.dat data id (terrain key), not world id | step 5; [identity](map-identity-flags-native-5517.md) |
| 3 | Spawns for destination entities **after** 86. Any role spawned earlier is deleted by `DelAllPlayer` | `0x61DB0C` |
| 4 | Old-map entities need no 135 to the traveller. The client clears them itself | `0x61DB0C` |
| 5 | 1110 **after** 86. 86 does not run the 1110 refresh (`0x61F185` chain), and the doc-2068 (0x814) test reads the old `+0xE4` | §2 step 4 |
| 6 | Send 1110 in the same flush as 86, so that 0x516's `+0xE0 == 0x40C` test sees the new world id | `0x5C6BB0`; PostMessage pumped after drain |
| 7 | Never answer travel with 74 | §5 |
| 8 | 86 alone is a complete transition. No prior 85 is needed (server-initiated NPC / revive / GM moves) | step 2 sets 0x3F0 itself |
| 9 | Arrival tile not within one tile (3×3) of an exit on the destination map | §5 |

Minimum valid server reply: **86 → 1110 → destination spawns**. 104 / 1016: see §6 (S order); client order constraint vs. 86
is not traced (U).

## 4 Client requests during travel (C)

| Packet | When | Distinct from bootstrap |
|---|---|---|
| 85 (request) | once per attempt, `0x65DD3B` | yes — bootstrap uses client 74 → server 74 → client 75 ladder |
| — after 86 | none. No acknowledgement exists | the server must not wait |
| 408 | only from 1110 when qword bit 38 (`HasFlags64HighBit6`) differs old vs new (`0x732CFD`) | same handler as bootstrap; not a travel ack |
| 75 | only if a 74 arrives (`0x6FF540`) | bootstrap rung |
| 2400 `{+4=2,+8=region+0x14}` | on a type-0xE tile region, hero-tick region branch (`0x65DB26`, `CMsgMapInfo2400__CreateAction2`). Armed by `CHero_OnTileRegionTypeActivated` `0x666853`; 1110 clears `+0x2F58` (`0x732BB0`) | not part of exit travel |

Client-side refusals (no packet sent; message once per latch `0x93EF7D`, re-armed when a scan finds no exit):

| Gate | Text |
|---|---|
| current action 0x12C | `STR_ALERTING_CANNOT_CHANGEMAP` "You can`t enter another map while in combat!" |
| anti-addiction grade `+0x2E34` == 0 / 50 (set only by `CMsgUserAttrib__Process`; init −1 `0x662FC0`) | `STR_WALLOW_OPT_LIMIT_WARNING_NONE` / `_HALF` "Operation failed." |
| status 5/10, state `0x1EC` ≠ 6, action not standby-set, auto-run UI lock | silent |

## 5 Refusal, interruption, repetition, malformed input

| Case | Tag | Behaviour |
|---|---|---|
| Server silent after 85 | C | 0x3F0 forever: status text, packets still dispatched, no timer, no world |
| Talk / other packets while waiting | C | dispatched normally. Of the mode setters (§1), only 86 and 74 are in-session packets |
| Socket loss while waiting | C | 0x44C, runtime reset |
| 86 `+4` ≠ hero | C | CHECK, ignored; client stays waiting |
| 86 `+8` not in GameMap.dat | C | log "GameMapInfo (%u) not found" (`0x61DA78`), CHECK, ignored; old map intact; stays 0x3F0 |
| 86 `+8` known, file load fails | C/U | "game map %s load failed"; component link already written (`0x61DABE`); partial state not traced |
| 86 tile outside grid | U | the 86 branch has no bounds test; callee behaviour not traced |
| Later valid 86 | C | recovers (step 2 → step 12) |
| 74 mid-session | C | 0x3F5: no packet dispatch, no world tick. Only Flash `CMD_CLOSE` exits; those hosts are hidden after 0x483. Also sends 75. Not run-tested |
| 74 then 86 in one drain | C | 86 still runs in the same loop and sets 0x3F2 |
| Same-map 86 | C | full reload (all non-pet roles dropped). Use 108 / 156 for in-map moves |
| Two 86 in one drain | C | two full loads; last wins |
| Arrival next to exit | C | next eligible hero tick sends 85 again (loop) |
| Inbound 85 | C | no case in main switch; inert after entity gate |

## 6 Historical and community servers

| Item | Tag | Fact |
|---|---|---|
| 85 handler | S | case 0x55: alive (else `STR_DIE` talk), vf+264(5), `CUser__ChangeMap` `0x420C0A` |
| Tile source | S | **server** position, same 9-offset order as client `0x65DC6A`. Client candidate ignored |
| Resolve | S | `CGameMap__GetPassageMap` `0x433A6A`: map id > 1,000,000 ⇒ map fields 17/18/19, else passway → portal |
| Refusal | S | no passway / fly error ⇒ talk "no map passway!" (`0x50DD94`) only. A 5517 client would stay in 0x3F0 |
| Refusal | T | `ChangeMap`: fly to default login map, then kick socket |
| Refusal | X | Fox: tile not portal ⇒ `ChangeMap` to revive point (always answers); distance > 2 ⇒ `STR_INVALID_JUMP` + disconnect |
| Group | S | other map-group process ⇒ `CUser__ChangeMapGroup` `0x425827` |
| Fly | S | `CUser__FlyMap` `0x420F48`: invalid map/point ⇒ "FLY " log, −1; `LeaveMap` (leave action 132 to room excl. self) → set map/x/y → **86** `{id,x,y,dir,data=mapdoc}` to self → `EnterMap` |
| EnterMap | S | `0x417CF7`: `CUser__SendLight` 104 (map ARGB) → `CGameMap__EnterRoom` → `CGameMap__SendRegionInfo` (1016 if in a weather region) → `CGameMap__SendMapInfo` 1110 → `CUser__SendSelfToBlock` (own spawn to room) → map-type bit 9 ⇒ detach 0x400000 → lock 10 s → step 2 |
| Order | T | `EnterMap`: SendLight, EnterRoom, SendRegionInfo, SendMapInfo (same) |
| Order | X | Fox `ChangeMap`: 85 to client (inert), 86 (`+8` mapdoc), 1110, `LoadSurroundings` spawns; then lock |
| Other spawns to traveller | S | not inside `EnterMap` body; not traced |
| Layout | S | 15.10 type 1010, body `{+0 time,+4 id,+8 data,+12 x,+14 y,+16 dir,+18 action}`, 1110 body 12 B with u32 type. Semantics only; the 5517 wire comes from §2 and [identity](map-identity-flags-native-5517.md) |

The client gives 104 meaning: prologue `0x6FED87` applies `+8|0xFF000000` (0 ⇒ −1) to `CGameMap_SetMapARGB` `0x61ED50`
(`+0x368`, `+0x13C`).

## 7 Unresolved retail 5517 server (U)

- Retail post-86 order and set (104 / 1016 / 1110 / spawns). S and Fox agree on 86 before 1110; that is not proof.
- Retail refusal reply. The S talk-only reply would strand a 5517 client.
- Whether retail validated the client candidate tile (S ignores it; Fox uses it, distance ≤ 2).
- Retail use of 2400 action 2 and the doc-2068 (0x814) case.

## 8 Vector (constructed from client reads, not a capture)

86, hero 1000001, data id 1002, tile (430,380) (1002 portal0 per [map catalog](map-catalog-5517.md)), dir 0. 38 B before
framing/seal ([protocol](../Network/00_protocol_overview.md)):

```
26 00 1A 27 41 42 0F 00 EA 03 00 00 00 00 00 00 00 00 00 00
56 00 00 00 AE 01 7C 01 00 00 00 00 00 00 00 00 00 00
```

Read by the client: `+4` 0x000F4241, `+8` 0x3EA, `+0x14` 0x56, `+0x16` 0, `+0x18` 0x1AE, `+0x1A` 0x17C.

## Corrections made elsewhere

- [map-transitions](map-transitions.md): 86 (not "the burst") ends 0x3F0; the mode does **not** end on its own after a silent refusal.
- [01_core_packets](../Network/01_core_packets.md): 0x56 builds a 0x11C type-5 block (`0x6FF85A..85`); 86 and inbound-104 rows added.
- [world loading](../Game_Map/post_login_world_loading_orchestration.md): 0x424 has no 0x464 case; `0x5C3E71` is 0x426.
  `CGameMap_ReconcileType2ChildComponentEntityLinks` → `CGamePlayerSet_DelAllPlayer`.
- [frame loop](../Architecture/09_frame_loop_architecture.md): anti-addiction grade 0 is the strictest (portal refused, 15-min
  notice), not "no throttle".

## Tool records

Binja `Conquer.exe` renames (in memory until saved):

| VA | Name |
|---|---|
| `0x5DCF87` | `CMyShellDlg_RunWaitingStatusFrame` |
| `0x57818C` / `0x578186` / `0x578135` / `0x5780E6` | `CLoginFlashCallbackHandler_DispatchMode3F0Frame` / `_GetModeCode3F0` / `_GetModeCode3F2` / `_GetModeCode3F5` |
| `0x577EBF` | `CLoginFlashCallbackHandler_EnsureModeCode44C` |
| `0x61D9FF` / `0x637700` | `CGameMap_GetExitIndexAtTile` / `CMapGroundEntityLayer_FindExitPasswayIndexAtTile` |
| `0x6E7F89` / `0x6E82D8` | `CGamePlayerSet_DelAllPlayer` (was `CGameMap_ReconcileType2ChildComponentEntityLinks`) / `CGamePlayerSet_GetPlayerRefByIndex` |
| `0x64E1D9` | `Role_AbortCommandToStandbyUnlessType07` |
| `0x66076F` / `0x6639DB` | `CHero_SetDword0FC0` / `CHero_ClearFlagBits2E60` |
| `0x4BCD46` | `NoOpFunction_Return_4BCD46` |
| `0x61ED50` | `CGameMap_SetMapARGB` |
| `0x740837` / `0x7408C0` | `CMsgMapInfo2400__Ctor` / `CMsgMapInfo2400__CreateAction2` |
| `0x666853` / `0x66688C` | `CHero_OnTileRegionTypeActivated` / `CHero_OnTileRegionTypeDeactivated` |

Binja comments:

- Function comments: `0x5782A6`, `0x5DCF87`, `0x65D9B2`, `0x6E7F89`, `0x61DA1F` (appended), `0x61ED50`, `0x7408C0`, `0x666853`,
  `0x64E1D9`.
- Address comments: `0x6FF652`, `0x6FF44A`, `0x5C3E71`.

IDA `MsgServer.exe.i64` (saved):

- Renames: `CUser__ChangeMap` `0x420C0A`, `CGameMap__GetPassageMap` `0x433A6A`, `CUser__SendLight` `0x429E26`,
  `CGameMap__SendRegionInfo` `0x433272`, `CGameMap__SendMapInfo` `0x433DF0`, `CUser__SendSelfToBlock` `0x417DE3`,
  `CWeather__SendWeather` `0x48BD75`, `CMsgMapInfo__Create` `0x48DA46`, `CMsgWeather__Create` `0x492454`,
  `CMsgAction__Create` `0x467157`, `CUser__ChangeMapGroup` `0x425827`, `CGameMap__EnterRoom` `0x433027`.
- Comments on: `0x420C0A`, `0x420F48`, `0x433A6A`, `0x429E26`, `0x433272`, `0x433DF0`, `0x48DA46`.
