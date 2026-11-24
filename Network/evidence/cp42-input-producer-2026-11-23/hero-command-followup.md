# Hero command dispatch and packet fields

## Proven scope

This completes the sender/dispatch part of the interrupted investigation.
The held-pointer state machine remains unresolved; it is not an implementation
contract yet. Target identity remains the executable SHA-256 in instructions.json.

The first trace inspected the generic role callback at 0x74353F. The hero uses
vtable 0x86AD08, installed at 0x655730. Slots +0x80 / +0x84 / +0x58 contain
0x65C079 / 0x65C0F5 / 0x64EAB2. These entries are retained alongside the three
existing message-map entries in message-map.json. This corrects two earlier
overgeneralizations: the generic builder is not the local hero builder, and the
remote-role queue does not describe acceptance of local hero target requests.

## Command ownership and dispatch

**Proven.** Hero +0x80 checks the incoming pointer, conditionally commits coordinate
bookkeeping, and calls 0x64DD38. If accepted, that function copies 0x11C bytes into
hero+0x1E8. States 0x20, 0x21 and 0x28 accept only incoming type 0x2F there;
additional branches exist for 0x29, 0x2D and 0x2E. The complete effective-state
getter and all upstream eligibility conditions remain outside this claim.

**Proven.** At 0x67265D the role tick calls +0x58. A true result takes the queue
inspection path and then +0x84 at 0x6726D8. A false result dispatches +0x84 only
when both the command-class test and due-action application succeed. Otherwise
it skips to 0x6726E5. After +0x84, 0x64E2DD restarts action presentation. The
+0x58 function tests frame index against frame count, samples the clock, honors
a positive interval override and computes a rounded frame from elapsed time.
This is a motion-completion boundary, not proof of a fixed input packet timer.

The hero callback at 0x65C0F5 selects the action at 0x65C540 before deciding whether
to emit movement. Its 0x65C517–0x65C5A6 gates include the recent-state suppressor
and a check of role+0x224 for command types 0x11..0x13 and 0x16..0x18. Physical
actions 110/111 choose selector 0; 120/121 choose selector 1. Other branches,
including mounted actions, are not authorized ordinary movement by this note.

## Hero ordinary packet construction

**Proven.** Caller range 0x65C686–0x65C6D9 and builder 0x740457:

| Logical offset | Value | Width written by hero builder |
| --- | --- | --- |
| +0 / +2 | 24 / 10005 | u16 / u16 |
| +4 | role+0x17C + 8*(rand()%31), low byte | byte after packet reset |
| +8 | role+0xCC actor ID | u32 |
| +12 | selector 0 or 1 | byte after packet reset |
| +16 | sampled client milliseconds, helper 0x768FEB | u32 |
| +20 | map singleton getter 0x4F6569, which reads object+0xE0 | u32 |

The map getter is the existing analysis-labelled map identity getter. This trace
proves the field source and width; it does not redefine the complete map
identity/data-ID relationship. The packed byte ranges from 0 to 247 for ordinary
eight-way direction. The two-byte/dword reset behavior remains as recorded in
the first trace.

The builder called here is 0x740457, not 0x740407. The latter was correctly
recorded for the generic role sender but cannot establish omitted hero fields.
The sampled-packet sender fills a zero timestamp before forwarding through
0x6DF355. The transport's explicit timestamp rewrite at 0x6DF118 is gated on
packet 1009/subtype 27, not packet 10005. No new runtime emission is claimed.

## Release and interception boundary

**Proven.** Release handler 0x5DB61E calls 0x76A7AB(x,y,0). That helper stores
the third argument at 0x96B988 and coordinates at 0x96B980/0x96B984, then returns.
It performs no role call or command clear. This proves only that the helper
itself is not a movement-stop routine.

The release handler also calls viewport input 0x6F0E17(0,x,y). That consumer
branches on its active-entry lookup and otherwise calls 0x6F0DD1, which tests
coordinates, updates viewport+0x24, and has release-state/time bookkeeping.
The active-entry callback and the consumers of those viewport fields are
**unresolved**. Do not turn this limited trace into a claim that releasing the
pointer always continues movement, cancels it, or retargets it.

## Validation and analysis state

Raw objdump commands and their output are retained in objdump-transcripts.json.
Normalized instruction rows join the earlier Binary Ninja transcripts in
instructions.json and are checked by the existing verify.py. The jump table
following 0x7405C7 is explicitly excluded from instruction claims.

The Binary Ninja bridge returned connection refused at localhost:9009 during
resumption. The original image was available, so the sender correction was
verified with /usr/bin/objdump and direct PE virtual-address mapping. No new
Binary Ninja names or comments were applied in this follow-up, and no database
save occurred. Earlier live annotations and their disk persistence must be
checked after reconnection. No new REA execution result or interactive capture
is claimed; the existing REA image identity remains applicable to the same hash.

## Exact resume boundary

- **Proven:** generic versus hero builder, hero command acceptance, virtual
  dispatch boundary, ordinary packet field producers, release sample writes.
- **Candidate:** existing analysis names for map identity and command classes
  retain the narrower instruction-level scope above.
- **Unresolved:** repeated pointer/held-state producer, complete HUD routing,
  viewport release consumers, focus loss, correction/transfer interruption and
  client emission cadence against OCS pacing.
- **Next static probe:** reconnect the existing Conquer.exe view and follow
  0x6F0E17 -> 0x6EE36B and 0x6F0DD1; identify readers of viewport+0x24/+0x5C/+0x68.
  The earlier xrefs to sample reader 0x76A7C7 reached UI text hit testing, which
  is not sufficient proof of a movement-hold loop.
- **Next runtime probe:** the controlled single-click/hold/drag/release,
  HUD/focus/correction/transfer matrix already listed in README.md, with
  sanitized logical C→S frames and input timestamps.

No production OCC or OCS code changed. The existing codecs can represent the
proven field values. That compatibility does not establish current server
pacing acceptance or full interactive behavior; OCC #341 stays open.
