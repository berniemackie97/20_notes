# System Packets — Tick, Achievements, Titles, Missions, SubPro, Cross-Server
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Network\

---

## MsgTick (Type 1009)
**Direction**: Bidirectional (heartbeat/keepalive)
**Dispatch**: Create `CMsgTick__Create` (0x6EABEB), parse `CMsgTick__Parse` (0x6EAE56), process `CMsgTick__Process` (0x6EAEB6)
**Parse**: `CMsgTick__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1009`.

**Verified field usage in `CMsgTick__Process`** (offsets relative to packet start):
- `+4` (u32) `param_a` (commonly item UID, tracked-position key, entity ID, or lParam payload depending on subtype)
- `+8` (u32) `param_b` (commonly tracked-position key, state ID, or lParam payload depending on subtype)
- `+12` (u16) `subtype` (main switch key)
- `+16` (u32) `param_c` (used by subtype `27` as a timestamp baseline)
- `+20` (u32) `count_or_value` (count for list-driven subtypes, or value payload)
- `+24` (u32) additional payload (used by subtype `32`)
- `+28` (u8) optional flag byte (used by outbound builders)
- `+84` (u32 array) variable dword list region (`count_or_value` entries for list-based subtypes)

**Verified subtype handling in `CMsgTick__Process`** (`subtype = *(u16*)(packet+12)`):
- `3`: removes item by UID (`+4`) and posts `PostMainWndMsg_0x464(0x3EB,0)` and `PostMainWndMsg_0x464(0x4BA,+4)`. This is the native remove-item packet path; `MsgItem (1008)` action `3` is not deletion.
- `5`: inventory/equipment reroute update. Native looks up an inventory-only item by UID `+4`, removes it from the hero item tables, optionally iterates `count_or_value` dwords from `+84` as item UIDs routed through `CHeroItem__FindTrackedPositionByItemUid`, then tracks the moved item at tracked position `+8`. After the item-table mutation it posts `0x3EB/0x3FB/0x445/0x446`, optional `0x4F6` and `0xDF4`, then sends `CMsgAction` type `10010`.
- `6`: tracked-position sync/update path keyed by tracked position `+8`. Native gets the tracked item directly through `CHeroItem__GetTrackedItemRefByPosition(+8)`. If that item is a two-handed weapon and `+8` is `4` or `0x18`, it also refreshes the paired tracked position (`5` or `0x19`) first. It then re-tracks the current item at `+8`, refreshes derived equipment state, posts `0x3EB/0x3FB/0x445/0x446`, optional `0x4F9`, and sends `CMsgAction` type `10010`.
- `9`: writes `+8` via `CHero__SetDword_0x114C_AndPost3F8` (stores `hero+0x114C` and posts `0x3F8`).
- `15`: emits a red system message via string id `0x2CEF`.
- `17`: durability/equip-break handling for tracked position `+4` with signed target durability `+8`. Native fetches the tracked item by position, emits warning strings `0x18709/0x1870A` as applicable, and always writes the incoming low word through `CItem__SetCurrentDurability`. For non-positive durability it additionally sets `CItem+0x1AC` to `1` for equipment-category items; the positive path does not clear that byte. It refreshes derived equipment state on break, posts `0x3FB/0x445/0x446`, then sends `CMsgAction` type `10010`.
- `18`: route-specific item update path with expected item UID `+4` and tracked position `+8`. Native gets the tracked item directly through `CHeroItem__GetTrackedItemRefByPosition(+8)`, normalizes `+8` through `ItemPosition_NormalizeEquipmentPosition`, gets the equip-slot ref for that normalized slot, asserts that the tracked item UID matches `+4`, re-tracks the item at `+8`, conditionally refreshes the equip-slot ref, posts `0x3FB/0x445/0x446`, and sends `CMsgAction` type `10010`.
- `19`, `20`: calls `TickHelper__663D69("improveSuc")`.
- `22`: calls `TickHelper__70AC6F(hero+0x2A54, +4, +8, 0, 0)`.
- `23`: if `+8 == hero+0x2A1C`, calls `TickHelper__71800D(hero+0x2A18, +4)`; if `+8 == hero+0x2A58`, also calls `TickHelper__70AD91(hero+0x2A54, +4, 0)`.
- `24`: if `+8 == hero+0x2A1C`, calls `TickHelper__71800D(hero+0x2A18, +4)`.
- `25`: finds item by UID `+4`, writes word from `+8`, posts `0x3EB/0x3FB`.
- `26`: spawns three randomized on-screen effects via `UIEffect__62D578` using screen dimensions and random offsets.
- `27`: updates local latency field `hero+0x2CF4 = timeGetTime() - +16`.
- `28`: "CountB/CountK" counter display update using UID `+4` and value `+8`; updates zoomed string UI.
- `29`: calls `TickHelper__70AC6F(hero+0x2A54, +4, +8, 0, 1)`.
- `32`: timed-status entry update keyed by `+4`/`+8` with post `0x4CD`.
- `33`: timed-status start/stop update keyed by `+4`/`+8`; may emit chat strings `0x334C5/0x334C6/0x334C7`; posts `0x4CC` or `0x4CD`.
- `39`: posts `PostMainWndMsg_0x464(0xCBB, +8)`.
- `40`: posts `PostMainWndMsg_0x464(0xCF7, +8)`.
- `41`: active-item tip flow for UID `+4`; if item is valid, builds localized `STR_ACTIVE_ITEM_TIP` text and adds a system chat line.
- `42`: item-timeout delete flow for UID `+4`; removes item, posts `0x3EB/0x4BA` and optional `0xD31`, logs "ItemTimeOut". If UID is already absent, runs fallback timeout cleanup helpers and logs the same notification.
- `43`: posts `PostMainWndMsg_0x464(0xD33, +8)`.
- `46`: complete equipment snapshot. It consumes fixed UID fields at `+20,+24,+28,+2C,+30,+34,+38,+3C,+40,+44,+48,+4C,+50`, applies `CHeroItem__SetEquipSlot` for slots `{1,2,3,5,4,6,7,8,9,16,15,17,18}`, applies `CHeroItem__SetEquipMode(+8)`, refreshes equipment-derived stats, clamps current life and its gauge follower to effective max life when required, then posts `0x3EB/0x3FB/0x445/0x446/0x4FE`.
- `47`: force-equip-to-bag text assembly flow; iterates UID list at `+84` for `count_or_value` entries, resolves item names, and shows a message box.
- `50`: item-transfer flow via subsystem `0x4B178A` using UID `+4` and state `+8`; posts `0xC30(+8)`, `0xC2E(0)`, `0x3EB(0)`.
- `51`: iterates `count_or_value` dword entries from `+84`, posting `0xD37` for each UID, then posts `0xD38` with `+8`.
- Other subtype values in this build fall through with no additional handling.

### Subtype 46 UI refresh tail

The five calls are not packet-state mutations. `Conquer_PostMainWindowMessage464` posts Windows
message `0x464` to the main window with the listed command in `wParam`; subtype 46 supplies zero in
`lParam` for all five calls. `CMyShellDlg_WindowProc_DispatchMainWindowMessages` consumes them in the
same order in which they were posted.

| `wParam` | Verified native receiver behavior |
|---:|---|
| `0x3EB` | If `CDlgMpcGoods` at shell `+0x6C9CC` is visible, `CDlgMpcGoods_RefreshInventoryGridAndDependentUi` clears and rebuilds its inventory grid from the hero item deque, posts its dependent refresh commands, and refreshes two text controls from hero values. Whether that dialog is visible or not, `CMyShellDlg_RefreshItemShortcutStackCounts` then recomputes the displayed stack total for each of ten item shortcut slots by scanning the complete hero inventory. |
| `0x3FB` | Tests four equipment-dependent pages for visibility in order: shell `+0x66714` (resource `0x87` page; class name not yet proven), `+0x68BE4` (`CDlgSubWeapon`), `+0x6382C` (`CDlgQuery_Skill`), and `+0x698A0` (`CDlgSubProfession`). The first two use visible-dialog lifecycle flag `0`; `CDlgQuery_Skill` uses flag `1`; the sub-profession page instead calls `CDlgSubProfession_RefreshPreviewRoleFromHeroEquipment`, which reapplies the hero's transform, motion timing, body, helmet, garment and eligible weapon sources to its preview role. |
| `0x445` | If `CDlgBattleLevelOther` at shell `+0x1492A0` is visible, invokes its visible-dialog lifecycle with flag `1`. |
| `0x446` | If the embedded `CDlgBattleLevDetail` at shell `+0x14939C` (`CDlgBattleLevelOther+0xFC`) is visible, invokes its visible-dialog lifecycle with flag `1`. |
| `0x4FE` | If `CDlgVipRepairAll` at shell `+0x49FD0` is visible, refreshes its ten equipped-item images first, then recomputes per-slot repair eligibility/failure or cost text and the total repair cost. |

The current managed client has no implementation of any of those dialog or shortcut-bar surfaces.
Subtype 46 already performs the proven managed state work (equipment projection, derived maxima and
life/follower clamp). The native UI notifications therefore remain deliberately unmodeled until a
corresponding managed consumer exists; reproducing the MFC message IDs as an otherwise unused managed
event layer would add no native-visible behavior.

**Verified outbound builders (`MsgTick` send-side helpers)**:
- `CMsgTick__Build_SubType` (0x6EAC51): fixed-size packet (`size=88`) with fields `+4=a2`, `+8=a3`, `+12=subtype`, `+16=(localHeroId ^ timeGetTime())`.
- `CMsgTick__Build_SubType1_WithCount` (0x6EACBD): `subtype=1`, writes `+20=count`.
- `CMsgTick__Build_SubType_WithCountAndByte` (0x6EAD32): writes `+12=subtype`, `+20=count`, `+28=byte_flag`.
- `CMsgTick__Build_SubType40_WithDwordList` (0x6EADB7): `subtype=40`, `size=88+4*N`, `+20=N`, dword list starts at `+84`.
- `CMsgTick__AppendDwordToSubType40List` (0x6EAE79): appends one dword at `+84 + 4*count`, increments packet size by 4 and increments `count` (`+20`).

---

## MsgNpcInfo (Type 2030)
**Direction**: S->C
**Purpose**: First-world NPC spawn/materialization packet.
**Dispatch**: Create `CMsgNpcInfo__Create` (0x7439E3), parse `CMsgNpcInfo__Parse` (0x743A9F), process `CMsgNpcInfo__Process` (0x743B32)

**Verified parse behavior**:
- `CMsgNpcInfo__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 2030`.

**Verified fixed-field usage in `CMsgNpcInfo__Process`** (offsets relative to packet start):
- `+4` (u32) `entity_id`
- `+8` (u32) `spawn_auxiliary_dword` (passed to helper `0x650D9E`; exact semantic meaning is still unproven)
- `+12` (u16) `tile_x`
- `+14` (u16) `tile_y`
- `+16` (u16) `look_composite`
- `+18` (u16) `npc_kind`

**Verified name handling**:
- `CMsgNpcInfo__Create` initializes the internal MsgStringList helper at `this+0x408`.
- `CMsgNpcInfo__Process` reads the first entry from that helper and, when present, copies it with max length `0x10` and overrides the default role-data name.
- **Pinned 2026-08-29**: `CMsgNpcInfo__Create` binds the list at `0x743A2A` with `lea eax, [esi+4]` / `add eax, 0x16`, so the list starts at **packet + 0x16** and the fixed part is 22 bytes. The region begins with a one-byte entry count (`sub_771FC0` returns `**(list+4)`), then `[length byte][bytes]` per entry. Entry 0 is fetched with capacity `0x10` and `MsgStringList_TryGetEntry` fails when `capacity <= length`, so a name of 16 bytes or more is dropped and the NPC ends up nameless — the result is not checked.

**Verified `CMsgNpcInfo__Process` flow**:
- resolves an existing entity by `entity_id`; if one exists it runs the existing-entity cleanup path before deciding whether a new `CNpc` must be allocated
- allocates `0xA58` bytes, constructs `CNpc`, and wraps it in the standard entity ref/smart-pointer path when a fresh spawn is required
- writes:
  - `npc+0xCC = entity_id`
  - `npc+0x368 = npc_kind`
- calls helper `0x650D9E(npc, spawn_auxiliary_dword)`
- applies a default string through `0x6E5292`
- selects RoleView mode by `npc_kind`:
  - default -> `CRole__CreateRoleView(npc, look_composite, 4)`
  - `0x0E` -> `CRole__CreateRoleView(npc, look_composite, 6)`
  - `0x13` -> `CRole__CreateRoleView(npc, look_composite, 8)`
  - `{0x19,0x1A,0x27,0x29,0x2A,0x66,0x67}` -> `CRole__CreateRoleViewWithPos(npc, look_composite, 9, entity_id, tile_x, tile_y)`
- non-type-9 paths also call npc vfunc slot `+0x18` with `(tile_x, tile_y)`
- splits `look_composite` into:
  - `look_lookup_id = look_composite / 10`
  - `look_direction_index = look_composite % 10`
- role-data lookup branch:
  - if `look_lookup_id < 5000`, uses `RoleDataQuery()->vtable+0x30(look_lookup_id)`
  - else uses `RoleDataQuery()->vtable+0x34(look_lookup_id)`
- on successful role-data lookup:
  - applies the role-data name via `0x6E5292`
  - if `npc+0x430` exists, calls its vfunc `+0x10` with the role-data payload and flag `1`
  - writes `npc+0x184` from role-data offset `+0x80` (standard lookup) or `+0x5C` (terrain lookup)
- applies `look_direction_index` through `0x650CC2`
- if MsgStringList entry `0` exists, overrides the name again from that string entry
- registers the final entity through `0x6E77D5(&data_96B018, entityRef)`
- posts the entity update through `sub_6A55A6(sub_4CB09D(), entity_id)`

---


## Alternate Account Authentication Response (Type 1057; former MsgAchievement alias)
**Direction**: S->C
**Purpose**: Alternate account grant with primary/BGP endpoint selection and resource-version reporting; not achievement state.
**Dispatch**: `CMsgAccountAuthResponse1057__Ctor` (0x754F4D), `CMsgAccountAuthResponse1057__Process` (0x754FD6)

**Verified field usage in `CMsgAccountAuthResponse1057__Process`** (offsets relative to packet start):
- `+4` (u32) gates the handler. If zero, error path uses `CMsgConnect__HandleError(+8)` and stores `+8` via `MFC__SetDword_0x4`. If nonzero, stored into singleton offset `+2716`.
- `+8` (u32) is authenticationKey on success, stored by `CHero__SetLoginAuthKey`; otherwise an error code. The wrapping sum with UID XOR 0x4321 creates a stack-local cookie, not a checksum.
- `+12` (u16) is used as the port for a ping against the host string at `+20`.
- `+20` is treated as a NUL‑terminated host/IP string for `CPing__Ping`.
- `+52` (u16) is used as the port for a ping against the host string at `+56`.
- `+56` is treated as a NUL‑terminated host/IP string for the secondary `CPing__Ping`.

**Other observed behavior (context only)**:
- The continuation selects GameServer mode 2 at 0x7557F1 before rekeying outbound legacy tables at 0x755837. The tables are unused by mode 2. [Full native audit, including deployment limits](/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/20_notes/Network/14_session_derived_legacy_cipher_mask.md).
- Reads `res.dat` and sends a type‑1052 packet via `CMsgLoginBootstrap1052__BuildAccountResourceVersionReport` + `CNetMsg__Send`.
- Uses `CHero__GetDword_0x2E58` and `CHero__GetDword_0x2E5C` to compute a threshold `100*(a+1)+b+1`, then compares ping results to `v41`/`v44`.


## MsgTitle (Type 1071)
**Direction**: S->C
**Purpose**: Ride‑Match/title updates (verified by `Handle_Ride_Match_*` calls and ride‑match singleton usage).
**Dispatch**: Create `CMsgTitle__Create` (0x76208E), process `CMsgTitle__Process` (0x762117)

**Verified field usage in `CMsgTitle__Process`** (offsets relative to packet start):
- `+4` (u16) is the mode selector.
- Mode `0`:
  - `+8` (u32) stored via `MFC__SetDword_0x4` on the ride‑match singleton.
  - `+12` (u32) passed to `MFC__SetDword_0x20` on the same singleton.
- Mode `1`:
  - Calls `Handle_Ride_Match_Result(+8, +16, +12)`.
  - Posts `PostMainWndMsg_0x464(0xCBD, 0)`.
- Mode `2`:
  - Uses a NUL‑terminated string at `+12`, and dwords at `+16` and `+28`.
  - Calls `Handle_Ride_Match_Msg_First_Place(+8, { +16, +28, string@+12 })`.
  - Posts `PostMainWndMsg_0x464(0xCBD, 0)`.


## MsgTitleMsg (Type 1130)
**Direction**: S->C
**Purpose**: Title-state synchronization/update packet (gain/loss/select/list refresh flows for title IDs).
**Dispatch**: Create `CMsgTitleMsg__Create` (0x6EC7DE), parse `CMsgTitleMsg__Parse` (0x6EC844), process `CMsgTitleMsg__Process` (0x6EC8C8)

**Verified parse behavior**:
- `CMsgTitleMsg__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1130`.

**Verified field usage in `CMsgTitleMsg__Process`** (offsets relative to packet start):
- `+4` (u32) `entity_id` (local/remote role ID target, depending on subtype).
- `+8` (u8) `title_id`.
- `+9` (u8) `subtype` (switch key: `1..4` handled in this build).
- `+10` (u8) `count` (used by subtype `4`).
- `+11` (u8 array) `title_id_list` (`count` bytes, used by subtype `4`).

**Verified subtype behavior in `CMsgTitleMsg__Process`**:
- `1` (gain title):
  - Requires `entity_id == localHeroId`; otherwise ignored.
  - Adds `title_id` via `CTitleMgr__AddOwnedTitleById_6ACA7C`.
  - If title entry exists (`CTitleMgr__FindTitleEntryById(title_id)`), formats/logs system text using title-entry field `[6]`.
  - Posts `PostMainWndMsg_0x464(0xD2D, 0)`.
- `2` (lose title):
  - Requires `entity_id == localHeroId`; otherwise ignored.
  - If title entry exists, formats/logs system text using title-entry field `[6]`.
  - Posts `PostMainWndMsg_0x464(0xD30, title_id)`.
- `3` (active title change):
  - If `entity_id == localHeroId`:
    - Calls `CTitleMgr__SetActiveTitleAndPostD2C_6ACB5C(title_id)`.
    - If `title_id != 0`, also calls `CTitleMgr__SelectActiveTitleById_6AC9E5(title_id)`.
  - Else (remote role path):
    - Looks up role by `entity_id`.
    - Reads old value via `CRole__GetDword_0x8AC`.
    - If `old_title > 0 && title_id == 0`, calls `CTitleMgr__ApplyTitleToEntity_6ACA36(role_entity_id, old_title)` before write.
    - Writes new value via `CRole__SetDword_0x8AC(role, title_id)`.
    - If `title_id != 0`, calls `CTitleMgr__SelectActiveTitleById_6AC9E5(title_id)`.
- `4` (owned-title list refresh):
  - Clears title manager lists via `CTitleMgr__ClearLists_6ACB3D`.
  - If `entity_id == localHeroId`, iterates `count` bytes from `+11` and calls `CTitleMgr__AddOwnedTitleById_6ACA7C` for each title ID.
  - Posts `PostMainWndMsg_0x464(0xD2D, 0)`.
- Other subtype values in this build return without additional processing.

**Verified outgoing builder (`client -> server`)**:
- `CMsgTitleMsg__BuildSize12_EntityTitleSubtype` initializes:
  - `size = 12`, `type = 1130`
  - `+4 = entity_id` (u32)
  - `+8 = title_id` (u8)
  - `+9 = subtype` (u8)
  - `+10 = 0`, `+11 = 0`


## MsgMissionSystemUpdate (Type 1134)
**Direction**: S->C
**Purpose**: Mission-system entry update packet (single/batch state transitions, value updates, and mission-fail handling).
**Dispatch**: Create `CMsgMissionSystemUpdate__Create` (0x72D0DA), parse `CMsgMissionSystemUpdate__Parse` (0x72D140), process `CMsgMissionSystemUpdate__Process` (0x72D163)

**Verified parse behavior**:
- `CMsgMissionSystemUpdate__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1134`.

**Verified field usage in `CMsgMissionSystemUpdate__Process`** (offsets relative to packet start):
- `+4` (u16) `subtype` (switch key: `1,2,3,4,8,9` handled in this build).
- `+6` (u16) `entry_count` (used by subtype `3`).
- `+8` (u32) `entry_id` (single-entry subtypes).
- `+16` (u32) `value_16` (used by subtypes `1` and `9`).
- Subtype `3` repeating entry record (`12` bytes each):
  - `+8 + 12*i` (u32) `entry_id_i`
  - `+12 + 12*i` (u16) `state_code_i`
  - `+16 + 12*i` (u32) `value_i`

**Verified subtype behavior in `CMsgMissionSystemUpdate__Process`**:
- `1`:
  - Calls `CMissionSystemData__SetEntryDword_0x40_ById_6A5339(value_16, entry_id)`.
  - If `value_16 != 0`, calls `CMissionSystemData__AppendByteId_6A52A3(entry_id)`.
  - Posts `PostMainWndMsg_0x464(0xC4B, entry_id)` and `PostMainWndMsg_0x464(0xC78, entry_id)`.
  - Calls `CMissionSystemData__AppendEntryRefById_6A58F3(entry_id)`.
- `2`:
  - Posts `PostMainWndMsg_0x464(0xC48, entry_id)` and `PostMainWndMsg_0x464(0xC4A, entry_id)`.
  - Calls `CMissionSystemData__RemoveEntryRefById_6A5925(entry_id)`.
- `3` (batch):
  - Iterates `entry_count` records.
  - For each record, if `CMissionSystemData__FindEntryById_6A4F78(entry_id_i)` exists:
    - Calls `CMissionSystemData__SetEntryDword_0x40_ById_6A5339(value_i, entry_id_i)`.
    - If `state_code_i != 5 && state_code_i != 1 && value_i != 0`, calls `CMissionSystemData__AppendByteId_6A52A3(entry_id_i)`.
    - If `state_code_i == 5`:
      - calls `CMissionSystemData__ResetEntryFlagsById_6A5313(entry_id_i)`,
      - calls `CMissionSystemData__SetEntryWord_0x4E_ById_6A4D1A(entry_id_i, 0)`.
    - Else: calls `CMissionSystemData__SetEntryWord_0x4E_ById_6A4D1A(entry_id_i, state_code_i)`.
    - If manager-entry field `+20 == 2`, builds/sends a type-1135 request via:
      - `CMsgMissionSystemDetail__Create` + `CMsgMissionSystemDetail__BuildSubtype0_ByEntryId(0, entry_id_i)` + `CNetMsg__Send`.
  - If `state_code_i == 0`, calls `CMissionSystemData__AppendEntryRefById_6A58F3(entry_id_i)`.
  - After loop posts `PostMainWndMsg_0x464(0xC4C, 0)`.
- `4`:
  - Posts `PostMainWndMsg_0x464(0xC49, entry_id)`.
  - Calls `CMissionSystemData__RemoveEntryRefById_6A5925(entry_id)`.
  - Calls `CMissionSystemData__RemoveByteId_6A52C1(entry_id)`.
- `8`:
  - Plays screen effect by name `"taskfail"` via `CScreenEffectMgr__PlayEffectByName_620936`.
  - Calls `CMissionSystemData__RemoveByteId_6A52C1(entry_id)`.
  - Calls `CMissionSystemData__ResetEntryFlagsById_6A5313(entry_id)`.
  - Posts `PostMainWndMsg_0x464(0xC46, entry_id)`.
- `9`:
  - Calls `CMissionSystemData__SetEntryDword_0x40_ById_6A5339(value_16, entry_id)`.
  - Calls `CMissionSystemData__SetEntryWord_0x4E_ById_6A4D1A(entry_id, 0)`.
- Other subtype values in this build return without additional handling.


## MsgMissionSystemDetail (Type 1135)
**Direction**: S->C
**Purpose**: Mission-system detail payload packet (writes seven detail values for one mission entry and refreshes mission UI).
**Dispatch**: Create `CMsgMissionSystemDetail__Create` (0x716B20), parse `CMsgMissionSystemDetail__Parse` (0x716B86), process `CMsgMissionSystemDetail__Process` (0x716BCF)

**Verified parse behavior**:
- `CMsgMissionSystemDetail__Parse` validates:
  - non-null source,
  - `Size == *(u16*)Src`,
  - `type == 1135`,
  - then copies packet to object+4.

**Verified field usage in `CMsgMissionSystemDetail__Process`** (offsets relative to packet start):
- `+4` (u16) `subtype` (`0` handled in this build).
- `+8` (u32) `entry_id`.
- `+12,+16,+20,+24,+28,+32,+36` (u32) `detail_1..detail_7`.

**Verified processing flow**:
- If `subtype != 0`: returns without updates.
- If `subtype == 0`:
  - Looks up entry via `CMissionSystemData__FindEntryById_6A4F78(entry_id)`.
  - If found, writes:
    - `detail_1` into slot `1`,
    - `detail_2` into slot `2`,
    - ...
    - `detail_7` into slot `7`,
    using `CMissionSystemData__GetDetailSlotByIndex_4CA239`.
  - Posts `PostMainWndMsg_0x464(0xC46, entry_id)`.

**Verified outgoing builder (`client -> server`)**:
- `CMsgMissionSystemDetail__BuildSubtype0_ByEntryId` initializes:
  - `size = 40`, `type = 1135`
  - `+4 = 0` (u16 subtype)
  - `+8 = entry_id` (u32)
- This builder is called from `CMsgMissionSystemUpdate__Process` subtype `3` when a matched entry has manager field `+20 == 2`.


## Types 1136–1149 (No Handler — Unused in This Build)
**Status**: Fully verified — all 14 type IDs (1136, 1137, 1138, 1139, 1140, 1141, 1142, 1143, 1144, 1145, 1146, 1147, 1148, 1149) route to the default dispatch target at `0x6E137B` in `CNetMsg__ProcessMsg_Dispatch`. They have **no** create, parse, or process functions. No message object is allocated, no packet data is read. These are reserved/unused type slots in the 1002–1151 jump table for client build 42.0.1. A developer implementing this protocol should ignore these type IDs — they are dead entries with no server-side behavior expected.


## MsgLottery (Type 1059)
**Direction**: Bidirectional
**Purpose**: Lottery/random seed update (verified by `srand`/`rand` usage and UI post).
**Dispatch**: Create `CMsgLottery__Create` (0x764B3D), process `CMsgLottery__Process` (0x764BC6)

**Verified field usage in `CMsgLottery__Process`** (offsets relative to packet start):
- `+4` (u32) is used as the seed to `srand`.
- After seeding, the handler writes 16 random bytes (`rand() % 256`) into a global buffer at `0x93FD83`.
- Ends with `PostMainWndMsg_0x464(0xCEE, 0)`.


## MsgQualifying (Type 1062)
**Direction**: Bidirectional
**Purpose**: Qualifying match list/updates (verified by `QualifyingMgr__*` calls).
**Dispatch**: Create `CMsgQualifying__Create` (0x75D5FD), process `CMsgQualifying__Process` (0x75D686)

**Verified field usage in `CMsgQualifying__Process`** (offsets relative to packet start):
- `+4` (u16) is the mode selector.

**Mode 0 (`+4 == 0`)**:
- `+8` (u32) is entry count.
- Entries begin at `+16` with stride 56 bytes.
- Per entry: dwords at `+16`, `+24`, `+28`, and a string at `+32` length `0x24` (36 bytes). Passed to `QualifyingMgr__SetEntry`.

**Mode 1 (`+4 == 1`)**:
- Uses dwords at `+24` and `+28` with `QualifyingMgr__SetPair_0x10_0x14`.

**Mode 2 (`+4 == 2`)**:
- Uses dword at `+12` with `QualifyingMgr__SetDword_0x18_AndUpdate`.


## MsgRank (Type 1065)
**Direction**: S->C
**Purpose**: Ranking list update (verified by rank‑manager calls in `CMsgRank__Process`).
**Dispatch**: Create `CMsgRank__Create` (0x6F942F), process `CMsgRank__Process` (0x6F94E1)

**Verified field usage in `CMsgRank__Process`** (offsets relative to packet start):
- `+4` (u16) is the mode selector.
- For modes `0–3`, if `+6` (u8) is nonzero, the list is cleared for that mode.
- `+8` (u32) is entry count.
- Entries start at `+12` with stride 16 bytes (4 dwords). The 4 dwords are passed to the mode‑specific manager.
- Mode `4` uses an alternate manager but the same 4‑dword entry layout.
- After processing, `PostMainWndMsg_0x464(0xD98, 0)` is triggered.


## MsgStrCheckKey (Type 1108)
**Direction**: Bidirectional
**Purpose**: Item data verification/update packet (applies item fields and routes updates by mode; includes target entity and item payload).
**Dispatch**: Create `CMsgStrCheckKey__Create` (0x75F94E), parse `CMsgStrCheckKey__Parse` (0x75F9B4), process `CMsgStrCheckKey__Process` (0x75F9D7)

**Verified parse behavior**:
- `CMsgStrCheckKey__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1108`.

**Verified field usage in `CMsgStrCheckKey__Process`** (offsets relative to packet start):
- `+4` (u32) `item_uid` (passed to `CItem__InitFromUIDAndItemId` and `CHeroItem__FindTrackedItemByUid`)
- `+8` (u32) `entity_id` (used by `EntityManager__FindEntityById`, compared to local hero ID)
- `+12` (u32) `value_12` (passed to `WriteDword_0x150_0x67B1CD` / `WriteDword_0x154_0x67B1DA`)
- `+16` (u32) `item_id` (passed to `CItem__InitFromUIDAndItemId`)
- `+20` (u16) → `CItem__SetWord_0x194`
- `+22` (u16) → item word at `((WORD*)item)+42`
- `+24` (u8) `mode` (switch selector; values `1..4`)
- `+25` (u8) → item byte at `+86`
- `+26` (u8) `route_type` (passed to `ItemPosition_NormalizeEquipmentPosition`; `mode==4` requires non‑zero)
- `+28` (u32) → `CItem__SetDword_0x14C`
- `+32` (u8) → item byte at `+87` (gem slot 1)
- `+33` (u8) → item byte at `+88` (gem slot 2)
- `+36` (u32) → item dword at `((DWORD*)item)+23`
- `+40` (u8) → item byte at `+96`
- `+41` (u8) → item byte at `+97`
- `+42` (u8) → item dword at `((DWORD*)item)+90`
- `+43` (u8) → `CItem__CanUpgrade`
- `+44` (u8) → item dword at `((DWORD*)item)+91`
- `+48` (u32) → item dword at `((DWORD*)item)+92` and (mode 2) written to entity words at `+2240/+2242` when not `0xFFFFFFFE`
- `+52` (u16) → `CItem__SetByte_0x1AD`
- `+54` (u16) → `CItem__OrDword_0x1A0`
- `+56` (u16) → `CItem__SetRoleViewTextureVariantSelector` and passed to `FieldGroup__Set_*` helpers in mode 2
- `+60` (u32) → `CItem__SetDword_0x160`
- `+64` (u32) → `CItem__SetDword_0x17C`
- `+68` (u32) → `CItem__SetTimerDuration`
- `+72` (u16) → `CItem__SetDwordMin1_0x190`
- `+76` (u32) `param_a` (used as `v4`; if zero, uses `+80`)
- `+80` (u32) `param_b` (used when `param_a == 0`; also passed to `CObject__SetDword_0x10`)
- `+76` also passed to `CItem__SetDword_0x14`

**Verified processing flow**:
- The item field mapping matches `MsgItem` but is shifted by `+8` bytes (extra dwords at `+8/+12`), and uses `mode` at `+24`.
- `mode == 1`:
  - Requires `*(s__GetSingletonPtr_404460()+10780) == *(u32*)(packet+8)`.
  - Builds a `CItem`, initializes via `CItem__InitFromUIDAndItemId(item_uid, item_id)`, copies all item fields above, and calls `CItem__IsTypeEquipSet_1_8_12_14_15_16_20_21`. If that returns true and `+20 == 0`, calls `CItem__SetByte_0x1AC(1)`.
  - Applies `WriteDword_0x150_0x67B1CD(value_12)` and sets `CItem__SetByte_0x165` based on whether local hero ID equals `entity_id`.
  - Routes the item through the verified singleton item-sync consumer after obtaining the singleton via `j_s__GetSingletonPtr_404460`.
- `mode == 2`:
  - Looks up `entity_id` via `EntityManager__FindEntityById`. If found, routes based on `ItemPosition_NormalizeEquipmentPosition(route_type)`:
    - return `1` → `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView(item_id, v4, +56, 1)`.
    - return `3` → `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView(item_id, v4, +56, 1)`.
    - return `4` → `CRole__SetRightWeaponVisualInputsAndRefreshRoleView(item_id, v4, 1)` and if `+48 != 0xFFFFFFFE`, writes `*(u16*)(entity+2240) = (u16)+48`.
    - return `5` → `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView(item_id, v4, +56, 1)` and if `+48 != 0xFFFFFFFE`, writes `*(u16*)(entity+2242) = (u16)+48`.
  - If entity not found and local hero ID equals `entity_id`, updates the local tracked item by UID via `CHeroItem__FindTrackedItemByUid`, copies all item fields, sets `CItem__SetByte_0x165(1)`, posts `0x3FB/0x445/0x446`, and triggers `CHero__RefreshEquipmentDerivedStats` plus the adjacent local-item refresh helper at `0x6B2E34`. If the item gains a socket and status flag `0x3F` is not set, posts `0x4B9` with the item UID.
- `mode == 3`:
  - Similar to mode `1` but calls `WriteDword_0x154_0x67B1DA(value_12)` for the alternate slot.
- `mode == 4` and `route_type != 0`:
  - Builds a `CItem`, initializes and copies fields, sets `CItem__SetByte_0x165(0)`, routes through `ItemPosition_NormalizeEquipmentPosition(route_type)` / `CRole__SetEquipSlotItem`, and posts `0x432` if the add path succeeds.


## MsgCrossSwitch (Type 1109)
**Direction**: Bidirectional
**Purpose**: NPC/entity spawn-switch packet with role-view construction, map tile reveal updates, and optional name override from an embedded string list.
**Dispatch**: Create `CMsgCrossSwitch__Create` (0x75EEB0), parse `CMsgCrossSwitch__Parse` (0x75EF6C), process `CMsgCrossSwitch__Process` (0x75EF8F)

**Verified parse behavior**:
- `CMsgCrossSwitch__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1109`.

**Verified field usage in `CMsgCrossSwitch__Process`** (offsets relative to packet start):
- `+4` (u32) `entity_id`: looked up in `EntityManager__FindEntityById`; if already present, triggers immediate replacement/removal flow.
- `+8` (u32) `value_0x370`: written via `CRole__SetDword_0x370_650D9E`.
- `+12` (u32) `value_for_vfunc50`: passed to spawned entity vtable method `+200` (`(*v70)[50]`) on mode-4/mode-5/mode-9 paths.
- `+16` (u32) `value_field606`: passed to `CRole__SetDwordField606_673EAC(entity, 1, +16)` on mode-4/mode-5/mode-9 paths.
- `+20` (u16) arg0 and `+22` (u16) arg1: passed to entity vtable method `+24` (`(*v70)[6]`).
- `+24` (u16) `look`: used by `CRole__CreateRoleView*`, and split as `(look/10, look%10)` for role-data queries.
- `+26` (u16) `npc_kind`: main switch key; stored into entity field `[218]`.
- `+34..` string-list payload: list object initialized from packet buffer (`MsgStringList__InitBuffer(this+258, packet+34, 0x3E1)`); entry 0 (max 16 bytes) is consumed via `MsgStringList__GetEntry`.

**Verified processing flow**:
- Step 1: if `entity_id` already exists, calls `EntityManager__RemoveEntityById_6E7B23(manager, entity_id, 1)` and exits.
- Step 2: allocates/constructs `CNpc` (`0xA58` bytes), then applies base fields:
  - `entity[51] = entity_id`
  - `CRole__SetDword_0x370_650D9E(entity, +8)`
  - initializes name with the default `name` symbol, then resolves role-data name by `look` and writes it through `CRole__SetString_0x14C_6E5292`
  - sets `entity[218] = npc_kind`
  - calls entity vfunc `+24` with `(+20, +22)`
  - if string list has entry `0`, overrides display name with that entry.
- Step 3: adds the new entity via `EntityManager__AddEntity_6E77D5(entityManager, entityRef, refcount)`.

**`npc_kind` path selection (verified)**:
- `npc_kind == 0x0A (10)`: `CRole__CreateRoleView(entity, look, 5)`, then post-add calls `(*entity)[50](+12)`, `CRole__SetDwordField606_673EAC(entity,1,+16)`, and sets `entity[93] = 4`.
- `npc_kind == 0x0E (14)`: `CRole__CreateRoleView(entity, look, 6)`, then add-only path (no `(*entity)[50]` / `CRole__SetDwordField606_673EAC` in this build).
- `npc_kind in {0x19,0x1A,0x27,0x29,0x2A,0x66,0x67}`:
  - uses `CRole__CreateRoleViewWithPos(entity, look, 9, entity_id, +20, +22)`,
  - if `npc_kind == 26`, sets `entity[93] = 2`,
  - then runs `(*entity)[50](+12)` and `CRole__SetDwordField606_673EAC(entity,1,+16)`.
- all other `npc_kind` values: generic path with `CRole__CreateRoleView(entity, look, 4)`, then `(*entity)[50](+12)` and `CRole__SetDwordField606_673EAC(entity,1,+16)`.

**Role-data query split (verified)**:
- if `look/10 >= 5000`, queries role-data branch via vtable slot `+52`.
- else uses vtable slot `+48`.
- both branches set the role name and push appearance data into `entity[268]` via vtable method `+16`.


## MsgTrusteeshipState (Type 1129)
**Direction**: S->C
**Purpose**: Copies a 32-bit trusteeship/state value from packet payload into singleton state and triggers UI refresh message `0x4DB`.
**Dispatch**: Create `CMsgTrusteeshipState__Create` (0x75DA61), parse `CMsgTrusteeshipState__Parse` (0x75DAC7), process `CMsgTrusteeshipState__Process` (0x75DAEA)

**Verified parse behavior**:
- `CMsgTrusteeshipState__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1129`.

**Verified field usage in `CMsgTrusteeshipState__Process`** (offsets relative to packet start):
- `+4` (u32) `state_value`: copied into local singleton state via `DwordPacketField__CopyU32Max4_75DB37` + `Singleton4197DD__SetDword_0x34`.

**Verified processing flow**:
- Initializes a 4-byte local buffer (`DwordPacketField__CopyU32Max4_75DB37` enforces max copy size 4).
- Copies `state_value` from packet offset `+4` into the buffer.
- Resolves singleton via `s__GetSingletonPtr_4197DD` and writes value to singleton dword field `+0x34` (`Singleton4197DD__SetDword_0x34`).
- Posts `PostMainWndMsg_0x464(0x4DB, 0)`.


## MsgSubPro (Type 1113)
**Direction**: Bidirectional
**Purpose**: Synchronizes sub-profession state in `CSubProfMrg` (value arrays + triple-slot values), with subtype-driven add/subtract/reset flows and status chat notifications.
**Dispatch**: Create `CMsgSubPro__Create` (0x75E53B), parse `CMsgSubPro__Parse` (0x75E5A1), process `CMsgSubPro__Process` (0x75E627)

**Verified parse behavior**:
- `CMsgSubPro__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1113`.

**Verified packet layout used by `CMsgSubPro__Process`** (offsets relative to packet start):
- `+4` (u8) `subtype` (switch key, values `0..6` used in this build).
- `+5` (u8) `count_or_param`:
  - subtypes `0..3`: loop count.
  - subtype `4`: duration parameter passed to `CSubProfMrg__SetDurationWindowFromSeconds`.
- `+8` (u32) `owner_or_entity_id`:
  - subtypes `0..5`: compared against `CSubProfMrg__GetOwnerEntityId(CHero+0x2AD8)`.
  - subtype `6`: used for `EntityManager__FindEntityById`.
- Repeating entries for subtypes `0..3` (`i in [0, count_or_param)`):
  - `+12 + 8*i` (u8) `entry_index` (consumed by `CSubProfMrg` getters/setters; valid range `0..22`).
  - `+16 + 8*i` (u32) `entry_delta`.
- Subtype `6` local payload:
  - `+16` (u8) `v0`
  - `+17` (u8) `v1`
  - `+18` (u8) `v2`

**Verified subtype behavior in `CMsgSubPro__Process`**:
- `0`:
  - Owner check must pass.
  - For each entry: `target[index] = target[index] + delta` using `CSubProfMrg__GetTargetValueByIndexOrTotal22` / `CSubProfMrg__SetTargetValueByIndex`.
  - Posts `PostMainWndMsg_0x464(0x438, 0)`.
- `1`:
  - Owner check must pass.
  - For each entry:
    - `target[index] += delta`
    - `current[index] += delta`
  - Uses `CSubProfMrg__GetTargetValueByIndexOrTotal22`, `CSubProfMrg__SetTargetValueByIndex`, `CSubProfMrg__GetCurrentValueByIndexOrTotal22`, `CSubProfMrg__SetCurrentValueByIndex`.
  - Posts `0x438`.
- `2`:
  - Owner check must pass.
  - For each entry: `target[index] = max(target[index] - delta, 0)`.
  - Posts `0x438`.
- `3`:
  - Owner check must pass.
  - For each entry:
    - `target[index] = max(target[index] - delta, 0)`
    - `current[index] = max(current[index] - delta, 0)`
  - Posts `0x438`.
- `4`:
  - Owner check must pass.
  - Adds system message from dataset id `100131`.
  - Calls `CSubProfMrg__ClearEntryStateInList_0xD0`, `CSubProfMrg__ClearCurrentAndTargetValues`, then `CSubProfMrg__ClearEntryStateInList_0xD0` again.
  - Calls `CSubProfMrg__SetDurationWindowFromSeconds(count_or_param)`.
  - Posts `0x438`.
- `5`:
  - Owner check must pass.
  - Adds system message from dataset id `100132`.
  - Posts `0x438`.
- `6`:
  - Looks up entity by `owner_or_entity_id` and, if entity component at `+0x3B4` exists, writes three byte values via component vfunc(+4) keys `27`, `28`, `29` using packet bytes `+16/+17/+18`.
  - If local owner id matches `owner_or_entity_id`:
    - `sum = v0 + v1 + v2`.
    - Chooses dataset id `100134` when `sum <= 10`, else `100133`.
    - Formats/logs a red system message (`CChatLog__AddSystemMessage(..., 2005, -65536, ...)`).
    - Stores triple values in local manager slots 0..2 via `CSubProfMrg__SetTripleValueBySlot0to2`.
    - Calls `CSubProfMrg__ClearCurrentAndTargetValues`.
    - Posts `0x438`.
  - If local owner check fails, this subtype path returns without posting `0x438`.
- Other subtype values in this build have no handler path.

**Verified outgoing builder (`client -> server`)**:
- `CMsgSubPro__BuildSingleEntry` builds a 20-byte packet:
  - `size=20`, `type=1113`
  - `+4=subtype`, `+5=1`
  - `+8=owner_id`
  - `+12=entry_index`
  - `+16=entry_delta`
- `CSubProfMrg__SendSubtype2ForIndexIfCurrentNonZero` uses this builder with `subtype=2` and current value for the selected index.


## MsgMapInfo (Type 1110)
**Direction**: Server to client in the verified world-entry path
**Purpose**: Updates `CGameMap` state fields/flags and fans out UI + manager updates based on flag transitions.
**Dispatch**: construct `CMsgMapInfo1110__Ctor` (0x732A87), parse `CMsgMapInfo1110__Parse` (0x732AED), process `CMsgMapInfo1110__Process` (0x732B10)

**Verified parse behavior**:
- `CMsgMapInfo1110__Parse` calls `CNetMsg__ValidateHeaderAndCopy` (validates size/type, copies packet to object+4) and checks `type == 1110`.

**Verified field usage in `CMsgMapInfo1110__Process`** (offsets relative to packet start):
- `+4` (u32) → `CGameMap_ApplyMapIdAndRefreshWorldState` (`CGameMap.currentMapId` at `+0xE0`). The refresh chain always runs; only `forceType5TriggerRefresh` at `+0x2E4` is set conditionally when the ID changes.
- `+8` (u32) → `CGameMap_SetMapDocumentId` (`CGameMap.currentMapDocumentId` at `+0xE4`).
- `+12` (u32) `flags_low` (low dword of map-state qword at `CGameMap+0xE8`).
- `+16` (u32) `flags_high` (high dword of map-state qword at `CGameMap+0xEC`).

**Verified processing flow**:
- Captures pre-update booleans from old map flags:
  - `old_bit_0x02000000 = CGameMap__IsDword_0xE8_Bit_0x02000000()`
  - `old_bit_0x10000000 = CGameMap__IsDword_0xE8_Bit_0x10000000()`
  - `old_bit_0x0000004000000000 = CGameMap__IsQword_0xE8_Bit_0x0000004000000000()`
  - `old_qword = CGameMap__GetQword_0xE8()`
- Applies packet values to `CGameMap` via:
  - `CGameMap_ApplyMapIdAndRefreshWorldState(+4)`
  - `CGameMap_SetMapDocumentId(+8)`
  - `CGameMap_SetFlags64(+12, +16)`
- Resets a hero byte and posts a UI refresh:
  - `CHero__SetByte_0x2F58(0)`
  - `PostMainWndMsg_0x464(0xD9B, 0)`
- Locale-gated system message path:
  - If `strcmp(Str1, GameDataSetQuery()->vfunc_52()) == 0`, computes `mode = CGameMap__ClassifyQword_0xE8_Bits_0x8_0x81()`.
  - `mode == 1` posts chat system message id `49996`; `mode == 2` posts id `49997`; `mode == 0` does not post.
- Bit transition side effects:
  - If bit `0x02000000` is set after update: `CRaceTrackPropMgr__HandleMapStateBit0x02000000_Set()`.
  - Else if it was previously set: `CRaceTrackPropMgr__HandleMapStateBit0x02000000_Clear()`.
  - If bit `0x10000000` is set after update: `CFactionPKMgr__HandleMapStateBit0x10000000_Set()`.
  - Else if it was previously set: `CFactionPKMgr__HandleMapStateBit0x10000000_Clear()`.
- Posts mode/status UI messages from current flags:
  - If bit `0x00400000` is set: `PostMainWndMsg_0x464(0xBF9, 0)`, else `PostMainWndMsg_0x464(0xDDC, 0)`.
  - If `CGameMap+0xEC` has bit `0x10`: `PostMainWndMsg_0x464(0xDE1, 0)`, else `PostMainWndMsg_0x464(0xDE2, 0)`.
- If qword bit `0x0000004000000000` changed:
  - `CHero__RefreshEquipmentDerivedStats(CHero*)`
  - posts `0x445`, `0x446`, `0xDA4`
  - builds/sends `CMsgAction` type `10010` with action id `408`.
- Delayed transition gate (`g_bTransitionGateLatch` latch):
  - Predicate function `CMsgMapInfo1110_HasTrackedFlagPattern` (`0x732A44`) is true when `(flags_low & 0xA0000000) != 0` or `(flags_high & 0x81) != 0`. The shared feature meaning of those four bits is not yet proven.
  - If latch is clear and predicate transitions `false -> true`, calls `QwordFlagLatch__OnPatternEnter_0x5EFA30()` and sets latch.
  - If latch is set and `GetTransferListEvent(...) == 1002`, calls `QwordFlagLatch__OnTransferEvent1002_0x5EFA80()` and clears latch.
- Always posts `PostMainWndMsg_0x464(0xDA5, 0)` at exit.

**Bootstrap note**:
- The managed login/bootstrap slice currently consumes `1110` as the first explicit map-state snapshot after the client’s post-`1006` `74`.
- Managed runtime mapping now stores the verified `1110` fields into shared map state:
  - `mapId` / `CGameMap+0xE0` mirror
  - `mapDocumentId` / `CGameMap+0xE4` mirror
  - `flagsLow` / `CGameMap+0xE8` low dword
  - `flagsHigh` / `CGameMap+0xEC` high dword
- The current slice does **not** claim all native UI post-message side effects (`0xD9B`, `0xBF9`, `0xDDC`,
  `0xDE1`, `0xDE2`, `0xDA5`, etc.) are implemented yet; it only persists the verified state values those branches
  operate on.


## MsgWarFlag (Type 1083)
**Direction**: Bidirectional
**Purpose**: War‑flag UI updates (verified by `PostMainWndMsg_0x464` variants in the handler).
**Dispatch**: Create `CMsgWarFlag__Create` (0x714B0B), process `CMsgWarFlag__Process` (0x714C89)

**Verified field usage in `CMsgWarFlag__Process`** (offsets relative to packet start):
- `+248` (u32) is a mode selector.
  - If `== 0`: posts `PostMainWndMsg_0x464(0xCEC, +252)`.
  - If `== 7`: posts `PostMainWndMsg_0x464(0xCED, 0)`.
  - Else: posts `PostMainWndMsg_0x464(0xCF0, 0)` then `PostMainWndMsg_0x464(0xCF2, 0)`.
- `+252` (u32) is used only in the `+248 == 0` case.
