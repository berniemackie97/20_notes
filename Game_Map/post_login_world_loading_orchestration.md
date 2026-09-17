# Post-Login World Loading Orchestration

## Verified Native Flow (BNinja)

### Bootstrap → World Frame Gate

1. **Bootstrap loop** (`TryReceiveInitialGameHandoff`): blocks on socket, dispatches all packets via fan-out `TryDispatchDecodedPacket`. The dispatch hits 4 handlers simultaneously:
   - `RoleCommandStateBootstrapIngressRuntime` (marks bootstrap state flags)
   - `ClientWorldInboundPacketApplyRuntime` (writes world state: map state, role state, weather)
   - `RoleCommandStateInboundPacketDispatchRuntime.MsgActionIngress` (command state)
   - `CGameMapMsgActionIngressRuntime` (queues map create requests)

2. **MsgAction EnterMap (0x4A) from server**: The server's EnterMap response packet goes to ALL four handlers. `ClientWorldInboundPacketApplyRuntime` applies the local-hero tile/direction state, `RoleCommandStateInboundPacketDispatchRuntime.MsgActionIngress` queues the verified command-type-05 block, `CGameMapMsgActionIngressRuntime` queues a `CGameMapCreateRequestRuntime` with the map data ID, and native immediately follows this branch by sending client `MsgAction actionGetItemSet (0x4B / 75)`. The verified response path touched by this slice is `MsgItem (1008)` action `4` for equipped-item hydrate through `CRole__SetEquipSlotItem`. Managed server correction for this seam: defer login item-table `1008` sends until the `0x4B` request arrives instead of pushing them directly from post-`1006` connect bootstrap. Bootstrap state marks `HasReceivedServerEnterMapAction`.

3. **Bootstrap completion**: When `IsInitialWorldBootstrapReady` becomes true (all 9 flags set), the bootstrap loop exits and posts `PostMessage(hwnd, 0x464, 0x483, 0)`.

4. **World frame gate enable**: `CMyShellDlg_HandleStartupCommand0x483` at `0x5CAA2D`:
   - Hides login flash hosts (CFlashHostDialog_ApplyShowHideStateAndLifecycleCallbacks)
   - Repositions UI shell windows (MoveWindow calls based on screen dimensions)
   - Centers parent window
   - Configures ExChat panel layout (3-way mode switch: bottom, right, left)
   - Sets `CMyShellDlg+0x179AB9 = 1` (world frame gate flag)

### First World Frame

When the world frame gate is enabled, `Role3DClientSceneFrameRuntime.TickAndRenderFrame` executes:
1. **Network ingress** → pumps any packets that arrived after bootstrap
2. **Front overlay** → draws ExChat top background
3. **Map tick** → `ProcessPendingMapCreateRequests()` **dequeues the EnterMap request queued during bootstrap** and calls `CGameMap_CreateFromDataId`
4. **Projection + render dispatch** → runs camera/projection, dispatches map component renders
5. **HUD + sound** → renders HUD elements, including the verified static `Dialog4` main-UI subset and baseline `CDlgMain` button/check widgets from `CDlgMain_RenderMainUiDialogAndStatusOverlay`

### Projection-Center Producer Before First Render

BNinja anchors:
- `0x5ACAC3` `Exe_TickMapProjectionAndDispatchMapRender`
- `0x65185D` `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor`
- `0x5CAA2D` `CMyShellDlg_HandleStartupCommand0x483_EnableWorldFrameGateAfterStartupLayoutChecks`

Verified behavior:
- `Exe_TickMapProjectionAndDispatchMapRender` does **not** branch on a missing projection snapshot. The first operation in the function is the hero vfunc `+0x10` call that fills the center-base pair, then the code adds half-screen width/height and calls `CGameMap_UpdateProjectionAndCameraFromScreenCenter`.
- The resolved vfunc target is `CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor`, whose body is only:
  - `outX = hero+0x350`
  - `outY = hero+0x354`
- Therefore native first-world-frame correctness depends on startup sequencing, not on a projection-stage fallback branch. By the time `0x483` enables the world frame, the hero projection-base fields must already be valid.
- verified writer semantics for that hero projection-base pair:
  - `Role_SetTilePositionAndProjectScreenCoordinates` (`0x6E4C79`) writes `hero+0x350/+0x354` directly from tile projection during world-entry/spawn-style commits
  - the same world-entry commit also mirrors that projected pair into:
    - `hero+0x194/+0x198` (projected-screen start pair)
    - `hero+0x19C/+0x1A0` (projected-screen current pair)
  - `Role_ApplyGroundMoveActionAndPoseFromPathCursor` (`0x736315`) stages movement into `hero+0x19C/+0x1A0`, not `hero+0x350/+0x354`
  - `Role_RecomputeCoordinateGateCacheFromProjectedPosition` (`0x64E9A5`) later commits staged movement into `hero+0x350/+0x354`
- `CGameMap_CreateFromDataId` does map-load and hero-side setup work before posting `0x424`, but the final `map+0x48/+0x4C` projection-center commit still happens later in `CGameMap_UpdateProjectionAndCameraFromScreenCenter` during the first world render dispatch.

Managed parity contract for this seam:
- startup/bootstrap owns the verified `1004 ANSWER_OK -> 2078 -> 2079 -> 1006 -> client 74 -> {server 74, client 75=item-set request, 1110, 1016, 10014}` window before `0x483`
- the first world-frame map tick must then materialize the projected local-hero state before projection dispatch runs
- regression coverage now explicitly proves that this first map tick is sufficient for the hybrid projection source to drive the initial `map+0x48/+0x4C` write even while command snapshots remain unavailable
- that projected local-hero feed is only a startup fallback; once command snapshots exist, native parity requires the committed `RoleField350/354` pair to win over projected world-state materialization
- managed normal-runtime correction in this slice:
  - the world map tick now always runs the verified oldest-queued command-state dequeue/apply step,
    even when there is no playback host runtime
  - the projection bridge no longer treats "some command-state snapshot exists" as equivalent to
    "the committed projection-center pair is valid"
  - it prefers `RoleField350/354` only after those fields have been explicitly written into the
    command snapshot state; until then it continues to use the projected local-hero fallback for
    the projection center while still preserving command-state availability for the rest of the tick
  - the world map tick now also seeds the committed/staged path-cursor pair from the authoritative
    local-hero tile state before dequeue/apply:
    - project tile through `Map_ProjectTileToScreenCoordinates` (`0x61D850`)
    - write staged `RoleField19C/1A0`
    - if `RoleField350/354` are still missing, commit that same projected pair and recompute the
      coordinate-gate cache through inverse tile projection against `map+0x40/+0x44`
  - managed startup parity now also preserves the duplicated projected-screen start/current pair
    alongside that committed cursor:
    - projected-screen start = committed world-entry projected pair
    - projected-screen current = committed world-entry projected pair
  - managed dequeue/apply now mirrors the verified conditional pre-apply commit branch:
    - `Role_TryApplyIncomingActionInfoWithConditionalStateSync` (`0x65C079`) gate set
    - `Role_RecomputeCoordinateGateCacheFromProjectedPosition` (`0x64E9A5`) staged
      `0x19C/0x1A0 -> 0x350/0x354` commit
  - `map+0x40/+0x44` are now copied into command snapshot state every frame so command-state-driven
    motion math no longer runs with stale zero base-center values

### First World-Frame Local-Hero State Snapshot (Managed Verification)

The current managed branch now has explicit verification for the exact startup seam that matters to the bad first-frame screenshots:

1. `MsgUserInfo1006` writes the local-hero identity/appearance seed into `ClientWorldRoleStateStoreRuntime`
   (`LocalHeroEntityId`, health/mana, appearance composite, names).
2. Server `MsgAction10010` enter-map (`0x4A`) writes the local-hero tile/direction into the same role-state store.
3. The first world-frame map tick runs `ClientWorldRoleSceneMaterializationRuntime.RefreshProjectedRoleStates`,
   producing a projected local-hero state from that `1006 + 0x4A` pair.
4. The first projection tick then commits `map+0x48/+0x4C` from that projected local-hero fallback.
5. The first ground/entity-layer map render pass consumes the projected local hero into the managed
   `ClientWorldRoleViewSceneObjectStoreRuntime`.

Managed runtime diagnostics now log this seam once the first world frame has both a loaded map and a local-hero state:
- `localHeroEntityId`
- tile `(x,y)`
- projected `(screenX,screenY)`
- resulting `map+0x48/+0x4C`
- the submitted player-render point relative to `map+0x48/+0x4C`
- map grid dimensions, ground/entity-layer bitmap extents, scaled viewport, and projection base center
- command-state dequeue/apply state:
  - whether a command block was applied on that world frame
  - pending incoming command-state count
  - whether the committed projection-center path-cursor pair is actually present
  - whether the staged projected pair has been seeded and committed from local-hero tile state
- the resolved post-ground-entity-layer startup RoleView asset plan for the local hero:
  - `body/mix_body/mix2_body` asset-table hits/misses
  - ensure-binding selectors whose source IDs are currently verifiable from the startup load plan

Verified native player-render coordinate contract for this seam:
- `Map_ProjectTileToScreenCoordinates` (`0x61D850`) writes the absolute projected point from `map+0x40/+0x44`
- `Role_TickAndRender` (`0x64F5F7`) then converts that point into:
  - a RoleView projection-base offset via `CGameMap_GetProjectionCenterOffsetFromScreenPoint` /
    `CGameMap_GetProjectionBaseCenterFromOffsets`
  - a later MyBitmap composite screen point via helper `0x61D77F`
- managed player scene objects therefore must cache both verified coordinate spaces, not the map-component render offset
- whether the ground/entity-layer pass submitted a local-hero scene object, and its render coordinates when present

### Current Boundary: Scene Object Submission, Not Visible Hero Draw

This slice does **not** claim that the hero should already be visible on screen after the above steps.

Verified native player-visual chain:
- `CGameMapGroundEntityLayerComponent_MapComponentRenderTick` (`0x637553`)
- `CHero_Render` (`0x65E472`)
- `CHero_TickAndRenderRoleVisuals` (`0x66F7AB`)
- `Role_TickAndRender` (`0x64F5F7` / call site documented at `0x66F843`)
- `CRole__CreateRoleView` (`0x64D51F`) -> `RoleViewCreate(1)` -> RoleView vtable transform/color/render calls

Current managed equivalent stops earlier:
- type-1 render order is preserved,
- player appearance inputs are preserved into persistent scene objects,
- but there is still no verified managed replacement for the native
  `CRole__CreateRoleView -> Role_TickAndRender -> RoleView slot +0x10/+0x18/+0x28`
  visual object contract.

Implication:
- if the new diagnostics show correct local-hero tile/projected/projection-center values and a submitted
  local-hero scene object, then the remaining first-frame visual mismatch is downstream of camera bootstrap;
  it is in scenery ordering and/or the still-missing visible RoleView draw path.

### CGameMap_CreateFromDataId (`0x61DA1F`)

Verified sequence:
1. `RoleDataQuery()->vtable+0x7C(mapDataId)` → lookup map info record (path + ground/entity-layer component link ID)
2. If not found: log "GameMapInfo (%u) not found" → return 0
3. Copy path string (0x40 bytes), read companion dword at +0x40
4. `CGameMap_FindFirstComponentWithTypeCode1(this)` → if found, set component link ID
5. `CGameMap_LoadMapFileFromRelativePath(this)` → parse .7z/.dmap file
6. If load fails: log "game map %s load failed" → return 0
7. On success:
   - Reset projection/viewport state (`CGameMap_ResetProjectionViewportState`)
   - Reconcile type-2 child component entity links (`CGameMap_ReconcileType2ChildComponentEntityLinks`)
   - Hero position setup via `CHero_GetSingletonPtr()`
   - Type-2 child component iteration
   - Store map data ID: `this[0x39] = mapDataId`
   - Init floating text viewport
   - **Post `PostMessage(hwnd, 0x464, 0x424, 0)`**

### Message 0x424 Handler

WndProc dispatch: `msg=0x464, wParam=0x424` → jump table case 7 at `0x5C3E71`:
- Checks if `CFlashHostDialog_IsWindowVisibleOrPendingActivation(this+0xA7E54, 1)` is true
- If visible: calls `CFlashHostDialog_ActivateVisibleDialogLifecycle(this+0xA7E54, 0)`
- **This is purely a UI overlay lifecycle/activation path** — likely related to a "Creating Maps..." loading overlay
- Does NOT trigger any rendering, state transitions, or gameplay logic

### Key Insight: Map Loading Is Self-Contained

The map file loading in `CGameMap_LoadMapFileFromRelativePath` populates all the data structures needed for rendering:
- Tile cell grid (section 1)
- Exit markers (section 2)
- Type-3 subcomponents — ANI sprites, puzzle bitmaps (section 3)
- Type-4 records — 3D objects overlaid on the map (section 4)

The 0x424 message just dismisses a loading UI. The actual rendering begins on the NEXT frame after the map data is loaded, when the component tick/render dispatchers iterate the now-populated subcomponents.

## Map Data ID Table

`ini/GameMap.dat` contains 262 entries. Example:
- Map 1000 → `map/map/desert.7z` (Desert)
- Map 1002 → `map/map/newplain.7z` (Plain of Kings)
- Map 1010 → `map/map/newbie.7z` (Newbie Village) — the default spawn map

## Managed Implementation Status

The full pipeline is wired:
- `GameMapDataIdTable` ← parsed from `ini/GameMap.dat`
- `CGameMapMsgActionIngressRuntime` ← queues map create requests from MsgAction 0x4A/0x56
- `CGameMapResourceRequestLifecycleRuntime` ← dequeues and processes requests each frame
- `CGameMapCreateFromDataIdRuntime` ← data-id lookup → file load → state update → post 0x424
- `CGameMapFileLoadFromRelativePathManagedRuntime` ← opens map file, parses sections, feeds sinks
- `CGameMapMainWindowMessageSinkNoOpRuntime` ← 0x424 handler is no-op (correct — just hides UI overlay)

Diagnostic logging added at: world frame gate transition, map ingress queue, map lifecycle processing, first world frame tick.
