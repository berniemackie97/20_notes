# Death, ghost and revival — 5517

Verified 2026-10-16. Client: Binja `Conquer.exe` 5517 (`b6ba5ab8…8a62`; renames/comments in memory until GUI
save). Older server: TQ CQServer 15.10 `MsgServer.exe.i64` (headless IDA, saved). Community: FoxConquer5517
(`Remakes/Conquer/Servers/FoxConquer5517-master`), LongV6270 (`…/LongV6270-main`). Ancestor names: eosource
`3drole/Hero.cpp`, `MyShell/DlgXp.cpp` (same routines, one revision earlier).
Prerequisite (not repeated): [movement eligibility](movement-eligibility-5517.md) — dead 5, ghost 0xA, walk rules.

Tags: **C** native 5517 client · **S** TQ 15.10 server (5095 era) · **T** TQ source lineage (`40_tools/fight-master`, EO;
names only) · **X** community (Fox 5517, Canyon 6192, Long 6270) · **U** unresolved retail 5517 server.
Rev 2 2026-10-16: §0, §6–§8 and the retail-evidence table added; §2/§3/§5 corrected.

## 0 Status bit identity

| Bit | C (5517 behaviour) | S (15.10 keep-effect, CUser+2064) | X names |
|---:|---|---|---|
| 5 | dead (corpse; 3-s → 145) | death: `CUser__SetStatus(1)` effect := (old & 0xC040) \| **0x20** | Fox/Canyon/Long call it GHOST |
| 10 (0xA) | ghost (walk, revive) | `CUser__SetGhost`: \|= **0x400** (`CUser__AddEffect`) | called DEAD |
| 33 (0x21) | bless | added by SetStatus(0/1) when `CUser__IsBlessed` | — |
| 111 (0x6F) | Soul Shackle | — (no shackle code in 15.10) | Fox `SHACKLED`=112 (1-based), Long `SoulShackleTimer` 111 |

SetStatus(1) keeps only bits 6 (team leader), 14/15 (PK colour), plus bless; sync=1 ⇒ attr 25 to room (self if no map).
X swaps the dead/ghost names but attaches both at death, so the bits the client sees are the same.

## 1 Ghost transition

| Step | Tag | Fact |
|---|---|---|
| Kill | C | MsgInteract 1022 subtype 14 (`0x6FB317`→`0x6FBE54`): target `+0xC` life := 0 (`CRole_SetPlayerDataByIndex(1,0)`); target = hero ⇒ tile `+0x10/+0x12` (unless vf+0x90), post 0x41A; id > 999,999 ⇒ command 0x2F. Player die-pose branch `0x6FBF7F` not traced |
| Status 5 add | C | `CHero_ProcessStatusMaskChange` `0x65F01A`: `m_timeDie` `+0xE00` = now; `CHero_QuitTrade` `0x72A36C` sends **1056** `{+4 hero, +8 u16 2}` (12 B); `CHero_CloseTrade(0)` `0x729BF3` rolls back, post 0x3EF |
| Remote corpse | C | 10014 spawn `0x756D05`: dead ∧ ¬ghost ⇒ command 4, action **0x14B**, dir `+0x5A`; dead ∧ ghost or alive ⇒ normal action `+0x5B` |
| +3 s | C | `CHero_ProcessReborn` `0x65DF0B`: dead ∧ `+0xE00`≠0 ∧ ≥3000 ms ⇒ `+0xE00`=0, send **MsgAction 145** once |
| 145 wire | C | 38-B 10010: `+4` hero id, `+16` timeGetTime, `+20` u16 145; all else 0 (`CMsgAction__Create(hero,0,0,0,0x91,0)`) |
| Inbound 145 | C | none — 0x80–0x9F table `0x7009C5/0x700995` sends 0x91 to default exit |
| Server ghost | S | **actionGhost = 137** in 15.10 (case table `0x4699D7` idx 26 → `0x468FD4`): user ∧ ¬alive ⇒ `CUser__SetGhost` `0x422FCC`: ghost byte `+1492`=1; status \|= 0x400 (bit 10) → attr 25 broadcast; attr 11 lookface broadcast. No timing check. 15.10 has no case for 145 |
| Numbering | S/C | 15.10 jump = 133, actionGhost = 137; 5517 jump = 137, ghost = 145. A 5517 server must not read 137 as ghost |
| Ghost lookface | S | `CUser__GetLookFace` `0x41A116`: ghost ⇒ base + 980,000,000 if `CUser__GetSex` (`(base%10000)/1000`) == 1, else + 990,000,000 |
| Status 0xA add | C | `m_timeGhost` `+0xE04` = now; 20-s counter at (W−80, H−200) (x=80 Arabic); StrRes 100036 "You have to wait for 20 seconds to revive!"; post **0x41D** → `CDlgMain_OnGhostBegin` → `CDlgXp_SetReborn(1)` |
| Ghost look | C | attr 11: family = lookface/10⁷ → look 980/990 (+`(lookface/1000)%10` only if that id resolves); `TransForm.ini` has only `[980] Look=98` / `[990] Look=99`, both `Jump=0`; `3dobj.ini` 98000000/99000000 → `c3/ghost/098|099/100.c3`; `3dmotion.ini` 92 rows each |
| Ghost render | C | no SimpleShadow (`0x64F85E`); RoleView vf+0x14 light = (0, 0,0,0, 0.8, 0.1×3) vs (g_93E908, 300,−300,−1000, fade, 0.1×3) (`0x64FBFF`) |

**Dead vs ghost:** status 5 alone = corpse (pose 0x14B, no walk, no revive buttons, 3-s timer running); 5 + 0xA =
mobile ghost (walk, buttons, 20-s timer). Every client gate keys on 0xA; the look comes only from attr 11.

| Source | Death statuses | 145 |
|---|---|---|
| S 15.10 | ghost bit only via SetGhost (137) | — |
| X Fox / Long | `BeKill` attaches DEAD **and** GHOST at once (Long: ∞ duration); timers ghost 3 s, revive 20 s | `SetGhost`: transform 98, 99 if `Gender==2`; Long syncs transform |

With X, the client sees ghost at death: buttons and the 20-s counter start immediately, and 145 only changes look. **U**: retail 5517 order.

## 2 Revival requests

| Control | Tag | Fact |
|---|---|---|
| Dialog | C | `CDlgXp` (IDD 189). Ctrl **0x4A2** (`+0xBB8`, `XpSkillType0`) → `CDlgXp_OnXpImg1` → mode 0 Revive. Ctrl **0x4A3** (`+0xAC8`, `XpSkillType5`) → `CDlgXp_OnXpImg2` → mode 1 Revive Here. Neither hides on click |
| Show/hide | C | 0x41D show (`m_bDie` `+0x104`=1, width 118); 0x41B / 0x41E hide (`CDlgMain_OnGhostEnd`) |
| Cross-server | C | `CDataMigrationSubject` `+4`==1 (MsgCrossSwitch 2501 `+4`=0; `CDataMigrationSubject_SetCrossServerMode` `0x68A3D8`) ∧ map bit 13 clear ⇒ 0x4A3 disabled, width 68 |
| Wire | C | **MsgAction 94**: `+4` hero, `+8` u32 mode (0/1), `+16` time, `+20` 94, rest 0 |

`CHero_RequestReborn(nMode)` `0x65D819` order (C):

| # | Test | Result |
|---:|---|---|
| 1 | mode 1 ∧ cross-server ∧ ¬bit 13 | silent |
| 2 | ¬status 0xA | silent |
| 3 | status 0x6F (StatusTips[98] Soul Shackle "revive is disabled") | silent |
| 4 | `+0xE04`≠0 (<20 s since ghost) | 100033 "You can't revive at the moment!" |
| 5 | current action in physical set (moving) | 100034 "You can't revive while moving!" |
| 6 | mode 0 | send |
| 7 | mode 1 ∧ ¬status **0x21** | 10484 "You can't revive here unless blessed by a Praying Stone!" |
| 8 | mode 1 ∧ ¬map bit 13 | 10485 "You can't revive here!" |
| 9 | — | send |

- **Heaven Blessing (C):** status 0x21 = `statuseffect.ini` row 33 `bless`; `CHero_HasBlessStatus21` `0x66F766` also feeds `CHero_GetEffectiveMaxPhysicalForce`.
- **Map rule (C):** `CGameMap+0xE8 & 0x2000` = bit 13 RebornNowEnable ([map catalog](map-catalog-5517.md): 119 maps). No region check.
- **Refusal (C):** no refusal packet exists. Inbound **94** is handled in the `CMsgAction__Process` prologue (`0x6FEE02`):
  unconditional post 0xD74 ⇒ shell `0x5CD4F8` hides CDlgXp and clears `m_bDie` (no status/look change). Correction: rev 1 said "no handler".

| Server | Tag | Fact |
|---|---|---|
| 94 handler | S | `0x46816D`: user ∧ ¬alive ⇒ bChgPos=1; `CUser__IsBlessed` (bless status object 0x10000000, or bless expiry `+2028` packed YYMMDDHH in future) ∧ param==1 ⇒ bChgPos=0; `CUser__Reborn(user, bChgPos, 1)`. Replay after revive: alive ⇒ ignored. Reborn sends no MsgAction 94 back |
| Early revive | S | bChgPos ∧ revive timeout (20 s, armed by BeKill) running ⇒ log "Cheat: %s reborn in %d seconds!", re-arm **60 s**, refuse silently. bChgPos=0 skips the timer. No map-flag or shackle check |
| Spell revive | S | magic status handler `0x49D880` ⇒ `Reborn(target, 0, 0)` |
| Fox | X | 94 ⇒ `Reborn(Data==0)`; CanRevive = dead ∧ respawn lock ∧ 20 s ∧ ¬SHACKLED |
| Long / Canyon | X | 94 ⇒ `RebornAsync(Command==0)` (their `Command` @+12 = 5517 `+8` param; later layout has a leading u32); CanRevive = dead ∧ 20 s; `RebornNowEnable` flag defined, never read |
| — | U | whether retail enforces bit 13, cross-server, bless, shackle or the 20 s for Revive Here server-side |

## 3 Revival synchronization

Client needs (C), each as an individual message:

| Need | Message | Client effect |
|---|---|---|
| Clear 5 and 0xA | 10017 attr 25 | ghost end → 0x41B + 0x41E, counter stop; dead end → `0x65ED40` (same cleanup as status-4 removal) |
| Normal look | 10017 attr 11 (family ≠ 98/99) | transform cleared |
| Life | 10017 attr 0 | — |
| Move | MsgAction **86** (`+8` map data id → map create `0x6FF6FB`) + position packets | none revive-specific |

`CUser__Reborn` `0x422CFA` order (S): SetStatus(0) (effect rebuilt: PK colour, team leader, bless) → ghost byte 0 →
`0x4232A7(0)` → attr 0 = MaxLife → attr 25 → attr 11 → `AddAttrib(8,+100)` = energy (`CUser__AddEnergy`, clamped) →
vf+0x5C(0) → bChgPos: `CUser__FlyMap`(record) (MsgAction 86 to self, then `CUser__EnterMap`) → bless remaining > 0 ⇒
re-attach bless status → `m_tLock` 10 s (§8) → script action 80000003. Mana is not touched (T source sets mana; S binary does not).
Client on dead removal: `Role_IssueActionCommand08(role, 0xB4)` (`0x672ED9`); on 94 echo: 0xD74 hides the dialog.

| Source | Tag | Revive effects |
|---|---|---|
| Fox | X | detach GHOST/DEAD, clear transform, stamina 100, life max, **mana max**, ChangeMap, action 8000002, `CHGMAP_LOCK_SECS` |
| Long | X | same + XP 0 |
| — | U | retail order and mana |

## 4 Ghost movement networking

| Item | Tag | Fact |
|---|---|---|
| Walk packet | C | 10005 selector = 1 only if current action ∈ {0x78, 0x79} (`0x65C5B8`); ghost always walks ⇒ 0. No ghost field |
| Downgrade | C | `0x7431F3`: alive ⇒ run 0x12; dead ∧ ghost ⇒ walk 0x11 (`0x743126`); dead ∧ ¬ghost ⇒ no command |
| Jump | C | ghost look 980/990 has `Jump=0`; dead refused anyway |
| Ack | C | same 10005 echo as ordinary walk |
| Server | S | walk: dead ∧ ¬ghost ⇒ STR_DIE, ghost allowed; jump: dead ⇒ STR_DIE |
| — | U | retail ghost cadence/occupancy rules |

## 5 Revival destinations

| Item | Tag | Fact |
|---|---|---|
| Client knowledge | C | no revive coordinates in any client file; only bit 13 (Revive Here). Destination arrives via map/position packets |
| Death record | S | `CUser__BeKill` `0x41CDBD`: `CGameMap__GetRebornMap` `0x433D0B` = current map field 13 `reborn_mapid` → that map's fields 11/12 `portal0_x/y` (field 14 `reborn_portal` read, unused) → `CUser__SetRecordPos` (`recordmap_id/recordx/recordy`, no DB save). Failure ⇒ CHECK log, record unchanged |
| Ordinary revive | S | FlyMap(record) |
| Revive Here | S | no move |
| Fox | X | same GetRebornMap→record; syn map outside war ⇒ record 1002 (438,398); Revive Here falls back to record when not blessed or on prison/PK-field/PK-game/syn maps; map 7503 event exception |
| Long | X | GetRebornMap uses current map `link_x/link_y` when both ≠0, else reborn map portal; same Revive Here fallbacks (newbie-disable instead of PK-game) |
| Data | — | [map catalog rev 2](map-catalog-5517.md) rows carry `reborn_map`/`portal0`/`revive_source` (L 211, Q 53, EU 14, T7 3, Z 1). Only the **target** map's portal0 matters: 227/289 rows resolve; T7 (TQ 2007/08) and L agree on `reborn_map` for all 156 shared rows; target portal0 identical in T7/L/Z (1002 (430,380), 1000 (499,650), 1011 (193,266), 1015 (717,577), 1020 (566,565), 1213 (448,272), 1219 (1003,1278)). Gaps: 60 rows `reborn_map`=0 (48 no-TQ-row maps incl. 2065, 7 unavailable, 1779/1780/1801/1860/1969 Q rows with 0); 2060 target portal0 (0,0); 1036 portal0 (303,237) unwalkable on its catalog terrain (S `SetRecordPos` rejects non-standable ⇒ record unchanged) |

Unprovable from the binaries (**U**): retail 5517 values for the 60 zero rows and any 5517-only map; whether retail applied
map-type exceptions (PK field, syn war, prison) or Long's link-point rule; server-side Revive Here location limits;
cross-server destination. Strongest evidence order: T7∧L agreement > L > T7 > community.

## Corrections made elsewhere

- [01_core_packets](../Network/01_core_packets.md) subtypes: 94 is actionReborn (not Hotkeys; inbound hides revive UI); 145 actionGhost added; 159 = overhead countdown (`CHero_StartOverheadCountdown` `0x66699D`, `+0x2ED0..D8`), not SetGhost; 162 = server auto-pathfinding (not Reborn).
- 1056 outbound trade quit on death ([05_guild_packets](../Network/05_guild_packets.md)).
- `CHero_TickStatusFlagExpiryPacketSend` renamed `CHero_ProcessReborn`; `CHero_HasExtendedPhysicalForceGaugeStatus` renamed `CHero_HasBlessStatus21`.
- [TQ 15.10 semantics](tq-server-15.10-runtime-semantics.md): death record point is now binary-traced.

## 6 Login, reconnect, map entry, spawn (C)

| Event | Client behaviour |
|---|---|
| Login / reconnect | `CGameMain_AccountSetupAndSendLoginAuthPacket` → `CHero_ResetStateForLogin` `0x65700E` → `CHero_InitializeState`: `CRole__Init` zeroes masks `+0x70/+0x80/+0x90`, `+0xE00/+0xE04`=0, transform `+0xEC`=0, `0x65ED40`; cross-server mode reset. Revive dialog not touched (no 0x41B/0x41E/0xD74) |
| 1006 | no status mask; `+8` → `CRole__SetTransformLookSourceId` (`+0xDC`), `+10` packed look without the 10⁷ family ⇒ **cannot** carry ghost look |
| Ghost look sources | only 10014 spawn (`0x756BA4`) and 10017 attr 11 (`0x757B13`) call `CRole__SetTransformLook` |
| Status at login | only 10017 attr 25. Diff from zero: dead+ghost in one packet ⇒ `+0xE00`/`+0xE04`=now, trade quit 1056 sent, buttons shown, 20-s counter restarts, and **145 is sent again 3 s later** |
| Map entry | no writer of `+0xE00/+0xE04` or the masks outside ctor, InitializeState, status diff, ProcessReborn ⇒ map change keeps ghost state and timers |
| Spawn order | 10014: pose chosen at `0x756D05` **before** the packet mask is applied at `0x756E4E` (vf+0xD0). New role ⇒ pose = packet action `+0x5B`; known role ⇒ its old mask (dead∧¬ghost ⇒ command 4 / 0x14B). Then `Role_ApplyStatusFlagBitfieldAndDispatchEffects` (no pose for dead add) |

| Server | Tag | Fact |
|---|---|---|
| Login while dead | T | `SetStatus(STATUS_NORMAL)`; life ≤ 0 ⇒ life 1 (User.cpp load path) |
| Login while dead | X | Long/Canyon `ReallyRevive(true,false)` on logout/login when dead |
| Spawn pose | S | `CMsgPlayer::Create` `0x4790D5` pose = `GetPose()`; no dead override (T source identical) |
| — | U | retail login state for dead users; retail 10014 action for a corpse |

## 7 Ghost entering another player's view (C)

One 10014 is sufficient: `+4` lookface with family 98/99 ⇒ ghost model; `+0x16` mask with 5 and 0xA ⇒ ghost render
(no shadow, ghost light) and walk gates; `+0x5B` normal stand action. No extra 10017 is required. An unknown mover
triggers MsgAction 0x66 query ([movement](movement.md)). A **corpse** (5 without 0xA) first seen by a client stands
unless the server puts a lying action in `+0x5B` — S/T send `GetPose()`; **U** for retail.

## 8 Post-revive / map-entry lock

| Item | Tag | Fact |
|---|---|---|
| Name | T | `m_tLock` / `CHGMAP_LOCK_SECS` = 10 (fight-master `User.h:83`; later replaced by `STATUS_PK_PROTECT`) |
| Start | S | `CUser__EnterMap` `0x417CF7` and `CUser__Reborn`: CUser+2372 = 10, +2376 = now s |
| Effect | S | `CUser__IsBeAtkable` `0x42B09C`: lock active ⇒ cannot be attacked |
| Clear | S | `CUser__ProcessOnMove` (move) and `CUser__ProcessOnAttack` `0x418D12` (attack) |
| Client | C | no status bit, string or UI for it in 5517 (statuseffect/StatusTips/StrRes); server-only |
| X | X | Canyon/Long `protectionTimer` identical (EnterMap + Reborn start, move/attack clear, IsAttackable false) |
| — | U | retail 5517 value and existence (consistent TQ 2008 → Canyon 6192 lineage) |

## Retail evidence status (2026-10-16 search)

No retail 5517 server binary, packet capture or contemporary trace exists locally (pcap/log sweep of Remakes and
Evidence trees) or in public search (elitepvpers, conquerwiki, cooldown.dev). Every server rule above is therefore S/T/X.

| Question | Strongest evidence | Class |
|---|---|---|
| Ghost/look timing vs 145 | dead bit at death (attr 25), ghost bit + look on ghost request | S (X differs: both at death) |
| 94 authorization | 20 s only for ordinary revive; bless for Revive Here; no bit-13/cross-server/shackle | S; X adds shackle (Fox) |
| Revival sync | individual attrs 0/25/11, energy +100, fly 86; no mana | S |
| 10-s timer | change-map lock, attack immunity until move/attack | S + T names |
| Destinations | T7∧L `reborn_map` + target portal0 | data, not retail-proven |
| Login/spawn ordering | client facts §6 | C; server side T/X |
| Ghost in view | 10014 alone | C |
