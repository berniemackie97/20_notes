# `PlayerRoleView_Set{Right,Left}WeaponSource` — weapon slot setter pair

**Scope:** The two RoleView.dll setter entry points that accept a packed
weapon-source id and route it to the correct hand slot, applying 5517's
"family-500/370 left-flip" predicate plus the composite-id/105 cross-slot
swap. Mirrors the pair end-to-end as a managed `PlayerRoleViewWeaponSlotSetter`.

## 5517 oracle (`RoleView.dll`, BNinja decomp)

### `PlayerRoleView_SetRightWeaponSource(arg1, edi)` at `0x10001af1`

```
edi   = arg2
temp1 = (edi / 1000) % 1000        // 3-digit family class

// Branch A — left-flip predicate.
if (temp1 == 0x1f4 || temp1 == 0x172) {        // 500 OR 370 (5517 added 370)
    if (RightFamily / 0x2710 != 0x69)           // skip removePart when stored
        I3DRole.removePart("r_weapon")          //   right is composite-id/105
    RightFamily = 0
    LeftQuery, RightQuery = RightQuery, 0       // swap query slots
    return SetLeftWeaponSource(arg1, edi)       // recurse left
}

// Branch B — composite-id/105 incoming on right while left is 500.
if ((edi / 0x2710) == 0x69
    && (LeftFamily / 0x3e8) % 0x3e8 == 0x1f4) {
    SetLeftWeaponSource(arg1, 0)                // pre-clear 500-family left
}

// Branch C — standard right load.
edi = edi % 0xf4240                             // clamp to 6 digits
I3DRole.removePart("r_weapon")
RightFamily = 0
if (edi != 0
    && LoadPartSourceIntoI3DRole(arg1, "r_weapon", "v_r_weapon", "body", edi, RightQuery)) {
    RightFamily = edi
    return TRUE
}
return FALSE
```

### `PlayerRoleView_SetLeftWeaponSource(arg1, arg2)` at `0x10001a21`

```
// Branch A — composite-id/105 swap (mirror of the right-side 500/370 flip).
if ((arg2 / 0x2710) == 0x69
    && (LeftFamily / 0x3e8) % 0x3e8 != 0x1f4) {
    I3DRole.removePart("l_weapon")
    LeftFamily = 0
    LeftQuery, RightQuery = 0, LeftQuery        // swap query slots
    return SetRightWeaponSource(arg1, arg2)
}

// Branch B — standard left load (arg2 != 0 OR right is not composite-id/105).
if (arg2 != 0 || (RightFamily / 0x2710) != 0x69) {
    temp1_3 = arg2 % 0xf4240
    I3DRole.removePart("l_weapon")
    LeftFamily = 0
    if (temp1_3 != 0
        && LoadPartSourceIntoI3DRole(arg1, "l_weapon", "v_l_weapon", "body", temp1_3, LeftQuery)) {
        LeftFamily = temp1_3
        return TRUE
    }
    return FALSE
}

// Branch C — clearing left while right holds a composite-id/105 weapon.
// Composite-id/105 weapons live "logically on the left" but are stored in the
// right slot. Clearing left therefore clears the right backing.
I3DRole.removePart("r_weapon")
RightFamily &= arg2                             // arg2 == 0 here, so RightFamily = 0
return TRUE
```

### Native state-slot map

| Offset | Field | Managed mirror |
|---:|---|---|
| `+0x3c` | `m_uLeftFamily` (stored left source family) | `PlayerRoleViewWeaponSlotSetter.LeftFamily` |
| `+0x40` | `m_uRightFamily` (stored right source family) | `PlayerRoleViewWeaponSlotSetter.RightFamily` |
| `+0x90` | `m_uLeftQuery` (left-slot query/override id) | `PlayerRoleViewWeaponSlotSetter.LeftQuery` |
| `+0x94` | `m_uRightQuery` (right-slot query/override id) | `PlayerRoleViewWeaponSlotSetter.RightQuery` |
| `+0xd8` | `I3DRole*` pointer; vtbl `+0x20` removes part by name | `RemovePlayerRoleViewWeaponAttachedPartRuntime` delegate |

`LoadPartSourceIntoI3DRole(roleView, partName, attachmentVisualTrack, attachmentPart, sourceId, queryId)`
returns the native non-zero success flag → managed `bool` from
`TryLoadPlayerRoleViewWeaponPartRuntime`.

## 5517 evolution from retail

The retail oracle (`40_tools/fight-master/my_client/3DBaseCode/PlayerRoleView.cpp`)
checked only family-500. 5517 evolved the predicate in two directions:

1. **Family 370 added to the left-flip predicate.** New polearm/pole-weapon
   family treated as left-handed for animation purposes. Same code path as 500.
2. **Composite-id/105 cross-slot swap added on both setters.** Composite ids in
   the `1_05x_xxx` range (105 thousand-bucket) live logically on the left but
   are stored in the right slot. The pair of setters maintain that invariant
   via the swap branches.

Neither evolution survives in retail. The managed port captures both verbatim
so the equipped-weapon state machine in 5517 reproduces exactly.

## Managed port (`Conquer.Role`)

```csharp
internal sealed class PlayerRoleViewWeaponSlotSetter
{
    public PlayerRoleViewWeaponSlotSetter(
        RemovePlayerRoleViewWeaponAttachedPartRuntime removeAttachedPart,
        TryLoadPlayerRoleViewWeaponPartRuntime tryLoadAttachedPart);

    public uint LeftFamily  { get; internal set; }   // RoleView+0x3c
    public uint RightFamily { get; internal set; }   // RoleView+0x40
    public uint LeftQuery   { get; set; }            // RoleView+0x90
    public uint RightQuery  { get; set; }            // RoleView+0x94

    public bool SetRightWeaponSource(uint newRightSourceId);
    public bool SetLeftWeaponSource(uint newLeftSourceId);
}
```

### Truth table (asserted in tests)

| Setter | Input pattern | Effect |
|---|---|---|
| Right | normal weapon (family ≠ 500/370, not 105 compositeId) | remove `r_weapon` → load `r_weapon` → store right family |
| Right | family 500 | swap query slots → tail-call SetLeftWeaponSource |
| Right | family 370 | swap query slots → tail-call SetLeftWeaponSource (5517-only) |
| Right | family 500 AND `RightFamily/10000 == 105` | skip redundant `r_weapon` remove, still swap+recurse |
| Right | `edi/10000 == 105` AND `LeftFamily%1000 == 500` | pre-call SetLeftWeaponSource(0), then standard right load |
| Right | source clamped to `% 1_000_000` | only effective 6 digits load |
| Right | source 0 | remove `r_weapon`, no load, return false |
| Right | load fails | reset right family to 0, return false |
| Left | normal weapon (not composite-id/105) | remove `l_weapon` → load `l_weapon` → store left family |
| Left | `arg2/10000 == 105` AND `LeftFamily%1000 != 500` | swap left→right query → tail-call SetRightWeaponSource |
| Left | `arg2/10000 == 105` AND `LeftFamily%1000 == 500` | fall through to standard left load (no swap) |
| Left | `arg2 == 0` AND `RightFamily/10000 != 105` | remove `l_weapon`, no load, return false |
| Left | `arg2 == 0` AND `RightFamily/10000 == 105` | remove `r_weapon`, clear right family, return true (cross-slot clear) |
| Left | load fails | reset left family to 0, return false |

15 tests, all green via:

```
dotnet test tests/Conquer.Tests/Conquer.Tests.csproj \
  --filter "FullyQualifiedName~PlayerRoleViewWeaponSlotSetterTests" --nologo
```

## Where this fits in the broader port

This setter pair was previously a documented gap in the managed port: the
existing `PlayerRoleViewStartupVisualLoadPlanResolver` only modeled the
*startup* path (initial load from a fully resolved part-source state) and did
not implement the runtime swap predicate that fires when equipment changes
mid-session. The setter port closes that gap.

Wiring the setter into the managed RoleView equipment-change pipeline (so a
gear swap on a live character routes through it) is a follow-up integration
slice — the setter as it stands is a pure unit, ready to compose.

## Cross-refs

- **Native source:** `RoleView.dll` `PlayerRoleView_SetRightWeaponSource` (`0x10001af1`),
  `PlayerRoleView_SetLeftWeaponSource` (`0x10001a21`),
  `PlayerRoleView_LoadPartSourceIntoI3DRole` (BNinja-renamed loader)
- **Managed code:** `10_work/src/Conquer/Role/Appearance/Configuration/PlayerRoleViewWeaponSlotSetter.cs`
- **Tests:** `10_work/tests/Conquer.Tests/Client/PlayerRoleViewWeaponSlotSetterTests.cs` (15 tests)
- **BNinja parity comments:** set on both function symbols, link back to the managed file + this note
- **Adjacent managed:** `10_work/src/Conquer/Role/Appearance/Resolution/PlayerRoleViewMotionLookupContextResolver.cs`
  (consumes weapon source ids without the swap), `10_work/src/Conquer/Role/Appearance/Loading/PlayerRoleViewStartupVisualLoadPlanResolver.cs`
  (startup load plan, also without swap)
