# Existing-character login: reference-server comparison

Date: 2026-09-16. This extends the
[native 2078/2079 audit](10_extended_packets.md#successful-existing-character-login-audit-2026-09-15).
The reference projects below provide implementation examples and search hints;
native 5517 Binary Ninja instructions remain authoritative for client behavior.

## Findings saved during the comparison

The previous audit's 23 function names and 17 nonempty function comments were
restored in the restarted `Conquer.exe.bndb` view and verified through MCP.
The user handles database saving. The restoration readback is in
`10_work/docs/evidence/post-auth-2078-2079-5517/annotations-restored-2026-09-16.json`.

| Local project | 2078 construction / existing-character send | 2079 construction / existing-character send |
|---|---|---|
| `50_server/OpenConquerPublic` | Sends `(timestamp=0, flag=0, location="")`, total packet length 10 | Sends state 0, total length 8 |
| `50_server/OpenConquer5517v3` | Sends the same zero tuple under the old incorrect title-label names | Sends state 0 |
| `50_server/Conquer5517` | Packet ID enum entry only in the searched C# sources; no implementation found | Same |
| `50_server/5517Conquer` | No matching packet implementation found in the searched C# sources | Same |
| FoxConquer5517 | Its actual existing-character login path sends `new MsgUserIpInfo()`: timestamp `0x4E591DBA`, followed by zero bytes; declared packet length 264 | Sends `ClassicMode=0, PotencyMode=0`; declared packet length 12 |
| Canyon 6192 and local `canyon-main` (README targets 6090) | Class exists with timestamp `0x4E591DBA`, Action byte and DifferentAddress bool; no construction/send call found in their searched C# sources | Actual login path sends `new MsgServerInfo()`, two zero int32 values, total length 12 |
| Long 6270 | Packet enum entry exists; no matching 2078 class/send found in the searched C# sources | Actual login path sends `new MsgServerInfo()`, two zero int32 values, total length 12 |

The two Canyon copies have byte-identical `MsgUserIpInfo.cs`, `MsgServerInfo.cs`
and `MsgConnect.cs`; they are not two independent observations. The old managed
projects likewise must not be counted as independent native discoveries.

## Native cross-check already established

- 2078 parser `0x75B006` checks type after common header/copy validation. It does
  not demand Fox's 264-byte length. Both the compact 10-byte empty form and Fox's
  padded form fit the native packet buffer and required fields.
- 2078 Process `0x75B029` and setter `0x6577BF` read timestamp at +4, alert byte
  at +8, and NUL-terminated location at +9. Fox's padding means an empty location,
  not a separate seed block. A nonzero timestamp follows the account-history
  display path; timestamp zero skips content rebuild in dialog `0x4189D2`.
- Canyon's `DifferentAddress` byte at +9 must not be ported as a 5517 boolean:
  false happens to be the empty string terminator; true becomes location byte
  `0x01`. The native alert test uses +8, and treats Action values 1 and 2 alike
  as nonzero for that test. The alternate BGP/auth presentation predicate still
  applies before the extra warning is added.
- 2079 parser `0x75AF53` permits extra bytes; Process `0x75AF76` only reads +4.
  The reference projects' second dword at +8 is unused by this 5517 handler.
  Sending 12 bytes therefore does not establish that the extra dword is required.
- State 0 selects native status-UI state 2000; state 1 selects 2001. Other u32
  values preserve it. The reference name `ClassicMode` is a hint, not a recovered
  meaning for every 5517 use of this global.

Fox's fixed `0x4E591DBA` equals 1314463162 (2011-08-27 16:39:22 UTC when interpreted
as Unix seconds). It is hardcoded, not loaded from the account's prior login.
There is no reason to substitute this historical timestamp for real account
history. Source comments claiming a packet is mandatory do not override the
native `1006` build/send dataflow.

## Native consequences of the existing wire values

The existing OpenConquerPublic bytes are 2078 `(0,0,empty NUL text)` and 2079
state `0`. Native instructions establish their effects: store that tuple, skip
account-alert content rebuilding because timestamp is zero, and assign state
2000. This is an input/output fact, not a claim that the binary requires those
values or that reference-server agreement establishes retail policy.

The zero-timestamp branch returns at `0x418FDE` before the dialog layout resets
at `0x418AAD/0x418AB4`. It does not prove that existing dialog content is cleared.
Calling the zero tuple a general reset or guaranteed clean UI state would be
stronger than the native evidence.

The compact packets, excluding the transport footer, are:

```text
2078: 0A 00 1E 08 00 00 00 00 00 00
2079: 08 00 1F 08 00 00 00 00
```

For nonzero timestamps, the native consumer calls `localtime`; a null result
returns without rebuilding. With a nonempty hero name and valid time conversion,
the normal presentation uses the received location only when its length exceeds
one; otherwise it uses the unknown-city resource. The flag comparison gives no
special meaning to values 1 versus 2, and no canonical server choice is selected
by that comparison. These are native branches, not an inferred server policy.

The client consumption contract above is proven from native instructions. The
exact retail-server historical values are not established by the reference
projects or by the replay. Source inspection is not a new native
login test. No production packet values or order were changed in this comparison.

## Reproducible native candidate checks

[Replay script](../../10_work/docs/evidence/post-auth-2078-2079-5517/replay_reference_candidates.py)
and [40 passing results](../../10_work/docs/evidence/post-auth-2078-2079-5517/reference-candidate-replay.json)
execute the unmodified clean 5517 instructions in an x86 emulator. The executable
hash is pinned to the same image as the original Binary Ninja byte verification.

- Ten 2078 cases include the working zeros, Fox's 264-byte packet, Canyon's unused
  default construction and its true-boolean variant, synthetic history with
  flags 0/1/2/255, a one-character location, and an all-bits-set timestamp.
  They validate/copy, store the unchanged timestamp/flag, call the char-range
  assignment with the expected location bytes, and post `0xD39, 0`.
- Thirty 2079 cases combine initial state 2000/2001, wire values
  0/1/2/2000/0xFFFFFFFF, and no extra dword / zero extra dword / `0xDEADBEEF`
  extra dword. Only the first dword affects state. Unknown values preserve it.

Limits: constructor state is initialized from its audited layout. Hooks replace
`memcpy`, `strlen`, hero singleton lookup, char-range assignment, and message
posting. The native validators, numeric stores, field offsets, branches, call
arguments and 2079 assignments execute unchanged. The hook records location
assignment arguments; it does not execute the native heap/vector implementation.
The Windows CRT `localtime`, actual dialog rendering, socket transport and a full
login are not executed by this probe. All-bits-set timestamp acceptance proves
storage only, not a valid displayable time. Canyon's true-boolean variant relies
on the constructor-zeroed buffer to terminate the one-byte string and is a
diagnostic case, not a recommended wire encoding.

The static native dialog evidence from the original audit supplies the separate
zero-timestamp, location-length and warning-branch conclusions. The reference
project encoders were inspected; replay candidates were derived from those
writers, not captured from running servers.

## Source provenance

[27 source hashes and numbered excerpts](../../10_work/docs/evidence/post-auth-2078-2079-5517/reference-sources-2026-09-16.json)
record the exact local copies used. Principal anchors:

| Project root | Relevant files and lines |
|---|---|
| `client-5517/50_server/OpenConquer5517v3` | `src/OpenConquer.GameServer/Sessions/GameClientSession.cs:78-84,497-501,880-891`; `Handlers/Login/ConnectHandler.cs:102-108` |
| `Remakes/Conquer/Servers/FoxConquer5517-master/FoxConquer5517-master` | `ServerCore/Networking/Packets/2078-UserIpInfo.cs:15-20`; `2079-ServerStatus.cs:19-38`; `PacketStructure.cs:80-84,274-287`; `MsgServer/Network/GameServer/Handlers/1052-MsgConnect.cs:124-127,166-198` |
| `Remakes/Conquer/Servers/CanyonV6192-main` | `src/Canyon.Game/Sockets/Game/Packets/MsgUserIpInfo.cs:8-31`; `MsgServerInfo.cs:8-17`; `MsgConnect.cs:122-127`; `src/Canyon.Network/Sockets/TcpServerActor.cs:70-76` |
| `Remakes/Conquer/Servers/ServersClients/canyon-main` | Same three packet/login files, byte-identical to the CanyonV6192 copies; README identifies 6090 |
| `Remakes/Conquer/Servers/LongV6270-main/LongV6270-main` | `src/Long.Kernel/Network/Game/Packets/MsgServerInfo.cs:7-16`; `MsgConnect.cs:92-97`; `src/Long.Network/Packets/PacketType.cs:138-139`; `Sockets/TcpServerActor.cs:75-82` |

Paths above are under `/Volumes/EnderChest/Development/Repos/GameDev/`; the
`client-5517` row is under its `Conquer` directory. The manifest contains full roots.
The broader Howmuch 5517 source search also found a `MsgServerInfo` name for a
different vigor/action packet; a matching class name alone was not treated as
evidence for wire type 2079.
