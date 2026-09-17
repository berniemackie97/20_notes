# Position synchronisation

Verified against `Conquer.exe` 5517 on 2026-08-28.

## The client reports its own position, continuously

`CHero_TickIdlePositionSyncSend` (`0x661AAC`) builds MsgAction subtype **100** (`0x64`) from a tick
for the whole session, unprompted:

```
CMsgAction__Create(heroId = hero+0xCC, x, y, dir = hero+0x17C, 0x64, timeGetTime())
```

with the tile read from the role's own tile-pair getter. Push order at `0x661A9B`..`0x661AAC`
confirms the mapping. It is gated by the `vtable+0x18` predicate on `hero+0x2CD8`.

**Subtype 100 in the other direction is a different thing.** Its receive branch (`0x6FFC39`) shares
a label with subtype `0xCF`, computing a replacement for packet `+8` through `sub_67E717` and
returning the packet — a challenge the client answers in place. Echoing an inbound 100 back is
therefore not an acknowledgement.

## Correcting a client: subtype 108

`0x6FFC4B`. Applies only when the entity id at `+4` resolves to the local hero. Reads the tile at
`+0x18`/`+0x1A`, recomputes the coordinate gate, sets the role tile through role `vtable+0x18` and
calls `Role_UpdateCoordinateGateAndMapFromTilePair`. No effect, no animation — unlike subtype 156,
which is a teleport and plays `"KOTeleport"`.

It then **replies with subtype 146**, and if auto-run was active it re-issues a move-to-tile command,
stops auto-run and shows GameDataSet string `0x2B73`.

## Subtype 146 is position sync, not an emote

`0x7001DF`. For the local hero: recompute the coordinate gate, read the hero's own tile, and when it
differs from the packet's `+8`/`+0x0A`, **rewrite the packet with the hero's tile** and `+0x1C` with
`CGameMap_GetMapId()`, then return it. For any other role: snap that role onto the tile.

Both ends answer 146, so a server that echoes one leaves the two trading it indefinitely.

## What this server does

- Reads subtypes 100 and 146 as the same statement — "this is where I think I am".
- Judges a report against **the tiles the character actually occupied**, not against how far it is
  from where the character is now. The session keeps a short history of recent tiles; a report
  naming any of them is in flight and is accepted.
- Counts consecutive reports that name a tile in no history, and corrects with subtype 108 only
  after `GameServer:WorldPosition:DivergentReportsBeforeCorrection` of them (default 3). A matching
  report clears the run.
- Never echoes 100 or 146.

**Distance is the wrong test, and using it produces false corrections.** Movement is echo-driven, so
a client is wherever the last echo it processed put it. A report that crosses a burst of steps, or a
jump — which covers up to sixteen tiles at once — names a tile the character genuinely stood on and
can be arbitrarily far from where the server has moved on to. A distance threshold would correct
players for moving quickly, and a stale report crossing a map change would correct them onto the
wrong map. The history check recognises all of those as in-flight and the map change clears the
history outright.

What remains after that is a report naming a tile the server never authorised, repeatedly. By the
time several have arrived in a row nothing is still in flight, so the two ends have genuinely parted
company — which this build can produce, since server-side movement validation sees only the DMap
base layer while the client also honours scenery overlays.

The correction settles rather than loops: the client's 146 acknowledgement carries the tile it just
adopted, which by then agrees. A client that does not take it is tried again, but only once another
full run of reports has gone by, never once per report.

A newer-generation community server (LongV6270) was read as a cross-check on the server-side
handling. It corroborates the packet — its `Kickback` is action 108 carrying identity, direction,
tile and timestamp — and, more usefully, it never reconciles a periodic report at all: it sends 108
only to reject a specific action it has already judged invalid. That is the conservative end of the
same reasoning, and it is why this server corrects on a proven run rather than on a distance.

## Not done

- **The divergence is corrected, not diagnosed.** Nothing distinguishes an overlay disagreement from
  a client that is lying, and nothing acts on repetition.
- **Subtype 100's inbound challenge is not implemented.** `sub_67E717` is unread, so the server
  neither poses it nor would know a valid answer.
