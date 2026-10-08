# GFX-UI-006: main HUD quickbar / CMyGrid native contract

Evidence-only, clean 5517. Completed native capture/replay review 2026-10-04.
Addresses are EXE virtual addresses unless a DLL is named. Names ending in
`_Analyst` are analyst assignments, not recovered source symbols. Raw instruction
widths, stack cleanup and dataflow take precedence over existing decompiler types
and folded helper names.

Evidence: [`10_work` bundle](../../10_work/docs/evidence/gfx-ui-006-main-hud-quickbar-5517/README.md).
The bundle contains raw assembly/IL, complete direct family xrefs, caller contexts,
retail identities, original-x86 replay vectors and restorable annotations. This
contract describes client-owned decisions and explicit calls into other systems.
It does not represent a live Windows capture, a GPU pixel comparison, or proof of
server-side availability of every ID present in retail content.

## 1. Identity, ABI and initialization

`CDlgMain+0x13C430`, equivalently `CMyShellDlg+0x13D3C8`, is the grid bound to
control `0x3FD` in `0x4BB6B8`. Its storage ends at the next member
`CDlgMain+0x13F508`, giving `0x30D8` bytes. Resource 130 contains a BUTTON class
ordinal `0x80`, style `0x5001800B` (`BS_OWNERDRAW`, initially enabled). Its old
resource rectangle `(46,50,205,20)` is in dialog units and is not the final runtime
rectangle. `resource-grid.json` checks the exact resource bytes.

At `0x4BB8A9`, `ECX=main+0x13C430`. The call in `0x4BB869` is:

```c
// Semantic signature reconstructed from actual stack consumption.
int __thiscall CMyGrid_Init(
    Grid* self, int parentLeft, int parentTop,
    uint8_t rows, uint8_t columns, uint32_t context,
    const char* coverSection, const char* optionalBackgroundSection);
// Main: parent.left, parent.top, 1, 10, 3, "Compose_CoverPic", NULL.
// 0x59F5E3: RET 0x1C; successful normal path returns 1.
```

`0x59F5F5..0x59F609` obtains the control ID, calls
`UiLayout_RegisterAndPlaceWindowFromIni` (`0x591DF4`), then resets the parameters
subobject through `0x59F257(self+0x44)`. It reads the resulting HWND rectangle,
subtracts the passed parent origin, and stores the relative origin at `+0x88/+0x8C`.
`+0x5C` is a local RECT `(0,0,HWNDwidth,HWNDheight)`.

`+0x54=rows`, `+0x55=columns`. Native signed division computes:

```text
cellHeight = low8(truncTowardZero((HWNDheight - rows + 1) / rows))
cellWidth  = low8(truncTowardZero((HWNDwidth  - columns + 1) / columns))
```

Argument values are narrowed to bytes before division. Init has no zero-divisor
or `rows*columns <= 256` check. The main values are safe: one row, ten columns,
40×40 cells. The `3` argument is the pickup/notification context identifier,
also used by Show to select quickbar quantity and cooldown behavior. The final
`0` is a null background-section pointer, so `+0x50` remains zero. It is not a
frame selector, spacing value, or color. The cover section is stored separately.

`[GridNum]` in `ini/Info.ini` supplies `Dir=3`, `Size=16`; these are DWORDs at
`+0x30D0/+0x30D4`. Main Show overrides the number direction argument to zero.
There is no post-placement dialog-font scaling pass in this grid Init. The shared
placement helper can first scale the prior HWND size at `0x591E2E..0x591E70`;
its subsequent explicit GUI x/y/w/h `MoveWindow` at `0x591FF6` replaces that size.
The complete `[130-1021]` record therefore leaves this grid at 410×40. Do not
apply the check, progress-gauge, old shell-height, or screen-width scaling formulas
here.

### Default state and field map

Offsets below are relative to the outer grid, **not** the `+0x44` params receiver.
`0x59F1D6` constructs that params subobject; `0x59F257` resets it. Init then enables
interaction/pickup, stores row/column/context and sets every selector to 3.

| Offset / width | Proven meaning and relevant default |
|---|---|
| `+0x44 DWORD` | insertion/removal counter, zero; overwriting an occupied slot still increments it, so it is not an invariant occupied-slot count |
| `+0x48 DWORD` | context, main=3 |
| `+0x4C DWORD` | cached picked/activated slot selector |
| `+0x50 byte` | optional background enabled, main=0 |
| `+0x51 byte` | interaction gate, Init=1; setter `0x5A164F` |
| `+0x52 byte` | hover/hint cache active, initially 0 |
| `+0x53 byte` | occupied-slot pickup gate, Init=1; setter `0x5A1659` |
| `+0x54/+0x55 bytes` | rows / columns, main=1/10 |
| `+0x56/+0x57 bytes` | cell height / width, main=40/40 |
| `+0x58/+0x59 bytes` | cached picked glow / content kind |
| `+0x5C RECT` | local hit rectangle; right/bottom fields also at `+0x64/+0x68` |
| `+0x6C DWORD` | cached picked/activated payload |
| `+0x70/+0x74 DWORDs` | hovered payload / content ID; not the item-instance UID |
| `+0x78/+0x7C DWORDs` | cached picked/activated item UID / content ID |
| `+0x80/+0x84 DWORDs` | last destination column/row, written on drop request |
| `+0x88/+0x8C DWORDs` | parent-relative origin |
| `+0x90/+0x94 DWORDs` | cached one-based hovered column/row |
| `+0x98/+0x9C DWORDs` | cached one-based picked source column/row |
| `+0xA0/+0xA4 DWORDs` | absolute origin cached by the most recent Show |
| `+0xA8`, 16 bytes | cached picked metadata descriptor |
| `+0xB8`, 256 DWORDs | per-slot image/texture variant selector, Init=3 |
| `+0x4B8`, 256 DWORDs | aggregate inventory quantity, initially 0 |
| `+0x8B8`, 256 bytes | occupied flag, initially 0; any nonzero byte tests occupied |
| `+0x9B8`, 256 bytes | cover flag and interaction block, initially 0 |
| `+0xAB8`, 256 bytes | content kind, initially 0 |
| `+0xBB8`, 256 bytes | item glow kind, initially 0 |
| `+0xCB8`, 256 DWORDs | item glow start time, initially 0 |
| `+0x10B8`, 256 DWORDs | source payload; inventory producers use an inventory index; other producers can supply zero |
| `+0x14B8`, 256 DWORDs | content ID, e.g. item type, action ID, skill type, dance ID |
| `+0x18B8`, 256 DWORDs | item-instance UID, initially 0; independent of content ID |
| `+0x1CB8`, 256 pointers | per-slot Game3DEffect object, constructor=null |
| `+0x20B8`, 256 records ×16 | item metadata: DWORD add level, DWORD stack count, byte copied from CItem+0x165 in DWORD storage, DWORD inscribed flag |
| `+0x30B8/+0x30C4`, 12 bytes each | cover/background character-vector storage |
| `+0x30D0/+0x30D4 DWORDs` | number direction / size; these are not strings |

`0x67B782` proves metadata construction. The byte at item `+0x165` is preserved
without assigning an unproven gameplay name. Metadata defaults are `(0,0,byte 1,0)`;
the upper three bytes of its third DWORD are **not** initialized by that write.
The poison-memory constructor replay confirms this. Reset does not reinitialize
metadata. Reset calls effect `vtable+8` on non-null `+0x1CB8` pointers, without
nulling them. Do not replace Reset with a blanket zero-fill.

## 2. Geometry and hit testing

Both `ini/GUI.ini` and `ini/GUI800X600.ini`, section `[130-1021]`, contain
`x=90,y=98,w=410,h=40`. Parent `[0-130]` is at `(0,459)` or `(0,627)`.

| Logical framebuffer | Parent-relative grid | Absolute grid `(x,y,w,h)` |
|---|---|---|
| 800×600 | `(90,98,410,40)` | `(90,557,410,40)` |
| 1024×768 | `(90,98,410,40)` | `(90,725,410,40)` |

For zero-based slot `i=0..9`, the cell draw rectangle is
`(90+41*i, H-43, 40,40)`. The union of the HWND's clickable cell intervals is
`[90,500) × [H-43,H-3)`. Each slot's effective input rectangle within that HWND
is `(90+41*i,H-43,41,40)`, including the one-pixel horizontal gap after its
40-pixel draw. Geometry vectors enumerate all ten rectangles at both resolutions.

`0x5A0965` is a distinct point-to-coordinate mapper. It scans one-based rows and
columns, accepting signed `pixel <= cellSize+(coordinate-1)*(cellSize+1)`.
It does not test a lower bound. Thus negative X/Y can map to `(1,1)` if called
directly. With the main dimensions, X 0..40 maps column 1, 41..81 column 2,
369..409 column 10; Y 40 also maps row 1 in the mapper, although outside the HWND.
If no match is found, output X is the original pixel X; output Y is the last row
whose Y upper bound passed, or the original Y if none passed. This is not a
clamp and not a reliable invalid-slot sentinel. See the exact negative/outside
vectors. Mouse-down/right-down invoke this mapper without their own PtInRect.

Hover `0x5A1226` explicitly uses `PtInRect(+0x5C,POINT)`: left/top inclusive,
right/bottom exclusive. Pickup-start `0x59FAA3` additionally checks actual cursor
position inside `GetWindowRect(HWND)` and `WindowFromPoint == HWND`. Drop callbacks
check the actual HWND rectangle with `PtInRect`. No alpha-mask or texture pixel
participates in these grid tests. HWND routing and any default BUTTON processing
remain Windows responsibilities.

`0x5A17FC` handles private message `0x271C` by decoding **unsigned** 16-bit X/Y
from wParam and width/height from lParam, then calling `0x5A1910`. That function
moves the HWND, caches origin, rebuilds local RECT, and recomputes byte cell sizes;
unlike Init, it guards zero row/column counts. WM_ERASEBKGND returns 1;
WM_NCPAINT returns 0; WM_PAINT calls BeginPaint/EndPaint without drawing content.
Other messages go to `CWnd::WindowProc` (`0x77716C`).

## 3. Exact queried APIs and mutation

All below use ECX=this, with stack arguments in the displayed order. `int`/`u32`
mean 32-bit stack slots; byte arguments consume a 4-byte slot but use only its
low byte. Return values not explicitly documented are not semantic success flags.

| Address | Proven semantic signature / boundary |
|---|---|
| `0x59F5E3` | `int Init(int parentX,int parentY,u8 rows,u8 cols,u32 context,char* cover,char* background)`; RET 28 |
| `0x59FC1E` | `Show(int parentX,int parentY)`; RET 8 |
| `0x5A0FA7` | `u8 Occupied(int col1,int row1)`; AL only; RET 8 |
| `0x5A11B5` | `int Index(int col1,int row1)`; EAX; RET 8 |
| `0x5A16AB` | `u8 Kind(int index0)`; AL only, unchecked; RET 4 |
| `0x5A17CC` | `POINT* Origin(POINT* out)`; returns out; RET 4 |
| `0x5A17E4` | `u32 CellWidth()`; zero-extended byte +0x57 |
| `0x5A17E9` | `u32 CellHeight()`; zero-extended byte +0x56 |
| `0x5A17EE` | `u32 ItemUid(int index0)`; unchecked DWORD +0x18B8; RET 4 |
| `0x5A08D2` | `ShowSlotEffect(int col1,int row1)`; RET 8 |
| `0x5A0965` | `POINT* MapPoint(POINT* out,int pixelX,int pixelY)`; RET 12 |
| `0x5A103E` | `int Populate(int col1,int row1,u32 content,u32 payload,u32 selector,u8 kind,u8 glow,u32 autoPlace,Metadata16* data)`; RET 36 |
| `0x5A15C0` | `ClearOccupied(int col1,int row1,u8 all)`; RET 12 |
| `0x5A16CB` | `SetItemUid(int index0,u32 uid)`; unchecked write first; RET 8 |

Index is `columns*(row-1)+column-1`, with 32-bit wrapping and no checks.
Occupied checks only signed index `0 <= index < 256`, not configured coordinates;
for example `(11,1)` can refer to storage slot 10 despite a ten-column grid.
This does not authorize treating that as an eleventh visible main-HUD slot.

Populate validates column/row against configured dimensions before checking
`autoPlace`. Invalid coordinates log and return 0. A full auto-place scan returns
-1. Success returns the zero-based slot index, so 0 is also valid success.
`0x59FA20` finds the first unoccupied cell, row-major, reversing columns when
`g_uiLayoutModeFlag` at `0x96AB30` is nonzero. `0x5A1138` writes occupancy,
content/payload/selector/kind/glow and all 16 metadata bytes. A nonzero glow resets
its timer to zero; zero glow leaves the old timer untouched. Neither routine
sets UID or aggregate quantity. Populate increments `+0x44` on overwrite too.
There is no physical-capacity guard for oversized configured dimensions.

The all-removal argument tests only its low byte. Single removal clears occupancy and decrements the counter only if occupied;
all-removal clears 256 occupancy bytes and sets the counter to zero. All other
slot fields persist. `0x5A1629` restores a cached descriptor through `0x5A1138`
without updating counter or UID. `0x5A16CB` writes UID before its hover checks,
then may refresh the item tooltip for the visible parent/current hovered kind-1
slot. `0x5A1671` sets quantity; its direct caller `0x5D7B5F` aggregates inventory
items matching the shortcut's content ID, adding `max(itemStackCount,1)`.

### Main-instance producer census

The bundle retains every direct caller of population, internal descriptor write,
restore, occupancy write, interaction/pickup gates, per-slot effect setup, quantity
and UID setters, plus their raw instruction neighborhoods. The separate member-
displacement candidate list includes other HUD members and is not itself an
alias or reachability proof. Main receiver identity is followed through:
`main+0x13C430`, `shell+0x13D3C8`, and `(main+0xF8)+0x13C338`.

| Producer | Main population sites / semantics |
|---|---|
| config restore `0x4BDC59` | `0x4BDF2C`, `0x4BE00B`, `0x4BE0F3`; kinds 1..6, glow=0, no auto-place |
| main drag adapter `0x4BBF81` | `0x4BC104`, `0x4BC163`; inventory kind1 or existing quickbar descriptor kind, glow=0 |
| action context `0x13`, `0x419C71` | `0x419D58`; kind2, selector3, glow0 |
| dance context `0x5F`, `0x442D3D` | `0x442E24`; kind5, selector3, glow0 |
| magic context `0x64`, `0x4A33EC` | `0x4A34D3`; kind3, selector3, glow0 |
| magic context `0x14`, `0x4B4545` | `0x4B462C`; kind3, selector3, glow0 |
| query-skill context9, `0x509AD6` | `0x509BBE`; descriptor content kind, selector3, glow0 |
| weapon-swap context `0x5E`, `0x52F9ED` | `0x52FABC`; kind6, content0, selector3, glow0 |
| XP context `0x24`, `0x57521A` | `0x575301`; kind4, selector3, glow0 |

External producers above require the matching pickup context and cursor inside
the actual main grid HWND. They derive slot coordinates from that cursor; no
screen-width proportional formula is involved. Each passes payload0 and default
metadata for non-item content. Config restore iterates columns 1..10, **stopping
if the current slot is already occupied**, rather than overwriting it. Saved
value `0xFFFFFFFF` is skipped; decimal remainder gives kind, quotient gives
content ID. Kind6 restores ID0. Kind1 finds a matching inventory item, or builds
a temporary item from the saved type if absent; UID, metadata and selector come
from that item. Save `0x4BDB3F` stores `10*contentID+kind`, or zero for empty.

All identified main population paths pass glow0. The generic FireLight branches
are documented below and inventoried separately; their presence in shared Show
is not evidence that the main quickbar activates them. Likewise the four direct
`0x5A1879` per-slot-effect setup callers belong to other grids. Main's independently
owned `reif` effect is proven and is included. No claim of dead storage is made
from absence of a direct write alone.

## 4. Rendering contract

Main calls Show at `0x4BC810`, after progress/XP rendering. Native order is:

```text
progress / XP phase
CMyGrid_Show: all ten slots
main suspicious-item overlay loop: all ten slots
 ten CMyButtons
 four CMyChecks
 Magic0 selected-skill image
 subsequent main item-use animation, when active
```

Show stores `(parentX+relativeX,parentY+relativeY)` in `+0xA0/+0xA4` and traverses
rows then columns, stride `(cellWidth+1,cellHeight+1)`. Per slot: optional
background → occupied content → item quantity/plus if applicable → cover/cooldown
text → per-slot effect. An empty slot has no icon/background in main; it can
still draw explicit cover and an existing slot effect. At the end, active hover
causes `0x5A1558` cursor polling. There is no general disabled tint or selected
frame transition in this Show.

Let `(X,Y)` be this slot's absolute cell origin, main width/height `40`.
All ordinary quickbar icon calls use frame 0, color argument 0, mode 0.
Color 0 preserves the frame's vertex color; it does not mean alpha zero.
The established `CMyBitmap`/C3 mode-0 path uses source-alpha / inverse-source-alpha
blending; see [the renderer contract](15_main_hud_gauge_render_contract.md).
The grid does not clip sprite draws to HWND bounds. Logical framebuffer clipping
is downstream; no per-cell alpha-mask or clipping rectangle is installed here.

| Kind | Exact resolution | Draw geometry |
|---:|---|---|
| 1 | `RoleDataQuery()->vtable+0x9C(ResolveItemIconKey(content,selector),1)` | source `(0,0,64,64)`, destination `(X,Y,40,40)` |
| 2 | `ani/Control.ani`, `ButtonA%d` with content ID | whole natural frame, origin `(X+3,Y+5)` |
| 3 | `ani/Magic.ani`, `MagicSkillType%d` | source `(0,0,50,50)`, destination `(X+2,Y+4,37,37)` |
| 4 | `ani/Magic.ani`, `XpSkillType%d` | same geometry as kind3 |
| 5 | `ani/Control.ani`, `Action_Dance%dBtn` | whole natural frame, origin `(X+3,Y+5)` |
| 6 | `ani/Control.ani`, `Swapuse_SwapmainbBtn` when hero `+0xF1C==1`, otherwise `Swapuse_UsemainbBtn` | whole natural frame, origin `(X+3,Y+5)`; content ID unused |
| other | no content icon branch | explicit cover and slot effect still processed |

Every resolved retail action/dance/swap frame0 in this inventory is 64×64.
Thus these whole-frame destinations are `(X+3,H-38,64,64)`, extending 26 pixels
below a height-H framebuffer; this describes rectangle geometry, not the alpha
coverage of the artwork. Their sprite extent is not forced to 40×40. The 40×40
item/cover cells end at H-3; 37×37 magic cells end at H-2. No width scaling is used.

The unused-for-main optional background path (`+0x50`) resolves Control.ani /
`+0x30C4`, source38×38, destination cell dimensions, color `0x000000FF`, mode0.
Do not treat this color as opaque white.

### Item key, overlays, quantities, cooldown

`0x67AEB2` calls `ItemSourceFamily_ResolveCategoryCode` (`0x67AF1A`): families
1/3/6 use `selector*1,000,000+contentID`; family14 queries
`RoleDataQuery()->vtable+0xA8(100*contentID + selector%100, selector/100)` and uses
returned record `+0x10`, falling back to contentID for null; all others use
contentID. Arithmetic is native DWORD arithmetic. GameData.dll vtable
`0x100170E8+0x9C` resolves to `0x10007958`: key0 returns null; other keys request
`ani/ItemMinIcon.Ani`, section `Item%d`, with fallback `ItemDefault` on failed
lookup. These are item **type/icon** keys, not item-instance UIDs.

Item glow, when nonzero, precedes the icon. `+0xBB8` values 1/2/3/4/6 select
`FireLight` / `RedLight` / `BlueLight` / `RoyalBlueLight` / `YellowLight` in
`ani/effect.ani`. Value5 looks up `contentID%700000` in the table at `0x957F68`
through `0x5AB92C`, taking the nonempty string at returned record `+0x28`.
Other nonzero values skip glow. Null lookup skips it. Start tick0 writes
`timeGetTime()` and draws frame0. Otherwise frame is
`uint32(now-start)/100 % aniFrameCount`. Source64×64, destination cell dimensions.
This subtraction wraps as DWORD; a non-null ANI with frame count0 would divide
by zero on that later path. Main producer census does not establish a nonzero
main glow writer; these are shared-class semantics, not mandatory main effects.

Quantity `0x5A199E`: main context3 uses aggregate `+0x4B8` and draws even zero.
It formats decimal text with `_itoa`, resolves each digit as Control.ani /
`Main3_Num%dPic`, source16×16, destination `GridNumSize` square. For the clean
size16, first digit `(X+2,Y+2)`, stride8. Other contexts use metadata stack count,
skip <=1 and honor configured direction. Negative values format a minus sign;
that character produces section `Main3_Num-3Pic`, whose failed lookup stops the
number. It is not a separate minus asset special case.

Plus `0x59FB0A`: positive metadata add level draws decimal `Equip_Num%d` digits
right-to-left at `(X+cellWidth-11,Y)`, decrementing X by9, then `Equip_AddPic` to
the left. All use natural frame0 dimensions. No plus overlay when
`(contentID/10000)%100 == 73`. A missing digit stops the digit loop; a successfully
loaded plus sprite can still draw. A missing item icon skips both quantity and
plus, but not the later cover/effect phase.

Cover is `Control.ani / Compose_CoverPic`, frame0 source64×64 to cell40×40.
An occupied slot draws it if explicit `+0x9B8` is nonzero, or context3 kind1 has
quantity<=0, or context3 kind3/4 has positive remaining cooldown. An empty slot
uses only explicit `+0x9B8`. Cover is a full rectangle, not a radial or progress
fill. It is drawn after quantity/plus.

Cooldown predicate `0x6F6163` succeeds when the global remaining timer is nonzero
or the learned magic information DWORD `+4` exceeds1000. Remaining calculation
`0x6F60B9` returns0 if `CGameMap_IsStateBlockingAutoRun` succeeds, otherwise the
maximum of global and per-skill remaining times. `0x6F6201` returns
`hero[+0x122C]-now` only if unsigned deadline>=now; equality gives0. Per-skill
last-use value from `0x6F6097` plus info[+4] wraps to32bits; it contributes only
when unsigned resulting deadline>now. These comparisons are **not** wrap-safe
elapsed-time comparisons. `cooldown-vectors.json` verifies equality and wrap.

Positive remaining time draws `((remaining-1)/1000)+1` as decimal text after
cover. `[QuickMagicNum]` in Info.ini: OffsetX0, OffsetY0, FontSize20,
Color`0xFFFFFF00`. Native text arguments are `(X+offsetX,Y+offsetY,color,text,
fontSettings+0x10D,fontSize,fontSettings[+8],fontSettings[+4],
fontSettings[+0x214],&fontSettings[+0x218])`. These are GUI face, antialias,
render-text style, corner color and corner offset. `Load_FontSetting_Ini`
(`0x769BC7`) supplies the record; a null record logs and aborts **the entire Show**,
skipping later cells/effects/hover polling. Font enumeration/settings/default-
font selection is the existing native font subsystem, not a new quickbar font
asset rule. The clean fixture has `ini/Font.ini` (`Arial 12`), no FontSetting.ini
or Font/GUI/Font/Chat directory. Font size20 comes from QuickMagicNum, not that12.

### Per-slot effect and main-owned effects

`0x5A08D2` guards flattened index0..255, then performs two map-coordinate
conversions on `(A0+cellWidth*(column-1), A4+cellHeight*(row-1))`. This anchor
omits the one-pixel stride. A non-null `+0x1CB8[index]` receives virtual `+0xC`
with the resulting coordinates and `0xFFFFFFFF`, regardless of occupancy.

After Show, `0x4BC839..0x4BC959` checks ten occupied kind1 slots, obtains each
UID, finds the item, and tests `CItem_IsSuspicious`. It draws **main+0x1A0** effect
`reif`, allocated during main construction and loaded at `0x4BBF1A` with repeat1.
The anchor starts at `(cellWidth+1)*(column-1)+(cellWidth+1)/2` and
`(cellHeight+1)/2`, then uses the captured map conversion sequence with world-Y
minus20. This is separate from `+0x1CB8`.

`reif-native-database.json` verifies `ini/c3.wdb` → `ini/3DEffect.dbc` record2254,
offset209364, four layers9528..9531, offset `(0,35,0)`, start delay0,
loop count99999999, frame-count field44, lifetime0, source/destination blend5/2.
Resource IDs resolve through packed 3DEffectObj/3DTexture records to
`c3/effect/reif/{1..4}.{c3,dds}`. Text INI copies are not the authority.

Right-click item activation also calls `CDlgMain_PlayItemQUse` (`0x4BD901`): it
loads `effect.ani / ItemUse`, sets main `+0x18C=1`, start tick `+0x194=0`, caches
frame count `+0x190`, and origin `+0x184/+0x188`. Its later render block begins
`0x4BCC3F`, after Magic0. Its ANI dependencies are inventoried as a subsequent
activation effect, not part of CMyGrid_Show's cell draw order.

## 5. Input, notifications and drag/drop

Message map `0x8679D8`, entries `0x8679E0..0x867A58`:
WM_LBUTTONDOWN201→`0x5A09E7`; WM_RBUTTONDOWN204→`0x5A0DF9`;
WM_LBUTTONDBLCLK203→`0x58A597` (Default);
WM_MOUSEMOVE200→`0x5A1226`; WM_LBUTTONUP202→`0x5A1683`.
The grid vtable is `0x867A78`; WindowProc slot+A0→`0x5A17FC`, default-proc slot+A8
uses the captured MFC thunk `0x777160`. No grid-owned SetCapture/ReleaseCapture
call or pixel-alpha hit test occurs in these handlers. Native default forwarding
is an explicit boundary; no Windows notification/capture outcome is inferred
from the replay's mocks.

### Left down / up

Left down maps POINT and index first. `GetKeyState(VK_CONTROL)` is tested as
**AL & 0x80**, not AX & 0x8000. With an occupied slot this path requests command
`0xDC3` with the main slot UID and returns before Default. Original-x86 vectors
separate return values0x8000 and0x0080. It is inaccurate to silently replace this
instruction with a conventional high-bit Ctrl check.

Otherwise `+0x51` gates processing. For main context3, nonzero hero byte`+0x2E30`
(read by `0x667633`) first posts `(0xC66,1)`. That byte is recorded by offset;
no unsupported gameplay label is assigned to it. Occupied, pickup-enabled,
unblocked slots behave as follows:

- No active drag: cache source coordinates, content, UID, selector, payload,
  kind/glow and metadata; call manager start `0x5E7C8B(context)`. On success,
  clear source occupancy through `0x5A15C0`. On failure, occupancy remains.
- Active drag in matching context and destination kind1: cache destination's
  descriptor, store destination `+0x80/+0x84`, post `(0xD,context)`.
- Other active drag: store destination coordinates and post `(0xC,context)`.
- Empty slot with active drag: likewise posts `(0xC,context)`.

The normal tail calls Default after these changes. Main has no Shift split-stack
branch; the low-AL Shift test in the shared handler is restricted to context12.

Left up checks only active drag, matching context, and context3. It posts `(0xC,3)`
then calls Default. It does **not** hit-test the supplied POINT, update destination
coordinates, restore the removed slot, or itself release capture. The subsequent
callback uses actual cursor position. Thus an outside input coordinate alone
cannot be interpreted as native cancellation.

Command C at `0x5B2E4F` → `0x5BAC27` → manager `0x5E7C04`: target callback v0;
true ends active drag, false retains it and updates target context. Command D
routes through `0x5BAC4F` → `0x5E7C3F`, callback v4. Start `0x5E7C8B` uses v8;
cancel `0x5E7CC7` uses vC, sets context`0xFFFFFFFF`, clears active. Registration
`0x5E828C` → `0x5E7D0F` associates the callback object with context3.

Main's callback object is **main+0xF8**, vtable`0x855DB0`:
v0=`0x4BBF81`, v4=`0x4BCD46`, v8=`0x4BC18F`, vC=`0x4BCD46`.
The latter is an empty return, not a restore operation. Start checks cursor/
HWND via `0x59FAA3`, copies snapshot `0x5A0FD1` into manager descriptor+0x10.
Drop checks the actual grid rectangle and accepts main context3 or inventory
context12. Inventory rejects equipment or categories10,11,15,16,17,18,20 through
`0x67C8AE/0x67C8A0/0x67C849/0x67C877` in addition to equipment predicate.
It populates with glow0, writes UID, refreshes aggregate quantities. Dropping
outside grid still returns true, ending the drag without restoring the shortcut
removed at pickup. A separate descriptor control ID`0x3FE` targets the selected-
skill HWND and delegates to `0x5BABBC`; it is not another grid slot.

### Right down activation

For context3, enabled + occupied + not blocked snapshots payload/UID/selector and
posts command0x10 with `(contentID<<8)|index0`, then normally Default.
A zero interaction byte returns before mapping the point or calling Default. There is no kind-specific frame press/release transition. Command0x10 entry
`0x5B2E7C` → `0x5BB2E4` decodes low byte slot0..9 and upper24 content ID:
kind1 finds inventory by type and calls `0x6D9C31` plus the main item-use effect;
kind2 delegates action `0x41A007`; kind3/4 follow their captured skill selection/
cast paths; kind5 delegates dance `0x44344A`; kind6 posts command`0xC29`.
These are the exact client dispatch boundaries, not claims that every activation
sends a packet or bypasses downstream action/skill guards.

### Hover ordering, including corrected prior note

`0x5A1226` behaves differently from an always-forwarded mouse-move handler:

- Outside `+0x5C` PtInRect: immediate return, **no clearing and no Default**.
- Occupied kind2: possibly hide the item tooltip if changing cached slot, update
  hovered coordinate, preserve hover flag and cached payload/content, return
  without Default. It does not emit an action tooltip command pair.
- New occupied non-kind2: set hover=1 and cache coordinate/payload/content.
  Anchor is `A0+cellWidth*(column-1), A4+cellHeight*(row-1)`, omitting spacing.
  Kinds3/4 post7(packed anchor), then9(content); kind5 posts7 then0x38(context);
  kind6 posts7 then0x6A(0x5E). These pairs return without Default.
- Kind1 with context!=0x37 uses the item-tooltip object (`0x5EAA28`) with UID,
  grid context and parent context (`0x6C788C`), then Default. If cached absolute
  origin is `(0,0)`, it includes the captured parent-rectangle conversion branch.
  Generic remaining kinds/context0x37 hide item tooltip, post7 then5(context),
  then Default. Same cached occupied slot normally only calls Default.
- Empty slot: if hover was set, clear it, post6(0), hide tooltip; then Default.

`Show`'s final `0x5A1558` polls GetCursorPos and the actual HWND rectangle. On
outside, it clears hover, posts6(0), hides tooltip. This is when an outside cursor
is cleared if no empty-slot move cleared it first. `input-vectors.json` verifies
outside retention, all content-kind notification pairs, Default ordering, down/
up transitions, and the distinct raw key-state test. Native calls to the default
BUTTON procedure are preserved as boundaries, not replaced by a guessed capture
or BN_CLICKED rule. The quickbar's client activation is its own right-down command.

## 6. Asset resolution, provenance and failure

`assets.json` contains every effective frame mapping for the selected Control
patterns, Magic patterns and ItemMinIcon lookup universe, plus shared glow and
ItemUse effects and packed `reif` resources. Each resolved unique logical path
has winning provenance, file size, SHA-256, native WDF UID, archive offset/size
when archived, decoded dimensions/format/FourCC and RGBA hash for raster assets.
C3 mesh records are identified as mesh containers, not assigned raster dimensions.

The primary cover is exactly:
`[Compose_CoverPic] FrameAmount=1`, frame0
`data/interface/compose/CoverPic.dds`, natural64×64. Its winning clean fixture
source is the loose file; archive candidates do not override an existing loose
file. See the manifest for exact casing and hashes. It is drawn into40×40.

Important native loader correction: ANI sections use the **case-sensitive** hash
`uint32(h*33 + signExtend8(character))`, starting0 (`graphic.dll 0x10037290`).
The section map compares only that unsigned hash. Parsing a later record with an
equal hash replaces the earlier frame vector (`0x1000C240`, insertion/find
`0x1000D370`, assignment at`0x1000C5CF`). This applies to duplicate titles and
hash collisions, without a secondary name comparison. Lookup uses the same hash
at`0x1000C8D0`. ItemMinIcon has conflicting duplicate sections; choosing the first
or doing a case-insensitive INI lookup would select wrong bytes.

The parser scans each frame path with `%s`, so trailing spaces are not part of
the path. Declared frame count is signed `%64`; count64 becomes0. The inventory
records parsed counts, offsets, all collision/duplicate records and winners,
and executes the original hash routine for every parsed title. WDF UIDs use the
original `TqPackageWdf.dll 0x100099D0` instructions. WDB descriptors are also
cross-checked with original GraphicData.dll crypt/decrypt instructions.

`AniCreateFromIndexInfo` (`graphic.dll 0x1000BC80`) eagerly creates **all** parsed
frames for a requested section. A failed frame load cleans up and fails the ANI.
Frame1/2 bytes can therefore be eager dependencies of an action/dance/swap icon
even though Show draws only frame0. This does not mean all sections in the
45,000-plus item lookup catalog load simultaneously or are server-reachable.
Repeated frame paths introduce repeated native frame objects, not different
content bytes. The machine-readable references distinguish frame indices.

The clean inventory resolves 3,728 paths and records one absent path,
`data/main3/skill38.dds`, referenced by retail Magic sections including1415..1417.
This is a verified missing-content outcome, not a substituted asset. Missing
ordinary ANI skips that local draw and continues; item lookup can try ItemDefault;
missing item ANI skips quantity/plus. Cover/effect remain independently attempted.
No guessed placeholder or new content file has been added.

## 7. Verification and explicit scope

- 197 captured assembly files / 46,934 instruction lines byte-matched to clean
  EXE/DLL images when captured; final `byte-validation.json` is authoritative if
  later supplemental captures increase those counts.
- Original x86 replay: mapper/index cases, poisoned constructor, insertion/
  overwrite/removal, auto-place, geometry, 75 Show cases, 142 input cases and
  100 cooldown cases. Foreign query/draw/font/OS/clock/entity boundaries are
  explicitly mocked in scripts; no render or OS result is claimed from a mock.
- 22 WDB descriptors decrypted by original native instructions and compared to
  the extraction, with exact resource130/control3FD verification.
- Function names/comments are reversible and guard against overwriting subsequent
  analyst edits. No executable patches, managed production changes, commits or
  pushes belong to this slice.

This closes the documented client-owned grid ABI, state, draw-stream and input-
dispatch contract without assigning meanings from filenames. The artifact does
not claim exhaustive symbolic reachability through every possible pointer alias,
OS delivery semantics, arbitrary server content-ID reachability, or pixel parity
of an implementation that has not yet been written. Those are separate proof
claims; their absence must not be reported as 100% end-to-end verification.
