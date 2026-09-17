# NPCs — spawn and removal

Verified 2026-08-29 against `Conquer.exe.bndb`.

## MsgNpcInfo (2030) — S → C

`CMsgNpcInfo__Create` `0x7439E3`, `CMsgNpcInfo__Parse` `0x743A9F`, `CMsgNpcInfo__Process` `0x743B32`.

Parse is only `CNetMsg__ValidateHeaderAndCopy` plus a check that the type word is `0x7EE`. That
validator enforces no minimum size — it checks only that the declared length equals the received
length and that the type is nonzero — so a short packet would let the handler read past the fields
into whatever the copy buffer held. The server must send a length that covers every field below.

| Offset | Size | Field |
|---|---|---|
| `+0x04` | u32 | entity id → `npc+0xCC`; also the id `EntityRef_ResolveByIdOrLocalHero` looks up |
| `+0x08` | u32 | → `CNpc__SetField_0x370`; **what that field means is not established** |
| `+0x0C` | u16 | tile x |
| `+0x0E` | u16 | tile y |
| `+0x10` | u16 | look composite |
| `+0x12` | u16 | npc kind → `npc+0x368` |
| `+0x14` | 2 | read by nothing |
| `+0x16` | … | string list |

`look / 10` selects the appearance record — `RoleDataQuery()->vtable+0x30` below 5000, `+0x34` at or
above — and `look % 10` goes to `CRole_SetDirectionFromPacked8`.

The kind picks the RoleView mode: `0x0E` → 6, `0x13` → 8, `{9, 0x19, 0x1A, 0x27, 0x29, 0x2A, 0x66,
0x67}` → 9 through `sub_64D919` with the tile, everything else → 4.

### The string list

`CMsgNpcInfo__Create` binds it at `0x743A2A`: `lea eax, [esi+4]` is the packet base, `add eax, 0x16`
is the list, and `0x3E9` is the capacity. **So the list starts at packet + 0x16**, and the fixed part
is 22 bytes.

Format, from the helpers: `sub_771FC0` returns `**(list+4)` — the first byte of the region is the
entry count — and `MsgStringList_TryGetEntry` walks `[length byte][bytes]` pairs from the byte after
it.

`Process` reads entry 0 only, and only when the count is nonzero, with capacity `0x10`.
`TryGetEntry` fails when `capacity <= length`, so **a name of 16 bytes or more is dropped**. The
return value is ignored at `0x743E9D` and `CRole_SetName` runs anyway on the zeroed buffer, so an
over-long name means a nameless NPC rather than an error: a server truncates to 15.

## MsgNpcAction (2031) — S → C

`CMsgNpcAction__Create` `0x72CB79`, `Process` `0x72CC60`. **No string list** — Create never calls the
binder — so the packet is fixed fields only and the client reads through `+0x0F`.

| Offset | Size | Field |
|---|---|---|
| `+0x04` | u32 | entity id |
| `+0x08` | u32 | only used by sub-action 5 |
| `+0x0C` | u16 | sub-action |
| `+0x0E` | u16 | npc kind, only used by sub-action 5 |

- **2 or 3** → `EntityManager_RemoveEntityById(&g_objPlayerSet, packet+4, 1)`, and nothing else. This
  is the NPC despawn.
- **5** → `sub_660AC5(hero, packet+8, flag)`, flag `1` for kinds `{9, 0x19, 0x1A, 0x27, 0x29, 0x2A,
  0x66, 0x67}` — the same set 2030 routes to RoleView mode 9 — and null otherwise. What
  `sub_660AC5` does is **not established**.
- anything else → posts `0x42A` and returns.

Note the sub-action is the u16 at **`+0x0C`**, not at `+4`; an earlier note in
`11_else_branch_packets.md` said `+4` and has been corrected.

### Why not MsgAction 135

Subtype 135 also removes by id, but it plays `"BodyDisapear"` for any id at or below `999999`, which
every NPC id is. 2031 sub-action 2 removes silently.

## The client culls NPCs itself

`EntityContainer_CullEntitiesOutsideVisibilityRange` (`0x6E9243`) walks the same container 2030
registers NPCs into (`sub_6E77D5(&g_objPlayerSet, …)`) and applies
`Map_IsTilePairOutsideVisibilityRange` to every entry. Its guard at `0x6E92D4` skips exactly two
things:

- an entity whose `+0x368` — the kind 2030 writes — equals `0x1C`;
- the entity id `0xEE6B2801` (4000000001).

Everything else, NPCs included, is dropped on the same Chebyshev-18 test the server uses, and
`CMyShellDlg_RunFrameTick` runs the sweep every frame. So an NPC leaving the radius needs no packet.

## What OpenConquerPublic does with this

- `NpcCatalog` loads `cq_npc` once at startup — 790 rows over 152 maps on the shipped database — and
  serves each map from a frozen lookup.
- `NpcVisibilityService` syncs a session after world entry, every step, every jump and every map
  change; it spawns what came into range, forgets what left, and sends a removal only when the
  configured radius is below the client's.
- **Map changes always remove explicitly.** Whether the client tears its entity container down on a
  map change is **not established**, and the cull would not cover it: `Map_IsTilePairOutsideVisibilityRange`
  compares tile coordinates with no notion of which map they belong to, so an old-map NPC near the
  arrival tile would survive and follow the character. Removals for entities the client has already
  dropped are free — `EntityManager_RemoveEntityById` (`0x6E7B23`) scans the deque for the id and
  returns 0 without touching anything when there is no match.
- **Open, same shape, outside this slice**: the departing client's view of the *characters* on the
  map it left rests on the same unproven teardown. `WorldVisibilityService` removes the leaver from
  the observers' screens but sends that client nothing about the players it was watching.
- Names are truncated to 15 bytes at send time.
- Rejected at load: id zero, id at or above 1000000 (the player range), and a zero look composite.
- The `+8` dword is sent as zero, because nothing establishes what the client's `npc+0x370` is for.
- Sub-action 5 of 2031 is not sent, and 2032 (task dialog) is not implemented at all: NPC
  interaction is its own system and none of it is claimed here.
