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
| 6 | XP gauge | `"%d/%d"` |
| 7 | MP gauge | `"%d/%d"` |
| 8 | HP gauge | `"%d/%d"` |

The gauge cases call `CMyProgress_GetValueRange` on the `CMyProgress` instances at
`this+0x140528`, `this+0x1405B0` and `this+0x140638` (stride `0x88`). They **discard the range
minimum**, take the live value from `CHero` — `CHero+0x510` for sub-kind 6,
`CHero_GetSmoothedCurrentMana` for 7, `CHero_GetPlayerDataByIndex(hero, 1)` for 8 — clamp it down
to the range maximum, and format `"%d/%d"` as (clamped value, maximum) through `_snprintf` with a
`0xFF` limit into a `0x200`-byte stack buffer. String cases `strncpy` the table text into that
same buffer.

The XP/MP/HP naming comes from the **region load order** in
`CDlgMain_InitializeMainHudWidgets` (see below), not from the `CHero` accessors, which have not
been independently verified. `CHero_GetSmoothedCurrentMana` on sub-kind 7 corroborates MP.

> An earlier revision of this note labelled sub-kind 6 as HP. That was an assumption drawn from
> `CHero+0x510` and is **superseded** by the region ordering.

Text colour for these hints is `0xFFFFFFFF`.

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

The hint panel is therefore driven by **command codes carrying packed parameters**, not by C++
mouse-hover logic. Verified write sites, with `param` = `[ebp+0x0C]`:

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
| `+0x174` | `Ini/ProgressXp.rgn` | 6 | XP |
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

**This ordering is the authority for the gauge naming.** All three `.rgn` files ship in the clean
client under `ini/`.

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

Note the asymmetry with the **producer** side: the hotspot rects belong to `CDlgMain`, while these
placement slots belong to `CMyShellDlg`. They are different objects with different child sets, so
a managed port cannot reuse one for the other.

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
