# MsgUserInfo 1006 semantic closure audit (2026-09-17)

This is a native-evidence investigation, not authorization to implement or rename unresolved protocol fields in production. Source: clean 5517 Conquer.exe, SHA-256 b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62, active Binary Ninja database Conquer.exe.bndb. The user retains responsibility for saving the database.

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

## Pending targets and proof standard

+32 -> hero+0x85C; +36 ->+0x844; +40 ->+0x848; +44 ->+0x8B8; +72 ->+0xF34; +74 ->+0xCE4; string entry 1 remain under investigation.

Earlier proximity/displacement scans in 01_core_packets.md are candidate searches, **not an exhaustive proof of dead fields**. Their same-offset hits must be checked with function boundaries and receiver provenance. No guessed gameplay names or dead-field verdicts are assigned here from those scans.

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

- Expanded raw-instruction candidate census: 1,410,457 decoded instructions, 197 candidate sites, 146 functions. Native functionAt membership was then obtained for every site, and full function-bounded HLIL and MLIL-SSA captured. Counts are search coverage, not a no-consumer proof.
- The old spawn discussion reverses the role-ID branches. Fresh native 0x755F64 shows ID >999999 takes the +0x848 dword write at 0x756525; ID <=999999 takes the protected life setter at 0x756407. Native 0x67350E checks IsPlayer() by rejecting ID <=999999, independently fixing the branch identity.
- Hero primary vtable slot +0xC4 points to 0x661F09, which was absent from BN's function list. It was defined and decoded: it reads +0x514, not any of the six target fields. Missing BN functions must not be treated as evidence of missing native consumers.
- Numeric targets +72 and +74 are one-byte wire values but **zero-extended dword stores** to hero+0xF34 and hero+0xCE4. Prior CHero type metadata splits +0xCE4 into a byte and padding; that metadata does not change the instruction width.
- The +66 wire bits are read with MOVSX at 0x764682. The baseline u16 wire-width description needs the explicit signed-16 interpretation when explaining native PK-point behavior.

All evidence is being retained under 10_work/docs/evidence/msguserinfo-1006-5517/. No implementation code has changed in this task.

The complete offset/width/destination/evidence/encoding table is maintained in
[10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md](../../10_work/docs/NATIVE_MSGUSERINFO_1006_5517.md).
It includes the unconsumed +83..84 span explicitly and marks the six numeric targets open rather
than inventing production property names. The clean INI defines class IDs1..6 and9; missing7/8
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
no-consumer claim. The six numeric fields retain their open status.
