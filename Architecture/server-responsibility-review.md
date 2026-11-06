# Server responsibility review — CP1.5

2026-11-05. OCS baseline `7407c71` (merged #190). Modern component boundaries;
no new native behavior or wire-contract claims. CP1.4 accepted retaining the gate,
command representation and worker policy. Keep those invariants unchanged.

Review targets: WorldRuntime 1,170 lines; WorldSession 932; GameConnectionSession
707; AccountMutationStore 645. Line count is evidence for review, not a size limit.

Existing authority is already recorded: ledger kind M for runtime/persistence;
Server/world-entry-bootstrap.md, Server/movement-eligibility-5517.md,
Server/death-ghost-revive-5517.md, Server/chat.md and Network/13_connection_lifecycle.md
for behavior surfaced by sessions. This slice moves existing behavior without changing
packet bytes, validation/tolerance, pacing, timers, failure classification or ordering.
No native symbol rename/comment or BNDB save is required.

Candidate boundaries from source inspection:
- WorldSession combines connection/resource lifetime with inbound gameplay handling
  and its pacing/reconciliation state. Extract a composed gameplay handler; preserve
  the session facade and ordered writes/visibility/lifetime controls.
- GameConnectionSession already delegates transport pumps and framing. Its handshake
  progression guards form a separate synchronous state component. Keep the same
  protocol gate, disposal checks, cipher ownership and cleanup order on the session.
- WorldRuntime owns authoritative cross-map residency. Reservation/seal/session-key
  changes share one gate and transactional cutover. Existing scheduler/partition/
  portal components already separate execution and external I/O. Retain the cohesive
  authority rather than distribute the same mutable ownership state among wrappers.
- AccountMutationStore owns atomic account-security persistence. Account, credential,
  ticket revocation and audit writes share lock order and one transaction. No password
  hashing, transport, hosting or logging lives here. Retain this transaction boundary;
  moving SQL helpers into a utility would not introduce a separate responsibility.

Pre-flight complete. Preserve all existing tests/fixtures and exceptions; verify moved
method bodies mechanically and run the unchanged focused suites. No lock/command
redesign, catch audit or unrelated docs cleanup in this slice.

Implementation: WorldSessionGameplay owns the existing ingress handlers and their
pacing/reconciliation fields; facade retains connection/output/location/lifetime.
GameHandshakeProgress owns handshake flags/guards; facade retains the original
protocol gate, disposal checks, codec adoption and cleanup. WorldRuntime and
AccountMutationStore remain unchanged, with cohesion rationale in OCS
`docs/architecture/server-responsibilities.md`.

Verification: 78 source-equivalence checks (moved bodies with owner-reference
rebinding, guards/lock scopes, state initializers, codec/cancel/disposal ordering,
constructor/rebind points and retained-file equality). Existing tests/fixtures are
unchanged; focused suites 2,782 pass, including GameServer 873 and Protocol 622.
Release build has zero warnings; locked restore and format pass. Source checker and
digests: OCS `docs/reviews/verify-server-responsibilities.py` and
`docs/reviews/evidence/server-responsibilities-2026-11-05/equivalence.json`.

Current sizes: WorldSession 650 + gameplay 364; GameConnectionSession 646 + progress
100. No size target or cosmetic partial-class split. CP1.5 implementation/review
complete locally; OCS [#191](https://github.com/berniemackie97/OpenConquerServer/pull/191)
on `bernie/server-responsibilities` at `104cc83`. [CI run 558](https://github.com/berniemackie97/OpenConquerServer/actions/runs/42151556236)
passed Verify (full suite and schema checks), dependency review and Studio terrain
integration. Committed source checks reproduce the recorded digests. Local server
branch and client main are clean and synchronized with upstream. Bernie review pending;
CP1.6 has not started.
