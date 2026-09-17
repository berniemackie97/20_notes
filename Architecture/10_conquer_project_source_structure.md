# Conquer Project Source Structure

## Scope

This slice reorganizes `10_work/src/Conquer` by runtime responsibility. It does not change packet,
format, timing, rendering, or startup behavior.

- SDK selection: `10_work/global.json` resolves installed SDK `10.0.302`
- Native binary selected for the startup evidence check: `Conquer.exe.bndb`
- Runtime behavior: unchanged by intent
- Binary Ninja database: no semantic names or types changed; two existing `RoleView.dll` weapon-setter
  comments received path-only updates after their managed file moved

Namespaces remain stable in this slice so physical organization is not mixed with an API-wide rename.

## Structural Standard

The executable project is organized first by feature or process boundary, then by responsibility:

- `Application`: composition roots, composition results/contexts, frame orchestration
- `Hosting`: application lifecycle and owned startup/input/render resources
- `Startup`: authentication, audio, configuration, lifecycle, messaging, presentation, rendering,
  server selection, and UI
- `World`: authoritative state, immutable models, packet-fed ingress, and movement orchestration
- `Scene`: frame pipeline and world-to-render projection
- `Map`: loading, map components, ground, scenery, state, ingress, and rendering
- `Role`: appearance, command-state adapter, models, playback, projection, rendering, and scene objects
- `CommandState`: ingress, movement, playback, resolution, state, and synchronization
- `UI`: controls, HUD, status hints, and UI asset metadata
- `Effects` / `BossEffects`: effect configuration/catalog/production and boss-effect runtime concerns
- `Composition`: shared resource contracts, registries/caches, and runtime timing

`Contracts`, `Models`, and `State` are separated from executable services. Implementation namespaces
are intentionally unchanged; folder names communicate ownership without changing managed identities.

`ConquerSourceLayoutTests` guards the feature roots against becoming loose-file dumping grounds again;
only project-level entry/plumbing files and the two single-purpose facades are allowed directly in
those roots.

The pass also normalized the pre-existing whitespace defect in
`UI/Hud/CDlgMainGaugeReadingFromWorldState.cs`; the repository-wide formatter verification now passes.

## Provenance Rule

Physical responsibility and evidence status are separate concerns. A folder location never proves
native parity. Verified behavior must retain its Binary Ninja or clean-data trail in the appropriate
note.

When verified native behavior and project-owned replacement behavior coexist in the same feature,
the source tree must make the distinction explicit. The first application of that rule is
`Startup/ServerSelection`:

- `NativeParity`: `Server.dat` decoding consumers and native `REGION`/`SERVER` payload semantics
- `OwnUi`: project-owned server catalog used by the non-Flash startup UI
- `Contracts`: shared provider and payload boundaries
- `Fallbacks`: explicit unavailable/null-object implementations

## Current Server.dat Runtime Status

The managed runtime ships clean `Server.dat` files in both `assets/5517` and `assets/5517-1`; the two
files are byte-identical at the time of this slice.

Native evidence remains as documented in `05_startup_data_files_and_native_replacement.md`. The
reviewed `Conquer.exe` function `CMyShellDlg_ValidateServerDatAndNotifyHero` (`0x5AFAFC`) opens
`server.dat`, reads at most `0x400` bytes, and checks printable/space or DBCS byte handling. The native
decode and payload evidence is recorded separately in that note.

The active `main-own-ui` managed flow does not currently consume `Server.dat` for endpoint selection:

1. `ConquerClientStartupSubsystemFactory` constructs `CLoginStartupUiPresentation` without a catalog
   provider.
2. `CLoginStartupUiPresentation` therefore selects
   `CLoginStartupUiServerCatalogHardwiredRuntime`.
3. That project-owned provider returns `Main World / Local Server / 127.0.0.1:9958`.
4. `CLoginStartupUiServerCatalogFromServerDatRuntime` and
   `CLoginStartupServerDatPayloadProducer` remain implemented and tested, but are not wired into the
   active own-UI composition path.

Changing that selection policy is a runtime behavior decision, not a file-organization refactor. It
must be handled in a separate slice with an explicit endpoint/source policy and focused tests.

## Intentional Non-Changes

- No source namespace was renamed.
- No class was moved between assemblies.
- No active server-selection provider was changed.
- No native/proprietary asset was copied or rewritten.
- Existing in-progress scene and test changes were preserved.
