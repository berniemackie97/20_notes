# MsgAction 0x61 — syndicate bootstrap, native 5517

Verified 2026-10-05. Documentation/evidence only; no production changes.

## Conclusion

**Recovered native enum name: `actionGetSynAttr` (`0x61`, decimal 97), the
syndicate-attributes bootstrap request.** The name occurs in the executable's
own assertion, not just a private-server enum. Receiving the `0x4E` completion
causes the client to send `10010/0x61` with its local hero ID. Receiving
`10010/0x61` with a resolvable entity ID causes it to send **`10010/0xFB`
(251), the silent-info checksum/version report**. It does not finish login.

The client proves that this action acknowledgement advances the ladder, but
does **not** prove the retail server's exact preceding packet burst, database
queries, or ordering. Packet `1106` independently updates syndicate attributes;
the `0x61` completion path does not count or require those updates. No
attributes followed by the acknowledgement is sufficient to advance an empty
membership bootstrap. It does not clear existing syndicate state.

Authority: clean `5517/Conquer.exe`, SHA-256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`,
5,880,840 bytes. This is **5517 evidence**; no 5518 executable was examined.
Function names other than recovered assertion text are analyst labels.

## Native evidence

| Native address / function | Observed instructions and implication |
| --- | --- |
| `CNetMsg__ProcessMsg_Dispatch` `0x6DF3B5`, branch `0x6E130B`, constructor call `0x6E1326` | Packet type `10010` allocates a `0x414`-byte CMsgAction object; its parser is called through the vtable. |
| `CMsgAction_ParseType10010_Analyst` `0x6FEB93` | Common header/copy validator `0x6DF2AE`, then type-word comparison with `10010`. No 38-byte minimum check here. |
| `CMsgAction__Process` `0x6FED1F`, `0x6FF15D..0x6FF18A` | Loads packet `+4` and resolves it via `EntityRef_ResolveByIdOrLocalHero` `0x6E847D`, includeLocalHero=1. Unresolved IDs exit at `0x700974` for `0x4E`, `0x61`, and `0xFB`. |
| `0x6FF283..0x6FF2EB` | Received `0x4E`: calls context helper `0x67E32D`, constructs message, reads `CHero+0xCC`, pushes action `0x61` at `0x6FF2AA`, calls Create at `0x6FF2B6`, Send at `0x6FF2E6`. |
| Literal `0x946000`, referenced by the failure assertion after that Create | `msg.Create(g_objHero.GetID(), 0, 0, 0, actionGetSynAttr)` recovers the source enum spelling. Source path at `0x94603C`: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\MsgAction.cpp`. |
| `0x6FF5B3..0x6FF5D0` | Subtraction cascade selects `0x61`: subtract `0x51`, `5`, `6`, `4`, then decrement. Matching branch starts at `0x6FF5D6`. |
| `0x6FF5D6..0x6FF625` | Obtains CSilentInfo via `0x4105E4`, reads version with `0x6BB3AC`, checksum with shared getter `0x6C4108`, builds report using `0x6FEC2D` at `0x6FF607`, sends at `0x6FF616`. |
| `CMsgSyndicateAttributeInfo1106__Process` `0x76090F` | Independent syndicate-state/UI update. It is not the action-61 completion branch and does not send its follow-up report. |
| `0x7008EA..0x700949` | Received `0xFB`, after the same entity gate: Create at `0x700914`, Send at `0x700944`, action `0x84`. Literal `0x945E48` recovers `actionGetStatistic`. |

The pre-request context helper `0x67E32D` writes context byte `+4=1`, resets
the helper objects at `+0x10/+0x1C`, and writes timeGetTime at `+0x0C`.
That is not a guild-membership or magic-row-count test. The `0x4E` completion
message itself drives the request; the magic protocol was not re-opened.

## Wire/request behavior

`CMsgAction__Create` at `0x6FE95F` is a thiscall builder (ECX=this, six stack
arguments, `ret 0x18`): `(u32 entity, u16 x, u16 y, u16 direction, u16 action,
u32 parameter)`. Narrow arguments still occupy four-byte x86 stack slots.
The action-61 call supplies `(heroId, 0, 0, 0, 0x61, 0)`.
It rejects entity zero without resetting/writing; otherwise it resets the
packet storage and emits this little-endian **38-byte** frame:

| Packet offset | Width | Client request `0x61` |
| ---: | ---: | --- |
| `+0` | u16 | `38` (`0x26`) |
| `+2` | u16 | `10010` (`0x271A`) |
| `+4` | u32 | Local hero ID, `CHero+0xCC` |
| `+8` | u32 | Parameter = 0 |
| `+12` | u32 | Action parameter = 0 |
| `+16` | u32 | Current `timeGetTime`, helper `0x768FEB` |
| `+20` | u16 | Action = `0x61` |
| `+22` | u16 | Direction = 0 |
| `+24`, `+26` | u16 each | X=0, Y=0; not the hero's map position |
| `+28`, `+32` | u32 each | Data1=0, Data2=0 |
| `+36`, `+37` | u8 each | Flag=0, string count=0 |

The normal eight-byte game-transport signature is outside the header length;
it is not part of this 38-byte MsgAction body. There is no action-61-specific
extra payload, coordinate use, timestamp equality test, or string list.

**Reply consumption:** after parsing, Process reads only `+20:u16` (action)
and `+4:u32` (entity) on the `0x61` route. `+16` is ignored: no preserved or
echoed timestamp is required by the client. Parameters, coordinates, direction,
data1/data2, flag and string count are likewise ignored on that route.
Echoing the canonical request is sufficient for this rung.

**Entity gate precision:** the resolver accepts the local hero **or** a matching
role already in `g_objPlayerSet` (`0x96B018`, role collection at `+0x14`, IDs at
role `+0xCC`). This is not an exact-local-hero-only check. Use the authenticated
hero's ID for bootstrap responses. Validating that request `+4` equals the
authenticated character is sound server policy, not recovered retail-server
validation. Zero or unknown reply IDs do not advance a logged-in client.

**Parser boundary:** `0x6DF2C7` compares `si` with `ax`, i.e.
`low16(callerSize)==headerSize`; it also requires a non-null buffer and nonzero
type before copying. The subclass then checks type 10010. There is no local
38-byte minimum/equality check. The dispatcher has an upstream signed
`size > 0x400` rejection. Replay accepts matching-header sizes 4, 8, 22, 38,
39 and 92 at this parser boundary; this does **not** make undersized frames
appropriate server encodings. Emit the proven 38-byte bootstrap frame.

## Server completion behavior

**Direct native facts:** the `0x61` acknowledgement is the completion signal
for this ladder edge. `1106` alone does not execute that edge. There is no
row count, end-of-list marker in `1106`, guild-membership predicate, or recorded
receipt dependency in the `0x61` branch. No attribute packets followed by a
valid action-61 acknowledgement advances the client; repeated valid
acknowledgements repeat the report. An acknowledgement alone does not reset
previous guild state.

Packet `1106` can provide the local hero's syndicate attributes. Its parser
`0x7608EC` checks the shared header and type, not an exact 92-byte length.
The packed consumer at `0x76090F` reads:

| Offset (decimal) | Native width/use |
| ---: | --- |
| 4, 8 | u32 syndicate ID, u32 member proffer |
| 12 | u64 silver fund (low/high dword loads) |
| 20, 24, 28 | u32 emoney fund, population, member rank |
| 32 | Pointer to NUL-terminated leader name |
| 48, 52, 56 | u32 required level, rebirth, profession |
| 60, 61 | u8 syndicate level, u16 mantle |
| 63, 67 | u32 position-expiration date, join date |
| 71 | u32 stored at hero `+0x1284`; business meaning unproven |
| 75 | Pointer to NUL-terminated syndicate name |

The zero-ID path first calls `0x6E98FC` to clear all syndicate statuses and
`0x66563D` to clear extended hero syndicate state. Both zero and nonzero paths
then apply **all** fields, including ID. A nonzero ID is marked status 2 via
`0x6E98BB`. The handler posts UI command `0x40A`; rank changes can also post it
through `0x660961`. This is separate from bootstrap completion.

**Length correction:** setters `0x6730E4` and `0x675A69` call `strlen`.
The 16-byte leader-name span is bounded structurally by the next field at 48,
but the read itself is not bounded to 16. Native reads the terminal name from
75 until NUL; this does not prove a fixed 17-byte terminal field or a unique
92-byte retail encoding. A zero-padded 92-byte encoding with 16/17-byte name
spans is compatible and used by the local reconstruction. Keep its bounded
name rules as server encoding policy, not a recovered parser restriction.

**Evidence limit:** without retail server code or a retail capture, the exact
number/order of guild attributes, announcements, relations, family packets,
or other ancillary packets is **not established**. Nothing here promotes
Fox or Long's burst to the 5517 retail contract. Confidence is high that
`1106` is the appropriate attribute-update packet and that the action-61
acknowledgement advances the client. Sending the desired snapshot before the
acknowledgement is an explicit server ordering policy, not an observed retail
wire trace. An explicit zero-ID `1106` is available when clearing old state is
desired; native does not require one just to advance empty membership.

## Next bootstrap transition

The next client request is **10010 / `0xFB`**, emitted by
`CMsgAction__BuildSilentInfoReport251` (`0x6FEC2D`):

| Field | Value |
| --- | --- |
| Size/type/action | 38 / 10010 / `0xFB` |
| Entity `+4` | **0** |
| Parameter `+8` | CSilentInfo `+4`, the loaded silent-data checksum |
| `+16` | Silent-data **version**, not a timestamp |
| Other body fields | 0 after reset |

The loader `0x6BB413` reads **`ini/Slient.dat`**, calculates/stores the checksum
using `0x6BB1E2`. The version reader `0x6BB3AC` opens
**`ini/SlientVersion.ini`**, parses text with `atoi`, and returns 1 if open
fails. Preserve the native misspelling; `silent.dat` is a different file.
The inspected clean fixture has an empty `slient.dat` and no SlientVersion.ini,
consistent with checksum 0 / version 1 after ordinary loading. This is
file-derived evidence, not a live socket capture or a constant for all clients.

The next server state can be named **`AwaitingSilentInfoReportConnection`**
(proposed application name, not a recovered native type). Do not label this
edge login-complete. One further boundary is proven: receiving `0xFB` with a
resolvable ID sends `0x84 actionGetStatistic`. The client-originated `0xFB`
has ID zero; a blind zero-ID echo **does not pass** the common resolver and
therefore does not send `0x84`. Use the local hero ID in that subsequent
completion response. Do not apply the action-61 request's nonzero-ID
expectation to the action-FB request.

## Bootstrap versus gameplay reuse

The census covers **80 direct callsites in 57 caller functions**, across all
seven captured CMsgAction builders: `0x6FE95F`, `0x6FE9F3`, `0x6FEAD0`,
`0x6FEBB6`, `0x6FEC2D`, `0x6FEC6E`, `0x6FECE4`. Every direct xref matches a
raw executable E8 call. Only `0x6FF2B6` constructs action 61; it is the
received-4E path. The two randomized movement-report senders choose from
`7F/81/83/85/88/8B/8D/8E/90/96`, not 61. The report includes the obfuscated
sender's real instruction stream, not the decoy block boundary.

**Conclusion within this census:** bootstrap origin only; no independent
gameplay emitter identified. Do not promote this to a formal whole-program
absence proof for arbitrary indirect/manual packet construction. The receiver
has no one-shot/connection-phase guard; replayed acknowledgements can trigger
the same response again. That repeatability is not evidence of a separate
gameplay meaning.

## Cross-checks (supporting only)

| Local source | Name / behavior | Comparison with native 5517 |
| --- | --- | --- |
| OpenConquerPublic, `50_server/OpenConquerPublic` | `GetSyndicateAttributes=97`; membership sends 1106 then action echo; absent membership sends echo. | Agrees with a compatible attribute bootstrap policy. Its `SilentInfoReportActionHandler` replies using `EncodeSilentInfoReport`, which hardcodes entity zero. That subsequent reply conflicts with the native resolver gate; code intentionally unchanged. |
| FoxConquer5517 | `CONFIRM_GUILD=97`; loads guild and family; guild announcement then 1106, name/relations and optional additional updates, finally echoes 61. | Corroborates syndicate meaning and acknowledgement. Extra burst is Fox policy, not proven retail order. |
| LongV6270 | `LoginGuild=97` echoes; `LoginComplete=251` runs login-complete modules, including syndicate loading. | Later implementation distributes guild work differently. Its 251 name must not replace native 5517's observed silent-info report and follow-up 84. |
| Albetros | `GetSynAttr=97`; branch sends guild information and other login effects, without an explicit action-61 echo in that branch. | Corroborates terminology; that branch is not evidence that native 5517 can omit its acknowledgement. |

`crosschecks.json` retains exact paths, source hashes, line ranges and excerpts.
Private source names never override the recovered native assertion or wire
instructions. The newer DotNet projects are separate checkouts; documentation
changes here target the local reverse-engineering workspace only.

## Implementation contract (documentation only)

1. **AwaitingSyndicateAttributesConnection** (suggested server state): receive
   normal 38-byte `10010/0x61`; validate framing, expected state, and that its
   entity ID belongs to the authenticated character. These server checks are
   policy. Canonical coordinates/data are zero; no timestamp matching needed.
2. If the character belongs to a syndicate, load and send its attribute
   snapshot as `1106`. Snapshot source and sending it before completion are
   server policy. The client does not mandate Fox's ancillary burst.
3. With empty membership, no attribute packet is required to advance. If
   clearing existing guild state, send a suitable zero-ID 1106 snapshot.
4. Send a 38-byte `10010/0x61` acknowledgement with local hero ID. Echoing the
   canonical request is sufficient; preserving its timestamp is optional for
   this native consumer.
5. Enter **AwaitingSilentInfoReportConnection**: expect `10010/0xFB` with
   entity zero, checksum at 8 and version at 16. It is not login-complete.
   The subsequent FB response needs a resolvable hero ID to produce the proven
   next request `0x84 actionGetStatistic`.

## Verification and limits

The evidence bundle retains raw BN ASM/HLIL/MLIL, builder xrefs and action
values, source provenance, native assertion bytes, restorable annotation
changes, deterministic x86 replay, and validation results. Instruction bytes
are compared with the clean PE. Replay executes the original Process and
builder instructions with explicitly recorded object/OS/transport boundaries;
it is not an independent managed reimplementation and not a live Windows login.

Replay covers 37 Process cases (4E/61/FB, local/known-remote/zero/unknown ID,
zero/55/FF ignored-field fills, repeated 61), three builder cases, and eight
parser cases. It verifies next actions, exact output bytes, packet-read offsets,
and rejection of unresolved IDs. The entity resolver itself is separately
captured native evidence, while its returned object is controlled in replay.
No retail-server order or 5518 binary compatibility is claimed.

Evidence bundle: [README and validation](../../10_work/docs/evidence/msgaction-0061-bootstrap-5517/README.md).
