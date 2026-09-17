# Transform Look Record — `ini/Transform.ini`

## Source
- Loader: `RoleDataSingleton_LoadTransformIni` (`GameData.dll:0x100026f8`)
- Lookup: `RoleDataSingleton_LookupTransformLookRecord` (`GameData.dll:0x100028bf`) — vtable `+0x28`
- Consumer: `CRole__SetTransformLook` (`Conquer.exe:0x650B58`)
- Storage: BST at `RoleDataSingleton + 0x1A4`, keyed by `uint32 refreshSourceId`

## INI Format

```ini
[refreshSourceId]
Jump=%u
AddSize=%d
Scale=%d
Look=%d
Armet=%u
RWeapon=%u
LWeapon=%u
Misc=%u
Mount=%u
```

Each section defines a transform-look record (36 bytes / 9 fields).

## Record Layout (0x24 bytes)

| Offset | Size | Field     | fscanf       | Description                              |
|-------:|-----:|-----------|--------------|------------------------------------------|
| 0x00   | 4    | Jump      | `%u`         | Jump capability flag                     |
| 0x04   | 4    | AddSize   | `%d`         | Size offset applied to CRole+0x174       |
| 0x08   | 4    | Scale     | `%d`         | Scale value (100 = default 1.0×)         |
| 0x0C   | 4    | Look      | `%d`         | Body appearance override (RoleView key 3)|
| 0x10   | 4    | Armet     | `%u`         | Helmet/armet source (RoleView key 5)     |
| 0x14   | 4    | RWeapon   | `%u`         | Right weapon source (RoleView key 6)     |
| 0x18   | 4    | LWeapon   | `%u`         | Left weapon source (RoleView key 7)      |
| 0x1C   | 4    | Misc      | `%u`         | Misc source (RoleView key 9)             |
| 0x20   | 4    | Mount     | `%u`         | Mount source (RoleView key 8)            |

## Lookup Function (`vtable+0x28`)

```c
// RoleDataSingleton_LookupTransformLookRecord (0x100028bf)
// ecx = RoleDataSingleton*, refreshSourceId is the lookup key
TransformLookRecord* result = BST_Find(this + 0x1A4, refreshSourceId);
if (result != sentinel)
    return result + 0x14;  // data payload past BST node header
return NULL;
```

## Consumer: `CRole__SetTransformLook` (0x650B58)

### Phase 1 — Clear existing transform (if `role[0x3B]` was previously set)

```
roleView.SetProperty(0, role[0x34].w)   // restore original body appearance
CRole__ReapplyAllVisualSources(role)     // 0x650AB9
role[0x5D] = 0                           // clear AddSize
role[0x61] = 100                         // reset Scale to default
```

### Phase 2 — Apply new transform (if `refreshSourceId != 0`)

```
record = RoleDataQuery()->vtable+0x28(refreshSourceId)
if (record == NULL) return

role[0x5D] = record.AddSize          // offset 0x04
role[0x61] = record.Scale            // offset 0x08
role[0x3B] = refreshSourceId         // store active transform id

roleView.SetProperty(3, record.Look)     // body appearance override
roleView.SetProperty(0x34, 0)            // zero override key 0x34
roleView.SetProperty(5, record.Armet)    // helmet source
roleView.SetProperty(0x37, 0)            // zero override key 0x37

role[0x41..0x44] = 0                     // clear equipment slots

roleView.SetProperty(6, record.RWeapon)  // right weapon source
roleView.SetProperty(0x3B, 0)            // zero override key 0x3B
roleView.SetProperty(7, record.LWeapon)  // left weapon source
roleView.SetProperty(0x3A, 0)            // zero override key 0x3A

role[0x45] = 0                           // clear slot

roleView.SetProperty(9, record.Misc)     // misc source
roleView.SetProperty(8, record.Mount)    // mount source
```

## RoleView Key ↔ Transform Record Field Mapping

| RoleView Key | Property Method                         | Transform Field | Record Offset |
|:------------:|:----------------------------------------|:----------------|:-------------:|
| 3            | ResetSourcesAndRebuildBodyAppearance    | Look            | 0x0C          |
| 5            | SetPrimaryHelmetVariantSourceAndReload  | Armet           | 0x10          |
| 6            | SetRightWeaponSource                    | RWeapon         | 0x14          |
| 7            | SetLeftWeaponSource                     | LWeapon         | 0x18          |
| 8            | SetMountSource                          | Mount           | 0x20          |
| 9            | SetMiscSource                           | Misc            | 0x1C          |

Override keys zeroed: `0x34`, `0x37`, `0x3A`, `0x3B`

## BNinja Renames Applied

- `GameData.dll`:
  - `RoleDataSingleton_LoadTransformIni`
  - `RoleDataSingleton_LookupTransformLookRecord`
- `Conquer.exe`:
  - `CRole__SetTransformLook`
  - `CRole__CreateRoleView`
  - `CRole__ReapplyAllVisualSources`
  - `CRole__ApplyAllVisualSourcesToRoleView`
  - `CRole__ApplyHelmetVariantSourcesToRoleView`
  - `CRole__ApplyBodyVariantSourcesToRoleView`
  - `CRole__ApplyLinkedSourceLookupIdToRoleView`
  - `CRole__ApplyHeadAttachmentSourceToRoleView`
  - `CRole__ApplyLeftWeaponSourcesToRoleView`
  - `CRole__ApplyMiscSourceToRoleView`
  - `CRole__ApplyMountSourceToRoleView`
  - `CRole__ApplyRightWeaponSourcesToRoleView`

## Verified separation: transform look vs normal visual-source reapply

`CRole__SetTransformLook` is not the generic equipment/body reapply path.

- verified property sequence:
  - key `3`
  - key `0x34`
  - key `5`
  - key `0x37`
  - key `6`
  - key `0x3B`
  - key `7`
  - key `0x3A`
  - key `9`
  - key `8`
- no key `4`
- no layered key families `0x27/0x2B`, `0x28/0x2C`, `0x35/0x36`, `0x38/0x39`,
  `0x3C/0x3D/0x3E`

The normal equipment/body refresh path instead comes from
`CRole__ApplyAllVisualSourcesToRoleView`:

1. helmet variant sources
2. body variant sources
3. linked source lookup id
4. head attachment source
5. left-weapon sources
6. misc source
7. mount source
8. right-weapon sources
