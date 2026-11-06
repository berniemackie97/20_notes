# Client login/session ownership — CP2.1c

2026-11-06 pre-flight. OCC `9933b852` (merged #236). Final part of the approved
world / role / login-and-state split. No new native or wire behavior is required.
Existing authorities: Architecture/03_login_flash_startup_command_contract.md,
Architecture/11_login_ui_assets_and_interactions.md, Architecture/12_create_role_flow.md,
and the pinned account/creation/world-entry fixtures already used by the client.
No native symbol changes or BNDB save are required for this modern ownership slice.

ClientLogin will own screen, catalog, attempts, registration, loading presentation
and audio. ClientSession will own transitions among Login, RoleCreation,
WorldLoading, World and return/closing phases, composing the three resource owners.
ClientApplication will retain window/context/device/loop hosting, not login flags.

Preserve frame ordering, native loading gates and handoff/close ownership. Keep
network teardown before window/context teardown and content release after it.
Replace nested shutdown with ordered stages that run despite earlier failures;
retain all cleanup failures. Tests must exercise transitions and cancellation,
delayed close/load reaping, handoff, partial startup and failed/repeated shutdown.
Gameplay rules, packet parsing, broad clock/logging cleanup and docs refresh remain
their existing later checkpoints.

Implementation: ClientLogin owns login UI/services, ClientSession owns explicit
Login / RoleCreation / WorldLoading / World / ReturningToLogin / Closing / Closed
phases. ClientApplication is 240 lines (638 at CP2.1b); no login/world flags or
coordinator fields remain. Host Created/Started/Disposed only guards desktop lifetime.

Ordered cleanup attempts all owners and preserves failures. A failed world map-load
dispose previously skipped ingress/session cleanup; regression tests now prove both
run, including when session cleanup also fails. World close retains its network task
when graphics release fails; graphics cleanup attempts all resources. Failed world
factory ownership is tracked to shutdown rather than dropping the transferred socket.

Local validation: SDK 10.0.403 locked restore, zero-warning Release build, 2,820
focused tests (Client 1,485, Content 750, Rendering 499, Platform 86), including 22
new cases. Real encrypted fixtures cover both admission routes and same-socket walk
after role handoff; readiness/loading gate, return reasons, delayed load reaping,
pending account/catalog cancellation and failed/repeated shutdown are covered.
Native frame-17/36/99 gates reused from note 11; synthetic placement timeline tests
the existing loading state machine, without claiming framebuffer equivalence.
Final format passes; constrained one-processor run passes 26 selected lifecycle
cases. [OCC #237](https://github.com/berniemackie97/OpenConquerClient/pull/237) opened
at `7606c685` on `bernie/client-login-state`.
[CI run 1000](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42244420171)
passed Linux Quality (including rendering/packaging), Windows and macOS; dependency
review passed. Ready for Bernie review. Local branch is clean, pushed and
synchronized. Running-client smoke remains unverified; CP2.2 not started.

Completion 2026-11-06: Bernie confirmed completion; #237 merged as `3d7144b6`.
Local main is clean and synchronized with that merge. CP2.1 (all three ownership
PRs) is closed. CP2.2 hero-model/native-constant pre-flight is next, not started.
