# Client Application And World Structure Refactor

## Scope

This slice is a source-only structural refactor inside `10_work/src/Conquer/Client`.

- Runtime behavior: unchanged by intent
- Packet semantics: unchanged by intent
- BNinja database: no symbols changed in this slice
- Native evidence/addresses: not applicable because no parity logic was introduced or modified

The goal was to make the application host/composition root and shared world state easier to navigate without rewriting runtime behavior.

## Folder Responsibilities After This Slice

### `Client/Application/Hosting`

Application entry and lifecycle host only.

- `Program`
- `GameApplication`
- `GameApplicationLifecycleRuntime`

### `Client/Application/Composition`

Composition-root state, result objects, and builder types.

- startup composition inputs/results/contexts
- scene composition result
- runtime service aggregates
- effect/map/boss-effect service builders
- client root path resolution

### `Client/Application/Orchestration`

Application-level runtime orchestration that is not itself composition.

- `GameDataSetPerFramePumpRuntime`
- `WorldFrameDevCameraPanRuntime`

### `Client/World/State`

Authoritative world/bootstrap/map/weather state containers.

- `ClientWorldBootstrapStateRuntime`
- `ClientWorldRoleStateStoreRuntime`
- `ClientWorldRoleAppearanceStateRuntime`
- `ClientWorldRoleStateSnapshotRuntime`
- `CGameMapRuntimeStateRuntime`
- `CGameWeatherRuntimeStateRuntime`

### `Client/World/Orchestration`

World-state mutation orchestration fed by decoded inbound packets.

- `ClientWorldInboundPacketApplyRuntime`

## Mechanical Refactor Details

### Moves

| Old location | New location | Reason |
|---|---|---|
| `Client/Application/*.cs` entry files | `Client/Application/Hosting/*` | Keep host/lifecycle code separate from application orchestration |
| `Client/Composition/StartupComposition.cs` | `Client/Application/Composition/StartupComposition.cs` | Move startup composition root under application composition |
| `Client/Composition/SceneComposition.cs` | `Client/Application/Composition/SceneComposition.cs` | Keep scene assembly with composition root |
| `Client/Composition/RuntimeServices.cs` | `Client/Application/Composition/RuntimeServices.cs` | Keep aggregated runtime service graph under composition |
| `Client/Composition/MapRuntimeServices.cs` | `Client/Application/Composition/MapRuntimeServices.cs` | Composition-root map service assembly |
| `Client/Composition/EffectRuntimeServices.cs` | `Client/Application/Composition/EffectRuntimeServices.cs` | Composition-root effect service assembly |
| `Client/Composition/BossEffectRuntimeServices.cs` | `Client/Application/Composition/BossEffectRuntimeServices.cs` | Composition-root boss-effect service assembly |
| `Client/Composition/ClientRootPathResolver.cs` | `Client/Application/Composition/ClientRootPathResolver.cs` | Resolver is startup composition input, not generic composition junk-drawer content |
| `Client/Composition/GameDataSetPerFramePumpRuntime.cs` | `Client/Application/Orchestration/GameDataSetPerFramePumpRuntime.cs` | Per-frame orchestration is not composition |
| `Client/CommandState/ClientWorldBootstrapStateRuntime.cs` | `Client/World/State/ClientWorldBootstrapStateRuntime.cs` | Bootstrap status is shared world state |
| `Client/CommandState/ClientWorldInboundPacketApplyRuntime.cs` | `Client/World/Orchestration/ClientWorldInboundPacketApplyRuntime.cs` | Packet-fed world mutation belongs to world orchestration |
| `Client/Role/ClientWorldRoleStateStoreRuntime.cs` | `Client/World/State/ClientWorldRoleStateStoreRuntime.cs` | Authoritative role state is shared world state, not role playback logic |
| `Client/Map/CGameWeatherRuntimeStateRuntime.cs` | `Client/World/State/CGameWeatherRuntimeStateRuntime.cs` | Weather state is shared world state |

### Splits

`StartupComposition.cs` was split so the composition method no longer carries unrelated record declarations:

- `RolePlaybackHostContextRuntime.cs`
- `MapResourceRequestContextRuntime.cs`
- `StartupNetworkIngressContextRuntime.cs`
- `ClientWorldStateContextRuntime.cs`
- `StartupCompositionResult.cs`

`SceneComposition.cs` was split so `SceneCompositionResult` has its own file.

`MapRuntimeServices.cs`, `EffectRuntimeServices.cs`, and `BossEffectRuntimeServices.cs` were split so builder types now live in dedicated files instead of sharing the same file as their service aggregates.

`ClientWorldRoleStateStoreRuntime.cs` was split so appearance state and role snapshot declarations are each in dedicated files.

`CGameMapRuntimeStateRuntime` was extracted out of `CGameMapCreateFromDataIdRuntime.cs`, leaving the map-creation file focused on creation flow instead of also defining persistent map state.

## Intentional Non-Changes

- `ClientWorldProjectedRoleStateRuntime` stayed under `Client/Role` for now because it is still tightly coupled to projection/materialization flow used by role/map rendering.
- `ClientWorldRoleViewSceneObjectStoreRuntime` stayed under `Client/Role` for now because it consumes role render-submission contracts defined in the map rendering path.
- `RuntimeClock` stayed under `Client/Composition` because it is currently shared by resource-cache tests, startup visuals, and per-frame resource orchestration; moving it in this slice would have widened churn without improving responsibility boundaries enough.
- `CLoginStartupUiContractsRuntime.cs` and `Role3DClientSceneContractsRuntime.cs` were left intact for now because they are broad contract bundles with wide call-site reach; they should be split in a dedicated follow-up slice instead of being mixed into this one.
