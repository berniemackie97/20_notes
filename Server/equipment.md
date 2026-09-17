# Equipment — equip and unequip over MsgTick (1009)

Verified 2026-08-29 against `Conquer.exe.bndb`. Every claim below is read from the binary; the two
places where the server deliberately departs from the client are labelled as such, and the one
client rule that is not reproduced is named with the exact missing evidence.

## The exchange

| Subtype | Direction | Built / applied at | Fields read |
|---|---|---|---|
| `4` | C→S | `CHeroItem__RequestEquipItemAtPosition` `0x6DB116`, send at `0x6DB493` | uid `+4`, position `+8` |
| `5` | S→C | `CMsgTick__Process` `0x6EB31C` | uid `+4`, position `+8`, count `+0x14`, uid list from `+0x54` |
| `6` | C→S | `CHeroItem__RequestUnequipPosition` `0x6DB8E9`, send at `0x6DBB5D` | uid and position |
| `6` | S→C | `CMsgTick__Process` `0x6EB118` | **position `+8` only** — the uid is ignored |

The equip request builder stamps `+16` with `(localHeroId ^ timeGetTime())`. The unequip request
passes the uid at that position (`Folded_GetDword_0x0C(item)`), but the apply branch never reads it.

## The position guard — jump table `0x6DB895`

`result = CItem_GetEquipmentCategory(item) - 1; if (result u> 0x14) → send`. **The index is
`category - 1`**, and categories outside `1..0x15` — including `-1`, "not equipment" — skip the guard
entirely and send anyway.

| Category | Allowed positions | Category | Allowed positions |
|---|---|---|---|
| 1 | `1` / `0x15` | 11 | `9` / `0x1D` |
| 2 | `2` / `0x16` | 12 | `0x0A` or `0x0B`, by `sub_67ADA4` |
| 3 | `3` / `0x17` | 13 | unrestricted |
| 4 | only `5` / `0x19` are checked | 14 | **forced** to `0x0C` (`0x6DB76D`) |
| 5 | `4` / `0x18` | 15 | `0x0F` or `0x10` |
| 6 | `5` / `0x19` | 16, 17 | `0x0F` |
| 7 | `6` / `0x1A` | 18 | `0x10` |
| 8 | `8` / `0x1C` | 19 | unrestricted |
| 9 | unrestricted | 20 | `0x11` |
| 10 | `7` / `0x1B` | 21 | `0x12` |

A position not listed falls to `0x6DB2C7` and is dropped silently, except where a branch raises a
message instead.

## Hand cross-checks

Only the hand branches read the other hand, and each reads the other hand *of the same set*.

- **Category 4 into `5` / `0x19`** (`0x6DB371`): the paired main hand must be occupied — a NULL item
  pointer is itself the refusal at `0x6DB391` / `0x6DB434` — and must hold a category 4 item, and
  `hero+0x82C` must satisfy `(prof % 1000) / 10 ∈ {1,5,6}` and `prof % 10 >= 2` (`0x6DB39D`).
  Message `0x186D1` otherwise. **Only this branch reads the profession.**
- **Category 5 into `4` / `0x18`** (`0x6DB51D`): refused with `STR_ERR_EQUIP_SHIELD_BOW` only when
  the paired off hand holds a category 6 item **and** the incoming item is
  `CItem__IsTwoHandedWeapon`. Nothing is displaced — the request is refused, not adjusted.
- **Category 6 into `5` / `0x19`** (`0x6DB605`): an empty main hand is fine. A category 5 main hand
  additionally requires the hero to have learned magic `0x2847` = 10311
  (`CRole__FindLearnedMagicByType`, `0x6DB654`, message `0x186D0`). Then, whatever its category,
  `STR_ERR_EQUIP_BOW_SHIELD` if it is `CItem__IsTwoHandedWeapon`.

`CItem__IsTwoHandedWeapon` (`0x462654`) is category 5 **and** sub-kind 0. Per `sub_67B0B3` that
sub-kind is `((type % 100000) / 1000) * 1000`, zero only for the `5x0000..5x0999` family — so the
name is misleading and the rule is bow-specific, which is what the two string ids say.

## Unequip guard

`0x6DB8E9`, in order: `Role_HasStatusFlag5`; `sub_674D64`; a Texas hold'em block
(`STR_TEXAS_INGAME_TIP_1`); a mount block when map predicate `sub_61F2E7` holds and the position is
`0x0C` (`STR_RIDE_MATCH_MSG_FORBID_UNEQ_MOUNT`); the paired-hand rule at `0x6DBA28` — **position 4
is refused while 5 is occupied, and `0x18` while `0x19` is** (`0x186D5`), and no other position is
cross-checked; an empty position is dropped silently; then the pack-space check.

### Pack capacity

`CHeroItem__CannotStoreItemInPack` (`0x6DCD96`) — **note the polarity: nonzero means it does not
fit**, and every caller tests for zero. A null item returns 1. The pack is the deque at
`hero+0xE34`; fewer than `0x28` = **40** entries returns 0. At 40 or more it walks the pack, adds
each stackable entry's remaining room (`sub_67D7D5(entry) - CItem_GetStackCount(entry)`), and
returns 0 only if that total covers the incoming item's stack count.

## What the applies do

**Equip apply, `0x6EB31C`.** Finds the item by uid at `+4` (nothing happens if unknown), removes it
from the pack list, then for each uid in the trailing list finds its current slot, clears that slot
and returns that item to the pack — then tracks the item at `+8`. Refreshes derived stats, posts
`0x3EB`/`0x3FB`/`0x445`/`0x446` (plus `0x4F6` for category `0x0C`), and sends MsgAction 10010
subtype `0x198`.

Two things a server depends on: **no automatic hand clearing on this branch**, and **the previous
occupant of the destination is not returned unless its uid is in the trailing list**.

**Unequip apply, `0x6EB118`.** Resolves the item from the position. When it is
`CItem__IsTwoHandedWeapon` and the position is `4` or `0x18`, it *also* clears the paired off hand
(`0x6EB172` computes 5 for 4, `0x19` for `0x18`) and returns that item to the pack unasked. The
client's own request path can never reach that branch, because it refuses to vacate a main hand
while the off hand is occupied; only a server applying an unequip the client would have refused
makes it reachable.

Both applies end by sending MsgAction 10010 subtype `0x198` = 408, and so do the equipment-set
switch paths in `sub_6DAEB9` (right after MsgTick subtype `0x2C` / `0x2D`) and the subtype 17 and 18
branches at `0x6EB099` / `0x6EB6F5`. Every one builds it with
`CMsgAction__BuildType10010(message, 0x198, 0)` — no fields.

**Corrected 2026-08-29**: 408 is *not* equipment-specific. `CMsgMapInfo1110__Process` sends it too
(`0x732D38`), after applying a new map, which makes seven senders. What they share is a
just-completed refresh of hero-visible state, so the action is modelled as `ClientStateApplied`.

**Nothing may be sent back under 408.** The constant `0x198` appears nowhere in
`CMsgAction__Process`'s disassembly: no compare, no `sub`-cascade total, and outside the
`0x80..0x9F` jump table. The client has no inbound branch for it and would discard one, so accepting
it silently is complete behaviour.

> Reading ids off that dispatcher's HLIL is unsafe: it mixes direct compares, `sub reg, imm / jz`
> cascades that HLIL folds away, and a jump table. Action 108 is dispatched by the cascade at
> `0x6FFC48` and shows up in no HLIL case label. Any id list taken from it must be built from the
> disassembly with the cascades accumulated.

## Refusals

There is no proven packet for a server to refuse a MsgTick with. The client raises its own message
for each case before it ever sends.

## What OpenConquerPublic does with this

- `ItemTypeFamily` / `EquipmentPositions` carry the arithmetic and the table.
- `EquipmentService` enforces every rule above, the magic-10311 gate included: it reads the
  character's learned magic through `IMagicRepository` (`cq_magic`), and only when a move actually
  depends on it. `cq_magic.unlearn` stays unmapped for the reason already recorded on `PlayerMagic`,
  so a row flagged that way counts as learned.
- **Server is stricter, deliberately, in two places.** An item with no equipment category is
  refused, and category 4 is confined to the four hand positions rather than the client's
  everything-but-`5`/`0x19`.
- The displaced list therefore holds at most the destination's occupant.
- An applied change re-broadcasts MsgPlayerSpawn (10014) to observers; `CMsgPlayerSpawn__Process`
  updates an existing entity in place through the `...AndRefreshRoleView` setters.
- Action 408 (`ClientStateApplied`) is a registered handler that deliberately does nothing, so it is
  accounted for rather than logged as an unimplemented subtype on every equip.

## Corrections made while verifying this

- An earlier comment at `0x6DB493` listed the category table **one category low** and attributed the
  profession check to categories 5 and 6 as well. Superseded at `0x6DB315`.
- The first implementation allowed an off-hand weapon over an **empty** main hand. The client treats
  an empty main hand as the refusal itself.
- The first implementation **displaced** a shield to make room for a bow. The client refuses that
  combination outright and displaces nothing.
- 10311 is checked **before** the bow conflict (`0x6DB66E` refuses first, and only a character that
  passes reaches `0x6DB6A1`), so a shield going under a bow reports the magic refusal, not the bow
  one, when the character lacks it.
