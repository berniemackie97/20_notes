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
- [position-sync.md](position-sync.md) — position synchronisation.
- [map-transitions.md](map-transitions.md) — map transitions.
- [entity-visibility.md](entity-visibility.md) — who each client is told about.
- [npcs.md](npcs.md) — NPC spawn and removal.

## Interaction

- [chat.md](chat.md) — `MsgTalk` (1004).
- [npc-dialog.md](npc-dialog.md) — `MsgTaskDialog` (2032). Transport only; what a
  server puts through it is a separate question.
- [equipment.md](equipment.md) — equip and unequip over `MsgTick` (1009).
- [character-attributes-and-auto-allot.md](character-attributes-and-auto-allot.md) —
  attributes, auto-allot, and the profession family, anchored on
  `CHero::GetEffectiveMaxLife` (`0x65D0C9`–`0x65D0EF`).

## Data provenance

- [database-provenance.md](database-provenance.md) — what the workspace database
  actually is, table by table, measured against the client's own shipped data.
- [map-catalogue-corrections.md](map-catalogue-corrections.md) — what the map
  catalogue got wrong and how it was disproved, using only coordinates the
  database already places on a map.
- [map-assets.md](map-assets.md) — native map asset formats and the server
  contract over them.
