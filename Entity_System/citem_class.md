# CItem & CItemData Classes — Item System
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Item.cpp / ItemData.cpp

---

## Item ID Structure (Conquer Online Item Type System)

The item ID (uint32) encodes the item's category, type, and quality through positional digits:

```
Item ID: AABBCCCD
  AA     = Major category (item_id / 100000 % 100)
  BBB    = Sub-type      (item_id / 1000 % 1000)
  CC     = Variant       (item_id / 10 % 100)
  D      = Quality tier  (item_id % 10)

Quality tiers (last digit):
  0-5 = Normal qualities
  6   = Super quality tier 1 (+4 socket score)
  7   = Super quality tier 2 (+3 socket score)
  8   = Super quality tier 3 (+2 socket score)
  9   = Super quality tier 4 (+1 socket score, also = socketable)
```

### Item Main Types (from GetItemMainTypeFromId @ 0x67AF1A)
```
Return  Condition                                   Description
------  -----------------------------------------   -----------
0       major_cat == 10                             Generic/consumable
1       major_cat == 1, sub in {11,14,17}           Helmet/headgear
        OR sub == 123
2       major_cat == 1, sub == 12                   Necklace
3       major_cat == 1, sub == 13                   Ring/bracelet
4       major_cat in {4,5}                          Weapon (one-handed)
        OR sub == 601                               Shield
5       major_cat == 5                              Weapon (two-handed)
6       major_cat == 6                              Ranged weapon (bow)
7       major_cat == 1, sub == 15                   Boots
8       major_cat == 1, sub == 16                   Armor (body)
9       major_cat == 7                              Fan/token
10      major_cat in {20-29}                        Misc equipment
11      major_cat == 1, sub in {18,19}              Wing/mantle
12      sub in {201,202}                            Gem/jewel
14      sub == 300 AND quality == 0                 Arrow/ammunition
15      sub == 350                                  Fashion head
16      sub == 360                                  Fashion garment
17      sub == 370                                  Fashion armor
18      sub == 380                                  Fashion accessory
20      sub == 200                                  Steed/mount
21      sub == 203                                  Special mount type
```

### Item Sub-Type (from GetItemSubTypeFromId @ 0x67B0B3)
Used for gems (type 201/202) and weapons (major_cat 4-7):
```
Gems (sub 201/202): returns (item_id % 10000) / 1000
Weapons (major 4-5): returns 1000 * ((item_id % 100000) / 1000)
Weapons (major 7/10): returns 10000 * ((item_id % 100000) / 10000)
```

---

## CItemData Record Layout (192 bytes)
From CItemData__CopyFrom @ 0x67983E and CItemData__ClearFields @ 0x6788DA:

```c
struct CItemData {
    uint32_t item_id;           // +0: The item type ID
    char     name[12];          // +4: Item name string (CString)
    uint8_t  field_16;          // +16: unknown flag
    uint8_t  field_17;          // +17: unknown flag
    uint8_t  field_18;          // +18: unknown flag
    uint8_t  field_19;          // +19: unknown flag
    uint16_t stat_a;            // +20: stat field A
    uint16_t stat_b;            // +22: stat field B
    uint16_t stat_c;            // +24: stat field C
    uint16_t stat_d;            // +26: stat field D
    uint8_t  field_28;          // +28: unknown
    uint16_t field_30;          // +30: unknown
    uint32_t base_price;        // +32: base buy price
    uint32_t field_36;          // +36: unknown value
    uint16_t stat_e;            // +40: stat E
    uint16_t stat_f;            // +42: stat F
    uint16_t stat_g;            // +44: stat G
    uint16_t stat_h;            // +46: stat H
    uint16_t stat_i;            // +48: stat I
    uint16_t stat_j;            // +50: stat J
    uint16_t stat_k;            // +52: stat K
    uint16_t stat_l;            // +54: stat L
    uint16_t stat_m;            // +56: stat M
    uint8_t  field_58;          // +58: flag
    uint8_t  field_59;          // +59: flag
    uint8_t  field_60;          // +60: flag (price = base * maxdur / dur / 3)
    uint32_t field_64;          // +64: value
    uint8_t  field_68;          // +68: flag
    uint8_t  field_69;          // +69: flag
    uint16_t field_70;          // +70: value
    uint16_t field_72;          // +72: value
    uint16_t field_74;          // +74: value
    uint16_t field_76;          // +76: value
    uint8_t  field_78;          // +78: flag
    uint8_t  field_79;          // +79: flag
    uint8_t  field_80;          // +80: flag
    uint32_t field_84;          // +84: value
    uint32_t field_88;          // +88: value
    uint32_t field_92;          // +92: value
    uint32_t field_96;          // +96: value
    uint32_t field_100;         // +100: value
    char     description[12];   // +104: Description string (CString)
    char     description2[12];  // +116: Secondary description (CString)
    uint32_t field_128;         // +128
    uint32_t field_132;         // +132
    uint32_t field_136;         // +136
    uint32_t field_140;         // +140
    uint32_t field_144;         // +144
    uint32_t field_148;         // +148
    uint32_t field_152;         // +152
    uint32_t field_156;         // +156
    uint32_t field_160;         // +160
    uint32_t field_164;         // +164
    uint32_t field_168;         // +168
    uint32_t field_172;         // +172
    uint32_t field_176;         // +176
    uint16_t field_180;         // +180
    uint32_t field_184;         // +184
    uint32_t field_188;         // +188: timer/duration
};
// Total: 192 bytes
```

---

## CItem Object Layout (~500 bytes)
From accessor analysis:

```c
struct CItem {
    void*    vtable;            // +0: vtable pointer (CItemTipBase__vtable (0x86B054) for CItemTipBase)
    // CString fields at offsets 1,4 (DWORD)
    uint32_t uid;               // +12 (DWORD offset 3): Item UID (CItem__GetUID)
    uint32_t item_id;           // +28 (DWORD offset 7): The item type ID
    // ...
    uint32_t base_price;        // +60 (DWORD offset 15): Base price
    uint16_t max_durability;    // +84 (WORD offset 42): Max durability
    uint8_t  gem_slot_1;        // +87 (byte): First gem socket
    uint8_t  gem_slot_2;        // +88 (byte): Second gem socket
    uint8_t  item_level;        // +97 (byte): via GetLevel_Byte
    // ... (more fields)
    uint16_t special_flag;      // +208 (WORD offset 104): Special item flag
    uint32_t amount;            // +432 (DWORD offset 108): Stack amount
    uint32_t timer_elapsed;     // +344: Timer elapsed value
    uint32_t timer_total;       // +348: Timer total
    uint8_t  timer_active;      // +356: Timer active flag
    uint16_t durability;        // +400/404: Current durability

    // Combat stats (DWORD offsets, with quench bonuses):
    uint32_t stat_attack;       // offset 33/58: Attack power (base/quenched)
    uint32_t stat_magic_atk;    // offset 45+77: Magic attack + bonus
    uint32_t stat_magic_def;    // offset 46+78: Magic defense + bonus
    uint32_t stat_atk_range;    // offset 47+79: Attack range + bonus
    uint32_t stat_dodge;        // offset 48+80: Dodge + bonus
    uint32_t stat_accuracy;     // offset 49+81: Accuracy + bonus

    // Extended fields:
    uint32_t timer_duration;    // offset 86 (DWORD): Timer duration in seconds
    uint8_t  item_bound;        // offset 108 (byte & 1): Bound flag
    uint32_t quench_data;       // offset 113: Quench refinement data
    uint32_t quench_exp;        // offset 115: Quench experience

    // Loaded item data (from CItem__LoadItemDataFromDb):
    void*    name_str;          // offset 220: Item name CString
    void*    desc_str;          // offset 232: Description CString
    uint32_t db_stat_a;         // +244: From database
    uint32_t db_stat_b;         // +248
    uint32_t db_stat_c;         // +252
    uint32_t db_stat_d;         // +256
    uint32_t db_stat_e;         // +260
    uint32_t db_stat_f;         // +264
    uint32_t db_stat_g;         // +268
    uint32_t db_stat_h;         // +272
    uint32_t db_stat_i;         // +276
    uint32_t db_stat_j;         // +280
    uint32_t db_stat_k;         // +284
    uint32_t db_stat_l;         // +288
    uint32_t db_stat_m;         // +292
    uint32_t db_stat_n;         // +296
    uint32_t db_stat_o;         // +300
    uint32_t db_stat_p;         // +304
    uint32_t db_stat_q;         // +308
    uint32_t db_stat_r;         // +312
    uint32_t db_stat_s;         // +316
    uint32_t db_stat_t;         // +320
    uint32_t db_stat_u;         // +324
    uint8_t  has_db_data;       // +480
};
```

---

## ItemTypeDataSingleton Startup Chain

The item-data singleton rooted at `data_96AE88` is not a CSV loader and not a simple
binary table. Native startup does the following:

1. `ItemTypeDataSingleton_Constructor` (`0x678A07`) initializes four internal trees:
   primary item records (`+0x04`), item textures (`+0x10`), item-add composite records
   (`+0x1C`), and fuse mappings (`+0x28`).
2. `ItemTypeDataSingleton_LoadAllTables` (`0x678BDA`) calls:
   - `ItemTypeDataSingleton_LoadPrimaryItemRecordTables` (`0x6791DD`)
   - `ItemTypeDataSingleton_LoadItemAddTable` (`0x678FE7`)
   - `ItemTypeDataSingleton_LoadItemFuseTable` (`0x678F07`)
   - `ItemTypeDataSingleton_LoadItemTextureTable` (`0x678C06`)
3. `ItemTypeDataSingleton_LoadPrimaryItemRecordTables` loads:
   - `ini/Itemtype.dat`
   - `ini/ItemtypeSub.dat`

### DecodedTextDatReader Path

`Itemtype.dat` and other text-like `.dat` assets (`LevExp.dat`, `magictype.dat`,
`MapDestination.dat`) are loaded through the shared decoded reader:

- `DecodedTextDatReader_Constructor` (`0x76D7F0`)
- `DecodedTextDatReader_OpenAndDecodeFile` (`0x76D859`)
- `DecodedTextDatReader_ReadLine` (`0x76D90F`)
- `DecodedTextDatReader_ReleaseDecodedBuffer` (`0x76D8EF`)
- `DecodedTextDatReader_DecodeBufferInPlace` (`0x76D98F`)
- `DecodedTextDatReader_Destructor` (`0x76D84E`)

Verified decode algorithm:

- constructor seeds a 128-byte table with the MSVC `rand()` algorithm
- `Itemtype.dat` uses seed `0x2537`
- decode step is `ROTR8(seed_table[index % 128] XOR encoded_byte, index % 8)`
- decoded text lines are split by the literal delimiter `@@`

### Primary Item Record Table

`ItemTypeDataSingleton_LoadItemRecordTableFromDecodedTextDat` (`0x677A95`) reads each
decoded line, tokenizes the 60-field `@@` record, and inserts/overwrites one primary
item record keyed by item type id. `ItemTypeDataSingleton_TryGetItemRecordByTypeId`
(`0x679190`) looks up that tree and logs
`"WARNING: Read Error in ItemType.dat, itemtypeID=%d"` on miss.

#### Verified text-field → binary-offset mapping

The parser iterates `sub_6779f5` (tokenizer) once per `@@`-separated text field, writing each
parsed value into the in-progress record at a deterministic stack offset. Confirmed mappings
discovered during slice 17 tracing:

| Text field index | Binary offset | Width / signedness | Semantic                                         | Verified via                                   |
|------------------|---------------|--------------------|--------------------------------------------------|------------------------------------------------|
| 0                | +0x00         | uint32             | Item type id (tree key)                          | Tree emplace at `0x679275`                     |
| 1                | +0x04         | char[12]           | Item name (CString)                              | Copy loop at `CItemData__CopyFrom` (`0x67983E`)|
| 4                | +0x12         | uint8              | Required level                                   | `CItem_GetRequiredLevel` (`0x67DED8`) and active-soul comparison at `0x67DE9C` |
| 18               | +0x30         | int16 (signed)     | Speed-percent offset (mount speed bonus)         | `Role_UpdateMountActionScaleCacheFromSources` at `0x6E5FD9` (`sx.d(*(record+0x30))`) |
| 19               | +0x32         | int16 (signed)     | Life                                             | `CItem_GetEffectiveLife` (`0x67DC23`), live item `+0x4E` |
| 20               | +0x34         | int16 (signed)     | Mana                                             | `CItem_GetEffectiveMana` (`0x67DC3B`), live item `+0x50` |

Field 18 (`+0x30`) is the only field actively consumed by the frame-interval pipeline — a
signed 16-bit value that contributes directly to `CRole+0x48` when the role's mount type id
resolves to a record in the primary tree. See
`20_notes/Rendering/roleview_dll/09_role_scale_formula.md` and
`13_role_compute_frame_interval.md` (slice 17) for the full accumulator chain.

Managed parity: `Conquer.Assets.Item.ItemTypeDatRecord.SpeedPercentOffsetFieldIndex = 18`
and the `TryGetInt16Field(int fieldIndex, out short value)` accessor. The managed
`ItemTypeDatTable` tokenizes the exact same `@@`-separated fields and exposes them by
original text-field index, preserving the native field ordering for future binary-offset
mappings. The equipped-stat slice additionally exposes field 4 as `RequiredLevel` and fields
19/20 as signed `Life` / `Mana`.

### Sidecar Tables

- `ItemTypeDataSingleton_LoadItemAddTable` parses `ItemAdd.ini` lines of ten unsigned
  integers. The first two columns become a composite key, and the remaining eight
  values are stored as 16-bit payload words.

  **Verified composite-key + payload-word layout:**

  | Line col | Role                                | Tree / record position                 |
  |---------:|-------------------------------------|----------------------------------------|
  | 0        | Primary lookup id (e.g. mount item type id) | high 32 bits of 64-bit tree key |
  | 1        | Secondary lookup id (e.g. mount plus level) | low 32 bits of 64-bit tree key  |
  | 2..9     | Eight 16-bit payload values         | node+0x18..+0x27, word offsets 0..7    |

  The tree lives at singleton `+0x1C`; lookups go through
  `GameDataSingleton_TryGetActionTypeRecordByDualKey` (`0x6791FB`), which composes the
  key as `(arg2 << 32) | arg3` and copies 16 bytes from the node to the caller's output
  buffer. Consumed by `Role_UpdateMountActionScaleCacheFromSources` at `0x6E5FF3` as
  `CRole+0x48 += zx.d(*(output+0x0E))` — the 8th payload word (col 9). Managed parity:
  `Conquer.Assets.Item.ItemAddIniTable` / `ItemAddRecord.SpeedPercentOffsetPayloadWordIndex = 7`.

  `CItem_RefreshItemAddRecordCache` (`0x67AC6B`) supplies the equipment-stat lookup. Its
  secondary key is MsgItem byte `+33`, stored at `CItem+0x61`. Its primary key starts from
  the item type, applies the native category-4/category-5 family substitutions (44,000 or
  55,000 while preserving the 100,000 bucket and low three digits, with the verified
  subtype/family exceptions), then truncates to a multiple of ten. The copied record lives at
  `CItem+0x180`. `CHero_GetEffectiveMaxLife` reads payload word 0 unsigned; word 7 remains the
  independently verified mounted speed-percent source.
- `ItemTypeDataSingleton_LoadItemFuseTable` parses `fuse.ini` mappings of the form
  `input_key=output_value`.
- `ItemTypeDataSingleton_LoadItemTextureTable` parses `ItemTexture.ini` sections keyed
  by stored RoleView source id, with `Amount=N` and repeated `ColorX=` / `TextureX=`
  pairs. The `ColorX` values are native texture-variant selectors, not generic tint ids.

### Equipped life/mana, soul, enchantment, and refinement

The exact item contribution consumed by `CHero_GetEffectiveMaxLife` / `MaxMana` is now closed:

- `CItem_GetEffectiveLife` (`0x67DC23`) starts from signed Itemtype field 19 and adds the
  active soul record's signed field 19 unless temporary-soul suppression is active. The result
  narrows to signed 16-bit before the hero sign-extends it. Mana does the same with field 20 in
  `CItem_GetEffectiveMana` (`0x67DC3B`).
- Soul item ids live at `CItem+0x10` (permanent) and `CItem+0x14` (temporary). The temporary
  id wins when nonzero. `CItem_ShouldSuppressTemporarySoulStats` (`0x67DE9C`) suppresses the
  loaded alternate stats only when a temporary id exists and base required level (field 4) is
  lower than the active soul record's required level. Permanent-only soul stats are not gated
  by that branch.
- MsgItem byte `+36` is zero-extended into `CItem+0x16C`; max life adds it for every equipped
  slot except slot 12 (steed).
- Primary refinement value/effect are `CItem+0x1C0/+0x1CC`; secondary value/effect are
  `CItem+0x1D4/+0x1DC`. Effect id 301 is the max-life effect. The primary value is added when
  primary effect is 301. The secondary value is added when secondary effect is 301 and the
  **signed** primary effect id is below 100. Reset state uses primary effect `-1`, so signedness
  is material.
- Max life skips items whose `CItem+0x1AC` broken/disabled byte is nonzero. Max mana iterates
  all 18 non-null equipment slots without consulting that byte and does not add ItemAdd,
  enchantment, or refinement values.
- The broken byte is state, not a pure `durability == 0` derivation. New MsgItem equipment
  objects initialize it to 1 only at zero durability; MsgItem update-existing explicitly writes
  0 for positive durability or 1 for zero. CMsgTick subtype 17 sets it on the non-positive path,
  but its positive path updates current durability without clearing an existing 1.

---

## Upgrade Experience Tables

### Standard Upgrade (GetUpgradeExp @ 0x67B411)
```
Index:  0     1     2     3     4      5      6      7       8       9      10     11      12
Exp:    0    20    40   120   360   1080   3240   9720   29160   87480  90180  95680  104680
```

### Alternate Upgrade (GetUpgradeExpAlt @ 0x67B4A6)
```
Index:  0     1     2     3     4      5      6      7       8       9      10     11      12
Exp:    0    20    40   130   370   1090   3250   9730   29170   87490  90190  95690  104690
```
Used for item type 14 (ammunition).

### Gem Upgrade (GetGemUpgradeExp @ 0x67B53B)
```
Index:  0     1     2     3     4      5      6      7       8
Exp:    0    10    40   120   360   1080   3240   9720   29160
```

### Composition Upgrade (GetCompositionExp @ 0x67B5B4)
```
Index:  0     1     2     3     4      5      6      7       8
Exp:    1    10    30   120   360   1080   3240   9720   29160
```

### Upgrade Threshold Table (GetUpgradeExpThreshold @ 0x67B33B)
```
Index:  0     1     2     3     4      5      6      7       8      9     10     11
Exp:   20    20    80   240   720   2160   6480  19440   58320   2700   5500   9000
```

### Alternate Threshold Table (GetUpgradeExpThresholdAlt @ 0x67B3A6)
```
Index:  0     1     2     3     4      5      6      7       8      9     10     11
Exp:   20    20    90   240   720   2160   6480  19440   58320   2700   5500   9000
```
Difference from standard: index 2 is 90 instead of 80.

---

## Equipment Slot System (NormalizeEquipmentSlot @ 0x67B8A1)

Maps item sub-types to canonical equipment positions:
```
Slot ID  →  Canonical  Description
111      →  111        Helmet
113      →  113        Necklace
114      →  114        Ring
117      →  117        (Weapon/shield)
118      →  118        Boots
120      →  120        Special slot
121      →  121        Special slot
130      →  130        Armor
131      →  131        Armor variant
133      →  133        Cape/mantle
134      →  134        Cape variant
138      →  133        (alias → cape)
139      →  134        (alias → cape variant)
171      →  111        (alias → helmet)
173      →  113        (alias → necklace)
174      →  114        (alias → ring)
177      →  117        (alias → weapon)
178      →  118        (alias → boots)
```

---

## Socket/Gem System

### Quality Tiers (GetItemQualityTier @ 0x67B28C)
```
Last digit of item_id:
  6 → Tier 4 (highest quality)
  7 → Tier 3
  8 → Tier 2
  9 → Tier 1

Special items:
  Item IDs 1100003, 1100006, 1100009: Tier 6
  Items in range 0x109A00-0x109A02: Tier 6
  Weapon accessories (type 9, sub 0): Tier 5
```

### Socket Score Calculation (CalcItemSocketScore @ 0x67B9C7)
```
Score = quality_tier
      + (gem_slot_1 != 0)
      + (gem_slot_2 != 0)
      + (gem_slot_1 % 10 == 3) // Super gem bonus
      + (gem_slot_2 % 10 == 3) // Super gem bonus
      + additional_effect_score

For type 14 items (bows with subtype 5):
  Score is doubled if certain conditions met.
```

### Can Add Socket (CanAddSocket @ 0x67CAFD)
```
Type 12 (gem): socket_score >= 5
Equipment: socket_score >= 8
Both require: not bound, not special locked
```

---

## Functions (verified through decompilation)

### Core Accessors
| Address | Name | Description |
|---------|------|-------------|
| 0x67AD9A | GetItemType | Returns main type via GetItemMainTypeFromId(item_id) |
| 0x67ADA4 | GetItemSubType | Returns sub-type via GetItemSubTypeFromId(item_id) |
| 0x67AF1A | GetItemMainTypeFromId | Static: extracts main type from item ID |
| 0x67B0B3 | GetItemSubTypeFromId | Static: extracts sub-type from item ID |
| 0x71FF0B | GetUID | Returns item UID (DWORD offset 3) |
| 0x67CC54 | GetItemLevel | Returns this[97] (byte) |
| 0x67D663 | GetLevel_Byte | Returns this[97] (byte, alias) |
| 0x67D7EF | GetItemDurability | Returns durability (offset 400 or 404) |
| 0x67D82F | GetMaxDurability | Returns max durability (WORD offset 202) |
| 0x67DCE2 | GetEffectiveId | Returns field 55 or field 8 based on flag |
| 0x67C885 | GetSpecialFlag | Returns WORD at offset 104 |
| 0x67CC02 | GetItemColor | Returns item color value |

### Type Checks
| Address | Name | Description |
|---------|------|-------------|
| 0x67C849 | IsFashion | True if type in {15,16,17,18} |
| 0x67C877 | IsSteed | True if type == 20 |
| 0x67CBBF | IsWeaponAccessory | True if type == 9 and sub == 0 |
| 0x67C894 | HasSpecialFlag | Checks WORD at offset 104 != 0 |
| 0x67B1EE | IsSocketable | Quality 9 or flagged socketable |
| 0x67C7FF | (unnamed) | Equipment type check |

### Upgrade System
| Address | Name | Description |
|---------|------|-------------|
| 0x67B411 | GetUpgradeExp | Standard upgrade exp table (13 entries) |
| 0x67B4A6 | GetUpgradeExpAlt | Alternate table for type 14 items |
| 0x67B53B | GetGemUpgradeExp | Gem upgrade exp table (9 entries) |
| 0x67B5B4 | GetCompositionExp | Composition exp table (9 entries) |
| 0x67B33B | GetUpgradeExpThreshold | Upgrade threshold table (12 entries) |
| 0x67B3A6 | GetUpgradeExpThresholdAlt | Alternate threshold (12 entries) |
| 0x67B65A | CalcUpgradeLevel | Determines level from total exp |

### Combat Stats
| Address | Name | Description |
|---------|------|-------------|
| 0x67DCFB | GetAttackPower | Base or quenched attack |
| 0x67DD22 | GetStatMagicAttack | Magic attack + quench bonus |
| 0x67DD44 | GetStatMagicDefense | Magic defense + quench bonus |
| 0x67DD66 | GetStatAttackRange | Attack range + quench bonus |
| 0x67DD88 | GetStatDodge | Dodge + quench bonus |
| 0x67DDAA | GetStatAccuracy | Accuracy + quench bonus |
| 0x67DDEA | ValidateItemType | Validates equipment type code |

### Economy
| Address | Name | Description |
|---------|------|-------------|
| 0x67ADAE | CalcSellPrice | price * maxdur / dur / 3 * quality_mult |
| 0x67ADDC | CalcRepairCost | Based on durability damage with quality multiplier |

### Socket/Gem
| Address | Name | Description |
|---------|------|-------------|
| 0x67B8A1 | NormalizeEquipmentSlot | Maps aliased slots to canonical IDs |
| 0x67B9C7 | CalcItemSocketScore | Calculates total socket quality score |
| 0x67BAD4 | GetGemSocketCompatibility | Returns gem-slot compatibility mapping |
| 0x67BD61 | CanEquipGem | Checks if gem fits in socket |
| 0x67B28C | GetItemQualityTier | Returns quality tier (1-6) |
| 0x67CAFD | CanAddSocket | Checks if item can receive new socket |

### Composition/Crafting
| Address | Name | Description |
|---------|------|-------------|
| 0x67C8C3 | CanCompose | Checks if two items can be composed |
| 0x67DEDC | CanApplyFashionDye | Checks equipment-to-fashion dye compatibility |
| 0x67BCAB | GetEquipmentCategory | Maps slot to category (410=weapon, 510=accessory) |
| 0x462649 | IsTwoHandedWeapon | Returns true when the item's main type is two-handed weapon and its subtype gate is zero |
| 0x67D83E | CanTrackInInventoryList | Predicate used before `CHeroItem__TryAddInventoryItem` in the native item-table reroute paths |

### Visual/Display
| Address | Name | Description |
|---------|------|-------------|
| 0x67B7CA | CalcItemMeshId | Calculates 3D mesh ID for rendering |
| 0x67D667 | HasVisualEffect | Checks if item has visual glow/effect |
| 0x67BF6B | SetAndFormatAmount | Sets stack amount and formats display |
| 0x67D177 | FormatQuenchTimeString | Formats quench remaining time |
| 0x67C169 | Handle_Item_Remain_Time_Second | Formats timed item remaining duration |

### Setters (offset-based)
| Address | Name | Description |
|---------|------|-------------|
| 0x67AD6B | InitFromUIDAndItemId | Loads CItemData by item_id; sets UID and base fields |
| 0x67AC6B | UpdateAddStatsFromItemIdAndLevel | Recomputes 4-dword add-stat array at +384 using adjusted item_id and level |
| 0x67C794 | SetDword_0x14C | Sets dword at offset +0x14C |
| 0x58CDDF | SetDword_0x160 | Sets dword at offset +0x160 |
| 0x67B0A6 | SetDword_0x17C | Sets dword at offset +0x17C |
| 0x67D80C | SetDwordMin1_0x190 | Sets dword at +0x190, clamped to minimum 1 |
| 0x67D820 | SetWord_0x194 | Sets word at offset +0x194 |
| 0x67C755 | CItem__SetRoleViewTextureVariantSelector | Sets the item-side texture-variant selector at +0x19C; for the special `sub_67AD9A(item) == 0x0E` branch, rewrites it as `sub_67D75D(item) * 100 + sub_67CC54(item)` |
| 0x67BF5E | OrDword_0x1A0 | ORs bitmask into dword at +0x1A0 |
| 0x67BF4F | AndNotDword_0x1A0 | Clears bitmask in dword at +0x1A0 |
| 0x67CBAB | SetByte_0x1AD | Sets byte at offset +0x1AD |
| 0x67B76E | SetByte_0x165 | Sets byte at offset +0x165 |
| 0x67C78D | CItem__GetRoleViewTextureVariantSelector | Returns the item-side texture-variant selector used by the `ItemTexture.ini` lookup path |
| 0x67DDCC | CItem__HasRoleViewOverrideLookupId | Returns true when either override-lookup field is populated |
| 0x67CAAE | CItem__GetRoleViewOverrideLookupIdOrFallback | Returns `item+0x14` when present, otherwise `item+0x10` |
| 0x67CAB9 | CItem__TryGetRoleViewOverrideLookupId | Returns the override lookup id only when the item is flagged to use it |

### Data Management
| Address | Name | Description |
|---------|------|-------------|
| 0x677A95 | ItemTypeDataSingleton_LoadItemRecordTableFromDecodedTextDat | Decodes and tokenizes one `Itemtype.dat`/`ItemtypeSub.dat` text table into the primary item-record tree |
| 0x679190 | ItemTypeDataSingleton_TryGetItemRecordByTypeId | Looks up one primary item record by item type id |
| 0x67983E | CItemData__CopyFrom | Copies 192-byte record field by field |
| 0x6788DA | CItemData__ClearFields | Zeros all fields in record |
| 0x67888F | CItemData__Init | Constructor, initializes strings + fields |
| 0x67886B | CItemData__ClearGemSlots | Zeros 8 gem slot WORDs |
| 0x67AC6B | CItem_RefreshItemAddRecordCache | Normalizes the item type / MsgItem `+33` key and refreshes the eight-word `ItemAdd.ini` cache at `CItem+0x180` |
| 0x67CBEE | CItem_IsBrokenOrDisabled | Returns the broken/disabled byte at `CItem+0x1AC` |
| 0x67D95A | CItem__LoadPrimaryItemRecordFieldsFromItemTypeData | Loads a selected soul item record into the alternate cache (`field19 -> +0x110`, `field20 -> +0x130`) |
| 0x67DC23 | CItem_GetEffectiveLife | Returns signed-16 base plus eligible active-soul life |
| 0x67DC3B | CItem_GetEffectiveMana | Returns signed-16 base plus eligible active-soul mana |
| 0x67DC53 | CItem__GetNameFromItemDb | Gets item name string from database |
| 0x67DF82 | CItem__ClearAllFields | Clears all CItem fields |
| 0x67C05C | CItem__SetTimerDuration | Sets item timer (converts minutes to seconds) |
| 0x67DE9C | CItem_ShouldSuppressTemporarySoulStats | Required-level gate for temporary soul stat substitution |
| 0x67DDEA | CItem_GetActiveSoulRequiredLevel | Selects temporary/permanent soul id and returns Itemtype field-4 required level |
| 0x67DED8 | CItem_GetRequiredLevel | Returns the base Itemtype field-4 required level |

### ItemTypeDataSingleton Core
| Address | Name | Description |
|---------|------|-------------|
| 0x678A07 | ItemTypeDataSingleton_Constructor | Initializes the four item-data trees and installs vtable `0x86B054` |
| 0x678B26 | ItemTypeDataSingleton_Destructor | Releases the four item-data trees |
| 0x678BDA | ItemTypeDataSingleton_LoadAllTables | Loads the full item-data startup bundle |
| 0x6791DD | ItemTypeDataSingleton_LoadPrimaryItemRecordTables | Loads `Itemtype.dat` then `ItemtypeSub.dat` through the decoded-text reader |
| 0x678FE7 | ItemTypeDataSingleton_LoadItemAddTable | Loads `ItemAdd.ini` into the composite-key sidecar table |
| 0x678F07 | ItemTypeDataSingleton_LoadItemFuseTable | Loads `fuse.ini` into the fuse mapping table |
| 0x678C06 | ItemTypeDataSingleton_LoadItemTextureTable | Loads `ItemTexture.ini` into the stored-source/variant texture table |
| 0x679275 | primary item-record tree emplace helper | Inserts/finds one primary item record node by item type id |
| 0x679326 | item-texture tree emplace helper | Inserts/finds one item-texture section node by stored RoleView source id |
| 0x6793C2 | item-add tree emplace helper | Inserts/finds one item-add node by two-part composite key |

### Data Files
| File | Purpose |
|------|---------|
| `ini/Itemtype.dat` | Primary decoded item record table |
| `ini/ItemtypeSub.dat` | Supplemental decoded item record table merged into the same tree when present |
| `ini/ItemTexture.ini` | Item texture/sprite mappings |
| `ini/fuse.ini` | Item fusion/composition data |
| `ini/ItemAdd.ini` | Item additional stat data |
| `ini/Info.ini` | General item information |
