# Minigame Packets — ShowHand Poker, Race Track, Texas HoldEm

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## Type 1075 — class unproven; label `MsgRaceTrackProp` withdrawn (`MsgRaceTrackProp.cpp` asserts are in the type 2072 handler; CP0.1 2026-11-05)
**Direction**: Bidirectional
**Purpose**: Race‑track property update with URL‑style encoding (verified by `=`/`+`/`/` encoding logic and `CHANGE_PICKEY` key).
**Dispatch**: Create `CMsgRaceTrackProp__Create` (0x715061), process `CMsgRaceTrackProp__Process` (0x715125)

**Verified field usage in `CMsgRaceTrackProp__Process`** (offsets relative to packet start):
- `+4` is treated as a NUL‑terminated string (input length via `strlen`).
- The handler builds an encoded copy where:
  - `'='` → `\"%3D\"`
  - `'+'` → `\"%2B\"`
  - `'/'` → `\"%2F\"`
  - all other bytes are copied as‑is.
- Allocates a 0x440‑byte buffer and writes:
  - `key[64] = \"CHANGE_PICKEY\"`
  - `value[0x400] = encoded string`
- Posts `PostMainWndMsg_0x464(0xCEB, buffer)`.
- Allocates a 0x400‑byte buffer with the raw string from `+4` and posts `PostMainWndMsg_0x464(0xCEA, buffer)`.
- Finally posts `PostMainWndMsg_0x464(0xCEF, 0)`.

## Type 1126 — class unproven; label `MsgTexasNpcInfo` withdrawn (`MsgTexasNpcInfo.cpp` asserts are in the type 2172 handler; CP0.1 2026-11-05)
**Direction**: S->C
**Purpose**: Texas Hold'em invite/notification UI packet (message box + follow-up UI posts, or red chat notification depending on mode).
**Dispatch**: Create `CMsgTexasNpcInfo__Create` (0x72C76E), parse `CMsgTexasNpcInfo__Parse` (0x72C820), process `CMsgTexasNpcInfo__Process` (0x72C843)

**Parse**: `CMsgTexasNpcInfo__Parse` — standard header validation, then `type == 1126`.

**Verified field usage in `CMsgTexasNpcInfo__Process`** (offsets relative to packet start):
- `+4` (u8) `mode`:
  - `0`: invite-confirm dialog path.
  - `2`: red system-message path.
  - `1` and other values: no additional handling in this function.
- `+8` (u32) `dataset_text_id`: passed to `GameDataSetQuery()->vfunc(+0x3C)` to obtain display text.
- `+12` (u32) `cmd_param`: passed to `CMessageBoxMgr__ShowCommandMessageWithParam` for mode `0`.
- `+16` (u32) `post_param`: posted as `lParam` with window message `0xD96` for mode `0`.

**Verified processing flow**:
- `mode == 0`:
  - Resolves display text from dataset id `+8`.
  - Calls `CMessageBoxMgr__ShowCommandMessageWithParam(3476, +12, "INVITE_TRANS_CONFIRM", resolved_text)`.
  - Posts `PostMainWndMsg_0x464(0xD96, +16)`.
  - Posts `PostMainWndMsg_0x464(0x51C, 0)`.
- `mode == 2`:
  - Resolves display text from dataset id `+8`.
  - Adds red system chat line via `CChatLog__AddSystemMessage(text, +8, 2005, -65536, 0, 0)`.
- `mode == 1` and other values:
  - no post/message side effects in this handler.

**Verified outgoing builder (`client -> server`)**:
- `CMsgTexasNpcInfo__BuildSize20_ModeValueParam_72C7D4` initializes a fixed-size packet:
  - `size = 20`, `type = 1126`
  - `+4 = mode` (u8)
- `+8 = value` (u32)
- `+12 = param` (u32)
- Verified callsite (`case 3476` in UI dispatcher around `0x584268`) builds with `(mode=1, value=1, param=esi)` and sends via `CNetMsg__Send`.

## CMsgShowHandEnter (Type 2090)
**Direction**: S->C

**Wire type**: 2090 (0x082A)
**Create**: `CMsgShowHandEnter__Create` @ `0x7513B2`
**Process**: `CMsgShowHandEnter__Process` @ `0x7514B5`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Handles player entry into a Texas Hold'em (ShowHand) poker table. Validates the join type (0-3) via `CShowHand__ValidateJoinType` (0x751418), returns early with assert on invalid type. Two main branches:

**Branch 1: Player ID matches local hero** (payload DWORD[+16] == local hero ID)
- Loads table configuration via `CTexasHoldem__LoadTableConfig` with table ID from DWORD[+12]
- Calls `CShowHandPlayer__SHP_JT_NONE` to set join state with: player ID (DWORD[+16]), seat index (WORD[+8]), join type, and active flag (BYTE[+4] != 0)
- On success: posts 0xCF1 + 0xCF8 (enter table UI). On failure: posts 0xCFA + 0xD0A
- Join type 1: shows "ShAdviseConfirm" advice message (command 3341)
- Join type 3: shows both "ShAdviseConfirm" and "ShPreJoinTip" messages
- Broadcasts player count update via `Handle_Sh_Broadcast_Player_Count_In_Game`

**Branch 2: Other player entering local table** (payload DWORD[+12] matches local table)
- Calls `CShowHandPlayer__SHP_JT_NONE` with same parameters
- Posts 0xD0A (refresh UI)
- Broadcasts player count update

| Offset | Size | Field |
|--------|------|-------|
| +4 | BYTE | Active flag (1 = active) |
| +6 | WORD | Join type (0-3) |
| +8 | WORD | Seat index |
| +12 | DWORD | Table ID |
| +16 | DWORD | Player entity ID |

## CMsgShowHandDealtCard (Type 2091)
**Direction**: S->C

**Wire type**: 2091 (0x082B)
**Create**: `CMsgShowHandDealtCard__Create` @ `0x75BD80`
**Process**: `CMsgShowHandDealtCard__Process` @ `0x75BF92`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Handles card dealing during ShowHand gameplay. Validates local player is in table via `CShowHandMgr__IsLocalPlayerInTable` (0x6B47A0). Three modes based on WORD[+6]:

**Mode 0: Initial deal** (pre-flop)
- Clears deal state via `CShowHandMgr__ResetGameState`, sets pot via `CPackage__SetDword_0x34`, sets blind values via `CShowHandMgr__SetSmallBlind`/`CShowHandMgr__SetBigBlind`
- Expects exactly 2 hole cards (WORD[+8] == 2), asserts on mismatch
- Iterates players (WORD[+30] count), deals cards with player IDs at stride-8 offsets starting at +48
- Cards transformed via `CMsgShowHandDealtCard__func_000`, placed via `CShowHandMgr__SetPlayerCard`
- For each hand, checks if player is local hero to determine card visibility

**Modes 1-3: Community cards** (flop/turn/river)
- Calls `CShowHandMgr__ClearCommunityCards` for state setup
- If WORD[+30] > 0, triggers `CShowHandMgr__func_019`
- Iterates WORD[+8] cards at stride-2 from offset +20 (card values) and +10 (suit values)
- Transforms and places via `CMsgShowHandDealtCard__func_000` + `CShowHandMgr__AddCommunityCard`

**Mode 4: Showdown**
- Clears via `CShowHandMgr__ResetGameState` + `CShowHandMgr__ClearActionLog`
- If WORD[+30] > 0, reveals all player hands
- Iterates players, deals cards with player IDs at stride-8 from +48
- Card data at stride-8 from +44 (suit) and +46 (value)

Finishes with `CShowHandMgr__SetStateTimer(WORD[+4], 1)` to advance game state.

## CMsgShowHandActivePlayer (Type 2092)
**Direction**: S->C

**Wire type**: 2092 (0x082C)
**Create**: `CMsgShowHandActivePlayer__Create` @ `0x75C272`
**Process**: `CMsgShowHandActivePlayer__Process` @ `0x75C2FB`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Notifies which player's turn it is. Validates table state via `CShowHandMgr__IsLocalPlayerInTable`.

**If active player is local hero** (DWORD[+16] == local hero ID):
- Posts 0xCFB (your turn indicator)
- If `CShowHandMgr__GetGameMode` returns 1, posts 0xCFE (enable betting UI)
- If local player has auto-action pending (`CShowHandPlayer__GetAutoActionFlag`), posts 0xD0B

**If active player is another player**:
- Looks up local player, checks `CShowHandPlayer__GetIsSeated` condition
- Posts 0xCFC (opponent's turn indicator)
- If `CShowHandMgr__GetGameMode` returns 1, posts 0xCFF (enable fold/check UI)

Finishes by calling `CShowHandMgr__SetActivePlayerTurn` with player ID (DWORD[+16]), round (WORD[+6]), bet amount (DWORD[+8]), and total pot (DWORD[+12]). Advances state via `CShowHandMgr__SetStateTimer(WORD[+4], 2)`.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sequence number |
| +6 | WORD | Round number |
| +8 | DWORD | Current bet amount |
| +12 | DWORD | Total pot |
| +16 | DWORD | Active player entity ID |

## CMsgShowHandCallAction (Type 2093)
**Direction**: S->C

**Wire type**: 2093 (0x082D)
**Create**: `CMsgShowHandCallAction__Create` @ `0x75106F`
**Process**: `CMsgShowHandCallAction__Process` @ `0x751180`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Handles a player's betting action (call, raise, fold, check, all-in). Validates action type via `CShowHand__ValidateActionType` (0x7510D5) which accepts power-of-2 flags: 1 (fold), 2 (check), 4 (call), 8 (raise), 16 (all-in), 32 (bet). Returns -1 for invalid.

If action is from local hero (DWORD[+16] == local hero ID):
- Calls `CShowHandMgr__SetPlayerActiveFlag(heroId, 1)` to update local state
- Posts 0xCFC (action taken indicator)
- If `CShowHandMgr__GetGameMode` returns 1, posts 0xCFF

Applies the action via `CShowHandMgr__ApplyPlayerAction` with player ID (DWORD[+16]), action type, bet amount (DWORD[+8]), and raise amount (DWORD[+12]). Advances state via `CShowHandMgr__SetStateTimer(WORD[+4], 3)`.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sequence number |
| +6 | WORD | Action type (1=fold, 2=check, 4=call, 8=raise, 16=all-in, 32=bet) |
| +8 | DWORD | Bet amount |
| +12 | DWORD | Raise amount |
| +16 | DWORD | Player entity ID |

## CMsgShowHandLayCard (Type 2094)
**Direction**: S->C

**Wire type**: 2094 (0x082E)
**Create**: `CMsgShowHandLayCard__Create` @ `0x75BAAE`
**Process**: `CMsgShowHandLayCard__Process` @ `0x75BC60`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Reveals/lays out player cards (e.g., during showdown). Validates table state via `CShowHandMgr__IsLocalPlayerInTable`.

Iterates WORD[+6] player entries at stride-12 starting at offset +16. For each player:
- Reveals 2 cards (inner loop, count=2) at stride-2 from offset +12 within entry
- Card suit at entry+8, card value at entry+12
- Transforms via `CMsgShowHandLayCard__func_000`, stores via `CShowHandMgr__SetPlayerCardByIndex(playerID, cardIndex, suit, value)`
- Checks if player is local hero to set display flag
- Calls `CShowHandMgr__EvaluatePokerHand` to determine hand ranking, `CShowHandMgr__SetPlayerHandRanking` to update result

Advances state via `CShowHandMgr__SetStateTimer(WORD[+4], 4)`.

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sequence number |
| +6 | WORD | Player count |
| +16+ | stride-12 | Per-player entries: DWORD playerID, 2x (WORD suit, WORD value) |

## CMsgShowHandGameResult (Type 2095)
**Direction**: S->C

**Wire type**: 2095 (0x082F)
**Create**: `CMsgShowHandGameResult__Create` @ `0x75B80F`
**Process**: `CMsgShowHandGameResult__Process` @ `0x75B898`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Delivers game round results. Validates table state via `CShowHandMgr__IsLocalPlayerInTable`. Clears display via `CShowHandMgr__ClearActionLog`, `CShowHandMgr__ClearAllPlayerCards`, `CShowHandMgr__ClearPlayerBetLabels`.

Iterates WORD[+6] player entries at stride-15, tracking winner (highest 64-bit score) and loser (lowest). For each player:
- Calls `CShowHandMgr__SetPlayerResult(playerID, scoreLow, scoreHigh, resultFlag)` to display result
- If BYTE[+8] flag is set: looks up player, calls `CShowHandPlayer__func_016(2)` for winner effect
- If player is local hero: posts 0xCFA (result screen), checks money via `Handle_Sh_No_Money_Confirm`, shows "ShInsufficientFunds" if applicable

After iteration:
- Shows winner broadcast via `Handle_Sh_Broadcast_Winner`
- Shows loser via `CShowHandMgr__ShowLoserEffect`
- Calls `CShowHandMgr__ShowRoundEndEffects` for cleanup
- Sets `CShowHandMgr__SetNextRoundReady(1)` for next round ready
- Advances state via `CShowHandMgr__SetStateTimer(WORD[+4], 5)`

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Sequence number |
| +6 | WORD | Player count |
| +8+ | stride-15 | Per-player: BYTE resultFlag, DWORD playerID, DWORD scoreLow, DWORD scoreHigh, WORD handRank |

## CMsgShowHandExit (Type 2096)
**Direction**: S->C

**Wire type**: 2096 (0x0830)
**Create**: `CMsgShowHandExit__Create` @ `0x75125E`
**Process**: `CMsgShowHandExit__Process` @ `0x751326`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Handles player exit from a ShowHand table. Only processes mode 1 (WORD[+4] == 1).

**If exiting player is local hero** (DWORD[+12] == local hero ID):
- Posts 0xCF9 (exit table UI)

**If exiting player matches local table** (DWORD[+8] == local table ID via `CShowHandMgr__GetTableId`):
- Removes player from table display via `CShowHandMgr__RemovePlayerById(playerID)`
- Posts 0xD0A (refresh table) + 0xD0C (player left)
- Broadcasts updated player count via `Handle_Sh_Broadcast_Player_Count_In_Game`

| Offset | Size | Field |
|--------|------|-------|
| +4 | WORD | Mode (1 = exit) |
| +8 | DWORD | Table ID |
| +12 | DWORD | Player entity ID |

## CMsgShowHandOnlineStatus (Type 2097)
**Direction**: S->C

**Wire type**: 2097 (0x0831)
**Create**: `CMsgShowHandOnlineStatus__Create` @ `0x75C471`
**Process**: `CMsgShowHandOnlineStatus__Process` @ `0x75C4FA`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Updates a player's online/offline status at a ShowHand table. Validates table state via `CShowHandMgr__IsLocalPlayerInTable`.

Only processes if DWORD[+8] matches local table ID (via `CShowHandMgr__GetTableId`):
- Mode 1 (BYTE[+4] == 1): player came online → `CShowHandMgr__SetPlayerOnline(playerID)`
- Other modes: player went offline → `CShowHandMgr__SetPlayerOffline(playerID)`
- Updates UI via `UIHelper__6B2E34(playerID)`

| Offset | Size | Field |
|--------|------|-------|
| +4 | BYTE | Status (1 = online, other = offline) |
| +8 | DWORD | Table ID |
| +12 | DWORD | Player entity ID |

## CMsgShowHandLostInfo (Type 2098)
**Direction**: S->C

**Wire type**: 2098 (0x0832)
**Create**: `CMsgShowHandLostInfo__Create` @ `0x75B575`
**Process**: `CMsgShowHandLostInfo__Process` @ `0x75B5FE`
**Packet object**: Standard layout — payload pointer at `this+257` (byte offset 1028), inline buffer at `this+4`.

Reconnection / state recovery packet for ShowHand. Restores game state when a player reconnects mid-game. Validates table state via `CShowHandMgr__IsLocalPlayerInTable`.

**Phase 1: Player card state** (iterates BYTE[+6] player entries at stride-11 from +52)
- Looks up player by DWORD at entry offset
- For each player with up to BYTE[+45] cards (max 2): restores card suit/value/visibility via `CShowHandPlayer__AddCard`, applies via `CShowHandPlayer__UpdateCardCount`

**Phase 2: Community cards and game state**
- Restores BYTE[+5] community cards (max 5) from offset +35 at stride-2 (suit, value pairs)
- Sets dealt card round via `CShowHandMgr__SetDealRound(BYTE[+4])`
- Sets pot via `CPackage__SetDword_0x34`, small blind via `CShowHandMgr__SetSmallBlind(DWORD[+27])`, big blind via `CShowHandMgr__SetBigBlind(DWORD[+31])`
- If DWORD[+19] (active player ID) is set: calls `CShowHandMgr__SetActivePlayerTurn` with player ID, round WORD[+9], doubled bet (2 * DWORD[+11]), and combined bet (DWORD[+11] + DWORD[+15])
- Advances state via `CShowHandMgr__SetStateTimer(WORD[+7], 2)`

| Offset | Size | Field |
|--------|------|-------|
| +4 | BYTE | Current dealing round |
| +5 | BYTE | Community card count (0-5) |
| +6 | BYTE | Player count |
| +7 | WORD | Sequence number |
| +9 | WORD | Current round |
| +11 | DWORD | Current bet |
| +15 | DWORD | Raise amount |
| +19 | DWORD | Active player entity ID |
| +23 | DWORD | Pot amount |
| +27 | DWORD | Small blind |
| +31 | DWORD | Big blind |
| +35 | 10 bytes | Community cards (5x: BYTE suit, BYTE value) |
| +45+ | BYTE | Per-player card count |
| +46+ | variable | Per-player card data (suit, value, visibility) |
| +52+ | stride-11 | Per-player entries: DWORD playerID, card data |

## CMsgArenaChallenge (Type 2210)
**Direction**: Bidirectional
