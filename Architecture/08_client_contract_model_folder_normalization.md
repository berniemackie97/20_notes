# Client Contract And Model Folder Normalization

## Scope

This slice continues the source-only client structure refactor in `10_work/src/Conquer/Client`.

- Runtime behavior: unchanged by intent
- Packet semantics: unchanged by intent
- BNinja database: unchanged in this slice
- Native evidence/addresses: not applicable because no verified parity logic changed

The purpose of this slice was to finish the missing structural pattern from the prior pass:

- stop leaving contracts embedded in runtime files
- stop leaving model/result records mixed into orchestration files
- use area-local `Contracts`, `Models`, `State`, and `Orchestration` folders consistently
- remove the stale root-level `Client/Contracts` placeholder from the project structure

## Structural Standard Applied

### Application

- `Application/Hosting`: entry and lifecycle host
- `Application/Composition`: composition-root assembly/builders only
- `Application/Models`: composition results and context models
- `Application/Orchestration`: application-level per-frame orchestration

### Startup

- `Startup/Contracts`: startup-facing interfaces
- `Startup/Models`: startup snapshots and run-loop/startup results
- `Startup/State`: mutable startup state containers
- `Startup/Orchestration`: startup state machine and run-loop orchestration

### Scene

- `Scene/Contracts`: scene stage interfaces
- `Scene/Models`: scene frame/tick/render result models

### Map

- `Map/Contracts`: map-facing interfaces
- `Map/Models`: map result/render-context models
- `Map/State`: map-local state containers and projection-state sinks

### World

- `World/State`: authoritative mutable world state
- `World/Models`: immutable world snapshot/model records
- `World/Orchestration`: world-state mutation orchestration

## Main Moves

| Old location | New location | Purpose |
|---|---|---|
| `Application/Composition/{RolePlaybackHostContextRuntime,MapResourceRequestContextRuntime,StartupNetworkIngressContextRuntime,ClientWorldStateContextRuntime,StartupCompositionResult,SceneCompositionResult}` | `Application/Models/*` | separate models from composition executables/builders |
| `Startup/CLoginStartupUiContractsRuntime.cs` | `Startup/State/CLoginStartupPresentationStateRuntime.cs` | keep mutable startup presentation state alone |
| `Startup/ConquerAppRunMessageLoopRuntime.cs` | `Startup/Orchestration/ConquerAppRunMessageLoopRuntime.cs` | explicit startup orchestration placement |
| `Startup/ConquerAppStartupStateMachineRuntime.cs` | `Startup/Orchestration/ConquerAppStartupStateMachineRuntime.cs` | explicit startup orchestration placement |
| `Scene/Role3DClientSceneContractsRuntime.cs` | `Scene/Contracts/Role3DClientSceneStageContracts.cs` | separate scene stage contracts from results |
| `Map/CGameMapDisplayAndGridStateRuntime.cs` | `Map/State/CGameMapScreenDimensionsRuntime.cs` | separate map-local state from contracts |
| `Map/CGameMapType4RecordEntryRuntimeContracts.cs` | `Map/CGameMapType4RecordEntrySupportRuntime.cs` | leave support/no-op/math logic in support file; move interfaces out |
| `World/State/{ClientWorldRoleAppearanceStateRuntime,ClientWorldRoleStateSnapshotRuntime}` | `World/Models/*` | immutable world records belong in models, not state |

## Main Splits

### Startup

`CLoginStartupUiContractsRuntime.cs` was split into:

- `Startup/State/CLoginStartupPresentationStateRuntime.cs`
- `Startup/Models/CLoginStartupPresentationStateSnapshotRuntime.cs`
- `Startup/Models/CLoginStartupVisualStateSnapshotRuntime.cs`
- `Startup/Contracts/CLoginStartupVisualStateContracts.cs`

`ConquerAppRunMessageLoopRuntime.cs` was split into:

- `Startup/Orchestration/ConquerAppRunMessageLoopRuntime.cs`
- `Startup/Contracts/ConquerAppRunLoopContracts.cs`
- `Startup/Models/ConquerAppRunMessageLoopResultRuntime.cs`

`ConquerAppStartupStateMachineRuntime.cs` was split into:

- `Startup/Orchestration/ConquerAppStartupStateMachineRuntime.cs`
- `Startup/Contracts/ConquerAppStartupContracts.cs`
- `Startup/Models/ConquerAppStartupRunResultRuntime.cs`

### Scene

`Role3DClientSceneContractsRuntime.cs` was split into:

- `Scene/Contracts/Role3DClientSceneStageContracts.cs`
- `Scene/Models/Role3DClientSceneStageResults.cs`

### Map

`CGameMapCreateFromDataIdRuntime.cs` now depends on:

- `Map/Contracts/CGameMapCreateContracts.cs`
- `Map/Models/CGameMapCreateFromDataIdResultRuntime.cs`

`CGameMapType4RecordEntrySupportRuntime.cs` now depends on:

- `Map/Contracts/CGameMapType4RecordEntryContracts.cs`
- `Map/Models/CGameMapFileRecordType04EntryRenderContextRuntime.cs`

`CGameMapScreenDimensionsRuntime.cs` now depends on:

- `Map/Contracts/CGameMapDisplayContracts.cs`
- `Map/State/CGameMapLoadedGridDimensionsProjectionStateSinkRuntime.cs`

## Project Hygiene Changes

- Removed the stale `<Folder Include="Client\\Contracts\\" />` entry from `src/Conquer/Conquer.csproj`.
- Removed the empty root `Client/Contracts` directory from the live tree.
- Added project-root `GlobalUsings.cs` files in `src/Conquer` and `tests/Conquer.Tests`.
- Policy for those files: only stable internal contracts/models/state namespaces with broad cross-project usage are global; implementation namespaces remain explicit in individual files.

## Intentional Non-Changes

- `Client/Composition` still contains resource-loading support abstractions and registries. Those files are already cohesive around the resource subsystem, so they were not renamed or redistributed in this slice.
- `Client/Role` still contains projected-role materialization and role-view scene-object submission logic. Those are still tightly coupled to role rendering flow and should be handled in a dedicated role/world boundary slice rather than mixed into this contracts/models pass.
- Startup runtime files outside the specific run-loop/state-machine/UI-state bundles were not mass-moved. Doing that now would increase churn without improving clarity as much as finishing the contract/model split first.
