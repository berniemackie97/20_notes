# Slice 14 — Action-id translation state machine

**Binary:** `Conquer.exe`
**Function:** `Role_UpdateActionAndDispatchRoleViewMotion` at `0x64e2dd`
**Role in pipeline:** Called by command/state update paths and by the stale-Vortex-latch
recovery path in `Role_TickAndRender` Phase 3 (slice 13). The function independently
honors the Shuriken Vortex action override at `CRole+0x60`; on its regular path, it
translates the base action id at `CRole+0x1A4` based on jump status, current action type,
and mount state before dispatching it to the RoleView via vtable slot `+0x0C`.

## Stage 1 — Jumping action remap (status flag `0x1b`)

When `Role_HasStatusFlag(role, 0x1b) != 0` (jumping/flying), the function remaps the
current action id to its in-air variant. Verified address range: `0x64e301..0x64e3e3`.

### Specific remaps

| Source action (hex) | Source action (dec) | Target      | Target (dec) | Quarter speed |
|---------------------|---------------------|-------------|--------------|---------------|
| `0x64`              | 100 (idle)          | `0x1F5`     | 501          | No            |
| `0x6E`              | 110 (walk)          | `0x1FE`     | 510          | **Yes**       |
| `0x6F`              | 111 (run)           | `0x1FE`     | 510          | **Yes**       |
| `0x73`              | 115 (walk variant)  | `0x1FE`     | 510          | **Yes**       |
| `0x78`              | 120 (run variant A) | `0x1FE`     | 510          | **Yes**       |
| `0x79`              | 121 (run variant B) | `0x1FE`     | 510          | **Yes**       |
| `0x82`              | 130 (attack)        | `0x1FE`     | 510          | No            |
| `0x12C`             | 300                 | `0x1F6`     | 502          | No            |
| `0x140`             | 320 (ranged)        | `0x230`     | 560          | No            |
| `0x191..0x194`      | 401..404 (mounted)  | `0x208`     | 520          | No            |
| Everything else     | —                   | `0x1F5`     | 501          | No            |

### Recognized jumping action ids (pass-through set)

Actions already in this set are NOT remapped when jumping:
`{0x1F5, 0x1F6, 0x1FE, 0x208, 0x212, 0x21C, 0x226, 0x230, 0x387, 0x14B}`

### Quarter-speed flag

When `var_c = 1` is set (walk/run actions remapping to `0x1FE`), the frame interval
gets quartered at `0x64e7f4`: `role+0x1B8 >>= 2`. This makes the in-air walking
animation play at 4× speed (fewer milliseconds per frame).

## Stage 2 — Paired-interaction override (`Role_GetActionType`)

Checked at `0x64e3f5`. `CRole+0xD8` is the current action type (`m_Info.iActType` in
the original-source terminology retained in the binary). Two paired-interaction action
types activate this translation stage:

### Hold hands (action type `0x186A4` = 100004)

| Source       | Target (default)            | Target (alternate when `CRole+0x398 == default`) |
|--------------|-----------------------------|---------------------------------------------------|
| `0x6E/0x6F`  | `0x124` (HoldHandsWalkB)    | `0x123` (HoldHandsWalkA)                          |
| `0x78/0x79`  | `0x126` (HoldHandsRunB)     | `0x125` (HoldHandsRunA)                           |
| `0x82`       | `0x127` (HoldHandsAttack)   | -                                                 |

### Hug walk / Love Stroll (action type `0x186A7` = 100007)

| Source       | Target (default)          | Target (alternate)   |
|--------------|---------------------------|----------------------|
| `0x6E/0x6F`  | `0x20C` (HugWalkWalkB)    | `0x20B` (HugWalkWalkA) |
| `0x78/0x79`  | `0x20E` (HugWalkRunB)     | `0x20D` (HugWalkRunA) |
| `0x82`       | `0x20F` (HugWalkAttack)   | -                    |

The alternation pattern (`CRole+0x398` comparison) implements left/right foot alternation
for paired walk/run cycles: each dispatch alternates between the A and B variants so the
walk animation does not repeat the same foot.

After translation, the paired-interaction path also pushes selector resets via RoleView vtable:
- `vtable+0x04(7, 0)` — clear selector 7
- `vtable+0x04(0x3A, 0)` — clear selector 58
- `vtable+0x04(6, 0)` — clear selector 6
- `vtable+0x04(0x3B, 0)` — clear selector 59

## Stage 3 — Frame interval + jitter computation

After action-id translation, the function:
1. `CGameMap_IsTileWithinScaledScreenBoundsWithMargin` — checks visibility (margin 4).
2. Dispatches to RoleView vtable `+0x0C` with the translated action id → returns frame count.
3. Stores frame count to `CRole+0x1AC`.
4. `Role_ComputeFrameIntervalFromAction` → stores to `CRole+0x1B8`.
5. Optional: if the role has a duration cap (`CRole+0x1FC > 0`), clamps frame count to
   `CRole+0x1FC / CRole+0x1B8`.
6. Optional: random start frame via `Conquer_GetRandomModulo(frameCount, 0)` → `CRole+0x1B0`.
7. Writes `CRole+0x398 = CRole+0x1A4` (snapshot previous pose action for next-frame alternation).

### Role_ComputeFrameIntervalFromAction (0x64de1b)

The frame interval computation is multi-factor:
- Base: `RoleDataQuery->vtable+0x08(compositeKey)` where `compositeKey` combines:
  - `CRole+0x128` * 1,000,000 (a per-role speed modifier, likely agility-derived)
  - `role_class * 10000` (derived from `zx.d(CRole+0xD0) * 0x33`)
  - The source action id itself
- Status modifiers:
  - Flag `0x15` or `0x12` → multiply by 2/3
  - Flag `0x17` → multiply by 2/3
  - Flag `0x70` → multiply by 2/3
  - Flag `0x1b` + state `0x1f` → halve
  - Flag `0x32` (mounted) → `Role_ApplyMountedSpeedClassScaleToFrameInterval` (per-speed-class scaling)
- `CRole+0x5C != 0` → additional scaling by speed percent: `result * 100 / (CRole+0x5C + 100)`
- Special: action `0x2C9` (mount) → additional per-class mount-speed ratio from lookup tables
  at `0x86AA64` and `0x86AA98`.

## Verified helper functions

| Function                                           | Purpose                                     |
|----------------------------------------------------|---------------------------------------------|
| `Role_IsCurrentActionInPhysicalAnimationSet`       | Returns 1 for body-animating action ids     |
| `CGameMap_HasOverlayRenderModeFlag`                | Checks `CGameMap+0xe8 & 0x400000`           |
| `Role_ApplyMountedSpeedClassScaleToFrameInterval`  | Mounted speed-class scaling                 |

## Managed parity

The verified jumping remap and paired-interaction override tables are encoded in:
- `src/Conquer.Graphics/Role/RoleActionIdTranslator.cs`
  - `TranslateForJumpingStatus(sourceActionId, out quarterSpeedPlayback)`
  - `TranslateForPairedInteraction(sourceActionId, currentActionType, previousPoseActionId, out translated)`
  - `IsRecognizedJumpingActionId(actionId)`
- `tests/Conquer.Tests/Client/RoleActionIdTranslatorTests.cs`

The translator is called in `Role3DClientRolePlayback.Tick` between action selection and
dispatch. `RoleActionIdTranslationState` provides `HasJumpingStatus` and
`CurrentActionType`; previous-pose tracking for paired-animation leg alternation is maintained
internally.
Quarter-speed playback flag shifts the frame interval right by 2 (4x speed) in
`ConfigurePrimaryFrameClock`.

## Current action type investigation (`CRole+0xD8`)

**Writer/reader functions:**
- `Role_SetActionType` at `0x64DDD9` writes the 32-bit `CRole+0xD8` field.
- `Role_GetActionType` at `0x64DDE6` reads the field.

All 13 setter call sites are traced. Twelve belong to paired-interaction controllers and
write constants; `CMsgPlayerSpawn__Process` supplies the remaining dynamic packet value.

| Action type | Dec    | Constant writers | Verified semantic |
|-------------|--------|------------------|-------------------|
| `0x64`      | 100    | 4                | `_ACTION_STANDBY`; interaction stop/reset |
| `0x186A4`   | 100004 | 3                | Hold hands; activates `0x123..0x127` translation |
| `0x186A7`   | 100007 | 4                | Hug walk / Love Stroll; activates `0x20B..0x20F` translation |
| `0x186AA`   | 100010 | 1                | Double dance; does not activate this translation stage |

The named constant-writing methods are:
- `HoldHandsInteraction_StopRoleAction`
- `HoldHandsInteraction_ApplyRoleAction209`
- `HoldHandsInteraction_ApplyCounterpartAction20A`
- `HugWalkInteraction_StopRoleAction`
- `HugWalkInteraction_ApplyRoleAction128`
- `HugWalkInteraction_ApplyCounterpartAction128`
- `DoubleDanceInteraction_StopRoleAction`
- `DoubleDanceInteraction_ApplyRoleAction`
- `DoubleDanceInteraction_ApplyCounterpartAction`
- `InteractionType100008_ApplyRoleAction`
- `InteractionType100009_ApplyRoleAction`

`Role_ResolveEffectiveCommandTypeAndDetectWeaponRefresh` (`0x64E231`) uses the same
action type when resolving command types `0x11..0x18`:
```
if (CRole+0x1E8 >= 0x11 && CRole+0x1E8 <= 0x18):
    actionType = Role_GetActionType(role)
    if (actionType == 100004 || actionType == 100007):
        result = 0x19
    else:
        result = CRole+0x1E8
```

`CRole+0x388` and `CRole+0x38C` are separate paired-interaction state fields.
`Role_SetInteractionActionState` writes the interaction type and interaction action ID;
`Role_GetInteractionActionId` returns `CRole+0x38C`. They must not be conflated with
the current action type at `CRole+0xD8`.

**Spawn packet:** `CMsgPlayerSpawn__Process` at `0x756604..0x75660A` reads a dword from
`frame+0x5B` and calls `Role_SetActionType`. Because the native frame includes the 4-byte
packet header, this is body offset `0x57` (87), and the field is 32 bits rather than a byte.

## Mutual-interaction command type `0x19`

`Role_CommandType19_SelectMutualInteractionAction` (`0x737246`) is the command-state
selector used by the interaction controllers. It reads command data from command-block
offset `+0x3C` (`CRole+0x224`), not payload-action offset `+0x40`.

At progress `0`, command data becomes the selected action. Actions
`{0x128, 0x1F8, 0x203, 0x210, 0x27B, 0x27E, 0x281}` complete immediately; all others
advance to progress `2`.

At progress `2`, the exact transitions are:

| Current action | Selected action | New progress |
|----------------|-----------------|--------------|
| `0x12..0x15` | unchanged | `5` |
| `0x1F9` | `0x1F7` | `5` |
| `0x204` | `0x202` | `5` |
| `0x279` | `0x27A` | `5` |
| `0x27C` | `0x27D` | `5` |
| `0x27F` | `0x280` | `5` |
| `0x1F7`, `0x202`, `0x27A`, `0x27D`, `0x280` | unchanged | `5` |
| `0x20A` | `0x209` | `6` |
| Any other action | unchanged | `6` |

Before returning, the native selector restores role direction from command-block offset
`+0x28` (`CRole+0x210`) and synchronizes position fields from `CRole+0x350/+0x354`.

**Managed wiring:** `MsgPlayerSpawn10014PacketReader` reads the current action type dword
at body offset 87, and `ClientWorldRoleStateStore` retains it in
`ClientWorldRoleStateSnapshot.CurrentActionType`. `MsgInteract1022PacketReader` and
`RoleCommandStateMsgInteractIngress` now reproduce the verified local-source subtype
`49`/`50` command lifecycle, including controller command data, direction, current-action
type changes, the controllerless `100006` no-op, and the type-`5` fallback reset.
`RoleCommandStateActionSelection.CommandType19` implements the selector table above.

Subtype `47` pending-state setup, subtype `48` controller state, interaction card UI,
controller event dispatch, and independent remote-role command-state ticking remain separate
native subsystems and are not claimed as completed managed parity.
