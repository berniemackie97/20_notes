# CGameMap / C3DGameMap — Game World Rendering

IDA folder `/Game_Map/`: 2 sub-folders, 23 functions.

## Overview

The game world rendering system uses isometric projection with 64x32 pixel tile dimensions.
Two main classes handle the map: `CGameMap` for logic/coordinate calculations, and
`C3DGameMap` for 3D terrain rendering and map object management. A helper class
`C3DMapSimpleObj` handles individual static 3D objects placed on the map.

**Source**: `F:\CQ2ClientRelease-42.0.1\3DGameMap` (debug strings)

**Key Singletons**:
- `GetSingletonPtr_410685` — Camera/viewport singleton (C3DGameMap instance)
- `GetSingletonPtr_404460` — Hero/game state singleton

**Isometric Projection**:
```
screen_x = camera_offset_x + ((tile_x - tile_y) * 64) / 2
screen_y = camera_offset_y + ((tile_x + tile_y) * 32) / 2
```

**External Dependencies**:
- `graphic.dll` — CMyBitmap 2D rendering (text, sprites)
- `CTerrainLayer` — Terrain heightmap/texture layer
- `CTerrainEffectManager` — Terrain visual effects
- `C2DMapRegion` — 2D map region/minimap overlay

## Verified packet-1110 map identity lifecycle

`CMsgMapInfo1110__Process` (`0x732B10`) owns the sole post-construction write of the current map id:

| Packet offset | `CGameMap` field | Writer |
|---:|---:|---|
| `+4` | `currentMapId` at `+0xE0` | `CGameMap_ApplyMapIdAndRefreshWorldState` (`0x61F185`) |
| `+8` | `currentMapDocumentId` at `+0xE4` | `CGameMap_SetMapDocumentId` (`0x61F2B6`) |
| `+12/+16` | flags low/high at `+0xE8/+0xEC` | `CGameMap_SetFlags64` (`0x61F2C3`) |

The map-id routine compares the old and incoming values. A change sets
`forceType5TriggerRefresh` at `+0x2E4` to `1`, but the incoming ID is stored and the entire refresh
chain runs in both the changed and repeated-ID cases. That flag is later consumed and cleared by
`CGameMap_UpdateTileRegionFlagsAndAmbientMedia`. Do not simplify a repeated 1110 map id to a no-op.

`CGameMap_IsStateBlockingAutoRun` (`0x62084B`) is exactly
`currentMapId == 0x40F` (1039). `CMsgMapInfo1110__Process` separately compares the same field with
`0x3EA` (1002), establishing `+0xE0` as the current map ID rather than a generic mode value.

**Scale System**: Global zoom factor stored in `dword_93C6C0`, applied to screen dimensions:
```
scaled_width  = screen_width * zoom_factor / scale
scaled_height = screen_height * zoom_factor / scale
```

## Verified Frame Integration Chain (Conquer.exe)

World-frame anchor in EXE is `CMyShellDlg_RunFrameTick` (`0x5DCFAA`).
Verified map-stage calls in order:

| Callsite | Callee | Meaning |
|---:|---|---|
| `0x5DD0CC` | `CGameMap_TickComponentsAndProcessScreenEffects` (`0x61D415`) | Tick map components and process timed screen effects |
| `0x5DD0D9` | `Exe_TickMapProjectionAndDispatchMapRender` (`0x5ACAC3`) | Build map projection and dispatch map component render pass |

Inside `CGameMap_TickComponentsAndProcessScreenEffects`:
- component container traversal uses deque helpers:
  - `StdDequePtr_GetElementCount(map+0x14, map+0x04)` at `0x61D464`
  - `StdDequePtr_AdvanceIteratorByOffset(&iter, index)` at `0x61D484`
- dispatch loop is `index=0..count-1` with null-guard before callback (`0x61D48C`..`0x61D490`)
- component tick callback dispatch is virtual `+0x8` (`0x61D496`)
  - callback arg is constant `0` (`push 0` at `0x61D494`)
- scaled viewport values are written at `+0x14C/+0x150`
- timed screen-effect processing call is `CGameMap_ProcessScreenEffects` (`0x620AC7`) at `0x61D521`

Inside `Exe_TickMapProjectionAndDispatchMapRender`:
- hero-centered projection inputs are built at `0x5ACAD9`..`0x5ACAF7` (CHero vfunc `+0x10` + half-screen offsets)
  - vfunc target resolved as `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor` (`0x65185D`)
  - function copies `hero+0x350/+0x354` into output XY pair
- keyboard state is sampled at `0x5ACB01` and used to select `allowEdgeScroll`
- keyboard bytes used in this path:
  - `keyboardState[0x12]` (`VK_MENU`) read from stack slot `-0xF6` at `0x5ACB07`
  - `keyboardState[0x10]` (`VK_SHIFT`) read from stack slot `-0xF8` at `0x5ACB6F`
- computed call arguments:
  - `centerX = heroVf10OutX + GetScreenWidth()/2`
  - `centerY = heroVf10OutY + GetScreenHeight()/2`
  - `allowEdgeScroll = (vkMenuHighBitSet && g_projectionEdgeScrollEnabled != 0 && !Role_HasStatusFlag(hero, 0x3C))`
- projection/camera update call is `CGameMap_UpdateProjectionAndCameraFromScreenCenter` (`0x61E0E7`) at `0x5ACB4A`
- earthquake queue processing call is `CEarthQuakeEffectMgr_ProcessQueuedEffects(CEarthQuakeEffectMgr_GetSingletonPtr())` at `0x5ACB4F`/`0x5ACB56`
- cached cursor-sample flag is cleared via `Exe_ClearCachedCursorSampleFlag` (`0x76A7A3`) at `0x5ACB5B`
- map render dispatch call is `CGameMap_RenderComponentsAndShowScreenEffects` (`0x61D1F5`) at `0x5ACB88` when `arg1 == 0`
- map render pass flag is selected by:
  - `renderPassFlag = (g_mapRenderPassOverrideFlag != 0 || vkShiftHighBitSet) ? 1 : 0`
- producer writes for projection globals:
  - `g_projectionEdgeScrollEnabled` (`data_958640`) is written at `0x5B3AB8`
    in `CMyShellDlg_DispatchCommandCode` jump-table entry `0x18`
  - `g_mapRenderPassOverrideFlag` (`data_958644`) is written at `0x5B4542`
    in `CMyShellDlg_DispatchCommandCode` jump-table entry `0x47`

Inside `CGameMap_UpdateProjectionAndCameraFromScreenCenter` (`0x61E0E7`):
- cursor-edge update path (`allowEdgeScroll != 0`) writes map offsets:
  - X offset `map+0x54`
  - Y offset `map+0x58`
- clamp path (`enforceProjectionClamp != 0`) uses:
  - `CGameMap_GetProjectionClampScaleDivisor` (`0x61EDC3`) = `(map+0x154 * map+0x140) / 100`
  - clamp bands:
    - X: `±(data_93C6C0 * 0x164 / divisor)`
    - Y upper: `+(data_93C6C0 * 0xC0 / divisor)`
    - Y lower: `-(data_93C6C0 * 0xAC / divisor)`
- timed projection effects are applied before commit:
  - `CGameMap_ApplyProjectionOffsetOscillation` (`0x61FB26`)
  - `CGameMap_ApplyProjectionScaleOscillation` (`0x61FB93`)
  - `CGameMap_ApplyProjectionColorBlend` (`0x61FC13`)
- final center commit:
  - writes `map+0x48` and `map+0x4C`
  - calls `CGameMap_UpdateGameCameraFromProjectionCenter(map, map+0x48, map+0x4C)`

Inside `CGameMap_UpdateGameCameraFromProjectionCenter` (`0x61E6C6`):
- computes camera XY from projection-center delta against origin base:
  - `camX = GetScreenWidth()*0.5 + (projectionCenterX - originX)`
  - `camY = GetScreenHeight()*0.5 + (projectionCenterY - originY)`
- dispatches `CMyBitmap::GameCameraSet(camX, camY, -1000.0f, 3)`

Inside `CGameMap_RenderComponentsAndShowScreenEffects`:
- camera build from scaled viewport at `0x61D204` via `CGameMap_BuildGameCameraFromScaledViewportDimensions` (`0x620920`)
- component render projection offset is built by `CGameMap_GetComponentRenderProjectionOffset` (`0x61E3D8`) at `0x61D213`:
  - `projectionOffsetX = map+0x48 - projectionBaseX`
  - `projectionOffsetY = map+0x4C - projectionBaseY`
  - where `projectionBaseX/Y` come from `CGameMap_GetProjectionBaseCenterFromOffsets` (`0x61E375`)
  - `CGameMap_GetProjectionBaseCenterFromOffsets` first resolves ground/entity-layer bitmap extents via
    `CGameMap_GetGroundEntityLayerScaledBitmapExtents` (`0x61E408`) at `0x61E382`
  - `CGameMap_GetGroundEntityLayerScaledBitmapExtents` exact helper chain for the ground-puzzle path:
    - `CGameMap_FindFirstComponentWithTypeCode1` at `0x61E409`
    - `CMapGroundEntityLayer_GetGroundBitmapDimensions` (`0x637803`) at `0x61E41D`
    - `CMapGroundEntityLayer_GetGroundBitmapScaleFactor` (`0x637824`) at `0x61E424`
    - `CMapGroundEntityLayer_GetGroundBitmapScaleDivisor` (`0x63A95B`) at `0x61E42E`
  - `CMapGroundEntityLayer_GetGroundBitmapDimensions` fans into:
    - `CMapGroundEntityLayer_GetGroundBitmapWidthPixels` (`0x638E9F`)
    - `CMapGroundEntityLayer_GetGroundBitmapHeightPixels` (`0x638EC8`)
  - when the ground/entity-layer component is in `.pul` ground-puzzle mode (`component+0x1C+0x04 == 0`):
    - width/height come from `CMapPuzzleBitmap_GetScaledBitmapDimensions` (`0x63A7DC`)
    - raw scale comes from `CMapGroundEntityLayer_GetGroundBitmapScaleFactorRaw` (`0x638F03`) -> `*(component+0x1C+0x1C4)`
    - divisor is `data_93D218` (`0x100`) via `CMapGroundEntityLayer_GetGroundBitmapScaleDivisor`
  - therefore the helper returns the loaded ground puzzle bitmap extents in pixels
    (`tileCountX * 0x100`, `tileCountY * 0x100`) rather than framebuffer width/height
- component container traversal uses deque helpers:
  - `StdDequePtr_GetElementCount(map+0x14, map+0x04)` at `0x61D21F`
  - `StdDequePtr_AdvanceIteratorByOffset(&iter, index)` at `0x61D241`
- dispatch loop is `index=0..count-1` with null-guard before callback (`0x61D249`..`0x61D24D`)
- component render callback dispatch is virtual `+0x4` (`0x61D257`)
  - call arguments are `(projectionOffsetX, projectionOffsetY)`
- render-tail subpass chain (verified callsites):

| Callsite | Callee | Verified role |
|---:|---|---|
| `0x61D273` | `CGameMap_RenderQueuedFloatingTextEntries` (`0x620D2A`) | Draw queued floating-text entries |
| `0x61D27A` | `CGameMap_ClearQueuedFloatingTextEntriesAfterRender` (`0x620D16`) | Clear floating-text queue after draw |
| `0x61D286` | `CBossEffectMgr_UpdateTrackedBossLifeState` (`0x682262`) | Boss-life manager state update pass (selection/timeout/periodic displayed-life smoothing) |
| `0x61D292` | `CBossEffectMgr_RenderBossLifeOverlay` (`0x682506`) | Boss-life overlay render pass |
| `0x61D2FE` | `CGameMap_ShowScreenEffects` (`0x620B79`) | Draw active timed screen effects |

Boss-effect singleton dispatch in this chain:
- `0x61D27F` calls `CBossEffectMgr_GetSingletonPtr` (`0x42D042`) before update subpass
- `0x61D28B` calls `CBossEffectMgr_GetSingletonPtr` (`0x42D042`) before render subpass

CHero component evidence in this map callback system:
- CHero vtable bytes at `0x86AD08`:
  `90 60 65 00 72 E4 65 00 70 E0 65 00 ...`
- vtable slot `+0x4` -> `CHero_Render` (`0x65E472`)
- vtable slot `+0x8` -> `CHero_PerFrameTickAndSubsystemUpdate` (`0x65E070`)
- `CHero_PerFrameTickAndSubsystemUpdate` calls `Role_TickCommandStateAndDispatchPlayback` at `0x65E097`
- `CHero_Render` calls `CHero_TickAndRenderRoleVisuals` (`0x66F7AB`) at `0x65E479`
- `CHero_TickAndRenderRoleVisuals` calls `Role_TickAndRender` at `0x66F843`

Camera helpers used by the map/effect render pass:
- `CGameMap_BuildGameCameraFromScreenDimensions` (`0x620905`): `GameCameraBuild(GetScreenWidth(), GetScreenHeight())`
- `CGameMap_BuildGameCameraFromScaledViewportDimensions` (`0x620920`): `GameCameraBuild(map+0x14C, map+0x150)`

Verified renames applied in this world-frame slice:
- `0x61E0E7` = `CGameMap_UpdateProjectionAndCameraFromScreenCenter`
- `0x61E6C6` = `CGameMap_UpdateGameCameraFromProjectionCenter`
- `0x61EDC3` = `CGameMap_GetProjectionClampScaleDivisor`
- `0x61EDD7` = `CGameMap_SetProjectionScaleAndViewport`
- `0x61E345` = `CGameMap_GetProjectionCenterWithOffset`
- `0x61E375` = `CGameMap_GetProjectionBaseCenterFromOffsets`
- `0x61E408` = `CGameMap_GetGroundEntityLayerScaledBitmapExtents`
- `0x61E3D8` = `CGameMap_GetComponentRenderProjectionOffset`
- `0x637803` = `CMapGroundEntityLayer_GetGroundBitmapDimensions`
- `0x637824` = `CMapGroundEntityLayer_GetGroundBitmapScaleFactor`
- `0x638E9F` = `CMapGroundEntityLayer_GetGroundBitmapWidthPixels`
- `0x638EC8` = `CMapGroundEntityLayer_GetGroundBitmapHeightPixels`
- `0x638F03` = `CMapGroundEntityLayer_GetGroundBitmapScaleFactorRaw`
- `0x63A95B` = `CMapGroundEntityLayer_GetGroundBitmapScaleDivisor`
- `0x61FB26` = `CGameMap_ApplyProjectionOffsetOscillation`
- `0x61FB93` = `CGameMap_ApplyProjectionScaleOscillation`
- `0x61FC13` = `CGameMap_ApplyProjectionColorBlend`
- `0x63029A` = `StdDequePtr_GetElementCount`
- `0x637DFF` = `StdDequePtr_AdvanceIteratorByOffset`
- `0x65185D` = `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor`
- `0x5B29E2` = `CMyShellDlg_DispatchCommandCode`
- `0x5DF869` = `CEarthQuakeEffectMgr_GetSingletonPtr`
- `0x623D5B` = `CEarthQuakeEffectMgr_Initialize`
- `0x623DC1` = `CEarthQuakeEffectMgr_QueueEffectByIniSection`
- `0x623EDF` = `CEarthQuakeEffectMgr_ProcessQueuedEffects`
- `0x76A744` = `Exe_SetCachedCursorSample`
- `0x76A769` = `Exe_GetCachedCursorSample`
- `0x76A7A3` = `Exe_ClearCachedCursorSampleFlag`

## C3DGameMap Memory Layout (partial)
```c
struct C3DGameMap {
    // Object list (3D map objects)
    DWORD obj_list[4];           // +1..+4 — object list (start/end/sentinel)

    // Camera/scroll offsets
    DWORD tile_offset_x;         // +16 — base tile X offset for screen projection
    DWORD tile_offset_y;         // +17 — base tile Y offset for screen projection
    DWORD scroll_offset_x;       // +18 — camera scroll X offset (pixels)
    DWORD scroll_offset_y;       // +19 — camera scroll Y offset (pixels)

    // Terrain
    CTerrainEffectManager terrain_effects;  // +52

    // Map info
    DWORD current_map_id;        // +57
    DWORD scale;                 // +80 (byte 0x140) — zoom/scale factor (0 = invalid)
    DWORD real_screen_width;     // +83 (byte 0x14C) — scaled screen width
    DWORD real_screen_height;    // +84 (byte 0x150) — scaled screen height

    // 2D map region list
    void* region_list;           // +166 — C2DMapRegion linked list

    // Terrain layer pointer
    void* terrain_layer;         // +196

    // Screen effect list
    void* screen_effect_list;    // +203 (byte 0x32C)

    // Team beam position
    DWORD team_beam_x;           // +226
    DWORD team_beam_y;           // +227

    // Region arrays (by type 0-14, 3 DWORDs each)
    // +256..+298 — region lookup arrays (start/end ptrs per type)

    // Object cleanup list
    DWORD cleanup_list[8];       // +340..+347

    // EXP/level display
    DWORD exp_display_enabled;   // byte +748
    DWORD exp_start_time;        // byte +756 — timeGetTime for +exp popup
    QWORD exp_delta;             // byte +760 — recent exp gain amount
    DWORD exp_label_x;           // byte +768
    DWORD exp_label_y;           // byte +772
    DWORD exp_delta_label_x;     // byte +776
    DWORD exp_delta_label_y;     // byte +780

    // Floating text list
    DWORD* float_text_start;     // byte +800 — entries are 10 DWORDs (40 bytes)
    DWORD* float_text_end;       // byte +804
};
```

## Verified Map Component Producer Chain (Conquer.exe)

This section locks the concrete producer path for the map component deque used by
`CGameMap_TickComponentsAndProcessScreenEffects` and
`CGameMap_RenderComponentsAndShowScreenEffects`.

### Component container ownership offsets

| Map offset | Meaning | Evidence |
|---:|---|---|
| `+0x04` | deque storage/header base used by insert/advance helpers | `CGameMap_InsertComponentAtIndexOrAppend` uses `lea esi, [ecx+0x4]` at `0x61D53A`; insert/append helpers consume this pointer |
| `+0x14` | deque count/iterator metadata used by count helper | `StdDequePtr_GetElementCount(map+0x14, map+0x04)` call setup in insert helper at `0x61D53D..0x61D541` |

### Insert helper: `CGameMap_InsertComponentAtIndexOrAppend` (`0x61D52D`)

BNinja decompile (verified):

```c
if (component == NULL) return;
count = StdDequePtr_GetElementCount(map + 0x14, map + 0x04);
if (index < 0 || index >= count)
    deque_append(map + 0x04, &component);
else
    deque_insert_at(map + 0x04, index, &component);
```

Branch evidence:
- null guard: `cmp [ebp+0x8], 0` / `je 0x61D586` (`0x61D533..0x61D538`)
- in-range test: `index < 0` (`jl 0x61D57B`) and `index >= count` (`jge 0x61D57B`) at `0x61D546..0x61D54F`
- in-range insert path: `0x61D551..0x61D579` (calls `0x62141F`, `0x621546`, `0x621521`)
- append path: `0x61D57B..0x61D581` (calls `0x621489`)

### Producer callsites and creation order

All xrefs to `CGameMap_InsertComponentAtIndexOrAppend` are from:
- `CGameMap_Constructor` (`0x61B875`)
- `CGameMap_ResetAndInitializeDefaultComponents` (`0x61D07A`)

Both callsites pass `index = -1` and append the same 5 creator results in the same order.

| Order | Creator | Constructor | VTable write in ctor | `GetTypeCode` |
|---:|---|---|---|---:|
| 1 | `CGameMapGroundEntityLayerComponent_Create` (`0x637516`) | `CGameMapGroundEntityLayerComponent_Constructor` (`0x63738F`) | `mov [esi], 0x86A2FC` at `0x637407` | `1` (`CGameMapGroundEntityLayerComponent_GetTypeCode`, `0x6375C0`) |
| 2 | `CGameMapComponentType2_Create` (`0x637201`) | `CGameMapComponentType2_Constructor` (`0x637126`) | `mov [esi], 0x86A2EC` at `0x637170` | `2` (`CGameMapComponentType2_GetTypeCode`, `0x63738B`) |
| 3 | `CGameMapComponentType6_Create` (`0x6370F4`) | `CGameMapComponentType6_Constructor` (`0x6370BB`) | `mov [esi], 0x86A2A8` at `0x6370C3` | `6` (`CGameMapComponentType6_GetTypeCode`, `0x6370F0`) |
| 4 | `CMapSceneryComponent_Create` (`0x63551C`) | `CMapSceneryComponent_Constructor` (`0x635210`) | `mov [esi], 0x86A258` at `0x635263` | `3` (`CMapSceneryComponent_GetTypeCode`, `0x43D103`) |
| 5 | `CGameMapComponentType5_Create` (`0x634B36`) | `CGameMapComponentType5_Constructor` (`0x6349D8`) | `mov [esi], 0x86A238` at `0x634A46` | `5` (`CGameMapComponentType5_GetTypeCode`, `0x63520C`) |

Concrete call sequence evidence:

| Function | Creator call range | Insert call range |
|---|---|---|
| `CGameMap_Constructor` (`0x61B875`) | `0x61BA3C`, `0x61BA4B`, `0x61BA5A`, `0x61BA69`, `0x61BA78` | `0x61BA46`, `0x61BA55`, `0x61BA64`, `0x61BA73`, `0x61BA82` |
| `CGameMap_ResetAndInitializeDefaultComponents` (`0x61D07A`) | `0x61D0D9`, `0x61D0EA`, `0x61D0F8`, `0x61D106`, `0x61D114` | `0x61D0E5`, `0x61D0F3`, `0x61D101`, `0x61D10F`, `0x61D11D` |

Verified default appended type-code order is therefore:

`[1, 2, 6, 3, 5]`

### Component callback mapping (`vtable+0x4/+0x8/+0xC`)

Map component dispatchers call:
- render callback at `vtable+0x4` from `CGameMap_RenderComponentsAndShowScreenEffects` (`0x61D257`)
- tick callback at `vtable+0x8` from `CGameMap_TickComponentsAndProcessScreenEffects` (`0x61D496`)
- type code getter at `vtable+0xC` from type-filter loops (`0x61D5EA/0x61D649/0x61D6A8`)

Verified callback mapping for default producer types:

| Type code | VTable | `+0x4` render callback | `+0x8` tick callback | `+0xC` get type |
|---:|---:|---|---|---|
| `1` | `0x86A2FC` | `CGameMapGroundEntityLayerComponent_MapComponentRenderTick` (`0x637553`) | `CGameMapGroundEntityLayerComponent_PerFrameTick` (`0x637566`) | `CGameMapGroundEntityLayerComponent_GetTypeCode` (`0x6375C0`) |
| `2` | `0x86A2EC` | `CGameMapComponentType2_MapComponentRenderTick` (`0x63723E`) | `CGameMapComponentType2_PerFrameTick` (`0x6372A2`) | `CGameMapComponentType2_GetTypeCode` (`0x63738B`) |
| `6` | `0x86A2A8` | `NoOpVirtualCallback_Arg2` (`0x768140`) | `NoOpVirtualCallback_Arg1` (`0x5AD9B1`) | `CGameMapComponentType6_GetTypeCode` (`0x6370F0`) |
| `3` | `0x86A258` | `CMapSceneryComponent_Render` (`0x6352F4`) | `CMapSceneryComponent_PerFrameTick` (`0x63537B`) | `CMapSceneryComponent_GetTypeCode` (`0x43D103`) |
| `5` | `0x86A238` | `CGameMapComponentType5_MapComponentRenderTick` (`0x634C34`) | `CGameMapComponentType5_PerFrameTick` (`0x634B6B`) | `CGameMapComponentType5_GetTypeCode` (`0x63520C`) |

Type-6 callback evidence:
- `NoOpVirtualCallback_Arg2` disassembly at `0x768140`: `retn 0x8`
- `NoOpVirtualCallback_Arg1` disassembly at `0x5AD9B1`: `retn 0x4`

### Type-2 callback body (fully verified)

`CGameMapComponentType2_MapComponentRenderTick` (`0x63723E`):
- pre-steps:
  - `CGameMapComponentType2_RenderPreStepA(this+0x0C)` (`0x648060`) at `0x63724B`
  - `CGameMapComponentType2_RenderPreStepB(this+0x40)` (`0x646CE9`) at `0x637253`
- child list count:
  - `count = StdDequePtr_GetElementCount_Type2ChildList(this+0x84, this+0x74)` at `0x63725F`
- loop `index=0..count-1`:
  - iterator advance via `StdDequePtr_AdvanceIteratorByOffset_Type2ChildList(&iter, index)` at `0x63727F`
  - child render callback via `call [vtable+0x4]` with literal `0` at `0x637287..0x63728D`
- incoming projection args are not consumed by the child-call path.

`CGameMapComponentType2_PerFrameTick` (`0x6372A2`):
- child list count:
  - `count = StdDequePtr_GetElementCount_Type2ChildList(this+0x84, this+0x74)` at `0x6372B0`
- loop `index=0..count-1`:
  - iterator advance via `StdDequePtr_AdvanceIteratorByOffset_Type2ChildList(&iter, index)` at `0x6372D1`
  - child tick callback via `call [vtable+0x8]` with dispatcher tick arg at `0x6372D9..0x6372E0`

### Type-3 callback body (fully verified)

`CGameMapComponentType3_MapComponentRenderTick` (`0x6352F4`):
- active render deque count:
  - `count = StdDequePtr_GetElementCount_Type3SubcomponentList(this+0x78, this+0x74)` at `0x63530C`
- loop `index=0..count-1`:
  - iterator advance via `StdDequePtr_AdvanceIteratorByOffset_Type3SubcomponentList(&iter, index)` at `0x635331`
  - per-child color write callback via `call [vtable+0x2C]` with `CGameMap_GetSingletonPtr()->ProjectionColorField13C` at `0x63534F`
  - per-child render callback via `call [vtable+0x4]` with literal `0` at `0x635358`
- therefore render dispatch consumes the active render deque rooted at `this+0x74/+0x78`, not the loaded subcomponent deque rooted at `this+0x34/+0x38`.

`CGameMapComponentType3_PerFrameTick` (`0x63537B`):
- allocates a temporary iterator/deque state on the stack (`0x635390..0x63539D`),
- clears the active render deque rooted at `this+0x74/+0x78` through `MotionPathNodeDeque_ClearAndResetCursors(this+0x74)` at `0x6353A9`,
- iterates the loaded subcomponent deque rooted at `this+0x34/+0x38` through `0x641D2C(this+0x34, &iter)` at `0x6353B5`,
- dispatches child tick callbacks by child virtual type code (`vtable+0x0C`), then feeds selected children into the active render deque update helper at `0x6355E7`.

Verified branch table from `0x6353FC..0x6354D6`:

| Child type code | Tick call argument | Post-tick active-render behavior | Evidence |
|---:|---|---|---|
| `0x01` | `nullptr` | no direct insertion; nested external objects drive updates | `0x63540C..0x635478` |
| `0x04` | hero projection-pair temp from `CHero_GetSingletonPtr()->vfunc+0x10` | always enters active-render helper at `0x6354D6` after tick | `0x635449..0x6354D6` |
| `0x05` | `nullptr` | no direct insertion | `0x635415..0x635478` |
| `0x06` | dispatcher tick arg | no direct insertion | `0x63541A..0x635447` |
| `0x07` | dispatcher tick arg | no direct insertion | `0x63541A..0x635447` |
| `0x09` | `nullptr` | inserts only when child field `+0x28 != 0` after tick | `0x635424..0x635438`, `0x6354D6` |
| `0x0A` | out-flag pointer on stack | inserts through `0x6355E7` only when returned out-flag is non-zero; child may also call `CGameMap_NotifyType3ComponentSubcomponentUpdated(this)` internally | `0x6354A0..0x6354D6`, `0x63B6AF` |
| `0x0E` | out-flag pointer on stack | inserts only when returned out-flag is non-zero | `0x635464..0x6354D6` |
| `0x11` | out-flag pointer on stack | inserts only when returned out-flag is non-zero | `0x635469..0x6354D6` |
| `0x13` | dispatcher tick arg | inserts only when `0x733041(child) != 0` after tick | `0x63547D..0x63549E`, `0x6354D6` |
| other | `nullptr` | no direct insertion | fallthrough to `0x635472..0x63547B` |

Verified helper inputs around the active-render update path:
- `0x6354B6..0x6354D6` packages the current child pointer plus its refcount control block and calls the helper at `0x6355E7`.
- `CGameMap_NotifyType3ComponentSubcomponentUpdated` (`0x61E74B`) finds component type `3` and forwards the child to `CMapType3Component_ReorderSubcomponentForDepth` (`0x635AE6`).
- `CGameMap_GetType3SubcomponentDepthSpanOrDefault` (`0x61E0BC`) returns `(1,1)` for null children, otherwise dispatches child `vtable+0x1C`; `CMapType3Component_ReorderSubcomponentForDepth` uses this helper while comparing insertion spans.
- for subtype `0x04`, the caller still passes the hero projection-pair temp into child `vtable+0x08`, but `CMapType3SubcomponentType04_Tick` itself does not consume that stack argument.
  - verified LLIL at `0x6454D1` immediately calls child `vtable+0x10` with only an output buffer.
  - for subtype `0x04`, `vtable+0x10` resolves to `CMapPositionedObj_GetProjectedScreenCoordinates` (`0x64B9A1`), which projects `this+0x0C/+0x10` tile coordinates through `Map_ProjectTileToScreenCoordinates`.

## Logic (6 functions, all documented)

### CGameMap__FindComponent_Type2 (0x61D649, size=90)
**Purpose**: Finds the first map component with type==2 in the component list.
```c
count = get_list_count(this+1);
for (i = 0; i < count; i++) {
    entry = list_get(this+1, i);
    obj = *entry;
    if (obj && obj->vtable->GetType() == 2)
        return obj;
}
return NULL;
```

### CGameMap__CalcScreenPosFromTile (0x61D850, size=118)
**Purpose**: Converts isometric tile coordinates to screen pixel position.
```c
// Isometric projection: 64x32 pixel tiles
*out_x = this->tile_offset_x + ((tile_x - tile_y) * 64) / 2;
*out_y = this->tile_offset_y + ((tile_x + tile_y) * 32) / 2;
```
**Offsets**: +16 = tile_offset_x, +17 = tile_offset_y

### CGameMap__AddScreenOffset (0x61D8C6, size=27)
**Purpose**: Adds camera scroll offset to screen coordinates.
```c
*out_x = x + this->scroll_offset_x;  // offset +18
*out_y = y + this->scroll_offset_y;  // offset +19
```
**Offsets**: +18 = scroll_offset_x, +19 = scroll_offset_y

### CGameMap__IsTileInViewRadius (0x61E00D, size=185)
**Purpose**: Checks if a tile coordinate falls within the visible screen area (with radius padding).
```c
// Scale radius by zoom factor and tile dimensions
radius_x = (radius * zoom * 64) / GetScaleDivisor();
radius_y = (radius * zoom * 32) / GetScaleDivisor();

// Get tile screen position
CalcScreenPosFromTile(tile_x, tile_y, &sx, &sy);
AddScreenOffset(0, 0, &origin_x, &origin_y);

// Build view bounds
left   = origin_x - radius_x;
top    = origin_y - radius_y;
right  = origin_x + radius_x + screen_width;
bottom = origin_y + radius_y + screen_height;

return (sx >= left && sy >= top && sx <= right && sy <= bottom);
```
**Globals**: `dword_93C6C0` = zoom/scale factor

### CGameMap__ProcessScreenEffect (0x620AC7, size=178)
**Purpose**: Processes timed screen effects — iterates linked list at offset +203, checks completion, and fires WndMsg callbacks on completion.
```c
// Linked list at this+203 (byte 0x32C)
for (node in screen_effect_list) {
    effect = node[3];
    if (effect) {
        if (sub_5ECA36(effect)) {  // effect completed?
            wndmsg = node[2];
            if (wndmsg) PostMainWndMsg(wndmsg, 0);
            remove_node(node);
        }
    }
}
```
**Debug**: "ERROR: CGameMap::ProcessScreenEffect() failed at %s, %d"

### CGameMap__ShowScreenEffect (0x620B79, size=189)
**Purpose**: Renders all active screen effects centered on screen.
```c
center_x = screen_width / 2;
center_y = screen_height / 2;
AddScreenOffset(center_x, center_y, &sx, &sy);
convert_to_tile(sx, sy, &tile_x, &tile_y);

for (node in screen_effect_list at this+203) {
    effect = node[3];
    if (effect)
        render_effect(tile_x, tile_y);
}
```
**Debug**: "ERROR: CGameMap::ShowScreenEffect() failed at %s, %d"

## Rendering (17 functions, all documented)

### C3DGameMap Lifecycle

#### C3DGameMap__func_000 (0x61CFA9, size=178) — **Destroy/Cleanup**
**Purpose**: Full map teardown — destroys terrain effects, camera, 3D objects, and all rendering resources.
```c
sub_755D0C(this->field_197, this->field_198);  // cleanup resources
CTerrainEffectManager__func_000(this+52);       // destroy terrain effects
GetSingletonPtr_623748()->cleanup();            // cleanup entity manager
CMyBitmap::GameCameraDestroy();                 // destroy camera
C3DGameMap__func_001(this);                     // destroy 3D object list
// Destroy terrain layer if present
if (this->terrain_layer) {
    terrain_layer->vtable->Destroy();
    this->terrain_layer = NULL;
}
C3DGameMap__func_017(this);  // cleanup object list 2
```

#### C3DGameMap__func_001 (0x61D15B, size=148) — **Destroy Object List**
**Purpose**: Iterates 3D object list (offsets +1..+4), destroys each via vtable[0](obj, 1), then clears the list.
```c
while (obj_list_start != obj_list_sentinel) {
    obj = *obj_list_start;
    if (obj) {
        obj->vtable->Destroy(obj, 1);  // flag=1: delete
        *obj_list_start = NULL;
    }
    advance_iterator(obj_list);
}
clear_list(this+1);
```

### Map Loading

#### CGameMap_CreateFromDataId (0x61DA1F, size=574)
**Purpose**: Load map from data-id using RoleData lookup record (`path + companion dword`), then run map-file load path.

**Verified call chain (Conquer.exe + GameData.dll):**

- `0x61DA3C`: call `RoleDataQuery`.
- `0x61DA49`: virtual call `(*vtable+0x7C)(mapDataId)` -> `RoleDataSingleton_GetGameMapInfoRecordByMapDataId` (`GameData.dll: 0x10007776`).
- `0x61DAA3`: `strncpy(localPath, mapInfo+0x00, 0xFF)`.
- `0x61DAA9`: read companion dword at `mapInfo+0x40` and forward into the ground/entity-layer component path.
- `0x61DAD3`: call `CGameMap_LoadMapFileFromRelativePath`.
- `0x61DBE4`: write `map+0xE4 = mapDataId`.
- `0x61DC22`: post main-window message `0x424` with `wParam=0`.

**RoleData map-info record layout (returned pointer from vtable+0x7C):**

| Offset | Size | Meaning | Evidence |
|---|---:|---|---|
| `+0x00` | `0x40` | Relative map file path ASCII (zero-terminated in copied record buffer) | `0x61DAA3` |
| `+0x40` | `0x04` | Companion dword consumed before map-file load (ground/entity-layer component link value) | `0x61DAA9` |

**`ini/GameMap.dat` load layout (source of above record):**

Loaded by `RoleDataSingleton_LoadGameMapDatTable` (`GameData.dll: 0x10007678`), one record per entry count.

| Entry field order | Size | Evidence |
|---|---:|---|
| `map_data_id` | `0x04` | `0x10007711` |
| `map_path_byte_length` | `0x04` | `0x1000771B` |
| `map_path_bytes[length]` | variable | `0x10007726` |
| `ground_entity_layer_component_link_id` | `0x04` | `0x10007738` |

The loader copies exactly `0x44` bytes per value into the tree-node value region (`node+0x14`), matching the create-path reads (`0x1000775D`, `0x10007796`).

**WndMsg**: `0x424` (map loaded)

Verified `CMsgAction__Process` callers into this map-create path:

- subtype `0x4A` branch callsite: `0x6FF478`
- subtype `0x56` branch callsite: `0x6FF6FB`

Both pass `msg+0x08` as little-endian map data-id.

#### CGameMap_LoadMapFileFromRelativePath (0x61DC3D, size=952)
**Purpose**: Open map payload reader, read header + first cell-grid block, validate per-row checksums, then continue into later map object sections.

**Reader selection/parity detail (verified):**

- `0x7715A8` lowercases path and selects reader by extension:
  - `.7z` -> mode `2`
  - `.gz` -> mode `1`
  - otherwise raw mode `0`
- `CGameMap_LoadMapFileFromRelativePath` constructs reader with mode `3` (`0x61DC9A` -> `0x77150C`), which routes through the above extension selector.

**Mode-2 (`.7z`) backend chain (verified, Conquer.exe):**

- `MapFileReaderCreateBackendByMode` (`0x771679`) mode-2 branch (`0x771729`) allocates `0x20` bytes and calls `MapFileReader7zBackendConstruct` (`0x771323`).
- `MapFileReader7zBackendConstruct`:
  - sets backend vtable pointer at `+0x00`,
  - initializes state: valid flag `+0x10=0`, payload ptr `+0x14=0`, cursor `+0x18=0`, payload size `+0x1C=0`,
  - calls `MapFileReader7zBackendValidateSignature` (`0x771426`) which checks first 6 bytes == `37 7A BC AF 27 1C`,
  - on valid signature, calls `MapFileReader7zBackendLoadArchiveIntoMemoryBuffer` (`0x771498`).
- `MapFileReader7zBackendLoadArchiveIntoMemoryBuffer`:
  - calls `MapArchive7zInstallAllocatorCallbacks` (`0x7BD800`),
  - calls `MapArchive7zExtractPayloadToBuffer` (`0x7BD830`) with source path and output slots `backend+0x14` (payload ptr), `backend+0x1C` (payload size).
- `MapFileReaderBufferedPayloadReadSuccess` (`0x7713E7`) returns true only when `backend+0x10 != 0` and `backend+0x1C > 0`.
- `MapFileReaderBufferedPayloadRead` (`0x7714BF`) performs bounded copy:
  - computes `requestedBytes = elementSize * elementCount` (uint32),
  - copies `min(requestedBytes, payloadSize - cursor)` bytes from `payloadPtr + cursor`,
  - advances cursor (`+0x18`) by copied bytes,
  - returns copied byte count.
- `MapFileReaderRead` (`0x771898`) forwards to backend vtable `+0x8` (the read method above), so map read blocks consume decompressed payload bytes, not archive container bytes.

**Mode-2 backend state layout (verified):**

| Offset | Size | Meaning | Evidence |
|---|---:|---|---|
| `+0x10` | `0x01` | signature-valid flag | `0x771378`, `0x7713E7` |
| `+0x14` | `0x04` | payload buffer pointer | `0x7714A7`, `0x7714F6` |
| `+0x18` | `0x04` | current read cursor | `0x7714C8`, `0x7714FE` |
| `+0x1C` | `0x04` | payload byte length | `0x7714A4`, `0x7714CB` |

**Mode-1 (`.gz`) backend chain (verified, Conquer.exe):**

- `MapFileReaderCreateBackendByMode` (`0x771679`) mode-1 branch (`0x771797`) allocates `0x20` bytes and calls `MapFileReaderGzipBackendConstruct` (`0x771115`).
- `MapFileReaderGzipBackendConstruct`:
  - sets backend vtable pointer at `+0x00` (`0x86D834`),
  - initializes state: valid flag `+0x10=0`, payload ptr `+0x14=0`, cursor `+0x18=0`, payload size `+0x1C=0`,
  - opens source path in binary read mode (`fopen(path, "rb")`),
  - calls `MapFileReaderGzipBackendValidateSignature` (`0x77122D`) which checks first 2 bytes == `1F 8B` and rewinds stream to start,
  - if signature valid: writes `+0x18=0`, then `+0x1C = MapFileReaderGzipBackendReadUncompressedSizeFromTrailer` (`0x771287`, last 4 bytes LE), then calls `MapFileReaderGzipBackendInflatePayloadIntoBuffer` (`0x7712B7`).
- `MapFileReaderGzipBackendInflatePayloadIntoBuffer`:
  - allocates payload buffer of size `arg3` into `backend+0x14`,
  - opens gzip stream via `GzipFileOpenReadBinary` (`0x7B6F40`),
  - inflates bytes via `GzipFileReadInflatedBytes` (`0x7B74A0`) into `backend+0x14` for `arg3` bytes,
  - closes gzip stream via `GzipFileClose` (`0x7B7880`),
  - returns inflate result (constructor asserts only against `-1` in debug-check path).
- Mode-1 vtable at `0x86D834` uses:
  - destroy: `MapFileReaderGzipBackendDestroyDeleting` (`0x7711C9`) / `MapFileReaderGzipBackendDestroy` (`0x7711E5`),
  - read-success: `MapFileReaderBufferedPayloadReadSuccess` (`0x7713E7`),
  - read: `MapFileReaderBufferedPayloadRead` (`0x7714BF`).
- Clean 5517 `ini/GameMap.dat` entries currently classify to `.7z` only (no `.gz` map-path rows), but mode-1 backend is present and verified in native.

**Clean-5517 payload sanity check (managed differential test):**

- Map archive source of truth should remain `.7z` payload output from mode-2 backend.
- Companion `.DMap` files are not universally authoritative mirrors:
  - `178` companion pairs match byte-for-byte.
  - `3` companions differ from `.7z` payload bytes: `d_antre01.7z`, `horserate.7z`, `icecrypt-lev3.7z`.
  - `11` `.7z` map files have no `.DMap` companion in clean set.

**Verified first read block layout:**

| Read order | Size | Meaning | Evidence |
|---|---:|---|---|
| 1 | `0x04` | header dword #0 | `0x61DD00` |
| 2 | `0x04` | header dword #1 | `0x61DD0F` |
| 3 | `0x104` | fixed puzzle/terrain path field | `0x61DD75` |
| 4 | `0x04` | grid width | `0x61DDDE` |
| 5 | `0x04` | grid height | `0x61DDED` |
| 6 | call | allocate/set grid dimensions | `0x61DDFA` |
| 7 | per cell | `word -> cell+0x02`, `word -> cell+0x00`, `word -> cell+0x04` | `0x61DE5A`, `0x61DE66`, `0x61DE76` |
| 8 | per row | read checksum dword and compare to computed accumulator | `0x61DEC3`, `0x61DECB` |

Verified downstream ownership of the first cell-grid words:

- `cell+0x00` is the base `uint16 surfaceId`.
- `cell+0x02` is the base `uint16 passabilityFlag`; zero is passable and nonzero is blocked.
- `cell+0x04` is the base signed `int16 elevation` returned by `MapTileEntry_GetTailLinkElevation`
  when no tail-link attachment chain exists yet.
- `MapTileEntry_GetTailLinkNode` falls back to the tile entry itself when `tileEntry+0x08 == 0`, so the
  three first-cell-grid words remain the live tail-node values until scenery insertion appends an attachment.

**Per-row accumulator formula (exact instruction sequence):**

```c
// x = column index, y = row index
// cell words: v0 = *(cell+0x00), v2 = *(cell+0x02), v4 = *(int16_t*)(cell+0x04)
rowSum += ((v0 + y + 1) * v2) + ((v0 + x + 1) * (v4 + 2));
```

On checksum mismatch the function exits fail path (`0x61DFD6`).

**Debug strings in this path**: `"mapfileReader.ReadSuccess()"`, `"pCellInfo"`, `"F:\\CQ2ClientRelease-42.0.1\\3DGameMap"`.

#### Post-Grid Type-1 Exit-Marker Block (verified)

After first grid + row checksums complete, `CGameMap_LoadMapFileFromRelativePath` calls the ground/entity-layer exit-marker reader `CMapGroundEntityLayer_LoadExitMarkersFromMapReader` (`0x637769`) before the type-3 component block.

**Call order evidence in `CGameMap_LoadMapFileFromRelativePath`:**

- `0x61DEE5`: `CGameMap_FindFirstComponentWithTypeCode1`
- `0x61DEF4`: `CMapGroundEntityLayer_LoadExitMarkersFromMapReader(groundEntityLayerComponent, mapFileReader)`
- `0x61DEFB`: `CGameMap_FindFirstComponentWithTypeCode3`

**Ground/entity-layer exit-marker block layout (reader-relative):**

| Read order | Size | Meaning | Evidence |
|---|---:|---|---|
| 1 | `0x04` | exit marker entry count (`int32`) | `0x63777D` |
| 2 | `0x0C` each | one entry triplet (`int32 a`, `int32 b`, `int32 c`) | `0x637799` |

For each entry:

- `a` and `b` are passed to `Map_ProjectTileToScreenCoordinates` as tile coordinates (`0x6377C1`).
- Entry is upserted by `(a,b)` key via `CMapGroundEntityLayer_UpsertExitMarkerByTileCoordinates` (`0x637666`); field `c` is stored/updated as the third value (`0x6376D2`, `0x6376DA`, `0x6376E3`, `0x6376FB`).
- A type-3 text object labeled `"Exit"` is spawned at projected screen coordinates (`0x6377E0`), with color arg `0xFFFFFFFF`.

**Supporting map-grid setup renames in same caller chain (verified):**

- `CGameMap_FreeTileCellAttachmentGrid` (`0x61EA03`) runs at `0x61DC7A` after component reset.
- `CGameMap_SetTileGridDimensionsAndAllocateCells` (`0x61D949`) runs at `0x61DDFA` after reading grid width/height.
- `CGameMap_AllocateTileCellGrid` (`0x61EA88`) is called inside the above setup helper.

#### Post-Grid Scenery Subcomponent Block (native type code `3`, verified)

After the type-1 exit-marker block, `CGameMap_LoadMapFileFromRelativePath` calls `CMapSceneryComponent_LoadSubcomponentsFromMapReader` (`0x635808`) through the scenery component pointer returned by `CGameMap_FindFirstComponentWithTypeCode3`.

**Call order evidence in `CGameMap_LoadMapFileFromRelativePath`:**

- `0x61DEFB`: `CGameMap_FindFirstComponentWithTypeCode3`
- `0x61DF0A`: `CMapSceneryComponent_LoadSubcomponentsFromMapReader(sceneryComponent, mapFileReader)`

**Type-3 block top-level layout (reader-relative):**

| Read order | Size | Meaning | Evidence |
|---|---:|---|---|
| 1 | `0x04` | subcomponent entry count (`int32`) | `0x635829` |
| 2 | `0x04` each | per-entry type code (`int32`) | `0x63584A` |
| 3 | variable | per-type payload (by type code) | branch table below |

**Verified branch table in `CMapSceneryComponent_LoadSubcomponentsFromMapReader`:**

| Type code | Ctor | Loader | Extra call | Payload bytes read by loader | Evidence |
|---:|---|---|---|---:|---|
| `0x01` | `CMapTerrainObjectGroup_Constructor` | `CMapTerrainObjectGroup_LoadFromMapReader` | none | `0x10C` | branch compare `0x635853`; calls `0x635A4D`, `0x635A88` |
| `0x04` | `CMapType3SubcomponentType04_Constructor` | `CMapType3SubcomponentType04_LoadFromMapReader` | none | `0x1A0` | branch compare `0x63585C`; calls `0x6359BA`, `0x6359F5` |
| `0x0A` | `CMapType3SubcomponentType0A_Constructor` | `CMapType3SubcomponentType0A_LoadFromMapReader` | none | `0x48` | branch compare `0x635867`; calls `0x63592A`, `0x635965` |
| `0x0F` | `CMapType3SubcomponentType0F_Constructor` | `CMapType3SubcomponentType0F_LoadFromMapReader` | `CMapType3SubcomponentType0F_StartSoundPlayback` | `0x114` | branch compare `0x635870`; calls `0x63588F`, `0x6358CA`, `0x6358FD` |

Loop increments entry index at `0x635AC7` and continues while `index < count` (`0x635ACD..0x635AD0`).

**Scenery insertion helper behavior (`CMapSceneryComponent_InsertLoadedSubcomponent`, `0x63556E`):**

- Appends the loaded subcomponent pointer into type-3 component deque at `this+0x34` (call to deque helper at `0x63599B`).
- Reads runtime type code via virtual call `(*subcomponent->vtable[3])()` (`call [eax+0x0C]` at `0x6355A5`).
- If returned type code is `1`, calls `CMapSceneryComponent_AttachTerrainObjectGroupToTileGrid` (`0x6355C3`) to project/attach records into map tile attachments.
  - that helper resolves each terrain object's anchor tile and subtracts the per-cell grid coordinates
  - it allocates a `0x0C` `MapTileLinkNode`, copies metadata `surfaceId` to `node+0x00` and `passabilityFlag` to `node+0x02`, adds metadata `elevationDelta` to the current tail elevation for `node+0x04`, then appends the node through `MapTileEntry_SetTailLinkAttachmentRecordPointer`
  - `MapTileEntry_GetTailLinkElevation` (`0x61EBC5`) resolves the final node through `MapTileEntry_GetTailLinkNode` (`0x61EAEE`) and returns signed `node+0x04`
  - every later attachment therefore uses the preceding attachment's accumulated elevation and becomes the live surface/passability/elevation source
- If returned type code is `0x11`, appends pointer into a dedicated pointer array rooted at `this+0x0C` via `CMapType3Component_AppendType11SubcomponentPointer` (`0x6355B7`).

#### Terrain Object Group Load Block (type `0x01`, verified)

`CMapTerrainObjectGroup_LoadFromMapReader` (`0x63F58E`) reads the following payload from the map stream:

| Read order | Size | Destination offset in type-01 object | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x104` | `+0x48` | external object-list path C-string | read `0x63F5C3`, string copy `0x63F5ED` |
| 2 | `0x04` | `+0x0C` | anchor tile X | `0x63F5FD` |
| 3 | `0x04` | `+0x10` | anchor tile Y | `0x63F60D` |

Immediately after loading these fields, the function calls `CMapTerrainObjectGroup_LoadTerrainObjectListFromPath(this, this+0x48)` (`0x63F616`).

`CMapTerrainObjectGroup_LoadTerrainObjectListFromPath` (`0x63F24D`) behavior:

- Opens path from `this+0x48` in binary mode (`fopen(path, "rb")`, `0x63F278..0x63F28B`).
- Clears previously loaded terrain objects first (`CMapTerrainObjectGroup_ClearLoadedTerrainObjectList`, `0x63F2A9`).
- Reads `int32 externalObjectCount` from file start (`fread`, `0x63F2B9`).
- Copies the resolved list path string back into `this+0x48` (`0x63F2CF`).
- For each file entry:
  - allocates `0xB0` bytes and constructs `CMapTerrainObject_Constructor` (`0x63F2E2..0x63F300`);
  - creates a refcount control block (`CMapTerrainObject_CreateRefCountControlBlock`, `0x63F30D`);
  - loads the entry body through `CMapTerrainObject_LoadFromListFile` (`0x63F338`);
  - appends the shared object into the terrain-object deque via `CMapTerrainObjectGroup_TerrainObjectList_PushBack` (`0x63F362`).
- After all entries, calls type-01 virtual slot `+0x18` with `this+0x0C/+0x10` so newly loaded external objects receive anchor tile coordinates (`0x63F386..0x63F390`).

If file open fails, debug log path points to `2DMapTerrainObj.cpp` (`0x63F28F`) with message format `"ERROR: file %s not found at %s, %d"` (`0x63F29A`).

**Terrain-object list file entry layout (`CMapTerrainObject_LoadFromListFile`, `0x64489D`):**

| Read order | Size | Destination offset in external object (`0xB0`) | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x100` | `+0x34` | resource path A C-string | `fread` `0x6448F4`, copy `0x64491B` |
| 2 | `0x040` | `+0x28` | resource path B C-string | `fread` `0x64492C`, copy `0x64494A` |
| 3 | `0x04` | `+0x14` | render offset X | read `0x644958`, set call `CMapTerrainObject_SetRenderOffset` (`0x63AE41`) |
| 4 | `0x04` | `+0x18` | render offset Y | read `0x644963`, set call `CMapTerrainObject_SetRenderOffset` (`0x63AE41`) |
| 5 | `0x04` | `+0x40` | frame interval milliseconds | read/store `0x64497E..0x644984` |
| 6 | `0x04` | `+0x1C` | per-cell metadata grid width | read `0x64498F`, set call `0x6449A9` |
| 7 | `0x04` | `+0x20` | per-cell metadata grid height | read `0x64499A`, set call `0x6449A9` |
| 8 | `0x04` | `+0x24` | render color ARGB | read/store `0x6449B5..0x6449BB` |
| 9 | `0x04` | `+0x48` | anchor tile offset X | read `0x6449C6`, set call `0x6449DE` |
| 10 | `0x04` | `+0x4C` | anchor tile offset Y | read `0x6449D1`, set call `0x6449DE` |
| 11 | `0x04` | `+0x44` | draw parameter field | read/store `0x6449EC..0x6449F6` |
| 12 | variable | deque at `+0x58` | per-cell metadata records | nested loops `0x644A1A..0x644A8B`, each record reads 3 dwords and stores low 16 bits into `+6/+4/+8` (`0x644A41..0x644A73`) |

Per-cell metadata record count is `gridWidth * gridHeight` from terrain-object virtual slot `+0x1C` (`CMapTerrainObject_GetPerCellMetadataGridDimensions`, call `0x644A0D`).

The three metadata dwords have verified low-word semantics, in file order:

| File dword | Stored word | Attachment destination | Meaning |
|---:|---:|---:|---|
| 1 | metadata `+0x06` | node `+0x02` | `uint16 passabilityFlag` |
| 2 | metadata `+0x04` | node `+0x00` | `uint16 surfaceId` |
| 3 | metadata `+0x08` | node `+0x04` after addition | `int16 elevationDelta` |

Native truncates each dword to its low 16 bits and performs the elevation addition as a wrapping
16-bit add. Managed parsing/attachment must not reject high-word data or replace this with checked arithmetic.

#### MapPathService eight-neighbor search (verified)

`MapPathService_TryBuildPath` (`0x6208E2`) forwards through the service at `CGameMap+0x64` to
`MapPathService_BuildPathNodesAndUpdateNearestTile` (`0x634279`). Search details:

- Neighbor order is `(0,1), (-1,1), (-1,0), (-1,-1), (0,-1), (1,-1), (1,0), (1,1)`.
- Initialization rejects equal start/target coordinates and a missing start tile. The start tile is
  marked visited but is not required to be passable.
- A neighbor is accepted only when its tile exists, its search-visited byte at tile `+0x0C` is zero,
  its final tail node exists, `tail+0x02 == 0`, and the absolute signed elevation delta from the
  expanded tile is at most `25`.
- Cardinal and diagonal path costs are `10` and `14`. The heuristic is
  `10 * max(abs(x-targetX), abs(y-targetY))`.
- Tiles are marked visited on first discovery; there is no later cost relaxation.
- Search nodes are `0x1C` bytes: path cost `+0x00`, total estimated cost `+0x04`, parent index
  `+0x08`, direction index `+0x0C`, X/Y `+0x10/+0x14`, and tile pointer `+0x18`.
- The open heap compares total estimated cost only. Equal-cost push leaves the existing parent above
  the new node; equal left/right children during root adjustment select the right child.
- With `limitSearchNodes=true`, expansion stops when the already-created node count is greater than
  `360`; the check runs after pop and before neighbor expansion.
- The service tracks the discovered node with the lowest unsigned squared distance to the target.
  Exact target discovery is the only `true` result. When an output `MotionPath` is supplied, native
  clears it first and reconstructs parent directions to that exact or nearest node even when the target is unreachable.
- On exact discovery, the reconstruction node is the target, while the service's exposed fallback
  tile fields are set to the parent tile that discovered it. This asymmetry is native behavior.

#### Ground/Entity-Layer Tile-Attached Terrain-Object Consumer (verified boundary)

The tile-attachment producer path above does not draw directly. Native ground/entity-layer render is
mode-switched by `CMapGroundEntityLayer_LoadGroundPuzzleBitmapFromPath` (`0x638DBD`):

- `.pul` source path:
  - clears `component+0x04` to `0`
  - loads `component+0xA0` through `CMapPuzzleBitmap_LoadFromPath`
  - later render uses `CMapPuzzleBitmap_RenderAtOffset`
- non-`.pul` source path:
  - sets `component+0x04` to `1`
  - loads `component+0x08` through `CMapGroundEntityLayer_LoadTerrainCacheDataFromPath` (`0x648946`)
  - later render uses the tile-attached terrain-object cache path below

`CMapGroundEntityLayer_Render` (`0x638E44`) is mutually exclusive:

- when `component+0x04 == 0`, it calls `CMapPuzzleBitmap_RenderAtOffset(arg1+0xA0, -offsetX, -offsetY, 0, 0)`
- when `component+0x04 != 0`, it calls `CMapGroundEntityLayer_RenderTileAttachedTerrainObjects(arg1+0x08, -offsetX, -offsetY)`

So the tile-attached terrain-object cache path below is the non-`.pul` terrain-cache branch, not the
active newbie-map branch.

The non-`.pul` terrain-cache branch is a separate cache-and-render chain:

- `CGameMapGroundEntityLayerComponent_PerFrameTick` (`0x637566`) calls
  `CMapGroundEntityLayer_RebuildTileAttachedTerrainObjectRenderCache` (`0x639756`)
- that forwards into `CMapGroundEntityLayer_BuildTileAttachedTerrainObjectTargetBitmapCache`
  (`0x64A6C4`)
- visible draw later happens through `CMapGroundEntityLayer_RenderTileAttachedTerrainObjects` (`0x64991A`)

Verified visible-draw behavior in `CMapGroundEntityLayer_RenderTileAttachedTerrainObjects`:

- enumerates visible `0x100 x 0x100` ground/entity-layer tile buckets from the current render offsets
- uses live `CMyBitmap::GetScreenWidth/Height` for visible-range coverage, not fixed `800x600`
- applies `CGameMap_ApplyProjectionScaleAroundViewportCenter`
- looks up the tile bucket through `TileCoordinateAttachmentLookup_FindByTileCoordinates` (`0x67A55C`)
- when the lookup node payload pointer at `result[6]` is non-null, calls payload virtual slot `+0x14`
  with `(screenX, screenY, scale, scale, 0xFFFFFFFF)`

The deeper cached target-bitmap composition inside `CMapGroundEntityLayer_BuildTileAttachedTerrainObjectTargetBitmapCache`
is now pinned one level deeper:

- early-out when `CMyBitmap::IfDeviceLost() != 0`
- computes the visible `0x100 x 0x100` tile range from live `CMyBitmap::GetScreenWidth/Height`
  plus the current projection clamp scale
- accumulates the visible tile coordinate pairs with `StdVectorIntPair_PushBack` (`0x639789`)
- prunes stale lookup nodes from the tile-to-payload tree at `this+0x8C`
- reuses or creates a `256 x 256` `TargetBmp` payload per occupied tile bucket, then stores it through
  `TileCoordinateAttachmentLookup_UpsertPayloadSlotByTileCoordinates` (`0x64AAB6`)
- fills each target through `CMapGroundEntityLayer_RasterizeTileAttachmentTargetBitmap` (`0x64A0AE`)

Verified rasterization behavior inside
`CMapGroundEntityLayer_RasterizeTileAttachmentTargetBitmap`:

- calls `CMapGroundEntityLayer_PrepareQuarterTileTriangleVisibilityMask` (`0x649AD2`) for the target tile
- begins the target bitmap scene through target vtable `+0x04`
- clears the target with `CMyBitmap::ClearBuffer(0, 1, 0xFFFFFFFF)`
- iterates a `4 x 4` quarter-tile mosaic in `0x40 x 0x40` cells
- quarter-tile metadata comes from
  `CMapGroundEntityLayer_TryGetQuarterTileMetadataWord` (`0x6494CE`), which returns a packed dword from the
  metadata tree at `this+0x28`
- direct frame cells are drawn by
  `CMapGroundEntityLayer_DrawQuarterTileDirectFrameIntoTargetBitmap` (`0x64956B`)
- triangle-composite cells are drawn by
  `CMapGroundEntityLayer_DrawQuarterTileTriangleCompositeIntoTargetBitmap` (`0x649684`)
- the triangle-composite path selects descriptors through
  `CMapGroundEntityLayer_SelectPuzzleTriangleDescriptorByIndex` (`0x6490F8`) using the
  `m_pPuzzleTriangle` helper at `this+0x14`
- ends the target bitmap scene through target vtable `+0x08`

Current stable boundary:
- the offscreen tile cache payload and its draw/blit lifecycle are verified for the non-`.pul` terrain-cache mode
- the remaining unported producer in that mode is the metadata-tree build path that feeds the packed quarter-tile words at `this+0x28`
- the active newbie map loads `map\\puzzle\\newbie.pul`, which is `.pul` puzzle-bitmap mode, so this terrain-cache branch is not the leading blocker for the current hero/platform mismatch
- until the terrain-cache producer is fully ported, the managed client should not fake tile-attached terrain-object imagery by drawing terrain-object list entries directly

**Terrain-object callback map used by the terrain-object group owner (vtable `0x86A5C4`):**

- `+0x04`: `CMapTerrainObject_Render` (`0x64450F`)
- `+0x08`: `CMapTerrainObject_Tick` (`0x644B7D`)
- `+0x0C`: `CGameMapComponentType2_GetTypeCode` (`0x63738B`, returns `2`)
- `+0x14`: `CMapTerrainObjectBase_GetAnchorTileCoordinates` (`0x63FA61`)
- `+0x18`: `CMapTerrainObject_SetAnchorTileCoordinates` (`0x6450B7`)
- `+0x1C`: `CMapTerrainObject_GetPerCellMetadataGridDimensions` (`0x6450D9`)
- `+0x2C`: `CGameMapFileRecordType04EntryBase_SetColorArgb` (`0x637360`)
- `+0x24`: `CMapTerrainObject_HitTestCursorInFrame` (`0x644A94`)

`CMapTerrainObject_Render` (`0x64450F`):
- queries ANI resource by dual path:
  - `GameDataSetQuery()->vfunc+0x10(this+0x34, this+0x28, 0, 0x7530)` at `0x64452A..0x644540`
- frame selection:
  - if `this+0x40 == 0`, writes `1` before divide (`0x64455A..0x64455C`)
  - `this+0x80 = ((timeGetTime() - this+0x84) / (this+0x40)) % frameCount` (`0x644563..0x64457A`)
- render point build:
  - projects absolute pair `this+0x0C/+0x10` through `Map_ProjectTileToScreenCoordinates` (`0x644595..0x6445A5`)
  - converts to point-relative-to-projection-center through `CGameMap_GetPointRelativeToProjectionCenter` (`0x6445AA..0x6445BF`)
  - adds local render offsets `this+0x14/+0x18` (`0x6445C4..0x6445D3`)
  - applies `CGameMap_ApplyProjectionScaleAroundViewportCenter` (`0x6445D6..0x6445E5`)
- color source is `this+0x08`; bytes are split into `ARGB` and written via `frame->vfunc+0x20` (`0x6445EA..0x644619`)
- scaled frame size uses `CGameMap_GetProjectionClampScaleDivisor` / `data_93C6C0` (`0x64462B..0x644656`)
- draw call is `frame->vfunc+0x08(screenX, screenY, 0, scaledWidth, scaledHeight, 0, 0, 0)` (`0x64465C..0x644671`)
- after the frame draw, the external object renders its nested child deque rooted at `this+0x88/+0x8C`:
  - per nested child color write at `0x6446EA..0x6446FA`
  - per nested child render callback at `0x6446FD..0x644702`

#### Terrain Object Group Callback Body (native subtype `0x01`, verified)

`CMapTerrainObjectGroup` callback mapping from vtable `0x86A488`:
- `+0x04`: `NoOpVirtualCallback_Arg1` (`0x5AD9B1`) (render callback)
- `+0x08`: `CMapTerrainObjectGroup_Tick` (`0x63F621`)
- `+0x0C`: `CMapTerrainObjectGroup_GetTypeCode` (`0x651852`, returns `1`)
- `+0x18`: `CMapTerrainObjectGroup_SetAnchorTileCoordinatesAndPropagateToTerrainObjects` (`0x63F4D3`)
- `+0x24`: `CMapTerrainObjectGroup_HitTestAnyTerrainObject` (`0x63F42E`)

`CMapTerrainObjectGroup_Tick` (`0x63F621`):
- iterates loaded terrain-object deque rooted at `this+0x14/+0x18`,
- for each child object pointer, calls child `vtable+0x08` with tick argument passed into type-01 tick callback.

`CMapTerrainObjectGroup_SetAnchorTileCoordinatesAndPropagateToTerrainObjects` (`0x63F4D3`):
- writes anchor tile coordinates to `this+0x0C/+0x10`,
- iterates loaded terrain-object deque,
- calls child `vtable+0x18` with `(baseX + childField0x48, baseY + childField0x4C)`.

`CMapTerrainObjectBase_GetAnchorTileCoordinates` (`0x63FA61`):
- returns anchor tile coordinates from `this+0x0C/+0x10`.

`CMapTerrainObjectGroup_HitTestAnyTerrainObject` (`0x63F42E`):
- iterates loaded terrain-object deque and calls child `vtable+0x24`,
- returns `1` on first hit, otherwise `0`.

#### Type-3 Subcomponent Type `0x0A` Load/Render/Tick (verified)

`CMapType3SubcomponentType0A_LoadFromMapReader` (`0x63B89C`) reads this payload:

| Read order | Size | Destination offset in type-0A object | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x40` | `+0x48` | effect resource path C-string | `0x63B8C5`, `0x63B8E6` |
| 2 | `0x04` | `+0x14` | initial point X | `0x63B8F5` |
| 3 | `0x04` | `+0x18` | initial point Y | `0x63B8F5` |

Post-read calls in loader:
- `CMapType3SubcomponentType0A_ConfigureEffectFromMapPositionAndResourcePath(this, this+0x14, this+0x18, this+0x48, 1, 0)` (`0x63B907`)
- `effect->vfunc+0x68(-1)` via effect object at `this+0x54` (`0x63B913`)
- writes defaults:
  - `this+0x20 = 0` (`0x63B916`)
  - `this+0x24 = 0` (`0x63B91A`)
  - `this+0x1C = 1` (`0x63B91E`)
  - `this+0x28 = 1` (`0x63B921`)

`CMapType3SubcomponentType0A_Render` (`0x63B4C3`):
- updates fade on effect object: `effect->vfunc+0x4C((float)this+0x24)` (`0x63B4CC..0x63B4D8`)
- if `this+0x20 != 0`, returns early (`0x63B53C..0x63B540`)
- computes rotation phase from `this+0x44 % 8` and applies `(-1 - remainder) * 45 * 0.0174532924f` (`0x63B54B..0x63B564`)
- pushes transforms:
  - `effect->vfunc+0x2C(this+0x3C, 0, this+0x38 + phaseOffset, 0xFFFFFFFF, 0)` (`0x63B56A..0x63B587`)
  - `effect->vfunc+0x30(this+0x2C, this+0x30, this+0x34, 0xFFFFFFFF, 0)` (`0x63B58A..0x63B5A8`)
- renders effect:
  - `effect->vfunc+0x0C(this+0x14, this+0x18, 0xFFFFFFFF)` (`0x63B5AB..0x63B5B8`)

`CMapType3SubcomponentType0A_Tick` (`0x63B5E9`):
- if `this+0x20 != 0`, writes output status `1` and returns (`0x63B5F6..0x63B604`)
- otherwise:
  - `status = effect->vfunc+0x04()` and writes to `*arg` and `this+0x40` (`0x63B609..0x63B616`)
  - computes projection center from `this+0x14/+0x18`, projects to tile via `CGameMap_ProjectScreenPointToTileCoordinatesUnchecked`, and writes map projection pair through own `vfunc+0x18` (`0x63B619..0x63B657`)
  - resolves visibility margin via `CMapType3SubcomponentType0A_GetVisibilityMarginTilesFromIniOrDefault` (`0x63B665`)
  - calls `CGameMap_IsTileWithinScaledScreenBoundsWithMargin` and conditionally calls `CGameMap_NotifyType3ComponentSubcomponentUpdated(this)` (`0x63B670..0x63B6AF`)
  - final output-status contract used by `CGameMapComponentType3_PerFrameTick`:
    - if `this+0x1C == 0`, clears `*arg = 0` before return (`0x63B6B4..0x63B6B9`)
    - therefore direct insertion by the main type-3 tick happens only when the returned out-flag remains non-zero (`0x6354A0..0x6354D6`)

`CMapType3SubcomponentType0A_GetVisibilityMarginTilesFromIniOrDefault` (`0x63B33A`):
- lazy-loads `ini/MapEffectExtent.ini` once through `CMapType3SubcomponentType0A_LoadMapEffectExtentIni` (`0x63B353`)
- lookup key is effect path from `this+0x48`, default fallback is `8` if key not found (`0x63B3A3..0x63B3AC`).

#### Type-3 Subcomponent Type `0x0F` Load/Sound callbacks (verified)

`CMapType3SubcomponentType0F_LoadFromMapReader` (`0x645934`) reads this payload:

| Read order | Size | Destination offset in type-0F object | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x104` | `+0x2C` | sound path C-string | `0x64596B`, `0x645993` |
| 2 | `0x04` | `+0x0C` | initial sound screen X | `0x6459A2` |
| 3 | `0x04` | `+0x10` | initial sound screen Y | `0x6459A2` |
| 4 | `0x04` | `+0x24` | sound play parameter #4 | `0x6459B1` |
| 5 | `0x04` | `+0x28` | sound play parameter #6 | `0x6459C8` |

`CMapType3SubcomponentType0F_StartSoundPlayback` (`0x6459CB`):
- if `this+0x20` (sound handle) nonzero, closes with `_DXClose2DSound@4` (`0x6459D3..0x6459D6`)
- starts with `_DXPlaySound@24(this+0x2C, this+0x0C, this+0x10, this+0x24, -1, this+0x28)` (`0x6459EE`)
- stores returned sound handle to `this+0x20` (`0x6459F4`).

`CMapType3SubcomponentType0F` callback mapping from vtable `0x86A62C`:
- `+0x04`: `NoOpVirtualCallback_Arg1` (`0x5AD9B1`) (render callback)
- `+0x08`: `NoOpVirtualCallback_Arg1` (`0x5AD9B1`) (tick callback)
- `+0x0C`: `CMapType3SubcomponentType0F_GetTypeCode` (`0x645A1C`, returns `0x0F`)
- `+0x14`: `CMapType3SubcomponentType0F_GetMapProjectionPair` (`0x6459F9`)
- `+0x18`: `CMapType3SubcomponentType0F_SetMapProjectionPair` (`0x645A0B`)
- `+0x34`: `CMapType3SubcomponentType0F_SetSoundScreenPositionAndProjectTilePair` (`0x6458EF`)

`CMapType3SubcomponentType0F_SetSoundScreenPositionAndProjectTilePair` (`0x6458EF`):
- writes `this+0x0C/+0x10` with new sound screen position,
- if sound handle exists, calls `_DXSet2DSoundPos@12(handle, x, y)`,
- projects screen point to tile via `CGameMap_ProjectScreenPointToTileCoordinatesUnchecked` into `this+0x14/+0x18`,
- applies fixed X adjustment `this+0x14 -= 0x3C`.

#### Type-3 Subcomponent Type `0x04` Load/Render/Tick (verified non-zero ANI color path)

`CMapType3SubcomponentType04_LoadFromMapReader` (`0x645654`) reads this payload:

| Read order | Size | Destination offset in type-04 object | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x104` | `+0x14` | ANI path string #1 | `0x64569F`, `0x6456CA` |
| 2 | `0x80` | `+0x20` | ANI path string #2 | `0x6456DB`, `0x6456FA` |
| 3 | `0x04` | `+0x0C` | tile X | `0x645708` |
| 4 | `0x04` | `+0x10` | tile Y | `0x645716` |
| 5 | `0x04` | `+0x34` | depth-span tiles X | `0x645724`, returned by child `vtable+0x1C` at `0x645649` |
| 6 | `0x04` | `+0x38` | depth-span tiles Y | `0x645732`, returned by child `vtable+0x1C` at `0x64564E` |
| 7 | `0x04` | `+0x2C` | render offset X | `0x645740` |
| 8 | `0x04` | `+0x30` | render offset Y | `0x64574E` |
| 9 | `0x04` | `+0x40` | frame-interval ms | `0x645765` |

`CMapType3SubcomponentType04` vtable at `0x86A5F8` (verified from clean `Conquer.exe`):

| Slot | Address | Function | Meaning |
|---:|---:|---|---|
| `+0x04` | `0x645203` | `CMapType3SubcomponentType04_Render` | render callback |
| `+0x08` | `0x6454D1` | `CMapType3SubcomponentType04_Tick` | tick callback |
| `+0x0C` | `0x645804` | `CMapType3SubcomponentType04_GetTypeCode` | returns `4` |
| `+0x10` | `0x64B9A1` | `CMapPositionedObj_GetProjectedScreenCoordinates` | projects `this+0x0C/+0x10` tile coordinates to absolute screen coordinates |
| `+0x14` | `0x6D1E51` | `CMapPositionedObj_GetTileCoordinates` | copies `this+0x0C/+0x10` into output pair |
| `+0x18` | `0x6322FD` | `CMapPositionedObj_SetTileCoordinates` | writes `this+0x0C/+0x10` |
| `+0x1C` | `0x645642` | `CMapType3SubcomponentType04_GetDepthSpanTiles` | copies `this+0x34/+0x38` into output pair |
| `+0x20` | `0x645631` | `CMapType3SubcomponentType04_SetDepthSpanTiles` | writes `this+0x34/+0x38` |
| `+0x24` | `0x645768` | `CMapType3SubcomponentType04_HitTest` | cursor/frame hit-test |
| `+0x2C` | `0x637360` | `CGameMapFileRecordType04EntryBase_SetColorArgb` | map color writer |
| `+0x30` | `0x63736A` | `CGameMapFileRecordType04EntryBase_GetColorArgb` | map color getter |

Color source for this object is `this+0x08`:

- `CGameMapFileRecordType04EntryBase_SetColorArgb` (`0x637360`) writes `this+0x08`.
- `CGameMapFileRecordType04EntryBase_GetColorArgb` (`0x63736A`) reads `this+0x08`.
- concrete writer chain to this field in map render flow:
  - `CGameMap_ApplyProjectionColorBlend` (`0x61FC13`) writes `CGameMap+0x13C` (`ProjectionColorField13C`) (`0x61FC5F`, `0x61FCDC`, `0x61FD8F`).
  - `CGameMapComponentType3_MapComponentRenderTick` (`0x6352F4`) calls child `vtable+0x2C` with that `ProjectionColorField13C` value (`0x63534F`).
  - for subtype-04 entries, `vtable+0x2C` resolves to `CGameMapFileRecordType04EntryBase_SetColorArgb` (`0x637360`), so `this+0x08` is refreshed each render dispatch.

`CMapType3SubcomponentType04_Render` (`0x645203`) ANI draw path:

1. Query ANI resource by dual path: `GameDataSetQuery()->vfunc+0x10(this+0x14, this+0x20, 0, 0xEA60)` (`0x645227`).
2. Resolve absolute projected screen coordinates through child `vtable+0x10` (`0x64523C`), which for subtype-04 resolves to `CMapPositionedObj_GetProjectedScreenCoordinates` (`0x64B9A1`) and projects tile coordinates `this+0x0C/+0x10`.
3. Convert those absolute coordinates relative to the current projection center via `CGameMap_GetPointRelativeToProjectionCenter` (`0x645254`), subtract render offsets `this+0x2C/+0x30` (`0x64525F`, `0x645268`), and apply projection scaling (`0x64527A`).
4. Resolve current frame: `resource->vfunc+0x10(this+0x3C)` (`0x645286`).
5. Read frame size: `frame->vfunc+0x14(&w,&h)` (`0x64529F`) and apply projection scaling (`0x6452B2..0x6452DA`).
6. Normal branch (`data_96AA6C == 0`):
   - read `colorArgb = this+0x08` (`0x6452DF`),
   - call `frame->vfunc+0x20(alpha, red, green, blue)` with bytes extracted as
     `(colorArgb>>24, colorArgb>>16, colorArgb>>8, colorArgb&0xFF)` (`0x6452E4..0x6452F9`),
   - draw via `frame->vfunc+0x08(x, y, 0, w, h, 0, drawParam=this+0x48, 0)` (`0x645314`).
7. Hover-highlight branch (`data_96AA6C != 0`, cursor tile match at `0x64535B..0x645369`):
   - `frame->vfunc+0x20(0x77, 0xFF, 0xFF, 0xFF)` (`0x645379`),
   - draw same call signature (`0x645394`),
   - restore white `frame->vfunc+0x20(0xFF, 0xFF, 0xFF, 0xFF)` (`0x64539F`).

`CMapType3SubcomponentType04_Tick` (`0x6454D1`) updates frame index:

- begins by resolving projected absolute screen coordinates through child `vtable+0x10` (`0x6454E4`), then converts relative to projection center through `CGameMap_GetPointRelativeToProjectionCenter` (`0x6454FC`).
- render offsets are subtracted from that projected point (`0x645504`, `0x64550A`) before tile visibility projection.
- visibility gate: `CGameMap_IsTileWithinScaledScreenBoundsWithMargin` (`0x645545`),
- frame index write: `this+0x3C = ((timeGetTime()-this+0x44)/(this+0x40)) % frameCount` (`0x64558D..0x645593`),
- visibility-margin helper: `CMapType3SubcomponentType04_GetVisibilityMarginTilesFromCachedFrameExtents` (`0x6454C4`) returns `max(this+0x50, this+0x54)`,
- notify reorder path: `CGameMap_NotifyType3ComponentSubcomponentUpdated(this)` (`0x645625`).
- main type-3 tick still routes subtype `0x04` through the active-render update helper at `0x6354D6` after the tick callback returns (`0x635449..0x6354D6`).

Practical consequence for managed parity:
- subtype-04 payload `+0x34/+0x38` must not be used as a render-position pair.
- render/tick screen origin comes from tile projection of `this+0x0C/+0x10`.
- payload `+0x34/+0x38` belong to the active-render depth-order contract only.

#### Post-Type3 Type-4 Record Block (verified)

Immediately after the type-3 block call returns, `CGameMap_LoadMapFileFromRelativePath` reads another counted block and creates one in-memory record object when per-entry type code is `4`.

**Call/order evidence in `CGameMap_LoadMapFileFromRelativePath`:**

- `0x61DF19`: read outer entry count (`int32`).
- per entry:
  - `0x61DF34`: read insert index (`int32`).
  - `0x61DF43`: read record type code (`int32`).
  - `0x61DF4C`: branch `if (recordType == 4)`:
    - `0x61DF50`: allocate `0x34` bytes.
    - `0x61DF63`: `CGameMapFileRecordType04_Constructor`.
    - `0x61DF93..0x61DF9F`: insert object pointer into map deque at `map+0x04` using insert-index path.
    - `0x61DFAA`: `CGameMapFileRecordType04_LoadFromMapReader(object, mapFileReader)`.
- loop increment/compare at `0x61DFB1..0x61DFBA`.
- map loaded-flag write at `0x61DFC0` (`map+0xE4 = 1`).

**Outer block layout (reader-relative):**

| Read order | Size | Meaning | Evidence |
|---|---:|---|---|
| 1 | `0x04` | outer entry count (`int32`) | `0x61DF19` |
| 2 | `0x04` each | insert index (`int32`) | `0x61DF34` |
| 3 | `0x04` each | record type code (`int32`) | `0x61DF43` |
| 4 | variable | type-4 payload only when record type == `4` | `0x61DF4C..0x61DFAA` |

Entries with record type not equal to `4` consume no additional bytes in this function; the loop advances to next outer entry (`0x61DFB1`).

#### Type-4 Record Payload (`CGameMapFileRecordType04_LoadFromMapReader`, `0x639BD6`)

`CGameMapFileRecordType04_LoadFromMapReader` starts by reading two header ints into object fields (`this+0x04`, `this+0x08`), then reads a child-entry count and dispatches child-entry loader by child type code.

**Top-level layout inside one type-4 record:**

| Read order | Size | Destination | Meaning | Evidence |
|---|---:|---|---|---|
| 1 | `0x04` | `this+0x04` | header int #0 | `0x639BF7`, `0x639C15` |
| 2 | `0x04` | `this+0x08` | header int #1 | `0x639C06`, `0x639C1C` |
| 3 | `0x04` | local | child-entry count (`int32`) | `0x639C25` |
| 4 | `0x04` each | local | child entry type code (`int32`) | `0x639C42` |
| 5 | variable | child object | child payload by type code | branch table below |

**Child type branch table:**

| Child type code | Constructor | Loader | Alloc size | Loader bytes read | Evidence |
|---:|---|---|---:|---:|---|
| `3` | `CGameMapFileRecordType04EntryType03_Constructor` | `CGameMapFileRecordType04EntryType03_LoadFromMapReader` | `0x44` | `0x19C` | compare `0x639C4D`; calls `0x639D0A`, `0x639D42` |
| `8` | `CGameMapFileRecordType04EntryType08Puzzle_Constructor` | `CGameMapFileRecordType04EntryType08Puzzle_LoadFromMapReader` | `0x164` | `0x104` | compare `0x639C57`; calls `0x639C79`, `0x639CB5` |

Both known child types are appended through `CGameMapFileRecordType04_AppendEntryToPointerArray` (`0x639CDF` / `0x639D6C`), which writes into the type-4 record pointer array rooted at `this+0x0C`.

#### Child Type-3 Payload (`CGameMapFileRecordType04EntryType03_LoadFromMapReader`, `0x64B674`)

| Read order | Size | Destination offset in child-type3 object | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x104` | `+0x14` | path string #1 | `0x64B6BF`, `0x64B6EA` |
| 2 | `0x80` | `+0x20` | path string #2 | `0x64B6FB`, `0x64B71A` |
| 3 | `0x04` | `+0x0C` | tile X | `0x64B728`, consumed by tick/render at `0x64B615` / `0x64B9C0` |
| 4 | `0x04` | `+0x10` | tile Y | `0x64B736`, consumed by tick/render at `0x64B615` / `0x64B9C0` |
| 5 | `0x04` | `+0x2C` | render offset X | `0x64B744`, consumed at `0x64B4EB` |
| 6 | `0x04` | `+0x30` | render offset Y | `0x64B752`, consumed at `0x64B4F4` |
| 7 | `0x04` | `+0x38` | frame interval milliseconds | `0x64B760`, consumed at `0x64B65F` |
| 8 | `0x04` | `+0x40` | raw int32 field | `0x64B777` |

Total bytes read by this loader: `0x19C`.

`CGameMapFileRecordType04EntryType03_GetEntryTypeCode` returns `3` (`0x64D014`), matching the branch discriminator used by the parent record loader.

Constructor defaults from `CGameMapFileRecordType04EntryType03_Constructor` (`0x64B397`):

| Offset | Value | Meaning | Evidence |
|---:|---:|---|---|
| `+0x34` | `0` | current frame index default | `0x64B406` |
| `+0x38` | `1` | frame interval default before load overwrite | `0x64B40C` |
| `+0x3C` | `timeGetTime()` | frame cycle start tick | `0x64B3D3` |

#### Child Type-8 Puzzle Payload (`CGameMapFileRecordType04EntryType08Puzzle_LoadFromMapReader`, `0x64B8F5`)

| Read order | Size | Destination offset in child-type8 object | Meaning | Evidence |
|---|---:|---:|---|---|
| 1 | `0x104` | `+0x14` | puzzle bitmap path string | `0x64B912`, `0x64B96E` |

The loader asserts bitmap load success via debug string from `2DMapPuzzleObj.cpp` (`0x64B92C..0x64B940`).

`CGameMapFileRecordType04EntryType08Puzzle_GetEntryTypeCode` returns `8` (`0x64B974`), matching the parent branch discriminator.

#### Type-4 Runtime Execution in Real Map Tick/Render Dispatch (verified)

Loaded type-4 records are executed by the same frame dispatch loops that run default map components.

**Insertion into component deque (load-time evidence):**

- `CGameMap_LoadMapFileFromRelativePath` allocates and constructs type-4 record objects when outer record type is `4` (`0x61DF50`, `0x61DF63`).
- The constructed pointer is inserted into the map component deque rooted at `map+0x04` through the insert-index path (`0x61DF93..0x61DF9F`).
- This insertion occurs before `CGameMapFileRecordType04_LoadFromMapReader` (`0x61DFAA`), so loaded records become regular deque members for later frame callbacks.

**Frame tick dispatch path:**

- `CMyShellDlg_RunFrameTick` calls `CGameMap_TickComponentsAndProcessScreenEffects` (xref at `0x5DD0CC`).
- `CGameMap_TickComponentsAndProcessScreenEffects`:
  - gets deque count from `map+0x04/+0x14` (`0x61D464`),
  - iterates each deque element (`0x61D474..0x61D4A2`),
  - calls component virtual callback at slot `+0x8` with literal `0` (`call [eax+0x8]` at `0x61D496`).

**Frame render dispatch path:**

- `Exe_TickMapProjectionAndDispatchMapRender` calls `CGameMap_RenderComponentsAndShowScreenEffects` (xref at `0x5ACB88`).
- `CGameMap_RenderComponentsAndShowScreenEffects`:
  - computes projection offsets via `CGameMap_GetComponentRenderProjectionOffset` (`0x61D213`),
  - gets deque count from `map+0x04/+0x14` (`0x61D21F`),
  - iterates each deque element (`0x61D231..0x61D263`),
  - calls component virtual callback at slot `+0x4` with `(projectionOffsetX, projectionOffsetY)` (`call [eax+0x4]` at `0x61D257`).

**Type-4 vtable slot mapping (ties deque callbacks to type-4 methods):**

- `CGameMapFileRecordType04_Constructor` writes `CGameMapFileRecordType04_VTable` into `this->vtable` (`0x639947`).
- `CGameMapFileRecordType04_VTable + 0x04` points to `CGameMapFileRecordType04_Render` (data ref at `0x86A320`).
- `CGameMapFileRecordType04_VTable + 0x08` points to `CGameMapFileRecordType04_Tick` (data ref at `0x86A324`).
- `CGameMapFileRecordType04_VTable + 0x0C` points to `CGameMapFileRecordType04_GetTypeCode` (data ref at `0x86A328`), which returns `4` (`0x43E331`).

Result: once inserted during map load, type-4 record callbacks are executed automatically by the standard map component tick/render loops in real client frame flow.

#### Type-4 Parent Render Context Build (`CGameMapFileRecordType04_Render`, `0x6399D0`)

For each frame render callback of a type-4 component, the parent computes a temporary context block and passes it to each child entry render callback (`child->vfunc+0x4`, call at `0x639ADB`).

Context values written before child dispatch:

| Temp slot | Value | Evidence |
|---:|---|---|
| `ctx[0]` | `rootScreenX` | `0x639A70` (`var_5c`) |
| `ctx[1]` | `rootScreenY` | `0x639A7C` (`var_58`) |
| `ctx[4]` | parent header int0 (`this+0x04`) | `0x639A7F` (`var_4C`) |
| `ctx[5]` | parent header int1 (`this+0x08`) | `0x639A8A` (`var_48`) |

Verified formulas used by parent render:

```c
projectionCenterX = map->field_0x48 + (GetScreenWidth() / 2);
projectionCenterY = map->field_0x4C + (GetScreenHeight() / 2);

GetTileGridDimensions(map, &gridWidth, &gridHeight); // map+0x2C/+0x30
halfMapWidth  = ((gridWidth  << 6) / 2);
halfMapHeight = ((gridHeight << 5) / 2);

rootScreenX = ((headerInt0 * (projectionCenterX - halfMapWidth)) / 100)
            + halfMapWidth - (GetScreenWidth() / 2);
rootScreenY = ((headerInt1 * (projectionCenterY - halfMapHeight)) / 100)
            + halfMapHeight - (GetScreenHeight() / 2);
```

Evidence chain: `0x6399E3..0x639A8A`.

#### Child Type-3 Runtime (`CGameMapFileRecordType04EntryType03_Render`, `0x64B48F`; `Tick`, `0x64B601`)

`Type03_Render` (`0x64B48F`) exact call flow:

1. Query resource by both path strings:
   - `GameDataSetQuery()->vfunc+0x10(pathPrimary@+0x14, pathSecondary@+0x20, 0, 0x7530)` (`0x64B4B3`)
2. If resource exists:
   - Get projected tile screen coordinates from entry callback (`0x64B4C8` -> `CMapPositionedObj_GetProjectedScreenCoordinates` at `0x64B9A1`)
   - Convert to projection-relative point via `CGameMap_GetPointRelativeToProjectionCenter` (`0x64B4E0`)
   - Subtract entry render offsets (`this+0x2C/+0x30`) (`0x64B4EB`, `0x64B4F4`)
   - Apply projection scaling around viewport center via `CGameMap_ApplyProjectionScaleAroundViewportCenter` (`0x64B506`)
   - Get current frame by index `this+0x34` (`resource->vfunc+0x10`, `0x64B512`)
   - If frame exists:
     - Read frame size (`frame->vfunc+0x14`, `0x64B527`)
     - Scale width/height by `GetProjectionClampScaleDivisor(map)/data_93C6C0` (`0x64B53A..0x64B55F`)
     - Draw frame (`frame->vfunc+0x8`) with `(x, y, 0, w, h, 0, 0, 0)` (`0x64B574`)
   - Always draw resource (`resource->vfunc+0x8`) with `(frameIndex, x, y, 0, 0)` (`0x64B588`)
3. Optional debug rectangle if `data_96AAF4 != 0` and frame exists:
   - Re-read frame size, apply same scaling, call `CMyBitmap::ShowRect(x, y, x+w, y+h, 0xFFFFFF00)` (`0x64B596..0x64B5F1`).

Cross-DLL slot resolution for the type-3 ANI path (verified end-to-end):

| Caller contract | Address evidence | Callee symbol | Module |
|---|---:|---|---|
| `GameDataSetQuery()->vfunc+0x10(path1, path2, mode, timeout)` | `Conquer.exe 0x64B4B3`, `GraphicData.dll vtable slot @ 0x100301A0` | `GameDataSet_QueryAniResourceByDualPath` (`0x100045E0`) | `GraphicData.dll` |
| Request-job case `type=4` for dual-string ANI load | `GraphicData.dll 0x10009EF8..0x10009F18` | `GameDataSetRequest_ExecuteLoadByType` -> `GameDataSet_CreateAniResource` (`0x100062B0`) | `GraphicData.dll` |
| ANI object creation | `GraphicData.dll 0x100062C9` | `AniCreate` (`0x1000BFE0`) | `graphic.dll` |

`CAniX` vtable layout used by type-3 runtime (`graphic.dll`, `CAniX_VTable @ 0x1003994C`):

| Slot | Function | Evidence |
|---:|---|---|
| `+0x08` | `CAniX_DrawFrameAt` (`0x1000BE20`) | called from Conquer `resource->vfunc+0x8` (`0x64B588`) |
| `+0x10` | `CAniX_GetFrameAt` (`0x1000BF30`) | called from Conquer `resource->vfunc+0x10` (`0x64B512`) |
| `+0x14` | `C3MotionTracker_GetMotionCount` reused as `CAniX` frame-count getter (`0x10007140`) | called from Conquer `resource->vfunc+0x14` (`0x64B65F`) |

Frame-object vtable layout used by type-3 runtime (`graphic.dll`, `CMyBitmapSpriteFrame_VTable @ 0x10039A34`):

| Slot | Function | Evidence |
|---:|---|---|
| `+0x08` | `CMyBitmapSpriteFrame_DrawSubRectAt` (`0x10012190`) | called from Conquer `frame->vfunc+0x8` (`0x64B574`) |
| `+0x14` | `CMyBitmapSpriteFrame_GetDimensions` (`0x10012520`) | called from Conquer `frame->vfunc+0x14` (`0x64B527`) |
| `+0x20` | `CMyBitmapSpriteFrame_SetColorArgbBytes` (`0x100125D0`) | called from Conquer `frame->vfunc+0x20` (`0x6452F9`, `0x645379`, `0x64539F`) |

Verified sprite draw-state contract under type-3 ANI path (`graphic.dll`):

| Function | Address | Verified behavior |
|---|---:|---|
| `CAniX_DrawFrameAt` | `0x1000BE20` | Reads frame count at `this+0x04`; if `<=0` returns `0`; otherwise computes `frameIndex % frameCount` and dispatches selected frame vtable `+0x04` (DrawAt) with `(x, y, color, drawParam)`. |
| `CMyBitmapSpriteFrame_DrawAt` | `0x10012120` | If `g_spritePrepareFlag != 1`, calls `CMyBitmap::PrepareSprite`; if `colorArg != 0`, calls `Sprite_SetColor(sprite, colorArg.b, 0xFF, 0xFF, 0xFF)` (low byte only, alpha feed); if `colorArg == 0`, no color write occurs (sprite keeps prior vertex color); then `Sprite_SetCoor(sprite, 0, x, y, 0, 0)` and `Sprite_Draw(sprite, drawParam)`. |
| `CMyBitmapSpriteFrame_DrawSubRectAt` | `0x10012190` | Branches on `(arg3,arg4,arg5)==0`: zero-branch uses `Sprite_SetCoor(sprite, 0, x, y, 0, 0)`; non-zero branch uses `Sprite_SetCoor(sprite, arg3, x, y, arg4, arg5)`; both branches share prepare-gate, color gate (`arg7 != 0` => `Sprite_SetColor(sprite, arg7.b, 0xFF, 0xFF, 0xFF)`, else no write), optional rotate (`arg8`), then `Sprite_Draw(sprite, arg7)`. |
| `CMyBitmap::PrepareSprite` | `0x100136B0` | If `g_spritePrepareFlag != 1`, calls `Sprite_Prepare()` and then sets `g_spritePrepareFlag = 1`. |

Type-3 callsite argument mapping into `CMyBitmapSpriteFrame_DrawSubRectAt` (`Conquer.exe 0x64B562..0x64B574`):

- pushes `(x, y, 0, scaledWidth, scaledHeight, 0, 0, 0)`
- therefore native type-3 render always uses the non-zero-size `Sprite_SetCoor` path (`arg3=0`, `arg4=scaledWidth`, `arg5=scaledHeight`)
- color/draw/rotation are zero for this callsite in clean 5517 data path; with `color=0` this callsite does not issue `Sprite_SetColor` and therefore relies on sprite default color (`0xFFFFFFFF` from `Sprite_Clear`) unless changed earlier.
- non-zero ANI color writes in native are still verified via `CMapType3SubcomponentType04_Render` (`0x645203`), which uses `frame->vfunc+0x20` color writes before draw.

ANI text-index parse contract used by native ANI lookup:

- Loader: `CAniFileSet_LoadAniIndexFile` (`graphic.dll 0x1000C240`)
  - section header parse via `sscanf("[%s")` (`0x1000C387`)
  - `FrameAmount=%d` parse (`0x1000C3C7`)
  - per-frame `Frame%d=%s` parse (`0x1000C432..0x1000C47E`)
- Section lookup: `CAniFileSet_FindAniIndexInfoBySectionName` (`graphic.dll 0x1000C8D0`)
- Combined file+section lookup used by ANI create path:
  `CAniFileSet_FindAniIndexInfoByFileAndSection` (`graphic.dll 0x1000CEC0`)

`Type03_Tick` (`0x64B601`) exact call flow:

1. Visibility gate: `CGameMap_IsTileWithinScaledScreenBoundsWithMargin(map, tileX@+0x0C, tileY@+0x10, 8)` (`0x64B615`).
2. If visible:
   - Query resource using same `(path1, path2, 0, 0x7530)` (`0x64B637`)
   - If resource exists:
     - `elapsed = timeGetTime() - this+0x3C`
     - `cycle = elapsed / this+0x38`
     - `frameCount = resource->vfunc+0x14()`
     - `this+0x34 = cycle % frameCount` (`0x64B65F`)
   - Notify map type-3 component reorder path:
     - `CGameMap_NotifyType3ComponentSubcomponentUpdated(this)` (`0x64B669`)

Helper functions used by this runtime:

| Function | Address | Verified behavior |
|---|---:|---|
| `Map_ProjectTileToScreenCoordinates` | `0x61D850` | `x = ((tileX-tileY)<<6)/2 + map+0x40`, `y = ((tileX+tileY)<<5)/2 + map+0x44` |
| `CGameMap_IsTileWithinScaledScreenBoundsWithMargin` | `0x61E00D` | Computes margin-scaled bounds and checks projected tile is within `[min,max]` window |
| `CGameMap_ApplyProjectionScaleAroundViewportCenter` | `0x61F0BD` | Scales point around `(screenW/2, screenH/2)` by `GetProjectionClampScaleDivisor()/data_93C6C0` |
| `CGameMap_GetProjectionClampScaleDivisor` | `0x61EDD6` | `(map+0x154 * map+0x140) / 100` |
| `CGameMap_GetPointRelativeToProjectionCenter` | `0x61D762` | subtract map center (`map+0x48/+0x4C`) |
| `CGameMap_GetPointAbsoluteFromProjectionCenter` | `0x61D8C6` | add map center (`map+0x48/+0x4C`) |

#### Child Type-8 Puzzle Runtime (`CGameMapFileRecordType04EntryType08Puzzle_Render`, `0x64B848`)

`Type08_Render` consumes the parent context pointer produced by `CGameMapFileRecordType04_Render`.

Call flow:

1. Return immediately if render context pointer is null (`0x64B857`).
2. Read:
   - `rootScreenX = ctx[0]` (`0x64B85D`)
   - `rootScreenY = ctx[1]` (`0x64B863`)
   - `ctx[4]`, `ctx[5]` copied to object fields `this+0x158/+0x15C` (`0x64B8DD`, `0x64B8E3`)
3. Read map tile dimensions via `CGameMap_GetTileGridDimensions(map, &w, &h)` (`0x64B875`), where `map+0x2C/+0x30` are returned (`0x61D93E`).
4. Compute half-map extents:
   - `halfMapWidth = ((w << 6) / 2)` (`0x64B880`)
   - `halfMapHeight = ((h << 5) / 2)` (`0x64B88B`)
5. Query puzzle bitmap scaled dimensions via `CMapPuzzleBitmap_GetScaledBitmapDimensions(this+0x20, &bmpW, &bmpH)` (`0x64B8A1`).
6. Set `this+0x34 = 0` (`0x64B8C9`).
7. Render puzzle bitmap:

```c
offsetX = -(rootScreenX - (halfMapWidth  - (bmpW /2)));
offsetY = -(rootScreenY - (halfMapHeight - (bmpH /2)));
CMapPuzzleBitmap_RenderAtOffset(this+0x20, offsetX, offsetY, 0, 0);
```

Evidence: `0x64B8E9`.

`CGameMapFileRecordType04EntryType08Puzzle_TickNoOp` (`0x64B975`) is an explicit no-op.

#### `CMapPuzzleBitmap` Load/State Contract (adapter parity evidence)

Verified constructor and load helpers for the embedded puzzle-bitmap state used by type-8 entries:

| Function | Address | Verified behavior |
|---|---:|---|
| `CMapPuzzleBitmap_LoadFrameIntervalFromInfoIni` | `0x639E71` | Reads `ini/Info.ini` section `PuzzleBmp`, key `FrameIntervalMilliSec`, default `1000`; writes result to global `data_969A40`. |
| `CMapPuzzleBitmap_Constructor` | `0x639F34` | Initializes defaults including `scaleField(+0x124)=data_93D218` (`0x100` in clean 5517), `headerScaleX(+0x138)=100`, `headerScaleY(+0x13C)=100`, timestamps (`+0x134=timeGetTime()`, `+0x0C=0`), and clears/zeros owned buffers. |
| `CMapPuzzleBitmap_ResetPuzzleIndexGrid` | `0x639FE7` | Frees pointer at `+0x10` when present, then clears `+0x10` and `+0x04`. |
| `CMapPuzzleBitmap_InitializePuzzleIndexGrid` | `0x63A006` | Stores tile dimensions to `+0x18/+0x1C`, allocates `tileCountX*tileCountY` ushort entries at `+0x10`, fills each with `0xFFFF`, stores total count at `+0x04`. |
| `CMapPuzzleBitmap_LoadFromPath` | `0x63A603` | Opens payload, validates signature (`PUZZLE`/`PUZZLE2`), copies texture-prefix string (`0x100` bytes) to `+0x20`, reads tile dimensions and ushort index grid, and for `PUZZLE2` reads scroll velocities into `+0x128/+0x12C`. |
| `CMapPuzzleBitmap_GetScaledBitmapDimensions` | `0x63A7DC` | `widthPixels = *(+0x18) * *(+0x124)`, `heightPixels = *(+0x1C) * *(+0x124)`. |
| `CMapPuzzleBitmap_RenderAtOffset` | `0x63A04B` | Uses literal `0x320/0x258` (`800x600`) for visible tile-range enumeration before applying projection scale around the live viewport center. |

`CMapPuzzleBitmap_LoadFromPath` read contract (exact block order):

1. Signature bytes (`8`) compared against `"PUZZLE"` / `"PUZZLE2"` (`0x63A66E..0x63A6BD`).
2. Texture-prefix path field (`0x100`) copied to `this+0x20` (`0x63A6D5..0x63A6FD`).
3. Tile dimensions (`int32 width`, `int32 height`) (`0x63A70D..0x63A718`).
4. `CMapPuzzleBitmap_InitializePuzzleIndexGrid(this, width, height)` (`0x63A725`).
5. Index grid read: `fread(this+0x10, 2, this+0x04, file)` (`0x63A733`).
6. `PUZZLE2` only: `fread(this+0x128, 4, 1)` and `fread(this+0x12C, 4, 1)` (`0x63A74D..0x63A75B`); otherwise both fields are zeroed (`0x63A762..0x63A769`).

Managed adapter implications used in current port slice:

- puzzle payload parser must preserve `PUZZLE/PUZZLE2` mode, texture-prefix path, tile dimensions, full ushort index grid, and optional scroll velocities.
- scaled bitmap dimensions must use constructor scale default `0x100` (`data_93D218` in clean 5517).
- frame-advance interval source must resolve from `ini/Info.ini` (`PuzzleBmp/FrameIntervalMilliSec`, default `1000`).
- visible tile enumeration for both ground and overlay puzzle renderers must stay pinned to native `800x600`; host-window resize may scale presentation, but it must not expand the enumerated puzzle coverage.

### Coordinate & Scale

#### C3DGameMap__func_002 (0x61D77F, size=192) — **ScreenToScaledCoords**
**Purpose**: Converts screen coordinates to scaled viewport coordinates, accounting for zoom and centering.
```c
// Requires scale to be set (offset +80 != 0)
// offset +83 = real_screen_width, +84 = real_screen_height
center_x = (screen_width - real_screen_width) / 2 + scroll_offset_x;
center_y = (screen_height - real_screen_height) / 2 + scroll_offset_y;

*out_x = (in_x - center_x) * screen_width / real_screen_width;
*out_y = (in_y - center_y) * screen_height / real_screen_height;
```
**Debug**: "m_nScale" (ASSERT: scale must be non-zero), "m_nRealScreenWidth" (dimensions must be non-zero)

#### C3DGameMap__func_006 (0x61EDD7, size=114) — **SetScale**
**Purpose**: Sets the map zoom/scale level and recalculates scaled screen dimensions.
```c
// ASSERT: nScale != 0
this->scale = nScale;              // offset +80 (byte 0x140)
this->field_0x350 = nScale;        // byte 0x350

// Recalculate scaled dimensions using global zoom factor
this->real_screen_width  = GetScreenWidth() * dword_93C6C0 / nScale;  // offset +83
this->real_screen_height = GetScreenHeight() * dword_93C6C0 / nScale; // offset +84
```
**Globals**: `dword_93C6C0` = base zoom factor

### Distance & Region

#### C3DGameMap__func_005 (0x61E5E6, size=220) — **CalcTileDistance**
**Purpose**: Calculates integer distance between two tile coordinates with directional adjustment.
```c
// Adjusts source tile based on direction (8 directions, lookup tables)
// Direction type 2: adjusts x/y based on computed direction (0-7)
// Direction type 3: uses dword_869EAC[dir]/dword_869ECC[dir] offset tables

// Distance = ceil(sqrt((dx*dx + dy*dy)))
// Uses integer approximation: finds smallest n where n*n >= dist_squared
// Then refines: if (n*n - (n-1)*(n-1)) > 2*(dist_squared - (n-1)*(n-1)) then n--
```
**Globals**: `dword_869EAC`, `dword_869ECC` — directional offset lookup tables (8 entries each)

#### C3DGameMap__func_012 (0x620407, size=179) — **FindRegionAtPoint**
**Purpose**: Finds a map region containing a given point, searching by region type.
```c
// Region arrays stored at offset +256, 3 DWORDs per type (start, end, ?)
// Special handling: type 8 → sub_62057C, type 14 → sub_6204BB
// Other types: linear search through region array

if (!IsValidRegionType(type)) { CHECKF error; return 0; }
if (type == 8)  return find_type8_region(point);
if (type == 14) return find_type14_region(point);

for (entry in region_array[type]) {
    region = *entry;
    if (region) {
        // Check point within region bounds: region[1]<=x<region[1]+region[4]
        //                                   region[2]<=y<region[2]+region[5]
        if (x >= region[1] && x < region[1]+region[4] &&
            y >= region[2] && y < region[2]+region[5])
            return region;
    }
}
return NULL;
```
**Debug**: "this->IsValidRegionType(nType)" (ASSERT)

### Map Object Rendering

#### C3DGameMap__func_008 (0x61F5A0, size=161) — **RenderMapRegions**
**Purpose**: Renders all C2DMapRegion overlays that match the current map layer.
```c
// Requires terrain layer to exist
CTerrainLayer__func_001();  // prepare terrain for rendering

count = get_list_count(this+166);
for (i = 0; i < count; i++) {
    entry = list_get(this+166, i);
    obj = *entry;
    if (obj && obj->layer == this->field_56) {
        render_result = C2DMapRegion__func_000(obj);
        if (render_result)
            submit_to_renderer(render_result);
    }
}
```
**Debug**: "pLayer" (ASSERT: terrain layer must exist)

#### C3DGameMap__ReleaseRenderObjectList (0x620361, size=50)
**Purpose**: Releases render-object nodes from the terrain-owned object list during reset/teardown.
```c
terrain = GetTerrainLayer();
if (!terrain) { ASSERT("pLayer"); return; }

// Iterate linked list at terrain+172
for (node in terrain->obj_list) {
    obj = node[24];  // node+24 = object pointer
    if (obj)
        obj->vtable->Destroy(obj);  // vtable[0]
}
cleanup_list(terrain+140);
```

#### C3DGameMap__func_011 (0x620393, size=116) — **GetTeamBeamPos**
**Purpose**: Returns the team beam/marker position.
```c
// ASSERT: output pointer must not be NULL
*out = this->team_beam_x;    // offset +226
out[1] = this->team_beam_y;  // offset +227
```
**Offsets**: +226/+227 = team beam X/Y position

### HUD/Overlay Rendering

#### C3DGameMap__func_009 (0x61FED4, size=397) — **RenderExpDisplay**
**Purpose**: Renders experience bar/percentage on screen, including recent exp gain popup.
```c
font = Load_FontSetting_Ini();
if (hero->IsInSpecialMode()) {
    // Show special mode label at (exp_label_x, exp_label_y)
    CMyBitmap::ShowStringCommon(x, y, COLOR_YELLOW, label, font);
} else {
    current_exp = hero->GetCurrentExp();  // QWORD at hero+2144
    max_exp = CHero__GetExpForLevel(hero);
    if (max_exp) {
        percentage = current_exp * 100.0 / max_exp;
        snprintf(buffer, 255, format_str_100135, percentage);

        // Show exp percentage
        CMyBitmap::ShowStringCommon(exp_label_x, exp_label_y, COLOR, buffer, font);

        // Show recent exp gain "+%I64u" for 2 seconds (0x7D0 = 2000ms)
        if (exp_delta > 0 && timeGetTime() - exp_start_time < 2000) {
            snprintf(delta_buf, 63, "+%I64u", exp_delta);
            CMyBitmap::ShowStringCommon(delta_x, delta_y, COLOR, delta_buf, font);
        }
    }
}
```
**Color**: -16648890 (0xFF00B946 — greenish yellow)
**Offsets**: byte +748 = enabled, +756 = start_time, +760 = delta (int64), +768/772 = label pos, +776/780 = delta pos

#### CGameMap_RenderQueuedFloatingTextEntries (0x620D2A, size=148) — **RenderFloatingText**
**Purpose**: Renders all queued floating text entries (damage numbers, pickup text, etc.) from the map queue at `+0x320/+0x324`.
```c
font = Load_FontSetting_Ini();
// Floating text list at byte +800/+804, entries are 0x28 bytes each
for (entry = float_text_start; entry != float_text_end; entry += 10) {
    // entry->showStringRenderTextStyle controls whether per-entry
    // style/corner args override defaults from font settings.
    if (entry->showStringRenderTextStyle != 0) {
        resolvedStyle = entry->showStringRenderTextStyle;
        resolvedCornerColor = entry->showStringCornerColor;
        resolvedCornerPos = entry->showStringCornerPos;
    } else {
        resolvedStyle = font->showStringRenderTextStyle;
        resolvedCornerColor = font->showStringCornerColor;
        resolvedCornerPos = font->showStringCornerPos;
    }

    CMyBitmap::ShowStringCommon(
        entry->screenX,
        entry->screenY,
        entry->showStringColorArgb,
        entry->text,
        font->faceName,
        lineHeight,
        font->showStringParameter7,
        resolvedStyle,
        resolvedCornerColor,
        resolvedCornerPos);
}
```

Verified queue/render/clear chain:

| Stage | Function | Evidence |
|---|---|---|
| Queue one entry | `CGameMap_QueueFloatingTextEntry` (`0x620C7A`) | Guard at `0x620C8E`/`0x620C95` rejects null/empty text; push at `0x620CEC` into map `+0x320` vector |
| Render queued entries | `CGameMap_RenderQueuedFloatingTextEntries` (`0x620D2A`) | Called from `CGameMap_RenderComponentsAndShowScreenEffects` at `0x61D273` |
| Clear queue after render | `CGameMap_ClearQueuedFloatingTextEntriesAfterRender` (`0x620D16`) | Called from `CGameMap_RenderComponentsAndShowScreenEffects` at `0x61D27A`; invokes erase/compact helper on `+0x320` |

`CGameMapFloatingTextEntry` layout (stride `0x28` bytes):

| Offset | Type | Meaning | Evidence |
|---:|---|---|---|
| `+0x00` | `int32` | `showStringRenderTextStyle` | zeroed in `CGameMapFloatingTextEntry_Initialize` (`0x621969`), written from queue arg at `0x620CA7`, read in render at `0x620D77` |
| `+0x04` | `uint32` | `showStringColorArgb` | queue write `0x620CBF`, render color arg at `CMyBitmap::ShowStringCommon` call |
| `+0x08` | `int32` | `screenX` | queue write `0x620CC5`, render read `i[2]` |
| `+0x0C` | `int32` | `screenY` | queue write `0x620CCB`, render read `i[3]` |
| `+0x10` | `std::string` | `text` | queue copy from source text at `0x620CB7`; consumed as `i[4]` in render |
| `+0x1C` | `uint32` | `showStringCornerColor` | initialize zero `0x621973`; queue write `0x620CD1`; render read `i[7]` |
| `+0x20` | `int32` | `showStringCornerPosX` | initialize zero `0x62197C`; queue write `0x620CE2`; render fallback/override branch uses `&i[8]` |
| `+0x24` | `int32` | `showStringCornerPosY` | initialize zero `0x62197F`; queue write `0x620CDC`; render fallback/override branch uses `&i[8]` |

Vector behavior evidence:
- `CGameMapFloatingTextEntryVector_PushBack` (`0x621692`) increments end pointer by `0x28` (`add [esi+0x4], 0x28` at `0x6216A9`).
- `CGameMapFloatingTextEntryVector_EraseAndCompactRange` (`0x621C51`) divides by `0x28` (`push 0x28` / `idiv ecx` at `0x621C5C..0x621C68`) and updates vector end pointer at `0x621CA4`.

### CBossEffectMgr world-render subpasses (`0x682262` / `0x682506`)

Verified chain (Conquer.exe):
- `CBossEffectMgr_SetBossEntityId_Global` (`0x65B3A5`) -> `CBossEffectMgr_GetSingletonPtr` (`0x42D042`) -> `CBossEffectMgr_SetBossEntityId` (`0x6821E7`)
- map render path calls:
  - `CBossEffectMgr_UpdateTrackedBossLifeState` (`0x682262`) at `0x61D286`
  - `CBossEffectMgr_RenderBossLifeOverlay` (`0x682506`) at `0x61D292`

`CBossEffectMgr` state offsets used by these methods:

| Offset | Type | Meaning | Evidence |
|---:|---|---|---|
| `+0x38` | `int32` | displayed life value used by boss-life draw | write in `CBossEffectMgr_SetActiveBossEntityId` (`0x6824DE`); read/draw in `CBossEffectMgr_RenderBossLifeOverlay` (`0x682588`) |
| `+0x40` | `uint32` | active-boss life anchor tick | write `0x6824D3`; read in periodic second-bucket compare `0x682331/0x682347` |
| `+0x44` | `uint32` | last life-adjust tick | write `0x6824D6` and update write `0x68236C`; read in second-bucket compare `0x68232E` |
| `+0x48` | `uint32` | pending boss set tick | write in `CBossEffectMgr_SetBossEntityId` (`0x68223F`); timeout compare in update (`0x682285..0x682290`) |
| `+0x4C` | `int32` | active boss entity id | set in `CBossEffectMgr_SetActiveBossEntityId` (`0x682497`); read in update/render entry (`0x6822EE` / `0x682515`) |
| `+0x50` | `int32` | pending boss entity id | set in `CBossEffectMgr_SetBossEntityId` (`0x682237`); read/clear in update (`0x68227B`, `0x682292`, `0x6822C5`) |
| `+0x1C` | `int32` | life-per-line value for segment math | write in render (`0x682569`) from `min(roleMaxLife, data_96AEC4)`; used by segment math helpers |
| `+0x30` | `int32` | line-pixel width for pixel-step math | used in `CBossEffectMgr_CalculateLifePixelStepPerTick` (`0x682783`) |
| `+0x34` | `int32` | pixel-step numerator for periodic adjust | used in `CBossEffectMgr_CalculateLifePixelStepPerTick` (`0x68277A`) |

Global boss-life config loads:
- `CBossEffectMgr_LoadLifePerLineConfig` (`0x680348`) loads `"LifePerLine"` -> `data_96AEC4` (default `0x2DC6C0`).
- `CBossEffectMgr_LoadColorAmountConfig` (`0x680412`) loads `"ColorAmount"` -> `data_96AECC` (default `0x14`).
- `CBossEffectMgr_LoadLinePerLayerConfig` (`0x6804D9`) loads `"LinePerLayer"` -> `data_96AEC8` (default `1`).

`CBossEffectMgr_UpdateTrackedBossLifeState` verified behavior:
1. Validates pending boss id (`+0x50`) with a 10-second timeout using `timeGetTime` (`+0x48 + 0x2710` compare).
2. If pending id is not usable (resolve fails or status flags 5/10 set), clears pending id.
3. Selects current target id: pending id when available, else `EntityManager_SelectNearestEligibleBossEntityId` (`0x6E9C43`).
4. Calls `CBossEffectMgr_SetActiveBossEntityId` to apply the active id (`+0x4C`) and initialize life timing/display state.
5. Re-validates active id; if invalid/flagged, clears active id.
6. Once per elapsed second bucket (`(last-activeAnchor)/1000` vs `(now-activeAnchor)/1000`), computes step with `CBossEffectMgr_CalculateLifePixelStepPerTick`, queries current life using role value helper (`0x673E92`, arg=`1`), and applies `CBossEffectMgr_AdjustDisplayedLifeValue`.

`CBossEffectMgr_RenderBossLifeOverlay` verified behavior:
1. Resolves current active boss id (`+0x4C`) and rejects flagged targets (status 5/10).
2. Reads role max life (`vtable +0xC4`), clamps to global life-per-line config (`data_96AEC4`), writes to `+0x1C`.
3. Queries current life via role value helper (`0x673E92`, arg=`1`).
4. Calls `CBossEffectMgr_AdjustDisplayedLifeValue(currentLife, 0)`.
5. Calls `CBossEffectMgr_DrawBossLifeOverlay(this, this+0x38, currentLife)`.

`CBossEffectMgr_DrawBossLifeOverlay` (`0x682787`) verified render-time slot usage:

| Offset | Type | Meaning | Evidence |
|---:|---|---|---|
| `+0x04` | `int32` | overlay background draw X | passed to first `ani/Control.ani` draw call at `0x6827C2` |
| `+0x08` | `int32` | overlay background draw Y | passed to first `ani/Control.ani` draw call at `0x6827C2` |
| `+0x0C` | `int32` | life-bar block origin X | loaded at `0x6828C8`; used by `CMyBitmap::ShowBlock` at `0x682932`/`0x68297B` |
| `+0x10` | `int32` | life-bar block origin Y | loaded at `0x6828CB`; used by per-line block loop at `0x682938` |
| `+0x14` | `int32` | life background border X offset | subtracted from origin X in second `ani/Control.ani` draw at `0x682912` |
| `+0x18` | `int32` | life background border Y offset | subtracted from origin Y in second `ani/Control.ani` draw at `0x68290D` |
| `+0x20` | `int32` | light sprite X offset | added to segment width at `0x6829AF..0x6829C9` |
| `+0x24` | `int32` | light sprite Y offset | added to segment row Y at `0x6829C7`/`0x682A20` |
| `+0x28` | `int32` | line separation (row stride) | row-step `edi += [esi+0x28]` at `0x682938` |
| `+0x2C` | `int32` | line height in pixels | used as bottom Y in block draws at `0x682927`/`0x68296A` |
| `+0x30` | `int32` | line pixel width | used for width scaling `(linePixel * life) / lifePerLine` at `0x682885..0x6828C2` |
| `+0x54` | resource handle | background animation slot | queried from `ani/Control.ani` and drawn first at `0x682792..0x6827C2` |
| `+0x60` | resource handle | life background animation slot | queried/drawn per line at `0x6828DB..0x682917` |
| `+0x6C` | resource handle | light animation slot | queried/drawn after block fill at `0x682981..0x682A29` |

Additional verified draw-function behavior:
- hard assert gate: `data_96AEC8 < 0x0A` (`0x6827CB..0x6827E9`) with source string `"s_nMaxLinePerLayer < MAX_LINE_PER_LAYER_VALID"` from `BossEffectMgr.cpp`.
- life-segment color ring buffer is local `var_50[9]` populated through `CBossEffectMgr_LoadLifeSegmentColorByIndex` in the loop at `0x682811..0x68283D`.

`CBossEffectMgr_LoadLayoutAndAssetsForScreenMode` (`0x680792`) verified load mapping for draw slots:

| Manager slot | Config key(s) | Default fallback | Evidence |
|---:|---|---:|---|
| `+0x54` | `"Boss_ShowbossbBG"` + `"BGAni"` or `"BGAni800X600"` | n/a (resource query path) | loads into slot with `sub_66E514` + `sub_410ABE` at `0x680A44..0x680A5F` and `0x681845..0x681860` |
| `+0x60` | `"Boss_BossBloodBG"` / `"Boss_BossBloodSBG"` + `"BGLifeAni"` / `"BGLifeAni800X600"` | n/a | slot writes at `0x680B81..0x680B9C` and `0x681982..0x68199D` |
| `+0x6C` | `"Boss_BloodLightPic"` + `"LightAni"` / `"LightAni800X600"` | n/a | slot writes at `0x680CBE..0x680CD9` and `0x681ABF..0x681ADA` |
| `+0x04` | `"BGX"` / `"BGX800X600"` | `0` | writes at `0x680861` / `0x681662` |
| `+0x08` | `"BGY"` / `"BGY800X600"` | `0x1F4` | writes at `0x68093F` / `0x681740` |
| `+0x0C` | `"ShowX"` / `"ShowX800X600"` | `0` | writes at `0x680DD1` / `0x681BD2` |
| `+0x10` | `"ShowY"` / `"ShowY800X600"` | `0x1F4` | writes at `0x680EAB` / `0x681CAC` |
| `+0x14` | `"m_nLifeBGBorderX"` / `"m_nLifeBGBorderX800X600"` | `0x11` | writes at `0x680F86` / `0x681D87` |
| `+0x18` | `"m_nLifeBGBorderY"` / `"m_nLifeBGBorderY800X600"` | `0x0B` | writes at `0x681061` / `0x681E35` |
| `+0x20` | `"m_nLightOffsetX"` / `"m_nLightOffsetX800X600"` | `-95` (`0xFFFFFFA1`) | writes at `0x68113C` / `0x681ECA` |
| `+0x24` | `"m_nLightOffsetY"` / `"m_nLightOffsetY800X600"` | `-2` (`0xFFFFFFFE`) | writes at `0x681217` / `0x681F5F` |
| `+0x28` | `"LineSep"` / `"LineSep800X600"` | `0x14` | writes at `0x6812F2` / `0x681FF4` |
| `+0x2C` | `"LineHeight"` / `"LineHeight800X600"` | `0x0F` | writes at `0x6813CD` / `0x682089` |
| `+0x30` | `"LinePixel"` / `"LinePixel800X600"` | `0x1F4` | writes at `0x6814A7` / `0x68211D` |
| `+0x34` | `"PixelStep"` / `"PixelStep800X600"` | `3` | non-800x600 path uses tailcall from `0x6814E3` with key `"PixelStep"`; 800x600 write at `0x6821B2` |

### Cleanup

#### C3DGameMap__func_017 (0x6211EB, size=357) — **CleanupObjectList2**
**Purpose**: Destroys all entries in the secondary object list (offsets +340..+347), freeing sub-objects, name strings, and child lists.
```c
while (cleanup_list_start != cleanup_list_sentinel) {
    entry = *cleanup_list_start;
    if (entry) {
        // Destroy child objects at entry+32..+36
        for (child in entry->children) {
            if (child) { sub_621358(child); delete child; }
        }
        // Free name string at entry+28
        if (entry->name) { string_dtor(entry->name+2); delete entry->name; }
        // Clear children list, delete entry
        clear_list(entry+32, entry+36);
        if (entry) { sub_621F65(entry+32); delete entry; }
    }
    advance_iterator(cleanup_list);
}
clear_list(this+340);
```

## C3DMapSimpleObj — Static Map Object

### Memory Layout
```c
struct C3DMapSimpleObj {
    void* vtable;           // +0 (off_86A944)
    void* render_obj;       // +5 — 3D render object (vtable-based)
    DWORD pos_x;            // +6 (byte +24)
    DWORD pos_y;            // +7 (byte +28)
    DWORD anim_start_time;  // +8 (byte +32)
    DWORD anim_period;      // +9 (byte +36) — ms per animation cycle
    DWORD is_dimmed;        // +11 (byte +44) — 0=full, 1=dimmed (alpha 0.65)
    DWORD scale_x;          // +12 (byte +48) — float
    DWORD scale_z;          // +13 (byte +52) — float
    DWORD has_body_anim;    // +14 (byte +56) — uses body animation system
    DWORD is_finished;      // +15 (byte +60)
    DWORD anim_start2;      // +16 (byte +64)
    QWORD current_anim;     // +18 (byte +72) — current animation ID (QWORD)
    DWORD* anim_queue_start;// +20 (byte +80) — animation queue
    DWORD* anim_queue_end;  // +21 (byte +84)
    // Overlay list at +23 (CZoomNum) and +92 (CPlayer__UpdateOverlayList)
};
```

### C3DMapSimpleObj__func_000 (0x64C7EF, size=157) — **Destructor**
**Purpose**: Destroys the simple map object — clears animation list, destroys render object, cleanup zoom numbers.
```c
vtable = off_86A944;
clear_list(this+20, this+21);       // clear animation queue
if (this->render_obj) {
    render_obj->vtable->Destroy();   // vtable[0]
    this->render_obj = NULL;
}
CZoomNum__func_000(this+23);        // destroy zoom numbers
destroy_list(this+20);              // destroy animation queue container
sub_64CCF3(this);                   // base destructor
```

### C3DMapSimpleObj__func_001 (0x64C8D4, size=58) — **SetAnimation**
**Purpose**: Sets the animation frame on the render object.
```c
if (frame) {
    if (this->render_obj)
        render_obj->vtable->SetFrame(frame);  // vtable+64
    else
        ASSERT("m_obj3DSimpleObj");
}
```

### C3DMapSimpleObj__func_002 (0x64C96E, size=270) — **RenderUpdate**
**Purpose**: Main per-frame render update — positions object, advances animation, renders to screen.
```c
// 1. Convert object tile pos to screen coords
GetSingletonPtr_410685();
TileToScreen(this->pos_x, this->pos_y, &screen_x, &screen_y);
// Also get camera center screen pos for reference
TileToScreen(camera_center, &cam_x, &cam_y);

// 2. Animation update
if (this->has_body_anim) {
    // Body animation system: load animation by ID from GameDataSet
    if (!current_anim) {
        // Pop next from animation queue
        if (anim_queue_start != anim_queue_end) {
            current_anim = *anim_queue_start;
            advance_queue(anim_queue_start);
        }
    }
    if (!current_anim) { this->is_finished = 1; return; }

    // Load "Body" mesh for animation
    mesh = GameDataSet->GetMesh("Body", anim_hi, anim_lo, 1, 0);
    render_obj->vtable->SetMesh(mesh);       // vtable+60
    frame_count = mesh->vtable->GetFrameCount();  // vtable+12
    frame = (timeGetTime() - anim_start2) / 33;   // ~30fps (33ms/frame)
    if (frame >= frame_count) {
        current_anim = 0;  // animation complete
        frame = frame_count - 1;
    }
    render_obj->vtable->SetFrame(frame);     // vtable+56
} else {
    // Simple looping animation
    elapsed = timeGetTime() - anim_start_time;
    frame = elapsed % anim_period;
    render_obj->vtable->SetFrame(frame, elapsed / anim_period);  // vtable+56
}

// 3. Set position and render
render_obj->vtable->SetPosition(scale_z, 0.0, scale_x);    // vtable+28
alpha = this->is_dimmed ? 0.65 : 1.0;
render_obj->vtable->Render(screen_x, screen_y, 0, 0, alpha); // vtable+16
render_obj->vtable->SetCamera(cam_x, cam_y, 5, 6);          // vtable+8

// 4. Update overlay list (floating text/damage numbers)
MapToScreen(this->pos_x, this->pos_y, &overlay_x, &overlay_y);
CPlayer__UpdateOverlayList(this+92, overlay_x, overlay_y - 100);
```
**Frame Rate**: ~30fps (33ms per frame for body animations)
**Dimmed Alpha**: 0.65 (for objects behind terrain/entities)

## Helper Address Index

| Function | Address | Size |
|---|---|---|
| CGameMap__FindComponent_Type2 | 0x61D649 | 90 |
| CGameMap__CalcScreenPosFromTile | 0x61D850 | 118 |
| CGameMap__AddScreenOffset | 0x61D8C6 | 27 |
| CGameMap__IsTileInViewRadius | 0x61E00D | 185 |
| CGameMap__ProcessScreenEffect | 0x620AC7 | 178 |
| CGameMap__ShowScreenEffect | 0x620B79 | 189 |
| C3DGameMap__func_000 (Destroy) | 0x61CFA9 | 178 |
| C3DGameMap__func_001 (DestroyObjList) | 0x61D15B | 148 |
| C3DGameMap__func_002 (ScreenToScaled) | 0x61D77F | 192 |
| C3DGameMap__LoadMapById | 0x61DA1F | 574 |
| C3DGameMap__LoadMapFile | 0x61DC3D | 952 |
| C3DGameMap__func_005 (CalcTileDistance) | 0x61E5E6 | 220 |
| C3DGameMap__func_006 (SetScale) | 0x61EDD7 | 114 |
| C3DGameMap__func_008 (RenderMapRegions) | 0x61F5A0 | 161 |
| C3DGameMap__func_009 (RenderExpDisplay) | 0x61FED4 | 397 |
| C3DGameMap__ReleaseRenderObjectList | 0x620361 | 50 |
| C3DGameMap__func_011 (GetTeamBeamPos) | 0x620393 | 116 |
| C3DGameMap__func_012 (FindRegionAtPoint) | 0x620407 | 179 |
| C3DGameMap__func_015 (RenderFloatingText) | 0x620D2A | 148 |
| C3DGameMap__func_017 (CleanupObjList2) | 0x6211EB | 357 |
| C3DMapSimpleObj__func_000 (Dtor) | 0x64C7EF | 157 |
| C3DMapSimpleObj__func_001 (SetAnim) | 0x64C8D4 | 58 |
| C3DMapSimpleObj__func_002 (RenderUpdate) | 0x64C96E | 270 |
