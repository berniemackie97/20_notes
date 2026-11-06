# CP2.4 — inbound validation vs native tolerance

**2026-11-06 · static clean-5517 · Binja view `Conquer.exe.bndb`.** No runtime capture. No BNDB save.

## Native receive path (CP2.4a)

| Step | Address | Fact |
|---|---|---|
| Receive | `CNetMsg__ProcessMsg` `0x6DEBF8..0x6DEC06` | `CGameSocket_ReceiveMsg` into 0x400 buffer. |
| Frame stop | `0x6DEC22` / `0x6DEC26` | size > remaining (signed) or size == 0 → leave loop. Transport, not message validation. |
| Dispatch | `0x6DEC2C` → `0x6DF3B5` | null buf / size > 0x400 (`0x6DF3D8`, signed) / unknown type → null. |
| Construct | per type, `operator new(0x408)` + ctor | every ctor calls `CNetMsg__ResetPacketBuffer` `0x6DF290`: `memset(object+4, 0, 0x400)`. Fresh object per message. |
| Parse | vtable+4, `0x6E1365` | `CNetMsg__ValidateHeaderAndCopy`: nonnull, header size == count, type ≠ 0; copy `size` bytes. Then type compare. No per-type size check. Fail → delete, null. |
| Skip | `0x6DEC3A` | null → no Process, no disconnect; advance by size, next message. |

Consequence: short message → unread fields are **zero**. Long message (≤ 0x400) → extra bytes ignored. Malformed message is dropped, never closes the session.

Ctor resets verified: 10005 `0x7403C3`, 10010 `0x6FE8D7`, 1008 `0x762A5C`, 1009 `0x6EAC0D`, 1016 `0x760689`, 10017 `0x75730D`.
Parsers 1008 `0x762AA0`, 1009 `0x6EAE56`, 10005 `0x7404BE` (vtable slot `0x86C8C8`) = validate + type compare only (10010/1016/10017: `typed-world-dispatch-cp23.md`).

Binja 2026-11-06, read back: `sub_7404be` → `CMsgEntityAction__Parse` + function comment; function comment `CNetMsg__ProcessMsg`; instruction comments `0x6DEC3A`, `0x758B92`, `0x6EB436`.

## Variable counts

| Type | Count | Loop | Bound |
|---|---|---|---|
| 10017 | +8 | `i < count` signed, `0x758B92` (also `0x75745D` entry test) | none. Entry `i` spans `12+20i..+19`; i ≤ 49 inside buffer, i ≥ 50 reads past it. count ≤ 0 → no entries. |
| 1009/5 | +20 | `i < count` unsigned, `0x6EB436` (entry test `0x6EB36F`) | none. List at +0x54; i ≤ 234 inside buffer. Order: FindItemByUid(+4) → unknown = no-op; RemoveItemByUid; loop; TrackItemAtPosition(+8). |

Entries past the packet but inside the buffer are zero: 10017 → attribute 0 value 0 (current life 0) on the target; 1009/5 → UID 0 lookup.

## Walk 10005 target

`CMsgEntityAction__Process` `0x7405E7`: no entity check in parse. Unresolved non-hero id → sends `CMsgAction` 0x66 query (`0x740730`). Entity 0 is not rejected.

## Inventory (managed world ingress, OCC `b95ac833`)

| # | Site | Managed | Native | Slice |
|---|---|---|---|---|
| F1 | `GameSecuredFrameDecoder` frame 4..0x400 | close | receive buffer 0x400; size 0 stalls loop | retained: transport framing |
| P1 | dispatcher header ≠ length | throw | cannot occur after transport | a: invariant |
| P2 | dispatcher size > 0x400 | (transport) | drop `0x6DF3D8` | a: drop |
| P3 | 10005 exact 24 | close | zero-extend | a |
| P4 | 10005 entity 0 | close | accepted; non-hero → query | a: accept, non-hero unhandled |
| P5 | 10010 exact 38 | close | zero-extend | a |
| P6 | 10010 +37 string count ≠ 0 | close | string list per subtype; 108 never reads it | a: accept |
| P7 | 1008 exact 68 | close | zero-extend | a |
| P8 | 1009 < 14 | close | zero-extend | a |
| P9 | 1009 consumed subtype needs `88+4n` | close | zero-extend | a |
| P10 | 1009/46 exact 88 | close | zero-extend | a |
| P11 | 1009/5 count > list room | close | unbounded unsigned loop | a: min(count, 235) |
| P12 | 10017 exact `12+20n`, count = n | close | unbounded signed loop | a: count ≤ 0 → 0, else min(count, 50) |
| P13 | 1016 exact 20 | close | zero-extend | a |
| H1 | walk destination outside u16 | close | XTEA tile + delta → `Role_UpdateCoordinateGateAndMapFromTilePair` | b |
| H2 | 108 non-hero / nonzero other fields | close | reads +4 hero check, +24/+26 | b |
| H3 | 1016 kind/intensity/direction range | close | signed validate + normalize | b |
| H4 | 1008 UID or type 0 | close | unread | b |
| H5 | 1008 inventory > 40 | close | unread | b |
| H6 | correction tile outside map | close | unread | b |
| H7 | equipped type missing from item table | close | unread | b |
| B1 | world-entry bootstrap sequence/ack | close | no sequencing in native receive | c |

## Decisions (D2)

| ID | Rule | Kind |
|---|---|---|
| D2.1 | Native tolerance is the default (issue #240). | decided |
| D2.2 | Counts past the 0x400 buffer stop at the buffer edge (10017 i ≤ 49, 1009/5 i ≤ 234). Native reads past its allocation there; not mirrored. | forced deviation |
| D2.3 | Unknown/unsupported types keep a one-time diagnostic line. Native is silent. Logging only. | managed addition |
| D2.4 | Bootstrap keeps exact `GameWorldAction10010.TryRead` until slice c. | deferred |
