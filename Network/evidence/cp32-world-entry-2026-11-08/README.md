# CP3.2 retail 5517 runtime evidence

Two existing-character logins on 2026-11-08 reached the rendered world in Windows 11 ARM64 under Parallels x86 emulation. The original Conquer.exe SHA-256 was verified on the host and in the guest before launch and rechecked during the run.

**b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62**

[Capture records](capture.json) contain 229 ordered records with phase, direction, opcode, discriminator where known, logical length, capture point, provenance, UTC and elapsed time. Each of the 189 disclosed packets contains exact plaintext hex and its SHA-256. Of those, 93 are original client emissions, 41 are controlled peer packets, 53 are unchanged peer echoes, and two are deliberately modified test stimuli. All 40 other records contain metadata only. [File hashes](SHA256SUMS)

## Capture boundary

- The client ran directly with its stock Server.dat and the normal blacknull argument. A temporary guest loopback address and TCP relay redirected the selected realm to an isolated peer over Parallels shared networking. No loader, game memory patch, retail server, or OpenConquer database participated. [Windows netsh interface reference](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/netsh-interface)
- A standalone peer used the OCS protocol library built from archived commit 18fe9926914c1cf3ef4f70c25cfddc99f2d8cce1 and BouncyCastle 2.7.0. It authenticated a disposable test login and assigned synthetic hero 1000000 with appearance 12001 on map 1010 with flags 0, at tile (61,109). Both sessions were admitted using the same peer behavior. The protocol assembly digest and the client asset digests are in the JSON.
- The peer recorded the four-byte little-endian header and complete logical payload after inbound decryption and TQClient trailer validation. For the opposite direction it retained the exact bytes passed to the encoder before encryption and TQServer trailer insertion. Hex and hashes exclude the eight-byte game transport trailer. Order is the peer's completed read/write order across two TCP sockets and directions. Each capture has a separate clock origin.
- Login seeds, credentials, tickets, Diffie–Hellman material, device reports and both forms of 1052 were excluded before hex or hashing. The first two attempts in capture 1 stopped after 1060 and contain metadata only. Capture 1 also withheld the three mission catalog payloads pending classification. Capture 2 disclosed the validated public catalog records and the peer's blank synthetic login history.
- Native-client provenance applies only to outgoing frames emitted by the retail executable. Controlled-peer packets are exact runtime inputs. Controlled-peer echoes reuse the corresponding client bytes verbatim. Derived stimuli are deliberately modified bytes. Visible effects and client responses establish the limited inbound observations below.

## Observed sequence

Frame references use capture number and sequence number in the JSON.

| Phase | Direction and result | Frames |
|---|---|---|
| Account authentication | Peer 1059 seed → native 1060 request → peer 1055 success → native 1100 device report and account-form 1052 resource report | 1/5–9 and 2/1–5, metadata only |
| Game transport and admission | Peer DH challenge → native DH response → native game-form 1052 proof | 1/10–12 and 2/6–8, metadata only |
| Existing character | Peer 1004 with ANSWER_OK on channel 2101 → 2078 → 2079 → 1006. The retail client rendered the named hero after the ladder completed. | 1/13–16 and 2/9–12 |
| Initial map | Native 10010/74 → peer 1110, 1016/1, 10010/74 → native 10010/114, then 75. Native 1151/2 follows the client's 74 in both runs. | 1/17–26 and 2/16–22 |
| Mission catalog | Native 1134/3, three consecutive frames with 80, 80 and 64 ascending records. The burst came after native 74 and 1151 in capture 1 and before both in capture 2. Capture 1 has lengths only. Capture 2 holds the bytes. | 1/22–24 and 2/13–15 |
| Bootstrap ladder | Native 75 → 76 → 77 → 78 → 97 → 251 → 132, with peer ACKs between rungs. Native 96 (PK mode) fell between 76 and 77 in both runs. Native 251 carried checksum 0 and version 1. Both runs reached world view without sending 408 on flags-0 map 1010. | 1/26–39 and 2/22–35 |
| Flower rank | Native 1151/2 was 80 bytes in each run with a byte discriminator at +4 and a zero remainder. Both captures have the same digest. | 1/21 and 2/20 |
| Heartbeat | Native 1009/27 was 88 bytes. The first arrived about 10 seconds after ACK 74, with another about every 10 seconds. The peer echoed exact bytes. The native client remained live and its HUD showed ping. | 1/40–43 and 2/36–39, with later repetitions |
| Movement | Native 10005 run selector 1 followed a ground click. The displayed tile changed from (61,109) to (64,109). Capture 2 also emitted selector 0 after ghost status. The peer echoed the requests. Player motion alone cannot distinguish receipt of an echo from local prediction. | 1/44–49 and 2/46–61 |
| Appearance and status | Peer 10017 attribute 11 with family 99 produced a translucent ghost model. Peer 10017 attribute 25 with low64 0x420 and high64 0 produced the revive controls, followed by native 1056 and 10010/145. The first capture's attribute 11 value 11001 had no clear visual effect. | 1/52 and 2/40–45 |

## Malformed and ordering probes

| Stimulus | Observed behavior | Frames |
|---|---|---|
| 1016 kind 2 at intensity 1000, then derived kind 6, then valid kind 1 | Kind 2 produced visible rain. Rain and movement persisted after kind 6, and heartbeats continued. Kind 1 cleared the rain. This exercises one invalid tuple. | 1/57, 64, 106 |
| Derived 22-byte 10010/75 after world admission | The peer shortened the 38-byte ACK to end at the action word, adjusted the logical length, and sent it with normal transport framing. The client emitted 76 after 195 ms. With subsequent peer ACKs it went through 132 again. The next heartbeat arrived. | 1/111–125 |
| Full 38-byte 10010/75 replay after world admission | The client emitted 76 after 30 ms, then went through 132 again under the same peer ACKs. This confirms replay outside the expected bootstrap phase. ACK 75 before the first ACK 74 and corrupt encrypted lengths or trailers were outside these runs. | 1/132–146 |

## Heartbeat field correction

Native 1009/27 carries the raw client millisecond timer at +16 on the wire. The builder's XOR is a real intermediate value. The send path replaces it before transmission. Capture 1 sequence 39 action-132 timer is 68946042. Sequence 40 heartbeat has 68952244, an increase of 6202 ms over 6238 ms of peer elapsed time. The next heartbeat's raw value increases by 10032 over 10028 ms of peer elapsed time.

Read-only assembly in the Conquer.exe Binary Ninja view ties the two operations together. The heartbeat caller builds subtype 27 at 0x661B3B and calls CNetMsg__Send at 0x661B4A. The builder XORs at 0x6EACB0 and stores at 0x6EACB4. CNetMsg__Send calls 0x6DF0E0 at 0x6DF39D. The latter compares packet type 1009 at 0x6DF104 and subtype 27 at 0x6DF10C, calls Conquer_GetTimeGetTime at 0x6DF113, and stores the raw result at packet +16 at 0x6DF118 before the buffered send at 0x6DF12A.

This supersedes the on-wire XOR conclusion in the prior bootstrap note. Client main's GameLatencyTick1009 writes milliseconds XOR heroId. The controlled peer's echo agrees with the historical echo behavior, while original 5517 server reply bytes remain unobserved. [Prior bootstrap evidence](../../bootstrap-tolerance-cp24d.md) · [Client writer on main](https://github.com/berniemackie97/OpenConquerClient/blob/main/src/OpenConquer.Networking/Game/World/GameLatencyTick1009.cs)

## Remaining boundaries

- The account phase and DH exchange are sequence evidence only. Secret-bearing vectors require a separate explicitly derived fixture. The original client has no path for the project-defined registration extension opcodes 0xF001 and 0xF002.
- The existing-character setup did not exercise character creation, populated inventory or item-use 1009 subtypes, mounted movement, bit-38 map entry and 408, the 30-minute address report, correction 108/146, or other 1151 variants. The 10017 status probe left high64 zero.
- Original-server bytes, malformed transport framing and exhaustive variant coverage remain open. Client #297 and server #213 are merged static-derived fixtures. The open client #298 and server #214 governance PRs had no production source changes. The runtime evidence is a partial contribution to the open CP3.2 task. [CP3.2 task](https://github.com/berniemackie97/OpenConquerClient/issues/248) · [Client #298](https://github.com/berniemackie97/OpenConquerClient/pull/298) · [Server #214](https://github.com/berniemackie97/OpenConquerServer/pull/214)
