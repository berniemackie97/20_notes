# Solution Architecture (Current Boundary Contract)

## Intent

This document defines the project-layer boundaries for `10_work` so implementation quality and maintainability stay consistent as reverse-engineering coverage grows.

## Project Responsibilities

| Project | Responsibility | Must Not Contain |
|---|---|---|
| `Conquer.Assets` | Asset parsing/loading domain, file format readers, resolver data tables. | Runtime orchestration, socket/channel flow, app startup state machines. |
| `Conquer.Crypto` | Cryptographic primitives and stateful cipher contexts (`TqCipher64*`). Reusable by runtime/tools/tests. | Rendering, gameplay state orchestration, launcher behavior. |
| `Conquer.Graphics` | Rendering/runtime graphics primitives and parity-focused graphics/motion/effect logic. | Launcher/process startup flows, socket transport orchestration. |
| `Conquer.Network` | Network packet contracts, transport flows, handshake/session channel logic. | UI/render runtime orchestration, launcher process logic. |
| `Conquer` | `Conquer.exe` app-layer runtime orchestration (scene, role, map, startup/run-loop parity). | `play.exe` launcher handoff implementation, autopatch-specific startup logic. |
| `Conquer.Play` | `play.exe` launcher behavior and handoff contracts. | `Conquer.exe` scene/runtime orchestration. |
| `Conquer.AutoPatch` | `AutoPatch.exe` app-layer boundary project (implemented as evidence is verified). | Conquer client scene/runtime logic. |

## Dependency Direction

Allowed:

- `Conquer` -> `Conquer.Assets`
- `Conquer` -> `Conquer.Graphics`
- `Conquer` -> `Conquer.Network`
- `Conquer.Network` -> `Conquer.Crypto`
- `Conquer.Tests` -> all projects under test

Disallowed:

- `Conquer.Assets` -> app-layer projects (`Conquer`, `Conquer.Play`, `Conquer.AutoPatch`)
- `Conquer.Graphics` -> app-layer projects
- `Conquer.Crypto` -> app-layer projects
- `Conquer.Network` -> app-layer projects
- Any circular project references

## Placement Rules

1. If logic is pure file/asset decoding, place it in `Conquer.Assets`.
2. If logic is cipher/math primitive behavior, place it in `Conquer.Crypto`.
3. If logic coordinates socket transport/session state, place it in `Conquer.Network`.
4. If logic is rendering/motion/effect parity, place it in `Conquer.Graphics`.
5. If logic orchestrates `Conquer.exe` startup/run-loop/scene runtime, place it in `Conquer`.
6. If logic is `play.exe` launcher-only, place it in `Conquer.Play`.

## Enforcement Checklist (for each new PR)

1. Verify no new forbidden project reference direction.
2. Verify no duplicated crypto primitive code outside `Conquer.Crypto`.
3. Verify no packet/transport orchestration duplication outside `Conquer.Network`.
4. Ensure launcher logic stays in `Conquer.Play`, not `Conquer`.
5. Run full test suite after boundary-impacting refactors.

## Binary File I/O Contract (Verified)

Ground truth from `Conquer.exe`:

- `CGameMap_LoadMapFileFromRelativePath` (`0x61DC3D`) performs fixed-width binary reads (`2`/`4` bytes) from a map reader.
- Parse flow asserts/open-checks first (`mapfileReader.ReadSuccess()`), then reads sequential fields.
- Malformed/truncated reads are treated as hard failures (abort parse path), not soft defaults.

Implementation requirements in `10_work`:

1. Binary parsers must use little-endian fixed-width reads (`uint16`/`uint32`/`float32`) matching on-disk layout.
2. Every read/skip must be bounds-checked and fail fast with deterministic exceptions.
3. Parser code should centralize low-level read/skip primitives to avoid duplicated offset arithmetic and drift.

Automated coverage:

- `10_work/tests/Conquer.Tests/Architecture/SolutionArchitectureTests.cs` enforces
  project-reference direction and verifies legacy `src/Conquer/Crypto` does not reappear.

## Startup Parity Notes

- `20_notes/Architecture/01_play_launcher_startup_and_handoff.md` captures verified `play.exe` startup and launcher handoff behavior for clean 5517.
- `20_notes/Architecture/02_conquer_client_startup_chain.md` captures verified `Conquer.exe` startup from CRT entry to the first stable frame-driving idle loop.
