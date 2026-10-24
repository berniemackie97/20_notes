# zf.sql map reconciliation against native 5517 evidence

**Superseded for the map list by [map-catalog-5517.md](map-catalog-5517.md)** (2026-10-10): 1501→1730 and
1778→1013 now sourced from TQ-English data; 1778 is a native world ID (GameMapEx DangerCave), so its
portals must stay. `practical-map-*.json` in the bundle is the superseded working profile.

Verified 2026-10-10. Evidence/documentation only. No SQL imports, migration/source changes, native patches,
Binary Ninja saves, commits or PRs. The existing native analysis is reused; no additional native rename
is warranted by database comparisons.

## Finding

The supplied `Archives/zf.sql` is **demonstrably customized for a server named Wolf-War**. This is a
conclusion from its contents, not a presumption based on its filename. Its earliest upstream lineage,
author, exact target client patch, and retail authenticity of individual inherited rows remain unknown.
It is useful comparison evidence, but does not authenticate a retail 5517 map catalog.

It has 306 unique `cq_map` records. Compared with either 273-row requested dump, 153 IDs are shared,
153 occur only in zf, and 120 occur only in the other dump. Among shared IDs, 17 mapdoc values and 90
flags differ. Compared with the documented 276-row reconstruction, 156 IDs are shared, 150 are zf-only,
120 reconstruction-only, 12 mapdoc values differ, and 93 flags differ. The complete union is 426 IDs.
Every row and shared column is reconciled, including names, descriptions, revive coordinates, ownership,
links and color. zf lacks the other schema's `file_name` column; schema absence is recorded separately
from a value conflict.

The unresolved claims concern exact retail configuration, not the mechanics of loading maps. The
native client proves terrain decoding and separately received world ID, terrain key and flags. A
working server can use the reconstructed configuration; calling every assignment and rule the
original retail 5517 configuration requires evidence beyond terrain bytes.

## Provenance and version

| source | bytes | SHA-256 |
|---|---:|---|
| zf | 401788832 | `5017530f725b4ecab69d89044853bc459a18507fe955a7c1bd9160b2be36bd16` |
| conquer | 15160990 | `b9bb29cdc3c46bf18ede390fc3fbd790167813a71f82539b4c34a57d6d938ea4` |
| ConquerServerDB | 15161438 | `9cdd38067c2a15cf9ee9ffc4601746b165f6ac34ed7a8323003b4e3882add41e` |

The supplied path is
`/Volumes/EnderChest/Development/Repos/GameDev/Remakes/Conquer/Archives/zf.sql`.
The nearby `zf.rar` is 19,170,224 bytes, SHA-256
`804bb67335318e3be1d83161c349ca0bf51e6a48853f8f27f56e693b71615332`.
Its sole member `zf.sql` extracts to exactly the supplied file (size, SHA-256 and CRC32 `C7A14204`
match). The RAR records `2012-12-02 15:13:08.3281250`; the SQL header says Navicat MySQL Data
Transfer, source/target `localhost:3306`, database `zf`, date `02/12/2012 03:06:30` followed by
byte `E3`. December 2 is consistent with the archive timestamp, but neither timestamp authenticates
creation, timezone or client version. The header provides no MySQL server version or client patch.

There are 105 CREATE TABLE definitions. `cq_map` has 22 columns, primary key `id`, index
`(idxserver,mapgroup)`, and `TYPE=MyISAM`; its `id`, `mapdoc` and `type` are unsigned INT.
`INT(4)` has 32-bit storage; `(4)` is display width, as specified by the
[MySQL integer documentation](https://dev.mysql.com/doc/refman/8.0/en/integer-types.html) and
[numeric syntax documentation](https://dev.mysql.com/doc/refman/8.4/en/numeric-type-syntax.html).
No schema syntax or reused table name identifies a precise game patch.

Modification evidence includes 2,578 action rows mentioning Wolf-War. Action 36565651 explicitly
calls it a private server (original line 97629); action 1901 does likewise (line 97857); actions 3/4
thank the player for using that server (lines 30127/30128). Schema also includes voting-related
structures. These establish customization of the dump as a whole, **not fabrication of every map row**.
Old official patch URLs and Monk dialogue coexist in its actions; neither dates the underlying
map records or establishes the intended client protocol. Exact tuples and byte spans are in
[provenance findings](../../10_work/docs/evidence/zf-map-reconciliation-5517/zf-provenance-findings.json) and [raw excerpts](../../10_work/docs/evidence/zf-map-reconciliation-5517/raw/zf-provenance-excerpts.sql).

Online research found no hash-linked original distribution or author for this 401MB file. A 2009
forum attachment named `zf.rar` is listed as 4.04MB and is only a filename collision, not provenance.
The [FoxConquer project](https://github.com/darkfoxdeveloper/FoxConquer5517) describes itself as a 5517
emulator based on WorldConquerV2. Its separate 9,212,428-byte database matches public Git blob
`5f8f6769d398f10278d9c9a5b54deaaa5b4f897c`, introduced by
[commit 8448dc4801dc87c4efa9c9504ae06819bba0e747](https://github.com/darkfoxdeveloper/FoxConquer5517/blob/8448dc4801dc87c4efa9c9504ae06819bba0e747/Database/zf.sql)
(2020-04-26). **All 273 normalized map rows, all 23 columns, are identical to conquer.sql and
ConquerServerDB.sql.** This establishes shared map content; it does not establish the copying direction,
independent corroboration or retail origin. [Online evidence](../../10_work/docs/evidence/zf-map-reconciliation-5517/web-research.json),
[blob verification](../../10_work/docs/evidence/zf-map-reconciliation-5517/fox-online-provenance.json), [local sources](../../10_work/docs/evidence/zf-map-reconciliation-5517/sql-map-source-inventory.json).

The local search covered 2,314 SQL paths under the requested Repos root and found 47 files with a
`cq_map`, `map` or `maps` schema, representing 30 distinct file hashes. Ten unique files contain populated
`cq_map` tables. Other map schemas are retained as written, without pretending their fields have
identical semantics. The 216-row Albetros snapshot shares 216 IDs with zf: 214 mapdocs, 203 flag values
and 173 complete shared-column rows match. That supports shared legacy content, without authenticating
it. Later LongV6270 and CanyonV6192 dumps have identical 256 `(id,mapdoc,type)` triples; both include 91
rows with upper-dword bits. Their folder/project lineage and modern dump headers do not establish
5517 applicability. [Supporting rows](../../10_work/docs/evidence/zf-map-reconciliation-5517/supporting-map-sources.json),
[lineage comparison](../../10_work/docs/evidence/zf-map-reconciliation-5517/supporting-lineage-comparison.json).

## Exodus and the older Windows server package

`Servers/Sources/ExodusBinaries.zip` is a **RAR v4 archive despite its .zip extension**:
334,929 bytes, SHA-256 `19eb6e56ec5516cd2d647b9e28224a6231714fcc266e6cbbda268df626ee69ac`.
Its 114 entries comprise 75 files, including 58 C# sources, a .NET Framework 3.5 project and managed
build outputs. The main EXE has a nonzero CLR directory (RVA `0x2008`). Member timestamps and the
assembly copyright indicate 2010-era material, not an authenticated game patch. Source readers query
an external `cq_npc`, `cq_action`, `cq_task` and `cq_user` database. **There is no SQL dump, MyISAM table
or `cq_map` source reader in this archive.** The occurrence of `1501` in its action enum means
`ACTION_TEAM_CHK_ISLEADER`, not a world-map assignment. This archive supplies no additional map rows.
The adjacent `ExodusBinaries5290.rar` also has no bundled SQL/MyISAM/database member. Its filename does
not establish the patch of the first archive. The separate `zfserver v2.5517.zip` and `v2.5103.zip`
packages have C# sources/build output and no enumerated database-file members.

A [2010 community discussion](https://www.elitepvpers.com/forum/co2-private-server/656041-whats-good-public-source-i-could-use-2.html)
describes Exodus as using the binaries' database. This is consistent with the source readers, but
is supporting context rather than a hash-linked identification of this exact archive.
[Package inventories and hashes](../../10_work/docs/evidence/zf-map-reconciliation-5517/server-package-inspection.json), [source witnesses](../../10_work/docs/evidence/zf-map-reconciliation-5517/exodus-source-witnesses.json),
[PE identities](../../10_work/docs/evidence/zf-map-reconciliation-5517/server-pe-identities.json).

**The useful older native package is `Servers/Sources/ZfServer.7z` and its extracted `ZfServer/` directory.**
Its `MsgServer.exe` is a 1,126,400-byte x86 PE without a CLR directory, SHA-256
`38c676e1db7e9918ca354cd1372d87e77ce0edd28373a2524e04689a709e8351`.
The version resource states TQ Digital Entertainment / Conquer Online Server,
`2007, 1210, 0, 123`, comment `Dec. 10, 2007`; the PE timestamp is `2008-04-18T18:52:47Z`.
`NpcServer.exe` is 405,504 bytes, SHA-256
`6d2761ac6a5b27756cdeaa610c4edb42db583374a1df118be3c06b7fd7c48dd5`, with matching product version
and PE timestamp `2008-04-18T18:52:21Z`. Resource value offsets and raw identities are recorded.
These are **embedded metadata claims, not proof of an untouched retail release or 5517 protocol**.
The package also includes a much newer `TQAccServer.exe` with a 2020 PE timestamp and .NET apphost
metadata; the distribution is a mixed package. No bundled server or setup instruction was executed.
Other located TQ server binaries identify themselves as Eudemons/魔域 and are not Conquer authority.

`ZfServer/MYSQL/data/cq/cq_map.MYD` contains **202 fixed records of 211 bytes**, with a 22-column
`cq_map.frm`. The data/schema/index members are byte-identical in `ZfServer.7z`, its extracted directory,
and `Archives/cq.zip`. The nine archive-member comparisons are recorded individually: three table members in each
archive, plus three executables in ZfServer.
The map data is 42,622 bytes; FRM is 9,272 bytes; MYI is 8,192 bytes.
[Raw map table files](../../10_work/docs/evidence/zf-map-reconciliation-5517/raw/old-zfserver), [physical field schema and hashes](../../10_work/docs/evidence/zf-map-reconciliation-5517/old-zfserver-map-schema.json).

The decoder follows MySQL's documented old-FRM handling in
[`sql/table.cc`](https://github.com/mysql/mysql-server/blob/mysql-5.0.96/sql/table.cc),
[`sql/field.h`](https://github.com/mysql/mysql-server/blob/mysql-5.0.96/sql/field.h) and
[`myisam/mi_statrec.c`](https://github.com/mysql/mysql-server/blob/mysql-5.0.96/myisam/mi_statrec.c).
FRM form offset `0x2000`; 22 descriptors at file offset 8835, 11 bytes each; names at 9077.
Record offsets: `id=+2`, `name=+6` (15 bytes), `describe_text=+21` (127 bytes),
`mapdoc=+148` (uint32 LE), `type=+152` (uint32 LE). The first two bytes hold the fixed-record
status/null bitmap; nullable fields consume bits 1..13 in schema order. No deleted records occur.
The decoder records all remaining columns, descriptors, null bits and per-row byte offsets/hashes.
It does not infer field meanings from byte resemblance.

**All 202 rows and all 22 columns exactly match**
`Conquer Online/Databases/cq.sql` (11,787,418 bytes, SHA-256
`f06f56e580e4b4e4a2495e660e0c82c851eb01c31250b57d643947612c15780e`), after decoding that SQL
export's UTF-8 text and removing MyISAM CHAR padding. This corroborates map-table identity;
it does not establish that all other tables or their snapshots are identical.
[Every decoded row](../../10_work/docs/evidence/zf-map-reconciliation-5517/old-zfserver-map-rows.json), [202-row SQL equality check](../../10_work/docs/evidence/zf-map-reconciliation-5517/old-zfserver-vs-cq-sql.json).

Against the 306-row zf dump, 200 IDs are shared: **all 200 terrain assignments agree**, while 19 flags
differ. IDs 1760/1761 occur only in the older 202-row table; 106 IDs occur only in the 306-row dump.
This establishes substantial shared map content, without proving copying direction or retail origin.
Against either 273-row dump, 123 IDs overlap, 11 terrain assignments and 76 flags differ.
Against the 276-row reconstruction, the same 123 overlap, with 6 terrain-assignment and 76 flag conflicts.
[Full supplementary row comparisons](../../10_work/docs/evidence/zf-map-reconciliation-5517/old-zfserver-map-comparisons.json).

The old table supports the same five historical corrections (`1051`, `2021`–`2024`), but contains no
world IDs `1500`, `1501`, `1502` or `2080`. Its flag column is physically 32-bit; the maximum stored mask
is 43,362. **It supplies no missing 64-bit flag word and does not settle world 1501.** The MySQL table
field width describes this old database, not the later native 5517 packet's 64-bit flag contract.

## Requested map questions

| world MapId | zf mapdoc | reconstructed mapdoc | result |
|---:|---:|---:|---|
|1051|1079|1079|corroborates historical candidate|
|1500|absent|1734|no assignment evidence from zf|
|1501|absent|1501 retained|still unresolved for retail 5517|
|1502|absent|1735|no assignment evidence from zf|
|2021|1501|1501|corroborates historical candidate|
|2022|1500|1500|corroborates historical candidate|
|2023|1501|1501|corroborates historical candidate|
|2024|1500|1500|corroborates historical candidate|
|2080|absent|700|no assignment evidence from zf|

zf agrees with **five of the eight corrections**, and has none of the other three IDs. Its own six
1051 portals and 64 mine traps reproduce the same native base-cell results: 1051 0/6→6/6;
2021,2023,2024 0/16→16/16; 2022 12/16→16/16. Agreement and coordinate fit do not establish retail
server provenance. [All target rows](../../10_work/docs/evidence/zf-map-reconciliation-5517/target-map-findings.json),
[873 coordinate checks](../../10_work/docs/evidence/zf-map-reconciliation-5517/target-coordinate-checks.json).

**1501:** zf has no static or dynamic map row for world 1501, no enumerated explicit world-map reference,
no literal reference under the documented action interpretations, and no lexical action candidate for 1501.
Its nine rows using `mapdoc=1501` refer to the native mine-b terrain key; they do not define world 1501.
In conquer.sql, NPC 664 is at (84,60), and action 3554691/type 1003 targets (78,59). Both points remain
walkable on mine-b/key 1501 and fairylandPK-02/key 1730. Two additional legacy references are now recorded:
action 3000124/type302/data1501 checks `alive_user == 1`; action 3000298/type303/data1501 announces
“The Water Taoist PK War has started!” These provide legacy usage context, not a numeric terrain binding.
Their original tuple offsets are 850692,855102 and 906105 respectively (all on the multirow SQL line 240).
The historical claim that only the two coordinate-bearing records reference 1501 is therefore too narrow.
Later Long/Canyon rows propose 1501→1730 with flags `0x0030010C40150007`, but cannot settle retail 5517.

**Flags:** zf has 38 distinct nonzero masks, maximum 108898 (`0x1A962`); none has any upper-dword bit.
All primary dump flag columns are 32-bit. Widening those columns preserves their values but cannot
recover unknown high bits. zf contains 60 type 306 map-attribute actions and no type 305 action rows;
their literal `type test` masks and contextual `status reset 1` provide no missing high-dword mask.
Action interpretation is explicitly emulator evidence; no executable has been proven to match the
306-row Wolf-War dump. The separately inspected older ZfServer package is not assumed to be its runtime.
[All masks and memberships](../../10_work/docs/evidence/zf-map-reconciliation-5517/flags-inventory.json), [state actions](../../10_work/docs/evidence/zf-map-reconciliation-5517/map-state-actions.json).

zf also supplies candidate flags 14,14,70 for the reconstructed additions 1782→1004,1783→1004,
1794→1028, whose reconstruction uses zero placeholders. These are **new legacy candidates**, not
recovered retail flags. Original zf lines 313640,313641,313648 / offsets 46309645,46309999,46312332.

## Complete differences and references

The seventeen terrain-key conflicts against either 273-row dump are:

| MapId | zf mapdoc | other dump mapdoc | native terrain relationship |
|---:|---:|---:|---|
|1051|1079|1051|different native paths|
|1080|1018|1080|same path; numeric keys still distinct|
|1081|1018|1081|same path; numeric keys still distinct|
|1511|1004|1511|same path; numeric keys still distinct|
|1550|1091|1550|different native paths|
|1551|1091|1551|different native paths|
|1969|1858|1969|different native paths|
|2021|1501|2021|different native paths|
|2022|1500|2022|different native paths|
|2023|1501|2023|different native paths|
|2024|1500|2024|different native paths|
|5000|1025|5000|same path; numeric keys still distinct|
|7000|700|1730|different native paths|
|7002|2024|1732|different native paths|
|7003|1734|1731|different native paths|
|7004|1050|1731|different native paths|
|8000|700|1001|different native paths|

All added/missing IDs and per-column differences are in the 426-row
[reconciliation](../../10_work/docs/evidence/zf-map-reconciliation-5517/map-reconciliation.json), [CSV overview](../../10_work/docs/evidence/zf-map-reconciliation-5517/map-summary.csv),
[full source rows](../../10_work/docs/evidence/zf-map-reconciliation-5517/map-rows.json), and [pairwise comparison](../../10_work/docs/evidence/zf-map-reconciliation-5517/pairwise-map-comparison.json).
No row was omitted because it appeared unchanged. All 175 non-identical zf world/terrain pairs are
present in the source rows. The four same-path conflicts are 1080,1081,1511,5000; companion values
are retained and compared separately.

| related table | zf rows | conquer/ConquerServerDB rows | shared equal | shared changed | zf-only | other-only |
|---|---:|---:|---:|---:|---:|---:|
|cq_dynamap|56|0|0|0|56|0|
|cq_portal|276|322|272|2|2|48|
|cq_passway|297|347|274|0|23|73|
|cq_npc|982|786|0|598|384|188|
|cq_dynanpc|1229|850|0|840|389|10|
|cq_generator|1759|1395|0|1115|644|280|
|cq_trap|485|473|473|0|12|0|
|cq_region|24|26|0|24|0|2|

“Changed” compares all shared row columns; it does not mean every NPC changed location. zf NPC schema
also has a `playerid` column absent in the other dump. Schema-only differences remain separately visible.
Portal 11 differs `(429,378)` versus `(403,394)`; portal 579 differs Y 1294 versus 1292. All 473 common
trap rows are identical. There are 3 ambiguous passway destination joins in each source; all are listed.
The two requested 273-row dumps have identical static related rows, not just identical map triples.

Every named map field in every schema was classified: actual world-ID candidates are distinguished
from `mapdoc` terrain IDs, `mapgroup` and portal indices. Persistent-player records are projected to
IDs/map fields only; accounts/passwords are not included. The action census separately records
3,114 zf and 2,405-per-other-dump opcode-selected candidates, including contextual/variable targets,
plus 7,569/15,885 lexical candidates. Numeric coincidence is never asserted to be a map reference.
The bounded opcode rules and their Fox source excerpts are included. Arbitrary SQL in action strings,
variables, dynamic maps, or overloaded NPC data fields require the corresponding server interpreter;
this report does not claim full gameplay reachability from static SQL.

[Reference rows](../../10_work/docs/evidence/zf-map-reconciliation-5517/reference-rows.json), [every row comparison](../../10_work/docs/evidence/zf-map-reconciliation-5517/reference-row-comparison.json),
[per-map references](../../10_work/docs/evidence/zf-map-reconciliation-5517/references-by-map.json), [unresolved joins](../../10_work/docs/evidence/zf-map-reconciliation-5517/unresolved-map-references.json),
[column census](../../10_work/docs/evidence/zf-map-reconciliation-5517/map-column-census.json), [action candidates](../../10_work/docs/evidence/zf-map-reconciliation-5517/action-map-references.json).

### Historical portal deletion needs reconsideration

zf explicitly defines 1778→1013(flags7),2204→1734(flags7),7007→1762(flags7), at lines 313635,
313672,313674 / offsets 46307873,46317635,46318058. All three terrain keys exist in native 5517.
This disproves an absolute “these IDs exist nowhere” assertion, but does not authenticate the rows.
Replaying the documented migration's deletion of their seven portal rows leaves passways 160 and161
pointing to missing `(map1778,portal_idx1/2)` destinations. The migration's orphan-portal check only
checks remaining portals against the catalog; it does not validate these passway joins.
This is a static reconstruction consequence, not a claim that a live database has those changes.
[Join results](../../10_work/docs/evidence/zf-map-reconciliation-5517/passway-portal-joins.json), [deleted rows](../../10_work/docs/evidence/zf-map-reconciliation-5517/reconstructed-removed-portals.json).
No migration was altered.

## Native 5517 cross-check

- `Conquer.exe!0x732B10` handles MsgMapInfo 1110: packet+4→world ID+E0 at 0x732B74;
  packet+8→terrain key+E4 at 0x732B89; packet+C/+10→flags+E8/+EC at 0x732BA1.
  Setter 0x61F2C3 copies both DWORDs. These independently received fields do not imply ID equality.
- `0x6206C8`/instructions 0x6206CD–0x6206CF mask the high DWORD with 0x40:
  qword `0x0000004000000000`, bit 38. None of the primary dump masks supplies it. A zero stored high
  word is not evidence that retail 5517 never sets it.
- `GameData.dll!0x10007678` parses GameMap.dat; 0x10007776 resolves exact terrain keys. The verified
 262-record/261-effective-key index supplies paths and companion values, not world mappings/flags.
  300/306 zf rows resolve to shipped 5517 terrain. Keys 1361,1362,1363,1738,2075,3055 do not exist in
  that index. This is a concrete incompatibility with those key values under the supplied client,
  not proof of the dump's age or wholesale inauthenticity.
- `Conquer.exe!0x61DC3D` reads the native DMap base grid. The new 873 coordinate comparisons use 18
  pristine terrain members whose encoded/decoded hashes were rechecked. Base-cell fit does not
  establish placement validity with overlays or authenticate server data.

Exact original binary identities, raw disassembly and prior instruction replay are linked by pinned
hash in [native evidence reused](../../10_work/docs/evidence/zf-map-reconciliation-5517/native-evidence-reused.json) and the maintained
[native contract](map-identity-flags-native-5517.md). Conquer.exe SHA-256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`;
GameData.dll SHA-256 `8168fd126234cbda52442dced750770ecf40d861d4b2aa483f08b91efa8c5077`.

## Verification and limits

An independent in-memory SQLite parser evaluated the **original map INSERT statements** and matched
every column of all 306+273+273 rows. All 389,078 selected source tuple witnesses and 279 schema
witnesses were rehashed against the original files. No duplicate primary map IDs were found. No
map/reference-table UPDATE/DELETE/REPLACE/ALTER was found in the three input dumps. The migration
replay matches all 276 previously documented identity/flag triples, and records changes to revive
fields and portal rows separately. No MySQL instance was changed. JSON values above 2^53−1 are
represented as decimal strings to avoid consumer precision loss.

Unresolved: the archive's original publisher/author and exact patch; which inherited map rows or
flag values came from retail; authoritative 1501 terrain; retail high flags; retail catalog completeness;
and runtime-generated/opaque server references. Proven customization does not invalidate every
inherited row, and repeated values across emulator descendants do not authenticate them.

[Validation](../../10_work/docs/evidence/zf-map-reconciliation-5517/validation.json) and [bundle README](../../10_work/docs/evidence/zf-map-reconciliation-5517/README.md) define the exact verification
scope and reproduction procedure. The older one-line `zf-map-cross-check.json` is superseded for
provenance by this investigation; its old file is preserved as historical evidence.
