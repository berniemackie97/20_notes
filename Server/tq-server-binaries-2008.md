# TQ server binaries — CQServer 15.10 (2008-10-21)

Verified 2026-10-12. Raw packages: `50_server/binaries/`. Working set + IDA DBs: `50_server/binaries/_re/`.
Historical server evidence. The exact compatible game-build era is unknown. The 5517 client executable is authoritative for client behavior. This server uses a different login protocol. See [era evidence](#era-cp02-2026-11-05).

## Canonical set (`_re/`)

| File | Copied from | SHA-256 (16) | PE time (UTC) | IDA funcs / FLIRT lib |
|---|---|---|---|---|
| `MsgServer.exe` | `ZFSERVER/GameServer/msgserver_beckup.exe` | `48749fc1ede8783e` | 2008-10-21 10:52:52 | 6587 / 1054 |
| `NpcServer.exe` | `zfserver-1/GameServer/Npcserver.exe` | `8c98ffec09382bc4` | 2008-10-21 10:52:27 | 2908 / 732 |
| `Root.dll` | `ZFSERVER/GameServer` | `671fd0141b3a7108` | 2008-10-21 10:52:29 | 546 / 276 |
| `Training.dll` | 〃 | `718d561f5a3fcc0e` | 2008-10-21 10:52:36 | 394 / 270 |
| `Lottery.dll` | 〃 | `916ffe5dfc377cc5` | 2008-10-21 10:52:40 | 515 / 288 |
| `Guide.dll` | 〃 | `dda214df03c2fb04` | 2008-09-27 09:52:42 | 805 / 350 |
| `Peerage.dll` | 〃 | `9200de755038ac50` | 2008-09-05 09:23:14 | 427 / 221 |
| `Rank.dll` | 〃 | `d72e06f3c79c80ea` | 2008-08-21 10:23:11 | 834 / 344 |
| `Flower.dll` | 〃 | `e63e80321f30241a` | 2008-08-13 14:14:24 | 682 / 356 |
| `Pigeon.dll` | 〃 | `692b4ef5d2c5b854` | 2008-08-07 10:21:53 | 425 / 226 |
| `DB.dll` | 〃 | `6134555f4a944003` | 2008-07-14 08:54:39 | 526 / 233 |
| `Common.dll` | 〃 | `a5a2f9619a2f1504` | 2007-12-17 12:18:44 | 383 / 253 |
| `libeay32.dll` | 〃 | `e68d228688ba0254` | OpenSSL 0.9.8g | — |
| `libmySQL.dll` | 〃 | `975e31cdd63666d5` | — | — |

Plugin DLLs: byte-identical in every package. Clean MSVC6 (linker 6.0, Rich header, `.reloc`).
Image base `0x400000` for both EXEs.

## Build identity

- Version resource `2007, 1210, 0, 123` / "Dec. 10, 2007" on every copy → not a build discriminator.
- Source root `D:\CQServer-15.10-1021\` (MsgServer, NpcServer, Root.dll).
- `__DATE__`/`__TIME__`: `Oct 21 2008` @`0x5096D0`, `18:52:45` @`0x5096DC`.
- Older clean build for era diff: `Remakes/Conquer/Servers/Sources/ZfServer/GameServer/MsgServer.exe` —
  root `D:\CQServer-12.3-0419\`, PE 2008-04-18, 1,126,400 B, SHA `38c676e1…` (see `zf-map-reconciliation-5517.md`).

## MsgServer copy census

Code `0x401000–0x4E93E7` byte-identical across all copies except GolDeN_X OEP stub.

| Path | Size | SHA (16) | State | Delta vs canonical |
|---|---|---|---|---|
| `ZFSERVER/GameServer/MsgServer.exe` | 1,451,501 | `f3cd9ab000253feb` | packed (`.hammy`, 19 imports) | parent of the dumps |
| `ZFSERVER/GameServer/msgserver_beckup.exe` | 2,386,963 | `48749fc1ede8783e` | ImpREC dump (`.textbss`+`.mackt`) | **canonical** |
| `zfserver-1/GameServer/Msgserver1.exe` | 2,387,456 | `53ee7323915d66eb` | ImpREC dump | image identical `0x1000–0x12C000`; `.mackt` only |
| `ZfServer-2/GameServer/Msgserver.exe` | 2,386,963 | `36e06dd837834d71` | dump + rebrand | `Conquer`→`Angell.` @`0x50876C`; date→`Sep 03 2010 19:35:53` @`0x5096D0` |
| `zfserver-1/GameServer/Msgserver.exe` | 3,608,576 | `eaf69a1c62e226fa` | dump re-protected (random section names) | code identical |
| `Zfserver(GolDeN_X)…/GameServer/MsgServer.exe` | 1,810,604 | `ac40477068742811` | original layout + protector (`.rrdata`, overlay 159,916) + "ramy4co" rsrc | OEP stub 269 B @`0x4BBCFE`; key→`0109494016123456` @`0x4EDF2C`; `2.0`→`202` in string @`0x51E35C`; `.rsrc` replaced |

GolDeN_X keeps the original import directory (dump's import-name area `0x505718+` is packer garbage) — source of the section map and IAT names below.

## NpcServer copy census

| Path | Size | SHA (16) | State | Delta vs canonical |
|---|---|---|---|---|
| `zfserver-1/GameServer/Npcserver.exe` | 417,792 | `8c98ffec09382bc4` | original layout, Rich, TQ rsrc, OEP intact | **canonical** |
| `ZFSERVER/GameServer/Npcserver.exe` | 458,069 | `3206ed75581bddf8` | ImpREC dump | 1,892 code bytes = IAT-slot remaps only; data identical outside import area |
| `ZfServer-2/GameServer/Npcserver.exe` | 458,069 | `094ba1e047f97e70` | dump + rebrand | `Angell.` @`0x459704`; date `Sep 03 2010` @`0x459870`; `"no use"`→`"Angell"` @`0x45CB76` |
| `Zfserver(GolDeN_X)…/GameServer/Npcserver.exe` | 847,872 | `e5b23c616b08d04b` | protector + "ramy4co" rsrc | OEP stub 237 B @`0x41E6E4` |

`zfserver-3` = byte duplicate of `zfserver-1`.

## MsgServer IDB fixups (applied, `_re/scripts/ida_build_msgserver.py`)

| Segment | Range | Class |
|---|---|---|
| `.text` | `0x401000–0x4EA000` | CODE |
| `.idata` (IAT, loader) | `0x4EA000–0x4EA5A0` | XTRN |
| `.rdata` | `0x4EA5A0–0x508000` | CONST |
| `.data` | `0x508000–0x52C000` | DATA |
| `dumptail` | `0x52C000–0x766000` | DATA — packer/BSS remainder, contents unclassified |
| `.mackt` | `0x766000–0x768000` | ImpREC import dir |

IAT name fixes (ImpREC picked aliased export): `0x4EA140` = `SetHandleCount` (ImpREC `LockResource`);
`0x4EA408` = `RegisterWindowMessageA` (ImpREC `RegisterClipboardFormatA`). Other 28 name diffs = `A`-suffix
aliases or libeay32 ordinals, same import.

## Era deltas vs 5517 client

| Item | Server 15.10 | 5517 client |
|---|---|---|
| Game cipher | libeay32 #46 `BF_set_key`, #41 `BF_cfb64_encrypt` → Blowfish CFB64 | CAST5 CFB64 (`Crypto/00_tqcipher64.md`) |
| Fixed key | `DR654dt34trg4UI6` @`0x4EDF2C` (xrefs `0x4A3BFD`, `0x4A3CB0`); same in 2008-04 build | `BC234xs45nme7HU9` |
| Seals | `TQClient` @`0x4EDF14`, `TQServer` @`0x4EDF20` (xref `0x4A3BCA`); also `0x4EDE60`/`0x4EDEB8` | same strings |
| DH | imports `DH_*`, `PEM_read_bio_DHparams`; `dh.pem` shipped | DH present |

Ordinals resolved against bundled `libeay32.dll` exports.

## Open

- Runtime semantics traced so far (shops, actions/tasks, generators, map cells): [tq-server-15.10-runtime-semantics.md](tq-server-15.10-runtime-semantics.md).
- World topology, AccountServer link, capacity: [historical-multi-server-topology.md](historical-multi-server-topology.md).

- Accepted client version: `CMsgConnect__Process` `0x4B0688`: language-gated 2-byte compare at `+10` → `STR_ERROR_VERSION`;
  word `+8` < `0x7B` (123) → `STR_ERROR_LOWER_VERSION` (`0x52079C`, used `0x4B0847`). Floor only, not a patch number.

## Excluded

- Account servers — not TQ: `CoAccountServer.exe` (.NET + MySql.Data), `AccServer.exe`, `EACC1.03.exe` (E-language, `krnln.fne`).
- `zfserver-1/GameServer/GameServer.exe` = `ForGameServer.exe`: 5.3 MB, 5.2 MB overlay, VC9 2010, no version info — launcher.
- `ZFSERVER/GameServer/ConquerAimbotHook.dll`: 12 bytes.
- Each package bundles a private `zf` MyISAM DB (101–109 tables) → data rules in `database-provenance.md`.

## Era (CP0.2, 2026-11-05)

Proven: `__DATE__` `Oct 21 2008`; source root `CQServer-15.10-1021`; walk = 1005, action = 1010 (5517: 10005/10010);
Blowfish game cipher; client floor `+8 ≥ 0x7B`. **No client patch number in MsgServer or NpcServer** (raw string scan).
The exact compatible game-build era is **unknown**. The `≤5095` and `~518x` estimates remain unverified. Tag findings from this binary set `historical`.

## Thread / timer model (MsgServer, historical, CP0.2 2026-11-05)

Per-thread pass functions (IDA function comments set, names left `sub_`; class/method names not proven by this binary):

| Fn | TU (assert) | Timer | Pass |
|---|---|---|---|
| `0x401153` | `MapGroupThread.cpp` | **500 ms**, `next += 500`; \|drift\| > 10 s → resync + log | drain port (buf 1048) → MapGroup `ProcessMsg`; break after 15000 ms (checked every 512 msgs); then MapGroup `OnTimer(now)` |
| `0x404DF6` | `WorldThread.cpp` | **1000 ms**, same drift rule | World `OnTimer(now)`; port wait 400 |
| `0x40475D` | `SocketThread.cpp` | **1000 ms**, same drift rule | socket `OnTimer`; socket process; port wait |
| `0x404ACF` | `UserLoginThread.cpp` | none (every pass) | UserKernel `OnTimer(now)`; port wait 400 |

- `0x408168`: profiler label table (`CUserManager::OnTimer()`, `CMapManager::OnTimer()`, `CRoleManager::OnTimer()`, …) — **not** a dispatcher.
- `0x421383`: per-user periodic routine (virtual, no direct callers). Literals: CATCH `CUser autoheallife timer crash`
  (`0x50E1C4`, `0x50E1D8`), deadloop label `m_dequeServerTick`, thresholds 30000 / 75000 ms. Semantics untraced → roadmap CP5.1.
- NpcServer (`KernelThread.cpp`, `CNpcWorld::OnTimer`, named `NpcServer__OnTimerStateMachine` `0x408175`): loop cadence untraced.

## Source TU inventory (asserts, historical)

**MsgServer.exe** (144 `.cpp`):

- `Comm/source`: InternetPort MessagePort
- `Common`: BaseFunc IniFile MyHeap StringManager
- `GameBaseCodeMT/source`: MyConstRecord MyDatabase MyRecord MyRecordset
- `MapData/source`: Cell MapData MapDataPath TerrainObj TerrainObjPart
- `MsgServer`: MapGroupThread MsgServerDlg SocketThread UserLoginThread WorldThread
- `MsgServer/Adapter/Src`: Adapter FlowerActor GuideActor LotteryActor LotteryPrize PeerageActor PigeonActor RankActor Responder TrainActor
- `MsgServer/LockLib`: ServerLock
- `MsgServer/MapGroupKernel`: AINpc BattleSystem BetOutside Booth ClientDetector Detain DisdainDataSet Enemy EventPack Friend FriendData FuseItem GMToolCfg GameAction GameBlock GameMap Item ItemAddition ItemData ItemType LeaveWord Magic Magic_Process MapGroup MapGroupKernel MapItem MapManager MapTrap Npc NpcLink NpcManager NpcScene NpcStorage NpcTask Package PoliceWanted RoleManager SquareDeal Status StatusData StatusMore StatusOnce SynAttr SynManager Syndicate Team TradeBuddy Transformation User UserData UserInfo UserKernel UserManager UserTeam UserWeaponSkill User_Item User_Task WantedList Weather WeatherRegion
- `MsgServer/MapGroupKernel/Network`: MsgAction MsgAiNpcInfo MsgBetOutside MsgCallPetInfo MsgDataArray MsgDetainItemInfo MsgDialog MsgEquipLock MsgFlushExp MsgFriend MsgFriendInfo MsgInteract MsgInviteTrans MsgItem MsgItemInfo MsgItemInfoEx MsgMagicEffect MsgMagicInfo MsgMapInfo MsgMapItem MsgName MsgPackage MsgPlayer MsgSynAttrInfo MsgSynMemberInfo MsgSyndicate MsgTalk MsgTeam MsgTeamAward MsgTrade MsgTradeBuddy MsgUserAttrib MsgUserInfo MsgWalk MsgWeather NetMsg NetMsgTracker
- `MsgServer/ServerSocket`: SSocket ServerSocket
- `MsgServer/WorldKernel`: ClientSocket MapList MessageBoard SupermanList SynWorldManager SynWorldShell UserList WorldKernel
- `MsgServer/WorldKernel/NETWORK2`: MsgDialog MsgMessageBoard MsgName MsgTalk MsgTime NetMsg

**NpcServer.exe** (53 `.cpp`):

- `AiModule/source`: AiCenter FactSet RuleSet Syntax
- `Comm/source`: InternetPort
- `Common`: BaseFunc IniFile MyHeap StringManager
- `GameBaseCodeMT/source`: MyConstRecord MyDatabase MyRecord MyRecordset
- `MapData/source`: Cell MapData MapDataPath TerrainObj TerrainObjPart
- `NpcServer`: ClientSocket KernelThread NpcServerDlg
- `NpcServer/NpcKernel`: Agent Body DynaNpcGen GameMap Item ItemPack ItemType MapManager Npc NpcGenerator NpcManager NpcType NpcWorld RoleFight RoleMove Sense SynManager Team User UserManager
- `NpcServer/NpcKernel/NetWork`: MsgAction MsgAiNpcInfo MsgInteract MsgItem MsgItemInfo MsgLogin MsgPlayer MsgSyndicate MsgTalk MsgUserInfo MsgWalk NetMsg

