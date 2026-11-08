# Create-role flow (`role.dat`, 5517)

Verified 2026-10-24 in Conquer.exe, graphic.dll and C3_CORE_DLL (Binja). SWF facts from `data/main/role.dat`
(SHA-256 `93b937535c74c6ae56bf7cd1352c0a223e99d6569790c40c0f106f8866d4074e`, CWS, 1024x768, 30 fps, 6 root frames),
decoded with JPEXS.

## Entry

| Step | Anchor | Effect |
|---|---|---|
| 1004 channel 2101 `NEW_ROLE` | `CMyShellDlg_HandleLoginStatusSystemTalk` `0x5DCD19` | login callback mode `0x3EC`; `PostMessage(0x464, 3, 0)` |
| `0x464` wParam 3 | `CMyShellDlg_DispatchCommandCode` case 3 `0x5B2D37` (message-map entry `0x8685E8`; WindowProc's own `0x464` tree has no case 3) | `CMyDialog_ApplyShowHideStateAndLifecycleCallbacks`: login dlg `+0x820` state 0, role dlg `+0xE40` state 5 |
| role dlg show | vtable `0x85E654` → `0x51C8FD` → `CRoleCreateFlashDlg_InitializeFlashMovieAndSeedVariables` `0x51C0AB` | movie `%s/data/main/role.dat`; vars below |

Seeded variables (`CRoleCreateFlashDlg_SetFlashVariableAndDispatch`, `VCTOFLASH = "NAME|value"`):

| Var | Value |
|---|---|
| `PATH` | client root, `\\`→`file:////`, `\`→`/` |
| `USERACCOUNT` | account name buffer `0x96AB38` (written by `CGameMain_AccountSetupAndSendLoginAuthPacket`) |
| `HIDERETURNBTN` | `"1"` when `0x96AB34` (Facebook launch variant) == 0, else `"0"` |

## Talk channels (`CMsgTalk__Process`, split at `0x7314D2`, channel = msg+8 u16)

| Channel | Queue | Reader |
|---|---|---|
| 2100 | `0x96B36C` | `CMyShellDlg_HandleCreateRoleStatusSystemTalk` `0x5DCDDF` (mode `0x3EC` frame, `CLoginFlashCallbackHandler_DispatchMode3ECFrame` `0x5781DB`) |
| 2101 | `0x96B330` | `CMyShellDlg_HandleLoginStatusSystemTalk` `0x5DCC64` |

## role.dat → host commands (`CRoleCreateFlashDlg_HandleFlashCommandString` `0x51C32E`)

| fscommand | Effect |
|---|---|
| `CMD_NICK` | name → `this+0x14C` (snprintf `0xFF`) |
| `CMD_BODYSIZE` | atoi → `this+0x138` |
| `CMD_VOCATION` | atoi → `this+0x13C` |
| `CMD_ENTERGAME` | `CRoleCreateFlashDlg_SubmitCreatePlayerRequest` `0x51C5C3` |
| `CMD_DRIVERBACK` | cancel `1001` (cancel 1, name `""`, body 0, profession 0, session uid), post `0x464/0x481` |
| `CMD_GAMESTART` | post `0x464/0x480` (`+0x179AAC = 1`) |
| `CMD_CLOSE` | `CRoleCreateFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` `0x51C2CF`: stop movie, path `C:/`, `MoveWindow(0,0,0,0)`, post `0x483`, `0xC6B`, mode `0x3F2` |
| `CMD_EXIT` | post `0x55` |
| `CMD_ERROR_RET` | no action |
| `CMD_CRITICAL_RET` | post `0x55` only when `0x96AB34` != 0 |
| `TRACE` | `MessageBoxA` |

SWF `submit()` (root frame 1) sends, in order: `CMD_NICK sUserName`, `CMD_BODYSIZE nSelectBody-1`,
`CMD_VOCATION nSelectJob-1`, `CMD_ENTERGAME 1`. `nSelectJob` 1..12, `nSelectBody` 1 (big) / 2 (small).

## Submit (`0x51C5C3`)

| Check | Result |
|---|---|
| name == `""` (`g_EmptyCString` `0x9560DC`) or byte length < 4 or >= 16 | `CRoleCreateFlashDlg_ShowErrorText(StrRes 10037, 0)` |
| per DBCS char (`String_IsDbcsLeadByteAt` `0x76A246`): `.` not first and not last | accepted |
| every other char: `CMyBitmap::CheckStringPixels(ch, 5, GUI font face (FontSetting +0x10D), normal height)` false | `ShowErrorText(StrRes 11089, 0)` |

`CheckStringPixels` (graphic.dll `0x10015390`) → C3_CORE `Font_CheckPixel` (`0x100030C0`): FreeType mono render at
the nominal pixel height; char passes when lit pixels > 5.

On pass: mode `0x3EC`; body and profession; `1001` sent (`1202` in the Facebook variant); `SetProgressVariable("1")`.

| Vocation index (`nSelectJob-1`) | Body (size 1) | Body (other) | Profession |
|---|---|---|---|
| even (male) | 1003 | 1004 | — |
| odd (female) | 2001 | 2002 | — |
| 0,1 | | | 100 |
| 2,3 | | | 10 |
| 4,5 | | | 40 |
| 6,7 | | | 20 |
| 8,9 | | | 50 |
| 10,11 | | | 60 |

Body size: `nSelectBody-1` → 0 = big, 1 = small. `selectCharacter.ini` `[affirmPanel]`: `vocation0` Male Taoist …
`vocation10` Monk, `vocation11` Saint; `shape0/2` Big, `shape1/3` Small.

## Result (channel 2100, `0x5DCDDF`)

| Text | Effect |
|---|---|
| `ANSWER_OK` (`_stricmp`) | `+0x179AAC = 0`; `LOADING_TRACE` = Cn_Res `STR_CREATE_ROLE_SUCCESS` ("Your character has been successfully created!"); `CConnectionFlow__SendGameSessionBootstrap` `0x6DF1D0` → re-sends `1052` login proof on the same socket (`1203` in Facebook variant) |
| other | `CLoginFlashCallbackState_InvokeProviderMethod8IfPresent` → mode handler slot 2 (`EnsureModeCode3E8`); `ShowErrorText(text, 0)` → `ERROR|text` |

`CRoleCreateFlashDlg_ShowErrorText` `0x51C06B`: null → no-op; `ERROR|text`, or `CRITICAL|text` when Facebook variant
and arg2 != 0.

## Back (`0x464/0x481`, `0x5C6EE4`)

Disconnect game socket (`0x96AFC8`); `CGameMsg_ClearAllMessageQueues` `0x5D336E`; `CRoleCreateFlashDlg_StopMovieAndHide`
`0x51C2A6`; login dlg state 5; start.dat `GOLOGIN|0`.

## Loading (`inGameMC`, sprite 110, root depth 102 at (508,376))

| Frame | Script |
|---|---|
| 1 | `isLoading=false`, hidden; `getLoadingTace(s)` shows and sets `txtMsg1` |
| 2 | `isLoading=true` (reached by `PROGRESS 1`/`80` → `play()`, or confirm OK `gotoAndPlay(2)`) |
| 71 | `stop()`; `CMD_GAMESTART 100` |
| 201 | `stop()`; `CMD_CLOSE 1` |

Loading text order (Binja 2026-10-25, push sites in clean `Conquer.exe`):

| Step | Anchor | Host → role.dat |
|---|---|---|
| 2100 `ANSWER_OK` | `0x5DCDDF` | `LOADING_TRACE` Cn_Res `STR_CREATE_ROLE_SUCCESS`; repeated `1052` |
| 2101 `ANSWER_OK` (created char accepted) | `CMyShellDlg_HandleLoginStatusSystemTalk` `0x5DCC64` → `CMyShellDlg_InitializeShellRegionAndHintSlots` | `LOADING_TRACE` StrRes 11238 "Initializing..." (`0x5DCCF4`; login dlg variant `0x5DCCBD`) |
| each map/role tick | `CMyShellDlg_TickMapRoleAndEffectPipeline` `0x5AFD4C` → `0x5DCEA3` | below |

StrRes push sites: 11237 `0x5DC760` (`CMyShellDlg_ProcessNetAndTraceAccountLogin11237`, login dlg only), 11238
`0x5DCCBD`/`0x5DCCF4`, 11239 `0x5DCF11`/`0x5DCF6B`, 11240 `0x5DCEF0`/`0x5DCF5C`. No other pushes.

`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` `0x5DCEA3` (login dlg `+0x820` checked first, then role dlg `+0xE40`;
same body each), role dlg visible: `+0x179AAC == 1 && +0x179AB8 != 0` →
clear both, `PROGRESS 80` (`CRoleCreateFlashDlg_SetProgressVariable(0x93883C)`), `LOADING_TRACE` StrRes 11240 ("Starting... Please wait..."); else `LOADING_TRACE`
StrRes 11239 ("Creating maps..."). `+0x179AB8` (map-ready flag, byte) writers (Binja 2026-10-25):

| Site | Function | Value | Trigger |
|---|---|---|---|
| `0x5C6B8F` | `CMyShellDlg_WindowProc_DispatchMainWindowMessages` `0x464` cmd `0x47F` (case `0x5C6B89`) | 1 | `Conquer_PostMainWindowMessage464(0x47F)` from `CMsgAction__Process` action 74 (`0x6FF45C`) |
| `0x5AE010` | shell ctor (`...AndInitializeMembers`) | 0 | init |
| `0x5C6ED8` | `CMyShellDlg_HandleStartupCommand0x482_ClearStartupConnectAndOverlayFlags` | 0 | login submit |
| `0x5D520C` | `CMyShellDlg_HandleExitGameRequest` `0x5D51E1` (arg 1) | 0 | exit |
| `0x5D5E71` | `CMyShellDlg_OnExitConfirmYes_ClearStartupFlags` `0x5D5E4E` (also clears `+0x179AAC`) | 0 | exit confirm IDYES |
| `0x5DCAA8` | `CMyShellDlg_ResetRuntimeAndDisableWorldFrameGate` `0x5DC783` (also clears `+0x179AAC`) | 0 | runtime reset |

MsgAction 10010 action 74 (EnterMap reply, `0x6FF44A`): login callback mode `0x3F5`; post `0x47F`;
`g_objGameMap.Create(dwData)` (msg `+8` = map id; `MsgAction.cpp` assert line 779).

Loading sequence, created char (host side, no world rendering needed):

| # | Event | role.dat effect |
|---|---|---|
| 1 | confirm OK → `submit()` + `inGameMC.gotoAndPlay(2)` | bar runs; host `SetProgressVariable("1")` on pass |
| 2 | 2100 `ANSWER_OK` | `LOADING_TRACE` success text; repeated `1052` |
| 3 | 2101 `ANSWER_OK` | `LOADING_TRACE` 11238 |
| 4 | `inGameMC` frame 71 | `stop()`; `CMD_GAMESTART 100` → `+0x179AAC = 1` |
| 5 | action 74 reply | `+0x179AB8 = 1`; map create → map tick runs `0x5DCEA3` |
| 6 | tick, AAC==1 && AB8!=0 | both cleared; `PROGRESS 80` → `inGameMC.play()`; `LOADING_TRACE` 11240 |
| 6' | tick, else | `LOADING_TRACE` 11239 each tick |
| 7 | `inGameMC` frame 201 | `stop()`; `CMD_CLOSE 1` → `0x51C2CF` (stop movie, post `0x483`, `0xC6B`, mode `0x3F2`) |

`0x5DCEA3` runs only from the map tick, so 11239 first appears after step 5.

## role.dat VCTOFLASH handlers (root frame 1 `getMsg`)

`PATH` (loads `ini/selectCharacter.ini`), `ERROR`/`CREATEFAIL` (`errorMC`), `EXIT` (quit windows), `PROGRESS` (`1`, `80`
→ `inGameMC.play()`), `USERACCOUNT`, `LOADING_TRACE`, `BANNED` (empty), `HIDERETURNBTN`.

`HIDERETURNBTN` has no visible effect: `getMsg` passes the undefined `sMsg` instead of the value, and no script reads
`isBtnReturnHide`.

## role.dat root display list

| Frame | Depth | Char | Name | Position (px) |
|---|---|---|---|---|
| 1 | 1 | 60 | — | 0,0 |
| 1 | 2 | 71 | — | 49,315.85 |
| 1 | 38 | 72 | `characterInAndOut` (loads `data/main/flash/characterInAndOut.swf`) | 0,0 |
| 1 | 40 | 58 | `createCharacterMC` | 0,0 |
| 1 | 55 | 75 | `quitWindow` | 0,0 |
| 1 | 64 | 77 | `errorMC` | 0,0 |
| 1 | 73 | 80 | — | 512,690 |
| 1 | 95 | 83 | — | 0,0 |
| 1 | 96 | 84 | `bottomDragonMC` | 0,0 |
| 1 | 98 | 85 | `topDragonMC` | 0,0 |
| 1 | 100 | 86 | `logoMC` (loads `data/main/flash/logo.swf` at ini `[logo]` 776,2) | 0,0 |
| 1 | 102 | 110 | `inGameMC` | 508,376 |
| 1 | 118 | 112 | `quitWindow2` | 0,0 |
| 3 | 74 | 116 | `jobInfo` | 244.95,682.5 |
| 3 | 79 | 122 | `returnBtn` | 106.4,720.3 |
| 3 | 82 | 130 | `nextBtn` | 924.05,718 |
| 3 | 85 | 140 | `flash1` | 864,701 |
| 5 | 4 | 304 | `sb` | 507.3,399.1 |
| 5 | 82 | 312 | `createBtn` | 924,719 |
| 5 | 85 | 316 | `flash2` | 865,701 |
| 6 | 4 | 350 | `sb` | 507,399 |

Frame 4 removes depths 74, 85; frame 5 removes 82; frame 6 removes 4, 82, 85.

## Stages (root frame scripts)

| Frame | Role |
|---|---|
| 1 | init: `watch("VCTOFLASH")`, Enter/Esc key polling, `snd_bs`/`snd_cs`/`snd_db` from ini; `isBtnReturnHide = true` |
| 2 | `snd_cs.show`; `characterInAndOut.inPlay()` once loaded |
| 3 | class select: item roll-over/press (`snd_cs` `rollOver_char`/`click_char`), `nextBtn` enabled (frame 5) after a class is chosen; next with no class → `errorMC` `nError=1`; Esc = return |
| 4 | `characterInAndOut.outPlay()` |
| 5 | body + name: `createBtn` enabled when name non-empty and body chosen; empty name → `nError=3`; no body → `nError=2`; else `createCharacterMC.gotoAndPlay(2)` |
| 6 | `stop(); tip.close()` |

`returnBtn` on frame 5 → root frame 2; on frame 3 → `back2Login()` (`CMD_DRIVERBACK`).

`sb` (304): name field `userNameTxt` (Flash length counts chars > 128 as 2; > 15 drops the last char), random
non-repeating `keyboardDown_0..2` per change; body buttons `bodySizeBtn_0`/`_1` and `sb`/`sm` clips select 1/2;
`infoTxt` = `infoII` of the class pair.

`createCharacterMC` (58): frame 2 locks `returnBtn`/`createBtn`, `snd_db.show`; frame 6 shows name, `jobTxt`
(`affirmPanel.vocationN`), `bodyTxt`; OK → `mcSafe.show()` when name == `USERACCOUNT`, else `submit()` +
`inGameMC.gotoAndPlay(2)`; Cancel → close; frame 7 `snd_db.hide`; frame 10 re-enables buttons on cancel.

## `1001` builder (`CMsgCreatePlayer1001__Build` `0x7200BF`)

See [Network/01_core_packets.md](../Network/01_core_packets.md#msgcreateplayer-type-1001).

## StrRes / Cn_Res

| Id | Text |
|---|---|
| 10037 | First Name should be 4-15 characters! |
| 11089 | Sorry, the name you specified contains invalid characters. |
| 11237 | Logging into account server... |
| 11238 | Initializing... |
| 11239 | Creating maps... |
| 11240 | Starting... Please wait... |
| `STR_CREATE_ROLE_SUCCESS` | Your character has been successfully created! |

## Retail runtime (2026-10-25)

Retail `Conquer.exe` `b6ba5ab8…` via `5517-loader` (`Conquer.Launch.exe` + Connect/Flash modules) in the Win11
ARM64 VM, 200% DPI (client 2048×1536 at (686,128), 2 px per stage px), against local servers with creation on.
No audio (DXSound init fails in the VM). Captures: `DotNet/Conquer/Evidence/nativeflashevidence/work/create-role-research/vm-runtime/`.

| Step | Observed |
|---|---|
| Login → role | black bar: "Logging into account server..." → "Logging into the game server.." → rod rolls in, scroll opens L→R onto class strip (~3 s) |
| Class strip | pointer near either edge scrolls the strip; centre band static; hover = colour + name banner ("Male Taoist", "monk") + `infoI` line under the stage; click = foot glow, banner kept; `nextBtn` lights on hover |
| Next | scroll rolls shut, ink dragon draws, body stage: two silhouettes ("Big"/"Small"), `infoTxt`, Name field, Big/Small buttons, "Create the character" |
| Body | hover darkens silhouette; Big button hover red; chosen = silhouette glow + red button |
| Create, empty name | `errorMC` "Please enter your First Name!" (`nError=3`), host not called |
| `abc` | confirm panel ("Are you sure you want to create this character ?", portrait, Name/Body Size/Class) → OK → StrRes 10037 |
| `.abcd` | → StrRes 11089 (leading `.` fails the pixel check) |
| `ab=cd` | passes the client gates; server creation-channel text shown in the same error panel |
| name == account | confirm OK → `mcSafe` "To make the Account ID and Character Name identical is very dangerous to your account.Will you proceed ?" Ok/Cancel |
| Valid (`Probe5517`, Monk, Small) | "Your character has been successfully created!" → "Initializing..." → "Creating maps..." bar ~10 s → world, map 1010. Stored body 1003, profession 60 (small = size 1 → 1003, confirmed) |
| Back on class stage | black → logo fire-dragon → login screen |
| After 2101 `ANSWER_OK` | client sends `1134` subtype 3 (968 B, 80 entries), seen after the `0x4A` exchange and before `0x198` (the `0x198` part is contradicted by the CP2.4d2 probe: no 408 on map 1010, see `Network/bootstrap-tolerance-cp24d.md`); see [Network/08](../Network/08_system_packets.md#msgmissionsystemupdate-type-1134) |

## `characterInAndOut.swf` (`b38d8831…`, 1024×768, 30 fps, 144 root frames)

Loaded by role frame 1 `iniLoaded` into `characterInAndOut` (sprite 72, root depth 38, identity). Static data:
`create-role-research/metadata/characterInAndOut.json` (`build_timelines.py`).

| Root frames | Content / script |
|---|---|
| 1 | `inPlay()` = `_parent.nextFrame(); gotoAndPlay(1)`; `outPlay()` = `gotoAndStop("OUT"); play()`; `isLoaded = true` (no `stop`) |
| 1–10 | rods: sprites 3, 6 (shapes 2, 5) at depths 214/216, matrix [0,−0.07,0.07,0] → [0.748,0,0,0.748], (1031,515) → (270.55/226.65,192.2); mask shape 7 (depth 218, clip 219) |
| 11–131 | paper sprite 9 (mask, depth 1, clip 212, x-scale 7.5 → 39.53) over bg sprite 12 (depth 3); 12 sons (depths 8…195) tween in from the right, alpha via CXFORM; frame 120 adds sprite 218 (depth 220, alpha 5→256) |
| 132 | morph 219 mask (depth 1, clip 196) over `mcRole` sprite 220 at (537.85,−6); sprite 218; sprite 223 at (1005,27). Script: `stop()`, `mcRoleInit`, alpha easing |
| 133 `OUT` | `disableRole(); onEnterFrame = null`; sprite 223 slides (903.3 → −215.3 by 144) |
| 144 | `_parent.play(); stop()` → role frame 4 → 5 |

Not defined in this movie, silent no-ops: `SelectID` (role frame 3 `onPressItem`), `getPath` (role `characterGetPath`).

`mcRole` (sprite 220) carousel, `onEnterFrame` while `bActived`, after the first mouse move:

| Item | Value |
|---|---|
| Scroll zone | `_ymouse` in (100, `Stage.height`−100) and `|_xmouse|` > 400 (clip-local) → `camTagX = _xmouse × 2.4`; `acc += 0.002` to max 0.2 |
| Outside zone | `acc −= 0.01` to 0 |
| Step | `camSpd = clamp((camTagX − camX) × acc, ±50)`; `|camTagX − camX| < 3` → spd 0, acc 0; `camX = round(camX + camSpd)` |
| Projection | son `_x = round(−3000 × (camX − x0) / (3000 − z))`, x0 = authored `_x`; `bgPic._x = bgOrgX − 0.3 × camX` |
| Init | `camX = camTagX = 200`, `setPos(200)` |

| Instance | Sprite | `id` (= `nSelectJob`) | z | authored (x, y) |
|---|---:|---:|---:|---|
| son_0 | 91 | 6 | −350 | (−1675.55, 747.9) |
| son_1 | 105 | 5 | −300 | (−1442.75, 743.9) |
| son_2 | 116 | 2 | −260 | (−1116.95, 767.9) |
| son_3 | 127 | 1 | −200 | (−826.15, 783.9) |
| son_4 | 138 | 8 | −100 | (−656.8, 767.9) |
| son_5 | 149 | 7 | −50 | (−349.45, 775.9) |
| son_6 | 160 | 11 | 0 | (−13.15, 748.9) |
| son_7 | 182 | 12 | 0 | (259.05, 784.1) |
| son_8 | 171 | 9 | −200 | (581.25, 792.65) |
| son_9 | 193 | 10 | −450 | (920.3, 760) |
| son_10 | 204 | 3 | −500 | (1244.95, 726.5) |
| son_11 | 215 | 4 | −1200 | (1560.6, 753.95) |

`bgPic` = sprite 12 at (−970.5, 96.3). Son depth order in sprite 220: son_11 lowest (6) … son_7 highest (193).

Son clip (e.g. sprite 91, 20 frames; `stop()` on 1, 10, 20; `id` set on 1):

| Frames | Content |
|---|---|
| 1 | `son` sprite 16 (sepia), `selectedEffect` 79 (31-frame foot glow, `show` = `gotoAndPlay(2)`, loops 2–31), `selectedEffect_1` 13 (show/hide `_visible`), `hitArea` 81 (alpha 0; being named `hitArea`, it is the clip's AS2 hit area, so pointer tests use only its shape) |
| 2–10 | roll-over: `son` alpha 250 → 0, colour sprite 84 alpha 0 → 256, light sweep sprite 86 masked by shape 88, glow shape 90 |
| 11–20 | roll-out, reverse |

Son events (root frame 132): roll-over → others ease to alpha 70 (`alpha −= (alpha − 70)/10` per frame, snap within 3),
`swapDepths(100)`, unselected → `gotoAndPlay(2)` + role `onRollOverItem(id)`; roll-out/release-outside → ease all to 100,
`swapDepths(orgDepth)`, unselected → `gotoAndPlay(20 − _currentframe)` + `onRollOutItem`; press (unselected) →
previous selection `gotoAndPlay(11)` + effects hidden, this `gotoAndStop(11)`, effects shown, alpha 100, role
`onPressItem(id)`. `selectedNameEffect` is absent from son sprites (no-op).

## role.dat runtime contract (decoded AS2, 2026-10-25)

Static data: `create-role-research/metadata/role.json`. Root display list (frames 1–6):

| Depth | Instance | Sprite | Frames |
|---:|---|---|---|
| 1 | — | shape 60 (backdrop) | all |
| 2 | — | 71 (602-frame loop) at (49, 315.85) | all |
| 4 | `sb` | 304 (frame 5), 350 (frame 6) at (507.3, 399.1) | 5–6 |
| 38 | `characterInAndOut` | 72 (loadMovie target) | all |
| 40 | `createCharacterMC` | 58 (confirm panel) | all |
| 55 | `quitWindow` | 75 | all |
| 64 | `errorMC` | 77 | all |
| 73, 95 | — | shapes 80 at (512, 690), 83 (chrome) | all |
| 74 | `jobInfo` | 116 at (244.95, 682.5) | 3 |
| 79 | `returnBtn` | 122 at (106.4, 720.3) | 3–6 |
| 82 | `nextBtn` / `createBtn` | 130 at (924.05, 718) / 312 at (924, 719) | 3–4 / 5 |
| 85 | `flash1` / `flash2` | 140 / 316 (60-frame highlight, morphs) | 3 / 5 |
| 96, 98 | `bottomDragonMC`, `topDragonMC` | 84, 85 | all |
| 100 | `logoMC` | 86 ← `logo.swf` at ini `[logo]` (776, 2) | all |
| 102 | `inGameMC` | 110 at (508, 376) | all |
| 118 | `quitWindow2` | 112 | all |

| Root frame | Script |
|---|---|
| 1 | vars (`nSelectJob`, `nSelectBody`, `sUserName`, `nError`), `watch("VCTOFLASH")`, Enter/Esc polling, `stop()`; `PATH` → `CIni(ini/selectCharacter.ini)` → `iniLoaded`: `play()`, load logo + characterInAndOut, copy `[info]`, `[affirmPanel]`, sounds |
| 2 | `stop()`; `snd_cs.show`; `onEnterFrame` waits for `characterInAndOut.isLoaded` → `inPlay()` (root → 3) |
| 3 | class stage: `onRollOverItem`/`onPressItem`/`onRollOutItem` (`jobInfo.showInfo`, sounds, `nSelectJob`, `nextBtn` → frame 5 when a class is chosen), `returnBtn`/`nextBtn` handlers |
| 4 | `stop()`, `outPlay()`; characterInAndOut frame 144 → root `play()` → 5 |
| 5 | body stage: `onEnterFrame` arms `createBtn` (frame 5) while name ≠ "" and `sb.nSelectBody > 0`; `createBtn.onRelease` → confirm panel, else `nError` 3 (empty name) / 2 (no body) |
| 6 | `stop()`, `tip.close()` |

- Handlers defined on a timeline resolve unqualified `gotoAndStop`/`_currentframe` against that timeline (AVM1
  scope chain), `this.` against the clip: `nextBtn.onRelease` steps root 3 → 4 only if `nSelectJob ≠ 0`, else
  `nError = 1` (`errorMC` "Please select your profession!").
- `returnBtn.onRelease`: root frame 5 → `gotoAndStop(2)` (frame 2 finds `isLoaded` still set and replays characterInAndOut from frame 1); frame 3 → `back2Login()`.
- `errorMC` (77): frame 2 disables `returnBtn`/`nextBtn`/`createBtn` (frame 4, `enabled = false`), frame 6 text by
  `nError` (0 `sErrorTxt`, 1 profession, 2 "Please select your body size.", 3 "Please enter your First Name!"),
  OK → `play()`, frame 10 re-enables.
- `tip` (`CTxtTip`): `addItem` is never called, so every `tip.show` draws nothing.
- `CIni` (LoadVars): URL-decoded (`+` → space, `%xx`), each line loses its last char (CR), edges ≤ 0x20 trimmed,
  `//` starts a comment, a line needs exactly one `=`, keys have no spaces, `~` → space. `turnToNewline` turns
  literal `\n` into newlines.
- Host messages (`VCTOFLASH`): `PATH`, `ERROR`/`CREATEFAIL` (→ `errorMC`, `nError` 0), `EXIT` (quit windows),
  `PROGRESS` 1/80 (`inGameMC.play()`), `USERACCOUNT`, `LOADING_TRACE`, `BANNED` (empty), `HIDERETURNBTN` (reads an
  undefined `sMsg`, so no effect).

## Retail render parity (2026-10-31, vm-runtime 18/33/34/36)

Pixel placement (unscaled, unrotated raster; `g` = device x/y of the bitmap texel grid):

| Fill | First device pixel | Evidence |
|---|---|---|
| bitmap matrix exactly identity (20 twips/texel) | `ceil(g)` | sb shape 176 g=(0.30,87.10) → exact match at (1,88); shape 188 edges 690.3→691, 662.8→663, 400.6→401 |
| other bitmap fills (19.99-twip authoring), vector | `ceil(g−0.5)` | returnBtn shape 118 y 700.3 → 700 |
| scale within 1/1000 of 1 | treated as unscaled | sb places 188 at y-scale 1.000412; retail crisp |

- Shape 188 (name box + "Name" label): fills 187@tx 13 (left rect x 104.65–168.15) and 187@tx −14.5 (right rect 168.15–239.5), 186 "Name" @ (4,5.25) scale 0.9989. Fills abut, no seam; JPEXS renders a seam + half-texel blur. Baked as 3 pieces (`bitmap_pieces.py`), verified vs Flash rule at both placement phases (304 @ 677.3,400.1; 350 @ 677,400).
- Open: Back/Create/top chrome (shape 83 at exact (0,0) drawn at (1,1) in retail) differ by 1 px; no single rule fits 83 vs 80 (80 at (512,690) matches). Not resolved.

Device text (Flash device fonts = GDI):

| Item | Rule | Evidence |
|---|---|---|
| advances | hinted (hdmx / FreeType `TARGET_MONO`) | infoTxt line "Through intense martial arts training, the" Arial 16: 275 px (v40 default 285) → same 5-line wrap |
| baseline | top + `ceil(ascender·ppem/unitsPerEm)` | Arial 16 → 15 (T cap rows 171–182, origin 168); Arial 14 → 13 |
| position | half rounds up | userNameTxt x 790.5 → 791 |
| clip | field bounds; only whole lines drawn | jobInfo (char 113, h 54.5) shows 3 of 4 lines |
| caret | never drawn | 5 captures with focused field, none; login host draws its own caret from `CMD_TEXTSELECT`, role.dat sends none |

- Edit-text `variableName`: text lives in the parent variable (`text` write → `parent.info`); sb re-places infoTxt (chars 144 → 184 → 207, all var `info`, frames 1/9/10), so class text survives only through the binding. SWF6 variable names case-insensitive.
- `logo.swf` (`7165b9ed…`, SWF8, 25 frames, 30 fps): one `DefineVideoStream` id 1, Sorenson H.263 (codec 2), 248×78, no alpha; VideoFrame tags for frames 0–4,6,8,10–13,15,16,18,19,21,22,24 (missing = hold last); root places ratio = frame−1, loops. Loaded into `logoMC` then `_x/_y` = ini `[logo]` (776,2).
- Handlers outliving their frame: `nextBtn` rollOut on root frame 4 references removed `flash1` (createBtn/`flash2` same on 6); portrait events reach `jobInfo` after frame 3. AS no-ops; must not throw.
- A clip disabled while hovered gets no rollOut: confirm panel frame 2 sets createBtn frame 4 + `enabled=false`; retail keeps the dim frame after the pointer leaves (capture 36).
- Retail draws these screens 32-bit (Flash windows); only the D3D world is RGB565.
