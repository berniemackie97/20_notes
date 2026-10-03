# Network — index

The 5517 wire protocol as implemented in `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`.
`NetMsg.cpp` dispatches 150 message types in the range 1002–1151; the else-branch
range runs to 10017.

Start with [00_protocol_overview.md](00_protocol_overview.md) for framing, header
validation and the encryption state machine, then
[13_connection_lifecycle.md](13_connection_lifecycle.md) for how a session is
actually established.

## Transport

- [00_protocol_overview.md](00_protocol_overview.md) — packet header, size and
  type validation, the CAST5-CFB64 phase and the `TQServer`/`TQClient` signature
  trailer.
- [13_connection_lifecycle.md](13_connection_lifecycle.md) — TCP connect, DH
  handshake, authentication, `CGameSocket` memory layout, `CClientSecurity`
  internals.
- [14_session_derived_legacy_cipher_mask.md](14_session_derived_legacy_cipher_mask.md) —
  audit proving the post-1055 session-derived mask rekeys the outbound legacy
  tables but is never consumed in mode 2.

## Packets by domain

- [01_core_packets.md](01_core_packets.md) — login, connection, player identity.
- [02_entity_packets.md](02_entity_packets.md) — NPC, entity, monster, names.
- [03_item_packets.md](03_item_packets.md) — items, equipment, gems, packages.
- [04_social_packets.md](04_social_packets.md) — chat, team, friends, trade,
  flowers, coach.
- [05_guild_packets.md](05_guild_packets.md) — syndicate, peerage, guild war.
- [06_combat_packets.md](06_combat_packets.md) — magic, skills, interact, PK.
- [07_world_packets.md](07_world_packets.md) — map, weather.
- [08_system_packets.md](08_system_packets.md) — tick, achievements, titles,
  missions, sub-profession, cross-server.
- [09_minigame_packets.md](09_minigame_packets.md) — ShowHand poker, race track,
  Texas Hold'em.
- [10_extended_packets.md](10_extended_packets.md) — pet, mentor, arena, quiz,
  title, cross-server war.
- [11_else_branch_packets.md](11_else_branch_packets.md) — types 1313–10017, the
  dispatch else-branch. Read the warning on the attribute-ID name column before
  citing it.

## Single-question audits

- [12_address_index.md](12_address_index.md) — address-to-name lookup tables. The
  2026-09-03 session-mask audit index, then a general network helper index. Names
  are analyst labels, not recovered debug symbols.
- [15_msgwalk_10005_direction_index_order.md](15_msgwalk_10005_direction_index_order.md) —
  the direction index order for `10005`, and the 8- vs 24-direction selector.
- [18_post_auth_server_comparison.md](18_post_auth_server_comparison.md) —
  existing-character login compared against the reference server.
- [MsgUserInfo1006-semantic-closure-2026-09-17.md](MsgUserInfo1006-semantic-closure-2026-09-17.md) —
  full wire map for 1006 and the state of each field's semantics. The date-stamped
  filename is cited inside `Conquer.exe.bndb`; do not rename it.

- [MsgUserInfo1006-historical-field-reconciliation.md](MsgUserInfo1006-historical-field-reconciliation.md) —
  focused COPS5066 alignment, retained compatibility slots, attribute23/24 and native proof limits.

- [MsgItem1008-domain-contract-5517.md](MsgItem1008-domain-contract-5517.md) — item field ownership,
  subtype1 versus inspected subtype4, equipment snapshots, locking, lifetimes, stacks and explicit unknowns.

## Related

Cipher primitives are in [../Crypto/](../Crypto/README.md). The server-side view
of what these packets must do is in [../Server/](../Server/README.md).
