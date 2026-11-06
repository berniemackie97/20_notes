# Client role-creation ownership — CP2.1b

2026-11-06 pre-flight. OCC baseline `7563ad6e` (open #235, CP2.1a), followed by
test-only CI repair `90899a35`: observe canceled task completion rather than a load
delegate's finally (which may never run). Run 996 is green on all three OS jobs.
The approved CP2.1 split is world owner, role-creation owner, then login owner /
application state / linear disposal. #235 subsequently merged as `14648db6` and
Bernie confirmed completion; this slice now targets main. Running-client smoke
has not been verified.

Existing behavior authority: `Architecture/12_create_role_flow.md` and
`Architecture/11_login_ui_assets_and_interactions.md` (loading transition), plus
the existing role screen, exchange and pinned fixture tests. No new native claim,
wire change, symbol annotation or BNDB save is required for this ownership refactor.

Move role screen, ini/text/font/raster caches, presentation binding and return/close
state out of ClientApplication. Keep the native command interpreter and network
exchange unchanged. Preserve Tick → admission callback → screen close → requested
return ordering, and observe background close before reopening. Preserve the global
context resource group's disposal order and the later font release point.

Tests will cover cancellation/return, admission handoff, initialization failure,
pending close observation and shutdown. Login ownership, clock/logging cleanup and
the final application state machine remain CP2.1c or their existing later slices.

Implementation: ClientRoleCreation owns screen/cache/presentation binding/input and
return/close state; IRoleCreationScreen supplies the narrow screen boundary for
lifetime tests. Native screen method bodies, exchange, Flash scripts, world and
networking are unchanged. Shared content field is now `_content` (C10).

Local validation: SDK 10.0.403 locked restore; Release build zero warnings/errors;
2,798 focused tests pass (Client 1,463, Content 750, Rendering 499, Platform 86),
including 11 new owner/handoff cases. The pinned creation/proof/world-entry transport
fixture confirms a walk works on the admitted session after owner disposal. Host
size is 638 lines after 2.1b (716 at CP2.1a); this is diagnostic, not a target.
Full format verification passes. [OCC #236](https://github.com/berniemackie97/OpenConquerClient/pull/236)
opened from `bernie/client-role-owner` at `12c40be2`, directly on merged #235.
[CI run 998](https://github.com/berniemackie97/OpenConquerClient/actions/runs/42166297478)
passed Quality (including rendering/packaging), Windows and macOS; dependency review
passed. Ready for Bernie review. Local branch is clean and synchronized; local main
matches #235 (`14648db6`). No running-client smoke claim; CP2.1c has not started.
