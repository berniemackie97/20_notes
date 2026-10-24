# Native 5517 auth string validation and exceptional paths

Evidence delta, 2026-10-18. Targets: 1004, 1006, 2078; compatibility with
AUTH-001N, AUTH-001O and AUTH-001P. Research only; no implementation changes.

## Scope and authority

This closes the malformed-input and encoding boundaries left outside the earlier
[1006 semantic closure](MsgUserInfo1006-semantic-closure-2026-09-17.md),
[core-packet bounds contract](01_core_packets.md), and
[2078 closure](10_extended_packets.md). Ordinary field meanings, normal bootstrap
ordering and the previously proven dead payload of 1006 string[1] are not re-audited.
The established [font code-page contract](../Rendering/graphic_dll/04_fonts_and_text.md)
is reused; the new evidence connects network byte storage and the 1004 filter to it.

Authority: existing Conquer.exe.bndb view9, graphic.dll.bndb view56 and
C3_CORE_DLL.dll.bndb view20. Conquer.exe SHA-256:
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Exact module/asset hashes, disassembly, reader replay, API probe, BN updates and
the compared managed source are in
[evidence/auth-string-validation-2026-10-18](evidence/auth-string-validation-2026-10-18/README.md).
Addresses below are Conquer.exe unless a DLL is named. Claims are static native
proof unless explicitly labeled **isolated replay**, **platform contract** or **Wine probe**.

The managed comparison is pinned to
[PR #134 head cf2470a2a47e44c0f696454446df2922bfd0d803](https://github.com/berniemackie97/OpenConquerClient/tree/cf2470a2a47e44c0f696454446df2922bfd0d803).
That tree contains N/O documentation and P's `GameCharacterInfo1006.cs`; it has
no separate P document. The local checkout was clean main at
`ecca07f601eb3e701d07a7a3b3548414652f7560`, which lacks O/P. Comparison therefore
uses the supplied PR head, not an assumption about local main or later PR revisions.

## 1. Parser failure is different from a malformed string list

1004's parser `0x731328` tests non-null input (`0x731333`), low16 supplied size
against the header (`cmp si,ax`, `0x731341`), and type1004 (`cmp ax,0x3EC`,
`0x73134F`). It copies the supplied bytes at `0x731360`. 1006's parser
`0x764253` calls common header/copy `0x6DF2AE`, then tests type1006 at
`0x764269`. Neither parser reads the string count or any string length.
The 2078 parser has the same common gate and type-only test at `0x75B01C`.

The dispatcher supplies a fresh constructor-zeroed 1024-byte packet buffer:
`0x6DF285..0x6DF290`. It rejects size>1024 at `0x6DF3D8`. Parse returns0 on
the header/type failures above; dispatcher `0x6E1368..0x6E1379` deletes the
message and returns null. Receive loop `0x6DEC3A -> 0x6DED8D` skips that frame
and advances through remaining input. **This is not the modern reader's
terminal invalid-string exception and socket close.** No hero mutation occurs
when Process is not called.

Distinguish two meanings of “truncated”: a TCP frame shorter than its declared
outer length remains buffered by `CGameSocket_ReceiveMsg` (`0x6E1C83`); it is
not dispatched as a short packet. A complete outer frame whose internal strings
claim unavailable bytes is copied and processed. Zero-fill after the copied
packet is then observable. These are payload-length checks, not TCP write boundaries.
Existing outer framing/signature rules remain unchanged.

## 2. String-list outcome matrix

The decisive new reading of `MsgStringList_TryGetEntry` is:

- `0x771F64..0x771F6C`: zero destination, provided list data pointer is non-null.
- `0x771F7F/82`: return0 if requested index >= count. Count is a u8 from
  `0x771FC0`; there is no requirement for exactly3 or exactly4.
- `0x771F8D`: read u8 length; `0x771F97`: skip an earlier entry by length+1.
  This skip does not test the earlier entry against the destination capacity.
- `0x771FA8/AB`: selected length >= capacity returns0, retaining zeros.
- `0x771FB3`: copy exactly selected length bytes; `0x771FBB/BD`: return1,
  including length0. No payload-length, region-capacity, NUL, encoding or
  final-cursor validation exists in this function.

1004 ignores all four return values at `0x731399/A7/B5/CF`. 1006 ignores all
three at `0x7642C6/D5/E4`. Failure of one lookup does not cancel later lookups.
Each lookup restarts at list+1.

| Input condition | 1004, login channel0x835 | 1006 |
|---|---|---|
| Count too small | Each missing index yields empty output. If index3 is missing, an empty message is enqueued and follows the ordinary non-control-text/refusal branch, not parser rejection. | Each missing index yields empty output. Missing name/spouse clears its owned string when the setter runs. |
| Count larger than consumed indices | Only indices0..3 are requested. Extra declared entries need not even be present or well formed. | Only indices0..2 are requested; unrequested entries are not inspected. |
| Selected length0 | Lookup succeeds with empty output. Empty message follows ordinary refusal handling. | Empty name/spouse is accepted and assigned. |
| Selected name-like length16..255 | That local becomes empty; later lookups still skip the entry's full declared length. Login message can still be found. | Name/spouse becomes empty. An oversized ignored index1 does not prevent reaching a correctly positioned spouse. |
| Message length255 | Reader accepts it into its256-byte local. There is no representable u8 length256; extra bytes become subsequent structure/trailing data. See the separate filter capacity defect below. | Not applicable; all three local capacities are16. |
| Missing length byte or short selected payload inside a complete frame | Uncopied bytes are zeros while within packet storage. A missing length can act as length0; a short payload can produce a C-string prefix followed by zero-fill. No rejection. Some extreme lists cross packet storage; see bounds below. | Same zero-fill behavior, and all reads performed by these three lookups stay within1024 bytes. A short name payload may produce a retained prefix or absorb later bytes according to its declared length. |
| Embedded NUL | Reader copies the whole declared entry. Message queue/filter use the prefix before NUL; `ANSWER_OK\0junk` can select success. Traversal to later entries still uses the declared byte length. | Setters use the prefix before NUL. `Ada\0tail` becomes `Ada`; a leading NUL clears the name. Embedded NUL in ignored index1 is semantically irrelevant. |
| Trailing bytes after consumed entries | No exhaustion check. Truly unreferenced bytes do not affect control processing. | No exhaustion check. Truly unreferenced bytes do not affect hero seed processing. |
| Physically omitted slot while count still claims it | Subsequent bytes are interpreted at the wrong index; there is no marker identifying a “missing” slot. | Omitting the index1 placeholder shifts spouse into the discarded slot. Omitting index0 can make the next entry the player name. This is distinct from a low count or a zero-length placeholder. |

**Malformed ignored strings:** 1006 index1's content is never validated for
encoding or NULs. Even length255 is structurally skipped for index2, although
its own copy fails. A false length changes where spouse is read and can make
it empty or reinterpret other bytes. In 1004, sender/recipient go through byte
substring replacement (`0x7313E4/F6`, `0x731407/14`); recipient also goes
through the conditional filter below (`0x731427`). The suffix local is not
used by login dispatch. None has a “bad ignored string => reject frame” gate.
All three lengths nevertheless affect locating the message. Recipient/filter
side effects mean “unused for routing” must not be expanded to “never touched.”

**Exact bounds, not a blanket safety claim:** list start is packet+110 for1006,
so index2's latest possible length byte is `111 + 2*256 = 623`; a successful
copy ends before packet+639. Earlier selected entries with length>=16 do not
copy. This proves that these three lookups cannot escape the1024-byte storage,
even for a count255 or truncated list. It does not prove all downstream hero
operations safe for arbitrary fixed-field values.

For1004, index3's latest length byte is `25 + 3*256 = 793`; length255 copies
packet offsets794..1048. That is25 bytes past packet storage. The dispatcher
allocates object size0x414 at `0x6DF4C2`, packet starts at object+4, so the
worst case includes16 bytes of object metadata and9 beyond the allocation.
Those bytes are not specified by the packet; the result can depend on memory
contents or fault. **No deterministic protocol rejection or universal zero-fill
claim is valid for this case.**

**Isolated replay:** the captured x86 bytes at `0x771F57` and `0x771FC0` were
executed under Unicorn2.1.4, hooking only CRT memcpy/memset. Eighteen named
cases plus1024 exhaustive length/count checks corroborate the matrix. A
deliberate0xCC sentinel beyond packet storage makes the1004 overread visible;
it does not purport to reproduce real adjacent heap contents. See the replay
source/JSON for exact packet bytes and return values.

## 3. Encoding is selected at consumers, not a fixed1252 wire validator

### 1004: a system-ACP round trip before control comparison

`0x731427` and `0x73143A` call `CSilentInfo_FilterTextUnlessHeroExempt`
(`0x6BB382`) on recipient and message. Its hero predicate at `0x6757C7`
compares the final four name bytes against `[GM]` and `[PM]`; true skips the
filter (`0x6BB391/93`). Otherwise it calls `0x6BB9CA`. Null/empty strings
return without conversion (`0x6BB9DA..0x6BB9EE`).

For a nonempty string the native call arguments are explicit:

| Instructions | API and effective arguments |
|---|---|
| `0x6BBA22..0x6BBA2F`, IAT`0x84411C` | `MultiByteToWideChar(0, 0, text, -1, NULL, 0)` to size |
| `0x6BBA7D..0x6BBA8A` | Same code page0/flags0, converts the entire NUL-terminated string to UTF-16 |
| `0x6BBA99..0x6BBAF8` | Applies the loaded wide-string substitution records |
| `0x6BBAFA..0x6BBB0B`, IAT`0x844118` | `WideCharToMultiByte(0,0,wide,-1,NULL,0,NULL,NULL)` |
| `0x6BBB0F..0x6BBB1C` | Converts back into the caller's original byte buffer; no caller capacity argument |

Zero means **system ANSI code page (CP_ACP)**. The flag is0, not
`MB_ERR_INVALID_CHARS`. Neither code-page1252 nor `g_nLocaleCodePage` is used
here. The conversion happens even if the substitution vector is empty.
The clean `ini/slient.dat` (native spelling, referenced by `0x6BB43B`) is
zero bytes; it is distinct from the9121-byte `ini/silent.dat`. The constructor
zeros the record vector (`0x6BB2FA..0x6BB303`) and reloads this file. There is
no evidence for assuming the similarly named nonempty file supplies these rules.

The filter's Boolean merely reports whether output changed and is ignored by
1004. It does not validate UTF-8, reject CP1252 control slots, or signal a bad
packet. For platform-invalid sequences its output depends on the selected ACP
and Windows conversion behavior; no conversion-error result is checked here.

The filter also has a capacity defect: `0x6BBB0B` returns a required byte count
including the NUL because input length is-1. `0x6BBB24` then writes another
NUL at `input[count]`. Thus an unchanged255-byte message writes one byte past
its256-byte local, and an unchanged15-byte recipient one past its16-byte local,
when this filter runs normally. Conversion expansion has no supplied capacity
bound either. This is an unsafe native operation, **not an intentional rejection
rule for a managed implementation to reproduce**.

Login enqueue (`0x731945 -> 0x730D6C`) uses strlen/strncpy (`0x730D91/DBB`),
preserving only the C-string prefix. It accepts an empty string; the queue read
returns its non-null pointer. Control comparison at `0x5DCC93` / `0x5DCD13`
is `_stricmp`, followed by the established success/creation/other-text paths.
The new compatibility point is that malformed lists do not gate those paths,
and a NUL suffix is invisible to the comparison. Case-insensitive comparison
was already recorded; it is only cross-referenced here for the N difference.
Refusal text goes to `CLoginFlashDlg_ShowLoginErrorText` then
`CFlashControl_SetVariable` (`0x5EA8EB`, MFC InvokeHelper DISPID0x97 with two
string arguments). This preserves the existing Flash presentation boundary;
the packet handler does not perform a separate fixed1252 decode for Flash.

### 1006 and2078: retain bytes, decode when drawn

1006 name `0x7642F4 -> 0x6E5292` and spouse `0x764304 -> 0x6728DC` use strlen
and `CharBuffer_AssignRange` (`0x403BF1`); the latter copies with memcpy at
`0x403C0F/2B`. There is no conversion, character whitelist or byte-validity
filter in these setters. The1006 ignored entry never reaches a decoder.
2078's setter similarly uses strlen `0x6577E5` and byte assignment `0x6577F5`.
Its first NUL ends the location; following bytes are ignored by this setter.
Missing on-wire NUL in a short packet is masked by constructor zero-fill.
At size1024, an all-nonzero location can make strlen leave packet storage;
the outcome is not a defined string-validation failure.

For ordinary game-font display, reuse the established shared contract:
`CodePage.ini` first line sets the C3 global; absent file leaves0/CP_ACP. The
clean asset set was rechecked and has no case-insensitive `CodePage.ini` match.
New decisive encoding anchors are C3 `0x10004570..0x100045D0`:
`IsDBCSLeadByteEx(global,byte)` selects a one- or two-byte character;
`Font_RasterizeAndCacheGlyph` then calls
`MultiByteToWideChar(global,0,bytes,1-or-2,&utf16,1)` at `0x100035C4`.
It ignores the API return and reads the initially-zero output at `0x100035CA`.
The graphic.dll iterator independently advances one extra byte for a DBCS lead
at `0x10015910..0x10015924`. There is no whole-string UTF-8 decoder in this
draw loop, and glyph availability/fallback is separate from packet acceptance.

Consequences:

- Under effective1252, `81 8D 8F 90 9D` are not rejected by these packet
  handlers. Microsoft's Windows mapping maps them to corresponding U+0081,
  U+008D, U+008F, U+0090, U+009D controls, unlike strict codec tables that call
  the positions undefined. This says nothing about whether a font draws a glyph.
- Under936, valid pairs such as `81 40` or `D6 D0` are processed as a single
  DBCS character by the game-font path. Fixed1252 rejection of81 loses valid
  text; fixed1252 decoding ofD6D0 produces two different characters.
- “Valid multibyte” is code-page-relative. `C3 A9` is two1252 characters,
  one936 character, or U+00E9 under an actual UTF-8 whole-string conversion.
  Native does not autodetect UTF-8. Setting the game-font global65001 does not
  turn its one-/two-byte DBCS iterator into a correct UTF-8 string iterator.
- 1004's filter always uses system ACP even if a font override selects another
  page. Treating one configurable font page as a universal packet decode page
  would therefore also misrepresent the client.

**Platform sources:** [Microsoft MultiByteToWideChar](https://learn.microsoft.com/en-us/windows/win32/api/stringapiset/nf-stringapiset-multibytetowidechar)
defines CP_ACP and flag0 behavior. Invalid-sequence handling varies with Windows
version (notably older dropping versus newer replacement); the client supplies
no stricter policy. [Microsoft's Windows1252 mapping](https://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/WindowsBestFit/bestfit1252.txt)
provides the five control mappings above. These are platform corroboration,
not substitute disassembly evidence.

**Wine API probe, not a retail Windows run:** CrossOver's Wine with ACP1252
preserved all five bytes through CP0/1252 round trips. Explicit936 converted
8140 to U+4E02 andD6D0 to U+4E2D; explicit65001 convertedC3A9 to U+00E9.
Full output and probe source are included. Invalid-sequence substitution in
this probe must not be claimed as every historical Windows version's output.
No retail Windows locale, font/glyph availability or live server traffic was
measured in this slice.

## 4. 1006 mutation and EnterMap failure conditions

Once the parser has admitted the packet and receive invokes Process at
`0x6DEC6B`, Process has no nonzero-EntityId, valid-name, nonempty-name,
spouse-present or well-formed-list gate. In execution order:

1. All three string extractions run before any name assignment.
2. Name assignment `0x7642F4`; spouse assignment `0x764304`.
3. UI refresh post `0x76430F`.
4. Raw u32 EntityId load `0x764321` and unconditional `hero+0xCC` store
   `0x764324`; context helper `0x6DEFE5` is called at `0x764338` (it rebuilds
   a1024-byte random table seeded from the now-stored hero ID, including zero).
5. Existing fixed-field stores/setters run. No return-based rollback appears.
6. Stack action constructor `0x764853` clears the packet. Hero ID is loaded
   at `0x764860`, action74 pushed at `0x764867`, builder called at `0x764873`.

The name setter tests null and `strlen >= 36` (`0x6E529A..0x6E52A8`), not
empty/lexical validity. This caller always supplies a non-null16-byte terminated
local, so every normal extracted C-string, including empty, passes. Spouse
setter rejects only null or strlen>16 (`ja`, `0x6728F2`); this caller's length
is at most15. Missing or overlong requested entries therefore **replace existing
name/spouse with empty strings**, rather than leaving old values untouched.
Undefined1252 bytes, controls, invalid DBCS and punctuation are retained as bytes;
character-creation name policy is not applied here.

| Exceptional input | Hero effect once Process runs normally | EnterMap consequence |
|---|---|---|
| Nonzero ID; empty/missing/overlong name; empty/missing/overlong spouse | Empty/prefix/raw-byte strings assigned; fixed fields continue to mutate | These conditions do not gate building action74 |
| Nonzero ID; malformed/truncated list | Strings follow zero-fill/declared-length matrix; fixed fields continue | No list-status gate before builder/send |
| EntityId0, including zero from a short fixed body | Stores ID0 and other fields first | Builder returns0; no valid action74 packet. Failure path below |
| Parser/header/type rejected or outer frame incomplete | Process not reached | No1006-driven action |

For EntityId0, `CMsgAction__Create` tests ID at `0x6FE969/6B` and returns0
at `0x6FE96D`, before writing length/type. Its constructor already zeroed the
packet at `0x6FE8D7`. **The caller does not stop:** `0x764878/7A` selects a
diagnostic log at `0x764895`, then converges on `CNetMsg__Send` at `0x7648A3`.

Send's callback-code0x44C check (`0x6DF358..0x6DF36B`) can suppress sending.
Otherwise it reaches transport `0x6DF0E0`; disconnected context or no socket
can prevent a socket call (`0x6DF0F7`, `0x6DF122`). With the ordinary active
context and socket, the zero packet length passed at `0x6DF38F..0x6DF39D`
reaches `CGameSocket_SendBufferedPacket`. Its `size <= 0` branch
`0x6E1A3A/3C -> 0x6E1C32` calls the error helper at `0x6E1C42`;
that helper **closes/resets the socket at `0x6E2435`**, then logs and returns0.
It never copies/encrypts/queues a valid action74 frame.

For nonzero ID, builder emits the established38-byte action74 packet and
returns1; no name, spouse, count or encoding check gates it. Actual wire delivery
still depends on callback suppression, connection/socket availability, and normal
send-buffer/transport success. “Builder reached” is not evidence of delivery.

**Partial state:** there is no transaction. On the zero-ID send failure, name,
spouse, ID and earlier fixed-field writes have already happened. Process resumes
after Send at `0x7648A8` and runs later UI/configuration operations; the send
result is not used for rollback. Later connection-loss/session cleanup can change
state, but that is not an atomic1006 rejection. Resource exceptions in downstream
callees likewise have no shown undo of prior hero writes; this audit does not
claim that every arbitrary appearance/profession value completes all callees.

## 5. Compatibility decisions for AUTH-001N/O/P

These are factual behavior differences, not a request to imitate native memory
errors or change the managed code in this research slice.

| Slice at reviewed PR head | Difference affecting compatibility |
|---|---|
| N: `GameLoginControl1004.Read` | Exactly4 entries, complete list, first3 lengths<=15, exact packet exhaustion and embedded-message-NUL rejection are stricter than native. A well-positioned ANSWER_OK after a16..255-byte ignored entry can work natively but is rejected by N. Extra count/trailing data also need not stop native. |
| N encoding/control | All four entries are screened for81/8D/8F/90/9D, including unused suffix. Native has no such gate; its conditional filter uses CP_ACP. N's fixed1252 refusal decode differs under other ACPs. N's case-sensitive token comparison also differs from the already documented `_stricmp`; a NUL suffix can be invisible natively. |
| O: `GameLoginHistory2078.Read` | Fixed1252 plus five-byte rejection differs from raw native location storage and locale-dependent rendering. Requiring on-wire NUL/minimum10 is a bounded managed policy: native short-frame zero-fill can supply the terminator. O's acceptance of bounded bytes after the first NUL agrees with the native setter. |
| P: `GameCharacterInfo1006.Read` | Exactly3 entries, minimum114, full entry extents and no trailing bytes are added strictness. Enforcing<=15 for **ignored index1** rejects data native skips without using; even correctly framed255-byte index1 can coexist with a valid spouse. |
| P encoding/names | The undefined1252 check runs even with `retain:false`. Native ignores those payload bytes. Player/spouse embedded-NUL rejection differs from native prefix assignment. Fixed1252 decode differs from native byte storage plus display code-page choice. |
| P exceptional behavior | Reviewed P **already accepts EntityId0 and present zero-length player/spouse strings**: there is no ID/nonempty check and GetString(empty) returns empty, not null. It rejects absent slots structurally. Do not describe its null-coalescing “absent” exception as a nonempty-name rule. |
| P state policy | P creates an immutable snapshot without hero mutation or EnterMap; this is its explicit bounded scope. Future application of that snapshot must choose deliberate validation/atomicity, rather than treating native's partial initialization and zero-ID socket error as validation requirements. |

Strict CP1252 validation **does not match native behavior, even with Windows
ACP1252**, because the five listed bytes are retained/mapped rather than rejected.
For compatibility documentation, separate (a) wire framing/storage,
(b) consumer-specific encoding, and (c) intentional bounded managed policy.
The evidence does not authorize silently relabeling the stricter policy “native.”

## Verification and completion boundary

- Nine focused BN comments and six justified function names were applied and
  read back before notes were written. BNDBs were not saved.
- Raw reader replay:18 named cases and1024 exhaustive checks passed. It runs
  only the reader/count instructions, not the full client or network stack.
- Captured instruction bytes were checked against the clean PE images; the
  verification JSON records the exact capture hashes and comparison count.
- API-only probe ran under Wine; native instruction-selected code pages/flags
  remain the primary evidence. Windows-version-specific malformed-sequence
  output and font appearance remain explicitly environment-dependent.
- PR #134 source comparison is fixed to the SHA above. No PR comments, commits,
  branches, implementation edits or game sessions were created.
- The updated archive preserves the supplied archive's unrelated entries.
  It contains these findings and the evidence needed to audit/reproduce them.
