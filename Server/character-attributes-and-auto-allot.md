# Character attributes, auto-allot and the profession family

## Profession codes decompose; they are not mapped

`CHero::GetEffectiveMaxLife` (`Conquer.exe` `0x65D0C9`–`0x65D0EF`) derives both halves of a
profession code arithmetically. Read from raw bytes, because the two `div` results share registers
and HLIL renders the pair ambiguously:

```
0065d0d1  bb e8 03 00 00   mov  ebx, 0x3e8      ; 1000
0065d0da  6a 0a            push 0xa             ; 10
0065d0df  8b c1            mov  eax, ecx        ; profession, CHero+0x82C
0065d0e1  f7 f3            div  ebx             ; edx = prof % 1000
0065d0e3  5b               pop  ebx             ; ebx = 10
0065d0e6  8b c2            mov  eax, edx
0065d0ea  f7 f3            div  ebx             ; eax = (prof % 1000) / 10   <- family
0065d0ed  3b c3            cmp  eax, ebx(=1)    ; family 1 is Trojan
```

So `family = (code % 1000) / 10` and `tier = code % 10`. Trojan is family 1, Warrior 2, Archer 4,
Ninja 5, Monk 6, Taoist 10, Water Taoist 13, Fire Taoist 14. The same divisor keys the auto-allot
table in `CAutoAllot::GetAllot`, which looks up `dwProfessional / 10`.

**There is no profession-to-family mapping table, and there must not be one.** Storing the
relationship lets the database express states native cannot, such as a Trojan pointing at the Taoist
curve.

## Attribute point budget

A character at level `L` owns `7 + 3L` attribute points: ten at level 1, three more per level. Those
points are either spent across the four attributes or held unspent in `cq_user.additional_point`.

The identity holds on all 1080 rows of the client's shipped `ini/AutoAllot.dat` — nine families
across levels 1 to 120 — which is what establishes it. It is the invariant that keeps allotment,
auto-allotment, level-up and reallotment mutually consistent, so a content row that breaks it cannot
be reconciled with the client.

**The budget is the only value rule the content keeps.** Attributes do not rise monotonically:
allotment redistributes. Native Trojan goes from `(182, 73, 109, 0)` at level 119 to
`(185, 72, 110, 0)` at level 120 — three strength and one vitality gained, one agility *given up*,
budget still exact. The corrected Archer curve does the same at level 99. Any validation that
requires attributes to increase will reject native content; this was tried and had to be removed.

## Maximum life

`CHero::GetEffectiveMaxLife` (`0x65D0AC`–`0x65D0DC`) computes the attribute-derived base:

```
0065d0ac  mov eax, [esi+0x50c]   ; spirit
0065d0b2  mov ecx, [esi+0x508]   ; vitality
0065d0b8  mov edx, [esi+0x4fc]   ; strength
0065d0c0  mov edi, [esi+0x504]   ; agility
0065d0c6  lea eax, [eax+ecx*8]   ; spirit + vitality * 8
0065d0cf  add eax, edi
0065d0d6  add eax, edx
0065d0dc  lea edi, [eax+eax*2]   ; * 3
```

`base = (STR + AGI + SPI + VIT * 8) * 3`.

This is **client-side**: `MsgUserInfo` carries only current life, never the maximum, so the client
derives the maximum itself and the server has to agree with it exactly. A Trojan-family-only
percentage bonus applies at tiers 1–5 (`{1:5, 2:8, 3:10, 4:12, 5:15}` percent, signed `idiv` by 100),
which is inert at tier 0 and therefore at creation. Equipment, refinement, the overlay bonus and the
per-type tier table also contribute; see
[../Rendering/14_hero_effective_max_life_mana.md](../Rendering/14_hero_effective_max_life_mana.md)
for the complete formula.

## Auto-allot is server-side in 5517

`ini/AutoAllot.dat` ships with the retail 5517 client, dated 17 March 2003, and **no shipped binary
references it**. The only allot strings in `Conquer.exe` are the thirteen `STR_ALLOT_*` resource
keys, and the dialog behind them (`AllotDialog_PromptAndCaptureAttributeEntries_5076B6` and its
behavioural twin `..._5089FD`) reads four typed-in text fields and stores them: it is manual point
entry, with no profession or level table lookup anywhere in the path. The client never auto-allots.

The file is still the authority on the content, because the server and client shipped the same ini
set. Its format is self-verifying — `8 + 4*9 + 9*120*16 = 17324` is exactly the file size:

```
u32 familyCount            ; 9
u32 levelCount             ; 120
u32 familyIds[familyCount] ; 1, 2, 3, 10, 11, 12, 13, 14, 15
{ u32 force, speed, health, soul } [familyCount][levelCount]
```

Fields are `dwForce, dwSpeed, dwHealth, dwSoul` (`CAutoAllot.h`) — strength, agility, vitality,
spirit — the same names `cq_user` and `cq_point_allot` use. Families 10 through 15 are byte-identical
to one another.

**Auto-allot stops at level 120.** Above it the server grants points and the player spends them by
hand, so an absent allotment above 120 is the normal case rather than missing content.

## Where the server reads it

`cq_point_allot`, keyed `(profession, level)` where `profession` is the family. Families 1, 2 and 10
in this database are byte-identical to `AutoAllot.dat` across all 360 overlapping rows, which is what
establishes the table's provenance.

Families 4, 5 and 6 postdate the 2003 file and have no native counterpart. As shipped, family 5 was
family 4's curve copied in — identical at level 1 — breaking the point budget on 118 of its 120 rows,
and family 6 broke it on 92, both from level 3 up. Auto-allot was maintained through Archer and
abandoned for the two classes added after it. Migration
`20260818_01_correct_profession_auto_allot` replaces those two families with rows from a later,
maintained copy of the same table whose families 1, 2, 4 and 10 are identical to the ones already
present, so the curves demonstrably were not re-tuned between versions. Every replacement row
satisfies the budget identity.

That migration also drops `character_profession_levelstats` and `character_profession_type`, which
duplicated `cq_point_allot` incorrectly: Trojan's level 120 off by one point, 28 wrong Archer rows, a
wholly different Ninja curve, Monk with agility and vitality transposed on every row, Taoist re-keyed
to a family 19 that does not exist, and 20 invented levels per family above the 120 the table covers.

## Creatable professions

`CRoleCreateFlashDlg_SubmitCreatePlayerRequest` (`0x51C5C3`) maps the vocation index to the
profession code it sends in `MsgCreatePlayer` (1001):

| vocation index | profession |
|---|---|
| 0, 1 | 100 Taoist |
| 2, 3 | 10 Trojan |
| 4, 5 | 40 Archer |
| 6, 7 | 20 Warrior |
| 8, 9 | 50 Ninja |
| 10, 11 | 60 Monk |

A new character is simply a fully auto-allotted level 1 character, so creation reads level 1 of the
same table rather than separate starting-attribute data.

## Level and experience

`ini/LevExp.dat` is referenced by the client and read by `CHero_LoadLevelExpTable` (`0x65FFE4`)
through `DecodedTextDatReader`. The decode is `plain[i] = rotr8(key[i % 128] ^ cipher[i], i % 8)`,
where the 128-byte key is `rand() % 256` after `srand(1234)` using the MSVC LCG.

Decoded, it is whitespace-separated text parsed with `"%d %d %I64d %I64d %u"`. The first column is a
track: track 0 is the main character level and runs 1 to 140; tracks 1–6 and 9 hold eight entries
each. `CHero_GetNextLevelExp` (`0x6601A7`) indexes track 0 directly by `level - 1` with a stride of
24 bytes and reads the first `int64` as the experience required. The `CHECK` string bounds the index
by `_MAX_LEVEL`, which is `0x96` (150).

**So 140 is the native level cap** — the 20 levels above the auto-allot range are real levels that
simply are not auto-allotted.

Not yet established, and not to be guessed at: the meaning of the third and fourth columns of track 0
(the fourth saturates at 600 from about level 118), and what tracks 1–6 and 9 key on.
`cq_levexp` exists in the database and nothing reads it yet.
