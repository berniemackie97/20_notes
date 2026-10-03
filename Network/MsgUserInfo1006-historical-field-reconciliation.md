# MsgUserInfo historical field reconciliation

`Conquer.exe` clean PC 5517; focused native checks, 2026-09-21.

## Result and evidence boundary

The proposed COPS5066 alignment matches the native PC5517 loads, widths and destinations.
No contradictory native evidence was found in the targeted checks below. This replaces the
blanket description of the six fields as unnamed unknowns with **named historical compatibility
fields and an explicitly corroborated Virtue mapping**. Broad receiver-model expansion was
stopped as requested.

Two kinds of evidence must remain distinguishable. The native binary proves the stores,
update routing, initialization and specific consumers below. COPS supplies the historical
field names and deprecated status. Matching the entire shifted block is strong lineage
evidence, but does not turn those names into recovered PC5517 symbols or prove that every
possible path in the client is incapable of reading the retained storage.

**PROVEN RETIRED/COMPATIBILITY FIELD** below uses the *compatibility* sense: native retention
is proven and the exact historical slot is documented as deprecated. It does **not** assert
exhaustive whole-program deadness. No behavioral consumer of those retained slots was established
in the reviewed paths. A stricter native-only verdict on the original gameplay name remains
unconfirmed, rather than contradicted or proven impossible to recover.

## Targeted reconciliation

Packet offsets in this table are decimal and include the four-byte header. Native member
offsets are hexadecimal. All raw values use little-endian wire order.

| PC5517 field | Historical identity / proposed production name | Native destination and decisive instructions | Verdict and encoding boundary |
|---|---|---|---|
| `+32`, 32 bits | Deed / `LegacyDeed` | Load `0x7643E9`, DWORD store `0x7643EC` to hero`+0x85C`; zero `0x6616DD` through inline state hero`+0x4F0` | **PROVEN RETIRED/COMPATIBILITY FIELD**, scoped above. COPS5066 deprecated signed32 `+30`; native copies bits unchanged and establishes no arithmetic signedness or retail default. |
| `+36`, u32 | Medal / `LegacyMedal` | Load `0x7643FD`, store `0x764400` to hero`+0x844`; zero `0x6616B3` | **PROVEN RETIRED/COMPATIBILITY FIELD**, scoped above. COPS5066 deprecated `+34`; raw DWORD, no proven required default. |
| `+40`, u32 | MedalSelect / `LegacyMedalSelect` | Load `0x764411`, store `0x764414` to hero`+0x848`; zero `0x6616AD`; player-spawn second writer `0x756525` | **PROVEN RETIRED/COMPATIBILITY FIELD**, scoped above. COPS5066 deprecated `+38`; raw DWORD. Additional network storage is not evidence of a gameplay read. |
| `+44`, u32 | Virtue / `VirtuePoints` | Load `0x764844`, store `0x764847` to hero`+0x8B8`; native packet10017 discriminator23 writes the same destination at `0x757BFF`; zero `0x661755` | **Native shared-field/update identity proven; Virtue name historically corroborated.** COPS5066 `+42`; no scale/clamp in these writes. Independent native-only gameplay-name closure is not established. |
| `+48`, u32 | MeteLev / `EncodedPreRebirthLevel` | Unsigned divide `0x764584`, setter call `0x764587` to `0x673202`, destination role`+0x83C`; tutor-grade consumer `0x73237F` | **PROVEN SEMANTIC** for retained pre-rebirth level used in tutor-grade selection; historical name MeteLev corroborates it. Client uses integer `raw / 100000`; remainder unused on this path. |
| `+72`, u8 | Nobility / `LegacyNobility` | MOVZX `0x7645C1`, DWORD store `0x7645C5` to hero`+0xF34`; constructor zero `0x655DEB` | **PROVEN RETIRED/COMPATIBILITY FIELD**, scoped above. COPS5066 deprecated `+68`; byte retained as `0..255`. Active peerage rank is separately proven at role`+0xA2C`. |
| `+74`, u8 | AutoAllot / `LegacyAutoAllot` | MOVZX `0x76454E`, DWORD store `0x764552` to hero`+0xCE4`; constructor zero `0x655DC3` | **PROVEN RETIRED/COMPATIBILITY FIELD**, scoped above. COPS5066 deprecated bool `+70`; native stores `0..255`, without boolean normalization. Neither required value1 nor a current auto-allocation effect is proven. |

For the four early DWORDs the shift is exactly two bytes; Strength likewise moves from5066
`+50` to5517 `+52`. In the profession region the two extra profession-history bytes account
for the further shift: historical profession `+67` maps to current profession `+69`, while
Nobility/rebirth/AutoAllot `+68/+69/+70` map to `+72/+73/+74`. The already established
first/previous-profession identities remain unchanged.

## Attribute23 is the update for the +44 field

`CMsgUserAttribEx__Parse` (`0x757351`) validates type `0x2721` (10017) at `0x75736D`.
`CMsgUserAttribEx__Process` (`0x757374`) loads the discriminator at `0x75746F` and
dispatches through table `0x758D19` at `0x75748E`:

| Discriminator | Table slot | Target | Native effect |
|---|---|---|---|
| 23 / `0x17` | `0x758D75` | `0x757BF9` | Gets the resolved role; loads the entry's low DWORD at `0x757BFC`, stores role`+0x8B8` at `0x757BFF`, then joins `0x758B86`. No per-case scaling or UI event. |
| 24 / `0x18` | `0x758D79` | `0x758B86` | Joins the common continuation directly; no field update. |
| 37 / `0x25` | Case body containing `0x758392` | Setter `0x673202` called at `0x758398` | Low DWORD divided by100000, same role`+0x83C` destination as1006 `+48`. |

Thus **USERATTRIB type23 is the update discriminator for the historically identified Virtue
slot**. The public enum's gap is unnecessary to establish this routing. The historical
MsgUserAttrib table does not itself enumerate type23; it must not be cited as doing so.
The high DWORD of the update value is not used by the type23 store. These observations prove
update semantics, not a server-side virtue earning formula or maximum.

## Specific checks against misleading alternatives

**MedalSelect versus life:** `CMsgPlayerSpawn__Process` (`0x755F64`) in the player
ID greater than999999 branch loads spawn packet`+0x50` as a DWORD at `0x756522` and
stores role`+0x848` at `0x756525`. The nonplayer branch uses a WORD from the same
wire position and calls the protected life setter at `0x756407`. These branches do
not establish that the player DWORD is life. Actual maximum-life getter `0x661F09`
reads role`+0x514`, while1006 current life has its own `+62` path. The additional
spawn writer neither contradicts MedalSelect nor independently proves that name.

**Legacy Nobility versus active peerage:** RTTI TypeDescriptor `0x921D68` names
`CPeerageMgr` at `0x921D70`; singleton helpers `0x407676` and `0x426D2F` use
global `0x956030`. `CRole_GetPeerageRank` (`0x675587`) reads role`+0xA2C`
at `0x67558D`. CHero vtable `0x86AD08` slot `+0x140` points to that getter.
UI function `0x42569E` calls the slot at `0x42644E`, passes the result into
manager lookup `0x6AB500` at `0x426458`, and uses `STR_PEERAGE_BATTLEEFFECT_TIP`
at `0x42656F`. This positively identifies active peerage storage distinct from
the retained `+72` destination. It does not establish every possible use of `+0xF34`.

**AutoAllot versus current manual allocation:** `CDlgRoleAttribute_RefreshAllotButtonsAndPendingStats`
(`0x5077E5`) reads unspent points hero`+0x840` at `0x50788B`, and current
attribute members, including Strength at `0x507A50`, to update allot controls.
It does not read hero`+0xCE4`. The function's separate `+0xF8` mode is a dialog
member, not a hero field. This targeted UI check does not prove universal deadness.
The legacy server's successful value1 is consistent with historical bool true,
but neither proves a native requirement nor a current gameplay effect.

**MeteLev:** tutor-grade consumer `0x68F7B9` passes current level, rebirth count
and stored role`+0x83C` to `0x73237F`. The latter selects the greater retained level
when rebirth is nonzero (`0x732396`/`0x732398`) and uses that key for the
`TutorType.ini` level-range lookup. Encoding `level * 100000` gives the required
quotient for this consumer. Historical descriptions of low-digit experience are
not proof of a retail5517 remainder encoding; this native path discards it.

## Packet1029 correction

The old notes incorrectly called `0x75E4CF` an HP/MP/level discriminator handler.
Parser `0x75E4AC` checks1029 at `0x75E4C8`; its processor adds packet`+4/+8/+12`
to hero`+0x109C/+0x10A0/+0x10A4` at `0x75E50F`/`0x75E4EE`/`0x75E531`.
There is no attribute discriminator here and it does not write `+0x8B8`.
COPS5066 calls1029 `MsgTeamAward` and names its three values Experience, Money,
Virtue. That family name is historical corroboration; the triple accumulation is
native-proven. The create/parse/process functions are now named `CMsgTeamAward__*`.
Do not conflate the award accumulator with the total updated by10017 discriminator23.

The other misleading Peerage label encountered during the focused check was packet1101:
parser `0x73FFB6` checks `0x44D` at `0x73FFD2`, and processor `0x740007` calls
CGameMap/map-item insertion at `0x740137` and uses `sound/DropItem.wav` at `0x74015F`.
Its parse/process functions are now `CMsgMapItem__Parse` and `CMsgMapItem__Process`.
Those ground-item paths provide no proof about Nobility or CPeerageMgr.

## Sources and durable evidence

Historical evidence is pinned to COPS commit
`714bbdad67f03372f58e71e1e429cee9b5d7fa7c`:
[README evidence conventions](https://github.com/conquer-online/cops-protocols-doc/blob/714bbdad67f03372f58e71e1e429cee9b5d7fa7c/README.md)
and [5066 packet tables](https://github.com/conquer-online/cops-protocols-doc/blob/714bbdad67f03372f58e71e1e429cee9b5d7fa7c/ZfProtocol5066.md#msguserinfo-1006).
Their bytes, hashes and source URLs are retained in
[historical-lineage](../../10_work/docs/evidence/msguserinfo-1006-5517/historical-lineage/provenance.json).

The [wiki MsgUserInfo5517 table](https://conquer-online.github.io/wiki/network/messages/msguserinfo.html)
explicitly uses an incomplete Mac1029 layout with the same release date. Its unknown
entries do not contradict this PC disassembly, and its labels do not override established
PC5517 semantics. The [wiki MsgUserAttrib enum](https://conquer-online.github.io/wiki/network/messages/msguserattrib.html)
leaves23/24 unnamed; native dispatch establishes their behavior above.

Native full-function HLIL, MLIL-SSA and disassembly captures are retained under
[followup](../../10_work/docs/evidence/msguserinfo-1006-5517/followup/), named by function address.
The compact [targeted evidence record](../../10_work/docs/evidence/msguserinfo-1006-5517/historical-reconciliation.json)
indexes the decisive stores and captures. Function renames/comments and instruction comments
are restorable from the manifests there. The clean executable SHA256 is
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Database saving remains with the user.

## Remaining limits and implementation boundary

- Native-only recovery of the words Deed, Medal, MedalSelect, Virtue, Nobility and AutoAllot
  has not been established. Their exact aligned historical identities are corroboration,
  not contradictory native evidence and not an assertion that the names are unrecoverable.
- Exhaustive whole-client deadness of the retained numeric storage is not established.
  The compatibility classification must not be silently strengthened to that claim.
- Retail-server defaults, virtue accrual policy, a required AutoAllot value and MeteLev's
  discarded low-digit policy are not recovered from these paths. Constructor zeros alone
  do not prove required packet values.
- Earlier closure for subprofession data and the discarded string[1] payload is unchanged.
  The latter still needs its structural slot; its historical name/retail contents remain unknown.

The [complete offset table](MsgUserInfo1006-semantic-closure-2026-09-17.md#complete-packet-offset-table)
uses the attributed historical names instead of anonymous numeric placeholders. The focused
hypothesis check is complete at the evidence level stated here; an all-native gameplay-name
closure claim would exceed it. No production implementation or legacy packet bytes changed.
