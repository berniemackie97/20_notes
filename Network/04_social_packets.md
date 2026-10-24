# Social Packets — Chat, Team, Friends, Trade, Flowers, Coach

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

## MsgTalk (Type 1004)
**Direction**: Bidirectional
**Handler**: CTxtMsgSet__ParseMessage (0x731371)
**Parse**: `CMsgTalk__Parse` validates size/type and copies the packet to object+4.

**Verified field offsets (relative to packet start)**:
- `+0` `uint16` size (checked against `Size`)
- `+2` `uint16` type (checked == 1004)
- `+4` `uint32` color (OR'ed with `0xFF000000` for display)
- `+8` `uint16` channel/type (compared to 2000/2001/2003/2005/2006/2007/2100–2115/2300/2500)
- `+10` `uint16` style (passed to `CChatLog__AddMessage`)
- `+12` `uint32` data (passed to `CChatLog__AddMessage`)
- `+20` `uint32` timestamp/packed time (used with `/ 0x2710` and `% 0x3E8` to derive time fields)

**String list helper (format verified)**:
`CTxtMsgSet__ParseMessage` reads indices 0..3 from a string-list object at `this+0x408` (ECX = `this+0x408` passed to `MsgStringList__GetEntry`).
`MsgStringList__GetEntry` expects a list format: first byte = count, then repeated `[len][bytes]` entries.
`MsgStringList__GetEntry` zeroes the destination buffer before attempting lookup and requires `destination_size > entry_len` (equal size fails).

### Verified login/control system-talk branches

The startup/login flow uses ordinary `MsgTalk (1004)` packets carrying control strings; these are not cosmetic chat lines.

BNinja anchors:
- `CMsgTalk__Process` (`0x731371`)
- `CMyShellDlg_HandleLoginStatusSystemTalk` (`0x5DCC64`)
- `CMyShellDlg_HandleCreateRoleStatusSystemTalk` (`0x5DCDDF`)
- `CMyShellDlg_WindowProc_DispatchMainWindowMessages` (`0x5BB79D`)
- `CConnectionFlow__SendGameSessionBootstrap` (`0x6DF1D0`)

Verified control strings:
- `"ANSWER_OK"`
  - login-status branch (`0x5DCC64`): clears/advances startup loading state, updates the loading trace, and continues the login callback path.
  - create-role branch (`0x5DCDDF`): clears create-role loading state, updates the loading trace with `STR_CREATE_ROLE_SUCCESS`, and calls `CConnectionFlow__SendGameSessionBootstrap`.
- `"NEW_ROLE"`
  - login-status branch (`0x5DCC64`): calls `CLoginFlashCallbackState_SetModeHandlerByCode(..., 0x3EC)` and posts `WM_COMMAND 0x464` with `wParam=3`.
  - window-proc branch (`0x5BB79D` case `3`): runs the create-role startup-host transition path; it is distinct from world-enable `0x483`.

Parity note:
- `ANSWER_OK` must remain a real `1004` control/system talk in the startup flow.
- It should not be replaced with a synthetic side-channel or treated as display-only text.
- `NEW_ROLE` is a separate control branch. Startup must stop waiting for world bootstrap on this branch and hand off through `WM_COMMAND 0x464 / 3`, not `0x483`.

## MsgInteract (Type 1022)
**Direction**: Bidirectional
**Purpose**: Subtype‑driven entity/effect/map update packet; see subtype table for verified behavior.
**Dispatch**: Construct `CMsgInteract__ctor` (0x6FADEE), parse `CMsgInteract__Parse` (0x6FB16A), process `CMsgInteract__Process` (0x6FB1CB)

**Parse**: `CMsgInteract__Parse` — standard header validation, then `type == 1022`.
- The five verified builders at `0x6FAE54`, `0x6FAF42`, `0x6FAFC1`, `0x6FB052`, and `0x6FB0F3` all produce a fixed 40-byte packet.
- The mutual-interaction lifecycle is client-sent and client-processed:
  - `CHero_SendMsgInteractSubtype47` (`0x66485B`) sends subtype `47` only while
    `CHero+0x2EEC == 0`.
  - `CHero_SendMsgInteractSubtype48` (`0x664983`) sends subtype `48` under the same status gate.
  - `CHero_TickInteractionActionState` (`0x664505`) sends subtype `49` after a pending
    interaction reaches the controller-selected meeting tile.
  - `CHero_SendInteractionStopSubtype50` (`0x6648E5`) sends subtype `50` while
    `CHero+0x2EEC != 0` and the map overlay-render-mode flag is clear.
  - All four packets set `+0x08` to the local hero ID, identify the partner at `+0x0C`,
    and carry the interaction type at `+0x18`.

**Verified field usage in `CMsgInteract__Process`** (offsets relative to packet start):
- `+0x00` (u16) is the fixed packet size, `40`.
- `+0x02` (u16) is the packet type, `1022`.
- `+0x04` (u32) is a timestamp.
- `+0x08` (u32) is passed to `EntityManager__FindEntityById` (entity lookup) and to other handlers such as `CMagicEffect__CreateInstance` / `CGameMap__RemoveEntriesByTypeAndId`.
- `+0x0C` (u32) is passed to `EntityManager__FindEntityById` and used as a parameter in multiple branches.
- `+0x10` (u16) is read and passed to `CGameMap__CalcScreenPosFromTile`.
- `+0x12` (u16) is read and passed to `CGameMap__CalcScreenPosFromTile`.
- `+0x14` (u16) is the primary branch selector: a large switch/jump table uses this field to route handling logic.
- `+0x18` (u32) is used as a packed value. Verified derived values include:
  - `(packet_u32_18 >> 24) & 0xF` (nibble extraction)
  - `(packet_u32_18 >> 28) & 0xF` (top nibble)
  - `*(u16*)(packet+0x18)` is also read in some branches.
- `+0x1A` (u16) is read as a value for UI/formatting logic (clamped and used for string selection).
- `+0x1C` (u32) is read and passed to handlers (e.g., `CRole__SetDisdainEffect`).
- `+0x20` (u32) is read and passed to handlers (e.g., `CRole__ApplyHitEffectFlags`, `ApplyFiveElementPropertyEffects`) and used in multiple UI/logic paths.
- `+0x20` is also read as a `u8` in some branches (bit test of `packet+0x20`).
- `+0x24` (u32) is read and passed to `ApplyFiveElementPropertyEffects` and other handlers.

**Subtype switch (`packet+0x14` as u16)**:
- `2`: uses `+0x08`, `+0x0C`; compares against singleton `+0xCC` and may call `CBossEffectMgr__SetBossEntityId`; then runs UI refresh path (calls `RefPtr__Assign`, `j_s__GetSingletonPtr_63EFAD`, `CMonsterSayMgr__TriggerSayIfEligible`).
- `8`: uses `+0x08`; entity lookup via `EntityManager__FindEntityById`.
- `13`: uses `+0x10`, `+0x12`, `+0x18`; calls `CGameMap__CalcScreenPosFromTile` and `CGameMap__FindComponent_Type2`, then spawns an effect via a component helper (the subtype value `13` is also passed through to the helper).
- `14`: uses `+0x0C`, `+0x10`, `+0x12`; calls `CGameMap__RemoveEntriesByTypeAndId` and `CRole__SetTilePosAndScreenPos`.
- `24`: uses `+0x18` and `+0x08`; calls `CGameMap__RemoveEntriesByTypeAndId`, `CHero__UpdateTimedIdMap_0xFA8`, and branches on `+0x18` with multiple sub-cases.
- `26`: uses `+0x1C`, `+0x18`; calls `CRole__SetDisdainEffect` and drives UI update path (color selection based on `+0x18`).
- `27`: falls through to the general block starting at `0x6FB335`; uses `+0x08`, `+0x0C`, `+0x10`, `+0x12`, `+0x18`, `+0x1C` in the subsequent logic.
- `28`: uses `+0x08`, `+0x0C`; similar singleton compare/call pattern as subtype `2`, followed by UI refresh path.
- `29`: uses `+0x1C`, `+0x18`; calls `CRole__SetDisdainEffect` and drives UI update path.
- `31`: uses `+0x1A`, `+0x1C`; calls `CHero__SetMapValue_0x2F4C`.
- `32`: uses `+0x1A`, `+0x1C`; calls `CHero__AddToMapValue_0x2F40`.
- `35`: uses `+0x1C`, `+0x08`; calls `IdList__Update`.
- `36`: uses `+0x1A`, `+0x1C`; calls `CHero__GetMapValue_0x2F40` / `CHero__SetMapValue_0x2F4C`.
- `37`: no packet fields referenced in handler; just UI notification (`PostMainWndMsg_0x464` with constant).
- `39`: uses `+0x1C`; pushes `+0x1C` then `PostMainWndMsg_0x464` path.
- `40`: uses `+0x1C`; if nonzero, triggers UI path (`PostMainWndMsg_0x464` with constant).
- `41`: default (no handler).
- `42`: uses `+0x1C`; triggers UI path (`PostMainWndMsg_0x464` with constant).
- `43`: uses `+0x08`, `+0x0C`, `+0x10`, `+0x12`, `+0x1C`, `+0x20`, `+0x24`; combines `+0x10/+0x12` into a 32-bit value and passes `+0x1C` / `+0x20` / `+0x24` into downstream calls.
- `44`: uses `+0x18`; calls `CHero__SetScapegoatSwitch` with a boolean derived from `+0x18`.
- `45`: same handler as subtype `2` (uses `+0x08`, `+0x0C`).
- `46`: uses `+0x08`, `+0x18`; allocates a small struct, stores `+0x08`/`+0x18`, then UI path.
- `47`: pending mutual-interaction initialization. Processing continues only when the local
  hero is `+0x08` or `+0x0C`, `CHero.boothManager.isActive == 0` (`CHero+0x2A5C`), and
  `InteractionType_IsUnavailableForCurrentLanguage(+0x18)` is false. It chooses the opposite
  entity as the partner and calls `CHero_BeginPendingMutualInteraction` (`0x664221`) with
  interaction type `+0x18`, action ID `+0x1C`, partner ID, and a boolean recording whether
  the local hero was the target. The helper writes partner/status/controller meeting-tile
  state at `CHero+0x2EDD..+0x2EEC`, writes interaction type/action ID to
  `CRole+0x388/+0x38C`, and either invokes the controller immediately or requests command type
  `0x12` movement to the controller-selected meeting tile through
  `Role_RequestCommandType12MoveToTile` (`0x657CD6`). That helper resets and dispatches the
  command block immediately; it is not a queue insertion. The target-side movement branch calls
  `MapPathService_TryBuildPath(outputPath=null, limitSearchNodes=true)` using the full native tile-tail
  search. Failure dispatches `STR_INTERACT_FORBID_CANTREACH` with code `0x7D5` and color
  `0xFFFF0000`, then sends subtype `50`. A direct-distance or approximate reachability test is not equivalent.
- `48`: interaction-controller state update. Calls
  `CMsgInteract_ProcessSubtype48InteractionState` (`0x70EF1C`) with interaction type
  `+0x18` and source entity `+0x08`. The helper resolves the source without local-hero
  fallback, but does not require resolution to succeed. It creates the controller and stops
  with no feedback or timestamp only when no controller exists (type `100006` and
  out-of-range values). Otherwise it invokes controller slot `+0x24`, then records or
  refreshes `timeGetTime()` in the nested table
  `g_mutualInteractionRejectionCooldownByEntity[sourceEntityId][interactionType]`.
  `MutualInteractionRejectionCooldown_IsActive` (`0x70EED6`) returns true only while unsigned
  `timeGetTime() - storedTick < 0x927C0` (600,000 ms), preserving 32-bit tick wrap.
  Verified controller feedback is:
  - `100000` through `100004`: local-hero role effect `gam_refuse` parameter `1` when
    `CHero+0x430` exists, card `CARD_YOUAREGOODMAN` parameter `0`, then
    `STR_MUTUAL_REJECTED` with message code `0x7D5` and color `0xFFFF0000`.
  - `100005`: the same role effect and message, with card `CARD_FEMBRACE`.
  - `100007`: the same role effect and message, with card `CARD_FHUGWALK`.
  - `100008` and `100009`: the shared role-reference-release no-op callback; no visible
    feedback, but the timestamp is still recorded.
  - `100010`: local-hero role effect `dbdance_ref` parameter `1` when `CHero+0x430` exists;
    initialize an empty 256-byte card-text buffer and, when the source role exists, format
    `STR_DOUBLEDANCE_REJECT_BY_OTHER` with `CRole+0x14C` using `_snprintf` size `0xFF`;
    always play `CARD_DOUBLEDANCE_REJECT` parameter `0`, set its text to that buffer, and
    dispatch `STR_MUTUAL_REJECTED` with message code `0x7D5` and color `0xFFFF0000`.
- `49`: paired-interaction start. If `+0x08` is the local hero, first calls
  `CHero_CancelRunningOrReadyInteractionAction` (`0x66402F`) and updates the hero map
  coordinate gates from `+0x10/+0x12`. It resolves the source role, recomputes its
  coordinate cache, writes its tile from `+0x10/+0x12`, and applies packed direction
  `+0x1C` modulo 8. `CMsgInteract_ProcessSubtype49InteractionStart` (`0x70F1CC`) then
  resolves source `+0x08` and target `+0x0C`, writes interaction type `+0x18` and
  interaction action ID `+0x1C` to `CRole+0x388/+0x38C` on both resolved roles, creates
  the controller for `+0x18`, and invokes controller slot `+0x20` with only the source.
  This same packet is emitted by `CHero_TickInteractionActionState` after status `1`
  reaches the stored meeting tile; the sender changes `CHero+0x2EEC` to status `2`
  immediately before building it.
- `50`: paired-interaction stop. If `+0x08` is the local hero, posts main-window message
  `0x464` with `wParam=0xC00`, `lParam=1`.
  `CMsgInteract_ProcessSubtype50InteractionStop` (`0x70F092`) resolves source `+0x08`
  and target `+0x0C`. When source command type is `0x19`, progress is not `6`, and the
  target exists, it creates the controller for interaction type `+0x18` and invokes
  controller slot `+0x0C` on the source. Type `100006` deliberately has no controller,
  so that gated path performs no fallback. Otherwise it sets source action type to
  standby `100`, invokes role slot `+0x70`, resets source command state to type `5` with
  position-cache refresh, and dispatches `gam_acc`, `gam_buss_cyc`, `gam_cuddle_cyc`,
  and `dbdance_body`.
- `51`: no packet fields referenced; calls `CRole__SetDword_0x9F0` if local state exists.
- `52`: uses `+0x18`, `+0x1A`; drives a sequence of `RefPtr__Assign` / `MagicEffectIni__GetEntryByIdAndLevel` / `Load_MagicEffect_Ini_69D515`.
- `53`: uses `+0x18`, `+0x1A`, `+0x10`, `+0x12`; calls `Load_MagicEffect_Ini_69D154`, `EffectRequest__Dispatch_46_919`, `CHero__UpdateMapInfoFromTiles`.
- `54`: uses `+0x18`; branches on `+0x18` and then runs UI construction path (no other packet fields observed).
- `55`: uses `+0x18`; calls `ApplyPropertyEffectFlags`.
- `56`: jump table target is `0x6FE33A`; IDA does not decode code at that address in this build (next code is at `0x6FE358`). No packet field usage was observed for subtype `56`.

## MsgTeamMemberList (Type 1026)
**Direction**: S→C
**Purpose**: Team member list refresh/join notifications (uses string `100114`: "%s has joined the team!").
**Dispatch**: Create `CMsgTeamMemberList__Create` (0x761A02), parse `CMsgTeamMemberList__Parse` (0x761A68), process `CMsgTeamMemberList__Process` (0x761AB1)

**Verified parse behavior**:
- `CMsgTeamMemberList__Parse` validates `Src`/`Size` using `CNetMsg__GetSize` and `CNetMsg__GetType` (type check for 1026), then `memcpy`s the packet into `this+4`.

**Verified field usage in `CMsgTeamMemberList__Process`** (offsets relative to packet start):
- `+4` (u8) is checked; if `== 1`, `CHero__TeamClear` is called.
- `+5` (u8) is treated as a count of entries.
- Entries are processed in a loop with stride `0x1C` (28 bytes) starting at `+8`:
  - `entry+0` (string, null-terminated) is passed to `strlen`/`ByteBuffer__AppendRange`.
  - `entry+16` (u32) is used as an ID in `CHero__TeamHasMember` and compared against local player ID.
  - `entry+20` (u32) is used in `v12[4] = value / 0x2710 % 0x3E8`.
  - `entry+24` (u16) and `entry+26` (u16) are copied into fields `v12[5]` and `v12[6]`.
- When a listed member is not already in the team and is not the local player, the handler posts system message `100114` (`%s has joined the team!`).

## MsgGuide (Type 1042)
**Direction**: Bidirectional
**Purpose**: Guide/monster transformation UI flow (verified by `Guide__*` calls and entity lookups).
**Dispatch**: Create `CMsgGuide__Create` (0x761CD3), parse `CMsgGuide__Parse` (0x761D39), process `CMsgGuide__Process` (0x761D5C)

**Parse**: `CMsgGuide__Parse` — standard header validation, then `type == 1042`.

**Verified field usage in `CMsgGuide__Process`** (offsets relative to packet start):
- `+8` (u32/pointer) is compared against `Concurrency::details::UMSSchedulerProxy::GetTransferListEvent()`; processing only continues if equal.
- `+36` (u8) must be nonzero to proceed; later passed into string formatting (`Guide__FormatMonsterName`) and used as a parameter for UI/log output.
- `+20` (u32) is treated as an entity ID ("old monster"): looked up via `EntityManager__FindEntityById`; if missing, logs `"pOldMonster"`; if found, passed to `EntityManager__RemoveEntityById_6E7B23` with flag `1`.
- `+28` (u32) is treated as an entity ID ("new monster"): looked up via `EntityManager__FindEntityById`; if missing, logs `"pNewMonster"`; if found, used for vtable calls and UI updates.
- `+4` (u32) is passed to a vtable call at offset `+0xA4` on the new entity object.

## MsgTradeDialog (Type 1040)
**Direction**: Bidirectional
**Purpose**: Trade dialog state (verified by `CTradeDialog__*` and `CHero__Trade*` calls).
**Dispatch**: Create `CMsgTradeDialog__Create` (0x72CCEF), parse `CMsgTradeDialog__Parse` (0x72CD55), process `CMsgTradeDialog__Process` (0x72CDA9)

**Parse**: `CMsgTradeDialog__Parse` — standard header validation, then `type == 1040`.

**Verified field usage in `CMsgTradeDialog__Process`** (offsets relative to packet start):
- `+4` (u32) is compared to the local player ID (singleton `+204`) to select the local/remote trade branch; the local branch triggers `CTradeDialog__SetLocalTraderId` and UI events `PostMainWndMsg_0x464(0xC6D)` and `PostMainWndMsg_0x464(0xDEA)`, the remote branch triggers `CTradeDialog__SetRemoteTraderId` and `PostMainWndMsg_0x464(0xC6C)`.
- `+8` passed to `CCheckListBox::SetCheckStyle`.
- `+12` passed to `CDocument::SetModifiedFlag`.
- `+16` passed to `MFC__SetDword_0x58`.
- `+20` passed to `COleControl::ResetVersion`.
- `+24` passed to `CAsyncMonikerFile::SetFormatEtc` (pointer).
- `+28` passed to `CDocument::SetModifiedFlag`.
- `+32` passed to `MFC__SetDword_0x50`.
- `+36` passed to `CObject__SetDword_0xC`.
- `+40` passed to `MFC__SetDword_0x8`.
- `+44` passed to `CObject__SetDword_0x10`.
- `+48` passed to `MFC__SetDword_0x4`.
- `+52` passed to `CObject__SetDword_0x14`.
- `+56` passed to `MFC__SetDword_0x18`.
- `+60` passed to `MFC__SetDword_0x68`.
- `+64` passed to `MFC__SetDword_0x3C`.
- `+68` passed to `MFC__SetDword_0x60`.
- `+72` passed to `MFC__SetDword_0x4C`.
- `+76` passed to `MFC__SetDword_0x1C`.
- `+80` passed to `MFC__SetDword_0x54`.
- `+84` passed to `MFC__SetDword_0x6C`.
- `+88` passed to `MFC__SetDword_0x20`.
- `+92` passed to `MFC__SetDword_0x24`.
- `+96` passed to `MFC__SetDword_0x64`.
- `+100` passed to `MFC__SetDword_0x34`.
- `+104` passed to `CDataPathProperty::SetControl` (pointer).
- `+108` passed to `MFC__SetDword_0x38`.
- `+112` passed to `MFC__SetDword_0x30`.
- `+116` passed to `MFC__SetDword_0x70`.
- `+120` passed to `COleDocument::EnableCompoundFile`.
- `+124` passed to `MFC__SetDword_0x78`.
- `+128` passed to `CRichEditCntrItem::Mark`.
- `+132` passed to `CPropertySheet::EnableStackedTabs`.

## MsgBrocastMsg (Type 1043)
**Direction**: S→C
**Purpose**: Broadcast/team‑roll UI update (verified by `CTeamRollMgr__*` calls and UI posts).
**Dispatch**: Create `CMsgBrocastMsg__Create` (0x720357), parse `CMsgBrocastMsg__Parse` (0x7203BD), process `CMsgBrocastMsg__Process` (0x720427)

**Parse**: `CMsgBrocastMsg__Parse` — standard header validation, then `type == 1043`.

**Verified field usage in `CMsgBrocastMsg__Process`** (offsets relative to packet start):
- `+12` (u32) is a mode selector; only when `== 1` does the handler proceed.
- `+4` (u32) and `+20` (u32) are passed to `CTeamRollMgr__SetEntryDword_0x8_ByItemId`.
- `+4` (u32) and `timeGetTime()` are passed to `CTeamRollMgr__SetEntryDword_0xC_ByItemId`.
- On success path, `PostMainWndMsg_0x464(0xDDA, 0)` is triggered.

## MsgInviteTrans (Type 1074)
**Direction**: Bidirectional
**Purpose**: UI notification only (verified by a single `PostMainWndMsg_0x464(0xCEF, 0)` call).
**Dispatch**: Create `CMsgInviteTrans__Create` (0x75D874), process `CMsgInviteTrans__Process` (0x75D8FD)

**Verified behavior**:
- No packet fields referenced.
- Posts `PostMainWndMsg_0x464(0xCEF, 0)`.

## MsgFlower (Type 1150)
**Direction**: Bidirectional
**Purpose**: Flower system packet (receive/give notifications + local flower-counter sync).
**Dispatch**: Create `CMsgFlower__Create` (0x76400B), parse `CMsgFlower__Parse` (0x7640DF), process `CMsgFlower__Process` (0x764102)

**Parse**: `CMsgFlower__Parse` — standard header validation, then `type == 1150`.

**Verified field usage in `CMsgFlower__Process`** (offsets relative to packet start):
- `+4` (u16) `mode` (handled: `0`, `1`).
- If `mode == 0`, `CMsgFlower__Process` forwards to `CHero__HandleFlowerEvent_70733E` with `payload = packet + 16`. `CHero__HandleFlowerEvent_70733E` uses:
  - `payload +0` (char[16]) `sender_name` (15-char, null-terminated copy)
  - `payload +16` (char[16]) `receiver_name` (15-char, null-terminated copy)
  - `payload +32` (u32) `count` (ignored if `0`; special handling for `99` and `999`)
  - `payload +36` (u32) `flower_type` (0..3 mapped via sprite/key selection)
  - `payload +40` (u8) `flag_40` (used only when `flower_type == 0`)
- If `mode == 1`, `CMsgFlower__Process` checks the local-hero dword at `CHero+0x178`:
  - If `*(u32*)(CHero+0x178) == 1`: posts `PostMainWndMsg_0x464(0x4DC, 0)`.
  - If `*(u32*)(CHero+0x178) == 2`: copies 8 dwords from `packet + 16` into hero fields via `CHero__SetFlowerCountersFromPacket_70711A(packet+16)` and posts `PostMainWndMsg_0x464(0x4DD, 0)`.
  - Other values: no additional handling in this build.

**Verified `CHero__SetFlowerCountersFromPacket_70711A` mapping**:
Let `src[i] = *(u32*)(packet + 16 + 4*i)` (i.e., 8 dwords starting at `packet+16`). The helper writes:
- `CHero+0x2D64 = src[1]`
- `CHero+0x2D68 = src[3]`
- `CHero+0x2D6C = src[5]`
- `CHero+0x2D70 = src[7]`
- `CHero+0x2D74 = src[0]`
- `CHero+0x2D78 = src[2]`
- `CHero+0x2D7C = src[4]`
- `CHero+0x2D80 = src[6]`

**Verified flower-type mapping used by the notification path**:
- `flower_type == 0`: `"red"` (e.g., `"red-flower-full"`, `"red-flower-r-999"`)
- `flower_type == 1`: `"white"`
- `flower_type == 2`: `"NEW"`
- `flower_type == 3`: `"tulip"`
Evidence: `FlowerAnim__SelectBaseSpriteByTypeAndScreenWidth_70701B` / `FlowerAnim__SelectRainSpriteByTypeAndScreenWidth_707097` and key table `g_FlowerAssetKeyTable (0x946520)` used by `FlowerAssetKey__GetByGiveReceiveTypeCount_706FDC`.

**Verified outgoing builder (`client -> server`)**:
- `CMsgFlower__BuildSize60_Mode0_Params_764071` initializes:
  - `size = 60`, `type = 1150`
  - `+4 = 0` (u16 mode)
  - `+8 = arg0` (u32)
  - `+12 = arg3` (u32)
  - `+16 = arg0` (u32, duplicate)
  - `+20 = arg1` (u32)
  - `+24 = arg2` (u32)
- `SendMsgFlower_707168` wraps create/build/send for this builder.

## MsgFlowerRank (Type 1151)
**Direction**: S→C
**Purpose**: Flower-rank list + flower-UI control packet (drives `DlgFlowerRank` updates and related UI message flows).
**Dispatch**: Create `CMsgFlowerRank__Create` (0x706D07), parse `CMsgFlowerRank__Parse` (0x706DC7), process `CMsgFlowerRank__Process` (0x706DEA)

**Parse**: `CMsgFlowerRank__Parse` — standard header validation, then `type == 1151`.

**Verified field usage in `CMsgFlowerRank__Process`** (offsets relative to packet start):
- `+4` (u8) `subtype` (handled: `1`, `2`, `4`, `5`).
- `+16` (u32) `count_or_flag` (subtypes `1/2/4` gate on `>= 1` / count).
- Subtype `1` wire record base is `+24` and repeats every `56` bytes; only a subset is consumed by the client:
  - `+24 + 56*i + 0` (u8) `rank_or_index_i` (stored into the posted entry as s32; `-1` marks unused)
  - `+24 + 56*i + 8` (u32) `value_lo_i`
  - `+24 + 56*i + 12` (u32) `value_hi_i`
  - `+24 + 56*i + 40` (char[32]) `name_i`
- Subtype `2` uses:
  - `+8` (u32) `id_low`
  - `+24` (u8) `id_high_mul_10000`
  - `+44` (u32) `hero_id_check`
- Subtype `4` uses:
  - `+8` (u32) `id_8`
  - `+44` (u32) `id_44`
- Subtype `5` uses local-hero fields and does not consume packet fields beyond the subtype.

**Verified subtype behavior**:
- `1` (rank list):
  - Allocates an array of 10 entries (`0x1E0` bytes; 10 * 48).
  - For each slot i in 0..9:
    - If `i < count_or_flag`, populates entry fields from the packet record subset above.
    - Else sets entry.rank = `-1`.
  - Posts `PostMainWndMsg_0x464(0x513, entries_ptr)`.
  - The posted entry layout is:
    - `+0` (s32) `rank_or_index` (`-1` means unused)
    - `+8` (u64) `value` (lo/hi from packet)
    - `+16` (char[32]) `name`
  - Evidence: `CDlgFlowerRank__PopulateRankEntry` at `0x48F39F` reads this structure (`itoa` at `+0`, `i64toa` of qword at `+8`, name at `+16`).
- `2`:
  - If `count_or_flag >= 1` and local-hero entity_id equals `hero_id_check` (`*(u32*)(packet+44)`):
    - computes `encoded_id = id_low + 10000 * id_high_mul_10000`,
    - appends it to hero buffer at `CHero+0xE7C` via `CHero__AppendU32_ToBuf_0xE7C_65777C(encoded_id)`.
- `4`:
  - If `count_or_flag >= 1` and local-hero entity_id differs from `*(u32*)(packet+44)`:
    - allocates an 8-byte struct `{ u32 a = *(u32*)(packet+44), u32 b = *(u32*)(packet+8) }`,
    - posts `PostMainWndMsg_0x464(0x4F3, ptr)`.
- `5`:
  - Calls `CHero__SelectBestEncodedIdFromList_65782D()` (selects a value from the hero list at `CHero+0xE7C` and writes it to `CHero+0xE88`).
  - Allocates an 8-byte struct `{ u32 hero_id, u32 selected_value }` where `selected_value = CHero__GetDword_0xE88_6577A3()`.
  - Posts: `PostMainWndMsg_0x464(0x4F3, ptr)`, then `PostMainWndMsg_0x464(0x514, 0)`, `PostMainWndMsg_0x464(0x515, 0)`, `PostMainWndMsg_0x464(0xCE8, 0)`.

**Verified outgoing builder (`client -> server`)**:
- `CMsgFlowerRank__BuildSize80_SubtypeAndParam_706D7D` initializes:
  - `size = 80`, `type = 1151`
  - `+4 = subtype` (u8)
  - `+8 = param` (u32)
  - `+12 = param2` (u8)

## MsgCoach (Type 1127)
**Direction**: Bidirectional
**Purpose**: Coach/apprentice relationship packet (coach/be-coach status updates, directional role actions, and coach UI/chat notifications).
**Dispatch**: Create `CMsgCoach__Create` (0x6ED9F1), parse `CMsgCoach__Parse` (0x6EDA57), process `CMsgCoach__Process` (0x6EDAC8)

**Parse**: `CMsgCoach__Parse` — standard header validation, then `type == 1127`.

**Verified field usage in `CMsgCoach__Process`** (offsets relative to packet start):
- `+4` (u16) `subtype` (values `0`, `1`, `2` handled in this build).
- `+8` (u32) `entity_id_a` (primary role ID in subtype `0`; role ID for subtype `2`).
- `+12` (u32) `entity_id_b` (secondary role ID in subtype `0`; local check target in subtype `1`).
- `+16` (u16) `value_16` (passed to role vfunc `+228` in subtype `2`).
- `+20` (s32) `delta_x` and `+24` (s32) `delta_y` (used to compute facing direction pairs in subtype `0`).

**Verified subtype behavior in `CMsgCoach__Process`**:
- `0`:
  - Looks up entities `entity_id_a` and `entity_id_b`.
  - If `entity_id_a` exists:
    - Computes facing from `(delta_x, delta_y)` and calls role-action helper with action id `480`.
    - Applies marker string `"Stipple_dhz"` on role-view component if present.
    - Updates coach-side prompt/state via role metric helper and either local prompt handler or role vfunc `+220`.
  - If `entity_id_b` exists:
    - Computes facing from `(-delta_x, -delta_y)` and calls role-action helper with action id `481`.
    - Applies marker string `"Stipple_bdh"` on role-view component if present.
    - Recomputes coach-related value using `CHero__CoachList_GetValueByIndex_6ED75E`, `CHero__CoachList_GetValueDiv5_6ED7B5`, and `CHero__CalcExpWithBonus`, then writes result via role vfunc `+228`.
  - If local hero ID equals `entity_id_a`:
    - Stores `entity_id_b` via `CHero__SetDword_0x2DCC`.
    - Sets singleton string-state key `"COACH"`.
    - If `entity_id_b` exists, formats red system text from `STR_COACH_COACH_O`.
  - If local hero ID equals `entity_id_b`:
    - Snapshots local role fields via `CHero__CopyRoleFieldsToCoachSnapshot_6ED9CC`.
    - Stores `entity_id_a` via `CHero__SetDword_0x2DC8`.
    - Sets singleton string-state key `"BE_COACH"`.
    - If `entity_id_a` exists, computes delta/remaining values via `CHero__CoachList_ComputeDelta_6ED844` and `CHero__CoachList_GetRemainingByValue_6ED7FD`, formats red system text from `STR_COACH_BE_COAC`, and posts `PostMainWndMsg_0x464(0xCA9, entity_id_a)`.
- `1`:
  - If `entity_id_b` equals local hero ID, calls helper at `0x6E682A` with token `"SCR_COACHSENDER"`.
- `2`:
  - Looks up role by `entity_id_a`; if found, calls role vfunc `+228` with `value_16`.
- Other subtype values in this build do not trigger additional processing.

**Verified outgoing builder and send path (`client -> server`)**:
- `CMsgCoach__BuildSize28_SubTypeAndTwoIds` builds a fixed-size packet:
  - `size = 28`, `type = 1127`
  - `+4 = subtype` (u16)
  - `+8 = id_a` (u32)
  - `+12 = id_b` (u32)
- `CHero__TrySendCoachRequest_6ECEFA(target_id)` validates local/target conditions, builds subtype `0` with `(id_a=localHeroId, id_b=target_id)`, sends via `CNetMsg__Send`, and posts `PostMainWndMsg_0x464(0xCAB, 0)` on success.

## MsgVipTeamConfirm (Type 1128)
**Direction**: S→C
**Purpose**: VIP-team confirmation packet for transport/back prompts (message-box flow gated by a local VIP-team entry state).
**Dispatch**: Create `CMsgVipTeamConfirm__Create` (0x72A561), parse `CMsgVipTeamConfirm__Parse` (0x72A5C7), process `CMsgVipTeamConfirm__Process` (0x72A623)

**Parse**: `CMsgVipTeamConfirm__Parse` — standard header validation, then `type == 1128`.

**Verified field usage in `CMsgVipTeamConfirm__Process`** (offsets relative to packet start):
- `+4` (u8) `mode` (only `mode == 2` has a processing path in this handler).
- `+8` (u32) `entry_id` (lookup key for `CHero__FindVipTeamEntryById_65FF73`; also passed as command parameter).
- `+12` (u32) `post_param` (posted via `PostMainWndMsg_0x464(0xD96, post_param)` after dialog path).
- `+16` (char[]) `arg_list` string pointer passed to `CMessageBoxMgr__ShowCommandMessageWithParam`.

**Verified processing flow**:
- If `mode != 2`: returns without side effects.
- If `mode == 2`:
  - Looks up local VIP-team entry by `entry_id` using `CHero__FindVipTeamEntryById_65FF73`.
  - If no entry: returns without side effects.
  - Uses `entry_state = entry[1]`:
    - `entry_state == 0`: shows command message `3288` with token `"CONFIRM_VIP_TEAM_TRANSPORT"`.
    - `entry_state == 1`: shows command message `3287` with token `"CONFIRM_VIP_TEAM_BACK"`.
    - other values: no dialog/post path in this handler.
  - For handled states, passes `entry_id`, `arg_list`, and `entry[2]` into `CMessageBoxMgr__ShowCommandMessageWithParam`, then posts `PostMainWndMsg_0x464(0xD96, post_param)`.

**Verified outgoing builder (`client -> server`)**:
- `CMsgVipTeamConfirm__BuildSize32_ModeAndId_72A5EA` initializes:
  - `size = 32`, `type = 1128`
  - `+4 = mode` (u8)
  - `+8 = id` (u32)
- This builder does not write `+12`/`+16`; those fields are consumed on receive-side paths.

## MsgSchool (Type 1061)
**Direction**: Bidirectional
**Purpose**: School/mentor list update (verified by `CMsgSchool__ClearEntries` / `CMsgSchool__AddEntry`).
**Dispatch**: Create `CMsgSchool__Create` (0x76221F), process `CMsgSchool__Process` (0x7622A8)

**Verified field usage in `CMsgSchool__Process`** (offsets relative to packet start):
- Clears existing list via `CMsgSchool__ClearEntries`.
- `+6` (u16) is entry count.
- Entries start at `+8` with stride 8 bytes: dword at `+8+8*i` and dword at `+12+8*i`. If the second dword is `>= 0`, the pair is passed to `CMsgSchool__AddEntry`.


## Auth string-validation evidence delta — 2026-10-18

The [native auth string-validation closure](Native-auth-string-validation-2026-10-18.md) establishes the1004 missing/extra-entry, ignored-string, NUL and
trailing-byte outcomes, plus the conditional system-ACP round trip before login
control comparison. It compares AUTH-001N against the native acceptance behavior.
