# `RoleView.dll` — Motion Lookup Key Construction (`GameDataSetQuery()->+0x20`)

The verified caller-side key construction `RoleView.dll` performs before querying `GraphicData.dll`.

For the action playback transition state (`+0xE0/+0xE4/+0xE8/+0xEC/+0xF4`) and blend formula used by the same dispatcher path, see:

- `analysis/conquer_docs/Rendering/roleview_dll/07_action_playback_transition_state.md`

## Import and call surface

- import slot: `GameDataSetQuery` at `0x10015018`
- runtime method used by `RoleView.dll`: vtable offset `+0x20`
- call shape observed repeatedly:
  - `GameDataSetQuery()->+0x20(partName, keyLow32, keyHigh32, 1, 0)`

`keyLow32`/`keyHigh32` are the low/high halves of a 64-bit composite motion lookup key.

## Deobfuscated `RoleView.dll` functions

The following functions were renamed in BNinja and verified in decompilation:

- `RoleView_ResolveMountMotionRequest` (`0x1000142F`)
- `RoleView_ResolveRightWeaponMotionRequest` (`0x100014B2`)
- `RoleView_ResolveHelmetMotionRequest` (`0x100016C6`)
- `RoleView_ResolveMiscMotionRequest` (`0x10001865`)
- `RoleView_UpdateRolePartMotionsForAction` (`0x10002DC8`)
- `PlayerRoleView_ConfigureRolePartActionEffects` (`0x10002549`)
- `RoleView_BuildBodyMotionLookupKey` (`0x10002D3E`)
- helpers:
  - `RoleView_ExtractMountEquipmentFamilyCode` (`0x100013C6`)
  - `RoleView_ExtractMountEquipmentSpecialFamilyCode` (`0x100013E1`)
  - `RoleView_ExtractMiscMotionFamilyCode` (`0x10001416`)
  - `RoleView_ComputeBodyMotionSubActionKey` (`0x1000124F`)

Important boundary note:

- `PlayerRoleView_ConfigureRolePartActionEffects` sits next to the action dispatcher, but it is
  not a motion-key builder.
- Verified `Role3D.dll` fan-out from this helper:
  - `I3DRole_RemovePartEffectInstanceByName(null, partName)` for body-family effect clearing,
  - `I3DRole_GetPartEffectProducer(partName)` to reach the embedded per-part effect producer,
  - `I3DRole_EnsurePartEffectInstanceByName(effectName, partName, 0)` for the named
    effect instance.
- Verified caller boundary:
  - the current local-hero/type-1 dispatcher calls this helper with primary `body` and
    primary `armet`, not with `mix_body` / `mix2_body` or `mix_armet` / `mix2_armet`
  - any layered visual-track fan-out beyond those direct calls is still unproven
- The final `PlayerRoleView_UpdateRolePartMotionsForAction` argument gates these calls:
  Conquer's action-dispatch path passes `1`, while ordinary render-tick calls pass `0`.
- Motion lookup key construction remains the responsibility of the resolver helpers listed
  above and the `GameDataSetQuery()->+0x20` calls documented below.

## Dispatcher call-site argument sourcing (`RoleView_UpdateRolePartMotionsForAction`)

This is the verified source-of-truth call site for runtime part-motion lookup requests.

### Common action key flow

- `actionId` is dispatcher arg2 (`[ebp+0x8]`).
- `subActionKey` is computed at each misc/helmet call site via:
  - `RoleView_ComputeBodyMotionSubActionKey(this)`.
- Stack flow is cdecl-compatible in this path:
  - push `actionId`,
  - call `RoleView_ComputeBodyMotionSubActionKey`,
  - push returned `subActionKey`,
  - push part-specific source id,
  - call resolver which consumes three args (`retn 0xC`).
  - the pre-pushed `actionId` is consumed by the resolver call, not by `RoleView_ComputeBodyMotionSubActionKey` itself.

Rewrite integration rule (parity-safe):

- helmet/misc request DTOs must carry `leftWeaponSourceId` and `rightWeaponSourceId`,
- the resolver-side key builder computes `subActionKey` internally from those two fields,
- callers do not pass a synthetic precomputed sub-action value.

### Verified source-offset table (all part-motion request paths)

| RoleView offset | Field | Dispatcher path |
|---:|---|---|
| `+0xA8` | `m_idArmor[_PART_ORG]` (body appearance source id) | body/misc/helmet/right-weapon/left-weapon key construction |
| `+0x44` | `m_idMount` | body special mount family branch, mount resolver, misc/helmet/weapon key construction |
| `+0x48` | `m_idMisc` | misc resolver source id (`"misc"`) |
| `+0x30` | helmet variant source 0 | helmet resolver + part `"armet"` |
| `+0x34` | helmet variant source 1 | helmet resolver + part `"mix_armet"` |
| `+0x38` | helmet variant source 2 | helmet resolver + part `"mix2_armet"` |
| `+0x40` | `m_idWeaponRightSource` | right-weapon resolver source id (`"r_weapon"`) |
| `+0x94` | `m_idWeaponRightOverrideSource` | right-weapon RoleData/SoulPart override lookup id |
| `+0x3C` | `m_idWeaponLeftSource` | left-weapon resolver source id (`"l_weapon"`) |
| `+0x90` | `m_idWeaponLeftOverrideSource` | left-weapon RoleData/SoulPart override lookup id |

### Misc request sourcing

At `0x1000312F..0x1000313D`:

- part name written to renderer: `"misc"`.
- resolver call:
  - `RoleView_ResolveMiscMotionRequest(this, this->m_idMisc, subActionKey, actionId)`.
- field source:
  - `this->m_idMisc` at offset `+0x48`.

### Helmet request sourcing

At `0x100031AC..0x100031D7`:

- loop over 3 helmet variant slots:
  - source ids at `this + 0x30`, `this + 0x34`, `this + 0x38`.
- parallel part-name table:
  - `{ "armet", "mix_armet", "mix2_armet" }`
  - pointer table label in BNinja: `RoleView_RolePartNameTable_HelmetVariants` (`0x1001704C`).
- per-variant resolver call:
  - `RoleView_ResolveHelmetMotionRequest(this, helmetVariantSourceId, subActionKey, actionId)`.

### Weapon request sourcing

Right weapon path (`0x10003206..0x10003223`):

- part name written to renderer: `"r_weapon"`.
- resolver call:
  - `RoleView_ResolveRightWeaponMotionRequest(this, this->m_idWeaponRightSource, this->m_idWeaponRightOverrideSource, actionId)`.
- field sources:
  - `this->m_idWeaponRightSource` at `+0x40`.
  - `this->m_idWeaponRightOverrideSource` at `+0x94`.

Left weapon path (`0x1000324A..0x10003269`):

- part name written to renderer: `"l_weapon"`.
- resolver call:
  - `RoleView_ResolveRightWeaponMotionRequest(this, this->m_idWeaponLeftSource, this->m_idWeaponLeftOverrideSource, actionId)`.
- field sources:
  - `this->m_idWeaponLeftSource` at `+0x3C`.
  - `this->m_idWeaponLeftOverrideSource` at `+0x90`.

## `RoleView_ComputeBodyMotionSubActionKey` parity formula (fully pinned)

Source fields used by the helper:

- `leftWeaponSourceId = this->+0x3C`
- `rightWeaponSourceId = this->+0x40`

All arithmetic uses unsigned integer division/modulo in native code.

1. `leftActionClass = (leftWeaponSourceId / 1000) % 1000`
2. `fallbackWeapon = (leftActionClass == 0x1F4 || leftActionClass == 0x172) ? leftWeaponSourceId : rightWeaponSourceId`
3. `preferredWeapon = ((rightWeaponSourceId / 10000) == 0x69) ? rightWeaponSourceId : leftWeaponSourceId`
4. early exits:
   - if `fallbackWeapon == 0`:
     - return `preferredWeapon == 0 ? 0 : 0x2BC`
   - if `preferredWeapon == 0`:
     - return `(fallbackWeapon % 1000000) / 1000`
5. class buckets from `% 1000000 / 1000`:
   - if either preferred/fallback bucket equals `0x259`, return `0x2A0`
   - if either preferred/fallback bucket equals `0x262`, return `0x2A1`
6. `preferredHundredK = (preferredWeapon % 1000000) / 100000`
   - if `preferredHundredK == 9` or `leftActionClass == 0x17C`:
     - return `(fallbackWeapon % 1000000) / 10000 + 0x2BC`
7. if `preferredHundredK == 4` or preferred bucket is `0x168`:
   - return `(preferredWeapon % 100000) / 10000 + (((fallbackWeapon % 100000) / 10000) + 0x3C) * 10`
8. final fallback:
   - if `(fallbackWeapon / 1000) == 0x1F4`, return `0x1F4`
   - if `(fallbackWeapon / 1000) == 0x172`, return `0x172`
   - otherwise return `0`

## Body key formula (fully pinned)

From `RoleView_BuildBodyMotionLookupKey` (`0x10002D3E`):

1. mount bucket:
   - if `actionId == 0x2C9`:
     - `mountBucket = RoleView_ExtractMountEquipmentSpecialFamilyCode(this)`
     - `= ((this+0x44) / 10000) % 100 + ((this+0x44) % 100) * 100`
   - else:
     - `mountBucket = RoleView_ExtractMountEquipmentFamilyCode(this)`
     - `= ((this+0x44) / 10000) % 100`
2. sub-action key:
   - `subAction = RoleView_ComputeBodyMotionSubActionKey(this)`
3. composite:
   - `composite = ((bodyAppearanceSourceId + mountBucket * 1000) * 10000000) + (subAction * 10000) + actionId`
   - where `bodyAppearanceSourceId = this+0xA8`
4. query call shape in dispatcher:
   - `GameDataSetQuery()->+0x20("body", low32(composite), high32(composite), 1, 0)`

Rewrite mapping (implemented from this evidence):

- `10_work/src/Conquer.Assets/Resolution/RolePart/RoleViewBodyMotionLookupKeyBuilder.cs`
- mount-bucket helpers in:
  - `10_work/src/Conquer.Assets/Resolution/RolePart/RoleViewEquipmentBucketExtractors.cs`
- runtime action->motion tracker resolution (body/misc/mount/helmet/right-weapon/left-weapon):
  - `10_work/src/Conquer/Client/RoleViewBodyActionMotionTrackerResolver.cs`
  - `10_work/src/Conquer/Client/RoleViewActionMotionTrackerSet.cs`
  - `10_work/src/Conquer/Client/RoleViewBodyMotionLookupContext.cs`
  - `10_work/src/Conquer/Client/RoleViewBodyMotionLookupContextResolver.cs`
  - includes native fallback query key `bodyAppearanceSourceId * 10000000 + actionId` when primary key misses.

### Live movement-dispatch integration correction

The per-role command tick must resolve its returned motion frame count from the same live RoleView
part state as rendering. `PlayerRoleView_SetBodyAppearanceSource` (`0x10001EB8`) asserts that its
input is greater than zero and less than `1000`, then stores it at `PlayerRoleView+0xA8` at
`0x10001EF3`. `PlayerRoleView_UpdateRolePartMotionsForAction` reads that field in both its primary
body key and its fallback `bodyAppearanceSourceId * 10000000 + actionId` key at
`0x10002EF6..0x10002F0C`.

Therefore the packed network `AppearanceCompositeId` is not a valid substitute for `+0xA8`.
For example, a packed appearance of `1002` produces the body source `2`; using `1002` as the body
source makes the verified clean-client ground-motion lookup fail and returns zero frames. The
managed `RoleViewMotionDispatch` now consumes `ClientWorldRoleViewSceneObjectStore` and rebuilds
its lookup context through `PlayerRoleViewMotionLookupContextResolver`, exactly as the render-time
playback path does. A clean-5517 asset test locks action `0x6E` to a positive body-motion frame count
through that shared state.

## Mount key formula (fully pinned)

From `RoleView_ResolveMountMotionRequest`:

1. `family = (mountModelId / 10000) % 1000`
2. special branch when `actionId == 0x2C9`:
   - `family += (mountModelId % 100) * 1000`
3. `composite = family * 10000000 + actionId`
4. query:
   - `partName = "mount"`
   - `primary = low32(composite)`
   - `secondary = high32(composite)`

Known live key already used in rewrite tests:

- `primary = 0x2FBE4A41`
- `secondary = 0`
- resolves `"c3/Mount/801/101.C3"` through `ini/mountmotion.dbc`

## Weapon formula and fallback order (fully pinned)

From `RoleView_ResolveRightWeaponMotionRequest`:

1. effective weapon source:
   - `weaponSource = arg2`
   - if `arg3 != 0`: `weaponSource = RoleDataQuery()->+0x14(arg3)` where
     `+0x14` resolves through `GameData.dll::RoleDataSingleton_ResolveWeaponSourceFromSoulPart`.
2. buckets:
   - `mountFamily = RoleView_ExtractMountEquipmentFamilyCode(this)` (`(this+0x44)/10000 % 100`)
   - `weaponResidue = weaponSource % 10000000`
   - `bodyBucket = (this+0xA8) % 1000`
3. base composite without action:
   - `base = ((mountFamily * 10000000 + weaponResidue) * 10000000) + bodyBucket * 10000`
4. probe order (identical for right and left weapon paths):
   - probe 1: `base + actionId` (`actionId = arg4`)
   - probe 2: `base + 9999`
   - probe 3: `base + (999 - ((base / 10000) % 1000)) * 10000 + actionId`
   - probe 4: `(base / 10000000) * 10000000 + 9999999`
   - probe 5: `base + (999 - ((base / 10000) % 10000)) * 10000 + actionId`

Query part name differs by caller path:

- right-hand path: `"r_weapon"`.
- left-hand path: `"l_weapon"`.

Both paths probe in the exact same 5-key order above until one succeeds.

## Role-data override source resolution (`RoleDataQuery()->+0x14`) (fully pinned)

Verified in `GameData.dll`:

- `RoleDataQuery` (`0x10001000`) returns the singleton object.
- singleton vtable `+0x14` method:
  - `RoleDataSingleton_ResolveWeaponSourceFromSoulPart` (`0x10002495`).
- source map loader:
  - `RoleDataSingleton_LoadSoulPartIni` (`0x100022ED`).

`RoleDataSingleton_LoadSoulPartIni` behavior:

- opens `ini/SoulPart.ini` from client root (must exist in native path),
- reads line-by-line and applies `sscanf("%u=%u", &lookupId, &resolvedWeaponSource)`,
- inserts/updates mapping `lookupId -> resolvedWeaponSource`,
- ignores non-matching lines.

`RoleDataSingleton_ResolveWeaponSourceFromSoulPart(lookupId)` behavior:

- returns mapped weapon source on hit,
- returns `0` on miss.

Parity consequence for `RoleView_ResolveRightWeaponMotionRequest`:

- when `arg3 == 0`: keep `arg2` as weapon source,
- when `arg3 != 0`: replace weapon source with role-data mapping result (including `0` on miss; no fallback to `arg2`).

Rewrite contract implemented from this evidence:

- `Conquer.Assets.Resolution.RoleViewWeaponSourceOverrideResolver.ResolveEffectiveWeaponSource(...)`
  applies the exact override semantics above.
- `GraphicDataAssetResolver.Open*` now loads typed `ini/SoulPart.ini` into `SoulPartIni`.
- `GraphicDataAssetResolver.ResolveRoleViewEffectiveWeaponSource(...)` is the public parity API for this path.
- right/left weapon builders expose runtime request overloads that accept `SoulPartIniTable` and compute
  the effective weapon source before probe construction.

## Helmet formula and fallback order (fully pinned)

From `RoleView_ResolveHelmetMotionRequest`:

1. buckets:
   - `mountFamily = RoleView_ExtractMountEquipmentFamilyCode(this)` (`(this+0x44)/10000 % 100`)
   - `helmetFamily = arg2 % 100`
   - `bodyBucket = (this+0xA8) % 1000`
   - `actionFamily = (arg3 / 1000) % 1000`
2. base composite without action:
   - `base = (((mountFamily * 100 + helmetFamily) * 1000 + bodyBucket) * 10000000) + actionFamily * 10000`
3. probe order (`partName = "armet"`):
   - probe 1: `base + actionId` (`actionId = arg4`)
   - probe 2: `base + 9999`
   - probe 3: `base + (999 - ((base / 10000) % 1000)) * 10000 + actionId`
   - probe 4: `(base / 10000000) * 10000000 + 9999999`

All probes call `GameDataSetQuery()->+0x20("armet", low32, high32, 1, 0)`.

## Misc formula and fallback order (fully pinned)

From `RoleView_ResolveMiscMotionRequest`:

1. buckets:
   - `mountFamily = RoleView_ExtractMountEquipmentFamilyCode(this)` (`(this+0x44)/10000 % 100`)
   - `miscFamily = RoleView_ExtractMiscMotionFamilyCode(this)`:
     - `0` when `(this+0x48) == 0`
     - otherwise `((this+0x48) / 10) % 100`
   - `bodyBucket = (this+0xA8) % 1000`
   - `actionFamily = (arg2 / 1000) % 1000`
2. base composite without action:
   - `base = (((mountFamily * 100 + miscFamily) * 1000 + bodyBucket) * 10000000) + actionFamily * 10000`
3. probe order (`partName = "misc"`):
   - probe 1: `base + actionId` (`actionId = arg3`)
   - probe 2: `base + 9999`
   - probe 3: `base + (999 - ((base / 10000) % 1000)) * 10000 + actionId`
   - probe 4: `(base / 10000000) * 10000000 + 9999999`

All probes call `GameDataSetQuery()->+0x20("misc", low32, high32, 1, 0)`.

## Clean 5517 data availability note (verified in rewrite E2E)

From the current clean-client root (`00_clean/clean/5517`):

- `ini/armetmotion.dbc` parses as an empty dual-key table (`0` records).
- `ini/miscmotion.dbc` parses as an empty dual-key table (`0` records).
- `ini/r_weaponmotion.dbc` and `ini/l_weaponmotion.dbc` contain records, but no decoded
  `weaponSource` bucket currently intersects values mapped from `ini/SoulPart.ini`.

So runtime `armet`/`misc` key-construction parity is pinned from binary call-site RE, but table-backed payload resolution in this specific clean dataset is expected to miss for `armet`/`misc`, and SoulPart-override request paths are also expected to miss against current `r_weapon`/`l_weapon` tables.
