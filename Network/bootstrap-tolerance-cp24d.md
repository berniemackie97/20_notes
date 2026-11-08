# CP2.4d — bootstrap tolerance

2026-11-06. Base OCC `45cf02b4`; Conquer.exe.bndb view9, clean SHA256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Existing receive-buffer, packet registry, map identity and action61/replay evidence
was inventoried first. Do not reuse the historical emulator/source cross-checks
in older notes as native authority.

## Native facts and remaining managed checks

| Check | Native authority | Slice |
| --- | --- | --- |
| Exact10010 length/string-count0 | Parse0x6FEB93 has only header/type rules; existing original-x86 replay accepts4/8/22/38/39/92. | d1 decoder |
| Exact1110 length20 | Ctor0x732AA9 resets0x400 buffer; Parse0x732AED checks header/type only. | d1 decoder |
| Exact1016 length20 | Parse0x7607DE checks header/type only; values are handled later. | d1 decoder |
| Nonzero map identities | Process0x732B6F/0x732B84/0x732B99 stores +4/+8/flags without this validation. | d2 flow |
| Mandatory first1110, then1016, then74 | No such sequence in native common dispatcher; per-handler consumers must drive supported state. | d2 flow/readiness |
|74 entity must equal hero | Process patches +4 to hero at0x6FEE25. It loads map from action+8 at0x6FF478, separately from1110 metadata. | d2 flow |
|74 parameter equals1110 document | No equality gate in74; the action's key is consumed independently. | d2 flow |
| Expected acknowledgement rung and parameter0 |75/76/77 and reused78/97/251 handlers have no previous-rung/parameter gate after resolver. Repeats repeat effects. | d2 flow |
| Exact-hero gate for75..251 | Common resolver0x6FF173 accepts hero or an existing remote role; zero/unknown skips. Remote-role ownership is not yet implemented in OCC. | d2 supported-state boundary |
| Stage-specific hydration whitelist | Native dispatch is independent of the outbound rung. Preserving supported state/order needs a separate bounded ownership design. | d2 flow |

Native response edges, builder/send:74→75 `0x6FF540/570`;75→76
`0x6FF3F4/424`;76→77 `0x6FF38C/3BC`;77→78 `0x6FF321/351`.
Existing `21_msgaction_0061_syndicate_bootstrap.md` and its original-x86 replay
already prove78→97→251→132. Inbound132 exits at0x700974; no132 response gate.
The earlier74 builder address0x6FF54A is stale; raw call is0x6FF540.

The current unconditional408 send after74 is also not established by that branch.
1110 sends408 on a high-map-bit38 transition (`0x732CFD..0x732D5B`). The explicit
builder census has ten408 sites, not the old seven-site prose; extra sites are
packet1024 at0x740A6F and packet2077 at0x75B1B6/0x75B22D. None is a direct74
emitter. This is a bounded explicit-call census, not an indirect/deferred absence
proof. Admission timing, native world-readiness and408 policy stay in d2 preflight.

## d1 implementation boundary

Use common zeroed-buffer/header/type decoding for10010,1110 and1016 in the current
bootstrap. Keep writers canonical. Type map metadata rather than decoding inline.
Do not change the existing semantic/entity/order checks, hydration budgets,
deadlines, session phases or activation point in this PR; they remain explicitly
open under d2. A tolerant codec must not be described as complete bootstrap parity.

Three parser comments extended/read back before code; no renames required or BNDB
save. Decoder tests reuse eight existing original-x86 parser results with pinned
input evidence, plus synthetic full-width1110 fields and encrypted same-socket
bootstrap sequences. No live native client/server trace is claimed.

## d2 preflight — action 408 (0x198) emitters (2026-11-06)

`CMsgAction__BuildType10010` `0x6FECE4` has 16 callers (Binja xrefs). 0x198 callers:

| Caller | Site | Trigger |
|---|---|---|
| `CMsgMapInfo1110__Process` | `0x732D4C` | high flags bit 6 (qword bit38) before ≠ after (`0x732B4A` vs `0x732CF8`, cmp `0x732CFD`) |
| `sub_6daeb9` (equip-set toggle) | `0x6DAF6C`, `0x6DAFE2` | UI only: caller `CMyShellDlg_WindowProc_DispatchMainWindowMessages` `0x5C04CC`; also sends 1009 subtype 44/45 |
| `CMsgItem__Process` | `0x6EB099`, `0x6EB2ED`, `0x6EB51D`, `0x6EB6F5` | 1009 mutation subtypes (incl. subtype 5 apply); not subtype 46 snapshot |
| `sub_740a37` (1024) | `0x740A6F` | packet 1024 |
| `CMsgNonSuch__Process` (2077) | `0x75B1B6`, `0x75B22D` | packet 2077 |

Other 6 callers pass fixed non-408 actions: `sub_65af8b` 0xAD, `sub_65affa` 0xAC, `sub_568c48` 0xB1, `sub_51ebb0` 0xB2, `sub_4f37ef`/`sub_4f384a` 0x196. Immediate census (objdump, same PE): all 19 `push 0x198` sites in `.text`: 10 = `BuildType10010` above; `0x463347`/`0x765F23` → `Debug_LogMessageToDailyFileWithDedup` (line no.); `0x4FC4A3` → `CMyDialog_Constructor` (resource id); `0x77D9CB` → OpenSSL lock `sub_77e4c0` (line no.); `0x5A3BFC..0x5A4A72` → import calls (UI). No `mov reg,0x198`. No other builder receives 0x198 as an immediate; computed action values not excluded.

Initial flags: `CGameMap` ctor `0x61B875` zeroes +0xE8/+0xEC (`0x61BB05`/`0x61BB32`; edi=0 at `0x61B898`). Only direct writer after that: `CGameMap_SetFlags64` `0x61F2C3`, sole caller `CMsgMapInfo1110__Process` `0x732BA1`. Other +0xE8/+0xEC stores (`0x62DF62..0x62E485`) belong to a different object layout.

Consequence: first entry sends 408 iff the first map's flags have bit38 (high dword bit 6). Ordinary hydration (1008, 1009-46) sends none.

Cross-repo: OCS `ExistingCharacterMapStateAppliedProcessor` blocks login on a 408 right after EnterMap; OCC sends 408 unconditionally after the 74 ack. Client and server agree, but native evidence above does not support an unconditional 408. Native client vs OCS on a map without bit38: expected stall until server timeout — **not observed** (no VM run).
Binja, read back: `sub_6daeb9` → `CHeroItem__SendEquipModeSwitch` + function comment; function comment `CMsgAction__BuildType10010` (census).

## d2 runtime probe — retail client vs OCS (2026-11-06)

Win11 VM, clean `5517-loader` copy in `C:\OC5517-probe`, loader → 10.211.55.2:9958/5816. OCS `656e177` against a throwaway `mysql:8.4.11` clone (realm renamed `GardenOfEden`, address 10.211.55.2). Account `test`, character `janna` (appearance 12001), map 1010 (OCS flags 0). Bernie logged in himself. Probe removed afterwards.

| Run | OCS result |
|---|---|
| 1 | login dropped at `ExistingCharacterMapStateAppliedProcessor`: "not a valid action packet: InvalidPacketId" |
| 2 (temp. diagnostic, reverted) | same; next client frame = **type 1151, length 80** (both attempts) |

Static match: `CMsgUserInfo__Process` sends action 74 (`0x764867` push 0x4A, ctor `0x764853`, create `0x764873`, send `0x7648A3`), then, when `hero+0x178 == 2`, `CMsgFlowerRank` subtype 2 via `BuildSize80` (`0x7648D3` push 2, call `0x7648DB`, send `0x7648E6`). `hero+0x178` = appearance `/1000 %10` (`Network/01_core_packets.md`); 12001 → 2.

Proven: on a flags-0 map the native client sends no 408 after the EnterMap exchange. Its post-1006 output is 74, then 1151 subtype 2 for body digit 2. No OCS map definition has bit38 set, so OCS's 408 wait can never be met by the native client. OCC's unconditional 408 is non-native. The earlier note in `Architecture/12` ("seen ... before `0x198`") is not reproduced by this run and needs re-checking.

## d2 probe iterations + historical server policy (2026-11-06)

Patched OCS (408 optional; 1151 subtype 2 / 114 / 408 consumed): retail client passed 74 → 75 → 76, then sent **action 96** (`0x60`) before 77. Native emitters:
- 114 booth close: `CGameMap_CreateFromDataId` → `CBoothManager_Close` `0x61DB1E` → `CMsgAction__Create(hero,0,0,0,0x72,0)` `0x70AC3D` (timestamp `timeGetTime`, `CMsgAction__Create` `0x6FE95F`). Every map creation, so before 75.
- 96 PK mode: `sub_66066a(hero, mode, send)`; send path only when arg3 ≠ 0. Main-dialog init `sub_4bdc59` calls it with (3, 1) at `0x4BDD30` (UI timing). Inbound path `0x6FF63B` passes 0 → no send.

Historical MsgServer (IDA, `MsgServer.exe.i64`, read-only):

| Behaviour | Address | Result |
|---|---|---|
| Socket message entry | `sub_409CD0` | rejects size ≤0 or >1024; `CreateMsg` wrapper `sub_43867D` → null → returns 1 (dropped, connection kept) |
| CreateMsg | `sub_43867D` → `sub_4388F3` (type switch), Parse `sub_48C396` | unknown type or Parse failure → null |
| MsgAction default | `CMsgAction__Process` `0x4672AE`, `LABEL_348` | debug assert (`MsgAction.cpp` line 1424), return; no disconnect |
| Action 96 | same, `case '\`'` | handled (PK mode, `STR_SAFE_PK_MODE`) |
| Action 114 | none | falls to default |

Historical tag: server binaries are older than 5517 (era unproven).

## d2 result — retail client in world on OCS (2026-11-06)

OCS branch `bernie/native-bootstrap-408`: no 408 step; while waiting for a ladder step it consumes any non-10010 frame and any well-formed non-ladder 10010; malformed 10010 or an out-of-order ladder step still fails. World loop ignores unsupported types/actions (debug log 6208) instead of disconnecting. Retail client entered and stayed in world. In-world ignored frames: 1009 ×6, 1037 ×1 (client→server; not yet analysed). Bernie noted jump oddities (no server warning logged); tracked separately under CP4.3.

OCC branch `bernie/native-bootstrap-408`: sends 1151 subtype 2 after 74 for body digit 2; 408 only for a bit38 map; 114 after the 74 reply. Not yet sent: PK mode 96, client 1009/1037, native action timestamps.

## d2b evidence (2026-11-06)

| Item | Native | Address |
|---|---|---|
| 75–78 requests | `CMsgAction__Create(hero,0,0,0,action,0)`; Create writes `timeGetTime` at +16 | `0x6FF540`, `0x6FF3F4`, `0x6FF38C`, `0x6FF321`; Create `0x6FE99C` |
| 74 / 97 / 132 / 114 / 96 | also `CMsgAction__Create` → +16 = `timeGetTime` | `0x764873`, `0x6FF2B6`, `0x700914`, `0x70AC3D`, `0x6606B1` |
| 408 | `CMsgAction__BuildType10010`: +16 stays 0 | `0x6FECE7..0x6FED17` |
| 251 report | `BuildSilentInfoReport251`: entity 0, +8 checksum, +16 version (not time) | `0x6FF607`; note 21 |
| Ack gate | Process reads only +4 (resolver: hero or known role, else silent exit `0x700974`) and +20; parameter, coordinates, timestamp ignored | note 21; common gate `0x6FF15D..0x6FF18A` |
| 74 ack | +4 overwritten with hero (`0x6FEE14`); map created from ack +8 (`0x6FF478`), independent of 1110 | |
| Repeated ack | each accepted ack repeats its effects (next request again) | note 21 |
| PK mode 96 | 75-ack handler sends 76, then posts main msg `0x401` (`0x6FF3CD`); `0x401` = jump table `0x5CD993` idx 6 → `0x5C351E` → `sub_4bdc59` → `sub_66066a(hero,3,1)` → Create(hero,0,0,0,0x60,**3**) | `0x4BDD30`, `0x6606AB` |
| Heartbeat | 74-ack handler starts `hero+0x2CE8` timer 10000 ms after sending 75 (`0x6FF57A..0x6FF587`). `CHero_TickHeartbeatAndPeriodicSessionSync` `0x661ADD` (per frame, `0x65E10A`): on fire and net state 2 → 1009 subtype 27, +4 hero id (`0x661B3B`). Server 1009/27 → latency `hero+0x2CF4 = timeGetTime − +16`. | |
| 1037 | same function: every 30 min (`0x1B7740` ms) and only if `hero+0x2F78 ≠ 0` → `sub_743fed(0, +0x2F78, latency, timeGetTime)`; writer of `+0x2F78` not yet found | `0x661B5F..0x661B9E` |

Binja: comments `0x6FF580`, `0x4BDD30`; function comment `CHero_TickHeartbeatAndPeriodicSessionSync` (name briefly overwritten and restored; any earlier function comment was replaced).

## d2b slice 2 evidence — heartbeat, 1037, 251 (2026-11-07)

| Item | Native | Address |
|---|---|---|
| 1009/27 body | `CMsgTick__Build_SubType(hero, 0, 27)` builds size 88, +4 hero, +8 zero, +12 subtype 27, and XORs the timer with the hero ID at +16. `GameTransport_SendPacket` overwrites +16 with the raw timer before socket buffering. | Builder `0x6EAC51..0x6EACB4`, send `0x6DF104..0x6DF12A`, [VM capture 1 frames 39–42](evidence/cp32-world-entry-2026-11-08/README.md) |
| Timer | vtable `0x86D7E0`: +4 interval, +8 start. `CTimerMS_IsTimeOut` `0x6B9C93`: active (start ≠ 0, `0x6B9D56`) and `now >= start+interval` (unsigned vs wrapped sum, `0x6B9CAA`). `CTimerMS_ToNextTime` `0x6B9D8B`: on timeout restart from now, return 1 | |
| Start | 74-ack handler: Startup(10000) after sending 75 | `0x6FF57A..0x6FF587` |
| Heartbeat order | timer fires → net state (`0x687190` on `0x96AFC8`) == 2 → send 1009/27 → if `now − hero+0x2F74 >= 1800000`: (if `hero+0x2F78 ≠ 0` send 1037), then `+0x2F74 = now` | `0x661AF0..0x661BB7` |
| `+0x2F74` | `timeGetTime` at hero construction | `0x655BA8..0x655BAD` |
| `+0x2F78` | local IPv4: `sub_66df97` `gethostbyname(gethostname())`, loop keeps the **last** `h_addr_list` entry (raw in_addr dword) via setter `0x665FC8`; called from `CLoginFlashDlg_PersistSelectionAndConnectAccountServer` `0x4AF266`; 0 at ctor `0x655BB4` | `0x66DFCC..0x66E05A` |
| 1037 body | `sub_743fed`: size 20, type 1037, +4 0, +8 address, +12 latency (`hero+0x2CF4`), +16 timeGetTime | `0x743FED` |
| Latency | inbound 1009/27: `hero+0x2CF4 = timeGetTime − +16` | `CMsgItem__Process` subtype 27 |
| 251 checksum | `CSilentInfo` ctor 0 (`0x6BB2F7`); `CSilentInfo_ReloadDataFile` reads `ini/Slient.dat` if it opens (`0x6BB440`); `0x6BB1E2`: `r=0; for b: r = ((r<<8)|b) ^ T[r>>24]`, T = reflected CRC-32 table (poly `0xEDB88320`) at `0x9432D8` (generator-verified) | |
| 251 version | `0x6BB3AC`: `ini/SlientVersion.ini` → `atoi` of the first 128 bytes; open failure → 1 | |
| Clean install | `ini/Slient.dat` 0 bytes → checksum 0; no `SlientVersion.ini` → version 1 | `00_clean/clean/5517-loader/ini` |

Decision (Bernie 2026-11-07): send 1037 with the local IPv4 as native does.
Binja: `CTimerMS_ToNextTime`, `CTimerMS_IsTimeOut` named and commented (both were unnamed and had no comment).

## Historical server: heartbeat, 1037, 251 (2026-11-07, IDA `MsgServer.exe.i64`)

| Item | Historical MsgServer | Address |
|---|---|---|
| 1009 layout | `CMsgItem::Process` switches on body word 4 = packet +12 (body pointer skips the 4-byte header), same as 5517 | `0x487F5E` |
| 1009/27 | case `0x1B` → `LABEL_66` → role vfunc+328 (`SendMsg`) with the same message: **echoed unchanged** | `0x487F5E` |
| 1037 | no `CreateMsg` case → null → dropped | `sub_4388F3` |
| 251 | no `CMsgAction::Process` case (falls to the default assert) — that server predates the 251 rung | `0x4672AE` |

OCS #209 echoes client 1009/27 in the world loop and ladder reader, following the historical server. The retail client sends a raw timer at +16 and computes elapsed time from the echoed field. The November 8 VM capture and the pre-buffer overwrite at `0x6DF118` resolve the earlier inference from the builder alone. Original 5517 server replies remain unobserved. The managed writer mismatch was fixed in [OCC #300](https://github.com/berniemackie97/OpenConquerClient/pull/300), and [OCS #215](https://github.com/berniemackie97/OpenConquerServer/pull/215) verified the existing echo against the capture digest. [OCC #299](https://github.com/berniemackie97/OpenConquerClient/issues/299) is complete. The 1037 drop and client-required 251 acknowledgement are separate behaviors.
IDA comments saved: `0x487F5E`, `0x4388F3`.
