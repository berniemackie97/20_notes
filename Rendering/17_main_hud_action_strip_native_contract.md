# CDlgMain action strip: native behavior and state-writer evidence

Evidence collected 2026-09-28 and completed 2026-09-29 against clean 5517.
This is an evidence report, not a managed implementation specification or recommendation.
This task made no executable or BNDB changes. The BNDB file hash did change during the resumed
investigation; both observations are recorded without attributing that change. All captured
instruction bytes still match the unchanged clean EXE. Suggested names in the evidence bundle are explicitly
**analyst proposals, not applied names**. Existing BN labels and comments are navigation aids;
the captured instruction bytes, clean PE data and receiver dataflow are authoritative.

Clean `Conquer.exe` SHA-256:
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Clean `ani/Control.Ani` SHA-256:
`a1db47baaeb2f75eea3b5216378f97d713c2afeaefe05ec02e6f584794532d27`.

Evidence and reproducible checks:
[`10_work/docs/evidence/main-hud-action-strip-5517`](../../10_work/docs/evidence/main-hud-action-strip-5517/README.md).
The actual work checkout is `10_work`; a nested `10_work/OpenConquerPublic` directory is absent.

## Status and proof boundaries

**PROVEN:** the ten bindings and handlers; the direct per-instance state references; shared
button state writers; initial enabled styles; exact PK mode storage, request/apply distinction,
skin mapping, blink producer, phase/expiry arithmetic and order; Organise frame writers;
the handler and lifecycle effects detailed below.

**NOT PROVEN:** an ordinary application activation path that disables Skill or Mission and
thereby displays their frame 2. Their common `WM_ENABLE(FALSE)` path is proven. The census found
no dedicated disabling caller, hover enable, skin replacement or timer writer for those two
instances. This is not a claim that arbitrary HWND messages or every possible indirect alias
have been excluded. No frame is declared dead from an absence scan.

The scans enumerate the clean EXE's decoded static candidates and classify actual receivers.
They do not prove a universal whole-program absence of indirect writes, external messages,
or transitive networking through every possible dialog creation/notification callback. Packet
statements below distinguish a direct button call from the concrete downstream paths inspected.
Original-x86 replays use documented boundary mocks; they are not live Windows/game captures.

## Object identity and initialization

All offsets in the `main` column are relative to the primary `CDlgMain` object. It is embedded
at `CMyShellDlg+0xF98`. Each button is a `0xA0`-byte `CMyButton`. DDX registration is in
`0x004BB6B8`; initialization is in `0x004BB869`. The PE message-map rows contain
`WM_COMMAND=0x111`, notification `0` (`BN_CLICKED`), matching first/last control IDs and each
handler address below. Those rows, rather than ANI filenames, establish activation binding.

| Control / supplied label | ID | main | shell | handler | Init call | Show call |
|---|---|---|---|---|---|---|
| Button40 / Query | `0x5DF` | `0x13FA84` | `0x140A1C` | `0x4BCD47` | `0x4BBA4B` | `0x4BC971` |
| Button410 / Message | `0x3EE` | `0x13FB24` | `0x140ABC` | `0x4BCDCF` | `0x4BBB74` | `0x4BC988` |
| Button42 / Items | `0x3EF` | `0x13FBC4` | `0x140B5C` | `0x4BCEA0` | `0x4BBA8D` | `0x4BC99F` |
| Button43 / Setup | `0x3F0` | `0x13FC64` | `0x140BFC` | `0x4BCF5A` | `0x4BBAAE` | `0x4BCA3E` |
| Main3_MissionBtn | `0x3F1` | `0x13FD04` | `0x140C9C` | `0x4BCFA4` | `0x4BBACF` | `0x4BCA55` |
| Button45 / Chat | `0x3F2` | `0x13FDA4` | `0x140D3C` | `0x4BCFCD` | `0x4BBAF0` | `0x4BCA6C` |
| Button46 / Group | `0x3F3` | `0x13FE44` | `0x140DDC` | `0x4BD109` | `0x4BBB11` | `0x4BCA83` |
| Button47 / PK | `0x3F5` | `0x13F9E4` | `0x14097C` | `0x4BD399` | `0x4BBB32` | `0x4BCB21` |
| Main3_OrganiseBtn | `0x400` | `0x13C390` | `0x13D328` | `0x4BDA50` | `0x4BBB53` | `0x4BCB9C` |
| Button41 / Skill | `0x402` | `0x13FEE4` | `0x140E7C` | `0x4BCD8B` | `0x4BBA6C` | `0x4BCBB3` |

Resource `RT_DIALOG/130/2052` has style `0x5001800B` for every one of these controls:
none has `WS_DISABLED (0x08000000)`. The constructor `0x589DCF` clears frame `+0x68`,
tracking `+0x80`, force polling `+0x81`, inside `+0x82`, hover opt-in `+0x83`, repeat flag
`+0x84` and special-press selector `+0x6C`. The initializer `0x58A21E` explicitly clears
`+0x68` at `0x58A230`; all ten callers supply zero special-press selector, timer command and
repeat flag. Initial ANI names are the names in the table, including **Button47**, even though
the hero's separately initialized PK mode is 1. Do not synthesize a mode-based initial skin.

## Handler behavior

All ten play `Sound/BtnClick.wav` before their subsequent work, using the sound import at
`0x844974`, zero positional/range/loop arguments and volume 100. Mission calls another helper
that plays the same sound again. A rejected activation can therefore still play the sound.

`0x596F79` is the common show/hide and lifecycle routine. A request for state 5 or 0 is not an
unconditional guarantee of visibility: creation can fail, current visibility can short-circuit,
and the routine checks HWND and byte `+0x71`. Accepted show invokes virtual slots `+0xEC` and
`+0xF0`; accepted hide invokes `+0xDC` and may hide or destroy according to `+0x60`. The
receiver-specific callbacks are preserved in `dialog-vtables.json`.

### Query — 0x004BCD47

After sound, calls `0x4BEE18` at `0x4BCD60`. A true result stops activation. Otherwise it toggles
the dialog at `main+0x62798`: visibility query with argument 1 at `0x4BCD73`, show-state call
at `0x4BCD83`, 0 if visible and 5 otherwise. No packet builder, button-frame setter, or direct
main-field assignment occurs in this handler.

Its hide callback is `0x501396` (primary vtable `0x85C010`, slot `+0xDC`). This closes visible
child dialogs at Query-relative `+0xFC,+0x2078,+0x2FE4,+0x4528,+0x54B4,+0x6170` and clears
the associated checks, then posts commands `0x447` and `0xD2B`. Their shell consumers hide
visible dialogs at `shell+0x1492A0` (`0x5C4EDF`) and `shell+0x12B348` (`0x5C23A2`). Thus even
the Query hide operation has effects beyond the top-level visibility flag.

### Skill — 0x004BCD8B

Same guard at `0x4BCDA4`, then toggles `main+0x6A250`, show-state call `0x4BCDC7`.
Its show callback `0x492467` (vtable `0x851DD8`, slot `+0xEC`) posts command `0x3FA` at
`0x492475`. The shell receives it at `0x5C3362` and calls `0x4925A2` on the same dialog at
`0x5C336E`. When visible, the refresh clears the list HWND at dialog `+0x11EC` with message
`0x184` (`0x4925D8`), iterates manager entries, copies each non-null entry's string at `+8`,
and inserts/appends rows according to entry dword `+0x14` (`0x492699/0x4926BB`). It updates
row states on the list object at dialog `+0x11CC` (`0x4926A6/0x4926C8`). This is a
dialog-content refresh path, not a Skill button frame-2 writer. The supplied “Skill” label
does not by itself establish the semantic identity of the opened dialog.

The common Query/Skill guard short-circuits on the first visible/pending dialog among:
`main+0x44E10`; when global shell `0x958678` is non-null, `shell+0x171A58`;
then `main+0x6F3D4,+0x870E0,+0x8A680,+0xFE618,+0x78AE4,+0x7903C,+0x9DDC8,+0x9E3D0,
+0x9E934,+0x9F300,+0xBD010,+0xA567C,+0xA6EBC,+0xADECC,+0xB469C`.
The call range is `0x4BEE26..0x4BEF56`; each query receives argument 1. No semantic dialog
names are assigned here solely from offsets.

### Message — 0x004BCDCF

Toggles `main+0xAADEC` at `0x4BCE07`, without the Query/Skill guard. Its show callback
`0x4A56AB` (vtable `0x854768`, slot `+0xEC`) calls `0x70FF8F` at `0x4A56C9` with receiver
`hero+0x2A94`, first argument word `[dialog+0xFC]`, second word `[dialog+0xFA]`.
The callee clears its old collection, stores those values at its `+0x1C/+0x20`, builds a
**type `0x457` (1111), operation byte 2** packet through `0x75EE00`, sends at `0x710065` when
build succeeds, and posts `0x428`. The builder stores the first/second values as packet words
`+4/+6`, operation at `+8`. Message activation is therefore not merely a dialog toggle.

### Items — 0x004BCEA0

Tests `main+0x6BA34` at `0x4BCEC2`. When closed, removes the `PKpack` effect through
`0x4BCE08(main,0)` at `0x4BCECE`. That helper queries/removes the named effect on the object
pointed to by `main+0x1A4`; it does not change Button42's frame.

It then checks two hero collection counts: `0x6DCB8A` delegates to `0x71B0F3` on `hero+0xE60`
and computes `(end(+8)-begin(+4))/0x38`; `0x6DCBDD` delegates to `0x71B1EA` and uses `+0x14/+0x10`.
If the first is signed-positive and `main+0x6BB38` is signed-positive, posts `0x4CF`. Otherwise,
if the second and that same main field are signed-positive, posts `0x4D0`. Posting is at
`0x4BCF11`, payload zero. These queued paths can open `main+0x9AF0C` or `main+0x9CE18` and
request **MsgAction `0x99`** with final builder parameter 0 or 1 respectively: helpers
`0x4F19ED` (send `0x4F1A40`) and `0x4F51E3` (send `0x4F5237`). The consumer only starts the
corresponding helper when that dialog is hidden, and may close the other via `0x4F5263`.

If `main+0xB0298` is visible, Items additionally invokes `0x6F8BAE(hero+0x2AD8,1)` at
`0x4BCF38`. When that helper's `+4` is nonzero, it builds **type `0x3F7` (1015), operation
byte `0x12`** via `0x73ED85` and conditionally sends at `0x6F8C06`; clears its `+4`;
calls `0x6F8A11/0x6F8D6C`; and posts `0x436,0x438,0x437`. Packet `+4` takes the prior helper
`+4`, and its optional string is obtained from hero `+0x14C`. These facts do not require a
speculative name for that helper.

Items finally requests state 5 at `0x4BCF51`. If initially visible, it rechecks visibility and
requests 0 at the same call site. The opening path has notification, networking and hero-side
effects; the handler is not just a toggle.

### Setup — 0x004BCF5A

If `main+0x76C04` is hidden, requests state 5 at `0x4BCF87`. If visible on both checks, calls
the thunk to `0x51EBB0` at `0x4BCF9D`. This close/apply path reads controls at Setup-relative
`+0xA48/+0xAD4` using `0x5E0576`, sets music/sound volumes at `0x51EBD2/0x51EBEB`, passes
music volume to `0x62821E`, then hides at `0x51EBF5`. Hide callback `0x51EF61` persists
settings using `0x6524AA,0x6525AA,0x6526AA,0x6529CF,0x653258` and `0x653350`.

After hiding, it scans four check pointers starting at Setup `+0xF8` and stops on the first
**zero** state byte from `0x58B907`. If such index `i` exists and differs from hero dword
`+0xDC` (getter `0x650B38`), it builds **MsgAction `0xB2`, parameter `i`** at `0x51EC43`
and conditionally sends at `0x51EC52`. Four nonzero states cause no packet. The meaning of
hero `+0xDC` is not inferred from an inherited BN label.

### Mission — 0x004BCFA4

Plays the click sound, removes the `roleword` effect from the object pointed to by `main+0x1A8`
using `0x4BCE54(main,0)`, then calls `0x4BD255`. That helper plays a second click sound at
`0x4BD266` and toggles `main+0x12AC64` at `0x4BD286`.

The dialog's show callback `0x4CA066` (vtable `0x8563C8`, slot `+0xEC`) refreshes its task
collections/tree through `0x6A4D63/0x4C8DB8`. The latter can select a non-null child tree item,
store its ID at dialog `+0xFC`, build **type `0x46F` (1135), operation word 0**, and send at
`0x4C955E` if builder `0x716CF3` accepts the nonzero ID. It also posts `0xC47`. Hide callback
`0x4CA0A6` clears dialog content through `0x4C872C` and releases/reset its `+0x100` object.
These are task-dialog/effect changes, not an emboss/frame-2 update of Mission itself.

### Chat — 0x004BCFCD

The supplied label and `ChatBtn.dds` filename do not establish the action. The exact path is:

1. Sound; `0x68A737(singleton_414BDA,0x1B)` at `0x4BCFF8`. It returns true when singleton
   dword `+4 == 1` (`0x68A72D`); selector `0x1B` resolves `STR_NOT_TRADE` via table
   `0x68B3FE[0x1B] -> 0x68B1BA` and displays the resolved nonempty text through `0x5858B0`.
   True stops activation. The PE RTTI identifies the owner as `CDataMigrationSubject`; its
   exact wider state-machine meaning is not assigned here.
2. Reject when `0x65BB03`'s shared status predicate is true (status bits `0x36/0x3B/0x3A`).
3. Anti-addiction grade 0 or 50 rejects and dispatches the respective
   `STR_WALLOW_OPT_LIMIT_WARNING_NONE` / `...HALF` text with code `0x7D5`, color `0xFFFF0000`.
4. Other grades post **WM `0x464`, wParam `0x16`, lParam 0** at `0x4BD031`.

`0x64D015` forwards the command unchanged via `PostMessageA` if HWND global `0x96AB00` is
nonzero. This low command reaches the base window procedure at `0x5CD97D`; the native MFC
message-map entry **`0x8685E8`** binds WM `0x464` to `0x5B29E2`. Its table
`0x5B80FC[0x16] -> 0x5B31B5` is the actual command consumer.

That consumer rejects map flags `[map+0xEC]&4` (the upper dword of the map flag field), showing
the text keyed at `0x9376CC`; rejects hero `[+0x1114]!=0` via getter `0x729CE6`, showing data-set
text ID `0x2D0F`. Otherwise it shows text ID `0x2751`, invokes `0x5B27AE(shell,0x10,0)` at
`0x5B32C3`, clears singleton `0x480676`'s `+4` via `0x685DA1`, and clears hero `+0x2EC0`
via `0x666990`. The shell setter writes `shell+0x179800=0x10`, global `0x95864C=0x10`, and
`shell+0x179804=0`. Changing modes first calls old-mode cleanup `0x5B26D4`; that cleanup can
change other state/checks and post further commands according to the old mode.

**PROVEN observable result:** guarded queuing/arming of interaction mode `0x10`, plus the
specified prompts and state changes. This handler does not directly open a chat window or
call a packet send. A complete packet-free claim for all old-mode cleanup paths is not made.
“Trade targeting” is a semantic interpretation supported by `STR_NOT_TRADE`; the exact
state writes above are the contract. The eventual target click is a separate event.

Do not confuse this with shell code `0x5C0FE9`: clean jump-table decoding maps that block to
**command `0x518`**, not `0x16`. HLIL's compressed switch case numbers are not necessarily
original message command values.

### Group — 0x004BD109

Toggles `main+0x817C4` at `0x4BD141`. No extra guard beyond visibility is present in the
button handler. The dialog's `+0xF0` callback `0x498C29` (vtable `0x852B60`) closes its visible
child `+0xF8`, refreshes member IDs/images/checks, and conditionally changes the skins of its
own buttons `+0xC0C/+0xCAC` to Button190/191/192/193/194/196. One branch disables its own
`+0xD4C` button at `0x498E66`. **Those are Group-dialog children, not Button46 or another
action-strip button.** Hide callback `0x51FCA0` also closes child `+0xF8` when visible.

### PK — 0x004BD399

After sound, calls `0x660657` at `0x4BD3B7`. This returns the inverse of `0x61F305`, which
tests `[map+0xE8]&0x10000000`. A set map bit suppresses activation; it does not disable
the button or select its disabled frame. When allowed, visibility of `main+0x8E100` forces
show-state 5 for `main+0x9581C`; otherwise that latter dialog is toggled. State call:
`0x4BD3F5`. The click itself does not cycle or assign PK mode. It opens/toggles the selector.

### Organise — 0x004BDA50

After sound, toggles `main+0x90A80` at `0x4BDA81`. Its primary vtable `0x858D38` uses the
empty `0x4BCD46` for the three show/hide callback slots described above. The click handler
does not clear `main+0x104`. The separate bulletin-opening paths below clear that flag.

## Per-instance writer/xref census

`census.py` scans all executable PE sections, retaining raw instruction bytes and context for
all candidate references to the ten `0xA0`-byte ranges. It considers primary main, shell, and
the main object's secondary interface at `+0xF8`; all setter/EnableWindow/GetDlgItem candidates
are also retained. The reviewed ledger has **98 numeric candidates, 81 actual action-strip
references and 17 rejected receiver/offset matches**. All 81 are classified in
`instance-reference-review.json`; the original candidates remain in `instance-references.json`.

The secondary-interface correction matters: `0x4BBFF1` is not a read of Button46's frame as
an HWND. Its receiver is `main+0xF8`, from vtable `0x855DB0` installed at `0x4B5F79`; adding
that adjustment makes its `+0x13FEAC` refer to the HWND at `main+0x13FFA4` of the following
object. `0x4BC18F` uses that same secondary receiver. The fourteen extra numeric matches from
the secondary range scan belong to other primary-main controls, including Progress44 and
Button411 (`CMyCheck`). None is an extra action-strip writer.

| Instance | Proven additional state paths after initialization |
|---|---|
| Query, Message, Setup, Chat, Group, Skill | Shared button/window paths below; no dedicated frame/skin/hover/enable writer identified in the reviewed instance census |
| Items | Same shared paths. `0x4BC9C0` reads HWND to position the separate `main+0x1A4` effect; no Button42 frame mutation |
| Mission | Same shared paths. `0x4BE78C` reads HWND to position the separate `main+0x1A8` effect; no Mission frame mutation |
| PK | Skin calls `0x5C34A9/0x5C34C1/0x5C34D9/0x5C34F1`; phase frame `0x4BCAE4`, expiration frame `0x4BCB04` |
| Organise | Phase frame `0x4BCB6F`; frame-zero calls `0x4BDB24`, `0x5C240C`, `0x5C2577` |

The scan also preserves 1,230 candidate method/import calls, including 821 calls to
the CWnd EnableWindow thunk and the application-wide frame/skin/hover/polling setters. Those
counts are search evidence, not 1,230 calls attributed to these ten objects. No reviewed
action-strip receiver is passed to EnableWindow, a hover opt-in setter (`0x589F29`), force
polling setter (`0x58A5F6`), or tooltip replacement setter (`0x58A570`). No instance-specific
post-init special-press/repeat activation was identified. ID-only GetDlgItem matches on other
dialogs do not establish a write to CDlgMain's identically numbered child.

Shared writers and relevant calls:

- `0x6C86F2`: stores the passed dword at button `+0x68`.
- `0x58A4AC`, WM_ENABLE: zero wParam writes 2 at `0x58A4C3`; nonzero writes 0 at
  `0x58A4DD`; calls base WindowProc at `0x58A4D3` afterwards.
- Mouse-down `0x58A1C2` writes frame 1 at `0x58A1CF`; mouse-up `0x58A17A` resets only
  frame 1 to 0. These ten have no special-press selector and no repeat-timer opt-in.
- Mouse-move `0x589F0F` enables tracking `+0x80`; cursor update `0x58A603` changes tracking
  and inside `+0x82` according to window/cursor state. Those are not hover-frame opt-in.
- Tick/Show `0x589FB1` writes render origin `+0x40/+0x44`, queries Control.Ani, then updates
  cursor state. It passes frame 3 only if `+0x83` and `+0x80` are true, current frame is not 1,
  and the HWND is enabled. Otherwise it passes dword `+0x68`. The ten initialize `+0x83=0`.
- Skin setter `0x58A547` assigns the string at `+0x74` only; it does not reset `+0x68`.
- The shared private message `0x271C` (`0x58A51C..0x58A53E`) decodes coordinates/extents
  and calls MoveWindow; it is not a frame selector. Initial placement/calibration remains
  described in the existing startup/layout notes.

## Skill and Mission frame 2

Exact clean ANI data (paths/case preserved; no semantics inferred from names):

| Section | frame 0 | frame 1 | frame 2 |
|---|---|---|---|
| Button41, count 3 | `data/main/SkillBtn.dds` | `data/main/SkillBtnClick.dds` | `data/main/SkillBtnL.dds` |
| Main3_MissionBtn, count 3 | `data/interface/Style01/Action/MissionBtnNormal.dds` | `data/interface/Style01/Action/MissionBtnClick.dds` | `data/interface/Style01/Action/MissionBtnEmboss.dds` |

**PROVEN:** frame 0 initialization, down/up 1/0, and generic WM_ENABLE(FALSE) selection of
frame 2 apply to both instances. Rendering passes that selected frame to the ANI draw.
The 48 native WM_ENABLE replays cover both instances and PK, four incoming frames, and
wParam 0/1/2/0xFFFFFFFF. **INSUFFICIENT EVIDENCE:** a dedicated game condition that sends
the disabling transition to Skill or Mission. “Skill available,” “quest notification,” or
“disabled forever” are not justified interpretations. Their frame-2 paths are listed in clean
Control.Ani; that listing alone is not reachability or asset-container validation.

## PK mode, skins and blink

### Mode source and request/apply split

PK mode is a dword at **hero+0xFBC**. The native write census identifies default writes of 1
at `0x6557E7` (constructor) and `0x656C53` (state initialization), and assignment from the
first argument at **`0x66074B`** in `0x66066A`.

`0x66066A(hero, mode, requestFlag)` has two materially different paths:

- `requestFlag != 0`: builds MsgAction with action `0x60`, hero ID from `+0xCC`, and mode as
  the final Create parameter at `0x6606B1`; conditionally sends at `0x6606C0`. It does **not**
  assign hero `+0xFBC` or post skin command `0x400`. Requesting mode 1 additionally clears
  hero fields `+0x2CB8/+0x2CB4`, records clocks at `+0x2CC8/+0x2CC4`, and visits entity IDs
  in `[+0x2CCC,+0x2CD0)` to call `0x742B32(entity,0)` for resolved entities.
- `requestFlag == 0`: stores the supplied mode at `+0xFBC`, posts WM0x464 command `0x400`
  with zero payload at `0x660751`, and performs no request-path send. No range clamp exists.

The four selector callbacks are `0x4EF5C1/0x4EF5DF/0x4EF5FD/0x4EF61B`: request modes
0/1/2/3 with flag 1, then hide their own dialog. Their BN_CLICKED IDs are respectively
`0x667/0x664/0x665/0x666`, established by PE entries `0x859D78..0x859DC0`.
The raw resource captions are not used to assign numeric-mode semantics.

Other request paths: configuration/startup application `0x4BDC59` requests mode **3** at
`0x4BDD30`; configured-hotkey code `0x5D94E5..0x5D953D` delegates to the selector handlers
to request 0->1->2->3->0. The hotkey path is distinct from clicking Button47.

The received MsgAction processor (`0x6FED1F`) dispatches subtype word packet `+0x14 == 0x60`
to `0x6FF62A`, reads mode dword packet `+8`, and calls `0x66066A(hero,mode,0)` at `0x6FF63B`.
The earlier common entity lookup must produce a non-null reference (`0x6FF173/0x6FF18A`).
This branch then updates the hero singleton, not the resolved entity object; it has no local
entity-ID equality check of its own. The replay covers both a null resolution and a distinct
resolved non-hero object. Packet processing, queued message processing and the next HUD render
are separate scheduling events.

### Skin command and actual blink trigger

WM0x464 command `0x400` enters `0x5C3424`. It reads current hero `+0xFBC`, not the posted
payload, and takes these branches:

| Mode | section | SetAni call | gate effect |
|---|---|---|---|
| 0 | Button47 | `0x5C34A9` | writes `main+0x108=1` at **`0x5C348E`** |
| 1 | Button49 | `0x5C34C1` | preserves gate |
| 2 | Button48 | `0x5C34D9` | preserves gate |
| 3 | Button412 | `0x5C34F1` | preserves gate |
| other dword | preserves prior section | none | preserves gate |

All branches subsequently call `0x6527A2` at `0x5C3514` with the current mode. This uses
`WritePrivateProfileStringA`, key **`PkModeRecord`**, owner-provided section/file pointers
`+0x1C/+0x10`. It does not supply a new runtime mode. No full config-file path is inferred.

**Correction to the older note and BN comment at `0x5C342A`: the gate write is not
unconditional. Only mode 0 arms it.** No branch in this command resets the blink timestamp or
current frame. Repeated mode-0 commands during an active blink do not restart its duration;
mode 1/2/3 can inherit an already active blink on the new skin. If multiple apply messages
are queued before dispatch, the consumer reads the latest hero field, not each original mode.

### Exact per-render timing and order

State: local gate `main+0x108`; process-global bit 0 of byte `0x956228`; process-global
start dword `0x95622C`. All those static bytes are zero in the PE image. Constructor clears
the local gate at `0x4B5F97`; it does not reinitialize the process-global statics.

When the gate is nonzero (`0x4BCA88`):

1. If global bit 0 is clear, set it and sample time at `0x4BCAA0`, storing start at `0x4BCAA5`.
2. If start is zero, sample again at `0x4BCAB2`, storing at `0x4BCAB7`. Zero is a sentinel,
   so a genuine zero clock result has this behavior too.
3. Sample **phaseNow** at `0x4BCABC`. Compute unsigned dword difference `phaseNow-start`,
   `DIV 500` with high dividend zero, then `&1`. Write frame 0 or 1 at `0x4BCAE4`.
4. Independently sample **expiryNow** at `0x4BCAE9`. Compute unsigned dword difference;
   `CMP 30000` / **JBE** at `0x4BCAF4/0x4BCAF9` retains the cycle at equality. Only
   `elapsed > 30000` clears gate, writes frame 0 at `0x4BCB04`, and zeroes start.
   The initialization mask bit remains set.
5. Tick/Show at `0x4BCB21` observes the resulting frame in the **same** HUD pass.

Thus stable-clock elapsed 499 draws 0; 500 draws 1; 999 draws 1; 1000 draws 0;
29999 draws 1; 30000 draws 0 with gate still set; 30001 draws 0 with gate cleared.
If phaseNow is 29999 elapsed and expiryNow reaches exactly 30000, that pass still draws 1.
If the second sample reaches 30001 it overwrites the just-selected frame with 0 before Show.
The two clock reads must not be collapsed when describing the native order.

SUB and DIV are 32-bit unsigned operations: elapsed is `(now-start) mod 2^32`. Crossing one
DWORD wrap is handled by subtraction; this is not a 64-bit elapsed-time counter and cannot
distinguish a full `2^32`-millisecond lapse. Starting at `0xFFFFFFF0` and sampling `0x1E4`
gives 500 and frame 1. When the gate is zero, the blink path preserves the current frame.

The blink writes are not gated by mouse-held state or HWND enable state. While active they can
overwrite a mouse-down frame or a prior WM_ENABLE frame 2 before the current draw. No special
PK EnableWindow call was identified. The selector's map guard is a handler guard, not an
enable/disable operation. The skin setter itself never resets frame or timer.

## Organise and comparison with the other controls

Organise's gate `main+0x104` uses global bit 1 at `0x956228` and start `0x956230`.
`0x4BCB2E..0x4BCB6F` computes `1+(((DWORD)(now-start)/500)&1)`, selecting frames 1/2
before Show `0x4BCB9C`. No timeout exists. Unlike PK it has no zero-start restart check.
Re-enabling its local gate preserves the old global epoch. Outside the gate, at **`0x4BCB85`**,
`0x4E892A(main+0x90A80, main+0x104==1)` copies the boolean byte into that dialog's `+0xF8`.
That dialog has its own button at `+0x2DC` with a separate 1/2 blink (`0x4E8937`); it is not
an eleventh action-strip instance.

The bulletin producer at `0x5C3897` / actual command `0x414` retains the previously documented
checksum path. Clear/reset paths affecting the strip are:

- `0x4BDACD`: after the common Query/Skill guard, when opening hidden `main+0x104204`,
  clears `main+0x104` at `0x4BDB22` and selects frame 0 at `0x4BDB24` if the flag was set.
- WM0x464 **commands `0xCAE` and `0xCAF`**, blocks `0x5C23C8` and `0x5C2533`: when
  `shell+0x10519C` is hidden and the flag is nonzero, clear at `0x5C23F7/0x5C2562` and
  select frame 0 at `0x5C240C/0x5C2577` before opening the host.

The older `0x78/0x79` command claim was a compressed-switch-index error. The native map
`0x5CE1FF` plus target table `0x5CDE2F`, after subtracting `0xBE3`, establishes `0xCAE/0xCAF`.
Neither reset clears the process-global Organise epoch. Clicking the Organise strip button
itself toggles the intermediate dialog and does not perform those resets.

Among the **other nine** controls relative to PK, Organise has the known separate blink.
For the remaining eight, no comparable native CMyButton timer/frame producer was identified.
All ten initialize repeat off; the shared optional repeat machinery in `0x58A1C2/0x58A6D6`
does not establish an active repeat path for them. Items' `PKpack` and Mission's `roleword`
are separately hosted effects positioned from their button HWNDs. They can change the visible
HUD, but are not CMyButton frame or blink state. Do not count the transient press frame as a
timer, or those effects as evidence for Skill/Mission frame 2.

## Remaining evidence limits

- Skill/Mission application-triggered disable reachability remains unproven; generic frame-2
  selection and enabled initialization are proven. No filename-based semantics are assigned.
- The static writer census is complete for the recorded decoded candidate criteria, not a
  universal proof against computed aliases or externally delivered HWND messages.
- Handler/lifecycle packet paths explicitly described above are proven. A blanket assertion
  that every other transitive callback is packet-free is not supported by this slice.
- No managed production code, architecture proposal, BN rename, comment mutation or binary patch
  is part of this work. The bundle records precise assertions, captures, review classifications,
  analyst proposals, replay inputs/mocks, and validation results for review.
