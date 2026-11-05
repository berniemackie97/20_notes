# `CHero::GetEffectiveMaxLife` / `GetEffectiveMaxMana`

`CHero_GetEffectiveMaxLife` `0x65D06D`, `CHero_GetEffectiveMaxMana` `0x65D25A`.

These are the values the HUD's HP and MP gauges are ranged against every frame by
`CDlgMain_UpdateGaugeRangesFromHero` (`0x4BD53E`) — see
[13_hud_progress_gauges.md](13_hud_progress_gauges.md). They are also the reason those gauges are
not percentage gauges.

**Both were read byte-exact rather than from HLIL**, because each contains a descending if-chain
whose arms share a store instruction; the decompiler folds them and renders arms that did not
execute together. Max life: `0x65D0C9`–`0x65D132`. Max mana: `0x65D285`–`0x65D318`.

## Shared gate helpers

| Function | Behaviour |
|---|---|
| `CGameMap_HasFlags64HighBit6_Analyst` (`0x6206C8`) | `(CGameMap_GetFlags64() & 0x0000004000000000) != 0` |
| `CRole_HasTransformLook` (`0x650B4C`) | `role+0xEC != 0` |

**Correction 2026-10-09:** `0x6206CD` clears EAX, and `0x6206CF` masks EDX (the high half) by 0x40.
The old low-0x40 predicate/name was wrong. The replacement is an analyst numeric name; its retail
feature name remains unproven. See the [map audit](../Server/map-identity-flags-native-5517.md).

### Where the map flags come from

`CGameMap_GetFlags64` (`0x61F2DA`) returns the pair `CGameMap+0xE8` (low) and `CGameMap+0xEC`
(high). The packet setter is `CGameMap_SetFlags64` (`0x61F2C3`), and its only caller is
`CMsgMapInfo1110__Process`, which stores packet `+0xC` into `+0xE8` and packet `+0x10` into `+0xEC`.
So the whole word is server-sent, in packet **1110**, whose managed reader
(`MsgMapInfo1110PacketReader`) carries exactly those four fields — map id at `+4`
(`CGameMap_ApplyMapIdAndRefreshWorldState`), map document id at `+8`
(`CGameMap_SetMapDocumentId`), flags low at `+0xC`, flags high at `+0x10`.

Two predicates relevant here read different parts of that word (other native predicates also exist):

| Predicate | Mask |
|---|---|
| `CGameMap_HasFlags64HighBit6_Analyst` (`0x6206C8`) | qword `0x0000004000000000` / high `0x40` |
| `CGameMap_HasOverlayRenderModeFlag` (`0x61DFF5`) | `0x400000` |

HLIL renders the second mask as `&__dos_header` because `0x400000` is also the image base; the raw
instruction is `and eax,0x400000` at `0x61DFFD`.

`CMsgMapInfo1110__Process` samples `CGameMap_HasFlags64HighBit6_Analyst` both before (`0x732B4F`) and after
(`0x732D00`) the store and calls `CHero__RefreshEquipmentDerivedStats` when it changed — that is the
path by which the bit reaches these formulas. It branches on the overlay mask at `0x732CAC`, posting
main-window message `0xBF9` when set and `0xDDC` when clear.

### What `role+0xEC` is

`role+0xEC` is `m_Info.nTransformLook` — the role's transformation look id, `0` when untransformed.
Proven from `CRole__SetTransformLook` (`0x650B58`), which is `CRole::Transform` in eosource
`3drole/Role.cpp:1376`: it writes `arg1[0x3b]` (= `+0xEC`) and carries the same CHECK-string path
`3DRole\Role.cpp`.

The value is **sticky**. With a non-zero look the function stores it *only* when the transform table
lookup (`RoleData` vtable `+0x28`, `RoleDataSingleton_LookupTransformLookRecord`,
`GameData.dll:0x100028BF`) finds a record; a look with no record leaves `+0xEC` at its previous
value. With look `0` it clears `+0xEC`, resets `+0x174` to `0` and `+0x184` to `0x64`, and reapplies
the visual sources.

The look itself is derived from the appearance composite carried by **MsgUserAttrib attribute id
`0xB`** (`0x757AC7`), read as a u64:

```
meshTransformId       = value / 10000 % 1000
role+0x178 (flag digit) = value / 1000 % 10
bodyAppearanceSourceId = value % 1000

group = value / 10000000            ; 0x989680
if group != 0:
    look = group * 10
    if role+0x178 != 0 and transformTable has (look + role+0x178):
        look = look + role+0x178
else:
    look = 0
CRole__SetTransformLook(role, look)
```

`CMsgPlayer__Process` (`0x756BA4`) calls `CRole__SetTransformLook` on the spawn path as well.
The transform table is `ini/Transform.ini`, already parsed managed-side by
`TransformLookIniTable`.

## Max life

```
A = (hero+0x514 > 0) && CGameMap_HasFlags64HighBit6_Analyst()
B = CRole_HasTransformLook(hero)
if (A || B) return hero+0x514;          // the normal formula runs only when !A && !B
```

Note that the `B` arm returns `hero+0x514` **without** requiring it to be positive, so a role with
`+0xEC` set and no override reports a maximum of zero. That is faithful, not a transcription slip.

```
base = (strength[+0x4FC] + agility[+0x504] + vitality[+0x508] * 8 + spirit[+0x50C]) * 3

// profession bonus, ONLY when (prof % 1000) / 10 == 1   (professions 10..19)
t   = prof % 10
pct = { 1:5, 2:8, 3:10, 4:12, 5:15 }, else 0
base += (pct * base) / 100              // SIGNED idiv, truncates toward zero

// equipment, slots 1..0x12 inclusive, via CHeroItem__GetEquipSlotItemRef
//   skipped entirely when CItem_IsBrokenOrDisabled(item)
base += (int16)CItem_GetEffectiveLife(item) + *(item+0x180)
if (slot != 0xC) base += CItem_GetEnchantmentLifeBonus(item)
if (primaryRefinementEffectId == 0x12D) base += primaryRefinementValue
if (primaryRefinementEffectId <  0x64 && secondaryRefinementEffectId == 0x12D)
    base += secondaryRefinementValue

if (CGameMap_HasOverlayRenderModeFlag(map)) base += hero+0xCB0

d = CHero_GetPackedPerTypeLevelDigit(hero, 9)
if (d > 0 && d <= 9) base += { 0,100,200,300,400,500,600,800,1000,1200 }[d]

return base >= 0 ? base : 0
```

The tier table is built on the stack as a zero followed by a nine-dword `memcpy`, then indexed as
`(&var_40)[d]` — so index 0 is the zero and the shipped constants occupy 1..9, matching the guard.

## Max mana

Deliberately **not** symmetric with max life. Three differences worth stating, because assuming
symmetry produces wrong values:

1. the override gate does **not** consult `role+0xEC`;
2. the profession gate is `(prof % 1000) / 10 > 10` — an **unsigned** compare — where max life uses
   `== 1`;
3. the profession result **replaces** the multiplier rather than adding a percentage.

```
if (hero+0x518 > 0 && CGameMap_HasFlags64HighBit6_Analyst()) return hero+0x518;

spirit = hero+0x50C
result = spirit * 5                     // default

if ((prof % 1000) / 10 > 10) {          // unsigned
    t = prof % 10                       // signed comparisons below
    t >= 5 -> spirit * 30
    t >= 4 -> spirit * 25
    t >= 3 -> spirit * 20
    t >= 2 -> spirit * 15
    t >= 1 -> spirit * 10
    t == 0 -> keeps spirit * 5
}

// equipment: 18 iterations from hero+0xE8C, stride 8, RAW pointer (not the shared_ptr accessor)
if (*p) result += (int16)CItem_GetEffectiveMana(*p)

return result >= 0 ? result : 0
```

No overlay bonus and no tier table.

## Managed mapping

The equipment loops for both formulas already exist as
`ClientWorldLocalHeroItemStatResolver.Compute`, which returns raw `MaxLife` / `MaxMana`
contributions and deliberately does not clamp — the clamp belongs to the enclosing formula, exactly
as native has it.

The remaining inputs all live on `ClientWorldLocalHeroStatState`: the four attributes, `Profession`,
`MaximumLifeOverride` (`+0x514`), `MaximumManaOverride` (`+0x518`) and `OverlayMaxLifeBonus`
(`+0xCB0`). The two map/role gate flags and the packed per-type level digit are supplied by the
caller, since they are not packet-owned state.

## HUD binding

The gauges reach these formulas through `ICDlgMainGaugeReadingSourceRuntime`, a seam that returns
`(Value, SecondaryValue, RangeMaximum)` per ANI section name. `CDlgMainHudUiRootRuntime.Draw`
refreshes every gauge's range from that source **before drawing any of them**, mirroring
`CDlgMain_UpdateGaugeRangesFromHero` running first in the native render routine.

Ranging goes through `ResetValueRange`, never `SetValueRange`: only the former recomputes the
pixels-per-unit scale, and the fill geometry depends on that scale. Using the wrong one leaves the
bar keyed to the previous maximum, which is a silent visual bug rather than a crash.

`CDlgMainGaugeReadingFromWorldStateRuntime` is the concrete projection. It serves five gauges. The
only gauge that reports no reading is the XP control whose ANI section is absent:

| Gauge | Why it is not served |
|---|---|
| `Progress44` | no `Progress44` section exists in the shipped `Control.Ani` |

### HP and MP second values are modeled

Native passes two different quantities to `Show`. For HP the pair is FDword index 1 against index
15. For MP the pair is current mana at `hero+0x5E0` against the follower at `hero+0x768`, read by
the `CHero` vtable `+0xB0` function.

Managed state now retains both followers. `ICDlgMainGaugeReadingSourceRuntime.AdvanceFrame` runs
once before the HUD range-update loop, advances both values with the verified native rule, and the
HP/MP readings pass those retained values as `SecondaryValue`. Equal values still select the
single-fill branch after convergence; the dual-fill branch appears while current life or mana is
rising faster than its follower.

## Gap closure pass

Everything below was verified in response to "what are we still missing" — the inputs my managed
formula consumes had been inherited from existing field names rather than checked.

### The override and overlay offsets are confirmed

`ClientWorldLocalHeroStatState` names three fields fed by `MsgUserAttrib` ids 1, 3 and 43. Each id
was traced to its actual store, and all three match what the formulas read:

| Attrib id | Native path | Field |
|---|---|---|
| `1` | CHero vtable `+0xC8` → `sub_673193` | `hero+0x514` — also notifies `role+0x3B4` with `(0x15, value)` |
| `3` | `sub_6731B8` | `hero+0x518` |
| `43` | `sub_65AACA` | `hero+0xCB0` |

The managed `MsgUserAttribExAttributeId` enum also matches native's switch on the two current-value
ids that matter here: `CurrentLife = 0` (→ `sub_673eac(role, 1, v)`) and `CurrentMana = 2`
(→ `CHero_SetCurrentMana`).

### FDword index 15: the delayed-rise follower of current life

This was previously recorded as unidentified. It is the **trailing bar** value.
`CHero_PerFrameTickAndSubsystemUpdate` (`0x65E128`–`0x65E167`):

```
current  = GetPlayerDataByIndex(hero, 1)
smoothed = GetPlayerDataByIndex(hero, 15)
maxLife  = CHero_GetEffectiveMaxLife(hero)

if (smoothed < current)
    smoothed += (maxLife >= 80) ? maxLife / 80 : 1     ; signed idiv
smoothed = min(smoothed, current)                       ; never exceeds current
setIndex15(smoothed)
```

So it snaps **down** instantly when life drops and climbs back at `maxLife / 80` per frame when life
rises. That is exactly the current/target pair `CMyProgress::Show` draws with frames 1 and 0.

`CMsgItem__Process` (`0x6EC485`–`0x6EC4C7`) also writes it, which is why the "never comes off the
wire" claim in the gauge note was wrong:

```
maxLife = CHero_GetEffectiveMaxLife(hero)
if (GetPlayerDataByIndex(hero, 1) > maxLife) {
    vtable[0xA4](maxLife)
    setIndex1(maxLife)          ; clamp current life down to the new maximum
    setIndex15(maxLife)
}
```

The managed binding retains this follower in `ClientWorldRoleStateStore`. It begins at zero, advances
once per rendered world frame before gauge reads, and is reset to the clamped maximum by the subtype
46 equipment snapshot path exactly where native writes index 15.

### The MP gauge uses the same follower rule

Native's second argument is `CHero_GetManaGaugeFollower` (`0x67347B`, vtable `+0xB0`). It reads the
protected dword at `hero+0x768` through `CProtectedDword_GetValue` (`0x713E03`). The complete tick
loop at `0x65E1C9`–`0x65E24C` proves its semantics:

```
current  = CHero_GetCurrentMana(hero)                  ; hero+0x5E0
follower = CHero_GetManaGaugeFollower(hero)            ; hero+0x768
maxMana  = CHero_GetEffectiveMaxMana(hero)

if (follower < current)
    follower += (maxMana >= 80) ? maxMana / 80 : 1     ; signed idiv
follower = min(follower, current)
CHero_SetManaGaugeFollower(hero, follower)              ; vtable+0xB4
```

Thus MP snaps down immediately when current mana falls and rises gradually at the same rate rule as
HP. `hero+0x5E0` is live current mana, not a smoothed value; `CHero_SetCurrentMana` additionally
notifies the local-hero timer at `hero+0x2C30` when mana decreases.

Initialization is also closed. `CHero` construction builds the protected-value state at `hero+0x4F0`;
the nested constructor calls `CProtectedDword_ConstructZero` (`0x7136A6`) at offsets that resolve to
`hero+0x5E0` and `hero+0x768`. That constructor writes logical value zero. Binary Ninja now types
both fields as `CProtectedDword` and names the four mana accessors accordingly.

### Remaining current-life packet coverage

The writer is `CRole_SetPlayerDataByIndex` (`0x673EAC`), the counterpart of
`CHero_GetPlayerDataByIndex`: it stores into the obfuscated `FDword` container at `role+0x978` via
`sub_749E47(container, value, index)`. Index 1 is current life. When the role is the local hero,
index is 1, and the new value is **lower** than the current one, it first pokes `hero+0x2C30`
(`FrameTickPerfTimer_RecordDeviceResetStart`) — the took-damage hook. A null container is a no-op.

It has nine call sites; five write index 1: `CMsgUserInfo__Process`, `CMsgUserAttrib__Process`,
`CMsgPlayer__Process`, `CMsgItem__Process` and `CMsgInteract__Process`. Managed now covers the
`MsgUserInfo`, `MsgUserAttrib`, subtype-46 `MsgItem`, and three verified `MsgInteract` paths. The
remaining uncovered writer is the remote-player spawn path described below.

**`CMsgItem__Process` subtype 46 is the complete equipment snapshot plus clamp.** Packet offsets
`0x20` through `0x50` contain 13 item UIDs mapped in order to slots
`{1,2,3,5,4,6,7,8,9,16,15,17,18}`. Native resolves each UID with
`CHeroItem__FindTrackedItemByUid`; zero or missing UIDs clear that slot. After
`CHero__RefreshEquipmentDerivedStats`, it recomputes `CHero_GetEffectiveMaxLife` and, **only when
the current index 1 exceeds it under a signed comparison**, writes the maximum into vtable `+0xA4`,
index 1 and index 15. After that optional clamp, it unconditionally posts message `0x464` with
`wParam` values `0x3EB`, `0x3FB`, `0x445`, `0x446`, `0x4FE` in that exact order and `lParam = 0`
for every post.

Managed packet parsing, the 13-slot UID snapshot, appearance projection, effective-max recomputation,
and the current-life/index-15 clamp are implemented. The native recipients of all five UI commands
are now identified in `Network/08_system_packets.md`. None has a managed consumer yet: the current
UI does not implement the NPC-goods inventory grid, item shortcut bar, query/sub-profession/sub-weapon
pages, battle-level dialogs, or VIP repair-all dialog. No synthetic message queue or revision counter
was added merely to preserve the native MFC/Flash dispatch shape.

**`CMsgInteract__Process` applies damage locally**, in three subtype arms:

| Subtype | Site | Effect |
|---|---|---|
| `0x0E` | `0x6FBE79` | index 1 set straight to `0` |
| `0x2D` | `0x6FD6E6` | `max(0, life - packet+0x18)`, and stores the amount at `role+0x97C` |
| `0x38` | `0x6FCB47` | `max(0, life - packet+0x18)` |

`packet+0x18` is an overloaded `dwData` field, **not** only an interaction type: the mutual
interaction subtypes `0x2F`–`0x32` read that same offset as the `100000`–`100010` interaction types
the managed `MsgInteract1022Packet.InteractionType` already models, while these combat subtypes read
it as a damage amount. The managed name is correct for the subtypes it serves; the field is a union.

All three guards were read from raw bytes rather than HLIL:

```
; 0x6FCB27 (subtype 0x38) and 0x6FD6CA (subtype 0x2D)
8b 4d ec                    mov  ecx, [ebp-0x14]          ; target role
81 b9 cc000000 3f420f00     cmp  dword [ecx+0xCC], 0xF423F
0f 87 .. / 77 ..            ja   skip                     ; id > 999999 -> no damage
6a 01                       push 1
e8 ..                       call CHero_GetPlayerDataByIndex
8b 8e 04040000              mov  ecx, [esi+0x404]
2b 41 18                    sub  eax, [ecx+0x18]          ; SIGNED subtract
79 02                       jns  +2
33 c0                       xor  eax, eax                 ; floor at zero
50 / 6a 01 / e8 ..          call CRole_SetPlayerDataByIndex(role, 1, eax)

; 0x6FBE68 (subtype 0x0E)
8b 4d ec / 85 c9 / 0f 84 .. test ecx, ecx / jz skip        ; null-role guard only, no id range
33 db / 53 / 6a 01 / e8 ..  call CRole_SetPlayerDataByIndex(role, 1, 0)
```

Two consequences worth stating because they look like bugs and are not:

- The entity-id guard is **inclusive** (`ja`, not `jae`), so exactly `0xF423F` is still damaged.
- The subtract is **signed**, so a `dwData` with the high bit set *raises* current life instead of
  lowering it. `100 - 0xFFFFFFFF` is `101`, and `jns` keeps it.

Subtype `0x2D` additionally stores the raw amount at `role+0x97C`
(`89 81 7c090000`), which subtype `0x38` does not.

**`CMsgPlayer__Process` carries current life on the wire** at `packet+0x50`. Raw x86 resolves
all three arms and their precedence:

- the self-spawn guard returns before mutation;
- ids `<= 999999` first write the unsigned life word through player-data index 1 (`0x756407`);
- after non-Chinese `~`-to-space name normalization, an exact `Monster.dat` lookup plus nonzero
  `packet+0xB5` overwrites it with signed `(lifeWord * record.MaxLife) / 10000` (`0x7564EF`), with
  truncation toward zero;
- ids `> 999999` instead store the full `packet+0x50` dword at `role+0x848` (`0x756525`);
- later, entity classifier category 4 (`100001..199999`) and syndicate rank `packet+0x10` exactly
  `990` or `1000` overwrite index 1 with `lifeWord * 100` (`0x757224`).

The adjacent level field also follows the id split: u16 `packet+0x52` for ids `<= 999999`, u16
`packet+0x63` for ids above it. `packet+0x0C` / `+0x10` are syndicate id / rank, corroborated through
packet 1106 processing.

**Now implemented:** `ClientWorldRoleStateStore.ApplyInteractDamage` and `ApplyInteractLifeZeroed`
mirror the three arms, including the inclusive id guard, the signed wrapping subtract and the
zero floor; `ClientWorldInboundPacketApply.TryHandleInteract` routes subtypes `0x0E`, `0x2D` and
`0x38` to them. `role+0x97C` is not stored yet — nothing managed reads it.

The managed `MsgPlayerSpawn10014PacketReader`, `MonsterDatTable`, and
`ClientWorldRoleStateStore.ApplyPlayerSpawn` implement these arms, including the word/dword packet
union, exact lookup, signed division, category/rank override, and native `Monster.dat` fail-stop
loading semantics.

### The equipment loop was audited too, not assumed

The managed formula consumes `ClientWorldLocalHeroItemStatResolver.Compute` without re-deriving it,
so that loop was checked against the byte-level reading rather than trusted:

| Native | Managed | |
|---|---|---|
| slots `1..0x12` (`i < 0x13`) | `slot = 1; slot <= 18` | ✓ |
| broken items skip the **life** terms only | mana added before the `IsBrokenOrDisabled` continue | ✓ |
| `if (i != 0xC)` excludes enchantment | `slot != EquipmentPosition.Steed`, and `Steed = 12` | ✓ |
| refinement effect id `0x12D` | `MaxLifeRefinementEffectId = 301` | ✓ |
| secondary gate `primary < 0x64` | `< 100` | ✓ |
| `movsx` on `CItem_GetEffectiveLife` | `ResolveEffectiveLife` returns `short` | ✓ signed |
| `movzx word [item+0x180]` | `ResolveItemAddLife` returns `ushort` | ✓ unsigned |
| `movsx` on `CItem_GetEffectiveMana` | `ResolveEffectiveMana` returns `short` | ✓ signed |

The signed/unsigned split on those two adjacent loads (`0x65D156` is `movsx`, `0x65D15B` is `movzx`)
is real and is reproduced.

`item+0x180` is the **ItemAdd record cache**, not a plain field.
`CItem_RefreshItemAddRecordCache` (`0x67AC6B`) fills it via
`GameDataSingleton_TryGetActionTypeRecordByDualKey(store, (normalizedType / 10) * 10,
CItem_GetByte61(item), item + 0x180)`, so the managed side recomputing the lookup from
`(NormalizeItemAddPrimaryLookupId(type), ItemAddLevel)` is an equivalent formulation rather than a
divergence, and `LifePayloadWordIndex = 0` matches native reading the record's first word.

### Production wiring

The projection is constructed in `SceneComposition` and handed to `CDlgMainHudUiRootRuntime`, so the
formulas are reachable from the running client rather than from tests only. Its four dependencies
all already existed on `RuntimeServices`: `RoleStateStore`, `LocalHeroItemStatResolver`,
`LocalHeroItemStore`, plus the environment.

**Historical managed parity claim withdrawn for the bit 38 gate (2026-10-09).** `CGameMapState`
stores the 1110 flags pair, but the existing managed `HasFlags64Bit0x40` property tests the low word.
The native `0x6206C8` predicate tests **high**0x40. The accompanying test that high bits affect neither
predicate is stale and is not native evidence. The overlay mask remains low 0x400000. Production
and test source were intentionally left untouched in this documentation-only audit.

**`RoleFlagAt0xEC` is now modelled too.** `ClientWorldRoleTransformLookState` holds `role+0xEC` per
role and reproduces the sticky rule: a requested look of zero clears it, a non-zero look is stored
only when `ini/TransForm.ini` has a matching record, and a look with no record leaves the previous
value in place. It is driven from both native producers —
`ClientWorldInboundPacketApply.TryHandlePlayerSpawn` (matching `0x756B68`) and the attribute-`0xB`
arm of `TryHandleUserAttribEx` (matching `0x757AC7`) — and `SceneComposition` reads the local hero's
entry for the environment.

A missing `ini/TransForm.ini` degrades to the empty table, which refuses every non-zero look; that
is the same outcome native reaches when the record lookup fails, so no role is reported as
transformed rather than some being wrongly reported.

`ClientWorldLocalHeroMaxStatEnvironment.NotYetModelled` is kept as the all-clear state — a real
native case, not a placeholder — and a test still pins that both formulas take their ordinary path
under it.

One residual: `Role3DClientSceneHudAndSoundStage` keeps a null-safety fallback that builds a HUD
root **without** a gauge source when none is supplied. `SceneComposition` always supplies one, so
the fallback only fires for stages constructed directly (tests). A future stage built without a
pre-made root would silently render no gauges.
