# CRole Class — Base Entity

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Role.cpp` (debug string at 0x93E950).
## IDA Folder: /Entity_Role/CRole (40 functions)

## Overview

CRole is the base entity class for all in-game entities (players, NPCs, monsters). It provides
core functionality: position tracking, animation, visual representation (RoleView), status flags,
effects, and rendering. CPlayer and CHero inherit from CRole.

## Memory Layout (~1088 bytes)
```c
struct CRole {
    void* vtable;                    // +0x000 (DWORD offset 0)

    // Position
    int32_t pos_x;                   // (set to -1 on init)
    int32_t pos_y;                   // (set to -1 on init)

    // Color/tint (RGBA bytes)
    uint8_t color_b;                 // +8 (byte offset)
    uint8_t color_g;                 // +9
    uint8_t color_r;                 // +10
    uint8_t color_a;                 // +11

    // Action state fields
    uint32_t action_loop_flag;       // +96 (DWORD 24), 1=looping action
    uint32_t fade_start_time;        // +888 (DWORD 222), timestamp for fade-out
    uint8_t  debug_action_flag;      // +40 (byte), debug logging toggle

    // Status flag bitsets
    uint32_t status_flags[4];        // +112 (DWORD 28-31), 128-bit bitset
    uint32_t flag_bitset_0x70[4];    // +112 (0x70 region), 128-bit bitset
    uint32_t flag_bitset_0x90[4];    // +144 (0x90 region), 128-bit bitset
    uint16_t flag_bitset_0xA0;       // +160 (0xA0 region), 16-bit flag

    // Core identity
    uint32_t entity_id;              // +204 (DWORD 51)
    uint32_t action_speed_index;     // +60 (DWORD 15), 0-12 for speed table
    uint32_t speed_modifier;         // +72 (DWORD 18), offset from 100

    // Look / appearance
    uint16_t look_type;              // +208 (WORD, offset 104 in words)
    uint16_t linked_source_lookup_id;// +0x0D2, packet HairCompositeId % 1000, RoleView key 1
    uint16_t head_attachment_source; // +0x0D4, packet HairCompositeId / 1000, RoleView key 2
    uint32_t look_id;                // +332 (DWORD 83)
    uint32_t action_type;            // +218 (DWORD offset)

    // Name and strings
    char     name[36];               // +332 (byte offset 0x14C), max 36 chars

    // Render-scale state
    int32_t  transform_look_add_size; // +0x174 (DWORD 93), init: 0, Transform.ini AddSize
    int32_t  body_scale;              // +0x184 (DWORD 97), init: 100
    float    action_scale_multiplier; // +0x188 (DWORD 98), init: 1.0f
    // Mounted action-scale helpers traced in the current slice:
    // +0x118 cached_mounted_action_frame_interval
    // +0x128 active_mounted_action_frame_interval
    // +0x314 mounted_action_vertical_offset
    // Direct-render vertical placement state:
    int32_t  vertical_render_offset;       // +0x30C
    int32_t  target_vertical_render_offset;// +0x310
    uint8_t  scapegoat_offset_y_gate_flag; // +0x394
    int32_t  scapegoat_offset_y;           // +0x39C, from [Scapegoat].OffsetY
    int32_t  additional_offset_y;          // +0x3A4
    uint8_t  additional_offset_y_enabled;  // +0x3A8
    uint32_t health;                  // (init: 100)
    uint32_t speed;                   // (init: 50)

    // Animation state
    uint32_t action_anim;            // +420 (DWORD 105), current animation ID
    uint32_t frame_index;            // +424 (DWORD 106), current frame
    uint32_t frame_count;            // +428 (DWORD 107), total frames
    uint32_t anim_start_time;        // +436 (DWORD 109), timestamp
    uint32_t frame_interval;         // +440 (DWORD 110), ms per frame
    uint32_t sound_frame;            // +940 (DWORD 235), sound trigger frame (-1=none, -2=random)
    uint8_t  sound_played;           // +944 (byte), death sound played flag

    // RoleView (3D visual representation)
    void*    role_view;              // +948 (DWORD 237), RoleView object pointer
    uint32_t rendering_mode;        // +1056 (DWORD 264), 0=normal, 1=building, 2=texture ready
    uint32_t render_size;            // +1060 (DWORD 265), render texture size
    void*    render_texture;         // +1068 (DWORD 267), MyBitmap texture

    // Movement state (from CRole__InitMovement)
    uint32_t move_speed;             // +0x1E8 (DWORD 122), init: 5
    uint32_t move_subtype;           // +0x1EC (DWORD 123), init: 0

    // Effect objects
    Game3DEffect* effect_main;       // +1072 (DWORD 268), main 3D effect
    Game3DEffect* effect_1;          // +1076 (DWORD 269)
    Game3DEffect* effect_2;          // +1080 (DWORD 270)
    Game3DEffect* effect_3;          // +1084 (DWORD 271)
    Game3DEffect* effect_4;          // +1068 (DWORD 267)

    // Screen position (calculated from tile pos)
    int32_t screen_x;               // +856 (DWORD 214)
    int32_t screen_y;               // +860 (DWORD 215)

    // Interpolation positions
    int32_t interp_src_x;           // +404 (DWORD), start X for animation
    int32_t interp_src_y;           // +408 (DWORD), start Y
    int32_t interp_dst_x;           // +412 (DWORD), destination X
    int32_t interp_dst_y;           // +416 (DWORD), destination Y
    int32_t render_x;               // +848 (DWORD), calculated render X
    int32_t render_y;               // +852 (DWORD), calculated render Y

    // Overlay/mount offset
    uint32_t overlay_height_offset;  // +780 (DWORD 195), height term used by overlay helpers and Role_TickAndRender vertical adjustment
    uint32_t mount_offset;           // +788 (DWORD 197), mount Y offset

    // Equipment slots (18 slots)
    uint32_t equip_slots[18];        // +2712 (DWORD 678+), slot data pairs

    // Title
    uint32_t title_id;               // +2220 (DWORD 555)

    // Stipple effect flags
    uint8_t  stipple_jx;            // +2476 (byte), stipple JX effect active
    uint8_t  stipple_kdh;           // +2477 (byte), stipple KDH effect active

    // CFDword property container
    void*    cf_dword_props;         // +2424 (DWORD 606)

    // Texas Hold'em
    uint8_t  texas_actor;            // +936 (byte), is Texas actor
    int32_t  texas_y_offset;         // +932 (DWORD 233), Texas Y screen offset

    // Entity marker flags
    uint32_t radar_icon_drawn;       // +2236 (DWORD 559), already drawn on radar this frame

    // Game3DEffect objects (created in Init)
    Game3DEffect* game_effect[4];    // +1072/1076/1080/1084
};
```

## Status Flag System

CRole uses three separate bitset regions for entity status:

| Bitset | Offset | Size | Check Function |
|--------|--------|------|----------------|
| Status flags | +112 (0x70) | 128-bit | `CRole__HasStatusFlag` |
| Bit flag 0x70 | +112 | 128-bit | `CRole__SetBitFlag_0x70` |
| Bit flag 0x90 | +144 | 128-bit | `CRole__SetBitFlag_0x90` |
| Flag bitset 0xA0 | +160 | 16-bit | `CRole__HasFlagBitset_0xA0` |

### Known Status Flag Values
| Flag | Meaning | Used In |
|------|---------|---------|
| 0x02 | Hidden/invisible | Render3D (skip render) |
| 0x0A | Ghost/transparent | Render3D (shadow, lighting) |
| 0x1B | Mounted/transformed | GetOverlayYOffset, Render3D |
| 0x2E | Looping animation | Render3D (frame cycling) |
| 0x32 | Status 50 (mounted) | ProcessWalkToTarget, Render3D |
| 0x5F | Has man aim flag | Render3D (flag effects) |
| 0x76 | War flag escort | Render3D (war flag effects) |

## Functions (40 total)

### Lifecycle & Initialization (4 functions)

#### CRole__Init (0x64D260, size=703)
**Purpose**: Constructor/initializer. Creates the base entity.
```
- Sets position to (-1, -1)
- Sets health to 100
- Sets transform-look AddSize to 0 (role+0x174)
- Sets body_scale to 100 (role+0x184)
- Sets action_scale_multiplier to 1.0f (role+0x188)
- Sets speed to 50
- Creates 4 Game3DEffect objects at offsets 1072, 1076, 1080, 1084
- Initializes RoleView related fields
```

#### CRole__Dtor (0x64D647, size=722)
**Purpose**: Destructor. Cleans up visual and effect objects.
```
- Destroys RoleView object
- Cleans up effect objects at offsets 268, 269, 270, 271, 267
- Frees Game3DEffect objects
- Releases COM references
```

#### CRole__InitMovement (0x64DC52, size=31)
**Purpose**: Sets movement defaults.
```
- move_speed = 5
- move_subtype = 0
- dword[130] = 0
- dword[131] = 0
```

#### CRole__InitProperties (0x651616, size=390)
**Purpose**: Initializes all property arrays to defaults.
```
- Clears property strings
- Sets scale = 1.0 (100)
- Sets health = 100
```

### Visual / RoleView (4 functions)

#### CRole__CreateRoleView (0x64D51F, size=296)
**Purpose**: Creates visual representation for the entity.
```
- type 4 = normal role view
- type 10 = mount (look ID > 5000)
- Calls RoleViewCreate() from RoleView.dll
- Sets up visual slots
```

#### CRole__CreateRoleViewWithPos (0x64D919, size=375)
**Purpose**: Like CreateRoleView but with initial x,y position.

#### CRole__SetTransformLook (0x650B58, size=362)
**Purpose**: Configures mount/pet/transform visuals.
```
- Sets RoleView slots 3, 5, 6, 7, 8, 9
- Handles mount transforms (look > 5000)
```

#### Corrected receiver: CDummy_SetInspectedEquipmentSlot (`0x66CECF`)

This is a `CDummy` method, not a `CRole` local-equipment setter. The assert at `0x66CF6E`
names `3DRole/Dummy.cpp`. It checks the inspected-role identity against `this+0xA88`
(`0x66CEEC`) and stores shared references at `this+0xA98 + 8*(slot-1)` for slots1..12/15..18.
MsgItem subtype4 calls it on hero+`0x1EA0` and passes packet+4 as the inspection identity.
See [the corrected item contract](../Network/MsgItem1008-domain-contract-5517.md).

### Animation (3 functions)

#### CRole__SetAction (0x64DA90, size=172)
**Purpose**: Sets the current action animation on the role.
```
- Updates RoleView animation state
- Triggers animation change via vtable call
```

#### Role_UpdateActionAndDispatchRoleViewMotion (0x64E2DD, size=1736)
**Purpose**: Animation state machine. Handles frame timing and sound playback.
```
Action type handling:
- 100-560+ range action codes
- Manages frame counts and timing
- Plays sounds via DXPlaySound()
- Handles looping/one-shot animations
```

#### CRole__ApplyActionEntry_0x11C (0x64DD38, size=181)
**Purpose**: Validates and applies an action command entry (memcpy of 0x11C bytes).
```
- Validates current command type before allowing override:
  - Types < 32: always allow
  - Types 32-33, 40: allow
  - Type 41 (browbeat): checks status 50, clears browbeat if needed
  - Type 45 (IceQueen): only allow if anim is 498/499 with specific conditions
  - Type 46 (AspectWorld): checks `Role_GetStateCode1EC`
  - For blocked types: only allows command type 47 (force override)
- On success: memcpy(this+122, Src, 0x11C) — copies entire action block
- Returns 1 on success, 0 on rejection
```

### Rendering (5 functions)

#### Role_AdvanceMotionInterpolationAndRefreshPosition (0x64EAB2, size=1529)
**Purpose**: Animation-frame timing and screen-space motion interpolation.
```
- Computes current frame from elapsed time and frame interval
- Special handling for action codes 320-336, 340-344, 700:
  - Frame 700: fades effect opacity based on progress (alpha channel)
  - 320-336, 340-344: sound-triggered frame synchronization
- Gets the current body-motion composite key from RoleView property 0x1E
- Queries RoleDataSingleton vtable +0x90 for the matching ActionCtrl.ini record
- Uses piecewise-linear TimePercent/MovePercent control points when a non-empty record resolves
- Falls back to linear elapsed-time interpolation when the record is absent or empty
- Writes the interpolated screen-space cursor at CRole+0x350/+0x354
- Inverse-projects that cursor into the protected tile coordinates at CRole+0x318/+0x334
- Refreshes the projection-relative coordinates at CRole+0x358/+0x35C
- Handles death sound effects ("EndureXPDeath")
```

The easing profile is not a Bezier curve. Its exact record layout, lookup fallbacks, and integer
rounding rules are documented in
`Rendering/gamedata_dll/01_action_control_motion_easing.md`.

#### Role_TickAndRender (0x64F5F7, size=3268)
**Purpose**: Main 3D rendering pipeline for an entity.
```
- Skips if status flag 0x02 (hidden) or no RoleView or in disabled state
- Converts tile position to screen coordinates
- Calculates facing angle:
  - Normal: `(-1 - direction_index) * 45` degrees
  - Pathfinding: atan2-based interpolation from src/dst positions
  - Target chase: atan2 toward target entity
- Sets scale from `body_scale * action_scale_multiplier * 0.75f * 0.01f`
- Texas actor: adds Y offset from field 233
- Positions RoleView with (screen_x, screen_y, y_offset, angle, scale)
- Shadow rendering: "SimpleShadow" animation with opacity fade
- NPC look_id coloring: queries RoleDataQuery for NPC color tint
- Lighting: 4-component RGBA with fade support (opacity * alpha)
- Render texture mode: builds camera, renders to texture, applies as billboard
- Ghost/echo mode (field 124==1): renders translucent secondary model at 60% alpha
- Status flag effects: ManAim, MountAim, WarFlagEscorts with stipple textures
- Overlays: positions name tags, floating text, chat bubbles above entity
```

#### CRole__RenderTitleName (0x506914, size=1951)
**Purpose**: Renders the entity's name, title, guild, and stat displays in the UI panel.
```
- Reads from the game world singleton (GetSingletonPtr_404460):
  - Hero name (offset 332)
  - Entity ID (offset 2104)
  - Guild name hierarchy (0/1/2+ levels deep, with word_92D274 separator)
  - Level (offset 2152) with color coding:
    - 20-99: yellow (-65536)
    - 100+: red (-16777216)
    - <0: green (-256)
  - Spouse name (offset 1264, fallback to GameDataSetQuery)
  - Sub-profession name (sub-profession-name helper at `0x6730B1`, fallback to `GameDataSetQuery`)
  - Sub-profession level (sub-profession-level helper at `0x6730C2`)
- Title display: looks up title_id (field 555) via CTitleMgr
  - If title_id == 0 or not found: shows "STR_TITLE_NONE" string
- Stat display: attack power, magic attack, defense, magic defense
  - Formats as "X-Y" range for atk/matk
  - Uses STR_MAGIC_DEF format string for magic defense
- Calls Handle_Allot_No_Point for point allocation UI
```

#### CRole__RenderStatusIcons (0x626D8A, size=2067)
**Purpose**: Renders team/friend/tutor/student icons on the radar minimap.
```
- Player flag icon: "ani/Common.ani" -> "PlayerFlag", drawn at entity radar pos
  - Sets radar_icon_drawn (offset 2236) to prevent duplicate rendering
- Team leader icon: "TeamLeader" animation, flashes with timer (8000ms timeout)
- Friend tracking: "Friend" animation at friend's position, cycles frames (30fps)
- Team members: iterates team list, draws "PlayerFlag" frame 3 for each
  - Skips self (hero entity_id match) and already-drawn entities
- Tutor icon: "Tutor" animation for mentor entity
- Student icons: iterates student list, draws "Student" animation
- Alliance/family members: draws "PlayerFlag" frame 0/1 based on list type
- Uses CRadar__func_001 to convert world coords to radar coords
- All icons offset by global dword_969610 (radar X offset)
```

#### CRole3D__CreateEffect (0x420FF3, size=318)
**Purpose**: Creates/updates the PK effect (3D particle effect) for an entity.
```
- Uses "PkResources" effect asset name
- If PK zone active (singletons 420AAD or 420B51):
  - Creates Game3DEffect if not exists (offset 102)
  - Loads "PkResources" effect
- Positions effect at entity's screen position via CGameMap__AddScreenOffset
- Converts to 3D coordinates via the map screen-to-projection helper (`0x61E319`)
```

### Position & Direction (4 functions)

#### Role_SetTilePositionAndProjectScreenCoordinates (0x6E4C79, size=159)
**Purpose**: Commits a world-entry / spawn-style tile position and mirrors the resulting projected-screen pair into the role's movement/render caches.
```
- Writes the authoritative tile pair:
  - XteaProtectedInt_Set(role+0x318, tileX)
  - XteaProtectedInt_Set(role+0x334, tileY)
- Calls Map_ProjectTileToScreenCoordinates to compute the absolute projected screen pair.
- Writes the committed path-cursor pair:
  - role+0x350 = projectedScreenX
  - role+0x354 = projectedScreenY
- Calls CGameMap_GetPointRelativeToProjectionCenter and writes:
  - role+0x358 = projectedScreenX relative to the projection center
  - role+0x35C = projectedScreenY relative to the projection center
- Mirrors that same projected pair into the startup/current screen caches:
  - role+0x194 = projectedScreenX
  - role+0x198 = projectedScreenY
  - role+0x19C = projectedScreenX
  - role+0x1A0 = projectedScreenY
- This is the direct world-entry writer that feeds CRole_GetProjectedScreenCoordinatesFromCommittedPathCursor on the
  first world frame before later movement paths start staging through role+0x19C/+0x1A0.
- CMsgPlayerSpawn__Process is a verified caller at 0x756E7E.
```

#### CRole_SetDirectionFromPacked8 (0x650CC2, size=29)
**Purpose**: Splits a signed packed direction by eight and stores its remainder.
```
- role+0x17C = packedDirection % 8
- If the active command type at role+0x1E8 is 6:
  - role+0x210 = packedDirection % 8
- Returns packedDirection / 8 using signed division.
```

#### CRole_SetDirectionFromPacked24 (0x650CE6, size=36)
**Purpose**: Splits a signed packed direction by 24 and stores its remainder.
```
- role+0x17C = packedDirection % 24
- If the active command type at role+0x1E8 is 6:
  - role+0x210 = packedDirection % 24
- Returns packedDirection / 24 using signed division.
```

#### CRole__UpdateNameTag (0x650455, size=302)
**Purpose**: Manages name tag display timing.
```
- Checks idle timeout (5000ms threshold)
- Shows/hides name tag based on activity
```

### Status Flags & Properties (7 functions)

#### CRole__HasStatusFlag (0x6E50D4, size=70)
**Purpose**: Tests a bit in the 128-bit status flag bitset at DWORD offset 28.
```
- Returns true if flag_index < 128 AND bit is set
- Bitset stored at this[28..31] (4 DWORDs)
- Bit calculation: (1 << (index & 0x1F)) & this[(index >> 5) + 28]
```

#### CRole__SetBitFlag_0x70 (0x6E511A, size=129)
**Purpose**: Sets a bit in the 128-bit flag bitset at offset 0x70.
```
- Only operates if bit index < 128
- Calls Bitset128__SetBit(index, 1)
```

#### CRole__SetBitFlag_0x90 (0x6E519B, size=64)
**Purpose**: Sets a bit in the 128-bit flag bitset at offset 0x90.
```
- Only operates if bit index < 128
- Calls Bitset128__SetBit(index, 1)
```

#### CRole__HasFlagBitset_0xA0 (0x6E51DB, size=55)
**Purpose**: Tests a bit in the 16-bit flag at offset 0xA0.
```
- Returns true if flag_index < 16 AND bit is set
- Stored at this[40] (single DWORD, only lower 16 bits used)
```

#### Role_IsCommandType04To0BOr0EWithCompleteFallback (0x6E4F55, size=30)
**Purpose**: Checks if current action type is in specific combat/interaction range.
```
- Returns 1 if action_type >= 4 AND (action_type <= 11 OR action_type == 14)
- Otherwise returns 0
```

#### CRole__SetString_0x14C_6E5292 (0x6E5292, size=47)
**Purpose**: Sets the entity name string at byte offset 332 (0x14C).
```
- Max length: 36 characters (0x24)
- Validates non-null input and length before copy
```

#### CRole__SetDwordField606_673EAC (0x673EAC, size=86)
**Purpose**: Sets a value in the CFDword property container at offset 606.
```
- If entity is hero and property index == 1 and new value < current:
  - Triggers the HP-decrease notification helper (`0x738C69`) at `hero+11312`
- Delegates to CFDword__func_000(container, value, index)
```

### Field Accessors (10 functions)

#### CRole__GetByte_0x6C (0x650D89, size=21)
**Purpose**: Returns byte at offset 108. (Purpose unknown, possibly a state flag.)

#### CRole__GetDword_0x8AC (0x674B4F, size=8)
**Purpose**: Returns DWORD at offset 555 (title_id).

#### CRole__SetDword_0x370_650D9E (0x650D9E, size=14)
**Purpose**: Sets DWORD at offset 220.

#### CRole__GetVerticalRenderOffset (0x650FDA, size=6)
**Purpose**: Returns `vertical_render_offset` (`role+0x30C`).

#### CRole__SetVerticalRenderOffset (0x650FEE, size=17)
**Purpose**: Sets `vertical_render_offset` (`role+0x30C`) and mirrors the same value to `role+0x310`.
```
- `role+0x30C = value`
- `role+0x310 = value`
- verified callers:
  - `0x7C5B0F`: incremental effect/status path grows the offset, clamps it, then stores it
  - `0x7C645E`: effect/status clear path stores constant `0x1E`
```

#### CRole__SetVerticalRenderOffsetTarget (0x650FE1, size=10)
**Purpose**: Sets `target_vertical_render_offset` (`role+0x310`) without touching current offset `role+0x30C`.
```
- verified caller: `Role_TickCommandStateAndDispatchPlayback` (`0x6725ED`)
- that tick then smooths `role+0x30C` toward `role+0x310` by `±6` per frame
- verified gate in the NPC/shared role tick:
  - status flag `0x1B` set -> target offset `100`
  - status flag `0x1B` clear -> target offset `0`
```

#### CRole__SetScapegoatOffsetY (0x651266, size=10)
**Purpose**: Sets `scapegoat_offset_y` (`role+0x39C`).
```
- single verified caller: `CScapegoatRole__RefreshTrackedRoleProjectionAndOffsetY` (`0x7333C3`)
- value source is global `data_96B3A0`
- `data_96B3A0` is populated from `ini/Info.ini`, section `[Scapegoat]`, key `OffsetY`
  during startup init at `0x732F16`; shipped asset value is `100`
```

#### CRole__SetAdditionalOffsetYEnabled (0x6513A3, size=10)
**Purpose**: Sets `additional_offset_y_enabled` (`role+0x3A8`).
```
- verified callers are Texas NPC actor builders in `TexasNpc.cpp`:
  - `0x7487AF`
  - `0x748DAB`
```

#### CRole__SetAdditionalOffsetY (0x6513B0, size=10)
**Purpose**: Sets `additional_offset_y` (`role+0x3A4`).
```
- verified callers are Texas NPC actor builders in `TexasNpc.cpp`:
  - `0x7487AF`
  - `0x748DAB`
```

#### CRole__SetEffectDirection (0x651100, size=154)
**Purpose**: Sets the rotation direction of the main 3D effect.
```
- Loads effect sub-object from effect_main (offset 268) with sub-index a2
- Converts direction (0-7) to radians: 45 * (-3 - dir%8) * PI / 180
- Applies rotation via effect vtable[44] with (0, 0, angle, subobj, 1)
```

### Speed & Movement Calculation (1 function)

#### CRole__CalcSpeedModifier (0x65127A, size=182)
**Purpose**: Calculates movement speed with action-based modifiers.
```
- Checks action_speed_index (offset 15), must be <= 12
- Base speed = speed_modifier (offset 18) + 100
- If base <= 0: assert failure
- Clamps to max from dword_86AA30 lookup table
- If entity is not in a speed-exempt state: adjusts as 100*speed/base
- Special case for action 713: applies additional ratio from dword_86AA64/dword_86AA98 tables
```

### Overlay Y-Offset Calculation (2 functions)

#### CRole__GetOverlayYOffset_0x650980 (0x650980, size=308)
**Purpose**: Calculates vertical offset for overlays (name tags, health bars) above entity.
```
- Depends on current animation type:
  - 110-111 (walk): uses the walk overlay-offset helper (`0x6502BB`)
  - 120-121 (fast walk): uses the walk overlay-offset helper (`0x6502BB`)
  - 130, 295, 527 (mounted/special): body_scale*50/100 + `Role_GetMotionArcScreenHeightAnchor` (`0x650583`) unless flag `0x1B`
  - Other: calculates from 3D position delta
- Adds extra offsets:
  - If flag 0x1B or bitset_0xA0: adds 3*overlay_height/2
  - If flag 0x32 (mounted): adds mount_offset (DWORD 197)
```

#### CRole__GetOverlayYOffset_0x66F6D9 (0x66F6D9, size=142)
**Purpose**: Simplified version of GetOverlayYOffset (no animation-type branching).
```
- For actions 130, 295, 527 (mounted): body_scale*50/100 + `Role_GetMotionArcScreenHeightAnchor` (`0x650583`)
- Flag 0x1B/bitset_0xA0: adds 3*overlay_height/2
- Flag 0x32: adds mount_offset
```

Verified helper chain used by both overlay-offset callers:
```
Role_GetMotionArcScreenHeightAnchor (0x650583)
  -> role vfunc +0x10 (fetch current projected screen point)
  -> Map_ComputeMotionArcScreenHeightOffsetFromProjectedPoints (0x6505B3)
     inputs:
       - role+0x194/+0x198
       - role+0x19C/+0x1A0
       - current projected screen point

Role_GetTerrainHeightDeltaFromProjectedScreenPosition (0x650903)
  -> Role_GetMotionArcScreenHeightAnchor
  -> projects role+0x350/+0x354 back to tile coordinates
  -> subtracts terrain height for the current tile entry

Role_IsCurrentActionInProjectedPathFacingOverrideSet (0x6E4E5F)
  -> checks current action id in:
     0x82, 0x83, 0x84, 0x8C, 0x127, 0x1FE, 0x20F
  -> used by Role_TickAndRender to replace facing angle from:
     (role+0x19C - role+0x194, role+0x1A0 - role+0x198)

Role_IsCurrentActionInTargetEntityFacingOverrideSet (0x6E506A)
  -> Role_IsActionInTargetEntityFacingOverrideSet (0x6E5038)
  -> checks action id in:
     0x191..0x199, 0x1D6, 0x208, 0x26C
  -> used by Role_TickAndRender to replace facing angle from:
     (targetProjectedX - role+0x350, targetProjectedY - role+0x354)
```

These two helpers are rotation-only branches. They do not contribute to the
direct-render vertical terms (`var_1c` / `var_20`) used for startup/local-hero
placement.

### Action Queue Processing (2 functions)

#### CRole__ApplyActionWithQueue_6720EE (0x6720EE, size=574)
**Purpose**: Complex action queue processor that handles action sequencing and buffering.
```
- Routes based on incoming command type:
  - Type 47 (force): flushes ring buffer (offset 568-572), processes all queued
    actions via CRoleAction__ProcessCommand, then applies new action
  - Types 38-39, 42-43 (Texas/combat): same flush-and-apply behavior
  - Type 8 with param 315 (special combat): flush and direct apply
  - Type 25 (mutual): flush and direct apply
  - Types 15-24 (interaction/skills): replays ring buffer backwards,
    preserving types 4-11,14,25 entries, then queues
  - Types < 15, > 36 (general): queues via the general action-queue helper (`0x6763EC`)
- Ring buffer at offsets 568-572: stores pending action entries
- Each queued action is replayed: ApplyActionEntry -> ProcessCommand -> command replay helper (`0x64E9A5`)
```

#### CRole__ProcessTimedActionQueue_0x440 (0x6724C6, size=188)
**Purpose**: Processes a timed action linked list at offset 272.
```
- Walks linked list, checking timeGetTime() >= entry.timestamp (offset 73)
- When ready: applies action entry via CRole__ApplyActionEntry_0x11C
- Plays animation if entry has different start/end frames (vtable[16] on effect)
- Plays sound via DXPlaySound if entry has sound data (offsets 77-78)
- Removes processed entry from list
```

### Visual Effects (2 functions)

#### CRole3D__CreateObj (0x64CB60, size=58)
**Purpose**: Creates a Simple3DObj for visual effects at a position.
```
- Stores parameters: position, timing (a5, a6)
- Records timeGetTime() as creation timestamp
- Calls Simple3DObjCreate(a2) and stores result at offset 5
- Returns whether creation succeeded
```

#### CRole__UpdateHelper_0x673AB4 (0x673AB4, size=178)
**Purpose**: Manages stipple (transparency/dithering) visual effects.
```
- Two independent stipple effects:
  1. "StippleJx" (offset 2476): toggled by the first stipple-state helper (`0x673BB1`)
  2. "StippleKdh" (offset 2477): toggled by the second stipple-state helper (`0x673C6D`) and `g_bSimplifiedRenderMode`
- Each effect: adds via effect_main vtable[16] when enabling, removes via the effect-removal helper (`0x651205`)
- Tracks active state in single-byte flags at offsets 2476/2477
```

### Mount / Horse Configuration (2 functions)

#### CRole__HorseRun800 (0x4CC385, size=26)
**Purpose**: Selects horse run animation string based on screen resolution.
```
- If high-res (byte_9562F0): uses "HorseRun"
- If low-res: uses "HorseRun800"
- Stores result in global dword_9562C0
```

#### CRole__HorseRun (0x4CEAC7, size=3103)
**Purpose**: Initializes all mount/horse configuration from INI settings.
```
- Reads "ini/GameSetup.Ini" to detect screen resolution mode
- Loads mount animation parameters from INI:
  - DummyScale (default 50), DummyOffsetX (60), DummyOffsetY (80)
  - DummyRotateX (0), DummyRotateY (0), DummyRotateZ (-90)
  - MovieBGOffsetX (50), MovieBGOffsetY (50), MovieBGW (500), MovieBGH (300)
  - MovieBegin (0), MovieEnd (10000)
  - BgEffectBegin (0), BgEffectEnd (10000)
  - BorderOffsetX (1), BorderOffsetY (2)
- Sets resolution-dependent asset paths:
  - HorseAff/HorseAff800, HorseBack/HorseBack800
  - HorseRun/HorseRun800, SceneApp/SceneApp800
  - SceneDis/SceneDis800, SceneGoon/SceneGoon800
  - HorseGrid/HorseGrid800
```

## Helper Address Index

| Function | Address | Size |
|---|---|---|
| CRole3D__CreateEffect | 0x420FF3 | 318 |
| CRole__HorseRun800 | 0x4CC385 | 26 |
| CRole__HorseRun | 0x4CEAC7 | 3103 |
| CRole__RenderTitleName | 0x506914 | 1951 |
| CRole__RenderStatusIcons | 0x626D8A | 2067 |
| CRole3D__CreateObj | 0x64CB60 | 58 |
| CRole__Init | 0x64D260 | 703 |
| CRole__CreateRoleView | 0x64D51F | 296 |
| CRole__Dtor | 0x64D647 | 722 |
| CRole__CreateRoleViewWithPos | 0x64D919 | 375 |
| CRole__SetAction | 0x64DA90 | 172 |
| CRole__InitMovement | 0x64DC52 | 31 |
| CRole__ApplyActionEntry_0x11C | 0x64DD38 | 181 |
| Role_UpdateActionAndDispatchRoleViewMotion | 0x64E2DD | 1736 |
| Role_AdvanceMotionInterpolationAndRefreshPosition | 0x64EAB2 | 1529 |
| Role_TickAndRender | 0x64F5F7 | 3268 |
| CRole__UpdateNameTag | 0x650455 | 302 |
| CRole__GetOverlayYOffset_0x650980 | 0x650980 | 308 |
| CRole__SetTransformLook | 0x650B58 | 362 |
| CRole_SetDirectionFromPacked8 | 0x650CC2 | 29 |
| CRole_SetDirectionFromPacked24 | 0x650CE6 | 36 |
| CRole__GetByte_0x6C | 0x650D89 | 21 |
| CRole__SetDword_0x370_650D9E | 0x650D9E | 14 |
| CRole__GetVerticalRenderOffset | 0x650FDA | 6 |
| CRole__SetVerticalRenderOffsetTarget | 0x650FE1 | 10 |
| CRole__SetVerticalRenderOffset | 0x650FEE | 17 |
| CRole__SetEffectDirection | 0x651100 | 154 |
| CRole__SetScapegoatOffsetY | 0x651266 | 10 |
| CRole__SetAdditionalOffsetYEnabled | 0x6513A3 | 10 |
| CRole__SetAdditionalOffsetY | 0x6513B0 | 10 |
| CRole__CalcSpeedModifier | 0x65127A | 182 |
| CRole__InitProperties | 0x651616 | 390 |
| CDummy_SetInspectedEquipmentSlot (receiver correction) | 0x66CECF | 205 |
| CRole__GetOverlayYOffset_0x66F6D9 | 0x66F6D9 | 142 |
| CRole__ApplyActionWithQueue_6720EE | 0x6720EE | 574 |
| CRole__ProcessTimedActionQueue_0x440 | 0x6724C6 | 188 |
| CRole__UpdateHelper_0x673AB4 | 0x673AB4 | 178 |
| CRole__SetDwordField606_673EAC | 0x673EAC | 86 |
| CRole__GetDword_0x8AC | 0x674B4F | 8 |
| CRole__SetTilePosAndScreenPos | 0x6E4C79 | 159 |
| Role_IsCommandType04To0BOr0EWithCompleteFallback | 0x6E4F55 | 30 |
| CRole__HasStatusFlag | 0x6E50D4 | 70 |
| CRole__SetBitFlag_0x70 | 0x6E511A | 129 |
| CRole__SetBitFlag_0x90 | 0x6E519B | 64 |
| CRole__HasFlagBitset_0xA0 | 0x6E51DB | 55 |
| CRole__SetString_0x14C_6E5292 | 0x6E5292 | 47 |
