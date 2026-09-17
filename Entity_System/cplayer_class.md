# CPlayer Class — Rendered Entity with Nameplate

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Player.cpp` (debug string at 0x93FED8).
## Inherits: CRole
## IDA Folder: /Entity_Player/CPlayer (22 functions) + /Entity_Player/Misc (1 function)

## Memory Layout (extends CRole, ~2636 bytes total)
```c
struct CPlayer : CRole {
    // vtable override at CPlayer__vtable (0x86AEEC)

    // Entity identification
    // entity_id at offset 204 (DWORD 51): determines type
    //   > 999999 (0xF423F): player character
    //   400001-500000: NPC
    //   500001-600000: monster

    // Name rendering
    uint32_t name_color;             // offset 578 (DWORD): ARGB color for name text
    char*    guild_name;             // offset 565 (DWORD): pointer to guild name string
    uint32_t guild_name_timestamp;   // offset 313 (DWORD): timeGetTime of last guild change

    // Equipment visuals
    void*    equipment_effect;       // offset 606 (DWORD): equipment glow effect object
    void*    body_effect;            // offset 608 (DWORD): body visual effect
    uint32_t transparency_value;     // offset 609 (DWORD): alpha transparency (0-255)
    void*    transparency_effect;    // offset 610 (DWORD): transparency shader object
    void*    pet_effect;             // offset 647 (DWORD): pet visual effect

    // Visual effect queue (circular buffer)
    struct VisualEffect {
        char  active;                // +0: is active
        DWORD expire_time;           // +16: timeGetTime expiration
        int   duration;              // +20: duration in ms
        void* roleview;              // +44: RoleView pointer
        // total size: 48 bytes per entry
    };
    VisualEffect effect_queue[6];    // offset 626 (DWORD): circular buffer (626-629 = begin/end/alloc)
    uint32_t effect_expire_total;    // offset 623 (DWORD)
    uint32_t effect_start_time;      // offset 624 (DWORD)
    uint32_t effect_last_spawn;      // offset 625 (DWORD)

    // Family/guild data
    uint32_t family_id;              // offset 554 (DWORD): family/clan ID (0 = none)

    // Inventory pointer
    // GetInventoryPtr() returns this + 1144

    // Linked list / map structures
    // offset 644 (DWORD): linked list head
    // offset 659 (DWORD): secondary data structure

    // Rendering state
    uint32_t last_render_time;       // offset 304 (DWORD): timeGetTime of last render
    uint32_t level_cmp_value;        // offset 2104 (DWORD): used for name color comparisons
};
```

## Functions (22 + 1 Misc = 23 total)

### CPlayer__Destructor (0x66F09C, size=745)
**Purpose**: Destructor, cleanup chain.
```
- Sets vtable to CPlayer__vtable (0x86AEEC)
- Iterates visual effect queue, destroys all RoleView objects at slot +44
- Destroys equipment_effect (offset 606)
- Destroys transparency_effect (offset 610)
- Destroys body_effect (offset 608)
- Destroys pet_effect (offset 647)
- Cleans up secondary data structures
- If entity_id > 999999, removes from guild registry
- Calls CRole__Dtor() as final step
```

### CPlayer__GetInventoryPtr (0x66F385, size=7)
**Purpose**: Returns pointer to inventory data.
```c
return this + 1144;  // byte offset to inventory region
```

### CPlayer__Update (0x66F7AB, size=478)
**Purpose**: Main per-frame update/render tick.
**Note**: IDA originally labeled this function as `CNpc__vtUpdate` at 0x66F7AB; it is actually the player update path.
```
Flow:
1. Check if entity is valid (vtable call +96)
2. Load entity info from ini (CPlayer__LoadInfoIni)
3. If CRole__HasStatusFlag(0x16):
   - Apply look color: (look & 0xFFFFFF) | 0x66000000
4. If vtable+120 returns true:
   - If g_bSimplifiedRenderMode and vtable+92 returns false:
     - CPlayer__LoadMonsterStatusIfMonster
     - CPlayer__RenderHpBar
     - CPlayer__RenderFullNamePlate
5. Else (vtable+120 returns false):
   - If CPlayer__GetByte_0x9F4 is non-zero: return
   - CPlayer__UpdateLinkedEffect_0x4D4
   - CRole__Render3D
   - If vtable+92 returns true:
     - CPlayer__RenderEquipEffect
     - CPlayer__RenderNameTag
   - Else:
     - last_render_time = timeGetTime()
     - If ID in 0x61A81–0x7A11F and !CPlayer__NameContainsStrId_0x186BC, or
       ID in 0x7A121–0x927BF: CPlayer__RenderBodyEffect
     - If g_bSimplifiedRenderMode or (GetSingletonPtr_410685+96) is set:
       - If (ID outside 0x61A81–0x7A11F or !CPlayer__IsEntityInRange_0xAAE61_0xC34FF_AndFlag) OR
         (!CRole__HasStatusFlag(0x0B) and !CRole__HasStatusFlag(5)):
         - CPlayer__LoadMonsterStatusIfMonster
         - CPlayer__RenderHpBar
         - v13 = CPlayer__RenderFullNamePlate
         - v14 = CPlayer__RenderSubTitle
         - v13 = max(v13, v14)
         - If (GetSingletonPtr_410685+232) has 0x8000: CPlayer__RenderFamilyTitle
   - CPlayer__RenderStatusOverlay_0x12_0x17(0)
   - CPlayer__RenderEffectAni(v13 / 2)
  - CPlayer__UpdateOverlayList(this+214, this+215 - CRole__GetOverlayYOffset_0x66F6D9() - 100)
   - CPlayer__RenderStallPrice
```

### CPlayer__UpdateOverlayList (0x72F8FF, size=0x6F2)
**Purpose**: Updates/animates the per-entity overlay entry list (floating image numbers/text).
**Notes**:
- Operates on a deque-like container of 0x44-byte entries; uses helper iterators
  `Deque68__IteratorDistanceMinus1` and `Deque68__SeekIndex`.
- Also referenced by `C3DMapSimpleObj__UpdateAndRender` (0x64CB1A), suggesting a shared overlay list type.

**Entry layout (referenced fields)**:
```
struct OverlayEntry {            // size 0x44
  int     width_px;              // +0
  int     height_px;             // +4
  int     unused_08;             // +8 (not referenced here)
  int     x_offset;              // +12
  uint16  flags16;               // +16 (if (flags16 & 0x3F0)==0, enables scale/color updates)
  uint16  pad;
  uint32  anim_flags;            // +20 (bit0/bit1/bit2 phase selection)
  uint32  color_argb;            // +24 (RGB used; alpha overwritten)
  uint32  delay_ms;              // +28
  uint32  phase3_ms;             // +32 (used in phase3/fade logic)
  uint32  start_time_ms;         // +36
  uint32  phase1_ms;             // +40
  uint32  phase2_ms;             // +44
  float   scale_start;           // +48
  float   scale_end;             // +52
  void*   view_primary;          // +56 (optional)
  void*   view_secondary;        // +60 (optional)
  void*   view_main;             // +64 (img-number renderer)
};
```

**Per-entry update (verified formulas)**:
- `elapsed = timeGetTime() - (start_time_ms + delay_ms)`. If negative, skip.
- `view_main` is updated every active phase and rendered via `CImgNum__Render`.
- Coordinate transforms are done by `CGameMap__AddScreenOffset` then
  `ScreenSpace__ApplyOriginOffset` before drawing optional view objects.

**Phase selection by `anim_flags`:**
1. **Phase A (`anim_flags & 0x2`, `elapsed <= phase2_ms`)**
   - `t = elapsed / phase2_ms`
   - `scale = scale_end - (scale_end - scale_start) * t`
   - Alpha ramps from 0x20 → 0xFF: `alpha = 32 + 223 * t`
   - Updates `view_main` scale, position, and color.
   - If `view_primary` exists, applies scale/color and draws at screen position.
2. **Phase B (`anim_flags & 0x1`, `elapsed <= phase1_ms`)**
   - `t = elapsed / (phase1_ms + phase3_ms)`
   - `scale = scale_start + (scale_end - scale_start) * t`
   - Y offset shifts by `height_px * t`.
   - Updates `view_secondary` (if present) and `view_primary`.
3. **Phase C (`anim_flags & 0x4`)**
   - If `anim_flags & 0x2`: fade-out over `phase3_ms` starting after phase2
     (`t = (elapsed - phase2_ms) / phase3_ms`), alpha = `255 * (1 - t)`.
   - Else if `anim_flags & 0x1`: fade-out over `phase1_ms + phase3_ms`, with
     scale pinned to `scale_end`.
   - Updates `view_main` color/pos and draws via `CImgNum__Render`.

### CPlayer__RenderStallPrice (0x66F989, size=940)
**Purpose**: Renders stall price numbers above a stallkeeping player.
```
Trigger: action_type == 16 (stallkeeper)
Resources:
- "ani/Control.ani" → "Stall_NumBG" (background)
- "ani/Control.ani" → "Stall_Num%d" (digit sprites 0-9)
Algorithm:
1. Query stall price for entity
2. Decompose price into individual digits
3. Calculate total display width
4. Center above player position
5. Render background sprite scaled to viewport
6. Render each digit sprite right-to-left
```

### CPlayer__RenderMagicTip (0x66FEA7, size=507)
**Purpose**: Renders magic/skill tooltip text above NPC/monster entities.
```
Trigger: Entity ID in NPC/monster range (400001-600000)
Uses: STR_USE_MAGIC_TIP string format
- Uses string at offset 565 via CPlayer__GetGuildName (field is named guild_name; here it supplies the tip name)
- Formats tooltip string
- Calculates text extent via CMyBitmap::CalcuTextExtentCommon
- Positions above entity head (screen_y - height)
- Renders with red color (-65536 = 0xFFFF0000)
```

### CPlayer__RenderNameTag (0x670410, size=948)
**Purpose**: Renders a multi-line title/name tag for player entities only.
```
Verified behavior:
- Early-out unless entity_id (offset +51) > 0xF423F (player range).
- Uses CPlayer__GetDword_0x8AC as the base string-id source; returns if null.
- Throttled by last_render_time (offset +304): renders only if >= 1000ms elapsed.
- Resolves a display string via string manager (GetSingletonPtr_432FB0 + IdMap__FindByKey_0x6AC9C6).
  If IdMap__FindById_0x6C2F57 returns a non-empty string-id (Entry__GetDword_0x74), that id overrides.
- Expands the resolved string-id into line fragments via CLanguage__GetLanguageName.
- Draws a background sprite ("ani/Control.ani" / "Dialog21") sized to the text.
- Renders each line with FontSetting.ini; alignment flips with g_bRightToLeftLayout (RTL/LTR).
- X clamped to screen width, Y clamped >= 0.
```

### CPlayer__RenderFullNamePlate (0x6707C4, size=3902)
**Purpose**: Builds and renders the main nameplate string (player + NPC/monster paths).
```
String construction (verified branches):
- Base name: Str = this+332.
- Player IDs (> 0xF423F): if IdMap__FindById_0x6C2F57 returns a string and Entry__GetString_0x94
  yields a non-"name" value, Str is replaced by that value.
- NPC/monster IDs (<= 0xF423F): if CRole__GetString_0x158 yields a non-empty string,
  builds Buffer using STR_PROTECTNPC_T or STR_PROTECTNPC_S (trailing "[]" check),
  then Str = Buffer.
- Special roledata ranges (ID 0x61A81–0x7A11F or 0x7A121–0x927BF):
  RoleDataQuery(vtable+36) + field(+120) select STR_BIOLOGICALT_* format variants,
  producing a final Buffer (Str = Buffer).
- Optional suffixes for players:
  - If CRole__GetByte_0x18 returns true, appends STR_TEMP_LEAVE_NA.
  - If GetSingletonPtr_414BDA reports a server name for this entity, appends
    STR_SERVERNAME_S formatted with that server name.

Name color selection:
- Players: status flags drive color
  - StatusFlag(0x0F): black (0xFF000000)
  - StatusFlag(0x0E): red (0xFFFF0000)
  - StatusFlag(0x00): blinking blue (0xFF0000FF)
- NPC/monster IDs: compares global value at +2104 (local) vs this+2104
  using +/-5 thresholds to choose black/red/white/green.

Rendering:
- Loads FontSetting.ini and computes text extents.
- Centers above entity using offsets +856/+860 and CRole__GetOverlayYOffset_0x650980.
- RTL/LTR handled via g_bRightToLeftLayout.
- If name color is too dark, forces outline color to -5592406.
- Uses string id 100124 in one layout path when action/state == 14.
```

### CPlayer__RenderFamilyTitle (0x671741, size=768)
**Purpose**: Renders family/clan title above the player.
```
- Queries family data at offset 554
- Loads family info via GetSingletonPtr_480676 → FamilyMgr__FindById
- Color by family rank:
  Rank 0: White (0xFFFFFFFF)
  Rank 1-2: Yellow (0xFFFFFF00)
  Rank 3: Red (0xFFFF0000)
- If CPlayer__IsDword_0x8B0_Equal100 is true, formats title as: name + STR_FAMILY_RANK_L
- Centers above entity, positioned below name
- Rank label rendered in color -10053121
```

### CPlayer__RenderSubTitle (0x671A41, size=949)
**Purpose**: Renders subtitle (guild position or custom title).
```
Two paths:
1. From IdMap__FindById_0x6C2F57:
   - Uses the returned object's Id string (non-empty) as subtitle
   - White color, centered below name
2. From custom title data (CPlayer__GetCustomTitleId / CPlayer__GetCustomTitleInfo):
   - Color by CustomTitleMgr__GetColorTypeById(custom_title_id):
     0=Green, 1=Red, 2=Yellow, else=White
   - Optional extra string from CPlayer__GetStringByFields_0x870_0x874
   - Renders title + extra string on the same line
   - Extra string in color -10053121
```

### CPlayer__RenderEquipEffect (0x671DF6, size=760)
**Purpose**: Renders nameplate overlays and equipment/pet visuals.
```
For players (ID > 0xF423F) and action != 17:
- RoleDataQuery(vtable+160) using look id at word offset 0xD6
- Loads FontSetting.ini
- Calls RenderFamilyTitle, RenderFullNamePlate, RenderSubTitle
- Draws overlay sprite via vtable+12 on returned RoleData entry
- Calls CPlayer__DrawOverlay_0x988 for additional overlay
- If pet_effect (offset 647) exists: renders a 3D effect with transformed coords

For NPCs/monsters (ID <= 0xF423F) and status flag 5 is clear:
- LoadMonsterStatusIfMonster
- RenderHpBar
- RenderFullNamePlate
- If ID in 0x61A81–0x7A11F and !CPlayer__NameContainsStrId_0x186BC, or
  ID in 0x7A121–0x927BF: RenderBattlePower
- If action_type == 9: RenderSubTitle
```

### CPlayer__GetNameColor (0x673498, size=56)
**Purpose**: Gets stored name color.
```c
assert(entity_id > 999999);
return this->offset_578;  // DWORD name_color
```

### CPlayer__SetNameColor (0x6734D0, size=62)
**Purpose**: Sets name color.
```c
assert(entity_id > 999999);
this->offset_578 = color;
```

### CPlayer__CalcRenderHeight (0x67350E, size=158)
**Purpose**: Calculates total vertical render height for all overlays.
```
For players:
  If camera zoomed in (CGameCamera__IsZoomedIn):
    return min(CPlayer__GetBaseRenderHeight(), 5)  // base height, capped at 5
  Else:
    return CPlayer__GetBaseRenderHeight() + CPlayer__GetRenderHeightOffset_0x4E8()
         + max(CPlayer__GetRenderHeightOffset_0x98C(), CPlayer__GetRenderHeightOffset_0x91C())
```

### CPlayer__RenderBattlePower (0x673F40, size=671)
**Purpose**: Renders battle power comparison indicator.
```
Early-out: if render mask has bit 0x2000000 set (CRole__GetRenderMask_0xE8).

Compares RoleData field(+27) against a global value (GetSingletonPtr_404460 vtable+184):
  diff = global_value - roledata[27]

  diff < 0 (target higher):
    |diff| 1–4  -> string id 100163
    |diff| 5–9  -> string id 100164
    |diff| >9   -> string id 100165
    Color: Black (0xFF000000)

  diff >= 0:
    If roledata[27] != 0: string id 100162 (uses roledata[27] and % diff)
    Else: string id 100161
    Color: White (0xFFFFFFFF)

If roledata[27] > 0:
- Ensures "battlelevstar" resource is loaded (CPlayer__HasBattleLevStarResource
  / CPlayer__LoadBattleLevStarResource)
- Draws the icon via CPlayer__DrawBattleLevStarAt(x,y)

Special entity sizes (action 130/295/527): height *= 2.4
```

### CPlayer__AddVisualEffect (0x6741F9, size=560)
**Purpose**: Adds a timed visual effect to the player's effect queue.
```
Parameters: (entity_id, max_queue_size, duration_ms, loop_flag)
Algorithm:
1. Resolve entity via EntityManager__FindEntityById
2. Check effect queue size at offset 626
3. If queue full (>= max_queue_size):
   - Destroy oldest effect's RoleView
   - Advance queue pointer (+48 bytes per entry)
4. Create new VisualEffect:
   - active = loop_flag
   - expire_time = timeGetTime() + duration_ms
   - duration = duration_ms
   - roleview = RoleViewCreate(entity.look)
5. Configure RoleView using entity fields (offsets +54, +161, +162, +44)
   and transform helper ScreenSpace__ApplyOriginOffset
6. Add to effect queue circular buffer
```

### CPlayer__UpdateVisualEffects (0x674429, size=472)
**Purpose**: Updates visual effect queue, removes expired effects.
```
Algorithm:
1. Get current time via timeGetTime()
2. While effect queue not empty:
   - Check oldest effect expiry (offset +16)
   - If expired: destroy RoleView, advance queue
   - If not expired: break
3. If effect_start_time (offset 624) is set:
   - Requires (time - offset_624) < offset_623 and entity_id == local player id
   - Re-spawn effect every 0x96 ms if CRole__IsSchedulerProxyInSet_401_409_470_520_620 returns false
   - CPlayer__AddVisualEffect(entity_id, 6, 650, false)
   - Otherwise clears offsets 624/625
4. Else if StatusFlag(0x70) is set and CRole__IsSchedulerProxyInEffectList returns true:
   - Runs helper chain EffectHelper__BuildParams_0x67772B → NoOp_0x6AF263 →
     GetSingletonPtr_66AD58 → EffectHelper__Process_0x6D5F83
```

### CPlayer__SetTransparency (0x674C0A, size=298)
**Purpose**: Controls player visual transparency.
```
Sets transparency value at offset 609
If value > 0:
  - Create transparency effect object (0x50 bytes) if not exists
  - Configure effect via CPlayer__SelectTransparencyEffectName(transparency_value)
  - Apply via EffectTemplate__ApplyByName
If value <= 0 or effect fails:
  - Destroy transparency effect object at offset 610
```

### CPlayer__SetStringProperty (0x675A69, size=74)
**Purpose**: Static helper to copy a string into a property field.
```c
assert(Str != NULL);
// Wraps string copy into internal string container
```

### CPlayer__SetGuildName (0x675C81, size=96)
**Purpose**: Sets guild/faction name and records change timestamp.
```c
this->offset_565 = copy_string(name);
if (offset_565 != offset_566) {  // guild name changed
    this->offset_313 = timeGetTime();
}
```

### CPlayer__LoadInfoIni (0x674601, size=1134)
**Purpose**: Loads entity visual info from INI config and renders visual effect queue.
```
Only runs for player entities (entity_id > 0xF423F).

One-time initialization (lazy, guarded by byte_96AE70 flags):
  1. Alpha pass (bit 0): Loads "Alpha" / "KoImage" / "ini/Info.ini" resources
     - Creates alpha effect template with value 50 → dword_96AE68
  2. Texture pass (bit 1): Loads "Texture" / "KoImage" / "ini/Info.ini"
     - Creates texture effect template with value 1000000000 → dword_96AE74

Per-frame effect queue rendering:
- Gets camera origin offset via GetSingletonPtr_410685
- Iterates circular effect queue at offsets 626-630:
  - For each active effect with RoleView (slot +44):
    - Sets animation frame, direction, color
    - If slot[12] == 0 (fading): computes remaining time ratio,
      applies alpha fade using dword_96AE68 global
    - If slot[12] != 0 (solid): applies half-brightness green channel,
      full alpha from dword_96AE68
    - Configures equipment slots 23-35 from entries +24 to +36
    - Applies additional slots 36-37 if present
    - If slot[12] active: sets slot 32=18, slot 38=dword_96AE74 (texture)
    - Renders via vtable[40]
- If offset 624 (effect_start_time) set: clears display buffer
```

### CPlayer__CheckGuildNameTimeout_0x8D4_0x8D8 (0x675CE8, size=57)
**Purpose**: Auto-reverts guild name display after timeout.
```
- Checks if guild name at offset 565 differs from offset 566 (original)
- If different and timeGetTime() > offset_313 + 2000ms:
  - Calls CPlayer__SetGuildName with empty/default name
  - Resets guild display to original after 2-second timeout
```

### Misc — CNpc__InitDefaults (0x66F42B, size=130)
**IDA Folder**: /Entity_Player/Misc
**Purpose**: Initializes default values for NPC entity fields.
```
- Sets DWORD at offset 286 = 0
- Initializes 5 string fields to "NULL" using sub_403BF1
- Each field receives a copy of the "NULL" string constant
```

## Helper Address Index

| Function | Address |
|---|---|
| CGameCamera__IsZoomedIn | 0x6206c8 |
| CGameMap__AddScreenOffset | 0x61d8c6 |
| CLanguage__GetLanguageName | 0x76938e |
| CImgNum__Render | 0x715506 |
| CPlayer__DrawBattleLevStarAt | 0x674a7c |
| CPlayer__DrawOverlay_0x988 | 0x674d3b |
| CPlayer__GetBaseRenderHeight | 0x675564 |
| CPlayer__GetByte_0x9F4 | 0x674d64 |
| CPlayer__GetCustomTitleId | 0x673043 |
| CPlayer__GetCustomTitleInfo | 0x6730b1 |
| CPlayer__GetDword_0x8AC | 0x674b4f |
| CPlayer__GetGuildName | 0x675ce1 |
| CPlayer__GetRenderHeightOffset_0x4E8 | 0x673a69 |
| CPlayer__GetRenderHeightOffset_0x91C | 0x673a95 |
| CPlayer__GetRenderHeightOffset_0x98C | 0x675776 |
| CPlayer__GetStringByFields_0x870_0x874 | 0x6730c2 |
| CPlayer__HasBattleLevStarResource | 0x674b01 |
| CPlayer__IsDword_0x8B0_Equal100 | 0x6729a1 |
| CPlayer__IsEntityInRange_0xAAE61_0xC34FF_AndFlag | 0x6510a2 |
| CPlayer__LoadBattleLevStarResource | 0x674ada |
| CPlayer__LoadInfoIni | 0x674601 | 1134 |
| CPlayer__LoadMonsterStatusIfMonster | 0x675d61 |
| CPlayer__NameContainsStrId_0x186BC | 0x651064 |
| CPlayer__RenderBodyEffect | 0x674af1 |
| CPlayer__RenderEffectAni | 0x66fd71 |
| CPlayer__RenderHpBar | 0x6700a2 |
| CPlayer__RenderStatusOverlay_0x12_0x17 | 0x6735ac |
| CPlayer__SelectTransparencyEffectName | 0x71e08f |
| CPlayer__UpdateLinkedEffect_0x4D4 | 0x66f53f |
| CPlayer__UpdateOverlayList | 0x72f8ff |
| CRole__Dtor | 0x64d647 |
| CRole__GetByte_0x18 | 0x650447 |
| CRole__GetOverlayYOffset_0x650980 | 0x650980 |
| CRole__GetOverlayYOffset_0x66F6D9 | 0x66f6d9 |
| CRole__GetRenderMask_0xE8 | 0x61f2da |
| CRole__GetString_0x158 | 0x6e52ec |
| CRole__HasStatusFlag | 0x6e50d4 |
| CRole__IsSchedulerProxyInEffectList | 0x6e4e98 |
| CRole__IsSchedulerProxyInSet_401_409_470_520_620 | 0x6e506a |
| CRole__Render3D | 0x64f5f7 |
| CustomTitleMgr__GetColorTypeById | 0x6e9924 |
| Deque68__IteratorDistanceMinus1 | 0x7304c8 |
| Deque68__SeekIndex | 0x7304f5 |
| EffectHelper__BuildParams_0x67772B | 0x67772b |
| EffectHelper__Process_0x6D5F83 | 0x6d5f83 |
| EffectTemplate__ApplyByName | 0x71e91d |
| EntityManager__FindEntityById | 0x6e847d |
| Entry__GetDword_0x74 | 0x6c85b5 |
| Entry__GetString_0x94 | 0x70827b |
| FamilyMgr__FindById | 0x699ef4 |
| IdMap__FindById_0x6C2F57 | 0x6c2f57 |
| IdMap__FindByKey_0x6AC9C6 | 0x6ac9c6 |
| CPlayer__CheckGuildNameTimeout_0x8D4_0x8D8 | 0x675ce8 |
| CNpc__InitDefaults | 0x66f42b |
| ScreenSpace__ApplyOriginOffset | 0x61e319 |
