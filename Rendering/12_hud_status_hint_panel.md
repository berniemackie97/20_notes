# `Conquer.exe` — HUD status hint panel

`CMyShellDlg__RenderStatusHintPanel` (`0x5B9C3F`) draws the HUD hover-hint: a `Control.ani`
`Dialog21` backdrop stretched to the measured text size, plus the hint string. It is the first
text-bearing UI surface reconstructed, and it exercises the whole text substrate — configuration,
measurement, the `#NN` data-icon escape, and the mode-9 draw path.

All addresses are from `00_clean/clean/5517-bninja/Conquer.exe.bndb`.

## Prerequisites

`Load_FontSetting_Ini()` must return a `CFontSettingInfo`; a null result logs `CHECK` /
`pFontSetInfo` against `MyShellDlg.cpp:0x1842` and the panel is skipped. Text uses that record's
`guiFontFaceName` (`+0x10D`), `antialiasEnabled` (`+0x08`), `defaultRenderTextStyle` (`+0x04`),
`defaultCornerColorArgb` (`+0x214`) and `defaultCornerOffsetX` (`+0x218`), with the pixel height
from `ClientFontSizeSettings_GetNormalHeightPixels`.

A null `Dialog21` resource pointer skips the entire panel.

## State fields on `CMyShellDlg`

| Offset | Meaning |
|---|---|
| `+0x17969C` | anchor X |
| `+0x1796A0` | anchor Y |
| `+0x1796A4` | per-slot X array, stride 8, indexed by the sub-kind byte |
| `+0x1796A8` | per-slot Y array, stride 8 |
| `+0x1796EC` | category selector |
| `+0x1796F0` | category parameter |
| `+0x1796F4` | sub-kind byte |

## Category 8 — button hints

Dispatch at `0x5BA70A`:

```
movzx eax, byte [ebx+0x1796F4]   ; sub-kind
dec   eax
cmp   eax, 0x7
ja    0x5BAB6C                   ; UNSIGNED -> jumps to the function end
jmp   dword [eax*4+0x5BAB7B]     ; 8-entry jump table
```

The comparison is **unsigned**, so sub-kind `0` wraps to `0xFFFFFFFF` on the `dec` and fails the
bound, rendering nothing. Valid sub-kinds are exactly `1`–`8`:

| Sub-kind | Source | Clean-client text |
|---:|---|---|
| 1 | string `0x2756` | `Walk/Run` |
| 2 | string `0x2757` | `Chat On/Off` |
| 3 | string `0x2758` | `Map On/Off` |
| 4 | `CMyCheck_GetStateFrameByte(this+0x140864)` non-zero → `0x275A`, else `0x2759` | `Shift Screen: On` / `Off` |
| 5 | string `0x2882` | `View Equipment` |
| 6 | **Skill gauge (`Progress42`)** | `"%d/%d"` |
| 7 | MP gauge | `"%d/%d"` |
| 8 | HP gauge | `"%d/%d"` |

The gauge cases call `CMyProgress_GetValueRange` on the `CMyProgress` instances at
`this+0x140528`, `this+0x1405B0` and `this+0x140638` (stride `0x88`). They **discard the range
minimum**, take the live value from `CHero` — `CHero+0x510` for sub-kind 6,
`CHero_GetCurrentMana` for 7, `CHero_GetPlayerDataByIndex(hero, 1)` for 8 — clamp it down
to the range maximum, and format `"%d/%d"` as (clamped value, maximum) through `_snprintf` with a
`0xFF` limit into a `0x200`-byte stack buffer. String cases `strncpy` the table text into that
same buffer.

**Corrected 2026-09-22:** sub-kind6 is the **Skill gauge (`Progress42`)**. The earlier XP
label was inferred from `ProgressXp.rgn` and is withdrawn. That file supplies hotspot geometry;
the actual object binding, value and clean ANI comment establish the gauge identity. The earlier
HP label was also wrong. Sub-kinds7/8 remain MP/HP.

Text colour for these hints is `0xFFFFFFFF`.

## Sub-kind 6 semantic proof

Independently recaptured from the native Binary Ninja view on2026-09-21/22. Existing analyst
comments and function names were treated as leads, not as independent proof. Complete HLIL,
MLIL-SSA, raw instructions, xrefs and data bytes are retained in
[the targeted evidence directory](../../10_work/docs/evidence/status-hint-skill-5517/).

### Embedded object and control binding

`CMyShellDlg_ConstructAndInitializeMembers` starts at `0x5ADAB7`. Native instructions preserve
shell `this` in ESI at `0x5ADAC7`, then construct the HUD inline:

```asm
005ADB11  lea  ecx, [esi+0xF98]
005ADB1B  call 0x4B5468                 ; CDlgMain constructor
```

The old note cited `0x5ADB10` as the LEA; that address actually pushes the null parent argument.
The constructor at `0x4B5468` passes dialog resource `0x82` at `0x4B5487`, constructs a
progress widget at its `+0x13F590` through `0x4B5E5D`/`0x4B5E67`, and installs its primary
vtable at `0x4B5F73`. The initializer is the vtable entry at `0x855E84`.
Native xrefs identify the shell constructor call at `0x5ADB1B`.

DDX binding is an independent control identity check:

```asm
004BB71A  lea  eax, [esi+0x13F590]
004BB720  push eax
004BB721  push 0x3FA
004BB726  push edi                     ; CDataExchange*
004BB727  call DDX_Control
```

`CDlgMain_InitializeMainHudWidgets` starts at **`0x4BB869`**; `0x4BB873` is its body after
the exception prolog. It pushes the string `Progress42` (`0x92BE0C`) at `0x4BB970`, sets
ECX to `dlg+0x13F590` at `0x4BB978`, and calls `CMyProgress_Init` at `0x4BB981`.
The fresh HLIL and raw push order agree:

```c
// Native call at 0x4BB981, normalized parameter names:
CMyProgress_Init(dlg + 0x13F590, rect.left, rect.top,
                 "Progress42", 0, 100, 0, 0, 0, 0);
```

The object-offset arithmetic is exact:

```text
shell + 0xF98                         = embedded CDlgMain
shell + 0xF98 + 0x13F590 = +0x140528  = Progress42, control0x3FA
shell + 0xF98 + 0x13F508 = +0x1404A0  = separate Progress44, control0x3FB
```

The latter DDX binding is at `0x4BB708`/`0x4BB70F`/`0x4BB715`. It is not the object read
by sub-kind6. Slot6 placement separately obtains `GetWindowRect(shell+0x140548 HWND)` at
`0x5B9939`/`0x5B993F`, then writes slot6 X/Y at `0x5B994F`/`0x5B9955`.
`0x140548 = 0x140528 + 0x20`, the progress widget's CWnd handle member.

### Dispatch, live value and exact formatting

Category selection subtracts5 at `0x5B9C8D`, then3 at `0x5B9C96`; the equality branch at
`0x5B9C99` therefore selects category8. Sub-kind dispatch subtracts1 and bounds it to0..7
at `0x5BA711`–`0x5BA715`. Table slot `0x5BAB7B + 5*4 = 0x5BAB8F` contains
`0x5BA7B0`, proving sub-kind6 enters this block:

```asm
005BA7B3  lea  ecx, [ebx+0x140528]     ; shell this retained at0x5B9C52
005BA7B9  push eax                     ; &maximum = EBP-0x24
005BA7BA  lea  eax, [ebp-0x10]
005BA7BD  push eax                     ; &minimum
005BA7BE  call 0x5A9A48                ; CMyProgress_GetValueRange
005BA7C3  call 0x404460                ; CHero singleton
005BA7C8  mov  eax, [eax+0x510]         ; live value, no XP/qword conversion
005BA7CE  jmp  0x5BA81F
005BA81F  cmp  eax, [ebp-0x24]
005BA822  mov  [ebp-0x10], eax         ; discards the returned minimum
005BA825  jle  0x5BA82A                ; SIGNED comparison
005BA827  mov  eax, [ebp-0x24]         ; upper clamp only
005BA82A  push dword [ebp-0x24]        ; maximum
005BA82D  push eax                     ; selected live value
005BA82E  push 0x92359C                ; "%d/%d"
005BA83F  call [_snprintf]
```

`CMyProgress_GetValueRange` starts at **`0x5A9A48`**, reads widget`+0x7C`/`+0x80` at
`0x5A9A4C`/`0x5A9A51`, and writes the two output pointers at `0x5A9A4F`/`0x5A9A5B`.
Its three native call xrefs are exactly the three gauge branches in this renderer.
The hero receiver is independently identified by singleton `0x404460`: native RTTI at
`0x9217B0` is `.?AVCHero@@`, and its return loads global `0x955F8C` at `0x4044F3`.

Equivalent hint logic is `snprintf(buffer, 255, "%d/%d", min_signed(live, maximum), maximum)`.
The native code then explicitly writes `buffer[255] = 0` at `0x5BA848`.
There is no lower clamp, percentage conversion, rounding or character-experience scaling in
this branch. With the verified widget range it displays `value/100` for normal values0..100.
Do not replace the signed comparison with unsigned saturation when reproducing exact behavior.

### Every relevant range call in this chain

| Phase | Native calls and effect |
|---|---|
| Initial range | `0x4BB981` passes0/100 to Init (`0x5A9784`), which calls SetValueRange at `0x5A985F`. |
| Storage setter | `CMyProgress_SetValueRange` (`0x5A9A34`) writes minimum at `0x5A9A38` to `+0x7C`, maximum at `0x5A9A3F` to `+0x80`. Native xrefs are Init and ResetValueRange only. |
| Per-frame range | HUD renderer starts at `0x4BC1F8` and calls `CDlgMain_UpdateGaugeRangesFromHero` at `0x4BC20A`, before draws. Call `0x4BD664` obtains100 from `0x65D256`; EBP is zero from `0x4BD557`; `0x4BD66B` selects `dlg+0x13F590`; reset call `0x4BD671` sets0/100. |
| Maximum helper | `0x65D256`: bytes `6A 64 58 C3`, i.e. PUSH100 / POP EAX / RET. Four bytes, not three; sole native call xref `0x4BD664`. |
| Range reset | `CMyProgress_ResetValueRange` starts at **`0x5A9999`**, forwards the two bounds to SetValueRange at `0x5A99BB`, then recomputes fill geometry. `0x5A99AB` is an internal GetWindowRect call, not its entry. |
| Hint read | `0x5BA7BE` reads both bounds; only maximum survives into formatting. |

The distinct experience path calls the next-level requirement getter at `0x4BD682`, scales
it at `0x4BD68B`, and resets `dlg+0x13F508` at `0x4BD698`. The draw path likewise reads
hero`+0x510` at `0x4BC766`/`0x4BC771` for Progress42's Show call `0x4BC78E`, while
Progress44 reads the experience qword `+0x860/+0x864` and calls Show at `0x4BC7F7`.
A shell command at `0x5C3A64`/`0x5C3A6A` also addresses `shell+0x140528`, but changes
only its sub-variant; it is not another range setter.

### Region load order and command payload

| Region index | Literal / push | Region object stored | Posted category/sub-kind |
|---:|---|---|---|
| 0 | `Ini/ProgressXp.rgn`, `0x92BD20` / `0x4BBDB4` | `dlg+0x174` at `0x4BBE14` | 8 / 6, Skill / Progress42 |
| 1 | `Ini/ProgressMp.rgn`, `0x92BD0C` / `0x4BBE25` | `dlg+0x178` at `0x4BBE7F` | 8 / 7, MP / Progress41 |
| 2 | `Ini/ProgressHp.rgn`, `0x92BCF8` / `0x4BBE90` | `dlg+0x17C` at `0x4BBEEA` | 8 / 8, HP / Progress40 |

The CFile open calls are `0x4BBDBC`, `0x4BBE2D`, `0x4BBE98`; the ExtCreateRegion calls
are `0x4BBE09`, `0x4BBE74`, `0x4BBEDF`. The files are passed to the same geometry-loader
sequence; no XP-stat lookup occurs there.

The native MFC message-map entry at `0x855CD8` contains message `0x200` and handler pointer
`0x4BD438` at `0x855CEC`. Its region loop starts at `dlg+0x174` (`0x4BD4A1`), strides4
and stops at3 (`0x4BD4C1`/`0x4BD4C4`). On hit:

```asm
004BD4CD  add  al, 6
004BD4CF  add  ebx, 6
004BD4D2  push ebx                     ; payload = regionIndex+6
004BD4D3  mov  [esi+0x180], al
004BD4D9  push 8                       ; command code
004BD4DB  jmp  0x4BD529
004BD529  call 0x64D015
```

Helper `0x64D015` posts Windows message `0x464` at `0x64D02C`, with code as wParam and
payload as lParam when the main-window handle is nonzero. Dispatcher table slot
`0x5B80FC + 8*4 = 0x5B811C` points to `0x5B2DE9`; stores at `0x5B2DEF` and
`0x5B2E01` set category8 and the payload's low byte as sub-kind. There is no remapping of6
to another gauge. Existing rect-hit fallthrough and hover-exit behavior remain as documented below.

### Independent native semantic evidence and boundary

Init resolves its supplied section in **`ani/Control.ani`** through the dataset vtable call
at `0x5A98DF`; it pushes that file literal at `0x5A98DA` and the caller's section at
`0x5A98D7`. The clean file, decoded as GB18030/CP936, contains:

```ini
// 技能槽(Dialog4)
[Progress42]
FrameAmount=3
Frame0=data/main/ProgressPower.dds
Frame1=data/main/ProgressPower.dds
Frame2=data/main/ProgressPowerH.dds
```

The comment is at line1416, section at1417. **技能槽 means skill gauge/slot.** This is a
clean retail asset label tied to the actual native control lookup, independent of the hotspot
filename or an analyst's function name. Its SHA256 is
`a1db47baaeb2f75eea3b5216378f97d713c2afeaefe05ec02e6f584794532d27`.

The independent packet/UI update chain agrees: packet10017 discriminator27 branches directly
at `0x757476`/`0x75747F` to `0x757C0A` (not through the0..26 table), clamps its low
DWORD **unsigned** to100 at `0x757C0D`/`0x757C10`, writes role`+0x510` at `0x757C1F`,
and posts command `0x40F` through `0x7585F3`. The shell dispatch independently checks
message `0x464` at `0x5BB957`, loads wParam at `0x5BB964`, subtracts `0x40F` at
`0x5BBB9E`, maps index0 through byte `0x5CDA5B = 0`, then jumps through
`0x5CD9DF = 0x5C3CC0` at `0x5BBBC3`. The shell branch at `0x5C3CC0` reads the
local hero field, checks it below100 unsigned at `0x5C3CD1`/`0x5C3CD8`, and calls
`CDlgMain_ArmSkillGaugeHighlight` at `0x5C3CE6` with `shell+0xF98`.
That helper clears `dlg+0x19C` and sets `dlg+0x198` at `0x4BE215`/`0x4BE21C`.
This establishes an update/highlight path for the same value; the command number alone does
not supply an English gameplay name.

**Conclusion:** change sub-kind6 from XP to **Skill (`Progress42`)**. `ProgressXp.rgn` is the
geometry asset used by that hotspot. There is no remaining ambiguity in the control, value,
range, category/sub-kind or separation from character-experience Progress44. These checks do
not establish the server's gauge-accrual formula, whether the mechanic is colloquially called
an "XP skill" gauge, or why the old geometry filename contains Xp; no such claim is needed
for this UI contract. Existing names `CHero_GetSkillGaugeMaximum` and
`CDlgMain_ArmSkillGaugeHighlight` are appropriate; `0x5A8F86` is now named
`CMyProgress_Constructor`. No production code changed.

## Measurement

`CMyBitmap::CalcuTextExtentCommon(text, faceName, height, dataIcon, 0x15)` where `dataIcon` is
`GameDataSetQuery()->vtable+0x5C(0)`. The `CMySize` result comes back in `eax:edx`, so **`eax` is
the width and `edx` the height** (`0x5BA8A7`). Because a real `IDataIcon` is supplied, `#NN`
escapes inside hint text are measured as emotion icons — see
[`graphic_dll/04_fonts_and_text.md`](graphic_dll/04_fonts_and_text.md) and
[`graphicdata_dll/02_igamedataset_vtable.md`](graphicdata_dll/02_igamedataset_vtable.md).

## Placement

Verified instruction by instruction across `0x5BA8A4`–`0x5BAAA5`. `g_uiLayoutModeFlag`
(`0x0096AB30`) selects between two modes:

**`flag == 0`** (`0x5BAA14`) — backdrop and text are both drawn at `(slotX, slotY)`.

**`flag != 0`** (`0x5BA8BF`) — with `fits = (slotX + measuredWidth) <= GetScreenWidth()`:

```
backdropX = fits ? slotX : GetScreenWidth() - measuredWidth
textX     = backdropX + measuredWidth
textY     = backdropY = slotY
```

Both sub-paths reduce to the same rule, so this mode anchors the text to the backdrop's right
edge and pulls an overflowing hint back by its own width. The two paths look like unrelated
formulas if only one is read.

## Backdrop draw

`GameDataSetQuery()->vtable+0x10("ani/Control.ani", "Dialog21", 1, 0x7530)`, then that resource's
vtable `+0x0C` (`CAniX_DrawFrameSubRectAt`) with:

```
(frame 0, X, Y, &RECT{0, 0, 0x64, 0xC8}, measuredWidth, measuredHeight, 0, 0)
```

A 100x200 source region stretched to the measured text extent. Slot semantics are recorded in
[`07_ani_frame_animation_runtime.md`](07_ani_frame_animation_runtime.md).

## Category 5 — avatar prompt

Requires `+0x1796F0 == 0x16` and draws **no backdrop**. String `0x2754` is drawn at
`(+0x17969C, +0x1796A0 + 0x14)` and string `0x2755` at `(+0x17969C, +0x1796A0 + 0x26)`, both in
colour `0xFFFFFF00`.

## Who sets the hint state

Established by scanning `.text` for the field displacements `0x1796EC`, `0x1796F0` and
`0x1796F4` and resolving every hit, so this list is complete for the image:

- `CMyShellDlg_ConstructAndInitializeMembers` initialises the category field;
- `CMyShellDlg__RenderStatusHintPanel` reads them;
- **`CMyShellDlg_DispatchCommandCode` is the only writer.**

The native C++ hover handlers drive the panel through **command codes carrying packed parameters**. Verified write sites, with `param` = `[ebp+0x0C]`:

| Site | Effect |
|---|---|
| `0x5B2D61` | `anchorX = (int)(short)param`, clamped to `0` when negative; `anchorY = (param >> 16) + 0x2A` (unsigned shift) |
| `0x5B2D88` | `visible = 1`, `category = 5`, `parameter = param` |
| `0x5B2DB6` | `visible = 1`, `category = 0x6A`, `parameter = param` |
| `0x5B2DE9` | `category = 8`, `visible = 1`, `subKind = (byte)param`; when `param == 0` it also falls through to `CGameMap_GetSingletonPtr` |
| `0x5B2E31` | `category = 9`, then joins the shared `parameter = param` store |
| `0x5B3BEC` | `visible = 1`, `parameter = param`, `category = 0x38` |
| `0x5B2DCC` | clear: `+0x179694 = 0` and `+0x179698 = 0`, only when `+0x1797CC == 0` |

`+0x179694` is a **hint-visible flag** written by every category and cleared by the clear path.
The render routine never reads it; the gate lives in the caller and is now verified at
`CMyShellDlg_RunFrameTick` `0x5DD337`-`0x5DD36A`. The panel is drawn only when **both** hold:

1. `CSkillDragVisual_GetActiveFlag()` is false. When it is true the frame calls
   `CSkillDragVisual_TickCursorTracking` (`0x5DD349`) and jumps past the panel, so dragging a
   skill suppresses the hint.
2. `+0x179694 != 0`.

The active-flag query appears twice in that stretch — once to route the drag tick and once again
immediately before the gate — so a reader who only sees the second occurrence would miss the
suppression behaviour.

Category `0x6A` (106) is set by the dispatcher but no handler for it was observed in the render
routine. Unresolved.

### Separate mechanism: per-control tooltips

`CMyButton_TickAndRender` (when `cursorInside` is set and the tooltip glyph-run vector is
non-empty) and `CMyCheck_ShowTip` both render their own multi-line tooltip through `sub_592d78`,
measuring each line with `CalcuTextExtentCommon`. Neither touches the hint fields. Do not conflate
the two systems.

### The trigger is native, not Flash

An earlier revision of this note assumed the hint commands came from the Flash-backed UI layer.
**That was wrong and is superseded.** The trigger chain is entirely native C++:

```
native control hover handler
  -> Conquer_PostMainWindowMessage464(code, param)      (0x64D015)
     = PostMessageA(mainWindow, 0x464, code, param)
  -> CMyShellDlg_DispatchCommandCode                    (0x5B29E2)
     jump table at 0x5B80FC indexed by the command code (0..0x6B)
  -> hint state fields
  -> CMyShellDlg_RunFrameTick gate
  -> CMyShellDlg__RenderStatusHintPanel
```

Message `0x464` is the client's general internal command bus: 1,562 call sites across 868
functions, including network packet handlers. The hint codes are one small region of it.

Command codes, resolved from the jump table. The code **equals the category** in every
category-setting case:

| Code | Effect |
|---:|---|
| `5` | category 5, parameter = payload |
| `6` | clear the hint (`visible = 0`) |
| `7` | set anchor: `X = (short)payload`, `Y = (payload >> 16) + 0x2A` |
| `8` | category 8, `subKind = (byte)payload` |
| `9` | `visible = 1`, category 9 |
| `0x38` | category 0x38 |
| `0x6A` | category 0x6A |

#### Confirmed producer: `CMyGrid` hover (`sub_5A1226`)

A `CMyGrid` mouse-move handler — it calls `PtInRect`, `CMyGrid_GetZeroBasedSlotIndex` and
`CMyGrid_GetSlotOccupiedFlag`, and ends in `CWnd::Default`. Over an occupied slot it packs the
slot's screen position as `(y << 16) | x`, posts code `7` with it, then dispatches on the slot's
content-kind byte at `this + slotIndex + 0xAB8`:

| Content kind | Posts |
|---:|---|
| 3 or 4 | code `9` with `*(this+0x74)` |
| 5 | code `0x38` with `*(this+0x48)` |
| 6 | code `0x6A` with `0x5E` |
| 1 (and `*(this+0x48) != 0x37`) | code `5` with `*(this+0x48)` |

When `PtInRect` fails it posts code `6` with `0`, clearing the hint. Hover-in raises the hint and
hover-out clears it, all in native code.

#### Confirmed producer: `CDlgMain` hover (`CDlgMain_OnMouseMoveUpdateStatusHintHotspot`, `0x4BD438`)

This is the producer of the **category 8** hints. Class identity is proven from the MFC message
map, not from address proximity: the entry at `0x855CD8` carries `nMessage = 0x200`
(`WM_MOUSEMOVE`) with this handler, and neighbouring entries in the same map are `WM_COMMAND`
handlers for control ids `0x3F7`, `0x3FF` and `0x3FE`, all of which appear in
`CDlgMain_BindMainHudWidgetControls`.

Hotspot storage on `CDlgMain`:

| Offset | Meaning |
|---|---|
| `+0x114` | six `RECT` hotspots, stride `0x10`, hit-tested with `PtInRect` |
| `+0x174` | three HRGN-bearing objects, hit-tested with `PtInRegion` on `*(obj+4)` |
| `+0x180` | index of the currently hovered hotspot, `0xFF` = none |

When `g_uiLayoutModeFlag` is non-zero the X used for the **region** tests becomes
`GetScreenWidth() - x`; the rect tests always use the raw x.

- Nothing hovered (`+0x180 == 0xFF`): scan the six rects in order; the first hit stores `i` and
  posts `(8, i)` at `0x4BD498`. **That hit block then falls through into the region loop at
  `0x4BD49F` — there is no early-out**; the no-hit path at `0x4BD48D` jumps to the same place. A
  point inside both a rect and a region therefore posts **twice**, and the region overwrites
  `+0x180`. The region loop null-checks each slot (`0x4BD4A9`) and on a hit stores `index + 6`
  and posts `(8, index + 6)`.
- Already hovering: re-test only that hotspot — `PtInRect` below 6, `PtInRegion` for 6..8. An
  index outside both ranges falls straight through to `CWnd::Default` via `0x4BD500` (`js`) or
  `0x4BD505` (`jge`) and **clears nothing**. The region slot is dereferenced here *without* a
  null guard, unlike the enter path. When the cursor has left, `0x4BD51F` does
  `or byte [esi+0x180], 0xFF` (equivalent to storing `0xFF`) and posts `(6, 0)`.

Coordinates: `[ebp+0x0C]` is x, `[ebp+0x10]` is y. Both `PtInRect` sites push the **raw** x; only
the `PtInRegion` sites use the mirrored value.

So **the hotspot index is the hint sub-kind**. Indices 6–8 are regions rather than rects, which
lines up with the three gauge sub-kinds being the non-rectangular HP/MP orbs; sub-kinds 1–5 come
from rects 1–5.

Rect index 0 posts sub-kind 0, which renders nothing — see the dispatch bound below. That is
deliberate, not an omission.

#### Hotspot geometry: `CDlgMain_InitializeMainHudWidgets` (`0x4BB869`)

The hotspot arrays are built during HUD initialisation, not from static data.

**Rects (`+0x114`, six entries of `0x10`)** are `GetWindowRect(control)` converted to
dialog-client coordinates by subtracting the dialog's own `GetWindowRect`. `CWnd::m_hWnd` lives at
`+0x20`, so each source address identifies its bound control:

| Rect | Source | Control | Ctrl id | Sub-kind |
|---:|---|---|---|---|
| 0 | `*(this+0x13F528)` | `+0x13F508` | `0x3FB` | 0 — renders nothing |
| 1 | `*(this+0x13F860)` | `+0x13F840` | `0x3F4` | 1 Walk/Run |
| 2 | **explicitly zeroed** (`0x4BBCD2`) | — | — | 2 Chat On/Off — unreachable here |
| 3 | `*(this+0x13F7D4)` | `+0x13F7B4` | `0x3F7` | 3 Map On/Off |
| 4 | `*(this+0x13F8EC)` | `+0x13F8CC` | `0x3FF` | 4 Shift Screen |
| 5 | `*(this+0x13F978)` | `+0x13F958` | `0x3F8` | 5 View Equipment |

Rect 0 alone is padded vertically: `top - 2` and `bottom + 2`. Rect 2 is zeroed, so `PtInRect`
can never succeed on it and sub-kind 2 cannot be raised by this producer.

**Regions (`+0x174`, three pointers)** are loaded from files, in this order:

| Slot | File | Hotspot index | Sub-kind |
|---|---|---:|---:|
| `+0x174` | `Ini/ProgressXp.rgn` | 6 | **Skill / Progress42** |
| `+0x178` | `Ini/ProgressMp.rgn` | 7 | MP |
| `+0x17C` | `Ini/ProgressHp.rgn` | 8 | HP |

Each is `CFile::Open` → `CFile::Read` of a 4-byte byte count → `operator new` → `CFile::Read` of
the `RGNDATA` payload → `ExtCreateRegion` → `CGdiObject::FromHandle`. A failed open leaves the
slot null, which the enter path tolerates and the re-test path does not.

##### `.rgn` file format, confirmed against the shipped files

The payload is a Win32 `RGNDATA`: a 32-byte `RGNDATAHEADER` followed by `nCount` `RECT`s.

| Field | Offset in payload | Value in all three files |
|---|---:|---|
| `dwSize` | `0` | `32` |
| `iType` | `4` | `1` (`RDH_RECTANGLES`) |
| `nCount` | `8` | rectangle count |
| `nRgnSize` | `12` | `nCount * 16` |
| `rcBound` | `16` | union of the rectangles |

| File | Size | Leading count | Rects | `rcBound` |
|---|---:|---:|---:|---|
| `ProgressHp.rgn` | 724 | 720 | 43 | `(10,58)-(47,132)` |
| `ProgressMp.rgn` | 724 | 720 | 43 | `(47,58)-(84,132)` |
| `ProgressXp.rgn` | 1988 | 1984 | 122 | `(0,49)-(92,141)` |

The leading count equals `filesize - 4` in every file, and `rcBound` exactly equals the union of
the rectangles — a self-check that the layout is being read correctly. The coordinates live in the
`0xA3`-tall HUD shell space, not the 400x70 dialog template space. The HP and MP regions are
disjoint, verified by scanning every point in `(0..100, 40..150)`.

**This ordering proves the region-to-sub-kind mapping, not the gauge semantics.**
The first filename contains Xp, but its sub-kind6 reads Progress42/Skill. All three files ship
in the clean client under `ini/`; the native object/section binding below settles the identity.

#### Heuristic candidate list, and one confirmed false positive

The producer sites were first located by scanning `.text` for calls to
`Conquer_PostMainWindowMessage464` and taking the last `push imm8` before each call. That
heuristic misses codes passed in registers or as `push imm32`, and misattributes when the last
push is the payload rather than the code.

`sub_46B620` (`0x46B627`) was such a false positive: it is actually
`PostMainWindowMessage464(0xC5C, 8)`, where `8` is the payload. Treat any site below that has not
been decompiled as a candidate only.

| Code | Candidate sites |
|---:|---|
| `5` | `0x46B5FA`, `0x4E95F7`, `0x55A8FD`, `0x5A140E`†, `0x5BCC07`, `0x5DD584` |
| `6` | `0x436305`, `0x442F72`, `0x44302E`, `0x46B618`, `0x4BD529`†, `0x4E9667`, `0x574E53`, `0x5A1537`†, `0x5A1592`, `0x5A2E31`, `0x5A37E4` |
| `7` | `0x442F48`, `0x46B609`, `0x4E969F`, `0x5A1345`†, `0x5A1404`†, `0x5A141E`†, `0x5A14B2`†, `0x5A3784`, `0x5A37A9` |
| `8` | `0x46B627` (FALSE POSITIVE), `0x4BD498`†, `0x4E964B` |
| `9` | `0x46B636`, `0x597779`, `0x5A37B6` |
| `0x38` | `0x442F52` |
| `0x6A` | `0x5A14BB`† |

† confirmed by decompilation.

### Consequence for the reconstruction

Because the whole chain is native, the managed client can reproduce it exactly rather than
designing a replacement: control hover handlers post the verified codes onto an internal command
bus, a dispatcher writes the hint state, the frame gate applies the skill-drag and visible-flag
checks, and the existing planner turns that state into a draw plan.

## Per-slot position arrays

`CMyShellDlg__RenderStatusHintPanel` places category 8 from the per-slot arrays at `+0x1796A4`
(X) and `+0x1796A8` (Y), stride 8, indexed by the raw sub-kind byte. Their writers were found by
scanning `.text` for every displacement in `0x1796A4`..`0x1796E8`: exactly two functions write
them, `CMyShellDlg_InitializeShellRegionAndHintSlots` (`0x5B91D8`) and `sub_5DB954`, and both
perform the same nine stores.

Each slot is `GetWindowRect(child)` converted to dialog-relative by subtracting
`GetWindowRect(*(this+0x20))`, with the **Y always reduced by a further `0x14`**:

| Slot | Child HWND at | Slot X | Slot Y |
|---:|---|---|---|
| 0 | `+0x1404C0` | `+0x1796A4` | `+0x1796A8` |
| 1 | `+0x1407F8` | `+0x1796AC` | `+0x1796B0` |
| 2 | `+0x1406E0` | `+0x1796B4` | `+0x1796B8` |
| 3 | `+0x14076C` | `+0x1796BC` | `+0x1796C0` |
| 4 | `+0x140884` | `+0x1796C4` | `+0x1796C8` |
| 5 | `+0x140910` | `+0x1796CC` | `+0x1796D0` |
| 6 | `+0x140548` | `+0x1796D4` | `+0x1796D8` |
| 7 | `+0x1405D0` | `+0x1796DC` | `+0x1796E0` |
| 8 | `+0x140658` | `+0x1796E4` | `+0x1796E8` |

Nine slots, matching sub-kinds `0`–`8`.

**Independent cross-check.** `CWnd::m_hWnd` is at `+0x20`, so slots 6, 7 and 8 are the windows of
the `CMyProgress` instances at `this+0x140528`, `this+0x1405B0` and `this+0x140638` — exactly the
three the render routine reads through `CMyProgress_GetValueRange` for the gauge sub-kinds. The
slot ordering and the gauge ordering therefore agree without either being assumed from the other.

**How far the `-0x20` rule is actually verified.** It is corroborated for four slots only:

| Slot | Implied control | Corroboration |
|---:|---|---|
| 4 | `+0x140864` | the `CMyCheck` the render routine reads for the Shift Screen sub-kind |
| 6 | `+0x140528` | `CMyProgress`, read by the render routine |
| 7 | `+0x1405B0` | `CMyProgress`, read by the render routine |
| 8 | `+0x140638` | `CMyProgress`, read by the render routine |

Scanning `.text` for the implied bases of the remaining slots returns **zero** references for
`+0x1404A0` (slot 0), `+0x1406C0` (slot 2) and `+0x14074C` (slot 3). For those, only the HWND
member offset is established; the owning control class is **not**. Do not assume the `-0x20`
relationship for them without tracing each one.

The producer offsets are relative to embedded `CDlgMain`; the placement offsets are relative
to `CMyShellDlg`. For gauge slots6–8 these resolve to the **same controls** after adding
`+0xF98`. Hit-test region geometry and hint-placement coordinates still serve different purposes
and must not be substituted for each other.

## Not yet enumerated

Categories 9 and 56 (weapon-swap tip via `CStringManager` keys `STR_SWAP_MAJOR_WEAPONTIP` /
`STR_SWAP_SUB_WEAPONTIP`, selected by `sub_6da8b2(CHero)`) and the `STR_WRAPSHOP_TRY_TIP` branch
carry their own placement arithmetic which has **not** been walked instruction by instruction.
Do not assume they follow the category 8 rule.

## Managed renderer

`CMyShellDlgStatusHintPanelRendererRuntime` turns a plan into draw calls, closing the path from
hint state to pixels. Before it existed, `TryBuildPlan` was reachable only from tests.

Two prerequisites make native abandon the **entire** panel rather than draw part of it, and both
are reproduced:

1. a null `Dialog21` resource — checked before anything else, so it suppresses the text too, even
   for category 5 which draws no backdrop;
2. a null `CFontSettingInfo` record.

Native treats both as ordinary frame-skip conditions, so the managed renderer reports them through
its result rather than throwing.

The backdrop is one `CAniX_DrawFrameSubRectAt` with the constant source region `{0, 0, 0x64, 0xC8}`
stretched to the plan's measured extent. Text draws take their colour from the plan and every other
parameter — face, pixel height, antialias, style, corner colour and corner offsets — from the shared
font-setting record, which is the same `CFontSettingInfo` the floating-text path already reads.
