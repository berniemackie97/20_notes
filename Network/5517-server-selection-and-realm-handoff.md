# 5517 server selection and realm handoff (native)

Verified 2026-10-12, Conquer.exe `b6ba5ab8…8a62`. Names/comments in `Conquer.exe.bndb` (in memory until GUI save).
Evidence: `10_work/docs/evidence/multi-realm-architecture-5517/` (`native-realm-selection-call-chain.json`,
`server-list-field-mapping.csv`, `login-selected-server-field-mapping.csv`, `server-dat-retail-*`).
TQ server side: [historical topology](../Server/historical-multi-server-topology.md). Decision:
[multi-realm architecture](../Server/multi-realm-architecture-5517.md). All facts CONFIRMED_5517_NATIVE unless marked.

## Chain

```
Server.dat (outenserver) ─► REGION/SERVER push (0x4AD12F)
  ─► CMD_SELECTGROUP/SERVER: dlg+0x190 / +0x194 (0-based)            persist GameSetup.Ini [Group]/[Server]
  ─► CMD_ENTERGAME 0x4ABFBD: role-2 row check (fail ⇒ ERROR StrRes 10012), 10 s rate limit, pwd length
       ─► 0x4AF12D: persist indices, connect AccountServer 0x66D3FF (BGP fallback)
  ─► CMD_GAMESTART ⇒ 0x480 ⇒ submit 0x4AEE6A: rowId = g·100 + s + 101 (0x4AEEF0)
       ├─ endpoint: 0x4AFE37 role 2 = row ServerIP/ServerPort (ACCOUNT_SERVER)
       └─ identity: row ServerName (0x4AEF7C) ─► 0x66D4C1 ─► 1060/1084/1098/1102/1121 server field
  ─► 1055: host[16]+port from AccountServer (0x75492C) ─► game connect, DH, 1052/1203 proof
```

## Functions

| Address | Name | Fact |
|---|---|---|
| `0x4ABFBD` | `CLoginFlashDlg_HandleEnterGameCommand_ValidateAndBeginBindHandshake` | CMD_ENTERGAME; role-2 row check first (StrRes 10012) |
| `0x4AF12D` | `CLoginFlashDlg_PersistSelectionAndConnectAccountServer` | writes GameSetup.Ini Group/ServerRecord, connects |
| `0x66D3FF` | `CGameMain_ConnectAccountServerWithBgpFallback` | 10 s connect, BGP retry, StrRes 10397 on fail; fail path `Sleep(5000)` (`push 0x1388` `0x66D472`, `call [0x8440E4]` `0x66D477`) |
| `0x4AAA49` | `CLoginFlashDlg_PrepareServerRootAndSelectionFromIni` | root `.\Server[%d]` (oem id); indices from `GameSetup.Ini`, fallback `DefaultGameSetup.ini`; missing −1 (prior) |
| `0x4AEE6A` | `CLoginFlashDlg_SubmitLoginRequestAndPostCommand482` | rowId; endpoint role 2 (fail ⇒ CHECK log, no send); ServerName copy cap 0x21 |
| `0x4AFE37` | `CLoginFlashDlg_GetServerEndpointByServerRowAndRole` | roles: 0 Pic, 1 Bind, 2 Server (account), 3 `nameRes.ini` KeyServer[_Charges], 4 AccountBindServer[_Charges], 5 BGP |
| `0x66D4C1` | `CGameMain_AccountSetupAndSendLoginAuthPacket` | same `serverName` to every account packet creator; creator failure ⇒ nothing sent |
| `0x96AD38` | `g_LoginSelectedServerName` | 0x21 B, set after submit |
| `0x96AC38` | `g_LoginAccountServerHost` | 0x100 B, set after submit |
| `0x710E6D` | `CChatLog_LoadServerScopedChatFile` | `LOG\<ServerName>\<id>\CHAT\<file>`, XOR key mixes ServerName |
| `0x651F35` | `CharacterSetupRecord_InitServerScopedSetupIniPath` | `Log/<ServerName>/<id>/Setup.ini` |
| `0x5EA5EB` | `ServerStatusCatalog_LoadFromCommonIniUrl` | `ini/common.ini [ServerStatus] URL`, `CInternetSession::OpenURL`, lines `"%s %d"` |
| `0x5EA5A2` | `ServerListEntry_ResolveFlashStatusCode` | case-sensitive `strcmp` on ServerName; absent ⇒ 0 |
| `0x4B05C0` → `0x4B05A8` | `CLoginFlashDlg_LoadProgressThreadProc` → `RunLoadProgressStep` | one fetch; sets `dlg+0x61D` ⇒ one refresh push |

## Retail Server.dat (`0b4d3667…7a90` → XML `5d6b00ff…c35a`)

TQ MyISAM table `cq2.outenserver` (created 2008-11-26, updated 2011-05-06): `id`, `ServerName varchar(32)`,
`ServerIP varchar(15)`, `ServerPort`, `FlashName/FlashIcon varchar(32)`, `FlashHint varchar(128)`, `Child`.
14 groups, 94 server rows, **67 distinct ServerName** (aliases: e.g. row 205 label `Water` → `Fire`), all on host
`208.96.34.46` ports 9959/9960/9963/9964, names ≤15 B, no whitespace. Pic/Bind/BGP/Charges absent.

## Questions

| # | Answer |
|---|---|
| Group/server identity | 0-based indices; row id derived; no persisted id |
| ServerName role | machine identity (packet, status key, file namespace); FlashName = display |
| Sent identity | ServerName only (no group id, no endpoint) |
| Stable across launches | indices persisted; meaning depends on file order |
| Different account endpoints per realm | yes, per row |
| ServerIP/ServerPort | AccountServer (role 2) |
| Shared endpoint | yes — all retail rows share one host |
| Unavailable/full | status int from optional URL, meaning in SWF (unresolved). 1055 failure: code only (no endpoint read), text `STR_CONNECT_ERROR_MSG_TYPE_%03u` — 10 down, 20/21 busy, 53 same server, 59 misconfigured, 70 locked ([Architecture/03](../Architecture/03_login_flash_startup_command_contract.md)) |
| Live status / refresh | one optional URL fetch + one refresh; no polling |
| Consumed fields | ServerName, ServerIP, ServerPort, FlashName/Icon/Hint, Child (+ unused-in-retail Pic/Bind/BGP/Charges) |
| Name limits | 1060 ≤16 B; status token no whitespace; used in paths; case-sensitive compare |
| OEM effect | `oem.ini` id selects `.\Server%d` root; `AccountSetup/Type` selects credential length — not routing |
| Selection removed/renamed | stale indices ⇒ missing row ⇒ CMD_ENTERGAME shows ERROR StrRes 10012 "Failed to open the Server.dat file…" (errorMC, loading reset); submit CHECK is only a second guard. Retail ini ships Group/ServerRecord=0; Flash auto-reselects saved then server 0 per region ([Architecture/11](../Architecture/11_login_ui_assets_and_interactions.md)) |
| Flash vs native | Flash: presentation, status meaning, paging. Native: persistence, row math, endpoint/identity, packets, status fetch |
| 1060 string origin | Server.dat row ServerName for current selection; may be empty only if row field empty; validated only by creator length |
| Realm affinity in 1055 | none; host/port only |
| One AccountServer for many realms | yes (retail data) |

## Managed clients

- OpenConquerClient `ab8fa68`: signed catalog = protocol name + per-server account endpoint (native shape).
  Gaps: name ≤64 (needs ≤15 ASCII), no selection persistence, 1060 not wired, duplicate names rejected
  (retail aliased). See `client-selection-contract-inventory.csv`.
- Legacy `10_work`: hardwired `Main World / Local Server / 127.0.0.1:9958`; sends display name as server name.
