# `play.exe` Startup And Handoff (Verified)

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
