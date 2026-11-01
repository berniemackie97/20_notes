# TQ multi-server topology (CQServer 15.10, 2008-10-21)

Verified 2026-10-12, headless IDA on MsgServer `48749fc1…f726`, NpcServer `8c98ffec…664f`
([census](tq-server-binaries-2008.md)). All names saved in the `.i64`. Class **VERIFIED_OLDER_VERSION_ONLY**
unless marked. Evidence: `10_work/docs/evidence/multi-realm-architecture-5517/historical-topology-evidence.json`.
Related: [runtime semantics](tq-server-15.10-runtime-semantics.md) (shops, actions, generators, map cells),
[multi-realm decision](multi-realm-architecture-5517.md).

## Shape

```
            client ──1060──► AccountServer (retail binary MISSING)
                                  ▲   │ 1052 pending login (account, key, info)
       1099 login, 1200/1201 ─────┘   ▼ 1200 kick, 1201 fee
   ┌──────────── world "SERVERNAME" ─────────────┐
   │ MsgServer ◄── NpcServer (1 per MsgServer)    │   × N worlds, each:
   │    │ SERVE_PORT (5816) clients + NpcServer   │   own game DB, own SERVERNAME,
   │    └── game DB (shell.ini [Database])        │   own process pair per host mutex
   └──────────────────────────────────────────────┘
```

## Configuration

| File / section | Keys | Reader | Meaning |
|---|---|---|---|
| `shell.ini [Database]` | `DB_IP DB_USER DB_PW DB_DB DB_PORT` | `CWorldKernel__Create` `0x4A48A9` | one game DB per world |
| `shell.ini [System]` | `SERVE_PORT` (default 5816) | `CSocketKernel__Create` `0x4A0AA1`, `0x4A48A9` | client + NpcServer listener; sent to AccountServer in 1099 |
| `shell.ini [AccountServer]` | `ACCOUNT_IP ACCOUNT_PORT SERVERNAME LOGINNAME PASSWORD` | `0x4A48A9`; NpcServer `0x402827` | world identity + link credentials (kernel `+0x24B0/+0x24C0/+0x24D0`, 16 B each) |
| `shell.ini [AccountServer]` | `MAXLOGINTABLESIZE LOGINOVERTIMESECS` | none in 12 modules | unused by 15.10 |
| `gameserver.cfg` | `maxPlayers serverIndex host user pw db [port]` | `GameData__OpenDatabaseFromGameServerCfg` `0x4B5927` | `g_MaxPlayers` `0x5218F0`, `g_ServerIndex` `0x5218EC` |
| NpcServer `config.ini [GameServer]` | `GAMESERVER_IP GAMESERVER_PORT SND_SIZE RCV_SIZE` | NpcServer `NpcServer__ConnectGameServerFromConfig` `0x40240B` | link to its MsgServer |

No numeric world id exists. `SERVERNAME` (≤15 chars, `CMsgLogin_A__Create` `0x4AF77B`) is the only identity.

## World ↔ AccountServer link

Names re-verified 2026-10-13 (REA/Ghidra + IDA); source names from fight-master `WorldKernel.cpp` (same design, older
revision — guide only).

| Dir | Type | Size | Layout | Function |
|---|---:|---:|---|---|
| W→A | 1099 | 56 | `+4 LOGINNAME[16] +20 PASSWORD[16] +36 SERVERNAME[16] +52 u32 SERVE_PORT`; each `strlen<16` | `CWorldKernel__SendGameServerLogin` `0x4A605B` |
| A→W | 1002 | 32 | id≠0 ⇒ accepted (`kernel+0x24A8`); echoed back by `CWorldKernel__SendAccountLoginAck` `0x4A60CA` | `CWorldKernel__OnAccountServerLoginReply` `0x4A630D` |
| A→W | 1052 | 28 | `+4 account, +8 key, +12 info[16]` | `CWorldKernel__OnAccountConnect` `0x4A7A8C` → `CWorldKernel__ProcessConnect` `0x4A635A` |
| A→W | 1200 | 12 | `_MSG_FEE`: `+4 account, +8 u8 type`; 3 HEARTBEAT ⇒ echo; 4 FEE_KICKOUT ⇒ kick `STR_LOGIN_ANOTHER`, not online ⇒ reply 5 | `CWorldKernel__ProcessFee` `0x4A6AB9` |
| A→W | 1201 | 20 | `_MSG_QUERYFEE` notices | `CWorldKernel__OnAccountFeeNotice` `0x4A6B68` |
| W→A | 1200 | 12 | `_MSG_FEE` type: 0 BEGIN (login) 1 END (logout) 3 HEARTBEAT 5 OFFLINE 6 SERVER_BUSY 7 SERVER_FULL 8 SERVER_CLOSE | `CWorldKernel__SendFee` `0x4A611C` |
| W→A | 1201 | 20 | `_MSG_QUERYFEE` `(0, online, 0, 103)` periodic; `(account, 0, 0, 100)` on login | `CWorldKernel__SendQueryFee` `0x4A614E` |

`CWorldKernel__OnTimerAccountLink` `0x4A581A`: reconnects, sends 1099 once per connect, pumps A→W messages through
`CWorldKernel__ProcessAccountServerMsgs` `0x4A61D0` (exact size per type; unknown type stops the pump). Status timer
`kernel+0x48` = **30 s** (`CWorldKernel__Create`): `SendQueryFee(0, online, 0, 103)`; online ≥ `g_MaxPlayers` ⇒
`SendFee(0, 7)`; else `CWorldKernel__IsAnyMapGroupBusy` `0x4A5AD7` ⇒ `SendFee(0, 6)`. Busy = any map group **message
backlog** (`CWorldKernel__GetMapGroupMessageBacklog` `0x4A5B3A` → `StdList__Size` `0x406477`) > 5000, or group 4 >
3000 (`0x526794`/`0x526798`, set in `CMsgServerDlg__OnInitDialog`). Not latency.

## Login, characters, logout

| Step | Fact | Address |
|---|---|---|
| AccountServer 1052 | online > `g_MaxPlayers` ∧ account > 1000 ∧ ¬`CUserList__IsAccountExemptFromPlayerLimit` ⇒ `SendFee(account, 7)`. Client already connected + key match ⇒ login; else store `CConnectUser` | `CWorldKernel__ProcessConnect` `0x4A635A`, `CLoginEntry__Init` `0x4AF910` |
| Client 1052 | version mismatch ⇒ talk 2101 `STR_ERROR_VERSION`; < 0x7B ⇒ `STR_ERROR_LOWER_VERSION`; online > max ∧ account > 1000 ⇒ talk 2101 `STR_ERROR_SERVER_FULL`; validation fail ⇒ talk 2101 `account locked!` | `CMsgConnect__Process` `0x4B0688` → `CWorldKernel__ClientConnect` `0x4A661B` |
| Rate gate | after 1800 s uptime, logins per **10 s** window < 15 / 10 / 5 (online < 200 / < 500 / more); fail ⇒ talk 2101 `STR_ERROR_SERVER_BUSY`, close | `CWorldKernel__IsLoginRateAllowed` `0x4A6849` |
| Matched login | account already in world ⇒ `CUserList__KickOutAccount(STR_LOGIN_AGAIN)`, **new login refused**. `LoginUser` 0 ⇒ ok (login count++), 1 ⇒ talk 2101 `NEW_ROLE`, 2 ⇒ talk 2101 `STR_ERROR_LACK_OF_BALANCE` + close | `CWorldKernel__LoginConnectedAccount` `0x4A688A` |
| Character load | `SELECT … cq_user WHERE account_id=X`, first row is loaded; this does not enforce one character per account per world | `CUserList__LoginUser` `0x4A9D1A` |
| Create | `INSERT cq_user` without `id` (DB-assigned ⇒ ids unique per world DB only); map 1010 | `CUserList__CreateNewUser` `0x4AA79A` |
| Logout | `SendFee(account, 1)`, `INSERT login_rcd`, online−− | `CUserList__LogoutUser` `0x4AA096` |
| Kick | `SendFee(account, 1)`; talk SYSTEM→ALLUSERS text on channel **2100**; close socket | `CUserList__KickOutAccount` `0x4AA260` |
| Close | `(socket, account)`: account ≠ 0 ⇒ `SendFee(account, 1)`; close | `CUserList__CloseSocketReportingLogout` `0x4AA350` |

All refusal texts are `CStringManager__GetStr` (`0x4B3D15`) keys from `shell.ini [Language] StringFile`
(`CStringManager__LoadShellIniStringFile` `0x4B38DC`). Packaged `ini/cn_Res.ini` (`ca6be9f2…2cbb`) / GolDeN_X
`En_Res.ini` (`1ebc066c…481f`): `STR_ERROR_SERVER_FULL` "Error> The server is full atm. Please re-log in later.",
`STR_LOGIN_ANOTHER` "someone.loged.as.u..", `STR_LOGIN_AGAIN` "Please login again??..."; `STR_ERROR_SERVER_BUSY` absent
from both. 5517 client channel routing: [01_core_packets](../Network/01_core_packets.md) (2101 ⇒ login-screen error;
2100 ⇒ create-role queue).

## TQ AccountServer policy (source, binary missing)

fight-master `my_server/AccountServer` = TQ AccountServer C++ source (revision unknown). Class
**CORROBORATED_SOURCE**: its refusal codes match the 5517 client `STR_CONNECT_ERROR_MSG_TYPE_%03u` table 1:1.

| Code | `Global.h` | Client text | Raised by |
|---:|---|---|---|
| 1 | `c_errPassword` | Invalid Account ID or Password | bad credentials |
| 6 / 7 | `c_errNotPoint` / `c_errNotTime` | Point / Monthly Card Expired | billing |
| 10 | `c_errUnknowServer` | The Server is down. | `NewLogin` ⇒ `ERR_NO_SERVER` (name unknown or world link down) |
| 11 | `c_errOnline` | Please try again later. | account online on **another** world (or other fee account) |
| 12 | `c_errBan` | This account has been banned. | blocked |
| 20 | `c_errServerBusy` | Server is busy. | world state BUSY |
| 21 | `c_errServerFull` | Server is busy. Please try again, later. | world state FULL |
| 999 | `c_errUnknown` | Database Error | bad fee type |

| Mechanism | Source |
|---|---|
| Refusal = 1055 `CMsgConnect(ID_NONE, code, text)`, then shutdown | `LoginThread.cpp` `RefuseLogin` |
| Online elsewhere (other world or other fee account) ⇒ `Kickout` (A→W 1200 type 4) to the old world unless `IsTimeWait` (entry in state `c_stateOnlineRejoin` already logged out and held `REJOINTIMEWAITSECS`, 0–3600 s; normal-state entries are removed at logout); **new login refused 11** either way; same world ⇒ allowed (world kicks old) | `LoginThread.cpp:464`, `OnlineTable.h:133`, `OnlineTable.cpp:636`, `typedef.cpp:107` |
| `NewLogin`: link open ∧ (NORMAL ∨ account ≤ `MAX_GM_ID`) ⇒ forward 1052; BUSY ⇒ 20; FULL ⇒ 21; else 10 | `PointThread.cpp:237` |
| W→A type 6/7 ⇒ BUSY/FULL until `SERVER_BUSY_DELAY_SECS` / `SERVER_FULL_DELAY_SECS`, then NORMAL | `PointThread.cpp:1437,1491` |
| No heartbeat for `HEARTBEATKICKSECS` ⇒ link closed, world OFFLINE | `PointThread.cpp:1448` |
| Online table: added on allowed login, removed on W→A type 1/5; double type 0 ⇒ kick | `PointThread.cpp:721` |

Account data: MsgServer issues no SQL against any account table; account ids arrive over the link.
zf package schema: `cq_user` PK `id`, UNIQUE `name`, non-unique `account_id` (package may be modified).

## Process boundaries

| Fact | Address |
|---|---|
| MsgServer single instance per `SERVERNAME` per host (mutex `"%s - %s"`); title from SERVERNAME | `CMsgServerApp__InitInstance` `0x4015C3`, `CMsgServerDlg__OnInitDialog` `0x4027BC` |
| NpcServer single instance per `SERVERNAME` per host; title/syslog from SERVERNAME | NpcServer `NpcServerApp__InitInstanceServerNamedMutex` `0x402827`, `CNpcServerDlg__OnInitDialog` `0x402CC9` |
| NpcServer → its MsgServer: `config.ini [GameServer]`; generators start 10 s after link login | NpcServer `NpcServer__ConnectGameServerFromConfig` `0x40240B`, `NpcServer__OnTimerStateMachine` `0x408175` |
| One NpcServer per MsgServer, hard-coded NPC login on SERVE_PORT; repeat login drops old | `CSocketKernel__OnNpcServerLogin` `0x4B0FD8` |
| Content partition `idxserver = g_ServerIndex` on `cq_map`/`cq_npc`/`cq_dynanpc`; all shipped rows −1; never on `cq_user` | `CMapManager__LoadMapsForServerIndex` `0x43C77B`, `CNpcManager__LoadNpcsForServerIndex` `0x4398A5` |
| No code path naming another world | string + xref census |
| Map groups = threads inside one process (`MAPGROUP_SIZE`) | `0x403A15` |
| Local lock service `127.0.0.1:9870` | `0x4A0AA1` (not traced) |

## Question map

| # | Answer | Class |
|---|---|---|
| World identity | `SERVERNAME`, ≤15 chars, no numeric id | V |
| Configured where | `shell.ini [AccountServer]` | V |
| Shared account DB | account ids from link; account DB not touched by MsgServer | V (AccountServer missing) |
| Separate game DBs | one `[Database]` per MsgServer | V |
| Character partition | per world DB; first row per account | V |
| Character ids | DB-assigned per world DB | V |
| Names | unique per world DB (package schema) | V (schema provenance caveat) |
| Multi-world characters per account | yes, one per world | V |
| Simultaneous login across worlds | refused 11 + old world kicked (1200 type 4) | CORROBORATED_SOURCE (fight-master AccountServer) |
| Online tracking | world reports login 0 / logout 1 / status 100 per account, online count 103 | V |
| MsgServer↔NpcServer across worlds | no; one NpcServer per world | V |
| Registration / heartbeat / capacity | 1099 registration, periodic 1201, Busy/Full 1200 | V |
| Central directory | AccountServer online table + per-world link state | CORROBORATED_SOURCE |
| >1 GameServer per world | not supported in practice; `idxserver` content split exists, unused | V |
| Restart survival | game DB rows; pending logins + online state are process-local | V |
| Realm vs map instance | separate concepts: world = process+DB; maps = map groups inside | V |

Retail AccountServer binary: absent; its C++ source is in fight-master (policy above). Packaged account servers are third-party — .NET `CoAccountServer`
(`592534841d0eb68d`, `04a112398a1ace87`), E-language `AccServer` (`8f108fd3d3cfb9df`) / `EACC1.03`
(`93b41a5a1226d024`), 2020 .NET `TQAccServer` (`af66921411d7fed0`). Not evidence.

Creation-time ownership and uniqueness checks, response ordering, and the single-INSERT failure boundary are now traced in [the focused 15.10 addendum](character-creation-decision-15.10.md). This does not establish 5517 server parity.
