# Frame Loop Architecture — CMyShellDlg_RunFrameTick

Source: `F:\CQ2ClientRelease-42.0.1\MyShell\MyShellDlg.cpp` (debug string at 0x93F3CE).
## Entry: `CMyShellDlg_RunFrameTick` (`0x5dcfb0`)
## Verified via BNinja HLIL decompile of `0x5dcfb0`

## Summary

`CMyShellDlg_RunFrameTick` is the outermost per-frame orchestrator called by the Windows
message-loop `OnIdle` handler. `arg1 = CMyShellDlg*`, `arg2 = lCount` (nonzero on
first idle call of a message cycle). The function drives:
network processing → rendering start → world tick → 3D render → HUD → flip.

## Managed reconstruction status

The production managed frame composition now invokes the completed native step-14/step-15 subset
through `Role3DClientSceneFirstMapComponentPreTickService`. Step 14 runs the local-hero
auto-run/idle decision; step 15 then finds the first type-1
ground/entity-layer component and calls its tick entry with native argument `0` before the later
all-component map tick. The type-1 component therefore receives two calls in a normal frame, exactly
as the native sequence at `0x5DD05A` and `0x61D490` requires; this is not accidental duplicate work.

Queued managed map-create work is drained immediately after decoded network ingress and before the
front-overlay/pre-map stages. Native `CMsgAction__Process` performs
`CGameMap_CreateFromDataId` synchronously inside the `0x4A`/`0x56` packet branches, so leaving the
managed queue drain in the later map-stage tick would incorrectly pre-tick the previous map once on
a transition. `Role3DClientSceneMapStage` retains an injectable map-resource lifecycle only for
isolated compatibility tests; production ownership is the outer scene frame.

The larger managed pre-map composite contains independently tested models for steps 16, 21, and 22,
but production does not claim those stages yet. Step 14's decision, packets, command-type-6
transitions, coordinate-cache refresh, timeout source, and Windows working-set call are active.
Packet 1110 supplies the verified managed writer for
`CGameMap+0xE0`, and `CGameMap_IsStateBlockingAutoRun` is modeled as exact equality with map id
`0x40F`. Native action `0x6F` now supplies the verified nonzero-ID managed writer for
`CHero.boothManager.boothNpcId/isActive` (`CHero+0x2A58/+0x2A5C`). Equipment and status ingress now
supply the verified managed writer for cached mounted interval `CRole+0x118`, which removed the last
step-14 production blocker. ShowHand and dummy-movie sound remain hooks, and the `WM_0CBC`
consumer/re-arm owner is not yet reconstructed. The larger composite therefore remains inactive;
production stops at the completed step-14/step-15 boundary.

The idle threshold source itself is now verified: `CHero_LoadIdleTimeoutMillisecondsFromInfoIni`
(`0x654DFB`, effective body `0x654E08..0x654E75`) reads `ini/Info.ini`, section `TempLeave`, key
`TimeMilliSec`, with default `0x2BF20` (**180000 ms**) into
`g_HeroIdleTimeoutMilliseconds` (`0x96AB10`). The clean v5517 `Info.ini` has no such entry, so the
default is the effective value for the supplied runtime assets. `IniStore_ReadIntOrDefault`
(`0x76F9CE`) returns the supplied default for a missing or empty value, uses hexadecimal `%x` only
when the stored value is longer than two characters and begins exactly with `0x` or `0X`, and uses
decimal `atoi` otherwise. Section and key lookup is case-insensitive.

The file lexer is also verified in `IniStore_LoadFile` (`0x76EF0E`): section text is the bytes
strictly between a leading `[` and the first `]` (no trimming), keys lose trailing spaces/TABs and
are lowercased, and values skip leading spaces/TABs and end at TAB, semicolon, CR, or LF. Ordinary
spaces inside or at the end of a value are retained.

## Global State

| Symbol | Address | Purpose |
|---|---|---|
| `data_937084` | 0x937084 | Frame-tick anchor timestamp; initialized to `GetTickCount()` on first call when `== 0xffffffff` |
| `data_957de8` | 0x957de8 | `CFrameEventList` singleton (floating text / damage numbers) |
| `data_958651` | 0x958651 | Anti-addiction grade-100 WM_0x471 sent flag |
| `data_958652` | 0x958652 | Anti-addiction grade-100 WM_0x472 sent flag |

## Frame Tick Sequence (verified order, BNinja HLIL `0x5dcfb0`)

```
 #   Address     Call                                                          Notes
 1   5dcfba      guard: if *(arg1+0x179ab9) == 0 → return                    frame-active flag
 2   5dcfc7      if data_937084 == 0xffffffff: data_937084 = GetTickCount()   anchor init (once)
 3   5dcfd8      if arg2 != 0: CNetMsg__ProcessMsg()                          network pump (per idle)
 4   5dcfe4      CMyBitmap::IfDeviceLost()                                    device-lost poll
     ── device-reset branch (eax==2) ──────────────────────────────────────────────────────────────
 5   5dd011      FrameTickPerfTimer_RecordDeviceResetStart(...)
 6   5dd016      CGameMap_GetSingletonPtr()
 7   5dd01d      CGameMap_ResetActiveMapLayerComponent()
 8   5dd022      CDeviceResetCallback_FireAndClear()
 9   5dd027      CMyBitmap::ResetDevice()
10   5dd02f      CMyShellDlg_DrawExChatTopBackgroundAndFlip(arg1)
11   5dd036      CMyShellDlg_DrawExChatJointPanelAndFlip(arg1)
     ── device-issue path (eax!=0) ────────────────────────────────────────────────────────────────
12   5dcffa      FrameTickPerfTimer_RecordDeviceIssueDetected(...)
     ── main path ─────────────────────────────────────────────────────────────────────────────────
13   5dd040      CFrameEventList_BeginTick(&data_957de8)                      purge expired floating text
14   5dd04c      CHero_TickPreFrameAutoRunAndIdleDecision(CHero_GetSingletonPtr())
                                                                              idle+autorun tick (see §Idle)
15   5dd05a      CGameMap_TickFirstActiveComponent()                          component type-1 tick
16   5dd069      CShowHandMgr_Tick(CRole3DSceneMgr_GetSingletonPtr())         ShowHand animation tick
     ── render start (skipped on device-reset) ────────────────────────────────────────────────────
17   5dd074      CMyBitmap_Begin3DRenderAndClear()                            begin DirectX 3D frame
     ── world tick ────────────────────────────────────────────────────────────────────────────────
18   5dd082      edi_2 = CHero_GetSingletonPtr() + 0xcec                     hero tile coords offset
19   5dd08a      XteaProtectedInt_Get trampoline                              read protected hero tile X
20   5dd0a0      CHero_TickNearbyEntityPrioritySelectionAndSound(&data_96b018, arg1)
                                                                              entity registry visual tick + sound priority
21   5dd0ac      CDummyMovieMgr_TickSoundKeyframes(CDummyMovieMgr_GetSingletonPtr())
                                                                              BGM/3D SFX keyframe tick
22   5dd0b8      CScheduledWindowMsg0CBC_TickFireIfElapsed(                   5-second periodic WM_0CBC
                   CScheduledWindowMsg0CBC_GetOrCreateSingleton())
23   5dd0cc      CGameMap_TickComponentsAndProcessScreenEffects(              map component tick (all types) +
                   CGameMap_GetSingletonPtr())                                timed screen effects
24   5dd0d9      Exe_TickMapProjectionAndDispatchMapRender(...)               map projection + render
     ── 3D render (skipped on device-reset, requires local hero) ─────────────────────────────────
25   5dd0e2      if !device_reset && CRole3DSceneMgr_TryResolveLocalHero():
26   5dd0f3        CRole3DSceneMgr_RenderSceneToBuffer(eax_8, edi_2.b)       3D entity + terrain render
     ── HUD ───────────────────────────────────────────────────────────────────────────────────────
27   5dd0fb      CMyShellDlg_RenderHudAndProcessSound(...)                   FPS smoothing + 3D sound
28   5dd108      CMyBitmap::ClearBuffer(1, 0, 0xff000000)                    clear alpha channel black
     ── movie / card system ───────────────────────────────────────────────────────────────────────
29   5dd122      if !device_reset:
30   5dd122        CDummyMovieMgr_DispatchActiveMovieEntries(...)             active movie entry render
31   5dd12e      if CCardPlaySystem_GetOrCreateSingleton() != 0:
32   5dd139        (*CCardPlaySystem vtable[6])()                             card-play system frame tick
     ── post-render ───────────────────────────────────────────────────────────────────────────────
33   5dd14b      if CRole3DSceneMgr_TryResolveLocalHero():
34   5dd14b        CRole3DSceneMgr_PostRenderCleanup(eax_8)
     ── UI buttons (MFWindow resize / SubWindow detection) ───────────────────────────────────────
35   5dd157      sub_40390b() / sub_40255c() — window utility
36   5dd16c      CMyButton__TickAndRender(...)                                various UI button groups
     ── anti-addiction system ─────────────────────────────────────────────────────────────────────
37   5dd38d      if locale=="SCH" && CHero_IsAntiAddictionSystemEnabled():
38   5dd3ae        grade = CHero_GetAntiAddictionGrade()
39              grade == 0  (online < 3h):  no throttle
40              grade == 50 (3h–5h):        if elapsed >= 0x1b7740 (1800s) → post WM_0x2b34
41              grade == 100 (>5h):         if elapsed >= 0xdbba0 (900s) → post WM_0x2b35
42                                          posts WM_0x471 once (data_958651 flag)
43                                          posts WM_0x472 once (data_958652 flag)
     ── FPS diagnostic (600-frame sampling) ──────────────────────────────────────────────────────
44   5dd5b2      if counter >= 0x258 (600): compute fps = frames/elapsed, test vs 5.0 fps threshold
     ── viewport HUD overlays ─────────────────────────────────────────────────────────────────────
45   5dd2b7      CGameMap_RenderHeroExpAndStatOverlays(...)
46   5dd2c5      CMapViewportState_GetOrInit()
47   5dd2ce      CMapViewportState_CheckAndTriggerPendingUpdate(&data_96b090)
48   5dd2d5      CUserAttribMgr_RenderStatusIconTooltips()
49   5dd2dc      CMapViewportState_PrepareRenderParams(&data_96b090)
50   5dd2e8      CSynCompeteMgr_RenderLeaderboardOverlay(...)
51   5dd2f4      CGameMap_BuildGameCameraFromScreenDimensions()
52   5dd300      CMyDialogMgr_TickAndSyncChildWindows()
53   5dd311      if CFrameEventList_IsActiveFlag(&data_957de8):
54   5dd31a        (render floating text entries)
55   5dd326      CGameMap_BuildGameCameraFromScaledViewportDimensions(...)
56   5dd332      CUserAttribMgr_RenderViewportAttribDisplays(&data_96b090)
57   5dd345      CSkillDragVisual check / TickCursorTracking
     ── frame event list end + role overlays ──────────────────────────────────────────────────────
58   5dd6b0      CFrameEventList_EndFrameDispatch(&data_957de8)              floating text end-frame
59   5dd6bc      CMyShellDlg_UpdateRoleWordOverlayPosition(&arg1[0x3e6])
60   5dd6cf      if arg1[0x5e6b5]: CMyShellDlg_RenderNpcLeaveInstancePrompts(arg1)
61   5dd6df      CLastingActionMgr_TickTimerAndDispatch(...)
62   5dd6eb      CGameMsg_TickAndExpireCenterMsg(...)
63   5dd6ff      if !device_reset: CLastingActionMgr_RenderActiveOverlays(...)
64   5dd70b      CGameMsg_RenderCenterMsg(...)
     ── flip ──────────────────────────────────────────────────────────────────────────────────────
65   5dd710      CMyBitmap_End3DAndFlip()                                    present DirectX back-buffer
```

## Key Frame Loop Singletons

| Singleton Getter | Singleton Address | Type |
|---|---|---|
| `CHero_GetSingletonPtr()` | — | `CHero*` local player |
| `CRole3DSceneMgr_GetSingletonPtr()` | — | 3D scene + ShowHand mgr |
| `CGameMap_GetSingletonPtr()` | — | map state + components |
| `CDummyMovieMgr_GetSingletonPtr()` | — | keyframe BGM/SFX |
| `CScheduledWindowMsg0CBC_GetOrCreateSingleton()` | `data_956050` | 5s timer |
| `CCardPlaySystem_GetOrCreateSingleton()` | — | Texas Hold'em card system |
| `&data_957de8` | 0x957de8 | `CFrameEventList` (static) |
| `&data_96b018` | 0x96b018 | Entity registry (static) |
| `&data_96b090` | 0x96b090 | `CMapViewportState` (static) |

## CScheduledWindowMsg0CBC — 5-Second Periodic Timer

**Singleton address**: `data_956050` (0x956050).
**Constructor** (`0x6afe36` via `sub_6afe36`): allocates 0x30 bytes, calls `sub_6b00e6` (init).
**Init** (`0x6b00e6`):

```c
sub_6b05f8(obj + 0x24);           // initialize string container at +0x24
memset(obj + 4, 0, 0x12);         // zero +4..+21
*(obj + 0x18) = 0;                // fired-gate = 0 (open = ready to fire)
*(obj + 0x1c) = 0;                // arm-timestamp = 0 (not yet armed)
*(obj + 0x20) = 0;
```

**Object layout** (verified from decompiles):

| Offset | Size | Name | Purpose |
|---|---|---|---|
| +0x10 | 4 | `counter` | Reset to 0 in `Fire`; purpose unclear (some hit counter) |
| +0x18 | 4 | `fired_gate` | 0 = ready; nonzero = gate closed (timer won't fire again) |
| +0x1c | 4 | `arm_timestamp_ms` | `timeGetTime()` snapshot when timer was armed; 0 = not armed |
| +0x20 | 4 | unknown | Initialized to 0 |
| +0x24 | — | string container | Initialized by `sub_6b05f8` |

**TickFireIfElapsed** (`0x6b0372`):
```c
void CScheduledWindowMsg0CBC_TickFireIfElapsed(obj) {
    if (obj->fired_gate == 0 && obj->arm_timestamp_ms != 0 &&
        timeGetTime() - obj->arm_timestamp_ms >= 5000)
        CScheduledWindowMsg0CBC_Fire(obj);
}
```

**Fire** (`0x6b02ce`):
```c
void CScheduledWindowMsg0CBC_Fire(obj) {
    obj->counter     = 0;
    obj->fired_gate  = timeGetTime() - 1;     // nonzero → close gate
    Conquer_PostMainWindowMessage464(0xcbc, 1); // post WM_0CBC
}
```

**Behavior**: one-shot timer. `WM_0CBC` handler must rearm by setting
`obj->fired_gate = 0` and `obj->arm_timestamp_ms = timeGetTime()` to restart the 5s cycle.

## CDummyMovieMgr — Sound Keyframe Tick

**Source file** (debug string): `F:\CQ2ClientRelease-42.0.1\3DRole\DummyMovieMgr.cpp`
**Singleton getter**: `CDummyMovieMgr_GetSingletonPtr` (`0x4cfd0a`).
**Constructor**: `CDummyMovieMgr_Ctor` (`0x68b80c`).
**TickSoundKeyframes**: `CDummyMovieMgr_TickSoundKeyframes` (`0x68be96`).
Called at frame step 21 from `CMyShellDlg_RunFrameTick` (`0x5dd0ac`).

### Object layout (verified from `CDummyMovieMgr_Ctor` `0x68b80c`)

| Offset | Type | Name | Purpose |
|---|---|---|---|
| +0x04 | ptr | `soundInterface` | Created by `Game3DEffectCreate(0)`; vtable used for BGM play/stop |
| +0x14 | container | `sequenceContainer` | Holds animation keyframe data (indexed by dummy-ID type) |
| +0x20 | ptr | `movieEntryListBegin` | Movie entry list start (init 0) |
| +0x24 | ptr | `movieEntryListEnd` | Movie entry list end (init 0) |
| +0x28 | ptr | `?` | Init 0 |

### Sound keyframe struct (+0x44 stride, verified `0x68bf84`)

| Offset | Name | Purpose |
|---|---|---|
| +0x14 | `type` | Keyframe type: `0x3ea` = BGM, `0x3eb` = 3D positioned SFX |
| +0x1c | `startMs` | Elapsed-since-entry-arm threshold to trigger playback |
| +0x20 | `durationMs` | Playback window; keyframe expires at `startMs + durationMs` |
| +0x24 | `mapCoordX` | Map X coordinate (3D SFX only) |
| +0x28 | `mapCoordY` | Map Y coordinate (3D SFX only) |
| +0x34 | `soundHandle` | BGM handle (from vtable `+0x10`); SFX effect index |
| +0x38 | `soundId` | BGM filename/ID string pointer |
| node+0x14 | `triggerFlag` | Iterator-node field: `< 0` = not yet triggered, `>= 0` = triggered |

### TickSoundKeyframes verified algorithm (`0x68be96`)

```c
void CDummyMovieMgr_TickSoundKeyframes(obj) {
    // Guard: empty entry list → no-op
    if (*(obj+0x20) == *(obj+0x24)) return;

    uint32_t nowMs = Conquer_GetTimeGetTime();

    // Iterate over each movie entry
    for (entry : movie_entry_list) {
        uint32_t elapsed = nowMs - entry->startMs;  // entry[1] = arm timestamp

        // ── Sequence/animation keyframes (type 1..999) ───────────────────
        int dummyType = entry->type;  // entry[4] = +0x10
        if (dummyType >= 1 && dummyType <= 0x3e7) {
            seqData = find_in_container(sequenceContainer+4, dummyType);
            if (seqData found && seqData->resource != 0) {
                // Stride = 0x44; advance keyframe index when elapsed >= next frame time
                int idx = entry->curKeyFrameIdx;
                int count = (seqData->end - seqData->begin) / 0x44;
                if (idx + 1 < count && elapsed >= seqData->begin[(idx+1)*0x44]) {
                    entry->curKeyFrameIdx = idx + 1;
                    if (seqData->begin[(idx+1)*0x44 + 8] != 0)
                        sub_66c917(seqData->resource, seqData->begin[(idx+1)*0x44 + 8]);
                }
            }
        }

        // ── Sound keyframes (type 0x3ea / 0x3eb) ─────────────────────────
        soundKf = find_in_container(sequenceContainer+0x10, dummyType);
        if (soundKf not found) continue;

        if (soundKf->triggerFlag < 0) {          // not yet triggered
            if (elapsed >= soundKf->startMs) {   // start threshold reached
                if (soundKf->type == 0x3ea) {    // BGM play
                    soundIface = *(obj+4);
                    (*vtable[+0x18])(soundKf->soundId);                        // play by ID
                    soundKf->soundHandle = (*vtable[+0x10])(soundKf->soundId, 1); // get handle
                } else if (soundKf->type == 0x3eb) {  // 3D SFX play
                    map = CGameMap_GetSingletonPtr();
                    CGameMap_GetPointAbsoluteFromProjectionCenter(
                        map, soundKf->mapCoordX, soundKf->mapCoordY, &screenX, &screenY);
                    _DXPlaySound(soundKf->soundId, screenX, screenY, 0, soundKf->soundHandle, 100);
                }
                soundKf->triggerFlag = 0;         // mark triggered
            }
        } else {                                  // already triggered
            if (elapsed > soundKf->startMs + soundKf->durationMs) {  // window expired
                if (soundKf->type == 0x3ea) {    // BGM stop
                    (*vtable[+0x14])(soundKf->soundHandle);
                } else if (soundKf->type == 0x3eb) {  // 3D SFX stop
                    _DXCloseSound(soundKf->soundId, 0, nullptr);
                }
            }
        }
    }
}
```

**Sound interface vtable** (at `*(obj+4)`, created by `Game3DEffectCreate(0)`):

| Vtable offset | Action |
|---|---|
| `+0x10` | Get sound handle by ID + flags |
| `+0x14` | Stop BGM by handle |
| `+0x18` | Play BGM by ID |

## CGameMap_TickFirstActiveComponent — Frame Step 15

**Entry**: `CGameMap_TickFirstActiveComponent` (`0x61d404`).
Called at frame step 15: `CGameMap_TickFirstActiveComponent()` (no args — resolves singleton internally).
**Sole xref**: `CMyShellDlg_RunFrameTick` @ `0x5dd05a`.

### Verified algorithm (`0x61d404`)

```c
void CGameMap_TickFirstActiveComponent(void) {
    CGameMap* map = CGameMap_GetSingletonPtr();
    CGameMapComponent* comp = CGameMap_FindFirstComponentWithTypeCode1(map);
    if (comp != NULL) {
        (*comp->vtable[+8])(0);     // Tick(nativeTickArgument = 0)
    }
}
```

### Helper: `CGameMap_FindFirstComponentWithTypeCode1` (`0x61d59b`)

```c
CGameMapComponent* CGameMap_FindFirstComponentWithTypeCode1(CGameMap* map) {
    // Deque header: map+0x14 = head sentinel, map+0x4 = tail sentinel
    for (node = map[0x14]; node != &map[0x4]; node = node->next) {
        CGameMapComponent* comp = node->component;
        if ((*comp->vtable[+0xc])() == 1) {   // GetTypeCode() == 1
            return comp;
        }
    }
    return NULL;
}
```

### Purpose

Single-slot early tick for the **type-1 ground entity layer** before the full component-list
tick at step 23. Type-1 in managed = `Role3DClientSceneMapGroundEntityLayer` (verified via
`Role3DClientSceneMapComponentRegistryFeeder` default order `[1, 2, 6, 3, 5]` from
`CGameMap_ResetAndInitializeDefaultComponents` @ `0x61D07A`).

### Native vtable slot correspondence

| Slot | Role | Managed equivalent |
|---|---|---|
| `+0x08` | `Tick(arg)` | `IRole3DClientSceneMapComponentRuntime.Tick(context)` |
| `+0x0C` | `GetTypeCode()` | `IRole3DClientSceneTypedMapComponentRuntime.TypeCode` |

### Managed implementation

- Interface: `IRole3DClientSceneMapComponentSourceRuntime.FindFirstComponentByTypeCode(int)`.
- List impl: `Role3DClientSceneMapComponentList.FindFirstComponentByTypeCode` — linear scan,
  returns first `IRole3DClientSceneTypedMapComponentRuntime` with matching `TypeCode`.
- Runtime: `Role3DClientSceneFirstTypedMapComponentTickRuntime.TickFirstComponentByTypeCode(
  typeCode, nowTickMilliseconds, nativeTickArgument)` — mirrors native `arg = 0` call site but
  generalized.
- Result: `Role3DClientSceneFirstTypedMapComponentTickResult(ComponentFound, TypeCode,
  NativeTickArgument)`.

### Type-1 component Tick body — `CGameMapGroundEntityLayerComponent_PerFrameTick` (`0x637566`)

**vtable slot**: `+0x08` on ground-entity-layer component. Native vtable entry at data
`0x86a304` (verified xref to `0x637566`).

**Decompile**:

```c
void CGameMapGroundEntityLayerComponent_PerFrameTick(CGameMapGroundEntityLayerComponent* self) {
    int32_t offsetX = 0, offsetY = 0;
    CGameMap_GetComponentRenderProjectionOffset(CGameMap_GetSingletonPtr(), &offsetX, &offsetY);
    CMapGroundEntityLayer_RebuildTileAttachedTerrainObjectRenderCache(self + 0x18, offsetX, offsetY);
    CHero_GetSingletonPtr();
    int32_t heroTileX = XteaProtectedInt_Get();
    int32_t heroTileY = XteaProtectedInt_Get();
    CMapGroundEntityLayer_TickChunkStreamingQueue(self, heroTileX, heroTileY);
}
```

The decompile above omits each accessor's implicit `ECX` protected-integer container argument;
the two calls target the hero tile X and tile Y containers respectively.

**Substeps**:

1. `CGameMap_GetComponentRenderProjectionOffset` (`0x61e3d8`):
   `offsetX = gameMap+0x48 - projectionBaseCenterX`, `offsetY = gameMap+0x4c - projectionBaseCenterY`
   (delegates to `CGameMap_GetProjectionBaseCenterFromOffsets`).

2. `CMapGroundEntityLayer_RebuildTileAttachedTerrainObjectRenderCache` (`0x639756`) on
   `self+0x18` (embedded `CMapGroundEntityLayer` sub-struct):
   ```c
   void Rebuild(arg1, offsetX, offsetY) {
       if (*(arg1+4) == 0) return;         // cache gate closed
       /* neg.d(offsetY) / neg.d(offsetX) stored as locals */
       CMapGroundEntityLayer_BuildTileAttachedTerrainObjectTargetBitmapCache(arg1 + 8);
   }
   ```
   Gate `+0x04` = cache-dirty flag. Cache built into `arg1+0x08`.

3. `CHero_GetSingletonPtr()` result discarded — triggers hero init if needed (side-effecting).

4. Two trampoline calls at `0x7132EC` tail-call `XteaProtectedInt_Get` and return the hero's
   protected tile X, then protected tile Y.

5. `CMapGroundEntityLayer_TickChunkStreamingQueue` (`0x6379f4`) — throttled (~20s) chunk
   loader/unloader using intrusive deque at `self+0x426c..0x4278`, active chunk slot at
   `self+0x4290`, last-time at `self+0x4260`. Iterates queue, streams chunk for hero tile coords.

**Native object offsets** (in `CGameMapGroundEntityLayerComponent`, alloc size `0x4294`):

| Offset | Purpose |
|---|---|
| `+0x0018` | Embedded `CMapGroundEntityLayer` struct (render-cache owner) |
| `+0x4260` | Last chunk-tick `time()` seconds |
| `+0x4268..+0x4278` | Chunk streaming deque head / iter state |
| `+0x427c` | Deque tail sentinel |
| `+0x4290` | Currently-streaming chunk pointer |

### Tile-attached render cache build — `CMapGroundEntityLayer_BuildTileAttachedTerrainObjectTargetBitmapCache` (`0x64a6c4`)

Called from `CMapGroundEntityLayer_RebuildTileAttachedTerrainObjectRenderCache` (`0x639756`)
when the cache-dirty gate at `layer+0x04` is non-zero.

**Algorithm**:

1. `if (CMyBitmap::IfDeviceLost() != 0) return;` — device-lost guard.
2. Compute floor-division tile anchors:
   `var_30 = floor(offsetX / -256); var_2c = floor(offsetY / -256)` (decrement if >0 for true floor).
3. `scaledTileSize = (CGameMap_GetProjectionClampScaleDivisor(map) << 8) / data_93c6c0`
   (global projection zoom factor).
4. `halfColCount = screenWidth / scaledTileSize + 2`; `halfRowCount = screenHeight / scaledTileSize + 2`.
5. Outer loop row `i ∈ [-halfRowCount, halfRowCount)`; inner col `ecx ∈ [-halfColCount, halfColCount)`.
6. Per-cell: `tileX = var_30 + ecx`, `tileY = var_2c + i`. Require `0 ≤ tileX < layer+0x08` and
   `0 ≤ tileY < layer+0x0c` (layer bounds).
7. Screen pixel anchor = `(ecx << 8) + pixelAnchorX`, `(i << 8) + pixelAnchorY`.
8. `CGameMap_ApplyProjectionScaleAroundViewportCenter` → final screen XY (already mirrored in
   `CMapGroundEntityLayerTileAttachmentRender.ApplyProjectionScaleAroundViewportCenter`).
9. Keep only tiles where `(screenX + offsetX) ≥ 0 && (screenY + offsetY) ≥ 0` and within screen
   dims. Push `(tileX, tileY)` into visible vector.
10. Purge phase: walk cache entries at `arg1+0x8c` (intrusive map). Entries whose `(tileX, tileY)`
    are NOT in visible vector → release via refcount path (`sub_404189`, `sub_64ab16`).
11. Insert phase: for each visible tile without cache entry:
    - `bitmap = TargetBmpCreate(layer+0x04)`
    - `CMapGroundEntityLayer_RasterizeTileAttachmentTargetBitmap(layer, bitmap, tileX, tileY)`
    - `TileCoordinateAttachmentLookup_UpsertPayloadSlotByTileCoordinates(layer+0x8c, (tx, ty)).payload = bitmap`
12. Drop collector refs on all created bitmaps.

**Semantics**: visible-set diff → purge stale → rasterize+insert new. Pure reconciliation
keyed by tile coord.

**Cross-ref (ConquerMono)**: `40_tools/ConquerMono-master/Rendering/Drawing/PuzzleDrawingComponent.cs`
uses the same visible-tile iteration shape — `numX = sr.Width / _puzzle.TileSize + EXTRA`
(EXTRA=2), start at `sr.X / TileSize`, with layer-bounds clamp `x < 0 || x >= HorizontalTiles`.
Confirms our Slice-G `CMapGroundEntityLayerVisibleTileEnumerator` semantics. `Puzzle.HorizontalTiles`/
`VerticalTiles` (managed ConquerMono) ↔ `layer+0x08/+0x0c` (native 5517) ↔ `TileCountX/TileCountY`
(our `ICMapGroundEntityLayerDimensionsSource`).

### Chunk streaming queue tick — `CMapGroundEntityLayer_TickChunkStreamingQueue` (`0x6379f4`)

Called from `CGameMapGroundEntityLayerComponent_PerFrameTick` with `(heroTileX, heroTileY)`.
Drives **music-zone crossfade** — the "chunks" in the deque are music-zone records, not map
geometry. Each chunk owns an internal AABB tile rectangle + volume/state fields. Hero's current
tile coord picks which zone is active; `_DXSetMusicVolume` + `_DXCloseAllMedia` handle the fade.

**Leaf helpers (renamed in BNinja)**:

| Address | Renamed | Purpose |
|---|---|---|
| `0x627f04` | `CMusicZoneChunk_ContainsHeroTile(zone, tx, ty)` | AABB test: `1` iff `tx ∈ [zone→0x30[0], +width)` and `ty ∈ [zone→0x30[1], +height)` |
| `0x627f86` | `CMusicZoneChunk_TryAdvanceFadeOut(zone)` | Crossfade-out tick. If `g_musicZoneStreamingEnabledGate == 0` skips; else `_DXSetMusicVolume` ramp-down; returns `1` while fading, `0` once fully faded |
| `0x627f64` | `CMusicZoneChunk_FinalizeFade(zone)` | Finalize mid-frame: gated on `g_musicZoneStreamingEnabledGate` + `zone+9`; zeroes `zone+9`/`zone+0x10`; `_DXSetMusicVolume(g_musicZoneBaseVolume)` |
| `0x627fdb` | `CMusicZoneChunk_BeginZone(zone, flag)` | Begin: `_DXCloseAllMedia`; reset internal zone state; descend into `sub_628080` loader |
| `0x6281e8` | `CMusicZoneChunk_Release(zone)` | Release: `_DXCloseAllMedia` + `sub_66893c(zone+0x18, ...)` recursive cleanup |
| `0x628218` | `CMusicZoneStreaming_IsEnabledGate` | Returns `g_musicZoneStreamingEnabledGate` byte |
| `0x62813d` | `CMusicZoneChunk_AdvanceVolumeRamp(zone)` | Per-frame volume-ramp advance (reads `zone[5]` = ramp ptr, computes `time() - ramp[1]` for fade-in curve) |

**Retail cross-ref**: `40_tools/fight-master/my_client/3DGameMap/` (`CInteractiveLayer::Process`,
`CMapSound`, `C2DMapRegion`) has no equivalent zone-crossfade machine — retail `DXSetMusicVolume`
calls only live inside menu dialog code (`DlgSetup_Music.cpp`). The zone streaming at
`0x6379f4` is a post-retail addition built on top of `CInteractiveLayer`'s existing map-obj deque
infrastructure.

**Algorithm** (throttle constant `0x14` = 20 seconds):

1. If deque head (`+0x4268`) == tail (`+0x4278`) OR `g_musicZoneStreamingEnabledGate == 0`:
   - If active zone (`+0x4290`): `CMusicZoneChunk_Release(active)`; `+0x4290 = 0`; return.
2. `elapsed = time() - +0x4260` (unsigned compare).
3. If `elapsed ≤ 20`:
   - If active: `CMusicZoneChunk_FinalizeFade(active)`.
   - Return `CMusicZoneChunk_AdvanceVolumeRamp(active)`.
4. Throttle expired. Fast-path probe: if active && `CMusicZoneChunk_ContainsHeroTile(active, heroX, heroY)` → stay.
   Finalize via `CMusicZoneChunk_FinalizeFade(active)` + return ramp result.
5. If active == 0 → skip to commit phase (step 8).
6. Scan 1 — probe deque for any non-active zone containing hero:
   - Iterate deque copy of iter state (`+0x426c..+0x4278`, two 16-byte blocks);
   - Dereference each entry; skip entry == active; if `CMusicZoneChunk_ContainsHeroTile(entry, heroX, heroY)` → break.
   - Exhausted with no hit → `CMusicZoneChunk_FinalizeFade(active)` + return ramp result (keep active).
7. Candidate exists. If `CMusicZoneChunk_TryAdvanceFadeOut(active) == 0` (fully faded) → `CMusicZoneChunk_Release(active)`; `+0x4290 = 0`.
8. Commit phase — scan 2: iterate deque, skip active, on `CMusicZoneChunk_ContainsHeroTile(entry, heroX, heroY)` hit:
   - `+0x4290 = entry` (commit active slot);
   - `CMusicZoneChunk_BeginZone(entry, 1)` (begin zone with flag 1 = force-refresh);
   - `+0x4260 = time()` (reset throttle);
   - Return.

**Semantics**: throttled hero-zone detector + BGM crossfade. 20-second minimum between zone
swaps. Between swaps, per-frame volume-ramp advance only. When hero stays inside current
zone, no swap regardless of elapsed time.

**Global state** (renamed in BNinja):

| Address | Renamed | Purpose |
|---|---|---|
| `0x93cc55` | `g_musicZoneStreamingEnabledGate` | Music-streaming master gate (1 = enabled). Kill-switch in native. |
| `0x93cc58` | `g_musicZoneBaseVolume` | Base music volume constant fed to `_DXSetMusicVolume`. |
| `0x93cc54` | `g_musicZoneCrossfadeEnableFlag` | Secondary crossfade-enable flag checked inside `CMusicZoneChunk_AdvanceVolumeRamp`. |

### Managed Tick implementation

Two leaf hook interfaces injected into `Role3DClientSceneMapGroundEntityLayer`:

| Interface | Native mirror |
|---|---|
| `IGroundEntityLayerTileAttachedTerrainObjectRenderCacheRebuilder.RebuildIfDirty(offsetX, offsetY)` | `CMapGroundEntityLayer_RebuildTileAttachedTerrainObjectRenderCache` |
| `IGroundEntityLayerChunkStreamingQueueTicker.TickChunkStreamingQueue(heroTileX, heroTileY)` | `CMapGroundEntityLayer_TickChunkStreamingQueue` |

Coord sources (also leaf interfaces):

| Provider | Native mirror |
|---|---|
| `IGroundEntityLayerProjectionOffsetSource.GetComponentRenderProjectionOffset()` | `CGameMap_GetComponentRenderProjectionOffset` |
| `IGroundEntityLayerHeroTileCoordSource.GetHeroTileCoord()` | `CHero_GetSingletonPtr` + two `XteaProtectedInt_Get` trampolines |

## CShowHandMgr — Card Animation Tick

**Tick function**: `CShowHandMgr_Tick` (`0x6b87fd`).
Called at frame step 16: `CShowHandMgr_Tick(CRole3DSceneMgr_GetSingletonPtr())`.
**arg1** is `CRole3DSceneMgr*`; the ShowHand sub-state lives inside the 3D scene manager.

### Verified algorithm (`0x6b87fd`)

```c
void CShowHandMgr_Tick(sceneMgr) {
    // Check render context via vtable at sceneMgr[0x13]
    if ((*vtable[+0x20])() != 0) {         // context ready
        (*vtable[+0xc])();                  // render call 1
        (*vtable[+0x18])();                 // render call 2
    }
    // If context gone and state == 5: cleanup
    if ((*vtable[+0x20])() == 0 && sceneMgr[0xa] == 5) {
        CShowHandMgr_CheckContextReadyAndClearState(sceneMgr);
        CShowHandMgr_ResetAllQueuesAndState(sceneMgr);
    }
    // Tick all active card-animation entities (intrusive ref-counted list)
    for (entity : entity_list[+0x31..+0x32]) {
        CShowHandMgr_TickCardAnimEntity(entity);    // 0x72517b
    }
    CShowHandMgr_ProcessDealtCardEffect(sceneMgr);
    CShowHandMgr_SpawnNextEntityWithRandomPose(sceneMgr);
}
```

**Purpose**: Texas Hold'em card-dealing animation system. Ticks all in-flight card animation
entities each frame and manages card spawn/process lifecycle.

## CHero Idle System — Frame Loop Integration

Called at step 14 (`0x5dd04c`) from `CMyShellDlg_RunFrameTick`.
Full function verified at `CHero_TickPreFrameAutoRunAndIdleDecision` (`0x65cc70`).
See `../Entity_System/chero_class.md § Idle State System` for complete docs.

Cancellation conditions form one short-circuit OR ladder. If any predicate is true, the native
function makes exactly one call to `CHero_CancelAutoRunAndClearIdle`:

1. `CGameMap_IsStateBlockingAutoRun()` — `map+0xe0 == 0x40f`
2. `Role_GetAutoRunActiveState(hero)` — auto-run active flag
3. `hero->boothManager.isActive != 0` — embedded booth manager flag at `hero+0x2a5c`
4. `CHero_HasInteractionActionStatus(hero)` — `hero+0x2eec != 0`
5. `CHero_IsCommandType03BlockingAutoRun(hero)` — command type `CRole+0x1e8 == 3`

`CRole+0x1e8` is the command-state type at the head of the 0x11c-byte command block. It is not
`CRole+0xd8`, the separate current action type used by paired-interaction animation translation.

Idle entry: unsigned `elapsed = timeGetTime() - hero+0xf30 >= g_HeroIdleTimeoutMilliseconds`
→ send CMsgAction(0xa1, 1)
Idle cancel (on any condition above, if was idle): send CMsgAction(0xa1, 0)

Both packet transitions then call
`Role_CommandType06_SelectActionAndToggleMountedScaleSuppression` (`0x67563F`), with
`enteringIdle=true` for entry and `false` for cancel. Entry clears a nonzero mounted interval before
the status-flag gates, optionally completes and reprojects an active type-6 command, then submits a
fresh type-6 command with payload `0xFA`. Cancel submits payload `0x64` only when status flags
`0x1E`/`0x1F` are clear and interaction suppression is false, then restores the cached mounted
interval when status flag `0x32` is set.

## CFrameEventList — Floating Text Lifecycle

**Static object**: `data_957de8` (0x957de8).
**Begin** (`CFrameEventList_BeginTick` at `0x592f51`): delegates to `CFrameEventList_PurgeOldEntriesForTick(obj+0x94, *(obj+0x94), *(obj+0x98))` — purges expired entries.
**End** (`CFrameEventList_EndFrameDispatch` at `0x592f2b`): dispatches active floating text render.
**IsActiveFlag** (`0x593f90`): returns active-flag state (used as render gate).

Entry lifecycle: `BeginTick` (purge) → render active entries → `EndFrameDispatch`.

## Device-Reset Flag

`var_8_1` in frame locals = device-reset flag (set to 1 when `CMyBitmap::IfDeviceLost() != 0`).
Several render calls are gated: `if var_8_1 == 0`.
When device-reset: chat backgrounds are flipped instead of normal scene.

## Anti-Addiction System

**Grade values** (`CHero_GetAntiAddictionGrade`, `hero+0x2E34`; init −1 at `0x662FC0`; written only by
`CMsgUserAttrib__Process` via `0x66311D`). **Corrected 2026-10-24.** The earlier table had the ends swapped.
- 0x00 (0) = strictest: StrRes 11061 ("unhealthy time", income 0) every 0xDBBA0 ms (15 min); exit-tile map change refused
  (`STR_WALLOW_OPT_LIMIT_WARNING_NONE`)
- 0x32 (50) = StrRes 11060 ("fatigue time") every 0x1B7740 ms (30 min); map change refused (`…_HALF`)
- 0x64 (100) = normal: online-hours notices 0x471 (1 h) / 0x472 (2 h), once each via `data_958651` / `data_958652`
- −1 (default) = no message, map change allowed ([portal transition](../Server/portal-transition-5517.md) §4)

Active only for `locale == "SCH"` (Simplified Chinese / mainland China clients). That locale test covers the frame
messages only. The portal gate (`0x65DCD9`) reads the grade with no locale test.
