# Shared build baseline — CP1.3 / D5

Decision recorded 2026-11-05. Modern development policy; no native 5517 behavior
claim and no Binja/IDA rename, comment, or database save required for this slice.

- Both repositories: SDK `10.0.403` (exact pin), C# `14.0`, `net10.0`,
  `latest-recommended` analyzers, warnings-as-errors, enforced code style.
- Validate written XML docs; missing-member XML docs allowed (`CS1591`).
- Central transitive package pinning, locked restore, deterministic builds, portable
  symbols, CI continuous-integration metadata.
- Explicit types; file-scoped namespaces; braces; unused-import and formatting errors.
  Preserve the stricter client rule expanding single-line blocks/statements.
- Prefer primary constructors where clean and appropriate, not only for DI types.
  Keep explicit constructors for validation, derived state, or readonly stored values.
  Preference is advisory; no bulk primary-constructor conversion.
- Test underscores allowed by test-only `CA1707` exemption.

The matching `docs/architecture/shared-build-baseline.md` in OpenConquerServer and
OpenConquerClient records the policy and validation commands. Cancellation/cleanup
regressions exposed while resolving analyzers receive focused lifetime tests.

Local validation on SDK `10.0.403`: both locked restores, Release builds (zero
warnings), and format verification pass. OCS focused suites: Domain 343, Protocol
622, Transport 71, Application 422, AccountServer 218, GameServer 873, content tool
222 (2,771 total). OCC: Client 1,448, Content 750, Platform 86, Rendering 499
(2,783 total). Both EF model checks report no pending model changes. Infrastructure
Docker tests and other platform gates are left to CI.

Merged PRs: [OCS #189](https://github.com/berniemackie97/OpenConquerServer/pull/189)
and [OCC #234](https://github.com/berniemackie97/OpenConquerClient/pull/234).

CI is green for both PRs: OCS verification (including Docker tests), dependency
review and terrain integration; OCC Windows, macOS, quality and dependency review.

Status: complete. Bernie confirmed both merges on 2026-11-05: OCS `718eaf7`,
OCC `ed181d7b`. Local mains synchronized; CP1.4 is next.
