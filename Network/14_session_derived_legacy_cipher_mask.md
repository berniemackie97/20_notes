# Native 5517 session-mask audit

Date: 2026-09-03
Decision: **Intentionally omit the session-derived legacy-cipher mask from the standard OpenConquerServer GameServer protocol.**

## Executive result

The mask calculation is real, but it is not part of the active standard GameServer cipher in this executable. Successful packet 1055 installs encryption mode 2, then modifies an unused outbound legacy-TQ key schedule. Mode 2 bypasses that schedule before DH, during DH, and after DH.

The active GameServer primitive is **CAST5 / CAST-128 in CFB64 mode**, not Blowfish. DH messages have their own fixed-key CAST5 wrapper; subsequent traffic uses CAST5 keyed from the DH shared secret. This identification comes from the native code and exact crypto-table matches, not from OpenConquerPublic.

The two packet-1055 values remain important: the client forwards them unchanged in the post-DH packet-1052 login proof. Their direct effect on that packet must not be confused with an effect of the separately derived mask.

The original audit was non-mutating. This maintained record is now accompanied by reconstruction boundary comments and Binary Ninja analyst annotations; executable bytes and server behavior remain unchanged. The executable was not launched against a server.

## 1. Scope, identity, and evidence conventions

Primary input:

- 00_clean/clean/5517/Conquer.exe
- Original audit input /Volumes/EnderChest/Development/Repos/DotNet/Conquer/5517/Conquer.exe is byte-identical.
- 5,880,840 bytes; PE32 x86; preferred image base 0x00400000.
- SHA-256: b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62.
- The executable beside the active Conquer.exe.bndb and the clean GameDev retail copy have exactly the same hash.
- Binary Ninja database: 00_clean/clean/5517-bninja/Conquer.exe.bndb.

Evidence methods:

1. Native decompilation and cross-references.
2. Original x86 instructions, including independently decoded real entry points through the overlapping-instruction endpoint checks.
3. Raw executable searches for the mask constant, socket-state offsets, and mode field.
4. Execution of original x86 arithmetic, table-rekey, send/flush, and receive routines in Unicorn 2.1.4, with controlled inputs and intercepted CRT/Winsock operations.
5. Only afterward: source comparison against OpenConquerPublic, clean commit 11fa7ee1db02dc147afb9581bd456bedad79ed71.

Existing descriptive function names in the database are analyst labels, not proof of original source names. The former database label CMsgMapInfoEx1203 did not establish map semantics: its native caller and layout prove it is an alternate login bootstrap. The annotation update uses CMsgLoginBootstrap1203 names. Historical aliases in captured evidence are retained, and addresses remain the stable identifiers.

All addresses below are preferred virtual addresses. For every .text/.rdata address and backed .data address cited here, **file offset = VA - 0x00400000**. This follows from the PE section mappings, not an assumed universal PE rule. Globals above 0x00956000, including 0x0096AFDC, are zero-initialized virtual data and have no corresponding initialized file bytes.

| Function / location | VA | File offset |
|---|---:|---:|
| Packet-1055 processor | 0x0075492C | 0x0035492C |
| Cookie ADD / XOR | 0x00754C19 / 0x00754C1C | 0x00354C19 / 0x00354C1C |
| Mask XOR | 0x00754EAC | 0x00354EAC |
| Legacy schedule rekey | 0x00755DF3 | 0x00355DF3 |
| Socket constructor | 0x006E16B2 | 0x002E16B2 |
| Socket mode setter | 0x006DF1B0 | 0x002DF1B0 |
| Buffered send | 0x006E1A07 | 0x002E1A07 |
| Actual send flush | 0x006E215C | 0x002E215C |
| Socket receive/decrypt | 0x006E246C | 0x002E246C |
| Receive framing / DH orchestration | 0x006E1C83 | 0x002E1C83 |
| Legacy byte transform | 0x006E23A5 | 0x002E23A5 |
| DH challenge processor | 0x00753801 | 0x00353801 |
| DH response generator | 0x00753669 | 0x00353669 |
| Active CAST key setup | 0x00778790 | 0x00378790 |
| Active CFB64 transform | 0x00778590 | 0x00378590 |
| Active CAST block transform | 0x0077F310 | 0x0037F310 |

Full extracts: [native-evidence.txt](../../10_work/docs/evidence/session-mask-5517/native-evidence.txt).

Executable probe: [native_probe.py](../../10_work/docs/evidence/session-mask-5517/native_probe.py).

Recorded passing results: [native-probe-results.txt](../../10_work/docs/evidence/session-mask-5517/native-probe-results.txt).

## 2. Packet 1055: origins and storage

**VERIFIED NATIVE REQUIREMENT**

The dispatch factory at 0x006DF824 selects packet type 0x041F (1055), constructs the object at 0x007548A3, and the virtual processor is 0x0075492C. The vtable at 0x0086D060 contains the parse pointer 0x00754909 and process pointer 0x0075492C.

The message object is 0x408 bytes. Its +0x404 member points to its inline packet buffer at object+4; the packet's own four-byte length/type header is therefore included in the offsets below. CNetMsg__ValidateHeaderAndCopy at 0x006DF2AE copies incoming bytes into object+4. The 1055 parser checks type 0x041F at 0x00754925.

| Offset from packet header | Native value | Storage/use |
|---|---|---|
| +0x00 | uint16 declared length | Generic packet parser |
| +0x02 | uint16 opcode 1055 | Parser type check |
| +0x04 | uint32 sessionUid | CHero+0xA9C, store instruction 0x00754B72 |
| +0x08 | uint32 authenticationKey, or failure code when UID=0 | CHero+0x2F5C via call 0x00754BBE to setter 0x00663795 |
| +0x0C | GameServer port, read as a dword then narrowed by socket connect | 0x00754E09; connect at 0x00754E21 |
| +0x10 | additional session field | CHero+0xAA0, store 0x00754B98; later used by 1203 |
| +0x14 | server IPv4 string | endpoint validation/copy/connect |

CHero_GetSingletonPtr at 0x00404460 returns the object held at global 0x00955F8C. The authentication-key setter writes [this+0x2F5C] at 0x00663799; the getter reads it at 0x006637A8.

When packet+4 is zero, the processor enters the login-failure branch. Packet+8 is then used as an error code, not as an accepted authentication key; the cookie/rekey path is not executed.

Native evidence establishes two opaque 32-bit grant values and how they are forwarded. It does not establish that sessionUid must equal a persistent account ID, a character ID, or a particular database primary key.

## 3. Consumers during the transition

These are the identity-aware consumers on the standard 1055 transition, followed by the generic wire-processing chain:

| Consumer | Evidence and role |
|---|---|
| 1055 processor, 0x0075492C | Checks success, saves UID/key/additional field, computes cookie |
| CHero key setter, 0x00663795 | Stores authenticationKey |
| MAC report builder, 0x00767DA1 | Called at 0x00754BEA; writes UID at packet+4 in opcode 1100 |
| Account resource-report builder, 0x007543CA | Called at 0x00754CAC; writes UID at packet+4 and resource version at packet+8 in opcode 1052; no authenticationKey or mask |
| GameServer continuation, real entry 0x00754D4C | Selects mode 2, computes mask, passes it to the outbound legacy schedule |
| Rekey routine, 0x00755DF3 | Consumes mask and mask squared; no packet generation |
| Post-DH bootstrap dispatcher, 0x006DF1D0 | Selects standard 1052 or alternate 1203; does not calculate a mask |
| Standard proof sender, 0x007544E8 | Reads CHero+0xA9C and calls key getter at 0x007545EA |
| Standard proof builder, 0x0075443E | Writes UID at packet+4 and key at packet+8 |
| Alternate proof sender, 0x007559FC | Reads UID, key, additional field, and alternate launch data |
| Alternate proof builder, 0x00755930 | Writes those values into opcode 1203; no cookie/mask |

Generic delivery is:
CNetMsg__Send 0x006DF355 -> sub_6DF0E0 -> CGameSocket_SendBufferedPacket 0x006E1A07 -> CGameSocket_FlushSendBuffer 0x006E215C -> Winsock send at 0x006E218B.

The generic functions see packet buffers, not a separate session-mask argument. Their only possible access to its derived tables is the explicitly gated legacy-transform call described below.

The pre-disconnect opcode-1100 and resource-report opcode-1052 transmissions use the existing AccountServer socket. CNetClient_DisconnectAndDisposeSocket at 0x006DF043 flushes that socket before freeing it. Thus the GameServer rekey is not a change to the existing AccountServer stream.

## 4. Exact arithmetic, widths, and destination

**VERIFIED NATIVE BUT VESTIGIAL/UNUSED on the standard GameServer path**

Essential original instructions:

```asm
; 1055 packet bytes have already been copied into the message object
00754C16  mov eax, dword [eax+4]
00754C19  add eax, dword [ecx+8]
00754C1C  xor eax, 0x4321
00754C21  mov dword [ebp-0x830], eax       ; cookie, stack-local

00754E91  push 2
00754E98  call CNetClient_SetSocketEncryptionMode
00754EA9  mov eax, dword [eax+8]
00754EAC  xor eax, dword [ebp-0x830]
00754EB2  mov dword [ebp-0x980], eax      ; mask, stack-local
00754EC1  mov eax, dword [0x96AFDC]      ; current socket pointer
00754ECC  push dword [ebp-0x980]
00754ED8  add ecx, 0x12014
00754EDE  call 0x755DF3
```

Equivalent width-explicit pseudocode:

```c
uint32_t cookie = (uint32_t)(sessionUid + authenticationKey) ^ 0x00004321u;
uint32_t mask = authenticationKey ^ cookie;
ApplyLegacyMask(socket + 0x12014, mask);
```

The addition is x86 32-bit ADD, with wraparound modulo 2^32. No carry is propagated and no overflow exception/check is used. The later square is two-operand 32-bit IMUL at 0x00755E00: only the low 32 product bits are retained. The signed instruction name does not change those low bits.

**Important correction to the premise:** no persistent scalar mask field is stored in the socket. Cookie and mask are stack temporaries. The durable effect is an in-place change to two byte tables.

Rekey at 0x00755DF3:

```c
uint32_t squared = (uint32_t)(mask * mask);
for (unsigned offset = 0; offset < 256; offset += 4) {
    xor_u32_le(cipher + 0x008 + offset, mask);
    xor_u32_le(cipher + 0x108 + offset, squared);
}
```

Instructions 0x00755E0B and 0x00755E11 perform the two read-modify-writes; the loop increments by four at 0x00755E13 and tests 0x100 at 0x00755E19. Exactly 64 dwords per table are changed. Counters are not reset by this routine.

### Object ownership and non-overlapping layout

CNetClient is global 0x0096AFC8. Its +0x14 member, global 0x0096AFDC, owns the heap socket. CNetClient_ConnectWithEndpointAndTimeout at 0x006DEF5F first destroys the old socket, allocates 0x124D4 bytes at 0x006DEF8D, constructs a fresh socket, and assigns it at 0x006DEFAE.

| Socket offset | Meaning |
|---|---|
| +0x00000 .. +0x01FFF | Outbound byte buffer |
| +0x02000 | Outbound buffered byte count |
| +0x02004 | Winsock handle |
| +0x02008 | Connected state |
| +0x0200C .. +0x1200B | Receive ring buffer |
| +0x1200C / +0x12010 | Receive available-count / cursor |
| +0x12014 / +0x12018 | Legacy outbound low/high counters |
| +0x1201C .. +0x1211B | Legacy outbound table A, XORed with mask |
| +0x1211C .. +0x1221B | Legacy outbound table B, XORed with mask squared |
| +0x1221C / +0x12220 | Separate legacy inbound counters |
| +0x12224 .. +0x12423 | Separate legacy inbound tables, not rekeyed here |
| +0x12424 | DH-pending flag |
| +0x12428 | Encryption mode |
| +0x1242C | Handshake receive-position bookkeeping |
| +0x12430 | ClientSecurity context |
| +0x12434 / +0x12438 | CAST inbound/outbound feedback positions |
| +0x1243C | ClientSecurity initialized flag |
| +0x1243D .. +0x12444 | CAST inbound IV |
| +0x12445 .. +0x1244C | CAST outbound IV |
| +0x12450 .. +0x124D3 | CAST_KEY: 32 uint32 subkeys and short-key flag |

The legacy mask writes stop immediately before the inbound legacy object. They cannot overlap the DH flag, mode, CAST IVs, or CAST key schedule.

## 5. Every subsequent table read and mode gate

The only byte-consumption routine for these legacy tables is 0x006E23A5. Its table read instructions are:

- 0x006E23CC: read [cipher + 8 + lowCounter].
- 0x006E23D7: read [cipher + 0x108 + highCounter].

It XORs both bytes into the input, advances the counters, swaps nibbles, and XORs 0xAB at 0x006E2406.

The routine has three actual call sites:

1. 0x006E1BDC: outbound state socket+0x12014.
2. 0x006E255F: inbound state socket+0x1221C.
3. 0x006E2628: inbound state socket+0x1221C, second receive span after ring wrapping.

Only the first can read the mask-modified tables. The other two reference the untouched inbound object.

The rekey routine itself reads the old table words while updating them. There are no additional later scalar-mask reads: no such socket scalar exists.

### All mode assignments

The executable has three direct writers of socket+0x12428:

- Constructor 0x006E1703: zero.
- Close/reset 0x006E22FA: zero.
- Setter 0x006DF1C4: caller-supplied mode, range-checked 0..4.

Seven unique setter call sites:

| Call site | Mode | Context |
|---|---:|---|
| 0x0066D486 | 1 | Fresh AccountServer connection |
| 0x00754E98 | 2 | Successful 1055 -> GameServer |
| 0x007557F1 | 2 | Successful 1057/BGP endpoint alternative -> GameServer |
| 0x004AF6EC | 3 | Fresh picture-key service connection |
| 0x004AF3F8 | 4 | Fresh account-binding service connection |
| 0x006DEF24 | 0 | Disconnection cleanup |
| 0x005BC79C | 0 | Main-window disconnection cleanup |

The mode-1/3/4 setters follow creation of fresh sockets, which regenerate the default legacy schedules. They do not switch a live, masked mode-2 GameServer socket into a legacy mode.

Raw executable scans found only three occurrences of the cookie constant 0x4321, corresponding to the three handlers discussed here, and only three unique calls to 0x00755DF3. Duplicate Binary Ninja xrefs at 0x00754EDE are overlapping function annotations, not a fourth call.

## 6. Actual send path and wire effect

At 0x006E1AE4, SendBufferedPacket copies packet bytes into the outbound queue. It then reads socket+0x12428 at 0x006E1AE9:

```c
switch (socket->mode) {
case 1:
case 3:
case 4:
    LegacyTransform(socket + 0x12014, queuedBytes, packetLength, true);
    break;
case 2:
    if (!socket->dhPending) {
        ClientSecurityEncrypt(socket + 0x12430, packet, queue, packetLength);
        ClientSecurityEncrypt(socket + 0x12430, "TQClient", queueTail, 8);
        queuedLength += 8;
    }
    break;  // while DH is pending, preserve already-wrapped handshake bytes
default:
    break;
}
queuedLength += packetLength;
```

Relevant instructions/calls:

- Mode tests: 0x006E1AF2..0x006E1B09.
- DH-pending test: 0x006E1B14.
- Active packet encryption: 0x006E1B4D -> 0x00753C5B.
- Active trailer encryption: 0x006E1B98 -> 0x00753C5B.
- Legacy transform: 0x006E1BDC, reachable only for modes 1/3/4.
- Physical send: 0x006E218B, send(socketHandle, socketBuffer, queuedLength, 0).

There is no additional transform in FlushSendBuffer. It sends the queued bytes and shifts unsent bytes after partial sends.

Consequently, in the actual standard mode 2, neither raw pre-session transport nor post-DH payload/trailer encryption can read the mask-modified tables.

## 7. Actual receive path, DH, and framing

Winsock recv at 0x006E24D8 fills the receive ring. The same mode decision is made at 0x006E24EB:

- Modes 1/3/4: legacy transform with socket+0x1221C.
- Mode 2 with DH pending: leave received bytes unchanged for the handshake parser.
- Mode 2 after DH: call ClientSecurityDecrypt 0x00753CA1 at 0x006E2539.

The second receive span uses the same decision and calls active decryption at 0x006E2601 or legacy decryption at 0x006E2628. No branch uses the outbound tables.

ReceiveMsg at 0x006E1C83 performs framing and handshake orchestration:

1. In mode 2 with DH pending, call 0x00753801 at 0x006E1E70.
2. On a complete valid challenge, generate the client response via 0x00753669 at 0x006E1ECF.
3. Queue the generated bytes at 0x006E1EF6 and flush at 0x006E1EFD while DH-pending remains true.
4. Clear DH-pending at 0x006E1F1E.
5. Call post-DH login bootstrap 0x006DF1D0 at 0x006E1F27.

After DH, it reads the decrypted packet length, includes an additional eight bytes in frame availability, and checks the trailing "TQServer" at 0x006E1FF6. The send counterpart encrypts the "TQClient" trailer. Neither framing operation consults the legacy tables or mask.

### Handshake and active cipher provenance

0x00753801 creates a temporary schedule from literal "BC234xs45nme7HU9", a zero IV and zero feedback position, then decrypts the challenge using 0x00778590. It extracts directional IVs and the DH p/g/server-public fields.

Native DH operations:

- Hex parsing: 0x00779F90.
- DH key generation dispatch: 0x0077A290.
- DH shared-secret dispatch: 0x0077A2A0.
- Default method table: 0x0094C330.
- Actual generation / shared-secret functions: 0x0077A2D0 / 0x0077A460.
- The latter performs modular exponentiation using DH private exponent and p at 0x0077A54E, then converts the result to bytes at 0x0077A56C.

The caller zeroes a DH_size-sized output buffer, writes the minimal big-endian DH result into its beginning, then calls active key setup at 0x00753BFC. No UID, authenticationKey, cookie, mask, or legacy-table pointer is an input.

0x00753669 constructs the client response from the DH public key and random padding. It separately uses the same fixed literal, zero IV, and zero feedback position at 0x007537B9/0x007537E0. It does not use the newly derived session schedule to wrap the response.

0x00753C5B and 0x00753CA1 use only ClientSecurity+0x20 key schedule, +0x15/+0x0D IVs and +8/+4 feedback positions. Both call 0x00778590, the active CFB64 routine.

### CAST5, not Blowfish

This is independently established by:

- 0x00778790 caps key input at 16 bytes and stores a short-key flag at key+0x80.
- 0x0077F310 implements the CAST add/XOR/subtract-and-rotate round structure.
- All 2,048 words of all eight native S-boxes match the official OpenSSL CAST tables byte-for-byte:
  - table0 0x0086DF90; table1 0x0086E390; table2 0x0086E790; table3 0x0086EB90;
  - table4 0x0086EF90; table5 0x0086F390; table6 0x0086F790; table7 0x0086FB90.
- Key schedule and CFB64 control flow match the corresponding official implementations.

Primary algorithm references, used only to identify the native primitive:
[OpenSSL CAST tables](https://github.com/openssl/openssl/blob/OpenSSL_1_0_0d/crypto/cast/cast_s.h),
[CAST key setup](https://github.com/openssl/openssl/blob/OpenSSL_1_0_0d/crypto/cast/c_skey.c),
[CAST CFB64](https://github.com/openssl/openssl/blob/OpenSSL_1_0_0d/crypto/cast/c_cfb64.c).

## 8. Alternate paths

### Standard outgoing 1052

0x0075443E writes:

- +0 length 0x1C; +2 opcode 0x041C;
- +4 UID; +8 authenticationKey;
- +0x0C mode 0x007C;
- +0x0E two locale bytes;
- +0x10 six MAC-address bytes;
- +0x18 resource version.

The caller at 0x007545FC gets UID/key from CHero without cookie arithmetic. It sends through mode 2 after DH. The mask does not alter its content or cipher.

### Incoming legacy 1052 response

The dispatch factory at 0x006DF7D2 selects opcode 1052 and its vtable at 0x0086D04C routes processing to sub_75464C.

This handler computes the same cookie at 0x007546F8, disconnects, connects to packet+0x0C at fixed port 0x16B8 (5816), immediately builds/sends a 1052 proof at 0x00754831/0x00754840, and then applies the mask at 0x00754861.

It does **not** set mode 1 or 2 on the fresh socket. The constructor leaves mode 0. Consequently the immediate proof is sent without the legacy transform, and the later rekey has no active cipher consumer in this handler. This is a different retained compatibility path, not the standard 1055/DH path. Its historic production deployment/support is not established by its mere presence.

### Incoming 1057 endpoint/BGP alternative

The factory's opcode 0x0421 case at 0x006DF84D selects constructor 0x00754F4D and processor 0x00754FD6.

It saves UID/key and computes the same cookie at 0x0075513F. It evaluates primary/BGP endpoints, connects via the continuation around 0x007555E7, explicitly sets mode 2 at 0x007557F1, then applies the mask at 0x00755837. Thus the same inactive-table conclusion holds after either successful endpoint choice.

### Facebook / alternate outgoing 1203

The global at 0x0096AB34 is set when launch parsing obtains five fields (0x005AAF72). The flag also selects the Facebook-related login failure branch and alternate AccountServer request 1121, and selects the 1203 post-DH bootstrap at 0x006DF1E0.

The 1203 builder at 0x00755930 writes length 0x60, type 0x04B3, UID at +4, the additional 1055 field at +8, authenticationKey at +0x0C, mode 0x7C at +0x10, locale/MAC/resource metadata and a 64-byte alternate value at +0x20.

It is selected by the same post-DH dispatcher. It neither computes nor reuses the mask. The extra fields are alternate-authentication payload, not evidence of another transport mask or standard-path persistent secret.

### OEM / mobile protection / binding / picture-key services

CGameMain_AccountSetupAndSendLoginAuthPacket at 0x0066D4C1 reads ini/oem.ini [AccountSetup] Type and selects credential/request variants, including 1060, 1084, 1098, 1102 and 1121. These are upstream AccountServer request choices; they do not provide another rekey call or overwrite the GameServer mode.

The binding and picture-key paths select modes 4 and 3 only after creating fresh sockets. Those services use the legacy cipher, but do not inherit a mask-modified GameServer schedule.

The obfuscated branch at 0x00754CCA is also not an alternate mask cipher. Resolving its return-address jumps gives real code at 0x00754D01 -> inet_addr(packet+0x14), then 0x00754D4C. It rejects invalid addresses and first-octet 127 (low byte satisfies remainder 1 modulo 7 and remainder 12 modulo 23). The rejected branch at 0x00754DAE only performs cleanup. The accepted branch connects and selects mode 2. No secret/mask choice is hidden in that gate. The 1057 continuation contains the equivalent endpoint check.

## 9. Native execution checks

The probe executes original machine instructions loaded from the hashed executable. It does not reimplement the transport branches. Hooks intercept memcpy/memset and Winsock send/recv so no actual network connection is created.

Checks passed:

- Four cookie/mask input pairs, including 0xFFFFFFFF+1 and 0x80000000+0x80000000 overflow.
- Five rekey masks, comparing the entire 0x124D4-byte socket against the exact expected changes: only the two outbound 256-byte tables changed.
- Six send-mode configurations, comparing mask=0 with mask=0xDEADBEEF.
- Twelve receive configurations, including both non-wrapping and wrapping receive-buffer spans.
- Positive controls in modes 1, 3 and 4 demonstrate that the probe detects a real mask effect.

| Native transport configuration | Mask changes outbound bytes? | Reads changed outbound tables? |
|---|---|---|
| Mode 2, DH pending | No | None |
| Mode 2, established session | No | None |
| Mode 0 | No | None |
| Modes 1 / 3 / 4, forced positive controls | Yes | 0x006E23CC and 0x006E23D7 |
| Receive in all tested modes, both ring layouts | No | None |

A 28-byte controlled 1052 payload produced exactly the same 36 bytes after mode-2 encryption and trailer addition with either mask:
a01ca623303e90740d1101e795ee2d2fd51f965a04ad54cd9d7f83be70e3e7ba6d440d66.

This vector uses a controlled 16-byte key and zero IVs, not a captured retail session. DH negotiation itself was statically traced, not executed end-to-end by this probe. The pending-DH transport probe tests pass-through behavior, not generation of a valid DH message. These limits do not weaken the structural fact that neither handshake routine has a reference to the changed tables.

Changing UID/key naturally changes their serialized proof bytes. The differential test deliberately holds payload, active cipher state and other inputs constant while perturbing only the legacy mask state; this isolates the mechanism under audit.

## 10. Comparison against OpenConquerPublic — secondary evidence only

Compared the user-specified checkout at `50_server/OpenConquerPublic`, clean commit `11fa7ee1db02dc147afb9581bd456bedad79ed71`. Its relevant source files match the earlier comparison checkout. No behavior above was inferred from either server copy.

### It omits the derived legacy mask

- [LoginTicketIssuer.cs:27-30](../../50_server/OpenConquerPublic/src/OpenConquer.Application/Auth/Tickets/LoginTicketIssuer.cs:27) creates independent UID/authentication-key values.
- [LoginHandshakeWriter.cs:58-83](../../50_server/OpenConquerPublic/src/OpenConquer.Protocol/Login/Handshake/Writers/LoginHandshakeWriter.cs:58) emits them in packet 1055 without a cookie/mask.
- [GameConnectionHandoffProcessor.cs:25-48](../../50_server/OpenConquerPublic/src/OpenConquer.GameServer/Network/Handshake/GameConnectionHandoffProcessor.cs:25) sends the DH challenge and completes DH before reading the identity proof.
- [GameConnectionHandoffProcessor.cs:56-77](../../50_server/OpenConquerPublic/src/OpenConquer.GameServer/Network/Handshake/GameConnectionHandoffProcessor.cs:56) decrypts/parses 1052, then consumes the UID/key ticket.
- [GameHandshakeBootstrapCipher.cs:5-23](../../50_server/OpenConquerPublic/src/OpenConquer.Protocol/Game/Crypto/GameHandshakeBootstrapCipher.cs:5) uses the same fixed literal and zero IV.
- [GameHandshakeExchange.cs:86-106](../../50_server/OpenConquerPublic/src/OpenConquer.Protocol/Game/Handshake/GameHandshakeExchange.cs:86) derives session key material from DH only.
- [TqCipher64Cfb64Stream.cs:18,38-42](../../50_server/OpenConquerPublic/src/OpenConquer.Protocol/Game/Crypto/TqCipher64Cfb64Stream.cs:18) uses CAST5 and caps the key at 16 bytes.
- [GameSessionCipher.cs:21-24](../../50_server/OpenConquerPublic/src/OpenConquer.Protocol/Game/Transport/GameSessionCipher.cs:21) creates independent directional CAST streams; :113-116 appends/encrypts the server trailer.

A source search found no 0x4321/cookie/session-mask mechanism in the active server implementation. Its login-cipher XorMask=0xAB is the unrelated per-byte legacy operation, not this session-derived mask.

**It omits the native leftover; it does not replace it with a hidden new cipher.** DH+CAST5 is itself the verified native active transport.

### Server implementation choices versus native requirements

**LEGACY SERVER IMPLEMENTATION CHOICE**

- Treating sessionUid as a random ticket identifier distinct from accountId.
- Defining ticketId == sessionUid.
- Duplicating authenticationKey into packet-1055's additional +0x10 field ([LoginHandshakeProcessor.cs:225](../../50_server/OpenConquerPublic/src/OpenConquer.AccountServer/Login/Handshake/LoginHandshakeProcessor.cs:225)). Native code only proves that this extra field is retained and forwarded by 1203; equality with authenticationKey is not a native standard-path requirement.
- Persisting tickets in a relational table.
- Selecting a fixed DH group; the native client receives p/g from the challenge.
- Supporting standard 1052 while rejecting unsupported alternate proof formats.

**MODERN SERVER HARDENING**

- Cryptographically generated grant tokens.
- Expiration and replay protection.
- Conditional/atomic single-use ticket consumption.
- Binding a valid ticket to the account identity.
- Limits and validation on unauthenticated handshake/proof traffic.

For example, [EfLoginTicketRepository.cs:12](../../50_server/OpenConquerPublic/src/OpenConquer.Infrastructure/Persistence/Auth/Tickets/EfLoginTicketRepository.cs:12) sets a five-minute lifetime; :52-61 checks UID/key/expiry and conditionally deletes the ticket, and :63-68 rejects competing consumes. This policy is not encoded by the native mask arithmetic and must not be described as a recovered native database requirement.

## 11. Required server state and implementation boundary

**VERIFIED NATIVE REQUIREMENT**

The standard client must receive a successful 1055, negotiate the native DH/CAST5 transport, and then send UID/key in encrypted 1052. It has no additional standard-path mask field, mask-dependent DH input, mask-dependent framing, or mask-dependent active session-cipher key.

**VERIFIED NATIVE BUT VESTIGIAL/UNUSED**

The session-derived legacy outbound table rekey is executed but not consumed by the standard mode-2 transport. The generic legacy-TQ cipher itself is not globally dead: it is active for the separate mode-1/3/4 services.

**Server persistence conclusion**

No additional persistent mask/cookie/shared-server secret is implied. DH private values, shared key, IVs and feedback positions are connection-local crypto state, not extra account-derived persistent state. Server-side authentication still needs an authoritative way to validate and associate the presented grant with an account. Whether that is a database, cache, inter-service grant exchange or another design cannot be recovered from this client.

**STILL UNRESOLVED**

- The historical reason the obsolete rekey calls remain.
- Whether a particular vendor server deployment enabled legacy incoming-1052 or 1057/Facebook paths.
- Server-internal database schema and additional server-side checks.
- Behavior of other executable hashes, patched clients or injected networking/protection code.
- A live Windows end-to-end packet capture was not performed.

These are separate questions; none is necessary to decide whether this exact standard transport needs the mask.

| Boundary | Engineering action |
|---|---|
| AccountServer grant generation | Issue valid UID/key fields; do not derive/store a transport mask |
| GameServer pre-DH transport | Do not apply the mask or legacy schedule |
| DH/session establishment | Implement native fixed-key CAST5 handshake and DH derivation; no UID/key mask input |
| Post-DH packet cipher | Implement CAST5-CFB64 with directional IV/state and native trailers; no legacy-mask layer |
| First secured login proof | Validate UID/key from 1052, with deliberate server-side ticket security policy |
| Optional exact historical client-state emulator | May reproduce the dormant table mutation for parity/testing, isolated from active transport |
| Future legacy-protocol support | Require separately specified mode/version evidence; do not enable it by assumption |

## Final recommendation

Maintenance record: the 2026-09-03 annotation update renamed 17 Binary Ninja
functions and added/appended 32 function comments plus 29 address comments.
Every name/address/comment was read back; existing comments were retained.
The database save completed. See the [before/after annotation manifest](../../10_work/docs/evidence/session-mask-5517/bninja-annotations.json)
and [verification record](../../10_work/docs/evidence/session-mask-5517/verification.md). Retail executable bytes and
server source were not changed. Documentation aliases were corrected where
they previously implied suit/achievement/map semantics or a proprietary CAST variant.

**OpenConquerServer: intentionally omit this mechanism from the standard 5517 login protocol.** Preserve UID/authenticationKey in the grant and post-DH proof, implement the native DH + CAST5-CFB64 path, and apply explicit modern ticket validation. The native mode-2 branches bypass the only reads of the rekeyed tables, and original-instruction differential probes confirm no send/receive byte effect from the mask.
