# Map transitions

Verified against `Conquer.exe` 5517 on 2026-08-28.

## The client asks; it does not decide

`CHero_TickPortalDetectionAndMapChangeRequest` (`0x65D9B2`) runs on the hero tick. It offsets the
hero's tile by each of the nine entries in the −1..1 table at `0x65DC6A` and asks
`sub_61D9FF` whether that tile is an exit; that resolves through
`CGameMap_FindFirstComponentWithTypeCode1` to `sub_637700`, a walk of the deque at
`component+0x420C` holding `{x, y, passwayIndex}` triples, returning `-1` when the tile is not one.

On a hit it sends **MsgAction subtype `0x55` (85)**. The build names the packet itself, in the
assert beside the send at `0x65DD3B`:

```
msg.Create(this->GetID(), posHero.x, posHero.y, this->GetDir(), actionChgMap, posTest.x, posTest.y, 0, 0)
                                            F:\CQ2ClientRelease-42.0.1\3DRole\Hero.cpp:0x1552
```

So the candidate tile travels in the parameter pair — low word x, high word y — while the packet's
own X/Y carry the hero's tile and the direction its facing. **It sends no index.** The server has to
resolve the tile itself.

Immediately after sending, the client puts itself into UI mode `0x3F0` (`0x65DE0E`) — the loading
screen. The map burst is what ends it.

Gates before any of this: `Role_HasStatusFlag5`, `Role_HasStatusFlag10`, state code `0x1EC == 6`,
and a current action id in `{0x64, 0x65, 0x66, 0x67, 0x69, 0x1F5, 0x1F6}` or `0x12C`.

**The older subtype table calling 85 "Walk" is wrong.** Walking is packet 10005.

## Where the exit list comes from

The DMap carries it, immediately after the terrain grid.
`CGameMap_LoadMapFileFromRelativePath` (`0x61DC3D`) reads, in order: two header dwords, the `0x104`
puzzle path, width and height, the cell grid with a checksum per row, then
`CMapGroundEntityLayer_LoadExitMarkersFromMapReader` (`0x63777D`), then the scenery subcomponents
and the positioned overlays.

The exit section is:

```
[count : i32]
count × { x : i32, y : i32, passwayIndex : i32 }        // one 12-byte read per record
```

Each record goes to `CMapGroundEntityLayer_UpsertExitMarkerByTileCoordinates` and draws an `"Exit"`
effect at the projected position. This is the same list the hero tick searches, so a server that
parses it sees exactly the tiles the client will ask about.

## Joining the index to a destination

`passwayIndex` is `cq_passway.passway_idx`. The row names a target map and one of its portals;
`cq_portal` turns that portal index into the arrival tile. Both ship populated — roughly 774
passways over 948 portals — and neither carries coordinates in the passway row, so a portal moving
does not require rewriting the passways that lead to it.

## What this server does

- Parses the exit section as part of the DMap read, bounded by `MapAssets:MaximumExitsPerMap`.
  Records are taken as the file gives them, **including coordinates outside the grid**: the client
  does not bounds-check them either (`CMapGroundEntityLayer_UpsertExitMarkerByTileCoordinates`,
  `0x637679`, files every record into a flat list that is later scanned against the hero's tile), so
  such a marker is inert rather than invalid. Shipped maps contain them — `qiling.DMap` has one at
  (284,444) on a 96x96 grid — and rejecting them refuses the client's own data.
- Joins passways to portals once at start (`MapTransitionCatalog`). A passway naming a portal that
  does not exist is **dropped and named in the log**, not fatal: the shipped tables contain two such
  rows out of 347, both on map 1778, and refusing to run a server over authored content it can
  simply not offer would be the wrong trade. The exits that use them refuse when stepped on, which
  is reported there.
- Answers subtype 85 by resolving the named tile against **the map the server has the character
  on**, and only when that tile is within one of the character's own position — the same nine tiles
  the client's scan could have reached. The hero position and facing in the packet are not read at
  all.
- Moves through `MapTransitionService`: leave the old map's visibility index, change the session's
  map and tile, send the map burst, enter the new map's index. If the destination cannot be
  described the character is put back and re-enters the map it came from, so it reappears to the
  players who were just told it left.
- Sends nothing when a request is refused. The client has no proven "no" for this, and the loading
  mode it entered ends on its own.

## Not done

- **Nothing else moves a character between maps.** No portals through NPCs, no teleport items, no
  revive. Subtype 85 is the only entry point so far.
- **Arrival tiles are not walkability-checked.** They are authored, and this server's passability
  view is the DMap base layer only, so refusing one would more likely be the server being wrong
  than the data.
