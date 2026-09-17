# `Conquer.exe` — binary overview

Client binary `CQ2ClientRelease-42.0.1`. Win32 PE, x86, MFC42 (`CWinApp` subclass).

## Census

| Property | Value |
|----------|-------|
| Binary | `CQ2ClientRelease-42.0.1.exe` |
| Platform | Win32 PE, x86 |
| Framework | MFC42 (CWinApp subclass) |
| Code range | `0x401000 - 0x83E428` (~4.2MB) |
| Total functions | 18,983 |
| Named functions | ~6,293 (33%) |
| Organized in IDA folders | ~2,763 |
| Level cap | 150 |

## Evidence policy

Stated once, in [README.md](README.md). In short: the v5517 binaries and clean
v5517 assets are authoritative, the legacy source trees are leads only, and
client/server agreement is not verification.

## Source tree (from debug strings)
```
F:\CQ2ClientRelease-42.0.1\3DRole\
├── Network/
│   ├── NetMsg.cpp          — Packet dispatch (1002–1151, 150 types)
│   ├── socket.h            — CGameSocket class
│   ├── MsgConnect.cpp      — Connection/handshake (type 1002)
│   ├── MsgAccount.cpp      — Account/login (type 1063)
│   ├── MsgAction.cpp       — Player actions (type 1010)
│   ├── MsgItem.cpp         — Item operations (type 1008)
│   ├── MsgInteract.cpp     — Combat (type 1019)
│   ├── MsgName.cpp         — Name/strings (type 1015)
│   ├── MsgPlayer.cpp       — Player spawn (type 1012)
│   ├── MsgUserInfo.cpp     — User info (type 1006)
│   ├── MsgUserAttrib.cpp   — Attrib updates (type 1029)
│   ├── MsgNpcInfo.cpp      — NPC info (type 1032)
│   ├── MsgNpcInfoEX.cpp    — Extended NPC info (type 1033)
│   ├── MsgTaskDialog.cpp   — Quest dialogs (type 1034)
│   ├── MsgFactionRankInfo.cpp — Gem embed request (type 1027)
│   ├── MsgFriend.cpp       — Friends (type 1016)
│   ├── MsgLottery.cpp      — Lottery (type 1059)
│   ├── MsgPackage.cpp      — Warehouse (type 1039)
│   ├── MsgWarFlag.cpp      — War flags (type 1083)
│   ├── MsgRaceTrackProp.cpp— Race track (type 1075)
│   ├── MsgMapInfo.cpp      — Map state (type 1110)
│   ├── MsgStrCheckKey.cpp  — String check (type 1108)
│   ├── MsgVerifyCheck.cpp  — Verification (type 1107)
│   ├── MsgCrossSwitch.cpp  — Cross-server (type 1109)
│   ├── MsgTexasNpcInfo.cpp — Poker NPC (type 1126)
│   ├── MsgShowHand*.cpp    — Poker system (types 1127-1151)
│   ├── MsgBattleEffectiveness.cpp — Battle power (type 1111)
│   ├── MsgTeamMember.cpp   — Weapon skill update (type 1025)
│   ├── MsgMonsterTransform.cpp — Transform (type 1112)
│   └── Ping.cpp            — Latency ping
├── Role.cpp       — CRole base entity class
├── Player.cpp     — CPlayer intermediate class
├── Hero.cpp       — CHero local player class
├── Item.cpp       — CItem class
├── ItemData.cpp   — CItemData class
├── Npc.cpp        — CNpc class
├── Monster.cpp    — CMonster class
└── ...
```

## Class hierarchy
```
CRole (base entity, ~1088 bytes)
  └── CPlayer (rendered entity with nameplate, ~2636 bytes)
        └── CHero (local player singleton, ~12300 bytes)

CItem (item instance)
CItemData (item database/CSV parser)
```

## IDA folder census (29 top-level folders)
```
/Crypto_OpenSSL      — OpenSSL crypto functions (33)
/Crypto_zlib         — zlib compression (2)
/Data                — Config/INI loaders (330)
/Data_Structures     — Generic data structures (6)
/Dialog              — Dialog system (76)
/Entity_Hero         — CHero local player (110)
/Entity_Item         — Item system (155)
/Entity_Monster      — Monster entities (1)
/Entity_NPC          — NPCs and pets (20)
/Entity_Player       — CPlayer class (23)
/Entity_Role         — CRole base entity (58)
/Game_Chat           — Chat system (21)
/Game_Effects        — Weather/visual effects (26)
/Game_Map            — Map rendering/logic (23)
/Game_Mount          — Mount system (2)
/Game_Peerage        — Nobility/peerage (9)
/Game_Replay         — Replay system (1)
/Game_Syndicate      — Guild/faction system (25)
/Game_Task           — Quest/task system (12)
/Game_TeamPK         — Team PK/Elite PK (57)
/Game_TexasHoldem    — Texas Hold'em poker (107)
/MFC_Stubs           — MFC framework stubs (6)
/Magic               — Magic/spell effects (24)
/Network             — Networking layer (441)
/Obfuscation         — Anti-debug/obfuscation (4)
/Security            — Client security (13)
/System              — System utilities (10)
/UI                  — UI framework (1167)
/Utility             — Misc utilities (1)
```

## Entity ID ranges
| Range | Type | Description |
|-------|------|-------------|
| 1 - 999,999 | Player | Real human players (ID > 0xF423F = 999999) |
| 400,001 - 500,000 (0x61A81-0x7A120) | NPC | Non-player characters |
| 500,001 - 600,000 (0x7A121-0x927BF) | Monster | Monster entities |

## External DLL dependencies
| DLL | Purpose |
|-----|---------|
| `graphic.dll` | Low-level 2D rendering |
| `GraphicData.dll` | Sprite/animation data loading |
| `Role3D.dll` | 3D role model rendering |
| `NDSound.dll` | DirectSound audio wrapper |
| `Assist.dll` | Helper utilities |
| `RoleView.dll` | Role visual representation |
| `GameData.dll` | Game data queries |
| `DINPUT8.dll` | DirectInput keyboard/mouse |

## Singletons
The client uses singletons extensively via `GetSingletonPtr_XXXX()` functions:
- `GetSingletonPtr_404460` — Game world/map singleton
- `GetSingletonPtr_410685` — Camera/viewport singleton
- `GetSingletonPtr_414BDA` — Server name registry
- `GetSingletonPtr_432FB0` — Guild/faction data
- `GetSingletonPtr_480676` — Family/clan manager
- `GetSingletonPtr_4902A3` — Player data lookup
- `GetSingletonPtr_676B72` — Stall price manager
- `RoleDataQuery()` — Role/NPC database queries
- `GameDataSetQuery()` — Game data resource queries
- `Load_FontSetting_Ini()` — Font configuration
