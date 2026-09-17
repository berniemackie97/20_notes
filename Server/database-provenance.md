# Database provenance and 5517 fitness

What this database actually is, table by table, measured against the 5517 client's own shipped
data and against three independent copies of the same TQ dump. Every number here comes from the
files named; nothing is taken from another project's word.

## Sources used

| Source | What it is | Why it counts |
| --- | --- | --- |
| `00_clean/clean/5517.7z` | The shipped client archive, 445 MB | **The only pristine source.** Extract from here to check any file. |
| `00_clean/clean/5517-loader/ini/` | Unpacked copy, original 2011 timestamps | Verified byte-identical to the archive |
| `00_clean/clean/5517/ini/` | Working copy | Files match the archive **except `Questinfo.ini`, which was edited** |
| `Conquer.exe` @ `0x6791e0`, `0x677ae0` | `ItemTypeDataSingleton_LoadItemRecordTableFromDecodedTextDat` | Proves the decode seed and the field order |
| `Archives/zf.sql` | 2012 Navicat dump of a `zf` private server | Descends from the ~5071 TQ leak, heavily modified |
| `CanyonV6192-main/sql/dump-cq-*.sql` | Canyon, v6192 | Independent copy of the later English retail dump |
| `LongV6270-main/sql/game_cq.sql` | Long, v6270 | Independent copy of the same, best maintained |

`ini/Itemtype.dat` is read through `DecodedTextDatReader` with **seed `0x2537`** (`0x677ae0`).
`ini/magictype.dat` uses the **same seed** (`0x69c1c2`), and keys its rows `type * 10 + level`
(`0x69cd71`). `ini/LevExp.dat` uses seed `0x4D2`, recorded earlier in
`20260818_02_rebuild_level_experience_from_native.sql`.

## cq_itemtype - genuinely 5517, now exact

`itemtype.dat` decodes to **14,981 rows of 59 `@@`-separated fields**, and the client reads all 59
in the order the decompiled loader shows. Every one of those rows was already present.

Migration `20260831_01_rebuild_item_catalogue_from_native` closed the gap:

* **175 cells** disagreed with the client's file and were corrected. They were not random drift -
  91 `emoney_price` cells held exactly 100x the native price, six item types carried crit, immunity,
  breakthrough and counteraction values native sets to zero, and one item name (711326) was stored
  as four U+FFFD replacement characters because it had been imported through a decoder that could
  not read GBK. In the other direction the table had **lost** native values in `resist_wood`,
  `resist_earth`, `honor_price` and `req_profession`.
* **Five native fields had no home** and now do: f27 `magic2` (an existing all-zero column of that
  name sat exactly where it belongs, so it was filled rather than duplicated), f29 `data`,
  f53 `type_desc`, f54 `item_desc`, f55 `color_index`.
* The **169 rows the client has no record of are deliberately kept**: 70 `cq_action` rows,
  19 `cq_lottery` prizes, 5 `cq_goods` rows and one live `cq_item` reference them, so deleting them
  would manufacture dangling references. A NULL `type_desc` is what marks them.

The table now reproduces `ini/itemtype.dat` **exactly** on all 14,981 rows and all 59 fields.

## cq_magictype - was drifted, now exact

`magictype.dat` uses the **same seed** (`0x69c1c2`) and keys its rows `type * 10 + level`
(`0x69cd71`), which is the key this table already used. Migration
`20260831_02_rebuild_skill_catalogue_from_native`:

* corrected **608 cells**, concentrated in `need_prof` (156), `delay_ms` (113), `status` (106) and
  `need_exp` (76) - the columns that decide whether a skill can be learned and how fast it casts;
* added the **twelve native fields that had no column at all**: `need_time` (non-zero on 365 of 893
  rows), `status_data0..2`, `target_num`, `need_ast_prof`, `need_ast_prof_rank`, `width`, `data`,
  `dur_time`, `atk_interval`, `coldtime`.

Now exact on all 893 rows and all 48 fields.

## WARNING: which copy of the client data to read

**Migration 17 used an edited copy of `Questinfo.ini`.** The pristine file is the one inside
`00_clean/clean/5517.7z` (180,916 bytes, 2011-07-28 02:19:31, sha256 `b96b7f30...`), which
`00_clean/clean/5517-loader/ini/Questinfo.ini` reproduces byte for byte. The copy under
`00_clean/clean/5517/ini/` is 180,811 bytes, dated 2026-04-22, sha256 `98d92e41...`.

Only that one file differs between the trees. `itemtype.dat`, `magictype.dat`, `magictypeop.dat`,
`Monster.dat`, `Shop.dat` and `LevExp.dat` are byte-identical in both, so migrations 15, 16, 18
and 19 are unaffected.

**Always read client data from the archive or from `5517-loader/`, never from `clean/5517/`.**

## cq_questtype - corrected and trimmed to what the client can draw

`ini/Questinfo.ini` is plain text and declares `TotalMission=230` over **224 distinct** `MissionId`
values; six ids appear twice. Migration `20260831_03_correct_quest_catalogue_from_native`:

* widened the ten `intent` columns from `VARCHAR(255)` to `VARCHAR(512)` - **the table could not
  hold the client's own text**, mission 992's intent line runs to 324 characters;
* corrected **60 cells**, all import damage: 42 `prize` cells held a doubled backslash where the
  file has a single one, 17 `intent` cells were mojibake (the same GBK fingerprint as the item name
  above) or truncated, and one `profession` cell held 100 where native holds 999;
* **deleted the 390 rows** describing missions the client has no block for. Unlike the surplus item
  types, nothing references these: no server code reads `cq_questtype`, and every
  `action_complete`, `action_quit` and `action_fail` is zero.

All 224 client missions now match a client block on all 22 mapped fields.

## cq_magictypeop and cq_goods

`cq_magictypeop` needed nothing: 393 rows x 65 fields, **already exact** against
`ini/magictypeop.dat`.

`cq_goods` stock is correct too. Over the 63 shops `ini/Shop.dat` declares - a plain-text file,
read straight through the ini store at `0x74f9ef` with no decoder in the path - there are zero
items the client stocks and we lack, zero we stock and it lacks, and zero moneytype
disagreements. Migration `20260831_04_deduplicate_shop_stock` removed **30 rows that duplicated
another row of the same shop exactly**. Eleven shop owners have no `[Shop]` block in the client's
file (333 rows); all eleven are real NPCs, five in `cq_npc` and the rest in `cq_dynanpc`, and
whether the client can open a shop it has no local block for is **not established**, so they stay.

## cq_monstertype - six columns aligned to the client

**A correction first.** An earlier pass reported that `helmet_type`, `weaponr_type` and
`weaponl_type` matched `Armet`, `RWeapon` and `LWeapon` on all 383 rows and that this proved the
join. It proved nothing: those keys, with `BodyType`, `Mount` and `BiologicalType`, are **zero on
every section of the file**, so they match any all-zero column.

The join is `TypeID`, which is a **list** on two sections. Expanded, 745 sections cover 739
distinct type ids, and `TypeID = cq_monstertype.id` matches **462** of our 579 rows - not 383. The
section name also agrees on 384 of those (83.1%), which is what confirms it. Where two sections
claim an id, the one whose name matches the stored name is used.

`Monster.dat` is the client's **rendering** table. It has no attack, defence, dodge, drop or AI
data, so most of `cq_monstertype` has no counterpart in it. A key is only used where the two value
domains are the same, so that a disagreement is about one quantity rather than two:

| key | column | rows differing |
| --- | --- | --- |
| `MaxLife` | `life` | 40 |
| `Level` | `level` | 48 |
| `SizeAdd` | `size_add` | 125 |
| `BattleLev` | `extra_battlelev` | 4 |
| `StcType` | `stc_type` | 21 |
| `Boss` | `boss` | 15 |

Four candidates are **rejected** because the sides hold different quantities: `ZoomPercent` is
90-200 (a zoom percentage) against our 400/500/1000 `run_speed`; `BornAction` is 100/101/315
against our 20900 / 5035500-style motion ids; `ExtraExp` is **100 on every row**, carrying no
information at all; and `AntiType` is non-zero on 8 rows where `anti_monster` is non-zero on 130.

Migration `20260831_05_align_monster_baseline_to_client` changes **253 cells** and widens
`extra_battlelev` from `TINYINT` - the client's own file carries `BattleLev = 285`, which the
column could not hold. The 117 rows with no client section and the 277 client sections with no row
of ours are untouched.

Whether the client's `MaxLife` and `Level` also govern what the server should use is **not
established** by anything in the binary. Taking the client as the baseline for these six columns
is a recorded project decision.

## oc_character_task_records - our own storage for 1056/1057/1058

The three opcodes were understood but had nowhere to write: their 332 task ids (400..6448) appear
**nowhere** in `cq_statistic`'s key space - zero overlap with anything 1073, 1074, 1080 or 1081
touch. Migration `20260831_06_add_character_task_record_contract` adds the table, derived from the
corpus rather than adopted from anyone's schema.

What the shipped scripts require:

* **1056** - 838 rows, three forms and no others: `isexit` 470, `delete` 219, `new` 149. A record
  exists or does not, per character per task. That is why `(character_id, task_id)` is the key.
* **1057** - 1,914 rows, every one `<field> <op> <n>`. Fields `complete`, `data1`..`data6`;
  operators `==`, `>=`, `<=`, `set`, `+=`. Operands: `complete` 0..2, `data1` 0..40000,
  `data2` 0..2461, `data3`..`data6` are 0/1 flags. **Not one operand is negative.**
* **1058** - 116 rows: `time set 0` on all 89 stamps, `interval(1) >= 1|10|30` and
  `interval(0) >= 60`. Units follow the convention proven for 1081: 0 seconds, 1 days.

`set 0` records the current time, by the same argument that settled 1080: of the 16 task ids whose
time is ever checked, 15 are also stamped, and 15 of 27 interval checks reach a `time set` on the
**same** id from their success branch. A literal zero would leave all 15 of those gates permanently
open.

Two semantics the data forces:

1. **A write creates the record.** 215 of the 302 ids 1057 touches are never created by a `new`,
   so a design requiring `new` first would make two thirds of the task records unusable.
2. **An absent record reads as zero**, so `complete == 1` is false and `data1 >= N` fails - the
   same contract already used for `cq_statistic`.

Departures from the reference `task_detail` shape, each deliberate: `data7`, `notify_flag`, `type`
and `max_accumulate_times` are dropped because no opcode in the corpus reaches them and the corpus
is closed; the surrogate id plus non-unique index is replaced by a composite primary key, because
that shape permits two rows for one character and task and `isexit` has no way to choose between
them; and `task_overtime INT` becomes a nullable `DATETIME(6)`, so NULL means never stamped rather
than a comparison against the epoch.

Nothing reads it yet. The opcodes remain unimplemented and the walker still refuses them.

## cq_action, cq_task, cq_npc - the later English retail dump, not 5517

Our copies are the same artefact three other projects carry, essentially untouched:

| Table | Ours | Long v6270 | Canyon v6192 |
| --- | --- | --- | --- |
| `cq_action` | 151,854 | 151,854 | 151,828 |
| `cq_task` | 9,010 | 9,011 | 9,004 |
| `cq_npc` | 790 | 787 | 786 |

* `cq_action`: all 151,854 ids are shared with Long and **exactly one row differs** in the
  structural columns (id 9580142, `data` 804 here against 605 there). The 1,336 apparent `param`
  differences are all SQL-escaping and tab-handling artefacts of the two export paths, not content.
* `cq_task`: all 9,010 shared rows are **identical across all 15 columns**. Long has one extra row
  it added (150000000).
* `cq_npc`: 786 shared rows, **five differ** - four are Long's own repositionings and one is a
  rename (10010 is `VillageGateman` here, `KnowItAll` there).

The same holes appear in all three copies, so they belong to the dump itself and are not an
artefact of our import: **77** dangling `cq_action.id_next`, **65** dangling `id_nextfail`,
**29** dangling `cq_task.id_next`, and **14** NPC task ids with no `cq_task` row. Neither Long nor
Canyon can resolve a single one of them.

### The version mismatch this creates

`cq_itemtype` is 5517. The script corpus is not.

Opcodes 501/502/503/519 name an item type in their `data` column. Across the whole table that is
29,345 references over 5,334 distinct ids, and **7,799 of those references (2,266 distinct ids)
name an item the 5517 client does not have**. Those ids are not lost data - **2,182 of them are in
Canyon's item table and 2,254 are in Long's**, while the 5071-era `zf.sql` has 21 and the 5517
client has none. The script corpus is post-6192 content.

The damage to actual conversations is far smaller than that headline, because most of the corpus
is not reachable from an NPC at all. Walking every scripted NPC's task graph - following
`id_next`, `id_nextfail`, the task id inside a 102 option, and the eight ids inside a 122 -
reaches **38,274 of 151,854 actions (25.2%)**. Inside that reachable set:

* **3,297 item operations, of which 286 (8.7%) name a post-5517 item**;
* **66 of 581 scripted NPCs (11.4%)** can walk into one.

`cq_npc` itself is clean against the client: all 790 rows use a `type` that `ini/npc.ini` defines
(1,096 `NpcType` entries, 1..1439).

### cq_questtype has the same drift

`ini/Questinfo.ini` declares `TotalMission=230` and carries **224 distinct `MissionId`**. Our
`cq_questtype` has **614 rows**. All 224 client missions are present; **390 rows describe missions
the 5517 client has no entry for**. Nothing in the server reads this table yet.

## cq_task: twelve columns the server ignores

`cq_task` has 15 columns and `EfNpcTask` maps three of them. The other twelve are the native entry
gate, checked before the task's action chain runs. Measured over our 9,010 rows, most of them are
inert in this data:

| Column | Rows away from default | Verdict |
| --- | --- | --- |
| `money`, `profession`, `metempsychosis`, `query` | 0 | never used |
| `sex` | 8,901 hold `999`, 109 hold `0` | both permissive; no real gate |
| `team` | 8,901 hold `999`, 109 hold `0` | both permissive; no real gate |
| `min_pk` / `max_pk` | 8,885 hold the wide-open `-100000..100000` | but **89 gate on `0..1000`** and **16 on `-100000..1030000`** |
| `itemname1` | **74** | real - names an item by name (`Meteor`, `DragonBall`, `PassToken1`) |
| `itemname2` | **2** | real |
| `marriage` | **2** | real |
| `client_active` | **3,251 hold `2`, 6 hold `1`** | real, three-valued; meaning NOT established |

So the ignored columns cost us **105 PK gates, 74 item-name gates, 2 marriage gates**, and a
`client_active` flag on a third of all tasks whose meaning has not been proven.

## The opcode name table

Long ships `cq_action_type`, 296 rows of `id -> name`, in TQ's own naming style
(`ActionMenutext`, `ActionUserStcCompare`). It is a community table from a later version and is
**not** treated as truth here. Its value is as a hypothesis map, and it is a good one: it names
**194 of the 204 opcodes** this database uses, covering **151,828 of 151,854 rows**.

It agrees with all twenty opcodes proven independently here, including the four that rest on
coherence arguments over the shipped data rather than on a client witness:

| id | Proven here | `cq_action_type` |
| --- | --- | --- |
| 502 / 503 | ConsumeItem / RequireItem | `ActionItemDel` / `ActionItemCheck` |
| 1073 / 1074 | statistic read / statistic write | `ActionUserStcCompare` / `ActionUserStcOpe` |
| 1080 / 1081 | stamp time / check elapsed | `ActionUserStcTimeOperation` / `ActionUserStcTimeCheck` |
| 1056 / 1057 / 1058 | task record, its fields, its time | `ActionUserTaskManager` / `ActionUserTaskOpe` / `ActionUserTaskLocaltime` |

Ten opcodes it does not name, all rare: 0 (13 rows), 224 (4), 1070 (2), and 721, 1726, 2014, 2201,
2202, 2203, 3907 (1 each).

## The missing table for 1056/1057/1058

Both Canyon and Long carry **`task_detail`**, which is the per-character task record this database
has no home for:

```
user_id, task_id, complete_flag, notify_flag,
data1 .. data7, task_overtime, type, max_accumulate_times
```

That is a direct fit for what the shipped scripts do with it - `complete == 1`, `complete set 2`,
`data1 set 0` (1057) and `time set 0`, `interval(1) >= 1` (1058). The column names come from those
two projects, so the shape is corroborated but not native-proven; what the scripts require of it
is proven from our own data.

## cq_npc - one real duplicate, removed

The shipped quest table settles a stack this database has carried all along. **NPC 1060 `Guide`
and NPC 5672 `RecruitMaster` both sat on map 1010 tile (62,105)** with the same lookface 2610 and
the same task0 9588020 - two NPCs, one tile, one script, one appearance.

The pristine `Questinfo.ini` references **5672 `RecruitMaster` at exactly (1010,62,105)** and never
mentions 1060. 1060 is the later-version name for the same NPC, carried in by the post-6192 dump -
and consistently, LongV6270 has 1060 but not 5672. The edit to `Questinfo.ini` described above was
precisely this swap, applied to six missions.

Nothing in the database references 1060 as an NPC: `cq_action.data`, `cq_npc.linkid` and
`cq_goods.ownerid` all return zero. Fifteen `cq_action.param` rows contain the digits 1060 and all
fifteen are false positives - eight are map id 1060 in a 301/1003 parameter list, seven are the
value 1060 in an `stc(46,4)` comparison.

Migration `20260831_07` deletes 1060 and reverts the eight `cq_questtype` cells to the pristine
file. **This is the only duplicate of its kind**: outside map 5000 there is exactly one tile
carrying two NPCs with the same lookface, and exactly one with the same task0, and both are this
pair. Map 5000 is `NPCJail`, where stacking is by design. Repeated names elsewhere - `ShopFlag`
144 times, `StageGuard` and `LonelyGhost` 25 - are deliberate multiples on distinct tiles.

### What is NOT fixed, and why

The shipped quest table names 117 NPC ids. Only **18** match `cq_npc` on both name and position;
**72 are absent from `cq_npc` entirely**, **5 names disagree** and **26 positions do**. These are
not corrected, because for most there is no proof the two sides mean the same NPC: id 13 is
`GuruTodd` here and `Tommy` on another map in the client, id 400 is `StormMaster` here and
`ArcherGod` there, id 7935 is `CharacterNameEditor` here and `ChefCarr` there. The position deltas
are not a uniform offset either - they cluster near (128,100) on map 1002 but range from (1,1) to
(139,102), and four NPCs sit on a different map altogether.

## Player data cleared, four tables dropped

Migration `20260831_08`. Every per-character row in the database was an **orphan** - not one
belonged to a character that existed:

| table | rows | orphaned |
| --- | --- | --- |
| `cq_item` | 296 | 296 (294 owned by dump players 1004438-1004451, `DaRkFox[PM]`, `EasyLoot`) |
| `cq_magic` | 15 | 15 |
| `cq_questinfo` | 15 | 15 (uid 1-5) |
| `cq_weapon_skill` | 4 | 4 |
| `character_missions` | 3 | 3 |
| `cq_arena` | 2 | 2 |
| `cq_statistic` | 2 | 2 |
| `cq_carry` | 1 | 1 |
| `dyna_rank_rec` | 1 | 1 |

The seven `cq_user` rows were the local test characters, all level 1, all with valid accounts.

**Dropped**: `oc_character_recordpoint` (0 rows), `oc_admin_commands` (0), `npcscript` (1 - an NPC
editor's table), `character_missions` (3). None is created by any migration, none appears in the
nineteen tables the server maps, none appears in any raw query.

**Kept, against the request**: `oc_character_task_records`. It holds no rows but it is not leftover
test data - migration 20 created it as the storage contract for opcodes 1056-1058 and the readiness
validator asserts its ten columns. Dropping it would make the server refuse to start.

**Kept, deliberately**: `player_permission_types` (7 rows). It is the lookup `accounts.permission`
points at under a RESTRICT foreign key.

The whole database has five foreign keys. Two shaped the order: `accounts` is RESTRICT-referenced
by `cq_user`, so characters go first; and both `accounts` and `cq_user` are foreign-key parents,
which MySQL will not let `TRUNCATE` touch, so every statement is a `DELETE`. AUTO_INCREMENT
counters are left where they are - where the next character id starts is server behaviour, not
cleanup.

## What the two reference servers do with cq_action

They run it. Both load the whole table and dispatch on the native opcode:

* `ActionRepository.GetAsync()` in Long is literally
  `SELECT * FROM cq_action UNION ALL SELECT * FROM cq_newaction ORDER BY id ASC`;
* an NPC click reaches `GameAction.ExecuteActionAsync` through `MsgNpcInfo.cs`, and a dialog reply
  through `MsgTaskDialog.cs:177`, which is
  `ExecuteActionAsync(user.TestTask(task) ? task.IdNext : task.IdNextfail, ...)` - `cq_task`
  driving the dialog, entry gate and all;
* Canyon's `GameAction.cs` switch carries **570 `case` labels**.

Lua is **two opcodes** inside that switch - `ActionLuaLinkMain` and `ActionLuaExecute`, in the
"Lua > 20000" region - which turn a `param` into a Lua call. It is how those projects author *new*
content; it is not what runs the shipped data. Neither project transpiled `cq_action`.

## The recommendation

Keep `cq_action`/`cq_task` as the execution model.

* It is the model the 5517 client speaks. `MsgTaskDialog 2032`, its option list and its 8-line /
  8-option assertions are shaped by this graph, and every opcode semantic proven so far is
  expressed in its terms.
* It is the only quest content that exists - 151,854 rows, reproduced by no client file.
* Transpiling requires the work already in progress: you cannot translate an opcode you have not
  proven, and a conversion done now would freeze today's partial understanding into the new source
  of truth.

The version drift wants a load-time gate, not a rewrite: resolve every item reference in
`cq_action` against `cq_itemtype` at startup and refuse to arm an action naming an item the
catalogue lacks. That covers the 286 reachable cases without touching the other 151,568 rows.
Deleting those rows would be worse than leaving them - an `id_next` pointing at a deleted row
becomes a new dangling reference.
