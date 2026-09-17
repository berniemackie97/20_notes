# Rendering / UI / Animation Gap Analysis (5517 Client)
## Goal
Document all *Windows-specific* and *engine/DLL-specific* rendering, UI, input, timing, and animation touchpoints observed in the original client.

This document is based on:
- IDA import table inspection (Win32 + external DLL boundaries)
- Decompilation of key frame-loop and render-path functions

---

## Executive Summary
The original client is *not* “just a DirectX app” in the typical sense; most rendering-facing work is performed via a proprietary `graphic.dll` API (centered around `CMyBitmap::*` static methods), plus additional proprietary DLLs for assets and 3D (`GraphicData.dll`, `Role3D.dll`, `RoleView.dll`, `GameData.dll`).

Windows specificity comes from:
- Win32 windowing/event loop (`USER32`, MFC `CWnd` usage)
- GDI utilities (`GDI32`) for bitmaps/fonts/regions
- DirectInput (`DINPUT8`)
- WinMM timing (`timeGetTime`, `timeSetEvent`)
- Device-loss semantics exposed through `graphic.dll` (`IfDeviceLost`, `ResetDevice`, `Flip`, etc.)

The original client’s rendering and UI behavior is a product of:
1) Win32/MFC windowing + message processing,
2) `graphic.dll` device lifecycle + draw primitives,
3) `RoleView.dll` / `Role3D.dll` visual objects + effects,
4) data-driven resource lookup via `GraphicData.dll` / `GameData.dll`.

---

## External Engine / DLL Boundaries (Observed)
Strings in the binary reference these external modules:
- `graphic.dll` (primary render + text + sprite/bitmap primitives)
- `GraphicData.dll` (dataset queries)
- `Role3D.dll` (3D object/effect creation)
- `RoleView.dll` (creates “role view” objects used for rendering entities/effects)
- `GameData.dll` (`RoleDataQuery`, etc.)
- `NDSound.dll` (DX* sound wrappers)
- `Assist.dll` (monitor manager)
- `DINPUT8.dll` (DirectInput)
- `MFC42.DLL` (MFC app/UI framework)

### Key imported APIs from proprietary rendering stack
From `graphic.dll` imports (non-exhaustive but representative):
- `CMyBitmap::Init3DEx(HWND, width, height, ...)`
- `CMyBitmap::Begin3D()`, `CMyBitmap::End3D()`
- `CMyBitmap::Flip(RECT*, RECT*, HWND*)`
- `CMyBitmap::ClearBuffer(...)`
- `CMyBitmap::IfDeviceLost()`, `CMyBitmap::ResetDevice()`
- `CMyBitmap::GameFontCreate()`, `CMyBitmap::GetDefaultFontName()`
- `CMyBitmap::ShowStringW/ShowStringCommon`, `CalcuTextExtent(W)`, etc.
- `CMyBitmap::PrepareSprite()`, `ShowBlock`, `ShowRect`, `ShowLine` …
- `CMyBitmap::GameCameraBuild/Destroy/Set/GetPos`
- `CMyBitmap::ChangeDisplayResolution`, `GetScreenWidth/Height`, `ScreenShot`

From `GraphicData.dll`:
- `GameDataSetQuery`, `GameDataSetDestroy`

From `Role3D.dll`:
- `Simple3DObjCreate`, `Game3DEffectCreate`, `LimitGame3DEffectLevel`

From `RoleView.dll`:
- `RoleViewCreate` (central factory used by entity render/effects paths)

From `GameData.dll`:
- `RoleDataQuery`, `RoleDataDestroy`

---

## Windows-Specific Dependencies (Observed)

### Windowing + message loop
Imports include `PeekMessageW`, `GetMessageW`, `TranslateMessage`, `DispatchMessageW`, `CreateWindowExW`, `BeginPaint/EndPaint`, and heavy use of Win32 window state APIs (`GetClientRect`, `SetCapture`, `GetFocus`, etc.).

The frame loop is implemented inside an MFC dialog method (see below), and relies on:
- `GetTickCount` and `timeGetTime` for scheduling and time deltas
- device-lost polling via `CMyBitmap::IfDeviceLost`

### GDI usage
Imports include `CreateDIBSection`, `BitBlt`, `CreateFontA`, region APIs (`CreateRectRgn`, `CombineRgn`, etc.). This strongly suggests parts of UI/bitmap/text may go through GDI (either directly or within `graphic.dll`).

### Input
`DirectInput8Create` is imported from `DINPUT8`. There are also Win32 `mouse_event`, `keybd_event`, `GetKeyboardState`, etc.

### Timing
`timeGetTime` and `timeSetEvent` from `WINMM` are imported and used. These imply the client expects millisecond-resolution time sources and possibly multimedia timer callbacks.

### Audio
Audio is mediated by `NDSound.dll` exports like `_DXPlaySound`, `_DXSetVolume`, `_DXProcessSound`, etc.  
RE verification in `Rendering/ndsound_dll/` confirms DirectSound-style buffer control semantics (volume in `[-5000, 0]` dB range, positional attenuation/pan updates, replay/loop handling in per-frame `_DXProcessSound@8`).

---

## Verified Call-Sites / Flows (Decompiled)

### 1) 3D + font initialization uses HWND (`graphic.dll`)
Function `Exe_GfxInit_CreateFonts` (`0x66DC5A`) shows init is HWND-based and includes font creation:
```c
dword_96AB2C = hwnd;
if (!CMyBitmap::Init3DEx(hwnd, width, height, 1, 1u) || !CMyBitmap::GameFontCreate())
  return 0;
```
This is a hard Windows dependency (HWND), and implies the original “engine” controls swap-chain/device creation.

### 2) Main per-frame loop in `CMyShellDlg_RunFrameTick` (`0x5DCFAA`, MFC dialog)
`CMyShellDlg_RunFrameTick` behaves like a central “tick + render” driver:
- optionally processes network: `CNetMsg__ProcessMsg(...)`
- polls device loss: `CMyBitmap::IfDeviceLost()`
  - on state `2`: triggers reset path and calls `CMyBitmap::ResetDevice()`
- clears frame: `CMyBitmap::ClearBuffer(1, 0, 0xFF000000)`
- updates numerous managers (map, UI subsystems, movies, etc.)

This function is the best “anchor” for:
- determining frame pacing/ticks and ordering
- locating where UI draw happens relative to world draw
- identifying implicit assumptions about resource lifetime and draw ordering

### 2.1) Verified world-frame caller chain (map -> role -> screen effects)
BNinja verification (Conquer.exe.bndb) confirms the world-frame chain anchored at `CMyShellDlg_RunFrameTick` (`0x5DCFAA`):

| Stage | Caller site | Callee | Verified behavior |
|---|---:|---|---|
| World tick stage | `0x5DD0CC` | `CGameMap_TickComponentsAndProcessScreenEffects` (`0x61D415`) | Iterates map components and dispatches component virtual `+0x8` callback (`0x61D496`), then runs `CGameMap_ProcessScreenEffects` (`0x61D521`) |
| World render dispatch | `0x5DD0D9` | `Exe_TickMapProjectionAndDispatchMapRender` (`0x5ACAC3`) | Updates projection state, processes queued earthquake effects, clears cached cursor-sample flag, then conditionally dispatches `CGameMap_RenderComponentsAndShowScreenEffects` (`0x5ACB88`) |
| HUD/sound side pass | `0x5DD0FB` | `CMyShellDlg_RenderHudAndProcessSound` (`0x5ACB8F`) | Separate dialog-level HUD/debug/sound pass; distinct from map component render pass |

Inside `CGameMap_TickComponentsAndProcessScreenEffects` (`0x61D415`):
- component deque traversal uses:
  - `StdDequePtr_GetElementCount(map+0x14, map+0x04)` at `0x61D464`
  - `StdDequePtr_AdvanceIteratorByOffset(&iter, index)` at `0x61D484`
- dispatch loop is index-based (`0..count-1`) with null check before callback (`0x61D48C`..`0x61D490`)
- map component tick callback is virtual `+0x8` (`0x61D496`) with constant arg `0` (`push 0` at `0x61D494`)

Inside `Exe_TickMapProjectionAndDispatchMapRender` (`0x5ACAC3`):
- hero-centered projection input is built from CHero vfunc `+0x10` output plus half-screen offsets (`0x5ACAD9`..`0x5ACAF7`)
  - vfunc target resolved from `data_86AD08 + 0x10 = 0x65185D`:
    `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor`
  - function body at `0x65185D` copies `hero+0x350/+0x354` into the output pair
  - verified writer split for that pair:
    - `Role_SetTilePositionAndProjectScreenCoordinates` (`0x6E4C79`) writes the committed world-entry/spawn value
      into `role+0x350/+0x354`
    - `Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`) does **not** write `role+0x350/+0x354`;
      it stages the next projected point into `role+0x19C/+0x1A0`
    - `Role_RecomputeCoordinateGateCacheFromProjectedPosition` (`0x64E9A5`) later commits staged
      `role+0x19C/+0x1A0 -> role+0x350/+0x354`
  - implication for managed parity:
    - projecting the local hero tile is exact for initial world-entry centering
    - it must remain a fallback only and must not override a verified command snapshot once
      `RoleField350/354` are available
  - first-world managed verification now covers the full startup data chain into this fallback:
    - `MsgUserInfo1006` + server enter-map `0x4A` populate the local-hero world state
    - the first map tick materializes a projected local-hero snapshot
    - the first projection tick writes `map+0x48/+0x4C`
    - the first type-1 render pass submits that local hero into the managed RoleView scene-object store
    - the fresh type-1 body-appearance load requests for that local hero are now pinned as:
      - `body` -> `bodyAppearanceSourceId * 1_000_000`
      - `mix_body` -> `bodyAppearanceSourceId * 1_000_000`
      - `mix2_body` -> `bodyAppearanceSourceId * 1_000_000`
      - attachment `v_mount -> mount`
      - in the clean 5517 asset tables for the live local-hero source (`2_000_000`):
        - `body` resolves
        - `mix_body` resolves
        - `mix2_body` does not resolve
    - the local-hero startup `AppearanceRefreshSourceId` is `0x0002`, and clean `ini/TransForm.ini`
      has no section `[2]`, so this bootstrap path does not currently add transform-driven armet/weapon/mount/misc loads
    - managed scene-object state was also missing the transform-driven misc source from RoleView key `9`; that is now preserved
  - consequence:
    - if the live diagnostics now show correct tile/projected/projection-center values, then the remaining
      “sky only / no visible hero” mismatch is no longer explained by a missing startup center producer
    - the remaining startup visual blocker is downstream of scene-object bootstrap: the missing `I3DRole` load/bind/render consumer
  - live movement commit cadence is separate from the first-frame bootstrap path:
    - immediate packet ingress uses role vtable `+0x80` -> `Role_TryApplyIncomingActionInfoWithConditionalStateSync`
      (`0x65C079`)
    - per-tick role update uses `Role_TickCommandStateAndDispatchPlayback` (`0x6725ED`)
      and its oldest-queued-entry branch calls `Role_TryApplyIncomingActionInfo` directly at `0x67268D`
    - managed correction now covers the verified startup/local-hero half of this seam:
      - local-hero tile state seeds staged `RoleField19C/1A0`
      - missing committed `RoleField350/354` is seeded from that tile projection before the first dequeue/apply
      - the `0x65C079` gate set now triggers the `0x64E9A5`-equivalent staged-position commit and coordinate-gate recompute
      - `map+0x40/+0x44` are copied into command snapshot state every frame instead of remaining zero
    - remaining scrolling parity work is downstream of that fix: ongoing role-position advancement beyond the startup/local-hero seed
- keyboard state is read once (`GetKeyboardState` at `0x5ACB01`)
- keyboard bytes used by this function are:
  - `keyboardState[0x12]` (`VK_MENU`, read from stack slot `-0xF6` at `0x5ACB07`)
  - `keyboardState[0x10]` (`VK_SHIFT`, read from stack slot `-0xF8` at `0x5ACB6F`)
- projection center arguments are computed as:
  - `centerX = heroVf10OutX + (GetScreenWidth() / 2)`
  - `centerY = heroVf10OutY + (GetScreenHeight() / 2)`
- `allowEdgeScroll` branch is selected from:
  - cached key byte at stack `-0xF6` (`0x5ACB07`..`0x5ACB11`), and
  - `Role_HasStatusFlag(..., 0x3C)` gate (`0x5ACB1C`..`0x5ACB2C`)
- equivalent verified boolean form:
  - `allowEdgeScroll = (vkMenuHighBitSet && g_projectionEdgeScrollEnabled != 0 && !Role_HasStatusFlag(hero, 0x3C))`
- projection/camera update call:
  - `CGameMap_UpdateProjectionAndCameraFromScreenCenter(map, centerX, centerY, allowEdgeScroll, 1)` at `0x5ACB4A`
- earthquake effect queue processing:
  - `CEarthQuakeEffectMgr_ProcessQueuedEffects(CEarthQuakeEffectMgr_GetSingletonPtr())` at `0x5ACB4F`/`0x5ACB56`
- cached cursor-sample flag clear:
  - `Exe_ClearCachedCursorSampleFlag()` at `0x5ACB5B`
- conditional map render dispatch:
  - if `arg1 == 0`, call `CGameMap_RenderComponentsAndShowScreenEffects` (`0x5ACB88`)
  - render-pass flag passed to map render is selected by global `g_mapRenderPassOverrideFlag` (`data_958644`) or cached key byte at stack `-0xF8` (`0x5ACB66`..`0x5ACB81`)
  - equivalent verified boolean form:
    - `renderPassFlag = (g_mapRenderPassOverrideFlag != 0 || vkShiftHighBitSet) ? 1 : 0`
- verified producer writes for these globals are in `CMyShellDlg_DispatchCommandCode` (`0x5B29E2`):
  - `g_projectionEdgeScrollEnabled` (`data_958640`) write at `0x5B3AB8`
    from `jump_table_5B80FC[0x18]` block start `0x5B3AB3`
  - `g_mapRenderPassOverrideFlag` (`data_958644`) write at `0x5B4542`
    from `jump_table_5B80FC[0x47]` block start `0x5B453F`

Current managed runtime correction from this slice:
- the non-playback world scene no longer replaces the real startup ingress context with a no-op network stage
  and dead command snapshot source after bootstrap
- this does not complete scrolling parity by itself, but it removes a verified architectural blocker:
  native keeps world packet ingress live after the world-frame gate flips, and managed must do the same
- normal runtime command-state dequeue/apply is now wired back into the map tick stage even when no
  playback host exists
- the projection snapshot bridge now distinguishes:
  - "a command block was applied", from
  - "the committed projection-center pair (`role+0x350/+0x354`) is actually valid"
- consequence for managed parity:
  - incoming command blocks can be applied in normal runtime without forcing the projection center
    back to `(0,0)` when the committed path-cursor pair has not yet been written by verified movement semantics
- additional managed correction now landed:
  - first world-frame map tick seeds the committed/staged path-cursor pair from authoritative local-hero tile state
  - dequeue/apply mirrors the verified `0x65C079` conditional pre-apply commit into `RoleField350/354`
  - coordinate-gate cache recompute now uses the verified inverse tile-projection math against `map+0x40/+0x44`
- a new post-type1 role-visual asset-plan capture stage now consumes the submitted player RoleView scene objects
  after component render dispatch and resolves the currently verified startup part-load requests against the
  clean 5517 role-part tables
  - this is intentionally not a guessed renderer
  - it is a verified downstream consumer that tells us exactly which native startup parts currently resolve
    and which still stop before the missing `I3DRole` load/bind/render contract

Verified clean-data newbie-map backdrop facts:
- `map/map/newbie.7z`
  - first cell grid = `132 x 132`
  - positioned-overlay outer entry count = `1`
  - that single outer entry is record type `4`
  - it contains exactly one child entry: child type `8`
  - child type `8` puzzle path = `map\\puzzle\\newbiebg.pul`
- `map/puzzle/newbie.pul`
  - format `PUZZLE`
  - texture path `ani\\newbie.ani`
  - tile grid `15 x 9`
- `map/puzzle/newbiebg.pul`
  - format `PUZZLE`
  - texture path `ani\\newbie.ani`
  - tile grid `6 x 6`
- implication:
  - the currently visible sky/farmland backdrop in newbie is the positioned overlay puzzle
    `newbiebg.pul`
  - it is not the type-1 ground puzzle `newbie.pul`
  - therefore any remaining mismatch between the visible backdrop framing and the player/camera state
    must be reasoned about with both sources present, not by treating the type-1 bitmap as the whole scene

`CGameMap_UpdateProjectionAndCameraFromScreenCenter` (`0x61E0E7`) helper chain (verified):
- edge-scroll cursor region logic (`allowEdgeScroll != 0`):
  - cursor sample from `Exe_GetCachedCursorSample` (`0x61E0FA`)
  - near-edge updates on map offsets:
    - `map+0x54` (X) and `map+0x58` (Y)
    - thresholds:
      - top/left `<= 0x78`
      - bottom `>= GetScreenHeight() - 0xAA`
      - right `>= GetScreenWidth() - 0x78`
    - delta formula uses `/ 0x14` and `±6` (`0x61E115..0x61E179`)
- clamp block (`enforceProjectionClamp != 0`):
  - divisor helper `CGameMap_GetProjectionClampScaleDivisor` (`0x61EDC3`) = `(map+0x154 * map+0x140) / 100`
  - X clamp (`map+0x54`) to `±(data_93C6C0 * 0x164 / divisor)` (`0x61E182..0x61E1A8`)
  - Y clamp (`map+0x58`) to:
    - upper: `+(data_93C6C0 * 0xC0 / divisor)` (`0x61E1AA..0x61E1C6`)
    - lower: `-(data_93C6C0 * 0xAC / divisor)` (`0x61E1C9..0x61E1E7`)
- timed projection effects called in-order:
  - `CGameMap_ApplyProjectionOffsetOscillation` (`0x61FB26`)
  - `CGameMap_ApplyProjectionScaleOscillation` (`0x61FB93`)
  - `CGameMap_ApplyProjectionColorBlend` (`0x61FC13`)
- projection center commit:
  - provisional center = `(screenCenterX + map+0x54, screenCenterY + map+0x58)`
  - stores to `map+0x48/+0x4C` at `0x61E300`/`0x61E307`
  - camera update call:
    `CGameMap_UpdateGameCameraFromProjectionCenter(map, map+0x48, map+0x4C)` at `0x61E30D`

`CGameMap_UpdateGameCameraFromProjectionCenter` (`0x61E6C6`) verified output:
- reads origin/base via:
  - `CGameMap_GetGroundEntityLayerScaledBitmapExtents` (`0x61E408`)
  - `CGameMap_GetProjectionBaseCenterFromOffsets` (`0x61E375`)
- `CGameMap_GetGroundEntityLayerScaledBitmapExtents` verified ground-puzzle chain:
  - `CGameMap_FindFirstComponentWithTypeCode1` (`0x61E409`)
  - `CMapGroundEntityLayer_GetGroundBitmapDimensions` (`0x637803`) at `0x61E41D`
  - `CMapGroundEntityLayer_GetGroundBitmapScaleFactor` (`0x637824`) at `0x61E424`
  - `CMapGroundEntityLayer_GetGroundBitmapScaleDivisor` (`0x63A95B`) at `0x61E42E`
  - `.pul` path inside the ground/entity-layer component reads width/height from
    `CMapPuzzleBitmap_GetScaledBitmapDimensions` (`0x63A7DC`) and raw scale from
    `CMapGroundEntityLayer_GetGroundBitmapScaleFactorRaw` (`0x638F03`)
  - with divisor `0x100`, the effective extents are the loaded ground-puzzle bitmap pixel size
    (`tileCountX * 0x100`, `tileCountY * 0x100`), not the current window size
- computes camera set arguments:
  - `camX = (GetScreenWidth() * 0.5f) + (projectionCenterX - originX)`
  - `camY = (GetScreenHeight() * 0.5f) + (projectionCenterY - originY)`
  - `camZ = -1000.0f`
  - mode `3`
- dispatch:
  - `CMyBitmap::GameCameraSet(camX, camY, -1000.0f, 3)` at `0x61E73D`

BNinja rename set applied in this slice (Conquer.exe.bndb):

| Address | Semantic Name |
|---:|---|
| `0x61E0E7` | `CGameMap_UpdateProjectionAndCameraFromScreenCenter` |
| `0x61E6C6` | `CGameMap_UpdateGameCameraFromProjectionCenter` |
| `0x61EDC3` | `CGameMap_GetProjectionClampScaleDivisor` |
| `0x61EDD7` | `CGameMap_SetProjectionScaleAndViewport` |
| `0x61E345` | `CGameMap_GetProjectionCenterWithOffset` |
| `0x61E375` | `CGameMap_GetProjectionBaseCenterFromOffsets` |
| `0x61E3D8` | `CGameMap_GetComponentRenderProjectionOffset` |
| `0x61E408` | `CGameMap_GetGroundEntityLayerScaledBitmapExtents` |
| `0x61FB26` | `CGameMap_ApplyProjectionOffsetOscillation` |
| `0x61FB93` | `CGameMap_ApplyProjectionScaleOscillation` |
| `0x61FC13` | `CGameMap_ApplyProjectionColorBlend` |
| `0x63029A` | `StdDequePtr_GetElementCount` |
| `0x637803` | `CMapGroundEntityLayer_GetGroundBitmapDimensions` |
| `0x637824` | `CMapGroundEntityLayer_GetGroundBitmapScaleFactor` |
| `0x638E9F` | `CMapGroundEntityLayer_GetGroundBitmapWidthPixels` |
| `0x638EC8` | `CMapGroundEntityLayer_GetGroundBitmapHeightPixels` |
| `0x638F03` | `CMapGroundEntityLayer_GetGroundBitmapScaleFactorRaw` |
| `0x63A95B` | `CMapGroundEntityLayer_GetGroundBitmapScaleDivisor` |
| `0x637DFF` | `StdDequePtr_AdvanceIteratorByOffset` |
| `0x65185D` | `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor` |
| `0x5B29E2` | `CMyShellDlg_DispatchCommandCode` |
| `0x5DF869` | `CEarthQuakeEffectMgr_GetSingletonPtr` |
| `0x623D5B` | `CEarthQuakeEffectMgr_Initialize` |

### 2.2) Verified scenery-component activation gap (current rendering blocker)
Follow-up decomp on the same world-frame path shows the remaining visual gap is not the projection-base math anymore; it is the scenery component active render path.

Verified behavior in `CMapSceneryComponent_*`:
- `CMapSceneryComponent_PerFrameTick` (`0x63537B`) clears the active render deque rooted at `this+0x74/+0x78` via `MotionPathNodeDeque_ClearAndResetCursors` (`0x6353A9`).
- The same function iterates the loaded subcomponent deque rooted at `this+0x34/+0x38` (`0x6353B5`) and rebuilds the active render deque through the helper at `0x6355E7` plus child-driven calls to `CGameMap_NotifySceneryComponentSubcomponentUpdated` (`0x61E74B`).
- `CMapSceneryComponent_Render` (`0x6352F4`) renders only the rebuilt active deque at `this+0x74/+0x78`; it does not render the loaded deque directly.

Verified subtype consequences for the current sky-island map:
- subtype `0x01` owner objects are still render-noop; their nested external objects are the real renderables.
- subtype `0x01` insertion also feeds the separate ground/entity-layer tile-attachment cache path:
  `CMapSceneryComponent_InsertLoadedSubcomponent -> CMapSceneryComponent_AttachTerrainObjectGroupToTileGrid`
  writes per-cell attachment records into the map tile tail-link chain using the first-cell-grid `cell+0x04`
  word as the fallback surface-height source.
- the later ground/entity-layer consumer boundary is now pinned, but it is the non-`.pul` terrain-cache mode only:
  - `CMapGroundEntityLayer_LoadGroundPuzzleBitmapFromPath` selects `.pul` puzzle-bitmap mode vs non-`.pul`
    terrain-cache mode
  - `CMapGroundEntityLayer_Render` chooses exactly one branch:
    - `.pul` -> `CMapPuzzleBitmap_RenderAtOffset`
    - non-`.pul` -> `CMapGroundEntityLayer_RenderTileAttachedTerrainObjects`
  - the tile-attached cache rebuild chain is
    `CMapGroundEntityLayerComponent_PerFrameTick -> CMapGroundEntityLayer_RebuildTileAttachedTerrainObjectRenderCache
    -> CMapGroundEntityLayer_BuildTileAttachedTerrainObjectTargetBitmapCache`, with visible enumeration/draw in
    `CMapGroundEntityLayer_RenderTileAttachedTerrainObjects`
- the cached target-bitmap compositor is now partially deobfuscated:
  - each occupied ground/entity-layer tile bucket gets a `256 x 256` `TargetBmp`
  - the cache filler is `CMapGroundEntityLayer_RasterizeTileAttachmentTargetBitmap`
  - that filler clears the target and stamps a `4 x 4` quarter-tile mosaic into it
  - quarter-tile content splits into:
    - `CMapGroundEntityLayer_DrawQuarterTileDirectFrameIntoTargetBitmap`
    - `CMapGroundEntityLayer_DrawQuarterTileTriangleCompositeIntoTargetBitmap`
  - quarter-tile selection comes from packed metadata words returned by
    `CMapGroundEntityLayer_TryGetQuarterTileMetadataWord`
- the remaining unported map-side gap in the terrain-cache branch is now narrower:
  the missing producer is the metadata-tree build path that feeds those packed quarter-tile words, not the
  existence of tile attachments themselves.
- practical correction for newbie:
  - `map/puzzle/newbie.pul` is `.pul` puzzle-bitmap mode
  - so the terrain-cache branch above is not the current leading explanation for the startup hero/platform mismatch
- terrain objects have a real ANI render callback: `CMapTerrainObject_Render` (`0x64450F`).
- the external-object list fields at `+0x14/+0x18` are render offsets, not tile coordinates:
  - loader call is `CMapTerrainObject_SetRenderOffset` (`0x63AE41`)
  - render adds those fields after projecting the propagated pair from `+0x0C/+0x10` (`0x6445C4..0x6445D3`)
- **CORRECTION.** An earlier revision of this section said subtype `0x04` entries are "force-inserted
  into the active render deque by the main scenery tick after their tick callback". That was wrong,
  and it was wrong in the same way for every subtype. The per-child flag `CMapSceneryComponent_PerFrameTick`
  checks is a **remove/destroy** signal, not an insert signal — see the corrected dispatch table under
  "The per-frame tick reaps, it never inserts" below. Subtype `0x04` is not force-inserted at all; it
  self-registers from inside its own tick.
- subtype `0x04` animated-sprite positioning is now fully split:
  - `this+0x0C/+0x10` are tile coordinates
  - child `vtable+0x10` resolves to `CMapPositionedObj_GetProjectedScreenCoordinates` (`0x64B9A1`), which projects those tile coordinates to absolute screen space each frame
  - `this+0x34/+0x38` are depth-span tiles returned by child `vtable+0x1C`, used by `CMapSceneryComponent_ReorderSubcomponentForDepth`
  - consequence: a managed port that treats payload `+0x34/+0x38` as a render-position pair will misplace or drop the newbie platform even when ANI assets resolve correctly
- subtype `0x0A` entries use a mixed model:
  - tick writes an out-flag checked by the main scenery tick (`0x6354A0..0x6354D6`) — that flag is the
    effect's update state code, and a nonzero value means the effect has FINISHED and is to be torn down
  - tick separately calls `CGameMap_NotifySceneryComponentSubcomponentUpdated(this)` (`0x63B6AF`) to
    self-register for rendering
  - the two are mutually exclusive: `NotifyUpdated` runs only when the state code is `0`, and the flag is
    suppressed to `0` whenever `this+0x1C` is `0`

#### The per-frame tick reaps, it never inserts

`CMapSceneryComponent_PerFrameTick` (`0x63537B`) clears the active deque at `+0x74`, snapshots the
loaded deque at `+0x34` (`sub_641D2C`), then per child reads `CMapObj::GetObjType` (`vtable+0x0C`) and
dispatches:

| Type code | Tick argument | Removal check |
| --- | --- | --- |
| `0x01` | `nullptr` | none |
| `0x04` | `CHero` singleton `vtable+0x10` output pair | none |
| `<= 0x05`, `<= 0x07` | the component tick argument | none |
| `0x09` | `0` | `child[0x28] != 0` |
| `0x0A`, `0x0E`, `0x11` | `&flag` | `flag != 0` |
| `0x13` | the component tick argument | `sub_733041(child) != 0` |
| default | `nullptr` | none |

"Removal" is `CMapSceneryComponent_DetachAndRemoveSubcomponent` (`0x6355E7`):

- `CMapSceneryComponent_RemoveFromActiveRenderDequeAndType2Parents` (`0x635710`) erases the child from
  the active deque at `+0x74`, then — only when the child's own type code is not `2` — walks that deque
  and calls `CMapSceneryType2Subcomponent_RemoveChild` (`0x644D83`) on every type-`2` entry, erasing the
  child from that entry's `+0x88` child list;
- `sub_6415A6(this + 0x34)` removes it from the loaded-subcomponent index;
- type `0x01` then runs the terrain-group teardown, type `0x11` the `+0x0C` list teardown.

`sub_6366FA`, the tail of that erase, is a plain `std::deque::erase(first, last)` and is now named
`StdDequePtr_EraseRange`.

So **nothing reaches the active render deque by a decision the component tick makes**. Every entry
self-registers through `CGameMap_NotifySceneryComponentSubcomponentUpdated` during its own tick. For
subtype `0x04` that call is at `0x645625`, gated on a *second* on-screen test that reads the stored tile
pair `this+0x0C/+0x10` (the first test uses the tile pair reprojected from the render offsets).

Practical parity consequence:
- a managed scenery runtime that renders the loaded list directly can never match native object visibility/order.
- a managed scenery runtime that treats the tile-attached terrain-object path as “draw the terrain-object list entries directly”
  will still diverge from native, because native is drawing cached quarter-tile composites rather than the raw scene entries.

Current verified next gap after this slice:
- exact depth/nesting order inside the active render deque still depends on `CMapSceneryComponent_ReorderSubcomponentForDepth` (`0x635AE6`), `CGameMap_GetType3SubcomponentDepthSpanOrDefault` (`0x61E0BC`), and the helper at `0x6355E7`.
- that is the remaining parity boundary for final object ordering once the external objects themselves are active and drawable.

#### Progress on that gap

`CGameMap_GetType3SubcomponentDepthSpanOrDefault` (`0x61E0BC`) is fully decoded:

```text
GetType3SubcomponentDepthSpanOrDefault(outPair, subcomponent)   // __stdcall, retn 8
    if (subcomponent == 0) { outPair[0] = 1; outPair[1] = 1; }
    else subcomponent->vtable[0x1C](outPair);
```

A null child yields a default span of **(1, 1)**, not zero. Treating a missing
child as zero-span would order it differently from native.

`CMapSceneryComponent_ReorderSubcomponentForDepth` (`0x635AE6`) is partially
decoded; the Binary Ninja function comment carries the detail. Established:

- a null subcomponent inserts nothing;
- it operates on the **active** deque at `this+0x74`, never the loaded deque;
- it branches on the incoming subcomponent's `vtable+0x0C` subtype.

The non-`2` path is **parenting, not insertion**. It scans for the first
subtype-`2` entry whose footprint claims the incoming coordinate pair
(`sub_644E0E`), and on a hit attaches the incoming to that entry
(`sub_644BA9`) without touching the deque at all. When no entry claims it,
`0x635BC9` sets a `-1` sentinel and jumps into `label_635BCF` — so an unclaimed
non-`2` subcomponent takes the **same** depth-ordered insertion as a `2`.

The depth path orders by a two-axis footprint overlap test. Per candidate it
reads the `vtable+0x14` coordinate pair and the depth span of both the existing
entry and the incoming one, then:

```text
axis-A overlap := (inA - spanA_in - enA + 1) <= 0 && (enA - spanA_en - inA + 1) <= 0   // 0x635C79
axis-B overlap := (inB - spanB_in - enB + 1) <= 0 && (enB - spanB_en - inB + 1) <= 0   // 0x635D06
```

The two are mutually exclusive, A tested first. **Overlap on one axis is
resolved by the other axis** — overlap on A compares `inB < enB`, overlap on B
compares `inA < enA`. Smaller means the incoming precedes the entry and a
backward scan runs; otherwise a forward scan runs. Both scans compare the sum
`(a + b)` of each neighbour's coordinate pair against the incoming's, and both
carry a running best index separate from the pending insert index.

The container primitives underneath are now all decoded and renamed in Binary
Ninja:

| Address | Name | Meaning |
| --- | --- | --- |
| `0x62141F` | `StdDequePtr_CopyBeginIterator` | block-copies the 4-dword begin iterator |
| `0x621546` | `StdDequePtr_IteratorPlusOffset` | `iterator + n` |
| `0x636331` | `StdDequePtr_Insert` | `insert(pos, value)`, front/back fast paths |
| `0x636306` | `StdDequePtr_PushBack` | `push_back`; tail `+0x10`, block end `+0x18` |

A deque's own first four dwords **are** its begin iterator, which is why
`CopyBeginIterator` just block-copies 16 bytes off the deque object.

That resolves the tail at `0x635F10`. It is **not** two behaviours: on the `-1`
sentinel nothing claimed the incoming and it is a plain `PushBack`; otherwise
`0x635F21` tests `chosen < count-1` and either inserts at `begin + chosen + 1`
or falls to `PushBack`, which at index `count-1` *is* `begin + chosen + 1`. Both
arms mean **insert immediately after the chosen index**. The earlier reading of
"a different insert helper for the last slot" was an ordinary end-of-container
fast path misread as a distinct rule. The other insert sites (`0x635E0C`,
`0x635EFC`, `0x635F85`) build `begin + pendingIndex` and so insert *before* that
index.

#### The depth comparator, fully proven

`CMapSceneryType2Subcomponent_InsertChildForDepth` (`0x644BA9`) is the nested
counterpart of the deque reorder — same rule, applied to a type-2 entry's own
child list at `+0x88` — and it states the ordering far more plainly than
`0x635AE6` does. It is what the reorder tail-calls once
`CMapSceneryType2Subcomponent_FootprintContainsTile` (`0x644E0E`) says the
incoming falls inside that entry's footprint.

`0x644E0E` also settles the coordinate convention:

```text
return a <= baseA && b <= baseB && a > baseA - spanA && b > baseB - spanB;
```

The anchor (`+0x0C`, `+0x10`) is the **far corner** and the span (`+0x1C`,
`+0x20`) extends backwards, so a subcomponent covers the half-open interval
`(anchor - span, anchor]` per axis. Every `(x - spanX - y + 1) <= 0` test in
both routines is that same interval overlap written out.

The complete comparator, "does the incoming draw before the existing entry":

```text
if      (overlap on X)  return inY < enY;      // 0x644C78
else if (overlap on Y)  return inX < enX;      // 0x644C94
else                    return inX + inY < enX + enY;   // 0x644CA5
```

The third case is the one `0x635AE6` only hinted at through the `(a + b)` sum
comparisons in its forward and backward scans. `0x644BA9`'s own insertion is a
plain forward walk stopping at the first entry the incoming precedes, appending
at `0x644CD0` when it precedes none.

Implemented in `Conquer.Map.MapSceneryDepthOrdering`, with the footprint carried
by `MapSceneryDepthFootprint`.

#### Scan termination and the axis mapping

Both were settled from disassembly rather than HLIL.

The scans are **not re-entrant**. `0x635E1D` tests `i < count` and returns, and
every backward insert reaches it with `i` still a valid candidate index, so the
function always returns there. `0x635E29` is reachable only from `0x635BF1`
with an empty deque, or from `0x635F0D` with the `-1` sentinel. HLIL rendered it
as re-entrant because `[ebp-0x34]` has two lifetimes: the insert index in the
backward branches, and the second element of the neighbour's coordinate pair in
the forward ones.

Full deque shape, per candidate whose footprint overlaps the incoming:

| Case | Behaviour |
| --- | --- |
| incoming precedes the candidate | backward scan, settles a position and returns |
| incoming follows the candidate | forward scan, advances a running best index only; candidate walk continues, tail inserts after best |
| nothing overlaps at all | order by coordinate sum alone (`0x635E29`) |

**Axis mapping, proven.** `+0x0C` is tile X and `+0x10` is tile Y.
`CMapScenerySubcomponent_SetTileCoordinatesAndProjectScreenOffset` (`0x63AE52`)
passes its two tile arguments straight into `Map_ProjectTileToScreenCoordinates`
(`0x61D861`) and then into `CMapPositionedObj_SetTileCoordinates`
(`0x6322FD`) in the same order, and the projection is

```text
screenX = (a - b) * 32 + map[0x40]
screenY = (a + b) * 16 + map[0x44]
```

the standard isometric mapping for a 64×32 tile, so the first coordinate is X.
This matters because the comparator resolves an overlap on one axis *using the
other*, so a swapped mapping would invert the draw order.

Implemented in `Conquer.Map.MapSceneryDepthOrdering` as `DrawsBefore`,
`AxisFootprintsOverlap`, `FindOrderedInsertIndex` (the `0x644BA9` walk) and
`FindActiveRenderInsertIndex` (the `0x635AE6` walk).

Still outstanding: `Role3DClientSceneMapSceneryComponent.NotifyUpdated` appends
in tick order and does not yet call the ordering, and the non-type-2 parenting
path has no managed counterpart.

#### What blocks the wiring

`IMapScenerySubcomponentRuntime` exposes only `TypeCode`, so the ordering has
nothing to read. Of the three implementers, only
`CMapSceneryAnimatedSpriteSubcomponent` carries `TileX`, `TileY` and the depth
spans. `CMapSceneryEffectSubcomponent` and `CMapScenery2DSoundEmitterSubcomponent`
model only the projection pair at `+0x14`/`+0x18`, derived *from* a screen point —
that is a different pair from the `+0x0C`/`+0x10` the ordering reads.

**The setter is generic, and its meaning is class-dependent.**
`CMapPositionedObj_SetTileCoordinates` (`0x6322FD`) is a plain two-int store
into `+0x0C`/`+0x10`, and callers disagree about what those ints mean:

| Caller | What it stores |
| --- | --- |
| `0x63AE52` | its own tile arguments — genuine tile X/Y, the case the ordering reads |
| `sub_63AB04` (`0x63AD8C`, `0x63AC8F`, `0x63AB98`) | the **output** of `Map_ProjectTileToScreenCoordinates`, i.e. screen coordinates, into a different child object at `parent+0x44` |

So a subcomponent's `+0x0C`/`+0x10` cannot be assumed to be tile space without
knowing which loader populated it.

The remaining writers are now decoded, and both store **screen** coordinates:
`sub_74F2BD` (`0x74F337`) passes the projection's output, and `sub_7C7CFE`
(`0x7C7DBF`, `0x7C7E0D`) passes pairs from `vtable+0x30` and `vtable+0x10`. Both
push their object into `map+0xD4`, and both build it with `sub_6323F1` — a
different class from the scenery subcomponents in the component's deques.

`0x63AE52`, the only genuine tile-coordinate writer, has **no code references**:
its single data reference at `0x86A368` is a vtable slot, so it is a virtual
override rather than a called helper.

This resolves the question in the deque's favour. Screen coordinates only ever
reach `sub_6323F1` products in `map+0xD4`; members of the active render deque get
tile coordinates through the `0x63AE52` override. The ordering is tile space,
which is also the only reading consistent with the spans being tile counts.

**But the managed subtypes do not all have a tile footprint**, and this is a
property of the file format rather than a gap:

| Payload | Fields |
| --- | --- |
| Type04 animated sprite | `TileX`, `TileY`, `DepthSpanTilesX`, `DepthSpanTilesY` |
| Type0A effect | `InitialPointX`, … |
| Type0F 2D sound | `InitialSoundScreenX`, … |

Effect and sound carry screen points from file, matching the screen-coordinate
writers above. Only Type04 has a tile footprint, so only Type04 can participate
in tile-space depth ordering as a footprint owner.

**The `vtable+0x0C` code IS the map-file subcomponent type code.** An earlier
revision of this section claimed it was a separate, coarser classification. That
was wrong, and the correction matters because it changes what "type 2" means.

Verified by walking vtables. For the vtable based at `0x86A3A0` — identified by
the tile getter `0x6D1E51` at `+0x14` and the setter `0x6322FD` at `+0x18` — slot
`+0x0C` holds `CMapType3SubcomponentType0A_GetTypeCode` (`0x63BD65`). The family
is:

| Address | Name |
| --- | --- |
| `0x645804` | `CMapType3SubcomponentType04_GetTypeCode` |
| `0x63BD65` | `CMapType3SubcomponentType0A_GetTypeCode` |
| `0x645A1C` | `CMapType3SubcomponentType0F_GetTypeCode` |

So `== 2` at `0x635B18` and `0x635B58` means map-file subcomponent type code 2.
The vtable based at `0x86A350` returns `0x11` from its `+0x0C`, so type codes
beyond the three the managed loader handles (`0x04`, `0x0A`, `0x0F`) do exist.

**Type 2 is the footprint-owning, parenting subtype, and managed implements none
of it.** That reframes the wiring work: the ordering's parenting path has no
managed subject at all, and the deque path currently only ever sees `0x04`,
`0x0A` and `0x0F`. Of those only `0x04` carries a tile footprint.

#### Type 2 identified: the Type01 external object

The class is `CMapType3SubcomponentType01ExternalObject`, vtable at `0x86A5C4`
(slot 0 is its deleting destructor, `0x64447E`). Slot `+0x0C` there is
`0x63738B`, which is a bare `return 2`.

That thunk is COMDAT-folded across every class whose type code is 2, so its
current Binary Ninja name (`CGameMapComponentType2_GetTypeCode`) reflects only one
of its users and must not be renamed for a single class.

This also settles what the depth span physically *is*. `vtable+0x1C` — the slot
`CGameMap_GetType3SubcomponentDepthSpanOrDefault` calls — resolves on this class
to `CMapType3SubcomponentType01ExternalObject_GetPerCellMetadataGridDimensions`
(`0x6450D9`), paired with the setter at `0x6450C8`. **The depth span is the
external object's per-cell metadata grid dimensions**, i.e. how many tiles its
footprint covers per axis. Type04 has its own span pair via
`CMapType3SubcomponentType04_GetDepthSpanTiles` (`0x645642`).

This is the same "external objects" work §2.2 names as the active-render blocker,
so the depth ordering and that blocker are one problem, not two. The Type01
family already has named routines to build from:
`CMapType3SubcomponentType01_AppendLoadedExternalObject` (`0x63F19F`),
`CMapType3SubcomponentType01_ExternalObjectList_GrowAndPushBack` (`0x63F971`),
and `CMapType3SubcomponentType01ExternalObject_GetPerCellMetadataAt` (`0x644845`).

#### The external objects are the terrain objects, and managed already models them

`CMapType3SubcomponentType01_AppendLoadedExternalObject` (`0x63F19F`) has exactly
one caller: `CMapTerrainObjectGroup_LoadTerrainObjectListFromPath` (`0x63F362`).
So the Type01 external objects are the **terrain objects**, which managed already
loads through `CMapTerrainObjectGroup` and `CMapTerrainObjectListFromFileLoader`.

`CMapTerrainObjectGroup` implements `IMapScenerySubcomponentRuntime` with
`TypeCode => 0x01`, and `IMapTerrainObjectPerCellMetadataSourceRuntime` already
exposes precisely the two things the depth ordering reads:

| Native | Managed |
| --- | --- |
| `vtable+0x14`, anchor tile pair | `GetAnchorTileCoordinates(out anchorTileX, out anchorTileY)` |
| `vtable+0x1C`, depth span | `PerCellMetadataGridWidth` / `PerCellMetadataGridHeight` |

The group also propagates `anchor + AnchorTileOffsetX/Y` to each terrain object,
matching the per-object anchor native sets.

**The load path keeps external objects in the group.** `0x63F362` decodes to:

```text
f = fopen(path, "rb"); ClearLoadedTerrainObjectList(group)
fread(&count, 4, 1, f); store path at group+0x48
for i in 0 .. count-1:
    obj = new CMapTerrainObject(0xB0); CMapTerrainObject_Constructor(obj)
    CMapTerrainObject_CreateRefCountControlBlock(&cb, obj)
    CMapTerrainObject_LoadFromListFile(obj, f)
    cb->strongReferenceCount += 1
    CMapType3SubcomponentType01_AppendLoadedExternalObject(group, obj)
    SharedPtrControlBlock_DecrementStrongReference(cb)
group->vtable[0x18](group[3], group[4])
fclose(f)
```

A missing file logs through `Debug_LogMessageToDailyFileWithDedup` with the
original source path `F:\CQ2ClientRelease-42.0.1\3DGameMap\2DMapTerrainObj.cpp`,
which confirms the class name.

So loaded external objects go into the **group's own list**, never directly into
the scenery component's deque. The trailing `vtable[0x18]` call re-applies the
group's own anchor pair, which is the anchor propagation
`CMapTerrainObjectGroup.SetAnchorTileCoordinatesAndPropagateToTerrainObjects`
already mirrors.

#### How entries reach the deque: self-registration during Tick

`CMapSceneryComponent_ReorderSubcomponentForDepth` has exactly one caller,
`CGameMap_NotifySceneryComponentSubcomponentUpdated` (`0x61E74B`):

```text
if (subcomponent == 0) return;
component = CGameMap_FindFirstComponentWithTypeCode3();
if (component) CMapSceneryComponent_ReorderSubcomponentForDepth(component, subcomponent);
```

Its callers answer the outstanding question:

| Caller | Meaning |
| --- | --- |
| `CMapTerrainObject_Tick` (`0x644BA0`) | individual terrain objects self-register |
| `CMapType3SubcomponentType04_Tick` (`0x645625`) | type 4 self-registers |
| `CMapType3SubcomponentType0A_Tick` (`0x63B6AF`) | type 0A self-registers |
| `CGameMapFileRecordType04EntryType03_Tick` (`0x64B669`) | |
| `Role_TickCommandStateAndDispatchPlayback` (`0x672772`, `0x672830`) | **roles register too** |
| `Role_UpdateActionAndAuxiliaryMotionSampling` (`0x64F505`, `0x64F5BA`) | **roles register too** |
| `sub_7CAFB1`, `sub_6404E9`, `sub_64CB26` | not yet identified |

So the deque holds **individual** subcomponents, not groups — including individual
terrain objects, which is what makes them the type-2 entries the parenting path
searches for. Each entry puts itself in during its own tick.

`Role3DClientSceneMapSceneryComponent` already has this exact shape:
`IMapScenerySubcomponentActiveRenderInsertionRuntime.ShouldInsertIntoActiveRenderListAfterTick`
driving `NotifyUpdated`. The structure is right; only the ordering inside
`NotifyUpdated` is missing.

The registration idiom is visible in `sub_64CB26`, one of the previously
unidentified callers:

```text
if (this[0x28] != 0) return;                                   // inactive flag
if (CGameMap_IsTileWithinScaledScreenBoundsWithMargin(map, this[0x0C], this[0x10], 8))
    CGameMap_NotifySceneryComponentSubcomponentUpdated(this);
sub_72FFF1(this + 0x5C);
```

An entry passes **itself**, gated on an inactive flag at `+0x28` and an on-screen
test with an 8-tile margin. That test reads `+0x0C`/`+0x10` as tile coordinates,
which independently confirms those slots are tile space for deque members.

`sub_7CAFB1` shows the same idiom in a class that does not store the pair inline —
it fetches its coordinates through `vtable+0x14` first, then applies the identical
8-tile margin cull before registering itself. So the contract for a deque member
is: expose `vtable+0x14`, self-register from tick, cull at 8 tiles.

**Roles satisfy that contract — proven.** The role vtable family is identified by
`Role_AdvanceMotionInterpolationAndRefreshPosition` (motion interpolation) at
`+0x58`. Six vtables carry it, so six role
subclasses exist, with bases at `0x86AACC`, `0x86AD08`, `0x86AEEC`, `0x86C568`,
`0x86C94C` and `0x86CB3C`. Off base `0x86AACC`:

| Slot | Address | Meaning |
| --- | --- | --- |
| `+0x0C` | `0x651856` | `CRole_GetObjectTypeCodeFromRoleType` — `return this[0x360]` |
| `+0x14` | `0x651875` | `CRole_GetTileCoordinatesFromXteaFields` — two `j_XteaProtectedInt_Get` reads |
| `+0x1C` | `0x641307` | depth span slot |

Two things matter here. First, a role's type code is **stored at `CRole+0x360`,
not constant**. Second, the role's tile pair lives in the XTEA-protected
containers, which is why it is fetched through `vtable+0x14` rather than read
inline.

So the isometric depth sort orders **roles and scenery in one list**. Roles
register themselves via `CGameMap_NotifySceneryComponentSubcomponentUpdated` from
`Role_TickCommandStateAndDispatchPlayback` and
`Role_UpdateActionAndAuxiliaryMotionSampling`.

#### The shared base class is `CMapObj`, and it is named in the binary

The deque's element type is not an inference. `CMapSceneryComponent_ReorderSubcomponentForDepth`
builds a `shared_ptr` for the **incoming** subcomponent at `0x635B97` through
`SharedPtrCMapObj_CreateNonOwningControlBlock` (`0x636E67`). That control block's
vtable is `0x86A298`; its `_Get_deleter` slot, `TDoNothingDeleterCMapObj_GetDeleter`
(`0x636ECA`), compares against the RTTI type descriptor at `0x93D080`, whose name
string at `0x93D088` is:

```text
.?AV?$TDoNothingDeleter@VCMapObj@@@@
```

One `shared_ptr<T>` has to hold terrain objects, type `0x04`/`0x0A`/`0x0F`
subcomponents *and* roles, so `T` is the common base: **`CMapObj`**.

`CMapObj`'s own vtable is `0x86A2B8`. `CMapObj_ScalarDeletingDestructor`
(`0x63736E`) installs it, and so does the first vptr store of every derived
constructor — `CRole_Constructor` writes `0x86A2B8` at `0x64D090` before
overwriting it with `0x86AACC` at `0x64D142`.

| Slot | Contract | `CMapObj` default |
| --- | --- | --- |
| `+0x00` | scalar deleting destructor | `0x63736E` |
| `+0x04` | `Render(arg)` | `CMapObj_VirtualNoOpOneArg` (`retn 4`) |
| `+0x08` | `Tick(arg)` | `CMapObj_VirtualNoOpOneArg` |
| `+0x0C` | `GetObjType()` | `CMapObj_GetObjectTypeCode`, returns `this+0x04` |
| `+0x10` | `GetProjectedScreenCoordinates(outPair)` | `CMapObj_VirtualNoOpOneArg` |
| `+0x14` | `GetTileCoordinates(outPair)` | `CMapObj_VirtualNoOpOneArg` |
| `+0x18` | `SetTileCoordinates(x, y)` | `CMapObj_SetDepthSpanTilesNoOp` (`retn 8`, COMDAT-folded) |
| `+0x1C` | `GetDepthSpanTiles(outPair)` | `CMapObj_GetDepthSpanTilesDefaultOneByOne` → `(1, 1)` |
| `+0x20` | `SetDepthSpanTiles(x, y)` | `CMapObj_SetDepthSpanTilesNoOp` |
| `+0x24` | 0-arg getter | `CMapObj_VirtualReturnZeroNoArgs` |
| `+0x28` | two out-params | `0x63734D`, writes `0` to both |
| `+0x2C` | `SetColorArgb(argb)` | `CMapObj_SetColorArgb`, stores `this+0x08` |

Base fields are `+0x00` vptr, `+0x04` type code, `+0x08` colour ARGB. The base
stores **no** tile pair and **no** depth span; its getters are a no-op and the
constant `(1, 1)` — the same default `CGameMap_GetType3SubcomponentDepthSpanOrDefault`
returns for a null child.

Twenty-four vtables carry `CMapObj_SetColorArgb` at `+0x2C`, which is the whole
family. Two branches matter:

1. **`CMapPositionedObj`**, vtable `0x86A910`, ctor `CMapPositionedObj_Constructor`
   (`0x64B978`), own type code `0x0D`. Adds the inline tile pair at `+0x0C`/`+0x10`
   (`CMapPositionedObj_GetTileCoordinates` / `_SetTileCoordinates`) and projects it
   through `CMapPositionedObj_GetProjectedScreenCoordinates`. Every map-file scenery
   subcomponent is on this branch, including the type-`2`
   `CMapType3SubcomponentType01ExternalObject` (the terrain object), which adds its
   footprint span at `+0x1C`/`+0x20`.
2. **`CRole`**, vtable `0x86AACC`, ctor `CRole_Constructor` (`0x64D079`). It derives
   from `CMapObj` **directly**, not from `CMapPositionedObj`: no inherited
   `+0x0C`/`+0x10` tile storage, `+0x14` overridden with
   `CRole_GetTileCoordinatesFromXteaFields` (XTEA containers at `CRole+0x318` and
   `CRole+0x334`), `+0x0C` overridden with `CRole_GetObjectTypeCodeFromRoleType`
   (`CRole+0x360`, not the base's `+0x04`).

All six role vtables leave `+0x1C` at the base default, so **every role has a depth
span of exactly `(1, 1)`**.

Role type codes read out of the constructors: `CRole` `0` (`CRole__Init` memsets
`+0x360..+0x36B`), `CHero` `6` (`0x655755`), `CNpc` `7` (`0x66EC52`), and the
`0x86C568` subclass `0x13` (`0x732FE7`, which also mirrors it into the base's
`+0x04`). None of the role classes read so far reports `2`. That is an observation
over the constructors read, not an exhaustive proof.

#### What the type-2 branch actually buys: nested rendering

Type code `2` is the terrain object, so a role — or any non-`2` subcomponent —
standing inside a terrain object's footprint is **parented to that terrain object**
instead of entering the deque. `CMapTerrainObject_Render` (`0x64450F`) then, after
drawing its own ANI frame:

```text
count = child list at this+0x88
for each child:
    child->vtable[0x2C](CGameMap_GetSingletonPtr()[0x13C])   // SetColorArgb
    child->vtable[0x04](0)                                   // Render
sub_63F8C6(this + 0x88)                                      // clear the child list
```

The clear happens at the end of **Render**, not at tick, so a culled terrain object
keeps its accumulated children.

That is the whole mechanism for role-versus-scenery occlusion: one isometric sort
over `CMapObj`, plus a nesting escape hatch for anything that falls inside a
footprint.

#### Managed state after this slice

- `ICMapObjRuntime` (`Conquer.Map`) is the managed `CMapObj` contract: type code,
  tile pair, depth span (default `(1, 1)` as a default interface member, mirroring
  the base implementation), colour, tick and render.
- `Role3DClientSceneMapSceneryComponent.NotifyUpdated` now runs the real rule: the
  type-`2` parenting scan first, then `MapSceneryDepthOrdering.FindActiveRenderInsertIndex`.
- `ICMapObjDepthChildListRuntime` carries the type-`2` side —
  `FootprintContainsTile` (`0x644E0E`) and `InsertChildForDepth` (`0x644BA9`) — and
  `CMapTerrainObjectFromListFileRuntime` implements it, including the render-time
  child walk and clear.
- The component tick no longer force-inserts. `IMapScenerySubcomponentActiveRenderInsertionRuntime`
  is gone; type `0x04` self-registers from its own tick like native.

#### How a role puts itself in the deque

`CRole_Tick` (`0x64F464`) is role vtable `+0x08` off base `0x86AACC`, and it is where the
registration lives. The `0x86AEEC` class overrides it with
`Role_TickCommandStateAndDispatchPlayback` (`0x6725ED`), which repeats the block verbatim plus one
extra gate, and `CHero`'s own override (`0x65E070`) delegates to that at `0x65E097`.

```text
actionId = Role_GetCurrentActionId(this)
if (actionId in {0x6E, 0x6F, 0x78, 0x79}) {          // ground-move pair and run pair
    saved = (Xtea_Get(this+0x318), Xtea_Get(this+0x334))
    step  = (this->field_17C <= 3) ? (this->field_194, this->field_198)   // motion START point
                                   : (this->field_19C, this->field_1A0)   // motion END point
    ProjectScreenPointToTileCoordinatesUnchecked(map, step, &tx, &ty)
    Xtea_Set(this+0x318, tx); Xtea_Set(this+0x334, ty)                    // substitute
    if (IsTileWithinScaledScreenBoundsWithMargin(map, tx, ty, 2))
        CGameMap_NotifySceneryComponentSubcomponentUpdated(this)          // 0x64F5BA
    Xtea_Set(this+0x318, saved.x); Xtea_Set(this+0x334, saved.y)          // restore
} else {
    if (IsTileWithinScaledScreenBoundsWithMargin(map, Xtea_Get(0x318), Xtea_Get(0x334), 2))
        CGameMap_NotifySceneryComponentSubcomponentUpdated(this)          // 0x64F505
}
```

Three things a port must get right:

- **The role cull margin is 2 tiles.** Terrain objects use 8, and the type-`0x04` animated sprite
  uses a frame-extent-derived margin.
- **The substitution writes the role's real XTEA containers and writes them back.** It is not a
  local, so everything reached through `vtable+0x14` during the registration sees the substituted
  pair. That is the point: mid-step, a role's depth position is the projected endpoint of its
  current step, not its committed tile, so a walking role does not pop through scenery.
- The `0x86AEEC` branch adds `&& this->field_3A8 == 0` at both `0x672772` and `0x672830`.
  `CRole+0x3A8` is `additional_offset_y_enabled` per `Entity_System/crole_class.md`. Bare `CRole`
  has no such test.

**Hierarchy correction.** `sub_66EC52` — the `0x86AEEC` constructor — calls `CRole_Constructor`
directly at `0x66EC66`, not a `CPlayer` constructor. `CHero_Ctor` then calls `sub_66EC52` and
overwrites the type code with `6`. So the chain is `CRole` → `0x86AEEC` class (type `7`) → `CHero`
(type `6`), and `Entity_System/cnpc_class.md`'s "CNpc extends CPlayer which extends CRole" is not
what the constructors do. The `0x86C94C` and `0x86CB3C` classes also derive from `sub_66EC52` and
keep `7`; only the `0x86C568` class derives straight from `CRole`, with type `0x13`.

#### Managed state after this slice

`CRoleMapObjRuntime` (`Conquer.Role`) is a role with identity that implements `ICMapObjRuntime`:
type code `6` for the local hero and `7` otherwise, tile pair from its own XTEA-equivalent fields,
the inherited `(1, 1)` depth span, and a `Tick` that reproduces the registration block above
including the substitution, the restore and the margin-2 cull.
`ClientWorldRoleMapObjRegistrationRuntime` reconciles one of these per live role against
`ClientWorldProjectedRoleStateStore` and ticks them, and `Role3DClientSceneMapStage` drives it
immediately after the map component tick dispatch — that ordering is load-bearing, because
`CMapSceneryComponent_PerFrameTick` clears the active deque before anything registers.

`SceneComposition` builds the real runtime and hands it the loaded type-3 scenery component as its
notification target, found by scanning the component list the way
`CGameMap_FindFirstComponentWithTypeCode3` does. `SceneCompositionRoleDepthRegistrationTests` covers
it end to end: a role added to the role state store reaches the scenery component's active render
deque after one composed world frame, and the deque is rebuilt rather than accumulated across ticks.

#### The deque is the only way a role draws — managed now dispatches through it

The map's component deque is a **closed set of five**. `CGameMap_InsertComponentAtIndexOrAppend`
(`0x61D52D`) has exactly two callers — `CGameMap_Constructor` (`0x61B875`) and
`CGameMap_ResetAndInitializeDefaultComponents` (`0x61D07A`) — and both append the same five creator
results with `index = -1`: ground/entity layer (type 1), type 2, type 6, scenery (type 3), type 5.
**No role is ever inserted into it.**

That corrects a name and an assumption carried since an earlier session.
`CHero_MapComponentRenderTick` is renamed `CHero_Render`: it is `CMapObj::Render` for `CHero`, and it
is *not* reached from the map component render dispatch. The only paths that reach a role's `+0x04`
are `CMapSceneryComponent_Render` walking the active deque at `component+0x74`, and
`CMapTerrainObject_Render` walking its adopted child list at `+0x88` (`0x644702`).

It also settles an apparent signature clash. The `CMapObj` base render stub is
`CMapObj_VirtualNoOpOneArg` (`retn 4`) — one argument, matching both deque call sites. The
two-argument `(offsetX, offsetY)` form at `0x61D257` belongs to the map **component** vtable, which is
a different class; the second parameter Binary Ninja shows on `CHero_Render` is an unused stack slot.

**Architectural consequence.** Native has no separate role render pass: a role is drawn only as a
depth-sorted member of the scenery component's active deque, interleaved with scenery by the
comparator. Managed now follows that ownership. `CRoleMapObjRuntime.Render` forwards its entity id
through `Role3DClientSceneDepthSortedRoleMapObjRenderSinkRuntime`, and the production
`Role3DClientSceneMultiPartRenderStage` resolves and draws exactly that entity while the scenery
component is walking the deque. A role adopted into a type-2 terrain object's child list reaches the
same callback from that child walk, matching the second native call path.

The old bulk role render remains only as a compatibility fallback for render stages that do not
implement entity-addressable dispatch. The production router implements the depth-sorted frame
contract, so it does not redraw player roles after the component pass. The renderer clears its role
depth buffer once before component rendering and rebinds/restores its GL state around each role
callback without clearing, allowing scenery callbacks to remain interleaved.

The renderers themselves were never the missing piece: `Role3DMultiPartMeshRenderer`,
`RoleBodyMeshOpenGlRenderer`, `Role3DClientSceneMultiPartRenderStage` and
`Role3DClientSceneHeroBodyRenderStage` already existed. The missing piece was the entity-addressable
bridge from `CMapObj::Render`.

#### Dependency seam removed before the re-route

`CMapSceneryComponent_Render` (`0x6352F4`) is a plain walk, and managed already matches it exactly:

```text
for i in 0 .. count(this + 0x74) - 1:
    entry = deque[i]
    if (entry != 0):
        entry->vtable[0x2C](CGameMap_GetSingletonPtr()[0x13C])   // SetColorArgb
        entry->vtable[0x04](0)                                   // Render, one argument
```

So the deque side is ready to carry the draw. What blocks it is on the managed role side, and it is a
dependency chain native does not have:

```text
Role3DClientMapRenderExecutor.ExecuteRenderSubpasses
  1. DispatchRenderCallbacks()                  -> type-1 component render SUBMITS scene objects
  2. CaptureCurrentFrameRoleVisualPlans()       -> reads sceneObjectStore.EnumerateCurrentFrameSceneObjects()
  3. RenderHeroBodyMeshes(currentFps)           -> reads visualPlanStore.EnumerateCurrentFramePlans()
```

Originally step 3 could not move inside step 1 because step 2 fed it and step 2 was itself fed by
step 1. Moving the draw into the deque walk in that state would have made every body draw one frame
stale.

Native has no such chain. `Role_TickAndRender` (`0x64F5F7`) reads only role-local state — the entry
guards test `Role_HasStatusFlag`, role vtable `+0x60` and `role+0x3B4` (`m_pIRoleView`), and phase 1
projects `role+0x350`/`+0x354` — so nothing it needs is produced by the component render pass. The
per-frame scene-object submission during type-1 render is managed scaffolding with no native
counterpart, and it is what forces the three-phase order.

That prerequisite was completed first: `ClientWorldRoleRenderSubmissionStage` now runs at the front
of `Role3DClientMapRenderExecutor`, followed immediately by visual-plan capture, both before map
component rendering. With current-frame plans available, `RenderHeroBodyMesh(entityId)` can resolve
one deque member without depending on a submission produced by that same component walk.

`Role3DClientMapRenderExecutor` now opens the depth-sorted role frame after those two preparation
steps, dispatches map components, and completes the frame afterward. Focused coverage pins the
observable order as submission → plan capture → depth-frame begin → component/deque role callback →
depth-frame completion, plus a composed-world regression that proves one live role is rendered from
its scenery-deque slot exactly once.

One bounded limitation remains: standard simple-object NPC visual plans are still drawn during
depth-frame completion because they have not yet been converted into `ICMapObjRuntime` members.
Player/role bodies no longer use that separate path.

**The mid-step substitution is now wired.** `CRoleMapObjTickState.HasMotionStepEndpoints` is fed from
`RoleCommandStateTickSnapshotState.HasStagedGroundMoveStepEndpoints`, which the managed port of
`0x736315` sets, and `CRoleMapObjRuntime.MidStepFallbackCount` still counts any tick that reached the
mid-step branch without a staged step. That counter is now a real signal rather than a permanent
state: it means a role was in a ground-move or run action without the step staging having run, not
that the inputs are missing.

**Correction to an earlier revision of this paragraph**, which said managed "does not yet track
`CRole+0x17C`, `CRole+0x194`/`+0x198` or `CRole+0x3A8` per live role". All three are accounted for;
the earlier statement came from grepping for `RoleField194`-style names and missing the ones actually
used:

| Native | Managed, on `RoleCommandStateTickSnapshotState` |
| --- | --- |
| `CRole+0x17C` | `CurrentDirectionIndex` |
| `CRole+0x194`/`+0x198` | `ProjectedScreenStartX` / `ProjectedScreenStartY` |
| `CRole+0x19C`/`+0x1A0` | `RoleField19CStagedProjectedScreenX` / `RoleField1A0StagedProjectedScreenY` |
| current action id | `MotionState.CurrentActionId` |

`CRole+0x3A8` needs no plumbing at all: `CRole__SetAdditionalOffsetYEnabled` (`0x6513A3`) has exactly
two callers, both Texas Hold'em NPC actor builders in `TexasNpc.cpp` (`0x7487AF`, `0x748DAB`), a class
managed does not model. It is therefore provably `0` for every role managed materialises, so the
`AdditionalOffsetYEnabledField3A8 = false` default is correct rather than assumed.

#### The step-staging producer

`Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`) is fully decoded, and it is what
produces the two points:

```text
poseAction = this->field_398
this->field_1A4 = (poseAction == 0x6E || poseAction == 0x78) ? 0x6F : 0x6E

this->field_194 = this->field_350          // 0x736343  MOTION START = committed path cursor
this->field_198 = this->field_354          // 0x73634F

d = this->field_17C
Map_ProjectTileToScreenCoordinates(map,
    Xtea_Get(tileX) + <direction delta X>[d],
    Xtea_Get(tileY) + <direction delta Y>[d],
    &this->field_19C, &this->field_1A0)    // MOTION END = destination tile's projected point
return 1
```

Two consequences:

1. **Managed now has a ground-move step-staging counterpart**,
   `RoleCommandStateTickSnapshotState.StageGroundMoveStepEndpointsFromPathCursor`. Before it existed,
   only `ApplyJumpPreparationWrites` and the commit wrote those pairs, so `ProjectedScreenStartX/Y`
   were never a walking role's step start. It refuses a direction index outside the 8-entry table,
   which is the range native guarantees on the only path that reaches `0x736315`.
2. **A proven write-timing deviation.** `Role_RecomputeCoordinateGateCacheFromProjectedPosition`
   (`0x64E9A5`) commits `+0x19C`/`+0x1A0` into `+0x350`/`+0x354` and **does not touch `+0x194`** —
   native refreshes `+0x194` only in the staging above. Managed's
   `CommitStagedPathCursorAndRecomputeCoordinateGateCache` wrote `ProjectedScreenStartX` from the
   freshly committed cursor, putting managed's start point one step ahead of native's between a
   commit and the next staging. **Fixed**: the commit now only seeds the start point while no ground-
   move step has been staged, which keeps the world-entry and jump-preparation mirrors working while
   matching `0x64E9A5` once a role is actually walking.

**Delta table identity — resolved.** The operands at `0x736376` and `0x73638F` are `0x86C608` and
`0x86C628`. There are four direction delta tables, in two byte-identical pairs per size:

| Addresses | Symbol | Entries |
| --- | --- | --- |
| `0x86C608` / `0x86C628` | `g_RoleMoveDirection8TileDeltaX` / `Y` | 8 |
| `0x86C7C4` / `0x86C7E4` | `g_WalkDirection8TileDeltaX` / `Y` | 8, duplicate values |
| `0x86C648` / `0x86C6A8` | `g_RoleMoveDirection24TileDeltaX` / `Y` | 24 |
| `0x86C804` / `0x86C864` | `g_WalkDirection24TileDeltaX` / `Y` | 24, duplicate values |

`0x736315` indexes the 8-entry pair, and the index is in bounds: the only path that reaches it is the
command-type-13 first-probe-pass branch with no remaining path nodes, which has just written
`role+0x17C = dir1 % 8`. The `8..23` values (`dir1 + 8`, `dir2 + 16`) come only from the
second-probe-pass steering branch, which does **not** call this function and stages its own
coordinates through the 24-entry pair. So there is no 8-vs-24 hazard here.

Managed's `WalkDirectionTileDeltaTable` already holds these values byte-for-byte; only its doc
comment was incomplete, naming just the `0x86C7C4` pair and `CMsgEntityAction__Process` as the sole
consumer.
| `0x623DC1` | `sub_623dc1` | `CEarthQuakeEffectMgr_QueueEffectByIniSection` |
| `0x623EDF` | `sub_623edf` | `CEarthQuakeEffectMgr_ProcessQueuedEffects` |
| `0x76A744` | `sub_76a744` | `Exe_SetCachedCursorSample` |
| `0x76A769` | `sub_76a769` | `Exe_GetCachedCursorSample` |
| `0x76A7A3` | `sub_76a7a3` | `Exe_ClearCachedCursorSampleFlag` |

Inside `CGameMap_RenderComponentsAndShowScreenEffects` (`0x61D1F5`):
- component deque traversal uses:
  - `StdDequePtr_GetElementCount(map+0x14, map+0x04)` at `0x61D21F`
  - `StdDequePtr_AdvanceIteratorByOffset(&iter, index)` at `0x61D241`
- per-render callback offsets are produced by `CGameMap_GetComponentRenderProjectionOffset` (`0x61E3D8`) at `0x61D213`:
  - `offsetX = map+0x48 - projectionBaseX`
  - `offsetY = map+0x4C - projectionBaseY`
  - `projectionBaseX/Y` are from `CGameMap_GetProjectionBaseCenterFromOffsets` (`0x61E375`)
- component render callback dispatch is virtual `+0x4` (`0x61D257`)
  - dispatch loop is index-based (`0..count-1`) with null check before callback (`0x61D249`..`0x61D24D`)
  - callback args are `(offsetX, offsetY)`
- verified render-tail subpass order:

| Callsite | Callee | Verified role |
|---:|---|---|
| `0x61D273` | `CGameMap_RenderQueuedFloatingTextEntries` (`0x620D2A`) | Draw queued floating text |
| `0x61D27A` | `CGameMap_ClearQueuedFloatingTextEntriesAfterRender` (`0x620D16`) | Clear floating-text queue after draw |
| `0x61D286` | `CBossEffectMgr_UpdateTrackedBossLifeState` (`0x682262`) | Boss-life manager update pass (pending/active id validation + periodic displayed-life smoothing) |
| `0x61D292` | `CBossEffectMgr_RenderBossLifeOverlay` (`0x682506`) | Boss-life overlay render pass |
| `0x61D2FE` | `CGameMap_ShowScreenEffects` (`0x620B79`) | Draw active timed screen effects |

Floating-text queue details (Conquer.exe):
- Queue container lives at map `+0x320/+0x324` (entry stride `0x28` bytes).
- Queue API: `CGameMap_QueueFloatingTextEntry` (`0x620C7A`) rejects null/empty text (`0x620C8E`/`0x620C95`) and appends one `0x28` entry (`0x620CEC`).
- Render API: `CGameMap_RenderQueuedFloatingTextEntries` (`0x620D2A`) resolves `ShowStringCommon` style/corner args from per-entry values when entry style != 0, otherwise from font defaults loaded via `Load_FontSetting_Ini` (`0x769BC7`).
- Clear API: `CGameMap_ClearQueuedFloatingTextEntriesAfterRender` (`0x620D16`) calls `CGameMapFloatingTextEntryVector_EraseAndCompactRange` (`0x621C51`) with begin/end from `+0x320/+0x324`.

Boss-life overlay details (Conquer.exe):
- singleton entrypoint used by map render path is `CBossEffectMgr_GetSingletonPtr` (`0x42D042`) at `0x61D27F` and `0x61D28B`.
- packet-side set helper is `CBossEffectMgr_SetBossEntityId_Global` (`0x65B3A5`) -> `CBossEffectMgr_SetBossEntityId` (`0x6821E7`).
- update stage (`0x682262`) uses manager fields:
  - pending id `+0x50`, pending set tick `+0x48` (10s timeout window),
  - active id `+0x4C`,
  - life timing `+0x40/+0x44`,
  - displayed life `+0x38`.
- render stage (`0x682506`) clamps life-per-line (`+0x1C`) to `min(roleMaxLife(vtbl+0xC4), data_96AEC4)`, then applies displayed-life adjust and dispatches `CBossEffectMgr_DrawBossLifeOverlay`.
- draw stage (`0x682787`) consumes verified layout/resource slots:
  - draw coordinates/layout: `+0x04/+0x08/+0x0C/+0x10/+0x14/+0x18/+0x20/+0x24/+0x28/+0x2C/+0x30`
  - animation resource handles: `+0x54` (background), `+0x60` (life background), `+0x6C` (light)
  - all three resources are queried from `"ani/Control.ani"` (`0x93EB4C`) via `GameDataSetQuery()->vfunc+0x10` at `0x6827AC`, `0x6828FA`, and `0x6829A3`.
- layout/asset loader (`0x680792`) writes those slots from key pairs:
  - `Boss_ShowbossbBG + BGAni/BGAni800X600` -> `+0x54`
  - `Boss_BossBloodBG|Boss_BossBloodSBG + BGLifeAni/BGLifeAni800X600` -> `+0x60`
  - `Boss_BloodLightPic + LightAni/LightAni800X600` -> `+0x6C`
  - numeric layout defaults: `+0x04=0`, `+0x08=0x1F4`, `+0x0C=0`, `+0x10=0x1F4`, `+0x14=0x11`, `+0x18=0x0B`, `+0x20=-95`, `+0x24=-2`, `+0x28=0x14`, `+0x2C=0x0F`, `+0x30=0x1F4`, `+0x34=3`.
- config globals used by this runtime:
  - `data_96AEC4`: `"LifePerLine"` (`CBossEffectMgr_LoadLifePerLineConfig`, `0x680348`, default `0x2DC6C0`)
  - `data_96AECC`: `"ColorAmount"` (`CBossEffectMgr_LoadColorAmountConfig`, `0x680412`, default `0x14`)
  - `data_96AEC8`: `"LinePerLayer"` (`CBossEffectMgr_LoadLinePerLayerConfig`, `0x6804D9`, default `1`)

Inside the CHero map component callback path:
- CHero vtable slot `+0x4` points to `CHero_Render` (`0x65E472`)  
  (vtable bytes at `0x86AD08`: `... 72 E4 65 00 70 E0 65 00 ...`)
- `CHero_Render` calls `CHero_TickAndRenderRoleVisuals` at `0x65E479`
- `CHero_TickAndRenderRoleVisuals` calls `Role_TickAndRender` at `0x66F843`

Inside the CHero tick callback path:
- CHero vtable slot `+0x8` points to `CHero_PerFrameTickAndSubsystemUpdate` (`0x65E070`)
- `CHero_PerFrameTickAndSubsystemUpdate` calls `Role_TickCommandStateAndDispatchPlayback` at `0x65E097`

Camera-build wrappers used in this chain:
- `CGameMap_BuildGameCameraFromScreenDimensions` (`0x620905`) -> `GameCameraBuild(GetScreenWidth(), GetScreenHeight())`
- `CGameMap_BuildGameCameraFromScaledViewportDimensions` (`0x620920`) -> `GameCameraBuild(map+0x14C, map+0x150)`

### 3) Role rendering uses `graphic.dll` camera and bitmap primitives
`CRole__Render3D` references `CMyBitmap::GameCameraGetPos` and `MyBitmapCreateEx`, and invokes methods on role-view objects to render or create sprite-like resources.

### 4) Role-view creation is a hard dependency on `RoleView.dll`
`CRole__CreateRoleView` / `CRole__CreateRoleViewWithPos`:
- destroys existing role view (virtual destructor)
- chooses a type (e.g., 4 becomes 10 for large IDs)
- calls `RoleViewCreate(type)`
- initializes it with a “look”/ID and sets transforms via vtable calls
- consults `RoleDataQuery` for data-driven decisions

`CPlayer__AddVisualEffect` also uses `RoleViewCreate` for timed effects; it sets expiry times using `timeGetTime()`.

**Implication:** entity visuals/effects are implemented as objects from `RoleView.dll`, so parity requires either:
- reimplementing `RoleView` semantics ourselves, or
- providing a compatibility layer that exposes equivalent “role view” APIs in the new client.

Current managed boundary after the latest startup/bootstrap verification:
- type-1 map rendering already submits the local hero first and persists a player scene object with:
  - appearance composite
  - transform-look refresh source id
  - projected screen coordinates
  - the main RoleView transform input offset from `CGameMap_GetProjectionBaseCenterFromOffsets` (`0x61E375`)
  - the later MyBitmap composite screen point from the scaled-viewport helper at `0x61D77F`
  - fresh player body/helmet load requests derived from `bodyAppearanceSourceId`
- that is enough to prove whether the first world frame has correct hero-center input
- it is **not** enough to make the hero visibly draw yet, because the native visible-player path still runs through:
  - `CHero_Render` (`0x65E472`)
  - `CHero_TickAndRenderRoleVisuals` (`0x66F7AB`)
  - `Role_TickAndRender` (`0x64F5F7`)
  - the unresolved managed replacement for the `RoleView/I3DRole` part-load, track-bind, and render slot calls

Verified native coordinate-space rule for player render input:
- `Map_ProjectTileToScreenCoordinates` (`0x61D850`) first produces absolute projected role coordinates using `map+0x40/+0x44`
- `Role_TickAndRender` then converts that point through `CGameMap_GetProjectionCenterOffsetFromScreenPoint`
  / `CGameMap_GetProjectionBaseCenterFromOffsets` before the RoleView transform call
- later in the same offscreen bitmap path, helper `0x61D77F` converts the same absolute point into the final
  scaled-viewport MyBitmap composite screen point using `map+0x48/+0x4C` plus `map+0x14C/+0x150`
- therefore managed role render state must preserve **both**:
  - the RoleView projection-base offset used by the offscreen 3D render
  - the composite screen point used when the offscreen bitmap is drawn back into the world

---

## Documentation Completeness
This document records verified observations only. Items that are not yet documented (open questions, TODOs, next deob targets) live outside `analysis/conquer_docs/` so this folder remains an implementation-ready reference, not a work journal.

---

## Device-Lost / Reset (Observed Semantics)
The render loop polls `CMyBitmap::IfDeviceLost()` and branches on at least three outcomes:

- `0`: normal operation (render continues).
- `1`: “device lost” (but not reset yet). The client records a `timeGetTime()` timestamp via `Exe_DeviceLost_RecordTimestamp_OnSingleton` (`0x76E1B2`) on a singleton (`s__GetSingletonPtr_53A304()`).
- `2`: “device needs reset” (or reset-ready). The client:
  1) records a timestamp via `Exe_DeviceReset_RecordTimestamp_OnSingleton` (`0x738C69`) on the same singleton,
  2) calls `C3DGameMap__ReleaseRenderObjectList(...)` (`0x620361`) to release per-map render object nodes before reset,
  3) calls `Exe_DestroyGlobalSingleton_dword_957F18` (`0x5DF50D`) (destroys global singleton `dword_957F18` via its vtable, then nulls it),
  4) calls `CMyBitmap::ResetDevice()`.

**Implication:** the client expects a defined *device/graphics-context loss* model and a well-defined “invalidate GPU resources → recreate → resume” hook order. This is observable behavior in the original.


---

## Scope Note
This document is descriptive: it records what the original client depends on and how those dependencies behave. It does not prescribe a rewrite architecture.

---

## Notes
See dedicated module documentation for deeper details:
- `analysis/conquer_docs/Rendering/01_graphic_dll_api_surface.md` (EXE import surface)
- `analysis/conquer_docs/Rendering/graphic_dll/README.md` (the `graphic.dll` IDB documentation set)
- `analysis/conquer_docs/Rendering/02_roleview_object_interface.md` (EXE-side `RoleViewCreate` usage)
- `analysis/conquer_docs/Rendering/03_targetbmp_and_mybitmap_object_interfaces.md` (EXE-side TargetBmp/MyBitmap usage)
