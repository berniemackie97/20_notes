# Multi-realm architecture (OpenConquer 5517) — decision record

Verified 2026-10-12. Inputs: Conquer.exe `b6ba5ab8…8a62` (Binja), TQ 15.10 MsgServer/NpcServer (IDA),
OpenConquerServer `6c618ca`, OpenConquerClient `ab8fa68`, legacy `10_work@8925927`, LongV6270 (comparison only).
Native: [5517 selection/handoff](../Network/5517-server-selection-and-realm-handoff.md). TQ:
[historical topology](historical-multi-server-topology.md). Evidence + CSV/JSON:
`10_work/docs/evidence/multi-realm-architecture-5517/`. Research only — no application code changed.

## Answer

**One AccountServer service + one Accounts DB; one GameServer process + one Game DB per realm; a realm registry
in the Accounts DB keyed by the native protocol server name; login tickets bound to a realm.** No control plane,
discovery service, broker or shared cache. Matches what the 5517 client sends and what TQ 15.10 did; keeps every
current Game schema invariant.

## Existing conclusions — status

| Conclusion (source) | Status |
|---|---|
| Server.dat RSA public decode, no private key (`Architecture/05`, `Crypto/02`) | Established native |
| Selection = group/server indices, persisted `GameSetup.Ini` (`Architecture/03`, `/05`) | Established native; now with rowId formula `0x4AEEF0` |
| Submit uses role 2 `ServerIP/ServerPort` (`Architecture/02`, `/03`) | Established; corroborated by assert text `GetServerInfo(ACCOUNT_SERVER,…)` |
| "`ServerName` attribute used for connection target lookup" (`Architecture/03` SERVER format) | **Imprecise** — ServerName is the identity sent in 1060 and the status key; the target is ServerIP/ServerPort |
| 1060 `server_name +260`, 16 B (`Network/13`) | Established native; origin now proven (`0x4AEF7C`) |
| Status code fixed 3 on init, resolver on refresh (`Architecture/05`) | Established; source now proven (`common.ini [ServerStatus] URL`) |
| Legacy own-UI hardwired `Main World / Local Server / 127.0.0.1:9958` (`Architecture/10`) | Still true at `10_work@8925927`; also sends display name as server name (non-native) |
| Credential envelope, DH/CAST5, session mask (`Server/login-credential-envelope`, `Network/14`) | Established; untouched by realm routing |
| TQ binaries census / runtime semantics (`Server/tq-server-*`) | Established; extended with topology |
| OCC signed catalog replaces Server.dat (OCC `docs/compatibility/server-dat.md`, STARTUP-001G) | Consistent with native shape (protocol name ≠ label, per-server account endpoint) |
| `GetSingletonPtr_414BDA` "server name registry", `STR_SERVERNAME_S` (`01_architecture_overview`, `cplayer_class`) | Unresolved — cross-server name display, not traced |

## Compatibility requirements (5517 native)

| Requirement | Class |
|---|---|
| Client sends realm identity = protocol server name; 1060 field 16 B, creator rejects >16 B | CONFIRMED_5517_NATIVE |
| Same name in 1084/1098/1102/1121 | CONFIRMED_5517_NATIVE |
| Each list entry may point to its own account endpoint | CONFIRMED_5517_NATIVE |
| Retail: many entries share one account host; 94 entries → 67 names (aliases) | CONFIRMED_5517_NATIVE (data) |
| 1055 carries host/port only; server chooses redirect | CONFIRMED_5517_NATIVE |
| Name used as on-disk namespace (`LOG\<name>\`, `Log/<name>/`) ⇒ stable, filesystem-safe, no whitespace | CONFIRMED_5517_NATIVE |
| Status lines `"%s %d"` keyed by exact name | CONFIRMED_5517_NATIVE (optional URL) |
| World identity ≤15 chars | CORROBORATED_CROSS_VERSION (TQ 1099 limit; retail max 15) |
| One character per account per world; per-world DB | VERIFIED_OLDER_VERSION_ONLY |
| AccountServer central, worlds register/report | VERIFIED_OLDER_VERSION_ONLY (link differs; AccountServer missing) |

Protocol name rule (modern choice satisfying all above): 1–15 bytes ASCII `[A-Za-z0-9_()-]`, exact ordinal
match, immutable per realm.

## Concepts

| Term | Meaning here |
|---|---|
| Realm | player-selectable world = protocol name + one GameServer process + one Game DB |
| Map / map instance | inside a realm (`MapId`; instances later) — never a realm |
| World partition | per-map partition inside the GameServer (`world-execution.md`) |
| GameServer process | exactly one per realm now; horizontal split not needed (TQ never used `idxserver`) |
| Cross-server gameplay / transfers / cross-realm events | separate future features over account-level services; out of scope |

## Options

| Criterion | A: Accounts shared, Game DB per realm | B: Accounts shared, one Game DB + `realm_id` | C: TQ-style dynamic registration link |
|---|---|---|---|
| 5517 compatibility | full | full | full |
| Matches TQ 15.10 | yes (DB per world) | no | yes (link) |
| Character uniqueness | existing `UX account_id`, `UX name` per DB, unchanged | every unique key becomes `(realm_id, …)` | as A |
| Schema change | Accounts: `realms`, ticket `realm_id`; Game: `realm_binding` | `realm_id` on every realm-scoped table + all queries | A + protocol + heartbeat tables |
| Isolation / blast radius | DB per realm | one DB for all realms | as A |
| Leak risk | DB boundary | any missing filter leaks | as A |
| Migrations | same migrations run per realm DB | one large migration | as A |
| Backup / restore | per realm | all-or-nothing | as A |
| Scaling | add DB + process | contention in one DB | as A |
| Ops complexity | N connection strings | 1 DB | + persistent link, heartbeats |
| Cross-realm later | account-level services | joins easy (also a risk) | registry exists |
| Migration from today | current Game DB becomes realm 1 unchanged | rewrite keys | as A + new link |

**Choose A.** B rewrites every constraint and makes one missing `WHERE realm_id` a cross-realm leak. C adds a
long-lived control link and heartbeat state with no current need: realm endpoints and state are operator data;
GameServer capacity is enforced at admission. Add a status heartbeat only when a live status feature exists.

## Sequence (A)

```
Client          Catalog(HTTPS)     AccountServer          Accounts DB        GameServer[R]      Game DB[R]
  │ startup ──────►│ signed realms.json (+sig)  (modern choice)
  │◄───────────────│ regions/servers: label, protocolServerName, accountHost/Port
  │ select realm (persist regionId/serverId)                                   (modern choice)
  │ 1060(account, cred, protocolServerName) ──►│
  │                                  │ resolve realm: exact name, state=enabled ─► realms   (modern)
  │                                  │ authenticate (existing) ────────────────► accounts
  │                                  │ grant ticket(account, realm_id) ────────► game_login_tickets (modern)
  │◄──── 1055(token, key, realm.public_game_host:port) ──│                      (native field use)
  │ connect + DH + 1052/1203 proof ──────────────────────────────────────────►│
  │                                                      redeem(session,key,expected realm R) ─► tickets (modern check)
  │                                                                            │ resolve character by account ─► characters
  │◄──────────────── 1004 NEW_ROLE  or  existing-character bootstrap ──────────│
  │ 1001 create (same session) ───────────────────────────────────────────────►│ insert ─► characters
  │◄──────────────── world entry ──────────────────────────────────────────────│
```

Failure replies use existing client texts: unknown/malformed/disabled → 10, maintenance → 70 (modern choice; retail
code use unresolved, R-02). No busy (20/21) reply: AccountServer has no capacity view. 1055 failure carries no
endpoint — client failure branch reads the code only (`0x754962`).

## Data model (A)

```
Accounts DB                                   Game DB (one per realm R)
 accounts (PK account_id)                      realm_binding (realm_id = R, 1 row)
   1─* game_login_tickets                      characters (PK character_id, UX account_id, UX name)
         (PK session_uid, realm_id FK) *─1 realms     1─* items, magic, weapon_skills
 realms (PK realm_id, UX protocol_server_name,        1─* social_relations
         public_game_host, public_game_port, state)    syndicates 1─* syndicate_memberships
 [later] account_realm_presence (account_id PK, realm_id, lease)
```

`characters.account_id` references Accounts logically (no cross-DB FK), as today.

## PR slices

| # | Slice | Why / limitation solved | Files | Migration | Invariants changed | Tests | Must not change | Operational | Depends |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Realm registry | no realm concept; config-only endpoint | Domain `RealmId`/`ProtocolServerName`; Infrastructure Accounts `realms` config + store | Accounts v3 | protocol name unique, immutable, ≤15 ASCII | name validator, uniqueness, store | ticket/auth behaviour | no | – |
| 2 | Realm-resolving login | `LoginHandshakeProcessor` ignores ServerName | `LoginHandshakeProcessor`, `LoginHandshakeConfiguration` (removed endpoint), AccountServer config | – | 1055 endpoint from registry; unknown/locked → 10/70 before password work | unknown, locked, enabled, timing parity | credential, rate-limit, revocation rules | yes (single realm row) | 1 |
| 3 | Realm-bound tickets | ticket redeemable by any GameServer | `GameLoginTicketGrantRequest/Issuer`, `GameLoginTicketRecord/Configuration`, `GrantStore`, `RedemptionStore`, `Redeemer`, `GameConnectionAuthenticator` | Accounts v3 (same) | redeem requires `ticket.realm_id == configured` inside row lock | cross-realm reject, concurrency, revocation | single-use, key HMAC, commit rule | yes | 1, 2 |
| 4 | GameServer realm binding | no realm identity; DB could be swapped | `GameServerConfiguration` (`Realm:Id`), startup check, Game `realm_binding` | Game v10 | start only if config = binding = enabled registry row | mismatch fails startup | world runtime, content | yes | 1, 3 |
| 5 | Client selection submit | OCC 1060 not wired; name limits too loose | OCC `LoginServerCatalog` validator (≤15 ASCII set), `StandardAccountRequest1060` wiring, selection persistence by ids | – | client sends catalog protocol name; endpoint from catalog directory | validator, persistence, packet bytes | catalog signature trust | yes | none server-side |
| 6 | Ops: second realm | prove isolation | deployment docs, per-realm DB users/secrets | – | per-realm creds | two-realm integration test | – | yes | 1–4 |

**Before character creation ships:** slices 1, 3 and 4 (identity + realm-bound tickets + DB binding). Creation
itself needs no schema change under A: `UX account_id` / `UX name` are already the correct per-realm rules.

## Operations

| Case | Pattern |
|---|---|
| Local dev | one `realms` row, one GameServer, one Game DB |
| Two realms | two GameServers (own port), two Game DBs, two Game DB users, two creation users |
| More realms | same, per realm; AccountServer unchanged |
| Multiple GameServers per realm | not supported/needed |
| Maintenance | `realms.state`; login refused before password work |
| Migrations | Accounts once; Game per realm DB (same migration set) |
| Backup/restore | Accounts + each realm DB independently; restore of a realm never touches others |
| Secrets | per-realm DB credentials; ticket HMAC key ring shared now, per-realm key ids later if trust domains split |

## OpenConquerServer status (2026-10-14)

| Slice | OCS PR | State |
|---|---|---|
| 1 realm registry | #129 | merged |
| 2 realm-resolving login | #131 (pre-auth gate), #137 (1055 from registry) | merged |
| 3 realm-bound tickets | #136 | merged |
| 4 GameServer realm binding | #130 | merged |
| availability codes 10/70; AccountServer static GameServer endpoint removed | #139 `bernie/realm-139-native-availability-failures` | review |
| capacity + health: Accounts v5 `realm_status` (GameServer report, lifetime 3× interval); AccountServer 10/20/21 pre- and post-auth; GameServer full/busy → talk 2101 | `bernie/realm-141-capacity-and-health` | review |
| one realm at a time: Accounts v6 `account_sessions` + `account_session_kicks`; AccountServer 11 + kick; GameServer claim under row lock, talk 2101 on conflict, 1 s kick poll → 1115 mode 0 + close | `bernie/realm-142-single-account-session` | review |
| 5 client submit | OCC | open: protocol name rule ≤64 in `LoginServerCatalog` + `RealmCatalogDefinition` (needs 1–15 `[A-Za-z0-9_()-]`); 1060 not wired |
| 6 ops second realm | #140 `bernie/realm-140-realm-operations` (`docs/operations/realms.md`; SQL verified on fresh v4/v10 DBs) | review; two-realm live run not yet done |

TQ → OCS mapping (sources: [topology](historical-multi-server-topology.md)):

| TQ | OCS | Parity |
|---|---|---|
| W→A 1201 type 103 + 1200 type 6/7 every 30 s; link drop ⇒ OFFLINE | `realm_status` row, `GameServer:RealmStatus:ReportInterval` (10 s), expires after 3 intervals | same states; DB instead of link |
| busy = map-group backlog > 5000 | a map partition's bounded queue refusing work | same signal, bounded form |
| full = online ≥ `g_MaxPlayers` | resident characters ≥ `GameServer:World:MaxCharacters` | same |
| A: `NewLogin` BUSY 20 / FULL 21 / no link 10 | same codes, before and after password check | same |
| W 1052: online > max ⇒ talk 2101 `STR_ERROR_SERVER_FULL` | full ⇒ talk 2101 after ticket redemption | same |
| W 1052: login-rate gate ⇒ talk 2101 `STR_ERROR_SERVER_BUSY` | busy (partition saturated) ⇒ talk 2101; no login-rate gate (per-source + global admission instead) | channel same, trigger differs |
| A: online elsewhere ⇒ kick (1200 type 4) + refuse 11; skip kick while `IsTimeWait` | kick row + refuse 11; no rejoin wait | same, minus `REJOINTIMEWAITSECS` |
| W: FEE_KICKOUT ⇒ `KickOutAccount` talk 2100 + close | 1115 mode 0 + close | differs on purpose: 2100 is the 5517 create-role queue |
| W: same-world relogin ⇒ kick old + refuse new | replace old (1115), admit new | differs on purpose |
| A online table: added on allowed login, removed on W type 1/5 | `account_sessions`: written by the GameServer at world entry, removed at disconnect; cleared at GameServer start/stop | same role |
| GM ≤ `MAX_GM_ID` bypasses busy/full | none (no staff accounts yet) | gap |

Known limit: realm disabled between post-auth lookup and locked ticket grant → code 1 (grant collapses lost
preconditions into one status).

## Blockers / open

- Retail AccountServer binary missing; policy from its C++ source (fight-master, CORROBORATED_SOURCE): codes 10/11/20/21
  and the cross-world kick. Implemented (#141, #142).
- Retail meaning of Server.dat status integers: unresolved (R-03).
- Merged realms (retail aliases): model as one realm with one protocol name; catalog may show one label.
- Unresolved list: `unresolved.json` (R-01…R-07).
