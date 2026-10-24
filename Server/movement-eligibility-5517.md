# Movement eligibility, statuses, mount and vigor — 5517

Verified 2026-10-15, Binja on `Conquer.exe` 5517 (names/comments saved in the bndb). Server-side columns: TQ
CQServer 15.10 MsgServer (headless IDA, names in the `.i64`) — **5095-era; no retail 5517 server exists in the
workspace**, so every 5517 server rule below is unproven unless marked client-proven.
Related: [movement.md](movement.md), [position-sync.md](position-sync.md),
[TQ 15.10 semantics](tq-server-15.10-runtime-semantics.md#movement-visibility-kickback).

## Status storage and sync (client-proven)

| Item | Fact |
|---|---|
| Primary mask | `CRole+0x70`, 128 bits; `Role_HasStatusFlag` `0x6E50D4` (index ≥0x80 ⇒ false) |
| Secondary mask | `CRole+0x80`, 128 bits; `Role_TestSecondaryStatusBit` `0x6E5248` |
| Primary writers | `10017` attribute **25**: 16-byte value = whole mask (`CMsgUserAttribEx__Process` `0x7574CB`, record stride 0x14, value at record+0x10); `10014` spawn; client sets only 0x3E/0x3F (equipment lock) itself |
| Secondary writer | **2075** `CMsgStatusDetail2075__Process` `0x75C5F9` (was mislabelled CMsgMagicEffect): builds a fresh set from the records whose flag byte ≠0 and **replaces** `+0x80` wholesale |
| 2075 layout | `+4` entity, `+8` count, records 0x14 from `+0xC`: `+0` status index, `+4` u8 op (0 add, 1 remove, 2 update-if-flag), `+5` u8 flag, `+8` value A, `+0xC` duration, `+0x10` value B. Handler table `StatusDetailHandler_GetForStatus` `0x7688D7` |
| Expiry | client never clears movement statuses; server sends the mask/records |

## Movement-relevant statuses

Meaning column: behaviour is client-proven; names come from `ini/statuseffect.ini` (col 3 = `StatusTips.ini`
section; that column link is a data correlation, loader not traced).

| Index | Name (data) | Client behaviour |
|---:|---|---|
| 5 | dead | blocks walk/run/ride/jump/charge/mount; 3 s after death client sends MsgAction **0x91** (`CHero_ProcessReborn` `0x65DF0B`; full sequence in [death/ghost/revive](death-ghost-revive-5517.md)) |
| 0xA | ghost | with 5: walk (cmd 0x11) only; run/ride requests downgrade to walk; may click onto occupied tiles |
| 0x1B | fly | walk/run click ⇒ jump request instead (unless autorun); jump climb cap 100; jump pose 0x1FE; mount refused `STR_MOUNT_MOUNT_FLY` |
| 0x2E | `cyclonehandcycle` | walk ⇒ run; jump, charge refused; peak-elevation check returns false |
| 0x32 | ride | ride command 0x13 when vigor >1; mounted jump/charge vigor limit |
| 0x34 | Accelerated (tip 68) | 2075 value B ⇒ `CRole+0x5C` speed % (`CRole_SetMoveSpeedPercent5C`) + hero `+0xDF8` |
| 0x35 | Decelerated (tip 69) | value B ⇒ `CRole+0x5C` + hero `+0xDFC` |
| 0x36 | Flustered (tip 70) | blocks player move/jump/charge input; with secondary bit **client auto-wanders**: random tile ±5, passable, Δelev ≤25, cmd 0x12 (0x13 if riding) — `CHero_TickStatusFlag36AutoWander` `0x657B32` |
| 0x37 | Sprint (tip 67) | add: effect `move_improve`, hero `+0x2DA4` = value A (vigor max bonus); remove: 0 |
| 0x3A | Stun (tip 64) | blocks input; add ⇒ command 0x2A; remove ⇒ command 5 |
| 0x3B | Freezed (tip 66) | blocks input; add ⇒ `frost_app`, saves current walk target, command 5; remove ⇒ `frost_end`, **re-issues walk (cmd 0x12) to the saved target** |
| 0x5F | war-flag carrier | jump/charge refused `STR_WARFALG_CANNOT_JUMP`; walking allowed |

`CRole+0x5C` scales action frame interval `×100/(pct+100)` ([action translation](../Rendering/roleview_dll/12_action_id_translation_state_machine.md)),
so steps get faster/slower — server cadence policy must follow these statuses.

## Request gates (client-proven, player input)

Common to walk `Role_RequestCommandType11MoveToTile` `0x657940`, run `…12…` `0x657CD6`, ride `Role_QueueCommandType13MoveToTile`
`0x65833B`, jump `Role_RequestJumpToTile` `0x658965`, charge `Role_RequestMountedChargeToTile` `0x658536`:
not suppressed (below), none of 0x36/0x3B/0x3A, world entry complete, booth closed (`CHero+0x2A5C` = boothManager.isActive),
not in busy command 0x20/0x21/0x28/0x2E (`Role_IsInBusyCommand20_21_28_2E`; on map **1039** the refusal also sends
MsgInteract subtype 25 self-pair).

| Request | Extra gates |
|---|---|
| walk 0x11 | 0x2E ⇒ run; 0x1B ⇒ jump; dead needs ghost; alive hero: clicked tile with another role ⇒ ignored |
| run 0x12 | 0x1B (no autorun) ⇒ jump; dead+ghost ⇒ walk |
| ride 0x13 | dead+ghost ⇒ walk; cmd handler falls back to 0x12 unmounted, 0x11 if vigor ≤1 |
| jump | not 0x5F, not 0x2E, alive; transformed (`CRole+0xEC`): `TransForm.ini [id] Jump` must be ≠0 (no record ⇒ allowed); untransformed: ≥3000 ms since `CRole+0x125C`; rounded dist 1..16 else StrRes 100032; horse-race map flag `0x02000000` ⇒ `STR_RIDE_MATCH_MSG_FORBID_JUMP`; riding ∧ dist > vigor ⇒ tip, no request; peak elevation (below) else StrRes 100022; target tile missing/blocked or living occupant ⇒ StrRes 100023 |
| charge 0x15 | riding; not transformed; same 3000 ms; dist 1..16 `STR_CHARGE_FAIL_DISTANCE`; horse-race map ⇒ `…FORBID_CHARGE`; dist ≤ vigor; \|tail elev target−source\| ≤160 (`MOUNT_JUMP_HEIGHT_LIMIT`); peak elevation else `STR_CHARGE_FAIL_TARGET`; target as jump |

Peak elevation `Role_IsDirectPathPeakElevationDeltaWithinLimit` `0x65D31A`: max tail-link elevation over the rounded
direct line excluding the source (`CGameMap_BuildLineTileEntriesAndFindPeakElevationTile` `0x61E886`) minus source
elevation ≤ `CRole+0x1258` — set to **200** in both constructors and never written again; status 0x1B uses **100**.

`CRole+0x125C` = time of the last cast whose `MagicEffect.ini SortOfAct` = 19 (transformation spells, e.g. 1270,
1280, 1350, 1360) — `CHero_SendEncodedMagicInteractionAndStartUiTimers` `0x6F82FC`.

## Suppression and interruption

| Source | Effect |
|---|---|
| `CHero_SetDirectMovementSuppression` `0x65AE9A` | `+0xFB4/+0xFB8`: all requests refused for 1000 ms. Set (1) by `CHero_RequestAttackTarget` `0x65B625` after it sends MsgInteract 2 and forces command 5; cleared (0) by the server's MsgInteract subtype **45** echo of the hero's attack |
| tracked casts | cast of a learned magic with SortOfAct 40 (MagicEffect `103150`) within 1000 ms ⇒ refused |
| freeze/stun add | movement stopped (command 5); freeze resumes the saved walk on removal |
| attack echo 45 | cancels autorun |

## Mount and vigor (client-proven)

| Item | Fact |
|---|---|
| Vigor | `CHero+0x2DA8`; only writer `CHero_SetMountVigor` ← packet **1033** mode 2 value `+8` (`CMsgNpcInfoEX__Process` `0x74A5E6`). Client never decrements or regenerates it — server-authoritative |
| Max shown | steed (equip slot 12) item `+0x18C` u8 + item `+0x4A` s16 + `CHero+0x2DA4` (Sprint bonus) — `STR_MOUNT_MPICON_TIP` "Vigor: %d/%d … restored while standing still" |
| Mount request | `CHero_RequestMountRideMagic7001` `0x716EB4`: not fly; not interacting; map flag `0x40000` or map region type 8 at hero tile with `+0x18`=0 ⇒ forbidden; not dead/ghost; steed in slot 12; steed add level ≥ region `+0x18`; magic 7001 learned; capped stamina ≥ magic cost (tip text: 20). Sends magic 7001 on self. Status 0x32 comes back from the server |
| Riding move | cmd 0x13 ⇒ actions 0x7A/0x7B ⇒ 10005 selector 9 (24-dir); vigor ≤1 ⇒ walk |
| Mounted jump/charge | distance ≤ vigor (`MOUNT_JUMP_MOVEPOINT_LIMIT`) |
| Dismount | unequip slot 12 refused on horse-race maps (`CHero_RequestUnequipSlot` `0x6DB8E9`) |
| Charge wire | MsgAction 0x89 with byte `+0x24` = 1 (`CMsgAction_CreateMountedCharge89` `0x6FEAD0`); remote role: 0x89 ⇒ cmd `0x14 + (+0x24≠0)` |

Not established: how much vigor a step/jump/charge costs and the regeneration rate (server-side; no binary has steeds).

## Local animation vs authoritative tile — correction to [movement.md](movement.md)

The client keeps two tiles. **Gate** `CHero+0xCEC/+0xD08`: changed only by echoes (10005 local: gate += delta;
0x89 local: gate = target; 108/156 corrections). **CRole tile** `+0x318/+0x334` (vtable `+0x14`, used by new requests and
by idle report 100): `Role_RecomputeCoordinateGateCacheFromProjectedPosition` `0x64E9A5` sets it from the finished
action's end point. Walk steps and jumps are animated locally before any echo, so a refused request with no reply
leaves the CRole tile at the unauthorised target while the gate stays put; subtype 108 restores both. "Withholding
the reply refuses" is true for the gate only.

## Remote presentation

| Packet | Client |
|---|---|
| 10005 selector 0 / 1 / 9 | remote command 0x16 walk / 0x17 run / 0x18 ride; ignored while the remote player is in command 0x20/0x21 |
| MsgAction 0x89 | `+0x24`=0 jump (0x14), 1 charge (0x15); unknown entity ⇒ client sends 0x66 query |

## Native server enforcement (TQ 15.10 only)

| Rule | 15.10 | 5517 retail |
|---|---|---|
| Walk status gates | dead (¬ghost) ⇒ `STR_DIE`; transformation with `cq_monstertype.attack_user` bit `0x40` (FIXED) ⇒ `STR_YOUR_CANNOT_WALK` + KickBack. **No freeze/stun/lock check** in the binary | unknown |
| Jump status gates | dead ⇒ `STR_DIE`; transformation without bit `0x20` (JUMP) ⇒ socket kicked | unknown |
| Jump geometry | Chebyshev ≤18 else kicked; landing `IsStandEnable` else teleport to fallback + kicked (`0x42082D`); altitude line check only on map 1038 | unknown; client: Euclid ≤16, peak ≤200 |
| Cadence | walk avg ≥187 ms, jump avg ≥643 ms over 4 client timestamps, else kicked | unknown |
| Refusal | KickBack 108, 5 s suppression | unknown; client design (local animation) needs 108 |
| Jump visibility | jump broadcast from the **origin** (incl. self), then `JumpPos` mutual `SendShow` to things whose x or y crossed into ≤18; no intermediate points | client: unknown jumper ⇒ 0x66 query |
| Mount, vigor, charge, 2075 statuses | **absent** (no steed/vigor/ride strings or code) | unknown |
