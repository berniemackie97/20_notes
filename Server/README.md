# Server contract — index

What a server has to do, read out of the client. These documents describe the
native client's expectations; they are not a description of any particular server.
Where an implementation is named it is `50_server/OpenConquerPublic`.

Each document states its own verification date and binary. Most of the protocol
work dates from late August 2026; `database-provenance.md` is older (2026-04-22)
and three documents carry no date at all.

## Session

- [login-credential-envelope.md](login-credential-envelope.md) — how the account
  server recovers a password from a login request. **Settled and proven against
  the real native client.** Two stages: the RC5 key is derived from the login
  seed, then the per-account keypad permutation is applied. `0x93FD84` is only the
  pre-login default and is overwritten by
  `CMsgLoginSeed__Process_DeriveCredentialRc5KeyFromSeed` (`0x764BC6`).
- [world-entry-bootstrap.md](world-entry-bootstrap.md) — map identity and the
  10014 gate, from the 2026-08-23 smoke test against OpenConquerPublic.
- [online-directory.md](online-directory.md) — the server-wide list of signed-in
  characters. Distinct from visibility, which is per-map.

## World and movement

- [movement.md](movement.md) — movement and jump. Both server-authoritative: the
  client applies nothing until the server echoes it back, and withholding the
  reply is the only way to refuse.
- [movement-eligibility-5517.md](movement-eligibility-5517.md) — statuses, request gates, jump/charge
  elevation, mount and vigor, local animation vs gate, TQ 15.10 enforcement.
- [position-sync.md](position-sync.md) — position synchronisation.
- [death-ghost-revive-5517.md](death-ghost-revive-5517.md) — death, ghost transition (145), revive (94),
  Revive Here gates, revival sync and destinations; client vs TQ 15.10 vs community.
- [map-transitions.md](map-transitions.md) — map transitions.
- [portal-transition-5517.md](portal-transition-5517.md) — connected travel: frame modes 0x3F0/0x3F2/0x3F5,
  inbound 86 step list, ordering 86 → 1110 → spawns, no client ack, refusal strands the client, 74 forbidden
  mid-session; TQ 15.10 ChangeMap/FlyMap/EnterMap order, Fox. 2026-10-24.
- [entity-visibility.md](entity-visibility.md) — who each client is told about.
- [npcs.md](npcs.md) — NPC spawn and removal.

## Interaction

- [chat.md](chat.md) — `MsgTalk` (1004).
- [npc-dialog.md](npc-dialog.md) — `MsgTaskDialog` (2032). Transport only; what a
  server puts through it is a separate question.
- [equipment.md](equipment.md) — equip and unequip over `MsgItem` (1009).
- [character-attributes-and-auto-allot.md](character-attributes-and-auto-allot.md) —
  attributes, auto-allot, and the profession family, anchored on
  `CHero::GetEffectiveMaxLife` (`0x65D0C9`–`0x65D0EF`).

## Reference server binaries

- [tq-server-binaries-2008.md](tq-server-binaries-2008.md) — TQ CQServer 15.10 (2008-10-21) MsgServer/NpcServer
  + plugin DLLs: copy census, canonical picks, IDA DB fixups, era deltas (Blowfish vs CAST5). IDBs in
  `50_server/binaries/_re/`. 2026-10-12.
- [tq-server-15.10-runtime-semantics.md](tq-server-15.10-runtime-semantics.md) — proven 15.10 behaviour: shop load/buy,
  action/task engine, spawn generators, map cell/collision composition. Addresses + IDB names. 2026-10-12.
- [historical-reconciliation-5095.md](historical-reconciliation-5095.md) — OpenConquerServer vs ZFSERVER (5095) vs 5517:
  39 classified findings (items, shops, additions, maps, actions, DB), proposed catalogs, import procedure, task list.

## Realms

- [multi-realm-architecture-5517.md](multi-realm-architecture-5517.md) — decision record: one AccountServer, one
  GameServer + Game DB per realm, realm registry keyed by protocol server name, realm-bound tickets. 2026-10-12.
- [historical-multi-server-topology.md](historical-multi-server-topology.md) — TQ 15.10 world/AccountServer link,
  identity, capacity, per-world DB. 2026-10-12.

## Data provenance

- [map-catalog-5517.md](map-catalog-5517.md) — **current server map list.** 289 world IDs anchored on
  the client's GameMapEx.ini (proven world-MapId table) + client data refs; bindings/flags from TQ data
  (2007 MYD, Long/Canyon TQ-English lineage); passways checked against native DMap exits. 2026-10-10.
- [zf-map-reconciliation-5517.md](zf-map-reconciliation-5517.md) —306-row zf provenance, complete426-ID
  reconciliation against both273-row dumps and the276 reconstruction, related references, native
  compatibility, historical portal-deletion findings and unresolved retail authority. Verified2026-10-10.

- [database-provenance.md](database-provenance.md) — what the workspace database
  actually is, table by table, measured against the client's own shipped data.
- [map-identity-flags-native-5517.md](map-identity-flags-native-5517.md) — native field widths,
  exact flag masks, terrain-index census, eight geometry rechecks, all 38 non-identical legacy pairs,
  map 1501 ambiguity, and the limits of the276-row reconstruction. Verified 2026-10-09.
- [map-catalogue-corrections.md](map-catalogue-corrections.md) — historical migration and coordinate
  tests; retail-identity overclaims corrected by the audit above.
- [map-assets.md](map-assets.md) — native map asset formats and the server
  contract over them.

- [Retail credential mode selection](credential-mode-selection-5517.md) — 2026-10-30: encoding/policy argument separation, all direct callers, account switching, and exceptional preload boundary.

- [Historical 15.10 creation decisions](character-creation-decision-15.10.md) — acceptance/refusal, ownership, response order, and persistence failure boundaries.
