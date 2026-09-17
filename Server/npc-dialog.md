# NPC conversations — MsgTaskDialog (2032)

Verified 2026-08-29 against `Conquer.exe.bndb`. This covers the **transport only**. What a server
should *say* in a dialog comes from the task script tables, whose opcode meanings are not derivable
from the client — see the last section.

`CMsgTaskDialogEx__Create` `0x72BBFF`, `CMsgTaskDialogEx__Build` `0x72BD04`,
`CMsgTaskDialogEx__Process` `0x72BD72`.

## Layout

Twelve fixed bytes, then a string list. The list offset is read off Create (`add eax, 0xC` at
`0x72BC46`), not inferred.

| Offset | Size | Notes |
|---|---|---|
| `+0x04` | u16 | → line`+0x18` |
| `+0x06` | u16 | → line`+0x1C` |
| `+0x08` | u16 | → line`+0x04` |
| `+0x0A` | u8 | → line`+0x08`; inbound, the option the player picked |
| `+0x0B` | u8 | **action** — the value the handler switches on |
| `+0x0C` | … | string list; only entry 0 is read, capacity `0x100` |

Widths are from the handler's own `movzx` instructions (`0x72BE99`, `0x72BEA6`, `0x72BEB3`,
`0x72BEC7`, `0x72BD90`). The outbound builder writes `+4` as a single dword; the handler reads those
four bytes as two u16s.

## Actions

Actions 1–5 and 100 each allocate a 0x20-byte line, fill it from the fields above, stamp a type code
at line`+0`, and append it with `sub_7295EE(hero, line)`.

| Action | Effect |
|---|---|
| `0` | **nothing** — the `dec` chain at `0x72BDA2` never matches zero, so the handler returns |
| `1` | line type 0 |
| `2` | line type 1 |
| `3` | line type 2 |
| `4` | line type 3 |
| `5` | line type 1 — the same block as action 2 |
| `6` | no line; a message box via `sub_585AF0(0xD7D, (byte@+0xA << 16) \| (word@+8), "Confirm")` |
| `100` | line type 4, then `sub_7294BD(hero)` finalises and `0x3F9` is posted |
| `112` | no line; text goes to `sub_6D0A66(sub_55F488(), …)`; `byte@+0xA == 0` calls `sub_6D0A75` first, `== 2` posts `0xC91` |
| other | returns silently |

**Action 100 is the terminator**: nothing is shown until it arrives.

## Text is tilde-encoded

`'~'` (`0x7E`) stands in for a space. Inbound the client runs `sub_76A29C(text, 0x7E, 0x20)`;
outbound it does the reverse before sending (`0x583CE5`..`0x583CEF`). Both are guarded by the same
`_stricmp` against the GameDataSet string at `0x927B94`, so there is a configuration where neither
substitution runs — **which one is not established**. `sub_76A2D0(text, 0x100, "\n")` then folds a
marker into newlines unconditionally.

## Lengths are asymmetric — read this before writing a codec

`CMsgTaskDialogEx__Build` sets the length to `MsgStringList_GetRegionByteSize(list) + 0x0F`, but the
region starts at `+0x0C`. **The client over-declares its own packets by three bytes.** The native
server evidently tolerates it.

A server must not copy that habit: `CNetMsg__ValidateHeaderAndCopy` requires the declared length to
equal the number of bytes received, so an over-declared server packet is dropped. Send exactly
`0x0C + regionBytes`, and when parsing, do **not** require the declared length to match the payload —
this client's own packets will not.

`MsgStringList_GetRegionByteSize` (`0x771FC7`) = one count byte plus, per entry, one length byte and
its bytes.

## The NPC click — MsgNpcAction (2031) sub-action 6

**Found 2026-08-29.** `CMyShellDlg_OnLButtonDown` builds it at `0x5B1C6F` and `0x5B238C`, both as
`sub_72CBDF(msg, subAction: 6, id: entity+0xCC, 0, 0)`, guarded by the interaction mode at
`shell+0x179800` being `0x2C`. Mode `0x13` takes a different path entirely, `sub_660F33(hero, id)`.

The builder's layout (`sub_72CBDF`, note the argument slots shift across the `push 1` at
`0x72CBF1`):

| Offset | Size | Value |
|---|---|---|
| `+0x00` | u16 | `0x10` — the packet is always 16 bytes |
| `+0x02` | u16 | `0x7EF` = 2031 |
| `+0x04` | u32 | the entity id |
| `+0x08` | u32 | arg3, zero for a click |
| `+0x0C` | u16 | the sub-action |
| `+0x0E` | u16 | arg4, zero for a click |

Sub-action 6 is outbound only — the client's own 2031 handler implements 2, 3 and 5 and posts
`0x42A` for anything else — so a server must never echo it.

## What the client sends on 2032

Every sender of the outbound builder is a dialog or shell command:

| Action | Carries | From |
|---|---|---|
| `6` | chosen byte at `+0x0A` | `sub_583927` `0x583A50`, answering the action-6 confirm box |
| `101` | option byte at `+0x0A`, dword `+4` zero | `sub_53BF1B` `0x53BF45`, `sub_53C016` `0x53C02C` |
| `102` | dword at `+4` plus a text entry | `sub_729600`, from `CMyShellDlg_DispatchCommandCode` `0x5B3FA4` |

**None of these is the NPC click.** The packet that opens a conversation is not 2032 and has not yet
been found — every caller of the 2032 builder is already inside a dialog.

## A second evidence source: TQ's own action definitions

`Sources/魔域/Server/jehadServer/MapGroupKernel/ActionDefine.h` is original TQ server source —
Chinese comments, dated 2003.1.25, author "paled" — defining the action system this content is
written in. It documents each opcode's meaning and parameter format.

**It is a sibling lineage, not this build.** That file is the Eudemons-era (魔域) tree, and the
numbering does not match 5517:

- our `1056` (`new` / `delete` / `isexit`) is its `1080` `ACTION_USER_TASK_MANAGER`;
- our `1080` (`timestamp(a,b) set 0`) and `1081` (`interval(a,b,c) >= 1`) are 5517-only and appear
  nowhere in it;
- its `1001` attribute list names `force`, `dexterity`, `speed`, `health`, `soul` — a different
  game's stat set from Conquer's, so those names are **not** mapped across on its say-so.

So it is used as a hypothesis generator, never as a lookup table: **every reading is confirmed
against the shipped 5517 rows** — parameter arity, value ranges, branch usage — before anything is
implemented.

What it confirmed, independently of the derivations already made here: `101` menu text, `102` menu
link `"text task_id"`, `104` menu picture `"x y pic_id"` (which also settles the field order that
had been sent in stored order on a guess), `120` menu create, `123` check-time with its six forms,
`501` add item, `502` delete item, `503` check item, `2003` compare — and the whole `%` variable
list, one for one with the names found in the data.

What it did **not** get to settle, and was wrongly used for at first: `123` forms `2` and `5`, and
opcodes `121` and `122`. Those were implemented on its authority alone and have been **reverted**.
They are server-side opcodes with no witness in the 5517 client, and the shipped rows are merely
*consistent* with its readings rather than proof of them. A sibling game's server source is a lead,
never the last word.

What it did not settle: `501`'s parameter template. It documents twelve fields
(`amount amount_limit ident gem1 gem2 magic1 magic2 magic3 data warghostexp gemtype availabletime`)
while the 5517 rows carry lists of 9, 13 and 18 numbers. The arity disagrees, so the template stays
refused.

## The script model

`cq_npc.task0` → `cq_task` → `cq_action`, and the action rows form a linked list through `id_next`.
Verified against the shipped data by tracing real chains, e.g.:

```
1501 101 next=1502  "After~you~learn~spells,~you~may~cast~spells~to~kil..."
1502 102 next=1503  "Will~you~teach~me? 1510"
1503 102 next=3050  "Learn~advanced~spells. 3060"
1504 120 next=0     ""
```

So `id_next` builds the dialog linearly and `120` terminates it. For a `102`, the **trailing number
is a `cq_task` id** — 1510, 1520, 1570 and 3060 all resolve against `cq_task` — and it is where the
script continues when that option is picked; `id_next` is unrelated to the pick.

Which task slot an interaction selects is **not established**. Slot 0 is populated for all 583
scripted NPCs; slots 1, 2 and 3 for 26, 14 and 7 of them; slots 4 to 7 for none.

### Opcodes with evidence

| Opcode | Meaning | Evidence |
|---|---|---|
| `101` | dialog text | `param` is the text and is stored tilde-encoded, matching the substitution the client performs |
| `102` | option, `<text> <task id>` | trailing number resolves against `cq_task`; sibling `102` rows chain through `id_next` |
| `120` | finish and show | no param, no next; the client shows nothing without a terminator |

| `1001` | test a character attribute | see the expression corpus below |
| `1073` | test a stored counter | ditto |
| `104` | dialog face line | structural, below |

Two more line up but are not implemented, because nothing needs them yet: `105` carries text with
`data` in `{0, 2}`, matching the client's action-112 branch on the byte at `+0x0A`; `104` carries
three numbers.

### The dialog's capacity, and the picture line

From `MyShell\DlgTask.cpp` in the 5517 client (`0x53BA79`):

- the dialog holds **one** picture id at `this+0x5BC`, `0xFFFFFFFF` meaning none, resolved through
  `RoleDataQuery()->vtable+0xA4(id, 1)` and drawn at a **hard-coded** position — dialog x plus a
  constant, dialog y plus `0x1E`, with a `0x40 x 0x40` source rect. **No position comes from the
  packet**, so opcode `104`'s first two numbers are not screen coordinates;
- `"0 <= m_nTextAmount && m_nTextAmount < 8"` and `"0 <= m_nLinkAmount && m_nLinkAmount < 8"` are the
  class's own assertions, so **eight text lines and eight links** is the hard ceiling. Text records
  are `0x50` bytes from `this+0xF8`; link records `0x44` bytes from `this+0x37C`, with the byte a
  picked link returns at link`+0x40`.

Which packet field carries the picture id is still **not** established.

### Opcode 104 — the picture line

Established structurally, without a name to lean on. Across all 260 rows:

- `data` is always 0;
- `id_nextfail` is always 0, so it never branches — a state change would need that branch;
- **every single one is followed by opcode `120`**, the terminator, and 5,261 of them are preceded
  by an option — so it is the last line of the dialog, after the choices;
- the parameter is always exactly three integers: 254 of the form `10 10 N`, plus `103 10 8` and
  five `0 0 N`.

The third number ranges 0–259, which matches the numbering of the client's own portrait images in
`data/Npcface` (`75.dds`, `219.dds`, `320.dds`, …). Together with the client's remaining unused
dialog line type — action 4, line type 3 — that identifies this as the dialog's face line.

**Not established**: which of the packet's three u16 fields each number belongs in. They are sent in
stored order (`+4`, `+6`, `+8`). Getting it wrong costs a wrong portrait, not a wrong game state.

Implementing this one opcode took completable conversations from 14 NPCs to 287.

### Coverage, and why opcode counts mislead

`NpcScriptCoverage` walks every scripted NPC at startup and reports how many can reach a terminator,
exploring both branches of a condition. On the shipped data: **295 of 583**. Action-count coverage
moved only 42,063 → 42,323 for the same change, which is why it is not the number to steer by.

Blocking opcodes after 104, by how many NPC scripts each stops: `123` (86), `503` (77), `1056` (37),
`1010` (28), `1081` (19), `122` (11).

- `123` — 1,216 rows, branches (1,130 have a failure target), and `data` selects the kind: `data=3`
  carries a time range (`6 12:00 6 14:59`), `data=5` carries `00 01`. Several sub-forms, each
  needing its own derivation.
- `503` — 3,264 rows, `data` is an item type, 3,253 have no parameter, and it branches. An item
  test of some sort, but `502` and `503` must be told apart before either is implemented: one of
  them plausibly consumes rather than checks, and getting that backwards would destroy players'
  items.
- `1056` — parameter `isexit`, `data` an id, branches.
- `122` — a list of item type ids, usually no next.

### Opcodes 501, 502, 503 — the item family

Told apart by position and by prose, not by name.

**503 checks.** Its failure branches are written out: *"You do not have a DragonBall."*, *"Sorry, you
do not have a meteor."*, *"You are kidding. Didn`t you say that you have taken the Kylin Jade with
you?"*

**502 takes.** Three independent lines of evidence:

1. 1,292 scripts run a `503` and then a `502` **on the same item type**. You check once and take
   once; you do not check twice.
2. A `502` is almost never followed by another opcode naming that item — 7 rows out of 5,043 —
   while a `503` is, 1,292 of 3,262. The take is terminal for that item.
3. The `502` that follows a same-item `503` has an **empty failure branch** — it cannot fail,
   because the check already passed — and the text after it is *"Thank you for finding the
   KylinJade back for me."*

**501 gives.** Its two branch targets are always identical, so it asks nothing; and it is the most
common opcode within four steps of a `502` success (5,580 occurrences), which is the shape of paying
for a quest item.

Counts: `501` 20,976 rows (12,452 with no parameter), `502` 5,123 (5,033 empty, 80 with `data = 0`
and a name), `503` 3,264 (3,253 empty, 2 named). Only 556 of the 5,123 consume rows have a failure
branch at all — the other 4,567 send a failed take to action zero, which is a path that runs out and
therefore abandons the walk.

**Not established**: the positional template on 8,524 of the grant rows — 9 to 18 numbers, almost
all zero, e.g. `0 0 0 0 0 0 0 0 0 0 0 3 3`. Rows carrying one are refused. So are grants of a type
absent from `cq_itemtype`, which is 1,306 of the 3,623 distinct types granted.

### Opcode 123 — time windows

`data` selects the granularity, and the same two-ended shape appears at each:

| `data` | Rows | Form | Example |
|---|---|---|---|
| 0 | 787 | absolute | `2012-12-20 00:00 2013-01-03 23:59` |
| 1 | 31 | yearly, month-day | `8-24 6:01 12-31 23:59` — leading numbers are 1, 8, 12 |
| 2 | 51 | **not modelled** | `1 21:28 1 21:29` — the leading number is 1 in every row |
| 3 | 198 | weekly, day-of-week | `6 13:00 6 14:59` — leading numbers span 0–6 |
| 4 | 122 | daily | `20:00 20:59` |
| 5 | 27 | **not modelled** | `30 35` — pairs under 60 |

That it is a clock test, and the week's numbering, both come from the prose: a `data = 3` row of
`6 20:45 6 21:59` leads to the option **"Saturday Guild War?"**, so 6 is Saturday and the week starts
at Sunday; another answers **"The event has not started yet."** on the failure branch.

`data = 2` is refused because a single observed leading value cannot fix what it counts, and
`data = 5` because a pair of numbers under 60 does not say what period they are minutes of.

Windows wrap: a start that sorts after its end runs into the next cycle.

### Opcode 2003 — world conditions

2,732 of 2,734 rows are an expression; the other two are a bare `1002 410 354` triple and are
refused. Variable usage across them: `%user_map_id` 881, `%user_map_x` 858, `%user_map_y` 856,
`%map_owner_id` 111, `%user_id` 109, then `%iter_var_data*`, `%user_team`, `%user_home_id`,
`%syn_id`, `%id`.

Either operand may be the variable (`192 < %user_map_y` is as common as `%user_map_y < 298`) and
both may be. Answered: map, tile x, tile y, character id, syndicate id — all from the live session.
Refused: `%map_owner_id`, `%user_home_id`, `%user_team`, `%id`, `%iter_var_*`.

### Opcode 302 — map population

62 rows, every one with a failure branch, every one using `==`, and every `data` value a map id. The
parameter is `<who> <operator> <number>` with both `map_user` and `alive_user` appearing.

Counting is straightforward; the word `alive_user` is the interesting half, because it means the
scripts distinguish living characters from present ones. This server has no death state, so both
words count the same characters today — routed through a single `GameSession.IsAlive` so the
distinction lives in one place rather than being assumed away at each call site.

What "alive" will mean is visible in the client: a role carries a **128-bit status bitfield at
`role+0x70`**, tested by `Role_HasStatusFlag` (`0x6E50D4`) which bounds the index at `0x80` and
indexes `role + (index >> 5) * 4`. Being dead is one of those flags, not a life total of zero.
Which bit has **not** been established — the flag-to-meaning table would come from the status-effect
dispatcher (`sub_65F01A` and `Role_ApplyStatusFlagBitfieldAndDispatchEffects`, `0x6729E1`), which is
its own piece of work.

That shape — aliveness as a status flag on the role, exposed as one property — is also what the
LongV6270 community server does for a newer client (`Character.IsAlive => QueryStatus(GHOST) == null`,
against `Role.IsAlive => Life > 0` for other roles). It is used here as a design cue only: that
project targets a different protocol version, and nothing about its status numbering is carried
over.

### Opcodes 1080 and 1081 — cooldowns on the statistic rows

Both address `cq_statistic` rows, keyed exactly as `stc(a, b)` keys them. The proof is the key
space: **217 of the 218** distinct `timestamp(a,b)` keys and **231 of the 233** `interval(a,b)` keys
also appear as `stc(a,b)` keys. That table carries a `data` column, which `stc` reads, and a
`timestamp` column, which these two use.

They are a cooldown pair: **414 of 745** interval checks stamp the same key on their success branch,
and **507 of 795** stamps are reached from a check on that key. This is what settles `set 0`: were
it a literal zero, the elapsed time would be enormous and all 414 of those gates would stand
permanently open, so the stamp must record the current time. 794 of the 795 stored rows are
`set 0`; the one carrying another value is refused.

Units, from the thresholds each is used with: unit `0` appears with 60, 300, 600, 3600, 36000,
43200 — seconds — and unit `1` with 1, 2, 7, 30 — days. Opcode `1058` uses the same `interval(0)` /
`interval(1)` convention on its own record, which corroborates it independently.

### The task-record family — 1056, 1057, 1058 — has no storage here

Not implemented, and not for want of understanding:

- `1056` — `new` / `delete` / `isexit` on a record named by `data` (327 distinct ids, 400 to 6448);
- `1057` — fields of the *current* record: `complete == 1`, `complete set 2`, `data1 set 0`;
- `1058` — its time: `time set 0`, `interval(1) >= 1`, `interval(0) >= 10`.

It is a per-character task record with at least `complete`, `data0..3` and a time. **This database
has no table for it** — the schema holds `cq_task` and `cq_action` (the definitions) and
`cq_statistic`, and nothing per-character with those fields. The key space confirms it is separate:
none of the 327 `1056` ids is ever referenced by `stc`, `timestamp` or `interval` anywhere in the
151,854 rows, and none appears as an `stc` first argument.

So the blocker is storage, not meaning. Implementing it means either finding the missing table in
another dump or designing our own — a decision, not a derivation.

### Why the walk stages its writes

Nothing is written while a script is walked. The changes are collected and applied in one
transaction when the dialog completes. Without that, a script that took a quest item and then hit an
opcode this server cannot read would leave the player robbed — and `501` following `502` is the
single most common continuation, so that pairing is the norm rather than the exception.

### The expression corpus

Derived 2026-08-29 from all 8,000 non-empty params of opcodes 1001, 1073, 1074 and 2003.

| Opcode | Rows | Left-hand forms | Operators |
|---|---|---|---|
| `1001` | 4,303 | `profession` (1194), `level` (957), `vip` (835), `money` (346), `e_money` (293), `metempsychosis` (140), `exp` (140), `pk` (86), `iterator` (45), `life` (41), `e_money_mono` (36), `rankshow` (30), `speed` (28), `force` (20), `rank` (20), `look` (15) | `<` `>` `+=` `<=` `==` `>=` `=` |
| `1073` | 1,475 | `stc(a,b)` only | `==` `>=` `>` `<` |
| `1074` | 905 | `stc(a,b)` only | `=` `+=` |
| `2003` | 1,317 | `%user_map_id`, `%user_map_x`, `%user_map_y`, `%map_owner_id`, `%user_home_id`, `%syn_id`, and a bare `map x y` triple | `==` `<=` `<` |

`1001` is **both** a test and an assignment — 689 of its rows use `=` or `+=`. Reading those as
comparisons would branch on a falsehood, so the reader refuses them outright.

`stc(a,b)` addresses `cq_statistic`: `a` is `event_type`, `b` is `data_type`, and the row's `data`
is the value. A character with no matching row reads zero, which is what the 1,059 `== 0` tests are
asking. `1074` writes the same counter (`stc(202012,10) = 1 1` — the second number's meaning is not
established) and is not performed.

**Why the attribute names count as evidence.** Each accepted name is an English word for a value
this server already holds, and each matches a column of `cq_user`: `profession`, `level`, `exp`,
`money`, `emoney`, `metempsychosis`, `pk`, `life`, `lookface`. The names with no such column —
`vip`, `speed`, `force`, `rank`, `rankshow`, `e_money_mono`, `iterator` — are refused rather than
mapped onto something that merely sounds similar (`speed` and `force` in particular have plausible
but unproven candidates in `Speed` and `strength`).

### What is NOT established, and cannot be from this binary

**204 distinct opcodes** appear across the 151,854 action rows; the ones implemented now cover
103,118 of them. The rest are executed server-side — checks (`1020`, `check 1001`), effects (`1010`,
`1085`) — and the client never sees any of them, so the binary cannot prove what they mean. None is
implemented, and a walk that reaches one stops rather than guessing.

### MsgAction 132 — a client-side statistic request (not the stc language)

`Conquer.exe` at `0x700905` pushes `0x84` into a `msg.Create` call whose failure logs the source
line `msg.Create(g_objHero.GetID(), 0, 0, 0, actionGetStatistic)`. So **`actionGetStatistic` is
MsgAction subtype 132**, sent with the hero id and three zero arguments. Commented in the database
at that address. It is a client→server *request*, unrelated to opcodes 1073/1074, and is recorded
here as a lead for a future slice rather than as evidence for this one.

### 1010 — implemented; channel ids verified in the client

The biggest single first-blocker at 80 NPCs. 10,942 rows whose parameter is player-facing text
("Refinery complete! Breakthrough +N%; Term: N days.", "You are below Level N and can`t use this
book.") and whose `data` is 2005 (9,695), 2007 (1,138), 2011, 2000 and 7005. It never branches —
`id_nextfail` is 0 on 10,941 of 10,942.

**`data` is a MsgTalk channel id, verified in the client.** `CMsgTalk__Process` (0x731371)
dispatches on the channel at `+8` of the message body, and the constants line up: `0x7d5` = 2005,
`0x7d7` = 2007, `0x7d0` = 2000. Two behaviours worth recording:

* at `0x73144e` the client **rewrites channel 2000 to 2007** on arrival;
* for channel 2005 with sender `SYSTEM` addressed to the hero's own name, it calls
  `sub_5d2eaa(gameMsg, text, 0xffff0000)` — it supplies that colour itself and ignores the
  packet's. Other channels take the packet colour ORed with `0xff000000`.

All three open questions were then settled. The tilde is a space — `sub_76a2d0` is a replace-all
and the client only ever uses it to strip `\r` and `\n` (replacement operand at `0x9560dc` is the
empty string), while 19 stored rows use tildes and real spaces in the same sentence. The `%`
question was mostly a miscount: only **144** rows name a real variable, the other 899 carry a
literal per-cent sign as in "+5%; Term: 7 days"; the 144 are refused. The colour follows the
convention this server already uses elsewhere and cannot matter on channel 2005, where the client
supplies its own.

### 122 — reopened, and derived from the corpus after all

This was refused for a long time on the grounds that the only thing behind it was the Eudemons
source. That described one abandoned attempt, not the state of the evidence: 122 is server-side, so
no client witness can exist for it either, and the corpus method that settled six other opcodes was
simply never applied to it. Applied, it settles cleanly — eight slots always, `data` zero always,
the repeats as weights, and nothing in the row to key a deterministic choice on. See
`docs/game-server/npc-dialog.md`.

A measurement error went with it: 122 was reported as unlocking nothing, but that model let it fall
through to `id_next`, which is zero on 710 of its rows. Following the eight slots properly, it
unlocks **+9**.

### 1056/1057/1058 — the branch targets are the evidence

No client witness exists for these either. What settles which forms ask and which act is the stored
data itself: `isexit` carries a distinct failure target on 319 of its 470 rows while `new` and
`delete` carry one on none of their 368; `==`/`>=`/`<=` on 983 rows against `set`/`+=` on none of
822; `interval` on all 27 against `time set` on none of 89. Questions branch, effects do not, and
the walker and the coverage model both read the parameter for exactly that reason.

Storage is `oc_character_task_records` (migration 20). `data7` is not carried — no 5517 row reaches
it. See `docs/game-server/npc-dialog.md` for the full derivation.

### 1074 — searched for a witness, found none

Before implementing it the client was searched for any trace of the `stc` language: `Conquer.exe`,
every shipped DLL and the TQ admin tool `TQAT.exe` (ASCII and UTF-16) contain **no `stc` string at
all**. That is the expected result — 1073 and 1074 run entirely server-side — but it is recorded so
nobody repeats the search. Its semantics come from the shipped corpus, the same way 1073's did; see
`docs/game-server/npc-dialog.md` for the trailing operand and the clamp at zero.

### A correction to every coverage figure quoted before 2026-08-31

The startup diagnostic that reports "N of 582 scripted NPCs can reach a finished dialog" explored
the failure branch of only three opcodes when **eight** of them branch. Because a script counts
only when *every* explored path finishes, unexplored branches credit conversations that were never
checked, so the figures were **too high** and the blocker they named could be wrong. Corrected, the
pre-slice code reports **346**, not 358 — and the leading blocker is `122` (`ActionRandaction`) at
60, not `1074` at 56.

## Client data that corroborates the NPC model

`ini/npc.ini` is keyed `[NpcTypeN]` where N is `lookface / 10` — NPC 1 has `lookface 0010` and
`[NpcType1]` is `Name=Storekeeper`. That is independent confirmation of the look-composite split
verified in `CMsgNpcInfo__Process`.

`ini/Questinfo.ini` carries the client's quest journal: 230 missions with `MissionId`, level range,
`Prequest` chains, `BeginNpcId`/`FinishNpcId` as `id,map,x,y,name,mapName`, rewards and prose. It
describes quests but defines **no** script opcodes. Note its NPC coordinates do not match the
shipped `cq_npc` rows, so the two data sets come from different content builds.
