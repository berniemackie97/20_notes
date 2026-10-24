# `Conquer.exe` — HUD status hint panel

`CMyShellDlg__RenderStatusHintPanel` (`0x5B9C3F`) draws the HUD hover-hint: a `Control.ani`
`Dialog21` backdrop stretched to the measured text size, plus the hint string. It is the first
text-bearing UI surface reconstructed, and it exercises the whole text substrate — configuration,
measurement, the `#NN` data-icon escape, and the mode-9 draw path.

All EXE addresses refer to the clean 5517 image analyzed in
`00_clean/clean/5517-bninja/Conquer.exe.bndb`.

**GFX-UI-008 closure, 2026-10-08:** category 8 only. The maintained native findings below
supersede the old `0xA3` coordinate-space claim and the old unknown slot-owner claims.
[Raw captures, retail identities, censuses and replay](../../10_work/docs/evidence/gfx-ui-008-main-hud-category8-status-hint-5517/README.md)
are retained independently of analyst names. This slice changes annotations/documentation only;
it makes no claim that a managed implementation has been updated or audited.

## Prerequisites

`Load_FontSetting_Ini()` must return a `CFontSettingInfo`; a null result logs `CHECK` /
`pFontSetInfo` against `MyShellDlg.cpp:0x1842` and the panel is skipped. Text uses that record's
`guiFontFaceName` (`+0x10D`), `antialiasEnabled` (`+0x08`), `defaultRenderTextStyle` (`+0x04`),
`defaultCornerColorArgb` (`+0x214`) and `defaultCornerOffsetX` (`+0x218`), with the pixel height
from `ClientFontSizeSettings_GetNormalHeightPixels` for category 8. Category 9's learned-magic helper instead receives fixed height12 at `0x5BA6A9..0x5BA6EE`.

For category 8, the `Dialog21` lookup is at `0x5BA866`, measurement at `0x5BA89B`,
and the null-resource test at `0x5BA8A4` / `0x5BA8AD`. A null resource suppresses both
backdrop and text **after measurement**. It is not the first operation and is not a proven
global prerequisite for the other categories. The font lookup is earlier, at `0x5B9C54`.

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
| 7 | MP gauge, only when `DWORD[shell+0x1098] == 0` | `"%d/%d"` |
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

**MP guard, newly closed:** `0x5BA7D0` compares `DWORD[shell+0x1098]` with zero;
`JNE 0x5BAB6C` at `0x5BA7D7` skips sub-kind 7 completely when nonzero. This is
`CDlgMain+0x100`, initialized to 1 at `0x4BB933`. The per-frame gauge updater
(`0x4BC20A -> 0x4BD53E`) tests signed `min(currentMana, effectiveMaxMana) > 0`
at `0x4BD603..0x4BD60D`, changes the HP startup sub-variant, and clears the flag at
`0x4BD632`. That update precedes the panel in the same frame. Sub-kinds 6 and 8 do
not take this MP guard. This condition was missing from the earlier contract.

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
- **`CMyShellDlg_DispatchCommandCode` is the subsequent command-driven writer of these selection fields.** This historical census does not describe the separate slot-coordinate arrays.

The native C++ hover handlers drive the panel through **command codes carrying packed parameters**. Verified write sites, with `param` = `[ebp+0x0C]`:

| Site | Effect |
|---|---|
| `0x5B2D61` | `anchorX = (int)(short)param`, clamped to `0` when negative; `anchorY = (param >> 16) + 0x2A` (unsigned shift) |
| `0x5B2D88` | `visible = 1`, `category = 5`, `parameter = param` |
| `0x5B2DB6` | `visible = 1`, `category = 0x6A`, `parameter = param` |
| `0x5B2DE9` | `category = 8`, `visible = 1`, `subKind = (byte)param`; when `param == 0` it also falls through to `CGameMap_GetSingletonPtr` |
| `0x5B2E31` | `category = 9`, then joins the shared `parameter = param` store |
| `0x5B3BEC` | `visible = 1`, `parameter = param`, `category = 0x38` |
| `0x5B2DCC` | clear: `+0x179694 = 0` at `0x5B2DD4` and `+0x179698 = 0` at `0x5B2DDA`, **before** the conditional branch at `0x5B2DE0`; `+0x1797CC` does not gate these stores |

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

**GFX-UI-009 correction:** the native subtract/compare dispatch at `0x5B9C87..0x5B9CB8` does handle `0x6A` (106), the weapon-swap string branch. Category `0x38` (56) instead constructs a dance magic for the shared helper. The earlier absence/weapon-swap labels were wrong; unrelated-category details remain outside this slice.

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

#### Confirmed producer: `CMyGrid` hover (`0x5A1226`)

GFX-UI-006 corrects the earlier unconditional-Default and immediate-hover-out
summary. See [the exact grid contract](19_main_hud_quickbar_native_contract.md).
Outside `PtInRect(this+0x5C)`, MouseMove returns without clearing the cache or
calling Default. Show later calls `0x5A1558`, which polls the cursor against the
HWND rectangle and clears outside hover. Moving to an empty slot also clears it.

For a new occupied slot, kind3/4 posts code7 with the packed anchor then9 with
content ID; kind5 posts7 then0x38 with grid context; kind6 posts7 then0x6A with
0x5E. These paths return without Default. Kind2 updates the cached coordinate,
preserves the other hover fields and returns without Default. Kind1 in context
other than0x37 uses the item-tooltip object with the instance UID and then Default;
it does not use the generic code5 pair. Generic remaining kinds/context0x37 post7
then5 and Default. Same cached slot and empty-slot paths normally Default.
The anchor uses cell dimensions without the one-pixel draw stride.

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
maps to Skill / Progress42, MP / Progress41 and HP / Progress40 respectively. Sub-kinds
1, 3, 4 and 5 come from rects 1, 3, 4 and 5; rect 2 is explicitly zero.

Rect index 0 posts sub-kind 0, which renders nothing by the unsigned dispatch bound.
No design intent is inferred from that observed behavior.

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

The leading count equals `filesize - 4` in every file, and `rcBound` exactly equals the union
of its rectangles. HP and MP are disjoint. `regions.json` retains every rectangle.

**Correction: these are direct CDlgMain-client pixel coordinates. The former `0xA3`-tall
HUD-shell-space assertion is withdrawn.** At `0x4BBE09`, `0x4BBE74`, `0x4BBEDF`,
`ExtCreateRegion` receives a null XFORM and the file payload unchanged. No dialog-unit,
font-scale or origin transformation is applied to the region. A null XFORM is the platform's
identity transform ([Microsoft ExtCreateRegion contract](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-extcreateregion)).

`MoveWindow` at `0x5B9242` places the embedded CDlgMain at `(0,H-141,W,141)`.
The inherited `WM_MOVE` handler (`0x596473`) calls Default, then stores draw origin
`+0xF0/+0xF4` at `0x59647F/0x596489`; the static-art renderer consumes that origin.
Dialog130 is borderless (`style 0x40000040`, extended style 0). The shell's extended
dialog102 resource is also borderless (`style 0x50000040`, extended style `0x40000`).
Thus the full logical-frame pointer `(X,Y)` maps to the handler's `(x,y)` as:

| Resolution | CDlgMain/static-art origin | Incoming client point | Region point, flag zero | Region point, flag nonzero |
|---|---|---|---|---|
| 800×600 | `(0,459)` | `(X,Y-459)` | `(X,Y-459)` | `(800-X,Y-459)` |
| 1024×768 | `(0,627)` | `(X,Y-627)` | `(X,Y-627)` | `(1024-X,Y-627)` |

The alternate flag is `DWORD[0x96AB30]` (`g_uiArabicLikeLayoutEnabled`, historically
`g_uiLayoutModeFlag`); the subtraction is **W-x**, not W-1-x. Rectangles always use
unmirrored `(x,y)`. A desktop pointer must first be expressed relative to the shell client
origin; the table starts with a logical-frame pointer, not desktop coordinates.
`WM_MOUSEMOVE` supplies client-relative coordinates ([Microsoft contract](https://learn.microsoft.com/en-us/windows/win32/inputdev/wm-mousemove)).
`CMyCheck` forwards a move to its parent at `0x58B96F`, after adding its cached local
`+0x50/+0x54` origin to the packed point at `0x58B932..0x58B95C`; this is a separate
child-to-parent conversion, not an extra adjustment of the region payload.

PtInRect calls are `0x4BD47A` / `0x4BD4F5`; PtInRegion calls are `0x4BD4B6` /
`0x4BD515`. The zero/active/exit behavior described above uses those same coordinates
at both resolutions. The replay includes region edges, mirroring, overlaps, invalid prior
hotspot indices and the zero rectangle. Its region API is a rectangle-union mock, not a
live GDI execution.

**This ordering proves the region-to-sub-kind mapping, not the gauge semantics.**
The first filename contains Xp, but its sub-kind6 reads Progress42/Skill. All three files ship
in the clean client under `ini/`; the native object/section binding below settles the identity.

#### Historical heuristic candidates and confirmed false positives

The producer sites were first located by scanning `.text` for calls to
`Conquer_PostMainWindowMessage464` and taking the last `push imm8` before each call. That
heuristic misses codes passed in registers or as `push imm32`, and misattributes when the last
push is the payload rather than the code.

`sub_46B620` (`0x46B627`) was such a false positive: it is actually
`PostMainWindowMessage464(0xC5C, 8)`, where `8` is the payload. GFX-UI-008 also proves `0x4E964B` is
`PostMainWindowMessage464(0xDAC, 8)`: raw pushes in `0x4E9641` put 8 in the payload,
not in the command code. It is **not a category-8 producer**. Treat the remaining
unexamined entries as historical candidates only; other categories are outside this slice.

| Code | Candidate sites |
|---:|---|
| `5` | `0x46B5FA`, `0x4E95F7`, `0x55A8FD`, `0x5A140E`†, `0x5BCC07`, `0x5DD584` |
| `6` | `0x436305`, `0x442F72`, `0x44302E`, `0x46B618`, `0x4BD529`†, `0x4E9667`, `0x574E53`, `0x5A1537`†, `0x5A1592`, `0x5A2E31`, `0x5A37E4` |
| `7` | `0x442F48`, `0x46B609`, `0x4E969F`, `0x5A1345`†, `0x5A1404`†, `0x5A141E`†, `0x5A14B2`†, `0x5A3784`, `0x5A37A9` |
| `8` | `0x46B627` (FALSE POSITIVE), `0x4BD498`†, `0x4BD529`† (region branch), `0x4E964B` (FALSE POSITIVE) |
| `9` | `0x46B636`, `0x597779`, `0x5A37B6` |
| `0x38` | `0x442F52` |
| `0x6A` | `0x5A14BB`† |

† confirmed by decompilation.

### Consequence for the reconstruction

Because the whole chain is native, the managed client can reproduce it exactly rather than
designing a replacement: control hover handlers post the verified codes onto an internal command
bus, a dispatcher writes the hint state, the frame gate applies the skill-drag and visible-flag
checks, and the existing planner turns that state into a draw plan.

## Per-slot position arrays — GFX-UI-008 closure

The category-8 renderer indexes `shell+0x1796A4` (X) / `+0x1796A8` (Y), stride 8,
by the raw sub-kind. The direct-displacement census finds **36 scalar stores**: 18 in
`CMyShellDlg_InitializeShellRegionAndHintSlots` (`0x5B91D8`) and 18 in `0x5DB954`, now
analyst-named `CMyShellDlg_RebuildMainHudRegionAndHintSlots_Analyst`. This census covers
explicit `.text` references to the 18 fields; it is not an assertion that absence of a
displacement proves arbitrary aliasing impossible. The two concrete writer bodies close
the observed initialization/relayout dataflow.

The origin being subtracted is the **shell window**, not CDlgMain:

```text
shellRect = GetWindowRect(shell HWND at +0x20)
childRect = GetWindowRect(the slot's child HWND)
slotX = childRect.left - shellRect.left
slotY = childRect.top  - shellRect.top - 20
```

Parent reads are `0x5B984C` and `0x5DBF3A`. These anchors are shell/frame-relative;
the region hit-test coordinates above are CDlgMain-local. They must not be substituted.

| Slot | Bound control / ID | CDlgMain object | Shell object | Shell HWND field | X / Y slot fields |
|---:|---|---|---|---|---|
| 0 | Progress44 / `0x3FB` | `+0x13F508` | `+0x1404A0` | `+0x1404C0` | `+0x1796A4 / +0x1796A8` |
| 1 | Check40 / `0x3F4` | `+0x13F840` | `+0x1407D8` | `+0x1407F8` | `+0x1796AC / +0x1796B0` |
| 2 | hidden chat CMyCheck / `0x3F6` | `+0x13F728` | `+0x1406C0` | `+0x1406E0` | `+0x1796B4 / +0x1796B8` |
| 3 | Check43 / `0x3F7` | `+0x13F7B4` | `+0x14074C` | `+0x14076C` | `+0x1796BC / +0x1796C0` |
| 4 | Check46 / `0x3FF` | `+0x13F8CC` | `+0x140864` | `+0x140884` | `+0x1796C4 / +0x1796C8` |
| 5 | Button411 (CMyCheck) / `0x3F8` | `+0x13F958` | `+0x1408F0` | `+0x140910` | `+0x1796CC / +0x1796D0` |
| 6 | Progress42 / `0x3FA` | `+0x13F590` | `+0x140528` | `+0x140548` | `+0x1796D4 / +0x1796D8` |
| 7 | Progress41 / `0x5DE` | `+0x13F618` | `+0x1405B0` | `+0x1405D0` | `+0x1796DC / +0x1796E0` |
| 8 | Progress40 / `0x5DD` | `+0x13F6A0` | `+0x140638` | `+0x140658` | `+0x1796E4 / +0x1796E8` |

Every shell/main object pair differs by `0xF98`; every HWND is its owning object +`0x20`.
The constructor `0x4B5468`, DDX binder `0x4BB6B8`, initializer `0x4BB869`, resource130
and both slot writers are captured. The old claim that owners of slots 0, 2 and 3 were
unknown is superseded by these positive bindings.

| Slot | Init GetWindowRect | Init X / Y stores | Refresh GetWindowRect | Refresh X / Y stores |
|---:|---|---|---|---|
| 0 | `0x5B9858` | `0x5B9869 / 0x5B9871` | `0x5DBF46` | `0x5DBF57 / 0x5DBF5F` |
| 1 | `0x5B9881` | `0x5B9891 / 0x5B9897` | `0x5DBF6F` | `0x5DBF7F / 0x5DBF85` |
| 2 | `0x5B98A7` | `0x5B98B7 / 0x5B98BD` | `0x5DBF95` | `0x5DBFA5 / 0x5DBFAB` |
| 3 | `0x5B98CD` | `0x5B98DD / 0x5B98E3` | `0x5DBFBB` | `0x5DBFCB / 0x5DBFD1` |
| 4 | `0x5B98F3` | `0x5B9903 / 0x5B9909` | `0x5DBFE1` | `0x5DBFF1 / 0x5DBFF7` |
| 5 | `0x5B9919` | `0x5B9929 / 0x5B992F` | `0x5DC007` | `0x5DC017 / 0x5DC01D` |
| 6 | `0x5B993F` | `0x5B994F / 0x5B9955` | `0x5DC02D` | `0x5DC03D / 0x5DC043` |
| 7 | `0x5B9965` | `0x5B9975 / 0x5B997B` | `0x5DC053` | `0x5DC063 / 0x5DC069` |
| 8 | `0x5B998B` | `0x5B99A2 / 0x5B99B0` | `0x5DC079` | `0x5DC089 / 0x5DC08F` |

Initialization caller: `0x5DCC64` compares the status string with `ANSWER_OK` (literal
`0x938818`, compare `0x5DCC93`, branch `0x5DCC99`) then calls the initializer at
`0x5DCC9D`. `0x5B9204 -> 0x5B90C0` shows the main dialog (mode 5 at `0x5B9118`),
then `0x5B9242` moves it. Refresh caller: resolution layout `0x5D9BDF` moves windows,
then `0x5DA0B8 -> 0x5DA165 -> 0x5DA1F5 -> 0x5DB954`. Refresh recalculates the
shell region and anchors; it does not itself move these children.

### Exact baseline HWND rectangles and anchors

Values below are `(x,y,width,height)` for the child HWND and `(x,y)` for the hint anchor.
They use the **8×16 dialog-unit baseline**, with font calibration disabled or equal to 1.
Both GUI files specify the same local child rectangles for slots 1, 3..8. The slot-2
resource-font qualification is given immediately below.

| Sub-kind | CDlgMain-local HWND | 800×600 HWND | 800×600 anchor | 1024×768 HWND | 1024×768 anchor |
|---:|---|---|---|---|---|
| 1 | `(0,23,22,22)` | `(0,482,22,22)` | `(0,462)` | `(0,650,22,22)` | `(0,630)` |
| 2 | `(70,32,22,22)` | `(70,491,22,22)` | `(70,471)` | `(70,659,22,22)` | `(70,639)` |
| 3 | `(72,23,22,22)` | `(72,482,22,22)` | `(72,462)` | `(72,650,22,22)` | `(72,630)` |
| 4 | `(50,11,22,22)` | `(50,470,22,22)` | `(50,450)` | `(50,638,22,22)` | `(50,618)` |
| 5 | `(22,11,22,22)` | `(22,470,22,22)` | `(22,450)` | `(22,638,22,22)` | `(22,618)` |
| 6 | `(0,50,92,86)` | `(0,509,92,86)` | `(0,489)` | `(0,677,92,86)` | `(0,657)` |
| 7 | `(52,54,40,86)` | `(52,513,40,86)` | `(52,493)` | `(52,681,40,86)` | `(52,661)` |
| 8 | `(4,54,40,86)` | `(4,513,40,86)` | `(4,493)` | `(4,681,40,86)` | `(4,661)` |

These are **HWND extents**, not image/fill extents. For example Progress42's HWND height
86 does not replace its separately proven 92×92 fill contract. Slot0's local HWND is
`(99,97,398,8)`, its anchor `(99,H-64)`; category8 sub-kind0 is rejected.

The initial parent uses height141. Resolution relayout reads `[0-130]` from
GUI800X600.ini `(0,459,800,150)` or GUI.ini `(0,627,1024,142)` and moves it at
`0x5D9F2C`. Those different heights do not change the origins above. Do not generalize
the initial height141 to all later HWND sizes.

When `g_uiDialogFontScaleEnabled` is active at widget Init, the established calibration
from `0x591C7B` is `sx=float32(8/mx)`, `sy=float32(16/my)`. For the seven initialized
controls, a GUI rectangle `(x,y,w,h)` becomes
`(R(x*sx),R(y*sy),R(w*sx),R(h*sy))`, where `R(z)=trunc(z+0.5)` with the native
floating-point evaluation. The initial anchor is then
`(R(x*sx), H-161+R(y*sy))`. `CMyCheck_Init` calls registration at `0x58B468`
and moves at `0x58B529`; `CMyProgress_Init` registers at `0x5A979B`, scales at
`0x5A97EF/0x5A9809` and calls MoveWindow at `0x5A9848`. Resolution relayout uses the
raw GUI pixels rather than calling these Init calibration paths again. In every case the
actual HWND read by the two slot writers, not a predicted font size, is authoritative.

### Slot 2: hidden chat CMyCheck, with resource geometry

`0x4B5E8A` selects `CDlgMain+0x13F728`; constructor call `0x4B5E94 -> 0x58B34F`
installs CMyCheck vtable `0x867038`. DDX selects that same object at `0x4BB750`,
pushes ID`0x3F6` at `0x4BB757`, and binds it at `0x4BB75D`. Resource130 item offset
`0x214` has BUTTON class atom`0x80`, title `聊`, style`0x4801800B` (child, disabled,
without WS_VISIBLE), extended style0 and **DLU `(35,16,11,11)`**. The dialog uses
DS_SETFONT, 12-point `宋体`. It is not one of the four CMyChecks initialized by
`0x4BB869`; no ANI name is inferred for it.

The slot-2 census records constructor, destructor/unwind, DDX, both anchor reads and
two state uses (`0x4BDB79/0x4BDB7F`, `0x4BDD14/0x4BDD1A`). Those state accesses do
not move the HWND. There is no `[130-1014]` section in either GUI file. Base dialog
initialization (`0x59642F`, registration `0x596441`) registers the parent, not every
child. Child registration is explicit in `0x591DF4`, reached from widget Init. The
resolution loop looks up the registered control ID at `0x5D9D3E -> 0x5932E8` and
skips an unregistered HWND at `0x5D9D5A`. An all-zero missing layout rectangle is
also skipped at `0x5D9D6F..0x5D9D83`. DDX alone does not provide that registration.

For the **actual dialog130 font base units** `(bx,by)`, its resource-created rectangle is:

```text
localX = MulDiv(35,bx,4)       localY = MulDiv(16,by,8)
width  = MulDiv(11,bx,4)       height = MulDiv(11,by,8)
anchor = (localX, H-161+localY)
```

This uses the documented font-based DLU conversion
([Microsoft MapDialogRect contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-mapdialogrect)).
There is no CMyCheck_Init `sx/sy` correction for this child. At `(bx,by)=(8,16)` the
table follows exactly. **The actual Windows font realization was not measured in this
run**, so the numeric baseline must not be presented as unconditional across machines.
The initializer's calibration measurement in another dialog does not prove dialog130 has
identical realized base units. The formula and actual GetWindowRect consumer are closed;
an unconditional OS-independent slot-2 pixel constant is not supported by the EXE.

Hotspot rect2 at `CDlgMain+0x134` is explicitly zeroed at `0x4BBCD2..0x4BBCE4`.
That prevents this mouse-move producer from posting sub-kind2; it does not eliminate
the independent HWND or its initialized anchor. Category8 dispatch itself still accepts2.

## Not yet enumerated

Category 9 and its zero-ID `STR_WRAPSHOP_TRY_TIP` branch are now closed in [GFX-UI-009](21_main_hud_magic_status_hint_native_contract.md). They do not use the category-8 placement rule. Weapon-swap belongs to category106 (`0x6A`), not56 (`0x38`); its separate full contract is outside this category-9 slice.

## Managed boundary

Earlier versions of this note described `CMyShellDlgStatusHintPanelRendererRuntime` as
already reproducing all prerequisites. That claim is not established by this evidence slice.
In particular, the old claim that native checks Dialog21 before anything else, including
for category5, was wrong. For category8 the font prerequisite is first; resource lookup,
measurement, then the null-resource guard follow at the addresses above. No managed
production code or tests were changed here. Native evidence is the authority for later work.

## GFX-UI-008 retail identity

The local clean retail archive `00_clean/clean/5517.7z` is 444752639 bytes,
SHA-256 `e44d7a30cfdf3ad3af79ea123599ebbcfe85786493ae24a5a3a3ac2a4014c080`.
The ANI, StrRes, three regions and complete data.wdf were extracted from that archive
and independently hash-compared with the clean tree; all agree. This establishes identity
to that supplied retail archive, not an unrecorded external download source.

| Retail file / winning provenance | Bytes | SHA-256 |
|---|---:|---|
| `ani/Control.Ani`, loose (native spelling `ani/Control.ani`) | 317837 | `a1db47baaeb2f75eea3b5216378f97d713c2afeaefe05ec02e6f584794532d27` |
| `ini/StrRes.ini`, loose | 59577 | `efe9f5f1d3e29bb79b9970c25dcb238179e3ab6e059e94d981b37236157cd072` |
| `ini/ProgressXp.rgn`, loose | 1988 | `8bbc96e993105cb97ff01d6ea5201c406d88aa0b91a5055b95617b89f28c62bc` |
| `ini/ProgressMp.rgn`, loose | 724 | `3aefd750231895a99d062276d460164d1004fbde7e3bbe3e922f1dea5bf743f4` |
| `ini/ProgressHp.rgn`, loose | 724 | `b7e8ed940da85bbe09e2eb96f7a074ca29f5d29d9cd121fb326373cb5540cea1` |
| `data.wdf`, package container | 392245257 | `fc628e4adeb7de48b0b7cde3c7793c7177a289a6defe9b90a33a1f683dcdb132` |
| `data/main/MsgDlg.dds`, data.wdf member | 65664 | `c91b686fa8e9758dd8c8825e401503825434a0ebaca3be30e8e0263b52985719` |

Exact section, with only one matching Dialog21 and no same-hash section collision:

```ini
[Dialog21]
FrameAmount=1
Frame0=data/main/MsgDlg.dds
```

No loose MsgDlg.dds override exists in this clean tree. Native WDF UID is `0x87576CFA`,
computed by executing original `TqPackageWdf.dll` hash code at `0x100099D0`.
The data.wdf record is index7817, offset**23254863** (`0x0162D74F`), size65664,
reserved0; exact record bytes are `fa6c57874fd762018000010000000000`.
The file is **DDS DXT3 / BC2, 256×256**. Its encoded header's raw RGBBitCount field
is not a valid description of the compressed pixel format.

Decoded pixels are canonical **RGBA8, straight alpha, top-to-bottom / left-to-right,
tightly packed**, 262144 bytes, SHA-256
`14c946e2af2f39339294b08c69357fdd59f87c1946065ee5ca84e60e489f4556`.
Pillow's decoder and an independent BC2 block decoder agree byte for byte. This is a
software-decoded identity, not a GPU readback. Native uses frame0 source RECT
`(0,0,100,200)`, not the DDS's full 256×256 extent.

Winning path proof reuses the established
[data-file/WDF contract](c3_core_dll/11_datafile_and_wdf.md) and adds targeted captures:
graphic `CAni` create `0x1000BBF0 -> 0x1000BC3A -> 0x1000BC80`, bitmap load
`0x10011EB0`, C3 `Sprite_Load 0x10015890 -> Texture_Load 0x10016360` at
`0x100158BC`. Texture_Load checks loose content through DataFile_UnpackSearch at
`0x1001641F`; absent loose data takes DataFile_Load at `0x10016442`, wrapper
`0x10001D60`, TqFDump at `0x10001D6F`. TqPackageWdf `0x10004220 -> 0x10001AC0`
uses the loose-first mode0 fallback; prefix routing `0x10003C80 -> 0x10003C30` maps
`data/` to `data.wdf`. This is not a search for the UID in arbitrary unrelated packages.
`assets.json` records the package table inspections separately from the winning route.

## Frame-loop ordering — GFX-UI-008

This is execution order when each path is admitted; visibility/resource/drag guards can
omit draws. No claim of adjacency is made: other frame overlays can occur in between.

```text
CMyShellDlg_RunFrameTick 0x5DCFAA
  0x5DD300 -> CMyDialogMgr_TickAndSyncChildWindows 0x597D66
    first list pass 0x597E00 -> 0x598458(callback 0x597931)
      -> 0x5971CF: visible dialog -> virtual+0xF4 at 0x5971E8
        CDlgMain vtable0x855DC0+0xF4 = [0x855EB4] = 0x4BC1F8
        CDlgMain_RenderMainUiDialogAndStatusOverlay
          main gauges/grid/buttons/checks
          0x4BCC2C selected image virtual+0xC4 -> 0x5A26EE
            selected icon, then cover tail 0x5A2A3E, then return
          0x4BCC34 -> 0x4BE7FB selected-skill cooldown
            text call 0x4BECB2
    remaining manager pass; return
  other frame overlays
  0x5DD337..0x5DD36A drag/visible gate
  0x5DD36A -> CMyShellDlg__RenderStatusHintPanel 0x5B9C3F
    category8 backdrop -> category8 text
```

The image target is independently read from vtable `0x867C38+0xC4 = 0x867CFC`.
The cooldown clear-cover call `0x4BE819` and conditional set-cover call `0x4BECC0`
occur **after** the current selected image/cover draw; the latter follows the cooldown
text. This slice uses the established GFX-UI-007 cooldown/image semantics only to pin
order, without re-investigating the algorithm.

Relevant guards: frame entry checks byte `shell+0x179AB9` at `0x5DCFB3`; the rendering
phase is bypassed by the branch at `0x5DD115` after testing `[ebp-4]`. The manager
checks the shell global `0x957EF4`, collects child windows and tests visibility, and
`0x5971CF` tests visibility again before the virtual call. CDlgMain's branch at
`0x4BC3A5` requires `+0x110 != 0`; a null Dialog4 at `0x4BC53F` skips the later
HUD/image/cooldown phase. The outer hint gate first queries drag-active; if true it
calls tracking at `0x5DD349` and skips the panel. A second active query at `0x5DD357`
must also be false, and `shell+0x179694` must be nonzero at `0x5DD360`. The panel's
font, category, sub-kind, MP and Dialog21 guards are additional.

Category8 backdrop calls are `0x5BA93B` (alternate overflow), `0x5BA9C7` (alternate
fits), `0x5BAA61` (ordinary layout); text converges at `0x5BAB63`. All backdrop calls
use frame0, source `(0,0,100,200)`, destination measured width/height, colour0 and
mode0. Placement uses the stored anchor without another Y subtraction. Alternate
overflow uses a signed fit comparison, as documented above.

## Verification and remaining platform boundary

The evidence bundle retains original-byte disassembly, HLIL/MLIL (analyst annotations
are not treated as proof), tables, resource records, complete direct slot stores, layout
sections, exact assets, extraction/inspection scripts and a guarded annotation restore file.
Original-x86 replay passes **982 cases** for both slot writers, hotspot selection,
category8 bounds/gauge routing/signed clamping/MP suppression and the frame hint gate.
The replay explicitly mocks HWND rectangles, region APIs, hero getters and frame
services; it does not execute USER32 dialog creation or a GPU renderer.

The requested client arithmetic, ownership, provenance and call ordering are closed.
The remaining environmental input is actual Windows dialog-font realization for slot2
and, when enabled at Init, the existing font calibration model for the other children.
Formulas are given rather than invented universal pixel constants. Live Windows/GPU
output was not observed. No other category or separate control-tooltip contract is
claimed closed by this slice.

## GFX-UI-009 category-9 closure

See [21_main_hud_magic_status_hint_native_contract.md](21_main_hud_magic_status_hint_native_contract.md) for full-DWORD learned-type lookup, exact helper ABI and embedded CMagic row, six text groups, original wrapping/layout arithmetic, optional Dialog21 plus border, zero-ID CDlgXp flags, retail identities and read-only managed integration audit. The learned-magic path continues text when Dialog21 is missing; it must not inherit category8's resource-null suppression. Raw captures/replays are in [the evidence bundle](../../10_work/docs/evidence/gfx-ui-009-main-hud-magic-status-hint-5517/README.md). Documentation and annotations only; no production implementation.

## HUD-010 additional category closure (2026-10-10)

[Rendering/22](22_main_hud_dance_weapon_swap_status_hint_native_contract.md) closes the remaining category `0x38` dance and `0x6A` weapon-swap branches. Dance synthesizes static Magic(type=parameter, level=0, experience=0); the main quickbar parameter3 has no retail record and draws nothing. Weapon swap tests hero DWORD+0xF1C exactly1, then enqueues one whole localized string for deferred rendering. Its default Dialog21 crop is100×100, with padding and no outline; missing art still permits text. Do not apply category8's resource suppression or sizing to that branch. Category8 findings above are unchanged.
