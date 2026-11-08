# Network Packet System — Full Protocol Documentation

Source: `F:\CQ2ClientRelease-42.0.1\3DRole\Network\`

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

Per-packet documents write this as **Parse**: `CMsgX__Parse` - standard header
validation, then `type == NNNN`. "Standard header validation" always means exactly
the four checks above. A packet whose parse wrapper does something else says so in
full.

## Encryption/Handshake (EncState == 2)
> **See also**: [13_connection_lifecycle.md](13_connection_lifecycle.md) for the complete connection lifecycle including TCP connect, DH key exchange, authentication, CGameSocket memory layout, and CClientSecurity internals.

This build implements its DH handshake and packet crypto at the `CGameSocket` layer (not via `CNetMsg` packet dispatch).

**2026-09-03 native consumer audit:** the post-1055 session-derived mask rekeys
outbound legacy tables, but mode 2 never consumes them. It is not a DH input,
packet checksum, framing change, or extra GameServer encryption layer.
See the [full binary-backed session-mask audit](14_session_derived_legacy_cipher_mask.md) for the exact
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
| 1006 | **CMsgUserInfo** ✓TU | 0x764197 | 0x764276 |
| 1007 | Default (no handler) | - | - |
| 1008 | `CMsg1008` (applied label, class declaration unverified) | 0x762a3a | 0x762ac3 |
| 1009 | `CMsgItem` (applied label), ✓TU `MsgItem.cpp` | 0x6eabeb | 0x6eaeb6 |
| 1010 | Default (no handler) | - | - |
| 1011 | Default (no handler) | - | - |
| 1012 | unproven (label `CMsgPlayer` withdrawn: TU = 10014) | 0x764997 | 0x764a42 |
| 1013 | Default (no handler) | - | - |
| 1014 | Default (no handler) | - | - |
| 1015 | **CMsgName** ✓TU | 0x73ecc9 | 0x73efdf |
| 1016 | CMsgWeatherUpdate | 0x760667 | 0x760801 |
| 1017 | Default (no handler) | - | - |
| 1018 | Default (no handler) | - | - |
| 1019 | CMsgFriend | 0x74d66d | 0x74d789 |
| 1020 | Default (no handler) | - | - |
| 1021 | Default (no handler) | - | - |
| 1022 | **CMsgInteract** ✓TU | 0x6fadee | 0x6fb1cb |
| 1023 | CMsgAllot | 0x72ac9a | 0x72ad85 |
| 1024 | CMsgWeapSkill | 0x740951 | 0x740a37 |
| 1025 | CMsgWeaponSkill | 0x761fd0 | 0x762059 |
| 1026 | **CMsgTeamMember** ✓TU | 0x761a02 | 0x761ab1 |
| 1027 | CMsgGemEmbed | 0x7533ae | 0x5ad9b1 |
| 1028 | CMsgWeather | 0x7534a1 | 0x5ad9b1 |
| 1029 | CMsgTeamAward (historical family name; native triple accumulator) | 0x75e446 | 0x75e4cf |
| 1030 | Default (no handler) | - | - |
| 1031 | Default (no handler) | - | - |
| 1032 | **CMsgBattleEffectiveness** ✓TU (label `CMsgNpcInfo` withdrawn) | 0x75e304 | 0x75e38d |
| 1033 | unproven (label `CMsgNpcInfoEX` withdrawn: TU = 1109) | 0x74a4e6 | 0x74a5e6 |
| 1034 | unproven (label `CMsgTaskDialog` withdrawn: TU = 2032) | 0x75df38 | 0x75dfc1 |
| 1035 | CMsgMagicEffect | 0x75db5b | 0x75dbe4 |
| 1036 | CMsgMagicInfo | 0x716545 | 0x7165f5 |
| 1037 | CMsgFloorItem | 0x743f64 | 0x6df2f6 |
| 1038 | CMsgMapItem | 0x717afa | 0x5ad9b1 |
| 1039 | unproven (label `CMsgPackage` withdrawn: TU = 1102) | 0x72b91e | 0x72ba6c |
| 1040 | CMsgTradeDialog | 0x72ccef | 0x72cda9 |
| 1041 | CMsgEnemyList (was CMsgSynAttr) | 0x6fe406 | 0x6fe4c0 |
| 1042 | **CMsgMonsterTransform** ✓TU (label `CMsgGuide` withdrawn) | 0x761cd3 | 0x761d5c |
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
| 1059 | unproven (label `CMsgLottery` withdrawn: TU = 1314) | 0x764b3d | 0x764bc6 |
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
| 1075 | unproven (label `CMsgRaceTrackProp` withdrawn: TU = 2072) | 0x715061 | 0x715125 |
| 1076 | Default (no handler) | - | - |
| 1077 | Default (no handler) | - | - |
| 1078 | Default (no handler) | - | - |
| 1079 | Default (no handler) | - | - |
| 1080 | Default (no handler) | - | - |
| 1081 | CMsgPKStatistic | 0x75d90e | 0x75d9ed |
| 1082 | Default (no handler) | - | - |
| 1083 | unproven (label `CMsgWarFlag` withdrawn: TU = 2224) | 0x714b0b | 0x714c89 |
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
| 1101 | CMsgMapItem (former Peerage label withdrawn) | 0x73fda7 | 0x740007 |
| 1102 | **CMsgPackage** ✓TU (label `CMsgDetainedItem` withdrawn) | 0x74e08a | 0x74e158 |
| 1103 | CMsgMagicEffectSimple | 0x760abc | 0x760b45 |
| 1104 | CMsgFlushExp | 0x76179a | 0x761823 |
| 1105 | CMsgMagicEffectEx | 0x760b79 | 0x760c02 |
| 1106 | CMsgPlayerSetInfo | 0x760886 | 0x76090f |
| 1107 | CMsgSyn | 0x702520 | 0x7031b9 |
| 1108 | unproven (label `CMsgStrCheckKey` withdrawn: TU = 2520) | 0x75f94e | 0x75f9d7 |
| 1109 | **CMsgNpcInfoEX** ✓TU (label `CMsgCrossSwitch` withdrawn) | 0x75eeb0 | 0x75ef8f |
| 1110 | CMsgMapInfo1110 | 0x732a87 | 0x732b10 |
| 1111 | unproven (label `CMsgBattleEffectiveness` withdrawn: TU = 1032) | 0x75ed21 | 0x75ee72 |
| 1112 | unproven (label `CMsgMonsterTransform` withdrawn: TU = 1042) | 0x75ebfc | 0x75ec85 |
| 1113 | CMsgSubPro | 0x75e53b | 0x75e627 |
| 1114 | CMsgHero | 0x7624e8 | 0x762571 |
| 1115 | CMsgKickoutNotice | 0x75d785 | 0x75d80e |
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
| 1126 | unproven (label `CMsgTexasNpcInfo` withdrawn: TU = 2172) | 0x72c76e | 0x72c843 |
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
| 2072 | 0x0818 | **CMsgRaceTrackProp** ✓TU (label `CMsgRaceTrackPropSync` withdrawn) | 0x74F3E1 | 0x74F55B |
| 2073 | 0x0819 | CMsgRaceTrackEffect | 0x75CB87 | 0x75CC10 |
| 2077 | 0x081D | CMsgNonSuch | 0x75B05B | 0x75B0E4 |
| 2078 | 0x081E | CMsgAccountLoginAlert2078 | 0x75AFA0 | 0x75B029 |
| 2079 | 0x081F | CMsgServerState | 0x75AEED | 0x75AF76 |
| 2080 | 0x0820 | CMsgChangeName | 0x74B5AE | 0x74B6A1 |
| 2090 | 0x082A | **CMsgShowHandEnter** ✓TU | 0x7513B2 | 0x7514B5 |
| 2091 | 0x082B | **CMsgShowHandDealtCard** ✓TU | 0x75BD80 | 0x75BF92 |
| 2092 | 0x082C | **CMsgShowHandActivePlayer** ✓TU | 0x75C272 | 0x75C2FB |
| 2093 | 0x082D | **CMsgShowHandCallAction** ✓TU | 0x75106F | 0x751180 |
| 2094 | 0x082E | **CMsgShowHandLayCard** ✓TU | 0x75BAAE | 0x75BC60 |
| 2095 | 0x082F | **CMsgShowHandGameResult** ✓TU | 0x75B80F | 0x75B898 |
| 2096 | 0x0830 | CMsgShowHandExit | 0x75125E | 0x751326 |
| 2097 | 0x0831 | **CMsgShowHandOnlineStatus** ✓TU | 0x75C471 | 0x75C4FA |
| 2098 | 0x0832 | **CMsgShowHandLostInfo** ✓TU | 0x75B575 | 0x75B5FE |
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
| 2224 | 0x08B0 | **CMsgWarFlag** ✓TU | 0x74BA9B | 0x74BB60 |
| 2225 | 0x08B1 | CMsgGuildWarScore | 0x74D26B | 0x74D3E6 |
| 2226 | 0x08B2 | CMsgGuildWarRoster | 0x74CF8B | 0x74D04A |

### Else-Branch Dispatch Types

These types are dispatched via subtraction/comparison chains in the else-branch of `CNetMsg__ProcessMsg_Dispatch`, not via the main jump table.

| Type | Hex | Name | Create Addr | Process Addr |
|------|-----|------|-------------|--------------|
| 1313 | 0x0521 | CMsgFamilyOccupy | 0x7069F1 | 0x706AC6 |
| 1314 | 0x0522 | **CMsgLottery** ✓TU (label `CMsgLotteryAward` withdrawn) | 0x74DE0F | 0x74DEBF |
| 1350 | 0x0546 | CMsgTextMessage | 0x75D217 | 0x75D2A0 |
| 2030 | 0x07EE | **CMsgNpcInfo** ✓TU | 0x7439E3 | 0x743B32 |
| 2031 | 0x07EF | CMsgNpcAction | 0x72CB79 | 0x72CC60 |
| 2032 | 0x07F0 | **CMsgTaskDialog** ✓TU (label `CMsgTaskDialogEx` withdrawn) | 0x72BBFF | 0x72BD72 |
| 2033 | 0x07F1 | CMsgBuddyInfoEx | 0x75D2D9 | 0x75D362 |
| 2034 | 0x07F2 | CMsgNoOp2034 | 0x75D18E | 0x5AD9B1 |
| 2035 | 0x07F3 | CMsgPetSpawn | 0x75CE78 | 0x75CF01 |
| 2036 | 0x07F4 | CMsgNoOp2036 | 0x716D37 | 0x5AD9B1 |
| 2043 | 0x07FB | CMsgHeroStatUpdate | 0x75D0A8 | 0x75D131 |
| 2044 | 0x07FC | CMsgHeroPage | 0x744046 | 0x744107 |
| 2045 | 0x07FD | CMsgFamilyBattleEffect | 0x70A355 | 0x70A3BB |
| 2046 | 0x07FE | CMsgBuddyConfirm | 0x72B454 | 0x72B517 |
| 2047 | 0x07FF | CMsgBuddyUpdate | 0x75CCA3 | 0x75CD2C |
| 2075 | 0x081B | CMsgStatusDetail2075 (was CMsgMagicEffect) | 0x75C570 | 0x75C5F9 |
| 2101 | 0x0835 | **CMsgFactionRankInfo** ✓TU (label `CMsgContainerInfo` withdrawn) | 0x7022AF | 0x702372 |
| 2102 | 0x0836 | CMsgSynMemberTitle | 0x75A834 | 0x75A8F9 |
| 2103 | 0x0837 | CMsgChiefNameChange | 0x6ECB23 | 0x6ECC0F |
| 2110 | 0x083E | CMsgSynWarScore | 0x7518E3 | 0x751A49 |
| 2170 | 0x087A | CMsgLeaveword | 0x72C4CD | 0x72C615 |
| 2171 | 0x087B | CMsgTexasNpc | 0x744DA5 | 0x744E8B |
| 2172 | 0x087C | **CMsgTexasNpcInfo** ✓TU (label `CMsgTexasHoldEm` withdrawn) | 0x75AA46 | 0x75AACF |
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
| 2420 | 0x0974 | **CMsgVerifyCheck** ✓TU | 0x7593D9 | 0x759462 |
| 2501 | 0x09C5 | **CMsgCrossSwitch** ✓TU | 0x759776 | 0x7597FF |
| 2502 | 0x09C6 | CMsgCrossInfo | 0x7592FB | 0x759384 |
| 2504 | 0x09C8 | CMsgCrossFlagWarData | 0x74C15F | 0x74C21A |
| 2505 | 0x09C9 | CMsgCrossFlagWarStatus | 0x75904E | 0x7590D7 |
| 2506 | 0x09CA | CMsgWarflagEscort | 0x7531BD | 0x753278 |
| 2507 | 0x09CB | CMsgCrossFlagWarTeam | 0x74B7ED | 0x74B8A8 |
| 2510 | 0x09CE | CMsgFactionChiefBase | 0x701EE1 | 0x702071 |
| 2520 | 0x09D8 | **CMsgStrCheckKey** ✓TU (label `CMsgSilentUpdate` withdrawn) | 0x758DF1 | 0x758E57 |
| 10005 | 0x2715 | CMsgEntityAction | 0x7403A1 | 0x7405E7 |
| 10014 | 0x271E | **CMsgPlayer** ✓TU (label `CMsgPlayerSpawn` withdrawn) | 0x755E83 | 0x755F64 |
| 10017 | 0x2721 | **CMsgUserAttrib** ✓TU (label `CMsgUserAttribEx` withdrawn) | 0x7572EB | 0x757374 |

## Registry derivation and translation-unit evidence (CP0.1, 2026-11-05)

Method (repeatable): decompile `CNetMsg__ProcessMsg_Dispatch` `0x6DF3B5` → 183 ctor calls → 182 type→ctor pairs (`evidence/dispatch-registry-2026-11-05/parse_dispatch.py`, `registry.py` over the clean `00_clean/clean/5517/Conquer.exe`).
Ctor → first `mov [reg], vtable` before `ret` → vtable; **slot 4 = Process** (checked 1008 `0x86D650`→`0x762AC3`).
All ctor + Process addresses in the tables above agree with the derivation (0 mismatches). Names did not.

Shared no-op Process `0x5AD9B1`: 1002, 1027, 1028, 1038, 2034, 2036. Shared Process `0x75A199`: 2231, 2251.
Types 1013/1014: no dispatch entry.

**Source-file authority.** ✓TU means the handler references a translation-unit path in an assertion.
The path establishes the source file. Exact C++ class declarations require independent evidence.
The displayed names are analysis labels. Historical eosource names and IDs are orientation only.

For 1009, vtable `0x86B8CC` slot 4 points to `0x6EAEB6`. The assertion at `0x6EB5EA` pushes
`0x945240`, whose on-disk string ends in `Network\MsgItem.cpp`. The original `proven.json` agrees.
The former `Msg1008` row was a transcription error. Packet 1008 has separate vtable `0x86D650`
and Process `0x762AC3`. Keep `CMsgItem` and `CMsg1008` as the respective 1009 and 1008 analysis labels.

| TU | Type | Process | Assert site |
|---|---|---|---|
| MsgAction | 10010 | `0x6FED1F` | `0x6FF2C4` |
| MsgBattleEffectiveness | 1032 | `0x75E38D` | `0x75E3DA` |
| MsgCrossSwitch | 2501 | `0x7597FF` | `0x759988` |
| MsgFactionRankInfo | 2101 | `0x702372` | `0x7024CB` |
| MsgInteract | 1022 | `0x6FB1CB` | `0x6FB79F` |
| MsgItem.cpp | 1009 | `0x6EAEB6` | `0x6EB5EA` |
| MsgLottery | 1314 | `0x74DEBF` | `0x74DEE9` |
| MsgMonsterTransform | 1042 | `0x761D5C` | `0x761DB5` |
| MsgName | 1015 | `0x73EFDF` | `0x73F092` |
| MsgNpcInfo | 2030 | `0x743B32` | `0x743C01` |
| MsgNpcInfoEX | 1109 | `0x75EF8F` | `0x75F0C0` |
| MsgPackage | 1102 | `0x74E158` | `0x74E1FC` |
| MsgPlayer | 10014 | `0x755F64` | `0x756155` |
| MsgRaceTrackProp | 2072 | `0x74F55B` | `0x74F5B5` |
| MsgShowHandActivePlayer | 2092 | `0x75C2FB` | `0x75C323` |
| MsgShowHandCallAction | 2093 | `0x751180` | `0x75123C` |
| MsgShowHandDealtCard | 2091 | `0x75BF92` | `0x75BFB4` |
| MsgShowHandEnter | 2090 | `0x7514B5` | `0x7514E1` |
| MsgShowHandGameResult | 2095 | `0x75B898` | `0x75B8C0` |
| MsgShowHandLayCard | 2094 | `0x75BC60` | `0x75BC7E` |
| MsgShowHandLostInfo | 2098 | `0x75B5FE` | `0x75B627` |
| MsgShowHandOnlineStatus | 2097 | `0x75C4FA` | `0x75C513` |
| MsgStrCheckKey | 2520 | `0x758E57` | `0x758ED1` |
| MsgTaskDialog | 2032 | `0x72BD72` | `0x72C00D` |
| MsgTeamArena | 2247 | `0x752A2C` | `0x752A4F` |
| MsgTeamMember | 1026 | `0x761AB1` | `0x761CB5` |
| MsgTexasNpcInfo | 2172 | `0x75AACF` | `0x75ABCB` |
| MsgUserAttrib | 10017 | `0x757374` | `0x758561` |
| MsgUserInfo | 1006 | `0x764276` | `0x764881` |
| MsgVerifyCheck | 2420 | `0x759462` | `0x7594D6` |
| MsgWarFlag | 2224 | `0x74BB60` | `0x74BF79` |

TUs not tied to a dispatched Process: `MsgAccount` (asserts in outbound builder `CMsg1121__Create` `0x749333`), `MsgConnect`
(`CMsgAccountAuthResponse_FormatLoginFailureTraceText` `0x754025`, 1057 transition `0x755726`), `MsgFriend`
(`CMsgFriend__BuildSubtypeEntityIdFlagName16` `0x74D6E1`), `MsgShowHandTrusteeship` (`0x751853`, helper), `Ping` (`0x767F37`),
`NetMsg` (`0x6DED5E`, `0x6DF096`, `0x6E138C`).

Withdrawn labels → now: 1008 `CMsgItem`→`CMsg1008`; 1009 `CMsgTick`→`CMsgItem`; 1012 `CMsgPlayer`→`CMsg1012`;
1033 `CMsgNpcInfoEX`→`CMsg1033`; 1042 `CMsgGuide`→`CMsgMonsterTransform`; 1102 `CMsgAccount1102`/`CMsgDetainedItem`→`CMsgPackage`;
1112 `CMsgMonsterTransform`→`CMsg1112`; 10014 `CMsgPlayerSpawn`→`CMsgPlayer`; 10017 `CMsgUserAttribEx`→`CMsgUserAttrib`.
Binja renames applied the same day by address (`.bndb` save pending, Bernie).

### Dispatched types absent from the tables above

| Type | Hex | Class | Ctor | Process |
|---|---|---|---|---|
| 1312 | 0x0520 | unproven | 0x703be1 | 0x7041f4 |
| 2230 | 0x08B6 | unproven | 0x759eca | 0x759f53 |
| 2231 | 0x08B7 | unproven | 0x75a110 | 0x75a199 |
| 2232 | 0x08B8 | unproven | 0x6e267e | 0x6e27f8 |
| 2233 | 0x08B9 | unproven | 0x72e342 | 0x72e406 |
| 2240 | 0x08C0 | unproven | 0x729704 | 0x7297b3 |
| 2241 | 0x08C1 | unproven | 0x751c46 | 0x751d24 |
| 2242 | 0x08C2 | unproven | 0x75272b | 0x7527e1 |
| 2243 | 0x08C3 | unproven | 0x752250 | 0x7522ff |
| 2244 | 0x08C4 | unproven | 0x75207e | 0x752120 |
| 2245 | 0x08C5 | unproven | 0x752487 | 0x752529 |
| 2246 | 0x08C6 | unproven | 0x752d26 | 0x752daf |
| 2247 | 0x08C7 | **CMsgTeamArena** ✓TU | 0x75297f | 0x752a2c |
| 2250 | 0x08CA | unproven | 0x759bfb | 0x759c84 |
| 2251 | 0x08CB | unproven | 0x759e41 | 0x75a199 |
| 2252 | 0x08CC | unproven | 0x6e2d6c | 0x6e2ee6 |
| 2253 | 0x08CD | unproven | 0x72e132 | 0x72e1f6 |
| 10010 | 0x271A | **CMsgAction** ✓TU | 0x6fe8a3 | 0x6fed1f |
