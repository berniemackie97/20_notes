# MsgUserInfo 1006 semantic closure audit

`Conquer.exe` 5517; native verification through 2026-09-21.

This is a native-evidence investigation, not authorization to implement or rename unresolved protocol fields in production. Source: clean 5517 Conquer.exe, SHA-256 b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62, active Binary Ninja database Conquer.exe.bndb. The user retains responsibility for saving the database.


## Current status

**The focused historical reconciliation is complete; an all-native gameplay-name closure is not.**
The [targeted reconciliation](MsgUserInfo1006-historical-field-reconciliation.md) establishes
matching native storage/update behavior for the proposed COPS5066 identities. No contradictory
native evidence was found. Historical names are now explicit, rather than anonymous unknowns;
their provenance and the limits of the compatibility verdict must remain attached.

| Target | Wire location | Current verdict | Decisive evidence / boundary |
|---|---|---|---|
| 1 | `+32`, 32 bits | **PROVEN RETIRED/COMPATIBILITY FIELD**: LegacyDeed | Native `0x7643EC` -> hero`+0x85C`; deprecated name from aligned COPS5066 slot |
| 2 | `+36`, u32 | **PROVEN RETIRED/COMPATIBILITY FIELD**: LegacyMedal | Native `0x764400` -> hero`+0x844`; deprecated name from aligned COPS5066 slot |
| 3 | `+40`, u32 | **PROVEN RETIRED/COMPATIBILITY FIELD**: LegacyMedalSelect | Native `0x764414` -> hero`+0x848`; additional player-spawn write `0x756525` |
| 4 | `+44`, u32 | Native update identity proven; historical Virtue corroborated | `0x764847` and packet10017 discriminator23 at `0x757BFF` write hero`+0x8B8`; native-only gameplay-name closure not established |
| 5 | `+72`, u8 | **PROVEN RETIRED/COMPATIBILITY FIELD**: LegacyNobility | Native `0x7645C5` -> hero`+0xF34`; active peerage rank separately identified at role`+0xA2C` |
| 6 | `+74`, u8 | **PROVEN RETIRED/COMPATIBILITY FIELD**: LegacyAutoAllot | Native `0x764552` -> hero`+0xCE4`; no boolean normalization or required value1 established |
| 7 | `+97`, u8; `+98`, u64 | **PROVEN SEMANTIC** | Active subprofession ID and decimal-packed promotion phases, distinct from training levels |
| 8 | string entry1 | **PROVEN RETIRED/DEAD FIELD: payload on normal receive path** | Discarded local copy and message lifetime; entry length remains structural |

For targets1/2/3/5/6 the compatibility verdict means native retention plus documented historical
retirement. It is **not an exhaustive whole-client deadness claim**. The six original gameplay
words are historically corroborated, not independently recovered native symbols. No required
retail defaults are established. String[1]'s historical name/retail payload remain unrecovered;
an empty placeholder preserves spouse index2. Production implementation remains unchanged.

The complete offset table is included below so this notes repository preserves the findings
without depending on the work repository's narrative. Baseline rows retain the user's already
proven semantics; they were not all independently reopened in this pass.

## Confirmed discovery: +97/+98 are subprofession data

**PROVEN SEMANTIC: subprofession subsystem.** The MSVC TypeDescriptor at 0x921F28 has its ASCII decorated name at +8 (0x921F30): ` .?AVCSubProfMrg@@` (without the leading space). The pointer 0x0086DF04 at descriptor+0 is the shared type_info vftable, not the feature name.

- 0x49A653, now CSubProfMrg_GetSingletonPtr, uses that descriptor in its singleton diagnostic and constructs the 0x28-byte manager via 0x6C1EAD.
- 0x6C1EAD calls 0x6C22B1, now CSubProfMrg_LoadSubProfessionInfo.
- Loader 0x6C22FB names `ini/SubProfessionInfo.ini`; 0x6C231F names native source `SubProfMrg.cpp`. Section number is parsed to record+0x24.
- 0x6C17FD parses native property names including title, intro, req_joblv, suit (record+0x30), suitpower (+0x34), and BigClass (+0x40).
- 0x6C1FB3 finds a record with key `type*10 + phase` at 0x6C2003; phase >9 is rejected.
- MsgUserInfo 0x764276 sends packet+97 to 0x675ABA (role+0x450); packet+98..105 to 0x675AE1 (role+0x468/+0x46C); its selected decimal digit to 0x675AC7 (role+0x454).
- 0x675B94 reads the active type/phase through 0x675C0F/0x675C16, resolves that SubProfMrg record and applies its suit/suitpower through CSuitStatusMgr_AddOrUpdateRecord, using the role ID at +0xCC.
- The clean retail INI names class 1 Martial Artist and keys 11..19 P1..P9 Martial Artist. The phase-versus-training-level distinction is established below.

No reference-server label was needed to identify this feature. Earlier open-feature claims in 01_core_packets.md are superseded by this direct RTTI and loader evidence.

## Historical-name attribution and proof standard

The targeted names and verdicts are now recorded above and in the focused reconciliation.
Earlier proximity/displacement scans below remain historical candidate searches, **not exhaustive
dead-field proofs**. Do not restart broad receiver-model expansion from their old next-step text:
the latest requested scope is direct historical-hypothesis testing. Native-only identity, historical
attribution and server policy are separate evidence categories.

## Subprofession phase versus training level (native closure)

The wire qword at +98 is **PackedSubProfessionPhases**; +97 is **ActiveSubProfessionId**. The earlier neutral "per-type level vector" describes the packing but is too ambiguous for production naming.

- Native INI keys 11..19 have titles P1..P9 Martial Artist. CSubProfMrg record lookup uses type*10+phase. The record contains a separate req_joblv training-level requirement.
- Subprofession packet processor 0x728E70, whose parser 0x7293D9 validates type **2320 (0x910)**, maintains the distinction explicitly:
  - action 3: reads manager owned record+8, increments it (0x72926F), stores via 0x6C2217 and active hero+0x45C via 0x675AD4, then uses record+0x68, parsed from UpLevEffect.
  - action 5: takes packet+7 as phase, updates decimal-packed hero+0x468/+0x46C (0x72904F), active phase +0x454 (0x729080), and manager owned record+4 (0x729153); uses record+0x74 and +0x80, parsed from UpStepEffect and UpStepScreenEffect.
  - action 7: populates owned records as separate type/phase/training-level triples via 0x6C2238 (0x728F4F).
- Panel 0x52B24E reads active phase (0x52B2AA) and training level (0x52B2B9) separately; 0x52C27F uses STR_LEVEL_EXP/STR_LEVEL_COLOR_EXP with manager training level from 0x6C25ED.
- +97=0 stores no active type and skips phase digit extraction; +97>0 selects decimal digit type-1. The existing native phase value is not explicitly zeroed in that branch of 1006. Valid phase digits are 0..9; clean INI record titles identify phases 1..9. No server-policy default is inferred.
- Native 1006 extraction at 0x7647D6..0x7647FC uses pow(10,type-1), _ftol, a **CDQ sign extension of the low 32-bit result**, __alldiv and __allrem. Encode only supported native class IDs and nonnegative phase vectors; do not assume arbitrary u8 indexes/u64 values have a meaningful gameplay interpretation.

## String entry 1: local use is definitively discarded

0x7642CB loads EBP-0x40; 0x7642D5 passes it as the destination of MsgStringList_TryGetEntry(this+0x408,1,buffer,16). BN MLIL-SSA names the same buffer var_44 because of frame accounting. It is zero-initialized and its address is used for that copy only; no subsequent handler path reads its contents. Adjacent buffers EBP-0x30 and EBP-0x20 feed player name and spouse name respectively.

Helper 0x771F57 zeroes the supplied buffer when the list data pointer exists, walks length-prefixed entries, and copies only if entry length < capacity; it does not retain or publish the destination pointer. The return status at 0x7642D5 is ignored. This proves dead consumption in the 1006 Process handler, not a historical gameplay name for entry 1.

**Target 8: PROVEN RETIRED/DEAD FIELD, specifically the entry's payload bytes on the normal 5517 receive path.** The following lifetime trace closes the remaining check. The historical meaning and reason for retirement are not encoded by this trace and are not assigned a gameplay name.

- Dispatcher 0x6DF3B5 constructs this message at 0x6DF533 via 0x764197. The constructor installs vtable 0x86D678 and binds its string-list wrapper to packet+110.
- Dispatcher 0x6E1365 invokes vtable+4 = parser 0x764253. That parser calls 0x6DF2AE: header size/type checks and a byte copy into the internal packet buffer, with no interpretation of string[1].
- Receive loop 0x6DEBA5 invokes vtable+0x10 = Process 0x764276 at 0x6DEC6B. The only string[1] extraction is the discarded local copy documented above. The message pointer and string-list wrapper are not published by Process.
- After Process, 0x6DED5A invokes vtable+0 = deleting destructor 0x7641F9. It calls 0x764215; that destroys the embedded string-list wrapper through 0x771EAF and the base through 0x6DF27A. Both destructors only install their base vtable; neither reads string data. The deleting destructor then frees the message.
- Native xrefs to the 1006 constructor identify the dispatcher; parser/Process have vtable references. Vtable 0x86D678 has constructor/destructor code references, not a second feature-specific consumer.

**Structural distinction:** string[1]'s length byte is still used when the string-list helper walks to string[2]. Therefore the slot cannot simply be omitted while retaining spouse at index2. An empty index1 is sufficient to preserve that indexing; this is a client-compatible encoding, not proof that the retail server always sent an empty string. Malformed list lengths are outside this dead-payload statement.

## Important corrections to previous negative evidence

### Initialization of the four DWORD fields

Native `CPlayerInlineState_InitializeDefaults` (`0x66162B`) receives the inline state
at player/hero`+0x4F0`. The CPlayer constructor establishes that receiver at `0x66ECAE`
and calls the initializer at `0x66ED53`; hero reset passes the same receiver at
`0x65707D`/`0x657083`. `CPlayerInlineState__Ctor` (`0x6765EE`) also calls it at
`0x676686`. The initializer zeroes EBX at `0x661647` and performs these native writes:

| Packet field | Complete-object destination | Initializer-relative destination | Zero-store instruction |
|---|---|---|---|
| `+32` | hero`+0x85C` | inline state`+0x36C` | `0x6616DD` |
| `+36` | hero`+0x844` | inline state`+0x354` | `0x6616B3` |
| `+40` | hero`+0x848` | inline state`+0x358` | `0x6616AD` |
| `+44` | hero`+0x8B8` | inline state`+0x3C8` | `0x661755` |

These establish zero initialization and resetting. They do not establish gameplay meanings,
retail-server defaults, or dead-field status. Earlier exact-displacement searches missed these
writes because their receiver is an interior pointer. The decompiler also groups some stores
into synthetic memset calls; the table records actual individual instructions.

### Additional indexed-access checks

`Role_TestSecondaryStatusBit` (`0x6E5248`) rejects indexes outside `0..127` and reads
only receiver`+0x80..+0x8F` at `0x6E526B`. It cannot reach a target field.

`CDummy_CopyEquipmentSlotReference` (`0x42824E`) logs an assertion for equipment
positions outside `1..18`, but **continues after that assertion**. The traced receiver is
hero`+0x1EA0`. Normal positions read hero`+0x2938..+0x29C7`; this is not a bounds
enforcement proof for arbitrary inputs. Native assertion text is at `0x428270`.

`CDummy_FindEquipmentReferenceByStoredKey` (`0x66CE68`) has an actual bounded loop:
index starts at zero at `0x66CE71`, increments at `0x66CE8C`, and stops at `0x12`
at `0x66CE90`/`0x66CE93`. Its slot reads at `0x66CEA9` and `0x66CEB9` cover
the same hero`+0x2938..+0x29C7` range. The per-object key read uses the folded
accessor `0x71FF0B`; that accessor also serves unrelated classes.

`CRole_TrackPrimaryStatusBitChangesForRestrictedIdRange` (`0x676207`) permits only
entity IDs `0x61A81..0x7A11F` (`0x67621A`/`0x676225`). Its bit loop is bounded
to `0..127` at `0x6762DA`/`0x6762E3`; indexed role reads at `0x676277` and
`0x6762AA` stay within role`+0x70..+0x7F`. Its separate changed-bit vector is
at role`+0xA4C`/`+0xA50`. None of these accesses consumes a target numeric field.

### Entity-reference output routes

`EntityRef_ResolveByIdOrLocalHero` (`0x6E847D`) publishes the local hero through
an output reference at `0x6E84DA`, after the include-local-hero flag and entity-ID
checks at `0x6E848F`/`0x6E84A7`. Other branches return another entity or null.
The previous direct-return-only analysis did not follow that output storage.
Fresh native xrefs contain **258 call sites in 189 functions**. All caller SSA
captures are preserved under `entity-reference-callers/` in the evidence directory.
The extended candidate model accounts for all 258 call sites, including 14 whose
obfuscated stack is displayed as a generic `call(...)` by Binary Ninja. Matching
a call site is not a proof of complete propagation of every memory alias.

This route independently recovers the known player-spawn store at `0x756525`
and MsgUserAttrib store at `0x757BFF`; it has not established a new gameplay
consumer of those fields. Candidate output aliases conservatively include other
entities and reused stack storage, so native receiver review is still required.

`EntityManager_GetCurrentOrPreferredRoleReference` (`0x6E8A70`) is another output
route. Flags zero first considers the reference at manager`+0x0C`; the selection
path considers the hero when flag bit zero is set (`0x6E8AE6..0x6E8B65`), subject
to a virtual predicate. Later candidates may replace it. The final stored-object
and control-block writes are at `0x6E8FBE` and `0x6E8FC2`. Native xrefs identify
seven call sites in three functions. These are pointers to trace, not numeric-field
consumers by themselves.

### Exception-cleanup receiver proof

The `+0xF34` adjustment at `0x7F1793` is part of a **dialog** cleanup, not a hero
field consumer. This is established by the native ownership chain:

- Constructor `0x52A4A8` installs the subprofession-dialog vtable `0x8601D0` at
  `0x52A633`.
- That vtable's deleting-destructor slot points to `0x52AA59`, which calls
  `CDlgSubProfession__Destructor` (`0x4BB339`) at `0x52AA5C`.
- Normal destruction passes dialog`+0xF34` to the control destructor at `0x4BB3A2`.
- The exception handler `0x7F17D6` references FuncInfo `0x8AA770`; its unwind
  array is `0x8AA790`. The entry at `0x8AA81C` points to cleanup `0x7F1790`.
  That cleanup loads the original dialog pointer from frame`-0x10`, adds `0xF34`,
  and invokes the same control destructor `0x5A4FB9`.

The constructor/destructor, vtable bytes, exception metadata and native xrefs are
captured in the evidence directory. Names/comments were applied to the two
destructors and `CDlgSubProfession_UnwindEmbeddedControl_F34`. An offset match
alone would have assigned the wrong receiver here.

Current native captures and renames are preserved in the evidence directory. The corrected
constructor signatures survived the Binary Ninja restart; fresh SSA still connects the CE4/F34
zero stores to the incoming hero. The later historical reconciliation supplies attributed names; these constructor checks alone do not establish them.

- Expanded raw-instruction candidate census: 1,410,457 decoded instructions, 197 candidate sites, 146 functions. Native functionAt membership was then obtained for every site, and full function-bounded HLIL and MLIL-SSA captured. Counts are search coverage, not a no-consumer proof.
- The old spawn discussion reverses the role-ID branches. Fresh native 0x755F64 shows ID >999999 takes the +0x848 dword write at 0x756525; ID <=999999 takes the protected life setter at 0x756407. Native 0x67350E checks IsPlayer() by rejecting ID <=999999, independently fixing the branch identity.
- Hero primary vtable slot +0xC4 points to 0x661F09, which was absent from BN's function list. It was defined and decoded: it reads +0x514, not any of the six target fields. Missing BN functions must not be treated as evidence of missing native consumers.
- Numeric targets +72 and +74 are one-byte wire values but **zero-extended dword stores** to hero+0xF34 and hero+0xCE4. Prior CHero type metadata splits +0xCE4 into a byte and padding; that metadata does not change the instruction width.
- The +66 wire bits are read with MOVSX at 0x764682. The baseline u16 wire-width description needs the explicit signed-16 interpretation when explaining native PK-point behavior.

All evidence is being retained under 10_work/docs/evidence/msguserinfo-1006-5517/. No implementation code has changed in this task.

The complete offset/width/destination/evidence/encoding table is maintained in
[10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md](../../10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md).
It includes the unconsumed +83..84 span explicitly and attributes the newly reconciled
historical names without treating them as recovered native symbols. The clean INI defines class IDs1..6 and9; missing7/8
are not assumed supported. Type9's phase is also consumed by CHero_GetEffectiveMaxLife at0x65D1E8.

## Restart recovery and deeper computed-address review

The durable annotation manifest is `10_work/docs/evidence/msguserinfo-1006-5517/restorable-annotations.json`.
The restored 1006 handler comment now explicitly withdraws the older "apparently inert" characterization.
All annotations are applied through the native MCP connection; database saving remains with the user.

The receiver-helper capture contains 2,944 unique native functions. An affine SSA candidate pass found
47 possible target accesses and 220 dynamically indexed expressions. These counts are deliberately
overapproximated candidates, not proof of reachability or exhaustive semantic closure.

Two apparent computed reads of hero+0xF34 are ruled out by exact native loop bounds:

- `CHero_GetEffectiveMaxMana` 0x65D25A: EDI starts at hero+0xE8C (0x65D2EE), EBX is 18
  (0x65D2EC/0x65D2F4), the pointer load is 0x65D2F5, stride is 8, and DEC/JNE at
  0x65D308/0x65D309 terminates the loop. Actual read offsets are E8C through F14 inclusive.
- 0x6DBD7C: the two equipped-item loops start at hero+0xE8C (0x6DBDFC and 0x6DBF73),
  advance by 8 (0x6DBE72 and 0x6DC01F), and compare their zero-based counters with 18
  (0x6DBE75/0x6DBE79 and 0x6DC022/0x6DC026). Again, their last read is F14, not F34.

### Proven trampoline misalignment, resolved rather than discarded

0x64E008 is a real role-receiver function whose existing HLIL loses its real continuation.
The native bytes and call-return arithmetic prove this chain:

| Call | Pushed return address | Trampoline operation | Real continuation |
|---|---|---|---|
| 0x64E09D | 0x64E0A2 | 0x64E0B7: POP EBX; ADD EBX,0x2C; JMP EBX | 0x64E0CE, POPAD |
| 0x64E0EF | 0x64E0F4 | 0x64E10B: POP EDI; ADD EDI,0x2E; JMP EDI | 0x64E122, POPAD |
| 0x64E133 | 0x64E138 | 0x64E148: POP ECX; ADD ECX,0x27; JMP ECX | 0x64E15F, POPAD |
| 0x64E1A3 | 0x64E1A8 | 0x64E1B6: POP EDI; ADD EDI,0x25; JMP EDI | 0x64E1CD, POPAD |

Each POPAD balances the PUSHAD before its call. The trampoline comparisons are against zero,
but these computed continuation addresses are nonzero. The apparent `[ECX+EAX+0x45890000]`
operation at 0x64E0DD belongs to a misaligned junk path, not the executed continuation.
The actual continuations were defined separately in Binary Ninja and named/commented as
control-flow continuations, explicitly not independent gameplay functions. No binary bytes were patched.

Because this trap defeats a single linear disassembly alignment, a further candidate search scans
target-displacement byte patterns at every executable alignment. It includes overlapping qword
accesses and produced 198 candidate instruction alignments, four absent from the earlier census.
Their native reachability is reviewed separately; the count alone proves no field dead.
Captures and the search script are retained with the evidence.

The four new alignments are not new native instructions: 0x413DE5 starts inside LEA at0x413DE4,
0x479992 inside MOV at0x479991, 0x5A15D3 inside LEA at0x5A15D2, and 0x757C00 inside
the known attribute store at0x757BFF. Full native disassembly of each containing function
establishes those boundaries. The latter is the existing +0x8B8 writer, not a hidden reader.

Native indexed-access checks also rule out several plausible aliases: 0x6DA843 validates
equipment positions1..18 and reads hero+0xE84+position*8 (E8C..F14); 0x6E50D4 bounds status
indices to0..127 and reads role+0x70..0x7C; 0x6E51DB bounds indices to0..15 and reads+0xA0;
0x652F84 accepts only indices<32 and reads+0x34. Function0x662B13 indexes a separately
allocated vector through a pointer loaded from hero+0x2F24; it does not index inline hero storage.
These exclusions establish the exact paths reviewed, not a blanket absence proof for six fields.

The static-data search found only one exact dword offset candidate outside executable sections:
0x974844 contains 0x8B8 as the **Size** member of an IMAGE_RESOURCE_DATA_ENTRY for resource
type5/dialog396/language2052, data RVA0x58C728. Native xrefs to0x974844 are empty. It is
resource metadata, not a table mapping hero attributes to member offsets.

Further cross-function candidates have been checked:

- 0x6D95BC, now `CHeroItem__ClearInventoryAndEquipment`, calls `SharedPtr_ResetAndRelease`
  (0x712CE0) for exactly18 inline equipment slots. The shared-pointer reset writes its two
  dwords, so the final inline write is hero+0xF18, not F34. Native0x6D964C..0x6D965E proves
  the start/stride/count; the other reset loop operates on separately allocated inventory entries.
- Equipment predicate0x6DC90E similarly reads18 slots, E8C..F14, at0x6DC91D/0x6DC92C.
- 0x7387D3 has an ineffective range check: JGE0x7387D9 and JL0x7387DE together allow every
  signed32 index to reach `[ECX+EAX*4+4]`. This was not assumed safe from the decompiler.
  However, all11 native call xrefs are in0x73FE0D and supply constants0,2,3,7,10,12,13,15,17,18,19
  with receiver hero+0x2C60. These calls read2C64..2CB0, never the six target destinations.
  The containing constructor emits packet1101 and combines these components into packet+8.
  The getter is named `Protocol1101CheckData_GetComponent`; no historical component identities
  are inferred from that arithmetic.

The interprocedural candidate generator explicitly reports uncaptured callees and uncertain
parameter mapping. Its results cannot be used to turn these exclusions into an exhaustive
no-consumer claim. See the later historical reconciliation for the current field classifications.

## Virtual receiver correction and secondary interfaces

The constructor chain must be followed to its **final** vtable assignment:

- CRole constructor0x64D079 initially writes0x86A2B8 at0x64D090, but replaces it with
  **0x86AACC at0x64D142**. The latter has40 consecutive native function entries before
  zero/floating-point data. Treating the first assignment as CRole's final table misses methods.
- CPlayer constructor0x66EC52 calls the role constructor at0x66EC66, then installs0x86AEEC
  at0x66ED4D. Its83 consecutive function entries end at0x86B034, followed by floating-point data.
- CHero constructor0x655194 calls0x66EC52, then installs primary table0x86AD08 at0x655730.
  Its83 entries end at0x86AE50. **0x86AE54 is a different embedded object's table**, referenced
  by construction at0x6551C0; 0x86AE64 is another table referenced at0x66E946. The earlier
  91-entry pointer run over-counted the hero table by including these adjacent tables.
- Hero+0xA58 receives secondary table0x86AD00; hero+0xA5C receives0x86ACFC.
  0x66C448 subtractsA58 and tail-jumps the complete hero deleting destructor0x656090;
  0x66C453 similarly subtractsA5C. Both are now named/commented as this-adjusting thunks.
- Secondary table0x86AD00 slot4 calls0x6576D3. Its apparent negative-offset store
  `[this-0x98C]` at0x65770D is **hero+0xCC**, because this=hero+A58. The native
  Hero.cpp CHECK names `idHero > 0`. It is not a consumer of any six unresolved fields.

Native table bytes are retained in `native-vtable-bytes.json`; receiver seeds for all209
entries across these primary/secondary tables are in `verified-vtable-receiver-seeds.json`.
Their callees are included in the continuing function-bounded review. No table identity was
assigned merely because nearby data resembled a function pointer.

## Recovered continuation coverage after reconnect

Native Binary Ninja now verifies **41 CALL-to-continuation edges** in the captured receiver
functions. Each edge has the PUSHAD/CALL bytes, native xref, pushed return address, trampoline
ADD constant, and destination bytes preserved in `native-trampoline-edges.json`. All41 destinations
begin with POPAD. This establishes the continuation if the corresponding CALL executes; it is
not a whole-program reachability claim. Analysis anchors and comments explicitly identify these
as continuations within the original frame, not independent callable gameplay functions.

The previously missing calls resolve as follows:

| CALL | Return address | Trampoline | Add | Real continuation |
|---|---|---|---|---|
| 0x65D40D | 0x65D412 | 0x65D423 | 0x28 | 0x65D43A |
| 0x65D63E | 0x65D643 | 0x65D653 | 0x27 | 0x65D66A |
| 0x658DF0 | 0x658DF5 | 0x658E05 | 0x27 | 0x658E1C |
| 0x658E65 | 0x658E6A | 0x658E7E | 0x2B | 0x658E95 |

0x658E05 was itself absent from the earlier function capture. Native bytes at0x658E12
are FF E1 (JMP ECX); the apparent path at0x658E1A is misaligned junk. No executable bytes
were patched. Existing meaningful function names and comments were retained. The restorable
annotation manifest is current; database saving remains under the user's control.

These recovered paths are being checked with original register/frame provenance. A fresh
standalone continuation's inferred parameters cannot be treated as a trustworthy C++ prototype.
This finding does **not** close the six numeric fields, and supersedes any claim that the earlier
function list or decompiler output covered every executable path.


### Follow-up, 2026-09-18

One further continuation was exposed: CALL0x65D50F pushes0x65D514; trampoline0x65D52E
POPs ESI and adds0x31, giving0x65D545. Native0x65D53B is JMP ESI. The false-zero branch
at0x65D543 decodes junk; real0x65D545 starts POPAD and continues the original elevation-check
frame. This brings the captured native trampoline edges to42. Names/comments and restoration
manifest were updated before these notes. No production implementation changed.

The affine candidate model now has3351 captured functions,2157 states, no missing direct
callees and no depth-limit truncation. Its13 apparent target accesses are the bounded equipment
loops already discussed. These counts describe the model only, not exhaustive binary coverage.

## Complete packet offset table

All offsets include the four-byte header. Numeric fields use little-endian wire order.
Confidence distinguishes retained baseline evidence from conclusions established in this audit.

| Offset | Width | Production semantic name | Native destination | Decisive evidence | Confidence/status | Server encoding/scaling |
|---|---:|---|---|---|---|---|
| 0 | u16 | PacketLength | CNetMsg packet buffer | validator 0x76425E | Native proven | Packet byte length, including header and string list |
| 2 | u16 | PacketType | CMsgUserInfo parser | comparison 0x76426F | Native proven | 1006 / 0x3EE |
| 4 | u32 | EntityId | hero+0xCC | store 0x764324; random-table seed 0x764338 | Baseline proven | Raw ID |
| 8 | u16 | TransformLookSourceId | 0x650B1F, transform-look source setter | call 0x7644F4, refresh=1 | Baseline proven | Separate from packed appearance |
| 10 | u32 | PackedAppearance | RoleView source/mesh setters; hero+0x178 | 0x76448A, 0x7644B4, 0x7644DA | Baseline proven | source=v%1000; flag=(v/1000)%10; mesh=(v/10000)%1000 |
| 14 | u16 | HairComposite | linked-source/head-attachment setters | 0x764516, 0x764532 | Baseline proven | v%1000 and v/1000 |
| 16 | u32 | Silver | money setter 0x6844D2 | call 0x76442A | Baseline proven | Raw silver |
| 20 | u32 | ConquerPoints | emoney setter 0x698336 | call 0x76443F | Baseline proven | Raw CP |
| 24 | u64 | Experience | hero+0x860/+0x864 | 0x7643D2/0x7643D8 | Baseline proven | Low dword then high dword |
| 32 | 32 bits | LegacyDeed | hero+0x85C | store `0x7643EC`; COPS5066 +30 alignment | Proven compatibility store; deprecated historical name corroborated | Raw bits; historical s32, native arithmetic signedness/default unproven |
| 36 | u32 | LegacyMedal | hero+0x844 | store `0x764400`; COPS5066 +34 alignment | Proven compatibility store; deprecated historical name corroborated | Raw DWORD; no required retail default proven |
| 40 | u32 | LegacyMedalSelect | hero+0x848 | store `0x764414`; player spawn `0x756525`; COPS5066 +38 | Proven compatibility store; deprecated historical name corroborated | Raw DWORD; no required retail default proven |
| 44 | u32 | VirtuePoints (historical name) | hero+0x8B8 | `0x764847`; packet10017 discriminator23 store `0x757BFF` | Native shared-field/update identity proven; Virtue historically corroborated | Raw DWORD; attribute23 consumes low32 bits; no scale/default proven |
| 48 | u32 | EncodedPreRebirthLevel (historical MeteLev) | role+0x83C via `0x673202` | divide/call `0x764584`/`0x764587`; tutor lookup `0x73237F` | PROVEN SEMANTIC; MeteLev historical name corroborated | Quotient raw/100000 is retained pre-rebirth level; remainder discarded on this path |
| 52 | u16 | Strength | hero+0x4FC | 0x76437C | Baseline proven | Zero-extended to dword |
| 54 | u16 | Agility | hero+0x504 | 0x764391 | Baseline proven | Zero-extended to dword |
| 56 | u16 | Vitality | hero+0x508 | 0x7643A6 | Baseline proven | Zero-extended to dword |
| 58 | u16 | Spirit | hero+0x50C | 0x7643BB | Baseline proven | Zero-extended to dword |
| 60 | u16 | UnspentAttributePoints | hero+0x840 | 0x7645B0 | Baseline proven | Zero-extended to dword |
| 62 | u16 | CurrentLife | player protected data index1 via0x673EAC | 0x764351 | Baseline proven | Raw current life; not maximum |
| 64 | u16 | CurrentMana | mana setter0x67321A | 0x764368 | Baseline proven | Zero-extended argument |
| 66 | 16 bits | PkPoints | hero+0x868 | MOVSX0x764682; store0x764686 | Baseline identity; native signedness correction | Native interprets wire bits as signed i16, sign-extended to i32 |
| 68 | u8 | Level | hero+0x838 | 0x764567 | Baseline proven | Zero-extended to dword |
| 69 | u8 | CurrentProfession | hero+0x82C | 0x76459B | Baseline proven | Raw profession code |
| 70 | u8 | FirstProfession | role+0x850 | setter call0x7645F4 | Baseline proven | Raw profession code |
| 71 | u8 | PreviousProfession | role+0x854 | setter call0x76460B | Baseline proven | Raw profession code |
| 72 | u8 | LegacyNobility | hero+0xF34, DWORD | store `0x7645C5`; ctor `0x655DEB`; COPS5066 +68 | Proven compatibility store; deprecated historical name corroborated | Zero-extended byte; distinct from active peerage rank at role+0xA2C |
| 73 | u8 | RebirthCount | role+0x84C | setter call0x7645DD | Baseline proven | Raw count |
| 74 | u8 | LegacyAutoAllot | hero+0xCE4, DWORD | store `0x764552`; ctor `0x655DC3`; COPS5066 +70 | Proven compatibility store; deprecated historical name corroborated | Zero-extended byte, no bool normalization; value1 not proven required |
| 75 | u32 | AuraTierScore | role+0x984; status effect mapping | 0x76463A..0x76466B; virtual+D8 | Baseline proven | Raw score, not preconverted effect ID |
| 79 | u16 | CoachPointsHundredths | role+0x99C via0x6ED511 | 0x7646EF | Baseline proven | Client x100 representation |
| 81 | u16 | CoachExperienceShareCount | hero+0x9A8 via0x6ED5FD | virtual+E4 at0x764708 | Baseline proven | Raw count; zero/nonzero drives prompt/effect |
| 83 | 2 bytes | No semantic name assigned | No fixed-field load identified in Process | full0x764276 handler and packet-relative read map | No-read span in this handler; historical meaning unproven | Do not label reserved as a guessed protocol meaning |
| 85 | u16 | CoachSessionState | role+0x9A4 via0x673BA4 | 0x764720 | Baseline proven | Client coach session counter/state encoding |
| 87 | u32 | FlowerStatusTier | role+0x474 via0x673266 | 0x7646BF | Baseline proven | Raw tier, not flower count |
| 91 | u16 | TitleId | role+0x8AC via0x674B56 | 0x7646D6 | Baseline proven | Zero-extended |
| 93 | u32 | BoundConquerPoints | bound-emoney setter0x640098 | 0x764735 | Baseline proven | Raw bound CP |
| 97 | u8 | ActiveSubProfessionId | role+0x450 | 0x7647AA ->0x675ABA; CSubProfMrg RTTI/INI | **PROVEN SEMANTIC**, target7 | One-based class ID; 0 selects none |
| 98 | u64 | PackedSubProfessionPhases | role+0x468/+0x46C; active digit ->+0x454 | 0x764793, 0x7647D6..0x764809; native2320 action3 vs5 | **PROVEN SEMANTIC**, target7 | Sum of phase[type]*10^(type-1); phases are decimal digits, distinct from training levels |
| 106 | u32 | RacePoints | hero+0x2E08 via0x6655DB | 0x76474A | Baseline proven | Raw race points |
| 110 | u8 plus variable data | Strings | MsgStringList at message+0x408 | ctor0x7641D0..0x7641E4 binds packet+110 | Native proven | count followed by length-prefixed byte strings |
| string[0] | length-prefixed ANSI | PlayerName | CRole_SetName0x6E5292 | copy0x7642C6; apply0x7642F4 | Baseline proven | At most15 encoded bytes to fit native16-byte destination |
| string[1] | length-prefixed ANSI | DiscardedStringEntry (no historical gameplay identity recovered) | Local16-byte buffer EBP-0x40 | copy0x7642D5; no read/escape; receive0x6DEC6B -> destructor0x6DED5A/0x7641F9 | **PROVEN RETIRED/DEAD FIELD**, target8 payload on normal receive path | Empty entry preserves spouse index2; length remains structural; retail payload value is not recovered |
| string[2] | length-prefixed ANSI | SpouseName | vector at role+0x4F0 via0x6728DC | copy0x7642E4; apply0x764304 | Baseline proven | At most15 encoded bytes to fit native16-byte destination |

The string wire representation is length-prefixed, **not** a NUL-terminated wire field.
The native copy helper zeroes its destination before copying, leaving a terminator when length<16.
String decoding above does not establish a universal server-side ANSI code page.

The clean INI defines subprofession IDs 1 Martial Artist, 2 Warlock, 3 Chi Master, 4 Sage,
5 Apothecary, 6 Performer and 9 Wrangler. No support for IDs7/8 is inferred from their unused
decimal positions. Native 1006 uses a signed divide/remainder after pow/_ftol; supported class IDs
1..6,9 and nonnegative phase vectors fit the verified arithmetic path. Do not extend its domain
to arbitrary byte indexes.


## Analysis coverage and remaining boundary

### Additional getter calling-convention defect found and repaired

The saved database still inferred the protected-integer getter from unreachable cleanup
bytes. Its fake `RET 8` at `0x713497` made callers appear to consume two nonexistent
stack arguments. Native continuation arithmetic establishes the actual path:

| CALL | Pushed return address | Trampoline adjustment | Actual continuation |
|---|---|---|---|
| `0x71348F` → `0x7134AE` | `0x713494` | `+0x31` | `0x7134C5` |
| `0x7134CE` → `0x7134EA` | `0x7134D3` | `+0x2E` | `0x713501` |
| `0x71351C` → `0x713534` | `0x713521` | `+0x2A` | `0x71354B` |

Each continuation starts with `POPAD`, balancing its preceding `PUSHAD`. The real
epilogue loads the result at `0x7135C5`, restores EDI/ESI/EBX at
`0x7135C8`/`0x7135C9`/`0x7135CA`, and executes `LEAVE; RET` at
`0x7135CB`/`0x7135CC`. Thus the getter takes ECX=this, no stack arguments, and
preserves these three registers. Native bytes are in `native-xtea-getter-bytes.txt`;
function-bounded trampoline captures are in `followup/`.

Signatures for `XteaProtectedInt_Get` (`0x713482`), its jump alias `0x7132EC`,
and `CRole_GetTileCoordinatesFromXteaFields` (`0x651875`) were corrected.
The latter's actual `RET 4` is at `0x651899`; it receives one output pointer and
reads protected containers at role`+0x318` and `+0x334`. Fresh native SSA now
tracks this output pointer correctly, replacing the prior spurious `arg4`.

The three arithmetic/comparison wrappers also have proven `RET 4` signatures:
`0x7132FD` adds an offset, `0x713309` subtracts it, and `0x713315` returns
Boolean **not equal** in AL (`SETNE` at `0x713320`, `MOV AL,CL` at `0x713323`).
The latter two were renamed `XteaProtectedInt_GetMinusOffset` and
`XteaProtectedInt_IsNotEqual`, removing misleading map-specific names.
Upper EAX bits are not cleared by the Boolean wrapper and are not its Boolean result.

Restoration now includes **14 signatures and 160 function name/comment records**.
These repairs require refreshed downstream SSA before using old caller summaries;
they do not by themselves give gameplay identities to the six unresolved numeric fields.

### Handler-local value use and recovered helpers

Structured native export now supplies operand identities and formal-parameter order for
3,704 functions, with no export errors (`native-structured-ssa/status.json`). This is a
read-only export from the already-open, licensed UI BinaryView; no database save or byte
patch was performed. `native-formal-parameters.json` preserves these parameter mappings.
In particular, `0x5DFDAD` takes the output control-block address first and the role pointer
second; the old text model incorrectly treated the renamed `role` argument as argument zero.

Native RTTI closes this pointer-retention route: `0x5DFDAD` allocates a `0x14`-byte
control block, installs vtable `0x868948` at `0x5DFDD5`, stores the hero pointer at
block`+0x0C` at `0x5DFDE5`, and the deleter byte at `+0x10` at `0x5DFDEB`.
The vtable's disposal slot `+0x04` is `NoOpFunction_Return` (`0x6AF263`). Its
get-deleter slot `+0x0C` is `0x5DFEC0`, which compares the requested type against
TypeDescriptor `0x938940` at `0x5DFECC`. The descriptor name at `0x938948` is
`.?AV?$TDoNothingDeleter@VCHero@@@@`. Matching requests receive block`+0x10`;
other requests receive null (`0x5DFEDC`). This is a non-owning hero control block,
and this disposal path does not consume numeric hero state. The functions are now
`SharedPtr_CreateNonOwningHeroControlBlock` and
`SharedPtrHeroControlBlock_GetDoNothingDeleter`; both names/comments are preserved.
This excludes this specific retained-pointer route, not every possible heap alias.

Native SSA for `0x764276` shows only the defining load and destination store for
each of the six unresolved input values: `0x7643E9` → `0x7643EC`, `0x7643FD` →
`0x764400`, `0x764411` → `0x764414`, `0x764844` → `0x764847`, `0x7645C1` →
`0x7645C5`, and `0x76454E` → `0x764552`, respectively. There is no second direct
use of these loaded values within this handler. The last store is one native DWORD
instruction despite byte-split typed MLIL. This closes a handler-local dataflow question;
it does not establish that the destination fields have no consumers elsewhere.
Evidence: `six-field-packet-value-uses.json`; the Process function comment records the scope.

The interrupted helper captures below have now succeeded. `0x71D7C4` is
`PointerDeque_EnsureBackMapCapacity`, calling `PointerDeque_RecenterOrGrowMap`
(`0x71D7EA`) when its pointer map has insufficient space. Audited receivers are
hero`+0x1180`, `+0x11A8`, and `+0x11D0`; the latter helper accesses header offsets
`+0x04..+0x24` and separately allocated map storage. `0x73B936` is
`Vector12_DestroyElementsAndReleaseStorage`: on receiver hero`+0x1078`, it reads
the vector header and destroys heap elements of size `0x0C` before deallocation.
It does not reset the header. These paths do not access the six target fields.
All three names/comments were applied in Binary Ninja and preserved in
`restorable-annotations.json`, which now contains 160 records. Native captures are in
`followup/`. The earlier timeout is historical, not an active blocker.

### Prior candidate-model checkpoint

The persisted 2026-09-21 run covers **3,701 native function captures**, **4,511 receiver
states**, and **705 return summaries**, converging after six summary passes. It reports
29 target-access candidates: known packet/constructor writes and previously reviewed bounded
equipment loops. It reports 16 dynamic receiver states, four pending receiver states in two
uncaptured callees, 94 synthetic memory-operation states, and no call-depth truncation.
These are candidate-model counts, not an exhaustive dead-field proof.

The model follows direct and tail calls, affine returned aliases, explicit singleton/global
roots, entity-reference output storage, and register arguments of generic calls. Memory-SSA
versions now distinguish overwritten stack slots. For example, the resolver output pointer
at `0x659553` uses the address stored at `0x659552`; the same stack storage is later used
for a text buffer at `0x65A448`. Treating the slot name alone as a permanent hero alias
incorrectly produced unrelated text-processing consumers.

The previous missing constructor provenance is repaired by the eight native-verified
signatures documented below. The model now connects the known `+0xCE4` and `+0xF34`
constructor stores to the incoming hero. The four inline-state zero stores are independently
proved by actual instructions above; synthetic memset grouping must not hide those writes.

At that checkpoint the two pending native captures were **`0x71D7C4` and `0x73B936`**. Their requests timed
out after the native endpoint stopped responding; even its status query timed out. The function
declaration read failed with `timed out awaiting tools/call after 300s`. A later status check
still timed out. Do not interpret the transport failure as native behavior.
No Binary Ninja save, shutdown, restart, or executable-byte patch was performed.

Further closure requires native review of omitted stack arguments in generic calls,
remaining indirect/escaped aliases, parameter mappings, and bulk accesses. The model does
not resolve every such case. Its completed direct-callee expansion in an earlier narrower
run did not establish whole-program coverage. The 42 captured trampoline edges are verified;
the broader 979 clean-file pattern matches remain candidates, not a complete reachability proof.
This was the pre-reconciliation checkpoint. The current historical-name/compatibility verdicts
are at the top; this model did not itself establish those names or exhaustive deadness.

### Durable evidence and restoration

The native capture directory is
[10_work/docs/evidence/msguserinfo-1006-5517](../../10_work/docs/evidence/msguserinfo-1006-5517/).
It includes the complete handler SSA, caller/helper IL and disassembly, raw-offset candidate
census, singleton xrefs, native vtable bytes, receiver seeds, and the42 trampoline edge proofs.

[restorable-annotations.json](../../10_work/docs/evidence/msguserinfo-1006-5517/restorable-annotations.json)
contains 160 current function name/comment records. This is the restoration source if unsaved
Binary Ninja changes are lost. Existing meaningful names/comments were preserved. The user
handles database saving; no GUI save or executable-byte patch was performed.

The old receiver-model artifacts are retained for reproducibility, not as instructions to
resume broad expansion. Continue from the focused historical reconciliation and
`historical-reconciliation.json`. All model output is explicitly a candidate generator; native instructions and receiver
provenance decide each conclusion. The clean executable SHA-256 remains recorded at the top
of this audit. OpenConquerPublic changes from this investigation are documentation/comments;
its working login was user-reported, not a new native login test performed by this audit.


### Availability and verification at checkpoint

After the consolidation above, both the native MCP status call and its local HTTP endpoint
returned connection-refused on2026-09-18. Further live helper/prototype checks have therefore
not been completed. Previously captured native IL remains available; it does not justify
inventing a register-preservation contract when its inferred stack model is itself in question.
That outage and those helper checks were subsequently resolved. This paragraph records the
historical checkpoint, not the current continuation instruction.

The clean executable SHA-256 was rechecked and matches the value at the top of this document.
All relative links in this audit resolved locally at the checkpoint. A fresh diff inspection of
OpenConquerPublic's `MsgUserInfo1006.cs` found only comment changes from this investigation;
no serialization behavior was changed. No fresh native login test was performed.


## Constructor receiver break: native cause established, 2026-09-18

MCP connectivity was restored and Conquer.exe.bndb explicitly selected (view9). Native
assembly establishes that the apparent constructor register clobbers were analysis artifacts:

- `0x7132AF`, renamed `XteaProtectedInt__Ctor`, saves EBX/ESI/EDI and restores them
  at `0x7132E1`..`0x7132E3`, returning with RET0 at `0x7132E4` and EAX=this.
  It creates four random key dwords and calls the protected setter with value0.
- Setter `0x713328` takes ECX=this and one stack dword. Its real continuation chain is
  CALL `0x713345` -> `0x713371`, CALL `0x71337A` -> `0x7133A7`, and
  CALL `0x7133BF` -> `0x7133EF`. After the native four-round arithmetic loop, it
  restores EDI/ESI/EBX and executes **RET4** at `0x71347F`. The apparent RET at
  `0x71334E` is a junk fallthrough. Native bytes are retained in `native-xtea-setter-bytes.txt`.
  The wrong inferred cleanup shifted the caller's simulated POPs, creating a false ESI clobber.
- Constructor `0x739C8D` installs vtable `0x86C730`, returns EAX=this, and restores
  EDI/ESI/EBX at `0x739D7E`..`0x739D80`; LEAVE/RET0 is `0x739D88`/`0x739D89`.
  No gameplay class identity is assigned solely from this constructor.
- `0x403E9D`, renamed `NullTerminatedCharVector_ConstructFromCString`, initializes
  three pointers and copies a C string. It preserves ESI at `0x403EE2`, returns EAX=this,
  and executes **RET8** at `0x403EEB`. Caller `0x655D09`/`0x655D0A` pushes both
  construction arguments. The second argument's historical type is not asserted.

The four native function signatures were corrected to thiscall with their proven stack cleanup.
Names/comments were recorded in `restorable-annotations.json`; exact signatures are now also
preserved in `restorable-prototypes.json`. This fixes a concrete obstacle to the receiver audit,
not the gameplay identity of any of the six unresolved packet fields. The fresh constructor
capture and receiver check below verify the repair; current coverage is recorded above.


The nested signature audit also established: `0x73B446` RET8 (`0x73B493`),
`0x689886` RET4 (`0x689892`), `0x68992B` RET8 (`0x689933`), and
`0x40473E` RET12 (`0x404775`). Their callers push exactly those stack sizes.
Native `0x40473E` restores EDI/ESI/EBX at `0x404772`..`0x404774`.
These four signatures were corrected too, preserving existing meaningful names;
`0x73B446` is now `MotionPathNodeDeque__Ctor` (constructs the object subsequently
passed to `MotionPathNodeDeque_ClearAndResetCursors` in `0x739C8D`). Native assembly
and refreshed SSA are preserved in `followup/`; restoration includes eight signatures.


### Receiver repair verified after native reanalysis

Fresh BN MLIL-SSA for CHero constructor `0x655194` now preserves the incoming hero
through calls `0x655233`, `0x6553AB`, and `0x655D13`: none falsely produces a new ESI.
The known zero stores `0x655DC3` and `0x655DEB` now trace to the original receiver's
`+0xCE4` and `+0xF34`. `constructor-receiver-repair-check.json` records the positive-control
result, and the refreshed complete SSA is `followup/0x655194.mlil.json`.
The eight signature corrections therefore resolve this specific missing-constructor-provenance
problem. The broader model was rerun; its coverage and remaining gaps are recorded above.
This positive control does not prove any numeric field dead or semantically identify it.
Six numeric semantic targets remain open.


## Auth string-validation evidence delta — 2026-10-18

The previously excluded malformed-list boundary is now covered by the [native auth string-validation closure](Native-auth-string-validation-2026-10-18.md).
It distinguishes ignored index1 payload from its unchecked structural length,
proves missing/overlong name and spouse clearing, and traces EntityId0 through
hero mutation to the zero-length-send socket error without a hero rollback.
AUTH-001P comparison is pinned to PR#134 head, including its acceptance of
present empty strings and EntityId0 in an immutable snapshot.
