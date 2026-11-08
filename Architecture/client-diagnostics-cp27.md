# CP2.7 — structured client diagnostics

OCC base `ce70e61b`. Inventory covers the desktop entry point, startup
art and packages, login and role failure paths, local account history,
clipboard and audio fallbacks, world ingress, and appearance loading.
Previous console diagnostics could print exception text, asset paths,
package declarations or arbitrary command arguments. Unhandled world
packets were deduplicated but had no small per-world budget.

The client follows the server's source-generated LoggerMessage pattern.
Only fixed event templates and allowlisted numeric fields cross the
diagnostic boundary. The client does not attach exception objects or
raw packet bytes. Packet headers and known model slots are diagnostic
context. Unknown attribute IDs collapse into one group. Structured
diagnostics are a managed operational policy.

The desktop entry point owns the .NET JSON stderr provider. It sets a
bounded, nonblocking queue. The caller retains the original exit code
2 for rejected arguments and returns 1 for managed startup/runtime
failures. The log carries a stable event ID and numeric classification.
Native process output is outside this provider. The launcher still
owns its own diagnostic pipeline.

Regression checks use synthetic ticket/path text in an actual world
ingress failure, raw packet payloads, and arbitrary attribute IDs. World
close still runs once. Unknown packet diagnostics are capped at 64 pairs
plus the limit record. CLI subprocess checks produced only one JSON
record for each case, with event 2100 / exit 2 for a rejected argument
and event 2101 / exit 1 for a missing root. Neither output contained the
synthetic marker or an exception object.

OCC #281 at `a8d78856` passed all 3,765 tests, locked restore, format,
publish, and Build Bouncer on retry. Linux, Windows, macOS, dependency
review and CodeQL passed on attempt 1. It merged as `481be469`; the
reviewed tree matches local main and #243 is closed.
