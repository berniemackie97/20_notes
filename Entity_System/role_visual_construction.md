# Role Visual Construction — Post-MsgUserInfo1006

## Source
- `CMsgUserInfo__Process` (`Conquer.exe:0x764276`)
- Verified from decompilation of full function body

## Overview

When `MsgUserInfo1006` (packet type 1006) is received for the local hero, the native client
performs the following ordered visual construction sequence. This is the primary path that
produces the first on-screen player character after login or character creation.

## Packet Field Decomposition

| Packet Offset | Width | Native Usage                                     |
|--------------:|------:|:-------------------------------------------------|
| +0x04         | u32   | EntityId → `hero+0xCC`                           |
| +0x08         | u16   | `AppearanceRefreshSourceId` → `CRole__SetTransformLookSourceId` |
| +0x0A         | u32   | `AppearanceCompositeId` — decomposed as below    |
| +0x0E         | u16   | `HairCompositeId` — decomposed as below          |
| +0x34..+0x3E  | misc  | Stats (silver, health, mana, etc.)               |
| +0x44         | u16   | Experience-related                               |
| strings       | list  | [0]=PlayerName, [1]=SecondaryName, [2]=SpouseName |

### AppearanceCompositeId Decomposition

```
bodyAppearanceSourceId = AppearanceCompositeId % 1000
meshTransformId        = (AppearanceCompositeId / 10000) % 1000
transformFlag          = (AppearanceCompositeId / 1000) % 10
```

### HairCompositeId Decomposition

```
hairStyle = HairCompositeId % 1000
hairColor = HairCompositeId / 1000
```

Verified native consumers:

- `hairStyle` feeds `CRole__SetLinkedSourceLookupId` (`0x64DB3C`)
  - stores `role+0xD2`
  - with `refresh=1`, tail-calls `CRole__RefreshLinkedSourceLookupIdToRoleView` (`0x64DB57`)
  - the apply helper zeroes styles where `hairStyle % 100 == 0` before dispatching RoleView key `1`
- `hairColor` feeds `CRole__SetHeadAttachmentSource` (`0x64DC01`)
  - stores `role+0xD4`
  - with `refresh=1`, tail-calls `CRole__RefreshAllVisualSourcesToRoleView` (`0x64DC1C`)
  - the reapply chain then dispatches RoleView key `2`

## Visual Construction Sequence (Verified Order)

### 1. Name Setup
```
CRole__SetName(hero, playerName)           // 0x6E5292
CRole__SetSpouseName(hero, spouseName)     // 0x6728DC
```

### 2. Identity Assignment
```
hero+0xCC = packet.EntityId
```

### 3. Body Construction
```
CRole__CreateRoleView(hero, bodyAppearanceSourceId, type=1)    // 0x64D51F
```
- Releases any existing RoleView at `hero+0x3B4`
- Calls `RoleViewCreate(1)` → allocates the player RoleView
- `roleView.SetProperty(0, bodyAppearanceSourceId)` → set body source

Fresh player-RoleView body-appearance load requests verified from `PlayerRoleView_SetBodyAppearanceSource`
(`RoleView.dll:0x10001EB8`) and `PlayerRoleView_LoadPartSourceIntoI3DRole`
(`RoleView.dll:0x10003381`):

| Part | Attachment visual track | Attachment part | Source id |
|---|---|---|---:|
| `body` | `v_mount` | `mount` | `bodyAppearanceSourceId * 1_000_000` |
| `mix_body` | `v_mount` | `mount` | `bodyAppearanceSourceId * 1_000_000` |
| `mix2_body` | `v_mount` | `mount` | `bodyAppearanceSourceId * 1_000_000` |

For the live bootstrap currently under test, `bodyAppearanceSourceId=2`, so the initial
player RoleView load requests are:
- `body -> 2_000_000`
- `mix_body -> 2_000_000`
- `mix2_body -> 2_000_000`

Clean 5517 asset verification for that exact startup case:
- `body/2_000_000` resolves from the role-part tables
- `mix_body/2_000_000` resolves from the role-part tables
- `mix2_body/2_000_000` does not resolve from the clean role-part tables even though RoleView emits the request

### 4. Mesh Transform Seed Application
```
CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform(hero, meshTransformId, 0)  // 0x6E64A0
hero+0x178 = transformFlag                                                            // direct store
```

Verified behavior of `CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform`:

- stores the raw `meshTransformId` at `role+0x148`
- when `refreshMode == 0`, resolves an entity-record override through the role/entity table using
  `role+0xCC`
- writes the final effective mesh-transform value to `role+0x358`

This is a distinct startup phase from the later tile-projection path. `role+0x358` is therefore
not a pure projected-screen field across the whole lifecycle.

### 5. Transform Look Expansion (RoleDataQuery +0x28)
```
CRole__SetTransformLookSourceId(hero, AppearanceRefreshSourceId, 1)  // 0x650B1F
```
This triggers `CRole__SetTransformLook` which:
- Looks up `TransformLookRecord` via `RoleDataQuery()->vtable+0x28(refreshSourceId)`
- On hit, applies record fields to RoleView keys 3, 5, 6, 7, 8, 9
- Zeroes override keys 0x34, 0x37, 0x3A, 0x3B
- Writes `role+0x174 = record.AddSize`
- Writes `role+0x184 = record.Scale`

Fresh-role defaults verified in `CRole__Init` (`0x64D260`) before this stage:

```
role+0x174 = 0
role+0x184 = 100
role+0x188 = 1.0f
```

So for a bootstrap hero whose `AppearanceRefreshSourceId` does not resolve in `Transform.ini`,
the verified baseline render-scale state remains:

```
transformLookAddSize = 0
bodyScale = 100
actionScaleMultiplier = 1.0f
```

Live startup asset verification for `AppearanceRefreshSourceId=2`:
- `ini/TransForm.ini` has no section `[2]`
- therefore the local-hero bootstrap currently under test does not receive transform-look expansion from key `3/5/6/7/8/9`
- the first verified startup property-load contract for that hero is the fresh body-variant trio above

Verified refresh boundary:

- `CRole__SetTransformLookSourceId` only stores `AppearanceRefreshSourceId` at `role+0xDC`
- when `refresh=1`, it immediately calls `CRole__ReapplyAllVisualSources`
- `CRole__ReapplyAllVisualSources` does:
  1. `CRole__ApplyAllVisualSourcesToRoleView(role, roleView)`
  2. `Role_UpdateMountActionScaleCacheFromRoleState(role)`

So the native `MsgUserInfo1006` startup path already reaches the RoleView visual-source
reapply boundary. The still-missing startup-local-hero parity is therefore not explained by a
missing post-`1006` visual refresh call.

### 6. Hair Setup
```
CRole__SetLinkedSourceLookupId(hero, hairStyle, 1)     // 0x64DB3C
CRole__SetHeadAttachmentSource(hero, hairColor, 1)     // 0x64DC01
```

Verified semantic mapping:

- `hairStyle` is not a direct mesh-source id; it is the linked-source lookup id consumed by
  RoleView key `1`
- `hairColor` is not a tint-only field in this path; it is the head-attachment source consumed
  by RoleView key `2`
- because the second setter refreshes the full visual-source chain, the fresh local-hero
  startup path applies:
  1. helmet variant sources
  2. body variant sources
  3. linked source lookup id
  4. head attachment source
  5. left weapon
  6. misc
  7. mount
  8. right weapon

For a fresh player RoleView, the currently representable managed subset is the linked
source lookup id (`key 1`) primary `armet` load:

```
if (hairStyle % 100 != 0)
    armetSourceId = bodyAppearanceSourceId * 1_000_000 + hairStyle + 0x1D0D8
```

The head-attachment source (`key 2`) is a separate `"body" -> "head"` attachment path.
The managed renderer mirrors it as a supplemental resolved-record group attached to the existing
`body` slot, so the startup visual plan now carries:

```
body -> head : hairColor
```

and the body render path/motion interface consume those attached head records under the same
body slot instead of inventing a fake standalone top-level `head` slot.

### Role-side layered variant caches refreshed by the same startup path

The same normal visual-source reapply chain triggered during startup also refreshes the
role-side helmet / body / left-weapon lookup caches.

Verified cache writers:

- `CRole__ApplyHelmetVariantSourcesToRoleView` (`0x6E57A6`)
  - input cluster: `role+0x140`, `role+0x130`, `role+0xF0`
  - key tables:
    - `0x86B720` -> `{ 5, 0x27, 0x2B }`
    - `0x86B72C` -> `{ 0x37, 0x38, 0x39 }`
    - `0x86B738` -> `{ 0x0E, 0x2A, 0x2E }`
  - output caches: `role+0x104`, `role+0x108`, `role+0x10C`
  - `role+0xF0` is the helmet texture-variant selector used during the `ItemTexture.ini`
    lookup; it is not a generic lookup seed
- `CRole__ApplyBodyVariantSourcesToRoleView` (`0x6E60D7`)
  - input cluster: `role+0x11C`, `role+0x134`, `role+0xF4`, `role+0x144`
  - key table:
    - `0x86B750` -> `{ 0x3C, 0x3D, 0x3E }`
  - primary output cache: `role+0x110`
  - `role+0xF4` is the body texture-variant selector used during the same lookup path
- `CRole__ApplyLeftWeaponSourcesToRoleView` (`0x6E5CB7`)
  - input cluster: `role+0x124`, `role+0x138`, `role+0xF8`, `role+0xE4`
  - dispatches RoleView keys `0x3A` and `7`
  - when `source != 0`, `override == 0`, and the effective weapon family class is `6`,
    it queries RoleView key `0x0D`, resolves through the `ItemType.dat` singleton rooted at
    `0x96AE88`, and writes the left-weapon lookup cache at `role+0x114`
  - `role+0xF8` is the left-weapon texture-variant selector

Verified render-time consumer:

- `CRole__ApplyCachedHelmetBodyAndLeftWeaponLookupIdsToRoleView` (`0x6E56D0`)
  - pushes `role+0x104`, `role+0x108`, `role+0x10C` to RoleView selectors `'#'`, `')'`, `'-'`
  - pushes `role+0x110` to selector `0x24`
  - pushes `role+0x114` to selector `0x25`

The current managed startup plan mirrors the verified source-family writes and the
`"body" -> "head"` attachment path. The managed runtime now also mirrors the currently
representable primary texture/material cache subset from the native `ItemTexture.ini`
lookup path:

- primary helmet texture/material source id
- primary body texture/material source id
- left-weapon texture/material source id

Native does not query that table by generic item type id: it uses the stored RoleView source
id as the section key and one of the role-side variant-selector fields
(`role+0xF0/+0xF4/+0xF8`) as the `ColorN` selector. The remaining unported part of this seam
was the downstream player-RoleView texture/material rebinding consumer plus the layered helmet source
families that would populate `role+0x108/+0x10C`.

Current managed status:

- the runtime now consumes the verified primary cached item-texture results for:
  - primary helmet (`role+0x104`)
  - primary body (`role+0x110`)
  - left weapon (`role+0x114`)
- the render path applies those cached ids as primary texture-resource overrides on the
  corresponding already-loaded player RoleView parts
- layered helmet cache slots (`role+0x108/+0x10C`) are now representable in state and pass
  through the same draw-boundary hook when nonzero, but the current startup player path
  still leaves them at zero until the layered source-family inputs are carried into runtime state
- the remaining native gap on this seam is:
  - property case `0x26`
  - secondary texture rebinding
  - stored material reapply at the OpenGL draw boundary

Verified `CMsgPlayerSpawn__Process` packet feed into this same cluster:

- `packet+0x28` (`PrimaryHelmetSourceId`) feeds `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView`
- `packet+0x2C` (`SharedBodyHelmetVariantLookupSourceId`) feeds
  `CRole__SetSharedBodyHelmetVariantLookupSourceAndRefreshRoleView`
- `packet+0x30` (`PrimaryBodyVariantSourceId`) feeds
  `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView`
- `packet+0x34` (`LeftWeaponSourceId`) feeds `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView`
- `packet+0x38` (`RightWeaponSourceId`) feeds `CRole__SetRightWeaponVisualInputsAndRefreshRoleView`
- `packet+0x3C` (`ExtraLeftWeaponOverrideLookupId`) feeds
  `CRole__SetExtraLeftWeaponOverrideLookupIdAndRefreshRoleView`
- `packet+0x40` (`ExtraRightWeaponOverrideLookupId`) feeds
  `CRole__SetExtraRightWeaponOverrideLookupIdAndRefreshRoleView`
- `packet+0x44`, `packet+0x48`, `packet+0x85`, `packet+0x8B` feed the mounted action-scale cache refresh through
  `Role_UpdateMountActionScaleCacheFromSources`
- `packet+190` (`LeftHandVisualItemQueryId`) feeds the left-weapon override input at `role+0x138`
- `packet+194` (`RightHandVisualItemQueryId`) feeds the right-weapon override input at `role+0x13C`

- `HeadwearVisualItemQueryId` (`packet+0xB6`, offset `182`) is validated and stored through
  `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView`, feeding `role+0x130`
- `ArmorVisualItemQueryId` (`packet+0xBA`, offset `186`) is validated and stored through
  `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView`, feeding `role+0x134`
- when `CRole__SetTransformLook` runs, it explicitly zeros those RoleView override inputs
  (`0x34`, `0x37`, `0x3A`, `0x3B`), so the managed rewrite must clear the primary helmet/body
  override lookup ids whenever a verified transform-look record is active

Verified local-hero equipment feed into this same cluster:

- `CHeroItem__SetEquipSlot` (`0x6DA906`) is the native local-hero writer for the primary
  helmet/body/left-weapon selector fields
- slot `1` calls `CRole__SetPrimaryHelmetVariantInputsAndRefreshRoleView` with:
  - stored source id = `item+0x1C`, else `0`
  - override lookup id = `CItem__TryGetRoleViewOverrideLookupId(item)`, else `0`
  - texture-variant selector = `CItem__GetRoleViewTextureVariantSelector(item)`, else `3`
- slot `3` calls `CRole__SetPrimaryBodyVariantInputsAndRefreshRoleView` with:
  - stored source id = `item+0x1C`, else `0`
  - override lookup id = `CItem__TryGetRoleViewOverrideLookupId(item)`, else `0`
  - texture-variant selector = `CItem__GetRoleViewTextureVariantSelector(item)`, else `3`
- slot `5` calls `CRole__SetLeftWeaponVisualInputsAndRefreshRoleView` with:
  - stored source id = `item+0x1C`, else `0`
  - override lookup id = `CItem__TryGetRoleViewOverrideLookupId(item)`, else `0`
  - texture-variant selector = `CItem__GetRoleViewTextureVariantSelector(item)`, else `3`

### 7. Post-Visual Refresh
```
CRole__RefreshVisuals(hero)                // 0x65ED40
```

### 8. EnterMap Action (auto-sent)
```
CMsgAction__Create(entityId, 0, 0, 0, actionEnterMap=0x4A)
CNetMsg__Send(msg)
```

## Later Composite-Appearance Mutation Consumers

The startup seed above is not the only native consumer of the packed appearance fields.
The same family is re-consumed later by verified runtime update handlers:

- `CMsgUserAttribEx__Process` (`0x757374`), attribute id `11`
  - re-decomposes the incoming 64-bit composite
  - updates mesh transform id through
    `CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform`
  - stores `transformFlag` at `role+0x178`
  - updates body appearance through `CRole__SetBodyAppearanceSourceId`
  - may call `CRole__SetTransformLook` when the transform-look component is nonzero
- `CMsgAction__Process` (`0x6FED2F`), action type `0x97`
  - updates the target entity mesh-transform id through
    `CRole__SetMeshTransformIdAndResolveEffectiveMeshTransform`

These are verified runtime mutation paths, not the initial local-hero bootstrap path.

## Verified local-hero spawn boundary

`CMsgPlayerSpawn__Process` explicitly ignores packets whose `entity_id == CHero+0xCC`.
The handler logs `"Got a player with hero id! %u"` and returns before constructing or refreshing
another local entity, before `EntityRef_ResolveByIdOrLocalHero`, and before any tile, direction,
appearance, or RoleView writes from that packet are applied.

Therefore the startup local-hero visual seed must come from `MsgUserInfo1006` and its follow-up
packets, not from the local-hero copy of `MsgPlayerSpawn10014`.

## For New Characters (AppearanceRefreshSourceId == 0)

When `AppearanceRefreshSourceId` is 0, `CRole__SetTransformLook` exits early (Phase 2 skipped).
The RoleView uses only the body appearance source from `AppearanceCompositeId % 1000` and
the default hair. No equipment overrides are applied.

## Managed Parity Requirements

The managed rewrite must:
1. Parse `ini/Transform.ini` into a lookup table (keyed by refreshSourceId)
2. After `ApplyUserInfo`, construct a visual state that captures:
   - `bodyAppearanceSourceId`
   - `meshTransformId` and `transformFlag` from composite decomposition
   - Transform record lookup result (if `AppearanceRefreshSourceId != 0`)
   - `transformLookAddSize` and `bodyScale`
3. Produce a `RoleViewPartSourceState` with all resolved equipment sources
4. Preserve the raw startup-local-hero mesh-transform seed in scene-object state even when no managed
   consumer exists yet:
   - `meshTransformId = (AppearanceCompositeId / 10000) % 1000`
   - `transformFlag = (AppearanceCompositeId / 1000) % 10`
5. The managed runtime now also derives the fresh player-RoleView body-variant load requests from that source id
6. The managed runtime now preserves the transform-driven misc source (`RoleView` key `9`) in scene-object state
7. The managed runtime should use the verified baseline scale formula
   `bodyScale * 0.75f * 0.01f` until the action-driven `role+0x188` update path is carried into runtime state
8. The remaining missing piece is the actual `I3DRole` part consumer / render path that would turn those
   resolved load requests into visible meshes on screen

## BNinja Renames Applied

See `../Rendering/roleview_dll/08_transform_look_record.md` for full rename list.
