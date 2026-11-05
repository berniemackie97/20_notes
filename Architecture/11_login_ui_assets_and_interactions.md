# Retail 5517 login UI: assets, animation and interaction evidence

Research slice for OpenConquerClient PR #108, 2026-10-14. This is evidence and original-asset extraction only. No modern client implementation or architecture is prescribed.

Follow-up 2026-10-15: retail `Flash.ocx` 7.0 (`FlashVersion`=458752, SHA-256 `94058fe5…d703`) hosted outside Conquer with a probe harness, plus native closure in Binja. Results: [Follow-up closure](#follow-up-closure-2026-10-15). Several statements below are corrected in place.

## Authority and scope

The authority is the clean retail tree `/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/00_clean/clean/5517`, its shipped SWF tags/AVM1, and the existing deobfuscated `5517-bninja/Conquer.exe.bndb` (view 9). Existing native contracts in notes 02, 03 and 05 were reused. Only missing credential input/focus questions were inspected in native assembly. Five comments were added to the existing Binary Ninja view; no BNDB was saved, and no speculative renames were made. Follow-up: renames `0x4ABFBD` → `CLoginFlashDlg_HandleEnterGameCommand_ValidateAndBeginBindHandshake` (was `HandleReturnNavigation`), `0x4AF12D` → `CLoginFlashDlg_PersistSelectionAndConnectAccountServer`; comments at `0x4A9A83`, `0x4ADD5A`, `0x4ADFB3`, `0x4AE198`, `0x4AEF11` (corrected).

The companion `OpenConquer-5517-Login-UI-Assets.zip` is an evidence package, not a captured live Flash session. `metadata/sources.json` pins each analyzed movie to its original absolute path and SHA-256. `metadata/movies/*.json` contains symbol definitions, every timeline placement/removal, inherited display-list state for every frame, matrices, color transforms, clipping depths, text-field properties, and symbol bounds. `metadata/key-placements.json` gives composed stage coordinates for the principal controls. `asset-index.json` identifies every exported PNG, its source symbol/frame, dimensions, origin, source hash and limitations. The contact-sheet index covers every packaged PNG, including individual animation frames.

Coordinates below refer to the authored 1024×768 stage, `nStageType=0`. They are not desktop screen coordinates. Shell scaling/resizing remains the established note 05 contract. SWF translations are twips (20 per pixel); arrays use `[a,b,c,d,tx,ty]`, with `x'=a*x+c*y+tx`, `y'=b*x+d*y+ty`. Parent matrices must be composed. A symbol's registration point is not necessarily its image's upper-left corner.

## Source identity and loading

| Original relative path | SHA-256 |
|---|---|
| `data/main/start.dat` | `db4b4550bc4b3fa91b2fd7cc173bb9a6f8109dbc65221e7f0df290610655da20` |
| `ini/flashLogin.ini` | `323cdc428ac85c76616a89869057d616161ee0ce8867be2e4b37d61bd0d76ba9` |
| `data/main/flash/loginFlash.swf` | `8cc1d5a15d159f8b2c0d1c47109046324d34187f456710dfffbb8e0ca9fb9f6a` |
| `data/main/flash/logo.swf` | `7165b9ed4fc84dfd54dea8ee750ab537de522a7b19c645e2313e03c9a251c6f7` |
| `data/main/flash/defaultR.swf` | `e4b177bd42c047c330c882bed02ddd1082bd565a6e807d5691ffb2d7038f7c8f` |
| `data/main/flash/defaultS.swf` | `2579d4cce2fdf2498e194eca1c7c9b1299bd30438c0cefb9f841df7db782e252` |
| `data/main/flash/unopenedR.swf` | `2556c9a21092df4e62857be5326869e562167d03e9e5fba3915f0bdd081be9ac` |
| `data/main/flash/unopenedS.swf` | `0611f8a6c4f82fa1b75377eef6be9c018e7076eeb3275d3338dff4e906427f8b` |

The literal submovie directory is **`data/main/flash/`**, not `data/main/`. `getGamePath` constructs `mainPath`, loads `ini/flashLogin.ini` and `ini/oem.ini`, and calls `loadLoginFlash`. Root frame 3 loads `logo.swf`. Region sprite 259 and server sprite 180 append native-provided icon tokens to `data/main/flash/`; they use the default/unopened movies for their documented fallback conditions. Their actual code does not implement the managed three-directory fallback discussed elsewhere in note 05.

Additional loose artwork was inventoried, hashed and decoded: `Group1.swf` through `Group14.swf`, and 102 `GroupN/serverN.swf` files. These are available icon sources, not proof that every loose file is selected by this particular Server.dat. All 116 are included with their actual paths and source-derived frames. There are 136 loose SWFs in the Flash directory in total; character-creation/effect/Facebook alternatives are inventoried but not substituted into this `start.dat` slice. No WDF lookup was necessary for the resolved Flash assets.

`rsDragon.swf` also exists and is included. It is a 700×650, 30-fps bitmap-sequence animation. However, no `loadMovie` of it occurs in the inspected `start.dat` actions. Its existence and an `rsDragonMC.item.gotoAndPlay(2)` call do **not** establish an active loaded instance. See the animation section.

`ini/oem.ini` was not found in this clean retail tree, including a case-insensitive filename search of `ini/`. The fallback URL strings below are therefore source evidence; no URL was executed. INI topDragon/bottomDragon/poetry coordinates are configuration entries, not proof of applied transforms: `loadIni` applies loginFlash, logo and rsDragon positions, but does not apply those other three sections in this movie.

## Principal asset inventory and geometry

All IDs in this table belong to `start.dat` unless a different movie is named. The full matrix and hierarchy for every state is in the machine-readable metadata. Dimensions are authored bounds; PNG canvas dimensions are recorded separately because rasterization rounds fractional bounds.

Root `enterMC` is sprite **371**, root depth **221**, matrix `[1,0,0,1,512.5,720.4]`. Its origin is fixed independently of region/server selection. The following are its children:

| Element / actual presentation | ID | Depth | Local translation | Stage artwork bounds (x,y,w,h) | States |
|---|---:|---:|---|---|---|
| Register, visible **Sign Up** text plus round icon | 299 | 1 | −486.45,−7.05 | 26.05,713.35,81.85,21 | Up/Over/Down; fourth export is hit-test only |
| Charge/Paid, **CP Purchase** text plus icon | 305 | 6 | −374.5,−7.05 | 138,713.35,108.35,21 | Up/Over/Down + hit-test |
| **Help** text plus icon | 310 | 10 | −256.65,−7.05 | 255.85,713.35,57,22.1 | Up/Over/Down + hit-test |
| Account-panel gold ornament/background | 328 | 20 | 0,0 | 256,605.9,508.5,98.5 | Static bitmap-fill composition |
| Account history, upward triangle | 335 | 21 | 84,−74 | 596.5,646.4,17,15 | Up/Over/Down + hit-test |
| Save-account gold icon | 342 | 23 | 112,−73 | 624.5,647.4,22,19 | Up/Over/Down + hit-test |
| Clear-account icon | 349 | 25 | 143,−72 | 655.5,646.4,20,21 | Up/Over/Down + hit-test; local y-min is −2 |
| History-list container | 360 | 36 | −61,−89 | origin 451.5,631.4; dynamic rows extend upward | Runtime masking and 20-ms interval motion |
| `accountsTextHitArea` hover overlay | 362 | 42 | 20.05,−36 | 466.8687,672.4,146.4629,24 | x-scale 1.0559692; alpha 0/100 |
| `passwordTextHitArea` hover overlay | 362 | 44 | 11,−66 | 465.7664,642.4,128.7403,24 | x-scale .92819214; alpha 0/100 |
| Account editable text | 363 | 46 | −40,−75 | 470.5,643.4,122,22.1 | Editable/selectable; no tag max length |
| Password editable text | 364 | 47 | −40.35,−43.95 | 470.1493,674.45,140.6994,22.1 | x-scale 1.000351; password flag; tag max length 15 |
| Caps Lock notification | 370 | 50 | 88.5,−112.05 | 496.5,564.8808,180,114.7007 | y-scale 1.0004425; script alpha fade |

The two hover-overlay **names are opposite the vertical positions one might expect**: retain source names and geometry; do not silently swap them. They are hover alpha art, not proof of distinct keyboard-focus textures. `onEnterFrame2` performs shape hit tests and sets their alpha to 0 or 100. The password-focus callback installs a different frame callback that does not call `onEnterFrame2`, another reason not to model this as a generic focus-state skin.

`maskMC1` is sprite 326 at depth 18, local (−510.95,−60.5), covering the lower panel; `maskMC2` is sprite 366 at depth 48, local (−110.95,−84), covering the credential area. The scripts install no-op `onPress` handlers, suppress the hand cursor and toggle visibility. These are input-blocking clips, not `clipDepth` masks. The history container separately calls `setMask(maskMC)` and later removes that mask. Static exports of these containers do not execute those commands.

| Other element | Source symbol / hierarchy | Geometry and state evidence |
|---|---|---|
| Background | start shape 11, root depth 1 | Full-stage authored background composition |
| Flying bird animation | start sprite 21 (18 frames) nested in sprite 22 (602 frames), root depth 2 | Moving/rotated/scaled instances; timeline placements and bounds retained |
| Final top/bottom border ornament | start shape 400, root frame 3 depth 216 | Local bounds (−.5,−.5)..(1024,768); bitmap-filled composite, not raw bitmap 399 |
| Poetry | start sprite 260 `poetryMC`, root depth 177 at (890.95,213) | Empty one-frame sprite; no resolved visible poetry art or loader |
| Top / bottom named clips | start 402/401, root frame 3 depths 219/217 | Empty one-frame sprites, identity placement; no resolved loop |
| Selection dragon named clip | start 403, depth 272 | Empty; `loadIni` sets (183,73); external rsDragon file exists but loading is unproven |
| Logo holder | start 404, depth 274 | `logo.swf` loaded at (776,2); original video is 248×78 |
| Region panel | start 259 `sr`, root depth 138 | Matrix [.98028564,0,0,.9801178,150,381]; 16 slot holders and page controls |
| Server panel | start 180 `ss`, root depth 4 | Identity scale at (685,373); 4 rows × 3 slots |
| Region paging | start buttons 192/199 | Original Up/Over/Down + hit-test; initially hidden; shown when pages >1 |
| Server tile | start sprite 179 | 12-frame interaction timeline; nested 178 animated selection effect, status-light sprite 34 (4 states), external `son` art and dynamic label |
| Error | start 274 `errorMC`, root depth 179 at (−1,0) | 10-frame show/hold/hide; OK button 272 |
| Save confirmation | start 283 `saveMC`, depth 187 at (−1,0) | 10 frames; OK 272, Cancel 282; source warning text |
| Clear confirmation | start 285 `clearMC`, depth 196 at (−1,0) | 10 frames; same button art; runtime username text |
| Quit confirmations | start 287/396 `quitWindow`/`quitWindow2`, depths 205/294 | 10 frames; second instance is at (0,0), used during loading |
| Loading/progress | start 394 `inGameMC`, depth 278 at (512,384) | 100-frame stateful timeline; source bar/effects and dynamic trace field |
| Version label | start sprite 9 `verTxt`, depth 276 at (16,13) | Runtime text; initially hidden; shown at root frame 3 |
| Tooltips | `CTxtTip`, runtime `txtTipMC`, depth 9999 | Drawn at runtime from text metrics; no premade tooltip bitmap |

Enter/Exit art, cursors and audio were not re-exported for this package. Their source definitions remain in raw SWFs for verification. There is no evidence here for fabricated rectangular SAVE/CLEAR/LIST buttons, a BGM ON button, or a new settings panel. The **actual** save/clear/history icons above do exist.

## Animation and transitions

Nominal stage rate is **30 fps**, so an advancing stage frame is **1/30 s**. Stops, load completion, timers and host callbacks make wall-clock duration state-dependent. Do not play every exported sprite frame as one uninterrupted loop. The source frame numbers, placements and action stops remain authoritative.

### Opening movie and top/bottom ornaments

`loginFlash.swf` has one root frame, containing sprite **25**, named `item`, with **27 frames**. The root placement is `[1.0000458,0,0,.99993896,0,34.55]`; inside sprite 25, video character **1** sits at (.45,−34.55), depth 1. Composing these nearly cancels the y-offset; the exact matrices are retained.

Frames **1–24** display 24 encoded Sorenson H.263 video images, ratios 0–23, each on a 30-fps timeline. The stream declares 25 frames but only 24 `VideoFrame` tags exist. The original fiery dragon and central gold ornament are part of this **opaque 1024×768 opening video**. RGBA files preserve alpha 255 and original black pixels; no invented chroma-key transparency was applied.

At frame **25**, video depth 1 is removed. Static bitmap-fill layers then move apart over frames **25, 26, 27**:

| Layer in sprite 25 | Depth | Frame 25 local origin | Frame 26 | Frame 27 |
|---|---:|---|---|---|
| Bottom/account decoration, id 6 | 2 | 512,504.45 | 512,611.75 | 512,655.5 |
| Save icon, id 13 | 3 | 624.95,461.2 | 624.95,568.5 | 624.95,612.25 |
| Clear icon, id 20 | 5 | 655.95,462.2 | 655.95,569.5 | 655.95,613.25 |
| Top ornament, id 24 | 9 | 512,282.4 | 512,161.9 | 512,49.5 |

Additional id-21 black covering shapes at depths 7 and 10 change scale/translation on frames 25–26 and are removed on frame 27. All values above are **inside `item`**, before its root transform. At frame 27, `stop(); _root.play();` resumes `start.dat`.

`start.dat` frame 1 stops and hides its root; its panel is also hidden. The loaded `loginFlash.swf` root frame 1 explicitly sets `_root._visible=true`, allowing the opening movie to show while the account panel remains hidden. A one-shot 8500-ms interval advances the root only if `loginFlashMC.item` is absent. It is not an arbitrary duration assigned to the 27-frame movie. Root frame 2 shows the root; frame 3 stops, removes the opening holder, places static shape 400 and the empty named dragon holders, loads the logo and shows the panel/version. Observed ordering and timing are in [Follow-up closure](#follow-up-closure-2026-10-15).

**Result for the static-top-dragon question:** this snapshot proves a fiery opening video, then a three-frame separation of original top/bottom ornament layers, followed by the static final composite. It does **not** prove a separate continuously animated `topDragonMC` at the login screen. Empty sprite 402 and an unused `[topDragon]` INI position cannot supply such a loop. No replacement animation was fabricated.

### Logo

`logo.swf`: root **25 frames**, **30 fps**, video character 1, **248×78**, codec 2 (Sorenson H.263). There are **18 encoded images**, at zero-based video frame numbers:

`0,1,2,3,4,6,8,10,11,12,13,15,16,18,19,21,22,24`.

The timeline covers 25 slots (nominal 0.833333 s); absent encoded pictures hold the preceding picture. `assets/logo/video-timeline/0001.png` through `0025.png` retain that sequence. `metadata/video-timing.json` identifies every held slot and its encoded image. The decoded 18 original images are separately retained. The video has no alpha plane; its textured dark background is authentic opaque content.

The logo SWF has no stop action. The caller's `logoMC.gotoAndStop(1)` runs on the holder before the asynchronous load replaces it. **Runtime (Flash.ocx 7):** `_root.logoMC._totalframes`=25 and `_currentframe` cycles 1→25 continuously for the whole session — the logo loops.

### Separate selection-dragon source

`data/main/flash/rsDragon.swf` contains sprite **51 `item`**, **28 frames**, at root depth 1 with identity matrix. It uses original 700×650 RGBA bitmap-fill frames: frame 1 is blank, frames 2–26 contain 25 successive original drawings, frame 27 removes the drawing, frame 28 stops. The root action sets `_alpha=80` (apply this at the instance; exported sprite pixels preserve intrinsic alpha). Frame 1 initializes `bIsFirst=true`, then plays once and clears it. A subsequent `gotoAndPlay(2)` traverses the sequence without frame-1 initialization.

The `start.dat` region handler calls `rsDragonMC.item.gotoAndPlay(2)` after the first selection, but the inspected root only creates empty sprite 403 and sets its position. **No corresponding load is present.** **Runtime (Flash.ocx 7):** `_root.rsDragonMC.item._totalframes` stays empty for the whole session → `item` never exists; the `gotoAndPlay(2)` is a no-op. The selection dragon is **not displayed** by retail 5517; the package keeps it as an unused original asset. Neither it nor its frame count should be assigned to topDragon/bottomDragon by name association.

### Region/server and other animation

- `defaultR.swf` and all 14 Group movies have 13 root frames at 30 fps, with stops at **1,8,12,13**. The nested effect has 25 frames; a nested six-frame transition stops at frame 6. Exact child IDs differ between movies. Region wrappers request hover frame 2, rollout frame 10, and selected frame **16**. The loaded movies have only 13 root frames. **Runtime (Flash.ocx 7, `defaultR.swf`):** `gotoAndStop(16)` → `_currentframe`=13 — clamps to the last frame (frame-13 stop state is the selected look).
- Region hover swaps the hovered holder to depth 999. The root region matrix still applies. Region spring parameters are `nA=.25`, `nFraction=.65`; `nUnitChangeSize=0`, `nMinAlpha=100` in this source, so merely having spring/alpha code does not prove a visible displacement/dimming under defaults.
- Server sprite 179 stops at frames **1,6,11,12**. Hover plays from 2, rollout from 11, selection stops at 12. Nested sprite 178 has 47 frames; its last action returns to label `aa` (frame 23) then plays. The label location is retained in timeline metadata. Status light sprite 34 has four authored states; unknown status defaults to state 4, absent rows hide the light.
- A region change refreshes all 12 server slots. Slot row/column indices `(i,j)` set fade-out duration `i+j+5` and fade-in `i+j+4` with `Strong.easeIn`, **`useSeconds=false` (frame counts)**. Alpha goes 100→0, the external `son` movie is loaded, then 0→100. Slot input is disabled while moving; `_global.nMovingSeverCount` gates region selections. This does not disable credential fields. The first slot's completion requests the saved server index and then resets `_root.currentS=0`.
- `defaultS.swf`, `unopenedS.swf` and the loose server-icon movies have one root frame, authored header rate 25 fps. As static images their header does not create an animation. The embedding stage rate remains relevant to parent transitions.
- Bird sprite 21 has 18 shape frames; its parent sprite 22 has 602 frames (nominal 20.066667 s at 30 fps) with no stop actions. The parent moves/transforms nested birds. The package preserves both child and parent sequences; it is not a dragon animation.
- Account popup rows use an AVM1 20-ms timer, described below. Caps Lock uses per-stage-frame alpha steps, not an invented duration. Dialogs and progress have host/event stops, described below.

## Account history, saving and removal

The three actual account buttons are DefineButton2 symbols **335,342,349**. Up/Over/Down pixels are distinct; the fourth exported image is a **hit-test region, never a displayed disabled state**. There is no extra authored disabled/focus artwork for these controls in their button records.

Root `getUserListName` fills ACCOUNT0–ACCOUNT9; when index 9 arrives it calls `listMC.setData` and `create`. Sprite 360 removes empty/undefined values, retaining one empty entry if none remain. `create()` attaches exported **`itemBtn` sprite 6** at depths `10+i`, y=`25*i`, with actual account text in `nameTxt`. Rows have two authored frames: idle and highlighted; rollover enters frame 2 only for a nonempty name, rollout frame 1. Source row bounds are x=0..166, y=−.5..24.5. No sample username was fabricated in the package.

`popBtn.onRelease` toggles `listMC.pop()`/`reset()`. Opening applies the mask, returns rows to idle and moves the list upward by **`10+2*N` pixels every 20 ms**, clamping at `−listMC._height`. Only at completion is `bIsClick=true`; the mask becomes invisible and `setMask(null)` removes it. Closing restores the mask and increments y by the same amount until 0. This is dynamic list-height timing, not an arbitrary fixed frame animation. Reversing mid-opening is not a conventional symmetric tween: `reset` starts movement only if `bIsClick` is already true.

On the first mouse-down detected by `Key.isDown(1)`, an open clickable list checks its bounds, computes `floor(_ymouse/25)+N`, invokes `onClick(index,name)` for a valid nonempty account, then closes. Outside clicks close it too. The panel's callback sets account text and emits **`CMD_SELECTACCOUNT` with the account name**. Existing native evidence at `0x4AA4BA` establishes clearing credentials and pushing LOGINUSER/focus/selection when that account differs; selecting the already-current account does not take the different-account clear branch. The exact selected focus/range payload remains the established note 03 contract; no new all-text-on-click rule is inferred.

**Explicit saving:** `saveBtn.onRelease` requires nonempty account text and opens `saveMC` at frame 2, setting the panel blockers. Its frame 6 OK handler calls `_root.cmd_record()` → **`CMD_RECORDACCOUNT` with empty string**. Cancel only plays the hide sequence. The original warning is: “Remember this account? We do not recommend this if you use a public or shared computer.” This text is embedded in edit-text symbol 275; its device-font pixels are not embedded glyph artwork.

**No automatic saving (corrected 2026-10-15).** The only caller of `CLoginFlashDlg_RecordAccountAndPushAccountListToFlash` (`0x4AC7A3`) is the `CMD_RECORDACCOUNT` branch (`0x4AA25F` compare, call `0x4AA26C`). The earlier note 03 row "ENTERGAME → post 0x480 → record" was a one-row misalignment of the dispatch chain (fixed there). The saved-account list (ACCOUNT0–9) changes only through Save → OK.

**Removal:** `clearBtn.onRelease` opens `clearMC` only if the current nonempty account occurs in the list. Frame 6 OK calls `_root.cmd_clear(userName)` → **`CMD_CLEARACCOUNT` with that name**; Cancel does not send it. There is a real confirmation dialog, not a direct-delete icon. Its runtime text is `_root.sDelID_0 + ' "' + userName + '" ' + _root.sDelID_1` (sprite 285 frame 6, `0x7C9AA`). `sDelID_0/1` are defined nowhere: not in start.dat, not in Conquer.exe strings, not in any ini. SWF version is 6, so undefined concatenates as `""`. **Runtime (Flash.ocx 7, userName=""):** `clearMC.txt.text` = ` "" `. Final retail text = ` "<account>" ` — leading and trailing space, ASCII quotes, no other words — in field 284 (Arial 14 px, #FF4642).

Native account typing in the ordinary update branch dispatches LOGINUSER and then clears password/mobile-protect fields at **`0x4ADC6F`**. Neither the Flash region nor server selection handler assigns username/password. Region/server host-selection effects are reused from note 03, not inferred from the names of commands.

## Credential editing: twelve requested answers

These conclusions distinguish static Flash/native-path proof from unobserved ActiveX focus arbitration. No live retail login or external connection was performed.

| Question | Evidence-bounded answer |
|---|---|
| 1. Account editable with no region? | **Yes, the ordinary displayed login path permits it.** Symbol 363 is editable/selectable, panel handlers have no region gate, and native VAR_FOCUS=1 input processing at `0x4ADBD7..0x4ADC0B` has no direct `+0x190/+0x194` test. This is not merely LOGINUSER initialization evidence. It is not a claim that typing works through the opening movie or modal blockers. |
| 2. Password editable with no region? | **Yes under the ordinary input-policy state.** Symbol 364 is editable/selectable, password=true, maxLength=15; VAR_FOCUS=2 processing at `0x4ADDD4..0x4ADE26` has no selected-region/server branch. Auth-mode input policy is separate (question 12). |
| 3. Both editable with region but no server? | **The same paths permit it.** There is no additional server-selection prerequisite in either field's Flash focus handler or these native input branches. No broad guarantee is made about every auth/bind mode. |
| 4. Initial keyboard focus? | **None.** Native sends FOCUSTOFLASH only from CMD_SELECTACCOUNT (`0x4AA52F`) and the Tab branches (`0x4ADD74`, `0x4ADFCD`, `0x4AE1AE`) — nothing at startup. Runtime after load: `Selection.getFocus()`=null, VAR_FOCUS=0. User must click a field (or select a saved account, which pushes FOCUSTOFLASH=1). |
| 5. Initial Tab order? | Native bridge polls only DIK 0x01/0x0F/0x1C/0x9C — **no Shift**, so Shift+Tab = Tab. Account Tab → FOCUSTOFLASH=2 → runtime focus `_level0.enterMC.passwordTxt`, VAR_FOCUS=2. Password Tab → "3" → start.dat handles only 1/2 → runtime focus stays on password (no wrap). Third-field branch (VAR_FOCUS=3 → "1") is unreachable: start.dat only sets VAR_FOCUS 0/1/2. VAR_FOCUS=0 has no Tab branch. Retail client on Windows with real keystrokes: same result. Flash's own Tab traversal moves no field focus, and Tab in password selects all of its text. |
| 6. Clicking a field selects it immediately? | The tag is selectable/editable and has no realm-gated click-to-enable handler. On focus, username sets VAR_FOCUS=1 and password sets 2. The frame callback exports Selection begin/end via CMD_TEXTSELECT. This supports normal direct field focus; exact ActiveX click-to-caret timing and automatic selection of all text are not proven. |
| 7. Region changes clear fields? | The inspected Flash selection/refresh path does not clear either credential. Existing native CMD_SELECTGROUP evidence stores the selection pair; it does not establish a clear operation. Do not invent one. Secondary bind/auth effects outside this ordinary selection path are not generalized. |
| 8. Server changes clear fields? | Same bounded answer: no credential assignment/clear in the Flash server handler. It changes selection/art, requests two legacy flash effects and calls hideSoftKey; some referenced legacy clips/functions are absent here. Existing native server branch includes bind-tool policy, so no universal claim is made for all protection modes. |
| 9. Saved account selected? | Set visible username; send its name in CMD_SELECTACCOUNT; close dropdown. Native different-account branch clears password/mobile-protect and pushes account/focus/selection. Same-account selection skips that different-account branch. |
| 10. Enter in each credential field? | Both branches test DIK 0x1C/0x9C → `0x4AE2AE`: `GetWindowRect(Flash HWND)`, `SetCursorPos(origin + this+0x13C/+0x140)`, `mouse_event` LEFTDOWN/LEFTUP — a synthetic click, not a submit call. Offsets: ctor 700/720 (`0x4A9DD6`); `ini/Info.ini [LoginFlash] BtnEnterOffsetX/Y` override (`0x4AB3D9/0x4AB4B4`). Retail file has them only commented (742/710) under TQ's comment "after typing account/password, Enter cannot enter normally". Login dialog = IDD **305** (`0x4A9A83`); its RT_DLGINIT persists Flash `Scale=ShowAll`, `WMode=Window`, `Quality=High`, `AllowScriptAccess=always`. The Flash control is the template item `{D27CDB6E…}` (MFC creates it from DLGINIT; wrapper `Create` `0x4B084D` has no callers). `0x4AEC64` sizes dialog and control to the `CMyShellDlg` HWND (`MyWnd+0x40`; WS_CHILD, no frame), which `CMyShellDlg_ApplyScreenMode` (`0x5D7C51`) makes exactly **800×600 in ScreenMode 0/1** or **1024×768 in 2/3**. Retail `GameSetUp.ini` ships `ScreenModeRecord=2`. Modes 2/3: scale 1; (700,720) and (742,710) both lie in Enter bounds [649.95,704.4]–[781.95,744.4] → **Enter logs in**. Modes 0/1: equal aspect, so ShowAll scales by 0.78125 with no letterbox, and Enter sits at x507.8–610.9, y550.3–581.6. The unscaled y=720 is 120 px below the 600-px control → **Enter never logs in**. In mode 0 the click lands on whatever is below the game window; in mode 1 (display 800×600) `SetCursorPos` clamps it to y=599. The ini override can't fix this (`BtnEnterOffsetY` would need 550–581). |
| 11. Login without a realm? | **Retail has no unselected state.** `GameSetUp.ini` and `DefaultGameSetup.ini` ship `GroupRecord=0`, `ServerRecord=0`. Init pushes CURWORLD/CURSERVER (`0x4AB80F/0x4AB849`). The region build auto-presses `currentR`; the end of the ss1 tween calls `onPressItem(currentS+1)` → CMD_SELECTSERVER. Every later region change auto-selects server 0 (`currentS` reset). CMD_SELECTGROUP writes only `+0x190`. Flash Enter checks only that both fields are nonempty → inGameMC frame 17 → CMD_ENTERGAME → validator `0x4ABFBD` (table below). Missing Server.dat row → ERROR StrRes **10012** "Failed to open the Server.dat file. Please reinstall the game." → `getError`: errorMC opens, inGameMC returns to frame 1, blockers on. OK closes it and the user can retry. It is not a stall and there is no "select realm" popup. Edges, both resolved: (1) both ini keys absent → (−1,−1) → row 0, the root row. Its ServerIP element is empty (`<field name="ServerIP"></field>`), and the TinyXML loader (`0x766270`) stores a field only if it has a text child, so the lookup returns NULL → the same StrRes 10012 error. (2) A region click → CMD_SELECTGROUP at once, while `+0x194` keeps the old index until the ss1 fade-out ends (5 tween frames, `useSeconds=false`) and auto-selects server 0. Enter → inGameMC frame 2 → CMD_ENTERGAME at frame 17, 15 frames later. inGameMC frame 2 also places full-stage `maskMC` (sprite 262, self no-op `onPress`), which blocks every region/server click until loading resets. CMD_ENTERGAME therefore always sees the auto-selected (newGroup, 0); there is no stale-index window. |
| 12. What disables editing? | Blocker clips (`maskMC1/2`) during the opening movie, dialogs and loading. Native: account input passes `+0x158`; password input passes `(+0x158 ∥ +0x150==1 ∥ +0x155)`. When true, helper `0x59E5B2` accepts only queued soft-keyboard text (CMD_SOFTKEYDOWN); physical keys are ignored. Writers: `+0x155` = bind-server connect-failure latch (`0x4AF38C`; also sets `+0x150=1`, shows STR_BINDSERVER_CONNET_FAILURE, clears the password); `+0x158/+0x150` = lost bound-account metadata (`0x4AF7F7`). Reset in ctor, CMD_SELECTSERVER (`0x4AA1C8`) and close. Retail Server.dat has no BindServer rows → a bind connect is never attempted → the latch is unreachable with retail data. No branch tests region/server selection. |

`STARTTOFLASH` saves the selection start; `ENDTOFLASH` applies `Selection.setSelection(savedStart,end)`. `FOCUSTOFLASH="1"/"2"` calls `Selection.setFocus` on the actual username/password fields. `LOGINUSER`/`LOGINPASS` assign both the root backing value and visible field. The onChanged handlers in this panel play typing sounds; the native bridge owns the separately established credential synchronization. It would be incorrect to infer a required realm gate from that separation.

## Other controls, dialogs, tooltips and progress

Register/Paid/Help are real DefineButton2 controls. Their handlers install rollover sound + tooltip, rollout tooltip close, press sound and release command. No external endpoints were visited.

| Control | CMD_GETURL parameter source |
|---|---|
| Register / Sign Up | Nonempty `OEMiniData.Register.url`: `"http://" + value`; else literal `https://account.91.com/common/signup.aspx?flag=co&url=http://co.91.com` |
| Charge/Paid | Nonempty `OEMiniData.ReCharge.url`: `"http://" + value`; else `"http://" + iniData.URL.URL_charge`, whose shipped value is `credit.91.com/purchase` |
| Help | Nonempty `OEMiniData.OemHelp.url`: `"http://" + value`; else `"http://" + iniData.URL.URL_help`, whose shipped value is `co.91.com` |

The shipped tooltip strings include Save Account, Clear Account, Accounts List, Register, Purchase Conquer Points, Help, Previous, Next and Caps Lock. Their geometry is runtime-drawn by **CTxtTip**, not a separate raster skin: a text field starts at (5,5), initially 100×20, auto-sizes/word-wraps; text color 16118501; black fill at 70% alpha; beveled outline uses the original source line colors/alpha. The item starts at (10,10) inside a root mouse-following clip. Right overflow subtracts the tooltip width. No invented sample tooltip PNG is included; raw class code supplies exact drawing instructions and runtime text bounds remain font-dependent.

Caps Lock sprite 370 starts invisible. `setTxt` replaces the authored Chinese initializer with `iniData.tip.capsLock`. Password focus checks `Key.isToggled(20)`, installs a Key listener, and shows/hides the clip. Losing password focus removes the listener and hides it. Show adds 25 alpha per frame, clamping at 100; hide subtracts 25 per frame until invisible. Nominal full fade is four stage ticks, but the initial alpha/state matters. The authored larger text bounds are preserved; a static export's default Chinese text is not the runtime English message.

Error/save/clear/quit dialogs have a common **10-frame** timeline: frame 1 stop/idle, frame 2 begin show and sound, frame 6 stop for interaction, frame 7 hide sound, frame 10 reset/finish. Their masks and transforms are preserved per frame. Save/clear OK emits the corresponding command at frame 6; error OK merely advances its close sequence. `getError` sets `sErrorTxt`, opens errorMC and returns loading to frame 1. `ERROROK` dispatch calls `getEnterDown`, which is **empty in this SWF**; do not infer keyboard error dismissal solely from the native ERROROK sender. Quit has separate loading/nonloading instances and delayed `cmd_assureExit` at frame 10 after OK.

Loading sprite 394: frame 1 stops, hides the clip, clears panel blockers and sets `isLoading=false`; frame 2 shows it and sets blockers/`isLoading=true`; frame **17** stops and sends `CMD_ENTERGAME`; frame **36** stops and sends `CMD_GAMESTART` with **100**; frame **99** stops and sends `CMD_CLOSE` with **1**. Root `getProgress` resumes it only for strings **"1"** and **"80"**. `getLoadingTrace` shows it and assigns `txtMsg1`. This is a callback-driven sequence, not a numeric 0–100 progress-to-frame mapping or a free-running 100-frame loop. No new progress labels were invented.

### Login loading presentation (sprite 394, verified 2026-11-02)

Evidence: [evidence/login-loading-394-2026-11-02/](evidence/login-loading-394-2026-11-02/) (`timelines.json`, assets, frames, `SHA256SUMS.json`, `swfwalk.py`). Source `start.dat` `db4b4550…da20`. Root placement: depth 278 at (512,384), 30 fps. Matrices are in px.

**Display list**

| Depth | Char | From frame | Placement | Content |
|---:|---|---:|---|---|
| 1 | 262 `maskMC` | 2 | (−512,−552), sy 1.4375 | full-stage click blocker (shape 261) |
| 3 | 377 | 18 | (0,0) | bar track, bitmap 376 (1024×12) |
| 4 | 380 | 18 | x 70 → 954, y 1.95 | bar fill (shape 379), +10.7805 px/frame |
| 8 | 383 | 18 | (0,0) | bar frame, bitmaps 381/382 (1024×90) |
| 9 | 387 | 18 | x −442.95 → 441.05, y 0 | head; 7-frame loop, alpha mult 256,213,171,128,171,213,256 |
| 12 | 375 | 2 | (0,0) | dragon end caps, bitmap 374 (82×70) |
| 13 | 393 | 18 | (−4.75,60.95) | "Loading" text, 40-frame loop: shapes 389/390/391/392 at frames 1/11/21/31 |
| 15 | 373 `txtMsg1` | 1 | (−426,−94), s 0.99986/0.99585 | trace text: Arial 14 #B27A2D, centered, 856.1×20.1 |

There are no masks (no clipDepth) and no color transforms other than 387's alpha. Depth 4 and depth 9 move linearly from frame 18 to frame 100. Nested 387 and 393 keep looping while 394 is stopped. Frames 2–17 show only `maskMC` + 375, which is the end caps without a bar.

**Stops**

| Frame | Script | Head stage x |
|---:|---|---:|
| 1 | `stop`, hidden, blockers off, `isLoading=false` | — |
| 2 | shown, blockers on, `isLoading=true` | — |
| 17 | `stop`; `cmd_enterGame()` → `CMD_ENTERGAME` | — (bar not yet placed) |
| 36 | `stop`; `CMD_GAMESTART 100` | 263.1 (matches the retail capture, dot at x≈263) |
| 99 | `stop`; `CMD_CLOSE 1` | 942.25 |

**Existing-character sequence** (native; all text from `ini/StrRes.ini`):

| # | Trigger | Clip | `txtMsg1` |
|---|---|---|---|
| 1 | Enter → `inGameMC.gotoAndPlay(2)` | 2→17 (0.5 s), stop | (empty) |
| 2 | frame 17 `CMD_ENTERGAME` → validator `0x4ABFBD` → connect `0x66D3FF`; success sets callback mode **0x3E9** at `0x66D48B` (synchronous, inside the fscommand) | held at 17 | from the next host frame, each frame: mode handler `sub_577FFF` (`CLoginFlashCallbackState_SetModeHandlerByCode` case 1; vtable `0x8665E8`+0x10) → `0x5DC744`: StrRes 11237 "Logging into account server..." + net pump |
| 3 | seed packet → `0x764BC6` posts `0xCEE` → Submit `0x4AEE6A`: auth packet; `PROGRESS "1"` (`0x4AF0FC`, `0x923AF4`); post `0x482` (clears `+0x179AAC/+0x179AB8`) | play 17→36 (0.63 s), stop | 11237 still (mode 0x3E9) |
| 3b | packet 1055 success (`0x754F04`) posts 0x464 cmd **0x519**, lParam 0 → `0x5C13A7` | — | Cn_Res `STR_LOGIN_GAME_SERVER` "Logging into the game server.." (lParam≠0 takes `0x5C1338` instead) |
| 4 | frame 36 `CMD_GAMESTART` → `0x480` → `+0x179AAC = 1` | held at 36 | — |
| 5 | game server `ANSWER_OK` → `0x5DCC64` (login-dlg push `0x5DCCBD`) | held | StrRes 11238 "Initializing..." |
| 6 | MsgAction 74 → `0x47F` → `+0x179AB8 = 1`; map created; each map tick runs `0x5DCEA3` | held | StrRes 11239 "Creating maps..." |
| 7 | first tick with AAC==1 && AB8!=0 → clear both; `PROGRESS "80"` (`0x5DCEDF`) | play 36→99 (2.1 s), stop | StrRes 11240 "Starting... Please wait..." for that one tick; the next tick's else branch writes 11239 again, so 11240 is effectively invisible (not seen at runtime) |
| 8 | frame 99 `CMD_CLOSE 1` → `0x4AC62B`: post `0x483` (world gate), `0xC6B`, `0x3F2` | — | — |

`getError` at any point → `inGameMC.gotoAndStop(1)` (hidden, unblocked) + errorMC. `PROGRESS` has only those two senders (`"PROGRESS"` xrefs `0x4B04C1`, `0x51C294`).

**role.dat clip (sprite 110, root depth 102 at (508,376))**

Same depths, positions, maskMC and end caps. txtMsg1 is at x −421.4 with scale 1. Nested sprites have the same frame counts (7, 40). The timing differs:
- The bar appears at frame 7, not frame 18.
- The clip has 201 frames: head 4.5567 px/frame over frames 7→201, stops at 71 (`CMD_GAMESTART`) and 201 (`CMD_CLOSE`), with no frame-17 stop.
- Its bitmap tag bodies differ from start.dat's (only 1 of 9 shared). Pixel equality was not checked.

Mode 0x3EF (`0x4AF5C8`, bind-server variant) installs the same `sub_577FFF` handler; retail has no BindServer row.

**Runtime** (retail 5517 in Win11 VM, 1:1 pixels with the HIGHDPIAWARE compat flag on a scratch exe; OpenConquerServer against a throwaway DB copy; existing character). Frames: `evidence/…/runtime-burst/` (ms since the screen turned black; saved on txtMsg1 change, else 1/s).

| ms | Clip | Text |
|---:|---|---|
| 70 | frames 2–17, end caps only | (empty) |
| 869 | ≥ 18, already resumed | Logging into account server... |
| 1355 | moving toward 36 | Logging into the game server.. |
| 6624 | held at 36 (head x≈263) | same |
| 6929 | held at 36 | Initializing... |
| 7324 | past 36 | Creating maps... |
| 8391 / 9421 | moving to 99 | Creating maps... |
| 10060 | closed | world |

The long hold at 36 (≈5.5 s) is server-side time on our server. It is not a client constant.

**txtMsg1 pixels** (`runtime-text/`, crops of stage (84,286)–(942,312), `text-metrics.json`):
- GDI **ClearType** subpixel AA. Edge per-channel coverage differs, e.g. R 0.01 / G 0.22 / B 0.58.
- Full-ink pixels are exactly #B27A2D (178,122,45).
- The background matches the static 394 render to a mean absolute error of 0.08.
- Glyph box is y 293–305.
- Text bounding boxes: "Logging into account server..." x 427–595, "Initializing..." 477–544, "Creating maps..." 464–558.
- Guest: Windows 11 Pro 26200, `FontSmoothing=2`, `FontSmoothingType=2` (ClearType), orientation 1 (RGB), gamma 0 (default), Arial sha256 `B3658EAD…476A`, Flash.ocx 7.0.14.0.
- The pixels depend on these settings. Grayscale smoothing or a different gamma gives different pixels.

No visible music enable/disable control or handler emitting CMD_SELECTBGMUSIC was found in the complete inspected `start.dat` AVM1/display inventory. Existing native support/persistence of that command is retained in note 03, but it is not visual evidence. No Flash settings panel was resolved in this login movie. Loose `MusicDisable.dds` or a native command name elsewhere would not establish one here.

## Exact evidence locations

Offsets below are in the **decompressed SWF/FWS byte stream including its eight-byte header**, not offsets in the compressed `.dat` file. The raw source hash above pins the compressed original. Matrix coefficients are also retained as exact recovered 16.16 integers in timeline display states. `metadata/tag-index.json` gives every tag offset, `action-index.json` gives action ranges and raw hashes, and `function-offsets.json` gives exact raw function boundaries. `metadata/raw-avm1/` is parsed directly from those original bytes with every byte covered; readable decompiled scripts are secondary interpretation.

| Evidence | Original start.dat location |
|---|---|
| Root host-variable adapter | root frame 1 DoAction_2, action payload **0xBA3**, 9704 bytes |
| getLoginUser / getLoginPassWord | function records **0x1A5B / 0x1AC3** |
| getUserListName | **0x1C1C** |
| getSelectStart / getSelectEnd | **0x1CAE / 0x1CD3** |
| getTxtFocus / getProgress / getError | **0x1D61 / 0x1DE4 / 0x1E5D** |
| cmd_enterGame / cmd_record / cmd_clear | **0x27AD / 0x286C / 0x288C** |
| loadIni | **0x29B4** |
| Server createControl / onPressItem | sprite 180 frame 1 functions **0x6D509 / 0x6DBB8** |
| Region btnPressed / onPressItem | sprite 259 frame 1 functions **0x78F00 / 0x79357** |
| Save confirmation callbacks | sprite 283 frame 6 action payload **0x7C4A4**, 523 bytes |
| Clear confirmation callbacks | sprite 285 frame 6 action payload **0x7C9AA**, 534 bytes |
| History code | sprite 360 frame 1 action **0x8A20A**, 2839 bytes; create **0x8A662**, pop **0x8A7F7**, reset **0x8A997** |
| Account-panel handlers | sprite 371 frame 1 DoAction_2, action **0x8B19F**, 7178 bytes; createControl **0x8B88D**, onEnterFrame1 **0x8C123**, setSelect **0x8C2CA** |

Native new evidence is preserved as assembly text and the exact comment changes in `evidence/native/`. Main anchors: `0x4ADC0B` account input call, `0x4ADC6F` clear after account update, `0x4ADE26` password input call, `0x4ADD7B`/`0x4ADFD4` Tab dispatch, `0x4AE2AE..0x4AE2EC` synthetic click, and `0x59E5B2..0x59E5CC` conditional input-policy behavior. Existing account-list, command dispatch, server endpoint and initialization contracts remain referenced to notes 03/05 and `Network/5517-server-selection-and-realm-handoff.md`.

## Follow-up closure (2026-10-15)

Runtime method: the retail `Flash.ocx` 7.0 was hosted in an ATL window (`AtlAxWin`, 1040×807 outer, ~1024×768 client) under Wine. The probe loaded `start.dat`, seeded `VCTOFLASH=PATH|<retail root>`, sent `VCTOFLASH` commands, loaded probe SWFs into `_level1`, and polled `GetVariable` every 100 ms. Files are under `nativeflashevidence/work/login-ui-research/followup/`: `flash_probe.c`, `build_probes.py`, `focus_probe.swf`, `clear_probe.swf`, `region_probe.swf` and `runtime-experiments.log`. No Conquer.exe process, server or URL was involved.

| Gap | Result | Proof |
|---|---|---|
| Initial focus | none: typing before a click goes nowhere; Win32 focus starts on a native shell button | Flash.ocx probe + retail client on Windows |
| Tab / Shift+Tab | account→password; password Tab is a no-op; Shift ignored; Flash built-in Tab moves no field focus | Flash.ocx probe + **retail client on Windows** + `0x4ADD5A/0x4ADFB3/0x4AE198` |
| Enter | synthetic click (700,720): logs in at ScreenMode 2/3 (1024×768), never at 0/1 (800×600) | native chain `0x5D7C51`→`0x4AEC64`→`0x4AE2AE` + DLGINIT ShowAll |
| Protection policy | `+0x155/+0x158/+0x150` writers known; soft-key-only input; unreachable with retail data | native |
| Unselected realm | retail always has a selection; missing row or (−1,−1) → StrRes 10012 error; no stale-index window | native + TinyXML loader + retail ini/Server.dat + start.dat frame timing |
| Logo | loops 1–25 | runtime |
| rsDragon | never loaded, never shown | runtime + static |
| Top/bottom/poetry | empty holders; nothing to animate | static |
| Region frame 16 | clamps to 13 | runtime |
| Clear-dialog text | ` "<account>" ` | runtime + static |

- `nStageType` (start.dat 800×600 layout: root ×78.125, repositioned dialogs/tooltips) is declared 0 and assigned nowhere — not in start.dat, not in Conquer.exe or DLLs (ANSI or UTF-16), not in ini. That branch is dead in retail; only `Scale=ShowAll` scales the stage.
- Esc: DIK 0x01 polled at `0x4ADB23` → VCTOFLASH `SETKEYDOWN|0` → `getExit` → `quitWindow2` while `inGameMC.isLoading`, else `quitWindow`. OK → `cmd_assureExit` → `CMD_RETURN|1` → `0x4AA20F` `CRoleCreateFlashDlg_PostMainWindowMessage55` → main-window command 0x55. `SETKEYDOWN|1` → `getEnterDown`, which is empty.
- Opening timing (probe host, PATH seeded at 400 ms): root hidden until `loginFlash.swf` loads (`_visible` true at ~0.53 s); `item` runs frames 1→27 in about 1 s; root frame 2 at ~1.55 s, frame 3 at ~1.65 s. The 8500-ms check then finds `item` gone and calls `_root.play()` → root frame 4 at ~9.0 s. Frame 4 has the same display list as frame 3 plus `stop()`, so there is no visible change.

### CMD_ENTERGAME native validator `0x4ABFBD`

Dispatch: `strcmp "CMD_ENTERGAME"` at `0x4AA21F`, call at `0x4AA22C`. The body is obfuscated with `pushad; call stub` / `pop r; add r,imm8; jmp r`; real resumes are at `0x4AC077`, `0x4AC0CD`, `0x4AC12F` and `0x4AC165`. Each error goes through `ShowLoginErrorText` → VCTOFLASH `ERROR|text` (`CRITICAL` in the Facebook variant) → `getError`.

| # | Check | On failure |
|---:|---|---|
| 1 | role-2 `ServerIP/ServerPort` for row `+0x190*100 + +0x194 + 101` | StrRes 10012 "Failed to open the Server.dat file. Please reinstall the game." |
| 2 | `g[0x95620C]` ≠0 and `GetTickCount − it` < 10000 | StrRes 49995 "Please login later!" |
| 3 | sets `g[0x95620C] = GetTickCount` | — |
| 4 | `g_startupMovieFacebookVariantEnabled` (`0x96AB34`) | → `PersistSelectionAndConnectAccountServer` `0x4AF12D` |
| 5 | password length (`+0x414`) ≤0 or >0x80 | StrRes 10014 "Wrong password." |
| 6 | language (GameDataSet vf+0x34) ∈ {English, French, Spanish, Russia, Thai, Turkey, Vietnam, Brazil} and password length >14 | StrRes 11400 "Your password must be 10-14 characters…" |
| 7 | `BeginAccountBindServerHandshake` `0x4AF2C7` | no BindServer row (retail) → `0x4AF12D`: role-2 lookup, role-5 BGP, writes GroupRecord/ServerRecord to `ini/GameSetup.Ini` → `CGameMain_ConnectAccountServerWithBgpFallback` `0x66D3FF` (empty host ⇒ CHECKF and no connect; 10 s connect then BGP; both fail ⇒ StrRes 10397 "Server maintenance or network congested. Try again later." plus `Sleep(5000)`; success ⇒ callback mode 0x3E9) |

Auth packets are not sent here. The account server's seed packet makes `CMsgLoginSeed__Process_DeriveCredentialRc5KeyFromSeed` (`0x764BC6`) post cmd `0xCEE`; shell case `0x5BC81B` calls Submit `0x4AEE6A` at `0x5BC841` (corrected 2026-11-02; earlier text said 0x480). Every attempt that passes checks 1–2 sets the timestamp, including one that then fails checks 5–6. Account emptiness is checked only by Flash. Field 364's `maxLength` 15 allows a 15-character password, which check 6 rejects whenever the language matches. vf+0x34 is `GameDataSet_GetLanguageName` (GraphicData.dll `0x1001DC00`), which returns the constant `"English"`. Check 6 therefore always applies: passwords longer than 14 characters always fail with StrRes 11400.

### Device-font text fields (start.dat)

DefineFont2 3 (Arial, 15 glyphs ` ?Aaeinorstuwxy`), font 7 (Arial Bold, 12 glyphs `./0123456789`), fonts 291/368 (宋体 = SimSun, 0 glyphs). Only field 184 sets `useOutlines`, so it renders from embedded glyphs. All other fields are **device text**: GDI renders the named system font. Sizes are in px; bounds are local w×h.

| Field | Instance (sprite) | Font | Size | Color | Align | Flags | Bounds |
|---:|---|---|---:|---|---|---|---|
| 4 | `nameTxt` (6, history row) | Arial | 14 | #AF3A3A | L | ro, noSelect | 153×20.8 |
| 8 | `txt` (9, version) | Arial Bold | 14 | #888888 | L | ro | 194×21.9 |
| 35 | `nameTxt` (179, server tile) | Arial | 14 | #000000 | C | ro | 123.05×19.6 |
| 184 | `pageTxt` (259, region page) | Arial Bold **embedded** | 20 | #293940 | C | ro, useOutlines | 75×26.35 |
| 273 | `txt` (274, error) | Arial | 14 | #FF4642 | L | multiline, wrap | 277.15×113 |
| 275 | `txt` (283, save) | Arial | 14 | #FF4642 | C | multiline, wrap, initial text | 274.05×62 |
| 284 | `txt` (285, clear) | Arial | 14 | #FF4642 | L | multiline, wrap | 292.75×109.5 |
| 292–309 | Sign Up / CP Purchase / Help labels | SimSun (HTML `<font size=14>`) | 14 | 292/294/297 and 300/302/304 = #938040/#DBA94C/#938040; 306/307/309 all #938040 (definition order) | L | html | 59.85/91.35/36.2×20.25 |
| 363 | `userNameTxt` (371) | Arial | 14 | #908B37 | L | editable | 122×22.1 |
| 364 | `passwordTxt` (371) | Arial | 14 | #908B37 | L | editable, password, maxLength 15 | 140.65×22.1 |
| 369 | `txt` (370, Caps Lock) | Arial | 14 | #FFFFFF | L | multiline, wrap | 166×71.5 |
| 373 | `txtMsg1` (394, loading trace) | Arial | 14 | #B27A2D | C | ro | 856.1×20.1 |

Align is the DefineEditText code (0 L, 1 R, 2 C). Correction 2026-10-16: 35/184/275/373 are code 2 = **center**, not right (rev 1 misread). Retail capture confirms: "Mercury" centred at holder+90.3. Leading is 2 px for all fields (0 for the HTML labels); margins and indent are 0. Exact pixels need the retail Windows GDI fonts and Flash 7 device-text rasterization. This was not captured, because Wine substitutes its own fonts.

### Retail client on real Windows (2026-10-16)

Host: Windows 11 ARM64 VM (x86 emulation), 200% scaling (DPI 192, so the DPI-unaware client is shown 2048×1536). Client: clean retail tree copied into the guest (Conquer.exe `b6ba5ab8…`, Flash.ocx `94058fe5…` registered), `Conquer.exe blacknull`, ScreenMode 2. Outbound and inbound traffic blocked by a firewall rule for this exe only; no server, no login attempt. Input: Parallels hardware scancodes (`prlctl send-key-event`) and `SetCursorPos`/`mouse_event` clicks. Captures and scripts are in `nativeflashevidence/work/login-ui-research/vm-runtime/`. Guest cleaned afterwards.

| Test | Observed |
|---|---|
| Startup selection | clean ini (0,0) → Celebrations + GardenOfEden auto-selected |
| Fresh launch, no click, type `xyz` | nothing in either field. Win32 focus is a native shell `Button` child of MyWnd, not Flash |
| Click account, type `abc` | Win32 focus → `MacromediaFlashPlayerActiveX`; `abc` appears once (no doubled input) |
| Tab, type `de` | focus → password, `**` |
| Tab in password with text | focus stays, all text selected |
| Tab again / Shift+Tab, type | stays on password (`***`, `****`). Shift ignored |
| Click stage background, Tab, type `q` | no field gets focus or text. Flash's own Tab traversal moves nothing into a field |
| Side effect | Enter button switches to its highlight frame on the first Tab and stays. Cause not isolated (consistent with Flash tab-focus rollover) |
| Startup sound failure | "Failed to initialize the sound system…" box (DXSoundinit); OK continues to login |

### Stage geometry, runtime (2026-10-16)

Proven from metadata + AVM1, checked against `vm-runtime/01-login-first-launch-mode2.png` (1024×768, 2× DPI).

| Item | Value |
|---|---|
| shape 11 | bitmap 10 (1024×637) at stage y **41** |
| Region holders | `sr1..sr8` column x −93, `sr9..sr16` x 64.85 (xscale .99936), inside 259 matrix [.98028564,0,0,.9801178,150,381]. Slot order runs **down column 1, then column 2** (`aBtn`). Retail capture: 14 regions → column 2 rows 7–8 empty |
| Region y | 259 `onEnterFrame` springs every holder's `_y` to `aPosData.y` (−209,−159,−108,−57,−6,45,96,147); x untouched. `aVY` has 8 entries, but SWF 6 coerces `undefined` to 0, so `sr9..16` move too. Capture: both columns' tile tops at the same stage y |
| Region panel bg | 259 depth 1: sprite 183 at (−99.7,−242.85), CXFORM alpha 195/256 |
| Region hit | defaultR `hitMC` sprite 5 (−55.2,−199.6)–(60.8,−106.6) × [1.31546,0,0,.53772,73.7,109.05] → movie (1.09,1.72)–(153.68,51.73). unopenedR has no hitMC (`onEnterFrame1` stops at it) |
| defaultR | shape 3 = bitmap 2 (154×54 tile) at (0,−1) + bitmap 1 (caption "收费一至五区"). Frames 2–8 / 10–12: depth 3 sprite 9 = bitmap 7 (158×58) under per-frame matrix, alpha 128/0 on 11/12. Frame 13: sprite 61 at (3,1) + shape 62 (bitmap 6 red caption). Sprite 61 frames 1–5 alpha 26/72/118/164/210, stop at 6; nested sprite 60 loops 25 |
| Server holders | 180 at (685,373); `ss1..12` = `aPosData` (x −259.3/−91/77.35, y −179.25/−87.75/3.5/94.25; **ss3 y −178.25**) |
| Server tile 179 | frame 1 = `son` (placeholder sprite 25 until `loadMovie`), `light` (9.3,62.25), `nameTxt` (30.5,64.8) xscale 1.00433, `hitMC` sprite 37 × [1.29311,0,0,.89247,77.75,179.65] → (6.37,1.51)–(156.36,84.51). No server paging: 180 has no leftBtn/rightBtn/pageTxt |
| Tile 179 depths | 1 `son`, 4 sprite 40 (f2–10, at (2.1,1.75), alpha 13/74/135/195/256 f2–6, 195/135/74/13 f7–10; removed f11), 6 `light`, 8 sprite 83 (f6 at (−22.65,−9), removed f7) / sprite 178 (f12 at (−26,−29)), 10 `nameTxt`, 11 `hitMC`. Rollover `gotoAndPlay(2)` → stop f6; roll-out `gotoAndPlay(11)` (f7–10 never play); press `gotoAndStop(12)`, others `gotoAndStop(1)`. Rollover/roll-out skipped for `nSelectServer` (sound still plays) |
| Sprite 83 | 34 frames, no DoAction ⇒ **loops** while 179 holds f6; f22 removes depth 1 ⇒ f22–34 empty |
| `light` (sprite 34) | bounds (0,0)–(18,18); f1–4 red/yellow/green/purple. `flushLight`: present slot ⇒ visible, state 1–4 ⇒ that frame, else f4; absent ⇒ hidden. Init push state 3; refresh resolves `ServerListEntry_ResolveFlashStatusCode` (absent ⇒ 0 ⇒ f4). Loader catches `CInternetException` (`0x5EA7C5`, `e->Delete`) ⇒ empty catalog, flag still set, refresh pushed; empty URL ⇒ immediate return. Only non-`CException` throws skip the refresh (`0x4B05FE` catch(...) resumes past `SetLoadThreadRunningFlag`) ⇒ state 3 stays. Shipped `common.ini` line 103 `[ServerStatus] URL=http://account.conqueronline.com/status.php/` firewalled in VM capture ⇒ f4 on every server |
| Server movies | `GroupN/serverM.swf` root shape 3 = bitmap 2 (170×90 frame) + JPEG3 bitmap 1 picture at (6,3), shape-clipped; Group9/server1 shape 2 = bitmap 1 (164×85). JPEG3 RGB is premultiplied (JPEXS un-premultiplies) |
| Region paging | 259 rightBtn 192 [0,−1,1,0,103,261], leftBtn 199 [0,1,1,0,8,244]; visible only when pages > 1; `onRelease` steps `_root.nPage` and `flush(page)` only (selection kept); `onChangePage` is undefined (no-op), `bIsPageChange` stays false. pageTxt = `nPage + "/" + count` |
| Selection | region/server select on **press** (`hitMC.onPress`). Region press ignored while `nMovingSeverCount` > 0 or for the selected one. Server press plays `click_server` whenever enabled, selects only if different |
| `snd_ss` sounds | root f1 DoAction_2 loads every `[serverSelection]` key; played: `rollOver_region`, `click_region` (empty), `dragonMov` (259 DoAction), `rollOver_server`, `click_server` (180 DoAction), `rollOver_/click_leftPage`, `rollOver_/click_rightPage` (259). **`show` (Dragon.mp3) is never played** — no `playSound("snd_ss","show")` in start.dat |
| verTxt | `setVer`: `"version: "` + `LoadVars(version.dat).toString()` up to `=`/`%` → "version: 5517"; failure appends "版本号读取错误". Shown at root frame 3 |

### Residual unknowns

1. Retail device-font pixels (Arial/SimSun via GDI): not captured at 1:1. The VM runs at 200% DWM scaling and the session was stopped before a 1:1 capture. Field parameters are in the table above.
2. Cause of the Enter highlight after Tab (observed, not isolated).
3. The 800×600 Enter miss is proven statically (`0x5D7C51` → `0x4AEC64` → `0x4AE2AE`) but was not run in the VM.

## Export fidelity

1–7. Superseded by [Follow-up closure](#follow-up-closure-2026-10-15).
8. **Decoder limits:** JPEXS cannot render these embedded video frames into its static sprite preview; its crossed-box video placeholders were excluded. Original streams were extracted to FLV and decoded with FFmpeg, preserving opaque alpha. First 24 opening frames are supplied as decoded video with exact placement metadata; last three original nonvideo transition frames are separate. They are not mislabeled as full executed AVM1 screenshots.
9. **Decompilation normalization:** eight JPEXS p-code-hex exports differed from original action bytes because its action processing rewrote function bodies. They are not used as original byte offsets. Original action blobs, direct raw AVM1 listings and function-offset maps are included; offsets attached to JPEXS p-code are emitted only for byte-exact matches. The readable scripts remain useful for control-flow interpretation.
10. **Authored versus live composition:** exports render original bitmap fills/shapes/nested timelines; they do not execute AVM1 `loadMovie`, dynamic `attachMovie`, `setMask`, alpha/visibility changes or event stops. Metadata and this note carry those overrides. Hit-test images are diagnostic, never visible-state skins. Missing disabled/focus graphics are not manufactured. Fractional raster edges and device text remain renderer-dependent.

This slice supplies authentic source art and explicit evidence boundaries for the requested UI questions. It does not claim a live retail replay or full pixel-for-pixel ActiveX validation.
