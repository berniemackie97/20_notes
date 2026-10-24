# CMyProgress — the HUD gauge widget

Anchor: `CMyProgress::Show` at `0x5A9033`. Companion methods `Init` `0x5A9784`,
`SetValueRange` `0x5A9A34`, `GetValueRange` `0x5A9A48`, `ResetValueRange` `0x5A9999`,
`SetFillGeometryPixels` `0x5A9A96`, and the `+0x84` setter at `0x5A9A60`.

This is the widget behind the Skill / MP / HP gauges whose `.rgn` hover regions are already
implemented in [12_hud_status_hint_panel.md](12_hud_status_hint_panel.md). The hint hotspots raise
gauge sub-kinds today with no gauge behind them; this closes that gap.

The downstream HP/MP/stamina contract is now recorded in
[15_main_hud_gauge_render_contract.md](15_main_hud_gauge_render_contract.md):
frame reachability, subvariant-1 correction, unclipped overflow UVs, resource
failures, and OS font-calibration placement. Use that evidence for GFX-UI-002.

The Progress42 state machine, exact assets, fixed fill/whole-highlight geometry,
timer overlap/wrap vectors and corrected Progress44 boundary are closed in
[16_main_hud_skill_progress_render_contract.md](16_main_hud_skill_progress_render_contract.md)
for GFX-UI-003. In particular, Progress44's missing ANI section does not prevent
its procedural style-0xA drawing.

Static Progress45 and Dialog4 have a separate
[English native contract](14_static_main_hud_chrome.md): origin `(0,H-141)`,
no template scaling, background before these gauges and panels after stamina.

## Verified field map

Derived by cross-checking the accessors against every use inside `Show`, so each offset is
corroborated from at least two directions.

| Offset | Type | Meaning |
|---|---|---|
| `+0x20` | `HWND` | `CWnd::m_hWnd`, standard MFC layout |
| `+0x40` | `std::string` | ANI section name, always resolved in `ani/Control.ani` |
| `+0x4C` | `int` | overlay layer mode: `0` none, `1` draw **after** the fill, `2` draw **before** |
| `+0x50` | `int` | overlay offset x, assigned only when the mode is non-zero |
| `+0x54` | `int` | overlay offset y |
| `+0x58` | `int` | control origin x = `GetWindowRect().left - Init.baseX` |
| `+0x5C` | `int` | control origin y = `GetWindowRect().top - Init.baseY` |
| `+0x60` | `int` | fill width |
| `+0x64` | `int` | alternate fill width, style 0 with sub-variant 1 |
| `+0x68` | `int` | fill height = `rect.bottom - rect.top - 4` |
| `+0x6C` | `float` | pixels per value unit |
| `+0x70` | `float` | capped pixels per unit; `Show` uses the ratio `+0x70 / +0x6C` |
| `+0x74` | `u8` | style selector |
| `+0x78` | `int` | value span (`max - min`) for style `0xB`; that style compares the value against it |
| `+0x7C` | `int` | range minimum |
| `+0x80` | `int` | range maximum |
| `+0x84` | `u8` | sub-variant selector, consulted only when the style is 0 |

The `-4` in the height is not a typo — the control reserves four pixels of its window rect.

## Signatures

```
Init(this, baseX, baseY, aniSection, min, max, style, overlayMode, overlayOffX, overlayOffY)
Show(this, x, y, value, value2)
SetValueRange(this, min, max)          -> +0x7C, +0x80
GetValueRange(this, &outMin, &outMax)  <- +0x7C, +0x80
SetFillGeometryPixels(this, width, height, altWidth) -> +0x60, +0x68, +0x64
ResetValueRange(this, min, max)        -> SetValueRange, then recompute +0x6C per style
```

`Show` applies a **signed upper clamp** to both value arguments at `+0x80` before drawing;
it does not clamp negative values to zero. Two values are taken because several styles draw a
primary and a secondary fill (a current/target pair).

`Init` also repositions the control through `CWnd::MoveWindow` when the UI-scale global
`g_uiDialogFontScaleEnabled` (`0x957E24`) is set, using the factors at
`0x957E2C` / `0x957E30`. This is startup OS font-unit compensation, not an
unidentified screen-mode option. Its writers and conditional final coordinates
are proved in [the calibration contract](15_main_hud_gauge_render_contract.md#ui-calibration-and-final-origins).

## Styles

`ResetValueRange` is the clearest statement of the style set, because it recomputes `+0x6C`
differently per style:

- **0 — vertical fill.** Scale is height-based: `+0x6C = height / (max - min)`, and
  `+0x70 = span >= 100 ? height * 0.01 : height / span`. The `+0x84` sub-variant selects between
  draw paths within this style.
- **0xA — solid colour bands.** Drawn with `CMyBitmap::ShowBlock` as three stacked quarter-height
  bands in `0xFFF1D06E`, `0xFFE8A326`, `0xFFAB916C`. Mirrored horizontally when the GameDataSet
  string `0x28BA` equals `"Arabic"`.
- **9 — horizontal ANI fill.** Like style 0xA, `+0x6C = width (+0x60) / (max - min)`.
  Style 9 is Arabic-mirrored too. Styles 1/2 do not select these fill branches.
- **0xB — horizontal, ANI-sized remainder.** Width and height come from ANI frame 0's
  dimensions instead of the window rect. It compares the incoming value against
  `+0x78`, and draws the remaining source interval when unequal.

## Sub-variant selector

The old inherited Binary Ninja name `CMyProgress_SetBlendMode` was misleading and is now corrected
to `CMyProgress_SetSubVariant`. The setter stores only the low byte at `+0x84`; nothing establishes
alpha blending. For style 0, values 0 and 1 select the normal and alternate-width cropped-fill
paths. Value 2 instead queries the widget's `ani/Control.ani` section and invokes the resource draw
entry with frame index 2 at `(originX + parentX, originY + parentY)`, with both trailing parameters
zero. It ignores the gauge values after their common entry clamp and draws the highlight frame
whole.

## Known call site

`sub_4E6EB4`, the "Openhole" dialog renderer, calls
`CMyProgress_Show(dlg + 0xA24, dlg + 0xF0, dlg + 0xF4, v, v)` — note it passes the same value for
both arguments, which is the degenerate single-fill case.

## The six main-HUD gauges

Created in `CDlgMain_InitializeMainHudWidgets` (`0x4BB869`; body starts `0x4BB873`), drawn in
`CDlgMain_RenderMainUiDialogAndStatusOverlay` (`0x4BC1F8`; body starts `0x4BC202`). Exactly six `CMyProgress_Init` calls
live there, which is what fixes the set at six.

Every one is initialised `min = 0, max = 0x64`. **That is a placeholder, not the operating range**
— see the correction below. Only `Progress42` genuinely runs 0..100.

| Widget | ANI section | Style | `SetFillGeometryPixels(w, h, altW)` | `Show(value, value2)` source |
|---|---|---|---|---|
| `+0x13F6A0` | `Progress40` | 0 | `0x24, 0x4A, 0x56` | `GetPlayerDataByIndex(hero, 1)`, `GetPlayerDataByIndex(hero, 0xF)` |
| `+0x13F618` | `Progress41` | 0 | `0x22, 0x4A, 0x22` | `CHero_GetCurrentMana(hero)`, `CHero_GetManaGaugeFollower(hero)` (`vtable+0xB0`) |
| `+0x13F590` | `Progress42` | 0 | `0x5C, 0x5C, 0x5C` | `hero+0x510` for both arguments |
| `+0x13C308` | `Progress46` | 0 | `8, 0x46, 8` | `CHero_GetCappedPhysicalForce(hero)` for both |
| `+0x13C280` | `Progress47` | 0 | `8, 0x23, 8` | `force - 0x64` for both, after a range reset |
| `+0x13F508` | `Progress44` | **0xA** | *(none)* | `(u64 at hero+0x860) >> dlg+0x10C` for both |

Argument order is `Show(this, x, y, value, value2)`, confirmed from the push order at `0x4BC423`:
`x = dlg+0xF0`, `y = dlg+0xF4`, then the index-1 result, then the index-15 result.

Five gauges use style 0 (vertical, height-scaled). Only `Progress44` is style `0xA` (horizontal).

### Notable per-gauge behaviour

**`Progress40`** is the only gauge fed from the obfuscated FDword container at `role+0x978`, reading
index 1 (current life) against index 15. See
[01_core_packets.md](../Network/01_core_packets.md) for that index enum — index 1 is
server-delivered. **Index 15 is now identified — see
[14_hero_effective_max_life_mana.md](14_hero_effective_max_life_mana.md).** An earlier revision of
this note claimed it "never comes off the wire"; that is wrong, `CMsgTick__Process` writes it in its
clamp branch.

**`Progress41`** uses the same follower rule as HP. `hero+0x5E0` is live current mana;
`hero+0x768` is the delayed-rise MP gauge follower exposed through vtable slots `+0xB0/+0xB4`.
`CHero_PerFrameTickAndSubsystemUpdate` advances it by `effectiveMaxMana / 80` when the maximum is at
least 80, otherwise by 1, then clamps it to current mana. It therefore snaps down on mana loss and
lags only while mana rises. Both protected containers are constructed with logical value zero.

**Progress40 (HP)** is the gauge given a non-zero sub-variant at init:
`CMyProgress_SetSubVariant(+0x13F6A0, 1)` at `0x4BB92E`.
That is a direct confirmation of the `+0x84` semantics derived above — this widget is the one with
`width 0x24` but `altWidth 0x56`, and the flag is exactly what makes `Show` use `+0x64` instead of
`+0x60`.

**`Progress47`** is an overflow bar for stamina, drawn only when
`CHero_HasExtendedPhysicalForceGaugeStatus()` is set **and** `CHero_GetCappedPhysicalForce() >= 0x64`.
It calls `CMyProgress_ResetValueRange(this, 0, 0x32)` first, then shows `force - 0x64` — so it
represents physical force in the range 100..150 on a second, shorter bar.

**`Progress42`** is driven by `hero+0x510`, **now identified**. `CMsgUserAttribEx__Process` attribute
id `0x1B` (27) writes it at `0x757C1F`, **clamping the value to `0x64` first** (`0x757C10`) and then
posting custom main-window code `0x40F` with payload zero through the common call at `0x7585F3`.
The `0x464` window-message arm at `0x5C3CC0` reads the current local `CHero+0x510` value and calls
`CDlgMain_ArmSkillGaugeHighlight` (`0x4BE215`) only when the unsigned value is below 100. That
method clears `CDlgMain+0x19C` and sets `CDlgMain+0x198` to one; it does not change the widget
immediately. The clamp to 100 is what makes this the one gauge native re-ranges to a
literal `0x64` rather than to a live maximum, and the shipped `ani/Control.ani` labels the section
`技能槽` — the skill gauge. So the field is the skill-gauge percentage; it is the value passed to both inputs
of this gauge's Show call. This identified packet writer is not an exhaustive writer census. The status hint panel reads it too, at `0x5BA7C8`, alongside
`CMyProgress_GetValueRange` for the numeric readout.
It is also the gauge with a one-shot highlight. Because the producer does not change the widget,
the already-running HUD pass draws its prior variant first. At the render tail, when `dlg+0x198` is
set and `dlg+0x19C` is zero, native selects sub-variant 2 and records `timeGetTime()` at
`dlg+0x19C`. With no intervening variant command, later passes draw frame 2 whole
until unsigned now >= uint32(start+500); that pass draws before its tail forces
variant 0 and clears `dlg+0x198`. There is no saved previous variant.
Command 0x40D can set variant 1 during the timer without restarting it, and 0x40E
can set variant 0 without cancelling it. The timestamp remains until rearmed.
Equality expires; DWORD addition wrap and the zero timestamp sentinel have the
specific behavior recorded in the GFX-UI-003 contract. This is a one-shot
highlight, not a repeating blink.

**`Progress44`** shows experience as a 64-bit value right-shifted by `dlg+0x10C`, a runtime-adjusted
shift paired with the scaled next-level experience maximum. Its operating range
is not the initial placeholder 0..100.

### Hover regions

The same initialiser loads the three gauge hit regions, in this order:

```
Ini/ProgressXp.rgn -> dlg+0x174
Ini/ProgressMp.rgn -> dlg+0x178
Ini/ProgressHp.rgn -> dlg+0x17C
```

This independently confirms the load order recorded in
[12_hud_status_hint_panel.md](12_hud_status_hint_panel.md), and pairs the regions with the gauges:
**Skill with `Progress42`**, MP with `Progress41`, HP with `Progress40`.
The former pairing of `ProgressXp.rgn` with Progress44 was incorrect: region0 posts sub-kind6,
whose native receiver is shell`+0x140528` = dlg`+0x13F590` = Progress42.
The [independent proof](12_hud_status_hint_panel.md#sub-kind-6-semantic-proof) records the
constructor, DDX binding, Init, range, live value and message chain.

## The vertical fill, exactly

Taken from the raw instruction stream, not HLIL: the source rectangle is assembled from four
separate stack slots (`[ebp-0x14]`, `-0x10`, `-0x0C`, `-0x08`) whose order the decompiler does not
preserve, so reading it as rendered would produce a plausible but wrong rectangle.

`Show` branches on the two values at `0x5A95AC` before doing anything else.

### Single fill, when `value1 <= value2` (`0x5A95BA`–`0x5A9634`)

`value1 == 0` skips the draw entirely (`cmp eax, ecx` against zero, then `je`) — native does not
issue an empty blit.

```
fillPixels = (int)(value1 * PixelsPerUnit)        ; _ftol truncates toward zero
RECT       = { 0, height - fillPixels, width, height }
dest       = ( originX + x, originY + y + (height - fillPixels) )
blit       = ( width, fillPixels )
frame      = 0
```

Bottom-anchored, so the bar grows upward.

### Value pair, when `value1 > value2` (`0x5A963C`–`0x5A971E`)

Two blits, in this order. The zero skip does **not** apply here.

```
; first — the larger value, frame 1
pixels1 = (int)(value1 * PixelsPerUnit)
RECT    = { 0, height - pixels1, width, height }
dest    = ( originX + x, originY + y + (height - pixels1) )
blit    = ( width, pixels1 )
frame   = 1

; second — the smaller value, biased, frame 0
bias    = (int)(CappedPixelsPerUnit / PixelsPerUnit + 0.5)
exact   = (value2 + bias) * PixelsPerUnit
pixels2 = (int)exact                              ; truncated
height2 = (int)(exact + 0.5)                      ; rounded half up
RECT    = { 0, height - pixels2, width, height }
dest    = ( originX + x, originY + y + (height - pixels2) )
blit    = ( width, height2 )
frame   = 0
```

The constant added before each `_ftol` is the float `0.5` at `0x84D4A0`, i.e. round-half-up.

**Note the asymmetry in the second blit.** Two different roundings are taken from the same product:
the source rectangle uses the truncated pixel count while the blit height uses the rounded one, so
the blit can be one pixel taller than the rectangle it samples. This is faithful behaviour and is
reproduced rather than tidied away.

For these HP/MP callers, frame 1 displays current value and frame 0 displays the
biased delayed-rise follower. The followers snap down on loss and lag on rises;
this is not an old-level trail during falling values.

### Width selection

Both branches above are sub-variant 0 and use `+0x60`. Sub-variant 1 uses
`+0x64` **and frame 2** (pushes at `0x5A950A` and `0x5A95A5`). In its
current>follower branch it submits only one follower-based frame-2 draw; the
earlier current-based RECT is overwritten at `0x5A957E`. It does not submit
frame 1 and does not apply the normal-path follower bias. The earlier claim
that both variants can differ only by effective width was incorrect. See
[the exact branch table](15_main_hud_gauge_render_contract.md#exact-style-0-submissions).

## Dialog placement

The gauges are bound to dialog controls by the DDX block at `0x4BB6C0`, immediately before
`CDlgMain_InitializeMainHudWidgets`. Control ids and the template rects from RT_DIALOG resource
`0x82` (400 x 70 template units, language 2052):

| Gauge | Control id | Template `x, y, cx, cy` | Class |
|---|---|---|---|
| `Progress40` | `0x5DD` | `2, 27, 20, 43` | `msctls_progress32` |
| `Progress41` | `0x5DE` | `26, 27, 20, 43` | `msctls_progress32` |
| `Progress42` | `0x3FA` | `0, 25, 46, 43` | `msctls_progress32` |
| `Progress44` | `0x3FB` | `47, 46, 203, 6` | `msctls_progress32` |
| `Progress46` | `0x401` | `21, 29, 6, 39` | `msctls_progress32` |
| `Progress47` | `0x403` | `21, 26, 6, 16` | `msctls_progress32` |

The extraction is self-checking: the same pass yields `Main3_OrganiseBtn` (`0x400`) at
`350, 46, 25, 12`, which matches the constants the already-implemented organise button uses, and a
template size of 400 x 70. Those are dialog units; agreement with managed constants is
corroboration only. It does not establish a pixel scale for the static HUD artwork, whose
separate [native placement contract](14_static_main_hud_chrome.md) uses explicit pixels.

**The control rect is not the fill geometry.** Native `Init` derives width and height from
`GetWindowRect`, and `SetFillGeometryPixels` then overwrites both with fixed pixel constants — so
`Progress40` is a 20 x 43-unit control carrying a 0x24 x 0x4A pixel fill. Only the origin scales
with the dialog. A port that sizes the fill from the template rect will be wrong on every gauge.

`Progress44` never receives a `SetFillGeometryPixels` call at all, so its geometry stays whatever
`Init` derived from its control rect.

## What the shipped ANI data says

`ani/Control.ani` carries a GBK comment above each section, which is the developers' own label:

| Section | Comment | Frames |
|---|---|---|
| `Progress40` | `HP槽` — HP gauge | `ProgressHP.dds`, `ProgressHPA.dds`, `ProgressHPH.dds` |
| `Progress41` | `MP槽` — MP gauge | `ProgressMP.dds`, `ProgressMPA.dds`, `ProgressMPH.dds` |
| `Progress42` | `技能槽` — **skill gauge** | `ProgressPower.dds`, `ProgressPower.dds`, `ProgressPowerH.dds` |
| `Progress45` | `背景` — background | `ProgressBk.dds` |
| `Progress46` | `体力` — stamina | `ProgressForce.dds`, `ProgressForceA.dds` |
| `Progress47` | `体力2` — stamina 2 | `ProgressForce2.dds`, `ProgressForce2A.dds` |

Read the file as GB18030; the comments are CP936 and are mojibake under UTF-8.

**This names `hero+0x510`.** `Progress42` is the gauge fed from that field and nothing else, and the
shipped data labels it 技能槽, the skill gauge. Note the artwork is called `ProgressPower`, so the
filename and the comment disagree; the section comment is the more specific of the two and is the
developers' own label for the control. The native fixed0..100 range and packet clamp establish the gauge scale.
`SkillGaugeValue` is a defensible UI name; this does not establish the server's accrual formula
or a broader gameplay name such as skill proficiency or character experience.

The three-frame layout corroborates the `+0x84` analysis exactly:

- frame 0 — the base fill
- frame 1 — the first/current draw of the normal dual-fill pair; Progress42
  duplicates ProgressPower.dds here and cannot reach this frame with its equal inputs
- frame 2 — the `…H` variant: cropped by sub-variant 1 and drawn whole at the
  origin by sub-variant 2. HP and MP can request it through sub-variant 1.

Sub-variant 2 draws `ProgressPowerH.dds` (frame 2) whole at the control origin and does not consult
either gauge value. That whole-frame highlight is conclusive: `+0x84` selects artwork, not a blend
mode.

### `Progress44` missing ANI does not imply no draw — corrected 2026-09-26

The already-established absence of a `Progress44` section is unchanged, but the previous
implementation consequence was wrong. Init at `0x4BBA2A` passes style `0xA` (push
`0x4BBA14`) and overlay mode 0. Show dispatches that style at `0x5A90D3` to
`0x5A915C`, a solid-colour path that never queries the ANI section. For positive
values, the English branch submits three `CMyBitmap::ShowBlock` calls at
`0x5A9287`, `0x5A92C6`, and `0x5A92FE`, using `0xFFF1D06E`, `0xFFE8A326`,
and `0xFFAB916C`. Zero skips; negative values have a separate red-block path.
The caller continues at `0x4BC7FC` into `CMyGrid_Show` at `0x4BC810`.

Thus Progress44 needs no ANI/DDS dependency, but **its visible procedural experience
bar cannot be omitted on the grounds of the missing section**. The original claim
that its live Show performs a failed section lookup was not supported by its actual
style branch. The GFX-UI-003 evidence bundle records the original-instruction replay
and the corrected implementation boundary.

### Asset availability — CORRECTED

An earlier revision of this note claimed only two Progress assets ship. **That was wrong**, and the
error was in the search, not in the client: it looked only at loose files under `data/main/` and
ignored `data.wdf`, the 392 MB packed archive the client actually reads through
`TqPackageWdf.dll`.

Resolved properly using the repo's own verified `WdfHash` (reimplemented from
`TqPackageWdf.dll` `0x100099D0`), against `data.wdf`'s 14,739-entry index:

| Path | Where |
|---|---|
| `data/main/ProgressHP.dds` | `data.wdf`, 16512 bytes |
| `data/main/ProgressHPA.dds` | `data.wdf`, 16512 |
| `data/main/ProgressHPH.dds` | `data.wdf`, 16512 |
| `data/main/ProgressMP.dds` | `data.wdf`, 16512 |
| `data/main/ProgressPower.dds` | `data.wdf`, 16512 |
| `data/main/ProgressPowerH.dds` | `data.wdf`, 16512 |
| `data/main/ProgressForce.dds` | `data.wdf`, 16512 |
| `data/main/ProgressForceA.dds` | `data.wdf`, 16512 |
| `data/main/ProgressBk.dds` | `data.wdf`, 65664 |
| `data/main/ProgressForce2.dds` | loose file only |
| `data/main/ProgressForce2A.dds` | loose file only |

**Every gauge's artwork ships.** The two that are not in the archive are exactly the two present as
loose files, which is the patch-override mechanism working as designed, not a gap.

The hash port used for this lookup is self-validating: nine exact hits out of eleven candidate
paths. An incorrect hash would have produced zero.

A framebuffer conformance case is therefore possible for **every gauge that has an ANI section**,
not for `Progress47` alone as previously stated.

On case sensitivity: WDF lookup lowercases the path before hashing, so archive resolution is
case-insensitive by construction. Only the loose-file path is exposed to the filesystem's own rules,
which is where the `ProgressForce2A.dds` reference against a shipped `ProgressForce2a.dds` matters —
fine on Windows and on a default macOS volume, broken on a case-sensitive one.

### Why the `Progress44` ANI section still does not resolve

This survived re-checking, and is now established three independent ways:

1. `ani/Control.Ani` contains sections `Progress40`, `41`, `42`, `45`, `46`, `47` — no `Progress44`.
2. `Progress44` *is* defined in the sibling files `ani/Control1.Ani` and `ani/Control2.Ani` (which
   also add `Progress43`), but **no binary in the client references them**: scanning every `.dll`
   and `.exe` in the tree for `Control1` / `Control2` returns nothing, and `Conquer.exe` contains
   exactly one such string, `ani/Control.ani`.
3. Neither `ani/Control.ani` nor its numbered siblings exist inside `data.wdf` or `c3.wdf`, so the
   loose file is the only copy and is authoritative.

The section genuinely does not resolve, but the live XP gauge's style-0xA
`Show` does not query it. The sibling sections are not dependencies of this
procedural draw path; see the corrected implementation boundary above.

## Correction: the gauges are NOT percentage gauges

An earlier revision of this note read the `min = 0, max = 0x64` in
`CDlgMain_InitializeMainHudWidgets` as proof that the gauges take percentages. That was wrong. The
initialiser's range is a placeholder that never survives the first frame.

`CDlgMain_UpdateGaugeRangesFromHero` (`0x4BD53E`) is called **first** from the render routine
(`0x4BC20A`), before any gauge draws, and re-ranges them from the hero's real maxima every frame:

| Gauge | Per-frame range |
|---|---|
| `Progress40` HP | `ResetValueRange(0, CHero_GetEffectiveMaxLife(hero))` |
| `Progress41` MP | `ResetValueRange(0, CHero_GetEffectiveMaxMana(hero))` |
| `Progress46` stamina | `ResetValueRange(0, CHero_GetEffectiveMaxPhysicalForce(hero))` |
| `Progress42` skill | `ResetValueRange(0, CHero_GetSkillGaugeMaximum(hero))` — returns constant `0x64` |
| `Progress44` XP | `ResetValueRange(0, CDlgMain_ScaleExperienceGaugeRangeToDword(dlg, CHero_GetNextLevelExp(hero)))` |

So the values are raw against a live maximum. That also resolves what looked like a contradiction
earlier: `MsgUserInfo` delivers raw current health into FDword index 1, and the gauge shows it
correctly because its range is max life, not 100.

`CHero_GetEffectiveMaxLife` (`0x65D06D`) was named from its formula rather than from a symbol:
`(spirit + vitality * 8 + agility + strength) * 3`, then a profession-keyed percentage bonus,
per-slot equipment contributions, an overlay-mode bonus from `hero+0xCB0`, and a nine-entry tier
table. `hero+0x514` short-circuits it as an override when positive under a map flag. The
vitality-times-eight term is what makes the identification unambiguous.

`CHero_GetEffectiveMaxMana` (`0x65D25A`) is now closed too. It honors the `hero+0x518` override
only when map flags64 bit 38 (`0x0000004000000000`, high-dword `0x40`) is set, otherwise starts at `spirit * 5`, applies the raw
profession-family branch exactly as assembled (`(profession % 1000) / 10 > 10`, unsigned), adds
signed mana from all 18 equipment slots, and clamps negative totals to zero. The `JBE` at
`0x65D2AB` is important: changing the condition to `== 1` would be an attractive but false
"cleanup."

`CHero_GetSkillGaugeMaximum` (`0x65D256`) is the four-byte constant-return helper immediately
before the mana getter. Its only xref is this HUD range update, and it returns `100`; this closes
the distinction between the skill gauge's fixed range and all four stat-driven ranges.

### XP range is the current level requirement, not a percentage table

`CHero_GetNextLevelExp` (`0x6601A7`) reads the first qword from key `0`, record
`(hero.level - 1)`, in the 24-byte `ini/LevExp.dat` table. The loader
`CHero_LoadLevelExpTable` (`0x65FFE4`) uses decoded-text seed `0x4D2`; the shipped key-0 rows begin
with level 1 = `120`, level 2 = `180`. `CDlgMain_ScaleExperienceGaugeRangeToDword` (`0x4BE718`)
then chooses shift `0`, `16`, or `32` so that the qword fits a 32-bit `CMyProgress` range and
stores that shift at `dlg+0x10C`. The draw path shifts current experience by the same amount.

The previously open equipped-item inputs are now binary-closed: Itemtype fields 19/20 provide
signed life/mana; ItemAdd payload word 0 is max-life; MsgItem `+36` is the non-steed enchantment
life bonus; permanent/temporary soul ids select alternate Itemtype fields with the exact
required-level suppression gate; and CMsgNonSuch 2077 owns the primary/secondary refinement
state. The managed equipped-item contribution resolver implements this substrate. The remaining
HUD boundary is integration of those verified contributions into the full hero formula and live
gauge range binding, not further inference about item semantics.

### The alternate width is a startup transient

Also corrected: `Progress40`'s sub-variant is not a steady state. The initialiser sets
`CMyProgress+0x84 = 1` and sets `dlg+0x100 = 1`. Then at `0x4BD60D`, on the first frame where
`dlg+0x100` is set **and** signed `min(currentMana, effectiveMaxMana)` is greater than zero,
`CMyProgress_SetSubVariant(Progress40, 0)` fires and `dlg+0x100` is cleared. A later return to zero
mana does not re-arm the startup state.

So the `0x56` alternate width applies only until the first frame with non-zero mana; the steady
state is the `0x24` primary width. Both states are real, and the framebuffer case HUD-002
deliberately exercises the startup state.

## Draw order — the gauges are SPLIT around the Dialog4 panels

`CDlgMain_RenderMainUiDialogAndStatusOverlay` (entry `0x4BC1F8`, body `0x4BC202`)
in full, with addresses:

| # | Step | Address |
|---:|---|---|
| 1 | `CDlgMain_UpdateGaugeRangesFromHero` | `0x4BC20A` |
| 2 | Flash host dialog visibility | `0x4BC215`–`0x4BC39A` |
| 3 | `Progress45` backdrop, gated on `dlg+0x110` | lookup `0x4BC3C6`; English draw `0x4BC420` |
| 4 | **`Progress40`** HP | `0x4BC455` |
| 5 | **`Progress41`** MP | `0x4BC48F` |
| 6 | **`Progress46`** stamina | `0x4BC4C2` |
| 7 | **`Progress47`** stamina overflow | `0x4BC517` |
| 8 | Dialog4 static panels, four English sub-rect draws | `0x4BC6B6`, `0x4BC6E9`, `0x4BC720`, `0x4BC75E` |
| 9 | **`Progress42`** skill | `0x4BC78E` |
| 10 | **`Progress44`** XP | `0x4BC7F7` |
| 11 | `CMyGrid_Show` + ten slot items | `0x4BC810`– |
| 12 | Buttons and checks | `0x4BC971`–`0x4BCC0F` |
| 13 | `CMyImage` vtable `+0xC4` | `0x4BCC2C` |
| 14 | `Progress42` one-shot highlight expiration, 500 ms | `0x4BCD02`– |

**Four gauges draw before the Dialog4 panels and two after.** Drawing all six together puts the
skill and XP gauges on the wrong side of the panel art. An earlier managed revision was worse than
that: it called the HUD root's whole `Draw()` from inside the button loop, at the position of
`Main3_OrganiseBtn`, so every gauge rendered in the middle of the button sequence.

The managed stage now mirrors the native phases, and `CDlgMainHudUiRootRuntime` exposes
`UpdateGaugeRanges`, `DrawGaugesBeforeDialog4Panels`, `DrawGaugesAfterDialog4Panels` and
`DrawOrganiseButton` separately so the panel pass can be interleaved.

### Button and check order

Native's order comes from the member offsets, **not** from the dialog-resource order:

```
0x13FA84 Button40    0x13FB24 Button410   0x13FBC4 Button42   0x13FC64 Button43
0x13FD04 Main3_MissionBtn        0x13FDA4 Button45           0x13FE44 Button46
0x13F9E4 Button47    0x13C390 Main3_OrganiseBtn              0x13FEE4 Button41
then 0x13F840 Check40, 0x13F7B4 Check43, 0x13F8CC Check46, 0x13F958 Button411
```

Note `Button410` is **second** and `Button41` is **tenth**. An earlier managed revision had those
two swapped. `Button411` is a `CMyCheck`, not a button, despite the name.

Two buttons blink on a 500 ms cycle before being drawn: the PK button `Button47` gated on
`dlg+0x108` and the faction button `Main3_OrganiseBtn` on `dlg+0x104`, both via
`CMyButton_SetCurrentFrame`. Both flags and both producers are identified below.

### Button blink cycles

Both were read from raw bytes — HLIL emits each cycle's two frame arms out of address order, so the
rendered form assigns the wrong frame to the wrong branch.

Shared state: one bitmask at `0x956228` marking whether a cycle has started (bit 0 Button47, bit 1
organise) plus separate start timestamps at `0x95622C` and `0x956230`. Half-period `0x1F4` ms for
both, and the frame is `(elapsed / 0x1F4) & 1`.

**Button47** (`0x4BCA8E`–`0x4BCB21`), gated on `dlg+0x108`, alternates frames **0 and 1**. It also
restarts when its stored timestamp is zero, which is the state its own timeout leaves behind. The
timeout compares with `JBE` against `0x7530`, so the cycle survives exactly 30000 ms and ends past
it; on expiry it forces frame 0, clears `dlg+0x108` and zeroes the timestamp.
Phase and expiry use separate clock samples (`0x4BCABC` and `0x4BCAE9`). Both differences are
unsigned DWORD subtraction modulo `2^32`. Expiry can therefore replace the phase frame with 0
before Show in the same pass. The complete ordering and replay boundaries are in
[17_main_hud_action_strip_native_contract.md](17_main_hud_action_strip_native_contract.md).

**Organise button** (`0x4BCB2C`–`0x4BCB9C`), gated on `dlg+0x104`, alternates frames **1 and 2** and
has **no timeout** — nothing in the blink path ever clears `dlg+0x104`.

One call sits deliberately outside the blink gate: `sub_4E892A(dlg+0x90A80, dlg+0x104 == 1)`.
`0x4BCB74` is the `jz` target; the actual call is at `0x4BCB85`, so it runs every frame regardless
of whether the cycle is active. It copies that boolean byte to the child dialog's `+0xF8`.
Not modelled.

### Who raises the two flags

`CDlgMain` is embedded in `CMyShellDlg` at **`+0xF98`** — proven from the ctor call site at
`0x5ADB11`, `lea ecx, [esi+0xF98]`, then the constructor call at `0x5ADB1B`
to `CDlgMain_Constructor` (`0x4B5468`). The earlier `0x5ADB10` citation was the parent-argument push.
So the two flags are `CMyShellDlg+0x109C` (`dlg+0x104`) and `CMyShellDlg+0x10A0` (`dlg+0x108`),
and the shell dispatcher accesses those flags at the corresponding shell displacements.
Scanning only the main-relative displacements misses those shell accesses. The additional
main-relative reset in `sub_4BDACD` is recorded below.

`CDlgMain_Constructor` zeroes `+0x100`, `+0x104`, `+0x108` and then `+0x10C`, so both flags start
clear.

Both producers live in `CMyShellDlg_WindowProc_DispatchMainWindowMessages` (`0x5BB79D`). Command
ids are `CMD_NORMAL + n` with `CMD_NORMAL = 1000` (eosource `3DBaseCode/BaseFunc.h:316`).

**`dlg+0x108` — PK mode.** Actual command `0x400` enters at `0x5C3424`. **Only its mode-0 branch**
sets the flag to 1 (`0x5C348E`); modes 1/2/3 preserve it. It re-skins the same widget the blink drives —
`dlg+0x13F9E4`, DDX control `0x3F5` = `IDC_MAIN_PK` — from `CHero+0xFBC`:

| `CHero+0xFBC` | ANI section |
| --- | --- |
| 0 | `Button47` |
| 1 | `Button49` |
| 2 | `Button48` |
| 3 | `Button412` |

then calls `sub_6527A2(sub_4197DD(), CHero+0xFBC)` to persist `PkModeRecord`. Neither the skin
setter nor this command resets the current frame or timestamp. Mode 0 arms the blink; another
mode can inherit an active blink, and repeated mode-0 commands do not restart it. The loop
clears the flag after elapsed time exceeds 30000 ms. Invalid modes preserve skin and gate but
still reach the persistence call. This corrects the earlier unconditional-gate claim.

**`dlg+0x104` — guild bulletin.** `case 0x414` = `CMD_FLASH_SYNDICATE_WORD` (1000+44), at
`0x5C3897`. It first refreshes the guild-word host at `CMyShellDlg+0x108E30` when that host is
visible (`sub_46B015`), then copies the bulletin text returned by `sub_7012AA(CHero)` into a local
buffer with `strncpy` capped at `0xFF`. When the text is neither the literal `"NULL"` nor empty it
checksums it as `sum(abs((signed char)c))` over `strlen` characters. The flag is raised only when
**all three** hold:

1. the flag is currently 0 (`0x5C3981`),
2. the guild-word host at `CMyShellDlg+0x108E30` is **not** visible, and
3. the checksum differs from the last one stored at `CMyShellDlg+0x1797BC`.

It then sets the flag to 1 (`0x5C39B7`) and stores the new checksum (`0x5C39CD`). The checksum
comparison is what stops an unchanged bulletin from re-blinking on every refresh.
Empty text or `"NULL"` skips checksum accumulation but still reaches the comparison with a
zero checksum; nonempty text is not an additional prerequisite for raising the flag.

The dispatcher reset blocks are actual commands **`0xCAE` and `0xCAF`**, entering at
`0x5C23C8` and `0x5C2533`. The earlier `0x78/0x79` values were compressed switch indexes,
not message command IDs. When the host at `CMyShellDlg+0x10519C` is hidden and the flag is
nonzero, the blocks clear it at `0x5C23F7/0x5C2562` and select button frame 0 at
`0x5C240C/0x5C2577`. An additional reset in `sub_4BDACD` clears at `0x4BDB22` and selects
frame 0 at `0x4BDB24` while opening hidden `CDlgMain+0x104204` after the common modal guard.
None resets the process-global Organise timestamp. Clicking `Main3_OrganiseBtn` itself
only toggles its intermediate dialog; it does not perform these resets.

Both host dialog offsets (`CMyShellDlg+0x108E30` and `+0x10519C`) are still unidentified, and the
bulletin getter `sub_7012AA` is not yet named — the checksum path does not depend on either, so
the blink is modelled without them.

### Not the blink flags

`dlg+0x18C` is `m_bItemAct` from `CDlgMain::PlayItemQUse` (`0x4BD901`, eosource
`MyShell/DlgMain.cpp:1226`), with `m_ActPnt` at `+0x184`/`+0x188`, `m_nActAmount` at `+0x190` and
`m_dwLastActTime` at `+0x194`. It drives the `ani/effect.ani` `ItemUse` overlay, not a button
blink. eosource's declaration order for the four `BOOL`s does **not** survive into 5517, so the
`m_bLevRead` / `m_bFactionRead` names from that header cannot be mapped onto `+0x104`/`+0x108`
by position; the mapping above comes from the producers instead.
