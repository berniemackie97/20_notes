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
| H1 | walk destination outside u16 | close | XTEA tile + delta → `Role_UpdateCoordinateGateAndMapFromTilePair` | c |
| H2 | 108 non-hero / nonzero other fields | close | reads +4 hero check, +24/+26 | b |
| H3 | 1016 kind/intensity/direction range | close | signed validate + normalize | b |
| H4 | 1008 UID or type 0 | close | unread | b |
| H5 | 1008 inventory > 40 | close | unread | b |
| H6 | correction tile outside map | close | no bounds rule; see H1/H6 below | c |
| H7 | equipped type missing from item table | close | unread | b |
| B1 | world-entry bootstrap sequence/ack | close | no sequencing in native receive | d |

## Handler checks (CP2.4b)

| # | Native | Address | Result |
|---|---|---|---|
| H2 | 108: role resolved from +4 (common gate, `0x6FF15D..0x6FF18A`, include hero); unresolved → exit `0x700974`; resolved but not hero (`+0xCC` compare `0x6FFCBF..0x6FFCD0`) → exit `0x700974`. Reads only +0x18 / +0x1A (`0x6FFCEC` / `0x6FFCF3`, u16). Then tile set, `Role_UpdateCoordinateGateAndMapFromTilePair` `0x6FFD31`, reply action 0x92 (146) `0x6FFD80`, auto-run re-path. | `CMsgAction__Process` | non-hero = silent no-op; +8/+12/+22/+28/+32/+36/+37 ignored |
| H3 | `CMsgWeatherUpdate__ValidateAndNormalize` `0x7606CD`: signed kind 1..11, intensity 0..1022, direction 0..359; reject → Process no-op. Kind 6: table `0x7607B2` entry 6 = `0x7607A9` (return 0). | `0x7606D6..0x760711`, table read from PE | out-of-range or kind 6 = silent no-op. Old "kind 6 unassigned" claim wrong; Binja comment corrected. |
| H4 | 1008 kinds 1/2/4 build a `CItem`; `sub_67ad6b` `0x67AD6B` returns 0 for UID 0, type 0 or `ItemTypeData` miss (`0x679197..0x6791C6`, logs "Read Error in ItemType.dat"). Failure → release, return. Kind 3: `FindItemByUid` miss → skip; type change re-runs `0x67AD6B`, fail → skip (`0x763608..0x763617`). | `0x762DF5`, `0x76311C`, `0x763610` | skip, no close |
| H5 | `CHeroItem__TryAddInventoryItem`: count ≥ 40 and not arrow → 0 (`0x6D935F..0x6D936B`); UID already in inventory (`FindItemByUid(...,1)` = inventory only) → 0 (`0x6D938A..0x6D9399`). 1008 kind 1 placement 0 on 0 → release, no post (`0x763048`). | | skip; arrows exempt from 40 |
| H5b | 1008 kind 3 placement: `FindItemByUid(...,1)` at `0x7637F8` (inventory only). Inventory item → fields only, +0x12 ignored. Tracked item → `CHeroItem__TrackItemAtPosition(+0x12)` `0x763867`. That function accepts 1..18 (`0x6DB042`) / 21..29 (`0x6DB050`), else no-op; it adds a key without removing the old one; 10..18 → `SetEquipSlot`, others re-set active slots holding the item. | | managed: inventory update in place; tracked moves only to an accepted position; one location per UID kept (native duplicate reference not copied) |
| H5a | Arrow `CItem_IsArrow` `0x5681F9`: category 0 and subtype 50000. Category 0 ⇔ `id%10⁷/10⁵ == 10` (`0x67AF1A`, branch `0x67B049`); subtype for that family = `id%10⁵/10⁴*10⁴` (`0x67B0B3`). Special groups (≥123) cannot occur in that family. | | `id%10⁷/10⁵==10 && id%10⁵/10⁴==5` |
| H7 | Follows from H4: an item whose type has no `ItemType.dat` row is never created, so no equipped item can miss the table. | | skip at 1008; stat-resolution throw unreachable |
| H1/H6 | No range rule: walk hero ack adds the table delta to the XTEA tile (`0x7406C9..0x7406E3`); correction sets the u16 tile. `Role_UpdateCoordinateGateAndMapFromTilePair` stores int32 tiles (`XteaProtectedInt_Set` `0x65CB3A`/`0x65CB49`); `CGameMap_UpdateTileRegionFlagsAndAmbientMedia` does region lookups only. `GetCell` `0x61D9C8`: x/y outside `[0,width)`/`[0,height)` (+0x2C/+0x30) → NULL. Camera `0x61E0E7` (all callers `0x5ACB4A`/`0x63C85A`/`0x6FF855` pass clamp 1) clamps the projection centre to ground-layer bitmap extents — managed `WorldCameraProjection` already clamps to ground-puzzle bounds. Role draw order, cell altitude for NULL cells and int tile state **unproven** — slice c. | | c |

Cross-repo: native replies 146 to every applied 108 (`0x6FFD80`); OCS already accepts 146 as a position report (`GamePositionReport.CorrectionReplyAction`). OCC sends no 146 — parity gap, not tolerance.

### CP2.4b resumed audit — item object identity

Read-only native/source revalidation at OCC `906e25d3` found three errors in the
unfinished handler rewrite. Native kind 1 allocates a fresh `CItem`
(`0x762D84/0x762D9C`), even when a UID matches an older object. Kind 3 mutates
the located object, then always tracks an accepted position (`0x763867`).
Tracking compares active **pointers**, not UIDs (`0x6DB0C0`), and refreshes the
same object (`0x6DB0E7`); positions 10..18 set the active slot (`0x6DB0A7`).

Therefore retain active references on ordinary/alternate placement updates,
re-track even unchanged accepted positions so special slots can reactivate, and
keep a fresh Add distinct from an old active object sharing its UID. Use a
world-owned item reference with in-place mutable stats; this is model identity,
with no renderer or content-I/O responsibility. The Track function comment was
extended and read back before implementation. No BNDB save.

Native older-key retention and inventory/tracked UID overlap remain outside
this slice's one-location store. Do not claim complete item ownership parity.
Tracked as OCC #264; missing correction reply 146 is OCC #263. Existing
two-handed displacement remains #262. Raw excerpts and the weather kind-6
table target are byte-verified against clean SHA in
`evidence/handler-tolerance-2026-11-06/`; no native execution is claimed.

## Decisions (D2)

| ID | Rule | Kind |
|---|---|---|
| D2.1 | Native tolerance is the default (issue #240). | decided |
| D2.2 | Counts past the 0x400 buffer stop at the buffer edge (10017 i ≤ 49, 1009/5 i ≤ 234). Native reads past its allocation there; not mirrored. | forced deviation |
| D2.3 | Unknown/unsupported types keep a one-time diagnostic line. Native is silent. Logging only. | managed addition |
| D2.4 | Bootstrap uses native message-buffer decoding as of OCC #267. | resolved |

Binja CP2.4b, read back: comments `0x7606CD` (kind-6 correction), `0x6FFCD0`, `0x762DFC`, `0x763617`, `0x7637F8`, `0x6D936B`, `0x6D9399`; function comment `CHeroItem__TrackItemAtPosition`; `sub_67ad6b` → `CItem_InitIdentityFromItemType` + function comment.

## CP2.4b validation and review boundary

OCC #265, commit `d8f159a6`, is pushed and ready for Bernie review. SDK10.0.403
locked restore, zero-warning/error Release build, format verify and 2,919 focused
tests pass (Client1,584, +37; Content750; Rendering499; Platform86). Native-derived
golden inputs and encoded sequences distinguish fresh/add versus update identity,
placement, capacity/arrow, missing type and ignored-message continuation. No
running-client or native-runtime comparison claimed.

CI run1010 passed Linux Quality, Windows and macOS; dependency review passed.
Private retail-content gates were conditionally skipped. Source/reference and
ownership/lifecycle self-audit found no remaining findings for this bounded slice.
Local client branch is clean/synced; GitHub #240 and both master trackers stay open.
H1/H6 are CP2.4c; B1 is CP2.4d. BNDB remains unsaved by the agent.

CP2.4c native preflight now resolves the old H1/H6 unknowns in
`off-map-tiles-cp24c.md`: screen-only registration and ordinary scenery depth
ordering, signed/wrapping coordinates, and zero NULL-cell terrain contribution
traced to the actual render operand. No universal zero-height claim or new motion
feature follows from those facts.

## CP2.4 acceptance — 2026-11-07

OCC #240 closed at OCC `11a7a1c1` and OCS `18fe9926` (OCS #209,
closes #208). The 1,641 client tests passed on merged main. The PR CI
runs for #270 and #209 passed. The retail VM probe covers #207, with the
later heartbeat echo covered by secured-session tests.

F1 remains the 4–1024 byte secured-frame boundary. P1–P13 and H1–H7 are
covered by the codec and handler slices above and the CP2.4c evidence.
B1 is covered by `bootstrap-tolerance-cp24d.md`. The client retains the
74 reply, 1110 and statistics request as readiness requirements, an
authenticated hero ID, bounded hydration and deadlines. These are
managed lifecycle and safety rules. Counts stop at the copy boundary
(D2.2). Unknown dispatch and native no-op fields can pass without a
protocol disconnect. Remote role resolution, later map transfers, and
the parked item and correction features remain separate.
