# CNpc Class -- NPC System
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Network\MsgNpcInfo.cpp

---

## Class Hierarchy
```
CRole (base, ~1088 bytes)
  -> CPlayer (~2636 bytes)
    -> CNpc (~2648 bytes, 0xA58)
      -> CHero (~12300 bytes, singleton)
```

**Correction (verified from the constructors).** `sub_66EC52`, the constructor that installs vtable
`0x86AEEC` and stores role type `7`, calls `CRole_Constructor` (`0x64D079`) **directly** at
`0x66EC66` — there is no intermediate constructor between it and `CRole`. `CHero_Ctor` (`0x6551A1`)
then calls `sub_66EC52` and overwrites the type code with `6` at `0x655755`. So the constructor
chain is:

```
CRole (vtable 0x86AACC, type 0)
  -> 0x86AEEC class (type 7)          <- this file's subject
    -> CHero (vtable 0x86AD08, type 6)
```

`0x86C94C` and `0x86CB3C` are two further subclasses of the `0x86AEEC` class and keep type `7`;
`0x86C568` derives straight from `CRole` and uses type `0x13`. Whether the `0x86AEEC` class is
`CPlayer` or `CNpc` is not settled by the constructors — `cplayer_class.md` claims the same vtable —
but there is no separate class between it and `CRole`. Also note `CRole` itself derives from
`CMapObj` (vtable `0x86A2B8`), which is what makes roles members of the map's active render deque;
see `Rendering/00_rendering_gap_analysis.md`.

CNpc extends CPlayer (which extends CRole). It represents all non-player-controlled entities in the game world, including static NPCs, monsters, terrain objects, and special interactive objects.

---

## CNpc Object Layout (0xA58 = 2648 bytes)

### Key Offsets (DWORD indices from constructor at 0x66EC52)
| Offset (DWORD) | Offset (bytes) | Field | Notes |
|---|---|---|---|
| 0 | 0x000 | vtable_ptr | Points to 0x86AEEC |
| 51 | 0x0CC | entity_id | Set from packet field +1 (DWORD) |
| 195 | 0x30C | current_hp | Gradually interpolated toward target_hp |
| 196 | 0x310 | target_hp | Target HP value |
| 216 | 0x360 | role_type | Set to 7 in constructor (NPC type) |
| 218 | 0x368 | npc_type | NPC type/appearance enum |
| 237 | 0x3B4 | is_alive | 0 = dead/inactive |
| 273 | 0x444 | field_444 | Cleared in constructor |
| 274 | 0x448 | field_448 | Cleared in constructor |
| 275 | 0x44C | field_44C | Cleared in constructor |
| 280 | 0x460 | field_460 | Cleared in constructor |
| 285 | 0x474 | field_474 | Cleared in constructor |
| 286 | 0x478 | dynarank_entry | Initialized via DynarankEntry__Ctor |
| 302-304 | 0x4B8-4C0 | fields | Cleared in constructor |
| 305 | 0x4C4 | string_1 | std::string, initialized empty |
| 310 | 0x4D8 | string_2 | std::string, initialized empty |
| 313 | 0x4E4 | field_4E4 | Cleared |
| 314 | 0x4E8 | field_4E8 | Cleared |
| 316 | 0x4F0 | component_0x4F0 | Large sub-object, init via CNpcComponent_0x4F0__Ctor |
| 525 | 0x834 | max_hp_default | Set to 100 in constructor |
| 554 | 0x8A8 | field_8A8 | Cleared |
| 557 | 0x8B4 | field_8B4 | Cleared |
| 559 | 0x8BC | processing_flag | Cleared each update frame |
| 568 | 0x8E0 | action_queue_ptr | Action/animation queue |
| 570 | 0x8E8 | action_queue_end | End of action queue |
| 578 | 0x908 | field_908 | Cleared |
| 579 | 0x90C | string_3 | std::string |
| 580 | 0x910 | string_3_end | |
| 582 | 0x918 | field_918 | Cleared |
| 583 | 0x91C | field_91C | Cleared |
| 584 | 0x920 | component_0x920 | Init via CNpcComponent_0x920__Ctor |
| 606 | 0x978 | timer_value | Random timer from CdFunc |
| 607 | 0x97C | field_97C | Cleared |
| 608 | 0x980 | effect_3d_1 | Game3DEffectCreate(0) |
| 609 | 0x984 | field_984 | Cleared |
| 610 | 0x988 | field_988 | Cleared |
| 611 | 0x98C | field_98C | Cleared |
| 612 | 0x990 | string_4 | std::string |
| 615-618 | 0x99C-9A8 | fields | Cleared |
| 620-622 | 0x9B0-9B8 | fields | Cleared |
| 623-625 | 0x9CC-9D4 | fields | Cleared |
| 636 | 0x9F0 | field_9F0 | Cleared |
| 638-639 | 0x9F8-9FC | fields | Cleared |
| 641 | 0xA04 | field_A04 | Cleared |
| 642 | 0xA08 | component_0xA08 | Init via CNpcComponent_0xA08__Ctor |
| 647 | 0xA1C | effect_3d_2 | Game3DEffectCreate(0) |
| 648 | 0xA20 | component_0xA20 | Init via CNpcComponent_0xA20__Ctor |
| 652 | 0xA30 | component_0xA30 | Init via CNpcComponent_0xA30__Ctor |
| 659-661 | 0xA4C-A54 | fields | Cleared |

### Special byte offsets
| Offset (bytes) | Field | Notes |
|---|---|---|
| 0x470 (1136) | byte flag | Cleared |
| 0x3A8 (936) | byte flag | Checked in map visibility |
| 0xA00 (2560) | byte flag | Cleared |
| 0x9AC (2476-2477) | byte flags | Cleared |
| 0xA48 (2632) | byte flag | Cleared |

---

## CNpc VTable (0x86AEEC, 30 entries)

| Index | Address | Function | Description |
|---|---|---|---|
| 0 | 0x66EF2E | CNpc__Destructor | Destructor (calls CPlayer__Destructor) |
| 1 | 0x66F7AB | CNpc__vtUpdate | Virtual update dispatch |
| 2 | 0x6725ED | CNpc__Update | Main update logic: animation, movement, effects |
| 3 | 0x651856 | (getter) | Returns field |
| 4 | 0x65185D | (getter) | Returns field |
| 5 | 0x651875 | (getter) | Returns field |
| 6 | 0x65189C | (setter) | SetPosition(x, y) |
| 7 | 0x641307 | (func) | |
| 8 | 0x64B975 | NoOp_0x64B975 | No-op |
| 9 | 0x64CCFD | (func) | |
| 10 | 0x63734D | (func) | |
| 11 | 0x637360 | (func) | |
| 12 | 0x63736A | (func) | |
| 13 | 0x73399A | CRoleAction__ProcessBumpBack | Bump/knockback action handler |
| 14 | 0x733B20 | CRoleAction__ProcessQuickMove | Quick-move/teleport action handler |
| 15 | 0x735A1B | (func) | |
| 16 | 0x735A6F | (func) | |
| 17-20 | 0x6517xx | (getters/setters) | Various property accessors |
| 21 | 0x64F5F7 | CRole__Render3D | 3D rendering |
| 22 | 0x64EAB2 | (func) | Render-related |
| 23 | 0x6E4D36 | (func) | |
| 24 | 0x6E4E21 | (func) | |
| 25 | 0x651845 | (getter) | |
| 26 | 0x651852 | (getter) | |
| 27 | 0x64E1D9 | (func) | |
| 28 | 0x64E228 | (func) | |
| 29 | 0x64E217 | (func) | |

---

## NPC Type System

NPC kinds determine the RoleView construction path. Verified from `CMsgNpcInfo__Process` (`0x743B32`):

### NPC kind categories (`packet+18`)
| Kind Value | RoleView Mode | Verified branch |
|---|---|---|
| `0x0E` | 6 | `CRole__CreateRoleView(npc, look, 6)` |
| `0x13` | 8 | `CRole__CreateRoleView(npc, look, 8)` |
| `0x19, 0x1A, 0x27, 0x29, 0x2A, 0x66, 0x67` | 9 | `CRole__CreateRoleViewWithPos(npc, look, 9, entity_id, x, y)` |
| all other values | 4 | `CRole__CreateRoleView(npc, look, 4)` |

### NPC Look Composite Encoding
```
look_lookup_id       = look_composite / 10
look_direction_index = look_composite % 10
```
When `look_lookup_id >= 5000`: uses terrain role-data lookup via
`RoleDataSingleton_FindTerrainNpcRecord` (`GameData.dll`, `0x10004D9C`) through
`RoleDataQuery()->vtable+0x34`
When `look_lookup_id < 5000`: uses standard role-data lookup via
`RoleDataSingleton_FindNpcTypeRecord` (`GameData.dll`, `0x10004D63`) through
`RoleDataQuery()->vtable+0x30`

### Verified GameData role-data sources behind those lookups

`GameData.dll` loads three distinct NPC tables:

- `RoleDataSingleton_LoadNpcTypeAndNpcVariantTables` (`0x100044BF`)
  - opens `ini/Npc.ini`
  - parses `[NpcType%d]` sections with:
    - `Name`
    - `SimpleObjID`
    - `StandByMotion`
    - `BlazeMotion`
    - `RestMotion`
    - `Effect`
    - `ASB`
    - `ADB`
    - `FixDir`
    - optional `ZoomPercent`
    - optional `SimplifyEnabled`
  - inserts records through `RoleDataNpcTypeRecord_Assign` (`0x10004BE3`)
  - then opens `ini/NpcX.ini`
  - parses `[%d]` sections with:
    - `Name`
    - `AddSize`
    - `Scale`
    - `FixDir`
    - `Look`
    - `Head`
    - `Hair`
    - `Armet`
    - optional `ArmetColor` (defaults to `3` when absent)
    - `Armor`
    - optional `ArmorColor` (defaults to `3` when absent)
    - `RWeapon`
    - `LWeapon`
    - optional `LWeaponColor` (defaults to `3` when absent)
    - `Misc`
    - `Mount`
    - `Effect`
    - optional `SimplifyEnabled`
  - inserts records through `RoleDataNpcVariantRecord_Assign` (`0x10004CA1`)
- `RoleDataSingleton_LoadTerrainNpcTable` (`0x1000419D`)
  - opens `ini/TerrainNpc.ini`
  - parses `[NpcType%d]` sections with `Name` and `Dir0..Dir7`
  - each `DirN` string is a scene path consumed by the terrain-NPC path

Important distinction:

- `ini/NpcX.ini` is a GameData NPC appearance table used by the type-4 / standard role-data path.
- `ini/npcex.ini` is a different RoleView-local variant table used by RoleView type 5.

### Verified standard type-4 render seam

For the common `npc_kind -> RoleView mode 4` path:

- `RoleView_Type4_SetLookId_LoadRoleData` (`RoleView.dll`, `0x10004A68`) feeds
  `record+0x50` (`SimpleObjID`) into an internal `Simple3DObj` at `npc_role_view+0x94`
- the active motion family also comes straight from the same `Npc.ini` record:
  - blaze -> `record+0x58/+0x5C`
  - rest -> `record+0x60/+0x64`
  - standby -> `record+0x68/+0x6C`
- the live current-motion pair is initialized from **standby**
- `RoleView_Type4_TickAndRender` resolves motions only through
  `GameDataSetQuery()->vtable+0x20("body", motionLow, motionHigh, 1, 0)`
- frame stepping is fixed at `33` ms (`0x21`)
- `RoleView_Type4_SetLookId_LoadRoleData` zeros the frame timer at `type4+0x7C`
- motion completion in the live type-4 render loop is:
  - completed blaze -> standby
  - every other completion defaults to standby
  - non-blaze completion only swaps to rest when
    `RoleView_RandModuloOptionalReseed(0x1E, 0) == 0x0F`
- the separate 20-second timeout is real native behavior, guarded by `type4+0x90 != 0`, and
  forces current motion to blaze while restarting both timers
- the live `type4+0x90` gate is written by `RoleView_Type4_RenderOrHitTest` (`0x10004583`) in
  both the direct internal `Simple3DObj` hit-test path and the manual ray/AABB fallback path
- when the simple-object model id is applied, `Role3D.dll::Simple3DObj_SetModelId_LoadPartInfo`
  first probes `3DSimpleObjEx.dbc`, then falls back to the `3DSimpleObj.dbc` pointer-map
  loaded at `GraphicData.dll::GameDataSet + 0x0C`

So the verified standard NPC render stack is:

1. `MsgNpcInfo(2030)` -> `Npc.ini` role-data lookup
2. `SimpleObjID` -> `RoleView type 4` internal `Simple3DObj`
3. `Simple3DObj` model id -> `GraphicData.dll` simple-object DB lookup
4. `"body"` motion lookup by the type-4 simple-object motion pair
5. `Simple3DObj` frame advance + render

Current managed reconstruction uses that same stack as a one-body-slot simple-object render path:

- visual-plan kind: `StandardSimpleObjectRoleData`
- transform input: type-4 body render now consumes the RoleView projection-base offset
  derived from the NPC's absolute projected point, matching the shared
  `Role_TickAndRender -> RoleView_Type4_SetTransform` contract
- mesh source: `3DSimpleObj.dbc` pointer-map rows for the resolved `SimpleObjID`
- texture source: `SimpleObjectRecord.Pairs[*].SecondaryResourceId`
  - verified native path: `Simple3DObj_Render -> PartInfo_BindPerPartTexturesAndMaterial`
    -> mesh texture bind
  - managed implication: standard type-4 NPC draws must feed
    `RolePartResolvedPart.PrimaryTextureId` into the renderer when no stronger runtime
    texture override exists
- motion source: `"body"` only, from the current type-4 motion pair
  - `RoleView_Type4_SetLookId_LoadRoleData` copies the stored low/high motion pair directly
    from role-data storage into the live type-4 object
  - `GraphicData.dll::ResourceExecute_LoadStringKeyed` then probes `3dmotion.dbc` by exact
    compound-key match
  - real 5517 assets show `Guide` `Npc.ini::RestMotion=9990070101`, but runtime
    `c3.wdb:ini/3dmotion.dbc` stores the matching record as `999007101` / `0`
  - managed reconstruction therefore applies the raw-then-stripped fallback only for
    standard simple-object NPC body motions
- frame cadence: fixed `33` ms
- completion rule: blaze falls back to standby; every other completion defaults to standby and
  only promotes to rest on live `rand()%30==15`

The native `3DSimpleObjEx.dbc` probe remains documented above but is still intentionally left
out of the managed runtime path until the 16-byte item-row semantics are pinned tightly enough
to map into `RolePartModelResolution` without guesswork.

Oracle-backed stopgap (not yet directly pinned from 5517 BNinja parser control flow):

- live 5517 `Npc.ini` rows frequently omit `ZoomPercent` (for example `NpcType1`, `NpcType261`)
- older retail client sources initialize the field to `100` before the optional read
- the managed type-4 runtime currently mirrors that `100` fallback only when the parsed value is
  `0`, so common standard NPCs remain visible while the exact 5517 omitted-line default is still
  being re-verified

---

## MsgNpcInfo Packet (Type 2030)
**Source**: MsgNpcInfo.cpp
**Handler**: `CMsgNpcInfo__Process` @ `0x743B32`

### Verified fixed packet fields
| Offset | Size | Field | Description |
|---|---|---|---|
| +4 | 4 | entity_id | NPC entity ID |
| +8 | 4 | spawn_auxiliary_dword | Passed to helper `0x650D9E`; exact semantic still unproven |
| +12 | 2 | tile_x | Spawn X |
| +14 | 2 | tile_y | Spawn Y |
| +16 | 2 | look_composite | Encodes role-data lookup id and facing remainder |
| +18 | 2 | npc_kind | Selects RoleView mode branch |

### Verified process flow
1. Resolves any existing entity by `entity_id` and runs the cleanup path first.
2. Allocates `CNpc` (`0xA58`) and constructs it when no surviving entity remains.
3. Writes:
   - `npc+0xCC = entity_id`
   - `npc+0x368 = npc_kind`
4. Calls helper `0x650D9E(npc, spawn_auxiliary_dword)`.
5. Applies a default string through `0x6E5292`.
6. Builds RoleView mode `4`, `6`, `8`, or `9` according to `npc_kind`.
7. Non-type-9 paths also call npc vfunc slot `+0x18` with `(tile_x, tile_y)`.
8. Splits `look_composite` into `look_lookup_id` and `look_direction_index`.
9. Uses standard or terrain role-data lookup depending on `look_lookup_id < 5000`.
10. On successful role-data lookup:
    - applies the role-data name
    - forwards role-data payload into the live RoleView object at `npc+0x430` when present
    - writes `npc+0x184` from the role-data record
    - standard type-4 payload includes:
      - `SimpleObjID`
      - `StandByMotion`
      - `BlazeMotion`
      - `RestMotion`
      - `ASB`
      - `ADB`
      - `FixDir`
11. Applies `look_direction_index` through `0x650CC2`.
12. Overrides the display name from MsgStringList entry `0` when present.
13. Registers the entity in the entity manager and posts the final entity update.

---

## Key CNpc Functions

| Address | Name | Size | Description |
|---|---|---|---|
| 0x66EC52 | CNpc__Constructor | 0x2CC | Initializes 2648-byte NPC object, sets role_type=7 |
| 0x66EF2E | CNpc__Destructor | ~24 | Calls CPlayer destructor, frees memory |
| 0x66F42B | CNpc__InitDefaults | | Initializes default NPC field values |
| 0x66F7AB | CPlayer__Update | | CNpc vtable update dispatch (shared player update path) |
| 0x6725ED | CNpc__Update | 0x2F0 | Main per-frame update: animation, movement, effects |
| 0x660AC5 | CHero__SpawnNpcRole | 0x257 | Creates an NPC entity from type ID |
| 0x7439E3 | CMsgNpcInfo__Create | | Creates the MsgStringList-backed 2030 packet object |
| 0x743A9F | CMsgNpcInfo__Parse | | Validates type 2030 and copies the packet bytes |
| 0x743B32 | CMsgNpcInfo__Process | 0x3DF | Processes NPC spawn packet |
| 0x75E38D | CMsgNpcInfo__ProcessBattleLevel | 0xB9 | Updates NPC battle level/power field |
| 0x74A5E6 | CMsgNpcInfoEX__Process | 0x115 | Handles time sync and related type-coded updates |
| 0x66EB93 | CNpc__AllocateMemory | | Allocates 0xA58 bytes for NPC |
| 0x505C58 | CSmartPtr__Create | | Creates smart pointer wrapper (ref-counted) |

---

## NPC Spawn Flow

1. Server sends MsgNpcInfo packet with `entity_id`, `spawn_auxiliary_dword`, position, `look_composite`, and `npc_kind`
2. `CMsgNpcInfo__Process` creates a new CNpc (0xA58 bytes) via CNpc__AllocateMemory + CNpc__Constructor when needed
3. Entity ID is set at offset +51 (DWORD)
4. NPC kind determines the RoleView mode (visual appearance):
   - Standard NPCs use mode 4
   - Interactive/object kinds use mode 9 with explicit position
   - Special types (14, 19) use modes 6 and 8 respectively
5. Look data is loaded from RoleData using:
   - `look_lookup_id = look_composite / 10`
   - `look_direction_index = look_composite % 10`
   - standard lookup for `< 5000` via `RoleDataSingleton_FindNpcTypeRecord`
   - terrain lookup for `>= 5000` via `RoleDataSingleton_FindTerrainNpcRecord`
6. Display name is finally overridden from MsgStringList entry `0` when present
7. NPC is registered in the entity manager via `0x6E77D5`

---

## NPC Update Loop (CNpc__Update @ 0x6725ED)

Each frame:
1. CPlayer__CheckGuildNameTimeout_0x8D4_0x8D8 (timeout-based guild name reset)
2. Updates visual effects (CPlayer__UpdateVisualEffects)
3. Clears processing_flag (offset +559) and checks alive flag (offset +237 must be non-zero) or returns
4. State gate:
   - If !CRole__GetByte_0x6C and !CRole__HasFlagBitset_0xA0:
     - If CRole__HasStatusFlag(27): CRole__SetVerticalRenderOffsetTarget(100)
     - Else: CRole__SetVerticalRenderOffsetTarget(0)
5. Updates role info list (CRoleInfo__UpdateAndPrune) and helper CRole__UpdateHelper_0x673AB4
6. If vtable+88 is true:
   - If RingBuffer__Count_0x11C(this+2272) > 0:
     - Copy 0x11C bytes from action queue entry (offsets +568/+570 = 0x8E0/0x8E8)
     - Call CRole__ApplyActionEntry_0x11C
     - Advance queue via RingBuffer__AdvanceBlock_0x11C
   - Else if !Role_IsCommandType04To0BOr0EWithCompleteFallback or !CRole__ProcessTimedActionQueue_0x440: skip animation step
7. vtable+132 then CRole__ProcessAnimation
8. UI__UpdatePaneState_0x64E291
9. Screen-space checks:
   - For scheduler proxy 110/111/120/121: pre-processes coordinates via
     ObfThunk__CallShift1 / ObfThunk__CallNeg1, then uses CGameMap__TileToScreenDelta
     followed by CGameMap__IsTileInViewRadius. If in view and byte flag 0x3A8 is clear,
     calls CGameMap__NotifyComponentType3_IfAny(this).
   - Otherwise: uses CGameMap__IsTileInViewRadius + CGameMap__NotifyComponentType3_IfAny.
10. If field[580] != field[579] and Random__RandMod_Seeded(100,0)==1:
    HandleStringIfNotNull_0x6E4D1D(field[579])
11. Update floating text (CFloatingStr__UpdateAndPrune) and zoom numbers (CZoomNum__UpdateAndPrune)
12. Smoothly interpolates field[195] toward field[196] by +/-6 per frame
13. Calls vtable+152

---

## Entity Manager Integration

NPCs are managed through a shared entity system:
- `EntityManager__FindEntityById(ptr, entity_id, 0)` - Lookup entity by ID
- `EntityManager__RegisterEntity(npc_ptr, ref)` - Register entity in manager
- `RefPtr__Reset(&ptr)` - Release entity reference
- Entity IDs: NPCs use range 400001-500000, Monsters 500001-600000

---

## NPC Data Files

- **NpcType data**: Loaded via RoleDataQuery(10, variant) - uses vtable+48 for standard, vtable+52 for terrain
- **NpcType%d_%d format string** at 0x9358D8: Used for NPC type lookup by ID and variant
- NPC visual data includes mesh/animation info at type_data+16 and name at type_data+4



## Helper Address Index

| Function | Address |
|---|---|
| CFloatingStr__UpdateAndPrune | 0x7381c9 |
| CGameMap__IsTileInViewRadius | 0x61e00d |
| CGameMap__NotifyComponentType3_IfAny | 0x61e74b |
| CGameMap__TileToScreenDelta | 0x61d707 |
| CNpcComponent_0x4F0__Ctor | 0x6765ee |
| CNpcComponent_0x920__Ctor | 0x7178f0 |
| CNpcComponent_0xA08__Ctor | 0x66ea9d |
| CNpcComponent_0xA20__Ctor | 0x66eadc |
| CNpcComponent_0xA30__Ctor | 0x66eaf6 |
| CPlayer__CheckGuildNameTimeout_0x8D4_0x8D8 | 0x675ce8 |
| CPlayer__Destructor | 0x66f09c |
| CPlayer__UpdateVisualEffects | 0x674429 |
| CRoleInfo__UpdateAndPrune | 0x6e5408 |
| CRole__ApplyActionEntry_0x11C | 0x64dd38 |
| CRole__GetByte_0x6C | 0x650d89 |
| CRole__HasFlagBitset_0xA0 | 0x6e51db |
| CRole__HasStatusFlag | 0x6e50d4 |
| Role_IsCommandType04To0BOr0EWithCompleteFallback | 0x6e4f55 |
| CRole__ProcessAnimation | 0x64e2dd |
| CRole__ProcessTimedActionQueue_0x440 | 0x6724c6 |
| CRole__SetVerticalRenderOffsetTarget | 0x650fe1 |
| CRole__UpdateHelper_0x673AB4 | 0x673ab4 |
| CZoomNum__UpdateAndPrune | 0x7302b1 |
| DynarankEntry__Ctor | 0x72e771 |
| EntityManager__FindEntityById | 0x6e847d |
| EntityManager__RegisterEntity | 0x6e77d5 |
| ObfThunk__CallNeg1 | 0x7132f1 |
| ObfThunk__CallShift1 | 0x7132ec |
| Random__RandMod_Seeded | 0x769250 |
| RefPtr__Reset | 0x712ce0 |
| RingBuffer__AdvanceBlock_0x11C | 0x676dea |
| RingBuffer__Count_0x11C | 0x676a33 |
| UI__UpdatePaneState_0x64E291 | 0x64e291 |
