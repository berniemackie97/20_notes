# Historical TQ 15.10 character-creation decision path

Verified 2026-10-30 from the existing `50_server/binaries/_re/MsgServer.exe.i64`.
Executable SHA-256: `48749fc1ede8783eae5d97bf3d025143609bfbdbd0362a49888194e749caf726`.
This is a delta to `20_notes.zip`, SHA-256 `c950f088daac9c824c6e0c57ec2721a411c6e7f25f5ed326bee1c67a0e59ef95`.
It adds the server decision path only; established starting attributes, appearance, spawn, and client bootstrap are not repeated.
**Every server behavior below is historical 15.10 evidence. None establishes a 5517 server contract.**

## Result

The recovered socket path reaches `CMsgRegister__ProcessCharacterCreation_15_10` (`0x4B0B17`).
It checks text syntax and name filters, then calls `CUserList__CreateNewUser` (`0x4AA79A`).
That routine performs one `INSERT cq_user`; it does not first query name uniqueness, account ownership,
or an existing character for the account. Every false return becomes the same duplicate-name refusal.
Success attempts a client `ANSWER_OK` reply before an AccountServer notice. There is no compensating deletion
or rollback after either notification on this path.

## Acceptance and refusal, in execution order

Offsets below are relative to the request **body**, excluding the four-byte packet header.
The message constructor sets its body pointer to object `+0xC`; the handler reads it through object `+0x41C`.
These are historical server operands, not a claim that the retail 5517 client has this extended wire layout.

| Order | Native condition | Result if rejected |
|---|---|---|
| 1 | `ValidateLegacyTextBytes(body+0, 0)` at `0x4B0B35` | resource key `STR_ERROR_ILLEGAL_ACCOUNT` |
| 2 | Same validator on `body+32` at `0x4B0BE4` | `STR_ERROR_ILLEGAL_PASSWORD` |
| 3 | `ValidateCharacterNameSyntaxAndReservedWords(body+16)` at `0x4B0CB2`; then kernel unlawful-name rule matcher `0x4A79F7` | `STR_ERROR_ILLEGAL_NAME` |
| 4 | `CreateNewUser` must find map 1010 and accept requested body value, at `0x4AA7B7..0x4AA7E6` | `STR_ERROR_DUPLICATE_NAME` |
| 5 | The single SQL execution must return true, at `0x4AA91A` | `STR_ERROR_DUPLICATE_NAME` |
| 6 | True result at `0x4B0CE9` | attempt `ANSWER_OK`, then AccountServer notice |

The call at `0x4B0CE9` passes account/name/password pointers at body `+0/+16/+32`,
unsigned 16-bit body/profession values at `+48/+50`, and unsigned 32-bit account ID at `+52`.
The SQL uses this **request-supplied numeric account ID** and name. The account/password string arguments
are not read by `CreateNewUser` itself; the preceding checks validate byte syntax, not authentication.

The body allowlist is exactly `1003, 1004, 2001, 2002`. Invalid bodies fail before SQL.
**Profession is normalized, not rejected:** `10, 40, 50, 100` retain their respective branches;
zero and every other value become `20` (`0x4AA7FA`, `0x4AA843`). This corrects the earlier IDA description
that called the profession handling validation. Attribute values remain in the existing runtime-semantics note.

## Name uniqueness and session/account ownership

There is no name-availability SELECT or in-memory uniqueness lookup in the recovered handler/create chain.
The SQL is a plain INSERT, with no IGNORE, REPLACE, or ON DUPLICATE KEY clause.
A database uniqueness constraint can reject it, but the native wrapper does not classify that error.
Missing map, invalid body, absent DB connection, and any query failure all produce the same refusal key.
Thus **a duplicate-name message does not prove a name collision**.

The packaged schema's unique-name/nonunique-account-index evidence remains in the existing provenance notes;
it is not newly established here and is not proof of the deployed database or its collation.
The earlier topology note's first-row account lookup describes loading, not an enforced one-character-per-account invariant.
No native creation-time check enforcing that invariant appears in this path.

The upstream chain was followed beyond the handler:

- Socket acceptance `0x4A18C3` assigns routing group 2 (`0x4A1962`, `0x4A1A0B`).
- Receive `0x4A12AB` frames the packet with `0x4A1F08`, then posts internal event 1001 to that group at `0x4A1650`.
  This internal event number is separate from the incoming packet's type 1001.
- Kernel pump `0x4A4DBC` dispatches that event to `0x4A5B65` at `0x4A4EF8`.
- `0x4A5B65` creates the socket-bound message through `0x4AF377` and calls its process virtual slot `+0xC`.
  The packet factory `0x4AF500` selects the registration constructor `0x4B0A8D` for type 1001.
- `0x4AF377` records socket routing and zero user ID, then directly calls base body-copy parser `0x48C396`.
  It does not invoke a specialized registration authorization gate.
- Replies through `0x4AF335` use socket index when present, otherwise user ID. Routing the reply is not an ownership check.

In that recovered fresh-socket route, no comparison binds body account ID to an authenticated session,
no account-string-to-ID resolution occurs, and no password proof is checked before insertion.
This is a bounded static claim about the identified path. External admission controls and other deployments remain outside the evidence.
It is not a runtime demonstration or a statement about 5517 server behavior.

## Invalid text and malformed requests

`0x4B22B2` rejects a null pointer, bytes below `0x20` in single-byte positions, byte `0x80`,
and a final unpaired lead byte in `0x81..0xFE`. Such lead bytes consume the following byte without
validating that trail byte. Byte `0xFF` is treated as a single byte. An empty string passes.
There is no minimum or maximum string-length check in this validator.

`0x4B232B` first rejects every byte below `0x20` and the ASCII bytes
`20 22 25 27 2C 2F 3B 3D 40 5B 5C 5D` (hex).
It then checks an exact reserved literal, case-sensitive reserved substrings,
and, after `_strupr`, the substrings `GM`, `PM`, `SYSTEM`, `NPC`, `GUARD`, `PATROL`, `NONE`.
The tail `0x4B2806` checks seven more literals before calling the common byte validator.
The complete 51 literal operands, match types, exact bytes, and addresses are preserved in
[name-literals-exact.json](evidence/preworld-creation-15.10-2026-10-30/name-literals-exact.json).
Hex bytes are authoritative. Some IDA labels display only `G` or resemble pointers; their full literal bytes differ.

The second name check `0x4A79F7` copies with capacity 16, lowercases, and evaluates loaded rule groups.
A group rejects when all its token substrings match; an empty group also matches.
The loader `0x4A789F` reads `select word from cq_unlawful`, splits each row on `_`, and lowercases tokens.
Actual loaded dictionary rows and locale-dependent case conversion are not established here.
With no matching configured rule, an empty name passes the recovered native syntax checks;
subsequent SQL constraints can still reject it.

Framing `0x4A1F08` accepts declared lengths 4..1024, waits for the full frame, and conditionally verifies
an eight-byte `TQClient` trailer. Kernel dispatch requires a nonempty body and caps it at 1024.
Neither the socket message factory/base copy nor the registration handler enforces a registration-specific
fixed size or NUL termination inside each nominal string field. The constructor clears its 1024-byte body
before copying, so a short request can leave later fields zero rather than automatically causing a size refusal.
The validators use `strlen`, and name checking later uses `strcpy` into a 256-byte local buffer.
These observations establish missing local bounds checks; no malformed-packet runtime test or exploit claim is made.
Frames rejected before the handler do not acquire one of its semantic refusal messages; framing errors use socket closure in receive.

## Result messages and ordering

All handler refusal branches attempt one `CMsgTalk` response, from `SYSTEM` to `ALLUSERS`, color `0xFFFFFF`,
channel `2100`, using the resource key in the decision table. Sending occurs only if talk construction succeeds.
No additional refusal packet, automatic retry, or disconnect is issued by this handler.
The exact loaded translation is configuration-dependent. The supplied modified ZFSERVER resource file contains:

| Key | Packaged resource value |
|---|---|
| `STR_ERROR_ILLEGAL_ACCOUNT` | `Error> Invalid accountID!` |
| `STR_ERROR_ILLEGAL_PASSWORD` | `Error> Invalid password!` |
| `STR_ERROR_ILLEGAL_NAME` | `Error> UNallowed/invalid characters in name!` |
| `STR_ERROR_DUPLICATE_NAME` | `Error> This name already exist.` |

These are recoverable package strings, not proof of the original 15.10 production translation.
The file hash and source lines are in [packaged-response-text.json](evidence/preworld-creation-15.10-2026-10-30/packaged-response-text.json).

On successful SQL return:

1. Construct literal `ANSWER_OK` with the same talk parameters at `0x4B0D29`; send at `0x4B0D3D` if construction succeeds.
2. With kernel available, call `CWorldKernel__SendCharacterCreatedNotice1100` at `0x4B0D63`, using account ID `body+52`
   and string `body+56`. The pointer non-null test is not a nonempty-string or ownership check.
3. `0x4A618C` constructs a 52-byte notice: WORD length 52, WORD type 1100, DWORD account ID,
   then a string copied with capacity 41. It issues the send through the kernel's AccountServer link at `+0x60` (`0x4A61C6`).

The notice is attempted even if talk construction failed, and the handler does not test the talk send result.
This proves **call order**, not delivery order across the client and AccountServer sockets.
No server bootstrap or world-admission sequence beyond this handler is newly claimed.

## Persistence failure and partial-state boundary

The kernel database getter slot `+0x14` resolves to `0x4A5AD3`; the database vtable at `0x4EE274`
resolves slot `+0xC` to `CMyDatabase__ExecuteSQL` (`0x4B5227`).
The wrapper's SQL guard `0x4B4CA4` imposes UPDATE/DELETE safeguards; the INSERT passes that guard.
An unavailable thread connection returns false and records error 1003. A nonzero `mysql_query` result
at `0x4B532F` records error 1004, logs the SQL, and returns false. Zero returns true.
It does not inspect affected rows or distinguish a duplicate-key error from other query errors.
The exception path also returns failure. All such false results feed the generic duplicate-name response.

There is only **one native persistence operation** in this creation path. No later inventory, secondary-row,
or staged-character write can be identified here. No explicit transaction, commit, rollback, or compensating
DELETE surrounds it. Therefore:

- Rejections before the INSERT do not persist a character through this path.
- After a successful INSERT return, notification failure does not remove the inserted row.
  The client can miss success while the database has accepted the character. This is an unacknowledged insert,
  not evidence of a half-built multi-stage character.
- A false query return cannot, from this code alone, certify that no database change occurred.
  A transport failure after SQL execution, server engine behavior, triggers, and transaction/commit settings
  are outside the recovered native wrapper. No fault-injection run was made.
- Consequently, **absence of partially persisted state under every failure is not certified**.
  The recovered code establishes the single-write design and missing compensation; actual database failure
  atomicity requires the matching deployed schema/engine/settings and a controlled failure observation.

## Evidence and scope

REA attached to the existing IDA database and returned partial raw evidence for `0x4AA79A`:
`ev_37b98095becf106ab9d647c99d6ef75f3a5898d34e8f0feec65582b8d4ae13da`.
Its adapter marked `unreadable_output` because the IDA endpoint returned `code` rather than the expected
normalized pseudocode shape. The raw result is retained in [create-new-user.json](evidence/preworld-creation-15.10-2026-10-30/create-new-user.json).
Further queries used the same installed IDA MCP endpoint on the existing database; no fresh replacement database was analyzed.
This fallback is recorded explicitly and is not represented as successful normalized REA output.

Raw evidence is under [evidence/preworld-creation-15.10-2026-10-30](evidence/preworld-creation-15.10-2026-10-30/):

- `create-handler-asm.json`, `create-asm.json`, `validate-name-asm.json`, `db-execute-asm.json`, `success-notice-asm.json`;
- corresponding decompilations, xrefs, factory/dispatch/socket captures, DB getters/vtables, and exact name literals;
- `byte-validation.json`: all 16 captured byte ranges match the supplied executable, including main routines and vtables;
- `annotations.json`, `annotation-names-after.json`, `annotation-after-*.json`, `annotations-save.json`: six justified function names,
  five instruction comments, readback, and save confirmation in the existing IDA database. A pre-edit database backup is retained in task work.

No server executable was run or patched. This slice makes no implementation changes.
Name/account ownership gaps are resolved as bounded historical native behavior, not upgraded to a security guarantee.
**Still open:** 5517 server parity; actual runtime dictionary/resource choice; deployed uniqueness/collation/account constraints;
database failure atomicity; observed delivery/failure behavior. Client 5517 behavior cannot close those server gaps.
