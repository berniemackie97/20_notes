# CP2.8 — failure, asynchronous lifetime and diagnostic safety

Base OCC `481be469`. Task #244 is under client runtime epic #283, R1
P0 on the Client Roadmap. CP2.7 diagnostics are merged. This checkpoint
changes managed lifetime and diagnostic behavior. It does not change
wire layouts or native game behavior.

The existing LoginAccountResponse1055 and LoginAccountExchangeResult
already redact their diagnostic strings and have regression coverage.
Adjacent authentication/admission records still expose private fields
through generated record output. Keep the wire fields and redact the
diagnostic representation.

Initial ownership gaps: a throwing world close notification or stop
callback can skip later owners. Ingress and egress stop callbacks can
fault before their pending operation is drained. Role screen ownership
can be published before callbacks are bound. Cleanup should keep the
original failure and continue releasing later owners.

## Changes and review

- ClientWorld publishes its single closing task before callbacks. Graphics
  teardown stays on the context thread and gates asynchronous network
  teardown. Notification, cancellation and cleanup faults are collected.
- Ingress, egress, role, content and authentication owners retain or join
  their drain tasks. A stop callback fault cannot skip a pending read or
  later resources. A pending role return takes precedence over admission.
  Failed screen binding never publishes the candidate or its callbacks.
- Resource groups release every constructed part even when teardown faults.
  World role rollback and normal teardown keep all observed failures.
  Drawing and frame completion preserve both faults when both fail.
- The existing 1055 test stays in place. Added explicit safe diagnostic
  output for character info, login history, prelude, admitted snapshot,
  saved-account selection and role creation outcome.

## Retained boundaries

The audited client and networking sources have no async-void handlers
or Task.Wait calls. Frame-path task reads are gated by completion
(ingress/egress, catalog/login/role, world close and CPU content). The
remaining synchronous waits are the host-owned startup rollback,
catalog disposal and desktop shutdown boundaries. They drain tasks
which use context-free continuations before releasing the window
context. They remain ordered so graphics and native input are released
on the owner thread.

Broad exception handlers in the authentication coordinators map
untrusted operation failures to existing safe outcomes. Registration
cannot infer whether an interrupted request committed. Catalog refresh
handles transport/data failures as unavailable and propagates unexpected
programming failures. Protocol catches close unusable exchanges or
release buffers/crypto state before rethrowing. Rendering constructor
rollback releases constructed resources and keeps the initiating
failure. Existing individual HUD rollback catches preserve that first
construction error after best-effort cleanup. Optional asset and
clipboard fallbacks catch their specific platform/content failures.

Nullable transfer contracts now prove successful account and role
handoffs. Remaining null suppressions are constrained to typed UI
invariants: a placed Flash text field has a parent, an available
validated HUD frame set has its required frames, prepared presentation
owns its font/layout, active input has its field, and OpenAL's null
device pointer selects the default device. The focused render and
input conformance fixtures cover those normal paths.

## Launcher gate

Two full local macOS test runs hit the same Avalonia dispatcher access
failure seen on Windows in OCC #279. The failure occurred in
`EnsureIsolatedApplication` before the test action. The fixture now
keeps one owned dispatcher for the class and disposes each fresh
window on that dispatcher even when an assertion fails. The fixture
claims dispatcher access in the builder before compositor setup.
The original five input assertions remain.
[Avalonia issue](https://github.com/AvaloniaUI/Avalonia/issues/22021).

## Local verification

Locked restore, Release build (zero warnings and errors), formatting
and all 3,770 tests passed. All five launcher input tests passed in 30
fresh processes and all 305 launcher tests passed in four fresh runs.
Full retail OpenGL conformance passed. The desktop probe ran 420
production world frames with injected packets, 20 armor swaps, 40
movement events, no context-thread content opens and clean teardown.
The probe did not authenticate against a remote server.

The launcher headless fix is part of this slice because it blocked the
full validation gate. Launcher runtime handlers and the launch/close
race remain a separate CP2.8 acceptance boundary.

The first macOS CI run failed in the class fixture before input tests.
The canceled activation dispatcher test also accesses the global
dispatcher and can initialize it from another worker. All dispatcher
consumers in the launcher test assembly now share one xUnit collection
and one headless session. The dispatcher is claimed before either
class runs. This removes the competing initialization without reducing
coverage. [First macOS run](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42428735422/job/128572645592).

Revised commit `28a5cbc0` passed Release build (zero warnings and
errors), format, all 3,770 tests and Build Bouncer. All six dispatcher
tests passed in 30 fresh processes and all 305 launcher tests passed
in four further fresh processes.

Linux Quality, macOS, dependency review and CodeQL passed for
`28a5cbc0`. The Windows launcher suite passed in both full solution
runs on that commit. Each run reported 3,673 passed and 97 hosted
skips outside the launcher suite. Hosted private retail asset checks
were skipped. [CI](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42429147211/attempts/1)
and [Windows repeat](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42429147211/job/128574652385).
#291 closes #279 on merge. CP2.8 remains open through #290.

## CP2.8b launcher window ownership

#291 merged as `00502b25` with the same reviewed tree and #279 is Done.
#290 covers the launcher runtime boundary. The verified retail
handoff writes the counters, starts AutoPatch, then closes
(`01_play_launcher_startup_and_handoff.md`, call sites `0x405A46`
and `0x405B99`). Managed close now cancels and drains its async
preferences and installation work. Successful process creation
still hands ownership to the client before launcher close.
No new native interpretation is needed.

The main window owns startup, play, settings dialog and close tasks.
It starts cancellation and all owner drains before awaiting them.
A late startup result cannot update the screen, and play checks
shutdown between preference operations and immediately before process
creation. A successful play requests close outside the tracked launch
task. A mode write that already committed remains saved. The settings
dialog drains its store and UI operation before releasing the window.
Unrelated cancellation reaches the failure path.

One guarded Avalonia event bridge observes synchronous and asynchronous
faults. The window retains original failures and separate cleanup
faults. The host receives them directly even when the dispatcher
stops pumping after close. Diagnostics keep the existing redacted
projection and nonzero exit. External URI requests are handed off to
the OS, with faults observed while the launcher remains active.

Retained synchronous waits are the bounded pre-UI activation attempt
(main-thread process lease) and the activation listener drain after
desktop exit. Listener I/O uses context-free continuations. Best-effort
deletion in release acquisition, transport and the managed store
handles absent or inaccessible temp artifacts without replacing the
actual operation result. Workspace locks release in finally and
failed files do not become verified releases. Other broad catches
either aggregate cleanup, roll back an owned resource and rethrow,
or serve the redacted host diagnostic boundary. Typed transport,
filesystem, parser, signature and process-start failures retain
their existing outcomes.

Remaining launcher null suppressions follow checked invariants:
supported catalog strings and SHA-256, validated signature IDs and
manifest paths, active generation for schema 2, hash state allocated
with an expected digest, absolute configuration root, and faded
art only on buttons that own it. These are outside the window
lifetime changes.

Locked restore, Release build with zero warnings and errors, format,
and all 3,776 tests passed locally. Six headless window cases exercise
close during startup, each launch preference await, successful
handoff, multiple shutdown failures and late dialog loads.
The macOS native probe used the production App and UI. It opened
Display Settings, sent an application quit request, verified the
request was deferred, and exited 0 after the dialog and main window
closed. It did not start a game client.

OCC #292 at `f836d276` passed Build Bouncer and first-attempt Linux
Quality, macOS, Windows, dependency review and CodeQL. Windows ran the
whole launcher suite and reported 3,679 solution tests passed with
97 hosted skips outside the launcher. Hosted private retail gates
were skipped. [CI](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42431909188/attempts/1).
#292 closes #290 and #244 when merged.
