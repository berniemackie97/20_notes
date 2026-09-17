# CHero Class — Local Player (Singleton)

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Hero.cpp` (debug string at 0x93F114).
## Inherits: CPlayer -> CRole
## IDA Folder: /Entity_Hero/ (8 sub-folders, 160 functions total)

## Memory Layout (~12,300 bytes)
```c
struct CHero : CPlayer {
    // CHero extends CPlayer with massive additional state

    // Map singleton
    void* map_singleton;             // (this-611) via SetMapSingleton

    // Inventory system (18 slots, 8 bytes each)
    struct InventorySlot {
        uint32_t item_id;
        uint32_t item_data;
    };
    InventorySlot inventory[18];     // offset 931 (DWORD)

    // Level/Experience
    struct LevelExpEntry {
        int32_t  level;              // level number
        int32_t  unknown;
        int64_t  base_exp;           // base experience for level
        int64_t  total_exp;          // total experience needed
        uint32_t unknown2;
    };
    LevelExpEntry* level_exp_table;  // offset 1151: loaded from ini/LevExp.dat
    // Max level: 150
    // Format: "%d %d %I64d %I64d %u" (24 bytes per entry)

    // Magic cooldown timers
    uint32_t magic_timer_type13_19_timestamp;  // offset 1179
    uint32_t magic_timer_type13_19_duration;   // offset 1180
    uint32_t magic_timer_type14_27_timestamp;  // offset 1177
    uint32_t magic_timer_type14_27_duration;   // offset 1178
    uint32_t magic_timer_type14_8_timestamp;   // offset 1182
    uint32_t magic_timer_type14_8_duration;    // offset 1183

    // Arrow/ammo system
    uint32_t arrow_count_a;          // offset 2826
    uint32_t arrow_count_b;          // offset 2827

    // XP bar rendering
    uint32_t xp_bar_countdown;       // offset 826: remaining XP blocks
    uint32_t xp_bar_start_time;      // offset 848: countdown start timestamp
    uint32_t xp_bar_cast_time;       // offset 852: last action timestamp
    uint32_t xp_bar_elapsed;         // offset 853: elapsed timestamp

    // Container/warehouse system (indexed 0-9)
    void*    current_container;      // offset 2983: current active container
    void*    item_list;              // offset 2986: item list pointer
    void*    container_ids;          // offset 2989: container ID array
    void*    warehouse_container;    // offset (accessed via warehouse getter/setter methods)

    // School/mentor system
    void*    school_object;          // offset 2994

    // Interaction system
    uint32_t interact_target_a;      // offset 3000
    uint32_t interact_target_b;      // offset 3001
    uint32_t interact_target_c;      // offset 3002

    // Pet system
    void*    pet_list_ptr;           // offset 3017
    uint32_t pet_list_count;         // offset 3018

    // Linked list data
    void*    linked_list_head;       // offset 3071
    uint32_t linked_list_count;      // offset 3072

    // Magic system (inherited offsets from CRole/CPlayer)
    // CMagic* magic_list_ptr;       // offset 4616 (8 bytes per entry: ptr + refcount)
    // uint32_t magic_list_count;    // offset 4620

    // Chat bubble rendering
    uint8_t  chat_bubble_active;     // offset 11796
    uint8_t  chat_bubble_visible;    // offset 11797
    uint32_t chat_bubble_start;      // offset 11808
    uint32_t chat_bubble_end;        // offset 11812
};
```

## Combat (25 functions, all verified through decompilation)

### CHero__ProcessPlayerAction (0x5AFEDF, size=~5800)
**Purpose**: Top-level player action handler. Massive dispatcher for all player-initiated actions.
```
- Processes keyboard/mouse input into game actions
- Validates player state before allowing actions
- Handles "wallow" (anti-addiction) restrictions with system messages
- Checks map flags (bit 0x10 for PK restrictions)
- Validates status flags (0x1C for ranged, 0x1B for melee)
- Range checking: computes attack range from hero + target body sizes
- Sends CRoleAction command type 31 (attack) with target entity ID
- Calls Handle_Server_Forbid_Pk for PK zone validation
- Calls Handle_Ride_Match_Msg_Forbid_Jump for mounted combat
- Error messages via CChatLog: 100141 (out of range), 100028/100029 (name check), 100126 (guild PK)
```

### CHero__ProcessJump (0x658033, size=425)
**Purpose**: Handles jump action (type 32).
```
State machine: 0 -> 2 -> 6
- State 0: Initiate jump
- State 2: In-air
- State 6: Landing
Validates movement is possible before jumping.
```

### CHero__ProcessDash (0x6581DC, size=351)
**Purpose**: Handles dash action (type 33).
```
State machine: 0 -> 2 -> 6
After dash completes: triggers action 711 (post-dash effect)
Similar to jump but with directional momentum.
```

### CHero__ValidateAttackCommand (0x65B625, size=1558)
**Purpose**: Validates whether the hero can attack a target entity.
```
Validation chain:
1. Check if hero is in valid attack state (sub_65AF57, sub_657B03)
2. Verify target is not self (target ID != hero ID at offset 0x2EE0)
3. Check hero offset 73 (entity active flag)
4. Status flag 0x1C: ranged attack range check
5. Map flag 0x10: PK zone restriction
6. sub_67584F: additional state check
7. sub_6F621C: magic state check
8. sub_66312A: mentor state (50 = blocked, non-zero = wallow check)
9. Handle_Server_Forbid_Pk: server PK restriction
10. CheckState2EECAndEntityFlag: state 0x2EEC validation
11. Range calculation: (hero_size + target_size + 1) / 2 + attack_range
12. On success: sends CRoleAction type 31 (attack), sets offset 841 = 1
Error messages: 100028 (name filter), 100029 (name confirm), 100126 (guild PK)
```

### CHero__SendInteractMsg (0x65BC3B)
**Purpose**: Sends MsgInteract (type 12) to server.
```
Constructs and sends interaction packet with target entity info.
```

### CHero__ProcessAction_Main (0x65C0F5, size=2558)
**Purpose**: Main action dispatcher. Routes all hero action types.
```
Action type mapping:
  6  -> Use item (inventory interaction)
  12 -> Send interaction message (MsgInteract)
  20 -> Melee attack
  21 -> Ranged attack (bow/crossbow)
  27 -> Team invite
  28 -> Team accept
  30 -> Team leave/dismiss
  110-111 -> Melee skill attacks
  115 -> Special melee
  119-121 -> Ranged skill attacks
  122-123 -> Magic/spell casting
  280 -> Peerage interaction
  470 -> Qualifying match (uses XOR obfuscation on action data)
```

### CHero__RenderXpBar (0x65E497, size=2151)
**Purpose**: Renders the XP skill bar and associated buff timers on screen.
```
Rendering pipeline:
1. Call sub_661057, sub_661304, sub_6611E9, sub_666C57 (pre-render helpers)
2. Render hit number animations (CImageStringHitNum, CZoomInImgString)
3. Check multiple status flags for different XP bar types:
   - Flag 0x04: Basic countdown (20 second timer, screen_y - 85)
   - Flag 0x70: Magic 10390 XP bar (queries CMagic data record for duration)
   - Flag 0x2F: Magic 6011 XP bar
   - Flag 0x2E: Magic 6010 XP bar (duration = field0 * field4 * 1000)
   - Flag 0x5C: Magic 10309 XP bar
   - Flag 0x12: Generic XP countdown (20 second total)
   - Flag 0x17: Similar to 0x12
4. For each bar type:
   - Compute remaining blocks: offset_826 - elapsed_seconds
   - Render "ani/Common/ani" -> "XpBlock" icons (35px spacing, 3 tiers)
   - Render progress bar via sub_73CC4F / sub_73CB6E
5. Map flag checks: 0x4000000, 0x10000000 for special rendering modes
6. Falls through to CPlayer__RenderFullNamePlate if applicable
```

### CHero__AutoMine (0x65ED95, size=260)
**Purpose**: Automatic mining with cooldown.
```
- 20 second cooldown between mine actions
- Sends action type 93 to server
- Checks if hero is at valid mining position
```

### CHero__SpawnNpcRole (0x660AC5, size=599)
**Purpose**: Creates a local NPC role entity.
```
- Queries NPC data from RoleData
- Creates CRole object with type 17 (NPC)
- Sets up visual representation
- Places at map coordinates
```

### CHero__MagicEffect_SetTimer_Type13_19 (0x660F91, size=99)
**Purpose**: Sets magic cooldown timer for effect type 13, subtype 19.
```c
// Queries magic data by ID and level
// Validates: Load_MagicEffect_Ini(id, level, 13) == 19
// Sets timer:
this->offset_1180 = 1000 * magic_data.field4;  // duration in ms
this->offset_1179 = timeGetTime();              // start timestamp
```

### CHero__MagicEffect_SetTimer_Type14_27 (0x660FF4, size=99)
**Purpose**: Sets magic cooldown timer for effect type 14, subtype 27.
```c
// Queries magic data by ID and level
// Validates: Load_MagicEffect_Ini(id, level, 14) == 27
// Sets timer:
this->offset_1178 = 1000 * magic_data.field4;  // duration in ms
this->offset_1177 = timeGetTime();              // start timestamp
```

### CHero__MagicEffect_SetTimer_Type14_8 (0x661186, size=99)
**Purpose**: Sets magic cooldown timer for effect type 14, subtype 8.
```c
// Queries magic data by ID and level
// Validates: Load_MagicEffect_Ini(id, level, 14) == 8
// Sets timer:
this->offset_1183 = 1000 * magic_data.field4;  // duration in ms
this->offset_1182 = timeGetTime();              // start timestamp
```

### CHero_BeginPendingMutualInteraction (0x664221)
**Purpose**: Initializes local pending-interaction state from `CMsgInteract` subtype `47`.

Verified behavior:
- Requires the opposite entity ID to differ from the local hero ID.
- Resolves the partner without local-hero fallback and creates the controller from the
  packet interaction type.
- Stores partner ID at `CHero+0x2EE0`, orientation at `+0x2EDD`, controller meeting tile
  at `+0x2EE4/+0x2EE8`, and status `1` at `+0x2EEC`.
- Writes interaction type/action ID to `CRole+0x388/+0x38C`.
- Target orientation validates a different nonzero meeting tile through
  `MapPathService_TryBuildPath(outputPath=null, limitSearchNodes=true)`. Failure dispatches
  `STR_INTERACT_FORBID_CANTREACH` with message code `0x7D5` and color `0xFFFF0000`, then sends subtype `50`.
- Reachability success or already occupying the meeting tile stops active autorun. A zero meeting tile
  sends subtype `50`; otherwise the controller is invoked and
  `Role_RequestCommandType12MoveToTile` (`0x657CD6`) immediately dispatches command type `0x12`.
- Source orientation invokes the controller without movement. Both successful orientations post main-window
  message `0x464` with `wParam=0xBFF`, `lParam=0`.

### CHero_TickInteractionActionState (0x664505)
**Purpose**: Advances local pending mutual-interaction state each frame.

When status `1` reaches `CHero+0x2EE4/+0x2EE8`, this function changes status to `2` and
sends `CMsgInteract` subtype `49` with the local hero, partner, current tile, and interaction
type. A separate status-`3` recovery branch queues command type `7`, action `0x278` after
its verified 30-second timeout.

### CHero interaction packet senders
- `CHero_SendMsgInteractSubtype47` (`0x66485B`): sends subtype `47` only at status `0`.
- `CHero_SendInteractionStopSubtype50` (`0x6648E5`): sends subtype `50` only at nonzero
  status and when `CGameMap_HasOverlayRenderModeFlag` is false.
- `CHero_SendMsgInteractSubtype48` (`0x664983`): sends subtype `48` only at status `0`.

### CHero__UpdateMagicByIdLevelCaster (0x6F5546, size=502)
**Purpose**: Updates an existing magic entry or creates a new one by magic ID, level, and caster.
```
Search algorithm:
1. Iterate magic list at offsets 4616/4620 (8 bytes per entry: ptr + refcount)
2. For each entry, get CMagic data record (via CMagic__GetMagicDataRecord)
3. Compare field 0 (magic ID) and field 9 (caster ID)
4. If found: update level/caster fields, call MagicEffect_SetTimer for types 13/14
5. If not found: create new CMagic, add to list, set all timer types
Calls:
- MagicEffect_SetTimer_Type13_19
- MagicEffect_SetTimer_Type14_27
- MagicEffect_SetTimer_Type14_8
- MagicEffect_RecordCastTime
```

### CHero__CountMagicByEffectParam25_0 (0x6F573C, size=146)
**Purpose**: Counts magic entries where effect parameter at offset 25 equals 0.
```c
int count = 0;
for (int i = 0; i < magic_list_count; i++) {
    CMagic* magic = magic_list[i];
    MagicDataRecord* rec = CMagic__GetMagicDataRecord(magic);
    if (rec->field_25 == 0) count++;
}
return count;
```

### CHero__GetMagicByEffectParam25_0 (0x6F57CE, size=586)
**Purpose**: Gets the Nth magic entry where effect parameter at offset 25 equals 0.
```
- Iterates magic list searching for entries with field_25 == 0
- Returns the Nth matching entry (0-indexed)
- Used for building UI lists of active buff/debuff effects
```

### CHero__ValidateMagicUse (0x6F5A18, size=1613)
**Purpose**: Massive validation function for magic/skill use.
```
Validation checks:
1. Verify magic exists in hero's magic list
2. Check cooldown timers haven't expired
3. Validate mana/stamina requirements
4. Check status flags that prevent casting
5. Verify target validity (range, line of sight)
6. Check map restrictions for magic use
7. Validate weapon requirements for weapon skills
8. Returns success/failure with error message codes
```

### CHero__MagicEffect_RecordCastTime (0x6F6065, size=450)
**Purpose**: Records the timestamp when a magic effect was cast.
```
- Stores cast time in an internal map keyed by magic ID
- Used by cooldown system to track per-spell cooldowns
- Map operations: lookup, insert, update timestamp
```

### CHero__ProcessMagicAction (0x6F6227, size=~5500)
**Purpose**: Main magic action dispatcher. Routes magic cast actions by magic type/effect.
```
Major magic type handlers:
- Type lookups via Load_MagicEffect_Ini
- Processes magic effect categories (damage, buff, heal, summon, etc.)
- Constructs and sends MsgInteract packets for server-side magic processing
- Handles AoE targeting, single target, self-cast
- Manages magic animation playback
- Updates cooldown timers after successful cast
- Interacts with weapon skill system for melee-magic combos
```

### CHero__CountMagicByEffectParam25_1 (0x6F77D9, size=147)
**Purpose**: Counts magic entries where effect parameter at offset 25 equals 1.
```c
// Same pattern as CountMagicByEffectParam25_0 but checks field_25 == 1
// Used for a different category of magic effects
```

### CHero__GetMagicByEffectParam25_1 (0x6F786C, size=220)
**Purpose**: Gets the Nth magic entry where effect parameter at offset 25 equals 1.
```
Same iteration pattern as GetMagicByEffectParam25_0 but for param25 == 1.
```

### CHero__CountMagicByEffectParam25_2 (0x6F7948, size=147)
**Purpose**: Counts magic entries where effect parameter at offset 25 equals 2.
```c
// Same pattern as CountMagicByEffectParam25_0 but checks field_25 == 2
// Third category of magic effects
```

### CHero__GetMagicByEffectParam25_2 (0x6F79DB, size=220)
**Purpose**: Gets the Nth magic entry where effect parameter at offset 25 equals 2.
```
Same iteration pattern as GetMagicByEffectParam25_0 but for param25 == 2.
```

### CHero__AddNewWeaponSkillToList (0x71D25D, size=438)
**Purpose**: `CHero::AddNewWeaponSkill(DEQUE_WEAPONSKILL&, type, level, exp, nextLevelExpRequired)`.
```
- Scans the given deque for an entry whose +4 == type
- Found: writes +8 = level, +0xC = exp, +0x10 = nextLevelExpRequired, then looks up
  RoleDataQuery()->vtbl[0x94](type * 100 + level) and, if that record has a non-empty
  range, drives the level-up effect via (hero+0x430)->vtbl[0x10] and DXPlaySound
- Not found: operator new(0x94) + CWeaponSkill__Ctor, same four writes, push_back
- So level-up feedback fires only on an update, never on the initial snapshot
- CHECK "pSkill" at 0x71D3AB -> 3DRole\HeroWeaponSkill.cpp line 0xB3
```

### CHero__GetWeaponSkillByType (0x71D415, size=~200)
**Purpose**: `CHero::GetWeaponSkill(int nWeaponSkillType)` — returns `shared_ptr<CWeaponSkill>`.
```
- Searches the three WEAPON SKILL deques in order: +0x1180, +0x11A8, +0x11D0
  (single-hand, double-hand, other) — these are NOT magic lists
- Each is a deque of shared_ptr (raw ptr + control block)
- Delegates per list to CHero__GetWeaponSkillByTypeFromList (0x71CED7),
  which matches entry+0x4 == m_nWeaponSkillType
- Returns the first hit, else an empty shared_ptr
- Consumers: item tips (0x5803F8, 0x6DA781, 0x718DA9) read entry+0x8 (level)
  to gate proficiency requirements; MsgFlushExp 1104 action 0 writes
  entry+0xC and entry+0x10
```

## Core (69 functions, all verified through decompilation)

### Lifecycle & Initialization (3)

### CHero__Dtor (0x6562D0, size=2272)
**Purpose**: Destructor. Full cleanup chain.
```
Cleanup order:
1. Destroy 3D effects, COM objects
2. Call CPlayer__Destructor
3. CPlayer calls CRole__Dtor
Destroys: pet effects, school objects, inventory containers, etc.
```

### CHero__Init (0x656BB0)
**Purpose**: Constructor. Full hero initialization.
```
1. Call CRole::Init (base entity setup)
2. Set up 18 inventory slots (offset 931, 8 bytes each)
3. Load Info.ini offsets for hero configuration
4. Create RoleView for hero model
5. Initialize subsystems:
   - Inventory containers
   - Equipment slots
   - Pet system
   - School/mentor
   - Chat system
   - Status effects
```

### CHero__Reset (0x65700E, size=1733)
**Purpose**: Full hero state reset (e.g., on respawn/teleport).
```
Clears:
- All inventory containers
- Team/party data
- Active effects and visuals
- Movement/action state
Reinitializes:
- Subsystem pointers
- Status flags
Sends action codes:
- 0x46F (1135): Reset notification
- 0x491 (1169): State sync
- 0x4A6 (1190): Additional reset
```

### Level / Experience (4)

### CHero_LoadLevelExpTable (0x65FFE4, size=444)
**Purpose**: Loads the 5517 level-experience tables from the encoded text asset.

Verified binary contract:

- Opens exactly `ini/LevExp.dat` through `DecodedTextDatReader` with seed `0x4D2` (1234).
- Parses each non-empty decoded line with `%d %d %I64d %I64d %u`.
- The first integer is a table key; the second is the one-based level and is validated in
  `1..150`.
- Appends one 24-byte record to the vector for that key in the map at `CHero+0x11FC`.
- Increments `CHero+0x11F8` for every key-0 row.

This corrects the old description of the first two columns as `level, unknown` and the first qword
as `base_exp`. Decoding the shipped file proves that the first two columns are `key, level`; its
first rows are `0 1 120 2 3`, `0 2 180 2 3`, and so on. The first qword of each key-0 record is the
player's next-level experience requirement.

The similarly named loose `ini/LevelExp.dat` is a different binary asset inherited from the older
client path. The 5517 loader at this address does not open it.

### CHero_GetNextLevelExp (0x6601A7, size=119)
**Purpose**: Returns the current level's next-level experience requirement.

The function reads `CHero+0x838`, validates `level - 1` in `[0,149]`, looks up table key `0`, and
returns the first qword at `(level - 1) * 24`. It returns zero for an invalid level and
`0x00000000FFFFFFFF` when the key-0 vector is too short. The direct ancestor calls its equivalent
method `GetNextLevelExp`; the name is independently fixed here by the 5517 data and HUD consumer.

### CHero__CalcExpProgress (0x660270, size=394)
**Purpose**: Calculates experience percentage toward next level.
```
- Handles level 150 cap (returns 0 at max level)
- Computes: (current_exp - level_base_exp) / (next_level_exp - level_base_exp)
- Applies bonus multipliers from server
```

### CHero__CalcExpWithBonus (0x6603FA, size=431)
**Purpose**: Computes experience gain with time-based bonuses.
```
- Applies server-defined bonus multipliers
- Handles double XP events
- Returns final adjusted exp value
```

### Configuration & UI (4)

### CHero__CONTRI_TYPE_FINANCE (0x46EF2F, size=~320)
**Purpose**: Faction/guild contribution ranking dialog handler.
```
- Validates contribution type (a2) against current type at offset 400
- Max type index: 9 (asserts on > 9)
- Clears UI controls at offsets 15516, 15852, 412
- Hides CWnd windows at offsets 16516, 16676
- Stores type at offset 400, sets offset 408 = 1
- Calls CDlgFactionContriRank__func_003, Handle_Syn_Top_Duty_Tip
- Creates and sends CMsgContainerInfo packet
```

### CHero__LoadSkillHotkeys (0x5BB2E4, size=~1080)
**Purpose**: Handles skill hotkey activation from keyboard shortcuts.
```
Skill type dispatch (via sub_5A16AB):
- Type 1: Item use (searches inventory by item ID, calls CItem__GetUID)
- Type 2: Magic skill (validates via Handle_Magic_Lack_Sub_Access, calls ProcessMagicAction)
  - Magic IDs 0x564-0x58A: maps to CDlgDanceAct indices 2-16
  - Magic IDs 1190, 1195: direct ProcessMagicAction call
  - Others: creates "MagicSkillType%d" hotkey entry
- Type 3: XP skill (validates, queries CMagic data, checks magic 10309 for status 0x5C)
  - Creates "XpSkillType%d" hotkey entry
- Type 4: CDlgDanceAct activation
- Type 5: PostMainWndMsg 0xC29
- Type 6: sub_41A007 call
Error: 10382 (skill not accessible)
```

### CHeroConfigMgr__func_000 (0x651C06, size=~550)
**Purpose**: Resolves animation file path with version suffix.
```
- Loads version number from Info.ini via Load_info_Ini_652AEF
- Tries: "ani/{name}{version}.ani" first
- Falls back to: "ani/{name}.ani" if versioned file doesn't exist
- Checks file existence via sub_76A05B (GetCurrentDirectory + path concat)
- Asserts if strFileKey is empty
```

### CHeroConfigMgr__func_003 (0x653B92, size=~660)
**Purpose**: Initializes default keyboard hotkey bindings and saves to INI.
```
Default key mappings (action code -> virtual key):
  110 -> 32 (Space)    201 -> 83 (S)      301 -> 70 (F)
  401 -> 1096          402 -> 71 (G)      403 -> 84 (T)
  404 -> 75 (K)        405 -> 73 (I)      406 -> 79 (O)
  407 -> 81 (Q)        408 -> 1108        409 -> 77 (M)
  410 -> 72 (H)        501 -> 67 (C)      504 -> 74 (J)
  506 -> 78 (N)        601 -> 87 (W)      604 -> 220
  605 -> 86 (V)        801 -> 1095        802 -> 1091
  901 -> 65 (A)        902 -> 192 (~)     903 -> 82 (R)
  904 -> 76 (L)        905 -> 69 (E)      906 -> 80 (P)
- Saves to INI with "UserDataVer" key
- Writes via WritePrivateProfileStringA
```

### Title & Display (3)

### CHero__SetTitleLabelData (0x6577BF, size=~60)
**Purpose**: Sets hero title label properties.
```c
this->offset_3552 = title_id;      // title ID
this->offset_3556 = title_flag;    // title display flag (byte)
strcpy(this->offset_3560, title_string);  // title text
```

### CHero__SelectBestEncodedIdFromList_65782D (0x65782D, size=~275)
**Purpose**: Selects the best encoded ID from a list at offsets 927/928.
```
Encoding: (id - 30000000) / 10000 = priority tier
Selection criteria (priority order):
1. Lower tier number = higher priority
2. Higher id % 10 value (sub-priority)
3. Lower id % 10000 / 100 index (from lookup table: 4,1,2,3)
Special: tier 255 -> sets offset 930 = 0 (no valid ID)
Result stored at offset 930.
```

### CHero__GetStringByFields_0x178_0x82C (0x66063D, size=~30)
**Purpose**: Builds display string from two field offsets.
```c
return sub_73C7C5(this->offset_94, this->offset_523);
// Combines fields 0x178 and 0x82C into formatted string
```

### Encryption & Notification (3)

### CHero__EncryptString (0x661F10, size=60)
**Purpose**: Encrypts a string using CEncryptData.
```c
return CEncryptData__EncryptString(string);  // XOR-based string encryption using key table
```

### CHero__SetNotifyMessage (0x662DA9, size=~50)
**Purpose**: Sets a notification message string on the hero.
```c
if (str && strlen(str) < 256)
    memcpy(this->offset_12056, str, strlen(str));
```

### CHero__ClearLastHeroEntry (0x662D0A, size=~30)
**Purpose**: Removes the last entry from the hero entry list at offset 3020.
```c
// List stores 24-byte entries
if (list.begin != list.end) {
    list.end -= 24;
    cleanup(list.end);
}
```

### Status Effects & State (5)

### CHero__LoadStatusEffect (0x6633FC, size=245)
**Purpose**: Loads status effect visual definitions.
```
Status effect codes: 50, 51, 52, 53
- Each code maps to a specific visual overlay
- Loads sprite/animation resources for each effect type
```

### CHero__IsDword_0x2EEC_NonZero (0x6647B1, size=12)
**Purpose**: Returns true if hero state 0x2EEC is non-zero.
```c
return GetDword_0x2EEC() != 0;
```

### CHero__CheckState2EECAndEntityFlag_6647BD (0x6647BD, size=~130)
**Purpose**: Complex state validation for combat/interaction readiness.
```
State 0x2EEC values:
  0 -> return 1 (ready)
  1,2 -> return 0 (busy)
  3+ -> check entity flag at offset 904/11997 via vtable call
Returns: 1 if ready for action, 0 if blocked
```

### CHero__IsDword_0x2EEC_Equal3 (0x66483F, size=14)
**Purpose**: Returns true if hero state 0x2EEC equals 3.
```c
return GetDword_0x2EEC() == 3;
```

### CHero__CheckTexasHoldemEntry (0x664BCB, size=560)
**Purpose**: Validates entry requirements for Texas Hold'em table.
```
- Checks player gold: must have >= 10x minimum bet
- Validates player state (not in combat, etc.)
- Returns success/failure with appropriate error message
```

### Container Management (2)

### CHero__ClearBlock_0x2E7C_0x28 (0x66563D, size=~80)
**Purpose**: Full reset of inventory container system.
```
1. Call sub_668B84 on container at offset 2983
2. memset(offset_2973, 0, 0x28) — clear 40 bytes of container state
3. Reset item list at offset 2986/2987
4. Reset container IDs at offset 2989
```

### CHero__GetLinkedListEntry (0x667582, size=130)
**Purpose**: Retrieves an entry from a linked list by index.
```c
// Iterates linked list at offset 3071
// Returns entry data and copies value to output parameter
// Validates index < offset_3072 (count)
```

### Buffer / Pointer Accessors (3)

### CHero__GetPtr_0xE7C_657775 (0x657775, size=7)
**Purpose**: Returns pointer to buffer at byte offset 3708 (0xE7C).
```c
return (char*)this + 3708;
```

### CHero__AppendU32_ToBuf_0xE7C_65777C (0x65777C, size=~20)
**Purpose**: Appends a uint32 value to the buffer at offset 0xE7C.
```c
DwordBuf__AppendU32_63361E(this + 3708);
```

### CHero__GetDword_0xE88_6577A3 (0x6577A3, size=7)
**Purpose**: Gets DWORD at offset 930 (0xE88 bytes).
```c
return this->offset_930;
```

### Guild/Syndicate ID (2)

### CHero__GetDword_0x86C (0x673043, size=7)
**Purpose**: Gets guild/syndicate ID at offset 539 (0x86C bytes).
```c
return this->offset_539;
```

### CHero__SetDword_0x86C (0x67304A, size=~60)
**Purpose**: Sets guild/syndicate ID with special handling.
```c
if (this->offset_539 != value) {
    if (this == hero_singleton && value == 0)
        sub_700D78(old_value);  // notify guild leave
    this->offset_539 = value;
}
```

### CHero__UpdateDword_0x86C_ById_0x70173C (0x70173C, size=~180)
**Purpose**: Updates guild ID across hero and all players by old->new.
```
1. If hero's guild ID == old_id, set to new_id, call vtable[212](200)
2. Iterate all player entities in game
3. For each player with matching old guild ID, update to new_id
4. Call CGamePlayerSet__func_002(new_id)
```

### Guild String Fields (2)

### CHero__SetString_0x884 (0x6730E4, size=~40)
**Purpose**: Sets guild name string at offset 2180 (0x884 bytes).
```c
if (str) memcpy(this->offset_2180, str, strlen(str));
```

### CHero__SetString_0x2FBC (0x701806, size=~30)
**Purpose**: Sets string at offset 12220 (0x2FBC bytes).
```c
if (str) memcpy(this->offset_12220, str, strlen(str));
```

### Guild/Syndicate Numeric Fields (12)

### CHero__SetDword_0x878 (0x6730A4, size=10)
**Purpose**: Sets DWORD at offset 542. `this->offset_542 = value;`

### CHero__SetDwordPair_0x898_0x89C (0x673118, size=~20)
**Purpose**: Sets two DWORDs at offsets 550/551. `this->offset_550 = a; this->offset_551 = b;`

### CHero__SetDword_0x890 (0x673136, size=10)
**Purpose**: Sets DWORD at offset 548. `this->offset_548 = value;`

### CHero__SetByte_0x8A4 (0x67314A, size=10)
**Purpose**: Sets byte at offset 2212. `this->byte_2212 = value;`

### CHero__SetDword_0x8A0 (0x67315E, size=10)
**Purpose**: Sets DWORD at offset 552. `this->offset_552 = value;`

### CHero__SetDword_0x87C (0x673172, size=10)
**Purpose**: Sets DWORD at offset 543. `this->offset_543 = value;`

### CHero__SetDword_0x880 (0x67317F, size=10)
**Purpose**: Sets DWORD at offset 544. `this->offset_544 = value;`

### CHero__SetWord_0x874 (0x675D22, size=15)
**Purpose**: Sets WORD at offset 1082. `this->word_1082 = value;`

### CHero__GetWord_0x874 (0x675D31, size=8)
**Purpose**: Gets WORD at offset 1082. `return this->word_1082;`

### CHero__SetDword_0x114C_AndPost3F8 (0x6F867E, size=~30)
**Purpose**: Sets DWORD at offset 1107 and posts window message 0x3F8.
```c
this->offset_1107 = value;
PostMainWndMsg(0x3F8, 0);
```

### CHero__SetDword_0x2FB8 (0x7017F2, size=10)
**Purpose**: Sets DWORD at offset 3054. `this->offset_3054 = value;`

### Interaction/Target State Fields (3)

### CHero__GetDword_0x2EE0 (0x66484D, size=7)
**Purpose**: Gets entity ID of current target at offset 3000 (0x2EE0 bytes).
```c
return this->offset_3000;  // interact_target entity ID
```

### CHero__GetDword_0x2EEC (0x664854, size=7)
**Purpose**: Gets interaction state at offset 3003 (0x2EEC bytes).
```c
return this->offset_3003;  // interaction state (0=ready, 1-2=busy, 3=special)
```

### CHero__GetDword_0x2F98 (0x666694, size=7)
**Purpose**: Gets DWORD at offset 3046. `return this->offset_3046;`

### Coach/Mentor System Fields (2)

### CHero__GetDword_0x2E58 (0x6639A3, size=7)
**Purpose**: Gets DWORD at offset 2966. `return this->offset_2966;`

### CHero__GetDword_0x2E5C (0x6639AA, size=7)
**Purpose**: Gets DWORD at offset 2967. `return this->offset_2967;`

### Container/Inventory Page Fields (10)

### CHero__SetDword_0x2E74 (0x665B78, size=10)
**Purpose**: `this->offset_2973 = value;`

### CHero__SetDword_0x2E78 (0x665B92, size=10)
**Purpose**: `this->offset_2974 = value;`

### CHero__SetDword_0x2E7C (0x665B85, size=10)
**Purpose**: `this->offset_2975 = value;`

### CHero__SetDword_0x2E80 (0x665BAD, size=10)
**Purpose**: `this->offset_2976 = value;`

### CHero__SetDword_0x2E84 (0x665C0A, size=10)
**Purpose**: `this->offset_2977 = value;`

### CHero__SetDword_0x2E88 (0x665BC1, size=10)
**Purpose**: `this->offset_2978 = value;`

### CHero__SetDword_0x2E8C (0x665BD5, size=10)
**Purpose**: `this->offset_2979 = value;`

### CHero__SetDword_0x2E90 (0x665BE9, size=10)
**Purpose**: `this->offset_2980 = value;`

### CHero__SetDword_0x2E94 (0x665BFD, size=10)
**Purpose**: `this->offset_2981 = value;`

### CHero__SetDword_0x2E98 (0x667B86, size=10)
**Purpose**: `this->offset_2982 = value;`

### Magic/Skill System Fields (6)

### CHero__SetDword_0x1284 (0x667BBD, size=10)
**Purpose**: `this->offset_1185 = value;`

### CHero__SetDword_0x1288 (0x700E52, size=10)
**Purpose**: `this->offset_1186 = value;`

### CHero__SetDword_0x128C (0x700E5F, size=10)
**Purpose**: `this->offset_1187 = value;`

### CHero__SetDword_0x1290 (0x700E6C, size=10)
**Purpose**: `this->offset_1188 = value;`

### CHero__SetDword_0x1294 (0x7009E5, size=10)
**Purpose**: `this->offset_1189 = value;`

### CHero__SetDword_0x1298 (0x701030, size=10)
**Purpose**: `this->offset_1190 = value;`

### Miscellaneous Fields (4)

### CHero__SetByte_0x2F58 (0x6668C0, size=10)
**Purpose**: Sets byte at offset 12120. `this->byte_12120 = value;`

### CHero__SetDword_0x2DC8 (0x6ED744, size=10)
**Purpose**: `this->offset_2930 = value;`

### CHero__SetDword_0x2DCC (0x6ED751, size=10)
**Purpose**: `this->offset_2931 = value;`

### Pointer Accessors (2)

### CHero__GetPtr_0x2D60_707113 (0x707113, size=7)
**Purpose**: Returns pointer at byte offset 11616 (0x2D60).
```c
return (char*)this + 11616;
```

### CHero__GetPtr_0x2D98_707337 (0x707337, size=7)
**Purpose**: Returns pointer at byte offset 11672 (0x2D98).
```c
return (char*)this + 11672;
```

## Inventory (21 functions, all verified through decompilation)

### Container Page System (8)

### CHero__SwitchInventoryPage (0x6657D3, size=95)
**Purpose**: Switches inventory page view.
```c
// page_index: 0-9
return container_at_offset_2983[page_index];
```

### CHero__GetItemAtIndex (0x66589C, size=71)
**Purpose**: Gets item pointer from inventory list.
```c
return *(offset_2986 + index * 8);  // 8 bytes per item entry
```

### CHero__GetItemIdByPage (0x6658E3, size=81)
**Purpose**: Gets item ID from container by page.
```c
return container_at_offset_2989[page].item_id;
```

### CHero__GetItemCountByPage (0x665934, size=97)
**Purpose**: Gets item count in a container page.
```c
return (container.end - container.start) / 28;  // 28 bytes per item
```

### CHero__SetContainerValue (0x665995, size=74)
**Purpose**: Sets a value in a container by index.

### CHero__ClearContainer (0x6659DF, size=89)
**Purpose**: Sorts or clears a container at offset 2983.

### CHero__SetWarehousePage (0x665A38, size=190)
**Purpose**: Switches warehouse page and rebuilds display.
```
- Validates page index (0-9)
- Looks up page in map via RBTree__LowerBound (tree find)
- Clears current display
- Rebuilds item list from warehouse data
```

### CHero__GetWarehouseItemAtIndex (0x665AF6, size=125)
**Purpose**: Gets item from warehouse by page and index.
```c
// Validates page (0-9) and index (0 to count-1)
// Item stride: 28 bytes
return warehouse_page.start + 28 * index;
```

### Item Lookup (3)

### CHero__FindEquippedItemByUID (0x667B5B, size=~30)
**Purpose**: Finds an equipped item by its UID.
```c
CPackage__FindItemByUID(this + 985, result, uid);
// Searches equipped items package at offset 985
```

### CHeroItem__FindItemByUid (0x6D924B, size=~200)
**Purpose**: Searches the local hero item tables for an item by UID.
```
- Iterates the inventory deque at offset 0xE34
- For each item: gets CItem pointer and ref-count
- Compares `CItem__GetItemUid()` against target UID
- Returns item pointer + ref or NULL
- If not found and inventory-only mode is clear, falls back to `CHeroItem__FindTrackedItemByUid` on the tracked-position map at `0xF20`
```

### CHeroItem__GetEquipSlotItemRef (0x6DA843, size=~110)
**Purpose**: Gets the equipped item ref at slot position `1..18`.
```c
// Validates position: 1-18 (asserts on out of range)
// Returns item ref at: this + 0xE84 + 8*position
// Increments ref-count on returned item
```

### CHeroItem__GetTrackedItemRefByPosition (0x6DA8B9, size=~80)
**Purpose**: Direct tracked-position lookup on the hero item map.
```c
// Looks up tracked position key in heroItem+0xF20
// Returns { item_ptr, ref_counted_handle } for that tracked position
// Returns NULL if the tracked position is absent
```

### CHeroItem__FindTrackedPositionByItemUid (0x6DBCE2, size=~150)
**Purpose**: Reverse lookup from item UID to tracked-position key.
```c
// Iterates heroItem+0xF20
// Compares CItem__GetItemUid(item_ptr) against target UID
// Returns tracked-position key from node+0x10
// Returns -1 when the item is not currently tracked by position
```

### Equipment System (5)

### CHeroItem__SetEquipSlot (0x6DA906, size=~1100)
**Purpose**: Sets equipment in a specific slot with visual updates.
```
Slot handling (switch on slot index):
  1: Headwear -> updates the primary helmet variant source / override lookup id / texture-variant selector
     (`role+0x140/+0x130/+0xF0`) via `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView`
     - source = `item+0x1C` when equipped, otherwise `0`
     - override lookup id = `CItem__TryGetRoleViewOverrideLookupId(item)` when equipped, otherwise `0`
     - texture-variant selector = `CItem__GetRoleViewTextureVariantSelector(item)` when equipped, otherwise `3`
  2,6,7,8,10,11,18: Simple equip (store + ref update)
  3: Armor -> updates the primary body variant source / override lookup id / texture-variant selector
     (`role+0x11C/+0x134/+0xF4`) via `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView`, then runs the post-armor appearance helper
     at `0x673F05`
     - source = `item+0x1C` when equipped, otherwise `0`
     - override lookup id = `CItem__TryGetRoleViewOverrideLookupId(item)` when equipped, otherwise `0`
     - texture-variant selector = `CItem__GetRoleViewTextureVariantSelector(item)` when equipped, otherwise `3`
  4: Right hand -> weapon type validation:
     - Type 5 (bow): checks for shield conflicts
     - Updates the right-weapon source / override-input group (`role+0x120/+0x13C`)
       via `CRole__SetRightWeaponVisualInputsAndRefreshRoleView`
     - Sets weapon subtype at offset 2240/2242
  5: Left hand -> updates the left-weapon source / override lookup id / texture-variant selector group
     (`role+0x124/+0x138/+0xF8`) via `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView`
     - source = `item+0x1C` when equipped, otherwise `0`
     - override lookup id = `CItem__TryGetRoleViewOverrideLookupId(item)` when equipped, otherwise `0`
     - texture-variant selector = `CItem__GetRoleViewTextureVariantSelector(item)` when equipped, otherwise `3`
  9: Garment -> updates the shared body/helmet fallback variant selector (`role+0x144`)
     via `CRole__SetSharedBodyHelmetVariantLookupSourceAndRefreshRoleView`
  12,17: Steed / SteedArmor -> combines both items and calls
     `Role_UpdateMountActionScaleCacheFromSources` (`0x6E5F41`)
  15: AccessoryRight -> updates the extra right-weapon override lookup input
     (`role+0xE8`) via `CRole__SetExtraRightWeaponOverrideLookupIdAndRefreshRoleView`
  16: AccessoryLeft -> updates the extra left-weapon override lookup input
     (`role+0xE4`) via `CRole__SetExtraLeftWeaponOverrideLookupIdAndRefreshRoleView`
All slots: call the shared UI refresh path (`0x4BF2C3 -> 0x6D3C04`)
```

### CHeroItem__SetEquipMode (0x6DAE7C, size=~50)
**Purpose**: Sets equipment mode (main hand / alt hand).
```c
// Validates mode < 2 (asserts on invalid)
this->offset_967 = mode;  // 0 = main, 1 = alt
```

### CHeroItem__func_003 (0x6DAEB9, size=~350)
**Purpose**: Sends equipment swap request to server.
```
Mode 0 (main): sends CMsgTick subtype 45 + CMsgAction type 10010/408
Mode 1 (alt):  sends CMsgTick subtype 44 + CMsgAction type 10010/408
Asserts on invalid EquipMode values
```

### CHeroItem__func_004 (0x6DB116, size=~1900)
**Purpose**: Validates and sends item equip request.
```
Validation chain:
1. Check sub_67584F (riding state)
2. Find item by UID via CHero__GetItemByUID
3. Check wallow/anti-addiction restrictions (error 50)
4. Check IsSteed() for mount items
5. Item type -> slot mapping:
   Type 1 -> slot 1/21    Type 2 -> slot 2/22
   Type 3 -> slot 3/23    Type 4 -> slot 5/25 (with weapon conflicts)
   Type 5 -> slot 4/24 (with shield conflicts, magic 10311 check)
   Type 6 -> slot 5/25 (with bow conflict: StrErrEquipShield)
   Type 7 -> slot 6/26    Type 8 -> slot 8/28
   Type 10 -> slot 7/27   Type 11 -> slot 9/29
   Type 12 -> slot 10/11 by subtype
   Type 14 -> slot 12     Type 15 -> slot 15
   Type 16,17 -> slot 15  Type 18 -> slot 16
   Type 20 -> slot 17     Type 21 -> slot 18
6. On success: sends CMsgTick subtype 4 with item UID and slot
Error messages: 100049 (wrong slot), 100048 (need magic), StrErrEquipBow
```

### CHeroItem__func_009 (0x6DC7B7, size=~310)
**Purpose**: Initiates steed mount action.
```
1. Check sub_650B4C (mount readiness)
2. Get equipped item at slot 4
3. Validate item ID: must be category 562 (id/1000%1000 == 562)
4. Check current action != 9 (already mounting)
5. Send CRoleAction type 9 via vtable[128]
6. Send CMsgAction type 99 (mount) to server
Error: 100054 (need mount equipment)
```

### Gem/Socket System (2)

### CHeroItem__SendGemEmbed (0x6DC5A2, size=~220)
**Purpose**: Sends gem embedding request to server.
```
1. Validates both items exist (equipment UID and gem UID)
2. Validates action type (1 or 2)
3. Creates and sends CMsgGemEmbed packet
Fields: hero entity ID, equipment UID, gem UID, action type
```

### CHeroItem__SendGemTakeout (0x6DC68A, size=~170)
**Purpose**: Sends gem removal request to server.
```
1. Validates equipment item exists by UID
2. Validates action type (1 or 2)
3. Creates and sends CMsgGemEmbed packet with takeout flag
```

### Item Durability/Upgrade (2)

### CHeroItem__func_005 (0x6DC33E, size=~300)
**Purpose**: Sends item upgrade/enhancement request.
```
1. Validates target item exists and has ID 1088000 (upgrade stone)
2. Gets source item by UID
3. Compares ceil(max_durability/100) vs ceil(current_durability/100)
4. If valid: sends CMsgTick subtype 19 (upgrade request)
```

### CHeroItem__func_006 (0x6DC46A, size=~300)
**Purpose**: Sends item repair/restoration request.
```
1. Validates target item via sub_67D933/sub_67D940
2. Gets source item by UID
3. Compares durability values (same formula as func_005)
4. If valid: sends CMsgTick subtype 20 (repair request)
```

### Container Info Processing (1)

### CMsgContainerInfo__Process (0x702372, size=~370)
**Purpose**: Processes server container info packet and populates inventory.
```
1. Reads container type (byte at offset 4, max 9)
2. Reads item count (byte at offset 6) and capacity (word at offset 8)
3. Clears container page, sets capacity
4. For each item (68 bytes per entry):
   - Extracts item fields (ID, count, name string)
   - Maps item field to container slot by type (0-9 -> fields 3-12)
   - Calls CHero__SetWarehousePage to store
5. Switches to the updated inventory page
6. Posts window message 0xC5F to refresh UI
```

## Movement (6 functions, all verified through decompilation)

### CHero__StartAutoRun (0x5B29E2, size=~10000+)
**Purpose**: Initiates auto-run pathfinding mode. Massive function handling auto-navigation.
```
- Processes auto-run waypoints and pathfinding
- Validates map terrain and elevation
- Handles multiple auto-run modes (NPC pathing, quest navigation, etc.)
- Creates movement path from current position to target
- Sends movement packets to server
- Integrates with quest system for auto-navigation
```

### CHero__SetMapSingleton (0x6576D3, size=68)
**Purpose**: Associates hero with a map singleton.
```c
*(this - 611) = map_singleton_ptr;
```

### Role_UpdateCoordinateGateAndMapFromTilePair (0x65CAF3, size=~130)
**Purpose**: Replaces the role coordinate-gate tile pair and performs the hero-owned visibility and map refresh sequence around that write.
```
1. Read the CHero singleton's old tile pair from the XTEA-protected containers
   at CHero+0xCEC and CHero+0xD08.
2. Call EntityContainer_CullEntitiesOutsideVisibilityRange(g_EntityContainer,
   oldX, oldY).
3. Call CGameMap_ClearTransientSceneryQueuesAndCullDistantType17Objects(CGameMap).
4. Write tileX/tileY into this+0xCEC/+0xD08 with XteaProtectedInt_Set.
5. Read the newly written pair back through XteaProtectedInt_Get.
6. Call CGameMap_UpdateTileRegionFlagsAndAmbientMedia(CGameMap, newX, newY).
```

### CHero__TryMoveToTarget (0x65D9B2, size=1369)
**Purpose**: Pathfinding to reach a target entity.
```
Algorithm:
1. Calculate direction to target
2. Try 9 adjacent directions (center + 8 neighbors)
3. Check "wallow" restrictions (water/obstacle tiles)
4. Send MsgAction type 85 (walk) to server
5. Handles failed movement by trying alternate paths
```

### CHero__AddStringToMap (0x6674FC, size=134)
**Purpose**: Adds a key-value string pair to an internal map.
```c
// Wraps string key creation and value assignment
map[key] = value;
```

### CHero__StopAutoRun (0x7365F3, size=~1500)
**Purpose**: Processes auto-run state machine per frame and handles stopping.
```
State machine at offset 123:
  0: Not running -> initiates pathfinding
  2: Walking (state A) -> direction 120
  3: Walking (state B) -> direction 121
  6: Stopped/finished

Per-frame logic:
1. If not running (offset_123 == 0):
   - Clear path list at offset 111
   - Compute path via `MapPathService_TryBuildPath` (`0x6208E2`) with destination at offset 130
   - If path found: set state 2 and start walking
   - If no path: set state 6, stop, show message 11128
2. If walking (state 2 or 3):
   - Check remaining path length
   - Get next waypoint direction (mod 8)
   - Validate target tile (sub_61D9C8): terrain traversable, height delta <= 25
   - If valid: call sub_736315 (movement step), toggle between state 2/3
   - If blocked: attempt recursive call or set state 6
3. On stop: call sub_66279B, post message 0x478, show "AutoRunEnd" text
```

## Pets (3 functions, all documented)

### CHero__AddPet (0x662AE7, size=24)
**Purpose**: Adds a pet/eudemon entity pointer to the hero's pet list vector.
```c
// Vector at this+0x2F24 (DWORD offset 3033)
if (entity_ptr != NULL) {
    vector_push_back(&this->pet_list_vector, entity_ptr);  // sub_5EA7D8
}
```
**Offsets**: 3033 (byte 0x2F24) = pet list vector (start/end/capacity std::vector<DWORD>)

### CHero__ClearPetList (0x662B38, size=150)
**Purpose**: Clears the hero's pet list by iterating and freeing all pet entries.
```c
this->offset_3017 = NULL;  // pet_list_ptr
this->offset_3018 = 0;     // pet_list_count
// Iterates and frees all pet entries
```

### CHero__SetEudemonAttrib (0x6662B3, size=42)
**Purpose**: Sets 4 eudemon/pet attribute DWORDs.
```c
this->offset_3043 = a2;  // byte 0x2F6C - eudemon attrib 1
this->offset_3046 = a5;  // byte 0x2F78 - eudemon attrib 4
this->offset_3044 = a3;  // byte 0x2F70 - eudemon attrib 2
this->offset_3045 = a4;  // byte 0x2F74 - eudemon attrib 3
```
**Offsets**: 3043-3046 (bytes 0x2F6C-0x2F78) = eudemon attributes (4 DWORDs)

## Rendering (3 functions, all documented)

### CHero__DrawArrowCount (0x6617BA, size=437)
**Purpose**: Renders arrow/ammo count in the UI.
```
Resources: "ani/Common/ani" -> "NoArrow"
- Reads arrow counts from offsets 2826/2827
- Uses CMyBitmap::ShowStringCommon for text rendering
- Shows "NoArrow" icon when out of ammo
```

### CHero_CancelRunningOrReadyInteractionAction (0x66402F, size=248)
**Purpose**: Cancels the local hero's current paired-interaction UI/action state before
`CMsgInteract` subtype 49 starts the replacement interaction.

Verified behavior:
- Requires interaction status `CHero+0x2EEC` to be running (`1`) or ready (`2`);
  otherwise emits the embedded `Hero.cpp` `CHECK` diagnostic.
- Creates the interaction controller from `CRole+0x388`.
- Resolves partner entity `CHero+0x2EE0` without local-hero fallback.
- When the controller exists, writes interaction status `3` and invokes controller
  vtable slot `+0x08` with byte `CHero+0x2EDD` and the resolved partner shared reference.
- The controller slot hides the interaction-specific card tip and, for every implemented
  controller except double dance, dispatches `gam_acc` to the partner role.

### CHero__RenderChatBubble (0x666A20, size=567)
**Purpose**: Renders chat text bubble above the hero.
```
Prerequisites:
- offset_11796 and offset_11797 must both be true
- offset_11808 != offset_11812 (bubble has content)
Process:
1. Load font settings
2. Get camera scale factor
3. Calculate text extent (CMyBitmap::CalcuTextExtentCommon)
4. Position bubble above hero head (screen_y - 130 * scale/100)
5. Clamp to screen boundaries
6. Render "ani/Control.ani" -> "Dialog21" background
7. Render text with ShowStringCommon
8. RTL/LTR handling via g_bRightToLeftLayout
```

## Social (17 functions, all documented)

### VIP Team System

#### CHero__FindVipTeamEntryById (0x65FF73, size=90)
**Purpose**: Searches the VIP team linked list for an entry matching a given ID.
```c
// Linked list at offset 2934 (byte 0x2DCC)
// Each node has sub-array at node+20..node+24, entries are 5 DWORDs (20 bytes)
// First DWORD of each entry is the ID
node = this->offset_2934->next;  // skip sentinel
while (node != this->offset_2934) {
    for (entry = node[20]; entry < node[24]; entry += 5) {
        if (entry[0] == target_id)
            return entry;  // found
    }
    node = tree_next(node);  // sub_404189
}
return NULL;
```
**Offsets**: 2934 (byte 0x2DCC) = VIP team list head (linked list with tree traversal)

### Coach/Mentor System

#### CHero__SetMentorProgressFields (0x663131, size=560)
**Purpose**: Calculates and sets mentor progress bar fields based on level thresholds and experience milestones.
```c
// Offsets 3032-3036 (bytes 0x2F60-0x2F70)
// offset_3036 = mentor_type (7=level50+, 9=level15+, 12=level3+)
// offset_3032/3033 = progress bar value (64-bit, min 3,000,000)
// offset_3034 = previous tier indicator
// offset_3035 = current tier indicator

// Tier thresholds by mentor_type:
//   type 7 → threshold 50, type 9 → threshold 15, type 12 → threshold 3

// Experience milestones by switch(mentor_type 1-5):
//   1 → 30,000,000
//   3 → 100,000,000
//   5 → 200,000,000

// Calls vtable+328 (get current exp), computes delta to milestone
// Sets progress bar minimum to 3,000,000 if below threshold
```
**Offsets**: 3032-3033 (byte 0x2F60) = mentor progress (int64), 3034 (byte 0x2F68) = prev tier, 3035 (byte 0x2F6C) = curr tier, 3036 (byte 0x2F70) = mentor type

#### CHero__DestroySchool (0x663377, size=133)
**Purpose**: Destroys the school/mentor object.
```c
if (this->offset_2994) {
    delete this->offset_2994;
    this->offset_2994 = NULL;
}
```

#### CHero__TrySendCoachRequest (0x6ECEFA, size=627)
**Purpose**: Validates and sends a coach/mentor request to a target player.
```c
// 1. Find target entity by ID via EntityManager
// 2. Check if target is already coaching (sub_67584F) → show error "CoachAbsolu"
// 3. Check same map (compare positions via sub_61ED95) → show error "CoachTarget"
// 4. Check level range: |hero_level - target_level| must be within 20 (offset 526 vs hero+2104)
//    → show error "CoachRelati" if out of range
// 5. Build CMsgCoach packet (1032 bytes, size 28, subtype + two IDs)
// 6. Send packet and post WndMsg 0xCAB
```
**Network**: CMsgCoach packet (size 28) with hero entity ID and target entity ID

#### CHero__CoachList_GetValueByIndex (0x6ED75E, size=87)
**Purpose**: Gets a value from the coach list at a 1-based index.
```c
// Coach list at offset 1151 (this+1151, byte 0x11FC)
// Uses sub_6C6D28 to get list root, entries are 24 bytes each
// Returns DWORD at entry+12, or -1 if index invalid (>150 or out of range)
entry = find_entry(this->coach_list, index-1);
if (valid && (entry[6]-entry[5])/24 > index-1 && index-1 <= 150)
    return *(entry[5] + 24*(index-1) + 12);
return -1;
```
**Offsets**: 1151 (byte 0x11FC) = coach list container, entries 24 bytes, value at +12

#### CHero__CoachList_GetValueDiv5 (0x6ED7B5, size=25)
**Purpose**: Gets coach list value at index divided by 5.
```c
return CHero__CoachList_GetValueByIndex(hero_singleton, index) / 5;
```

#### CHero__CoachList_CeilDivByValueDiv5 (0x6ED7CE, size=47)
**Purpose**: Ceiling division of a value by the coach list value/5.
```c
divisor = CoachList_GetValueDiv5(index);
if (divisor <= 0) divisor = 1;
result = value / divisor;
if (divisor * result != value) result++;  // ceiling
return result;
```

#### CHero__CoachList_GetRemainingByValue (0x6ED7FD, size=71)
**Purpose**: Calculates remaining coaching time in minutes.
```c
// offset 2929 (byte 0x2DC4) = coaching session start timestamp
total_minutes = 20 * CeilDivByValueDiv5(index, sub_673B96(hero));
elapsed_minutes = (timeGetTime() - this->offset_2929) / 60000;
remaining = total_minutes - elapsed_minutes;
return (remaining > 0) ? remaining : 0;
```
**Offsets**: 2929 (byte 0x2DC4) = coaching session start time (timeGetTime)

#### CHero__CoachList_ComputeDelta (0x6ED844, size=258)
**Purpose**: Computes experience delta between current and target coach level.
```c
// Uses byte offsets: 11696 (index param), 11704 (exp value)
// Calls CHero__CalcExpWithBonus twice:
//   1. Current exp at level
//   2. Target exp at 4*value/5 of coach list entry
// Returns delta = target_exp - current_exp via output param
```

#### CHero__CopyRoleFieldsToCoachSnapshot (0x6ED9CC, size=37)
**Purpose**: Snapshots current role fields for coach comparison.
```c
this->offset_2924 = this->offset_526;   // level snapshot
this->offset_2926 = this->offset_536;   // field 536 snapshot
this->offset_2927 = this->offset_537;   // field 537 snapshot
```
**Offsets**: 2924 (byte 0x2D90) = coach level snapshot, 2926-2927 = additional snapshots from role fields

### Syndicate UI

#### CHeroSyndicate__func_000 (0x701421, size=261)
**Purpose**: Renders syndicate notification messages on screen.
```c
// Only renders if within 60 seconds (60000ms) of timestamp at this+898
if (timeGetTime() - this->offset_898 <= 60000) {
    x = screen_width - 300;  // or 300 if RTL layout
    y = 5;
    font = Load_FontSetting_Ini();
    count = get_notification_count(this);
    for (i = 0; i < count; i++) {
        text = get_notification_text(i);
        if (text) {
            y += line_height + 5;
            CMyBitmap::ShowStringCommon(x, y, YELLOW, text, font+269, line_height);
        }
    }
}
```
**Offsets**: 898 (byte 0x0E08) = syndicate notification timestamp

### Flower System

#### CHero__SetFlowerCountersFromPacket (0x70711A, size=176)
**Purpose**: Sets 8 flower counter DWORDs from a packet structure.
```c
// 4 flower types × 2 counters each (today + total)
// Packet layout: [type0_total, type0_today, type1_total, type1_today, ...]
this->offset_2905 = packet[1];  // type 0 today counter
this->offset_2906 = packet[3];  // type 1 today counter
this->offset_2907 = packet[5];  // type 2 today counter
this->offset_2908 = packet[7];  // type 3 today counter
this->offset_2909 = packet[0];  // type 0 total counter
this->offset_2910 = packet[2];  // type 1 total counter
this->offset_2911 = packet[4];  // type 2 total counter
this->offset_2912 = packet[6];  // type 3 total counter
```
**Offsets**: 2905-2908 (bytes 0x2D54-0x2D60) = today flower counters (4 types), 2909-2912 (bytes 0x2D64-0x2D70) = total flower counters (4 types)

#### CHero__SetFlowerLastCountAndType (0x7071CA, size=23)
**Purpose**: Sets the last flower event count and type.
```c
this->offset_2913 = count;  // byte 0x2D74 - last flower count
this->offset_2914 = type;   // byte 0x2D78 - last flower type (0-3)
```
**Offsets**: 2913 (byte 0x2D74) = last flower count, 2914 (byte 0x2D78) = last flower type

#### CHero__AppendFlowerNameToBuffer (0x7071E1, size=50)
**Purpose**: Appends a sender name string to the flower name buffer.
```c
// Buffer at byte offset 11660 (0x2D8C)
if (name && strlen(name) > 0) {
    string_append(&this->byte_11660, name, name + strlen(name));
}
```
**Offsets**: byte 11660 (0x2D8C) = flower sender name buffer (std::string)

#### CHero__FlowerStats_AddOrAccumulateByName (0x707213, size=276)
**Purpose**: Tracks per-sender flower statistics, adding to existing entry or creating new one.
```c
// Flower stats list at offset 2918-2919 (byte 0x2D88-0x2D8C)
// Each entry: 28 bytes = name_string(12) + 4 counters(16)
//   counter at +12 = type 0 count
//   counter at +16 = type 1 count
//   counter at +20 = type 2 count
//   counter at +24 = type 3 count

for (entry in this->flower_stats_list) {
    if (entry->name == sender_name) {
        entry->counter[flower_type] += amount;
        return;
    }
}
// Not found - create new 28-byte entry
new_entry = new FlowerStatsEntry();
new_entry->name = sender_name;
new_entry->counter[flower_type] += amount;
vector_push_back(&flower_stats_list, new_entry);
```
**Offsets**: 2918-2919 (bytes 0x2D88-0x2D8C) = flower stats vector (start/end ptrs)

#### CHero__HandleFlowerEvent (0x70733E, size=877)
**Purpose**: Main flower event handler — processes incoming flower gifts with sound, animation, and stat tracking.
```c
// Packet: sender_name(16) + recipient_name(16) + count(DWORD@+32) + type(DWORD@+36) + flag(@+40)
// 4 flower types (0-3), byte offsets for counters:
//   Type 0: 11620/11636 (today/total)
//   Type 1: 11624/11640
//   Type 2: 11628/11644
//   Type 3: 11632/11648

if (recipient == hero_name) {
    // We received flowers
    flower_counter[type].today += count;
    flower_counter[type].total += count;
    DXPlaySound("Sound/Flower2.wav");
    play_animation(FlowerAssetKey(receive=1, type, count));
    SetFlowerLastCountAndType(count, type);
    AppendFlowerNameToBuffer(sender);
    FlowerStats_AddOrAccumulateByName(sender, type, count);
} else if (sender == hero_name) {
    // We sent flowers
    DXPlaySound("Sound/Flower1.wav");
    show_system_message(str_11241, recipient);  // "You sent flowers to %s"
} else {
    // Third-party flower event
    DXPlaySound("Sound/Flower2.wav");
    play_animation(FlowerAssetKey(receive=1, type, count));
}

// Special animations for large gifts
if (count == 99) {
    PostWndMsg(0x4F7, FlowerAnim_BaseSprite(type));
} else if (count == 999) {
    PostWndMsg(0x4F7, FlowerAnim_BaseSprite(type));
    PostWndMsg(0x4F7, FlowerAnim_RainSprite(type));  // flower rain effect
}
```
**Sound**: "Sound/Flower1.wav" (sending), "Sound/Flower2.wav" (receiving)
**WndMsg**: 0x4E0 (flower received), 0x4DD (flower name update), 0x4DF (special flag), 0x4F7 (animation)

### Qualifying System

#### CHeroQualifying__func_000 (0x70B475, size=178)
**Purpose**: Cleans up the qualifying (arena/tournament) system entries.
```c
// Vector at this+885 (byte offset 0xDD4)
count = (this->offset_886 - this->offset_885) / 4;
for (i = 0; i < count; i++) {
    entry = vector[i];
    if (entry) {
        sub_70B527(entry);  // cleanup entry
        delete entry;
    }
}
vector_clear(this->offset_885, this->offset_886);
```
**Offsets**: 885-886 (bytes 0xDD4-0xDD8) = qualifying entries vector (start/end ptrs)

## SubProfession (16 functions, all documented)

### CSubProfMrg Memory Layout
```c
struct CSubProfMrg {
    void* vtable;           // +0 (off_86B980)
    DWORD owner_entity_id;  // +1 (byte 0x04)
    DWORD current[22];      // +2..+23 (bytes 0x08-0x5C) - current sub-profession values
    DWORD _padding;          // +24
    DWORD target[22];       // +25..+46 (bytes 0x64-0xBC) - target sub-profession values
    DWORD _padding2;         // +47
    DWORD field_48;          // +48 (byte 0xC0)
    DWORD slot_values[3];   // +49..+51 (bytes 0xC4-0xCC) - triple slot values
    // Vector (entries list)
    DWORD* entries_start;   // +52 (byte 0xD0)
    DWORD* entries_end;     // +53 (byte 0xD4)
    DWORD* entries_cap;     // +54 (byte 0xD8)
    DWORD duration_start;   // +55 (byte 0xDC) - timeGetTime timestamp
    DWORD is_active;        // +56 (byte 0xE0) - active flag
    // Timer/string at +57 (byte 0xE4)
};
```

### Lifecycle

#### CSubProfMrg__Ctor (0x6F8707, size=113)
**Purpose**: Constructor — initializes all fields and clears current/target values.
```c
vtable = off_86B980;
owner_entity_id = 0;
is_active = 0;
field_48 = 0;
ClearCurrentAndTargetValues();
duration_start = 0;
slot_values[0] = slot_values[1] = slot_values[2] = 0;
entries vector initialized (start=end=cap=0);
timer at +57 initialized;
```

#### CSubProfMrg__Dtor (0x6F8794, size=78)
**Purpose**: Destructor — restores vtable, cleans up timer and entries vector.
```c
vtable = off_86B980;
CDiceManager__func_001();  // cleanup
destroy_timer(this+57);
destroy_vector(this+52);
```

#### CSubProfMrg__ScalarDtor (0x6F8778, size=28)
**Purpose**: Scalar deleting destructor (compiler-generated).
```c
CSubProfMrg__Dtor();
if (flags & 1) operator_delete(this);
```

### Accessors

#### CSubProfMrg__GetOwnerEntityId (0x6C4108, size=6)
**Purpose**: Returns the owner entity ID.
```c
return this->owner_entity_id;  // offset +1 (byte 0x04)
```

#### CSubProfMrg__func_000 (0x6C2133, size=75)
**Purpose**: Gets a pointer to an entry by index from the entries list at offset +7/+8.
```c
// Entries at offsets +7/+8, each 12 bytes
if (index >= 0 && index < (this[8] - this[7]) / 12)
    return this[7] + 12 * index;
// ASSERT: "nIndex>=0 && nIndex<size"
return NULL;
```

#### CSubProfMrg__GetCurrentValueByIndexOrTotal22 (0x6F87E2, size=46)
**Purpose**: Gets a current sub-profession value by index (0-21), or sum of all 22 if index==22.
```c
if (index > 22) return 0;
if (index == 22) {
    total = 0;
    for (i = 0; i < 22; i++) total += this->current[i];
    return total;
}
return this->current[index];  // this[index+2]
```

#### CSubProfMrg__SetCurrentValueByIndex (0x6F8810, size=24)
**Purpose**: Sets a current sub-profession value at index (0-22 max).
```c
if (index <= 22) this->current[index] = value;
```

#### CSubProfMrg__GetTargetValueByIndexOrTotal22 (0x6F8828, size=46)
**Purpose**: Gets a target sub-profession value by index (0-21), or sum of all 22 if index==22.
```c
if (index > 22) return 0;
if (index == 22) {
    total = 0;
    for (i = 0; i < 22; i++) total += this->target[i];
    return total;
}
return this->target[index];  // this[index+25]
```

#### CSubProfMrg__SetTargetValueByIndex (0x6F8856, size=24)
**Purpose**: Sets a target sub-profession value at index (0-22 max).
```c
if (index <= 22) this->target[index] = value;
```

#### CSubProfMrg__SetTripleValueBySlot0to2 (0x6F886E, size=27)
**Purpose**: Sets one of 3 slot values (indices 0-2).
```c
if (slot <= 2) this->slot_values[slot] = value;  // offset +49..+51
```

### Network Operations

#### CSubProfMrg__SetOwnerAndResetOrSendName17 (0x6F8AF3, size=187)
**Purpose**: Either resets sub-profession state locally or sends a name-type-17 network packet.
```c
if (send_mode) {
    // Network mode: send packet with subtype 17
    if (!owner_id) return;
    CMsgName packet;
    if (packet.Build(17, hero_name, owner_id))
        packet.Send();
} else {
    // Local mode: set owner and reset
    this->owner_entity_id = owner_id;
    ClearCurrentAndTargetValues();
    PostWndMsg(0x435, 0);  // sub-profession reset
    this->is_active = 1;
}
PostWndMsg(0x438, 0);
PostWndMsg(0x437, 0);
```
**Network**: CMsgName subtype 17 (sub-profession registration)
**WndMsg**: 0x435 (reset), 0x437 (update), 0x438 (refresh)

#### CSubProfMrg__CommitAndResetOrSendName18 (0x6F8BAE, size=163)
**Purpose**: Commits sub-profession progress by sending a name-type-18 packet, then resets.
```c
if (!this->owner_entity_id) return;
if (commit_mode) {
    CMsgName packet;
    if (packet.Build(18, hero_name, this->owner_entity_id))
        packet.Send();
    this->owner_entity_id = 0;
    cleanup();
    ClearCurrentAndTargetValues();
    PostWndMsg(0x436, 0);  // sub-profession committed
}
PostWndMsg(0x438, 0);
PostWndMsg(0x437, 0);
```
**Network**: CMsgName subtype 18 (sub-profession commit/finalize)
**WndMsg**: 0x436 (committed), 0x437 (update), 0x438 (refresh)

#### CSubProfMrg__SendSubtype2ForIndexIfCurrentNonZero (0x6F8CE9, size=131)
**Purpose**: Sends a CMsgSubPro packet with subtype 2 for a specific index if current value is non-zero.
```c
if (!this->owner_entity_id) return;
if (index > 21) return;
value = GetCurrentValueByIndexOrTotal22(index);
if (value) {
    CMsgSubPro packet;
    if (packet.BuildSingleEntry(owner_id, 2, value, index))
        packet.Send();
}
```
**Network**: CMsgSubPro subtype 2 (sub-profession value update)

### State Management

#### CSubProfMrg__ClearCurrentAndTargetValues (0x6F8D6C, size=20)
**Purpose**: Zeros all 22 current values and 22 target values (44 DWORDs total).
```c
// Clears this[2..24] (current) and this[25..47] (target)
for (i = 0; i < 23; i++) {
    this->current[i] = 0;  // this[i+2]
    this->target[i] = 0;   // this[i+25]
}
```

#### CSubProfMrg__ClearEntryStateInList_0xD0 (0x6F8D80, size=133)
**Purpose**: Clears the state field (+12) of all entries in the entries vector.
```c
count = (this->entries_end - this->entries_start) / 4;
for (i = 0; i < count; i++) {
    entry = entries_start[i];
    if (entry) entry[3] = 0;  // entry+12 = state field
}
```

#### CSubProfMrg__SetDurationWindowFromSeconds (0x6F8E05, size=61)
**Purpose**: Sets the duration timer window from a seconds value (capped at 50 seconds).
```c
// Convert seconds to ms, cap at 50000ms
duration_ms = min(seconds * 1000, 50000);
// Set start time as (now + duration - 50000), so elapsed check works
this->duration_start = timeGetTime() + duration_ms - 50000;
this->is_active = 1;
```
**Offsets**: +55 (byte 0xDC) = duration start timestamp, +56 (byte 0xE0) = active flag

## Idle State System

### Memory Layout — Idle Fields
```c
struct CBoothManager {             // size 0x40
    void* vtable;                  // +0x00
    uint32_t booth_npc_id;         // +0x04
    uint32_t is_active;            // +0x08
    NullTerminatedCharVector cry_out_text; // +0x0c, size 0x0c
    CBoothManagerListedItemDequeStorage listed_items; // +0x18, size 0x28
};

struct CHero {
    // ...
    uint8_t  idle_state_flag;      // hero+0x18:  0=active, 1=idle. Read by CHero_GetIdleState, written by CHero_SetIdleState.
    // ...
    uint32_t command_type;         // CRole+0x1e8: first dword of the 0x11c-byte command block. Value 3 blocks this idle timer.
    // ...
    uint8_t  idle_init_flag;       // hero+0xf2c: first-run initialization flag for idle timer. Written once on first tick.
    uint32_t idle_timestamp_ms;    // hero+0xf30: timeGetTime() snapshot of when idle timer started (or last reset).
    // ...
    CBoothManager booth_manager;   // hero+0x2a54..+0x2a93; is_active is hero+0x2a5c.
    // ...
    uint32_t ping_ms;              // hero+0x2cf4: last measured network round-trip time in milliseconds.
    // ...
};
```

### Embedded booth manager and `CHero+0x2A5C`

`CHero+0x2A5C` is not a generic movement-block field. It is
`CHero.boothManager.isActive`. `CHero_Ctor` constructs the embedded manager at `CHero+0x2A54`
(`0x655505`), and the next embedded object begins at `+0x2A94`, fixing the manager size at `0x40`.
`CBoothManager_Ctor` (`0x70A677`) initializes the NPC ID and active flag to zero after constructing
the cry-out string and listed-item deque.

The v5517 action `0x6F` branch in `CMsgAction__Process` (`0x6FFE50..0x6FFE7B`) requires the packet
entity ID to equal the local hero ID, combines the words at packet `+8/+10`, and passes that dword to
`CBoothManager_Open` (`0x70A832`). A nonzero ID writes `boothNpcId`, sets `isActive = 1`, and requests
local role action `0xFA`. A zero ID is a different client-originated setup path: it clears the
manager, validates five direction-dependent booth tiles, and sends action `0x6F` only when the
native map checks pass. It must not be modeled as an ordinary inactive response.

`CBoothManager_Close` (`0x70AAEB`) clears prices/listed items, NPC ID, active state, and cry-out text,
updates the booth UI, and sends action `0x72`. The item-list and booth UI lifecycle are proven but
remain outside the current managed slice.

### Globals
| Symbol | Address | Purpose |
|---|---|---|
| `g_HeroIdleTimeoutMilliseconds` | 0x96ab10 | Idle timeout threshold (ms). Loaded from `ini/Info.ini [TempLeave] TimeMilliSec`, default 180000. |
| `g_LastHeroIdleWorkingSetTrimTickMilliseconds` | 0x96ae64 | Timestamp of the last working-set trim attempt. |

#### Idle-timeout INI integer read

`CHero_LoadIdleTimeoutMillisecondsFromInfoIni` (`0x654DFB`, effective body
`0x654E08..0x654E75`) opens `ini/Info.ini` and reads section `TempLeave`, key
`TimeMilliSec`, through `IniStore_ReadIntOrDefault` (`0x76F9CE`). The INI store lookup is
case-insensitive. A missing or empty stored value returns the caller's default `0x2BF20`.

For a nonempty value, the integer reader selects its conversion exactly as follows:

- length greater than two and prefix exactly `0x` or `0X`: `sscanf(value, "%x", &result)`
- every other value: `atoi(value)`

The clean v5517 `Info.ini` contains no `TempLeave/TimeMilliSec` entry, so its effective timeout is
180000 ms.

The surrounding file grammar is verified through `IniStore_LoadFile` (`0x76EF0E`) and its parser
helpers:

- `IniStore_TryParseSectionHeaderLowercase` (`0x76ED5D`) requires `[` as byte zero, uses the first
  later `]`, copies the intervening bytes without trimming, and lowercases them.
- `IniStore_TryParseKeyValueLowercaseKey` (`0x76EDF5`) uses the first `=`, removes trailing
  spaces/TABs from and lowercases the key, skips leading spaces/TABs in the value, then terminates
  the value at TAB, semicolon, CR, or LF. Ordinary spaces are retained.
- `IniStore_IsCandidateKeyValueLine` (`0x76ECF7`) rejects lines of length at most two and lines
  beginning with TAB, LF, CR, space, `/`, `;`, `=`, or backslash. `#` is not a comment marker in
  this parser.

### Functions

#### CHero_GetIdleState (0x650447)
```c
// Returns hero+0x18 (idle_state_flag).
uint8_t CHero_GetIdleState(CHero* this) {
    return this->idle_state_flag;  // this+0x18
}
```

#### CHero_SetIdleState (0x65044b)
```c
// Sets hero+0x18 (idle_state_flag).
void CHero_SetIdleState(CHero* this, uint8_t state) {
    this->idle_state_flag = state;  // this+0x18
}
```

#### CHero_SendIdleActionMsg (0x65cd30)
**Purpose**: Builds and sends `CMsgAction` with action type 0xa1 (161) carrying the idle flag.
```c
// Packet layout (CMsgAction / wire type 10010):
//   EntityId      = heroUID
//   ActionType    = 0xa1 (161, idle toggle)
//   ParamLow/High = idleFlag (0=active, 1=idle)
void CHero_SendIdleActionMsg(CHero* this, uint8_t idleFlag) {
    CMsgAction msg;
    CMsgAction_Create(&msg, this->hero_uid, /*actionType=*/0xa1, idleFlag);
    CMsgAction_Send(&msg);
}
```
**Network packet**: type 10010, `ActionType=0xa1`, `ParamLow=idleFlag`.

#### CHero_TrimWorkingSetOnIdle (0x66dca6)
**Purpose**: Calls `SetProcessWorkingSetSize(-1,-1)` (Windows OS trim) throttled to once per 3 minutes.
```c
// force=false skips while elapsed <= 180000; the first allowed elapsed is 180001.
void CHero_TrimWorkingSetOnIdle(bool force) {
    uint32_t now = timeGetTime();
    if (!force && now - g_LastHeroIdleWorkingSetTrimTickMilliseconds <= 180000) return;
    g_LastHeroIdleWorkingSetTrimTickMilliseconds = now;
    SetProcessWorkingSetSize(GetCurrentProcess(), -1, -1);
}
```
The timestamp write precedes the Windows API call. There is no evidence that `GC.Collect` is a
behaviorally equivalent cross-platform substitute; the managed client keeps this platform effect
behind an explicit working-set-trim sink.

#### CHero_TickPreFrameAutoRunAndIdleDecision (0x65cc70)
**Purpose**: Called once per frame from `CMyShellDlg_RunFrameTick` (`0x5dd04c`). Combines auto-run cancellation checks with idle-state entry detection.
```c
void CHero_TickPreFrameAutoRunAndIdleDecision(CHero* hero) {
    // First-run: seed idle timer from current time (hero+0xf2c init guard)
    if (*(hero + 0xf2c) == 0) {
        *(hero + 0xf2c) = 1;
        *(hero + 0xf30) = timeGetTime();
    }

    // One short-circuit OR ladder; at most one cancel call per frame.
    if (CGameMap_IsStateBlockingAutoRun() ||
        Role_GetAutoRunActiveState(hero) ||
        CHero_GetSingletonPtr()->booth_manager.is_active != 0 ||
        CHero_HasInteractionActionStatus(hero) ||
        CHero_IsCommandType03BlockingAutoRun(hero)) {
        CHero_CancelAutoRunAndClearIdle(hero);
    }

    // Idle entry: only when not already idle
    if (CHero_GetIdleState(hero) == 0) {
        uint32_t elapsed = timeGetTime() - *(hero + 0xf30);
        if (elapsed >= g_HeroIdleTimeoutMilliseconds) { // unsigned comparison
            CHero_SetIdleState(hero, 1);       // hero+0x18 = 1
            CHero_SendIdleActionMsg(1);         // CMsgAction(0xa1, idleFlag=1)
            bool suppress = CHero_HasInteractionActionStatus(hero);
            Role_CommandType06_SelectActionAndToggleMountedScaleSuppression(hero, true, suppress);
            CHero_TrimWorkingSetOnIdle(0);
        }
    }
}
```
**Frame loop address**: Called at `0x5dd04c` (`CMyShellDlg_RunFrameTick`).

#### CHero_CancelAutoRunAndClearIdle (0x65cda2)
**Purpose**: Resets idle timer and, if hero WAS idle, sends CMsgAction(0xa1, 0) cancel packet.
Only executes body if `hero+0xf2c` (init flag) is non-zero.
```c
void CHero_CancelAutoRunAndClearIdle(CHero* hero) {
    if (*(hero + 0xf2c) == 0) return;         // skip if idle system not yet initialized
    *(hero + 0xf30) = timeGetTime();           // reset idle countdown timer
    if (CHero_GetIdleState(hero) != 0) {       // only if was idle
        CHero_SetIdleState(hero, 0);           // clear hero+0x18
        CHero_SendIdleActionMsg(0);            // CMsgAction(0xa1, idleFlag=0)
        bool suppress = CHero_HasInteractionActionStatus(hero);
        Role_CommandType06_SelectActionAndToggleMountedScaleSuppression(hero, false, suppress);
    }
}
```
**Cancel packet IS sent** when transitioning from idle back to active. The transition helper's
first stack argument is a boolean: `false` for cancel/active and `true` for idle entry. The role
object remains the `this` pointer in `ECX`; neither call passes a null role.

#### Role_CommandType06_SelectActionAndToggleMountedScaleSuppression (0x67563F)

Idle entry (`enteringIdle=true`) performs these operations in order:

1. If cached mounted interval `CRole+0x118` is nonzero, call
   `Role_SetMountedActionFrameIntervalAndRefreshActionScale(role, 0)` to clear the active interval at
   `+0x128`, then write the same cached `+0x118` value back through that setter.
2. Return if status flag `0x1E` or `0x1F` is set.
3. If command type `CRole+0x1E8` is `6` and progress `+0x1EC` is not `6`, call
   `Role_RecomputeCoordinateGateCacheFromProjectedPosition` (`0x64E9A5`). For the idle-entry path,
   the prior interaction-status cancellation proves `CHero+0x2EEC == 0`: a physical current action
   therefore returns immediately, while a nonphysical action follows the normal completion and
   inverse-projection path.
4. Zero a `0x11C` command block, write type `6`, progress `0`, direction from `CRole+0x17C`, and
   payload `0xFA`, then apply it through vtable slot `+0x80`
   (`Role_TryApplyIncomingActionInfo`).

Idle cancel (`enteringIdle=false`) applies the analogous type-6 command with payload `0x64` only
when flags `0x1E`/`0x1F` are clear and the interaction-suppression argument is false. Independently
of that command gate, mounted status flag `0x32` restores the active interval from cached
`CRole+0x118`.

The type-6 selector at `0x73450B` gives payload `0xFA` a two-stage interaction-aware mapping:

| Progress before | Interaction type | Selected action | Progress after |
|---:|---:|---:|---:|
| `0` | `100004` (hold hands) | `0x1DD` | `2` |
| `0` | `100007` (hug walk) | `0x1D9` | `2` |
| `0` | other | `0xFA` | `2` |
| `2` | `100004` (hold hands) | `0x1DE` | `3` |
| `2` | `100007` (hug walk) | `0x1DA` | `3` |
| `2` | other | `0xFA` | `3` |

Any other progress for payload `0xFA` takes the ordinary type-6 fallback: action `0x64`, progress
`6`. The two interaction selectors are `Role_SelectCommandType06PayloadFAFirstStageAction`
(`0x64F0D5`) and `Role_SelectCommandType06PayloadFASecondStageAction` (`0x64F102`).

#### CGameMap_IsStateBlockingAutoRun (0x62084b)
**Purpose**: Returns true if map state blocks auto-run (map+0xe0 == 0x40f).
```c
bool CGameMap_IsStateBlockingAutoRun(CGameMap* this) {
    return *(uint32_t*)(this + 0xe0) == 0x40f;
}
```

#### CHero_IsCommandType03BlockingAutoRun (0x65b610)
**Purpose**: Returns true if the command-state type at `CRole+0x1e8` equals 3.
```c
bool CHero_IsCommandType03BlockingAutoRun(CHero* this) {
    return this->command_type == 3;  // this+0x1e8
}
```

This field is not the current action type at `CRole+0xd8` (`Role_GetActionType`).

### Managed reconstruction status

`LocalHeroPreFrameAutoRunAndIdleDecision` mirrors the proven initialization, five-predicate
short-circuit cancellation decision, idle entry/cancel packet ordering, and strict working-set
throttle boundary. `LocalHeroIdleRoleCommandTransition` mirrors the command-type-6 transition,
including mounted-scale ordering, the narrow local-hero coordinate-cache path, and payload
`0xFA`/`0x64` command construction. The runtime adapters load the native timeout, submit the real
packet, and call `SetProcessWorkingSetSize(GetCurrentProcess(), -1, -1)` on Windows; other platforms
perform no substitute collection because none is supported by native evidence.

Production frame wiring now runs the completed native subset in order: step 14 idle/auto-run
decision followed by step 15 first-type-1-component tick. Packet 1110 writes the current map id, and
the managed map state derives the `0x40F` block predicate with exact equality. Local equipment and
status ingress now populate the cached mounted interval at `CRole+0x118`. The nonzero-ID action
`0x6F` path supplies the
verified managed writer for `CHero.boothManager.boothNpcId/isActive`, and the pre-frame runtime reads
that live state. Full booth setup/close behavior and the native `0xFA` role-action side effect are not
implemented by this slice. The larger pre-map composite remains inactive until its later native
frame slots have concrete managed implementations.

### Auto-Run Block Conditions (verified)
Auto-run is blocked by any of the following:
1. `CGameMap_IsStateBlockingAutoRun` → `map+0xe0 == 0x40f`
2. `CHero_IsCommandType03BlockingAutoRun` → command type `CRole+0x1e8 == 3`
3. `hero->boothManager.isActive != 0` (`hero+0x2a5c`)
4. `Role_GetAutoRunActiveState(hero)` → `hero+0x2e14 != 0`
5. `CHero_HasInteractionActionStatus(hero)` → `hero+0x2eec != 0`

### CMsgAction Action Type 0xa1 — Idle Toggle
| Field | Offset | Value |
|---|---|---|
| PacketSize | 0 | 38 (0x26) |
| PacketType | 2 | 10010 (0x271A) |
| EntityId | 4 | hero UID |
| ParamLow | 8 | idleFlag (0=active, 1=idle) |
| ParamHigh | 10 | 0 |
| ActionParam | 12 | 0 |
| Timestamp | 16 | timeGetTime() |
| ActionType | 20 | 0xa1 (161) |
| Direction | 22 | 0 |
| PositionX | 24 | 0 |
| PositionY | 26 | 0 |

## Helper Address Index

| Function | Address |
|---|---|
| CHero__Init | 0x656BB0 |
| CHero__Dtor | 0x6562D0 |
| CHero__Reset | 0x65700E |
| CHero__ProcessPlayerAction | 0x5AFEDF |
| CHero__ValidateAttackCommand | 0x65B625 |
| CHero__SendInteractMsg | 0x65BC3B |
| CHero__ProcessAction_Main | 0x65C0F5 |
| CHero__ProcessMagicAction | 0x6F6227 |
| CHero__ValidateMagicUse | 0x6F5A18 |
| CHero__UpdateMagicByIdLevelCaster | 0x6F5546 |
| CHero__RenderXpBar | 0x65E497 |
| CHero__LoadLevelExpTable | 0x65FFE4 |
| CHero__TryMoveToTarget | 0x65D9B2 |
| CPlayer__Destructor | 0x66F09C |
| CRole__Dtor | 0x64D647 |
| RBTree__LowerBound | 0x6C6D28 |
| CMagic__GetMagicDataRecord | (via vtable) |
| Load_MagicEffect_Ini | 0x69D154 |
| CHero__AddNewWeaponSkillToList | 0x71D25D |
| CHero_TickPreFrameAutoRunAndIdleDecision | 0x65cc70 |
| CHero_GetIdleState | 0x650447 |
| CHero_SetIdleState | 0x65044b |
| CHero_SendIdleActionMsg | 0x65cd30 |
| CHero_TrimWorkingSetOnIdle | 0x66dca6 |
| CHero_CancelAutoRunAndClearIdle | 0x65cda2 |
| CGameMap_IsStateBlockingAutoRun | 0x62084b |
| CHero_IsCommandType03BlockingAutoRun | 0x65b610 |
