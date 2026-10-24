# `play.exe` Startup And Handoff

## Scope

This slice documents only `play.exe` startup and launcher handoff behavior for clean 5517.

- Binary: `00_clean/clean/5517/play.exe`
- Active BNinja view: `125`
- Entry point: `_start` at `0x408AAC`

`AutoPatch.exe` and `TimeDelay.exe` behavior is intentionally out of scope for this slice.

## Renamed Symbols Applied In BNinja

| Address | Verified name |
|---|---|
| `0x408C3E` | `PlayLauncher_ForwardToAfxWinMain` |
| `0x408C56` | `PlayLauncher_ConfigureMfcModuleStateForStartup` |
| `0x408C7F` | `PlayLauncher_CrtInitializeMfcModuleState_Thunk` |
| `0x408C84` | `PlayLauncher_CrtInitializeMfcModuleState` |
| `0x4035B3` | `PlayLauncherApp_Constructor` |
| `0x4035E3` | `PlayLauncherApp_Destructor` |
| `0x4035F2` | `PlayLauncherApp_ConstructGlobalInstance` |
| `0x4035E8` | `PlayLauncherApp_ConstructAndRegisterGlobalInstance` |
| `0x4035FC` | `PlayLauncherApp_RegisterGlobalDestructor` |
| `0x403608` | `PlayLauncherApp_DestroyGlobalInstance` |
| `0x403612` | `PlayLauncherApp_InitInstance` |
| `0x403C45` | `PlayLauncherDialog_Constructor` |
| `0x40367B` | `PlayLauncherDialog_Destructor` |
| `0x405956` | `PlayLauncherDialog_OnStartNormalModeLaunchAutoPatch` |
| `0x405AB3` | `PlayLauncherDialog_OnStartLowModeLaunchAutoPatch` |
| `0x406622` | `PlayLauncherDialog_EnsureFlashOcxRegistered` |

## CRT -> MFC Startup Chain

| Step | Address | Evidence |
|---|---|---|
| CRT entry | `0x408AAC` | `_start` parses command line and computes `wShowWindow`, then calls launcher forwarder at `0x408BDB`. |
| MFC forwarder | `0x408C3E` | `PlayLauncher_ForwardToAfxWinMain` pushes 4 WinMain args and calls imported `AfxWinMain` at `0x408C4E`. |
| MFC init helper | `0x408C84` | `PlayLauncher_CrtInitializeMfcModuleState` calls `PlayLauncher_ConfigureMfcModuleStateForStartup(0, 0x600)` and stores success byte at `0x40E5A4`. |

Disassembly anchors:

- `_start -> PlayLauncher_ForwardToAfxWinMain`: `0x408BDB`
- `PlayLauncher_ForwardToAfxWinMain -> AfxWinMain`: `0x408C4E`
- `PlayLauncher_CrtInitializeMfcModuleState`: `0x408C84..0x408C95`

## App Singleton And InitInstance

Global app singleton storage uses `0x40E4B8` (constructed/destroyed via static initializer helpers):

- construct call site: `PlayLauncherApp_ConstructAndRegisterGlobalInstance` at `0x4035E8`
- destroy registration: `PlayLauncherApp_RegisterGlobalDestructor` at `0x4035FC`
- direct constructor thunk: `PlayLauncherApp_ConstructGlobalInstance` at `0x4035F2`
- direct destructor thunk: `PlayLauncherApp_DestroyGlobalInstance` at `0x403608`

`PlayLauncherApp_InitInstance` (`0x403612`) verified behavior:

1. `AfxEnableControlContainer(nullptr)` (`0x40362B`)
2. `CWinApp::Enable3dControls` (`0x403633`)
3. Constructs launcher dialog (`PlayLauncherDialog_Constructor`) (`0x403640`)
4. Assigns `m_pMainWnd` (`this+0x20`) to dialog object (`0x403655`)
5. Executes `CDialog::DoModal` (`0x403658`)
6. Destroys dialog (`PlayLauncherDialog_Destructor`) (`0x403667`)
7. Returns `0` (MFC app exits after modal dialog closes) (`0x40367A`)

## Launcher Handoff Behavior In `play.exe`

Two verified action handlers launch `AutoPatch.exe`:

- `PlayLauncherDialog_OnStartNormalModeLaunchAutoPatch` (`0x405956`)
- `PlayLauncherDialog_OnStartLowModeLaunchAutoPatch` (`0x405AB3`)

Shared handoff pattern in both handlers:

1. Read/write mode counters in `ini/GameSetup.ini` via `GetPrivateProfileIntA` and `WritePrivateProfileStringA`.
2. `GetCurrentDirectoryA` into local buffer.
3. Format executable path with `"%s\\AutoPatch.exe"` (`0x40D544`).
4. `ShellExecuteA(hwnd=this->m_hWnd, operation=null, file=<cwd>\\AutoPatch.exe, params="blacknull", dir=null, show=0xD)`.
5. End dialog with `CDialog::EndDialog(0)`.

Direct instruction anchors:

- normal mode `ShellExecuteA` call: `0x405A46`
- low mode `ShellExecuteA` call: `0x405B99`
- format string literal: `0x40D544` (`"%s\\AutoPatch.exe"`)

## Negative Evidence (Important)

- `play.exe` contains no `"Conquer.exe"` string hit in this slice.
- Verified direct launch target in this binary path is `AutoPatch.exe` (not direct `Conquer.exe`).

So for parity, `play.exe` should be modeled as launcher UI that dispatches to patch flow, not as the direct game-client process bootstrap.

## Managed Runtime Mapping (this slice)

`10_work/src/Conquer.Play` now mirrors the verified split used in `Conquer`:

- startup composition (`PlayStartupComposition`) resolves launcher current-directory input
- launcher composition (`PlayLauncherComposition`) resolves the verified AutoPatch launch contract
- app entry (`PlayLauncherApplication.Run`) composes both and exposes the resolved handoff tuple

Files:

- `10_work/src/Conquer.Play/Application/PlayLauncherApplication.cs`
- `10_work/src/Conquer.Play/Composition/PlayRootPathResolver.cs`
- `10_work/src/Conquer.Play/Composition/PlayStartupComposition.cs`
- `10_work/src/Conquer.Play/Composition/PlayLauncherComposition.cs`

## `CPlayDlg` UI (proven 2026-10-17)

Source `F:\Play-1.14\PlayDlg.cpp`. Dialog 102: `DLGTEMPLATEEX`, `WS_POPUP|WS_VISIBLE|DS_SETFONT`, `WS_EX_APPWINDOW`, 9pt `宋体`.
All controls repositioned/skinned from `ini/PlayGui.ini` section `0-<id>` (`x,y,w,h`; `normal/over/down/disabled/focus<variant>`).

| Addr | Name |
|---|---|
| `0x403F74` | `CPlayDlg_OnInitDialog` |
| `0x403E83` | `CPlayDlg_DoDataExchange` |
| `0x405583` | `CPlayDlg_LoadBackgroundAndWindowRegions` |
| `0x403907` | `PlayGui_ApplyControlLayoutAndSkin` |
| `0x40522A` | `CPlayDlg_PlayConfiguredSound` |
| `0x406979` | `PlayLauncherDialog_OnStartHighModeLaunchAutoPatch` |
| `0x405A59` / `0x405BAC` / `0x405BC2` | `CPlayDlg_OnLowModeButton` / `..ConfirmContinue` / `..ConfirmReturn` |
| `0x405BF8` / `0x405CBF` / `0x405D7E` / `0x405ED0` | `CPlayDlg_OnExit` / `OnOffice` / `OnRegister` / `OnLogo` |
| `0x405E3D` / `0x4052FC` / `0x4052AD` | `CPlayDlg_OnTimer` / `OnPaint` / `OnSysCommand` (About) |
| `0x4054AC` / `0x4054ED` / `0x405501` | window drag: LButtonDown capture, Up release, MouseMove `MoveWindow` |
| `0x405818` / `0x405944` / `0x406746` | `OnDestroy` / `OnSetCursor` (`SetCursor([this+0x210])` = `Normal.ani`, returns TRUE; only `SetCursor` call in play.exe, so it also covers the skin buttons) / `WindowProc_PlayHoverSounds` (`WM_MOUSEHOVER`, wParam=id) |
| `0x405F9F` / `0x40608B` / `0x40609F` / `0x4062AD` | centre web navigate / hide / masked image / Title+Content text |
| `0x404E18` / `0x404F32` | `GetUnescapedPlayDatString` (`\n`→LF, `\32`→space) / `BuildTextBlockFromGuiSection` |
| `0x407B0C` / `0x407D9A` / `0x407134` | `CSkinButton_LoadStateBitmaps` / `..CreateRegionFromColorKey` / `..DrawItem` |
| `0x408007` / `0x4080A6` / `0x40751C` | tooltip text / max width / `CSkinText_DrawLines` |
| `0x401E66` / `0x401D53` / `0x401D1C` | `MyIni_CreateNewByBuffer` / `GetString` / `GetInt` |

Message map `0x40A5B8`; DDX members:

| Id | Member | Role | PlayGui rect | Art |
|---:|---|---|---|---|
| 102 | dlg | window | 0,0 900x650; bg `Play/main.bmp` 800x600 | region `Play/Main.rgn` (299 rects, bounds 1,1–800,599) |
| 1000 | `+0x90C` | `CWebBrowser2` | 40,106 548x405 | region `Play/Center.rgn` (one rect 546x410) |
| 1001 | `+0xD3C` | Standard start | 585,443 | `low0x/low1x.bmp` 210x90 ("Standard Definition") |
| 1007 | `+0xA9C` | High start | 580,392 | `high0x/high1x.bmp` 210x80 |
| 1008 | `+0x7BC` | Low start | 580,520 | `Simplify0x/1x.bmp` 198x77 ("Low Definition") |
| 1002 | `+0xE8C` | Site | 273,541 | `Office0x.bmp` 108x30 |
| 1003 | `+0xFDC` | Register | 385,541 | `Register0x.bmp` 108x30 |
| 1004 | `+0x94C` | Exit | 160,541 | `Exit0x.bmp` 108x30 |
| 1005 | `+0xBEC` | Logo (disabled) | 385,-1 | `Play/LOGO.bmp`; `OnTimer` id 1 would cycle `Play/logo/logo0100%02d.bmp` 1–50, but timer 1 is never set (only `SetTimer` sites `0x4042FC`, `0x405F75` use id 2); dir absent in clean |
| 1009 | `+0x66C` | Hint popup (disabled) | 160,200 | `Hint.bmp` 397x207; text 20,20 color 0x7F, font 20/10 |
| 1010 | `+0x51C` | Continue | 220,350 | `Continue0x.bmp` 102x32 |
| 1011 | `+0x3CC` | Return | 380,350 | `Return0x.bmp` 102x32 ("Cancel") |
| 1012 | `+0x27C` | version text (disabled) | 110,33 | `version.dat` line 1; font 15/6; color 0xFF |

`0x` = `01 normal, 02 over, 03 down`; `1x` = variant 1. Foreground children (`fgcount=2`): `Play/MainS.bmp` at 594,0; `Play/Version.bmp` at 35,29.

- Skin button: window region = normal-bitmap pixels `!= RGB(0,255,0)` (exact). Resized to bitmap size. Draw priority disabled > pressed(down) > hover(over) > focus > normal.
- Modes (`ini/GameSetup.ini [GameMode]`): High → `HighTimes++`, `GameModeRecord=1`; Standard → `NormalTimes++`, `=0`; Low → `LowTimes++`, `=2`; then `ShellExecute AutoPatch.exe blacknull`, `EndDialog`. All three variant 1; most-used gets variant 0: `m = max(H,N) > L ? max(H,N) : L`, first of Normal, High, Low equal to `m` (fresh install → Standard).
- Low: first time (`LowTimes == 0`) shows Hint+Continue+Return; Continue → low launch; Return hides popup.
- Conquer.exe reads only `GameModeRecord == 2` (`0x65CF9B`).
- Exit/Site/Register: Oem.ini `[ExitPopUp]/[Office]/[Register] url` else Play.dat `[IE]`; `EnumWindows` for an open window titled `*Title`, else `ShellExecute`. Exit then `EndDialog`.
- Tooltips: system tooltip, `TTDT_AUTOMATIC` 500 ms, `TTM_SETMAXTIPWIDTH` 2000; `STR_PLAY_HIGH/NORMAL/LOW_TIP`.
- Sounds: click `EnterClick/ExitClick/OfficeClick/RegisterClick` = `Enter/Exit/Office/Register.wav` under `Sound/`; all `*Over` empty. Files absent in clean 5517; `PlaySoundA(SND_FILENAME)` without `SND_NODEFAULT` → system default sound.

### `ini/Play.dat`

Cipher: each byte −6. Decoded clean: `[Start] Type=1 Interval=5000`; `[Web] web1=http://co.91.com/gamer/gamer.shtml`; `[IE]` Office/Register/Exit URLs; `[Sound]` above; `[Title]`/`[Content]` empty text, 12pt, color `99FFFF`, default face `宋体`; `[Str]` tips + `STR_PLAY_SIMPILYCONFIRM`; `[Tip] MaxWidth=2000`.

## `AutoPatch.exe` UI (proven 2026-10-17)

| Addr | Name |
|---|---|
| `0x401010` | `CAutoPatchApp_Constructor` (theApp `0x451BA0`, config `+0x1E8`) |
| `0x401EB0` | `AutoPatchConfig_LoadFromConfigIni` (`AutoPatch\config.ini`) |
| `0x4052D0` | `CAutoPatchDlg_ApplyGuiIniLayout` (`AutoPatch\GUI.ini`) |
| `0x404820` | `CAutoPatchDlg_OnInitDialog` |
| `0x406D50` | `CAutoPatchDlg_OnTimer` (download state machine) |
| `0x407AF0` | `CPatchProgressBar_Draw` |
| `0x407CA0` | `CPatchProgressText_DrawLabelAndPercent` |

- Window 640x470 (GUI.ini `[Dialog]`), title `TqAutopatch`.
- `srand(time)`: download pic `DownPic[rand%3]` (`D1..D3.bmp`), setup pic `SetupPic[rand%3]` (`S1..S3.bmp`), 640x466.
- Bars (max 100): GUI ids 1002 (22,397 592x17), 1006 (22,436), 1008 (24,437); bar art `schedule.bmp` 678x17 revealed left-to-right, width `rectW*value/max`, not stretched.
- Text rows 1004 (27,377), 1005/1007 (27,416): label (`LableColor`, default 0x808000) then `%.0fK/%.0fK = %.2f%%` at x+80 (`TextColor` 0xFFFFFF). Labels `Updated:`/`Total:`/`Installed:`.
- Link font Arial 14 underlined (`WebTip` "Download from site").
