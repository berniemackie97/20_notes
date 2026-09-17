# CRadar — cell position to radar position

Verified in `Conquer.exe` 2026-09-06. TU proven by the assert string at `0x6275C1`,
`F:\CQ2ClientRelease-42.0.1\3DGameMap\Radar.cpp` line 756.

## Class shape (from the original headers)

`40_tools/fight-master/my_client/3DGameMap/Radar.h` and `40_tools/eosource/soul-code/3dgamemap/Radar.h`
carry the same `CRadar`:

```cpp
BOOL IsOnlyTeamMember(TeamMemberInfo* pInfo);
void LoadNpc();
void CellPos2RaderPos(CAni* pAni, CMyPos posCell, CMyPos& posRader);
void ShowBigMap(CMyPos posScr, OBJID idMap, CMySize sizeDlgBg);
void Show(CMyPos posScr, OBJID idMap, int nMode);
vector<NpcInfo> m_setNpcInfo;   // { OBJID idMapDoc; CMyPos posNpc; int NpcType; }
```

Both legacy bodies for `CellPos2RaderPos` are **empty** — signature only. Every behaviour below
is from the 5517 binary. 5517 also adds an `m_pEffect` member the legacy header lacks (CHECK
string at `0x6261EE`), and a fourth display mode; the legacy enum is `_MODE_128/256/512` = 0/1/2.

## Binja names

| Address | Name | Was |
|---|---|---|
| `0x62621C` | `CRadar_Show` | `CGameMap_RenderMiniMap` |
| `0x62759D` | `CRadar_CellPos2RaderPos` | `sub_62759D` |
| `0x626C9B` | `CRadar_DrawHeroMarker` | `sub_626C9B` |
| `0x626486` | `CRadar_DrawExpandedTiledView` | `sub_626486` |
| `0x6266AD` | `CRadar_DrawWindowFittedView` | `sub_6266AD` |
| `0x6268B9` | `CRadar_DrawTiledRightAlignedView` | `sub_6268B9` |
| `0x6263CE` | `CRadar_DrawSingleFrameView` | `sub_6263CE` |
| `0x6277EC` | `CRadar_TickZoomAnimation` | `sub_6277EC` |
| `0x51B707` | `CFlashHostDialog_MoveBesideMiniMap` | `sub_51B707` |
| `0x6E5E2C` | `CGameMap_GetDocId` | `sub_6E5E2C` |
| `0x626A1A` | `CRadar_BlitFrameClippedToWindow` | `sub_626A1A` |
| `0x6279CC` | `CRadar_DrawCellIconEffect` | `sub_6279CC` |
| `0x627AA1` | `CRadar_DrawFlagIconOverlay` | `sub_627AA1` |
| `0x969610` (data) | `g_RadarOriginOffsetX` | `data_969610` |
| `0x969614` (data) | `g_RadarZoomOffsetX` | `data_969614` |
| `0x969618` (data) | `g_RadarZoomOffsetY` | `data_969618` |

## Members touched by `CellPos2RaderPos`

| Offset | Member |
|---|---|
| `+0x04`, `+0x08` | mode-0 origin x, y |
| `+0x0C`, `+0x10` | scale x, y — 32-bit float |
| `+0x14` | mode |
| `+0x18`..`+0x24` | window rect: left, top, right, bottom |
| `+0x28`..`+0x34` | expanded rect: left, top, right, bottom |
| `+0x38`, `+0x3C` | collapsed anchor point |
| `+0x40` | zoom animation state |
| `+0x44` | `m_pEffect` — 5517 only |

## Algorithm

`__thiscall`, `retn 0x10`. `ebp+0x08` = `pAni`, `+0x0C` = cell x, `+0x10` = cell y, `+0x14` = out.

Null `pAni`: formats the current map id into a section name and fetches it from
`ani/MiniMap.ani` through `GameDataSetQuery()->vt[0x10](file, section, 0, 0x7530)`. A miss returns
without writing the out-param.

Shared prologue:

```
Map_ProjectTileToScreenCoordinates(gameMap, cellX, cellY, &screenX, &screenY)
CGameMap_GetProjectionCenterOffsetFromScreenPoint(gameMap, screenX, screenY, &bgX, &bgY)
CGameMap_GetGroundEntityLayerScaledBitmapExtents(&bgSize)
mode == 4 : aniW, aniH = pAni->GetSize(0)                     (vt+0x18)
mode != 4 : aniW, aniH = pAni->GetSize(3) + pAni->GetSize(0)  (component-wise)
```

**Watch the sense of this test.** It is `cmp dword [esi+0x14], 4 / jne 0x6276BE` at `0x627692`,
so **mode 4 is the fall-through** and takes the single-frame branch. That agrees with the
renderers: mode 4 draws frame 0 alone, while modes 0, 1 and 2 each tile frames 0-3.

`CGameMap_GetProjectionCenterOffsetFromScreenPoint` (`0x61E31C`) is just
`out = screenPoint - CGameMap_GetProjectionBaseCenterFromOffsets(...)`.

Then on `this+0x14`:

| Mode | Address | Result |
|---|---|---|
| 0 | `0x6277B2` | `x = ftol(bgX * scaleX) + originX`; `y = ftol(bgY * scaleY) + originY` — recomputes nothing |
| 1 | `0x627767` | `scaleX = (right-left)/bgW`; `scaleY = (bottom-top)/bgH`; `x = ftol(bgX*scaleX) + left`; `y = ftol(bgY*scaleY + top)` |
| 2, 4 | `0x627727` | `scaleX = aniW/bgW`; `scaleY = aniH/bgH`; `x = ftol(bgX*scaleX) + (GetScreenWidth() - aniW)`; `y = ftol(bgY*scaleY + top)` |

Mode 3 falls through the switch and writes nothing.

### Precision details that matter

- Every conversion is `_ftol` — truncation toward zero, never rounding.
- In modes 1/2/4 the vertical offset is added in floating point (`fiadd`) **before** the
  truncation. In mode 0 both offsets are added as integers **after**.
- The two axes do not use the same scale precision. `fst dword [esi+0xc]` stores the horizontal
  scale but keeps the x87 register, so the X multiply uses the **unrounded 80-bit** value; the
  vertical scale is `fstp`-ed and then re-read from the 32-bit field, so the Y multiply uses the
  **float32-rounded** value.

## Zoom animation — `CRadar_TickZoomAnimation` (`0x6277EC`)

`CRadar_Show` calls this **first** and abandons the whole draw when it returns zero, so the
animation gates the minimap rather than decorating it. It returns `CGameMap+0xF0`, the map's
radar-visible flag. This is the expand/collapse behaviour Preservation's client exposes as zoom
controls.

State on `+0x40`: `0` idle, `1` expanding, `2` collapsing. **Both states are tested in sequence**,
so a tick that finishes the expansion clears the state and the collapse check then does nothing.

```
midX = SignedHalf(expanded.left + expanded.right) ; midY = SignedHalf(expanded.top + expanded.bottom)
spanX = midX - anchor.x ; spanY = midY - anchor.y

state 1 (expanding)
  zoomX += 0x3C
  zoomY  = spanY * zoomX / spanX
  rect   = degenerate at the anchor
  InflateRect(rect, SignedHalf(expandedW * zoomX / spanX), SignedHalf(expandedH * zoomY / spanY))
  OffsetRect(rect, zoomX, zoomY)
  if (rect.left >= expanded.left || rect.top <= expanded.top):
      rect = expanded ; zoomX = zoomY = 0 ; state = 0

state 2 (collapsing)
  zoomX += 0x3C
  zoomY  = spanY * zoomX / spanX
  rect   = expanded
  InflateRect(rect, (expandedW * zoomX / spanX) / -2, (expandedH * zoomY / spanY) / -2)
  OffsetRect(rect, -zoomX, -zoomY)
  if (rect.left <= anchor.x || rect.top >= anchor.y):
      CGameMap+0xF0 = 0 ; state = 0 ; zoomX = zoomY = 0 ; rect = degenerate at the anchor
```

**Neither state accumulates.** Each tick rebuilds the rect from the anchor or the expanded rect
and applies the whole offset, so the two globals are the animation's only carried state.

The spans are divided by unguarded — an anchor exactly on the expanded rect's centre faults.

Managed: `10_work/src/Conquer/Map/Radar/CRadarZoomAnimation.cs`, tests in
`tests/Conquer.Tests/Client/Map/CRadarZoomAnimationTests.cs`.

## Mode 0 renderer — `CRadar_DrawExpandedTiledView` (`0x626486`)

`CRadar_Show` dispatches here at `0x6262FD`. This is the **only writer** of the `+0x04`/`+0x08`
origin and the `+0x0C`/`+0x10` scale that `CellPos2RaderPos` mode 0 reads back, which is why that
mode recomputes nothing.

Returns immediately unless `pAni->GetFrameAmount()` (vt `+0x14`) is exactly 4.

```
tiledW = GetSize(3).cx + GetSize(0).cx
tiledH = GetSize(3).cy + GetSize(0).cy
CGameMap_GetGroundEntityLayerScaledBitmapExtents(&bgSize)
CGameMap_GetPointAbsoluteFromProjectionCenter(map, SignedHalf(GetScreenWidth()),
                                              SignedHalf(GetScreenHeight()), &absX, &absY)
CGameMap_GetProjectionCenterOffsetFromScreenPoint(map, absX, absY, &bgX, &bgY)

scaleX  = tiledW / bgSize.cx          ; stays in st0, used unrounded
scaleY  = tiledH / bgSize.cy          ; fstp to a float32 local first
centreX = ftol(bgX * scaleX)          ; 80-bit scaleX
centreY = ftol(bgY * scaleY)          ; float32 scaleY
this+0x0C = (float)scaleX             ; stored only after both multiplies
this+0x10 = (float)scaleY

windowW = this+0x20 - this+0x18 ; windowH = this+0x24 - this+0x1C
viewX = centreX - SignedHalf(windowW) ; viewY = centreY - SignedHalf(windowH)
clamp below at 0, THEN above at tiledW-windowW / tiledH-windowH
this+0x04 = this+0x18 - viewX ; this+0x08 = this+0x1C - viewY
```

`CGameMap_GetPointAbsoluteFromProjectionCenter` (`0x61D8D1`) is just
`abs = projectionCenterScreen(+0x48/+0x4C) + point`.

The clamp order is load-bearing: a window wider than the tiled image makes the upper bound
negative, and the second clamp wins, so the origin lands past the window edge rather than at zero.

The four frames are then blitted through `sub_626A1A(this, pAni->GetFrame(i), x, y)` as a 2x2
tiling — frame 0 at the origin, frame 1 one `GetSize(0).cx` right, frame 2 one `GetSize(0).cy`
down, frame 3 at both offsets.

Managed: `10_work/src/Conquer/Map/Radar/CRadarExpandedViewLayout.cs`, tests in
`tests/Conquer.Tests/Client/Map/CRadarExpandedViewLayoutTests.cs`.

### The clipped blit — `CRadar_BlitFrameClippedToWindow` (`0x626A1A`)

`__thiscall`, `retn 0xC`: `(this, CMyBitmap* pFrame, int x, int y)`.

Reads the frame extents through `pFrame->vt[0x14](&w, &h)`, memcpy's the window rect from
`this+0x18`, then tests the **four corners of the window rect** against the frame's own rect
`[x, y, x+w, y+h]` — top-left, top-right, bottom-left, bottom-right — and emits a blit for the
**first** corner the frame contains, then returns. **One region per call**, not an intersection
assembled from several. All tests are inclusive on both bounds.

| Corner | Width | Height | Source origin |
|---|---|---|---|
| top-left | `min(frameRight - left, windowW)` | `min(frameBottom - top, windowH)` | `(left - x, top - y)` |
| top-right | `min(right - x, windowW)` | `min(frameBottom - top, windowH)` | `((right - x) - w, top - y)` |
| bottom-left | `min(frameRight - left, windowW)` | `min(bottom - y, windowH)` | `(left - x, (bottom - y) - h)` |
| bottom-right | `min(right - x, windowW)` | `min(bottom - y, windowH)` | `(0, 0)` |

Destination is `(g_RadarOriginOffsetX + srcX + x, srcY + y)`; the blit is
`pFrame->vt[0x08](dstX, dstY, &srcRect, w, h, 0xAA, 0, 0)`. Either axis collapsing to zero aborts
the call.

Two behaviours worth keeping:

- **Only the top-left branch writes `g_RadarOriginOffsetX`** (as
  `g_uiLayoutModeFlag ? -(x + srcX) : 0`). The other three read whatever the last writer left,
  normally the mode renderer that ran earlier in the frame.
- **The bottom-right branch stores the unclamped span in the source rectangle**
  (`right - x`, `bottom - y` at `0x626C76`/`0x626C7F`) while passing the clamped `w`/`h` as the
  blit size. The other three keep the two in step. They diverge only when the overlap exceeds the
  window on that axis.

Managed: `10_work/src/Conquer/Map/Radar/CRadarFrameClip.cs`, tests in
`tests/Conquer.Tests/Client/Map/CRadarFrameClipTests.cs`.

## Mode renderers 1, 2 and 4

All three set `g_RadarOriginOffsetX` (`0x969610`) with the `neg` / `sbb` / `and` mask idiom:
`g_uiLayoutModeFlag ? -baseX : 0`. Setting the flag cancels the mode's own horizontal placement
and puts the radar back at the left edge. This is the same global the role relationship-flag icons
offset by (`crole_class.md`).

### Mode 1 — `CRadar_DrawWindowFittedView` (`0x6266AD`)

Stretches the 2x2 tiling to fill the window rect. Requires exactly 4 frames.

```
tiledW = GetSize(3).cx + GetSize(0).cx ; tiledH = GetSize(3).cy + GetSize(0).cy
windowW = this+0x20 - this+0x18 ; windowH = this+0x24 - this+0x1C
leftW  = GetSize(0).cx * windowW / tiledW       ; imul, cdq, idiv
topH   = GetSize(0).cy * windowH / tiledH
rightH = GetSize(1).cy * windowH / tiledH
baseX  = this+0x18

frame 0 -> (origin + left,         top)        size (leftW,           topH)
frame 1 -> (origin + left + leftW, top)        size (windowW - leftW, rightH)
frame 2 -> (origin + left,         top + topH) size (leftW,           windowH - topH)
frame 3 -> (origin + left + leftW, top + topH) size (windowW - leftW, windowH - rightH)
```

Blit is `frame->vt[0x08](x, y, 0, w, h, 0x99, 0, 0)` — a stretch, alpha `0x99`.

### Mode 2 — `CRadar_DrawTiledRightAlignedView` (`0x6268B9`)

Same tiling at native size, flush right. Requires exactly 4 frames.

```
tiledW = GetSize(0).cx + GetSize(3).cx
baseX  = GetScreenWidth() - tiledW ; top = this+0x1C

frame 0 -> (origin + baseX,                 top)
frame 1 -> (origin + baseX + GetSize(0).cx, top)
frame 2 -> (origin + baseX,                 top + GetSize(0).cy)
frame 3 -> (origin + baseX + GetSize(0).cx, top + GetSize(1).cy)
```

Blit is `pAni->vt[0x08](frameIndex, x, y, 0x99, 0)` — on the animation, no extents, so each frame
draws at its own size.

### Mode 4 — `CRadar_DrawSingleFrameView` (`0x6263CE`)

Frame 0 alone, flush right. The only mode needing just one frame (`GetFrameAmount() >= 1`).

```
w, h  = GetSize(0)
baseX = GetScreenWidth() - w
frame 0 -> frame->vt[0x08](origin + baseX, this+0x1C, 0, w, h, 0xAA, 0, 0)
```

Alpha is `0xAA` here against `0x99` in modes 1 and 2.

### A shared quirk

Modes 1 and 2 both take the left column's second-row offset from frame 0 and the right column's
from frame 1, so the two rows only line up when those frames share a height. Native does not
reconcile them.

Managed: `10_work/src/Conquer/Map/Radar/CRadarViewLayouts.cs`, tests in
`tests/Conquer.Tests/Client/Map/CRadarViewLayoutsTests.cs`.

## Icon placement

Two shapes, both starting from `CellPos2RaderPos`.

### 3D effect icons — `CRadar_DrawCellIconEffect` (`0x6279CC`)

`(this, cellX, cellY, char const* sectionName, CAni* pAni)`.

5517 draws named minimap icons as **3D effects**, not 2D blits — this is what the 5517-only
`m_pEffect` member at `+0x44` is for (CHECK string at `0x6261EE`). The effect is created lazily
with `Game3DEffectCreate(0)`; the section resolves through vt `+0x60` (exists?) then vt `+0x64`
(fetch) or vt `+0x10(section, 1)` (create).

```
CellPos2RaderPos(pAni, cellX, cellY, &radar)
radar.x += g_RadarOriginOffsetX                  ; X only — Y is untouched
CGameMap_GetPointAbsoluteFromProjectionCenter(map, radar.x, radar.y, &absX, &absY)
CGameMap_GetProjectionCenterOffsetFromScreenPoint(map, absX, absY, &bgX, &bgY)
CGameMap_BuildGameCameraFromScreenDimensions()
m_pEffect->vt[0x0C](bgX, bgY, effect)
CGameMap_BuildGameCameraFromScaledViewportDimensions(map)
```

The absolute/offset pair is a real round trip, not a no-op: it re-expresses the radar-space point
in the projection-offset space the effect renderer draws in, and the camera is swapped to the
screen-dimension basis for the draw.

`CRadar_DrawFlagIconOverlay` (`0x627AA1`, called from `CRadar_Show` at `0x62632B` when bit
`0x80000000` of the map flag word at `+0xE8` is set) feeds it sections `"minmapflag"`,
`"MiniMapWarFlagMySynOccupy"` and `"bhitstsmle"`. Those names are the only evidence for what the
icons mean, so the function names stay generic. 5517 has **no `"TransPoint"` string at all** — the
legacy transit-point icons are gone.

### 2D hero marker — `CRadar_DrawHeroMarker` (`0x626C9B`)

Reads the hero cell pos, calls `CellPos2RaderPos`, fetches the `"hero"` section of
`ani/MiniMap.ani`, picks frame `(timeGetTime() / 30) % frameCount`, and draws its top-left at:

```
(g_RadarOriginOffsetX + radar.x - SignedHalf(frameW), radar.y - SignedHalf(frameH))
```

Again the origin offset lands on X only. `g_RadarOriginOffsetX` is `0x969610`, the same global
`crole_class.md` records the relationship-flag icons offsetting by.

Managed: `10_work/src/Conquer/Map/Radar/CRadarIconPlacement.cs`, tests in
`tests/Conquer.Tests/Client/Map/CRadarIconPlacementTests.cs`.

## Managed implementation

`10_work/src/Conquer/Map/Radar/CRadarCellPositionProjection.cs`, tests in
`tests/Conquer.Tests/Client/Map/CRadarCellPositionProjectionTests.cs`.

The x87 80-bit intermediate is modelled as `double`; the float32 field stays `float`, so the
axis asymmetry is preserved. Managed reuses the existing
`CGameMapPositionedOverlayMathRuntime.ProjectTileToScreenCoordinates` and
`GetProjectionBaseOffsetFromAbsoluteScreenPoint` for the prologue.

Not yet reconstructed: nothing in `CRadar` itself. What remains around it is the effect-object
side of `CRadar_DrawCellIconEffect` (the `Game3DEffect` vtable it drives) and the two cell lists
`CRadar_DrawFlagIconOverlay` walks.
