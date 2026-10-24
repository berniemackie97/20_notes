# Movement and jump — native contract

Server side: `50_server/OpenConquerPublic` — `MovementHandler`, `JumpActionHandler`.

## Both are server-authoritative

The client's authoritative **gate** tile changes only when the server sends the packet back; there is no reject
code. Corrected 2026-10-15: the step/jump is still **animated locally** on send and the CRole tile used for the next
request and for report 100 takes the animation's end point, so an unanswered refusal leaves the client visually at
the target until subtype 108 — see [movement eligibility](movement-eligibility-5517.md#local-animation-vs-authoritative-tile--correction-to-movementmd).

## Movement — MsgEntityAction (10005)

Wire layout verified against `CMsgEntityAction_CreateWithMoveTickAndMapState` (`0x740457`) and
`CMsgEntityAction__Process` (`0x7405E7`):

```
+0  u16 size (24)      +12 u32 command selector
+2  u16 type (10005)   +16 u32 movement tick
+4  u32 packed direction
+8  u32 entity id      +20 u32 current map-state value
```

Inbound handling (`0x7405E7`):

- Selector dword compared to exactly `9` → 24-direction table; anything else → 8-direction. Only the
  low byte of the packed direction is normalised.
- Delta tables: 8-dir at `0x86C7C4`/`0x86C7E4`, 24-dir at `0x86C804`/`0x86C864`.
- Entity resolved by id at `+8`. **If it is the local hero**:
  `CHero_ProcessMovementAcknowledgementTimestamp(pkt+0x10)` then
  `Role_UpdateCoordinateGateAndMapFromTilePair(current + delta)`.
- Unresolvable non-hero entity → client sends MsgAction subtype `0x66` querying the player.

**The delta is relative to the client's current tile**, so the acknowledgement is the request echoed
verbatim. Echoing a modified position would double-apply.

## Jump — MsgAction (10010) subtype 0x89 / 137

Branch `0x700352..0x7003DE`. Target is **absolute**, packed as two u16 in the dword at `+8`: low
word X, high word Y. The local-hero branch updates the coordinate gate straight from that pair.

Native gates, in order (`Role_RequestJumpToTile`, `0x658965`):

| Gate      | Address                | Rule                                                                                           |
| --------- | ---------------------- | ---------------------------------------------------------------------------------------------- |
| Distance  | `0x658BDE`, `0x658BF0` | `> 0` and `<= 0x10` (16 tiles)                                                                 |
| Map flag  | `0x658C6C`             | `CGameMap_GetFlags64 & 0x2000000` forbids jumping                                              |
| Mount cap | `0x658D31`             | with status flag `0x32`, also `<= Role_GetField2DA8StatusValue` = current vigor (`MOUNT_JUMP_MOVEPOINT_LIMIT`) |

Over-range emits string `0x186C0`; map-forbidden emits `STR_RIDE_MATCH_MSG_FORBID_JUMP`.

## Tile distance metric

`Map_CalculateRoundedTileDistanceByAdjustmentMode` (`0x61E5F0`). Mode 1 applies no source
adjustment, so it reduces to:

```
squared = dx*dx + dy*dy
low     = floor(sqrt(squared))
return (high² - low²) <= 2 * (squared - low²) ? low + 1 : low
```

which is **Euclidean rounded half-up** — `round(sqrt(dx² + dy²))`. Ported as
`OpenConquer.Domain.World.MapDistance.RoundedTileDistance`.

Not Chebyshev, and not a truncated square root. Either would disagree with the client exactly at the
range boundary that matters.

Mode 2 and mode 3 apply a direction-based source adjustment before measuring (tables at
`0x869EAC`/`0x869ECC`); neither is used by the jump gate and neither is ported.

## Passability

Base grid: **zero passable, nonzero blocked**. Verified at `0x657EB4`, where the native gate accepts
a tile only when `MapTileEntry_GetTailLinkPassabilityFlag != 1`, and the getter returns `1` when the
tile has no entry — so a missing tile is blocked.

`MapTileEntry_GetTailLinkNode` (`0x61EAEE`) walks the link list and **returns the tile entry itself
when there are no links**. So on any tile without an overlay, tail passability _is_ base
passability, and a base-only check matches the client exactly there.

## Known gaps

- **Overlay collision is not implemented.** Overlay link nodes are built by
  `CMapSceneryComponent_AttachTerrainObjectGroupToTileGrid` (`0x635FC5`), which sets `node+2` from
  `GetPerCellMetadataAt` on a `CMapType3SubcomponentType01ExternalObject`. That metadata lives in
  the external `.scene` / `.pul` / `.Part` assets, not the DMap. A tile blocked only by an overlay
  is currently accepted and the client will disagree.
- **Jump map flag and mount cap are not enforced** — the server loads neither map flags nor mount
  state. Full gate list, statuses, vigor and peak elevation: [movement-eligibility-5517.md](movement-eligibility-5517.md).
- ~~No broadcast of movement to other players~~ — implemented 2026-08-28; see
  [entity-visibility.md](entity-visibility.md).

## Movement timing challenge (anti-speedhack, server-initiated)

Verified 2026-10-14, Binja. Inert unless the server starts it.

| Step | Fact |
|---|---|
| S→C MsgAction `0xCD` | `CMsgAction__Process` `0x6FF06E`: replies `0xCD` with `timeGetTime`, then `CHero_SendMovementTimingChallenge` (`0x661BDA`): sends `0xCE`, pending (`hero+0x2CFD`) |
| S→C MsgAction `0xCE` | `0x6FF05F` → `CHero_CompleteMovementTimingChallenge` (`0x661C73`): baseline local/peer tick from packet `+0x10`, armed (`hero+0x2CFC=1`) |
| Each walk/jump echo | `CHero_ProcessMovementAcknowledgementTimestamp` (`0x661CC5`): unarmed or pending ⇒ accept. Armed: `now < baseline` ⇒ 1st time resend `0xCE`, later report reason 13 + **reject echo**; else accept iff `now − tick ≥ offset − 8000` |

Walk tick (`10005 +0x10`) = client `timeGetTime()` (`0x65C6AE`). Step period is RoleData-driven per action and scaled
by statuses (×2/3, ×½, speed %): [action translation](../Rendering/roleview_dll/12_action_id_translation_state_machine.md).
TQ 15.10 server walk/jump rules: [runtime semantics](tq-server-15.10-runtime-semantics.md#movement-visibility-kickback).
