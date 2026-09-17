# Entity visibility — who each client is told about

Verified against `Conquer.exe` 5517 on 2026-08-28. Everything below is read out of the client;
where this server makes a choice the client does not force, that is called out as a choice.

## The client's own visibility rule is a square of 18 tiles

`Map_IsTilePairOutsideVisibilityRange` (`0x61ED75`) is the whole function:

```c
return !(abs(heroX - entityX) <= 0x12 && abs(heroY - entityY) <= 0x12);
```

So entity visibility is **Chebyshev, 18 per axis**. It is *not* the rounded Euclidean distance
(`Map_CalculateRoundedTileDistanceByAdjustmentMode`, `0x61E5F0`) that gates the jump check, and the
difference is not cosmetic: the corner of the square is 25 tiles away by that measure.

## The client culls out-of-range entities by itself, every frame

Six call sites reach the predicate (xrefs to `0x61ED63`). Four are map/scenery culls —
`CGameMap_ClearTransientSceneryQueuesAndCullDistantType17Objects` (`0x61D3AB`), `sub_61f89e`
(`0x61F90A`), `sub_632e3f` (`0x632EDA`), `sub_63377d` (`0x63380E`). The remaining two are the
entity cull's own two loops, `EntityContainer_CullEntitiesOutsideVisibilityRange` (`0x6E9243`) at
`0x6E92F6` and `0x6E9418`. Only that one removes roles.

That cull has exactly two callers (xrefs to `0x6E9243`):

1. `Role_UpdateCoordinateGateAndMapFromTilePair` (`0x65CB1D`) — the hero's tile update.
2. `CHero_TickNearbyEntityPrioritySelectionAndSound` (`0x6E94D4`), which
   **`CMyShellDlg_RunFrameTick` calls every frame** at `0x5DD0A0`, passing the hero tile pair read
   from the XTEA-protected ints at `CHero+0xCEC`/`+0xD08` (`sub_6ea1aa`). Nothing gates that block
   on hero movement, and the device-lost flag at `[ebp-4]` does not skip it.

So the sweep is continuous, not movement-driven. It exempts roles tagged `CRole+0x368 == 0x1C`
(pets, written by `CMsgPetSpawn__Process`) and entity id `0xEE6B2801`, and requires both hero
coordinates to be positive.

Consequences for a server:

- An interest radius above `0x12` is self-defeating. The client discards the extra characters on
  its next frame while the server still counts them visible.
- At `0x12` exactly, a departure needs **no packet**: server and client drop the pair on the same
  condition from the same numbers.
- Below `0x12`, the server stops tracking a pair the client still holds, so a departure does need
  an explicit removal.
- Leaving the world *inside* the square — disconnect, map change — is invisible to a sweep that
  only tests distance, so that always needs an explicit removal.

An earlier revision of this note claimed the sweep only ran on the hero's own step, and concluded a
departure removal was always required. That was wrong: it was written from a single caller found in
`chero_class.md` rather than from the xref list.

## The three packets

| Direction | Packet | Verified at |
|---|---|---|
| S→C | MsgPlayerSpawn (`10014`) | `0x755F64` — materialises another entity; a self-spawn is discarded by the id guard at `0x755F8A` |
| S→C | MsgAction (`10010`) subtype `0x87` (135) | `0x70051A` — reads only the entity id at `+4`, then `EntityManager_RemoveEntityById(&g_objPlayerSet, id, 1)` at `0x7005AC` |
| S→C | MsgEntityAction (`10005`) relayed verbatim | `0x7407B4` — the remote branch applies the same direction delta to the named entity that the local branch applies to the hero |
| C→S | MsgAction subtype `0x66` (102) | `0x740730` — the client asks for an entity a movement packet named that it cannot resolve |

Subtype `0x87` is safe to send for an entity the client has already culled: the branch resolves the
id first and falls through to its epilogue when nothing resolves. That is a safety property, not a
reason to send it — see the cull section for when it is actually needed.

## What this server does

`OpenConquer.GameServer/World/Visibility`:

- `MapVisibilityIndex` — one per map. A uniform grid whose cell side is the visibility radius
  answers "who is near this tile" from nine cells, and a per-character set records who that
  character has actually been sent.
- The recorded set, not the geometry, drives packets. Re-deriving "newly visible" from distance on
  each side of a pair lets two characters moving at once both conclude the other is new (two
  spawns) or both conclude it is not (none). Membership changes happen once, under the map's lock,
  for both sides of every pair.
- Sends happen after the lock is released; the lock only ever covers index arithmetic.
- `WorldVisibilityService` — enter, move, leave, and the answer to action `0x66`. A character that
  has just come into view is sent only the spawn, never the spawn *and* the relayed move: the spawn
  already carries the destination tile.
- `WorldVisibilityOptions.TileRadius` is validated against `0x12` as a hard ceiling for the reason
  above. It defaults to `18`.
- A departure sends a removal **only when the configured radius is below `0x12`**. At the client's
  own radius the frame sweep has already done it. `LeaveAsync` always sends, at any radius.

Movement and jump both route through the same transition, because a jump of up to 16 tiles crosses
most of a screen.

## Deliberately not done

- **A spawn is placed at the destination tile, not at the screen edge.** A character that walks or
  jumps into view therefore appears where it now is rather than animating in from the boundary. The
  usual community fix walks a Bresenham line from the origin and spawns at the first tile inside the
  radius before relaying the jump. That is a presentation refinement with no correctness
  consequence, and it is not implemented.
- **No syndicate rank in the spawn.** `+0x10` is sent as zero. The client's life-scaling arm keys
  off exactly `990` and `1000`, so a rank that is not modelled must not be approximated.
- **Only players are spawned.** NPCs, monsters and ground items are separate packets and separate
  world state.
- **Map change is implemented** for the client's own `actionChgMap` request; see
  [map-transitions.md](map-transitions.md). Nothing else moves a character between maps yet.
