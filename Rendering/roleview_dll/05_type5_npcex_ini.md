# Type 5 RoleView — `ini/npcex.ini` Variant Selection

Type 5 RoleView objects (created by `RoleViewCreate(type=5)`) read `ini/npcex.ini` to select a **look-id variant** based on runtime values set through the property setter.

This file is distinct from the `GameData.dll` NPC role-data files:

- `RoleDataSingleton_LoadNpcTypeAndNpcVariantTables` (`0x100044BF`) loads `ini/Npc.ini` and `ini/NpcX.ini`
- `RoleDataSingleton_LoadTerrainNpcTable` (`0x1000419D`) loads `ini/TerrainNpc.ini`

Those GameData tables feed the type-4 / terrain-NPC role-data lookups used by `CMsgNpcInfo__Process`; they are not the same parser or data model as this type-5 `npcex.ini` path.

## Data source

- File: `ini/npcex.ini`
- Section name format: `NpcType%d` where `%d = lookId / 10`

## Loaded keys per section

The loader reads:

- `Amount` → `count` (clamped to `<= 64`)
- For each `i` in `[0 .. count)`:
  - `Var{i}` → integer threshold/variable
  - `Look{i}` → integer look-id to apply when the threshold condition matches

## Property keys and variant recomputation

Type 5 property setter (`RoleView_Type5_SetProperty`, vtable slot 1) uses:

- key `0`: `RoleView_Type5_SetLookId_LoadNpcExIni(lookId)`
  - stores `lookId % 10` into the object
  - loads `Amount`, `Var{i}`, and `Look{i}` arrays from `ini/npcex.ini`
  - applies `Look0` immediately via `RoleView_Type5_ApplyLookId_RoleData_ToSimple3DObj(lookId)`

- key `21`: `RoleView_Type5_SetValue21_RecomputeVariantLook(value21)`
  - writes `value21` into the object
  - recomputes a derived "percent" as `MulDiv(value22, 100, value21)` clamped to `<= 100`
  - selects the first `Look{i}` whose corresponding `Var{i}` is `>= percent`
  - applies that look-id via `RoleView_Type5_ApplyLookId_RoleData_ToSimple3DObj`

- key `22`: `RoleView_Type5_SetValue22_RecomputeVariantLook(value22)`
  - writes `value22` into the object
  - recomputes/selects/applies using the same rule as key `21`

If `value21 == 0`, recomputation treats the derived percent as `100`.

## Applying a look-id

`RoleView_Type5_ApplyLookId_RoleData_ToSimple3DObj(lookId)`:

- returns early if `lookId` equals the currently-applied look-id
- looks up role data for `(lookId % 10, lookId / 10)` via `RoleDataQuery`
- copies role data fields into the object (including a 0x24-byte name string)
- ensures an internal `Simple3DObj` exists and sets its "model id" from role data
