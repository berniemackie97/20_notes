# Else-Branch Dispatch Packets — Types 1313–10017

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## Else-Branch Dispatch Types (1313–10017)

The following types are dispatched via the else-branch of `CNetMsg__ProcessMsg_Dispatch` using subtraction/comparison chains rather than the main jump table. All use standard CNetMsg vtable layout unless noted.

### CMsgFamilyOccupy (Type 1313)
**Direction**: S→C
**Create**: `CMsgFamilyOccupy__Create` @ `0x7069F1`
**Process**: `CMsgFamilyOccupy__Process` @ `0x706AC6` (IDA: `Handle_Family_Occupy_Text40`)
**Alloc**: `operator new(0x414u)` — MsgStringList variant

Family/guild territory occupation notification. Process handler reads string entries from the MsgStringList buffer and dispatches family occupy text to the UI.

### CMsgLotteryAward (Type 1314)
**Create**: `CMsgLotteryAward__Create` @ `0x74DE0F`
**Process**: `CMsgLotteryAward__Process` @ `0x74DEBF` (IDA: `CMsgLottery__func_000`)
**Alloc**: `operator new(0x408u)`

Lottery item award notification. Process handler reads item data from the payload and posts window message 0xCB1 to notify the UI of lottery winnings.

### CMsgTextMessage (Type 1350)
**Create**: `CMsgTextMessage__Create` @ `0x75D217`
**Process**: `CMsgTextMessage__Process` @ `0x75D2A0`
**Alloc**: `operator new(0x414u)` — MsgStringList variant

Text message set. Uses MsgStringList for variable-length string content delivery.

### CMsgNpcInfo (Type 2030)
**Create**: `CMsgNpcInfo__Create` @ `0x7439E3`
**Process**: `CMsgNpcInfo__Process` @ `0x743B32`
**Alloc**: `operator new(0x414u)` — MsgStringList variant

NPC spawn with MsgStringList tail data. The verified fixed packet fields are:
- `+4` (u32) entity ID
- `+8` (u32) spawn auxiliary dword passed through helper `0x650D9E`
- `+12` (u16) X
- `+14` (u16) Y
- `+16` (u16) look composite
- `+18` (u16) NPC kind

Verified `CMsgNpcInfo__Process` flow:
- resolves/removes any existing entity by entity ID before deciding whether a fresh `CNpc` must be allocated
- allocates `CNpc` (`0xA58`) and stores:
  - `npc+0xCC = entity_id`
  - `npc+0x368 = npc_kind`
- selects RoleView mode `4`, `6`, `8`, or `9` from `npc_kind`
- applies position directly for non-type-9 branches through npc vfunc slot `+0x18`
- splits `look` into `look_lookup_id = look / 10` and `look_direction_index = look % 10`
- resolves role-data through the standard lookup (`vtable+0x30`) or terrain lookup (`vtable+0x34`) depending on `look_lookup_id < 5000`
- overrides the display name from the first MsgStringList entry when present
- registers the entity and posts the scene/update notification

### CMsgNpcAction (Type 2031)
**Create**: `CMsgNpcAction__Create` @ `0x72CB79`
**Process**: `CMsgNpcAction__Process` @ `0x72CC60`
**Alloc**: `operator new(0x408u)`

NPC action dispatch. **Corrected 2026-08-29**: the sub-action is the u16 at **`+0x0C`**, not `+4` —
`+4` is the entity id. Sub-actions `2` and `3` remove that entity with no effect or animation (the
NPC despawn); `5` calls `sub_660AC5(hero, packet+8, flag)` with the flag set for the same kind set
2030 routes to RoleView mode 9; anything else posts `0x42A` and returns. The packet has no string
list. Full write-up in `../Server/npcs.md`.

### CMsgTaskDialogEx (Type 2032)
**Create**: `CMsgTaskDialogEx__Create` @ `0x72BBFF`
**Process**: `CMsgTaskDialogEx__Process` @ `0x72BD72` (IDA: `CMsgTaskDialog__HandleResponse`)
**Alloc**: `operator new(0x414u)` — MsgStringList variant

NPC conversation, both directions. **Verified 2026-08-29**: twelve fixed bytes then a string list at
`+0x0C` (bound by Create at `0x72BC46`). u16 at `+4`/`+6`/`+8`, byte at `+0x0A`, and the **action**
byte at `+0x0B`. Actions 1-5 and 100 append dialog lines; 100 is the terminator that shows the
dialog; 6 raises a confirm box; 112 goes to a separate sink; **0 does nothing at all**. Text is
tilde-encoded - `~` stands in for a space in both directions. The client over-declares its own
outbound length by three bytes. Full write-up in `../Server/npc-dialog.md`.

### CMsgBuddyInfoEx (Type 2033)
**Create**: `CMsgBuddyInfoEx__Create` @ `0x75D2D9`
**Process**: `CMsgBuddyInfoEx__Process` @ `0x75D362`
**Alloc**: `operator new(0x408u)`

Extended buddy/friend information update. Delivers updated friend data to the social system.

### CMsgNoOp2034 (Type 2034)
**Create**: `CMsgNoOp2034__Create` @ `0x75D18E`
**Process**: `CNetMsg__NoopProcess` @ `0x5AD9B1` (shared no-op)
**Alloc**: `operator new(0x408u)`

Server-to-client no-op message. Parsed but has no client-side processing.

### CMsgPetSpawn (Type 2035)
**Create**: `CMsgPetSpawn__Create` @ `0x75CE78`
**Process**: `CMsgPetSpawn__Process` @ `0x75CF01`
**Alloc**: `operator new(0x408u)`

Pet/entity spawn message. Process handler creates a pet entity and posts window message 0x444 to update the UI.

### CMsgNoOp2036 (Type 2036)
**Create**: `CMsgNoOp2036__Create` @ `0x716D37`
**Process**: `CNetMsg__NoopProcess` @ `0x5AD9B1` (shared no-op)
**Alloc**: `operator new(0x408u)`

Server-to-client no-op message. Parsed but has no client-side processing.

### CMsgHeroStatUpdate (Type 2043)
**Create**: `CMsgHeroStatUpdate__Create` @ `0x75D0A8`
**Process**: `CMsgHeroStatUpdate__Process` @ `0x75D131`
**Alloc**: `operator new(0x408u)`

Hero stat update notification. Process handler posts window message 0x444 to trigger a UI refresh of the hero's statistics panel.

### CMsgHeroPage (Type 2044)
**Create**: `CMsgHeroPage__Create` @ `0x744046`
**Process**: `CMsgHeroPage__Process` @ `0x744107`
**Alloc**: `operator new(0x408u)`

Hero/entity page control. Manages paginated hero data display.

### CMsgFamilyBattleEffect (Type 2045)
**Create**: `CMsgFamilyBattleEffect__Create` @ `0x70A355`
**Process**: `CMsgFamilyBattleEffect__Process` @ `0x70A3BB` (IDA: `Handle_Family_Battleeffect_Share_None`)
**Alloc**: `operator new(0x408u)`

Family battle effect sharing. Process handler applies shared battle effects to family/guild members.

### CMsgBuddyConfirm (Type 2046)
**Create**: `CMsgBuddyConfirm__Create` @ `0x72B454`
**Process**: `CMsgBuddyConfirm__Process` @ `0x72B517` (IDA: `DlgTrade__OnBuddyConfirm`)
**Alloc**: `operator new(0x408u)`

Buddy/trade confirmation. Process handler handles trade confirmation between buddy entities.

### CMsgBuddyUpdate (Type 2047)
**Create**: `CMsgBuddyUpdate__Create` @ `0x75CCA3`
**Process**: `CMsgBuddyUpdate__Process` @ `0x75CD2C`
**Alloc**: `operator new(0x408u)`

Buddy update with item/position data. Updates buddy entity position and associated item information.

### CMsgStatusDetail2075 (Type 2075) — corrected 2026-10-15
**Create**: `0x75C570`
**Process**: `CMsgStatusDetail2075__Process` @ `0x75C5F9` (was "CMsgMagicEffect")
**Alloc**: `operator new(0x408u)`

Per-status detail records (status index, op, flag, duration, values) driving status handlers and replacing the
secondary status mask. Layout and handlers: [movement eligibility](../Server/movement-eligibility-5517.md#status-storage-and-sync-client-proven).

### CMsgContainerInfo (Type 2101)
**Create**: `CMsgContainerInfo__Create` @ `0x7022AF`
**Process**: `CMsgContainerInfo__Process` @ `0x702372` (IDA: `CHero__CONTIR_TYPE_ALL`)
**Alloc**: `operator new(0x408u)`

Container/inventory information. Process handler updates the hero's inventory containers with full item data.

### CMsgSynMemberTitle (Type 2102)
**Create**: `CMsgSynMemberTitle__Create` @ `0x75A834`
**Process**: `CMsgSynMemberTitle__Process` @ `0x75A8F9`
**Alloc**: `operator new(0x408u)`

Syndicate member title list. Delivers a list of syndicate member titles for display in the guild UI.

### CMsgChiefNameChange (Type 2103)
**Create**: `CMsgChiefNameChange__Create` @ `0x6ECB23`
**Process**: `CMsgChiefNameChange__Process` @ `0x6ECC0F` (IDA: `Handle_Change_Chiefbase_Name_Suc`)
**Alloc**: `operator new(0x408u)`

Chief/guild leader name change success notification.

### CMsgSynWarScore (Type 2110)
**Create**: `CMsgSynWarScore__Create` @ `0x7518E3`
**Process**: `CMsgSynWarScore__Process` @ `0x751A49`
**Alloc**: `operator new(0x408u)`

Clan/syndicate war score data. Contains war score information for the syndicate war system.

### CMsgLeaveword (Type 2170)
**Create**: `CMsgLeaveword__Create` @ `0x72C4CD`
**Process**: `CMsgLeaveword__Process` @ `0x72C615` (IDA: `Handle_Replace_Leaveword`)
**Alloc**: `operator new(0x408u)`

Leaveword/message board entry. Handles posting and displaying messages on the in-game message board system.

### CMsgTexasNpc (Type 2171)
**Create**: `CMsgTexasNpc__Create` @ `0x744DA5`
**Process**: `CMsgTexasNpc__Process` @ `0x744E8B`
**Alloc**: `operator new(0x408u)`

Texas Hold'em NPC management. Controls the Texas Hold'em poker table NPCs and game state.

### CMsgTexasHoldEm (Type 2172)
**Create**: `CMsgTexasHoldEm__Create` @ `0x75AA46`
**Process**: `CMsgTexasHoldEm__Process` @ `0x75AACF` (IDA: `CTexasTableRole__LoadTexasHoldEmInfo`)
**Alloc**: `operator new(0x408u)`

Texas Hold'em table information. Loads player hand data, pot, and table state into the Texas Hold'em UI.

### CMsgFamilyWarData (Type 2201)
**Create**: `CMsgFamilyWarData__Create` @ `0x75A695`
**Process**: `CMsgFamilyWarData__Process` @ `0x75A71E`
**Alloc**: `operator new(0x408u)`

Family/syndicate war data. Process handler posts window message 0xCB0 to update the family war UI with war status and participant data.

### CMsgShowHandTable (Type 2202)
**Create**: `CMsgShowHandTable__Create` @ `0x752EA9`
**Process**: `CMsgShowHandTable__Process` @ `0x752F93`
**Alloc**: `operator new(0x408u)`

ShowHand/poker table item list. Delivers the poker table state including card data and player bets for the ShowHand mini-game.

### CMsgTotemAdd (Type 2203)
**Create**: `CMsgTotemAdd__Create` @ `0x709F7F`
**Process**: `CMsgTotemAdd__Process` @ `0x70A063` (IDA: `Handle_Confirm_Totemaddsuc`)
**Alloc**: `operator new(0x408u)`

Totem add/remove confirmation. Handles successful totem placement or removal in the guild totem system.

### CMsgQualifyingOut (Type 2205)
**Create**: `CMsgQualifyingOut__Create` @ `0x71B76E`
**Process**: `CMsgQualifyingOut__Process` @ `0x71B866` (IDA: `Handle_Qualifying_Hero_Out`)
**Alloc**: `operator new(0x408u)`

Qualifying/arena hero elimination notification. Process handler invokes `CHeroQualifying__func_000` to remove a player from the qualifying round and posts window message 0xD18.

### CMsgQualifyingMatch (Type 2206)
**Create**: `CMsgQualifyingMatch__Create` @ `0x71BEF7`
**Process**: `CMsgQualifyingMatch__Process` @ `0x71BFCD`
**Alloc**: `operator new(0x408u)`

Qualifying match data with player pairs. Contains match brackets and opponent pairings for the qualifying tournament system. Reads paired player data and posts 0xD17.

### CMsgQualifyingRank (Type 2207)
**Create**: `CMsgQualifyingRank__Create` @ `0x71C1B3`
**Process**: `CMsgQualifyingRank__Process` @ `0x71C26A`
**Alloc**: `operator new(0x408u)`

Qualifying ranking list. Delivers the full ranking leaderboard for the arena qualifying system, iterating entries and calling `QualifyingMgr__SetEntry`.

### CMsgQualifyingStat (Type 2208)
**Create**: `CMsgQualifyingStat__Create` @ `0x71BB50`
**Process**: `CMsgQualifyingStat__Process` @ `0x71BBFF`
**Alloc**: `operator new(0x408u)`

Qualifying player stat list. Contains per-player statistics (wins, losses, scores) for the qualifying arena system.

### CMsgQualifyingSelf (Type 2209)
**Create**: `CMsgQualifyingSelf__Create` @ `0x71BD04`
**Process**: `CMsgQualifyingSelf__Process` @ `0x71BDB3`
**Alloc**: `operator new(0x408u)`

Qualifying self info. Delivers the current player's own qualifying statistics and ranking.

### CMsgDominateTeam (Type 2260)
**Create**: `CMsgDominateTeam__Create` @ `0x72997B`
**Process**: `CMsgDominateTeam__Process` @ `0x729A2A` (IDA: `DlgDominate__OnTeamName`)
**Alloc**: `operator new(0x408u)`

Dominate team name update. Sets the team name in the Dominate dialog UI.

### CMsgAchievementStar (Type 2320)
**Create**: `CMsgAchievementStar__Create` @ `0x728E0A`
**Process**: `CMsgAchievementStar__Process` @ `0x728E70`
**Alloc**: `operator new(0x408u)`

Achievement star/progress system. Process handler reads achievement progress entries (star count, completion status) and updates the achievement UI.

### CMsgFactionPKSetup (Type 2330)
**Create**: `CMsgFactionPKSetup__Create` @ `0x74D417`
**Process**: `CMsgFactionPKSetup__Process` @ `0x74D4D2`
**Alloc**: `operator new(0x408u)`

Faction PK setup and timer. Sub-action 1 resets the singleton and posts 0xCC2; sub-action 2 initializes a new faction PK session with timer, strings (name/description), and round data, posting 0xCC3.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sub-action (1 = reset, 2 = initialize) |
| +6 | 36 bytes | Name string (action 2) |
| +42 | 36 bytes | Description string (action 2) |
| +80 | 4×DWORD | Score/status array |
| +96 | DWORD | Timer duration (seconds) |
| +100 | DWORD | Round data |
| +104 | DWORD | Target ID (-1 = none) |

### CMsgFactionPKList (Type 2331)
**Create**: `CMsgFactionPKList__Create` @ `0x7599B4`
**Process**: `CMsgFactionPKList__Process` @ `0x759A3D`
**Alloc**: `operator new(0x408u)`

Faction PK participant list. Sets singleton state to 1, iterates a list of entries (stride 80 bytes each) calling `CFactionPKMgr__func_000` for each, then posts 0xCC2.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Entry count |
| +8 | variable | Entry array (80 bytes per entry) |

### CMsgFactionPKMatch (Type 2332)
**Create**: `CMsgFactionPKMatch__Create` @ `0x759AA9`
**Process**: `CMsgFactionPKMatch__Process` @ `0x759B32`
**Alloc**: `operator new(0x408u)`

Faction PK match data. Process handler sets state based on WORD[+4] (0→state 2, 1→state 3), iterates match entries (stride 120 bytes) calling `CFactionPKMgr__func_001`, sets timer from WORD[+6], determines match phase from BYTE[+8] and WORD[+6], and posts 0xCC2.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Action (0 = waiting, 1+ = in progress) |
| +6 | WORD | Timer value (×1000ms) |
| +8 | BYTE | Phase flag |
| +10 | WORD | Entry count |
| +16 | variable | Match entry array (120 bytes per entry) |

### CMsgApprenticeList (Type 2333)
**Create**: `CMsgApprenticeList__Create` @ `0x71C4F8`
**Process**: `CMsgApprenticeList__Process` @ `0x71C5BC`
**Alloc**: `operator new(0x408u)`

Apprentice/guide name list. Delivers a list of apprentice or mentor names for the apprentice system UI.

### CMsgMapInfo (Type 2400)
**Create**: `CMsgMapInfo__Create` @ `0x740837`
**Process**: `CMsgMapInfo_Process` @ `0x7408F9`
**Alloc**: `operator new(0x408u)`

Map information. Sub-action 0 delivers map data with coordinates and a name string; sub-action 1 calls a map update function. Uses `GetSingletonPtr_410685`.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sub-action (0 = full info, 1 = update) |
| +8 | DWORD | Map/zone ID |
| +16 | DWORD | X coordinate (action 0) |
| +20 | DWORD | Y coordinate (action 0) |
| +24 | DWORD | Parameter (action 0) |
| +28 | variable | Name string (action 0) |

### CMsgEctypeInvite (Type 2401)
**Create**: `CMsgEctypeInvite__Create` @ `0x6F8F5F`
**Process**: `CMsgEctypeInvite__Process` @ `0x6F9094` (IDA: `Handle_Ectype_Invite`)
**Alloc**: `operator new(0x414u)` — MsgStringList variant

Ectype (dungeon instance) invitation. Sub-action 0 reads inviter name and dungeon name from MsgStringList entries 0/1, formats an invitation message, and posts 0xD9C; sub-action 3 posts 0xD9B with timeout 60; sub-action 4 posts 0xD9B with param 0.

### CMsgArenaAction (Type 2410)
**Create**: `CMsgArenaAction__Create` @ `0x74A6FB`
**Process**: `CMsgArenaAction__Process` @ `0x74A7D2`
**Alloc**: `operator new(0x408u)`

Arena action dispatch with 6 sub-actions (0–5). Reads 5 DWORDs from the payload, dispatches based on WORD[+4]: action 0/5 → `sub_67EEF6`, action 1 → `sub_67EF3E`, action 3 → `sub_67F24A`, action 4 → `sub_67F209`, action 5 → `sub_67F26A`. All go through `GetSingletonPtr_5DF9AB`.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sub-action (0–5) |
| +8 | DWORD | Param 1 |
| +12 | DWORD | Param 2 |
| +16 | DWORD | Param 3 |
| +20 | DWORD | Param 4 |
| +24 | DWORD | Param 5 |

### CMsgVerifyCheck (Type 2420)
**Create**: `CMsgVerifyCheck__Create` @ `0x7593D9`
**Process**: `CMsgVerifyCheck__Process` @ `0x759462` (IDA: `CMsgVerifyCheck__func_000`)
**Alloc**: `operator new(0x408u)`

Anti-cheat verification check. Sub-action 0 initializes the verification data from `CMissionSystemData`. Sub-action 2 (when `byte_949CA0` is set) performs the actual verification: compares body matrix float values via `CAntiCheatMgr__GetBodyMatrixFloat` against server-provided expected values. If verification fails, shows a MessageBox with "VerifyCheck Failed" and calls `sub_76E1E3` to disconnect. If it passes, shows "VerifyCheck OK".

### CMsgCrossSwitch (Type 2501)
**Create**: `CMsgCrossSwitch_Create` @ `0x759776`
**Process**: `CMsgCrossSwitch_Process` @ `0x7597FF` (IDA: `CMsgCrossSwitch__func_000`)
**Alloc**: `operator new(0x408u)`

Cross-server switch command. Configures `CDataMigrationSubject` with source/target server IDs and migration pairs. Sub-action 0 enables cross-server mode, builds a response message and sends it, then refreshes the UI (posts 0x445, 0x446, 0x432). Sub-action 1 disables cross-server mode and refreshes UI.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sub-action (0 = enable cross, 1 = disable) |
| +8 | DWORD | Source server ID |
| +12 | DWORD | Target server ID |
| +16 | DWORD | Migration pair count |
| +20 | variable | Migration pairs (8 bytes each: src_id, dst_id) |

### CMsgCrossInfo (Type 2502)
**Create**: `CMsgCrossInfo__Create` @ `0x7592FB`
**Process**: `CMsgCrossInfo__Process` @ `0x759384`
**Alloc**: `operator new(0x408u)`

Cross-server info notification. Sub-action 0 posts 0xD1D; sub-action 1 posts 0xD1E; sub-action 2 resets the cross data manager and a related singleton, then posts 0xCCF.

### CMsgCrossFlagWarData (Type 2504)
**Create**: `CMsgCrossFlagWarData__Create` @ `0x74C15F`
**Process**: `CMsgCrossFlagWarData__Process` @ `0x74C21A`
**Alloc**: `operator new(0x408u)`

Cross-server flag war data. Sub-action 3 iterates participants (stride 28 bytes) calling `CCrossFlagWarMgr__func_003` for each, sets war data, then posts 0xD22. Sub-action 4 sets a score value and posts 0xD22.

### CMsgCrossFlagWarStatus (Type 2505)
**Create**: `CMsgCrossFlagWarStatus__Create` @ `0x75904E`
**Process**: `CMsgCrossFlagWarStatus__Process` @ `0x7590D7`
**Alloc**: `operator new(0x408u)`

Cross-server flag war status updates. Three sub-actions (switch on WORD[+4]):
- Action 0: Full status with position data for 3 players, calls `sub_6D1E63` and `sub_6D1D64`
- Action 1: Update positions, post 0xCCE for matching player
- Action 2: Simple score/position update via `sub_6D1D64`

### CMsgWarflagEscort (Type 2506)
**Create**: `CMsgWarflagEscort__Create` @ `0x7531BD`
**Process**: `CMsgWarflagEscort__Process` @ `0x753278` (IDA: `Handle_Warflag_Escort_Suc`)
**Alloc**: `operator new(0x408u)`

War flag escort success. Sub-action 0 finds entity by ID and attaches "WarflagEscortB" effect; sub-action 1 attaches "WarflagEscortS" effect and shows a congratulatory chat message if the escorting player is self; sub-action 2 posts 0xCD0 with an entity ID.

### CMsgCrossFlagWarTeam (Type 2507)
**Create**: `CMsgCrossFlagWarTeam__Create` @ `0x74B7ED`
**Process**: `CMsgCrossFlagWarTeam__Process` @ `0x74B8A8`
**Alloc**: `operator new(0x408u)`

Cross-server flag war team data. Sub-action 0 delivers initial team list — iterates entries (stride 72 bytes), reads GameDataSet names and builds team data for the war flag map, posts 0xDD3. Sub-action 1 delivers detailed team info — iterates entries (stride 72 bytes) calling `CCrossFlagWarMgr__func_002` with name, rank, and score data, posts 0xD1F.

### CMsgFactionChiefBase (Type 2510)
**Create**: `CMsgFactionChiefBase__Create` @ `0x701EE1`
**Process**: `CMsgFactionChiefBase__Process` @ `0x702071`
**Alloc**: `operator new(0x414u)` — MsgStringList variant

Faction chief base data. Reads 3 string entries from MsgStringList (base name, leader name, description), sets up the `CFactionChiefBaseMgr` singleton with base info (9 entries at stride 16), sets member count and base ID, then posts 0xDDE.

### CMsgSilentUpdate (Type 2520)
**Create**: `CMsgSilentUpdate__Create` @ `0x758DF1`
**Process**: `CMsgSilentUpdate__Process` @ `0x758E57` (IDA: `Load_SlientVersion_Ini_758E57`)
**Alloc**: `operator new(0x408u)`

Silent/background update delivery. Process handler writes received binary data to a temporary file (`temp/slient_u.tmp` with PID), then copies it to the final location and writes a version ini file. Validates that the received version doesn't match the local version before proceeding.

### CMsgEntityAction (Type 10005)
**Direction**: S→C
**Create**: `CMsgEntityAction__Create` @ `0x7403A1`
**Process**: `CMsgEntityAction__Process` @ `0x7405E7`
**Send**: `CMsgEntityAction__Send` @ `0x7404E1` (non-standard — vtable[3] is NOT the default `CNetMsg__Send`)
**Alloc**: `operator new(0x408u)`

Entity movement packet (S→C) with custom send method. This is the only type with a non-standard vtable[3]. Process handler handles entity movement steps:

**Direction mode logic** (from `+12`):
- `+12 == 9`: 24-directional movement (mount riding/dashing), direction = `+4 % 24`, uses `dword_86C804`/`dword_86C864` for delta X/Y. CRoleAction type = 24 (run/dash).
- `+12 == 1`: 8-directional walking, direction = `+4 % 8`, uses `dword_86C7C4`/`dword_86C7E4` for delta X/Y. CRoleAction type = 23 (walk).
- Other values: 8-directional movement, direction = `+4 % 8`, CRoleAction type = 22.

**Entity lookup behavior**:
1. Find entity by entity_id → if found: apply CRoleAction with direction + movement delta
2. Entity not found AND entity_id == hero_id → update own map position via `CHero__UpdateMapInfoFromTiles`
3. Entity not found AND entity_id != hero_id → send `CMsgAction(action_type=102)` = "QueryPlayer" request to server for unknown entity data

| Offset | Size | Field |
|--------|------|-------|
| +4 | BYTE | Direction index (mod 8 for walking, mod 24 for riding) |
| +8 | DWORD | Entity ID |
| +12 | BYTE | Movement mode (9 = 24-dir mount ride, 1 = 8-dir walk, other = 8-dir alt) |
| +16 | DWORD | Position/map parameter (used in hero self-update path) |

### CMsgPlayerSpawn (Type 10014)
**Direction**: S→C
**Create**: `CMsgPlayerSpawn__Create` @ `0x755E83`
**Process**: `CMsgPlayerSpawn__Process` @ `0x755F64` (IDA: `CMsgPlayer__func_000`)
**Alloc**: `operator new(0x414u)` — MsgStringList variant

Full player spawn/update — the most complex packet in the protocol (S→C). Process handler creates or updates a player entity via `CNpc__Constructor` (allocates 0xA58 = 2648 bytes per CPlayer) with full character data including:
- Character name, mate name, guild name, title (from MsgStringList entries 0–3)
- Appearance: mesh/look composite ID decomposed as `mesh = id % 1000`, `hairstyle = id / 1000 % 10`, `body_type = id / 10000 % 1000`, `transform = id / 10000000`
- Equipment: head, body, right hand (weapon), left hand (shield), mount, wing, tail, accessories — each with item ID lookup via `ItemTypeDataSingleton_TryGetItemRecordByTypeId`
- Stats: HP percentage, level, rebirth/metempsychosis level, nobility rank
- Position: tile X/Y, facing direction (0-7)
- Status flags (16-byte bitfield at +22, copied as 4 DWORDs)
- Transform look, equipment visual scores
- Entity creation: `EntityManager__AddEntity` for new entities, update-in-place for existing
- Entity type check via the entity-class discriminator at `0x6E6529`: returns 4 for NPC/pet entities (special creation path)
- Self-spawn guard: if entity_id == hero_id, packet is discarded with log message
- Anti-cheat/PK effect attachment, cross-server data
- Texas Hold'em NPC integration for poker table entities

BNinja confirmation of the self-spawn guard (`CMsgPlayerSpawn__Process`, `0x755F64`):
- compares `packet+8` against `CHero+0xCC` at the top of the handler;
- on equality, formats/logs `"Got a player with hero id! %u"` and returns immediately before:
  - `EntityRef_ResolveByIdOrLocalHero`
  - any role/entity construction or refresh
  - any tile/direction writes
  - any appearance or RoleView refresh calls.

The largest Process handler in the binary.

| Offset | Size | Field |
|--------|------|-------|
| +4 | DWORD | Appearance/mesh composite ID |
| +8 | DWORD | Entity ID |
| +12 | DWORD | Guild/Syndicate ID → `CHero__SetDword_0x86C` |
| +16 | DWORD | Guild Rank/War Score → entity vtable+212 |
| +20 | WORD | Title/Rank → `CHero__SetWord_0x874` |
| +22 | 16 bytes | Status bitfield |
| +38 | WORD | Local role field `+0xDC` refresh source (`CRole__SetTransformLookSourceId`) |
| +40 | DWORD | `PrimaryHelmetSourceId` → `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView` |
| +44 | DWORD | `SharedBodyHelmetVariantLookupSourceId` → `CRole__SetSharedBodyHelmetVariantLookupSourceAndRefreshRoleView` |
| +48 | DWORD | `PrimaryBodyVariantSourceId` → `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView` |
| +52 | DWORD | `LeftWeaponSourceId` → `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView` |
| +56 | DWORD | `RightWeaponSourceId` → `CRole__SetRightWeaponVisualInputsAndRefreshRoleView` |
| +60 | DWORD | `ExtraLeftWeaponOverrideLookupId` → `CRole__SetExtraLeftWeaponOverrideLookupIdAndRefreshRoleView` |
| +64 | DWORD | `ExtraRightWeaponOverrideLookupId` → `CRole__SetExtraRightWeaponOverrideLookupIdAndRefreshRoleView` |
| +68 | DWORD | `MountActionScalePrimarySourceId` → `Role_UpdateMountActionScaleCacheFromSources` param 1 |
| +72 | DWORD | `MountActionScalePreferredSourceId` → `Role_UpdateMountActionScaleCacheFromSources` param 4 |
| +76 | DWORD | Unresolved packet field (`Unknown70`) |
| +80 | WORD | HP percentage |
| +82 | WORD | Pet mesh ID |
| +84 | WORD | Weapon/mount visual |
| +86 | WORD | Tile X |
| +88 | WORD | Tile Y |
| +90 | BYTE | Direction |
| +91 | DWORD | Action/emotion ID |
| +95 | WORD | Action param |
| +98 | BYTE | Rebirth level |
| +99 | WORD | Level |
| +101 | BYTE | Away flag (1 = away) |
| +102 | BYTE | Cross-server flag |
| +103 | DWORD | Nobility rank |
| +107 | DWORD | Battle power |
| +111 | DWORD | Shield value |
| +115 | DWORD | Title/profession composite |
| +119 | DWORD | Equipment score |
| +123 | WORD | Garment color 1 |
| +125 | WORD | Garment color 2 |
| +127 | WORD | Wing effect |
| +129 | DWORD | Aura effect |
| +133 | BYTE | `MountPlusLevel` → `Role_UpdateMountActionScaleCacheFromSources` param 2 |
| +135 | DWORD | Flower count |
| +139 | DWORD | `MountColorIdentity` → `Role_UpdateMountActionScaleCacheFromSources` param 3 |
| +143 | WORD | Inner strength level |
| +145 | WORD | Quiz points |
| +149 | WORD | Team leader rank |
| +151 | DWORD | Quiz rank |
| +155 | DWORD | Guild ID 2 → guild-name lookup helper at `0x672987` + `GetSingletonPtr_480676` |
| +159 | DWORD | Guild Rank 2 → guild-rank update helper at `0x672994` |
| +163 | DWORD | Mount speed |
| +167 | WORD | Cultivation level |
| +169 | DWORD | Fairy ID |
| +173 | BYTE | Fairy type |
| +174 | DWORD | Fairy wings |
| +178 | BYTE | Ghost flag |
| +179 | BYTE | Fairy visible flag |
| +180 | BYTE | Emotion mount flag |
| +181 | BYTE | HP scale flag |
| +182 | DWORD | Headwear visual item-query id → validated headwear override lookup input (`role+0x130`) |
| +186 | DWORD | Armor visual item-query id → validated body override lookup input (`role+0x134`) |
| +190 | DWORD | Left-hand visual item-query id → validated left-weapon override input (`role+0x138`) |
| +194 | DWORD | Right-hand visual item-query id → validated right-weapon override input (`role+0x13C`) |
| +198 | BYTE | Metempsychosis level → metempsychosis digit-extraction helper at `0x675ABA` |
| +199 | DWORD | Metempsychosis EXP low → metempsychosis experience helper at `0x675AE1` |
| +203 | DWORD | Metempsychosis EXP high → metempsychosis experience helper at `0x675AE1` |
| +207 | WORD | Court rank |
| +209 | WORD | Mount rank |
| +211 | WORD | Sub-profession |
| +213 | DWORD | Sub-profession param |
| +217 | BYTE | Skip position flag |

String List entries (via MsgStringList at object+1032, max 36 chars each):
- Entry 0: Character name → `CRole__SetString_0x14C` (entity name)
- Entry 1: Mate/spouse name → displayed via "MonProMon" resource if non-empty
- Entry 2: Guild name → guild/syndicate display helper at `0x69A59C`
- Entry 3: Title/faction name

**Entity creation flow**:
1. If `entity_id == hero_id` → discard (log "Got a player with hero id!")
2. `EntityManager__FindEntityById(entity_id)` → check if entity already exists
3. If new: `CNpc__AllocateMemory(0xA58)` → `CNpc__Constructor` → allocate CPlayer (2648 bytes)
4. Set `entity+204 = entity_id`
5. The entity-class discriminator at `0x6E6529(entity_id)` returns 4 → NPC/pet path (special model, entity+872 = 9)
6. Otherwise → player path (entity+872 = 11, or 111 if `+179` flag set)
7. `CRole__CreateRoleView(entity, mesh_id, view_type)` → create visual representation
8. `EntityManager__AddEntity` → register in world
9. Apply all equipment, stats, position, status flags
10. Post window messages for UI refresh

Verified player RoleView note:

- player entities use RoleView type `1`
- `CMsgPlayerSpawn__Process` feeds both:
  - packed `lookface` / hair composites
  - the separate low-range appearance seed at `+0x26`
- in `RoleView.dll`, type-1 key `0` (the type-1 body/helmet million-range rewrite helper at `0x10001EB8`) rewrites body/helmet million-range source ids as `bodyAppearanceSourceId * 1_000_000 + existing_low_6_digits`
- managed/server implementations must therefore preserve the raw equipment item ids, the item-query ids, and the separate type-1 body appearance source id instead of flattening everything into a single packed mesh field

Managed/server writer correction for this slice:

- for first in-world player construction, the managed/server path now treats the following as parity-critical and writes/reads them explicitly:
  - `+4` packed appearance composite
  - `+38` type-1 appearance refresh source
  - `+40/+44/+48/+52/+56/+60/+64/+68/+72` raw equipped-item identities
  - `+182/+186/+190/+194` visual item-query ids that feed the verified primary helmet/body and weapon override-lookup chains
- the previous managed/server draft that zero-filled most of `10014` was sufficient only for packet progression, not for native-equivalent player RoleView setup.

### Managed mapping for initial world-entry materialization

Current managed runtime scope in `10_work`:

- `ClientWorldInboundPacketApplyRuntime` persists conservative role snapshots from `10014`:
  - `entityId`
  - `appearanceCompositeId`
  - `tileX/tileY`
  - `direction`
  - `rebirthCount`
  - `level`
  - string-list identities `[playerName, mateName, guildName, titleText]`
- local-hero `10014` is explicitly ignored once `MsgUserInfo (1006)` has established the local hero entity id,
  matching the verified native self-spawn guard at `0x755F64`.
- local-hero identity/health/mana come from `1006`; position comes from server `MsgAction` subtype `0x4A` (`74`).
- even when the local-hero copy of `10014` carries tile/direction fields, native returns before those fields are
  consumed; they do not override the `1006 + 0x4A` startup state.
- scene-facing role materialization now projects those stored tile coordinates through the same native math used by
  `Role_SetTilePositionAndProjectScreenCoordinates` (`0x6E4C79`):
  - `Map_ProjectTileToScreenCoordinates` (`0x61D850`) -> projected screen pair
  - XTEA tile fields are `role+0x318/+0x334`; absolute cursor is `role+0x350/+0x354`
  - `CGameMap_GetPointRelativeToProjectionCenter` refreshes `role+0x358/+0x35C`
  - this is exact for the initial world-entry/spawn commit because
    `Role_SetTilePositionAndProjectScreenCoordinates` writes `role+0x350/+0x354`
    directly from that tile projection
  - movement must consume `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor` (`0x65185D`) rather than reprojecting a static packet tile:
    - `Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`) stages the next projected point at
      `role+0x19C/+0x1A0`
    - `Role_RecomputeCoordinateGateCacheFromProjectedPosition` (`0x64E9A5`) later commits staged position into
      `role+0x350/+0x354`
  - managed projection therefore uses the local-hero projected screen pair only as a pre-command-snapshot fallback;
    once a verified command snapshot exists, its committed `RoleField350/354` pair must win

Conservative scope note:
- native `10014` performs full entity-manager creation/update, equipment visual binding, status-flag application,
  and multiple UI/anti-cheat side effects;
- the current managed slice materializes verified role snapshot state, projected screen-position state, raw type-1
  appearance/equipment fields, and local-hero-first type-1 render ordering needed for the first real role-scene
  composition slice.
- it still does **not** claim full native RoleView mesh draw parity yet; the remaining unresolved stage is the exact
  managed replacement for the native `Role_TickAndRender -> RoleView slot +0x10/+0x18/+0x28` draw contract.

### CMsgUserAttribEx (Type 10017)
**Direction**: S→C
**Create**: `CMsgUserAttribEx__Create` @ `0x7572EB`
**Process**: `CMsgUserAttribEx__Process` @ `0x757374`
**Alloc**: `operator new(0x408u)`

Extended user attribute update — the second most complex packet handler (~6000 lines). Process handler iterates an array of attribute entries (stride 20 bytes each), dispatching on attribute type via two switch statements (0–27 and 28–54) plus special case 128.

#### Packet Structure

| Offset | Size | Field |
|--------|------|-------|
| +0 | WORD | Packet size |
| +2 | WORD | Packet type (10017) |
| +4 | DWORD | Entity ID — target entity for attribute updates |
| +8 | DWORD | Entry count — number of attribute entries |
| +12 | array | Attribute entries (20 bytes each) |

**Each attribute entry (20 bytes)**:

| Entry Offset | Size | Field |
|--------------|------|-------|
| +0 | DWORD | Attribute ID |
| +4 | DWORD | Value (low 32 bits) |
| +8 | DWORD | Value (high 32 bits, for 64-bit values) |
| +12 | 8 bytes | Padding / unused |

#### Entity Lookup

The handler first looks up the target entity via `EntityManager__FindEntityById` using the Entity ID at +4. If the entity is **not found**, only three attribute types are handled in a fallback path:

| Attrib ID | Remote Fallback Behavior |
|-----------|-------------------------|
| 0 (Life) | `sub_7060DE(entity_id, value)` — remote HP bar update |
| 1 (MaxLife) | `sub_7060FB(entity_id, value)` — remote max HP update |
| 12 (Level) | `sub_729D49(value)` — only if entity_id matches hero, sets level on world singleton |

All other attribute types are silently skipped when the entity is not found.

#### Post-Loop Behavior

After processing all entries, if the **last** entry's attribute ID is NOT 0 (Life), 2 (Mana), 4 (NobilityDonate), or 5 (Experience), AND the target entity is the local hero, then `PostMainWndMsg(0x402)` is sent to refresh the character info UI.

#### Attribute ID Table

##### The `Name` column is not evidence

**The `Entity Field` and `Handler Details` columns are reliable — they were decompiled from this
build. The `Name` column is not.** Names in this table came from two different sources that were
never distinguished:

1. Names derived from evidence *inside this build* (a `STR_` string, a threshold, an observable
   behaviour). These have held up under re-verification.
2. Names imported from a reference-server enum for a **different client version**. These are wrong
   far more often than not.

As of 2026-08-16, re-deriving the `MsgUserInfo` (`1006`) fields from the binary disproved **10**
names in this table and confirmed **5**. Do not take a name from here as a lead — several hours
were lost chasing `PeerageLevel` and `NobilityDonate` into the wrong subsystems entirely.

**Disproven (use the right-hand column):**

| ID | Name in this table | Actually (proven from the binary) |
|---|---|---|
| 4 | `NobilityDonate` | **money / silver** (`hero+0x0C`) — gem-compose gate needs `>= 100000`, else `STR_COMPOSE_MONEY_NOT_ENOUGH` |
| 6 | `Stamina` | **PK points** (`hero+0x868`) — drives the red/black name colour thresholds in `CDlgRoleAttribute_RefreshLabelsFromHero` |
| 7 | `PkPoints` | **current profession** (`hero+0x82C`) — feeds `CHero_FormatProfessionDisplayName` |
| 8 | `AddPoints` | **current physical force / stamina** (`hero+0x830`) — capped by `hero+0x834` via `CHero_GetCappedPhysicalForce`. Unspent attribute points are `hero+0x840` |
| 29 | `Nobility` | **emoney / CPs** (`hero+0x10`) — name change needs `>= 810`, else `STR_CHANGE_NAME_EMONEY_NOT_ENOUGH` |
| 37 | `PeerageLevel` | **tutor level-equivalent** (`hero+0x83C`) — the lookup key into `ini/TutorType.ini`, nothing to do with peerage |
| 45 | `NobilityRank` | **bound emoney** (`hero+0x14`) — second shop currency with its own price, `STR_WRAPSHOP_ERR_EMONEY` |
| 47 | `FactionPKRound` | **race points** (`hero+0x2E08`) — point-shop balance, `STR_RACEPOINTSHOP_POINT_LIMIT` |
| 50 | `CourtRank` | **previous profession** (`hero+0x854`, `CHero_GetPreviousProfession`) |
| 51 | `MountRank` | **first profession** (`hero+0x850`, `CHero_GetFirstProfession`) |

**Confirmed correct:** `0` (Life), `2` (Mana), `5` (Experience), `12` (Level), `22` (Reborn) —
note these are exactly the entries whose `Handler Details` already cited in-build evidence.

Full proofs and the accessor renames are in
[01_core_packets.md](01_core_packets.md) under the `MsgUserInfo (Type 1006)` section.

The [2026-09-21 focused reconciliation](MsgUserInfo1006-historical-field-reconciliation.md)
corrects ID23 to historically identified Virtue, proves ID24 performs no update, and clarifies ID37
as MeteLev/pre-rebirth level. Historical names and native-only proof remain distinguished.

**First switch (IDs 0–27):**

| ID | Name | Entity Field | Handler Details |
|----|------|-------------|-----------------|
| 0 | Life | CRole+0x97C | `CRole__SetDwordField606_673EAC(entity, 1, value)` — current HP. Also calls `sub_7060DE` for world HP bar update |
| 1 | MaxLife | vtable+200 | `entity->vtable[50](value)` — max HP. Also calls `sub_7060FB` for world max HP update |
| 2 | Mana | — | `sub_67321A(entity, value)` — current MP |
| 3 | MaxMana | — | `sub_6731B8(value)` — max MP |
| 4 | NobilityDonate | CHero+0xC | `sub_6844D2(value)` — hero only (self-entity check). Nobility donation amount |
| 5 | Experience | entity[536..537] | 64-bit XP stored at entity[536] (lo) and entity[537] (hi). If new > old, calls `sub_62014B` for XP gain animation |
| 6 | Stamina | entity[538] | Direct store. PostMainWndMsg `0x403` |
| 7 | PkPoints | entity[523] | Direct store |
| 8 | AddPoints | entity[524] | Direct store. PostMainWndMsg `0x41F` (stat point allocation UI) |
| 9 | TeamLeaderRank | CHero+0x114C | Hero only. `CHero__SetDword_0x114C_AndPost3F8(value)`. PostMainWndMsg `0x3F8` |
| 10 | BloodThirst | entity[528] | Direct store. PostMainWndMsg `0xDED` (sub-profession UI refresh) |
| 11 | Mesh/Look | composite | Live composite-appearance mutation on an existing entity: `meshTransformId = (value64 / 10000) % 1000` → `CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform`; `transformFlag = (value64 / 1000) % 10` → `role+0x178`; body appearance source = `value64 % 1000` → `CRole__SetBodyAppearanceSourceId`; transform-look source family = `value64 / 10000000` → `CRole__SetTransformLook` with RoleDataQuery validation |
| 12 | Level | entity[526] | Triggers qualification check: if hero is <70 and new level ≥70, shows "STR_CONFIRM_QUAL" prompt via `CMessageBoxMgr`. PostMainWndMsg `0x402` (char info) + `0x494` (peerage). Calls `0x68F7B9` (tutor-grade recomputation) |
| 13 | InnerLevel | entity[323] | Direct store. PostMainWndMsg `0xDED` |
| 14 | InnerProgress | entity[322] | Direct store. PostMainWndMsg `0xDED` |
| 15 | SubProLevel | entity[319] | Direct store. PostMainWndMsg `0xDED` |
| 16 | SubProXp | entity[321] | Direct store. PostMainWndMsg `0xDED` |
| 17 | StatusEffect17 | — | `sub_6F0FB7(effect=17, mode=1, value, 1, 1)` — applies status effect via status manager |
| 18 | StatusEffect18 | — | `sub_6F0FB7(effect=18, mode=2, value, 1, 1)` — applies status effect via status manager |
| 19 | SoulShield | CHero+0x878 | `CHero__SetDword_0x878(entity, value)`. PostMainWndMsg `0x40A`. **Not a status effect** — sets a dedicated hero field |
| 20 | StatusEffect20 | — | `sub_6F0FB7(effect=20, mode=2, value, 1, 1)` — applies status effect via status manager |
| 21 | ExtraBattle | singleton+3304 | Hero only. Sets `GetSingletonPtr_404460()+3304 = value` — extra battle power |
| 22 | Reborn | — | `sub_673F05(value)` — rebirth/metempsychosis level. If hero: `CHero__RefreshEquipmentDerivedStats` + PostMainWndMsg `0x445`, `0x446`, `0x494`. Calls `0x68F7B9` (tutor-grade recomputation) |
| 23 | Virtue (historical name) | role+0x8B8 | Native `0x757BFF` stores low DWORD, same destination as1006 +44. Jump-table slot `0x758D75` -> `0x757BF9`. Historical identity corroborated by COPS5066; former KOBonus label unproven. |
| 24 | No field update | — | Native table slot `0x758D79` -> common continuation `0x758B86`. |
| 25 | StatusFlags | 16-byte | Copies 16 bytes from entry value into v206[]. For hero, checks/toggles 7 individual status flag pairs: bits 0x40→flag 0x66 (effect 91), 0x100→0x68 (92), 0x400→0x6A (93), 0x1000→0x6C (94), 0x4000→0x6E (95), 0x4→0x62 (96), 0x10→0x64 (97). Then calls `sub_676207` + `entity->vtable[52](v206)`. If hero has flag 0x1E or 0x1F, applies status effect 28 |
| 26 | Arrowsmith | — | `sub_64DB3C(value64 % 1000, 1)` + `sub_64DC01(value64 / 1000, 1)` — arrowsmith visual effect decomposition |
| 27 | HP% | entity[324] | Capped at 100. PostMainWndMsg `0x40F` — HP percentage display |

**Second switch (IDs 28–54, 128):**

| ID | Name | Entity Field | Handler Details |
|----|------|-------------|-----------------|
| 28 | XPTimer | singleton+11548 | `sub_6F0EB5(28, value64/1000, 2)` — XP timer in 1000ms units. Stores raw at singleton+11548, timeGetTime() at +11552. Manages effect 28 with status flags 0x1E/0x1F checks |
| 29 | Nobility | singleton+0x10 | `CObject__SetDword_0x10(singleton, value)` — nobility rank. Calls `sub_662E12` for level display update |
| 30 | Cultivation | singleton+3416 | Direct store — cultivation/enlightenment level |
| 31 | ShowHand | — | Poker state machine (6 sub-states 0–5): 0=remove effect 31; 1=timer mode 1; 2=timer mode 3; 3=set small blind (+10 via `sub_71FF40`); 4=timer 5000ms mode 2; 5=remove effect 31 |
| 32 | FatigueState | — | **Server name verified** via `GameDataSetQuery`. Calls `sub_663109(1)` to enable fatigue system. Branches on value: 0 → effect 33 + timer 5 + PostMainWndMsg `0x475`; 50 → effect 34 + timer 6 + PostMainWndMsg `0x474`; 100 → effect 35 + timer 7. Values represent fatigue health percentage |
| 33 | OnlineTime | — | **Server name verified**. `sub_663096(timeGetTime())` + `sub_663082(value)`. Threshold messages: 3600s(1h)→`0x471`, 7200s(2h)→`0x472`, 10800s(3h)→`0x473`. Displays formatted time via string ID 11070. Shows system chat message |
| 34 | FatigueTime | — | **Server name verified**. `sub_6630AA(value)`. Displays formatted time via string ID 11070. Shows system chat message. Calls `sub_6630BE(1)` |
| 35 | FatigueReset | — | **Server name verified**. Resets: `sub_663082(0)`, `sub_6630AA(0)`, `sub_66311D(100)`. Removes effects 33/34/35. Restores fatigue level based on `sub_66312A` result (0→effect 33/timer 5, 50→effect 34/timer 6, 100→effect 35/timer 7). PostMainWndMsg `0x470` |
| 36 | FamilyBattle | — | Complex 2+ entry handler. Entry[0] with value>0: sets bit flag 0x3E, `sub_673A88(value)`, formats "STR_FAMILY_BATTLE" string with family name from `sub_69A306`. Entry[0] with value≤0: clears bit 62, resets family. Entry[1]: formats prompt text. Uses effects 59 with timer |
| 37 | EncodedPreRebirthLevel (historical MeteLev) | role+0x83C | Native unsigned divide by100000 at `0x758392`, setter `0x673202` called at `0x758398`; same decode as1006 +48. `0x68F7B9` recomputes tutor grade. Not peerage/donation. |
| 38 | Title | — | Value=0: clears bit 63, PostMainWndMsg `0x4B8`. Value=255: sets bit 0x3F, PostMainWndMsg `0x4B1(value)`. Other: clears bit 63 |
| 39 | Coach | — | `sub_673266(value)` — coaching/mentor rank. If `GetGroupCount() > 0`: PostMainWndMsg `0x501(1)`. PostMainWndMsg `0x4DB` |
| 40 | MentorPK | — | Hero only. Old value via `sub_674D34`. Status effect swap: removes old effect via `sub_71E05A(old)`, adds new via `sub_71E05A(new)`. Sets via `entity->vtable[54](value)` |
| 41 | CoachBattlePower | CHero+0x99C | Hero: `Handle_Coach_Inc_Prompt(singleton, value, 0)` — shows coaching income prompts (STR_COACH_INC_PROMPT, STR_COACH_LOGIN_PROMPT), manages effect 55 with timer 3237/30000. Stores at entity[615]. Others: `entity->vtable[55](value)` |
| 42 | FamilyBattleRanking | — | Requires exactly 2 entries. Entry[0]: family ranking setup/teardown via `sub_69A306` with family lookup `sub_706290`. Entry[1]: formats family battle prompt. Shows "STR_FAMILY_BATTLE" chat messages. Uses effect 59. PostMainWndMsg `0x445`, `0x446` |
| 43 | FlowerEffect | singleton[812] | `sub_65AACA(value)` — sets singleton+0xCB0 (3248). Flower rank visual effect |
| 44 | NobilityExp | singleton[314] | `sub_673A5C(value)` — sets singleton+0x4E8 (1256). `CHero__RefreshEquipmentDerivedStats` + PostMainWndMsg `0x445`, `0x446` |
| 45 | NobilityRank | singleton+0x14 | `CObject__SetDword_0x14(singleton, value)`. Calls `sub_662E12` for level display update |
| 47 | FactionPKRound | singleton[2946] | `sub_6655DB(value)` — sets singleton+0x2E08 (11784). PostMainWndMsg `0xCC1` |
| 48 | FactionPKTimer | — | `sub_6972D3(value_hi)` + `sub_697638(1000 * value_lo)` via `GetSingletonPtr_420BF5` — faction PK round timer with millisecond conversion |
| 49 | SubProStatus | — | Handles magic IDs 93 and 113 specifically. For 93 (hero only): effect 89 mode 20 with value from entry[+20], calls `sub_667A58(entry[+28], entry[+24])`. For 113 (hero only): effect 90 mode 21 with value, calls `sub_667BB0(entry[+24])` |
| 50 | CourtRank | — | `sub_67630B(value)` |
| 51 | MountRank | — | `sub_6762F7(value)` |
| 52 | SubProField | — | `sub_6755BC(value)` via game singleton |
| 54 | TrainTimer | — | Hero only. `sub_67544A(singleton)` + effect 98 mode 2, value from entry[+20]. Timer via `sub_6F11E8(98, 0, -1)` |
| 128 | ServerPatch | singleton+11560 | Direct store at `GetSingletonPtr_404460() + 11560` — server-side patch/feature flags |

**Unhandled IDs in this build**: 24, 46, 53 (default case — silently skipped)
