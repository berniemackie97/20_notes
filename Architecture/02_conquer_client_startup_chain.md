# `Conquer.exe` Startup Chain

## Scope

This slice documents `Conquer.exe` startup from CRT entry through the first stable client frame-driving loop.

- Binary: `00_clean/clean/5517/Conquer.exe`
- Active BNinja view: `17`
- Entry point: `_start` at `0x777AAE`

`play.exe`, `AutoPatch.exe`, and `TimeDelay.exe` behavior is out of scope for this slice.

## Renamed Symbols Applied In BNinja

| Address | Verified name |
|---|---|
| `0x7CB324` | `Conquer_CrtForwardToAfxWinMain` |
| `0x7CB33C` | `Conquer_CrtConfigureMfcModuleStateForStartup` |
| `0x7CB365` | `Conquer_CrtInitializeMfcModuleState_Thunk` |
| `0x7CB36A` | `Conquer_CrtInitializeMfcModuleState` |
| `0x5AA547` | `ConquerApp_Constructor` |
| `0x5AA70D` | `ConquerApp_Destructor` |
| `0x5AA6C2` | `ConquerApp_DeletingDestructor` |
| `0x5AA766` | `ConquerApp_ConstructGlobalInstance` |
| `0x5AA75C` | `ConquerApp_ConstructAndRegisterGlobalInstance` |
| `0x5AA770` | `ConquerApp_RegisterGlobalDestructor` |
| `0x5AA77C` | `ConquerApp_DestroyGlobalInstance` |
| `0x5AA83F` | `ConquerApp_InitInstance` |
| `0x5AB47C` | `ConquerApp_RunMessageLoop` |
| `0x5AB8E4` | `ConquerApp_PumpMessage` |
| `0x5AB533` | `ConquerApp_OnIdle` |
| `0x5AB957` | `ConquerApp_ExitInstance` |
| `0x5AA327` | `ConquerApp_RunPeriodicMaintenanceSlice` |
| `0x5AB572` | `ConquerApp_LoadGemTipIni` |
| `0x5AAF10` | `ConquerApp_ParseLaunchArgumentsAndSetStartupMovieVariantFlag` |
| `0x4B084D` | `CStartupLogoDialog_CreateEmbeddedControl` |
| `0x4B0872` | `CStartupLogoDialog_ctor` |
| `0x4B0897` | `CStartupLogoDialog_scalarDeletingDtor` |
| `0x4B08B3` | `CStartupLogoDialog_GetMessageMap` |
| `0x4B08B9` | `CStartupLogoDialog_OnInitDialogLoadLogoBrush` |
| `0x4B0ABD` | `CStartupLogoDialog_dtor` |
| `0x4B0AEB` | `CStartupLogoDialog_OnDestroyReleaseLogoResources` |
| `0x4B0B11` | `CStartupLogoDialog_OnCtlColorReturnLogoBrush` |
| `0x4AD9A9` | `CLoginFlashDlg_TickFlashHostStateAndInputBridge` |
| `0x4B04B6` | `CLoginFlashDlg_SetProgressVariable` |
| `0x4B04CE` | `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` |
| `0x51C1C3` | `CRoleCreateFlashDlg_SetFlashVariableAndDispatch` |
| `0x51C289` | `CRoleCreateFlashDlg_SetProgressVariable` |
| `0x5AFD4C` | `CMyShellDlg_TickMapRoleAndEffectPipeline` |
| `0x5DCEA3` | `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` |
| `0x5780EC` | `CMyShellDlg_RunPreWorldFlashHostFrameCallbacksIfNonNull` |
| `0x57813B` | `CMyShellDlg_RunFrameTickCallback_InvokeIfNonNull` |
| `0x5789A2` | `CMyShellDlg_SetFrameTickContext` |
| `0x5964C1` | `CFlashHostDialog_IsWindowVisibleOrPendingActivation` |
| `0x596F79` | `CFlashHostDialog_ApplyShowHideStateAndLifecycleCallbacks` |
| `0x957F68` | `g_conquerAppInstance` (global data) |
| `0x96AB34` | `g_startupMovieFacebookVariantEnabled` (global data) |

## CRT -> MFC Startup Chain

| Step | Address | Evidence |
|---|---|---|
| CRT entry | `0x777AAE` | `_start` computes WinMain args and calls `Conquer_CrtForwardToAfxWinMain` at `0x777BDD`. |
| MFC forwarder | `0x7CB324` | Pushes 4 args and calls imported `AfxWinMain` at `0x7CB334`. |
| MFC module-state init | `0x7CB36A` | Calls `Conquer_CrtConfigureMfcModuleStateForStartup(0, 0x600)` and stores success byte to `0x96E784`. |

Disassembly anchors:

- `_start -> Conquer_CrtForwardToAfxWinMain`: `0x777BDD`
- `Conquer_CrtForwardToAfxWinMain -> AfxWinMain`: `0x7CB334`
- `Conquer_CrtInitializeMfcModuleState`: `0x7CB36A..0x7CB37B`

## Global App Construction Chain

`ConquerApp` global instance storage:

- `g_conquerAppInstance` at `0x957F68`

CRT static-initializer chain:

1. `ConquerApp_ConstructAndRegisterGlobalInstance` (`0x5AA75C`) — in initializer table (`data ref 0x921294`)
2. `ConquerApp_ConstructGlobalInstance` (`0x5AA766`) -> `ConquerApp_Constructor(&g_conquerAppInstance)`
3. `ConquerApp_RegisterGlobalDestructor` (`0x5AA770`) registers `ConquerApp_DestroyGlobalInstance`
4. `ConquerApp_DestroyGlobalInstance` (`0x5AA77C`) -> `ConquerApp_Destructor(&g_conquerAppInstance)`

## App Vtable Evidence (`data_868448`)

Constructor writes app vtable:

- `ConquerApp_Constructor`: `*this = 0x868448` at `0x5AA579`

Verified virtual slots used in startup/run path (from raw pointer table bytes):

| Vtable entry address | Pointer value | Meaning |
|---|---:|---|
| `0x8684A0` | `0x005AA83F` | `ConquerApp_InitInstance` |
| `0x8684A4` | `0x005AB47C` | `ConquerApp_RunMessageLoop` |
| `0x8684AC` | `0x005AB8E4` | `ConquerApp_PumpMessage` |
| `0x8684B0` | `0x005AB533` | `ConquerApp_OnIdle` |
| `0x8684B8` | `0x005AB957` | `ConquerApp_ExitInstance` |

Raw bytes anchor:

- `0x8684A0`: `3F A8 5A 00 7C B4 5A 00 74 75 77 00 E4 B8 5A 00`
- `0x8684B0`: `33 B5 5A 00 6E 75 77 00 57 B9 5A 00 68 75 77 00`

## `ConquerApp_InitInstance` (verified behavior)

`ConquerApp_InitInstance` (`0x5AA83F`) performs:

1. `AfxEnableControlContainer(nullptr)` (`0x5AA85A`)
2. `GameDataSet` init gate; on failure shows message and posts quit (`0x5AA8A3..0x5AA989`)
3. `CWinApp::Enable3dControls` (`0x5AB131`)
4. Allocates/constructs main shell dialog object (`new 0x179B40`) (`0x5AB2CF..0x5AB305`)
5. Stores global main shell pointer `data_95807C` and `this+0x20` (`0x5AB315`, `0x5AB326`)
6. Shows main shell window (`CWnd::ShowWindow`) (`0x5AB348`)
7. Loads optional startup data (`ConquerApp_LoadGemTipIni`) (`0x5AB465`)
8. Returns `1` (`0x5AB47B`)

## Message Loop + Idle Tick Path

`ConquerApp_RunMessageLoop` (`0x5AB47C`) mirrors MFC `Run` pattern:

1. Idle branch (`PeekMessageW == 0`):
   - call vtable `+0x68` (`ConquerApp_OnIdle`) with `idleCount`
   - if return non-zero, continue idle loop
2. Message branch:
   - call vtable `+0x64` (`ConquerApp_PumpMessage`)
   - if zero, call vtable `+0x70` (`ConquerApp_ExitInstance`) and return
   - call vtable `+0x6C` (`IsIdleMessage`) to reset idle mode/count

Virtual call anchors in `ConquerApp_RunMessageLoop`:

- `+0x68` at `0x5AB4C7`
- `+0x64` at `0x5AB4D7`
- `+0x6C` at `0x5AB4EF`
- `+0x70` at `0x5AB4DD`

`ConquerApp_PumpMessage` (`0x5AB8E4`) confirms:

- `GetMessageW` gate (`0x5AB8F1`)
- translate/dispatch path (`0x5AB919`, `0x5AB920`)
- pre-translate gate through vtable `+0x60` (`0x5AB90A`)

## First Stable Frame-Driving Loop

`ConquerApp_OnIdle` (`0x5AB533`) is the first stable per-frame driver in startup:

- ticks on `25 ms` interval (`0x19`) via `timeGetTime` compare (`0x5AB543`)
- updates last tick stamp `data_958080` (`0x5AB553`)
- runs map/role/effect frame pipeline:
  - `CMyShellDlg_TickMapRoleAndEffectPipeline(data_95807C + 0x40, 1)` (`0x5AB562`)
- runs periodic maintenance:
  - `ConquerApp_RunPeriodicMaintenanceSlice()` (`0x5AB567`)
- else path sleeps for remaining interval (`0x5AB54B`)

This establishes the startup-to-runtime bridge:

- `_start` -> `AfxWinMain` -> `ConquerApp_InitInstance` -> `ConquerApp_RunMessageLoop` -> `ConquerApp_OnIdle` -> `CMyShellDlg_TickMapRoleAndEffectPipeline`

## `CMyShellDlg_RunFrameTick` Network Pump Gate (verified)

`CMyShellDlg_RunFrameTick` (`0x5DCFAA`) contains the per-frame network pump gate ahead of world map tick/render:

| Caller site | Instruction pattern | Verified behavior |
|---:|---|---|
| `0x5DCFD4` | `cmp byte [ebp+0x8], 0` / `je 0x5DCFE4` | if frame flag arg is `0`, skip network pump call |
| `0x5DCFDF` | `call CNetMsg__ProcessMsg` (`0x6DEBA5`) | when frame flag arg is non-zero, process pending inbound packets before world stages |
| `0x5DD0CC` | `call CGameMap_TickComponentsAndProcessScreenEffects` | world tick stage runs after optional network pump |
| `0x5DD0D9` | `call Exe_TickMapProjectionAndDispatchMapRender` | world projection/render dispatch runs after map tick |

`ConquerApp_OnIdle` always calls:

- `CMyShellDlg_TickMapRoleAndEffectPipeline(data_95807C + 0x40, 1)` at `0x5AB562`,

so the normal idle-driven frame path enters `CMyShellDlg_RunFrameTick` with network processing enabled (`arg2 = 1`).

Cross-reference to verified socket lifecycle:

- `CGameSocket_InitializeNonBlockingSocket` sets `FIONBIO = 1` before the runtime frame pump becomes active.
- `CGameSocket__RecvFromSocket` / `CGameSocket__FlushSendBuffer` treat `WSAEWOULDBLOCK` as expected non-fatal polling outcome.

This means the `CNetMsg__ProcessMsg` call in the world-frame path is a non-blocking poll stage, not a blocking wait stage.

## `CMyShellDlg_RunFrameTick` World-Frame Enable Gate Byte (`this+0x179AB9`) (verified)

`CMyShellDlg_RunFrameTick` (`0x5DCFAA`) has an early world-frame enable gate that suppresses the entire per-frame world path:

| Site | Instruction pattern | Verified behavior |
|---:|---|---|
| `0x5DCFB3..0x5DCFBA` | `cmp byte [esi+0x179AB9], 0` / `je return` | if gate byte is `0`, returns before network pump, front-overlay draw, map tick/render, and HUD/sound |
| `0x5DCFD8..0x5DCFDF` | `cmp [arg2],0` / `call CNetMsg__ProcessMsg` | only reached when gate byte is non-zero |

Verified writers for `this+0x179AB9` in startup/reset lifecycle:

| Writer function | Site | Write | Meaning |
|---|---:|---|---|
| `CMyShellDlg_ConstructAndInitializeMembers` (`0x5ADAB7`) | `0x5AE01C` | `= 0` | ctor initializes world-frame gate disabled |
| `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate` (`0x5AE8D8`) | `0x5AF5B6` | `= 1` | temporary enable while applying startup layout work |
| `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate` (`0x5AE8D8`) | `0x5AF721` | `= 0` | startup init restores disabled state before thread create |
| `CMyShellDlg_ResetRuntimeAndDisableWorldFrameGate` (`0x5DC783`) | `0x5DCA0A` | `= 0` | reset/logout path forces gate disabled |

This establishes launch-parity expectation for clean startup: frame loop runs, but world-frame path remains off until a verified native flow enables `this+0x179AB9`.

## Verified `this+0x179AB9` enable trigger: `WM_COMMAND 0x483`

The concrete enable path is in `CMyShellDlg_WindowProc_DispatchMainWindowMessages` (`0x5BB79D`), not in `CMyShellDlg_RunFrameTick`:

1. `WM_COMMAND` dispatch range decode:
   - range gate: `arg3 in [0x442, 0x49B]` at `0x5BBBCD..0x5BBBE2`
   - selector byte table: `lookup_table_5cdb81` read at `0x5BBBEE` (`movzx eax, byte [eax+0x5CDB81]`)
   - jump table: `jump_table_5cda8d` branch at `0x5BBBF5` (`jmp [eax*4+0x5CDA8D]`)
2. For command id `0x483`:
   - index = `0x483 - 0x442 = 0x41`
   - `lookup_table_5cdb81[0x41] = 0x26` (table bytes at `0x5CDBC0..0x5CDBC3` are `24 25 26 27`)
   - `jump_table_5cda8d[0x26] = 0x5CAA2D` (entry bytes `2D AA 5C 00` at `0x5CDB25`)
3. In branch block `0x5CAA2D..0x5CAD64`, all paths converge at `0x5CAD57`, then:
   - `0x5CAD5D`: `mov byte ptr [eax+0x179AB9], 1`

Convergence edges:
- `0x5CABD5 -> 0x5CAD57`
- `0x5CAC63 -> 0x5CAD57`
- `0x5CACE2 -> 0x5CAD57`

This is the verified world-frame enable transition used by startup/login command flow.

### Own-UI startup submit chain mapping (`main-own-ui`)

Current managed startup UI preserves native main-window message sequencing for login handoff:

1. user submit queues native-equivalent credential commands (`CMD_NAME`, `CMD_PASSWORD`) in managed form;
2. submit stage posts `WM_COMMAND 0x464` with `wParam=0x480` (native `CMD_ENTERGAME` branch);
3. startup status callbacks (`LOADING_TRACE` `0x2BE7`/`0x2BE8`, `PROGRESS`) are treated as visual status only;
4. world-load stage posts `wParam=0x483` (plus `0xC6B`, `0x3F2`) only on explicit world-ready transition
   matching `CLoginFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` (`0x4AC62B`) semantics.

Practical endpoint consequence from verified handlers:

- `WM_COMMAND 0x464` submit branch at `0x5BC81B..0x5BC846`:
  - checks startup host visibility via `CFlashHostDialog_IsWindowVisibleOrPendingActivation` (`0x5964C1`);
  - when visible, calls `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` (`0x4AEE6A`) at `0x5BC841`.
- inside `0x4AEE6A`, submit first resolves account/login endpoint via
  `CLoginFlashDlg_GetServerEndpointByServerRowAndRole` (`0x4AFE37`) with role `2`
  (`ServerIP` / `ServerPort`), writing host buffer size `0x80` + out-port before
  calling `CGameMain_AccountSetupAndSendLoginAuthPacket`.
- `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` (`0x4AEE6A`) calls
  `CGameMain_AccountSetupAndSendLoginAuthPacket` (`0x66D4C1`) then posts
  `Conquer_PostMainWindowMessage464(0x482, 0)` at `0x4AF108`.
- `0x482` clear handler (`0x5C6EC5`) clears startup connect/overlay flags:
  `this+0x179AAC = 0`, `this+0x179AB8 = 0`.
- `0x483` (`0x5CAA2D`) is the world-frame enable point;
- native submit path (`CMD_ENTERGAME`/`CMD_GAMESTART`) posts `0x480` directly from
  `CLoginFlashDlg_HandleFlashCommandString` (`0x4AA24D`) with no separate C++ pre-connect socket probe;
- own-UI startup defaults must target login/account service on submit, not game/world service as the
  initial endpoint.

### Pre-world status callback branch contract (`0x5DCEA3`) used by own-UI orchestration

`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) dispatches startup status/progress by a strict
flag branch:

- ready branch requires:
  - host visible/active;
  - `this+0x179AAC != 0` (startup submit/connecting flag);
  - `this+0x179AB8 != 0` (startup overlay/ready flag).
- on ready branch:
  - emits `PROGRESS` then `LOADING_TRACE` id `0x2BE8`;
  - clears `this+0x179AAC` and `this+0x179AB8`.
- fallback branch emits only `LOADING_TRACE` id `0x2BE7`.

Own-UI startup status sequencing therefore treats:

- submit/connecting as the gating point for any startup status dispatch;
- the `0x2BE8` pulse as one-time ready-branch status;
- steady `0x2BE7` updates as post-ready connecting status;
- `LOADING_TRACE`/`PROGRESS` as visual status payloads only, never world-enable triggers.

Additional command-handler anchors verified in this slice:

- `0x5C6EB0`:
  `CMyShellDlg_HandleStartupCommand0x480_SetStartupConnectFlag` (`this+0x179AAC = 1`).
- `0x5C6EC5`:
  `CMyShellDlg_HandleStartupCommand0x482_ClearStartupConnectAndOverlayFlags`.
- `0x5C6EE4`:
  `CMyShellDlg_HandleStartupCommand0x481_ApplyFlashHostShowStateAndDispatchVariable`.
- `0x5CAA2D`:
  `CMyShellDlg_HandleStartupCommand0x483_EnableWorldFrameGateAfterStartupLayoutChecks`.

Native timeout/error callback bridge for startup submit flow:

- `CLoginFlashDlg_HandleFlashCommandString` routes `CMD_TIMEOUT` (`0x4AA582`) and
  `CMD_ERROR_RET` (`0x4AA9E1`) through `Conquer_PostMainWindowMessage464(0x55, ...)`
  (`0x4AAA08 -> 0x4AA24D`).
- `CMyShellDlg_DispatchCommandCode` case `0x55` (`0x5B2A64`) clears
  `g_startupMovieFacebookVariantEnabled` and executes startup error-recovery branch work.

## Reconstruction policy for legacy Flash surfaces (not a native fact)

The verified Flash/ActiveX paths in this note remain the historical evidence record for the 5517
client. The modern cross-platform reconstruction does not reproduce, embed, or depend on a Flash
runtime by default. It implements native managed UI/rendering equivalents while preserving the
observable contract recovered from the original surface:

- visual and interaction behavior;
- state variables, commands, callbacks, and navigation;
- asset, animation, audio, and timing behavior;
- server selection, authentication, character creation, and other network-facing effects.

Reverse Flash-hosted internals only when a concrete reconstruction slice needs them, and only to the
depth required to establish that contract. The complete original Flash footprint is not asserted as
closed. A Flash-compatibility approach may be reconsidered only after a bounded inventory proves
that broad indispensable logic cannot be reproduced faithfully and more economically in managed
code. Names such as `CLoginFlashDlg` and `FlashHost` below describe the original binary and do not
imply a managed-runtime dependency.

## Verified pre-world startup/login visual+audio host path (world gate off)

Before world gate enable, launch visuals/audio are driven by startup Flash host flow (`start.dat`), not by `CMyShellDlg_RunFrameTick` world-map render stages.

### Startup Flash payload and host init

`CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`) performs:

1. select payload by platform flag:
   - `%s/data/main/start.dat` or `%s/data/main/start-facebook.dat` (`0x4AB674..0x4AB68E`)
2. load payload via `CFlashControl_SetMoviePath(arg1+0xF8, path)` (`0x4AB6B9`)
   - payload content includes startup submovie references (`data/main/flash/*.swf`) that are
     consumed by the Flash runtime (asset decode verified from `start.dat`/`start-facebook.dat`).
   - `CFlashControl_SetMoviePath` (`0x5EA89A`) is an MFC `CWnd::InvokeHelper` dispatch
     (DISPID `0x66`, VTS_BSTR; signature data
     `CFlashControl_InvokeHelperSignature_SetMoviePath_Bstr` at `0x93907C`), confirming native
     host path is ActiveX boundary invocation, not
     C++ SWF tag interpretation.
3. send host path command:
   - `CLoginFlashDlg_SetFlashVariableAndDispatch(arg1, "PATH", arg1+0x1A4)` (`0x4AB6BE..0x4AB6C7`)
4. read `ini/GameSetup.Ini` `[FlashMusic] Enable`:
   - key/value source strings at `0x4AB6F3..0x4AB74B`
   - fetch via `IniReadIntWithFallback(...)` (`0x4AB777`)
5. emit startup flash command `"SELECTBGMUSIC"` with bool payload (`0x4AB7AA..0x4AB7BE`)

Startup timer and thread wiring in same login host:
- `CLoginFlashDlg_StartFlashLoopTimer` (`0x4AC5FA`) call order is:
  1. `CLoginFlashCallbackState_InvokeProviderMethod8IfPresent(CLoginFlashDlg_GetSingletonPtr())` at `0x4AC5FD..0x4AC604`
  2. `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` at `0x4AC60B`
  3. `SetTimer(this+0x20, id=1, 0x14ms, null)` at `0x4AC610..0x4AC619`
- `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` starts `AfxBeginThread(CLoginFlashDlg_LoadProgressThreadProc, arg1)` when `arg1+0x61D == 0`.
- timer callback path is `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` (`0x4B04CE`) ->
  `CLoginFlashDlg_TickFlashHostStateAndInputBridge` (`0x4AD9A9`), establishing a verified
  20ms host-update cadence for startup Flash-bound state.
  - body at `0x4B04CE` is exactly:
    1. `call CLoginFlashDlg_TickFlashHostStateAndInputBridge` (`0x4B04D1`)
    2. `call CWnd::Default` (`0x4B04D8`)
    3. `retn 0x4` (`0x4B04DE`)
- no native C++ startup SWF blit exists on this timer path; frame rendering remains in the Flash host.
- replacement implication for managed non-Flash runtime: startup SWF clipping semantics must be
  honored in managed composition (notably `PlaceObject2`/`PlaceObject3` `HasClipDepth` mask
  scopes), because native behavior is delegated to Flash host rendering rather than custom C++ draw code.
- replacement implication for managed non-Flash runtime: per-layer alpha compositing must be
  preserved when presenting startup SWF surfaces; transparent pixels from startup layers must not
  overwrite already-rendered lower layers with opaque black.
- replacement implication for managed non-Flash runtime: keep startup-host updates on 20ms timer
  cadence even though outer app idle frame gate is 25ms (`ConquerApp_OnIdle` at `0x5AB533`), i.e.
  timer-bound startup ticks must not be collapsed to raw idle-frame frequency.
- replacement implication for managed non-Flash runtime: because native host delegates movie control
  to Flash runtime (`SetMoviePath`/`SetVariable`/`GetVariable` ActiveX boundary), startup
  `loadMovie` target clips must follow replacement semantics in managed rendering (latest movie per
  target clip at the current frame, not cumulative historical layer stacking in one slot).
- replacement implication for managed non-Flash runtime: startup overlay passes must preserve target
  clip ownership (startup-owned `loginFlashMC`/`logoMC` vs selection-owned `sr`/`ss`) so the same
  slot is not composited twice in one frame.
- `CFlashControl_SetVariable` (`0x5EA8EB`) likewise dispatches through
  `CWnd::InvokeHelper` (DISPID `0x97`, VTS_BSTR/VTS_BSTR; signature data
  `CFlashControl_InvokeHelperSignature_SetVariable_BstrBstr` at `0x9390DC`), with no native SWF
  tag-level parsing.
- `CFlashControl_GetVariableAsCString` (`0x5EA90F`) likewise dispatches through
  `CWnd::InvokeHelper` (DISPID `0x98`, VTS_BSTR return path; signature data
  `CFlashControl_InvokeHelperSignature_GetVariableAsCString_OutBstr` at `0x9390E0`), confirming
  variable reads are the same ActiveX host boundary and not native SWF-tag processing.

Startup movie variant flag source/reset contract (verified):

- `ConquerApp_ParseLaunchArgumentsAndSetStartupMovieVariantFlag` (`0x5AAF10`) parses launch tokens
  with `sscanf(lpCmdLine, "%s %s %s %s %s", ...)` and sets
  `g_startupMovieFacebookVariantEnabled` (`0x96AB34`) to `1` only when parsed-token count is `5`
  (equivalently, at least five whitespace-delimited launch tokens).
- `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` (`0x4AB5C5`) branches on
  `g_startupMovieFacebookVariantEnabled`:
  - `0`: `%s/data/main/start.dat`
  - non-zero: `%s/data/main/start-facebook.dat`
- `CMyShellDlg_DispatchCommandCode` (`0x5B29E7`) case `0x55` resets
  `g_startupMovieFacebookVariantEnabled = 0` at `0x5B2A6B`.

Startup server-list producer chain (`REGION`/`SERVER`) in the same host:

1. `CLoginFlashDlg_PrepareServerRootAndSelectionFromIni` (`0x4AAA49`) seeds:
   - `this+0x3FC` from `ini/oem.ini [Oem] id`;
   - `this+0x400` as `.\\Server` or `.\\Server%d`;
   - `this+0x190` / `this+0x194` group/server selection from
     `ini/GameSetup.Ini` with fallback `ini\\DefaultGameSetup.ini`.
   - missing key default for these reads is `-1` (`0x4AB19E`, `0x4AB277`); values are not clamped
     before `CURWORLD` / `CURSERVER` dispatch.
   - native unset sentinel is `-1`; zero is a valid persisted selection value on this path.
2. `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` calls
   `CLoginFlashDlg_BuildAndPushServerListToFlash` at `0x4ABF91` with arg `0`.
3. `CLoginFlashDlg_BuildAndPushServerListToFlash` (`0x4AD12F`) reads root from `this+0x400`
   (`0x4AD152`) and dispatches:
   - `REGION` at `0x4AD442`
   - `SERVER` at `0x4AD93E`
   - header format contract (native `_snprintf` callsites):
     - `REGION`: `%d#` at `0x4AD25B` (`dword ptr [ebp-0x1c]`, declared region-group count);
     - `SERVER`: `%d#%d#` at `0x4AD54B`:
       - first `%d` is the producer loop counter (`dword ptr [ebp-0x40]`) starting at `1` and
         incremented per emitted group segment (`0x4AD943`);
       - second `%d` is declared server count for that group segment (`dword ptr [ebp-0x4C]`).
   - therefore, startup `SERVER` payload group markers are producer-order indices (1..N), not XML row `id`.
   - `FlashIcon` producer contract is opaque string pass-through:
     - group append path: `GetAttribute("FlashIcon")` at `0x4AD3D3`, null check at `0x4AD3FD`,
       append at `0x4AD423`;
     - server append path: `GetAttribute("FlashIcon")` at `0x4AD6EA`, null check at `0x4AD717`,
       append at `0x4AD739`;
     - no `.bmp` / `.swf` extension gate exists in this native producer.
4. Refresh path:
   `CLoginFlashDlg_TickFlashHostStateAndInputBridge` invokes
   `CLoginFlashDlg_BuildAndPushServerListToFlash` at `0x4AD9D7` when
   `this+0x61D != 0 && this+0x61C == 0`.

### Per-tick startup draw callback boundary (world gate still off)

The startup visual host callback is driven from `CMyShellDlg_TickMapRoleAndEffectPipeline` (`0x5AFD4C`)
before world-map rendering is enabled:

| Site | Instruction | Verified behavior |
|---:|---|---|
| `0x5AFE9C` | `push esi` / `call CLoginFlashDlg_GetSingletonPtr` | obtains startup/login host singleton for current frame |
| `0x5AFEA4` | `call CMyShellDlg_SetFrameTickContext` | writes current shell pointer to login host callback context |
| `0x5AFEA9` | `call dword [GameDataSetQuery]` | queries global frame-callback dispatcher object |
| `0x5AFEB3` | `call dword [edx+0x0C]` | executes per-frame callback dispatch after context write |

`CMyShellDlg_SetFrameTickContext` (`0x5789A2`) contract:

- reads callback object pointer from `arg1+0x4`
- when non-null, invokes callback vtable `+0x10` with `arg2` (the `CMyShellDlg*`)

Decompile evidence (`0x5789A7..0x5789B6`):

- `ecx = *(arg1 + 4)`
- `(*(*ecx + 0x10))(arg2)`

This is the concrete non-world startup frame hook boundary we mirror in managed runtime:

- startup presenter state is updated per frame from scene tick while world frame gate is `0`
- callback execution happens under the same frame-order point (context set, then callback dispatch).
  - replacement visual layering (managed, non-Flash): primary startup movie timeline (`start.dat`),
  then startup submovie overlays (manifest order), then selected group/server `FlashIcon` SWFs.
  - startup submovie anchor contract (verified from clean `start.dat` root timeline + action script tokens):
    - `loginFlash.swf` / `loginFlashFaceBook.swf` -> target clip name `loginFlashMC`
    - `logo.swf` -> target clip name `logoMC`
    - region visual clip (`defaultR.swf` / `unopenedR.swf` placeholder chain) -> target clip name `sr`
    - server visual clip (`defaultS.swf` / `unopenedS.swf` placeholder chain) -> target clip name `ss`
  - root `PlaceObject2`/`PlaceObject3` anchor translations in `start.dat` stage space:
    - `loginFlashMC`: `(0, 0)`
    - `logoMC`: `(0, 0)`
    - `sr`: `(150, 381)`
    - `ss`: `(685, 373)`
    - extracted matrix terms include non-unit scale on `sr` (`M00≈0.9803`, `M11≈0.9801`).
  - managed non-Flash renderer maps referenced startup SWFs and selected region/server SWFs to these
    named stage anchors instead of viewport-centered placement, and applies anchor matrix scale terms
    when sizing overlay surfaces.
  - startup submovie activation-time contract:
    - native boundary is timer-driven Flash host tick (`SetTimer(1,0x14)` -> `0x4B04CE` -> `0x4AD9A9`);
    - referenced startup SWFs become visible when Flash timeline reaches the root-frame that executes
      their `loadMovie(...)` action;
    - managed extraction now parses AVM1 action bytecode records (not raw blob token scans):
      `ActionConstantPool` + `ActionPush` + `ActionStoreRegister` + `ActionGetVariable` +
      `ActionSetVariable` + `ActionDefineLocal` + `ActionDefineLocal2` + `ActionGetMember` +
      `ActionSetMember` + `ActionCallFunction`/`ActionCallMethod` with stack-argument decoding for
      `loadMovie` callsites;
    - decode preserves symbolic identifier expressions for unresolved locals/member chains
      (`ActionDefineLocal2` + `ActionGetVariable`) so object-indirect method targets remain
      recoverable at `ActionCallMethod` boundaries (for example `self.son -> ss1`);
    - decode preserves symbolic register identities (`reg[N]`) when register value is unresolved,
      so local alias setup (`DefineLocal`) can continue to resolve member-key chains;
    - member-name fallback is applied when object alias is unresolved (`*.tagBmp`, `*.son`) so
      branch-local `SetMember` writes can still supply later `loadMovie` argument values;
    - when a `loadMovie` call target is `.son` and subsequent pushes emit slot-like `_name`
      literals (`ss1` / `sr1`), that deferred slot literal is bound to the same callsite target.
    - SWF tag decode also traverses nested `DefineSprite` timeline streams for additional startup
      action blocks;
    - action parse traverses nested AVM1 function bodies (`ActionDefineFunction`,
      `ActionDefineFunction2`) to recover `loadMovie(path,targetClip)` invocations emitted inside
      startup script helper functions;
    - managed non-Flash replacement gates each referenced startup SWF by earliest extracted
      `loadMovie` frame index from startup movie script tags (`DoAction` / `DoInitAction`), using
      1-based SWF frame numbering (`frame=1` before first `ShowFrame`).
    - when primary startup poster decode is temporarily `1/1` while startup manifest indicates
      `parsedFrames > 1`, activation uses manifest-frame timing on the startup movie clock so
      reference/slot gating does not freeze at frame 1 during async full-timeline upgrade.
  - selected `REGION`/`SERVER` visual overlays are slot-gated by startup movie load phase:
      - region slot `sr` activation uses decoded `targetClip=sr` `loadMovie` events only;
      - server slot `ss` activation uses decoded `targetClip=ss` `loadMovie` events only;
      - indexed aliases (`sr1..srN`, `ss1..ssN`) are treated as slot-target matches by prefix;
      - before the corresponding slot activation frame is reached, managed runtime suppresses
        selected group/server overlay draw for that slot.
      - no static filename fallback (`defaultR/defaultS/unopened*`) is used for slot activation.
      - when no decoded slot target clip event exists for a slot, activation remains unresolved and
        managed runtime keeps that slot ungated (no synthetic suppression window injected).
  - startup Flash host viewport contract (verified):
    - `CLoginFlashDlg_OnInitDialog` (`0x4B0604`) calls
      `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport` (`0x4AEC64`) at `0x4B0690`;
    - `0x4AEC64` queries shell viewport rect via
      `GetWindowRect(*(data_95807C + 0x60), &rect)`, then calls `CWnd::MoveWindow` for:
      - login dialog window (`this`) to `(0,0,width,height)`;
      - embedded Flash control (`this+0xF8`) to the same `(0,0,width,height)`.
  - startup Flash-control COM wrapper boundary (verified from call wrappers):
    - `CFlashControl_SetMoviePath` (`0x5EA89A`) -> `InvokeHelper(DISPID=0x66, PROPERTYPUT)`;
    - `CFlashControl_SetVariable` (`0x5EA8EB`) -> `InvokeHelper(DISPID=0x97, METHOD)`;
    - `CFlashControl_GetVariableAsCString` (`0x5EA90F`) -> `InvokeHelper(DISPID=0x98, METHOD)`;
    - `CFlashControl_StopActiveMoviePlayback` (`0x5EA8B7`) -> `InvokeHelper(DISPID=0x7E, METHOD)`;
    - `CFlashControl_GetFlashPlayerVersionCode` (`0x5EA8CA`) -> `InvokeHelper(DISPID=0x84, METHOD, VT_I4)`.
  - managed non-Flash stage scaling contract:
    - render primary startup stage into full viewport control rect with aspect-preserving fit
      (Flash host `showAll` equivalent) instead of fixed 1:1 centered pixels;
    - apply the same stage scale to startup referenced overlays and selected `sr`/`ss` overlays
      so anchor coordinates remain in startup stage space.
  - startup asset-root contract (verified producer roots):
    - startup movie absolute path is built from `this+0x1A4` + `"/data/main/start.dat"` or
      `"/data/main/start-facebook.dat"` at `0x4AB68E`;
    - `PATH` Flash variable is dispatched from `this+0x1A4` at `0x4AB6C7`;
    - server table producer root is stored at `this+0x400` by
      `CLoginFlashDlg_PrepareServerRootAndSelectionFromIni` (`0x4AAA49`) as `.\\Server` / `.\\Server%d`;
    - managed replacement must resolve startup referenced SWFs and `REGION`/`SERVER` `FlashIcon` values
      as client-root-relative paths only (reject rooted/out-of-root traversal values).
  - timeline frame synthesis decodes SWF stage `RECT` bounds and `PlaceObject*` matrices for
    stage-space placement, then composites display-list layers by depth.
  - for nested/local timelines without explicit stage dimensions (`DefineSprite`/button-local),
    compositor canvas bounds are derived from transformed layer extents (with canvas-origin offset),
    preventing translation-clipped child layers.
  - `DefineButton2` symbols are resolved as deterministic startup-state display lists
    (state-up preferred when available) so button-hosted assets participate in initial composition.
    Button-record filter lists are parsed/skipped for startup decode scope (no hard reject path).
  - shape-to-bitmap character mapping in this stage includes `DefineShape`/`DefineShape2`/`DefineShape3`
    bitmap fill styles (`0x40..0x43`) when resolving placed symbols.
  - managed shape contract for bitmap-fill symbols:
    - non-Flash timeline decode must consume `SHAPEWITHSTYLE` records (style-change + edge records)
      and rasterize resolved bitmap-fill areas in shape-local coordinates;
    - `StateNewStyles` branches in shape records are decoded (appended fill/line style arrays +
      refreshed `NumFillBits`/`NumLineBits`) rather than falling back to whole-bitmap substitution;
    - fill sampling must apply the style bitmap matrix (invert-to-sample model), so atlas-backed
      UI parts are clipped/scaled to shape geometry instead of drawing the entire source bitmap;
    - non-zero shape bounds minima are carried as local placement offsets for the resolved symbol
      layer (`DefineShape*` bounds origin -> composed layer transform), preventing origin-collapse
      shifts when shape bounds do not start at `(0,0)`;
    - when a shape record uses unsupported edge/style features, managed runtime may fall back to
      legacy shape->bitmap substitution for that specific symbol only (no synthetic global remap).
  - per-layer alpha from `PlaceObject2`/`PlaceObject3` `CXFORMWITHALPHA` (`mult` + `add`) is
    applied in the non-Flash compositor.
  - SWF timeline decode is scheduled out-of-band from the frame callback path; per-frame host
    callback (`0x4B04CE -> 0x4AD9A9`) remains non-blocking and continues drawing fallback startup
    surfaces while decode is pending.
  - startup movie manifest parse (`start.dat` tag pass for referenced SWFs/audio/script hooks) is
    likewise non-blocking on the frame path: manifest warm-up is queued at movie-path handoff and
    first frame ticks poll a shared cache until parse completion.
  - decode warm-up is keyed from startup movie handoff (`SetMoviePath` contract at `0x4AB6B9`) and
    shared by the pre-world visual stage so first presentation frames are not blocked by decode.
  - pre-loop init hook warm-up now includes selected `REGION`/`SERVER` SWF icon resources resolved
    from the produced payload strings and current `CURWORLD`/`CURSERVER` seed so selection overlays
    can render without first-use decode stalls.
  - managed SWF timeline decode uses a two-stage cache contract:
    1. prime decode builds a first-frame timeline (`frameCount=1`) for immediate visible startup
       surface;
    2. full decode upgrades the same cache entry asynchronously to the full loop timeline.
  - fallback draw contract in managed pre-world stage: if no startup SWF layer resolves on a tick
    (primary, referenced, selected group, selected server), the stage draws verified
    `DlgLogo/BgFormat` bitmap for that tick rather than presenting a black frame.

### Post-logo callback target chain (verified concrete target after context write)

The callback object used by `CMyShellDlg_SetFrameTickContext` resolves to
`CMyShellDlg_RunPreWorldFlashHostFrameCallbacksIfNonNull` (`0x5780EC`), which calls
`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) when shell context is non-null.

`CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) behavior:

| Site | Instruction | Verified behavior |
|---:|---|---|
| `0x5DCEB5` | `call CFlashHostDialog_IsWindowVisibleOrPendingActivation` (`arg1+0x820`) | checks login Flash host window active/visible |
| `0x5DCEDF` | `call CLoginFlashDlg_SetProgressVariable(0x93883C)` | dispatches `PROGRESS` variable on login host (payload `"80"`) |
| `0x5DCF02` | `call CLoginFlashDlg_SetFlashVariableAndDispatch(arg1+0x820, "LOADING_TRACE", str)` | pushes loading trace string to login host |
| `0x5DCF21` | `call CFlashHostDialog_IsWindowVisibleOrPendingActivation` (`arg1+0xE40`) | fallback checks role-create Flash host window |
| `0x5DCF4F` | `call CRoleCreateFlashDlg_SetProgressVariable(0x93883C)` | dispatches `PROGRESS` variable on role-create host (payload `"80"`) |
| `0x5DCF7D` | `call CRoleCreateFlashDlg_SetFlashVariableAndDispatch(arg1+0xE40, "LOADING_TRACE", str)` | pushes loading trace string to role-create host |

Loading-trace string id branch in the same function:

- uses string id `0x2BE7` when `(this+0x179AAC != 1 || this+0x179AB8 == 0)`
- uses string id `0x2BE8` when `(this+0x179AAC == 1 && this+0x179AB8 != 0)`, then clears
  `this+0x179AAC = 0` and `this+0x179AB8 = 0`.

### Login-host timer tick bridge (verified)

`CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` (`0x4B04CE`) is the timer-path callback body:

- `0x4B04D1`: calls `CLoginFlashDlg_TickFlashHostStateAndInputBridge(this)`
- `0x4B04D8`: falls through to `CWnd::Default(this)`

`CLoginFlashDlg_SetProgressVariable` (`0x4B04B6`) is the fixed helper used in the callback path:

- if payload is non-null, dispatches `("PROGRESS", payload)` through
  `CLoginFlashDlg_SetFlashVariableAndDispatch`.

## Verified startup logo dialog path (pre-world visual before Flash host takeover)

> Re-verified end-to-end against `Conquer.exe` (MD5 `d4a47de8bec942d23043dc3051ba9417`) in
> Binary Ninja on 2026-09-02, including the `RT_DIALOG` resource bytes. Statements below that
> are not backed by an address are marked **UNVERIFIED**.

### Window topology (this was previously documented incorrectly)

`CMyShellDlg` is **not** the top-level window. There are two windows:

| Object | Window | Evidence |
|---|---|---|
| outer `CMyWnd` (`data_95807C`, `operator new(0x179B40)` at `0x5AB2C4`) | class registered by `AfxRegisterWndClass(0, IDC_ARROW, NULL, NULL)`, window name `"MyWnd"`, style `WS_POPUP` (`0x80000000`), ex-style `0`, rect `(0,0,W,H)`, **`pParentWnd = NULL`** | `sub_40205F` -> `CWnd::CreateEx` at `0x4020B1`; called at `0x5AB33B` |
| inner `CMyShellDlg` at outer `+0x40` | `CDialog` with `IDD = 0x66`, created as a **child** of `MyWnd` | `CMyWnd::OnCreate` (`0x4020BC`): `lea edi,[esi+0x40]` / `push esi` / `push 0x66` / `call CDialog::Create` at `0x4020CF` |

`CMyShellDlg_ConstructAndInitializeMembers` (`0x5ADAB7`) confirms the template: `CDialog::CDialog(this, 0x66, parent)` at `0x5ADAD1`.

`RT_DIALOG 0x66` (RVA `0x578...`, lang 2052) is a **`DLGTEMPLATEEX`**:
`style = 0x50000040` = `WS_CHILD | WS_VISIBLE | DS_SETFONT`, `exStyle = 0x00040000` (`WS_EX_APPWINDOW`),
`cDlgItems = 5`, `x=0 y=0 cx=538 cy=369` (dialog units), font `9 pt` `宋体` weight `0` italic `0` charset `1`.

`CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate` (`0x5AE8D8`) is the body of
**`CMyShellDlg::OnInitDialog`**. Proof: `0x5AE68A` (the obfuscated entry stub for this body) occupies
vtable slot `+0xC4` of the `CMyShellDlg` vtable `0x868810` (`0x8688D4`), which is the same slot that
holds `CStartupLogoDialog_OnInitDialogLoadLogoBrush` (`0x4B08B9`) in the startup-logo dialog vtable
`0x855270` (`0x855334`). It also calls `CDialog::OnInitDialog(this)` at `0x5AE91B` and uses
`CDialog::EndDialog(this, 0)` on its failure paths.

**Therefore the whole logo lifecycle runs inside `CreateEx` -> `WM_CREATE` -> `CMyWnd::OnCreate` ->
`CDialog::Create(0x66)` -> `WM_INITDIALOG`, i.e. strictly before `CWnd::ShowWindow(data_95807C, SW_SHOW)`
at `0x5AB348`.** `MyWnd` has no `WS_VISIBLE` in its `CreateEx` style, so the main window is **hidden**
for the entire time the logo is on screen. The `IDD 0x66` child dialog does carry `WS_VISIBLE`, but a
child of a hidden parent is not on screen.

### Exact lifecycle ordering

| # | Site | Instruction | Verified behavior |
|---:|---:|---|---|
| 1 | `0x5AE8F6` | `call CStartupLogoDialog_ctor` | stack-local object at `[ebp-0x94]`; `CDialog::CDialog(this, 0x111, NULL)` at `0x4B087E`, vtable `0x855270`, `this+0x60 = this+0x64 = 0` |
| 2 | `0x5AE910` | `CDialog::Create(&logoDlg, 0x111, pShellDlg)` | creates the logo window; owner = the `IDD 0x66` shell dialog. `WM_INITDIALOG` -> `CStartupLogoDialog_OnInitDialogLoadLogoBrush` (`0x4B08B9`) runs here — **the bitmap and brush are built before the window is ever shown** |
| 3 | `0x5AE91B` | `CDialog::OnInitDialog(pShellDlg)` | base-class init of the shell dialog |
| 4 | `0x5AE92E`, `0x5AE941` | `CWnd::EnableWindow(this+0x179834/0x1798D4, FALSE)` | — |
| 5 | `0x5AE97C`, `0x5AE9B5` | `SendMessageA(shellHwnd, WM_SETICON(0x80), 1/0, this+0x179AA0)` | big then small icon |
| 6 | `0x5AEA71` | `ini/GameSetup.Ini` `[ScreenMode] ScreenModeRecord`, default `-1` | screen-mode record |
| 7 | `0x5AEB11` | `EnumDisplaySettingsA(NULL, ENUM_CURRENT_SETTINGS, this+0x179710)` | — |
| 8 | `0x5AEB30`/`0x5AEB77`/`0x5AEBBB`/`0x5AEBD9` | `CMyShellDlg_ApplyScreenMode` | mode 1/2/3/0 |
| 9 | **`0x5AEBE6`** | **`CWnd::ShowWindow(&logoDlg, SW_SHOW)`** | **logo becomes visible** |
| 10 | **`0x5AEBF3`** | **`CWnd::CenterWindow(&logoDlg, NULL)`** | centered *after* being shown; `pAlternateOwner = NULL` and the logo is not `WS_CHILD`, so MFC centers it on its **owner** (the shell dialog) |
| 11 | `0x5AEC8C` | `CWnd::MoveWindow(pShellDlg, 0, 0, W, H, TRUE)` | shell dialog sized to the screen mode |
| 12 | `0x5AECDE` | `CWnd::SetWindowTextA(GetParent(shellHwnd), title)` | caption goes on `MyWnd` |
| 13 | `0x5AEF49` | `CGameMain_InitializeGraphicsAndGameFont(shellHwnd)` | `CMyBitmap::Init3DEx` + `GameFontCreate` (`0x66DC7F`); on failure -> `EndDialog`, dxdiag prompt, `PostQuitMessage(0x12)` (`0x5AEF57`..`0x5AEFB2`) |
| 14 | `0x5AF034` | `DXSoundinit` | on failure -> message box only, init continues |
| 15 | `0x5AF09D`, `0x5AF0B9`, `0x5AF0D5`, `0x5AF103` | `CDialog::Create(..., 0xD7 / 0x1AB / 0xC3 / 0x1BC, pShellDlg)` | child dialogs |
| 16 | `0x5AF1A1` | `RedrawWindow(this+0x168C78, ... RDW_INVALIDATE\|RDW_ERASE\|RDW_UPDATENOW)` | — |
| 17 | **`0x5AF1B5`** | **`CFlashHostDialog_ApplyShowHideStateAndLifecycleCallbacks(this+0x820, SW_SHOW)`** | login/Flash host is **created (virtual `+0xD8` when `m_hWnd == 0`, `0x596FA2`) and shown (`0x596FE4`)** while the logo is still visible |
| 18 | `0x5AF2B4` | `CreateFontA(...)` | chat font |
| 19 | `0x5AF441`..`0x5AF477` | `sub_5ACA8B("\\\\.\\SICE" / "SIWDEBUG" / "NTICE" / "SIWVID")` | SoftICE probes; any hit -> `EndDialog(0)` and return `0` at `0x5AF481` |
| 20 | `0x5AF4AF` | `IsDebuggerPresent()` | non-zero -> `EndDialog(0)`, return `0` at `0x5AF4B9` |
| 21 | **`0x5AF4E7`** | **`CWnd::ShowWindow(&logoDlg, SW_HIDE)`** | logo hidden |
| 22 | **`0x5AF4F2`** | **`CWnd::DestroyWindow(&logoDlg)`** | logo window destroyed -> `WM_DESTROY` -> `CStartupLogoDialog_OnDestroyReleaseLogoResources` (`0x4B0AEB`) frees brush then bitmap |
| 23 | `0x5AF500` | `GetParent(shellHwnd)` | if `NULL`, the function returns `0` at `0x5AF519`/`0x5AF546` — **after** the logo is already gone |
| 24 | `0x5AF523` | `CWnd::CenterWindow(pMyWnd, NULL)` | frame centered |
| 25 | `0x5AF59B` | `CWnd::ShowWindow(this+0x1669B0, SW_SHOW)` | startup control bar |
| 26 | `0x5AF705` | `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport(this+0x820)` | login host laid out to the shell viewport |
| 27 | `0x5AF721` | `this+0x179AB9 = 0` | world-frame gate restored disabled |
| 28 | `0x5AF781` | `CreateThread(NULL, 0, sub_5AF7B5, NULL, 0, NULL)` | — |
| 29 | `0x5AF497` / `0x5AF53B` / `0x5AF79B` (and every early-return) | `CStartupLogoDialog_dtor` | C++ scope exit; deletes brush/bitmap again (`0x4B0AD5`/`0x4B0ADF`) — `OnDestroy` does not null the handles, so this is a benign double `DeleteObject` |
| 30 | `conquer.exe 0x5AB348` | `CWnd::ShowWindow(data_95807C, SW_SHOW)` | **main window becomes visible — only now, after `OnInitDialog` and `CreateEx` have returned** |

Answers to the ordering questions:

- The main shell window **exists** before the logo is created (the logo is created with it as owner)
  but is **not visible** at any point while the logo is on screen.
- The login/Flash host **exists and is `SW_SHOW`n at `0x5AF1B5`, before the logo is hidden at `0x5AF4E7`**.
  Because its ancestor chain is still hidden, it is shown-but-not-painted; the visible-on-screen
  handover is still logo -> (nothing) -> main window.
- The logo **overlaps the main window's lifetime**; it does **not** precede main-window construction.

### Duration: there is no minimum logo display time in native 5517

Verified by exhaustive scan, not by absence of observation:

- Across the whole `0x5AE8D8`..`0x5AF7B5` byte range there is **no** `call dword [...]` to any of
  `Sleep`, `SleepEx`, `WaitForSingleObject`, `MsgWaitForMultipleObjects`, `GetTickCount`,
  `timeGetTime`, `QueryPerformanceCounter`, `SetTimer`, or `KillTimer`. (Import thunks:
  `Sleep 0x8440E4`, `WaitForSingleObject 0x8441A8`, `QueryPerformanceCounter 0x844230`,
  `GetTickCount 0x844270`, `SetTimer 0x844A9C`, `KillTimer 0x844AA8`, `timeGetTime 0x844B80`.
  All 63 call sites in `.text` were enumerated; none lie in the range.)
- The constant `0x1F4` (500) does not appear as a word or dword anywhere in that range.
- The startup-logo dialog's message map (`0x855220`, from `CStartupLogoDialog_GetMessageMap` `0x4B08B3`)
  has exactly **two** entries and then a terminator: `WM_DESTROY (0x02) -> 0x4B0AEB` at `0x855228`, and
  `WM_CTLCOLOR (0x19) -> 0x4B0B11` at `0x855240`. **No `WM_TIMER`, no `WM_PAINT`, no `WM_ERASEBKGND`.**
  So the logo cannot self-gate on a timer either.
- The only `Sleep` in the neighbourhood is at `0x5AB54B` inside `ConquerApp_OnIdle`, which is the MFC
  idle handler and cannot run during `WM_INITDIALOG` (no message pump is entered between `0x5AEBE6`
  and `0x5AF4E7`).

**Conclusion:** the logo's visible duration is exactly the wall-clock cost of the synchronous
initialization block between `0x5AEBE6` and `0x5AF4E7` — Direct3D/`CMyBitmap::Init3DEx`, game font
creation, DirectSound init, four child-dialog creations, Flash-host creation, `CreateFontA`, and the
anti-debug probes. This is category (2) "logo simply remains visible while synchronous work runs",
**not** category (1) "explicit minimum duration". Any fixed minimum in a reimplementation is a
deliberate non-parity UX choice and must be labelled as such.

### Dialog resource `0x111`: the values are dialog units, not pixels

Resource bytes (RT_DIALOG id `0x111`, lang 2052, RVA `0x57B7C0`, 32 bytes):

```
40 08 00 80  00 00 00 00  00 00  00 00 00 00  fa 00  bc 00
00 00  00 00  00 00  0c 00  8b 5b 53 4f 00 00
```

Decoded as a **classic `DLGTEMPLATE`** (the first `WORD` is `0x0840`, not `1`, and the second is
`0x8000`, not `0xFFFF`, so this is *not* a `DLGTEMPLATEEX`):

| Field | Value |
|---|---|
| `style` | `0x80000840` = `WS_POPUP \| DS_CENTER (0x0800) \| DS_SETFONT (0x0040)` |
| `dwExtendedStyle` | `0x00000000` |
| `cdit` | `0` — **no controls at all** |
| `x`, `y` | `0`, `0` |
| `cx`, `cy` | `250`, `188` — **dialog template units (DLUs)** |
| menu / class / title | all absent (`0x0000`) |
| font (because `DS_SETFONT`) | point size `12`, typeface `U+5B8B U+4F53` = `宋体` (SimSun) |

Notes that matter for parity:

- **`DS_SHELLFONT` is not set.** `DS_SHELLFONT == DS_SETFONT | DS_FIXEDSYS == 0x48`; only `0x40` is
  present, and a classic `DLGTEMPLATE` cannot carry the weight/italic/charset fields that
  `DS_SHELLFONT` semantics require anyway.
- No `WS_VISIBLE`, no `WS_CAPTION`, no `WS_BORDER`, no `WS_DLGFRAME`, no `WS_THICKFRAME`,
  no `WS_SYSMENU`. It is a **borderless top-level popup**, so `AdjustWindowRectEx` adds nothing and
  the outer window rect equals the client rect.
- `DS_CENTER` means USER32 already centers the dialog on creation; the explicit
  `CWnd::CenterWindow(&logoDlg, NULL)` at `0x5AEBF3` re-centers it on the owner window afterwards.
- Nothing in `0x5AE8D8` ever calls `MoveWindow`/`SetWindowPos` on the logo dialog, so `250x188` DLU
  is the only geometry input.

**DLU -> pixel conversion.** USER32 derives the dialog base units from the `DS_SETFONT` font:
`px_x = cx * baseUnitX / 4`, `px_y = cy * baseUnitY / 8`, where `baseUnitX` is the font's average
character width and `baseUnitY` its `tmHeight`, measured after the font is realized at the device's
`LOGPIXELSY`. **This is a runtime property of the font actually selected on the user's machine and is
not statically determinable from the binary.**

Under the retail-era environment the client was built for — 96 DPI and SimSun present — SimSun at
12 pt realizes at `-MulDiv(12, 96, 72)` = 16 px em, giving `tmHeight = 16` and `tmAveCharWidth = 8`
for its half-width Latin cells. That yields:

- client/window size = `250 * 8 / 4` x `188 * 16 / 8` = **500 x 376 px**
- the retail assets `Data/Main/Logo1.bmp` / `Logo2.bmp` are **500 x 375, 24-bpp, uncompressed**
  (`BITMAPINFOHEADER`, `biCompression = BI_RGB`), i.e. the dialog is exactly the bitmap width and one
  row taller.

**Status: the `500 x 376` figure is inferred from documented SimSun metrics at 96 DPI, not proven by
the binary.** What *is* proven is that `250x188` are DLUs, that the conversion is font- and
DPI-dependent, and that the bitmap is 500x375. On a machine without SimSun, or at a non-96 DPI
setting, the native dialog would be a different pixel size — retail has no compensation for that.

**Do not describe `250x188` as pixels.** Rendering the logo into a 250x188 pixel surface halves it.

### `CStartupLogoDialog_OnInitDialogLoadLogoBrush` (`0x4B08B9`) — bitmap load contract

| Site | Instruction | Verified behavior |
|---|---|---|
| `0x4B08CE` | `CDialog::OnInitDialog(this)` | base init |
| `0x4B0928` | assign `"Data/Main/Logo%d.bmp"` (`0x92B9B4`) | **default** format, used when the INI lookup fails |
| `0x4B095E` | assign `"BgFormat"` (`0x92B9A8`) | key |
| `0x4B098A` | assign `"DlgLogo"` (`0x92B9A0`) | section |
| `0x4B09B6` | assign `"ini/info.ini"` (`0x924D08`) | file |
| `0x4B09E7` | `sub_66E514(out, file, section, key, default)` | ini read, see below |
| `0x4B0A06` | `_snprintf(buf, 0x103, "%s", value)` | copy resolved format into a 259-byte stack buffer |
| `0x4B0A4F` | `timeGetTime()` | variant source |
| `0x4B0A68` | `_snprintf(buf, 0x103, buf, (timeGetTime() & 1) + 1)` | **destination and format string are the same buffer**; variant is `1` or `2` |
| `0x4B0A88` | `LoadImageA(AfxGetModuleState()->m_hCurrentInstanceHandle, buf, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE)` | **`cx = 0`, `cy = 0` -> natural size; `LR_LOADFROMFILE` -> raw Win32 file I/O, path relative to the process CWD** |
| `0x4B0A8E` | `this+0x64 = hBitmap` | stored without a null check |
| `0x4B0A91`..`0x4B0A99` | `if (this+0x60) DeleteObject(this+0x60)` | old brush released |
| `0x4B0AA2` | `CreatePatternBrush(this+0x64)` | — |
| `0x4B0AAD` | `this+0x60 = hBrush` | — |
| `0x4B0AAB` | `return TRUE` | **always succeeds** |

INI resolution, `sub_66E514` (`0x66E514`, `retn 0x14`):

| Site | Behavior |
|---|---|
| `0x66E52D` | `sub_66E27D(&store, "ini/info.ini")` — resolve/parse the ini into the cached store |
| `0x66E577` -> `0x66E57D` | store is `NULL` (file missing/unparseable) -> `sub_403EEE(out, default)`, i.e. **out = `"Data/Main/Logo%d.bmp"`** |
| `0x66E55C` | store present -> `sub_76FA38(store, section, key, default)` = `IniStore_FindValueCaseInsensitive`; returns the found value only when it is non-`NULL` **and non-empty** (`0x76FA4C`), otherwise the default (`0x76FA4E`) |

Failure behavior — all non-fatal, verified:

- missing `ini/info.ini` -> default format
- missing `[DlgLogo]` or `BgFormat`, or an empty value -> default format
- `LoadImageA` fails (missing/unreadable BMP) -> `this+0x64 = NULL` -> `CreatePatternBrush(NULL)`
  returns `NULL` -> `this+0x60 = NULL`. `OnInitDialog` still returns `TRUE`, the dialog is still
  created, shown, and destroyed on the same schedule. **A missing logo BMP does not abort startup.**
- with a `NULL` brush, `CStartupLogoDialog_OnCtlColorReturnLogoBrush` returns `NULL` for
  `CTLCOLOR_DLG`, and `DefDlgProc` falls back to the system dialog background. The window is a
  blank rectangle, not a crash.

A malformed `BgFormat` (e.g. containing `%s`) is fed to `_snprintf` as a format string with a single
`int` argument. That is undefined behavior in native and is **UNVERIFIED** as to outcome; do not
model it as a defined contract.

### Presentation: pattern brush, no scaling

| Site | Instruction | Verified behavior |
|---|---|---|
| `0x855228` | msgmap entry `WM_DESTROY (0x02) -> 0x4B0AEB` | — |
| `0x855240` | msgmap entry `WM_CTLCOLOR (0x19) -> 0x4B0B11` | — |
| `0x4B0B1A` | `CDC::SetBkMode(pDC, TRANSPARENT)` | — |
| `0x4B0B24` | `if (nCtlColor != 4 /* CTLCOLOR_DLG */) return NULL` | — |
| `0x4B0B26` | `return this+0x60` | the pattern brush |

Because the dialog has **no controls** (`cdit = 0`) and no `WM_PAINT`/`WM_ERASEBKGND` handler,
`DefDlgProc` erases the client area with the brush returned from `WM_CTLCOLORDLG`. `CreatePatternBrush`
on Windows NT and later tiles the bitmap at its **natural** size from the brush origin, which defaults
to client `(0,0)`.

So the native presentation is: **the 500x375 bitmap painted 1:1, top-left anchored, tiled**. There is
**no stretch, no scale, no aspect fit, and no letterbox**. If the dialog client is 500x376 (see the DLU
section), the bottom 1-pixel row shows the tiled first row of the bitmap.

### Ownership: initialization-only, single instance

- `CStartupLogoDialog_ctor` (`0x4B0872`) has exactly one code xref: `0x5AE8F6` (plus the same site via
  the SEH-wrapper view of the same function). There is no second instantiation.
- `push 0x111` as a dialog id appears at only two sites: `0x4B0879` (the ctor's `CDialog::CDialog`) and
  `0x5AE905` (the `CDialog::Create`). Every other `0x111` in `.text` is `WM_COMMAND`.
- `"DlgLogo"` (`0x92B9A0`) and `"Data/Main/Logo%d.bmp"` (`0x92B9B4`) have xrefs from
  `CStartupLogoDialog_OnInitDialogLoadLogoBrush` only.
- The object is a **stack local** in `CMyShellDlg::OnInitDialog`; its C++ lifetime ends when that
  function returns.
- `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` (`0x5DCEA3`) dispatches host variables only
  (`PROGRESS`, `LOADING_TRACE`) and performs no `CStartupLogoDialog` work.

**Therefore there is exactly one lifecycle, and it is initialization-only.** The logo is not part of the
steady pre-world frame loop and is not a fallback surface for the login host. Any per-frame
startup-logo rendering, and any reuse of `DlgLogo/BgFormat` as a pre-world background, is a
**reimplementation-only construct** with no native counterpart.

### Flash usage in this path (reimplementation diverges deliberately)

The rewrite does not ship Flash. For the record, the native pieces this path touches:

- `this+0x820` is `CLoginFlashDlg`, an MFC dialog hosting the Shockwave Flash ActiveX control
  (CLSID `{D27CDB6E-AE6D-11CF-96B8-444553540000}`, GUID bytes at `0x855210`, wrapper
  `CWnd::CreateControl` at `0x4B084D` — note that function is mis-named
  `CStartupLogoDialog_CreateEmbeddedControl` in the current symbol set; it belongs to the Flash
  control wrapper class, not to `CStartupLogoDialog`).
- `CFlashHostDialog_ApplyShowHideStateAndLifecycleCallbacks` (`0x596F79`) is the show/hide driver;
  its debug strings name `F:\CQ2ClientRelease-42.0.1\MyShell\MyDialog.cpp`.
- **Divergence:** the reimplementation replaces the Flash host with its own login UI. The only part of
  step 17 that is parity-relevant is the *ordering* — the login surface is constructed and marked
  visible **before** the startup logo is torn down — not the ActiveX mechanics. Reproduce the
  ordering; do not reproduce the host.

### Flash command callback handshake for music option

`CLoginFlashDlg_HandleFlashCommandString` (`0x4AA0AE`) handles startup callback:

- command compare: `"CMD_SELECTBGMUSIC"` at `0x4AAA15..0x4AAA1E`
- persistent write:
  - `WritePrivateProfileStringA("FlashMusic","Enable",value,"ini/GameSetup.Ini")` at `0x4AAA32`
- command compare: `"CMD_CLOSE"` at `0x4AA69F`
- close dispatch:
  - calls `CLoginFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` at `0x4AA6A3`
  - this call path emits `Conquer_PostMainWindowMessage464(0x483,0)` at `0x4AC69C`

### Verified world-enable producer commands

Two close-command handlers post `0x483`, which reaches the decode above and enables world frame:

- `CLoginFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` (`0x4AC621`)
  - `Conquer_PostMainWindowMessage464(0x483, 0)` at `0x4AC69C`
- `CRoleCreateFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` (`0x51C2CF`)
  - `Conquer_PostMainWindowMessage464(0x483, 0)` at `0x51C301`

Both also post `0xC6B` and `0x3F2` in same sequence (`0x4AC6A7`, `0x4AC6C3`, `0x51C30C`, `0x51C327`).

### File-format evidence for startup payload

`10_work/assets/5517/data/main/start.dat` and `start-facebook.dat` are compressed SWF (`CWS`, version 6), matching the login-flash host path above.

Managed extractor contract for startup payload instrumentation:

- decode `CWS` to `FWS` payload;
- parse SWF timeline records deterministically (header + tag stream);
- emit typed manifest metadata for:
  - frame boundaries (`ShowFrame`);
  - placement operations (`PlaceObject*`);
  - audio tags (`DefineSound`, `StartSound`, `SoundStreamHead*`, `SoundStreamBlock`);
  - script token candidates from `DoAction` / `DoInitAction`;
- preserve embedded `data/main/flash/*.swf` reference extraction for compatibility diagnostics
  using case-insensitive prefix/extension matching (`data/main/flash/` + `.swf`) and slash
  normalization (`\` -> `/`) so mixed-case SWF action strings resolve consistently on
  case-sensitive hosts.

### BNinja renames applied in this startup-login slice (`Conquer.exe.bndb`)

| Address | Verified name |
|---:|---|
| `0x5BB79D` | `CMyShellDlg_WindowProc_DispatchMainWindowMessages` |
| `0x505EF9` | `CMyShellDlg_DoDataExchangeStartupControlBindings` |
| `0x4AA0AE` | `CLoginFlashDlg_HandleFlashCommandString` |
| `0x4AB5C5` | `CLoginFlashDlg_InitializeStartupFlashAndSelectBgMusic` |
| `0x4AC5FA` | `CLoginFlashDlg_StartFlashLoopTimer` |
| `0x4AC621` | `CLoginFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` |
| `0x4AC6C4` | `CLoginFlashDlg_SetFlashVariableAndDispatch` |
| `0x4AEC64` | `CLoginFlashDlg_ResizeDialogAndFlashControlToMainShellViewport` |
| `0x4B0604` | `CLoginFlashDlg_OnInitDialog` |
| `0x4B06A7` | `CLoginFlashDlg_PollInputAndCacheCapsState` |
| `0x4B05C0` | `CLoginFlashDlg_LoadProgressThreadProc` |
| `0x4B05A8` | `CLoginFlashDlg_RunLoadProgressStep` |
| `0x4B05B3` | `CLoginFlashDlg_SetLoadThreadRunningFlag` |
| `0x4B070E` | `CLoginFlashDlg_ReleaseMonitorAndAssistResources` |
| `0x4B07AC` | `CLoginFlashDlg_GetSingletonPtr` |
| `0x5789BC` | `CLoginFlashCallbackState_InvokeProviderMethod8IfPresent` |
| `0x4AEBF4` | `CLoginFlashDlg_SyncMonitorManagerAccounts` |
| `0x51C32E` | `CRoleCreateFlashDlg_HandleFlashCommandString` |
| `0x51C2CF` | `CRoleCreateFlashDlg_HandleCloseCommandAndPostWorldEntryMessages` |
| `0x4A9940` | `CMonitorCallback_OnEvent_CreateOrNotifyAssistDialog` |
| `0x5EA89A` | `CFlashControl_SetMoviePath` |
| `0x5EA8EB` | `CFlashControl_SetVariable` |
| `0x5EA90F` | `CFlashControl_GetVariableAsCString` |
| `0x66E4D9` | `IniReadIntWithFallback` |
| `0x66E467` | `IniReadIntFromResolvedStoreOrDefault` |
| `0x9560B0` | `g_loginFlashDlgSingleton` |
| `0x956200` | `g_assistDialogForMonitorEvents` |
| `0x956204` | `g_monitorEventCallback` |
| `0x956208` | `g_monitorManagerForLoginFlash` |

Within `CNetMsg__ProcessMsg` (`0x6DEBA5`) packet dispatch loop (verified):

| Site | Callee | Meaning |
|---:|---|---|
| `0x6DEC17` | `CNetMsg__GetSize` (`0x6DF3AD`) | read packet length from pending decoded frame buffer |
| `0x6DEC2C` | `CNetMsg__ProcessMsg_Dispatch` (`0x6DF3B5`) | allocate/parse concrete message object by type |
| `0x6DEC6B` | `msg->vtable[4](msg, 0)` | execute packet process handler |
| `0x6DED48` / `0x6DED5A` | object release path | release message object after processing |

## `CMyShellDlg_RunFrameTick` Pre-Map Front Overlay Draw Calls (verified)

In `CMyShellDlg_RunFrameTick` (`0x5DCFAA`), the pre-map overlay pass executes before world map tick/render:

| Caller site | Callee | Verified behavior |
|---:|---|---|
| `0x5DD02F` | `CMyShellDlg_DrawExChatTopBackgroundAndFlip` (`0x5DE04A`) | begins 3D, queries `ani/Control.ani:ExChat_TopBG`, draws top strip (`height=0x14`), refreshes ExChat panel resources, ends 3D, flips top strip |
| `0x5DD036` | `CMyShellDlg_DrawExChatJointPanelAndFlip` (`0x5DD71A`) | begins 3D, updates ExChat mode/layout state, draws joint panel background by mode, applies display-mode reflow, ends 3D, flips lower region |
| `0x5DD0CC` | `CGameMap_TickComponentsAndProcessScreenEffects` | world component tick stage starts only after both overlay calls |

### `CMyShellDlg_DrawExChatTopBackgroundAndFlip` argument contract (`0x5DE04A`)

Verified call and constants:

| Site | Evidence | Meaning |
|---:|---|---|
| `0x5DE098` | `GameDataSetQuery()->vfunc+0x10("ani/Control.ani","ExChat_TopBG",1,0x7530)` | animation resource lookup |
| `0x5DE0C6` | `resource->vfunc+0x0C(0,0,0,&rect,g_shellLayoutWidthPixels,0x14,0,0)` | draw frame 0 stretched to current shell width and fixed top height (`20 px`) |
| `0x5DE0CF` | `CExChatPanel_RefreshButtonResourcesAndNotifyMapProjection(arg1 + 0x168C58)` | refreshes ExChat panel buttons and map-projection notifications |
| `0x5DE0D4` / `0x5DE0F5` | `CMyBitmap::End3D` then `CMyBitmap::Flip` | completes and presents top-strip pass |

### `CDlgMain_RenderMainUiDialogAndStatusOverlay` Dialog4 main-UI panel contract (`0x4BC1F8`)

Verified `Dialog4` resource lookup:

| Site | Evidence | Meaning |
|---:|---|---|
| `0x4BC51C..0x4BC537` | `GameDataSetQuery()->vfunc+0x10("ani/Control.ani","Dialog4",1,0x7530)` | dialog panel resource lookup |
| `0x4BC545` | `cmp g_uiLayoutModeFlag, 0` | branch between screen-width right-anchored default (`==0`) and alternate left-anchored layout path |

Verified default branch (`g_uiLayoutModeFlag == 0`) `+0x0C` draw calls:

| Site | Draw call shape | Verified placement |
|---:|---|---|
| `0x4BC59E` | `resource->vfunc+0x0C(0, x0, y0, &rect, 0x100, 0x90, 0, 0)` | primary panel at `x0 = GetScreenWidth() + shellOffsetX - 0x100`, `y0 = shellOffsetY - 3`, source rect `(0,0x70,0x100,0x100)` |
| `0x4BC5E5` | `resource->vfunc+0x0C(0, x1, y1, &rect, 0x100, 0x36, 0, 0)` | lower strip start at `x1 = GetScreenWidth() + shellOffsetX - 0x200`, `y1 = shellOffsetY + 0x58`, source rect `(0,0,0x100,0x36)` |
| `0x4BC62D` | `resource->vfunc+0x0C(1, x2, y1, &rect, 0x100, 0x36, 0, 1)` | lower strip segment at `x2 = GetScreenWidth() + shellOffsetX - 0x300` (frame 1), source rect `(0,0,0x100,0x36)` |
| `0x4BC679` | `resource->vfunc+0x0C(1, x3, y1, &rect, 0x100, 0x36, 0, 1)` | lower strip segment at `x3 = GetScreenWidth() + shellOffsetX - 0x400` (frame 1), source rect `(0,0x40,0x100,0x76)` |

Managed reconstruction boundary for this slice:

- `ExChat_TopBG` remains owned by the pre-map front-overlay seam (`CMyShellDlg_DrawExChatTopBackgroundAndFlip`).
- `Dialog4` belongs to the post-map HUD/status pass because it is emitted by
  `CDlgMain_RenderMainUiDialogAndStatusOverlay`, which is reached from
  `CMyShellDlg_RenderHudAndProcessSound`.
- In the active `g_uiLayoutModeFlag == 0` path, the vertical placement is not top-anchored.
  The live 5517 draw calls consume shell offsets from `this+0xF0/+0xF4`; for the current
  fixed 1024x768 internal render mode, the managed port collapses that to the bottom-docked
  shell-dialog layout (`shellOffsetX = 0`, `shellOffsetY = screenHeight - 0xA3`), which yields
  `Dialog4` Y placements `602` and `693`. The surviving old-retail `DlgMain` source matches the
  same bottom-docked dialog rect height and is used only as corroboration for that collapse.
- The managed ANI draw contract now carries the native source-rect slice as first-class data.
  That is required for `Dialog4`: stretching the whole frame produces the incorrect top-right
  F-key strip and overwide bottom shell even when the destination coordinates are correct.
- `Progress45` is the main HUD background, not a dynamic stat bar. `CDlgMain_InitializeMainHudWidgets`
  sets the render gate at `shell+0x110` to `1` (`0x4BBF04`), and
  `CDlgMain_RenderMainUiDialogAndStatusOverlay` draws frame `0` from `ani/Control.ani`
  at `x = GetScreenWidth() + shellOffsetX - frameWidth`, `y = shellOffsetY`
  in the active `g_uiLayoutModeFlag == 0` path (`0x4BC3AB..0x4BC420`).

### `CDlgMain` main HUD widget layout contract (`0x4BB6B8`, `0x4BB869`)

Verified 5517 sources for the current managed subset:

- PE `RT_DIALOG` resource `0x82`, language `0x804`, is the `CDlgMain` main HUD dialog template.
  It is a standard dialog with rect `(0,0,400,70)` and 23 controls. The older retail
  `IDD_MAIN_DIALOG` source is only a corroborating hint; the 5517 PE resource is the coordinate source.
- `CDlgMain_BindMainHudWidgetControls` (`0x4BB6B8`) binds the live controls to `CDlgMain`
  member offsets. `CDlgMain_InitializeMainHudWidgets` (`0x4BB869`) then initializes those controls
  with the verified `ani/Control.ani` resource names.
- The managed path scales template X by `screenWidth / 400` and template Y by the verified
  shell height `0xA3 / 70`, then adds `shellOffsetY = screenHeight - 0xA3`. This matches the
  native bottom-shell scaling path used by `CMyButton_Init` / `CMyCheck_Init` and the `Dialog4`
  shell height already verified above.

Implemented button/check subset:

| Offset | Control ID | Init helper | Resource | Template rect |
|---:|---:|---|---|---|
| `0x13FA84` | `0x5DF` | `CMyButton_Init` | `Button40` | `(250,46,25,12)` |
| `0x13FEE4` | `0x402` | `CMyButton_Init` | `Button41` | `(300,46,25,12)` |
| `0x13FBC4` | `0x3EF` | `CMyButton_Init` | `Button42` | `(275,46,25,12)` |
| `0x13FC64` | `0x3F0` | `CMyButton_Init` | `Button43` | `(325,58,25,12)` |
| `0x13FD04` | `0x3F1` | `CMyButton_Init` | `Main3_MissionBtn` | `(250,58,25,12)` |
| `0x13FDA4` | `0x3F2` | `CMyButton_Init` | `Button45` | `(275,58,25,12)` |
| `0x13FE44` | `0x3F3` | `CMyButton_Init` | `Button46` | `(300,58,25,12)` |
| `0x13F9E4` | `0x3F5` | `CMyButton_Init` | `Button47` | `(325,46,25,12)` |
| `0x13C390` | `0x400` | `CMyButton_Init` | `Main3_OrganiseBtn` | `(350,46,25,12)` |
| `0x13FB24` | `0x3EE` | `CMyButton_Init` | `Button410` | `(350,58,25,12)` |
| `0x13F840` | `0x3F4` | `CMyCheck_Init` | `Check40` | `(7,5,11,11)` |
| `0x13F7B4` | `0x3F7` | `CMyCheck_Init` | `Check43` | `(0,16,11,11)` |
| `0x13F8CC` | `0x3FF` | `CMyCheck_Init` | `Check46` | `(29,5,11,11)` |
| `0x13F958` | `0x3F8` | `CMyCheck_Init` | `Button411` | `(18,12,11,11)` |

Implemented static progress background:

| Gate / site | Resource | Native draw |
|---:|---|---|
| `shell+0x110`, `0x4BC3AB..0x4BC420` | `Progress45` | frame `0`, right-anchored by frame width at `shellOffsetY` |

### `CMyButton` state, input, and activation contract

The first reusable in-world UI control contract is closed against the 5517 executable rather than
the startup replacement UI. The relevant class implementation is the native `CMyButton` in
`MyShell/MyButton.cpp`; its verified object size is `0xA0` bytes.

Verified field/state layout:

| Offset | Meaning | Native evidence |
|---:|---|---|
| `+0x40/+0x44` | final render X/Y | written as local position plus the parent render offset at `0x589FBC..0x589FCE` |
| `+0x48/+0x4C` | local X/Y | initialized from the child HWND rectangle relative to the parent at `0x58A254..0x58A268` |
| `+0x60/+0x64` | scaled child width/height | re-read from the child HWND after optional scaling at `0x58A30F..0x58A325` |
| `+0x68` | current visual frame | initialized to `0`; set by button messages and `CMyButton_SetCurrentFrame` |
| `+0x74` | `Control.ani` section string | written by `CMyButton_Init` / `CMyButton_SetAniSectionName` |
| `+0x80` | cursor tracking active | set on `WM_MOUSEMOVE`; cleared when the sampled cursor leaves |
| `+0x81` | force cursor polling | allows the cursor sampler to run without a preceding mouse-move message |
| `+0x82` | sampled cursor-inside flag | drives the optional tooltip branch |
| `+0x83` | hover-frame enable | opt-in flag; it is not enabled by `CMyButton_Init` |
| `+0x84` | repeat-timer enable | copies the final `CMyButton_Init` byte parameter |

The message map beginning at `0x866C48` proves the following handlers:

| Win32 message | Handler | Verified effect |
|---:|---|---|
| `WM_MOUSEMOVE (0x200)` | `CMyButton_OnMouseMoveBeginCursorTracking` (`0x589F0F`) | sets `+0x80=1`, then delegates to the default window procedure |
| `WM_LBUTTONUP (0x202)` | `CMyButton_OnLButtonUpResetPressedFrame` (`0x58A17A`) | kills the optional timer and changes frame `1 -> 0` before default button processing |
| `WM_LBUTTONDOWN (0x201)` | `CMyButton_OnLButtonDownSetPressedFrame` (`0x58A1C2`) | changes the current frame to `1`; optional special/timer behavior is controlled by fields initialized at `+0x6C/+0x70/+0x84` |
| `WM_ENABLE (0x0A)` | `CMyButton_WindowProcHandleEnablePaintAndMove` (`0x58A4AC`) | enabled selects frame `0`; disabled selects frame `2` |
| `WM_TIMER (0x113)` | `CMyButton_OnRepeatTimer` (`0x58A6D6`) | posts the configured repeat command, re-samples the cursor, and kills the timer after the cursor leaves |

`CMyButton_UpdateCursorInsideState` (`0x58A603`) uses `GetCursorPos`,
`GetWindowRect`, `WindowFromPoint`, the child/parent HWND relationship, and `PtInRect`.
The disassembly at `0x58A610..0x58A695` resolves misleading decompiler fall-through:
an inside point sets `+0x82=1` and returns; a point outside clears both `+0x80` and
`+0x82`.

`CMyButton_TickAndRender` (`0x589FB1`) queries
`GameDataSetQuery()->vfunc+0x10("ani/Control.ani", section, 1, 0x7530)` and selects the
ANI frame with this exact rule:

| Condition | Rendered frame |
|---|---:|
| hover enabled, cursor tracking active, current frame is not pressed, and HWND enabled | `3` |
| otherwise | current frame at `+0x68` |

The resulting verified visual indices are therefore:

| Index | Meaning |
|---:|---|
| `0` | normal |
| `1` | pressed |
| `2` | disabled |
| `3` | hover/emboss |

The optional tooltip branch at `0x58A041..0x58A16E` is explicitly outside this control-only
slice: it depends on the native font settings, string measurement, localized tooltip runs, and
text draw service. It must remain unwired until the text slice closes that contract.

For the canonical production control, PE `RT_DIALOG 0x82` binds control ID `0x400` to
`CDlgMain+0x13C390`; initialization selects `Main3_OrganiseBtn`. The `CDlgMain` message-map
entry at `0x855D20` dispatches `BN_CLICKED` to
`CDlgMain_OnOrganiseButtonClicked_ToggleOrganiseDialog` (`0x4BDA50`). That handler plays
`Sound/BtnClick.wav` at volume `100` and toggles the dialog hosted at
`CDlgMain+0x90A80` between show state `5` and hidden state `0`.

Clean `Control.Ani` section `Main3_OrganiseBtn` has four 64x32 DXT3 frames:

| Frame | Asset | SHA-256 |
|---:|---|---|
| `0` | `data/main/OrganiseBtnNormal.dds` | `0b4f52919c0506bf86881e4201859459128df5736552189737751118aa66b360` |
| `1` | `data/main/OrganiseBtnClick.dds` | `d6291032e2fc79aa6ca3a1715f32c2f3e73dc402b9fb927c9100dc7cae98b03a` |
| `2` | `data/main/OrganiseBtnUnClick.dds` | `f9382f214d194c56e320933d69d00a637621b015b757401e29e260dbc818aaa3` |
| `3` | `data/main/OrganiseBtnEmboss.dds` | `276d5d92563a4ae97825a0a2dafb7910788e2902c87ca7a96af2b2b7acdc2e16` |

The clean reference tree and `10_work/assets/5517-1` copies match byte-for-byte for the ANI
manifest and all four DDS files.

Verified but still pending from this same path:

- `CMyProgress_Show` data-driven bars:
  `Progress40` uses `CHero_GetPlayerDataByIndex(1)` / `CHero_GetPlayerDataByIndex(15)`;
  `Progress41` uses the hero mana getter at vtable `+0xB0` / `CHero_GetSmoothedCurrentMana`;
  `Progress46` and `Progress47` use `CHero_GetCappedPhysicalForce`, with the second segment gated by
  `CHero_HasExtendedPhysicalForceGaugeStatus`;
  `Progress42` reads `CHero+0x510`;
  `Progress44` reads the 64-bit value at `CHero+0x860/+0x864` shifted by `shell+0x10C`.
  The managed HUD must not draw these until the corresponding max/current/forecast state is present.
- `CMyGrid_Show` quickbar slots.
- The `Magic0` control at `0x3FE`: initialized through `CMyImage_Init`, immediately cleared by
  `CMyImage_ClearLoadedImage`, and drawn later only if a real selected-skill image is loaded.

### Managed Boundary: `Dialog5` talk shell remains intentionally absent

- The live 5517 HUD function shown above does **not** directly expose the talk-shell owner path yet.
- The asset itself is verified in the active 5517 bundle:
  `ani/Control.ani -> Dialog5 -> data/main/DialogTalk1..4.dds`.
- The managed client no longer draws an always-on `Dialog5` stopgap from the world HUD pass.
- Treat `Dialog5` as blocked on the real 5517 quickbar/talk widget owner path around
  `CMyGrid_Show(arg1 + 0x13c430)` and its sibling button/dialog calls, not manual placement tuning.

### BNinja rename set applied in this front-overlay slice (`Conquer.exe.bndb`)

| Address | Verified name |
|---:|---|
| `0x5DE04A` | `CMyShellDlg_DrawExChatTopBackgroundAndFlip` |
| `0x5DD71A` | `CMyShellDlg_DrawExChatJointPanelAndFlip` |
| `0x5DD987` | `CMyShellDlg_DrawExChatJointBackgroundByMode` |
| `0x5DE26F` | `CMyShellDlg_ApplyExChatDisplayModeAndReflowWindows` |
| `0x40C0ED` | `CExChatPanel_RefreshButtonResourcesAndNotifyMapProjection` |
| `0x4BC1F8` | `CDlgMain_RenderMainUiDialogAndStatusOverlay` |
| `0x4BB6B8` | `CDlgMain_BindMainHudWidgetControls` |
| `0x4BB869` | `CDlgMain_InitializeMainHudWidgets` |
| `0x58A21E` | `CMyButton_Init` |
| `0x58B448` | `CMyCheck_Init` |
| `0x58B882` | `CMyCheck_Show` |
| `0x58B733` | `CMyCheck_ShowTip` |
| `0x58B6BD` | `CMyCheck_ClearHoverFlagWhenMouseLeaves` |
| `0x59F5E3` | `CMyGrid_Init` |
| `0x59FC1E` | `CMyGrid_Show` |
| `0x5A0FA7` | `CMyGrid_GetSlotOccupiedFlag` |
| `0x5A11B5` | `CMyGrid_GetZeroBasedSlotIndex` |
| `0x5A16AB` | `CMyGrid_GetSlotContentKind` |
| `0x5A17CC` | `CMyGrid_GetRelativeOrigin` |
| `0x5A17E4` | `CMyGrid_GetCellWidthPixels` |
| `0x5A17E9` | `CMyGrid_GetCellHeightPixels` |
| `0x5A17EE` | `CMyGrid_GetSlotItemUid` |
| `0x5A9033` | `CMyProgress_Show` |
| `0x5A9784` | `CMyProgress_Init` |
| `0x5A9999` | `CMyProgress_ResetValueRange` |
| `0x5A9A60` | `CMyProgress_SetBlendMode` |
| `0x5A9A96` | `CMyProgress_SetFillGeometryPixels` |
| `0x5A1F8A` | `CMyImage_Init` |
| `0x5A2612` | `CMyImage_ClearLoadedImage` |
| `0x673E92` | `CHero_GetPlayerDataByIndex` |
| `0x749EBA` | `FDword_GetValueByIndex` |
| `0x67320F` | `CHero_GetSmoothedCurrentMana` |
| `0x66F766` | `CHero_HasExtendedPhysicalForceGaugeStatus` |
| `0x66F77C` | `CHero_GetCappedPhysicalForce` |
| `0x66F792` | `CHero_GetEffectiveMaxPhysicalForce` |
| `0x6C86F2` | `CMyButton_SetCurrentFrame` |
| `0x937088` | `g_shellLayoutWidthPixels` |
| `0x93708C` | `g_shellLayoutHeightPixels` |
| `0x96AB30` | `g_uiLayoutModeFlag` |

### BNinja rename set applied in this slice (Conquer.exe.bndb)

| Address | Verified name |
|---:|---|
| `0x6DEBA5` | `CNetMsg__ProcessMsg` |
| `0x6DF3B5` | `CNetMsg__ProcessMsg_Dispatch` |
| `0x6DF3AD` | `CNetMsg__GetSize` |
| `0x6DF3A4` | `CNetMsg__GetType` |
| `0x6DF355` | `CNetMsg__Send` |
| `0x6DF2AE` | `CNetMsg__ValidateHeaderAndCopy` |
| `0x6DF2F6` | `CNetMsg__LogProcessMsg` |

### BNinja rename set applied in world-frame gate byte slice (`Conquer.exe.bndb`)

| Address | Verified name |
|---:|---|
| `0x5ADAB7` | `CMyShellDlg_ConstructAndInitializeMembers` |
| `0x5AE8D8` | `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate` |
| `0x5AE704` | `CMyShellDlg_InitializeUiAndToggleStartupWorldFrameGate_SehWrapper` |
| `0x5DC783` | `CMyShellDlg_ResetRuntimeAndDisableWorldFrameGate` |

## Managed Runtime Mapping (this slice)

Implemented for parity scaffolding:

- `10_work/src/Conquer/Client/Startup/ConquerAppRunMessageLoopRuntime.cs`
- `10_work/src/Conquer/Client/Startup/ConquerAppOnIdleFrameGateRuntime.cs`
- `10_work/src/Conquer/Client/Startup/ConquerAppStartupStateMachineRuntime.cs`
- `10_work/src/Conquer/Client/Startup/CLoginStartupPresentationHostRuntime.cs` (`SetTimer(id=1,0x14)` cadence + `VCTOFLASH` payload dispatch format)
- `10_work/src/Conquer/Client/Startup/CLoginStartupPresentationNonFlashBridgeRuntime.cs` (typed `VCTOFLASH` ingest: `PATH`/`SELECTBGMUSIC`/`CURWORLD`/`CURSERVER`/`LOGINUSER`/`ACCOUNT0..9`; verified `CMD_*` allow-list queue)
- `10_work/src/Conquer/Startup/ServerSelection/NativeParity/CLoginStartupServerDatPayloadProducer.cs` + `CLoginStartupServerListPayloadFromOutenserverBuilder.cs` (pre-loop `REGION`/`SERVER` producer from `Server.dat` decode path; decode auto-detects tooling-generated profile first then native 5517 public profile fallback, with native schedule evidence documented in `Architecture/05`; init-status fixed `3`)
- `10_work/src/Conquer.Assets/Startup/ServerDatOutenserverTableDecoder.cs` (RSA block decode -> PKCS#1 type-1 extraction -> gzip inflate -> `outenserver` row parse)
- `10_work/src/Conquer.Assets/Startup/StartupSwfManifestExtractor.cs` + `StartupSwfManifest.cs` (deterministic startup SWF manifest extraction: header/frame/tag/audio/script-hook metadata)
- `10_work/src/Conquer.Assets/Startup/StartupSwfLosslessPosterExtractor.cs` + `StartupSwfLosslessPoster.cs` (deterministic SWF `DefineBitsLossless2` poster extraction primitives)
- `10_work/src/Conquer.Assets/Startup/StartupSwfLosslessTimelineExtractor.cs` + `StartupSwfLosslessTimeline.cs` (display-list + sprite timeline decode for startup icon SWFs)
- `10_work/src/Conquer/Client/Startup/CLoginStartupMovieResourceManifestRuntime.cs` (startup movie resolver now consumes extracted SWF manifest and projects typed startup visual state)
- `10_work/src/Conquer/Client/Startup/CLoginStartupFlashIconResourceResolverRuntime.cs` + `CLoginStartupBackgroundBitmapSelectorRuntime.cs` (opaque `FlashIcon` asset resolution: `.bmp` and `.swf` resource kinds with deterministic path probes under `clientRoot`, `data/main`, `data/main/flash`)
- `10_work/src/Conquer/Client/Startup/CLoginStartupSwfPosterProviderRuntime.cs` + `CLoginStartupPreWorldVisualStageRuntime.cs` (elapsed-time SWF frame sampling aligned to verified startup timer cadence, rendered through non-Flash OpenGL sink)
- `10_work/src/Conquer/Client/Startup/CLoginStartupSelectionIniStoreRuntime.cs` (reads `[Group] GroupRecord`, `[Server] ServerRecord`, `[Account] AccountRecord`, `[AccountList] Account0..9`)
- `10_work/src/Conquer/Client/Composition/ClientRootPathResolver.cs` (runtime default root pinned to `10_work/assets/5517`; no `00_clean` fallback in managed runtime path resolution)
- `10_work/src/Conquer/Client/Startup/CLoginStartupCommandStateRuntime.cs` + `CGameInputLoginPasswordEncoderRuntime.cs` (`CMD_SELECTGROUP`/`CMD_SELECTSERVER` state writes, `CMD_NAME`, `CMD_PASSWORD` transform parity)
- `10_work/src/Conquer/Client/Startup/CLoginStartupPresentationRuntime.cs` (`CMD_ENTERGAME` -> `PostMessage(0x480,0)`, `CMD_SELECTBGMUSIC` ini write, `CMD_CLOSE` -> `0x483/0xC6B/0x3F2`)
- `10_work/src/Conquer/Client/Scene/Role3DClientSceneNetworkIngressStageRuntime.cs`
- `10_work/src/Conquer/Client/Scene/Role3DClientSceneWorldFrameGateRuntime.cs` (`this+0x179AB9` world-frame enable gate state)
- `10_work/src/Conquer/Client/Scene/Role3DClientSceneFrameRuntime.cs` (world-frame gate + network gate + map tick/render stage order)
- `10_work/src/Conquer/Client/Scene/Role3DClientSceneFrontOverlayStageRuntime.cs` (pre-map top overlay stage with `ExChat_TopBG` only)
- `10_work/src/Conquer/Client/Scene/Role3DClientSceneHudAndSoundStageRuntime.cs` (post-map HUD/status stage now owns the verified static `Dialog4` main-UI subset)
- `10_work/src/Conquer/Client/Composition/SceneComposition.cs` now wires the non-noop front overlay stage into the live world-frame path using the verified ANI resource query + logical screen-dimensions dependencies

Unit coverage:

- `10_work/tests/Conquer.Tests/Client/Startup/ConquerAppRunMessageLoopRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/ConquerAppOnIdleFrameGateRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/ConquerAppStartupStateMachineRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/CLoginStartupPresentationHostRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/CLoginStartupPresentationNonFlashBridgeRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/CLoginStartupServerDatPayloadProducerRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/ServerDatOutenserverTableDecoderTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/CLoginStartupCommandDispatchRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/CLoginStartupSelectionIniStoreRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Startup/CGameInputLoginPasswordEncoderRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Role3DClientSceneFrameRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Role3DClientSceneFrontOverlayStageRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/Role3DClientSceneHudAndSoundStageRuntimeTests.cs`
- `10_work/tests/Conquer.Tests/Client/SceneCompositionNetworkIngressTests.cs` (real composition path now submits `ExChat_TopBG` from the pre-map stage and `Dialog4` from the post-map HUD stage once the world-frame gate is enabled)

## `CMyShellDlg_RenderHudAndProcessSound` FPS + Sound Tail Contract (verified)

Function: `CMyShellDlg_RenderHudAndProcessSound` (`0x5ACB8F`)

### Entry FPS global update (`0x5ACB9F..0x5ACBDD`)

`CMyShellDlg_RenderHudAndProcessSound` begins by updating two global fields:

- `g_hudSmoothedFps` at `0x95865C`
- `g_hudLastFpsSampleTick` at `0x958660`

Instruction anchors:

| Site | Evidence | Meaning |
|---:|---|---|
| `0x5ACBA4` | `sub eax, [0x958660]` | `elapsed = nowTick - g_hudLastFpsSampleTick` (unsigned subtraction) |
| `0x5ACBAD` / `0x5ACBAF` | `jae` else `ecx = 1` | divisor clamp: `max(elapsed, 1)` |
| `0x5ACBC1..0x5ACBC8` | `eax = 1000; div ecx` | `instantFps = 1000 / divisor` |
| `0x5ACBCB..0x5ACBD3` | `add eax, [0x95865C]; shr eax, 1` | smoothed update: `(instantFps + g_hudSmoothedFps) >> 1` |
| `0x5ACBDD` | `mov [0x958660], eax` | store new `g_hudLastFpsSampleTick` |

Cross-reference confirmation:

- `g_hudSmoothedFps` (`0x95865C`) xrefs are all in `CMyShellDlg_RenderHudAndProcessSound`
- `g_hudLastFpsSampleTick` (`0x958660`) xrefs are all in `CMyShellDlg_RenderHudAndProcessSound`

### Sound tail contract (`0x5AD930..0x5AD950`)

Tail block disassembly:

- `0x5AD930`: call `CHero_GetSingletonPtr`
- `0x5AD944`: call hero vfunc slot `+0x44` with two out pointers (`[ebp-0x7C]`, `[ebp-0x84]`)
- `0x5AD947` / `0x5AD94D`: push sampled pair to stack
- `0x5AD950`: call `_DXProcessSound@8`

Verified behavior:

- Sound frame processing is executed at the function tail after HUD branches.
- Arguments to `_DXProcessSound@8` are exactly the two values returned by hero vfunc `+0x44`.

### BNinja renames applied in this slice (`Conquer.exe.bndb`)

| Address | Verified name |
|---:|---|
| `0x5D0C29` | `CGameMsg_RenderFloatingMessagesAndSystemOverlay` |
| `0x65E497` | `CHero_RenderStatusOverlayAndXpBar` |
| `0x95865C` | `g_hudSmoothedFps` |
| `0x958660` | `g_hudLastFpsSampleTick` |

## Managed Runtime Mapping (HUD/sound parity scaffold)

Implemented:

- `10_work/src/Conquer/Client/Scene/Role3DClientSceneHudAndSoundStageRuntime.cs`
- `10_work/src/Conquer/Client/Composition/SceneComposition.cs` (wires non-noop HUD/sound stage)

Current verified scope in managed runtime:

- exact FPS smoothing formula + state update order
- `_DXProcessSound@8` tail hook represented as `IRole3DClientSceneDxSoundProcessorRuntime`
- explicit listener sample contract represented as `IRole3DClientSceneHudSoundListenerPositionSourceRuntime`

Listener coordinate producer mapping is intentionally not inferred in this slice; runtime uses an explicit source interface and default no-op provider until the concrete non-test producer path is verified end-to-end.

Unit coverage:

- `10_work/tests/Conquer.Tests/Client/Role3DClientSceneHudAndSoundStageRuntimeTests.cs`

## `CMyShellDlg_TickMapRoleAndEffectPipeline` Bridge Function (verified)

Function: `CMyShellDlg_TickMapRoleAndEffectPipeline` (`0x5AFD4C`)

Called by `ConquerApp_OnIdle` as `CMyShellDlg_TickMapRoleAndEffectPipeline(data_95807C + 0x40, 1)` at `0x5AB562`.

This function is NOT a thin forwarder — it performs significant per-frame orchestration between `ConquerApp_OnIdle` and `CMyShellDlg_RunFrameTick`.

### Verified call sequence

| Order | Callee | Address | Verified behavior |
|---:|---|---:|---|
| 1 | `PerfTimer_BeginSample(GetFrameTickPerfTimerSingleton())` | `0x5AFD59` | Stores `timeGetTime()` into perf timer `+0x14` |
| 2 | `QueryMonitorManager()` → vtable `+0x18` | `0x5AFD5E` | Monitor manager per-frame tick (null-guarded) |
| 3 | `*(*(arg1+0x17981C)+0x18)()` check, then `+0x14` with `0x3E8` | `0x5AFD84` | Timer/timeout object check+reset at `this+0x17981C` (1000ms interval) |
| 4 | `IncrementGlobalTickCounter()` | `0x5AFD92` | Increments `g_globalTickCounter` (`0x96AEC0`) |
| 5 | `CMyShellDlg_ManageParentWindowFocusState(arg1)` | `0x5AFD99` | Enable/disable parent window based on focus + cursor position |
| 6 | `g_frameTickCounter += 1` | `0x5AFD9E` | Increments `g_frameTickCounter` (`0x958664`) |
| 7 | Frame skip gate (see below) | `0x5AFDB2..0x5AFE13` | Skip frames when minimized or background |
| 8 | `CMyShellDlg_RunIdleMaintenanceAndAfkCheck()` | `0x5AFE1B` | AFK timeout (30 min) + periodic maintenance |
| 9 | `*(*(AfxGetModuleState()+4)+0xC8) = 0` | `0x5AFE2A` | Reset MFC idle count |
| 10 | `CMyShellDlg_UpdateNetworkSessionStateFlags(arg1)` | `0x5AFE30` | Update session/network state flags at `this+0x17980C/+0x179810/+0x179814` |
| 11 | Login flash window enable/disable | `0x5AFE43..0x5AFE72` | Disable controls at `this+0x179834` and `this+0x1798D4` when world entry not complete |
| 12 | Reentrant guard check (`g_frameTickReentrantGuard`) | `0x5AFE7D` | Skip frame tick if already executing |
| 13 | `CMyShellDlg_RepositionWindowsOnDrag(arg1)` | `0x5AFE97` | Reposition windows when `this+0x179708 != 0` (only when `arg2 == 1`) |
| 14 | `CMyShellDlg_SetFrameTickContext(loginFlashSingleton, arg1)` | `0x5AFEA4` | Invokes `CMyShellDlg_RunFrameTick(arg1, 1)` through callback chain |
| 15 | `(*(*GameDataSetQuery() + 0xC))()` | `0x5AFEB3` | GameDataSet per-frame resource pump (vtable `+0x0C`) |
| 16 | `g_frameTickReentrantGuard = 0` | `0x5AFEB6` | Release reentrant guard |
| 17 | `PerfTimer_EndSample(GetFrameTickPerfTimerSingleton())` | `0x5AFED3` | Accumulates elapsed time to perf timer `+0x30`, increments sample count `+0x34` |

### Frame skip mechanism (background/minimized throttle)

When login/world entry is not yet complete (`CLoginFlashDlg_IsWorldEntryComplete() == 0`), the function checks window state and skips frames:

| Condition | Divisor | Effect |
|---|---:|---|
| Parent window is minimized (`IsIconic == true`) | 5 | Execute frame tick only every 5th frame |
| App is not foreground (`GetForegroundWindow != any app HWND`) | 3 | Execute frame tick only every 3rd frame |
| App is focused and visible | 1 | Execute every frame (no skip) |

Frame skip uses `g_frameTickCounter % divisor != 0` to skip. When a frame is skipped, execution jumps past steps 8–17 entirely.

Foreground check compares `GetForegroundWindow()` against three HWNDs:
- `*(CWnd::FromHandle(GetParent(*(arg1+0x20)))+0x20)` — parent window
- `*(arg1+0x1669D0)` — secondary window handle
- `*(arg1+0x168C78)` — tertiary window handle (ExChat panel)

### Frame tick callback chain

`CMyShellDlg_SetFrameTickContext` (`0x5789A2`):
1. Gets callback object at `*(loginFlashDlg + 4)`
2. Calls vtable `+0x10` on callback object with shell dialog pointer
3. Callback invokes `CMyShellDlg_RunFrameTickCallback_InvokeIfNonNull` (`0x57813B`)
4. Which directly calls `CMyShellDlg_RunFrameTick(shellDlg, 1)` if non-null

### `CLoginFlashDlg_IsWorldEntryComplete` (`0x57829B`)

Calls `CLoginFlashDlg_CheckCallbackActiveMessageCode` (`0x578280`) with message code `0x3F2`.
Returns `1` when login/startup transition has completed (message `0x3F2` has been processed), `0` otherwise.
`0x3F2` is one of the three messages posted by `CMD_CLOSE` (alongside `0x483` and `0xC6B`).

### GameDataSet per-frame resource pump

`(*(*GameDataSetQuery() + 0xC))()` at `0x5AFEB3` runs AFTER the frame tick completes. This is vtable slot `+0x0C` (index 3) on the GraphicData.dll GameDataSet singleton — a per-frame resource management pump (likely handles deferred loading, garbage collection, or pending resource requests).

### BNinja renames applied in this slice (`Conquer.exe.bndb`)

| Address | Verified name |
|---:|---|
| `0x5AFD4C` | `CMyShellDlg_TickMapRoleAndEffectPipeline` (already named) |
| `0x67C049` | `IncrementGlobalTickCounter` |
| `0x5AFC7D` | `CMyShellDlg_ManageParentWindowFocusState` |
| `0x5AF9CC` | `CMyShellDlg_RunIdleMaintenanceAndAfkCheck` |
| `0x5D9AA0` | `CMyShellDlg_UpdateNetworkSessionStateFlags` |
| `0x5D8FAD` | `CMyShellDlg_RepositionWindowsOnDrag` |
| `0x5DCEA3` | `CMyShellDlg_RunPreWorldFlashHostFrameCallbacks` |
| `0x5780EC` | `CMyShellDlg_RunPreWorldFlashHostFrameCallbacksIfNonNull` |
| `0x57829B` | `CLoginFlashDlg_IsWorldEntryComplete` |
| `0x578280` | `CLoginFlashDlg_CheckCallbackActiveMessageCode` |
| `0x5964C1` | `CFlashHostDialog_IsWindowVisibleOrPendingActivation` |
| `0x4B04CE` | `CLoginFlashDlg_OnTimerTickFlashHostAndDispatchCallbacks` |
| `0x4AD9A9` | `CLoginFlashDlg_TickFlashHostStateAndInputBridge` |
| `0x4B04B6` | `CLoginFlashDlg_SetProgressVariable` |
| `0x51C1C3` | `CRoleCreateFlashDlg_SetFlashVariableAndDispatch` |
| `0x51C289` | `CRoleCreateFlashDlg_SetProgressVariable` |
| `0x76DE2C` | `PerfTimer_BeginSample` |
| `0x76DE39` | `PerfTimer_EndSample` |
| `0x53A304` | `GetFrameTickPerfTimerSingleton` |
| `0x958664` | `g_frameTickCounter` (data) |
| `0x958668` | `g_frameTickReentrantGuard` (data) |
| `0x96AEC0` | `g_globalTickCounter` (data) |
| `0x9564D4` | `g_frameTickPerfTimerSingleton` (data) |
