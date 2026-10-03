# Online character directory

The server-wide list of signed-in characters. Distinct from visibility, which is per map and only
covers what one character can see; this answers "where is character X" and "is character X online"
from anywhere.

## Why it exists

Three things need a character the asker cannot see:

- a directed chat message, addressed by name;
- the friend and enemy list's online column, hydrated during the world-entry ladder;
- later, presence pushes, team and trade.

## Membership

A character is listed from the moment it has a session until that session ends — not from map
entry. The friend list is hydrated on rung `0x4C` of the world-entry ladder, which runs inside the
session runtime, so a directory keyed on world entry would answer "offline" for everyone during
exactly the request that asks.

Names are matched case-insensitively, because the database's own uniqueness check is: two online
characters cannot differ only by case. A resolved character's own spelling is what goes back on the
wire.

A second session for the same character replaces the first; the displaced session's later
unregister is a no-op, because removal only matches the exact session instance. That ordering is
what stops a stale cleanup from unlisting the live connection.

## Online state on the wire — verified 2026-08-28

MsgFriend (`1019`) carries the online state as the **byte at `+9`** on the add paths.
`CMsgFriend__Process` passes it to `CFriend__CreateNew` (`0x709DA3`), which allocates the
`0x4C` list record and sets `record[5] = (flag != 0)` at `0x709E3B` — the same field that subtype
`12` (`FriendOnline`) sets to `1` at `0x74D972` and subtype `13` (`FriendOffline`) clears at
`0x74DA1E`. Any nonzero value reads as online.

`+0xC` = peerage rank, `+0x10` = peerage sex (1 male, 2 female) — proven 2026-09-28, see
`Network/06_combat_packets.md` MsgFriend. Only consumer: friend/enemy info dialog peerage icon + title
(`CPeerageMgr` key `sex + rank*10`). Zero sex = no icon/title. Presence 12/13/16/17 **overwrite** both
fields, so presence rows must carry them too. Sending 0/0 (current server) is harmless but blanks the icon.
Server values: rank from the counterpart's peerage (0,1,3,5,7,9,12), sex = counterpart lookface
`(look/1000)%10`.

## Presence pushes — verified 2026-08-28

Subtypes `12`/`13` (friend on/offline, `0x74D949` and `0x74D9F5`) and `16`/`17` (enemy,
`0x74DBA7` and `0x74DC4F`) are the only packets that change an already-hydrated entry's state.
Each looks the entry up **by id from packet `+4` alone** — the name at `+0x14` is not read on
these paths — and sets `record[5]`, the same field `CFriend__CreateNew` fills from `+9`.

### The mutual-row question

The client's complete MsgFriend send set settles the shape of it. Three call sites build a MsgFriend
(xrefs to `CMsgFriend__BuildSubtypeEntityIdFlagName16`, `0x74D6D3`):

| Site | Subtype | Meaning |
|---|---|---|
| `0x69E6E7` | `0xA` (10) | add-friend **request**: id = target, flag 0, name = target `CRole+0x14C` |
| `0x69E7E2` | `0xE` (14) | remove friend: id, flag 0, name = local friend entry name |
| `0x69E0C5` | `0x12` (18) | remove enemy: id, flag **1**, name = local enemy entry name |

All three populate name (builder refuses NULL). `+0xA/+0xC/+0x10` always 0. Flag is literal: 0 on 10/14, 1 on 18.

**There is no client path that sends 11 (AddFriend), 15 (AddFriendSilently) or 19 (AddEnemy).**
Those subtypes only ever arrive from the server. So:

- **A friendship is created through a two-party request.** The client asks with subtype 10 and adds
  nothing locally; the recipient's prompt is case 0 at `0x74D7BD` (GameDataSet string `0x18705`).
  Both characters are involved in creating it, which is what makes mutual rows the natural
  server-side outcome.
- **An enemy is never requested by a client at all.** Nothing in the client adds one, so an enemy
  relation is created server-side alone and is **one-sided by construction**.

That asymmetry is the reason the presence lookup is a real inverse query rather than a reuse of the
character's own list. Deriving "who should be told" from "who I list" would be defensible for
friends and simply **wrong for enemies** — the character who was made someone's enemy has no row of
their own to derive it from.

What the shipped storage actually contains is still unconstrained: `cq_friend` and `cq_enemy` carry
only `PRIMARY KEY(id)` — no uniqueness, no pairing constraint — and both ship empty, so no data
confirms the friend case either. `ISocialRelationRepository.GetListingsOfAsync` therefore asks the
inverse question directly against the counterpart column, which is correct in both cases and stays
correct however a future friend-add writes its rows.

The counterpart columns are unindexed in the shipped schema, so those are scans. They run once per
sign-in and once per sign-out, not per action. An index on `cq_friend.friend` and `cq_enemy.enemy`
is the fix if that stops being acceptable.

## List editing — implemented 2026-08-28

The three subtypes the client sends are the whole editing surface, and the server implements exactly
those:

| Subtype | Server behaviour |
|---|---|
| `10` Request | Completes the friendship when the target has already asked; otherwise records this half and forwards the request to the target, carrying **the requester's** id and name |
| `14` RemoveFriend | Deletes both rows and tells both clients — neither removes locally (`0x74DA9D`) |
| `18` RemoveEnemy | Deletes the one row and sends nothing — the client already removed it locally at `0x69E11E` |

Any other subtype is refused: accepting one would let a client write its own list state.

Because there is no accept subtype anywhere in the client, **acceptance is the same request coming
back the other way**. The first half waits in memory (`FriendRequestBook`), capped per target and
dropped when either character signs out — a request that outlives its session has no way to be
answered, because the answer is another live client sending the same packet.

Friendships are written in both directions in one transaction, enemies in one. A request naming an
offline character, an existing friend, the sender itself, or arriving at the 50-friend cap
(`0x69E54B`) is refused without a reply: no packet for any of those refusals is proven, and one
would put text in a chat log this client build was never shown.

### Native friend cap — proven 2026-09-28
`0x69E54B` is the tail of `CHeroFriendAndEnemyMgr_GetMaxFriendCount` (`0x69E4FD`):

| `CHeroConfigMgr` bit 10 (MsgTrusteeshipState 1129 `+4`) | hero `+0x474` (`CHero_GetFlowerStatusTier`) | cap |
|---|---|---|
| clear | any | 50 |
| set | 0 / 1 / 2 / 3 / 4 / 5 / other | 50 / 55 / 60 / 70 / 80 / 90 / 100 |

- Sole caller: `RequestAddFriend` (`0x69E5D9`). Gates only the client's own outgoing subtype 10.
- Not a storage/UI cap: `AddFriend` (`0x69E394`) push_back, no count/dedupe check; 11/15 always add;
  list refresh `0x4925A2` iterates all rows.
- Hydrating >50 is safe. Native design reaches 100. Display quirk only: `CMyList_SetRowState` (`0x5A47B7`)
  drops row-state for rows >= 64; draw `0x5A3C30` reads it unbounded -> rows >= 64 get colour from
  unrelated `CMyList` members.
- The server's flat 50 refusal is server policy, not a native invariant; matches native only while 1129
  bit 10 is clear (current server never sends 1129).

## Storage contract

Migration `20260828_01_add_social_list_write_contract` adds what a writer needs: `UNIQUE`
`(userid, friend)` and `(userid, enemy)` so a pair cannot duplicate, indexes on the counterpart
columns for the presence lookup, and it drops the now-redundant single-column `userid` indexes. The
readiness validator checks all four indexes, the column contract and the absence of self-relations
at start, so a database that drifted is refused rather than half-working.

## Not done

- **Nothing creates an enemy.** Enemy entries can be removed and read, but no server system adds
  one; the retail trigger for that is combat, which does not exist yet.
