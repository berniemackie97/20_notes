# Extended Packets — Pet, Mentor, Arena, Quiz, Title, Cross-Server War

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## CMsgPetInfo (Type 2051)

**Direction**: S→C
**Wire type**: 2051 (0x0803)
**Create**: `CMsgPetInfo__Create` @ `0x75C9A0`
**Process**: `CMsgPetInfo__Process` @ `0x75CA29`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Synchronises the player's pet/mount list. The server sends the full list; the client clears and rebuilds it.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2051 |
| +4 | 4 | param | Passed to `PostMainWndMsg_0x464(0x469, param)` after processing |
| +8 | 2 | clearFlag | If 0, clears the hero's pet list via `CHero__ClearPetList` before adding entries |
| +10 | 2 | entryCount | Number of pet entries (signed i16) |
| +12 | var | entries[] | Array of pet entries, stride = 112 bytes each |

### Pet Entry Layout (stride 112, starting at payload +12)

| Entry Offset | Size | Field | Description |
|--------------|------|-------|-------------|
| +0 | 4 | petID | Pet/mount unique ID → CPetInfo field 0 |
| +4 | 4 | field1 | Unknown u32 (not read by Process — but part of stride) |
| +8 | 4 | field2 | Unknown u32 (not read by Process — but part of stride) |
| +12 | 16 | name | Pet name string (null-terminated, up to ~15 chars) → CPetInfo field 4 (std::string) |
| +16 | 4 | field_16 | Unknown u32 → CPetInfo field 2 |
| +20 | 4 | field_20 | Unknown u32 → CPetInfo field 1 |
| +24 | 16 | name2 | Secondary name string → copied to CPetInfo field 4 (std::string at +16 bytes) |
| +28 | 4 | field_28 | Unknown u32 (not directly read — part of stride) |
| +32 | ... | ... | ... |
| +40 | 4 | field_40 | Unknown u32 → CPetInfo field 3 |
| +44 | 80 | displayName | Display name string — cleaned of `\r` and `\n` characters then stored → CPetInfo field 7 (std::string at +28 bytes) |

### Processing Logic
1. If `clearFlag == 0`, calls `CHero__ClearPetList` to reset the pet list.
2. Iterates `entryCount` times with stride 112:
   - Allocates a new `CPetInfo` object (40 bytes, `CPetInfo__Ctor` @ 0x655120)
   - Copies fields from the entry into the CPetInfo struct
   - Strips special characters from the display name at entry +44
   - Calls `CHero__AddPet` (0x662AE7) to add the pet to the hero's list
3. Posts `PostMainWndMsg_0x464(0x469, param)` to signal the UI.

## CMsgMentor (Type 2064)

**Direction**: Bidirectional
**Wire type**: 2064 (0x0810)
**Create**: `CMsgMentor__Create` @ `0x74A132`
**Process**: `CMsgMentor__Process` @ `0x74A2B3`
**Packet object**: MsgStringList layout — MsgStringList at `this+258`, payload pointer at `this+257`, inline buffer at `this+9`, buffer size 0x3B1 (945 bytes).

Manages the mentor/education system — handles name changes, student listings, and relationship updates.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2064 |
| +4 | 2 | mode | Action mode (1–4) |
| +8 | 2 | param1 | Mode 2: x-coord or count field |
| +10 | 2 | param2 | Mode 2: y-coord or count field |
| +12 | 4 | count | Mode 2: entry count |
| +20 | 4 | param3 | Mode 4: used with `CHero__SetMentorProgressFields` |
| +24 | 4 | param4 | Mode 4: used with `CHero__SetMentorProgressFields` |
| +32 | var | entries[] | Mode 2: stride-48 entries, passed via virtual call 240 |
| (strings) | var | stringList | MsgStringList — mode 1 reads entry 0 as player name; mode 3 reads entry 0 as name |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 1 | Set mentor name on hero via virtual call 284, post 0x487 + 0x445 + 0x446 |
| 2 | Clear via virtual call 276, set coords via virtual call 288 (`param1`, `param2`), iterate `count` entries (stride 48) calling virtual call 240, post 0x485 |
| 3 | Set name on entity: if entity ID at `+8` matches hero → virtual call 280 on hero; else find entity by ID → virtual call 280 on entity. Post 0x445 + 0x446 |
| 4 | Call `CHero__SetMentorProgressFields(+20, +8, +12, +24)`, post 0x488 |

## CMsgMentorNotify (Type 2065)

**Direction**: S→C
**Wire type**: 2065 (0x0811)
**Create**: `CMsgMentorNotify__Create` @ `0x74C355`
**Process**: `CMsgMentorNotify__Process` @ `0x74C484`
**Packet object**: MsgStringList layout — MsgStringList at `this+258`, payload pointer at `this+257`, inline buffer at `this+6`, buffer size 0x3E9 (1001 bytes).

Displays formatted mentor/education notifications. Uses string list entries for names and game data strings for message templates.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2065 |
| +4 | 1 | mode | Notification mode (6–23) |
| +8 | 4 | param1 | Used as format arg in many modes |
| +12 | 4 | param2 | Mode 16 (0x10): entity ID for hero check |
| +16 | 4 | param3 | Modes 13–15: format arg for game data strings |
| (strings) | var | stringList | Entry 0: player/entity name used in format strings |

### Mode Summary

| Mode | UI Message | Description |
|------|------------|-------------|
| 6 | 0x49E | Format "%s %u" with name + `param1` |
| 7 | (send) | Constructs and sends a CMsgMentorSync packet (type 0x0812) |
| 8 | 0x497 | Format "%s %u" with name + `param1` |
| 9 | 0x498 | Format "%s %u" with name + `param1` |
| 10 | 0x496 | Format game data string 100197 with name |
| 11 | 0x496 | Display game data string (no format args) |
| 12 | 0x499 | Format "%s %u" with name + `param2` (offset +12 as DWORD index 3) |
| 13 | 0x496 | Format game data string 100200 with name + `param3` |
| 14 | 0x496 | Format game data string 100201 with `param3` |
| 15 | 0x496 | Format game data string 100202 with name |
| 16 | 0x494 | If entity matches hero → clear education mgr; else if `param1` matches hero ID → set name |
| 17 | 0x494 | Mentor relationship actions — dismiss/establish via education mgr |
| 18 | 0x494 | Self-dismissal or send CMsgMentorSync response |
| 19 | 0x494 | Clear education mgr + refresh UI |
| 20 | 0x494 | Update student entry with name |
| 21 | 0x494 | Multi-path: clear education, set name, or update relationship based on `param3` |
| 22 | 0x49B | Set name on entity if matches hero |
| 23 | 0x494 | Find entity by name, update relationship |

## CMsgMentorSync (Type 2066)

**Direction**: S→C
**Wire type**: 2066 (0x0812)
**Create**: `CMsgMentorSync__Create` @ `0x7155CF`
**Process**: `CMsgMentorSync__Process` @ `0x7156DE`
**Packet object**: Uses `this+1028` for payload ptr and MsgStringList at `this+1032`.

Synchronises mentor/student entity data — creates or updates mentor and student records with detailed attribute fields.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2066 |
| +4 | 1 | mode | Action mode (1–6) |
| +6 | 2 | field_06 | Mode 1 uses for timer; mode 4: rank |
| +8 | 4 | entityId | Entity ID for mentor/student |
| +12 | 4 | param1 | Mode 2: entity key; mode 4: entry count |
| +16 | 4 | level | Level value (divided by 10000 mod 1000 for display) |
| +20 | 4 | exp | Experience/progress value |
| +24 | 4 | param2 | Relationship value; mode 2: level |
| +28 | 4 | param3 | Mode 1/2: additional status field |
| +32 | 1 | flag1 | Mode 1: online flag |
| +33 | 1 | flag2 | Mode 2: type flag |
| +34 | 2 | field_34 | Mode 2: portrait/icon |
| +36 | 4 | field_36 | Mode 1/2: rank/title |
| +40 | 4 | field_40 | Mode 1/2: additional data |
| +44 | 2 | field_44 | Mode 1/2: team status |
| +52 | 4 | field_52 | Mode 1/2: display order |
| +56 | 1 | onlineFlag | Mode 1: if set → mark online, else → mark offline |
| +64 | 4 | field_64 | Mode 2: spawn effect param 1 |
| +72 | 2 | field_72 | Mode 2: spawn effect param 2 |
| +74 | 2 | field_74 | Mode 2: spawn effect param 3 |
| (strings) | var | stringList | Entry 0: entity name; entry 2: secondary name (guild etc.) |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 1 | Create/update mentor entity — set name, level, exp, rank fields, online/offline status. Sends CMsgMentorSync (type 0x0812) response. Post 0x494(1) |
| 2 | Create/update student entity — similar to mode 1 but with additional spawn effect fields and team tracking. Sends CMsgMentorSync response. |
| 3 | Simple acknowledgement — post 0x494(1) |
| 4 | Iterate entries starting at +24 with stride 20, populate quiz/rank data. Set ranking fields from +6, +8, +10. |
| 5 | Rank display with timer/count data, multiple UI field updates. Post 0x50A(1) + 0x50F(1) |
| 6 | Status flag check — if hero has status 0x3E, update education score, refresh name board + UI. Post 0x445 + 0x446 |

## CMsgMentorRelation (Type 2067)

**Direction**: S→C
**Wire type**: 2067 (0x0813)
**Create**: `CMsgMentorRelation__Create` @ `0x716106`
**Process**: `CMsgMentorRelation__Process` @ `0x716249`
**Packet object**: Uses `this+1028` for payload ptr and MsgStringList at `this+1032`.

Updates education/mentor relationship status — handles assignment of experience, level, and spawn effects to mentor/student pairs.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2067 |
| +4 | 1 | mode | Action mode (5–8) |
| +16 | 4 | subMode | Mode 6: sub-action (0 = find by name, 1 = find by ID, 2 = direct) |
| +24 | 4 | expValue | Experience/score value to assign |
| +32 | 2 | spawnParam1 | Spawn effect parameter 1 |
| +34 | 2 | spawnParam2 | Spawn effect parameter 2 |
| (strings) | var | stringList | Entry 1: entity name for lookup |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 5 | Direct update: set exp, spawn param 1, spawn param 2 on education mgr. Post 0x49B |
| 6 | Conditional update by sub-mode: find mentor entity (by name or ID), apply exp + spawn effects if not already active |
| 7 | Reset: clear all education mgr relationships (exp=0, spawn params=0) |
| 8 | Signal: post 0x49B(1) — simple UI refresh |

## CMsgQuiz (Type 2068)

**Direction**: S→C
**Wire type**: 2068 (0x0814)
**Create**: `CMsgQuiz__Create` @ `0x71EB16`
**Process**: `CMsgQuiz__Process` @ `0x71EC45`
**Packet object**: Uses `this+1028` for payload ptr and MsgStringList at `this+1032`.

Manages the quiz/trivia minigame — delivers questions, options, scores, and results.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2068 |
| +4 | 1 | mode | Quiz action mode (1, 2, 4, 5, 7) |
| +6 | 2 | param1 | Mode-dependent (timer, rank, etc.) |
| +8 | 2 | param2 | Mode-dependent (score, count) |
| +10 | 2 | param3 | Mode-dependent |
| +12 | 2 | param4 | Mode 1: used for `CQuiz__SetScoreByIndex` calls |
| +14 | 2 | param5 | Mode 1: `CQuiz__SetScoreByIndex` |
| +16 | 2 | param6 | Mode 1: `CQuiz__SetScoreByIndex` |
| +20 | 4 | entryCount | Mode 4: number of quiz entries |
| +24 | var | entries[] | Mode 4: stride-20 entries (16-byte name + 2x u16 scores) |
| (strings) | var | stringList | Mode 2: entries 0–4 = question text, answer options; mode 5: entries 0–1 = timer data |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 1 | Initialize quiz round: set scores, timer, 3 quiz values, post 0x506(1) + 0x51C |
| 2 | Show question: set UI fields, load 5 string list entries (question + 4 options), post 0x50C(1). If `+8` is 1 → post 0x508(1), if 2 → post 0x508(0) |
| 4 | Populate leaderboard: iterate `entryCount` entries (stride 20), set rank + scores. Post ranking UI |
| 5 | Show results: parse timer data from string list, update multiple UI fields, post 0x50A(1) + 0x50F(1) |
| 7 | Set UI fields from `+6` and `+8`. If `+10` is 1 → post 0x508(1), if 2 → post 0x508(0) |

## CMsgQuizSignal (Type 2069)

**Direction**: S→C
**Wire type**: 2069 (0x0815)
**Create**: `CMsgQuizSignal__Create` @ `0x75C8FF`
**Process**: `CMsgQuizSignal__Process` @ `0x75C988`
**Packet object**: Standard layout — payload pointer at `this+257`.

Trivial signal packet — relays a single parameter to the UI.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2069 |
| +4 | 4 | param | Passed as LPARAM to `PostMainWndMsg_0x464(0x509, param)` |

### Processing Logic
Posts `PostMainWndMsg_0x464(0x509, +4)` — signals the quiz UI with the given parameter value.

## CMsgTitleVisual (Type 2070)

**Direction**: S→C
**Wire type**: 2070 (0x0816)
**Create**: `CMsgTitleVisual__Create` @ `0x707C29`
**Process**: `CMsgTitleVisual__Process` @ `0x707CE4`
**Packet object**: Standard layout — payload pointer at `this+1028`.

Applies or removes title/rank visual effects on entities. Uses the title visual asset table at `g_TitleVisualAssetTable`.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2070 |
| +4 | 2 | mode | Action mode (1 or 2) |
| +8 | 4 | titleSlot | Title slot index — used to look up `g_TitleVisualAssetTable[slot]` for the visual asset name |
| +12 | 4 | titleId | Title/rank ID |
| +16 | 4 | entityId | Target entity ID |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 1 | Add title visual: register title via title manager, resolve entity (hero or by ID), load title visual asset from `g_TitleVisualAssetTable[slot]`, attach to entity's render component. Posts 0xCE9 + 0x3FB |
| 2 | Remove title visual: unregister from title manager, resolve entity, remove visual asset from render component. Posts 0xCE9 + 0x3FB |

## CMsgEudemonAttrib (Type 2071)

**Direction**: S→C
**Wire type**: 2071 (0x0817)
**Create**: `CMsgEudemonAttrib__Create` @ `0x75C7EC`
**Process**: `CMsgEudemonAttrib__Process` @ `0x75C875`
**Packet object**: Standard layout — payload pointer at `this+257`.

Updates eudemon (pet/companion) attributes. Checks 8 flag bytes to determine which attribute category to update.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2071 |
| +4 | 4 | eudemonId | Eudemon identifier — first arg to `CHero__SetEudemonAttrib` |
| +8 | 4 | ownerId | Owner entity ID — must match hero to process |
| +12 | 4 | param1 | Second arg to `CHero__SetEudemonAttrib` |
| +16 | 4 | param2 | Third arg to `CHero__SetEudemonAttrib` |
| +20 | 1 | flag0 | If 1 → category = 1 |
| +21 | 1 | flag1 | If 1 → category = 2 |
| +22 | 1 | flag2 | If 1 → category = 3 |
| +23 | 1 | flag3 | If 1 → category = 4 |
| +24 | 1 | flag4 | If 1 → category = 5 |
| +25 | 1 | flag6 | If 1 → category = 7 |
| +26 | 1 | flag5 | If 1 → category = 6 |
| +27 | 1 | flag7 | If 1 → category = 8 (default if none set) |

### Processing Logic
1. If `ownerId` does not match local hero ID → ignore.
2. Scan flags `+20` through `+27` to determine category (1–8). First flag set wins (priority order: +20, +21, +22, +23, +24, +26, +25, +27).
3. Call `CHero__SetEudemonAttrib(eudemonId, param1, param2, category)` to update the eudemon's attributes.

## MsgRaceTrackProp (Type 2072) — class proven by `MsgRaceTrackProp.cpp` assert (CP0.1 2026-11-05); former label `MsgRaceTrackPropSync` withdrawn

**Direction**: S→C
**Wire type**: 2072 (0x0818)
**Create**: `CMsgRaceTrackPropSync__Create` @ `0x74F3E1`
**Process**: `CMsgRaceTrackPropSync__Process` @ `0x74F55B`
**Packet object**: Standard layout — payload pointer at `this+257`.

Synchronises race track prop entities. Creates or updates props in the `CRaceTrackPropMgr` singleton.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2072 |
| +4 | 2 | propType | Prop type/kind ID |
| +6 | 2 | propSubType | Prop sub-type |
| +8 | 4 | entityId | Map entity ID for the prop |

### Processing Logic
1. Validates `entityId != 0` and `propSubType != 0`.
2. Looks up entity via `CRaceTrackPropMgr`:
   - If found and `propType != 0`: update existing prop via `CRaceTrackPropMgr__UpdatePropType(entityId, propType)`.
   - If not found and `propType != 0`: create new prop via `CRaceTrackPropMgr__func_000(entityId, propSubType, propType)`.
   - If `propType == 0`: assertion/debug log.

## CMsgRaceTrackEffect (Type 2073)

**Wire type**: 2073 (0x0819)
**Create**: `CMsgRaceTrackEffect__Create` @ `0x75CB87`
**Process**: `CMsgRaceTrackEffect__Process` @ `0x75CC10`
**Packet object**: Standard layout — payload pointer at `this+257`.

Applies visual effects to race track props. Collects a DWORD list of effect IDs and dispatches to the effect manager.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2073 |
| +4 | 2 | effectType | Effect type ID |
| +6 | 2 | effectCount | Number of DWORD effect entries |
| +8 | 2 | param1 | Effect parameter 1 |
| +10 | 2 | param2 | Effect parameter 2 |
| +12 | 4 | entityId | Target entity ID for the effect |
| +16 | var | effectIds[] | Array of `effectCount` u32 effect IDs |

### Processing Logic
1. Builds a DWORD buffer from `effectCount` entries starting at `+16`.
2. Calls `CRaceTrackPropEffectMgr__func_000(effectType, entityId, param1, param2, effectIdBuffer)` on the effect manager singleton.

## CMsgNonSuch (Type 2077)

**Wire type**: 2077 (0x081D)
**Create**: (0x75B05B)
**Process**: `CMsgNonSuch__Process` @ `0x75B0E4`
**Packet object**: Standard layout — payload pointer at `this+257`.

Manages the "Nonsuch" (unique/special) equipment crafting system. Processes batch operations on items — each entry specifies an action mode and parameters for crafting, upgrading, or removing equipment.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2077 |
| +4 | 4 | entryCount | Number of crafting entries (signed i32) |
| +8 | var | entries[] | Array of entries, stride = 28 bytes each |

### Entry Layout (stride 28, starting at payload +8)

| Entry Offset | Size | Field | Description |
|--------------|------|-------|-------------|
| +0 | 4 | itemUID | Item UID — used to look up item in hero inventory |
| +4 | 4 | mode | Action mode dword (the handler switches on its low byte, 0–9) |
| +8 | 4 | param0 | Mode-dependent (item ID for load, compose value, etc.) |
| +12 | 4 | param1 | Mode-dependent (grade, quality) |
| +16 | 4 | param2 | Mode-dependent (item ID, slot) |
| +20 | 4 | param3 | Mode-dependent (bonus, timestamp) |
| +24 | 4 | param4 | Mode-dependent |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 0, 2 | Sends `CMsgAction(408)`; primary refinement effect id = param0, auxiliary = param1, value = param2, extra/timer field = param3, and records `timeGetTime()`. |
| 1 | Sends `CMsgAction(408)` and resets primary refinement to value 0 / effect -1 / auxiliary -1. |
| 3 | Secondary refinement effect id = param0, auxiliary = param1, value = param2; clears the primary auxiliary field. |
| 4 | Resets primary refinement, applies mode-3 secondary fields, then posts 0xD90. |
| 5 | Loads alternate/soul Itemtype fields from param0 and sets temporary soul item type id (`CItem+0x14`) to param0. Post 0xD5D. |
| 6 | Same soul load/set as mode 5 but flags the full inventory/equipment refresh. |
| 7 | Reloads the permanent soul item type id (`CItem+0x10`) or zero, clears temporary soul id, updates matching equip slots, and posts `NONSUCH_TIME_OUT` / 0xD08. |
| 8 | Permanent soul id = param0, temporary soul id = 0, then loads alternate/soul fields from param0. Flags refresh. |
| 9 | Same soul state mutation as mode 8 + post 0xD92. |

### Notes
- After processing all entries, if any mode flagged a refresh (`v37`), posts 0x3EB + 0x3F7 + 0x3F4 + 0x3F2 + 0x426 + 0x427 for full inventory/equipment UI update.
- Mode 7 iterates equipment slots 1–18 to find and re-equip matching items.
- Max-life effect id is exactly 301. It adds primary value at `CItem+0x1C0` when primary
  effect `+0x1CC == 301`; otherwise it may add secondary value `+0x1D4` when secondary effect
  `+0x1DC == 301` and the **signed** primary effect id is below 100.

## Account-login alert data (Type 2078; formerly labeled CMsgTitleLabel)

**Wire type**: 2078 (0x081E)
**Constructor**: `CMsgAccountLoginAlert2078__Ctor` @ `0x75AFA0`
**Validate/copy**: `CMsgAccountLoginAlert2078__ValidateAndCopy` @ `0x75B006`
**Process**: `CMsgAccountLoginAlert2078__Process` @ `0x75B029`
**Packet object**: payload pointer at byte offset `this+0x404`; buffer at `this+4`.

**Native correction, 2026-09-15:** this packet supplies the account's last-login
time/location alert. The previous title-label names were incorrect analysis labels.
`CDlgAccountLoginAlert_RefreshFromHero` (`0x4189D2`) reads the stored record,
passes the dword to `localtime` at `0x418A9C`, and uses native resource keys
`STR_ACCOUNT_LOGIN`, `STR_ACCOUNT_LOGIN_BGP`, `STR_UNKNOW_CITY` and `STR_ACCOUNT_ALERT`.
Its diagnostic path is `MyShell/DlgAccountLoginAlert.cpp`. Clean `ini/Cn_Res.ini`
lines 801-803 identify the last-login time/city and unusual-location warning.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2078 |
| +4 | 4 | lastLoginTimestamp (formerly titleId) | Stored at hero+0xDE0; consumed as a 32-bit CRT time value |
| +8 | 1 | locationAlert (formerly titleType) | Stored at hero+0xDE4; downstream test is zero versus nonzero |
| +9 | var | lastLoginLocation (formerly titleText) | NUL-terminated ANSI bytes copied into owned char storage at hero+0xDE8 |

### Processing Logic
1. Calls `CHero_SetAccountLoginAlertData` (`0x6577BF`) at `0x75B044`; stores the
   numeric fields unchanged and copies the text using `strlen` at `0x6577E5`.
2. Posts `PostMainWndMsg_0x464(0xD39, 0)` at `0x75B050`.
3. Getter `CHero_GetAccountLoginAlertData` (`0x6577B8`) returns the record to the
   account-login-alert dialog. Timestamp zero or empty hero name skips rebuilding
   its content (`0x418A64/0x418A6D`); failed `localtime` also skips it. A stored
   location length <=1 selects the unknown-city resource in the normal branch.
   Zero timestamp returns before dialog layout resets (`0x418AAD/0x418AB4`):
   this is a skipped rebuild, not proof that previous dialog content is cleared.
   Any nonzero alert byte permits the extra warning when the alternative
   BGP/auth presentation predicate is false (`0x418E5A..0x418E6B`).

The actual equipped character-title field is separate: `1006` calls
`CHero_SetTitleId` (`0x674B56`) at `0x7646D6`, which stores hero+0x8AC.
It does not overwrite this packet's hero+0xDE0 record.

### Parity note
- Login/bootstrap implementations must not model `2078` as a synthetic 260-byte seed blob.
- No fixed retail login timestamp, alert byte, or location string can be recovered
  from these client handlers. The parser checks packet type after common header/copy
  validation, not numeric values. All u32/u8 bit patterns reach storage; that is
  acceptance, not proof of a valid/displayable timestamp or retail server policy.
- Zero timestamp, zero flag and empty NUL-terminated text are accepted and suppress
  this dialog-content rebuild. They are not a native "no character title" encoding.
- `0x75AFA0` zeroes an inbound object before copying received bytes; it does not
  construct a server response or prove that the server sent zero-valued fields.
- The exact retail-server values require a retail packet trace or server evidence.

## CMsgServerState (Type 2079)

**Wire type**: 2079 (0x081F)
**Constructor**: `CMsgServerState2079__Ctor` @ `0x75AEED`
**Validate/copy**: `CMsgServerState2079__ValidateAndCopy` @ `0x75AF53`
**Process**: `CMsgServerState__Process` @ `0x75AF76`
**Packet object**: payload pointer at byte offset `this+0x404`; buffer at `this+4`.

Sets a global consumed by status-UI predicates. Calling it a negotiated protocol
version is not established by the recovered uses.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2079 |
| +4 | 4 | state | State value: 0 → set `g_ServerProtocolState` to 2000; 1 → set to 2001 |

### Processing Logic
- If `state == 0`: `g_ServerProtocolState` (0x93FD78) = 2000
- If `state == 1`: `g_ServerProtocolState` (0x93FD78) = 2001
- Other values: no action.

### Parity note
- The current evidence verifies the meaning of `state == 0` and `state == 1`.
- Clean image bytes at `0x93FD78` are `D0 07 00 00`: initial state is already 2000.
  The only recovered writes are the two Process branches. No session reset was
  found among this global's xrefs; unsupported packet values preserve prior state.
- All five native code xrefs to `0x93FD78` were followed: the two writes above,
  `CHero_CanOpenProtocol2000StatusUi` (`0x662DE5`),
  `CHero_RefreshProtocol2000StatusUi` (`0x662E12`), and the main-window UI branch
  at `0x5C5265`. The predicate has one recovered caller, shell hotkey dispatch
  `0x5D987A`. The refresh helper has calls at `0x7578AD`, `0x764900`, and
  `0x49AFA7`. Its `1006` call occurs **after** the EnterMap send at `0x7648A3`.
- The refresh helper uses unsigned hero thresholds at `+0x838 >=70`,
  `+0x84C >=1`, `+0x10 >=1`, or `+0x14 >=1`. With no threshold met it posts
  `0x44D`; with a threshold met and state 2000 it posts `0x44C`; with a threshold
  met and state 2001 it posts neither. The shell's `0x44C` branch also checks 2000.
- **Exact retail login wire value: unrecoverable from this client evidence.**
  Wire 0 and 1 select defined behaviors; other u32 values are parser-accepted no-ops.
  Initial global 2000 does not prove that a server sends 0. No requirement for
  0 or 1 before `1006` builds/sends EnterMap is present in the traced handlers.

### Successful existing-character login audit, 2026-09-15

The user-provided/working bootstrap order is
`1004 ANSWER_OK / channel 0x835 -> 2078 -> 2079 -> 1006 -> client action 74`.
This audit verifies consumption and dependencies, not a retail-server packet capture.
The old claim that the client waits for the complete four-packet set was unsupported:
`CNetMsg__ProcessMsg` dispatches each received packet through vtable `+0x10`
at `0x6DEC6B`; per-packet validation is invoked at `0x6E136A`.
`CMsgUserInfo__Process` builds action 74 at `0x764873` and calls `CNetMsg__Send`
at `0x7648A3` without checking receipt of 2078/2079 or their values. The ordinary
send callback/connection rules still apply; this is not a claim that arbitrary
packet omission guarantees an otherwise successful login.

The two constructors have recovered code xrefs only from packet dispatch
(`0x6E069C`, `0x6E06C5`). They allocate/reset inbound objects; their zeroed buffers
are overwritten by the wire bytes. The 2078 setter has one recovered caller
(`0x75B044`), its getter one (`0x418A0B`), and the dialog is referenced through
its vtable (`0x846918`). No literal successful-retail-login payload is generated
by this chain. Timestamp, location and risk flag belong to server account history
and policy; the actual 2079 choice also belongs to server policy.

**Corroboration only:** OpenConquerPublic's existing-character processor sends
2078 `(0,0,empty NUL-terminated text)` and 2079 `0`. The user reports native login
and world entry work with this server. These values are consistent with the native
consumer: zero timestamp skips account-alert content rebuild; state 0 selects the
initial 2000 UI behavior. This is not proof that retail servers send the same values.
The working byte sequence/order is preserved; misleading title and mandatory-gate
claims are corrected in the associated project documentation.

**Saved evidence and corrections:** [native exports, xrefs, annotation readbacks,
resource lines and byte verification](../../10_work/docs/evidence/post-auth-2078-2079-5517/README.md).
All 20,445 exported instruction rows in 22 captures match the clean executable
(SHA-256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`).
Native semantic names/comments were read back through MCP; database saves remain
under the user's control.

`10_work` now names the fields as account-login data, initializes the status state
to 2000, preserves it for unsupported wire values and bootstrap reset, and does
not require receipt of these two UI packets in its startup readiness predicate.
OpenConquerPublic uses the corrected `MsgAccountLoginAlert2078.EncodeEmptyHistory`
name while retaining exactly the existing wire values and order. The current
ANSI codec and malformed-packet policies were not changed or claimed as fully
native-equivalent by this investigation.

Validation: 36 focused legacy-client tests and 15 focused server tests passed;
the latter assert the exact 2078/2079 bytes through encrypted framing. These are
managed regression checks. This audit did not run a new native-client login or
capture retail-server traffic, and it does not convert server-policy unknowns
into proven retail defaults.

**Reference comparison completed 2026-09-16:** [Fox 5517, Canyon, Long and the local
server projects](18_post_auth_server_comparison.md) were inspected as hints. The final
claims remain the native input/output behavior, not a reference-derived required
login tuple. Forty bounded native-byte
replays verify candidate packet acceptance and field handling. Fox's fixed 2011
timestamp and larger packet padding are accepted alternatives, not required
values. Canyon's location-byte boolean and the references' extra 2079 dword must
not be imported as additional 5517 field semantics. Full source provenance,
scope limits and the existing server bytes are recorded in that comparison.

## CMsgChangeName (Type 2080)

**Wire type**: 2080 (0x0820)
**Create**: `CMsgChangeName__Create` @ `0x74B5AE`
**Process**: `CMsgChangeName__Process` @ `0x74B6A1`
**Packet object**: Standard layout — payload pointer at `this+257`.

Handles name change request results — displays success/failure messages and updates related UI state.

### Struct Layout (payload buffer)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| +0 | 2 | size | Packet size |
| +2 | 2 | type | 2080 |
| +4 | 2 | mode | Result mode (1–4) |
| +6 | 2 | param1 | Mode 3: value for singleton field 0x4 |
| +8 | 2 | param2 | Mode 3: value for singleton field 0x8 |

### Mode Behaviour

| Mode | Description |
|------|-------------|
| 1 | Success: load string "StrChangeNameOk", display via `CMessageBoxMgr__ShowFormattedMessage`. Post 0xDCE + 0xDD9 |
| 2 | Denied: load string "StrChangeNameDeny", display via `CMessageBoxMgr__ShowFormattedMessage` |
| 3 | Set parameters: update singleton (0x431D1D) fields 0x4 and 0x8 from `param1` and `param2`. Post 0xDCF |
| 4 | Signal: post 0xDD8 |

## CMsgArenaChallenge (Type 2210)

**Wire type**: 2210 (0x08A2)
**Create**: `CMsgArenaChallenge__Create` @ `0x71C382`
**Process**: `CMsgArenaChallenge__Process` @ `0x71C40B`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Arena challenge notification. Allocates a 0x20 challenge info object, populates it with two player names (strings at +8 and +32), two entity IDs (DWORDs at +24 and +48), and a challenge ID (DWORD at +4). Calls `sub_667462` to register the challenge with the hero system, checks `sub_675D46` to determine if arena UI is active (posts 0xBE9 if so). Delivers the challenge object via post 0xC23.

| Offset | Size | Field |
|--------|------|-------|
| +4 | DWORD | Challenge ID / initiator entity ID |
| +8 | 24 bytes | Player 1 name (null-terminated string) |
| +24 | DWORD | Player 1 score/rank |
| +28 | DWORD | Player 2 entity ID |
| +32 | 16 bytes | Player 2 name (null-terminated string) |
| +48 | DWORD | Player 2 score/rank |

## CMsgBattleObserver (Type 2211)

**Wire type**: 2211 (0x08A3)
**Create**: `CMsgBattleObserver__Create` @ `0x6E6CB6`
**Process**: `CMsgBattleObserver__Process` @ `0x6E6E4B`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Battle observer/spectator control. Dispatches on WORD[+4] mode:

| Mode | Description |
|------|-------------|
| 0 | Disable observer mode: sets hero observer flag off via `sub_675D39(1)` |
| 1 | Exit observer + refresh: calls `sub_675D39(0)`, posts 0xBEA |
| 2 | Populate arena: calls `sub_6674F1` to clear hero state, sets arena IDs via `sub_66744B(DWORD[+18], DWORD[+22])`. Iterates DWORD[+14] player entries at stride-36 starting at +30, adds each via `CHero__AddStringToMap`. Posts 0xBE9/0xBEC/0xC90/0xC9E depending on arena type |
| 3 | Same as mode 1: exit observer + post 0xBEA |
| 4 | Chat message: formats "StrBattleObserver" string with player names from +58 and +26, displays in system chat (channel 2005, red color) |

## CMsgFamilyArena (Type 2212)

**Wire type**: 2212 (0x08A4)
**Create**: `CMsgFamilyArena__Create` @ `0x704C32`
**Process**: `CMsgFamilyArena__Process` @ `0x704D2A`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Family arena master control packet. Dispatches on WORD[+4] mode (1-13):

| Mode | Description |
|------|-------------|
| 1 | Open arena UI: posts 0xC36 + 0xC3D |
| 2 | Setup arena display: calls `CAsyncMonikerFile::SetFormatEtc`, posts 0xC36 with param 1 |
| 3 | Display system message: loads "StrFamilyAreni" string, shows in chat (red, channel 2005), posts 0xC36 with param 0 |
| 4 | Arena status: DWORD[+8] controls sub-mode (0-5): sets arena phase via `sub_698340`. Posts 0xC35 |
| 6 | Arena result: DWORD[+8] selects arena phase. Posts 0xC36 + 0xC33 |
| 7 | System notification: loads "StrFamilyAreni_0" string, displays in chat |
| 8 | Close arena: posts 0xC36 + 0xC14 + 0xC37 |
| 9 | Victory/failure: plays "SportsVictory" or "SportsFailure" screen effect based on DWORD[+8] == 1 |
| 10 | Open with winner flag: posts 0xC36 + 0xC33 + 0xC3D with WORD[+8] encoded in param |
| 13 | Same as mode 10: posts 0xC36 + 0xC33 |

## CMsgFamilyArenaRoster (Type 2213)

**Wire type**: 2213 (0x08A5)
**Create**: `CMsgFamilyArenaRoster__Create` @ `0x7054BE`
**Process**: `CMsgFamilyArenaRoster__Process` @ `0x705594`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Populates the family arena team roster. Only processes when WORD[+20] == 0. Sets arena map position via `sub_63AE41(DWORD[+4]-1, DWORD[+8]-1)`, sets goal via `sub_6844D2(DWORD[+12])`, sets a display ID via `CObject__SetDword_0x10(DWORD[+16])`, clears roster via `CFamilyArenaMgr__func_000`.

Iterates DWORD[+24] entries at stride-80 starting at +28. Each entry contains:
- DWORD at +0: team ID
- String at +4 (16 bytes): player name 1
- DWORD at +20: score 1
- String at +24 (16 bytes): player name 2
- DWORD at +40: score 2
- DWORD at +60: additional ID
- String at +44 (16 bytes): player name 3
- String at +64 (16 bytes): player name 4

Adds each entry via `sub_698126`. Posts 0xC3B.

## CMsgFamilyArenaBracket (Type 2214)

**Wire type**: 2214 (0x08A6)
**Create**: `CMsgFamilyArenaBracket__Create` @ `0x70574F`
**Process**: `CMsgFamilyArenaBracket__Process` @ `0x7057F9`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Updates the family arena match bracket/schedule. Clears existing bracket via `sub_698145`. Iterates DWORD[+8] entries at stride-24 starting at +16. Each entry contains a DWORD ID at +0 and a string name at +4. Adds each via `sub_69810B(WORD index, entry)`. Sets round/phase info via `sub_6982A0(WORD[+4], WORD[+6])`. Posts 0xC3C.

## CMsgFamilyArenaRanking (Type 2215)

**Wire type**: 2215 (0x08A7)
**Create**: `CMsgFamilyArenaRanking__Create` @ `0x70535C`
**Process**: `CMsgFamilyArenaRanking__Process` @ `0x70540B`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Updates the family arena ranking list. Clears existing via `sub_69813D`. Iterates DWORD[+4] entries at stride-16 starting at +8. Each entry contains a string name. Adds each via `sub_6980A0(rank, entry)` where rank is 1-based. Posts 0xC3A.

## CMsgFamilyArenaMatchInfo (Type 2216)

**Wire type**: 2216 (0x08A8)
**Create**: `CMsgFamilyArenaMatchInfo__Create` @ `0x705171`
**Process**: `CMsgFamilyArenaMatchInfo__Process` @ `0x705220`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Delivers detailed family arena match information. Clears previous state via `sub_6982B1`. Loads 11 DWORDs of match data from offsets +4 through +44 (scores, IDs, round info) plus a string name at +49. Sets match data via `sub_698091`, sets active flag via `sub_69830B(BYTE[+48] != 0)`.

DWORD[+8] controls arena phase (0-5): sets phase via `sub_698340` with corresponding sub-mode. Posts 0xC35 + 0xC2B.

## CMsgFamilyArenaChallenge (Type 2217)

**Wire type**: 2217 (0x08A9)
**Create**: `CMsgFamilyArenaChallenge__Create` @ `0x704FC3`
**Process**: `CMsgFamilyArenaChallenge__Process` @ `0x70504C`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Family arena specific challenge notification. Allocates a 0x38 challenge object, populates with 4 strings (player/family names at +8, +24, +48, +64) and 2 DWORDs (+40, +80). Calls `sub_667462` to register the challenge. Posts 0xBE9 (if arena UI active) and 0xC32.

## CMsgElitePKArena (Type 2218)

**Wire type**: 2218 (0x08AA)
**Create**: `CMsgElitePKArena__Create` @ `0x75A35C`
**Process**: `CMsgElitePKArena__Process` @ `0x75A3C2`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Elite PK arena state control. Dispatches on WORD[+4] mode:

| Mode | Description |
|------|-------------|
| 1 | Open elite PK UI: posts 0xC89 |
| 2 | Setup arena: posts 0xC1D + 0xC14, enables arena via `sub_69A58F(1)`, posts 0xC24, sets round via `sub_691905(WORD[+44])`, posts 0xC8D with param 1 |
| 3 | Match result: plays "SportsVictory" or "SportsFailure" screen effect based on DWORD[+8] == 1 |
| 4 | Disable arena: calls `sub_69A58F(0)`, posts 0xC8D with param 0 |
| 5 | Enable arena: calls `sub_69A58F(1)` |

## CMsgElitePKGame (Type 2219)

**Wire type**: 2219 (0x08AB)
**Create**: `CMsgElitePKGame__Create` @ `0x6DE376`
**Process**: `CMsgElitePKGame__Process` @ `0x6DE4F0`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Elite PK tournament game state — the most complex handler in this batch. WORD[+4] selects the outer mode (0-6), and WORD[+16] (sub-mode) further refines behavior within some modes.

**Mode 0**: posts 0xC86 with WORD[+14] param.

**Mode 1**: Updates score entries. Iterates WORD[+28] entries at stride-30, increments score for type-3 entries. Sub-mode (WORD[+16]) selects which `CElitePKGameMgr` update function to call (5-8 map to different bracket stages, <5 → `sub_6912DA`).

**Mode 2**: Loads player list. Calls `sub_691327(WORD[+14])` to set group, iterates DWORD[+20] entries at stride-50 via `sub_691263`. If sub-mode > 5, loads extended entries via `sub_691A45` and calls `CElitePKGameMgr__func_004`.

**Mode 3 (and mode 0 fallback)**: Timer/countdown. Calls `CElitePKGameMgr__func_007` + `CElitePKGameMgr__func_008` with timestamp. Sub-modes 3-7 each manage different bracket display phases with stride-50 player entries.

**Mode 4**: Timer set (same as mode 3 core).

**Mode 5**: Boolean flag: calls `sub_685DA1(DWORD[+20] != 0)`.

**Mode 6**: Not present, falls through.

Posts 0xC84/0xC85/0xC86/0xC87/0xC8B depending on state. If WORD[+4] == 3, also posts 0xC8B with WORD[+14].

## CMsgDetainedItemList (Type 2220)

**Wire type**: 2220 (0x08AC)
**Create**: `CMsgDetainedItemList__Create` @ `0x74EA42`
**Process**: `CMsgDetainedItemList__Process` @ `0x74EB02`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Populates the detained (confiscated) item list. Only processes mode 1 (WORD[+4] == 1). Clears existing list via `sub_6AA5E6`. Iterates DWORD[+12] entries at stride-64 starting at +32. Each entry contains:
- DWORD at +0: item ID
- DWORD at +4: item count/quantity
- String at +8 (16 bytes): owner name
- DWORD at +44: additional ID

Adds each via `sub_6AA5F4`. Sets total count via `MFC__SetDword_0x4(DWORD[+8])`. Posts 0xCB8.

## CMsgServerPKToggle (Type 2221)

**Wire type**: 2221 (0x08AD)
**Create**: `CMsgServerPKToggle__Create` @ `0x75A4EF`
**Process**: `CMsgServerPKToggle__Process` @ `0x75A578`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Toggles server-wide PK (player-killing) permission. Reads WORD[+8]: if 0, PK is forbidden; otherwise PK is open. Reads previous state via `sub_660768`, sets new state via `sub_66076F`. Only displays a message if the state actually changed:
- PK forbidden: shows "StrServerForbidPK" in system chat (red, channel 2005)
- PK open: shows "StrServerOpenPK" in system chat (red, channel 2005)

## CMsgElitePKChallenge (Type 2222)

**Wire type**: 2222 (0x08AE)
**Create**: `CMsgElitePKChallenge__Create` @ `0x75A236`
**Process**: `CMsgElitePKChallenge__Process` @ `0x75A2BF`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Elite PK challenge notification. Clears previous challenge data via `sub_691891`, loads two player entries from payload +4 and +28 (each 24 bytes: DWORD ID + string name) via `sub_69187F`. Calls `sub_691912` to finalize, then registers challenge via `sub_667462` with player names, IDs, and scores from offsets +8/+4/+32/+28/+24/+48. Posts 0xBE9 (if arena UI active) and 0xC8E.

## CMsgElitePKPlayerList (Type 2223)

**Wire type**: 2223 (0x08AF)
**Create**: `CMsgElitePKPlayerList__Create` @ `0x72E552`
**Process**: `CMsgElitePKPlayerList__Process` @ `0x72E616`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Elite PK player list management. Dispatches on WORD[+4] mode:

**Modes 0-1: Load player list**
- Sets group via `sub_690FAE(DWORD[+8])`
- Iterates DWORD[+16] entries at stride-36 starting at +20
- For entries where DWORD[+12] > 3 or <= 0, assigns auto-incrementing rank (starting at 4)
- Adds each via `sub_690FD3(DWORD[+8], entry)`
- Sets total via `CElitePKGameMgr__func_002(DWORD[+8], DWORD[+16])`
- Posts 0xC85 with DWORD[+8]

**Mode 2: Load results**
- Clears via `sub_691857(DWORD[+8])`
- Iterates DWORD[+16] entries at stride-36 via `sub_6917DD`
- Sets phase via `CElitePKGameMgr__func_004(DWORD[+8], DWORD[+12])`
- Posts 0xC8B with DWORD[+8]

## CMsgWarFlag (Type 2224)

**Wire type**: 2224 (0x08B0)
**Create**: `CMsgWarFlag__Create` @ `0x74BA9B`
**Process**: `CMsgWarFlag__Process` @ `0x74BB60`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

War flag system — manages guild war flag positions, escorts, rankings, and state. If DWORD[+12] is set, processes flag position data (3 coordinate pairs from +16 at stride-4) and sends to the war flag manager via `sub_6D1B5E`.

Dispatches on WORD[+4] mode (0-13):

| Mode | Description |
|------|-------------|
| 0 | Signal: posts 3537 with param 1 |
| 1 | Load flag ranking: clears via `sub_6D19E9`, checks map area via `sub_620567`. Iterates WORD[+28] entries at stride-24 from +40 (tile name + DWORD position). Queries game data for tile type, builds ranking list via `sub_6D19F1`. Posts 3539 |
| 2 | Load flag score: clears via `sub_6D191D`. Iterates WORD[+28] entries at stride-24 (same format). Builds score list via `sub_6D1925`. Posts 3539 |
| 3 | Update flag positions: iterates WORD[+28] coordinate pairs at stride-4, processes via `sub_74C01D`. Updates war flag display via `sub_6D1A9D` |
| 5 | Param relay: posts 3278 with DWORD[+8] |
| 6 | Flag escort effect (type B): finds entity by DWORD[+8], sets "WarFlagEscortB" effect on entity's component |
| 7 | Flag escort effect (type S): finds entity by DWORD[+8], sets "WarFlagEscortS_1" effect. If local hero, shows "StrWarFlagEscort" chat message |
| 8 | Param relay: posts 3280 with DWORD[+8] |
| 9 | Signal: posts 3538 |
| 10 | Clear war flag: calls `sub_6D1B9D`, posts 3279 |
| 11 | Flag state: posts 3541 with BYTE[+8] |
| 12 | Single flag update: calls `sub_6D1D64(DWORD[+8], WORD[+32], WORD[+34])` |
| 13 | Toggle game mode: sets `GetSingletonPtr_43C8C8` DWORD_0x4 to (BYTE[+8] == 0) + 1 |

## CMsgGuildWarScore (Type 2225)

**Wire type**: 2225 (0x08B1)
**Create**: `CMsgGuildWarScore__Create` @ `0x74D26B`
**Process**: `CMsgGuildWarScore__Process` @ `0x74D3E6`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Simple guild war score/rank update. Calls `sub_696A92` with a string from payload +8 and a DWORD from +268 (score value). Posts 0xCDC.

## CMsgGuildWarRoster (Type 2226)

**Wire type**: 2226 (0x08B2)
**Create**: `CMsgGuildWarRoster__Create` @ `0x74CF8B`
**Process**: `CMsgGuildWarRoster__Process` @ `0x74D04A`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Guild war roster/participant list. If BYTE[+16] is set, clears existing roster via `sub_69690E`. Sets roster metadata via `sub_69696A(DWORD[+4], DWORD[+12])`.

Iterates DWORD[+8] entries at stride-344 starting at +24. Each entry is a large structure containing:
- DWORD at +0: guild ID
- String at +4 (16 bytes): guild name
- String at +295 (24 bytes): leader name
- String at +259 (24 bytes): additional name
- DWORD at +320/+324: score fields
- WORD fields at +352-+360: rank/status data
- BOOL at +352: active flag
- WORD at +354/+356/+358/+360: additional stats

Adds each entry via `sub_6968FF`. Posts 0xCDB.

## TeamPK / Team Arena / Team Pop PK Packet Types

These 16 packet types handle the TeamPK (team player-killing), Team Arena, and Team Pop PK competitive subsystems. They cover match setup, challenge notifications, game state progression, ranking displays, and award/result screens.

### TeamPK / Team Arena / Team Pop PK Type Registry

| Type | Hex | Name | Create Addr | Process Addr |
|------|-----|------|-------------|--------------|
| 2230 | 0x08B6 | CMsgTeamPKAward | 0x759ECA | 0x759F53 |
| 2231 | 0x08B7 | CMsgTeamPKChallenge | 0x75A110 | 0x75A199 |
| 2232 | 0x08B8 | CMsgTeamPKGame | 0x6E267E | 0x6E27F8 |
| 2233 | 0x08B9 | CMsgTeamPKRanking | 0x72E342 | 0x72E406 |
| 2240 | 0x08C0 | CMsgTeamPKDominateTeamName | 0x729704 | 0x7297B3 |
| 2241 | 0x08C1 | CMsgTeamArenaHero | 0x751C46 | 0x751D24 |
| 2242 | 0x08C2 | CMsgTeamArenaSchedule | 0x75272B | 0x7527E1 |
| 2243 | 0x08C3 | CMsgTeamArenaRankPage | 0x752250 | 0x7522FF |
| 2244 | 0x08C4 | CMsgTeamArenaRankList | 0x75207E | 0x752120 |
| 2245 | 0x08C5 | CMsgTeamArenaState | 0x752487 | 0x752529 |
| 2246 | 0x08C6 | CMsgTeamArenaChallenge | 0x752D26 | 0x752DAF |
| 2247 | 0x08C7 | CMsgTeamArenaPlayerInfo | 0x75297F | 0x752A2C |
| 2250 | 0x08CA | CMsgTeamPopPKAward | 0x759BFB | 0x759C84 |
| 2251 | 0x08CB | CMsgTeamPopPKChallenge | 0x759E41 | 0x75A199 |
| 2252 | 0x08CC | CMsgTeamPopPKGame | 0x6E2D6C | 0x6E2EE6 |
| 2253 | 0x08CD | CMsgTeamPopPKRanking | 0x72E132 | 0x72E1F6 |

## CMsgTeamPKAward (Type 2230)

**Wire type**: 2230 (0x08B6)
**Create**: `CMsgTeamPKAward__Create` @ `0x759ECA`
**Process**: `CMsgTeamPKAward__Process` @ `0x759F53`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Pre-game and post-game award/status packet for the TeamPK subsystem. Dispatches on WORD[+4] action subtype (values 2-9). Action 2 opens the TeamPK game UI (posts 0xC1D, 0xC14, 0xC24), starts the `TeamPKGameMgr`, sets the round from WORD[+44], and posts 0xC9A(1) and 0xC98(0). Action 3 plays a full-screen victory or failure effect based on DWORD[+8] (1 = "SportsVictory", else = "SportsFailure"). Action 4 falls through to action 6 logic (disable TeamPK mode). Action 5 sets `TeamPKGameMgr` mode to 1. Action 6 checks if DWORD[+12] matches the local hero entity ID (hero offset 0xCC = 51*4); if so, disables TeamPK mode (set to 0) and posts 0xC9A(0). Action 7 posts 0xC92 and sets mode to 0. Action 8 shows a formatted message box using string resource "STR_TEAM_AWARD_PR...". Action 9 posts 0xC98(0) to close the TeamPK dialog.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action subtype (2-9) |
| +8 | DWORD | Result flag (1 = victory, else = failure; used by action 3) |
| +12 | DWORD | Entity ID (compared against local hero; used by action 6) |
| +44 | WORD | Round number (used by action 2) |

## CMsgTeamPKChallenge (Type 2231)

**Wire type**: 2231 (0x08B7)
**Create**: `CMsgTeamPKChallenge__Create` @ `0x75A110`
**Process**: `CMsgTeamPKChallenge__Process` @ `0x75A199`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

TeamPK challenge notification. The process handler is shared with `CMsgTeamPopPKChallenge` (type 2251). Clears existing `TeamPKGameMgr` state, then adds two team name entries from payload (team 1 at +4, team 2 at +64, each a 60-byte block). Calls `sub_667462` to register the challenge with the hero system using: name1 at +28, entityID1 as DWORD at +4, name2 at +88, entityID2 as DWORD at +64, plus score DWORDs at +60 and +120. Checks if the arena UI is active via `sub_675D46` (posts 0xBE9 if so). Posts 0xC99.

| Offset | Size | Field |
|--------|------|-------|
| +4 | 60 bytes | Team 1 block (DWORD entityID at +0, string name at +24, DWORD score at +56) |
| +64 | 60 bytes | Team 2 block (DWORD entityID at +0, string name at +24, DWORD score at +56) |

## CMsgTeamPKGame (Type 2232)

**Wire type**: 2232 (0x08B8)
**Create**: `CMsgTeamPKGame__Create` @ `0x6E267E`
**Process**: `CMsgTeamPKGame__Process` @ `0x6E27F8`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Primary TeamPK game state packet with a large multi-path handler. Dispatches on WORD[+4] action type. Action 0 posts 0xC9B with WORD[+14] (team group ID). Action 1 performs an inner switch on WORD[+16] (sub-actions 5, 6, 7, 8, and <5) to update `TeamPKGameMgr` team member data. Action 2 (combined with action 0 path) posts 0xC98 and updates game timer info; if WORD[+16] == 4 and DWORD[+6] == 0, clears and re-populates team entries (stride 154 bytes from +24), then sets game round and phase via `func_010`/`func_005`. Action 3 behaves similarly to action 2 but always posts 0xC93. Action 4 updates timer only via `func_008`/`func_009`. Action 5+ updates rankings with team entry data at +6 (stride 154 per entry, count at DWORD[+20]); if DWORD[+6] == 1 and count >= 2, sets up head-to-head display. Action 6 toggles via `sub_685DA1` based on whether DWORD[+20] != 0.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (0-6) |
| +6 | DWORD | Context / game state flag |
| +14 | WORD | Team group ID (used by action 0) |
| +16 | WORD | Phase / sub-action (used by actions 1, 2) |
| +20 | DWORD | Entry count (used by actions 5+, 6) |
| +24 | variable | Team entries array (stride 154 bytes per entry) |

## CMsgTeamPKRanking (Type 2233)

**Wire type**: 2233 (0x08B9)
**Create**: `CMsgTeamPKRanking__Create` @ `0x72E342`
**Process**: `CMsgTeamPKRanking__Process` @ `0x72E406`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

TeamPK ranking display packet. Dispatches on WORD[+4] action type. Actions 0 and 1 initialize the ranking display via `sub_6C9D02(DWORD[+8])`, then iterate DWORD[+16] entries (stride 44 bytes from +20). Rank values greater than 3 or less than or equal to 0 are normalized to sequential IDs. Each entry is added via `func_002`, total count is set via `func_003`, and posts 0xC94 with DWORD[+8]. Action 2 clears state via `sub_6CA69C(DWORD[+8])`, iterates entries via `func_012`, updates phase via `func_005(DWORD[+8], DWORD[+12])`, and posts 0xC93.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (0 = set rankings, 1 = set rankings, 2 = update scores) |
| +8 | DWORD | Group ID |
| +12 | DWORD | Phase (used by action 2) |
| +16 | DWORD | Entry count |
| +20 | variable | Ranking entries array (stride 44 bytes per entry) |

## CMsgTeamPKDominateTeamName (Type 2240)

**Wire type**: 2240 (0x08C0)
**Create**: `CMsgTeamPKDominateTeamName__Create` @ `0x729704`
**Process**: `CMsgTeamPKDominateTeamName__Process` @ `0x7297B3`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Dominate team name assignment and notification. Dispatches on WORD[+4] action type (0-3). Action 0 sets the local hero's dominate team name from the string at +12 and posts 0xC97. Action 1 sets the hero's team name from +12, writes DWORD[+8] via `sub_6755BC`, and shows system chat message "STR_DOMINATE_TEA_0". Action 2 shows the system chat message "STR_DOMINATE_TEA" (domination success notification). Action 3 posts 0xC98(0) to close the dialog.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (0-3) |
| +8 | DWORD | Value / team data (used by action 1) |
| +12 | char[] | Team name (null-terminated string) |

## CMsgTeamArenaHero (Type 2241)

**Wire type**: 2241 (0x08C1)
**Create**: `CMsgTeamArenaHero__Create` @ `0x751C46`
**Process**: `CMsgTeamArenaHero__Process` @ `0x751D24`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Team arena hero state control. Very large handler with nested switches on WORD[+4] (outer action) and DWORD[+8] (inner state).

| Action | Description |
|--------|-------------|
| 1 | Open team arena UI: posts 0xD11(0), 0xD16(0) |
| 2 | Show chat message "STR_TEAM_ARENA_RI..." |
| 3 | Inner state machine for match phases (0-5) with timer management via `GetTickCount`. Sets competition state pairs (indices 10, 11) via `sub_6C7B54` |
| 6 | Inner state 0-5 with timer/competition progression, posts 0xD0F(3) |
| 7 | Show system chat "STR_TEAM_ARENA_HE..." |
| 8 | Open team arena UI: posts 0xD11, 0xC14, 0xD17(1) |
| 9 | Play victory/failure screen effect based on DWORD[+8] (1 = "SportsVictory", else = "SportsFailure") |
| 10 | Posts 0xD11(0), sets WORD[+8] into 0xD16 high word with low byte = 1, posts 0xD19(0) |
| 13 | Posts 0xD11(0), 0xD19(0) |

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (1, 2, 3, 6, 7, 8, 9, 10, 13) |
| +8 | DWORD | State / match phase / result flag |

## CMsgTeamArenaSchedule (Type 2242)

**Wire type**: 2242 (0x08C2)
**Create**: `CMsgTeamArenaSchedule__Create` @ `0x75272B`
**Process**: `CMsgTeamArenaSchedule__Process` @ `0x7527E1`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Populates the team arena match schedule display. If DWORD[+12] == 0, resets the display (clears entries, sets page to 1, sets total to 1, marks DWORD[+16]). If DWORD[+12] != 0, calculates pages from DWORD[+4] and DWORD[+12], then populates entries. Each entry is 48 bytes starting at +24, containing 12 DWORDs plus two name strings. Posts 0xD0F(2).

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Total matches |
| +8 | DWORD | Unknown |
| +12 | DWORD | Current index (0 = reset display) |
| +16 | DWORD | Display info / flags |
| +20 | DWORD | Entry count |
| +24 | variable | Schedule entries array (stride 48 bytes per entry) |

## CMsgTeamArenaRankPage (Type 2243)

**Wire type**: 2243 (0x08C3)
**Create**: `CMsgTeamArenaRankPage__Create` @ `0x752250`
**Process**: `CMsgTeamArenaRankPage__Process` @ `0x7522FF`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Paginated team arena rank listing display. If WORD[+6] == 0, resets the display. If WORD[+6] != 0, calculates pages from WORD[+4] and WORD[+6], then populates entries (stride 40 from +12). Each entry contains DWORD at +16 (entity ID), DWORDs at +12 and +8 (stat fields), a string at +21 (name), and a byte at +20 (flag). Posts 0xD10(0).

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Total pages |
| +6 | WORD | Current page (0 = reset display) |
| +8 | DWORD | Entry count |
| +12 | variable | Rank entries array (stride 40 bytes per entry) |

## CMsgTeamArenaRankList (Type 2244)

**Wire type**: 2244 (0x08C4)
**Create**: `CMsgTeamArenaRankList__Create` @ `0x75207E`
**Process**: `CMsgTeamArenaRankList__Process` @ `0x752120`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Team arena rank list with detailed stats per entry. Clears existing list via `sub_6C7D25`, then iterates DWORD[+4] entries (stride 44 from +8). Each entry contains a name string at +0 (20 bytes), followed by 7 DWORD stat fields. The score DWORD at +28 is decomposed as: `/10000 % 1000` = rank, `/1000 % 10` = tier. Posts 0xD0F(1).

| Offset | Size | Field |
|--------|------|-------|
| +4 | DWORD | Entry count |
| +8 | variable | Rank entries array (stride 44 bytes: char name[20] + 7 DWORDs) |

Entry sub-layout (44 bytes per entry):

| Entry Offset | Size | Field |
|--------------|------|-------|
| +0 | 20 bytes | Player/team name (null-terminated string) |
| +16 | DWORD | Stat field 1 |
| +20 | DWORD | Stat field 2 |
| +24 | DWORD | Stat field 3 |
| +28 | DWORD | Composite score (rank = /10000 % 1000, tier = /1000 % 10) |
| +32 | DWORD | Stat field 5 |
| +36 | DWORD | Stat field 6 |
| +40 | DWORD | Stat field 7 |

## CMsgTeamArenaState (Type 2245)

**Wire type**: 2245 (0x08C5)
**Create**: `CMsgTeamArenaState__Create` @ `0x752487`
**Process**: `CMsgTeamArenaState__Process` @ `0x752529`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Arena state and timer update with competition progression. Clears state via `sub_6C7B44`, then sets 8 state values via `sub_6C7B54(index, value)` for indices 2-9 sourced from payload DWORDs at +4, +36, +20, +24, +12, +16, +28, +32. Then switches on DWORD[+8] (match phase 0-5) with timer management via `GetTickCount`. Posts 0xD0F(0), 0xD0F(3), 0xC2B(0).

| Offset | Size | Field |
|--------|------|-------|
| +4 | DWORD | Phase info (state index 2) |
| +8 | DWORD | Match phase (0-5, controls timer/phase switch) |
| +12 | DWORD | Value 1 (state index 6) |
| +16 | DWORD | Value 2 (state index 7) |
| +20 | DWORD | Value 3 (state indices 4, 5) |
| +24 | DWORD | Value 4 (state index 5) |
| +28 | DWORD | Value 5 (state index 8) |
| +32 | DWORD | Value 6 (state index 9) |
| +36 | DWORD | Value 7 (state index 3) |

## CMsgTeamArenaChallenge (Type 2246)

**Wire type**: 2246 (0x08C6)
**Create**: `CMsgTeamArenaChallenge__Create` @ `0x752D26`
**Process**: `CMsgTeamArenaChallenge__Process` @ `0x752DAF`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Team arena challenge notification — structurally very similar to `CMsgTeamPKChallenge` (type 2231). Calls `sub_667462` to register the challenge with two player sets: name at +12/+40, IDs at +8/+36, scores at +28/+56. Checks if arena UI is active via `sub_675D46` (posts 0xBE9 if so). Initializes the team arena challenge display and posts 0xD1A(0).

| Offset | Size | Field |
|--------|------|-------|
| +4 | DWORD | Entity ID 1 |
| +8 | DWORD | Unknown 1 |
| +12 | 16 bytes | Player/team name 1 (null-terminated string) |
| +28 | DWORD | Score 1 |
| +32 | DWORD | Entity ID 2 |
| +36 | DWORD | Unknown 2 |
| +40 | 16 bytes | Player/team name 2 (null-terminated string) |
| +56 | DWORD | Score 2 |

## MsgTeamArena (Type 2247) — class proven by `MsgTeamArena.cpp` assert (CP0.1 2026-11-05); former label `MsgTeamArenaPlayerInfo` withdrawn

**Wire type**: 2247 (0x08C7)
**Create**: `CMsgTeamArenaPlayerInfo__Create` @ `0x75297F`
**Process**: `CMsgTeamArenaPlayerInfo__Process` @ `0x752A2C`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Populates team arena player and team info display. Requires DWORD[+8] != 0 (asserted). Dispatches on WORD[+4] action type. Action 0 sets the current team ID to DWORD[+8]; if DWORD[+12] == 0, shows chat message "STR_TEAM_ARENA_QU_0". Iterates DWORD[+12] entries (stride 40 from +16), finds the matching team by DWORD[+8], populates player stats, and posts 0xD0F(4). Action 1 clears and re-populates the secondary team view, then posts 0xD15(0).

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (0 = set main team, 1 = set secondary team) |
| +6 | DWORD | Padding / alignment |
| +8 | DWORD | Team ID (must be non-zero) |
| +12 | DWORD | Entry count |
| +16 | variable | Player entries array (stride 40 bytes per entry) |

## CMsgTeamPopPKAward (Type 2250)

**Wire type**: 2250 (0x08CA)
**Create**: `CMsgTeamPopPKAward__Create` @ `0x759BFB`
**Process**: `CMsgTeamPopPKAward__Process` @ `0x759C84`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Near-identical to `CMsgTeamPKAward` (type 2230) but for the ranked/pop TeamPK variant. Same dispatch on WORD[+4] action subtype (values 2-9) with the same handler logic. The only difference is action 7, which posts 0xD9F instead of 0xC92.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action subtype (2-9) |
| +8 | DWORD | Result flag (1 = victory, else = failure; used by action 3) |
| +12 | DWORD | Entity ID (compared against local hero; used by action 6) |
| +44 | WORD | Round number (used by action 2) |

## CMsgTeamPopPKChallenge (Type 2251)

**Wire type**: 2251 (0x08CB)
**Create**: `CMsgTeamPopPKChallenge__Create` @ `0x759E41`
**Process**: `CMsgTeamPKChallenge__Process` @ `0x75A199`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Pop/ranked TeamPK challenge notification. Shares the identical `CMsgTeamPKChallenge__Process` handler at `0x75A199` with `CMsgTeamPKChallenge` (type 2231). Payload and processing logic are identical to type 2231.

| Offset | Size | Field |
|--------|------|-------|
| +4 | 60 bytes | Team 1 block (DWORD entityID at +0, string name at +24, DWORD score at +56) |
| +64 | 60 bytes | Team 2 block (DWORD entityID at +0, string name at +24, DWORD score at +56) |

## CMsgTeamPopPKGame (Type 2252)

**Wire type**: 2252 (0x08CC)
**Create**: `CMsgTeamPopPKGame__Create` @ `0x6E2D6C`
**Process**: `CMsgTeamPopPKGame__Process` @ `0x6E2EE6`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Near-identical to `CMsgTeamPKGame` (type 2232) but for the ranked/pop TeamPK variant. Same action structure based on WORD[+4] with minor window message differences: action 0 posts 0xDA1 instead of 0xC9B; actions 1 and final paths post 0xDA3 instead of 0xC93; action 3 paths post 0xDA0/0xD9E instead of 0xC9D/0xC9C.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (0-6) |
| +6 | DWORD | Context / game state flag |
| +14 | WORD | Team group ID (used by action 0) |
| +16 | WORD | Phase / sub-action (used by actions 1, 2) |
| +20 | DWORD | Entry count (used by actions 5+, 6) |
| +24 | variable | Team entries array (stride 154 bytes per entry) |

## CMsgTeamPopPKRanking (Type 2253)

**Wire type**: 2253 (0x08CD)
**Create**: `CMsgTeamPopPKRanking__Create` @ `0x72E132`
**Process**: `CMsgTeamPopPKRanking__Process` @ `0x72E1F6`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Near-identical to `CMsgTeamPKRanking` (type 2233) but for the ranked/pop TeamPK variant. Same action structure based on WORD[+4] (actions 0/1 = set rankings, action 2 = update scores) with window message differences: posts 0xDA2 instead of 0xC94 and 0xDA3 instead of 0xC93.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action type (0 = set rankings, 1 = set rankings, 2 = update scores) |
| +8 | DWORD | Group ID |
| +12 | DWORD | Phase (used by action 2) |
| +16 | DWORD | Entry count |
| +20 | variable | Ranking entries array (stride 44 bytes per entry) |


## Auth string-validation evidence delta — 2026-10-18

See the [native auth string-validation closure](Native-auth-string-validation-2026-10-18.md) for2078 raw byte storage versus display code-page selection,
the five Windows1252 control-slot mappings, and the distinction between an
on-wire NUL requirement and the native short-packet zero-fill behavior.
The AUTH-001O comparison treats stricter validation as managed policy.
