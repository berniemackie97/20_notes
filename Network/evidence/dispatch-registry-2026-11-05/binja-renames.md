# Binja renames — CP0.1 dispatch registry (2026-11-05, Conquer.exe.bndb)

Applied by address via MCP. Re-apply verbatim if the .bndb was not saved.

| Addr | Old | New |
|---|---|---|
| 0x762A3A | CMsgItem__Ctor | CMsg1008__Ctor |
| 0x762AC3 | CMsgItem__Process | CMsg1008__Process |
| 0x74A4E6 | sub_74a4e6 | CMsg1033__Ctor |
| 0x74A5E6 | CMsgNpcInfoEX__Process | CMsg1033__Process |
| 0x6EABEB | CMsgTick__Ctor | CMsgItem__Ctor |
| 0x6EAEB6 | CMsgTick__Process | CMsgItem__Process |
| 0x761CD3 | CMsgGuide__Create | CMsgMonsterTransform__Ctor |
| 0x761D5C | CMsgGuide__Process | CMsgMonsterTransform__Process |
| 0x74E08A | CMsgAccount1102__Ctor | CMsgPackage__Ctor |
| 0x74E158 | sub_74e158 | CMsgPackage__Process |
| 0x755E83 | CMsgPlayerSpawn__Ctor | CMsgPlayer__Ctor |
| 0x755F64 | CMsgPlayerSpawn__Process | CMsgPlayer__Process |
| 0x7572EB | CMsgUserAttribEx__Create | CMsgUserAttrib__Ctor |
| 0x757374 | CMsgUserAttribEx__Process | CMsgUserAttrib__Process |
| 0x73ECC9 | sub_73ecc9 | CMsgName__Ctor |
| 0x75E304 / 0x75E38D | sub_ | CMsgBattleEffectiveness__Ctor / __Process |
| 0x75EEB0 / 0x75EF8F | sub_ | CMsgNpcInfoEX__Ctor / __Process |
| 0x74DE0F / 0x74DEBF | sub_ | CMsgLottery__Ctor / __Process |
| 0x72BBFF / 0x72BD72 | sub_ | CMsgTaskDialog__Ctor / __Process |
| 0x74F3E1 / 0x74F55B | sub_ | CMsgRaceTrackProp__Ctor / __Process |
| 0x7022AF / 0x702372 | sub_ | CMsgFactionRankInfo__Ctor / __Process |
| 0x74BA9B / 0x74BB60 | sub_ | CMsgWarFlag__Ctor / __Process |
| 0x75297F / 0x752A2C | sub_ | CMsgTeamArena__Ctor / __Process |
| 0x7593D9 / 0x759462 | sub_ | CMsgVerifyCheck__Ctor / __Process |
| 0x759776 / 0x7597FF | sub_ | CMsgCrossSwitch__Ctor / __Process |
| 0x75AA46 / 0x75AACF | sub_ | CMsgTexasNpcInfo__Ctor / __Process |
| 0x7513B2 / 0x7514B5 | sub_ | CMsgShowHandEnter__Ctor / __Process |
| 0x75BD80 / 0x75BF92 | sub_ | CMsgShowHandDealtCard__Ctor / __Process |
| 0x75C272 / 0x75C2FB | sub_ | CMsgShowHandActivePlayer__Ctor / __Process |
| 0x75106F / 0x751180 | sub_ | CMsgShowHandCallAction__Ctor / __Process |
| 0x75BAAE / 0x75BC60 | sub_ | CMsgShowHandLayCard__Ctor / __Process |
| 0x75B80F / 0x75B898 | sub_ | CMsgShowHandGameResult__Ctor / __Process |
| 0x75C471 / 0x75C4FA | sub_ | CMsgShowHandOnlineStatus__Ctor / __Process |
| 0x75B575 / 0x75B5FE | sub_ | CMsgShowHandLostInfo__Ctor / __Process |

Function comments set: every new `__Process` above with no prior comment (proof line); ctors of 1008, 1009, 1042, 10014,
10017, 2032 (their Process functions already held behaviour comments, left untouched).
Notes-only labels withdrawn (no Binja symbol existed): 1012 `CMsgPlayer__*` → `CMsg1012__*`, 1112 `CMsgMonsterTransform__*` → `CMsg1112__*`.
