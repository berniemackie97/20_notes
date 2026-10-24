# Combat Packets — Magic, Skills, Interact, PK

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## MsgFriend (Type 1019)
**Direction**: Bidirectional
**Dispatch**: ctor `CMsgFriend__ctor` (0x74D66D), parse `CMsgFriend__Parse` (0x74D766), process `CMsgFriend__Process` (0x74D789)
**Size**: 36. Proof pass 2026-09-28: `+0x0C`/`+0x10` semantics, send-site args, entry layouts.

| Off | Type | Field | Proof |
|---|---|---|---|
| +0 | u16 | size 36 | builder 0x74D75B |
| +2 | u16 | type 1019 | builder 0x74D74F |
| +4 | u32 | id | |
| +8 | u8 | subtype 10..19 | switch `*(+8)-10`, table 0x74DDE7 |
| +9 | u8 | online flag (nonzero = online) | `CFriend__CreateNew` 0x709E3B |
| +0x0A | u16 | pad; client writes 0 | ctor memset 0x6DF290 |
| +0x0C | u32 | **peerage (nobility) rank** | see below |
| +0x10 | u32 | **peerage sex** (1 male, 2 female) | see below |
| +0x14 | char[16] | name, NUL forced +0x23 | builder 0x74D734/0x74D743 |

### `+0x0C` / `+0x10` proof
- Stored: `CFriend__CreateNew` (0x709DA3) -> CFriend `+0x44`/`+0x48`; `CEnemy__CreateNew` (0x6FE6A7) -> CEnemy `+0x40`/`+0x44`.
- Overwritten by presence: 12/13 -> `+0x44`=pkt+0xC, `+0x48`=pkt+0x10 (0x74D985/0x74D996, 0x74DA2D/0x74DA3E); 16/17 -> CEnemy `+0x40`/`+0x44` (0x74DBDF/0x74DBF0, 0x74DC87/0x74DC98).
- Only readers (all consumers of CFriend/CEnemy scanned): `DlgFriendInfo_RefreshFromFriendEntry` 0x491A17 and `DlgEnemyInfo_RefreshFromEnemyEntry` 0x45DC52.
  - `CPeerageMgr_GetPeerageAssetName(out, rank=+0x44, sex=+0x48, 2)` (0x491C01) -> Icon32 image on ctrl `+0x140`, shown only if non-empty.
  - `CPeerageMgr_GetPeerageName(rank, sex)` (0x491C74) -> dlg `+0xF8`.
- `CPeerageMgr_GetPeerageName` (0x6AB500): key = `sex + rank*10` (0x6AB50D/0x6AB512); map loaded by `CPeerageMgr_LoadPeerageIni` (0x6AAD95) from `ini/peerage.ini`, section header `sscanf "[%d]"`. Miss -> "" (0x9560DC, bss).
- Same key built for live roles: `(CRole_GetPeerageRank = role+0xA2C, role+0x178)` at 0x42644E/0x426446, 0x73A800/0x73A7E7, 0x6F1940/0x6F1931.
  role+0x178 = `(lookface/1000)%10` (1006 +10 / spawn). Friend rows get no client derivation: server supplies `+0x10`.

### Value domains (shipped `ini/peerage.ini`)
| key | rank | sex | Name |
|---|---|---|---|
| 1 / 2 | 0 | 1 / 2 | Commoner / Commoner |
| 11 / 12 | 1 | 1 / 2 | Knight / Lady |
| 31 / 32 | 3 | 1 / 2 | Baron / Baroness |
| 51 / 52 | 5 | 1 / 2 | Earl / Countess |
| 71 / 72 | 7 | 1 / 2 | Duke / Duchess |
| 91 / 92 | 9 | 1 / 2 | Prince / Princess |
| 121 / 122 | 12 | 1 / 2 | King / Queen |

- rank 0 = Commoner (icon `nob_White32` shown if sex 1/2).
- sex 0 (or any rank/sex not in table) = key miss -> no peerage icon, empty title. Nothing else reads the fields.
- CFriend/CEnemy ctor default 0xFFFFFFFF for both; always overwritten by the creating packet.
- Sex source for a server: target lookface `(look/1000)%10` (same digit as role+0x178). Long 6270 `Gender`: male body -> 1, else 2, offline -> 0.

### Inbound subtypes
| Sub | Case | Effect |
|---|---|---|
| 10 | 0 | chat GameDataSet 0x18705 (name) ch 0x7D5; stores nothing |
| 11 | 1 | `CFriend__CreateNew` + `CHeroFriendAndEnemyMgr__AddFriend` + chat 0x18706(hero name, entry name) |
| 12/13 | 2/3 | FindFriendById(+4); online=1/0; overwrite +0xC/+0x10 fields; post 0x3FA, 0x48F(12/13); chat 0x18707/0x18708 |
| 14 | 4 | `CHeroFriendAndEnemyMgr__RemoveFriend(+4)` |
| 15 | 5 | as 11 without chat. No duplicate-id check (AddFriend push_back) |
| 16/17 | 6/7 | FindEnemyById; online=1/0; overwrite fields; post 0x439, 0x490(16/17); chat 0x18730/0x18731 |
| 18 | 8 | `CHeroFriendAndEnemyMgr__RemoveEnemy(+4, notify=0)` |
| 19 | 9 | FindEnemyById hit -> case skipped entirely (0x74DD33, no update); miss -> `CEnemy__CreateNew` + `AddEnemy` + post 0x439 |

No ladder/state gate in the handler. Bulk enemy alternative: MsgEnemyList 1041 (`05_guild_packets.md`).

### Client send sites (sole callers of `CMsgFriend__BuildSubtypeEntityIdFlagName16` 0x74D6D3)
Builder `(u8 sub, u32 id, u8 flag, char* name)`; name NULL -> CHECK (MsgFriend.cpp line 0x22), return 0. Never writes +0xA/+0xC/+0x10 -> 0.

| Site | Fn | Sub | id | flag (+9) | name |
|---|---|---|---|---|---|
| 0x69E6E7 | `RequestAddFriend` 0x69E54C | 10 | target role id (arg) | 0 (ebx, 0x69E577) | resolved `CRole+0x14C` |
| 0x69E7E2 | `RequestRemoveFriend` 0x69E739 | 14 | friend id | 0 (ebx, 0x69E75F) | `CFriend+0x08` |
| 0x69E0C5 | `RemoveEnemy` 0x69E005 (notify!=0) | 18 | enemy id | **1** (push 1, 0x69E0C0) | `CEnemy+0x08` |

- 10 gates: `CDataMigrationSubject` op 0x18; target must resolve in `g_objPlayerSet` (else silent 0); count < `GetMaxFriendCount` (else 0x186C9); not already friend (else 0x186CA). Callers: `CMyShellDlg_OnLButtonDown` 0x5B0D0B (role `+0xCC`), `DispatchCommandCode` case 0x53 0x5B2B93 (mgr `+0x10`).
- 14 gates: op 0x19; id!=0; friend exists (else 0x186CB). No local removal. Callers: `DlgFriendRemoveConfirm_Accept` 0x491E85, `OnLButtonDown` 0x5B0D25.
- 18: caller `DlgEnemyRemoveConfirm_Accept` 0x45DFC6 (notify=1). Local removal 0x69E11E + post 0x439 after send.
- Flag 1 on 18 is a literal; client never reads its own outbound flag.

### Entry objects
| | CFriend (0x4C, vtbl 0x86BC28) | CEnemy (0x48, vtbl 0x86BAC4) |
|---|---|---|
| ctor | 0x709CA8 | 0x6FE5AF |
| id | +0x04 | +0x04 |
| name (CharVector) | +0x08 | +0x08 |
| online | +0x14 | +0x14 |
| MsgFriendInfo 2033 fields | +0x1C..+0x34 | +0x18..+0x30 |
| mate (CharVector) | +0x38 | +0x34 |
| peerage rank (pkt +0xC) | +0x44 | +0x40 |
| peerage sex (pkt +0x10) | +0x48 | +0x44 |

Manager `CHeroFriendAndEnemyMgr` (singleton 0x956004, 0x78 B): friends `deque<shared_ptr<CFriend>>` +0x24, enemies +0x50. Info queries: `RequestFriendInfo` MsgAction 0x94, `RequestEnemyInfo` MsgAction 0x7B -> reply 2033.

Unresolved: literal text of GameDataSet strings 0x18705..0x18708, 0x18730/0x18731, 0x186C9..0x186CB; writer of mgr `+0x10` (case 0x53 source).

## MsgMagicEffect (Type 1035)
**Direction**: S→C
**Purpose**: Magic‑effect list update with optional `"ItemTimeOut"` notifications (verified by `CHero__Find/RemoveMagicEffectEntry_*` and `ItemTimeOut` string usage).
**Dispatch**: Create `CMsgMagicEffect__Create` (0x75DB5B), parse `CMsgMagicEffect__Parse` (0x75DBC1), process `CMsgMagicEffect__Process` (0x75DBE4)

**Parse**: `CMsgMagicEffect__Parse` — standard header validation, then `type == 1035`.

**Verified field usage in `CMsgMagicEffect__Process`** (offsets relative to packet start):
- `+4` (u32) is a mode flag used to select between paired handler paths (`CHero__FindMagicEffectEntry_List0`/`CHero__RemoveMagicEffectEntry_List0` vs `CHero__FindMagicEffectEntry_List1`/`CHero__RemoveMagicEffectEntry_List1`) and also selects the final UI notify (`PostMainWndMsg_0x464(0x4CC)` vs `PostMainWndMsg_0x464(0x4CD)`).
- `+8` (u32) is a count of list entries.
- Entries are a fixed stride of `0x0C` bytes starting at `+12`:
  - `entry+0` (u32) is passed to `CHero__FindMagicEffectEntry_List0`/`CHero__FindMagicEffectEntry_List1` and later to `CHero__RemoveMagicEffectEntry_List0`/`CHero__RemoveMagicEffectEntry_List1`.
  - `entry+4` (u32) is copied into `*(item+20)` when the entry update flag is nonzero.
  - `entry+8` (u8) is an update flag: if `0`, the handler runs the "timeout" path (may show `"ItemTimeOut"` UI); if nonzero, it updates `*(item+20)` with `entry+4`.
  - `entry+9` (u8) is checked before building the `"ItemTimeOut"` message (uses `CItem__GetEffectiveId` and `CStringManager__GetStr` to format the notification).

## Type 1036 — experience-cap packet (class name `CMsgMagicInfo` is a MISLABEL)
**Direction**: S→C
**Purpose**: Updates hero fields `0xF54/0xF58` and shows "max online/battle exp" confirmation dialogs.
**Naming warning**: the handler at 0x7165F5 has nothing to do with magic — it reads a mode byte and
drives `STR_MAX_ONLINE_EXP` / `STR_MAX_BATTLE_EXP` dialogs. `CMsgMagicInfo` in the CQ2 ancestor is a
different message carrying `{idOwner, dwExp, usType, usLevel}` and calling `g_objHero.AddMagic`.
Do not use this entry as the magic-set packet for ladder rung `0x4E`; that packet is not yet
identified. Verified: `CMsgMagicInfo__Parse` (0x7165D2) checks `type == 0x40C` (1036).
**Dispatch**: Create `CMsgMagicInfo__Create` (0x716545), parse `CMsgMagicInfo__Parse` (0x7165D2), process `CMsgMagicInfo__Process` (0x7165F5)

**Parse**: `CMsgMagicInfo__Parse` — standard header validation, then `type == 1036`.

**Verified field usage in `CMsgMagicInfo__Process`** (offsets relative to packet start):
- `+4` (u8) is a mode selector:
  - `0`: uses `+12` (u32) with `CHero__SetDword_0xF58`, then `+8` (u32) with `CHero__SetDword_0xF54`, then triggers `PostMainWndMsg_0x464(0x49B, 0)`.
  - `3`: shows a confirmation message using string `"STR_MAX_ONLINE_EX"` (`CMessageBoxMgr__ShowCommandMessage` with id `3456`).
  - `4`: shows a confirmation message using string `"STR_MAX_BATTLE_EX"` (`CMessageBoxMgr__ShowCommandMessage` with id `3456`).

## MsgWeapSkill (Type 1024)
**Direction**: S→C
**Purpose**: If `+4 == 0`, builds and sends a type‑10010 action packet (`action=408`, `data=0`) and posts UI `0xDE8`.
**Dispatch**: Create `CMsgWeapSkill__Create` (0x740951), parse `CMsgWeapSkill__Parse` (0x7409B7), process `CMsgWeapSkill__Process` (0x740A37)

**Parse**: `CMsgWeapSkill__Parse` — standard header validation, then `type == 1024`.

**Verified field usage in `CMsgWeapSkill__Process`** (offsets relative to packet start):
- `+4` (u8) is checked; when `0`, the handler builds a type‑`10010` packet via `CMsgAction__BuildType10010(408, 0)` and sends it via `CNetMsg__Send`, then triggers `PostMainWndMsg_0x464(0xDE8, 0)`.

## MsgWeaponSkill (Type 1025)
**Direction**: S→C
**Purpose**: Full snapshot of one weapon proficiency row. Sent one packet per row in response to the login-ladder rung `0x4D actionGetWeaponSkillSet`.
**Dispatch**: Create `CMsgWeaponSkill1025__Create` (0x761FD0), parse `CMsgWeaponSkill1025__Parse` (0x762036), process `CMsgWeaponSkillUpdate1025__Process` (0x762059)
**Class name**: the ancestor source calls this `CMsgWeaponSkill` (`40_tools/eosource/soul-code/3drole/Network/MsgWeaponSkill.h`). The earlier note here labelled it `CMsgTeamMember`; that name belongs to **1026**, whose handler at 0x761AB1 carries the `MsgTeamMember.cpp` CHECK string.

**Parse**: Parse — standard header validation, then `type == 1025`.

**Verified wire layout** (offsets relative to packet start):

| Offset | Size | Field |
|---|---|---|
| `+0x00` | u16 | size |
| `+0x02` | u16 | type (1025) |
| `+0x04` | u32 | `unType` — 3-digit weapon skill type (e.g. 410 Blade) |
| `+0x08` | u16 | `usLevel` — zero-extended to u32 by the handler |
| `+0x0C` | u32 | `unExp` |
| `+0x10` | u32 | `unNextLevelExpRequired` — **added in 5517** |

Minimum body size is therefore `0x14` bytes.

**Verified processing flow**:
- Calls `CHero__AddNewWeaponSkill(hero, +4, +8, +0xC, +0x10)` (0x71CF85), then `PostMainWndMsg_0x464(0x3FF, 0)` to refresh `CDlgQuery_Weapon`.

### The `+0x10` field is the next-level experience requirement
Proven in `CDlgQuery_Weapon__Render` (0x50ADBE, `MyShell\DlgQuery_Weapon.cpp`). For the
selected skill the detail panel does:

```
0x50af85  cmp [skill+8], 0x14        ; level == 20 -> max level, show GetStr(0x2724)
0x50afc9  Folded_GetDword_0x10       ; read skill+0x10
0x50afd1  cmp eax, 1 / jae           ; denominator clamped to >= 1
0x50afee  mov eax, [skill+0xC]       ; m_dwExp
0x50b007  fild / fmul 100.0f (0x852088) / fidiv by skill+0x10
0x50b023  GetStr(0x2723) -> _snprintf
```

so the displayed proficiency percentage is `exp * 100.0f / nextLevelExpRequired`, and the
maximum weapon skill level in this build is **20**.

Corroborating: the string `ini/WeaponSkillLevelExp.ini` does **not** exist anywhere in
`Conquer.exe` 5517. The ancestor's `CWeaponSkillData::Create` loaded that file into a
level→required-exp deque backing `CWeaponSkill::GetNextLevelExpRequired()`; the 5517
`CWeaponSkillData__Create` (0x71C87A) loads only `ini/WeaponSkillName.ini`. The table moved
to the server, which is why the requirement now rides on the wire. The `.ini` still ships in
`00_clean/clean/5517/ini/` as a stale leftover — do not treat it as live client data.

### CWeaponSkill object layout (0x94 bytes, vtable `g_CWeaponSkill_Vtbl` 0x86C240)

| Offset | Type | Field |
|---|---|---|
| `+0x00` | ptr | vftable |
| `+0x04` | int | `m_nWeaponSkillType` |
| `+0x08` | DWORD | `m_dwLevel` |
| `+0x0C` | DWORD | `m_dwExp` |
| `+0x10` | DWORD | `m_dwNextLevelExpRequired` — **added in 5517** |
| `+0x14` | char[0x80] | `m_szDescribe` (`_MAX_TITLESIZE` = 128) |

`CWeaponSkill__Ctor` (0x71C6E2) zeroes `+4/+8/+0xC/+0x10` individually then
`memset(+0x14, 0, 0x80)`. In the ancestor header `m_szDescribe` follows `m_dwExp` directly,
which is how the inserted DWORD is localised.

### Routing: the client derives the category from the type
`CHero__AddNewWeaponSkill` (0x71CF85) picks the destination deque by integer division:

| `type / 100` | deque |
|---|---|
| 4 or 6 | `hero+0x1180` — `m_setSingleHandWeaponSkill` |
| 5 | `hero+0x11A8` — `m_setDoubleHandWeaponSkill` |
| anything else | `hero+0x11D0` — `m_setOtherWeaponSkill` |

A server must send the **real 3-digit type**; renumbering or pre-categorising silently
misfiles rows into the wrong tab. The ancestor routed only `4` to the single-hand deque —
folding `6xx` in with it is a 5517 change.

`CHero__AddNewWeaponSkillToList` (0x71D25D) then scans that deque for `entry+4 == type`.
On a hit it overwrites all four fields and looks up `RoleDataQuery()->vtbl[0x94](type * 100 + level)`;
a non-empty record drives the level-up effect and `DXPlaySound`. On a miss it allocates
`operator new(0x94)`, constructs, writes the four fields and `push_back`s — so the level-up
feedback fires only on updates, never on the initial snapshot.

## MsgAllot (Type 1023)
**Direction**: C→S
**Purpose**: Team/party management (join/invite/quit/dismiss/disband/recruit toggles) plus a family battle effect share UI flow (subtype `0`). Evidence: string IDs `10002`/`10003`, `100107–100113`, `100147/100148`, and `STR_FAMILY_BATTLEEFFECT_SHARE_NONE`.
**Dispatch**: Create `CMsgAllot__Create` (0x72AC9A), parse `CMsgAllot__Parse` (0x72AD00), process `CMsgAllot__Process` (0x72AD85)

**Verified parse behavior**:
- `CMsgAllot__Parse` validates `Src`/`Size` using `CNetMsg__GetSize` and `CNetMsg__GetType` (type check for 1023), then `memcpy`s the packet into `this+4`.

**Verified field usage in `CMsgAllot__Process`** (offsets relative to packet start):
- `+4` (u16) is used as a mode/subtype selector (large switch).
- `+8` (u32) is passed to multiple handlers (ID used in lookups/queries/UI text flow).

**Subtype switch (`packet+0x04` as u16)**:
- `0`: no packet fields referenced; clears team state (`CHero__TeamClear`), sets `CHero__SetDword_0x448(0)`, builds a local entry via `CTeamMemberEntry__Create`, clears map `CHero__ClearMap_0x1240`, and updates StatusTips (`StatusTips__GetSingleton`/`StatusTips__AddOrUpdateEntry`) with `STR_FAMILY_BATTLEEFFECT_SHARE_NONE`; ends with `PostMainWndMsg_0x464(0x3FC, 0)` and `PostMainWndMsg_0x464(0x491, 0)` UI refresh calls.
- `1`: uses `+0x08`; passes it to `CHero__TeamCacheTargetFromEntityId`. If that returns nonzero, builds a confirmation UI flow (`CMessageBoxMgr__ShowCommandMessageWithButton` with id `3460`) using strings `10001`/`10002`.
- `2`: uses `+0x08`; compares against singleton `+0xCC`. If equal, shows message `100107` and triggers a UI close path (`PostMainWndMsg_0x464` with constants). Else calls `CHero__TeamRemoveMemberById` and `CHero__TeamFindMemberById` with `+0x08`, builds a string using `100108`, then posts it.
- `3`: default path (returns nonzero; no handler observed).
- `4`: uses `+0x08`; passes it to `CHero__TeamCacheTargetFromEntityId` and then runs a confirmation UI flow (`CMessageBoxMgr__ShowCommandMessageWithButton` with id `3461`) using strings `10001`/`10003`.
- `5`: default path (returns nonzero; no handler observed).
- `6`: no packet fields referenced; shows message `100109` and triggers a UI close path (`PostMainWndMsg_0x464` with constants).
- `7`: uses `+0x08`; compares against singleton `+0xCC`. If equal, shows message `100110` and triggers UI close path. Else calls `CHero__TeamFindMemberById` and `CHero__TeamRemoveMemberById` with `+0x08`, builds a string using `100111`, then posts it.
- `8`: no packet fields referenced; calls `CHero__SetTeamRecruitingDisabled` and shows message `100112`, then triggers `PostMainWndMsg_0x464(0x3FC, 0)`.
- `9`: no packet fields referenced; calls `CHero__SetTeamRecruitingEnabled` and shows message `100113`, then triggers `PostMainWndMsg_0x464(0x3FC, 0)`.
- `10–13`: default path (returns nonzero; no handler observed).
- `14`: uses `+0x08`; calls `CHero__IsTeamPaneActive`, then routes to `CHero__SetTimestampMap_0x1240(+0x08)` if true or `CHero__SetTimestampMap_0x124C(+0x08)` if false.
- `15`: uses `+0x08`; calls `CHero__SetDword_0x444(+0x08)` then triggers `PostMainWndMsg_0x464(0x3FC, 0)`.

## MsgMagicEffectSimple (Type 1103)
**Direction**: S→C
**Purpose**: Creates/updates a magic entry for `(magic_id, magic_level, caster_id)` and triggers a UI refresh.
**Dispatch**: Create `CMsgMagicEffectSimple__Create` (0x760ABC), parse `CMsgMagicEffectSimple__Parse` (0x760B22), process `CMsgMagicEffectSimple__Process` (0x760B45)

**Parse**: `CMsgMagicEffectSimple__Parse` — standard header validation, then `type == 1103`.

**Verified field usage in `CMsgMagicEffectSimple__Process`** (offsets relative to packet start):
- `+4` (u32) → `caster_id`
- `+8` (u16) → `magic_id`
- `+10` (u16) → `magic_level`

**This is the magic-set row packet for ladder rung `0x4E` (`actionGetMagicSet`).** Established by
xrefs on `CHero__AddOrUpdateMagic` (0x6F5546), the only function that installs a magic into the
hero: its only two callers are this handler and one MsgAction subtype, so no other packet can
deliver a magic row. Minimum packet span is `0x0C` bytes — the handler reads `+4`, `+8`, `+0xA`
and nothing else.

**No experience field.** 5517 split the ancestor's one-shot `CMsgMagicInfo`
`{idOwner, dwExp, usType, usLevel}` into this identity/level packet plus `MsgFlushExp` (1104)
`ucAction 1` for experience. A server hydrating the magic set sends one 1103 per row and, where a
magic has accumulated experience, a following 1104.

**Verified processing flow**:
- Calls `CHero__AddOrUpdateMagic(magic_id, magic_level, caster_id)` (0x6F5546):
  - Scans the hero magic list for an entry whose embedded magic data record matches `magic_id`.
  - If found, calls `CMagic__SetLevelAndCaster(magic_level, caster_id)` on that entry.
  - If not found, constructs a new `CMagic` via `CMagic__CreateFromMagicIdLevelCaster(magic_id, magic_level, caster_id)` and appends it to the list.
  - If magic data provides a sound record, plays it via `DXPlaySound`.
- Posts `PostMainWndMsg_0x464(0x406, 0)`.

## MsgFlushExp (Type 1104)
**Direction**: S→C
**Purpose**: Pushes a new experience value for one weapon skill or one magic skill without resending the whole row.
**Dispatch**: ctor `CMsgFlushExp1104__ctor` (0x76179A, sole xref dispatcher 0x6DF8E2), parse `CMsgFlushExp1104__Parse` (0x761800), process `CMsgFlushExp1104__Process` (0x761823). No builder in vtable 0x86D570 -> client never sends 1104.
**Class name**: `CMsgFlushExp` in the ancestor source (`40_tools/eosource/soul-code/3drole/Network/MsgFlushExp.h`). The earlier note here called it `MsgMagicEffectUpdate` and read `+4`/`+8` as opaque `value_a`/`value_b`; that reading is superseded.

**Parse**: standard header validation, then `type == 1104` (`0x450`).

**Verified wire layout** (offsets relative to packet start):

| Offset | Size | Field |
|---|---|---|
| `+0x00` | u16 | size |
| `+0x02` | u16 | type (1104) |
| `+0x04` | u32 | `dwExp` |
| `+0x08` | u32 | `dwNextLevelExpRequired` — **added in 5517** |
| `+0x0C` | u16 | `usType` |
| `+0x0E` | u8 | `ucAction` |
| `+0x0F` | u8 | never read — tail pad; any value accepted, send 0 |

**Length (verified 2026-10-04):** client defines **no fixed length**.
- Parse 0x761800 = `CNetMsg__ValidateHeaderAndCopy` + `type == 0x450`; dispatcher 0x6DF3B5 checks only
  buf != NULL and size <= 0x400. Rule: size word == frame bytes, excluding the 8-byte `TQServer` seal.
- Process reads only `+0xE` (0x76183B), `+0xC` (0x76188E/0x7618F7/0x761964/0x76199B), `+4`
  (0x761897/0x761900/0x76196D/0x7619BC), `+8` (0x7619CB). Highest byte read `+0xE`.
- Minimum span **15**. Shorter frame: missing fields read 0 (ResetPacketBuffer memset), so ucAction
  falls to 0 = weapon path.
- **Send 16** (wire 16 + 8 seal = 24): natural struct size, 15 data + 1 tail pad, matches ancestor
  server `m_unMsgSize = sizeof(MSG_Info)` (fight-master `MsgFlushExp.cpp`, no `#pragma pack`).
  Convention, not client-enforced; 15 behaves identically.
- Fox / Albetros emit the ancestor 12-byte form (`+8` type, `+0xA` action): native 5517 reads
  `usType`/`ucAction` past that frame as 0 -> incompatible.

The ancestor's `MSG_Info` has `dwExp`/`usType`/`ucAction` at `+4`/`+8`/`+0xA`. 5517 inserted the
u32 at `+8`, which is exactly why `usType` and `ucAction` sit at `+0xC` and `+0xE` here — the same
insertion that added `CWeaponSkill+0x10`.

**Verified processing flow** (`0x76183F` reads the action byte; `0x761848 dec eax / jne` means every
value other than 0 and 1 falls straight through with no work):
- `ucAction == 0` — `MSGFLUSHEXP_WEAPONSKILL`: `CHero__GetWeaponSkillByType(usType)` (0x71D415);
  on a hit writes `skill+0xC = dwExp` (0x7619BF) and `skill+0x10 = dwNextLevelExpRequired` (0x7619CE),
  then `PostMainWndMsg_0x464(0x3FF, 0)`.
- `ucAction == 1` — `MSGFLUSHEXP_MAGIC`: runs three filtered passes in sequence
  (counts `CHero__GetMagicAmount` 0x6F573C / `CHero__GetTeamMagicAmount` 0x6F77D9 /
  `CHero__GetXpSkillAmount` 0x6F7948; elements 0x6F57CE / 0x6F786C / 0x6F79DB). Each pass
  matches `GetMagicDataRecord(entry)->+0x40 == usType` and calls `CMagic__SetExp(entry, dwExp)`
  (0x6B0AF5, `entry+0x8 = m_dwExp`). This mirrors the ancestor's single `MSGFLUSHEXP_MAGIC` case,
  which covered magic, team magic and xp skill together.
  **These are not three containers.** All three counters read the same deque at
  `hero+0x1208 .. hero+0x120C` (8-byte shared_ptr elements, count = `(end - begin) >> 3`) and
  differ only in the constant they compare `CMagic__GetEffectParam(entry, 0x19)` against —
  `0` magic, `1` team magic, `2` xp skill, with `3` kongfu in the ancestor and no 5517 counter
  found for it. Contrast the weapon skills, which genuinely are three separate deques.
- The magic path never reads `+8`: only weapon skills carry a next-level requirement.

## MsgMagicEffectEx (Type 1105)
**Direction**: S→C
**Purpose**: Magic/skill effect execution packet (drives MagicEffect.ini visuals, per‑target effects, and hero timers).
**Dispatch**: Create `CMsgMagicEffectEx__Create` (0x760B79), parse `CMsgMagicEffectEx__Parse` (0x760BDF), process `CMsgMagicEffectEx__Process` (0x760C02)

**Parse**: `CMsgMagicEffectEx__Parse` — standard header validation, then `type == 1105`.

**Verified field usage in `CMsgMagicEffectEx__Process`** (offsets relative to packet start):
- `+4` (u32) `caster_id`: compared to local hero ID and used to find the caster entity via `EntityManager__FindEntityById`.
- `+8` (u32) `target_or_pos`:
  - read as `u16 x = *(+8)` and `u16 y = *(+10)` for position‑based effects and sound placement,
  - also treated as a target entity ID (`v116`), unless overridden below.
- `+12` (u16) `magic_id`: drives MagicEffect.ini lookups and is compared against constants `{1025, 1110, 15000, 6001, 6002, 6004, 6010, 7011, 7013, 7014, 7015, 10313}`.
- `+14` (u16) `magic_level`: used in MagicEffect.ini lookups and hero timer updates.
- `+16` (u8) `target_count`: number of 32‑byte entries starting at `+20`.
- `+20` (target entries): each entry is 32 bytes and passed to the effect system.

**Target entry layout (32 bytes, base = `+20 + i*32`)**:
- `+0` (u32) `target_id`: used for `EntityManager__FindEntityById` in multiple branches and as the fallback target ID.
- `+8` (u32) `flag`: if nonzero and `magic_id == 6001` → `CRole__SetBitFlag_0x70(61)`; if nonzero and `magic_id == 6002` → `CRole__SetBitFlag_0x70(94)`.
- `+20` (u32) `dir_index`: direction index (0–7) used with `g_DirectionDeltaX`/`g_DirectionDeltaY` for offset calculations.
- `+24` (u32) `dir_dist`: distance multiplier for the direction offsets above.
- Remaining bytes are passed through to the effect system unchanged via `CIMagicEffect__AppendTargetList`.

**Hero‑side timer updates (only if `caster_id == local hero`)**:
- `CHero__MagicEffect_SetTimer_Type13_19(magic_id, magic_level)`:
  - If `Load_MagicEffect_Ini(magic_id, magic_level, 13) == 19`, sets hero fields `+1179` = `timeGetTime()` and `+1180` = `1000 * magic_data[4]`.
- `CHero__MagicEffect_SetTimer_Type14_27(magic_id, magic_level)`:
  - If `Load_MagicEffect_Ini(magic_id, magic_level, 14) == 27`, sets hero fields `+1177` = `timeGetTime()` and `+1178` = `1000 * magic_data[4]`.
- `CHero__MagicEffect_SetTimer_Type14_8(magic_id, magic_level)`:
  - If `Load_MagicEffect_Ini(magic_id, magic_level, 14) == 8`, sets hero fields `+1182` = `timeGetTime()` and `+1183` = `1000 * magic_data[4]`.
- `CHero__MagicEffect_RecordCastTime(magic_id)`:
  - If `CGameMap__IsState_1039` (0x62084B) returns false, records `timeGetTime()` in the hero map at `+1160` for this `magic_id`.

**Special cases / effect routing**:
- If `magic_id == 15000`: loops each target entry, builds an action struct (`type=43`) using `dir_index`/`dir_dist`, and dispatches it to the target via vtable+128. For the local hero, it also computes tile offsets using `g_DirectionDeltaX/53C` and updates map info via `CHero__UpdateMapInfoFromTiles` (0x65CAF3).
- For general processing, magic data is loaded via `CMagicDataSet__QueryByMagicIdLevel` (0x69CDFB) and `Load_MagicEffect_Ini`. If the target entity is missing, and `Load_MagicEffect_Ini(..., 4) != 3`, a random target from the list is selected as the target entity.
- `magic_id == 7013`: spawns effect `"XidagBafi"` at `(x, y)` via `CGameMap__CalcScreenPosFromTile`.
- `magic_id == 7014`: spawns effect `"XidagF903"` at `(x, y)` via `CGameMap__CalcScreenPosFromTile`.
- `magic_id == 7015`: if the target entity exists, uses its tile position and spawns effect `"XidagDa"`.
- `magic_id == 10313` and the local hero is the target: calls `FlagWithTimestamp__Set(1)` and updates map info from `(x, y)`.
- If `Load_MagicEffect_Ini(..., 13) == 49` and the local hero is the target: calls `FlagWithTimestamp__Set(1)` and updates map info from `(x, y)`.

**Final dispatch**:
- After the above, the handler calls `CMagicEffect__ProcessByEffectType(caster_id, magic_id, magic_level, target_count, target_entries, target_id, x, y)` to instantiate the MagicEffect.ini‑defined effect class and feed it the 32‑byte target list.

## MsgPKStatistic (Type 1081)
**Direction**: S→C
**Purpose**: PK‑statistic / anti‑cheat warning (verified by `CHEATING_PROGRAM_TIP` string usage).
**Dispatch**: Create `CMsgPKStatistic__Create` (0x75D90E), process `CMsgPKStatistic__Process` (0x75D9ED)

**Verified field usage in `CMsgPKStatistic__Process`** (offsets relative to packet start):
- `+4` (u32) is compared against the local hero entity ID (singleton offset `+204`).
- If equal, it reads string‑list entry index `0` (via `MsgStringList__GetEntry`) and shows message `CHEATING_PROGRAM_TIP`.

## Type 1115 — moved

Not a PK-elite packet. It is the account kick notice `CMsgKickoutNotice`: see
[13_connection_lifecycle](13_connection_lifecycle.md#kick-notice-1115-cmsgkickoutnotice).

## MsgBattleEffectiveness (Type 1111)
**Direction**: S→C
**Purpose**: Updates the hero bulletin payload from a string-list triplet format when subtype `3` is received.
**Dispatch**: Create `CMsgBattleEffectiveness__Create` (0x75ED21), parse `CMsgBattleEffectiveness__Parse` (0x75EDDD), process `CMsgBattleEffectiveness__Process` (0x75EE72)

**Parse**: `CMsgBattleEffectiveness__Parse` — standard header validation, then `type == 1111`.

**Verified field usage in `CMsgBattleEffectiveness__Process`** (offsets relative to packet start):
- `+4` (u16) `pair_a` (passed to bulletin loader).
- `+6` (u16) `pair_b` (passed to bulletin loader).
- `+8` (u8) `subtype` (must be `3` for processing).
- `+9` (MsgStringList payload) list consumed by bulletin loader in triplets.

**Verified processing flow**:
- If `subtype != 3`: handler returns without client-side state changes.
- If `subtype == 3`:
  - Resolves local hero singleton (`s__GetSingletonPtr_404460`).
  - Calls `CBulletin__SetPairAndLoadTripletEntries_Post428(pair_a, pair_b, msg_string_list)` on bulletin object at `CHero + 0x2A94`.

**Verified behavior inside `CBulletin__SetPairAndLoadTripletEntries_Post428`**:
- Clears existing bulletin entry objects/list.
- Stores `pair_a` and `pair_b` into bulletin fields.
- Computes `group_count = MsgStringList__GetCount(list) / 3` and processes each triplet:
  - entry `0`: copied into first bulletin text field (buffer len `0x10`).
  - entry `1`: copied into second bulletin text field (buffer len `0x40`).
  - entry `2`: copied with len `0x10`, reformatted into a dashed token string from five 2-byte segments, then stored as the third bulletin text field.
- Posts `PostMainWndMsg_0x464(0x428, 0)` after rebuilding the list.
