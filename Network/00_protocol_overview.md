# Network Packet System — Full Protocol Documentation
## Source: F:\CQ2ClientRelease-42.0.1\3DRole\Network\

---

## Packet Format (All Messages)
```c
struct PacketHeader {
    uint16_t size;      // +0: Total packet size including header
    uint16_t type;      // +2: Message type ID
    // payload follows...
};
// Max packet size: 1024 bytes
// Byte order: Little-endian
// Encryption: See "Encryption/Handshake (EncState == 2)" below (CAST5-CFB64 + signature trailer)
```

### Header validation helper semantics (verified)

`CNetMsg__ValidateHeaderAndCopy` (`0x6DF2AE`) enforces:
- `Src != null`
- `packet.size == provided Size` (exact match)
- `packet.type != 0`
- `memcpy(this+4, Src, Size)` on success

It does **not** validate a specific message type ID; each message parse wrapper checks its own expected type afterward (for example `CMsgUserInfo__Parse` checks `type == 1006`).

## Encryption/Handshake (EncState == 2)
> **See also**: [13_connection_lifecycle.md](13_connection_lifecycle.md) for the complete connection lifecycle including TCP connect, DH key exchange, authentication, CGameSocket memory layout, and CClientSecurity internals.

This build implements its DH handshake and packet crypto at the `CGameSocket` layer (not via `CNetMsg` packet dispatch).

**2026-09-03 native consumer audit:** the post-1055 session-derived mask rekeys
outbound legacy tables, but mode 2 never consumes them. It is not a DH input,
packet checksum, framing change, or extra GameServer encryption layer.
See the [full binary-backed session-mask audit](/Volumes/EnderChest/Development/Repos/GameDev/Conquer/client-5517/20_notes/Network/14_session_derived_legacy_cipher_mask.md) for the exact
send/receive branches, 1052/1057/1203 alternatives and original-x86 probes.

### Handshake Phase (`CGameSocket+0x12424` != 0)
1. `CGameSocket__RecvFromSocket` (0x6E246C) receives raw bytes into the ring buffer. When `EncState == 2` and the handshake flag is set, it does **not** decrypt those bytes.
2. `CGameSocket__ReceiveMsg` (0x6E1C83) calls `CClientSecurity__ProcessServerDhChallenge` (0x753801) on the remaining bytes.
3. On success, `CGameSocket__ReceiveMsg` calls `CClientSecurity__GenerateClientDhResponse` (0x753669) and sends that raw buffer using `CGameSocket__SendMsg` (0x6E1A07) while the handshake flag is still set. In this mode, `SendMsg` treats the passed `Size` as authoritative (it does not rely on `PacketHeader.size`).

**Verified `CClientSecurity__ProcessServerDhChallenge` return semantics**:
- `< 0`: handshake failure → disconnect
- `0`: need more bytes (incomplete)
- `> 0`: number of bytes consumed from the receive ring buffer

### Post-handshake Packet Phase (`CGameSocket+0x12424` == 0)
**Receive path**:
- `CGameSocket__RecvFromSocket` decrypts received bytes in-place via `CClientSecurity__DecryptCast5Cfb64` (0x753CA1).
- `CGameSocket__ReceiveMsg` verifies the last 8 bytes of each decrypted packet equal `TQServer` (`CClientSecurity__GetExpectedFlag`, 0x753DD1), then strips those 8 bytes before returning plaintext packet bytes to `CNetMsg` parse/process.

**Send path**:
- `CGameSocket__SendMsg` encrypts packet bytes via `CClientSecurity__EncryptCast5Cfb64` (0x753C5B).
- It then encrypts and appends an 8-byte signature trailer derived from `TQClient` (`CClientSecurity__GetPacketSignature`, 0x753DCB). Trailer length is `ProtocolSignature__Len()` (0x43C42C), which returns `8`.

### Handshake Crypto Details (Verified)
- Fixed pre-key string used for handshake decrypt/encrypt: `BC234xs45nme7HU9`
- Cipher primitive: CAST5 / CAST-128 (`OpenSSL_CAST_encrypt`, 0x77F310) in CFB64 (`OpenSSL_CAST_cfb64_encrypt`, 0x778590); key setup `OpenSSL_CAST_set_key` at 0x778790. Names are analyst identifications backed by native control flow and all eight matching CAST S-boxes.
- Chunk-list format used inside handshake: length-prefixed entry array (`u32 total_len`, then repeated `u32 len + bytes`) accessed via `HandshakeChunkList__GetEntryByIndex` (0x753D64) / `HandshakeChunkList__AppendEntry` (0x753CE6). The constants `1013/1017` are max-size bounds, not chunk tags.
- OpenSSL DH/BN helpers used by the handshake:
- `BN_hex2bn` (0x779F90)
- `BN_bn2hex` (0x779CF0)
- `BN_new` (0x77A7F0)
- `BN_free_local` (0x77A790)
- `BN_num_bits` (0x77A6B0)
- `DH_generate_key` (0x77A290)
- `DH_compute_key` (0x77A2A0)
- `DH_size` (0x778020)

---


## Packet Dispatch (CNetMsg__ProcessMsg @ 0x6DED63)
`CNetMsg__ProcessMsg` calls `CNetMsg__ProcessMsg_Dispatch` at `0x6DF3B5` to allocate + parse the appropriate message object for an incoming packet (call site: 0x6DEC2C).
Inside `CNetMsg__ProcessMsg_Dispatch`, one switch/jump table handles message type IDs 1002–1151 (150 cases) at `0x6DF41A`, and additional chained dispatch logic handles larger type IDs (e.g., `type=10010` routes to `CMsgAction__Ctor` at 0x6E1326).
Many types share the default target at `0x6E137B` (no create/process).
Each packet type has:
1. A `Create`/constructor function that initializes the message object (after an `operator new` allocation)
2. A `Process` function that handles the received packet on the client

## Known Packet Type Registry
Note: This table is the 1002–1151 switch/jumptable view. `CNetMsg__ProcessMsg_Dispatch` also dispatches additional type IDs outside this range (e.g., `type=10010` for `MsgAction`).
| Type | Name | Create Addr | Process Addr |
|------|------|-------------|--------------|
| 1002 | CMsgConnect | 0x753f88 | 0x5ad9b1 |
| 1003 | Default (no handler) | - | - |
| 1004 | CMsgTalk | 0x731122 | 0x731371 |
| 1005 | Default (no handler) | - | - |
| 1006 | CMsgUserInfo | 0x764197 | 0x764276 |
| 1007 | Default (no handler) | - | - |
| 1008 | CMsgItem | 0x762a3a | 0x762ac3 |
| 1009 | CMsgTick | 0x6eabeb | 0x6eaeb6 |
| 1010 | Default (no handler) | - | - |
| 1011 | Default (no handler) | - | - |
| 1012 | CMsgPlayer | 0x764997 | 0x764a42 |
| 1013 | Default (no handler) | - | - |
| 1014 | Default (no handler) | - | - |
| 1015 | CMsgName | 0x73ecc9 | 0x73efdf |
| 1016 | CMsgWeatherUpdate | 0x760667 | 0x760801 |
| 1017 | Default (no handler) | - | - |
| 1018 | Default (no handler) | - | - |
| 1019 | CMsgFriend | 0x74d66d | 0x74d789 |
| 1020 | Default (no handler) | - | - |
| 1021 | Default (no handler) | - | - |
| 1022 | CMsgInteract | 0x6fadee | 0x6fb1cb |
| 1023 | CMsgAllot | 0x72ac9a | 0x72ad85 |
| 1024 | CMsgWeapSkill | 0x740951 | 0x740a37 |
| 1025 | CMsgWeaponSkill | 0x761fd0 | 0x762059 |
| 1026 | CMsgTeamMember | 0x761a02 | 0x761ab1 |
| 1027 | CMsgGemEmbed | 0x7533ae | 0x5ad9b1 |
| 1028 | CMsgWeather | 0x7534a1 | 0x5ad9b1 |
| 1029 | CMsgUserAttrib | 0x75e446 | 0x75e4cf |
| 1030 | Default (no handler) | - | - |
| 1031 | Default (no handler) | - | - |
| 1032 | CMsgNpcInfo | 0x75e304 | 0x75e38d |
| 1033 | CMsgNpcInfoEX | 0x74a4e6 | 0x74a5e6 |
| 1034 | CMsgTaskDialog | 0x75df38 | 0x75dfc1 |
| 1035 | CMsgMagicEffect | 0x75db5b | 0x75dbe4 |
| 1036 | CMsgMagicInfo | 0x716545 | 0x7165f5 |
| 1037 | CMsgFloorItem | 0x743f64 | 0x6df2f6 |
| 1038 | CMsgMapItem | 0x717afa | 0x5ad9b1 |
| 1039 | CMsgPackage | 0x72b91e | 0x72ba6c |
| 1040 | CMsgTradeDialog | 0x72ccef | 0x72cda9 |
| 1041 | CMsgSynAttr | 0x6fe406 | 0x6fe4c0 |
| 1042 | CMsgGuide | 0x761cd3 | 0x761d5c |
| 1043 | CMsgBrocastMsg | 0x720357 | 0x720427 |
| 1044 | Default (no handler) | - | - |
| 1045 | Default (no handler) | - | - |
| 1046 | Default (no handler) | - | - |
| 1047 | Default (no handler) | - | - |
| 1048 | Default (no handler) | - | - |
| 1049 | Default (no handler) | - | - |
| 1050 | Default (no handler) | - | - |
| 1051 | Default (no handler) | - | - |
| 1052 | CMsgMapInfo | 0x754364 | 0x75464c |
| 1053 | Default (no handler) | - | - |
| 1054 | Default (no handler) | - | - |
| 1055 | CMsgAccountAuthResponse (old alias: CMsgSuitStatus) | 0x7548a3 | 0x75492c |
| 1056 | CMsgDutyMinContri | 0x7622f4 | 0x7623b9 |
| 1057 | CMsgAccountAuthResponse1057 (old alias: CMsgAchievement) | 0x754f4d | 0x754fd6 |
| 1058 | CMsgSynMemberInfo | 0x701c52 | 0x701d0c |
| 1059 | CMsgLottery | 0x764b3d | 0x764bc6 |
| 1060 | Default (no handler) | - | - |
| 1061 | CMsgSchool | 0x76221f | 0x7622a8 |
| 1062 | CMsgQualifying | 0x75d5fd | 0x75d686 |
| 1063 | CMsgAccount | 0x6f448c | 0x6f469f |
| 1064 | Default (no handler) | - | - |
| 1065 | CMsgRank | 0x6f942f | 0x6f94e1 |
| 1066 | CMsgSynListInfo | 0x716722 | 0x7167e5 |
| 1067 | Default (no handler) | - | - |
| 1068 | Default (no handler) | - | - |
| 1069 | Default (no handler) | - | - |
| 1070 | Default (no handler) | - | - |
| 1071 | CMsgTitle | 0x76208e | 0x762117 |
| 1072 | Default (no handler) | - | - |
| 1073 | Default (no handler) | - | - |
| 1074 | CMsgInviteTrans | 0x75d874 | 0x75d8fd |
| 1075 | CMsgRaceTrackProp | 0x715061 | 0x715125 |
| 1076 | Default (no handler) | - | - |
| 1077 | Default (no handler) | - | - |
| 1078 | Default (no handler) | - | - |
| 1079 | Default (no handler) | - | - |
| 1080 | Default (no handler) | - | - |
| 1081 | CMsgPKStatistic | 0x75d90e | 0x75d9ed |
| 1082 | Default (no handler) | - | - |
| 1083 | CMsgWarFlag | 0x714b0b | 0x714c89 |
| 1084 | Default (no handler) | - | - |
| 1085 | Default (no handler) | - | - |
| 1086 | Default (no handler) | - | - |
| 1087 | Default (no handler) | - | - |
| 1088 | Default (no handler) | - | - |
| 1089 | Default (no handler) | - | - |
| 1090 | Default (no handler) | - | - |
| 1091 | Default (no handler) | - | - |
| 1092 | Default (no handler) | - | - |
| 1093 | Default (no handler) | - | - |
| 1094 | Default (no handler) | - | - |
| 1095 | Default (no handler) | - | - |
| 1096 | Default (no handler) | - | - |
| 1097 | Default (no handler) | - | - |
| 1098 | Default (no handler) | - | - |
| 1099 | Default (no handler) | - | - |
| 1100 | Default (no handler) | - | - |
| 1101 | CMsgPeerage | 0x73fda7 | 0x740007 |
| 1102 | CMsgDetainedItem | 0x74e08a | 0x74e158 |
| 1103 | CMsgMagicEffectSimple | 0x760abc | 0x760b45 |
| 1104 | CMsgFlushExp | 0x76179a | 0x761823 |
| 1105 | CMsgMagicEffectEx | 0x760b79 | 0x760c02 |
| 1106 | CMsgPlayerSetInfo | 0x760886 | 0x76090f |
| 1107 | CMsgSyn | 0x702520 | 0x7031b9 |
| 1108 | CMsgStrCheckKey | 0x75f94e | 0x75f9d7 |
| 1109 | CMsgCrossSwitch | 0x75eeb0 | 0x75ef8f |
| 1110 | CMsgMapInfo1110 | 0x732a87 | 0x732b10 |
| 1111 | CMsgBattleEffectiveness | 0x75ed21 | 0x75ee72 |
| 1112 | CMsgMonsterTransform | 0x75ebfc | 0x75ec85 |
| 1113 | CMsgSubPro | 0x75e53b | 0x75e627 |
| 1114 | CMsgHero | 0x7624e8 | 0x762571 |
| 1115 | CMsgPKEliteInfo | 0x75d785 | 0x75d80e |
| 1116 | Default (no handler) | - | - |
| 1117 | Default (no handler) | - | - |
| 1118 | Default (no handler) | - | - |
| 1119 | Default (no handler) | - | - |
| 1120 | Default (no handler) | - | - |
| 1121 | Default (no handler) | - | - |
| 1122 | Default (no handler) | - | - |
| 1123 | Default (no handler) | - | - |
| 1124 | Default (no handler) | - | - |
| 1125 | Default (no handler) | - | - |
| 1126 | CMsgTexasNpcInfo | 0x72c76e | 0x72c843 |
| 1127 | CMsgCoach | 0x6ed9f1 | 0x6edac8 |
| 1128 | CMsgVipTeamConfirm | 0x72a561 | 0x72a623 |
| 1129 | CMsgTrusteeshipState | 0x75da61 | 0x75daea |
| 1130 | CMsgTitleMsg | 0x6ec7de | 0x6ec8c8 |
| 1131 | Default (no handler) | - | - |
| 1132 | Default (no handler) | - | - |
| 1133 | Default (no handler) | - | - |
| 1134 | CMsgMissionSystemUpdate | 0x72d0da | 0x72d163 |
| 1135 | CMsgMissionSystemDetail | 0x716b20 | 0x716bcf |
| 1136 | Default (no handler) | - | - |
| 1137 | Default (no handler) | - | - |
| 1138 | Default (no handler) | - | - |
| 1139 | Default (no handler) | - | - |
| 1140 | Default (no handler) | - | - |
| 1141 | Default (no handler) | - | - |
| 1142 | Default (no handler) | - | - |
| 1143 | Default (no handler) | - | - |
| 1144 | Default (no handler) | - | - |
| 1145 | Default (no handler) | - | - |
| 1146 | Default (no handler) | - | - |
| 1147 | Default (no handler) | - | - |
| 1148 | Default (no handler) | - | - |
| 1149 | Default (no handler) | - | - |
| 1150 | CMsgFlower | 0x76400b | 0x764102 |
| 1151 | CMsgFlowerRank | 0x706d07 | 0x706dea |

Note: Types with `Default (no handler)` hit the dispatch default target at `0x6E137B` and do not allocate or process a message object in this client build.

---

## Extended Packet Types (2048+)

The dispatch function `CNetMsg__ProcessMsg_Dispatch` handles additional packet types outside the 1002–1151 jump table via chained if/else logic. These "extended" types cover subsystems such as item status sync, guild notifications, pet/mount management, poker (ShowHand), arena/battle, and TeamPK.

### Extended Type Registry

| Type | Hex | Name | Create Addr | Process Addr |
|------|-----|------|-------------|--------------|
| 2048 | 0x0800 | CMsgItemStatus | 0x6E702E | 0x6E70E7 |
| 2050 | 0x0802 | CMsgSynNotify | 0x7189B6 | 0x718B8A |
| 2051 | 0x0803 | CMsgPetInfo | 0x75C9A0 | 0x75CA29 |
| 2064 | 0x0810 | CMsgMentor | 0x74A132 | 0x74A2B3 |
| 2065 | 0x0811 | CMsgMentorNotify | 0x74C355 | 0x74C484 |
| 2066 | 0x0812 | CMsgMentorSync | 0x7155CF | 0x7156DE |
| 2067 | 0x0813 | CMsgMentorRelation | 0x716106 | 0x716249 |
| 2068 | 0x0814 | CMsgQuiz | 0x71EB16 | 0x71EC45 |
| 2069 | 0x0815 | CMsgQuizSignal | 0x75C8FF | 0x75C988 |
| 2070 | 0x0816 | CMsgTitleVisual | 0x707C29 | 0x707CE4 |
| 2071 | 0x0817 | CMsgEudemonAttrib | 0x75C7EC | 0x75C875 |
| 2072 | 0x0818 | CMsgRaceTrackPropSync | 0x74F3E1 | 0x74F55B |
| 2073 | 0x0819 | CMsgRaceTrackEffect | 0x75CB87 | 0x75CC10 |
| 2077 | 0x081D | CMsgNonSuch | 0x75B05B | 0x75B0E4 |
| 2078 | 0x081E | CMsgAccountLoginAlert2078 | 0x75AFA0 | 0x75B029 |
| 2079 | 0x081F | CMsgServerState | 0x75AEED | 0x75AF76 |
| 2080 | 0x0820 | CMsgChangeName | 0x74B5AE | 0x74B6A1 |
| 2090 | 0x082A | CMsgShowHandEnter | 0x7513B2 | 0x7514B5 |
| 2091 | 0x082B | CMsgShowHandDealtCard | 0x75BD80 | 0x75BF92 |
| 2092 | 0x082C | CMsgShowHandActivePlayer | 0x75C272 | 0x75C2FB |
| 2093 | 0x082D | CMsgShowHandCallAction | 0x75106F | 0x751180 |
| 2094 | 0x082E | CMsgShowHandLayCard | 0x75BAAE | 0x75BC60 |
| 2095 | 0x082F | CMsgShowHandGameResult | 0x75B80F | 0x75B898 |
| 2096 | 0x0830 | CMsgShowHandExit | 0x75125E | 0x751326 |
| 2097 | 0x0831 | CMsgShowHandOnlineStatus | 0x75C471 | 0x75C4FA |
| 2098 | 0x0832 | CMsgShowHandLostInfo | 0x75B575 | 0x75B5FE |
| 2210 | 0x08A2 | CMsgArenaChallenge | 0x71C382 | 0x71C40B |
| 2211 | 0x08A3 | CMsgBattleObserver | 0x6E6CB6 | 0x6E6E4B |
| 2212 | 0x08A4 | CMsgFamilyArena | 0x704C32 | 0x704D2A |
| 2213 | 0x08A5 | CMsgFamilyArenaRoster | 0x7054BE | 0x705594 |
| 2214 | 0x08A6 | CMsgFamilyArenaBracket | 0x70574F | 0x7057F9 |
| 2215 | 0x08A7 | CMsgFamilyArenaRanking | 0x70535C | 0x70540B |
| 2216 | 0x08A8 | CMsgFamilyArenaMatchInfo | 0x705171 | 0x705220 |
| 2217 | 0x08A9 | CMsgFamilyArenaChallenge | 0x704FC3 | 0x70504C |
| 2218 | 0x08AA | CMsgElitePKArena | 0x75A35C | 0x75A3C2 |
| 2219 | 0x08AB | CMsgElitePKGame | 0x6DE376 | 0x6DE4F0 |
| 2220 | 0x08AC | CMsgDetainedItemList | 0x74EA42 | 0x74EB02 |
| 2221 | 0x08AD | CMsgServerPKToggle | 0x75A4EF | 0x75A578 |
| 2222 | 0x08AE | CMsgElitePKChallenge | 0x75A236 | 0x75A2BF |
| 2223 | 0x08AF | CMsgElitePKPlayerList | 0x72E552 | 0x72E616 |
| 2224 | 0x08B0 | CMsgWarFlag | 0x74BA9B | 0x74BB60 |
| 2225 | 0x08B1 | CMsgGuildWarScore | 0x74D26B | 0x74D3E6 |
| 2226 | 0x08B2 | CMsgGuildWarRoster | 0x74CF8B | 0x74D04A |

### Else-Branch Dispatch Types

These types are dispatched via subtraction/comparison chains in the else-branch of `CNetMsg__ProcessMsg_Dispatch`, not via the main jump table.

| Type | Hex | Name | Create Addr | Process Addr |
|------|-----|------|-------------|--------------|
| 1313 | 0x0521 | CMsgFamilyOccupy | 0x7069F1 | 0x706AC6 |
| 1314 | 0x0522 | CMsgLotteryAward | 0x74DE0F | 0x74DEBF |
| 1350 | 0x0546 | CMsgTextMessage | 0x75D217 | 0x75D2A0 |
| 2030 | 0x07EE | CMsgNpcInfo | 0x7439E3 | 0x743B32 |
| 2031 | 0x07EF | CMsgNpcAction | 0x72CB79 | 0x72CC60 |
| 2032 | 0x07F0 | CMsgTaskDialogEx | 0x72BBFF | 0x72BD72 |
| 2033 | 0x07F1 | CMsgBuddyInfoEx | 0x75D2D9 | 0x75D362 |
| 2034 | 0x07F2 | CMsgNoOp2034 | 0x75D18E | 0x5AD9B1 |
| 2035 | 0x07F3 | CMsgPetSpawn | 0x75CE78 | 0x75CF01 |
| 2036 | 0x07F4 | CMsgNoOp2036 | 0x716D37 | 0x5AD9B1 |
| 2043 | 0x07FB | CMsgHeroStatUpdate | 0x75D0A8 | 0x75D131 |
| 2044 | 0x07FC | CMsgHeroPage | 0x744046 | 0x744107 |
| 2045 | 0x07FD | CMsgFamilyBattleEffect | 0x70A355 | 0x70A3BB |
| 2046 | 0x07FE | CMsgBuddyConfirm | 0x72B454 | 0x72B517 |
| 2047 | 0x07FF | CMsgBuddyUpdate | 0x75CCA3 | 0x75CD2C |
| 2075 | 0x081B | CMsgMagicEffect (else) | 0x75C570 | 0x75C5F9 |
| 2101 | 0x0835 | CMsgContainerInfo | 0x7022AF | 0x702372 |
| 2102 | 0x0836 | CMsgSynMemberTitle | 0x75A834 | 0x75A8F9 |
| 2103 | 0x0837 | CMsgChiefNameChange | 0x6ECB23 | 0x6ECC0F |
| 2110 | 0x083E | CMsgSynWarScore | 0x7518E3 | 0x751A49 |
| 2170 | 0x087A | CMsgLeaveword | 0x72C4CD | 0x72C615 |
| 2171 | 0x087B | CMsgTexasNpc | 0x744DA5 | 0x744E8B |
| 2172 | 0x087C | CMsgTexasHoldEm | 0x75AA46 | 0x75AACF |
| 2201 | 0x0899 | CMsgFamilyWarData | 0x75A695 | 0x75A71E |
| 2202 | 0x089A | CMsgShowHandTable | 0x752EA9 | 0x752F93 |
| 2203 | 0x089B | CMsgTotemAdd | 0x709F7F | 0x70A063 |
| 2205 | 0x089D | CMsgQualifyingOut | 0x71B76E | 0x71B866 |
| 2206 | 0x089E | CMsgQualifyingMatch | 0x71BEF7 | 0x71BFCD |
| 2207 | 0x089F | CMsgQualifyingRank | 0x71C1B3 | 0x71C26A |
| 2208 | 0x08A0 | CMsgQualifyingStat | 0x71BB50 | 0x71BBFF |
| 2209 | 0x08A1 | CMsgQualifyingSelf | 0x71BD04 | 0x71BDB3 |
| 2260 | 0x08D4 | CMsgDominateTeam | 0x72997B | 0x729A2A |
| 2320 | 0x0910 | CMsgAchievementStar | 0x728E0A | 0x728E70 |
| 2330 | 0x091A | CMsgFactionPKSetup | 0x74D417 | 0x74D4D2 |
| 2331 | 0x091B | CMsgFactionPKList | 0x7599B4 | 0x759A3D |
| 2332 | 0x091C | CMsgFactionPKMatch | 0x759AA9 | 0x759B32 |
| 2333 | 0x091D | CMsgApprenticeList | 0x71C4F8 | 0x71C5BC |
| 2400 | 0x0960 | CMsgMapInfo (else) | 0x740837 | 0x7408F9 |
| 2401 | 0x0961 | CMsgEctypeInvite | 0x6F8F5F | 0x6F9094 |
| 2410 | 0x096A | CMsgArenaAction | 0x74A6FB | 0x74A7D2 |
| 2420 | 0x0974 | CMsgVerifyCheck | 0x7593D9 | 0x759462 |
| 2501 | 0x09C5 | CMsgCrossSwitch | 0x759776 | 0x7597FF |
| 2502 | 0x09C6 | CMsgCrossInfo | 0x7592FB | 0x759384 |
| 2504 | 0x09C8 | CMsgCrossFlagWarData | 0x74C15F | 0x74C21A |
| 2505 | 0x09C9 | CMsgCrossFlagWarStatus | 0x75904E | 0x7590D7 |
| 2506 | 0x09CA | CMsgWarflagEscort | 0x7531BD | 0x753278 |
| 2507 | 0x09CB | CMsgCrossFlagWarTeam | 0x74B7ED | 0x74B8A8 |
| 2510 | 0x09CE | CMsgFactionChiefBase | 0x701EE1 | 0x702071 |
| 2520 | 0x09D8 | CMsgSilentUpdate | 0x758DF1 | 0x758E57 |
| 10005 | 0x2715 | CMsgEntityAction | 0x7403A1 | 0x7405E7 |
| 10014 | 0x271E | CMsgPlayerSpawn | 0x755E83 | 0x755F64 |
| 10017 | 0x2721 | CMsgUserAttribEx | 0x7572EB | 0x757374 |

---
