# MsgItem 1008 — item state and persistence contract

Clean English 5517 `Conquer.exe` and `GameData.dll`; native evidence reviewed 2026-09-25.

## Authority and result

Native instructions and shipped assets establish the client contract below. They cannot establish
retail server tables, an ID allocator, offline expiration policy, or the complete set of values a
retail server permits. **Persistence classifications and C# types are recommendations**, not claims
that the retail server used those tables/types. No modern production implementation was changed.

Evidence: [captures and provenance](../../10_work/docs/evidence/msgitem-1008-domain-5517/).
The captures include raw assembly, HLIL and MLIL; **raw operand widths override misleading HLIL**.
`Conquer.exe` SHA-256: `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
DLL/asset hashes are in `asset-provenance.json` in that evidence directory.

Three previous premises are disproved:

- `+0x34` is **composition progress**, not a status-clear mask or lifetime.
- **Subtype 1 hydrates local inventory and tracked equipment.** Subtype 4 hydrates the inspected
  `CDummy`, and its `+4` value is checked as the inspected-role identity.
- `+0x14` has **three verified uses**: talisman socket progress, steed packed color, and the
  Cloud Saint's Jar monster-kill baseline. Socket progress is not proved for all non-steeds.

Two compatibility bytes remain semantically unresolved. Their absence from identified gameplay
consumers is **not** a proof of dead code. The exact limits are recorded below.

## Complete local-item snapshot table

Offsets are hexadecimal from the packet header. Destination offsets are from `CItem`, unless stated.
Classification legend (each row has exactly one category):

- **P** = `Persistent server-owned state` (persist the domain concept/relation, not necessarily a duplicate column).
- **S** = `Derived from static game data`.
- **W** = `Calculated/transient wire state`.
- **U** = `Reserved / genuinely unresolved`.

An overloaded P field contains instance state for the applicable family; a family that ignores an
input does not require a second persisted copy. Static defaults do not make mutable instance fields
static-owned. No client-read instance field below is proved to be exclusively S. Static stack
capacity, base attributes, lifetime defaults and composition requirements are S inputs to the table.

| Packet offset / width | Semantic / proposed domain name | Native destination / decisive evidence | Class | Confidence / encoding and zero |
|---|---|---|---|---|
| `+0x00` u16 | `PacketLength` | framing; MsgItem parser `0x762AA0` | W | Header, not item state. This contract uses the established 68-byte row; last read ends at `+0x42`. |
| `+0x02` u16 | `PacketType` | parser `0x762AA0`, type 1008 | W | 1008. |
| `+0x04` u32 | `ItemId` for subtype 1/3; subtype 4 `InspectedRoleId` | `+0x0C`; `0x67AD73..0x67AD8D`; dummy comparison `0x66CEEC` | P | Native nonzero identity required by initializer. Subtype 4 is a protocol projection of role identity, not a new persistent item identity. |
| `+0x08` u32 | `ItemTypeId` | `+0x1C` static-record key; `0x67AD77..0x67AD8D`, loader `0x67ABB5` | P | Nonzero, successful native itemtype lookup required. |
| `+0x0C` u16 | `Durability`; arrows `ArrowQuantity`; jar kill-display threshold | `+0x194`, setter `0x67D820`; new-row call `0x762E32` | P | Exact integer units; zero accepted and marks equipment broken. Arrow quantity zero is not normalized by `+0x40`. Jar consumer `0x57C438`. |
| `+0x0E` u16 | `MaximumDurability`; arrows capacity; jar monster-counter key | `+0x54`, `0x762E44` | P | Raw word; zero accepted by store, not proved valid for every type. Do not apply one durability interpretation to all item families. |
| `+0x10` u8 | `ItemSnapshotKind` | dispatcher `0x762ADE` **MOVZX BYTE**, switch `0x762AEB` | W | Local create 1; local update 3; inspected equipment 4. 6 ignored. |
| `+0x11` u8 | `RetailCompatibilityByteA` | `+0x56`, `0x762E51/0x762E54` | U | Width/store/copies proved; meaning unresolved. Static token 23 is zero in every clean itemtype row. |
| `+0x12` u8 | `ItemWirePlacement` projected from `ItemLocation` | routing `0x762FC6/0x762FF4/0x763048` | W | 0 inventory; equipment encoding below. Not an arbitrary persistent container byte. |
| `+0x13` byte | unconsumed alignment byte | no read in `0x762AC3` | U | Zero when constructing a row; no wider protocol meaning claimed. |
| `+0x14` u32 | `TalismanSocketProgress` / `SteedAppearanceColor` / `MonsterKillCounterBaseline` | `+0x14C`, setter `0x67C794`, new-row call `0x762EEB` | P | Family-dependent; exact discriminators below. Zero means zero progress/color/baseline, not a universal default. |
| `+0x18` u8 | `Socket1` (`SocketState` / `SocketGemCode`) | `+0x57`, `0x762E63`; talisman consumer `0x57F056` onward | P | Zero is absent socket in verified talisman path. Keep the gem-code catalog separate; no invented complete gem enumeration here. |
| `+0x19` u8 | `Socket2` | `+0x58`, `0x762E72`; `0x57EFE0` | P | Same width; second-socket progression checks zero. |
| `+0x1A..0x1B` 2 bytes | unconsumed alignment | no read in this handler | U | Zero-fill; not gameplay state. |
| `+0x1C` u32 | `HiddenAttackEffect` | `+0x5C`, `0x762E81`; tooltip read `0x57BED3` | P | 200 poison, 201 life recovery, 202 mana recovery, 203 defense improvement, using StrRes11084..11088. Zero adds no hidden-effect line in this consumer. Other legal server values unproved. |
| `+0x20` u8 | `RetailCompatibilityByteB` | `+0x60`, `0x762E8D/0x762E90` | U | Meaning unresolved; static zero-based token 27 has 0..8. Do not call it SoulCategory solely from asset correlation. |
| `+0x21` u8 | `AdditionLevel`; steed lineage level | `+0x61`, `0x762E9F`; cache refresh `0x762EA2` → `0x67AC6B` | P | Unsigned byte, zero no addition. Setter does not establish a universal legal gameplay maximum. Steed visual/composition consumers also use it. |
| `+0x22` **u8** | `DamageReductionPercent` / `SteedCompositionRed` | `+0x168`, `0x762EB4`; `0x67CC66`, tooltip `0x57F3C6`; steed `0x4CE94D` | P | Raw subtype-4 proof `0x762C28 MOVZX BYTE`. Normal tooltip StrRes10465 `Damage -%d%%`; category14 excluded from ordinary reduction getter. Zero accepted. |
| `+0x23` u8 | `ItemBindingCode` | `+0x1A4`, derived mask `+0x1A8`; setter `0x67CB82`, call `0x762FA3` | P | Codes 1/2/3 produce restrictions `0x1F`; all other codes produce zero. Individual 1/2/3 identities unresolved; use raw code, not a guessed three-value enum. |
| `+0x24` u8 | `EnchantmentLifeBonus` / `SteedCompositionGreen` | `+0x16C`, `0x762EC7`; life stat path and steed `0x4CE983` | P | Zero-extended byte. Ordinary equipment contributes this life bonus except steed slot12; steed uses green channel. Zero legitimate absence. |
| `+0x25..0x27` 3 bytes | unconsumed alignment | no read in this handler | U | Zero-fill. |
| `+0x28` u32 | `MonsterRestraintId` / `SteedCompositionBlue` | `+0x170`, `0x762ED9`; `0x57A0FF`, `0x4CE9AC` | P | Restraint zero gives no description; clean table IDs1..5. `0xFFFFFFFF` skips hero right/left restraint overwrite. It is not a general default. Steed blue is stored as u32, unlike byte R/G. |
| `+0x2C` **u16 boolean** | `IsSuspicious` | `+0x1AD`, `0x762F0A CMP WORD`, call `0x762F12` | P | Zero false, any nonzero true; encode 0/1. Does **not** overlap status. StrRes11160/11161 via `0x57FA3F..0x57FAE4`. |
| `+0x2E` u16 | `EquipmentLockState` wire mask | `+0x1A0` replacement snapshot; `0x762F1A..0x762F2E` | P | 0 no known lock bits, mask0x0001 locked, mask0x0002 unlock pending. Unknown bits retained by input store but unproved gameplay meaning. |
| `+0x30` u16 | `EquipmentColor` (texture variant) | `+0x19C`, setter `0x67C755`; call `0x762F90` | P | Ordinary input stored as selector. Steed overwrites it with packed-color*100+addition at `0x67C782`; do not persist a second steed selector. No universal zero-color default proved. |
| `+0x32..0x33` 2 bytes | unconsumed alignment | no read in this handler | U | Zero-fill. |
| `+0x34` u32 | `CompositionProgress`; steed lineage progress | `+0x160`, setter `0x58CDDF`; `0x762EF9/0x762EFC` | P | Zero genuine zero progress; equipment tooltip `0x579D86`, steed `0x57E7B3`. Not a status operation. |
| `+0x38` u32 | `InscribedSyndicateId` / `ItemArsenalInscription.SyndicateId` | `+0x17C`, setter `0x67B0A6`; `0x762F3F` | P | Zero unregistered; `0x70A2F7/0x70A2FA` supplies hero's syndicate ID; unregister `0x70A250` supplies zero. Not a boolean. |
| `+0x3C` 32 bits, signed use | `WireLifetimeSeconds` calculated from `ItemLifetime` | `+0x158`, activation `+0x164`, start tick `+0x15C`; `0x762F50` → `0x67C05C` | W | Nonzero starts timer; zero static fallback. Negative is **not clamped**. Lifetime policy below. |
| `+0x40` u16 | `StackQuantity` wire projection | `+0x190`, `0x762FB6` → `0x67D80C` | P | 0 normalizes to1; 1..65535 stored without capacity clamp. Arrows use durability instead. Legal stacks bounded by type-specific capacity, not wire width. |
| `+0x42..0x43` 2 bytes | unconsumed tail in 68-byte envelope | no read in this handler | U | Zero-fill. Last field read is the word at `+0x40`. |

## Overloads and decisive consumers

### `+0x14`: separate typed concepts

`CItem_GetEquipmentCategory` (`0x67AD9A` → `0x67AF1A`) recognizes steed category14
when `(ItemTypeId % 1_000_000) / 1000 == 300` and `ItemTypeId % 10 == 0`.
The packed-color read in `0x4CE91C..0x4CE947` decomposes R/G/B; use `SteedAppearanceColor`.
The input is u32 even though the visible channels are RGB. No proof that the server derives this
field from the three composition components: **do not collapse those persisted concepts by assumption**.

For category12 (the 201/202 talisman families), `ItemTipBase_AppendTalismanSocketProgress`
(`0x57EFE0`) tests category at `0x57F042`, then sockets. Getter calls `0x57F082/0x57F0EC`
format StrRes11518 `Socket Progress: %d/%d`; first threshold 8000, second 20000.
The UI callers `0x4E75D1/0x4E802D` use the same progress. These are UI goals, not proof
of all server-side cap/overflow rules.

For **exact ItemTypeId750000** (`0xB71B0`, clean `CloudSaint'sJar`),
`ItemTipBase_AppendMonsterHunterJarProgress` (`0x57C438`) checks type at `0x57C47E`,
looks up a hero counter using maximum durability as key (`0x6637E4`), reads `+0x14C`
at `0x57C4BC`, and subtracts it at `0x57C4CA`. StrRes11048 displays `Killed: %d`.
Current durability is compared with this difference at `0x57C4D8` to choose display color;
that comparison alone does not establish the server quest-completion rule. The counter lookup
can request MsgInteract subtype `0x24`; it is not ordinary durability math.
Use `MonsterKillCounterBaseline` and type-specific jar state. Other families' accepted storage
of this dword does not establish an additional gameplay identity.

### `+0x28`: restraint lookup, not “green text”

At `0x57A0D9..0x57A0FF`, a nonzero value for a non-steed calls RoleDataQuery vfunc+`0x98`.
The vtable cell `GameData.dll:0x10017180` points to `0x10005871`, which searches the map at
provider+`0x54`. Loader `GameData.dll:0x10005890` opens `ini/restrain.ini` at `0x100058BB`,
parses `%u %u %s` at `0x10005928`, and inserts at `0x10005982`. The returned record's
`+4` string is displayed in green at `0x57A11B`. Clean IDs1..5 each have multiplier2 and
monster-specific double-damage descriptions. This identifies a **monster restraint table key**;
it does not prove the server's damage implementation. Right/left-hand equip propagation reads
it at `0x6DAB7E/0x6DABF0`, skips `0xFFFFFFFF`, otherwise stores the low word to hero
`+0x8C0/+0x8C2` at `0x6DAB90/0x6DAC02`.

For steeds, `0x4CE85B` reads R (`0x67D748`), G (`0x67D74F`), B (`0x67D756`).
The preview multiplies in 32-bit registers and divides unsigned: each component is
`((main*90) mod 2^32)/100 + ((minor*10) mod 2^32)/100`, with integer truncation.
For channel inputs0..255 this is `floor(90*main/100)+floor(10*minor/100)`. It then packs
`(((R << 8) + G) << 8) + B`, with 32-bit shifts/additions, at `0x4CE9FD`. This is native **preview** arithmetic;
server composition policy and its legal input ranges are not recoverable from that alone.

### Composition, suspicion and binding are different concepts

Composition assignment is literal:

```text
762EF9  push dword [eax+34h]
762EFC  call 58CDDF
58CDE3  mov  dword [ecx+160h],eax
```

Equipment tooltip `0x579D86` uses StrRes11208 `Progress: %d/%d` and next-level requirement
getter `0x67B33B`; steed tooltip `0x57E7B3` uses `STR_MOUNT_ITEM_TIP_APPEND_EXP` (`Lineage: %d`).
`0x4CDDE5` previews steed progress and level contributions; its preview limit is not a universal
server persistence cap.

Suspicion tooltip `0x57F9FF` calls `0x67CBB8` at `0x57FA3F`: StrRes11160 says
`Suspicious Item`, and 11161 describes the system checking the item within three days.
Binding tooltip `0x57E660`, test `0x57E692`, checks all restrictions `0x1F` and displays
StrRes11319 `Bound item (Untradable...)`. Neither is the equipment-lock bitmask.

## Equipment-lock state, including the alternate packet

Raw replacement sequence, not a set/clear pair from the wire:

```text
762F1A  push edi                     ; edi = FFFFFFFFh
762F1B  call CItem_ClearStatusMask    ; 67BF4F: NOT/AND at67BF55
762F29  movzx eax,word [eax+2Eh]
762F2E  call CItem_AddStatusMask      ; 67BF5E: OR at67BF62
```

Subtype4 repeats at `0x762C92/0x762C93/0x762CA1/0x762CA6`. Thus every such snapshot
sets `CItem+0x1A0 = zero_extend(packet.u16(+0x2E))` and clears any previous upper bits.

Meaningful consumers: `0x42BD7C` tests2 and selects `REBIND_CONFIRM`; `0x42BDB3` tests1
and selects `UNBIND_CONFIRM`; neither selects `BIND_CONFIRM`. `0x42C090..0x42C0F9`
binds the matching `EquipTie_ReTieBtn/RavelTieBtn/TieBtn` assets. StrRes11191 says
`%s is unlocked!`; 11192 formats an unlock date. Therefore use `EquipmentLockState`
(`Unlocked`, `Locked`, `UnlockPending`) separate from `ItemBindingCode` and `IsSuspicious`.
Both bits set are accepted; the pending path takes priority. This does not establish that3
is a legal retail-server state. Preserve unsupported raw bits only in compatibility storage.

`CMsgItemStatus__Process` **2048** (`0x6E70E7`) modes0/1 and3 also clear(-1) then
read **u8 at+9**, raw `0x6E749E` / `0x6E7203`. Its dword+`0x0C` is **packed unlock date** (`year*10000 + month*100 + day`), not amount. Formatter `0x67BF6B` stores it at item+`0x1B0`, derives
`date/10000`, `date%10000/100`, `date%100`, and writes the StrRes11192 description at
`+0x1B4`. The formatter does not prove a two- versus four-digit year convention.
Mode2 supplies/query-refreshes the date; mode3 clears the date and posts
unlocked notification (`0x6E7240/0x6E7252`). Mode4 posts `0x4B7`.
`0x67B93F` lazily requests mode2 if pending and the cached date is zero. Persist the server's
lock state and unlock schedule; the cached text/request marker is client-only.

The complete captured direct callers of mask OR/clear/get/test are in `67bf5e.xrefs.json`,
`67bf4f.xrefs.json`, `67b938.xrefs.json`, `67c729.xrefs.json`. Other hydration writers
use u8 (`0x74E6B4/0x74E91B`) or u16 (`0x75E155/0x75FBC0/0x75FE94/0x76021F/0x760563`).
Cloners `0x495991/0x694D1E` copy the mask; they do not originate higher bits.
**No meaningful lock mask beyond0x1/0x2 or upper-16-bit hydration path was established.** The dword
member itself is not proof of a 32-bit server status domain. This conclusion is bounded to
these traced sources/consumers, not an assertion about unanalysed indirect aliases.

## Timer: native behavior and the server-policy boundary

`CItem_ApplyWireLifetimeSeconds` (`0x67C05C`) uses signed seconds:

- Nonzero: store at `+0x158`, activate `+0x164` via `0x67C13E`, timestamp client tick at
  `+0x15C` via `0x67C050`. Negative values temporarily clear at `0x67C076` but are
  **restored at `0x67C0CA`** and activated; they are not normalized to zero.
- Zero: lookup static ItemType record+`0x58` (text token39); positive minutes multiply by60
  at `0x67C0AF`. Otherwise the setter leaves duration unchanged. Zero does not clear an
  existing activation flag/start tick. Constructor `0x67A6F7` zeroes those fields for a new item;
  loader `0x67ABED` initializes duration from static minutes.
- `CItem_FormatLifetimeRemaining` (`0x67C169`) uses inactive duration or
  `startTick + duration - currentTick`, then formats days/hours/minutes.
  `0x5AFD4C`, timer test then1000ms reset at `0x5AFD8F`, increments the counter at
  `0x5AFD92`. This is a client timer, not an absolute server timestamp or proof of wall-clock catchup.
- MsgTick1009 subtype41: inventory lookup `0x6EBDEF`, inactive test `0x6EBE02`, activation
  `0x6EBE13`. The activation packet does not itself convey a new duration.

Recommended `ItemLifetime`: permanent, pending activation with duration, or active expiry.
For a chosen **real-time-expiry policy**, persist `ExpiresAtUtc` (and activation provenance
where needed), calculate bounded positive remaining seconds at send time, and remove/expire
an item rather than encoding an expired timer as zero. **Retail offline ticking versus pausing
is unresolved**; if policy pauses offline, persist remaining budget plus accounting/activation
state instead. Do not pretend the client chooses one policy. Do not persist a continually
decaying seconds field as the only durable fact. No exact server clock/rounding policy is proved.

## Stack semantics

`0x67D80C` stores `max(signedArgument,1)` at `+0x190`; MsgItem supplies a zero-extended word.
It does not clamp to itemtype capacity. Getter `0x67D7EF` returns that field except for arrows,
where it returns **current durability `+0x194`**. Arrow predicate `0x5681F9` tests equipment
category0 and subtype50000. Capacity getter `0x67D7D5` uses arrow maximum durability
`+0x54`, otherwise static record+`0x94` / item+`0xB0`, itemtype text token47.

Native capacity checks `0x6DCC65` use this per-type capacity; new-slot calculations at
`0x6DCD5C` normalize capacity with `max(1,capacity)`. The 14,981 decoded primary `ini/itemtype.dat` rows have
capacity0/1 and several larger capacities, maximum100. A larger-than-one capacity is the
static basis for stacking; do not infer stackability merely from equal type IDs or a u16 wire.
A non-stackable item should serialize1;0 is a redundant encoding of1. Use a type-derived
quantity invariant and distinct arrow quantity projection. **65535 is accepted storage width,
not a proved legal quantity for every type**. The binary does not prove which differing
instance attributes a server permits to merge into one stack.

Inventory `0x6D9357..0x6D936B` checks40 entries with an arrow exception. Native presentation
capacity is not a database row-count invariant without applying that distinction.

## Subtype1, subtype4 and GetItemSet

| Property | Subtype1 | Subtype4 |
|---|---|---|
| Context | Local hero inventory / tracked equipment | Equipment of the inspected `CDummy` |
| `+4` | Stable local item identity | Inspected-role identity checked against dummy+`0xA88` |
| `+0x12` | 0 inventory; nonzero tracked placement | Zero rejected at `0x762AF7`; nonzero normalized |
| Field layout | Reads table above through `+0x40` | Same offsets/widths through `+0x40`, including identity's different role |
| Local marker `+0x165` | 1 at `0x762F5A` | 0 at `0x762D0A` |
| Destination | inventory `0x763048`; track `0x762FF4` and stat refresh `0x763000` | hero+`0x1EA0` at `0x762D4B`, call `0x66CECF` at `0x762D51` |
| Notification | inventory/equipment and lock notifications | posts `0x432` at `0x762D68`, without testing setter success |

`CDummy_SetInspectedEquipmentSlot` (`0x66CECF`) compares final argument against `this+0xA88`
at `0x66CEEC`; callsite pushes packet+4 at `0x762D15`. It stores shared references at
`this+0xA98 + 8*(slot-1)`, not the local hero table. Its assertion names `3DRole/Dummy.cpp`
at `0x66CF6E`. `CDummy_RefreshInspectedRoleAndRequestEquipment` (`0x66C9A3`) stores the
identity at `0x66C9C1`, pushes it at `0x66CD3D`, builds **MsgAction117 (0x75 hex)**
(push `0x66CD4F`, Create call `0x66CD55`), and sends at `0x66CD64`. Do not confuse action117 with **GetItemSet75 (0x4B)**.

Fresh subtype1 positions1..9/21..29 enter the tracked-position map but do **not alone activate**
main equip references. `CHeroItem__TrackItemAtPosition` (`0x6DB021`) overwrites its map entry
at `0x6DB068/0x6DB071`; positions10..18 call the active setter directly at `0x6DB0A7`.
Other positions refresh only an already-active pointer-identical item (`0x6DB0E7`).

MsgTick1009 **subtype46 (0x2E)** resolves tracked UIDs and activates the ordinary slots:

| Packet UID offset | Slot | `CHeroItem__SetEquipSlot` call |
|---|---|---|
| `+0x20` | 1 | `0x6EC230` |
| `+0x24` | 2 | `0x6EC25E` |
| `+0x28` | 3 | `0x6EC28C` |
| `+0x2C` | 4 | `0x6EC2E8` |
| `+0x30` | 5 | `0x6EC2BA` |
| `+0x34` | 6 | `0x6EC316` |
| `+0x38` | 7 | `0x6EC344` |
| `+0x3C` | 8 | `0x6EC372` |
| `+0x40` | 9 | `0x6EC3A0` |
| `+0x44` | 15 | `0x6EC3FC` |
| `+0x48` | 16 | `0x6EC3CE` |
| `+0x4C` | 17 | `0x6EC42A` |
| `+0x50` | 18 | `0x6EC458` |

It sets equipment mode from+8 at `0x6EC46D` (`0x6DAE7C`: main/sub mode text), then refreshes
stats at `0x6EC479`. Thus the recommended deterministic sequence is **subtype1 item rows →
active-equipment UID snapshot when needed → action75 echo**. Row-before-UID-resolution is a
native data dependency; the complete sequence is a server recommendation, not a captured retail
server trace. No general inventory-row-before-equipment-row requirement was found in the handler.

The action75 receive branch `0x6FF26C` pushes action76 at `0x6FF3E8`, builds it at `0x6FF3F4`, sends
at `0x6FF424`, then posts `0x401` at `0x6FF42F`. There is no item-count/minimum-item test.
**An empty item set can advance with the final action75 echo alone.** No need to re-open the
already-established general world-entry ladder.

## Equipment placement table

Normalize function `0x6DADB1` is authoritative. Slot names are supported by
[category/position guards and model consumers](../Server/equipment.md), `0x6DA906`,
and clean itemtype families. The table is an encoding contract, not permission to equip any type
in any nonzero slot.

| Wire position | Canonical `EquipmentSlot` | Equipment set / note |
|---|---|---|
| 0 | none | Inventory in subtype1; invalid in subtype4 |
| 1 / 21 | Headwear | Main / Alternate |
| 2 / 22 | Necklace | Main / Alternate |
| 3 / 23 | Armor | Main / Alternate |
| 4 / 24 | RightHand | Main / Alternate |
| 5 / 25 | LeftHand | Main / Alternate |
| 6 / 26 | Ring | Main / Alternate |
| 7 / 27 | Bottle | Main / Alternate; clean MiraculousGourd type2100025 |
| 8 / 28 | Boots | Main / Alternate |
| 9 / 29 | Garment | Main / Alternate |
| 10 | AttackTalisman | Fan family201; no alternate encoding here |
| 11 | DefenseTalisman | Tower family202 |
| 12 | Steed | Category14 |
| 13, 14 | no active slot | Track map accepts these keys, but normalizer returns0 and active setter skips them. Not legal production equipment slots. |
| 15 | RightWeaponAccessory | Native right-hand accessory visual input |
| 16 | LeftWeaponAccessory | Native left-hand accessory visual input |
| 17 | SteedArmor | Family200; mount model propagation `0x6DAC84` |
| 18 | RidingCrop | Family203 |
| 19, 20, 30..255 | invalid | Normalizer returns0; track function rejects outside1..18 or21..29 |

Positions21..29 normalize to1..9. Preserve `EquipmentSet` and `EquipmentSlot` separately;
normalizing alone loses alternate placement. `ItemWirePlacement` is a serializer projection.
Duplicate raw tracked positions overwrite a reference; duplicate inventory UIDs are rejected at
`0x6D938A/0x6D9399`. Tracked positions do not establish UID uniqueness across slots, and the
active setter does not perform a server-grade displacement transaction. Enforce unique item
location and unique equipment `(owner,set,slot)` in the server rather than copying this weakness.

## Ownership, identity and the recommended C# domain boundary

**Native proof:** item identity is a u32 at `CItem+0x0C`; initializer `0x67AD6B` rejects zero
UID and zero type, requires a successful static lookup, then stores UID at `0x67AD8D`.
No million-based allocation floor or player/item disjoint numeric range is checked there.
The inspection role path separately tests role identity >999999 at `0x66CAD7`; that actor
predicate must not be transferred to the item initializer as an ItemId constraint.
Inventory, tracked and active equipment hold shared `CItem` references; equipment moves in
MsgTick subtype5/6 (`0x6EAEB6`) resolve the existing item by UID rather than inventing identity.
ItemStatus2048 searches local hero items, package/storage (`0x6AA0DD`), and the additional
hero item set (`0x667B5B`), with secondary warehouse view (`0x685DCE`) for mode2.
This demonstrates identity-based cross-container lookup, **not retail database global uniqueness**.

**Recommended design, not native database evidence:**

- `ItemId` is a stable nonzero uint value object, distinct from `CharacterId`, `EntityId`,
  `ItemTypeId` and `SyndicateId`. Never construct an item UID from a hash, clock truncation,
  slot, owner, or a player-ID offset. Use an allocator with atomic uniqueness/exhaustion checks
  over the item namespace. Client evidence supplies no safe special reserved ranges.
- `ItemInstance` owns identity and mutable instance attributes. `ItemOwner` and `ItemLocation`
  are separate concepts. A location can be inventory, equipment, warehouse/storage, ground,
  or escrow; use typed payloads (storage identity, map instance/coordinates, equipment set/slot).
  Which account/character/guild can own each storage is server policy, not specified by MsgItem.
- Inventory→equipment and ownership-preserving storage movement keep the same identity.
  Trade UI display is a view, not proof that ownership already transferred. Atomically move
  ownership/location on the server's actual successful transfer. A ground representation need
  not use the identical packet layout; do not infer a ground packet contract from MsgItem.
- Enforce one current location per item, referential integrity, unique equipped slots and
  transactionally safe transfers. `character_items` may be a placement relation, but should not
  define the lifetime of item identity or make character ownership permanent.
- Named instance concepts: `AdditionLevel`, `SocketState`, `HiddenAttackEffect`,
  `DamageReductionPercent`, `EnchantmentLifeBonus`, `ItemBindingCode`, `IsSuspicious`,
  `EquipmentLockState`, `EquipmentUnlockSchedule`, `EquipmentColor`, `CompositionProgress`,
  `ItemArsenalInscription`, `MonsterRestraintId`, `TalismanSocketProgress`, `SteedAppearanceColor`,
  `SteedCompositionComponents`, `MonsterKillCounterBaseline`, `ItemLifetime`, `StackQuantity`.
  Serialize overloaded concepts by the native discriminator; do not build a universal
  `CompositionOrFlag` property. Keep unresolved compatibility bytes outside the gameplay API.

## Explicit unresolved facts and search boundary

1. **`+0x11 → item+0x56`**: parser `0x677A95` stores itemtype token23 at record+`0x3A`
   (`0x678024`); initializer clears it at `0x678948`. All 14,981 clean records contain zero.
   Clones read/copy at `0x495AA9/0x495AAC` and `0x694D97/0x694D9A`.
   Record copies `0x465E50/0x465E53`, `0x679901/0x679904` preserve it.
   No gameplay identity established. Do not call it identification or a proven retired field.
2. **`+0x20 → item+0x60`**: parser stores token27 at record+`0x44` (`0x678100`), default
   clear `0x678955`; clones `0x495AD5/0x495AD8`, `0x694DC7/0x694DCA`; record copies
   `0x465E68/0x465E6B`, `0x679919/0x67991C`. Static values0..8 exist; nonzero records
   correlate with DragonSoul equipment families. **That is an asset observation, not native
   proof of the packet field's gameplay meaning.** No verified semantic consumer was found.
   Zero is accepted and common, but not proved correct for every item type.
3. Direct getter/setter xrefs, captured CItem methods, packet writers, constructors, itemtype
   parser/copies and function-start-aligned byte-displacement candidates were checked for both.
   Same offsets on `CMyGrid`, MFC controls (`0x5A9CA5/0x5E0214`) and unrelated `0x699E2F`
   receivers are not CItem proof. `0x5A9D58` has a UI-vtable reference, not a demonstrated
   CItem caller. `compatibility-byte-candidates.json` is a candidate census, **not exhaustive
   proof against rebased/indirect aliases**, and may include decoded jump-table data. Do not
   relabel either field dead. Use `RetailItemCompatibility` containing
   `RetailCompatibilityByteA/B`; preserve captured values for existing items. A zero-emitting
   limited profile must be explicitly described as such, not full semantic closure.
4. Binding codes1/2/3 share restrictions but their individual distinctions remain unproved.
   Lock masks beyond0x1/0x2 have no established meaning; no higher-bit hydration source is proved.
5. The unlock-date year/century convention and exact retail offline timer policy, server clock/rounding, server composition/stack merge
   rules, valid-value limits beyond checked client predicates, and retail database ID allocator,
   reserved namespace ranges and cross-container global uniqueness are **not established**.
6. The client does not prove that steed appearance color equals a derivation from the three
   composition components, nor a universal `+0x14` meaning for every other item family.

These limits prevent calling this a completely verified final gameplay schema. The corrected
wire/routing facts are usable now; unresolved concepts must remain explicit before schema freeze.
