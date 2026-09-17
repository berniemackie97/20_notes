# CDummyMovieMgr — Timed Sprite Animation System (Verified)

## Scope

This document covers the `CDummyMovieMgr` singleton system. Despite the name, this system is
**NOT used for startup** — it drives **in-game mount/ride PK arena cutscenes**.

The startup intro animation was Flash-internal (inside `start.dat` SWF).

## Singleton Lifecycle

| Symbol | Address | Purpose |
|---|---:|---|
| `CDummyMovieMgr_CreateSingleton` | `0x405DF7` | Explicit singleton creation (from `CreateAllSingletons`) |
| `CDummyMovieMgr_GetSingletonPtr` | `0x4CFD0A` | Lazy singleton accessor |
| `CDummyMovieMgr_Ctor` | `0x68B80C` | Constructor — calls `CDummyMovieMgr_LoadIni` + `Game3DEffectCreate(0)` |
| `CDummyMovieMgr_LoadIni` | `0x68B9C3` | Parses `DummyMovie.ini` or `DummyMovie800X600.ini` |
| `CDummyMovieMgr_ReloadForResolution` | `0x68B8EC` | Reads `ScreenMode` from `GameSetup.Ini`, reloads correct INI |

Global storage: `data_955FD4`

## INI Selection

Resolution flag `data_96AED0` selects INI file:
- `0` → `ini/DummyMovie800X600.ini` (800x600)
- `>= 2` → `ini/DummyMovie.ini` (1024x768+)

Flag is read from `ini/GameSetup.Ini` section `[ScreenModeRecord]` key `ScreenMode`.

## DummyMovie.ini Format

ASSERT source path: `F:\CQ2ClientRelease-42.0.1\3DRole\DummyMovieMgr.cpp`

### Structure
- Comments start with `;`
- Blank lines and lines starting with `\n` skipped
- Section headers: `[N]` parsed via `sscanf(buf, "[%d]", &sectionIndex)`
- Each content line first read as 2 ints: `sscanf(buf, "%d%d", &startTime, &typeId)`

### Line Discrimination (field 2)

**Media lines** (`typeId` 1001–1003):
- 1001 = BG (background)
- 1002 = EFFECT (screen effect)
- 1003 = SOUND

Format (10 fields): `StartTime MediaType ResId ResourcePath TimeLasted ScrX ScrY ScrW ScrH Scale`
- `sscanf(buf, "%d%d%d%s%d%d%d%d%d%d")`

**Dummy object lines** (`typeId` 1–999):

Format (17 fields): `StartTime DummyId ActionType PlaySound TimeLasted ScrBeginX ScrBeginY ScrEndX ScrEndY ScaleBegin ScaleEnd RotateXBegin RotateYBegin RotateZBegin RotateXEnd RotateYEnd RotateZEnd`
- `sscanf(buf, "%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d%d")`
- DummyId maps to 3D model resource IDs

### Retail Content (`ini/DummyMovie.ini`)

**Section [1]** — Mount ride intro cinematic:
- 8 sound cues: start.wav → ring.wav → horse.wav → horse_run.wav → finish_1.wav
- 13 dummy object keyframes (DummyIds 705–710) over ~10.6 seconds
- Animates horse/rider sprites with position interpolation, scaling, and Z-axis rotation

**Sections [2] and [3]** — PK arena countdown:
- 5 EFFECT entries each: `ridmatch_num5` through `ridmatch_num1` at 1-second intervals
- Positioned center-screen (512, 384)

## Playback Trigger Chain

| Symbol | Address | Called From |
|---|---:|---|
| `CDummyMovieMgr_LoadAndStartAllSequences` | `0x4CE667` | `DlgMountAppend` mount handler |
| → `sub_68C1F5(mgr, sectionIndex)` | `0x68C1F5` | Load sequence by index |
| → `sub_68C2BE(mgr)` | `0x68C2BE` | Begin playback |

Trigger: `CMyShellDlg_WindowProc_DispatchMainWindowMessages` → `sub_4CD888` (mount dialog handler)

Frame update: `CMyShellDlg_RunFrameTick` → `sub_4CCF01` (mount dialog render) drives per-frame DummyMovie state:
- `sub_68C751(mgr, seqIdx)` — check sequence completion
- `sub_68C42E(mgr, seqIdx)` — advance/tick sequence

## BNinja Renames Applied

| Address | Name |
|---:|---|
| `0x405DF7` | `CDummyMovieMgr_CreateSingleton` |
| `0x4CFD0A` | `CDummyMovieMgr_GetSingletonPtr` |
| `0x68B80C` | `CDummyMovieMgr_Ctor` |
| `0x68B9C3` | `CDummyMovieMgr_LoadIni` |
| `0x68B8EC` | `CDummyMovieMgr_ReloadForResolution` |
| `0x4CE667` | `CDummyMovieMgr_LoadAndStartAllSequences` |
| `0x404D19` | `CreateAllSingletons` |
