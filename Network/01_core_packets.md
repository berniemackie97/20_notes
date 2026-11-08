# Core Packets — Login, Connection, Player Identity

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## Transport framing and the client's receive path — verified 2026-08-18

Every packet below is subject to these limits. Source file is `..\3DRole/Network/socket.h`
(from the error strings inside `CGameSocket_ReceiveMsg`).

**Wire frame** = `[packet of `size` bytes][8-byte "TQServer" signature]`. The `size` word at `+0`
does **not** include the signature: in framing mode 2 `CGameSocket_ReceiveMsg` reads the header
value, does `_Size_1 += 8` to decide how many bytes to wait for, then `_Size -= 8` before handing
the packet up. Inbound client frames use the `"TQClient"` signature the same way.

**Maximum packet size is `0x400` (1024 bytes), enforced twice:**

| Site | Check | Consequence of exceeding |
|---|---|---|
| `CGameSocket_ReceiveMsg` (0x6E1E14, 0x6E1D77) | `_Size_1 <= 0 \|\| _Size_1 > 0x400` | logs `"ERROR: Receive package len[%d] > _MAX_MSGSIZE"`, then **zeroes the ring's available count and read offset** — i.e. the client throws away its whole receive buffer |
| `CNetMsg__ProcessMsg_Dispatch` (0x6DF3D8) | `arg1 == 0 \|\| arg2 s> 0x400` | returns `nullptr`, packet silently dropped |

A server must never emit a packet over 1024 bytes: the failure is not a dropped packet but a
desynchronised client.

**The client reassembles a byte stream; it does not assume one packet per read.**
`CGameSocket_ReceiveMsg` owns a **64 KiB ring buffer** at `this+0x200C` with the available count
at `this+0x1200C` and the read offset at `this+0x12010`:

- the length word is read out of the ring little-endian by hand
  (`ring[off] | ring[off+1] << 8`) with wraparound via `mod 0x10000`;
- if the ring does not yet hold the whole frame it calls
  `CGameSocket_ReceiveAndDecryptSocketBytes()` and re-checks, returning 0 to wait for more;
- it then `memcpy`s exactly **one** complete frame to the caller, sets `*arg2 = size`, and
  advances the read offset modulo `0x10000`;
- the 8 trailing bytes are compared against `"TQServer"` with `memcmp`; a mismatch logs
  `PROTOCOL_PACKAGE_FLAG failed` and closes the socket.

`CNetMsg__ProcessMsg` (0x6DEBAF) then loops: `ReceiveMsg` → `CNetMsg__GetSize` →
`CNetMsg__ProcessMsg_Dispatch` → `begin += size; remaining -= size`, repeating while bytes remain,
and finishes with `CGameSocket_FlushSendBuffer`.

**Consequence for the server:** frames may be coalesced into one write freely. Reassembly is the
ring buffer's job and is independent of how the server chunks its writes; a frame split across
socket reads is buffered, not discarded.

**`CNetMsg__ValidateHeaderAndCopy` (0x6DF2B9)** — called by every `Parse` — enforces only:
1. the buffer is non-null,
2. the caller's byte count **equals** the `size` word in the header,
3. `type != 0`,

then `memcpy`s `size` bytes to `object+4`. There is **no** minimum-size and no per-type size check,
so a short packet is accepted and the handler reads whatever follows in the object. That region is
safe rather than random: `CNetMsg__ResetPacketBuffer` (0x6DF290) does `memset(object+4, 0, 0x400)`,
so bytes past a short packet read as **zero**. A packet must still cover every offset its handler
reads, or those fields silently arrive as 0.

## MsgConnect (Type 1002)
**Direction**: S→C (registered but NoopProcess in this build)
**Purpose**: Present in the `CNetMsg` dispatch table, but **not used** for the DH handshake/crypto in this build (handshake is handled at the `CGameSocket` layer; see above).
**Dispatch**: Create `CMsgConnect__Create` (0x753F88), parse `CMsgConnect__Parse` (vtable[1], 0x753FEE), process `CNetMsg__NoopProcess` (0x5AD9B1)

**Verified parse behavior**:
- `CMsgConnect__Parse` calls `CNetMsg__ValidateHeaderAndCopy` to validate `size` (word at +0), ensure `type != 0` (word at +2), and copy the raw packet to object+4.
- It then checks `type == 1002`.

**Verified process behavior**:
- `Process` is `CNetMsg__NoopProcess` in this build.

**Status**: No payload fields beyond the header are referenced by client code in this build.
```c
struct MsgConnect {
    uint16_t size;
    uint16_t type;          // 1002
    uint8_t  payload[];     // Unreferenced by client code in this build
};
```

## MsgAccount (Type 1063) — S→C Award/CrossFlagWar Updates
**Purpose**: Award updates and cross-flag-war list/UI updates (verified by `StrUpdateAward` and `CCrossFlagWarMgr__*` calls). Despite the IDA label "CMsgAccount", this is NOT a login packet in this build.
**Dispatch**: Create `CMsgAccount__Create` (0x6F448C), process `CMsgAccount__Process` (0x6F469F)
**Direction**: S→C only

> **Login packets use different types**: The client selects among native account-auth packet types
> **1060**, **1084**, **1098**, **1102**, and **1121**. Type **1121** is the Facebook/UIN session
> variant; it is not selected solely by DH transport state. See
> [13_connection_lifecycle.md](13_connection_lifecycle.md) for the full authentication flow.

**Note**: This handler was previously labeled `Handle_Update_Award`; the `StrUpdateAward` string appears in modes `2–7`.

**Verified field usage in `CMsgAccount__Process`** (offsets relative to packet start):
- `+4` (u16) is the mode selector.
- `+6` (u32) is a submode/flag (compared against `1` and `3` in multiple branches).
- `+10`, `+14`, `+18`, `+22`, `+26` are dwords used across modes.
- Entry arrays begin at `+30` with mode‑specific strides (20/36/52/60/62 bytes).

**Mode 0 (`+4 == 0`)**:
- `+10` is stored via `MFC__SetDword_0x4` on the mode‑0 manager.
- `+14` (u32) is entry count; entries at `+30` with stride 52 bytes.
- Each 52‑byte entry is treated as 13 dwords and passed to the mode‑0 manager add function.
- `+6` is checked; if not `1`, a finalize/update call is made on the mode‑0 manager.
- `+18`, `+22`, `+26` are passed into UI/update calls; ends with `PostMainWndMsg_0x464(0xC7F, 0)` and `PostMainWndMsg_0x464(0xDD6, 0)`.

**Mode 1 (`+4 == 1`)**:
- If `+6 == 3`, processes `+14` entries of stride 60 at `+30`. Fields used per entry: dwords at `+30`, `+34`, `+38`, `+42`, `+50` and a string at `+54`. After list update, uses `+18`/`+22` and posts `PostMainWndMsg_0x464(3361, 0)`.
- If `+6 != 3`, processes `+14` entries of stride 60 at `+30` by passing the entry pointer to the mode‑1 manager. If `+6 != 1`, an extra finalize call is made. Uses `+18`/`+22`/`+26`, posts `PostMainWndMsg_0x464(0xC81, 0)`, then `PostMainWndMsg_0x464(3542, 0)`.

**Modes 2–7 (`2 <= +4 <= 7`)**:
- If `+6 == 3`: uses `+18`/`+22`, posts `PostMainWndMsg_0x464(0xD21, 0)`, and shows a message box using the string key `StrUpdateAward`.
- If `+6 != 3`: uses `+18`/`+22`/`+26`, posts `PostMainWndMsg_0x464(0xC81, 0)` and `PostMainWndMsg_0x464(0xDD6, 0)`, then shows a `StrUpdateAward` message box.

**Mode 8 (`+4 == 8`)**:
- `+10` and `+14` are stored on the mode‑8 manager; `+18` is passed to `MFC__SetDword_0x18`.
- `+14` is entry count; entries at `+30` with stride 20 bytes, each passed to the mode‑8 manager.
- Posts `PostMainWndMsg_0x464(3542, 0)`.

**Mode 9 (`+4 == 9`)**:
- `+10` stored; `+14` entry count; entries at `+30` with stride 36 bytes; `+18` stored afterward.
- Posts `PostMainWndMsg_0x464(3556, 0)`.

**Mode 10 (`+4 == 10`)**:
- Uses `+10` and `+18`, then processes `+14` entries with stride 62 bytes.
- Per entry, the handler reads: `+30` (u16), strings at `+32` and `+48`, and dwords at `+84` and `+88` (all relative to entry base).
- Posts `PostMainWndMsg_0x464(3360, 0)`.

**Mode 11 (`+4 == 11`)**:
- Uses `+18` as the sole parameter to update the mode‑11 manager.

## Type 1012 (class unproven; label `MsgPlayer` withdrawn — `MsgPlayer.cpp` asserts are in the 10014 handler `0x755F64`)
**Direction**: C→S (client builds and sends player identity/response)
**Purpose**: Spawn player entity in world
**Dispatch**: Create `CMsg1012__Ctor` (0x764997), parse `CMsg1012__Parse` (0x7649FD), process `CMsg1012__Process` (0x764A42)

**Parse**: `CMsgPlayer__Parse` — standard header validation, then `type == 1012`.

**Verified field usage in `CMsgPlayer__Process`**:
- `packet+8` is set to `timeGetTime() ^ hero_id` (hero_id read from singleton `+204`).
- `packet+28` is set from the first two bytes of the current player name (XOR with constants).
- `packet+12`, `packet+16`, `packet+20`, `packet+24` are filled with random 32-bit values.

## MsgUserInfo (Type 1006)
**2026-09-17 semantic audit:** [current native findings and corrections](MsgUserInfo1006-semantic-closure-2026-09-17.md),
with the [complete wire table](../../10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md).
The earlier "apparently inert"/"no consumer" searches below are historical candidate searches,
not dead-field proofs. The +97/+98 feature is now proven to be subprofession ID/promotion phases,
distinct from training levels. The [focused historical reconciliation](MsgUserInfo1006-historical-field-reconciliation.md)
now records LegacyDeed, LegacyMedal, LegacyMedalSelect, Virtue, LegacyNobility and LegacyAutoAllot
with attributed historical names and native proof boundaries. Broad receiver analysis is stopped.

**Direction**: S→C
**Purpose**: Full user information payload (stats, equipment, etc.)
**Dispatch**: Create `CMsgUserInfo__Create` (0x764197), parse `CMsgUserInfo__Parse` (0x764253), process `CMsgUserInfo__Process` (0x764276)

**Parse**: `CMsgUserInfo__Parse` — standard header validation, then `type == 1006`.

**Verified string-list helper**:
- `CMsgUserInfo__Process` reads string indices 0..2 from a list object at `this+0x408` using `MsgStringList__GetEntry` (same `[count][len][bytes]...` format as MsgTalk).

**Verified field usage in `CMsgUserInfo__Process`** (offsets relative to packet start):
- `+4` assigned to singleton `+204` and passed to `RandTable__InitFromLocalPlayerId`.
- `+8` passed to `CRole__SetTransformLookSourceId` (u16).
  - downstream player RoleView evidence: type-1 key `0` (`sub_10001EB8` in `RoleView.dll`) consumes a separate low-range `bodyAppearanceSourceId` and rewrites million-range body/helmet source ids from it.
  - managed/client packet models must therefore preserve `+8` independently from packed `lookface` / hair.
- `+10` used as a packed appearance composite:
  - `% 0x3E8` -> `bodyAppearanceSourceId` for `CRole__CreateRoleView(..., type=1)`
  - `/ 0x3E8 % 10` -> `transformFlag` stored directly at `hero+0x178`
  - `/ 0x2710 % 0x3E8` -> `meshTransformId` for
    `CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform`
- `+14` split into `% 1000` and `/ 1000` for `CRole__SetLinkedSourceLookupId` and `CRole__SetHeadAttachmentSource` (u16).
- `+16` passed to `CObject__SetDword_0xC` (u32).
- `+20` passed to `CObject__SetDword_0x10` (u32).
- `+24`, `+28` stored to singleton `+2144` and `+2148` (u32/u32).
- `+32` stored to singleton `+2140` (u32).
- `+36` stored to singleton `+2116` (u32).
- `+40` stored to singleton `+2120` (u32).
- `+44` stored to singleton `+2232` (u32).
- `+48` divided by `0x186A0` and passed to `CRole__SetDword_0x83C` (u32).
- `+52`, `+54`, `+56`, `+58` stored to singleton `+1276/+1284/+1288/+1292` (u16/u16/u16/u16).
- `+60` stored to singleton `+2112` (u16).
- `+62` passed to `CRole__SetDwordField606_673EAC` (u16 widened to dword call arg).
- `+64` passed to `CRole__SetEncryptedValue_0x5E0` (u16).
- `+66` stored to singleton `+2152` (u16).
- `+68` stored to singleton `+2104` (u8).
- `+69` stored to singleton `+2092` (u8).
- `+70` passed to `CRole__SetDword_0x850` (u8).
- `+71` passed to `CRole__SetDword_0x854` (u8).
- `+72` stored to singleton `+3892` (u8).
- `+73` passed to `CRole__SetMetempsychosisCount` (u8).
- `+74` stored to singleton `+3300` (u8).
- `+75` read as a 32-bit value and passed to `MapValueToEffectId`; also used as a parameter to `s__GetSingletonPtr_404460`.
- `+79` passed to `Handle_Coach_Inc_Prompt` (u16).
- `+81` passed to a vtable call at `+228` (u16).
- `+85` passed to `CRole__SetDword_0x9A4` (u16).
- `+87` passed to `CRole__SetDword_0x474` (u32).
- `+91` passed to `CRole__SetDword_0x8AC` (u16).
- `+93` passed to `CObject__SetDword_0x14` (u32).
- `+97` passed to `CRole__SetDword_0x450` (u8), and controls digit extraction from the 64-bit value at `+98`.
- `+98` and `+102` passed together to `CRole__SetDwordPair_0x468_0x46C` (u32/u32); also read as a 64-bit value for digit extraction.
- `+106` passed to `CHero__SetDword_0x2E08` (u32).

**Verified post-processing side effects in `CMsgUserInfo__Process` (`0x764276`)**:
- Reads MsgStringList entries `0..2` and applies them to the local-hero runtime before the late UI posts.
- Calls `CRole__SetTransformLookSourceId(hero, packet+0x08, 1)`, and with `refresh=1` this
  immediately reaches `CRole__ReapplyAllVisualSources -> CRole__ApplyAllVisualSourcesToRoleView`.
- Builds and sends a client `CMsgAction` / `MsgData` packet with `actionEnterMap` immediately after the user-info hydrate step:
  - constructor: `CMsgAction__Ctor` (`0x6FE8A3`)
  - builder: `CMsgAction__Create` (`0x6FE95F`)
  - send: `CNetMsg__Send`
- Embedded evidence string in the function:
  - `"msg.Create(g_objHero.GetID(), 0, 0, 0, actionEnterMap)"`

**Parity implication**:
- `1006` is not just a passive state snapshot. It is the verified gate that causes the client to emit `DataAction.EnterMap` (`74`).
- `1006` also carries the local player's type-1 RoleView appearance seed at `+8`; do not collapse that value into packed `lookface` or hair fields.
- `1006` already performs the native visual-source reapply into RoleView; missing startup-local-hero
  parity must therefore be sought after this point in the render/update chain.
- Server implementations should therefore wait for the post-`1006` client `74` before sending the initial world-entry burst (`1110/1016/74/104/105/...`) instead of pushing that burst eagerly before the client finishes processing `1006`.
- In the managed rewrite, this also means the startup/login runtime must keep consuming the first post-DH packets itself until the bootstrap window is complete, because scene ingress is still disabled until `0x483`.

**Verified fixed-body size (re-proven 2026-08-15 from `CMsgUserInfo__Process` decompile)**:
- the last fixed-body read is the `u32` at `+0x6A` (106), so the fixed body is **110 bytes** and the
  MsgStringList begins at **+110**. This agrees with the managed client reader
  (`10_work/src/Conquer.Network/Packets/MsgUserInfo1006PacketReader.cs`, `StringListOffset = 110`)
  and with the legacy server writer (`FixedBodyLength = 106` measured from packet `+4`).
- `hero+0x830` is explicitly zeroed by `1006` (same field `MsgUserAttrib` id `8` targets).
- string-list buffers are `0x10` bytes each; entry `0` -> `CRole_SetName`, entry `1` is read but
  unused in this handler, entry `2` -> `sub_6728DC`.

**Field semantics proven from the role-attribute dialog (2026-08-15)**

The `1006` field meanings below are proven from the *readers* of each hero field, not imported from
any reference server. The decisive evidence is the role-attribute dialog:

BNinja anchors (renamed this session):
- `CDlgRoleAttribute_InitControls` (`0x506148`) — binds the `RoleAttribute_AddBtn` /
  `RoleAttribute_DecBtn` / `RoleAttribute_ConBtn` controls and the label objects.
- `CDlgRoleAttribute_RefreshLabelsFromHero` (`0x506914`) — writes each label from a specific
  `CHero` field.
- `CDlgRoleAttribute_RefreshAllotButtonsAndPendingStats` (`0x5077E5`) — per-label allot gating,
  each branch carrying a distinct `STR_ALLOT_*` string key.
- `CHero_FormatProfessionDisplayName` (`0x660627`), `CHero_GetFirstProfession` (`0x6762F0`) /
  `CHero_SetFirstProfession` (`0x6762F7`), `CHero_GetPreviousProfession` (`0x676304`) /
  `CHero_SetPreviousProfession` (`0x67630B`), `CHero_GetTitleId` (`0x674B4F`) /
  `CHero_SetTitleId` (`0x674B56`), `CHero_SetSmoothedCurrentMana` (`0x67321A`) paired with the
  pre-existing `CHero_GetSmoothedCurrentMana` (`0x67320F`).

| Packet offset | Hero field / setter | Proof |
|---|---|---|
| `+24`/`+28` (u64) | `hero+0x860`/`+0x864` | XP-gain animation fires when the new value exceeds the old |
| `+52` (u16) | `hero+0x4FC` — **Force / Strength** | label `+0x125C`; gating strings `STR_ALLOT_NO_FORCE`, `STR_ALLOT_FORCE_ADD` |
| `+54` (u16) | `hero+0x504` — **Speed / Agility** | label `+0x13AC`; `STR_ALLOT_NO_SPEED`, `STR_ALLOT_SPEED_ADD` |
| `+56` (u16) | `hero+0x508` — **Health / Vitality** | label `+0x14FC`; `STR_ALLOT_NO_HEALTH`, `STR_ALLOT_HEALTH_ADD` |
| `+58` (u16) | `hero+0x50C` — **Soul / Spirit** | label `+0x164C`; `STR_ALLOT_NO_SOUL`, `STR_ALLOT_SOUL_ADD` |
| `+60` (u16) | `hero+0x840` — **unspent attribute points** | label `+0x179C`; `STR_ALLOT_NO_POINT`; `hero+0x840 <= 0` disables all four add buttons |
| `+62` (u16) | `sub_673EAC(hero, 1, v)` — **current life** | same target as `MsgUserAttrib` id `0` |
| `+64` (u16) | `CHero_SetSmoothedCurrentMana` — **current mana** | paired getter name |
| `+66` (u16) | `hero+0x868` — **PK points** | label `+0xD1C` colour thresholds: `>19 && <100`, `>=100`, `<0`, prefixed by `sub_673273` |
| `+68` (u8) | `hero+0x838` — **level** | level label written via `_itoa` |
| `+69` (u8) | `hero+0x82C` — **current profession** | fed to `CHero_FormatProfessionDisplayName` for the class-name label |
| `+70` (u8) | `CHero_SetFirstProfession` — **first profession** | reborn history string, oldest entry |
| `+71` (u8) | `CHero_SetPreviousProfession` — **previous profession** | reborn history string, middle entry |
| `+73` (u8) | `sub_673F05` — **metempsychosis / reborn count** | `hero+0x84C` gates how many history entries render |
| `+91` (u16) | `CHero_SetTitleId` — **title id** | `CHero_GetTitleId` result, `STR_TITLE_NONE` fallback |
| `+16` (u32) | `hero+0x0C` — **money (silver)** | gem-compose gate at `0x45C101` reads `hero+0x0C`, requires `>= 100000`, else tip code `7` -> `STR_COMPOSE_MONEY_NOT_ENOUGH` (`DlgEmptyGemCompose.cpp`) |
| `+20` (u32) | `hero+0x10` — **emoney (CPs)** | name-change gate at `0x431A36..0x431A47` reads `hero+0x10`, requires `>= 810`, else `STR_CHANGE_NAME_EMONEY_NOT_ENOUGH` |

**COMDAT-folding trap (found 2026-08-15).** The one-line accessors on `CHero` are identical code to
accessors on unrelated classes, so MSVC folded them into single functions. `0x71FF0E` is
`return *(this+0x0C)` and was named `CItem__GetItemUid` by an earlier session — it is *also*
`CHero::GetMoney`, and that misleading name is what made the money field look unproven.
`0x71FF12` is `return *(this+0x10)` = `CHero::GetEmoney`. Setters `0x6844D2` (`*(this+0x0C) = v`)
and `0x698336` (`*(this+0x10) = v`) are folded the same way — hence their 28+ callers across
unrelated subsystems, which is why xref-based tracing does not isolate them.

Naming rule for folded accessors: name them `Folded_GetDword_0xNN` / `Folded_SetDword_0xNN` and put
the proven per-receiver meanings in the function comment. Do not name a folded accessor after one
class's use of it.

Applied in Binja 2026-08-15: `Folded_GetDword_0x0C` (`0x71FF0B`), `Folded_GetDword_0x10`
(`0x71FF0F`), `Folded_SetDword_0x0C` (`0x6844D2`), `Folded_SetDword_0x10` (`0x698336`), each with a
function comment recording the per-receiver proof.

**`hero+0x830` is not a `1006` packet field.** `CHero_GetCappedPhysicalForce` (`0x66F77C`) returns
`min(hero+0x830, CHero_GetEffectiveMaxPhysicalForce())`, and `CHero_GetEffectiveMaxPhysicalForce`
(`0x66F792`) returns `hero+0x834` (×3/2 when `CHero_HasExtendedPhysicalForceGaugeStatus`). So
`hero+0x830` is **current physical force (stamina)** and `hero+0x834` is its maximum. `1006`
explicitly zeroes `hero+0x830` rather than carrying a packet value — stamina arrives separately.
This also kills two more names in the `MsgUserAttrib` id table: id `8` (listed `AddPoints`) targets
`hero+0x830`, which is stamina, and the real unspent-points field is `hero+0x840`.

**`CDlgRoleAttribute_RefreshLabelsFromHero` (`0x50691E`) is the highest-yield reader in the binary.**
It renders the character-attribute panel straight from `CHero` and settles several fields at once.
Verified reads, in call order:

| Hero field | Rendered as | Settles |
|---|---|---|
| `+0x14C` | player name | — |
| `+0x838` | `_itoa` into the level label | **level** (`packet+68`) |
| `+0x82C` | passed to `CHero_FormatProfessionDisplayName` | **current profession** (`packet+69`) |
| `+0x84C` | branches `0` / `1` / `>= 2` to decide how much profession history to render | **reborn count** (`packet+73`) |
| `CHero_GetFirstProfession` = `*(hero+0x850)` | first link of the reborn profession chain | **first profession** (`packet+70`) |
| `CHero_GetPreviousProfession` = `*(hero+0x854)` | second link of the chain | **previous profession** (`packet+71`) |
| `+0x868` | label colour: `> 19 && < 100` -> `0xFFFF0000`, `> 99` -> `0xFF000000`, `< 0` -> `0xFFFFFF00`; prefixed by `sub_673273` (a `RoleDataQuery` vtable[0x84] status-name lookup on the same field) | **PK points** (`packet+66`) — the red/black name thresholds are unmistakable |
| `CHero_GetTitleId` | title label, `STR_TITLE_NONE` when `0` | **title id** (`packet+91`) |
| `+0x4FC`, `+0x504`, `+0x508`, `+0x50C` | four `_itoa` labels, then copied to `dlg+0xFC/+0x100/+0x104/+0x108` and handed to `CDlgRoleAttribute_RefreshAllotButtonsAndPendingStats` | the **four allottable base attributes** (`packet+52/54/56/58`) |
| `+0x840` | `_itoa` label next to the allot buttons | **unspent attribute points** (`packet+60`) |

This kills three more `MsgUserAttrib` id-table names: id `6` (listed `Stamina`) targets `hero+0x868`
which is PK points; ids `51`/`50` (listed `MountRank`/`CourtRank`) target `hero+0x850`/`+0x854`
which are the first/previous profession. The legacy `PlayerInfoWriter` is correct on all of these.

**`+79` proven = coach/mentor points, scaled x100.** `CHero_SetCoachPointsAndShowPrompt`
(`0x6ED34D`, was `sub_6ED34D`) stores the raw value at `hero+0x99C` and divides by 100 on every
display path: `STR_COACH_LOGIN_PROMPT` when the caller passes the login flag and `value/100 >= 1`,
`STR_COACH_INC_PROMPT` with `(value - old)` otherwise, plus a level `>= 90` branch querying
`GET_COACH_CHANCE` / `GET_EXTRA_COACH_CHANCE`. `1006` passes the login flag, so `1006` is the
login-time carrier. **Legacy labels `+79` `EnlightenPoints` — that is wrong**, and it is the first
field where the legacy writer is mistaken.

New lead for `+87` (`hero+0x474`, `sub_673266`): `MsgUserAttrib` id `39` targets it and posts
`0x4DB` / `0x501`; with `+79` now proven to be coach points, `+87` is probably the companion
mentor/apprentice rank. `CDlgRoleAttribute` does not read `0x474`, so the proof lies in whichever
dialog `0x4DB` refreshes.

**`+106` proven = race points (point-shop currency).** `CHero_GetRacePoints` (`0x6655D4`, was
`sub_6655D4`) returns `hero+0x2E08`; `CHero_SetRacePoints` (`0x6655DB`) writes it. The point-shop
purchase gate `sub_6AE581` compares the balance against `unitCost * quantity` and, when short,
dispatches **`STR_RACEPOINTSHOP_POINT_LIMIT`**. Companion strings confirm the shop:
`STR_RACEPOINTSHOP_BUYMSG_POINTLIMIT`, `STR_RACEPOINTSHOP_BUYMORE_POINTLIMIT`,
`STR_RACEPOINTSHOP_BUYMORE_POINTTIP`. The id table's `FactionPKRound` label for this field is wrong;
legacy leaves `+106` zero and makes no claim.

**`+85` proven = coach-system session counter (`hero+0x9A4`).** Accessors renamed:
`CRole_SetCoachSessionState` (`0x673BA4`), `CRole_GetCoachSessionState` (`0x673B9D`); neighbours
`+0x9A0` (`sub_673B75`) and `+0x9A8` (`sub_673B89` / `sub_673B96`).

`CRole_IsEligibleAsCoachApprentice` (`0x673BB1`, was `sub_673BB1`) is the apprentice-eligibility
predicate and pins the semantics. It requires all of: candidate entity id `> 999999` (players only),
no status flag5/flag10, candidate level `<= heroLevel - 20`, **`GetCoachSessionState(cand) % 10 < 5`**,
`get(+0x9A8) < sub_6ED75E(hero, candLevel)`, and `sub_673043(cand) == sub_673043(hero)`.

Subsystem is confirmed coach/tutor: the writers of `+0x9A4` sit in the same `0x6EDxxx` unit as the
proven `CHero_SetCoachPointsAndShowPrompt`, and `sub_6ED29E` walks the hero plus a tracked role list
resetting `+0x9A4` to `0` while re-applying coach points — a periodic reset of a capped counter.
`CMsgPlayer` (`10014`) writes it too, so it is remote-player state as well.

Server contract established: **`+85` carries a value whose low decimal digit is the used
coach-session count, and must be `< 5` for that role to be selectable as an apprentice.** The
feature's display name is still open — this build contains no `STR_ENLIGHT*` strings.

**`+75` proven = a raw tiered aura score (stored at `hero+0x984`), not an effect id.**
`AuraTierScore_ToEffectId` (`0x71E05A`, was `sub_71E05A`) is a pure threshold mapper:

| Score | Effect id |
|---|---|
| `<= 0` | `0` (none) |
| `<= 900` | `0x33` (51) |
| `<= 9000` | `0x34` (52) |
| `<= 27000` | `0x35` (53) |
| `> 27000` | `0x32` (50) |

`1006` performs an effect swap with it: reads the old score via `CRole_GetAuraTierScore`
(`0x674D34`, `return *(this+0x984)`), removes `ToEffectId(old)` through `sub_6F1222`, then for a
nonzero `packet+75` applies `ToEffectId(new)` through `sub_6F0FB7` and stores the **raw score** via
hero `vtable[0xD8]`. `MsgUserAttrib` id `40` runs the identical swap through the same function and
the same vtable slot, so it targets this field.

`hero+0x984` sits in the coach/mentor accessor region next to the proven coach-points field
(`hero+0x99C`) and coach session counter (`hero+0x9A4`). **Field adjacency is not evidence** — this
is the reason to keep looking for `+75`'s real subsystem, not a reason to call it tutor-related.

**Tried and rejected 2026-08-16: reading the tier names out of `ini/statuseffect.ini`.** That file
ships with the client and its rows are `id name ...`:

```
49 pkvip NULL
51 mate_pk_01 NULL
52 moveadding NULL 68
53 moveallaying NULL 69
```

Two independent reasons not to use this:
1. The id spaces are **not proven equal**. `sub_6F0FB7` is a generic effect-slot manager keyed by the
   id it is handed; it pulls its template from a registry at `arg1+0x78` that is populated elsewhere.
   It never indexes the `Statuseffect` dataset itself. The dataset key string `"Statuseffect"`
   (`0x9469D0`) is used only by `sub_70856A`.
2. The names at exactly the ids the mapper produces (`51`/`52`/`53`) are movement buffs, not auras,
   which is evidence *against* the naive mapping rather than for it.

To settle it, prove that the registry `sub_6F0FB7` reads at `arg1+0x78` is populated from the
`Statuseffect` dataset via `sub_70856A`. Until then `+75`'s tiers stay unnamed.

**What is proven:** the client applies the mapping above to whatever value arrives and retains it
verbatim at `hero+0x984` for the next removal.

**What is NOT proven:** the field's semantics, including whether the server is expected to send a
large magnitude at all. Every value in `1..900` yields effect `51`, so a server sending a small value
purely to trigger a specific aura tier is equally consistent with this code. The name
`AuraTierScore` describes the client-side mapping only. Do not write a server-side meaning for `+75`
until a producer or a reader of `hero+0x984` outside the effect swap is found.

**`+81` proven = coach/mentor EXP-share counter (`role+0x9A8`).** Resolved 2026-08-16 by walking the
vtable slot, which was the last accessor-shaped handle among the open fields.

Resolution path, reusable for any other vtable-dispatched field:
1. `CHero_Ctor` (`0x655194`) writes the vtable base — `*this = &data_86AD08`.
2. Slot `+0xE4` therefore lives at `0x86AD08 + 0xE4 = 0x86ADEC`.
3. `get_data_decl` at `0x86ADEC` yields `fd d5 6e 00` = **`0x006ED5FD`**.
4. That function is now `CHero_SetCoachExpShareCountAndShowPrompt`.

It stores the value at `role+0x9A8`, stamps `role+0x2DC4` with the tick count, and on transition:
- `0 -> nonzero`: applies effect `0x39` (`sub_6F0FB7`) and arms timer `0xCAA` (`sub_6F0EE6`)
- `nonzero -> 0`: removes effect `0x39` (`sub_6F1222`), dispatches **`STR_COACH_EXP_FIN`**, and
  notifies the card-play system with `"COACH_EXP_FIN"`

The loop closes against work already recorded here: `CRole_IsEligibleAsCoachApprentice` (`0x673BB1`)
reads the same field through `CRole_GetCoachExpShareCount` (`0x673B96`, was `sub_673B96`) and rejects
a candidate when `get(role+0x9A8) >= sub_6ED75E(hero, candidateLevel)`. Setter is
`CRole_SetCoachExpShareCount` (`0x673B89`).

**The 1006 coach cluster is now complete**, and it is four of the fields that were open:

| Packet | Field | Meaning |
|---|---|---|
| `+48` | `role+0x83C` | tutor level equivalent (`ini/TutorType.ini` key) |
| `+79` | `role+0x99C` | coach points, x100 |
| `+81` | `role+0x9A8` | coach EXP-share count |
| `+85` | `role+0x9A4` | coach session state (low decimal digit = used sessions, cap 5) |

**Profession code table (corroborates `+69` / `+70` / `+71`).** `sub_67328E` maps a profession class
to its animation/sound set name, which fixes the encoding independently of any reference source:

| Profession value | Name used |
|---|---|
| `1` | `warrior` / `warrior-s` |
| `2` | `fighter` / `fighter-s` |
| `4` | `archer` / `archer-s` |
| `5` | `ninjia_superc` |
| `6` | `monkalnonsuch` |
| `10`..`15` | `taoist` / `taoist-s` |

The `-s` variant is selected by the third argument. This matches the class values the rewritten
server already uses for character creation.

**`+93` proven = bound emoney (`hero+0x14`).** Accessors renamed `Folded_GetDword_0x14`
(`0x71FF13`) and `Folded_SetDword_0x14` (`0x640098`).

`CDlgWrapShop_ConfirmPurchaseOrShowCurrencyError` (`0x5743D7`, `MyShell\DlgWrapShop.cpp`) settles it.
The purchase is accepted when either currency covers the item, each at **its own price**:

```
price = *(item + 0x70)
if (Folded_GetDword_0x10(hero) >= price)                        -> buy confirm
else if (Folded_GetDword_0x14(hero) > 0 &&
         Folded_GetDword_0x14(hero) >= sub_67D92C(item))        -> buy confirm
else                                                            -> STR_WRAPSHOP_ERR_EMONEY
```

So `hero+0x14` is a second emoney-class balance with a separate item price, sharing the emoney error
string — which is exactly the behaviour of bound CPs, and matches legacy's `BoundEmoney` label.
Corroborated by `sub_662E12` grouping it with the proven CP field.

Xref tracing had to be abandoned for this field first: the getter has ~75 callers across `CItem`,
`CGameMap` and others. `sub_5D9A1B` / `sub_5D9A71` operate on `CGameMap+0xF4` (a `0/1/2` button-art
selector, `Button00`/`Button01`), and `sub_6629C2` compares both `+0x10` and `+0x14` against `5` on
an object carrying `+0x2F0C`/`+0x2F10` — irreconcilable with the proven CP meaning, so a different
folded receiver. **For folded small-offset fields, only a string-bearing gate works.**

**Dead end, recorded so it is not retried:** `CHero_RenderStatusOverlayAndXpBar` (`0x65E497`) does
not touch any outstanding `1006` field. It reads `hero+0xCE8` (the XP-block count, rendered from
`ani/common.ani` sprite `XpBlock` in 1..3 variants) plus `hero+0xD28/0xD40/0xD50/0xD54`. None of
those are carried by `1006`.

**`+97` / `+98` / `+102` mechanic proven (2026-08-15), feature name still open.**

Verified accessors:
- `sub_675ABA` -> `hero+0x450`, getter `sub_675C0F` — **selected type / tier index** (`u8` from `packet+97`).
- `sub_675AE1` -> `hero+0x468` / `hero+0x46C`, i.e. a **64-bit value** (`u32` pair from `packet+98`
  and `packet+102`).
- `sub_675AC7` -> `hero+0x454`, getter `sub_675C16` — **derived level digit**.

`CMsgUserInfo__Process` computes, when `packet+97 > 0`:
`hero+0x454 = ((value64 at +98/+102) / pow(10, packet+97 - 1)) % 10`, then posts `0xC74`.

`sub_675B94` consumes the pair: `sub_6C1FB3(sub_49A653(), &out, hero+0x450, hero+0x454)` scans a
manager list for the record whose `+0x24 == level + type * 10` and rejects `level > 9`; on a hit it
attaches a visual effect to the hero entity through `sub_6C3001`.

So the wire contract is: **`+98/+102` is a 64-bit decimal-packed vector of per-type levels (one
decimal digit per type), and `+97` selects which digit is active.** The effect table is keyed
`type * 10 + level`, which is why `level` is constrained to a single digit.

The managed `MsgUserInfo1006Packet` must retain this pair even though the selected visual-effect
type is not yet rendered: `SelectedPackedTypeIndex` is the byte at `+97`, and
`PackedPerTypeLevels` is the little-endian qword at `+98`. `CHero_GetEffectiveMaxLife` independently
consumes digit 9 from the packed qword, so discarding it would make a later max-life reconstruction
silently incomplete. The same reader also retains the already-proven bound-CP dword at `+93` and
race-points dword at `+106`; together these bring the verified managed `1006` carrier to 31 record
properties including `Size` and the three strings.

### Direct local-hero stat substrate (managed slice)

The authoritative managed hero-stat carrier is seeded by `MsgUserInfo (1006)` and then mutated by
the same verified `MsgUserAttrib (10017)` IDs as the native `CHero` fields. The HUD-critical direct
set is:

| ID | Managed/native value |
|---:|---|
| `0` | current life (`FDword` index 1) |
| `1` | maximum-life override (`hero+0x514`) |
| `2` | current mana |
| `3` | maximum-mana override (`hero+0x518`) |
| `5` | 64-bit experience (`valueLow | valueHigh << 32`) |
| `6` | PK points (`hero+0x868`) |
| `7` | current profession (`hero+0x82C`) |
| `8` | current physical force / stamina (`hero+0x830`) |
| `10` | unspent attribute points (`hero+0x840`) |
| `12` | level (`hero+0x838`) |
| `22` | metempsychosis / rebirth count |
| `39` | flower-status tier (`hero+0x474`) |
| `43` | overlay-mode max-life bonus (`hero+0xCB0`) |

IDs `25` status flags, `29` CPs, and `45` bound CPs remain part of the same verified enum even when
their UI consumers are elsewhere. `1006` explicitly seeds current physical force to zero; no
packet field may be invented for it. The native fresh maximum remains 100 and becomes 150 only
while status-flag index `0x21` is present.

`CMsgPlayer__Process` (`10014`) calls `sub_675ABA` as well, so this pair is part of every
player's visible appearance, not just the local hero.

Open: the manager's class name (`sub_49A653` is a generic singleton getter; its RTTI `type_info`
lives at `0x921F28` -> `0x0086DF04`). Reading that string is what identifies the feature.

**`+48` belongs to the tutor/mentor system, NOT to peerage. Earlier lead retracted.**

The consumer chain is now traced end to end:
- `1006` stores `packet+48 / 100000` into `hero+0x83C` via `CRole_SetTutorLevelEquivalent`
  (`0x673202`); the getter is `CRole_GetTutorLevelEquivalent` (`0x6731FB`).
- `CHero_RecomputeTutorGradeFromLevelKey` (`0x68F7B9`) calls
  `TutorTypeTable_LookupByLevelKey(mgr, hero+0x838 /*level*/, hero+0x84C /*reborn*/, hero+0x83C)`
  and caches the result at `caller+4`.
- `TutorTypeTable_LookupByLevelKey` (`0x73237F`) computes
  `key = level; if (reborn > 0 && field83C > key) key = field83C;` then scans 16-byte records for
  `record.min <= key <= record.max` and returns `record.payload`, else `0`.
- The scanned list is `mgr[8]` (byte offset `0x20`), populated by the manager constructor
  `sub_73209E` from **`ini/TutorType.ini`** (`sscanf "%u,%u,%u,%u"` — exactly 4 dwords per record).
  The same constructor also loads `ini/StudentType.ini` (`"%u,%u,%u,%u,%u"`) and
  `ini/TutorBattleType.ini` (`"%u"`), and tracks the minimum first column as a floor defaulting to
  `30`, which confirms that column is a level bound.

So `hero+0x83C` is a **level-equivalent** that substitutes for the real level in the tutor-grade
lookup when the player has reborn and the stored value is higher.

The previous "peerage donation" reading came from the `MsgUserAttrib` id table's `PeerageLevel`
label, which is part of the same discredited name set. `ini/peerage.ini` (`sub_6AAD95`) is a real
rank-indexed cosmetic table, but nothing connects `hero+0x83C` to it.

**Resolved 2026-08-16 with the shipped data file.** `ini/tutorType.ini` is present in the clean
client (`00_clean/clean/5517/ini/`) and contains exactly five records:

```
70,109,2,10
110,119,3,15
120,129,5,25
130,133,7,35
134,140,10,50
```

Four columns per row = the `sscanf "%u,%u,%u,%u"` and the 16-byte stride the lookup walks; the
payload returned is the 4th column. The constructor's floor (`min` of column 1, default `30` only
when the file is missing) is therefore **70** in practice, so the lookup key is a **level in
70..140**.

`CRole_GetTutorLevelEquivalent` has exactly **one** reader in the whole binary
(`CHero_RecomputeTutorGradeFromLevelKey`), so this field exists solely to serve that key. Combined
with the `reborn > 0 && field > level` condition, `hero+0x83C` is the **pre-rebirth level**, kept so
a reborn player retains tutor grade after their level resets.

**Server contract for `+48` is fully determined:** to give a reborn player the tutor grade for level
`L`, send any value in `[L*100000, L*100000 + 99999]`. The client uses only the quotient.

Why the wire value is scaled by `100000` remains unexplained, but **no client code reads the
remainder**, so the scaling is a server-side encoding choice that cannot affect client behaviour.
`+48` is therefore implementable now.

### Scorecard against the two reference name sets (updated 2026-08-16)

**Legacy `OpenConquer5517v3` `PlayerInfoWriter`** — correct on **every** field proven so far. It
leaves `+32`, `+36`, `+40`, `+44`, `+48`, `+81`, `+106` zero, so it makes no claim on those.

Correction (Bernie, 2026-08-16): an earlier revision of this file called legacy wrong on `+79` for
labelling it `EnlightenPoints` while the binary evidence says coach/mentor points. **Those are the
same thing** — "enlightenment points" is the colloquial player-facing term for the coach/mentor
points the `STR_COACH_*` prompts describe. Legacy's name is a synonym, not an error. The binary
evidence still stands on the mechanics that matter for the writer: the value is held **x100** and
every client display path divides by 100.

**The `MsgUserAttrib` id-name table** in [11_else_branch_packets.md](11_else_branch_packets.md) —
disproven on ids `4`, `6`, `7`, `8`, `29`, `37`, `45`, `47`, `50`, `51`; confirmed on ids `0`, `2`,
`5`, `12`, `22`. A warning block with the corrections is now at the head of that table.

The split is not random, and it is the useful part of this result: **the entries that survived are
exactly the ones whose `Handler Details` column already cited in-build evidence** (a `STR_` string, a
threshold, an observable behaviour). The entries that failed are the ones whose names were imported
from a reference-server enum for a different client version. The table's `Entity Field` and
`Handler Details` columns remain reliable throughout — only reference-imported names are suspect.

Practical rule: a name in that table is usable **only** when its own row cites in-build evidence.
Otherwise treat the row as an offset, not a name.

### World-entry packet consumers (corrected by native audit 2026-09-15)

The following order is used by the working server. Native handlers prove each packet's
consumption, not a requirement to receive this entire set. `1006` builds action 74 at
`0x764873` and sends it at `0x7648A3` without checking receipt or values of `2078/2079`.
Exact retail-server payloads and order require server evidence or a retail capture.

| Step | Packet | Verified layout | Evidence |
|---|---|---|---|
| 1 | `1004` MsgTalk on channel `0x835` | `[colour:u32][channel:u16][style:u16][identity:u32][u32][u32][stringList]` | `CMsgTalk__Process` |
| 2 | `2078` AccountLoginAlert | `[lastLoginTimestamp:u32][locationAlert:u8][location:ANSI][NUL]` | `CMsgAccountLoginAlert2078__Process` |
| 3 | `2079` MsgServerState | `[state:u32]` | `CMsgServerState__Process` |
| 4 | `1006` MsgUserInfo | 106-byte fixed body + string list at `+110` | `CMsgUserInfo__Process` |

**`1004` channel constants — proven, and easy to get backwards.** `CMsgTalk__Process` routes the
message text into one of two queues and returns without reading colour, style or identity:

- channel `0x835` (2101) -> `data_96B330`, drained by `CMyShellDlg_HandleLoginStatusSystemTalk`,
  which handles `ANSWER_OK` and `NEW_ROLE` -> **the login / game-entrance channel**. Any other text is shown on
  the login screen as an error (`CLoginFlashDlg_ShowLoginErrorText`, `0x5DCD58`); TQ 15.10 refuses game logins this
  way (`STR_ERROR_SERVER_FULL`, `STR_ERROR_SERVER_BUSY`, version, locked — [TQ topology](../Server/historical-multi-server-topology.md))
- channel `0x834` (2100) -> `data_96B36C`, drained by `CMyShellDlg_HandleCreateRoleStatusSystemTalk`,
  whose `ANSWER_OK` branch calls `CConnectionFlow__SendGameSessionBootstrap` -> **the create-role
  channel**

Because those branches return early, **only the channel and the message string matter** for these
control messages; the colour/style/identity fields are never read on them.

**`2079` values:** `0` -> `g_ServerProtocolState` (`data_93FD78`) `= 0x7D0` (2000); `1` -> `0x7D1`
(2001); anything else leaves it unchanged. The clean global starts at 2000.
`CHero_RefreshProtocol2000StatusUi` (`0x662E12`) gates a UI state on it being `0x7D0`;
this does not establish a required login wire value.

**`2078` text must be NUL-terminated**: `CHero_SetAccountLoginAlertData` (`0x6577BF`)
copies it with `strlen()` into `hero+0xDE8` (timestamp at `+0xDE0`, alert byte at `+0xDE4`);
the Process function then posts UI refresh `0xD39`. The account-login-alert dialog passes
the timestamp to `localtime` and formats last-login location and warning resources. This
is separate from the equipped title in `1006`. No fixed retail tuple is recoverable here.
See [the 2078/2079 native closure audit](10_extended_packets.md#account-login-alert-data-type-2078-formerly-labeled-cmsgtitlelabel)
for acceptance rules and the distinction between client behavior and server policy.

**String-list format and its bounds contract** (`MsgStringList_TryGetEntry`, `0x771F57`, renamed
from `sub_771F57`): the list is `[count:u8]` then repeated `[length:u8][bytes...]`. The reader
`memset`s the destination first, then requires `length < destSize`. With the `0x10` buffers used by
`1006` and by `MsgTalk` indices 0..2, **the maximum usable entry length is 15 bytes**, and a 16+
byte entry is *not truncated* — it is skipped and the destination stays zeroed, so an over-long name
renders blank rather than failing. A server must reject over-long entries itself.

Buffer sizes by call site: `1004` idx0 sender `0x10`, idx1 recipient `0x10`, idx2 `0x10`, idx3
message `0x100`; `1006` idx0 name `0x10`, idx1 read-but-unused `0x10`, idx2 `0x10` -> `sub_6728DC`
(stores at `hero+0x4F0`, rendered by the role-attribute panel with a fallback when empty).

**`1006 +8` is NOT the appearance composite reduced modulo 1000.** It is an independent
transform-look source id: `CRole__SetTransformLookSourceId` stores it at `role+0xDC` and, with
`refresh=1`, triggers `CRole__SetTransformLook`, which resolves it as a **section key in
`ini/TransForm.ini`** and on a hit overwrites RoleView keys 3/5/6/7/8/9, `role+0x174` (AddSize) and
`role+0x184` (Scale). Zero is the verified early-exit value.

The legacy writer sends `lookface % 1000` here. That happens to be harmless *only because of the
shipped data file*: `TransForm.ini` contains 119 sections, of which just two are below 1000 (`[980]`
and `[990]`), while player body ids yield keys 1..4. It is a data coincidence, not a protocol
property, so the rewritten server models this as its own field defaulting to `0`.

## Type 1008 — dispatch verified 2026-08-16, stat inputs extended 2026-08-20 — class unproven; label `MsgItem` withdrawn (`MsgItem.cpp` asserts are in the type 1009 handler; CP0.1 2026-11-05)

Delivered on the client's `MsgAction 0x4B` (75, GetItemSet) leg, **not** on the post-`1006`
bootstrap.

`CMsg1008__Process` (`0x762AC3`) switches on **`packet+0x10` as a byte, minus 1** — so `+0x10` is the
subtype and the handled range is **1..10**. Subtype `6` has no case and is silently ignored.

| Subtype | Behaviour |
|---|---|
| **1** | allocates a new `CItem` (`0x1EC` bytes) and populates it — **the add/inventory-row path, i.e. the login item set** |
| 2, 4, 5, 8, 9, 10 | also allocate a new `CItem` |
| 3 | `CHeroItem__FindItemByUid` then update an existing item; removal is MsgItem subtype3 |
| 7 | `sub_729CE6` / `sub_72A135` on `CHero`, no item allocation |

Packet offsets read anywhere in the handler: `+4`, `+8`, `+0xC`, `+0xE`, `+0x10`, `+0x11`, `+0x12`,
`+0x14`, `+0x18`, `+0x19`, `+0x1C`, `+0x20`, `+0x21`, `+0x22`, `+0x23`, `+0x24`, `+0x28`, `+0x2C`,
`+0x2E`, `+0x30`, `+0x34`, `+0x38`, `+0x3C`, `+0x40`. The last read is the word at `+0x40`; the established row envelope is 68 bytes.
The handler alone does not prove an exact minimum validated packet length.

### Subtype 1 — local inventory and tracked equipment

The corrected complete field map, native consumers and persistence boundary are maintained in
[MsgItem1008-domain-contract-5517.md](MsgItem1008-domain-contract-5517.md).
Raw recheck at `0x762C28` makes `+0x22` **u8**; `0x762F0A` makes `+0x2C` **u16**.
`+0x34` is composition progress (`0x58CDDF`), not a clear mask. Status is replaced by
clear(-1), then OR(u16 `+0x2E`). The suspicious boolean does not overlap status.

`+0x12 == 0` routes to inventory (`0x763048`); nonzero routes to tracked placement
(`0x762FF4`). Fresh main/alternate positions1..9/21..29 require the active equipment UID
snapshot (MsgTick1009 subtype46) to populate the active slots. Subtype4 instead targets an
inspected `CDummy`; it is not the local equipment login path. These distinctions supersede
the previous field map and equip-hydration interpretation.

### What implementing this leg actually requires

The packet is the small half. Serving `0x4B` needs an inventory subsystem: item and equipment
tables, item-type data, a schema migration with a readiness requirement, and a repository — the same
shape as the character work, and comparable in size.

## MsgPlayer (Type 10014) — core fields verified 2026-08-16 — class proven by `MsgPlayer.cpp` assert (CP0.1 2026-11-05); former label `MsgPlayerSpawn` withdrawn

**The client discards a self-spawn.** `CMsgPlayer__Process` (`0x755F64`) compares `packet+8`
(entity id) against `CHero+0xCC` as its very first action; on a match it logs
`"Got a player with hero id! %u"` and **returns** before resolving the entity or applying anything.

Consequences:
- 10014 is the packet that spawns **other** entities. It is **not** part of the local player's own
  world entry, and no amount of sending it will hydrate the local hero — that is `1006`'s job.
- The legacy world bootstrap sends a self-spawn (`SendSpawnAsync(character)`) as part of its burst.
  **That send does nothing on this client.** Anything appearing to depend on it is actually being
  produced by `1006`.

Entity ids `> 0xF423F` (999999) are treated as players, at or below as NPC/monster, and several
branches key off that split. A missing entity is allocated fresh (`0xA58` bytes).

Verified core offsets (the equipment-visual block is in
[role_visual_construction.md](../Entity_System/role_visual_construction.md)):

| Offset | Meaning |
|---|---|
| `+4` u32 | appearance composite — identical packing to `1006 +10` |
| `+8` u32 | entity id |
| `+0x0C` u32 | syndicate id |
| `+0x10` u32 | syndicate rank |
| `+0x26` u16 | transform-look source id (independent of `+4`, as in `1006 +8`) |
| `+0x50` u16 / u32 | current life — word for ids `<= 999999`, full dword for player ids |
| `+0x52` / `+0x63` u16 | level — non-player path / player path |
| `+0x54` u16 | hair composite (`% 1000`, `/ 1000`) |
| `+0x56` / `+0x58` u16 | tile x / y |
| `+0x5A` u8 | direction (packed) |
| `+0x5B` u32 | action type |
| `+0x62` u8 | reborn |
| `+0xB5` u8 | nonzero enables the name-indexed `Monster.dat` life scaling arm |
| `+0xB6`/`+0xBA`/`+0xBE`/`+0xC2` u32 | helmet / armor / left / right weapon **item type ids**, each validated through `ItemTypeDataSingleton_TryGetItemRecordByTypeId` and zeroed on a miss |
| `+0xCF` / `+0xD1` / `+0xD3` u16 | first / previous / current profession — read with `movzx eax, word` at `0x756BC5`/`0x756BDB`/`0x756BF1`, which is also what spaces them two bytes apart. Corrected 2026-08-28; they were previously listed as `u8`. |
| `+0xD9` u8 | when nonzero, suppresses direction and tile-position application |

**Five fields land on exactly the same targets as `1006`**, which is a strong independent
corroboration of that work: `+0x81`→`vtable[0xD8]` (`1006 +75`), `+0x91`→`vtable[0xE4]`
(`1006 +81`), `+0x95`→`CRole_SetCoachSessionState` (`1006 +85`), `+0xA7`→`CHero_SetTitleId`
(`1006 +91`), and `+0xC6`/`+0xC7`/`+0xCB` → the same trio as `1006 +97`/`+98`/`+102`.

String list: **four** entries at `0x24` (36) bytes each — note the wider buffer than `1006`'s `0x10`.
Entry `0` is the role name (`CRole_SetName` at `0x75618C`, and the `~`-to-space rewrite plus
`Monster.dat` lookup at `0x75642B` runs on the same buffer). Entry `1` is read only on the
non-player path at `0x756559`; entries `2` and `3` pair with the dwords at `+0x9B` and `+0xA3`.

Body length is exact, not a lower bound: `CMsgPlayer__Ctor` (`0x755E83`) initialises the
string list at `frame + 0xDA` with capacity `0x326` (`0x755EC4`..`0x755ED2`), so the fixed body is
218 bytes and the list begins there.

The primary equipment inputs are a **separate region** from the `+0xB6` lookup overrides: the
RoleView variant setters read `+0x28` headwear, `+0x30` armor, `+0x34` left hand and `+0x38` right
hand (`0x756A85`..`0x756AFB`), each carrying the same catalog item type as its override.

Current-life writes are ordered and later arms overwrite earlier ones:

1. The self-spawn guard returns before all role mutation.
2. For `entityId <= 999999`, index 1 receives the unsigned word at `+0x50`. On non-Chinese
   datasets the role name has `~` replaced by a space, then the client performs an exact
   `Monster.dat` name lookup. If it succeeds and `+0xB5 != 0`, index 1 is overwritten with signed
   `(lifeWord * record.MaxLife) / 10000`, truncated toward zero.
3. For `entityId > 999999`, the full dword at `+0x50` is stored directly at `role+0x848`.
4. Later, native entity-id classifier category 4 (`100001..199999`) and syndicate rank exactly
   `990` or `1000` overwrite index 1 with `lifeWord * 100`.

The `+0x0C` / `+0x10` meanings are independently corroborated by
`CMsgSyndicateAttributeInfo1106__Process`. `GameData.dll` loads `ini/Monster.dat` with decoded-text
seed `0x2537` into the exact-name map at the role-data singleton's `+0x1B0`. Its parser is fail-stop:
a failed required line read or `scanf` conversion logs `error data` and returns zero, retaining only
records inserted before that section. Decimal `scanf` accepts a numeric prefix. In the clean fixture,
the blank `Level=` in section 689 (`Lv122Serpent`) stops the load after 677 unique normalized names.

## MsgWeatherUpdate (Type 1016) — verified 2026-08-16

Fixed 16-byte body, **20-byte packet**: `+4` kind, `+8` intensity, `+12` direction, `+16` parameter.

**`CMsgWeatherUpdate__Process` (`0x760801`) calls
`CMsgWeatherUpdate__ValidateAndNormalize` (`0x7606CD`) first and does nothing when it returns 0.**
An out-of-range field therefore makes the entire packet a silent no-op.

Accept conditions — all required:

| Field | Range |
|---|---|
| kind (`+4`) | `> 0` and `< 0xC` → **1..11**, except 6 |
| intensity (`+8`) | `0..1022` |
| direction (`+12`) | `0..359` |

**The validator rewrites the packet in place** before `Process` reads it: direction is normalised to
a signed `[-180, 180]` (subtract 360 when `> 180`), and the kind is remapped:

```
 1 -> 0          7 -> param + 0x0A
 2 -> 1          8 -> param + 0x0E
 3 -> 2          9 -> 0x12
 4 -> 0x0D      10 -> 0x13
 5 -> param + 3 11 -> 0x14
```

**Input kind 6 is rejected.** Jump table `0x7607B2` entry 6 = `0x7607A9` (return 0), so the packet is a
silent no-op like any out-of-range value (corrected CP2.4b 2026-11-06; earlier "unassigned" claim wrong).

`Process` then resolves the map's type-5 component and branches on the **normalised** kind against
the component's current kind:
- same kind → `UpdateWeatherParams(+12, +8)`, or `ClearWeatherState` when intensity is `0`
- different non-zero kind → `SetWeatherKindAndParams(kind, +12, +8, +16)`
- different and zero → stop weather

**Server trap.** Normalised `0` comes from **input kind 1**, so *clearing weather is sent as kind 1*.
Sending kind `0` does not clear weather — it fails validation and the packet is discarded. The legacy
server defaults weather to `0` when a map has no metadata, which means those sends do nothing at all.

## MsgMapInfo (Type 1110) — verified 2026-08-16

**The handler was misnamed `CMsgTeamArena__Process`** (`0x732B10`), now
`CMsgMapInfo1110__Process`. The arena references inside it are two conditional chat messages
selected by map state (GameDataSet `0xC34C` / `0xC34D`), not the packet's purpose — its body loads
`CGameMap`, so 1110 is map info.

Fixed 16-byte body, so a **20-byte packet**:

| Offset | Size | Target | Verified behaviour |
|---|---|---|---|
| `+4` | u32 | `CGameMap+0xE0` | **map identity**. `CGameMap_ApplyMapIdAndRefreshWorldState` always stores the value and always drives the refresh chain (`sub_61F98A`, `sub_61F5A0`, `sub_62137E`, `CGameMap_UpdateTileRegionFlagsAndAmbientMedia`, `sub_6205F2`, then re-projects type-code-1 components). Only setting `CGameMap+0x2E4` to `1` is conditional on the ID changing; a repeated ID is not a no-op. |
| `+8` | u32 | `CGameMap+0xE4` | `CGameMap_SetMapDocumentId`; bare store of the map document/data id |
| `+12` | u32 | `CGameMap+0xE8` | 64-bit map flags, low half |
| `+16` | u32 | `CGameMap+0xEC` | 64-bit map flags, high half — bit `0x10` selects UI post `0xDE1` vs `0xDE2` |

The handler snapshots several map predicates **before** the stores and compares after, so a number of
UI posts fire only on transition. It ends by **sending MsgAction (10010) subtype `0x198` (408)** —
processing 1110 has an outbound consequence a server will observe.

**Legacy cross-check, with a caveat.** The legacy writer sends the same three logical fields (two
dwords plus a 64-bit flags pair), so the *shape* is independently corroborated. But its argument
names put "mapStateValue" first and "mapDoc" second, while the binary shows the **first** dword is
the one that triggers the reload — i.e. the map identity. Trust the offsets, not the legacy names.

**`+4` is definitively a map id.** Two predicates compare `CGameMap+0xE0` against literal map ids:
`CGameMap_IsStateBlockingAutoRun` (`0x62084B`) tests `== 0x40F` (1039), and
`CMsgMapInfo1110__Process` itself tests `== 0x3EA` (1002, Twin City). Legacy's own writer comment
also says this field "mirrors native CGameMap+0xE0, usually current map id".

**`+8` (`CGameMap+0xE4`) is a bare store.** `CGameMap_SetMapDocumentId` (`0x61F2B6`) is the packet
writer and `CGameMap_CreateFromDataId` also stores the selected map-data record id at this field.
The dedicated data-ID getter is `0x6E5E2C` (`mov eax,[ecx+0xE4]; ret`). The world-ID getter is
`0x4F6569` (`+0xE0`); `0x61F172` was an incorrect entry address. `0x61F2DA` returns flags low/high
in EAX/EDX. These independent fields do not establish a server MapId→MapDataId catalog.

**The flags are a 64-bit map-property bitfield.** Received0 is valid and clears all bits; choosing0
without retail evidence is still an unresolved per-map placeholder. Bits verified so far, all read from the low dword
(`CGameMap+0xE8`) unless noted:

| Bit | Predicate | Read by |
|---|---|---|
| **qword `0x0000004000000000` (high `0x40`)** | `CGameMap_HasFlags64HighBit6_Analyst` (`0x6206C8`) | transition triggers hero stat refresh, posts `0x445`/`0x446`/`0xDA4`, and builds/sends action `0x198` if builder succeeds |
| `0x2000000` | `sub_61F2E7` | snapshotted across `1110`, gates `sub_6AF6D1`/`sub_6AF6F7` |
| `0x10000000` | `sub_61F305` | snapshotted across `1110`, gates `sub_69770A`/`sub_697719` |
| `0x10` of the **high** dword (`CGameMap+0xEC`) | inline | selects UI post `0xDE1` vs `0xDE2` |

The [map identity/flags audit](../Server/map-identity-flags-native-5517.md) now supplies exact masks
for these and the other sampled consumers, all 33 direct flag-getter callsites, original-x86 one-hot
validation, and the remaining semantic/per-map-data limits. Low `0x40` is tested separately by
`0x6207EE`; it is not the `0x6206C8` stat-refresh gate.

## MsgAction / MsgData (Type 10010) — builder layout verified 2026-08-16

`CMsgAction__Create` (`0x6FE95F`) emits a fixed **38-byte** packet (size `0x26`, type `0x271A`) after
`CNetMsg__ResetPacketBuffer`, so anything it does not write stays zero:

| Offset | Size | Field |
|---|---|---|
| `+4` | u32 | entity id |
| `+8` | u32 | parameter pair |
| `+12` | u32 | action parameter (**not** written by this builder) |
| `+16` | u32 | timestamp — `Conquer_GetTimeGetTime()` |
| `+20` | u16 | **action** (low word of a shared dword) |
| `+22` | u16 | **direction** (high word of the same dword) |
| `+24` | u16 | x |
| `+26` | u16 | y |
| `+28` / `+32` | u32 | data1 / data2 |
| `+36` / `+37` | u8 | flag / string count |

The builder returns `0` without writing when the entity id is zero. A trailing MsgStringList may
follow the fixed body on some subtypes, so inbound packets should be accepted at **at least** 38
bytes rather than exactly 38.

This layout independently matches the legacy `OpenConquer5517v3` `DataPacket` (34-byte body measured
from `+4`), which is a second source agreeing field for field.

**The ladder is client-driven; inbound action acknowledgements advance it.** `CMsgUserInfo__Process` ends by calling the
builder with `actionEnterMap` (`0x4A`) and the local hero id. After that `CMsgAction__Process`
advances one rung per **inbound** action:

```
client 0x4A EnterMap  -> server echoes 0x4A -> client sends 0x4B GetItemSet
       0x4B -> 0x4C GetGoodFriend
       0x4C -> 0x4D GetWeaponSkillSet
       0x4D -> 0x4E GetMagicSet
       0x4E -> 0x61 GetSynAttr
       0x61 -> 0xFB SilentInfo checksum/version report
       0xFB -> 0x84 actionGetStatistic
```

An action acknowledgement advances these edges. Send the intended snapshot before acknowledging
its rung as server ordering policy; this is not proof of a native row-count gate or a retail
server packet burst. Acknowledgement fields are action-specific: the zero-ID client `0xFB` report
cannot be blindly echoed because its response must pass the entity-resolution gate. Any enum mapping `GetItemSet` to `52` instead of `0x4B`/`75` is incompatible with this build.

**Echo entity id is checked (corrected 2026-09-28).** `CMsgAction__Process` resolves packet `+4`
at `0x6FF173` (`EntityRef_ResolveByIdOrLocalHero`, includeLocalHero=1) before the rung switch.
Unresolved -> exit `0x700974`, no advance, for `0x4B/0x4C/0x4D/0x4E/0x61/0xFB`.
Correction 2026-10-05: the resolver accepts the local hero **or a matching existing role**, not
only the local hero. Bootstrap responses should use the authenticated local hero ID. `0x4A` is immune: `0x6FEE14` overwrites `+4` with the hero id first.

**`0x4C` rung, complete client requirement:** one MsgAction echo, subtype `0x4C`, `+4` = hero id.
Branch `0x6FF365..0x6FF3CB` reads nothing else and sends `0x4D`. MsgFriend rows are optional content:
zero rows valid, any order, `CMsgFriend__Process` has no ladder gate. No other packet family is read
on this rung. Enemy list is also re-queried by the client itself via MsgEnemyList 1041 when the enemy
dialog opens (`0x45D0FD`), independent of the ladder.

Rung payloads verified so far: `0x4B` is answered with `Msg1008` (1008) rows, `0x4C` with
`MsgFriend` (1019) rows (optional, see above), `0x4D actionGetWeaponSkillSet` with one `MsgWeaponSkill` (1025)
packet per proficiency row, and `0x4E actionGetMagicSet` with one `MsgMagicEffectSimple` (1103)
per magic — established by xrefs on `CHero__AddOrUpdateMagic` (0x6F5546), the only function that
installs a magic, whose sole callers are the 1103 handler and one MsgAction subtype. 1103 carries
no experience field, so magic exp needs a following `MsgFlushExp` (1104) `ucAction 1` — see `06_combat_packets.md`. Each 1025 row carries type, level,
exp **and the next-level exp requirement**, because the 5517 client no longer ships a
client-side level→required-exp table. The client derives the proficiency tab from
`type / 100`, so the real 3-digit type must be sent unmodified.

For the enter-map acknowledgement the **map id rides in the parameter pair at `+8`**, with the spawn
tile in `x`/`y` at `+24`/`+26`.

### Shipped client data files are a first-class evidence source

`00_clean/clean/5517/ini/` contains ~180 real data files, and `ini/tutorType.ini` settled `+48`
faster than any amount of binary tracing. Check there **before** starting a decompile chase. Files
directly relevant to the outstanding fields and to already-proven ones:

- `tutorType.ini` — settled `+48` (level bands `70..140`)
- `RacePointShop.ini` — corroborates the `+106` race-point proof
- `peerage.ini` — rank-indexed cosmetic table (`[01]` Commoner, `[11]` Knight, …)
- `Title.ini`, `synmembertitle.ini` — candidates for `+91` corroboration
- `SubProfessionInfo.ini`, `VipTrans.ini`, `Dynarank.ini`, `AutoAllot.dat`, `statuseffect.ini`
- `LevelExp.dat` / `levexp.dat`, `ProfessionalName.ini`

Caution learned the same day: a data file only proves something once the **id space it is indexed by
is shown to be the one the code uses**. See the rejected `statuseffect.ini` attempt above.

### Remaining unproven `1006` fields

**Historical list, superseded 2026-09-17:** +48, +81 and +87 are already semantically
closed; see the [current complete table](../../10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md).
For +32/+36/+40/+44/+72/+74 the later [historical reconciliation](MsgUserInfo1006-historical-field-reconciliation.md)
supplies names and compatibility/update classifications; native-only name proof is distinguished from lineage. The feature at+97/+98 is
subprofession ID/promotion phases, and string[1]'s payload is proven dead on the normal
receive path. The historical tutor-cluster hypothesis below is not evidence for other fields.

`+32` (`hero+0x85C`), `+36` (`hero+0x844`), `+40` (`hero+0x848`), `+44` (`hero+0x8B8`),
`+48` (`hero+0x83C`, the unexplained `/100000`), `+72` (`hero+0xF34`), `+74` (`hero+0xCE4`),
`+81` (hero `vtable[0xE4]`), `+87` (`hero+0x474`).

The earlier grouping of +48/+75/+79/+85/+87 as one tutor subsystem was a hypothesis and
is withdrawn. In particular, +75 is aura-tier score and +87 is flower-status tier.

Lead for `+93` (`hero+0x14`): `sub_662E12` gates a UI state on
`level < 70 && reborn < 1 && hero+0x10 < 1 && hero+0x14 < 1` (posts `0x44D`, else `0x44C`), so
`hero+0x14` groups with the proven emoney field at `hero+0x10`. That is a lead, not a proof — find a
cost/threshold check that reads `hero+0x14` and names its own failure string.

**Writer correction for managed/server parity**:
- the fixed-body offsets that matter for first local-hero visual construction are:
  - `+4` entity id
  - `+8` type-1 appearance refresh source (u16 widen path into `CRole__SetTransformLookSourceId`)
  - `+10` packed appearance composite used by:
    - `CMsgUserInfo__Process -> CRole__CreateRoleView(..., type=1)` after `% 1000`
    - `CMsgUserInfo__Process -> CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform(...)`
      after `/ 0x2710 % 0x3E8`
    - direct store to `hero+0x178` after `/ 0x3E8 % 10`
  - `+14` packed hair composite split by `% 1000` and `/ 1000`
- earlier managed/server drafts that wrote `lookface` at `+6` and hair at `+10` are wrong for 5517 and cannot produce native-equivalent local-hero RoleView construction.

## MsgCreatePlayer (Type 1001)
**Direction**: C→S
**Purpose**: Create-role request and create-role cancel request on the authenticated game session.
**Dispatch/Builders**:
- `CMsgCreatePlayer1001__Ctor` (`0x720059`)
- `CMsgCreatePlayer1001__Build` (`0x7200BF`)
- `CRoleCreateFlashDlg_SubmitCreatePlayerRequest` (`0x51C5C3`)
- `CRoleCreateFlashDlg_SendCreatePlayerCancelAndPostHostCommand481` (`0x51C54B`)

**Verified create/cancel packet layout**:

```c
struct MsgCreatePlayer1001 {
    uint16_t size;           // +0: 124
    uint16_t type;           // +2: 1001
    uint32_t cancel_flag;    // +4: 0=create, 1=cancel
    uint8_t  reserved_08[16];// +8: zero
    char     name[48];       // +24: nickname; builder copies 16 bytes and forces NUL at +39; +40..+71 zero
    uint16_t body;           // +72: body id (derived from vocation index + body-size selection)
    uint16_t profession;     // +74: profession code
    uint32_t session_uid;    // +76: `CHero+0xA9C`
    char     mac_text[40];   // +80: first NetBIOS adapter MAC, rewritten as "%02X"x6 only when the lookup succeeds
    uint8_t  trailing_zero;  // +120: forced zero
};
```

**Verified field derivation in `CRoleCreateFlashDlg_SubmitCreatePlayerRequest` (`0x51C5C3`)**:
- nickname buffer source: `this+0x14C`
- body-size selector source: `this+0x138`
- vocation index source: `this+0x13C`
- session uid source: `*(CHero_GetSingletonPtr() + 0xA9C)`

**Verified name gate before send** (full table: [Architecture/12](../Architecture/12_create_role_flow.md#submit-0x51c5c3)):
- reject `""`, `strlen < 4`, `strlen >= 16` → StrRes 10037
- per DBCS char: `.` not first/last accepted; else `CMyBitmap::CheckStringPixels(ch, 5, GUI face, normal height)` → StrRes 11089

**Verified body mapping** (corrected 2026-10-24; the earlier even/odd table was swapped — `test edx,edx; je 0x51C78C`):
- even vocation indices (`0,2,4,6,8,10`, male):
  - `body_size == 1` -> `0x3EB` (`1003`)
  - otherwise -> `0x3EC` (`1004`)
- odd vocation indices (`1,3,5,7,9,11`, female):
  - `body_size == 1` -> `0x7D1` (`2001`)
  - otherwise -> `0x7D2` (`2002`)

**Verified profession mapping**:
- vocation indices `0,1` -> `100`
- `2,3` -> `10`
- `4,5` -> `40`
- `6,7` -> `20`
- `8,9` -> `50`
- `10,11` -> `60`

**Verified control-flow implications**:
- create submit stays on the already-authenticated post-DH game socket; it does **not** reopen the account socket.
- cancel is also packet `1001`, but with `cancel_flag=1`, empty name/body/profession, and the same `session_uid`.
- on create success, the client does not reconnect; it waits for `1004` channel 2100 `"ANSWER_OK"` and then calls `CConnectionFlow__SendGameSessionBootstrap`, which re-sends `1052` on the existing game session.

**Own-UI data source note**:
- the shipped label/description surface for vocation/body choices lives in `ini/selectCharacter.ini`
  (`affirmPanel`, `info`, `infoII`), while the packet field mapping above is the verified native C++ contract.

## MsgTeamAward (Type 1029)

**Direction**: S→C. **Purpose**: accumulation of three award counters.
The family name is corroborated by COPS5066; the former `CMsgUserAttrib` label and
HP/MP/level-update description were incorrect.

**Dispatch**: Create `CMsgTeamAward__Create` (`0x75E446`), parse
`CMsgTeamAward__Parse` (`0x75E4AC`), process `CMsgTeamAward__Process` (`0x75E4CF`).
The parser compares type1029 at `0x75E4C8`.

| Packet field | Native addition | Historical COPS5066 label |
|---|---|---|
| `+4`, u32 | hero`+0x109C` at `0x75E50F` | Experience |
| `+8`, u32 | hero`+0x10A0` at `0x75E4EE` | Money |
| `+12`, u32 | hero`+0x10A4` at `0x75E531` | Virtue |

This packet has no attribute discriminator. The type23 update of role`+0x8B8`
occurs in packet10017 at `0x757BFF`; it is separate from these award accumulators.
See the [focused reconciliation](MsgUserInfo1006-historical-field-reconciliation.md).

<a id="msgplayersetinfo-type-1106"></a>

## MsgSyndicateAttributeInfo (Type 1106; former MsgPlayerSetInfo label)

**Direction**: S→C. Constructor `0x760886`, parser `0x7608EC`, process `0x76090F`.
Updates the local hero's syndicate attributes and posts UI command `0x40A`.
The packed field map and current names are in the
[action-61 native contract](21_msgaction_0061_syndicate_bootstrap.md#server-completion-behavior).

**Verified storage map** (packet offsets; historical setter labels retained for cross-reference):
- `+4` (u32) `entry_id` (see flow below)
- `+8` (u32) → `CHero__SetDword_0x878`
- `+12` (u32) → `CHero__SetDwordPair_0x898_0x89C` (low)
- `+16` (u32) → `CHero__SetDwordPair_0x898_0x89C` (high)
- `+20` (u32) → `CHero__SetDword_0x890`
- `+24` (u32) → `CHero__SetDword_0x8A0`
- `+28` (u32) passed to hero vtable method `+212`
- `+32` (char*) → `CHero__SetString_0x884`
- `+48` (u32) → `CHero__SetDword_0x1288`
- `+52` (u32) → `CHero__SetDword_0x128C`
- `+56` (u32) → `CHero__SetDword_0x1290`
- `+60` (u8) → `CHero__SetByte_0x8A4`
- `+61` (u16) → `CHero__SetWord_0x874`
- `+63` (u32) → `CHero__SetDword_0x87C`
- `+67` (u32) → `CHero__SetDword_0x880`
- `+71` (u32) → `CHero__SetDword_0x1284`
- `+75` (char*) → `CPlayer__SetStringProperty` (hero string at `+0x8C8`)


Correction 2026-10-05: zero ID first clears player-set syndicate statuses through
`0x6E98FC` and extended hero state through `0x66563D` (including the `+0x2E74`
block). **Both** zero/nonzero paths then apply all packet fields, including ID.
Nonzero ID additionally marks status 2. This packet does not complete action 61.
The parser does not require 92 bytes; name consumers at packet `+32/+75` use
`strlen`, not fixed 16/17-byte reads. A 92-byte bounded-name encoding is a
compatible reconstruction policy, not a recovered exact native parser length.

## MsgAction (Wire Type 10010; 1010 Not Dispatched In This Build)
**Direction**: Bidirectional (C→S via Create/CreateWalk builders; S→C via Process handler)
**Canonical fixed emission**: 38 bytes (may be larger with a string list); parser `0x6FEB93` itself enforces no 38-byte minimum | **Handler**: `CMsgAction__Process` (0x6FED1F, 0x1C76 bytes)

**Verified incoming dispatch**:
- `CNetMsg__ProcessMsg_Dispatch` (0x6DF3B5) routes `type == 0x271A` (10010) to an allocation of `0x414` bytes and `CMsgAction__Ctor` (0x6FE8A3). Evidence: branch chain at 0x6E12AD (`sub eax, 0x2715` then `sub eax, 5` → 0x6E130B/0x6E1326).
- Parse method `CMsgAction__Parse` (0x6FEB93) calls `CNetMsg__ValidateHeaderAndCopy` and checks `type == 10010`.
- `type == 1010` exists as a case in the 1002–1151 dispatch switch, but it routes to the default path (no create/process) in this build.

```c
struct MsgAction {
    uint16_t size;          // +0: Packet size; normal fixed emission 38, not a parser minimum
    uint16_t type;          // +2: 10010 (0x271A)
    uint32_t entity_id;     // +4: Entity performing the action
    uint16_t param_low;     // +8: Low word of parameter
    uint16_t param_high;    // +10: High word of parameter
    uint32_t action_param;  // +12: Action-specific parameter (referenced by Process for some action types)
    uint32_t timestamp;     // +16: timeGetTime() value (set by builders; read by exactly 5 inbound branches, see below)
    uint16_t action_type;   // +20: Action sub-type (see table below)
    uint16_t direction;     // +22: Direction/facing (used by some action types)
    uint16_t pos_x;         // +24: Map X coordinate
    uint16_t pos_y;         // +26: Map Y coordinate
    uint32_t data1;         // +28: Action-specific data
    uint32_t data2;         // +32: Action-specific data
    uint8_t  flag;          // +36: Action flag byte (used by some outbound builders; may be 0 inbound)
    uint8_t  string_count;  // +37: MsgStringList count byte (0 when absent)
    // +38: Optional MsgStringList entries (when string_count > 0)
};
```

**Verified inbound dispatch key and field consumption** (`CMsgAction__Process`, 0x6FED1F):
- The prologue reads **only** `movzx ecx, word [packet+0x14]` (0x6FED46) and switches on it. No
  entity-id check, no timestamp read, nothing else inspected before the branch is chosen.
- The timestamp at `+0x10` is read in exactly five places across the 0x1C76-byte body, found by
  tracking every `mov reg, [esi+0x404]` packet-base load and its `[reg+0x10]` uses:

| Address | Consumer |
|---|---|
| `0x6FEF51` | `CHero_StartAutoRunFromMsgActionPathFinding` |
| `0x6FF05F` | `CHero_CompleteMovementTimingChallenge` (movement timing / anti-speedhack) |
| `0x6FF952`, `0x700373`, `0x7006E7` | other action branches |

**The rung branches read nothing from the inbound packet — but the common path before them
resolves `+4` (corrected 2026-09-28).** `0x6FF15D..0x6FF18A`: `EntityRef_ResolveByIdOrLocalHero(
&g_objPlayerSet, packet+4, includeLocalHero=1)`; unresolved -> only `0x4F/0x51/0x63/0x82/0x89`
continue (`0x6FF1B0`, sends MsgAction `0x66` with `+4`), all other keys exit `0x700974`. Main switch
`0x6FF231`: `0x4A`->`0x6FF44A`, `0x4B`->`0x6FF3CD` (also posts main msg `0x401`), `0x4C`->`0x6FF365`,
`0x4D`->`0x6FF2FA`, `0x4E`->`0x6FF283`. Rung shape:

```
CMsgAction_Ctor(&local)
eax = CHero_GetSingletonPtr()->+0xCC        ; local hero id, NOT packet+4
push 0 ; push nextAction ; push 0,0,0 ; push eax
CMsgAction__Create(heroId, 0, 0, 0, nextAction, 0)
CNetMsg__Send(&local)
```

Normal Create-built follow-ups take the entity ID from the hero singleton and
use their own `Conquer_GetTimeGetTime()`. The received-61 branch instead uses
the separate FB builder: zero entity ID, checksum and version. Echo requirements: subtype `+0x14` must match; `+4` must resolve (use local hero
id for bootstrap) on `0x4B..0x4E`/`0x61`/`0xFB`; timestamp `+0x10` is ignored on those routes. (Earlier claim "echoed entity id never
observed" was wrong.) Rung ranges: `0x61` send `0x6FF28A..0x6FF2EB`, `0x4E` send
`0x6FF300..0x6FF356`, `0x4D` send `0x6FF36B..0x6FF3C1`, `0x4C` send `0x6FF3D3..0x6FF440`, `0x4B`
send `0x6FF44A..0x6FF594`.

**Verified `MsgStringList` placement (variable payload)**:
- `CMsgAction__Ctor` (0x6FE8A3) calls `MsgStringList__InitBuffer(this+0x408, (char*)this+41, 0x3DB)`, i.e., the string list begins at `packet+0x25` (byte offset `37`, immediately after `flag`).
- `CMsgAction__Process` uses `MsgStringList__GetCount` / `MsgStringList__GetEntry` in some action subtypes (e.g., branch at 0x7007B0).
- String list format matches the `MsgStringList` description under `MsgTalk` (count byte followed by `[len][bytes]` entries).

See [the action-61 contract](21_msgaction_0061_syndicate_bootstrap.md) for the
recovered enum, exact request/reply consumption, 61→FB→84 transition, direct
builder census, replay vectors, and retail-server evidence limits.

### Action Sub-Types
| Value | Hex  | Name | Description |
|-------|------|------|-------------|
| 74    | 0x4A | SetLocation | Set entity world position |
| 75    | 0x4B | GetItemSet | Client follow-up request emitted immediately after processing server `0x4A` during world-entry bootstrap |
| 85    | 0x55 | ChangeMap | **Verified 2026-08-28** at `0x65DD3B`, named by the build's own assert string `actionChgMap`. Client-originated: the hero tick finds an exit tile beside the hero and sends this naming that tile in the parameter pair. Not walking — walking is packet 10005. Inbound 85 has no case (inert). |
| 86    | 0x56 | actionFlyMap | **Verified 2026-10-24** at `0x6FF652`. Server→client map transition. `+4` must equal the hero id (CHECK). Map create from `+8`, tile `+0x18/+0x1A`, dir `+0x16`, pets follow, camera, 0x11C type 5, then mode `0x3F2` ends the `0x3F0` wait. Sends nothing. See [portal transition](../Server/portal-transition-5517.md) |
| 93    | 0x5D | AutoMine | Automatic mining action |
| 94    | 0x5E | actionReborn | **Verified 2026-10-16.** Client→server revive request, `+8` = 0 Revive / 1 Revive Here (`CHero_RequestReborn` `0x65D819`). Inbound 94: prologue `0x6FEE02` posts 0xD74 (hide CDlgXp, clear `m_bDie`). Former "Hotkeys" label wrong. See [death/ghost/revive](../Server/death-ghost-revive-5517.md) |
| 97    | 0x61 | actionGetSynAttr | **Verified 2026-10-05**, recovered native assertion. Sent after 4E completion; resolvable-ID 61 reply sends FB silent-info report. |
| 132   | 0x84 | actionGetStatistic | **Verified next request after resolvable-ID FB reply**, assertion `0x945E48`, send `0x700944`. |
| 251   | 0xFB | SilentInfoReport (analyst label) | **Verified 2026-10-05**: client request entity=0, checksum at +8, version at +16. Response requires a resolvable ID to advance to 84. |
| 101   | 0x65 | ConfirmGuild | Guild/faction confirmation |
| 104   | 0x68 | actionMapARGB (inbound) | **Verified 2026-10-24 (inbound only).** Prologue `0x6FED87`, before the entity gate: `+8`==0 ⇒ 0xFFFFFFFF; `CGameMap_SetMapARGB(+8 \| 0xFF000000)` (`0x61ED50`, map `+0x368/+0x13C`). eosource `actionMapARGB`; TQ `SendLight`. The former "Mine" label is unverified |
| 106   | 0x6A | EntitySpawn | Entity appeared in view |
| 111   | 0x6F | CreateBooth | **Verified 2026-08-29.** The inbound local-hero branch passes the dword at `+8` to `CBoothManager_Open`. A nonzero value becomes the booth NPC ID and sets the embedded manager active. Zero selects the separate client setup/validation path. |
| 114   | 0x72 | CloseBooth | **Verified outbound from `CBoothManager_Close`.** Sent after the manager clears prices, listed items, NPC ID, active state, and cry-out text. |
| 124   | 0x7C | PlaySoundById | Resolves sound path from `sound_id` (`+8`) via `GameDataSetQuery()->vtable[+0x30]`, then calls `DXPlaySound` with defaults `(0,0,0,0,100)` |
| 102   | 0x66 | QueryEntity | **Verified 2026-08-28**. Client-originated: `CMsgEntityAction__Process` builds it at `0x740730` when a movement packet names an entity it cannot resolve, carrying its own hero id and facing with the unresolved id in the parameter pair at `+8`. Answered by re-sending that entity's `10014`. |
| 408   | 0x198 | ClientStateApplied | **Verified 2026-08-29.** Client-to-server only, with every field zero (`CMsgAction__BuildType10010(msg, 0x198, 0)`). Seven senders: the four MsgItem apply branches (`0x6EB099` subtype 17, `0x6EB2ED` unequip, `0x6EB51D` equip, `0x6EB6F5` subtype 18), both equipment-set switch paths in `sub_6DAEB9` after MsgItem `0x2C`/`0x2D`, and `CMsgMapInfo1110__Process` at `0x732D38` after applying a new map. **Corrected**: an earlier note called this equipment-only; the map-info sender disproves that. What the seven share is a just-completed refresh of hero-visible state. **Takes no reply**: `0x198` appears nowhere in `CMsgAction__Process`'s disassembly. |
| 128   | 0x80 | DropItem | Drop item on ground (calls CAntiCheatMgr__GetBodyMatrixFloat) |
| 100   | 0x64 | ReportPosition / challenge | **Verified 2026-08-28.** Outbound from the client it is a periodic position report — `CHero_TickIdlePositionSyncSend` (`0x661AAC`) sends the hero id, tile and facing from a tick, unprompted. Inbound to the client it is unrelated: the branch at `0x6FFC39` computes a replacement for packet `+8` and returns the packet, a challenge rather than an acknowledgement. |
| 108   | 0x6C | CorrectPosition | **Verified 2026-08-28** at `0x6FFC4B`. Server-to-client: applies the tile at `+0x18`/`+0x1A` to the local hero — entity id must resolve to the hero — with no effect or animation, then replies with subtype 146. The right packet for correcting a position; 156 is a teleport and plays `"KOTeleport"`. |
| 130   | 0x82 | SyncPosition | Position synchronization |
| 134   | 0x86 | ChangeDirection | Change facing direction |
| 135   | 0x87 | RemoveEntity | **Verified 2026-08-28** at `0x70051A`. Reads only the entity id at `+4`, then calls `EntityManager_RemoveEntityById(&g_objPlayerSet, id, 1)` at `0x7005AC`. Plays the `"BodyDisapear"` effect first only for ids `<= 999999` that pass three role-state gates. An id that does not resolve is a no-op. |
| 137   | 0x89 | Jump | Jump request/echo and remote jump command |
| 146   | 0x92 | SynchronizePosition | **Verified 2026-08-28** at `0x7001DF`, and **not an emote**. For the local hero the client compares the packet's tile against its own and, when they differ, rewrites the packet with its own tile plus the map state at `+0x1C` and returns it. For a remote role it snaps that role onto the tile. The client also sends it unprompted to acknowledge a subtype 108 correction. A server must never echo one back — both ends answer it. |
| 151   | 0x97 | Portal | Enter portal/teleport |
| 156   | 0x9C | Teleport | **Verified 2026-08-28** at `0x7003E9`. Builds a `0x11C` command-state block with command type `0x28`, moves the entity to the tile pair at `+0x18`/`+0x1A`, and plays `"KOTeleport"`. It removes nothing; the previous "RemoveEntity" label here was wrong. |
| 157   | 0x9D | SetPkMode | Set PK mode (calls CGameMap) |
| 158   | 0x9E | LoginComplete | Login sequence complete |
| 145   | 0x91 | actionGhost | **Verified 2026-10-16.** Client→server once, 3 s after status 5 (`CHero_ProcessReborn` `0x65DF0B`); all fields 0 except entity/time/action. Inbound 145 ignored |
| 159   | 0x9F | OverheadCountdown (analyst label) | **Verified 2026-10-16.** Inbound `+8` seconds → `CHero_StartOverheadCountdown` `0x66699D` (`hero+0x2ED0..D8`), drawn red under 10 s. Former "SetGhost" label wrong |
| 162   | 0xA2 | AutoPathFinding (analyst label) | **Verified 2026-10-16.** Prologue `0x6FEF2D`: target map `+0x10`, tile `+0x18/+0x1A` → `CHero_StartAutoRunFromMsgActionPathFinding` `0x666E07`; refused dead (StrRes 11127) / vending (11124). Former "Reborn" label wrong |
| 235   | 0xEB | TexasHoldem | Texas Hold'em poker action |

### Verified subtype `0x6F` booth-open response

The branch at `0x6FFE50..0x6FFE7B` first compares `msg.entity_id` with the local hero ID. A mismatch
has no booth effect. On a match it passes `msg.param_low | (msg.param_high << 16)` to the embedded
`CBoothManager_Open` (`0x70A832`). For a nonzero parameter, the writes at
`0x70AAB0..0x70AAB3` store the booth NPC ID and set `isActive = 1`; the function then requests local
role action `0xFA`.

The managed ingress currently implements this proven nonzero-ID state write. It rejects zero rather
than pretending that path is an inactive response, because native zero enters map-tile validation
and an outbound booth-creation request. Full booth setup, close, UI, inventory, and the `0xFA`
role-action side effect are not part of this slice.

### Constructor Functions
| Address | Name | Parameters |
|---------|------|-----------|
| 0x6FE8A3 | CMsgAction__Ctor | () |
| 0x6FE921 | CMsgAction__Dtor | () |
| 0x6FE95F | CMsgAction__Create | (entity_id, pos_x, pos_y, direction, action_type, param_dword) — Sets `size=38`, `type=10010`, `timestamp=timeGetTime()` |
| 0x6FE9F3 | CMsgAction__CreateFull | (entity_id, pos_x, pos_y, direction, action_type, param_lo, param_hi, timestamp_or_0, data1, data2) — Sets `size=38`, `type=10010` |
| 0x6FEAD0 | CMsgAction__CreateWalk | (entity_id, pos_x, pos_y, direction, param_lo, param_hi, data1) — Sets `action_type=137`, `flag=1`, `data2=-1` |

### Verified subtype `0x89` command-ingress block build

`CMsgAction__Process` branch `action_type == 0x89` (Conquer.exe: `0x700352`) first
compares `msg.entity_id` with the local hero id.

The local branch at `0x700368` calls
`CHero_ProcessMovementAcknowledgementTimestamp(msg+0x10)`, then joins the shared
coordinate-gate path at `0x7002E3` with the destination from `msg+0x08/+0x0A`.
It does **not** enqueue or replace the local command-state block. The `CHero`
coordinate gate is distinct from the interpolated protected `CRole` tile pair.

The resolved non-local branch builds and dispatches a `0x11C` role command-state
block via role vtable slot `+0x80`:

- block reset:
  - `RoleActionCommandState_ResetBlock0x11C(&block)` at `0x70039C`
- writes:
  - `block+0x00 = 0x14 + (msg+0x24 != 0)` (`setne` + `add 0x14`) at `0x7003B2..0x7003C2`
  - `block+0x04 = 0` at `0x7003B5`
  - `block+0x20 = zx(msg+0x08)` at `0x7003C8..0x7003CC`
  - `block+0x24 = zx(msg+0x0A)` at `0x7003D2..0x7003D6`
- dispatch:
  - `call [roleVtable+0x80](role, &block)` at `0x7003DE`
  - for `CRole` vtable, `+0x80` resolves to
    `Role_TryApplyIncomingActionInfoWithConditionalStateSync` (`0x65C079`)
    via table entry `data_86AD08 + 0x80 = 0x86AD88` (`79 C0 65 00`).

### Verified subtype `0x4A` command-ingress block build

`CMsgAction__Process` branch `action_type == 0x4A` (Conquer.exe: `0x6FF44A`) builds and dispatches a
`0x11C` command-state block with command type `0x05`:

- block reset:
  - `RoleActionCommandState_ResetBlock0x11C(&block)` at `0x6FF4EE`
- writes (offsets from block base):
  - `+0x00 = 0x05` at `0x6FF4F3`
  - `+0x04 = 0` at `0x6FF4FD`
- dispatch:
  - `call [CHeroVtable+0x80](hero, &block)` at `0x6FF513`
- companion side effects in the same branch (outside ingress block write):
  - map create/load attempt `CGameMap_CreateFromDataId(CGameMap_GetSingletonPtr(), msg+0x08)` at `0x6FF468..0x6FF47F`
  - hero tile set + projected position flow from `msg+0x18/+0x1A` at `0x6FF4A2..0x6FF4CC`
  - hero coordinate-gate/map sync `Role_UpdateCoordinateGateAndMapFromTilePair(hero, tileX, tileY)` at `0x6FF4CC`
  - hero direction update from packed `msg+0x16` through `CRole_SetDirectionFromPacked8` at `0x6FF4D5..0x6FF4E7`
  - immediate client follow-up send:
    - creates `MsgAction actionGetItemSet (0x4B)` with `(heroId, 0, 0, 0, 0x4B, 0)`
    - constructor `CMsgAction__Ctor` at `0x6FF51F`
    - builder `CMsgAction__Create` at `0x6FF54A`
    - send `CNetMsg__Send`
    - embedded evidence string in the branch:
      - `"msg.Create(g_objHero.GetID(), 0, 0, 0, actionGetItemSet)"`

### Verified subtype `0x56` map-create side effect

`CMsgAction__Process` branch `action_type == 0x56` performs map create/load through the same
`CGameMap_CreateFromDataId(CGameMap_GetSingletonPtr(), msg+0x08)` path:

- callsite: `0x6FF6FB`
- argument source: dword at `msg+0x08` (`ParamLow`/`ParamHigh` pair on the wire)

**Correction 2026-10-24:** the branch *does* build a `0x11C` block. `RoleActionCommandState_ResetBlock0x11C`
runs at `0x6FF860`, with `+0x00 = 5` and `+0x04 = 0`, then hero vf+0x80 is called at `0x6FF885`, the same as `0x4A`.
The earlier "no `0x11C`" statement was wrong. Full step list:
[portal transition §2](../Server/portal-transition-5517.md#2-inbound-86-actionflymap-c).

### Managed mapping for verified map-create side effects

Runtime mapping in `10_work`:

- `CGameMapMsgActionIngressRuntime` queues map-create requests for subtypes `{0x4A, 0x56}` from `msg+0x08`.
- `RoleCommandStateInboundPacketDispatchRuntime` now fans a decoded MsgAction packet to both:
  - command-state ingress (`0x4A/0x89/0x51/0x9C`)
  - map-create ingress (`0x4A/0x56`)
- `CGameMapResourceRequestLifecycleRuntime` processes queued requests in map-stage tick and calls
  `CGameMapCreateFromDataIdRuntime` (lookup -> map-file load -> current-map-id write -> post `0x424`).
- `ClientWorldInboundPacketApplyRuntime` now also applies the verified non-command side effects of subtype `0x4A`
  into shared runtime state:
  - stores the latest server-enter-map tuple `[entityId, mapDataId, tileX, tileY, direction]`;
  - updates the local-hero role snapshot position/direction when the entity already resolves as the local hero.
- startup/bootstrap parity must also emit the verified client follow-up `MsgAction 0x4B (GetItemSet)` after the
  server `0x4A` side effects have been observed and the command/map ingress handlers have run.
- corrected item receive contract: local inventory and tracked equipment use `Msg1008 (1008)` subtype1;
  active equipment is selected through MsgTick1009 subtype46. Subtype4 targets inspected `CDummy`
  equipment, not local hero equipment. See [the item contract](MsgItem1008-domain-contract-5517.md).

Conservative managed scope note:
- native `0x4A` also drives hero projected-screen updates and coordinate-gate/map sync immediately in the
  message handler (`0x6FF4A2..0x6FF4CC`);
- the current managed slice persists the verified world-entry state and real map-load request, but does **not**
  claim full projection/camera/UI parity from this packet yet.

### Verified subtype `0x51` command-ingress block build

`CMsgAction__Process` branch `action_type == 0x51` (Conquer.exe: `0x6FF5B6`) builds one or more
`0x11C` command-state blocks with command type `0x06`:

- shared source reads:
  - `memcpy(&tmp, msg+0x08, 4)` at `0x6FF8D0..0x6FF8D7`, then `zx(tmp.low16)` is used as command data.
  - direction source is `zx(msg+0x16)` at `0x6FF931..0x6FF937`, `0x6FF9BE..0x6FF9C4`, `0x6FFA0E`.
- block writes (offsets from block base):
  - `+0x00 = 0x06` at `0x6FF917`, `0x6FF9A4`, `0x6FF9F0`
  - `+0x04 = 0` at `0x6FF921`, `0x6FF9AE`
  - `+0x04 = 7` at `0x6FF9FA`
  - `+0x18 = 0` at `0x6FF927`, `0x6FF9B4`, `0x6FFA04`
  - `+0x24 = zx(msg+0x16)` at `0x6FF937`, `0x6FF9C4`, `0x6FFA0E`
  - `+0x3C = zx(msg+0x08)` at `0x6FF90B..0x6FF911`, `0x6FF998..0x6FF99E`, `0x6FF9E4..0x6FF9EA`
- dispatch paths:
  - source-role path (`msg+0x04` resolved role id != hero id): `call [roleVtable+0x80](role,&block)` at `0x6FF940`.
  - action-param role path (`msg+0x10` resolved role id != hero id): `call [roleVtable+0x80](role,&block)` at `0x6FF9CD`.
  - action-param role path (`msg+0x10` resolved role id == hero id): `CHero` `+0x80` dispatch at `0x6FFA24`.

### Subtype `0x51` pose payload (CP1.2, 2026-11-05)

Send: `Role_SendCommandStartPacketsAndSelectAction` `0x74353F` — command type `role+0x1E8 == 6` at progress
`role+0x1EC == 0` → `CMsgAction__Create(id, x, y, dir = role+0x210, 0x51, data = role+0x228)` (`0x743605..0x74364B`).
Receive/display: `Role_CommandType06_SelectActionFromCommandPayloadMap` `0x73450B` reads the same `role+0x228`:

| Payload | State `+0x1EC` / action `+0x1A4` |
|---|---|
| ≤ 0, unlisted (incl. 18–149, 914) | 6 / 100 standby — not rejected |
| 1–17, 150, 160, 170, 190, 200, 210, 474, 478 | 2 / payload |
| 230, 270, 473 | two-stage: 0→(2, p); 2→(3, p+1) |
| 250 | two-stage: `…PayloadFAFirstStageAction` `0x64F0D5` / `…SecondStageAction` `0x64F102` |
| 903, 913, 915–917 | 6 / payload |

Displayable pose set = the non-default rows plus 100.

### Verified subtype `0x9C` command-ingress block build

`CMsgAction__Process` branch `action_type == 0x9C` (Conquer.exe: `0x7003E9`) builds a
`0x11C` command-state block with command type `0x28`:

- block reset:
  - `RoleActionCommandState_ResetBlock0x11C(&block)` at `0x70040E`
- writes (offsets from block base):
  - `+0x00 = 0x28` at `0x700416`
  - `+0x04 = 0` at `0x700420`
  - `+0x20 = zx(msg+0x18)` at `0x70043E..0x700442`
  - `+0x24 = zx(msg+0x1A)` at `0x700448..0x70044C`
  - `+0x28 = Role_SelectDirectionIndexTowardTile(resolvedRole, pos_x, pos_y)` result at `0x700457..0x70045C`
  - `+0x40 = Conquer_GetRandomModulo(3, 0) + 0x393` at `0x700426..0x700431`
- dispatch:
  - resolved role id == hero id: `Role_HandleIncomingActionStateBatch` (`0x6720EE`) at `0x70047E..0x70048C`
  - otherwise: `call [roleVtable+0x80](role,&block)` at `0x70049F`
- companion non-block side effects in this branch (kept separate from ingress block mapping):
  - callback/event `"move_end"` checks at `0x7004A5..0x7004DC`
  - hero tile sync call `Role_UpdateCoordinateGateAndMapFromTilePair(hero, pos_x, pos_y)` at `0x7004F2..0x700509`

### Verified subtype `0x82` movement sync path (no `0x11C` command-ingress build)

`CMsgAction__Process` branch `action_type == 0x82` (Conquer.exe: `0x7002CD`) does not build a
`0x11C` command-state block and does not dispatch role vtable slot `+0x80`.

- hero-id path:
  - compare `msg.entity_id` vs `hero.id` at `0x7002D0..0x7002E1`
  - direct hero coordinate-gate/map sync `Role_UpdateCoordinateGateAndMapFromTilePair(hero, msg+0x08, msg+0x0A)` at `0x7002E3..0x7002FA`
- non-hero resolved-role path:
  - predicate `Role_IsEntityId700001To799999AndHeroLinked(resolvedRole)` at `0x700307` / `0x700385`
  - predicate true: `Role_SetFieldA88A8CFromActionParamPair(resolvedRole, msg+0x08, msg+0x0A)` at `0x700310..0x700323`
  - predicate false: call role vtable slot `+0x18` with `msg+0x08/+0x0A` at `0x70032D..0x70034A`

This branch is explicitly classified as non-command-ingress for the `0x11C` state queue.

### Verified subtype `0x7C` sound dispatch chain

`CMsgAction__Process` branch `action_type == 0x7C` (Conquer.exe: `0x6FFEBF`) performs:

1. `dataset = GameDataSetQuery()`
2. `path = dataset->vtable[+0x30](sound_id)` with `sound_id = *(msg + 8)` (Conquer.exe: `0x6FFED4`)
3. if `path != null`, resolve again and call `_DXPlaySound@24(path, 0, 0, 0, 0, 100)` (Conquer.exe: `0x6FFEF4` -> `0x7001D4`)

This is the confirmed runtime bridge between action packet subtype `0x7C`, `GraphicData.dll` sound DB lookup, and `NDSound.dll` playback.

## 2026-08-16 — historical target-discovery record

The open-status labels and proposed broad searches in this historical section are superseded
by the [current reconciliation](MsgUserInfo1006-historical-field-reconciliation.md).
They remain here as provenance, not current investigation instructions.

`CMsgUserInfo__Process` (`0x764276`) was read end to end. The packet body pointer is
`*(arg1+0x404)`, so its offsets are packet-relative including the 4-byte header. Every previously
open field now has a concrete destination, which narrows the remaining work from "find the field"
to "name the field":

| Packet offset | Destination in the handler | Status |
|---|---|---|
| `+32` (`0x20`) | `hero+0x85C` (`field_85C`) | target known, meaning open |
| `+36` (`0x24`) | `hero+0x844` (`field_844`) | target known, meaning open |
| `+40` (`0x28`) | `hero+0x848` (`field_848`) | target known, meaning open |
| `+44` (`0x2C`) | `hero+0x8B8` (`field_8B8`) | target known, meaning open |
| `+72` (`0x48`) | `hero+0xF34` (`field_F34`) | target known, meaning open |
| `+74` (`0x4A`) | `hero+0xCE4` (`field_CE4`) | target known, meaning open |
| `+81` (`0x51`) | hero **vtable `+0xE4`** call, not a field store | target known, meaning open |
| `+87` (`0x57`) | `sub_673266(hero, v)` | target known, meaning open |

Everything else in the packet is confirmed; the full verified offset map is now recorded as a
Binary Ninja function comment on `CMsgUserInfo__Process`.

**Stamina is settled by direct evidence.** At `0x7646A9` the handler writes
`pad_478[0x3B8..0x3BB] = 0`, i.e. `hero+0x830` is explicitly zeroed by this packet. The field is
current physical force, its maximum is `hero+0x834`, and neither travels in `1006`.

### Negative result: the attribute panel is exhausted

`CDlgRoleAttribute_RefreshLabelsFromHero` (`0x50691E`) was re-read in full. It renders level
(`+0x838`), profession (`+0x82C`), the four attributes (`+0x4FC`/`+0x504`/`+0x508`/`+0x50C`),
unspent points (`+0x840`) and PK points (`+0x868`) — all already proven — and **touches none of the
eight open fields**. Do not re-check it for them.

### Independent capture source (was reported missing)

A real capture *does* exist, and it is not a `.pcap` and not under `10_work`:

```
50_server/OpenConquer5517v3/out/game-packets.ndjson
```

~23 MB of NDJSON written by the legacy server itself (`PacketTraceEnabled` /
`PacketTraceDirectory: ./out` in `appsettings.shared.json`). Each record carries `id`, `idName`,
`direction`, a `parsed` block, and a base64 `Frame` holding the complete wire packet. A `1006`
frame from it is now embedded as a regression fixture in
`tests/Conquer.Tests/Network/Packets/MsgUserInfo1006HeroStatFieldTests.cs`.

Two cautions on using it. The wire frame is the packet **plus an 8-byte `TQServer` seal**
(`131 = 123 + 8`), and the managed reader requires the seal stripped because
`PacketValidator.ValidateHeader` demands `declared size == buffer length`. And the legacy server's
`PlayerInfoWriter` leaves `+32`, `+36`, `+40`, `+44`, `+48`, `+81` and `+106` **zero**, so this
capture cannot settle most of the eight open fields — they need binary evidence or a capture from
a server that populates them.

### `+87` is CLOSED — flower-status tier (`hero+0x474`)

Proven from four independent directions (fifth consumer added 2026-09-28):

1. `CMsgUserInfo__Process` at `0x7646BF` calls `CHero_SetFlowerStatusTier` (`0x673266`), a one-line
   setter storing to `hero+0x474`. Getter is `CHero_GetFlowerStatusTier` (`0x5D4B61`).
2. `CMsgUserAttrib__Process` case `0x27` (`0x757E25`) writes the same field through the same
   setter, so the value also arrives as a live attribute update.
3. `CUserAttribMgr_RenderStatusIconTooltips` case `0x16` (`0x6F13FE`) reads it, clamps
   `v = min(v, 6)`, and uses it as an **index** into the 7-entry ladder `{1,2,3,5,10,15,30}` while
   formatting the string keyed **`STR_SEND_FLOWER_TIP`**. The retained source path is
   `F:\CQ2ClientRelease-42.0.1\3DRole\UserAttribMgr.cpp:0x75F`. Being an index, not an operand,
   this is a small **tier** (0..6) — not a raw flower count.
4. `CHero_SetCoachPointsAndShowPrompt` (`0x6ED511`) gates on it at level `>= 0x5A` (90):
   tier `< 1` selects `GET_COACH_CHANCE`, otherwise `GET_EXTRA_COACH_CHANCE`, formatting the tier
   both raw and as `tier * 0.01`.
5. `CHeroFriendAndEnemyMgr_GetMaxFriendCount` (`0x69E4FD`), when `CHeroConfigMgr` bit 10 set:
   tier 0..5 -> 50/55/60/70/80/90, other -> 100 (`0x69E506..0x69E54B`). Another tier-indexed ladder;
   field name "FlowerStatusTier" covers only the flower consumer.

`STR_SEND_FLOWER_TIP` is **not** present in the shipped `00_clean/clean/5517` tree — only
`data/AutoPatch_pic/Res.ini` ships `STR_` keys — so the key name embedded in the binary is the
evidence, and no localized text is available to quote.

`sub_673E79` (now `j_CHero_GetFlowerStatusTier`) is an incremental-link **jump thunk** onto the
getter: the call site address equals the function's own entry. It is a linker artifact, not
behaviour, and is not ported.

### `+44` cross-confirmed as a real hero attribute (still unnamed)

`CMsgUserAttrib__Process` case `0x17` (`0x757BFF`) writes `hero+0x8B8` directly. That fixes the
attribute type code at `0x17` and proves the field is a first-class hero attribute rather than
packet padding, but the case is a bare store with no strings, so the **meaning is still open**.

### Enum cross-check (independent confirmation of already-proven fields)

The `MsgUserAttrib` switch agrees with the `MsgUserInfo` mapping on every field they share:
`case 7 -> hero+0x82C` (profession), `case 8 -> hero+0x830` (stamina),
`case 0xA -> hero+0x840` (unspent attribute points). Two independently written handlers landing on
the same offsets is strong confirmation — and `case 8` writing stamina to `0x830` independently
re-proves that stamina is its own attribute and does **not** ride in `1006`.

### Method warning: raw displacement scans produce false positives

Scanning `.text` for `mod=10` ModRM instructions whose `disp32` equals a target hero offset finds
the real sites (it correctly located `0x7645C5` inside `CMsgUserInfo__Process` and `0x756525` in
the spawn handler), but **the same displacement occurs on unrelated base structures**. Worked
example: `0x50D6E5` matches `+0x8B8`, yet `sub_50D5EC` is a `CDialog` constructor chaining member
constructors at `+0x768`, `+0x8B8`, `+0xA08`, `+0xB58`, … on the *dialog* object. It has nothing to
do with `CHero`. This is the same trap that earlier made `sub_52A4A8` (the `DlgSubProfession`
constructor) look like a reader.

A scan hit is therefore only a candidate. Before using one, confirm the base register actually
holds a `CHero*`. "Nearest defined function at or below the address" is likewise **not** a safe way
to attribute a site — use Binary Ninja's own `function_at`.

### Still open at the time of writing: `+32`, `+36`, `+40`, `+44`, `+72`, `+74`, `+81`

> Superseded below: `+81` was closed later the same day. The `+81` row is kept only for the
> record of how it was approached.

| Packet offset | Destination | Best next lever |
|---|---|---|
| `+32` | `hero+0x85C` | candidate clusters `0x413xxx`, `0x5589F9`–`0x558EF1` |
| `+36` | `hero+0x844` | readers `sub_4E63E2`, `sub_50BFAC` (dialog range — verify base is `CHero*`) |
| `+40` | `hero+0x848` | clusters `0x4A08F1`–`0x4A1B63`, `0x52A580`–`0x52BD60` |
| `+44` | `hero+0x8B8` | attrib type `0x17` known; needs a string-bearing reader |
| `+72` | `hero+0xF34` | shares the `0x52Axxx`–`0x52Dxxx` region with `+40`, near `DlgSubProfession` |
| `+74` | `hero+0xCE4` | reader `sub_469404`; clusters `0x450xxx`, `0x469xxx`–`0x46Axxx` |
| `+81` | hero **vtable `+0xE4`** call | resolve the vtable slot to a concrete method first |

The lever that closed `+87` is the one to repeat: find a dedicated accessor for the offset, xref it,
and read the callers that carry `STR_*` keys or retained `.cpp` source paths.

## 2026-08-16 (later) — `+81` closed, and every open field's width now proven

### Correction to the entry above: `+87` is a DWORD, not a byte

The first pass added `+87` to the managed reader as a `byte`. That was wrong. The call site is

```
0x7646BA   ff 71 57      push dword ptr [ecx+0x57]      ; NOT a byte load
0x7646BF   call CHero_SetFlowerStatusTier
```

`FF /6` is `PUSH r/m32`, so the field is a **u32 spanning 87..90**, stopping exactly short of the
title id at 91. The reader and its test were corrected; the test now writes `01 02 03 04` across
all four bytes and asserts `0x04030201`.

### `+81` is CLOSED — coach EXP-share count (`hero+0x9A8`)

The virtual call resolved cleanly once the vtable was located. `CHero_Ctor` assigns the primary
vtable at `0x655730` (`*this = &data_86AD08`), so slot `+0xE4` is **`0x86AD08 + 0xE4 = 0x86ADEC`**,
which holds `0x6ED5FD` = `CHero_SetCoachExpShareCountAndShowPrompt` (virtual index 57).

Call site, `CMsgUserInfo__Process` `0x764705`:

```
0f b7 49 51             movzx ecx, word ptr [ecx+0x51]   ; packet +81, u16
ff 92 e4 00 00 00       call dword ptr [edx+0xE4]
```

The handler stores to `hero+0x9A8` and is a pure state-transition prompt:

- `0 -> non-zero`: raise status icon `0x39` with sub-kind 8; post code `0xCAA`
- `non-zero -> 0`: clear icon `0x39`, show **`STR_COACH_EXP_FIN`**, fire CardPlay `COACH_EXP_FIN`
- every call stamps `hero+0x2DC4 = timeGetTime()`

Note what is and is not proven: the string and event names establish this is the **coach EXP-share**
slot, but the handler only ever tests the value against zero, so the *unit* ("count" vs. remaining
time vs. percentage) is not established by it. The managed field carries the name of the existing
symbol and documents that limit.

The function sits immediately after `CHero_SetCoachPointsAndShowPrompt` (`0x6ED36D`–`0x6ED5FA`), so
the two were adjacent in the original source — both coach-system setters. That adjacency is also
why `+79` (coach points, `movzx word [ecx+0x4F]`) and `+81` behave alike.

### Widths of the five still-unnamed fields, proven from opcodes

Read straight out of the PE at each store, so these are certain even though the meanings are not:

| Packet offset | Load instruction | Width | Destination |
|---|---|---|---|
| `+32` | `8b 49 20`  `mov ecx,[ecx+0x20]` | u32 | `hero+0x85C` |
| `+36` | `8b 49 24` | u32 | `hero+0x844` |
| `+40` | `8b 49 28` | u32 | `hero+0x848` |
| `+44` | `8b 49 2c` | u32 | `hero+0x8B8` |
| `+72` | `0f b6 49 48`  `movzx ecx,byte [ecx+0x48]` | **u8** | `hero+0xF34` |
| `+74` | `0f b6 49 4a` | **u8** | `hero+0xCE4` |

`+72` and `+74` being single bytes matters: they bracket the reborn count at `+73`, so any reader
treating them as `u16` would silently swallow it.

`CHero_Ctor` independently confirms all of these are real `CHero` members — it zero-initialises
`+0xCE4` at `0x655DC3` and `+0xF34` at `0x655DEB`.

### Method note: resolving a virtual call

Locating the vtable in the constructor and reading the slot out of the PE took three steps and no
guessing. Prefer it over searching for candidate handlers: find `*this = &vtable` in the ctor, add
the slot offset, convert VA to file offset via the section headers, and read the dword. `function_at`
then names it (its output still fails schema validation, but the name is readable in the error).

**Six fields remain open: `+32`, `+36`, `+40`, `+44`, `+72`, `+74`** — targets and widths known,
meanings not.

## 2026-08-16 (third pass) — accessor lever exhausted; a lead on `+40`

### No accessors exist for the remaining six

The lever that closed `+87` was "the offset has a dedicated one-line accessor, so xref the accessor".
The PE was scanned exhaustively for that shape on all six remaining offsets — `__thiscall` getters
(`8b 81 <disp32> c3`), byte and word variants (`0f b6` / `0f b7` / `8a`), and the matching setters
(`8b 44 24 04 89 81 <disp32> c2 04 00`). Result:

- `0x844`, `0x848`, `0x8B8`, `0xF34`, `0xCE4`: **no accessor of any form**
- `0x85C`: one hit, `sub_66D3C6` — and it is a **false positive**

`sub_66D3C6` is real, but its only caller (`sub_4DD0E4`, `DlgNpcEquip.cpp`) invokes it as
`sub_66D3C6(&hero->pad_000[0x1EA0])`. The base is `hero+0x1EA0`, so it reads `hero+0x26FC`, not
`hero+0x85C`. Same class of trap as the displacement-scan false positives — **an offset match is
never enough; the base register decides**.

Those historical scans did not expose a consumer. They did not exhaust virtual or computed
paths: the 2026-09-17 audit recovered a previously undefined hero vtable function at 0x661F09
and resolved a separate misaligned trampoline chain. See the current audit for exact scope.

### Lead on `+40` / `hero+0x848` — plain vs. protected health storage

`CMsgPlayer__Process` writes `0x848` at `0x756525`, and the surrounding branch is informative.
The role id lives at `role+0xCC` (proven: `MsgUserInfo` stores its `EntityId` there at `0x764324`),
and the handler splits on `id > 0xF423F` (999999). **2026-09-17 correction:** the older
branch labels were reversed. Native IsPlayer CHECK at 0x67350E rejects IDs<=999999.

```
id  > 999999 (player branch):     *(role + 0x848) = u32(spawn + 0x50)
id <= 999999 (non-player branch): sub_673eac(role, 1, zero_extend(u16(spawn + 0x50)))
```

Both branches consume the **same** spawn offset `0x50`. And `sub_673eac` is exactly what
`CMsgUserInfo__Process` calls at `0x764351` with `packet[+62]`, i.e. CurrentHealth:

```
sub_673eac(role, index, value):
    if (role is the local hero && index == 1 && current > value) -> record a timer event
    -> sub_749e47(*(role + 0x978), value, index)
CHero_GetPlayerDataByIndex(role, index) -> FDword_GetValueByIndex(*(role + 0x978), index)
```

This establishes two distinct writes on different branches. It does not establish that
the +0x848 dword and protected life value have the same gameplay meaning.

**This is a lead, not a closure.** It does not settle `+40`, because `MsgUserInfo` writes *both*
`sub_673eac(hero, 1, packet[+62])` and `hero+0x848 = packet[+40]` — two different packet offsets
reaching different storage. A current-versus-maximum interpretation is not established;
`+40` remains open. Do not infer a semantic identity from the shared spawn offset.

### Where the remaining six actually stand

All have proven destinations and proven widths. What is missing is a **reader whose base register is
verified to be a `CHero*`/`CRole*`**. The honest next step is per-site verification of the candidate
clusters — slow, roughly 25–35 sites per offset, each needing the base register checked — or
finding another packet/dialog that touches the same offset with strings attached, which is how the
spawn handler produced the lead above.

### The `role+0x978` FDword container: index enum (verified)

`sub_673eac(role, index, value)` is the setter, `CHero_GetPlayerDataByIndex(role, index)` the getter;
both delegate to the obfuscated container at `role+0x978`. The index constants were read straight
out of the `push imm8` preceding each call site:

| Index | Written by | Read by |
|---|---|---|
| `1` | `CMsgUserInfo__Process` `0x764351` (from packet `+62`), `CMsgPlayer__Process` `0x756407`/`0x7564EF`, `CMsgUserAttrib__Process` `0x757902`, `CMsgItem__Process`, `CMsgInteract__Process` | HUD, `CBossEffectMgr_UpdateTrackedBossLifeState`, `CBossEffectMgr_RenderBossLifeOverlay`, `CMyShellDlg__RenderStatusHintPanel` |
| `0x0F` (15) | `CHero_InitializeState` `0x656D56`, `CHero_PerFrameTickAndSubsystemUpdate` `0x65E167` — **client-side only** | HUD, paired with index 1 |

Index 1 is **current life**: the boss-life manager reads it, and every server packet that carries a
health value writes it.

The main HUD renderer reads the two together at `0x4BC433`/`0x4BC43D`:

```
push 0x0F
call CHero_GetSingletonPtr        ; takes no args, so the 0x0F survives
mov  ecx, eax
call CHero_GetPlayerDataByIndex   ; (hero, 15)
push eax
push 1
mov  ecx, edi
call CHero_GetPlayerDataByIndex   ; (hero, 1)
```

**Index 15 is never written by any packet handler.** `CHero_PerFrameTickAndSubsystemUpdate`
recomputes it every frame with an accumulate-and-clamp (`idiv` by 80, `add`, clamp to a ceiling),
which is the shape of a regenerating quantity, not a server-delivered constant.

Consequence for `+40`: this **rules out** "`hero+0x848` is the max-life the server sends", because
the client's own paired value is computed locally and `MsgUserInfo` only ever writes index 1. It
does not establish what `+40` *is*. `+40` stays open — the useful outcome here is a ruled-out
hypothesis and a verified index enum, which the HP/stamina gauge slice will need regardless.

### Verified negative: no singleton-idiom reader exists for any of the six

The displacement scan kept producing candidates that dissolved on inspection (`sub_50D5EC` a
`CDialog` ctor, `sub_66D3C6` based on `hero+0x1EA0`, `sub_469404` a dialog `DoDataExchange` whose
`arg1+0xCE4` is a dialog member). Rather than keep checking them one at a time, the scan was
re-shaped to only accept sites whose **base register is provably the hero singleton**:

1. find every `e8 <rel32>` whose target is `CHero_GetSingletonPtr` (`0x404460`) — **4138 sites**
2. within the following 32 bytes, accept only ModRM with `mod=10, rm=000`, i.e. `[eax+disp32]`,
   where `eax` is still the returned pointer
3. keep those whose `disp32` is one of the six offsets

Result — the complete set, across the whole binary:

| Offset | Verified-base sites |
|---|---|
| `hero+0x85C` | `0x7643EC` |
| `hero+0x844` | `0x764400` |
| `hero+0x848` | `0x764414` |
| `hero+0x8B8` | `0x764847` |
| `hero+0xF34` | `0x7645C5` |
| `hero+0xCE4` | `0x764552` |

Every one is a **write inside `CMsgUserInfo__Process`**. There is not a single read.

Scope of the claim, stated precisely: this proves no code uses the
*fetch-the-singleton-then-access* idiom to read these fields. It does **not** prove no reader
exists — a consumer holding a cached `CHero*`/`CRole*` in a local, a member, or a parameter would
not match, and `CMsgPlayer__Process` demonstrates that `+0x848` at least is genuinely used on
non-hero `CRole` objects through exactly such a pointer.

What it does settle is that the cheap search space is exhausted and the earlier candidate clusters
are worthless. A real reader must be found through a role-typed pointer, not the singleton. The
practical routes left, in order of expected yield:

1. other packet handlers that touch the same offsets on a `CRole*` (the spawn handler already
   yielded the `+0x848` lead this way)
2. `CRole`/`CHero` virtual methods — resolve vtable slots as was done for `+81`, since a virtual
   getter would receive the role as `this`
3. per-site base verification of the raw displacement clusters, which is the slow fallback

At that checkpoint no reader established the gameplay names. The focused reconciliation now
attributes the historical identities and preserves native-only proof boundaries; production
implementation remains unchanged.

### Base-provenance filter: no consumer survives for any of the six

A generic filter beats per-site inspection. A function operating on a role touches the target
offset **and** an already-proven `CRole`/`CHero` offset **through the same base register**. Indexing
every `mod=10` memory access in `.text` (215,635 of them) and requiring a same-register
co-occurrence within ±96 bytes against the proven set
(`0xCC, 0x82C, 0x830, 0x834, 0x838, 0x840, 0x84C, 0x860, 0x864, 0x868, 0x978, 0x9A8, 0x474, 0x4FC,
0x504, 0x508, 0x50C, 0x8C0, 0x8C2, 0x178, 0x184, 0x430, 0x3B4`) cuts **148 raw sites to 11**.

The filter self-checks: it retains every site already known to be genuine — the six `MsgUserInfo`
writes, the spawn write at `0x756525`, and the attrib write at `0x757BFF`.

Of the three sites it surfaced that were not already known, all three are false positives, and each
was confirmed by decompiling:

- `0x4E6FB5` (`+36`) — `sub_4E6EB4` is the "Openhole" dialog renderer. `arg1+0x844` is a `CMyButton`
  member; the `0x864` co-occurrence is `IsWindowVisible(*(arg1+0x864))`, a window handle.
- `0x66CCDC` and `0x66D3C6` (`+32`) — both sit in the accessor block of the **sub-object at
  `hero+0x1EA0`**, not `CHero`. Proven by `CMsgPlayer__Process` `0x75724A`, which calls
  `sub_66C9A3(&hero->pad_000[0x1EA0])`, and by `sub_4DD0E4`, which calls
  `sub_66D3C6(&hero->pad_000[0x1EA0])`. Their `0x868` co-occurrence is that sub-object's field, not
  CHero's PK points.

The historical fixed-window search produced this candidate summary. "Not found" below
describes that search, not a whole-binary no-reader conclusion:

| Offset | Writes | Reads |
|---|---|---|
| `hero+0x85C` | `MsgUserInfo` | Not found by this search |
| `hero+0x844` | `MsgUserInfo` | Not found by this search |
| `hero+0x848` | `MsgUserInfo`, `MsgPlayer` player branch | Not found by this search |
| `hero+0x8B8` | `MsgUserInfo`, `MsgUserAttrib` type `0x17` | Not found by this search |
| `hero+0xF34` | `MsgUserInfo`; constructor zero | Not found by this search |
| `hero+0xCE4` | `MsgUserInfo`; constructor zero | Not found by this search |

**2026-09-17 correction:** the previous "inert" and "retired feature" characterizations were
not established by this evidence and are withdrawn. A live writer plus an incomplete reader
search does not prove retirement. The later historical reconciliation supplies compatibility names without strengthening
this negative search into an exhaustive dead-field proof.

Scope, stated honestly: this is a systematic negative, not a proof. The filter uses a fixed ±96-byte
window, ignores function boundaries, and skips SIB-addressed accesses, so a consumer that loads the
role pointer far from the access, or indexes it, would be missed. Turning this into a proof needs
function-bounded dataflow, not a byte scan.

**Consequence for implementation:** this historical negative search does not authorize
declaring the packet slice complete, naming these fields as inert, or assigning gameplay
semantics. The current attributed historical identities and native-only limitations are recorded
in the focused reconciliation, which supersedes the earlier anonymous-field status.

## 2026-08-16 — OpenConquerPublic's 1006 writer brought onto the verified layout

`50_server/OpenConquerPublic/src/OpenConquer.Protocol/Game/Packets/MsgUserInfo1006.cs` had several
spans marked "reserved" that the client actually loads. Corrections applied (build clean, 189
server tests green):

- **`+91` title id was written as a byte.** The client does `movzx ecx, word [ecx+0x5B]`, so the
  wire field is a `ushort`. The old `WriteByte` + `Reserve(1)` produced identical bytes for ids
  below 256 while silently capping the range. `UserInfoSnapshot.TitleId` widened to `ushort`; the
  domain and the `selected_title` column stay byte-sized for now, which widens implicitly.
- **`+81` and `+87` are now written** — coach EXP-share count (u16) and flower-status tier (u32),
  both closed earlier today.
- **`+74` was labelled a "show name" flag.** Native semantic proof for that label was not found:
  the handler copies it into `hero+0xCE4`, whose consumers remain under investigation. The value `1` was preserved
  because the shipped configuration was smoke-tested working, but the constant was renamed and the
  comment corrected so the label is not repeated as fact.
- The earlier **INERT** labels for +32/+36/+40/+44/+72/+74 were too strong and were removed
  from the legacy writer comments in the 2026-09-17 audit. Their stores are proven; semantic
  closure and a whole-binary dead-field proof are not established.
- The fixed-body padding `Reserve(FixedBodyLength - written)` was replaced by an explicit length
  check. The layout now accounts for every byte, so silent drift would be a bug rather than
  absorbed padding.

**Two offsets were deliberately left unnamed and zeroed**, after their candidate names failed
verification:

| Offset | Width | Destination | Why not named |
|---|---|---|---|
| `+85` | u16 | `hero+0x9A4` | Setter `0x673BA8` is a bare one-liner. Adjacent to the verified coach EXP-share slot at `0x9A8`, but adjacency is not evidence. The pre-existing Binja name `CRole_SetCoachSessionState` is unverified. |
| `+106` | u32 | `hero+0x2E08` | Setter `0x6655DB` is a bare one-liner with no string or label evidence. The pre-existing Binja name `CHero_SetRacePoints` is unverified. |

Both were briefly added to the server under those names and then removed: an inherited Binary Ninja
symbol is not verification. Anything carrying a name that has not been proven from a consumer stays
out of both the client and the server.

Also still unnamed, and left zero: `+97` (u8 digit count) with the `+98`/`+102` u32 pair, which the
client combines into a 64-bit value and formats via `pow(10, digits - 1)` division then `mod 10`.

## MsgItem (Type 1009) — equip/unequip verified 2026-08-29 — class proven by `MsgItem.cpp` assert (CP0.1 2026-11-05); former label `MsgTick` withdrawn

`CMsgItem__Ctor` `0x6EABEB`, `CMsgItem__Process` `0x6EAEB6`. Fixed body of `0x58` bytes with an
optional trailing u32 list: uid `+4`, position `+8`, subtype u16 `+0x0C`, token `+0x10`, list count
`+0x14`, list from `+0x54`.

| Subtype | Direction | Meaning |
|---|---|---|
| `4` | C→S | equip request — `CHeroItem__RequestEquipItemAtPosition` `0x6DB116`, send at `0x6DB493` |
| `5` | S→C | equip apply — `0x6EB31C`; the trailing list names uids to take out of their slots |
| `6` | C→S | unequip request — `CHeroItem__RequestUnequipPosition` `0x6DB8E9`, send at `0x6DBB5D` |
| `6` | S→C | unequip apply — `0x6EB118`; **reads only the position**, ignoring the uid at `+4` |

The equip apply does no automatic clearing and does not return the destination's previous occupant
unless its uid is in the list. The unequip apply is the opposite: for a bow leaving position `4` or
`0x18` it also clears the paired off hand by itself (`0x6EB172`).

Both applies end by sending MsgAction (10010) subtype `0x198` = **408** back to the server — the
client's notice that it has finished applying a change to hero state. It has seven senders in all,
and they are not only equipment (`CMsgMapInfo1110__Process` sends it too), always with zero fields.
It takes no reply: `0x198` appears nowhere in `CMsgAction__Process`'s disassembly, so the client has
no inbound branch for it.

The client's own equip guard — the category-to-position jump table at `0x6DB895`, the bow/shield
conflicts, the dual-wield profession gate at `hero+0x82C`, the learned-magic-10311 requirement for a
shield beside a category 5 weapon, the paired-hand unequip rule, and the 40-slot pack limit at
`0x6DCDD9` — is written up in full in `../Server/equipment.md`.


## Auth string-validation evidence delta — 2026-10-18

See the [native auth string-validation closure](Native-auth-string-validation-2026-10-18.md) for malformed1004/1006 lists, encoding and1006 exceptional paths.
The existing15-byte usable-name rule is a destination-copy rule, not whole-packet
rejection. Zero-fill is bounded: extreme1004 message copies can exceed packet
storage. EntityId0 mutates hero state before the failed EnterMap build/send path.
