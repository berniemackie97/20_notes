# Guild Packets — Syndicate, Peerage, Guild War

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## MsgSynAttr (Type 1041)
**Direction**: S→C
**Purpose**: Synced attribute list update for the local player (verified by `SynAttrMgr__AddEntry` and `SynAttrEntry__SetName`).
**Dispatch**: Create `CMsgSynAttr__Create` (0x6FE406), parse `CMsgSynAttr__Parse` (0x6FE46C), process `CMsgSynAttr__Process` (0x6FE4C0)

**Parse**: `CMsgSynAttr__Parse` — standard header validation, then `type == 1041`.

**Verified field usage in `CMsgSynAttr__Process`** (offsets relative to packet start):
- `+4` (u32) is compared against the local player ID (singleton `+204`). If it does not match, the handler returns without processing.
- `+8` (u32) is a count of entries.
- Entries are processed with stride `0x20` (32 bytes) starting at `+12`:
  - `entry+0`..`entry+11` are not referenced in this handler.
  - `entry+12` (u8) is a flag; nonzero sets a field to `1` in the constructed object, zero sets it to `0`.
  - `entry+16` (u32) is stored into the constructed object at offset `+4`.
  - `entry+20` (u32) is stored into the constructed object at offset `+64`.
  - `entry+24` (u32) is stored into the constructed object at offset `+68`.
  - `entry+28` is treated as a null-terminated string and passed to `strlen`/`ByteBuffer__AppendRange` via `SynAttrEntry__SetName`.
- For each constructed entry object, `SynAttrMgr__AddEntry` is called, and after the list is processed `PostMainWndMsg_0x464(0x439, 0)` is triggered.

## MsgSynMemberInfo (Type 1058)
**Direction**: S→C
**Purpose**: Syndicate member attribute bitmask update (verified by mask‑gated `CHero__SetDword_*` calls).
**Dispatch**: Create `CMsgSynMemberInfo__Create` (0x701C52), process `CMsgSynMemberInfo__Process` (0x701D0C)

**Verified field usage in `CMsgSynMemberInfo__Process`** (offsets relative to packet start):
- `+4` (u32) is a bitmask; if zero, the handler returns.
- Each set bit pulls a dword from the packet and writes it via a `CHero__SetDword_*` setter:

| Mask | Packet offset | Setter |
|------|---------------|--------|
| 0x0001 | `+8`  | `CHero__SetDword_0x2E74` |
| 0x0002 | `+12` | `CHero__SetDword_0x2E7C` |
| 0x0004 | `+16` | `CHero__SetDword_0x2E84` |
| 0x0008 | `+20` | `CHero__SetDword_0x2E78` |
| 0x0010 | `+24` | `CHero__SetDword_0x2E80` |
| 0x0020 | `+28` | `CHero__SetDword_0x2E88` |
| 0x0040 | `+32` | `CHero__SetDword_0x2E90` |
| 0x0080 | `+36` | `CHero__SetDword_0x2E8C` |
| 0x0100 | `+40` | `CHero__SetDword_0x2E94` |
| 0x0200 | `+44` | `CHero__SetDword_0x2E98` |

- After updates, `PostMainWndMsg_0x464(0xC5E, 0)` is triggered.

## MsgSynListInfo (Type 1066)
**Direction**: S→C
**Purpose**: Special‑meteor system messages (verified by `STR_SPECIAL_METE_*` string keys used in the handler).
**Dispatch**: Create `CMsgSynListInfo__Create` (0x716722), process `CMsgSynListInfo__Process` (0x7167E5)

**Verified field usage in `CMsgSynListInfo__Process`** (offsets relative to packet start):
- `+4` (u32) is the mode selector. No other packet fields are referenced.
- Modes map to UI message strings:
  - `1`: Formats and shows `STR_SPECIAL_METE_SUCC` with two parameters: a value from singleton offset `+2104` and a string returned by `CHero__GetStringByFields_0x178_0x82C` (lookup on singleton fields `+94` and `+523`).
  - `2`: Shows `STR_SPECIAL_METE_DEAD`.
  - `3`: Shows `STR_SPECIAL_METE_PROF_LEVEL`.
  - `4`: Shows `STR_SPECIAL_METE_SECOND_METE`.
  - `5`: Shows `STR_SPECIAL_METE_LEVEL`.
  - `6`: Shows `STR_SPECIAL_METE_NO_ITEM`.

## MsgSyn (Type 1107)
**Direction**: Bidirectional
**Purpose**: Syndicate/faction operations (join/apply/appoint/notify flows) driven by subtype codes and optional string‑list entries.
**Dispatch**: Create `CMsgSyn__Create` (0x702520), parse `CMsgSyn__Parse` (0x7025DC), process `CMsgSyn__Process` (0x7031B9)

**Parse**: `CMsgSyn__Parse` — standard header validation, then `type == 1107`.

**Verified field usage in `CMsgSyn__Process`** (offsets relative to packet start):
- `+4` (u16) `subtype`
- `+8` (u32) `param` (used as entity ID, entry ID, or rank/title value depending on subtype)
- String list entries are accessed via `MsgStringList__GetCount` / `MsgStringList__GetEntry` on the list at `this+258`.

**Subtype handling (by `+4`):**
- `1`: `CHero__SetDword_0x1294(+8)`; looks up entity `+8` and shows `CMessageBoxMgr__ShowCommandMessageWithButton(3462, entity_name, confirm_string, text)` using string IDs `10001`/`10004`.
- `2`: looks up entity `+8`; sets `CHero__SetDword_0x1294(+8)` and `CHero__SetDword_0x1298(CHero__GetDword_0x86C(entity))`; builds text with string IDs `10001`/`10005` and `CGamePlayerSet__Func_6E97E0`, then shows `CMessageBoxMgr__ShowCommandMessageWithButton(3463, entity_name, confirm_string, text)`.
- `7`: `CGamePlayerSet__Func_6E97E0(+8)` then `CGamePlayerSet__SetEntryStateById(+8, state=0)`; posts `PostMainWndMsg_0x464(0x40A, 0)`.
- `8`: `CGamePlayerSet__Func_6E97E0(+8)` then `CGamePlayerSet__SetEntryStateById(+8, state=3)`; posts `PostMainWndMsg_0x464(0x40A, 0)`.
- `9`: `CGamePlayerSet__Func_6E97E0(+8)` then `CGamePlayerSet__SetEntryStateById(+8, state=1)`; posts `PostMainWndMsg_0x464(0x40A, 0)`.
- `10`: same as subtype `8` (state `3`, posts `0x40A`).
- `13`/`14`: `CGamePlayerSet__Func_6E97E0(+8)` then `CGamePlayerSet__SetEntryStateById(+8, state=2)`.
- `15`: `CHero__UpdateDword_0x86C_ById_0x70173C(+8, +8)`.
- `16`: calls `NoOp_0x768140(+8, +8)` (no effect).
- `19`: `CGamePlayerSet__Handle_6E9AFA(&unk_96B018, +8)`.
- `23`: if string list has entry `0`, builds text using `STR_FACTION_APPL` and shows `CMessageBoxMgr__ShowCommandMessageWithButton(3516, entry, confirm_string, text)`.
- `25`: calls `Handle_Faction_Joinfail_Pro`.
- `26`: calls `Handle_Faction_Invitefail_Pro`.
- `27`: if string list has entry `0`, formats a destination string and passes it to `Handle_Yeah_Month_Day(hero, destination, +8)`.
- `28`: if string list non‑empty, builds confirmation text from `STR_FACTION_APPO_24`, uses `SynMgr__LookupString_6C5DE4(CHero__GetWord_0x874(), +8)`, updates hero fields `CHero__SetString_0x2FBC` and `CHero__SetDword_0x2FB8`, and shows `CMessageBoxMgr__ShowCommandMessage(3428, ...)`.
- `37`: clears the syndicate title list via `SynMgr__ClearList_6C5F24`, then for each string list entry parses 5 integers into a 5‑dword struct (`Struct5Dwords__Ctor_0x666976`) and calls `CSynMemberTitle__InsertSorted`; posts `PostMainWndMsg_0x464(0xBD9, 0)`.
- `39`: if `SynMgr__IsValue_602(+8)` or `SynMgr__IsValueSet_510_511_610_611(+8)` is true, builds a system message using `STR_FACTION_APPO_26` and `SynMgr__LookupString_6C5DE4`, adds it to chat log (type `2005`), then posts `PostMainWndMsg_0x464(0xBE3, 0)`.
- `40`: similar to subtype `39`, but uses `STR_FACTION_APPO_25`. Special case: if `+8 == 1000` and a string list entry is present, builds a message from `STR_BE_APPOINT_LE` and shows `CMessageBoxMgr__ShowFormattedMessage(...)` before posting `0xBE3`.
- `41`: posts `PostMainWndMsg_0x464(0xBE7, 0)` then `PostMainWndMsg_0x464(0xBE3, 0)`.
- `42–44`: posts `PostMainWndMsg_0x464(0xBE3, 0)`.
- Other subtypes in this build do not read packet fields or trigger processing.

## MsgDutyMinContri (Type 1056)
**Direction**: S→C
**Purpose**: Trade state updates (verified by `CHero__Trade*` calls; name differs from observed behavior).
**Dispatch**: Create `CMsgDutyMinContri__Create` (0x7622F4), parse `CMsgDutyMinContri__Parse` (0x762396), process `CMsgDutyMinContri__Process` (0x7623B9)

**Parse**: `CMsgDutyMinContri__Parse` — standard header validation, then `type == 1056`.

**Verified field usage in `CMsgDutyMinContri__Process`** (offsets relative to packet start):
- `+8` (u16) is a mode selector; most branches end with `PostMainWndMsg_0x464(0x3EB, 0)`.
- `+4` (u32) is passed into the mode-specific handlers.
- Observed mode-specific calls:
  - `1`: `CHero__TradeSetTargetNameIfEntityExists(+4)`.
  - `3`: `CHero__TradeSetTargetInfoIfEntityExists(+4)`.
  - `4`: `s__GetSingletonPtr_404460(1)` then `CHero__TradeProcessItemsAndPost3EEor3EF`.
  - `5`: `s__GetSingletonPtr_404460(0)` then `CHero__TradeProcessItemsAndPost3EEor3EF`.
  - `8`: `CHero__TradeSetField_0x1104_AndPost3F0(+4)`.
  - `9`: `CHero__TradeSetField_0x10FC_AndPost3F1(+4)`.
  - `10`: `CHero__TradeSetFlag_0x1110_AndPost3F5(s__GetSingletonPtr_404460())`.
  - `11`: `CHero__TradeRemoveItem_Post3EB_3F4(*(void **)(+4))`.
  - `12`: `CHero__TradeSetField_0x1108_AndPost3F0(+4)`.
  - `14`: `CHero__TradeSetField_0x1100_AndPost3F1(+4)`.
  - `15`: `PostMainWndMsg_0x464(0x4A8, 0)` (then still returns `PostMainWndMsg_0x464(0x3EB, 0)`).

## MsgPeerage (Type 1101)
**Direction**: Bidirectional
**Purpose**: Peerage/nobility map‑item and effect updates (verified by map‑item manager calls, peerage effect toggles, and drop‑sound selection).
**Dispatch**: Create `CMsgPeerage__Create` (0x73FDA7), parse `CMsgPeerage__Parse` (0x73FFB6), process `CMsgPeerage__Process` (0x740007), send `CMsgPeerage__Send` (0x73FFD9)

**Parse**: `CMsgPeerage__Parse` — standard header validation, then `type == 1101`.

**Verified outbound build path**:
- `CMsgPeerage__Build` (0x73FE0D) is called from `CHero__ProcessAction_Main` with `action = 3`, then sent via `CMsgPeerage__Send`.
- `CMsgPeerage__Build` sets:
  - `+0` (u16) = size `24`,
  - `+2` (u16) = type `1101`,
  - `+4` (u32) = local hero ID (singleton `+204`),
  - `+12` (u16) and `+14` (u16) = values forwarded from the action payload,
  - `+18` (u8) = `action` (caller passes `3`),
  - `+8` (u32) = checksum derived from the hero attribute array at `hero+0x2C60`:
    - `v16 = attr[0]`
    - `v7 = attr[13] + 1`
    - `v8 = (attr[10] + 1) * v7 + v16`
    - `v9 = attr[18] + 1`
    - `v10 = attr[3] * v9 + v8`
    - `v11 = attr[2]`
    - `v12 = attr[7] * v11 + v10`
    - `v13 = 25 * attr[12] + v12`
    - `v14 = v13 + 2 * attr[17]`
    - `v15 = attr[19] + v14`
    - `+8 = (attr[15] + v15) ^ 0x7914A09B`
- `CMsgPeerage__Send` checks `action == 3`, calls `NoOp_0x768140(17, 5)`, then calls `CNetMsg__Send`.

**Verified field usage in `CMsgPeerage__Process`** (offsets relative to packet start):
- `+18` (u8) is the action selector:
  - `1`: calls `CPeerage__AddMapItem(+4, +8, +20, +16, x=+12, y=+14)`. If `CGameMap__IsTileInViewRadius(x, y, 2)` is true, selects a drop sound based on `+8` (item ID) and plays it at `CGameMap__CalcScreenPosFromTile(x, y)` via `DXPlaySound`.
    - `+8 == 1091020` → `"sound/DropMoney.wav"`.
    - `0x10A1D0 <= +8 < 0x10A5CC` → `"sound/DropMed.wav"`.
    - `+8 in {1088000, 1088001, 1088002}` → `"sound/Bell.wav"`.
    - Otherwise, uses `GetItemMainTypeFromId(+8)` / `GetItemSubTypeFromId(+8)`:
      - Main type `1–8` → `"sound/DropEquip.wav"`.
      - Main type `0` and sub‑type `0` or `10000` → `"sound/DropMedic.wav"`.
      - Main type `0` and sub‑type `30000` → `"sound/DropBook.wav"`.
      - Main type `0` and sub‑type `50000` or `60000` → `"sound/DropItem.wav"`.
  - `2`: calls `CPeerage__RemoveMapItem(+4)`.
  - `3`: looks up entity `+4` via `EntityManager__FindEntityById`. If found, issues an effect command with ID `280` (opcode `8` in a small struct) and then calls `CRole__SetTilePosAndScreenPos(+12, +14)`.
  - `4`: calls `CPeerage__SpawnDisappearEffect({+12,+14}, +8, +16, 3000, 1000, "Disappear")`.
  - `10`: calls `CGameMap__PeerageEffect_FindOrCreate(+8, +4, +12, +14)`.
  - `11`: calls `CGameMap__PeerageEffect_FindOrCreate(+8, +4, +12, +14)` then `CGameMap__PeerageEffect_MarkById(+4)`.
  - `12`: calls `CGameMap__PeerageEffect_ClearById(+4)`.
  - `13`: treats `+4` as flags; bit `0` → `CGameMap__PeerageEffect_EnableType1`, bit `1` → `EnableType2`, bit `2` → `EnableType3`.
  - Other values (`0`, `5–9`, `14+`) do not read fields in this build.

## CMsgSynNotify (Type 2050)
**Direction**: S→C

**Wire type**: 2050 (0x0802)
**Create**: `CMsgSynNotify__Create` @ `0x7189B6`
**Process**: `CMsgSynNotify__Process` @ `0x718B8A`
**Packet object**: Uses MsgStringList — `MsgStringList__Ctor` at `this+257`, payload pointer at `this+260` (byte offset 1040), inline buffer at `this+4`, buffer size 0x3F1 (1009 bytes).

Delivers guild/syndicate notifications to the client. All modes display formatted game-data messages and/or clear syndicate state.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2050 |
| +4 | 1 | mode | Notification mode (3–6) |
| +8 | 4 | param | Parameter for string formatting (modes 3 and 5 use this as a format argument) |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 3 | Format game data string 100167 with `param` (twice), display via `CHero__SetNotifyMessage`, post 0x46C + 0x45C |
| 4 | Display game data string 100169 (no format args), post 0x46B + 0x45C |
| 5 | Format game data string 100168 with `param` (twice), display via `CHero__SetNotifyMessage`, post 0x46B + 0x45C |
| 6 | Clear last hero entry via `CHero__ClearLastHeroEntry`, post 0xDA6 |

### Notes
- The MsgStringList buffer is initialized at construction but the Process handler only reads fixed fields; the string list itself may be used by server-to-client string payloads in other code paths.
- `CHero__SetNotifyMessage` (0x662DA9) writes formatted text to the hero object at byte offset 12056, capped at 256 characters.
