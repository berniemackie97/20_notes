# CP2.3a — typed world dispatch native preflight

**2026-11-06 · static clean-5517 evidence · bounded to types 10010, 1016, 10017.**

Target: `00_clean/clean/5517-bninja/Conquer.exe.bndb`, active Binary Ninja view 9.
Executable SHA-256: `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
No native execution or packet capture was performed. No BNDB was saved.

## Existing evidence reused

| Source | Scope reused |
|---|---|
| [00_protocol_overview.md](00_protocol_overview.md), CP0.1 tables | Type-to-constructor/process registry and TU class proof: 10010 is CMsgAction; 10017 is CMsgUserAttrib, obsolete Ex name withdrawn. |
| [dispatch-registry-2026-11-05](evidence/dispatch-registry-2026-11-05/) | Existing dispatch assembly, type registry and rename history; selected assembly bytes are reverified here. |
| [01_core_packets.md](01_core_packets.md), MsgAction and weather sections | Fixed action builder layout, trailing string-list boundary, four weather fields and existing normalization audit. |
| [07_world_packets.md](07_world_packets.md), weather | Component consumer and parser/process addresses. |
| [21_msgaction_0061_syndicate_bootstrap.md](21_msgaction_0061_syndicate_bootstrap.md) | Header-copy distinction, 38-byte builder emission, action-specific semantics. |
| [11_else_branch_packets.md](11_else_branch_packets.md), MsgUserAttrib | Header, stride, attribute consumers. The broad entry+12 padding label is corrected below for status25. |

This inventory covers the prior evidence relevant to these three codecs; it is not an exhaustive audit of all world packet handlers.

## Raw authority and dispatcher

Selected instructions are in [evidence/typed-world-dispatch-2026-11-06](evidence/typed-world-dispatch-2026-11-06/). `verify-code.py` checks every recorded instruction and data window against the hashed PE.

The native dispatcher `0x6DF3B5` obtains a 16-bit type, selects the registered class, constructs it and invokes vtable +4 Parse at `0x6E1365`. Reused CP0.1 routes lead to action ctor `0x6FE8A3`, weather ctor `0x760667`, attribute ctor `0x7572EB`. Their vtables independently link parser / Process pairs:

| Type | Vtable | Parse slot +4 | Process slot +16 |
|---|---|---|---|
| 10010 / 0x271A | 0x86BAD8 | 0x6FEB93 | 0x6FED1F |
| 1016 / 0x03F8 | 0x86D4E0 | 0x7607DE | 0x760801 |
| 10017 / 0x2721 | 0x86D0B0 | 0x757351 | 0x757374 |

Each wrapper calls `CNetMsg__ValidateHeaderAndCopy` (`0x6DF2AE`) then compares the type word at object+6, i.e. packet+2. Type comparisons are at `0x6FEBA9`, `0x7607F4`, `0x757367`; the last parser's `SETE`, not comparison, is at `0x75736D`.

The common validator checks nonnull source, header size equality with **low16(caller size)** (`cmp si,ax`, `0x6DF2C7`), and nonzero type, then copies caller-size bytes. These wrappers do not enforce the managed exact 38/20/`12+20*n` rules. Dispatcher `0x6DF3D8` rejects signed caller size above 0x400. A modern typed dispatcher is a managed ownership/validation design; this evidence does not require mirroring native allocation or unsafe tolerance.

## 10010 action / correction layout

Offsets are relative to the packet header, little endian. The native builders emit a fixed 38-byte base; string data may follow it for other action subtypes.

| Offset | Width | Field / proof |
|---|---|---|
| 0 / 2 | u16 / u16 | Size / type; builder stores 0x26 and 0x271A at 0x6FEA15 / 0x6FEA20. |
| 4 | u32 | Entity id; 0x6FEA45. |
| 8 | u32 or two u16 | Action-specific parameter pair; full builder uses word stores at 0x6FEA92 / 0x6FEAA0. |
| 12 | u32 | Action-specific parameter; dword read at 0x6FEFC9. |
| 16 | u32 | Timestamp; 0x6FEA38. |
| 20 | u16 | Action discriminator; native dispatch load 0x6FED46. |
| 22 | u16 | Direction; 0x6FEA6A. |
| 24 / 26 | u16 / u16 | X / Y; builder 0x6FEA4E / 0x6FEA5C; correction reads 0x6FFCEC / 0x6FFCF3. |
| 28 / 32 | u32 / u32 | Data1 / Data2; 0x6FEA85 / 0x6FEAB0. A typed combined u64 is only a lossless grouping. |
| 36 | u8 | Action-specific flag; mounted builder writes 1 at 0x6FEB17. |
| 37 | u8 | String-list count boundary, reused existing constructor/string-list evidence (0x6FE8EA), not an extra dword. |

The correction action 108 is reached by the accumulated subtraction cascade at `0x6FFC36..4B`. The local resolved role is checked against the hero at `0x6FFCBF..D0`; its tile is read from +24/+26 as unsigned words.

Offsets 12/22/28/32/36 are **not universally reserved native bytes**. Current managed action108 requires them (and +8) to be zero, requires a hero target, accepts only the fixed length and zero string count, and ignores timestamp. Preserve these rules as managed validation policy in this slice. The full native correction response, coordinate/UI effects, other subtypes and tolerance are not reimplemented here.

## 1016 weather layout

The body is four 32-bit fields at packet+4 kind, +8 intensity, +12 direction, +16 parameter. Process `0x76080A..13` pushes all four DWORDs into `ValidateAndNormalize`; stores `0x760785/791/79A/7A3` establish the rebuilt field widths, and `0x76076E` sets size20.

Current managed validation uses exact20, kinds1..11 except6, intensity0..1022, direction0..359, and retains the raw tuple. Native range validation uses signed comparisons and rebuilds/normalizes the tuple before its weather component consumes it. The existing kind6 switch gap, direction conversion and mapped weather kinds remain documented in prior notes; CP2.3a does not change that policy or claim rendering parity.

## 10017 attribute layout and status high64 correction

| Offset | Width | Raw proof |
|---|---|---|
| 4 | u32 transport field | Target id passed to resolver at 0x757396. |
| 8 | u32 transport field | Entry count read at 0x75745D and 0x758B92. Native loop comparisons are signed; do not infer safe count validation. |
| 12 + 20*i | u32 | Attribute id; `i*5<<2` at 0x757469..6C, DWORD load 0x75746F. |
| entry+4 | u64 | Low payload, two adjacent dwords. Attribute-specific consumers determine interpretation. |
| entry+12 | u64 | High payload; meaningful for status25, not universal padding. |

Status25 jump-table slot `0x758D7D` contains `0x7574C5`. That path computes packet+16+20*i (`0x7574DA`) and copies **16 bytes** (`0x7574E3..EA`) into a local status value. It later passes that whole local to role vtable+0xD0 at `0x757712`. Thus the 20-byte entry consists of a 4-byte id plus 16 payload bytes; a low64/high64 DTO preserves the status width. Note11's entry+12 “padding / unused” description is overbroad. Other attributes may use only a subset; this finding does not establish new semantics for their high64.

Preserve current managed exact `12+20*count` length, bounded decoding, entry order, low/high bits, foreign-target skip and diagnostics. Native fallback processing is different and is outside CP2.3a.

## Fixtures and remaining boundaries

[wire-layout-golden.json](evidence/typed-world-dispatch-2026-11-06/wire-layout-golden.json) offers independently specified little-endian sentinel frames plus verified native code windows. Provenance is **static-disassembly-derived synthetic golden**, never captured native traffic or runtime output. All-fields action108 deliberately violates current managed ingress policy: it checks codec field preservation and the separate policy rejection. Weather checks full-width parameter retention; attributes check a wide low64 and nonzero status high64. Existing bootstrap packet vectors can additionally cover action38 read/write compatibility.

Recommended behavioral fixtures: exact/truncated/overlong headers; count multiplication boundaries; preserve unknown action/attribute IDs for existing diagnostics; repeated attribute order; correction restrictions one field at a time; foreign target; weather existing bounds and kind6 rejection. Rejection cases prove managed policy, not native rejection.

| Question | Status |
|---|---|
| Field offsets, widths and three type/parser links needed by current handlers | Proven statically; byte-verified. |
| Status25 high64 significance | Proven statically; prior broad padding label corrected here. |
| Exact-length and generic reserved-zero rules as native requirements | Not proven and not claimed; these are retained managed policy. |
| Native tolerance, broader gameplay semantics, normalization parity, foreign-role behavior | Deferred CP2.4. |
| Live native input/output, running client smoke, platform/lifecycle behavior | Not observed by this evidence task. |

Binary Ninja changes were made and read back before this note: weather parser renamed `sub_7607de` → `CMsgWeatherUpdate__Parse`; attribute parser `CMsgUserAttribEx__Parse` → `CMsgUserAttrib__Parse`; scoped parser comments and status-copy instruction comment. [binja-annotations.json](evidence/typed-world-dispatch-2026-11-06/binja-annotations.json) records the results. Existing comments' semantic information was preserved. No shared roadmap/ledger or production source was edited.

# CP2.3b — 1008/1009 codecs, snapshot slots, clamp order (2026-11-06)

Registry (CP0.1 `registry.json`): 1008 ctor `0x762A3A`, vtable `0x86D650`, parse `0x762AA0`, process `0x762AC3`, class unproven. 1009 ctor `0x6EABEB`, vtable `0x86B8CC`, parse `0x6EAE56`, process `0x6EAEB6`, applied label `CMsgItem`, with assert TU `MsgItem.cpp` and unverified C++ class declaration. Field layouts are reused from `03_item_packets.md`, `08_system_packets.md` and `MsgItem1008-domain-contract-5517.md`; no new field semantics.

Managed codec fields (only those consumed today):

| Type | Offset | Width | Use |
|---|---|---|---|
| 1008 | +4 / +8 | u32 / u32 | item UID / item type |
| 1008 | +12 | u16 | current durability |
| 1008 | +16 | u8 | action (1 add, 3 update consumed) |
| 1008 | +18 | u8 | position (0 inventory) |
| 1008 | +33 / +36 | u8 / u8 | ItemAdd level / enchantment life |
| 1009 | +4 / +8 | u32 / u32 | subtype-specific params A / B |
| 1009 | +12 | u16 | subtype |
| 1009 | +20 | u32 | list count (subtype 5) |
| 1009 | +84 + 4i | u32 | listed UIDs |
| 1009/46 | +0x20 + 4i, i<13 | u32 | snapshot UIDs |

Retained managed policy (not native rules): 1008 exact 68; 1009 ≥14, consumed subtypes 3/5/6/17/46 need `88 + 4n`, subtype 46 exact 88, subtype 5 count ≤ n.

## CP2.3b snapshot slot audit

Disassembly `0x6EC20A..0x6EC458`, read in Binja 2026-11-06. Each block: push `[packet+off]` → `CHeroItem__FindTrackedItemByUid` → push slot → `CHeroItem__SetEquipSlot`.

| Offset | Slot | Push slot | SetEquipSlot |
|---|---|---|---|
| +0x20..+0x28 | 1..3 | `0x6EC224/252/280` | `0x6EC230/25E/28C` |
| +0x30 | 5 | `0x6EC2AE` | `0x6EC2BA` |
| +0x2C | 4 | `0x6EC2DC` | `0x6EC2E8` |
| +0x34..+0x40 | 6..9 | `0x6EC30A/338/366/394` | `0x6EC316/344/372/3A0` |
| +0x48 | 16 | `0x6EC3C2` | `0x6EC3CE` |
| +0x44 | 15 | `0x6EC3F0` | `0x6EC3FC` |
| +0x4C / +0x50 | 17 / 18 | `0x6EC41E/44C` | `0x6EC42A/458` |

Result: offset→slot ascending; current managed `[1..9,15..18]` correct. Notes 14/08 `{1,2,3,5,4,…,16,15,…}` = call order; corrected. Binja comments `0x6EC29E`, `0x6EC3B2` added, read back.

Open (parked, not CP2.3): `CHeroItem__SetEquipSlot` case 3 (slot 4, `0x6DAA61..0x6DAB23`) may move the slot-5 item to inventory when the new item is two-handed (`CItem__IsTwoHandedWeapon`, `CHeroItem__TryAddInventoryItem` `0x6DAB0A`). With call order 5→4 this can empty slot 5 after the snapshot set it. Managed sets slots independently. HLIL conditions unresolved; needs instruction-level proof before modeling.

## CP2.3b snapshot clamp order

Native: clamp inside subtype 46 after `CHero__RefreshEquipmentDerivedStats` (`0x6EC479..0x6EC4C7`), synchronous, packet-ordered. CP2.2 managed: one pending flag consumed at next HUD draw → later 10017 life writes in the same batch were clamped retroactively.

Contract: item tables load before world state exists (world construction; failure = content-unavailable close). Model owns max-life inputs (item table, map flags, transform guard, tier 0). Hydration and live 1009/46 clamp at the snapshot. No pending flag, queue or buffering. Transform look active: clamp skipped (max-life transform input unsupported; unchanged from CP2.2, where the draw gate never consumed it).
