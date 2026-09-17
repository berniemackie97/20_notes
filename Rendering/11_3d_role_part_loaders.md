# Role-part bulk-copy loaders — `C3DArmor` / `C3DArmet` / `C3DMisc` / `C3DMount` / `C3DWeapon`

**Scope:** Managed port of the 5-loader family in 5517's GameRole.dll that
resolves a per-id `RolePartInfo` record and bulk-copies it into the part-slot.
Distinct from the head-record accumulator (`C3DHead_AddRecord`) which has a
different shape, and from `C3DMantle` which is fully removed in 5517.

Builds on note 10 (`C3DMount`). The four sister classes added here
share the loader semantics that note already covered.

## Retail oracles (`40_tools/fight-master/my_client/3DBaseCode/`)

Three sister classes shipped together in retail (header is 32 lines each, cpp
is 75 lines each):

| Retail class | Section name format | Ini file | Category enum |
|---|---|---|---|
| `C3DArmor` | `"Armor%09u"` | `ini/Armor.ini` | `ROLEPARTINFO_AEMOR` |
| `C3DArmet` | `"Armet%09u"` | `ini/Armet.ini` | `ROLEPARTINFO_ARMET` |
| `C3DMantle` | `"Mantle%010u"` | `ini/Mantle.ini` | `ROLEPARTINFO_MANTLE` |
| `C3DMount`  | `"Mount%u"` | `ini/Mount.ini` | `ROLEPARTINFO_MOUNT` |

Each class is a thin `C3DRolePart` subclass with a single `CreateNew(idType)`
factory and a `Create(idType)` loader that runs the same field-copy sequence:

```cpp
RolePartInfo* p = g_obj3DRoleData.GetRoleRartInfo(<category>, "<name>%fmt");
if (!p) ErrorOut("%s not found in %s!", szTitle, szIniFile);
m_infoPart.idMesh     = p->idMesh;
m_infoPart.idTexture  = p->idTexture;
m_infoPart.p3DMesh    = g_objGameDataSet.Get3DObj(p->idMesh);
m_infoPart.idTexture2 = p->idTexture2;
m_infoPart.fCurrentX  = 0.0f;
m_infoPart.fCurrentY  = 0.0f;
m_infoPart.fSpeedX    = p->fMoveRateX;
m_infoPart.fSpeedY    = p->fMoveRateY;
SetDefaultMotion();    // dropped in 3DArmor.cpp; present in Armet/Mantle/Mount
m_idType = idType;
return true;
```

## client-5517 surviving usage (`GameRole.dll`)

5517 evolution applies uniformly across the surviving loaders:
- name-keyed string lookup → numeric category-id lookup via
  `(*RoleDataQuery() + 8)(category, idType)`
- field-by-field copy → bulk `memcpy(arg1+0xb0, partInfo, 0x74)` (116 bytes)
- error string `"<Name>%fmt not found in %s!"` → bare `"[%u] not found in %s!"`
- `SetDefaultMotion()` call dropped; motion sourced from the visual-track configurator

Five loaders survive in 5517; one was removed:

| Function (BNinja-renamed) | Address | Category | Ini path | Status |
|---|---|---|---|---|
| `C3DWeapon_Create` | `0x100070e0` | 0 (Weapon) | `ini/Weapon.ini` | survives |
| `C3DArmet_Create`  | `0x10001120` | 1 (Armet)  | `ini/Armet.ini`  | survives |
| `C3DArmor_Create`  | `0x100012d0` | 2 (Armor)  | `ini/Armor.ini`  | survives |
| `C3DHead_AddRecord` | `0x10001360` | 3 (Head)  | `ini/Head.ini`   | different shape (multi-slot accumulator) |
| `C3DMount_Create`  | `0x10001720` | 4 (Mount)  | `ini/Mount.ini`  | survives — see note 10 |
| `C3DMisc_Create`   | `0x10001570` | 5 (Misc)   | `ini/Misc.ini`   | survives (no retail oracle — 5517 addition) |
| (removed)          | —            | —          | `ini/Mantle.ini` | absent — `Mantle` / `v_back` strings missing across all binaries |

The numeric category enum is verified at the call sites: `(*RoleDataQuery() + 8)(N, idType)`.

### Head-loader divergence

`C3DHead_AddRecord` (`0x10001360`) does NOT match the bulk-copy shape. It:
- Maintains a per-role array at `arg1+0xb4..+0xc4` (4 slots × 4 bytes each, two arrays)
- Tracks slot-state at `arg1+0x124`
- Copies only 8 bytes per record: `*(record+4)` and `*(record+0x14)` into the indexed slots
- Capacity gate `result s> 0 && result s< 4` (max 4 head records)

This is the head-attachment chain that builds up multiple head-bone records into a
container. Out of scope for the simple-loader managed port; flagged for a follow-up
slice that models the accumulator semantics.

## Managed port (`Conquer.Assets.RolePart`)

The 5 surviving loaders share an `internal static RolePartLoader.TryLoad`
helper, factored out so each public class is a thin record:

```csharp
public sealed class C3DArmor  { public const string ArmorIniPath  = "ini/Armor.ini";  ... }
public sealed class C3DArmet  { public const string ArmetIniPath  = "ini/Armet.ini";  ... }
public sealed class C3DMisc   { public const string MiscIniPath   = "ini/Misc.ini";   ... }
public sealed class C3DMount  { public const string MountIniPath  = "ini/Mount.ini";  ... }
public sealed class C3DWeapon { public const string WeaponIniPath = "ini/Weapon.ini"; ... }

internal static class RolePartLoader
{
    public static (uint TypeId, RolePartInfo PartInfo)? TryLoad(
        RolePartInfoCategory category,
        uint typeId,
        IRolePartInfoSource partInfoSource,
        IRolePartInfoErrorReporter? errorReporter,
        string iniPath);
}
```

Each class exposes a `static CreateNew(typeId, source, reporter?) -> Cls?`
factory matching the retail signature. The category enum is fixed per class
to prevent caller error.

### Invariants (tested)

26 tests in `RolePartLoaderTests.cs`:
- Theory across 5 categories: zero-id short-circuit returns `null` without consulting source / reporter.
- Theory across 5 categories: source miss returns `null` and reports `(typeId, iniPath)` exactly once.
- Source hit returns the loaded record verbatim.
- Each `C3D*` factory queries its own category exclusively (Armor, Armet, Misc, Weapon).
- All four garment factories short-circuit on `typeId == 0`.
- Source miss across all four reports the right `(typeId, iniPath)` per category.
- `RolePartInfoCategory` numeric values match the verified 5517 enum: Weapon=0, Armet=1, Armor=2, Head=3, Mount=4, Misc=5.
- `null` source argument throws `ArgumentNullException(paramName: "partInfoSource")`.
- `null` / empty `iniPath` argument throws `ArgumentException(paramName: "iniPath")`.

Plus 8 tests on `C3DMount` (note 10, unchanged).

Total Phase E test count: 34.

```
dotnet test tests/Conquer.Tests/Conquer.Tests.csproj \
  --filter "FullyQualifiedName~Conquer.Tests.Assets.RolePart" --nologo
```

### What this port does **not** cover

- `C3DHead` multi-slot accumulator (different shape, separate slice).
- `C3DMantle` — confirmed absent in 5517, no port needed. The retail-era cape /
  back-mantle subsystem was removed; `v_back` virtual-motion attachment string
  is also absent across all 5517 binaries.
- The 80-byte trailing payload in 5517's `0x74`-byte `RolePartInfo` — kept as
  `TrailingOpaqueBytes` until field-by-field decoding lands.
- `nType` / `p3DMesh` resolution chain — managed `Mesh3DHandle` modeled as
  `object?` until the C3DObj cache layer lands.

## Cross-refs

- **Retail source:** `40_tools/fight-master/my_client/3DBaseCode/3D{Armor,Armet,Mantle,Mount,RolePart}.{h,cpp}`
- **5517 native (BNinja-renamed + commented):**
  `GameRole.dll` — `C3DArmor_Create` (`0x100012d0`), `C3DArmet_Create` (`0x10001120`),
  `C3DMisc_Create` (`0x10001570`), `C3DMount_Create` (`0x10001720`),
  `C3DWeapon_Create` (`0x100070e0`); `C3DHead_AddRecord` (`0x10001360`, divergent)
- **Managed code:**
  - `10_work/src/Conquer.Assets/RolePart/RolePartLoader.cs` — shared bulk-copy helper
  - `10_work/src/Conquer.Assets/RolePart/C3DMount.cs` — enum + interfaces + `RolePartInfo` record + `C3DMount`
  - `10_work/src/Conquer.Assets/RolePart/C3DArmor.cs`
  - `10_work/src/Conquer.Assets/RolePart/C3DArmet.cs`
  - `10_work/src/Conquer.Assets/RolePart/C3DMisc.cs`
  - `10_work/src/Conquer.Assets/RolePart/C3DWeapon.cs`
- **Tests:**
  - `10_work/tests/Conquer.Tests/Assets/RolePart/C3DMountTests.cs` (8 tests)
  - `10_work/tests/Conquer.Tests/Assets/RolePart/RolePartLoaderTests.cs` (26 tests)
- **Adjacent slice (note 09):** `PlayerRoleViewWeaponSlotSetter` —
  the higher-level RoleView weapon-state machine that orchestrates Set{Right,Left}WeaponSource
  swapping. This slice is the leaf layer it consumes per part-id load.
- **Adjacent slice (note 10):** `C3DMount` retail / 5517 evolution detail.
