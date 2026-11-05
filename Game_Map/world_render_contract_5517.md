# World render contract (5517, Newbie Village MapDataId 1010)

Binja-verified 2026-10-31 on clean `Conquer.exe` (HLIL + disassembly). Consolidates and corrects
[cgamemap_class.md](cgamemap_class.md) and [Rendering/05](../Rendering/05_dmap_positioned_overlay_system.md).
Evidence dumps: `Rendering/evidence/world-rendering-2026-10-31/` (camera-depth, scenery, animation, assets).
Integer `/` below = C `idiv` (truncates toward zero). `SW/SH` = `CMyBitmap::GetScreenWidth/Height`.

## 1. Camera and projection

### Constants and fields

| Item | Value / meaning | Anchor |
|---|---|---|
| `data_93C6C0` | 256 (read-only; no writer) | xrefs |
| map `+0x140` scale | 256 (ctor `SetProjectionScaleAndViewport(data_93C6C0)`) | `0x61BBCD` |
| map `+0x154` zoom % | 100 (ctor `0x61BBBB`); changed by `ApplyProjectionScaleOscillation` | `0x61BBBB` |
| `div` | `(+0x154 * +0x140) / 100` = 256 by default | `CGameMap_GetProjectionClampScaleDivisor` `0x61EDC3` |
| `viewW/viewH` `+0x14C/+0x150` | `SW*256/div`, `SH*256/div` (each map tick) | `0x61D4A6..0x61D4DE` |
| `+0x2C/+0x30` | grid W, H (cells) | `0x61D955` |
| `+0x40/+0x44` | projection origin = `W*32`, `16` | `0x61D965`, `0x61D96C` |
| `+0x34/+0x38` | world extent `W*64`, `H*32` | `0x61D980` |
| `+0x48/+0x4C` | projection center = world px of viewport top-left | `0x61E300` |
| `+0x54/+0x58` | edge-scroll offset | `0x61E11E..0x61E179` |
| `+0x13C` | world color ARGB, default `0xFFFFFFFF` (`0x61BAF5`), timed blend `0x61FC13` | |

Default zoom ⇒ `div = 256` ⇒ every "scaled" formula below is identity.

### Formulas

| Step | Formula | Function |
|---|---|---|
| tile → world px | `x = (tx−ty)*64/2 + W*32`, `y = (tx+ty)*32/2 + 16` | `Map_ProjectTileToScreenCoordinates` `0x61D850` |
| role world px | `role+0x350/+0x354` (tile projection + motion interpolation) | `0x65185D` (CRole vfunc `+0x10`), [crole_class](../Entity_System/crole_class.md) |
| frame input | `vx = heroX + SW/(−2)`, `vy = heroY + SH/(−2)` (= hero − half screen) | `Exe_TickMapProjectionAndDispatchMapRender` `0x5ACAE8/0x5ACAF7` |
| ground base (world px of puzzle top-left) | `baseX = W*32 − PW/2`; `baseY = 16 + (H*32)/2 − PH/2 − ((H+1)%2)*32/2` | `0x61E375` |
| center | `cx = vx + off54`, `cy = vy + off58`, then clamp (below) | `0x61E0E7` |
| clamp X | `baseX − (SW−viewW)/2 ≤ cx ≤ baseX + PW − SW + (SW−viewW)/2` (upper applied first) | `0x61E281..0x61E2C4` |
| clamp Y | same with `SH`, `viewH`, `PH` | `0x61E294..0x61E2F8` |
| world → screen | `sx = wx − cx`, `sy = wy − cy` | `CGameMap_GetPointRelativeToProjectionCenter` `0x61D762` |
| zoom around viewport centre | `p' = div*(p − S/2)/256 + S/2` (S/2 = `S/2` truncated) | `CGameMap_ApplyProjectionScaleAroundViewportCenter` `0x61F0BD` |
| component render offset | `(cx − baseX, cy − baseY)` passed to each component `vfunc+4` | `0x61E3D8` |
| 3D camera | `GameCameraSet(SW*0.5 + cx − baseX, SH*0.5 + cy − baseY, −1000, 3)`; render pass `GameCameraBuild(viewW, viewH)` | `0x61E6C6`, `0x620920` |
| world → scaled screen (UI) | `SW*(wx − (cx + (SW−viewW)/2))/viewW` | `0x61D77F` |

PW/PH = ground puzzle `tileCount*256` (`CMapPuzzleBitmap_GetScaledBitmapDimensions` via `0x61E408`).
Newbie: W=H=132, `newbie.pul` 15×9 ⇒ PW=3840, PH=2304 ⇒ baseX = 4224−1920 = 2304, baseY = 16+2112−1152−16 = 960.

### Edge scroll (normally off)

Enabled only when `VK_MENU` high bit **and** `g_projectionEdgeScrollEnabled` (`data_958640`) **and** not
`Role_HasStatusFlag(hero, 0x3C)`. Cursor = `Exe_GetCachedCursorSample`.

| Zone | Update |
|---|---|
| `cursorY ≤ 120` | `off58 += cursorY/20 − 6` |
| `cursorY ≥ SH−170` | `off58 += 6 − (SH−50−cursorY)/20` |
| `cursorX ≤ 120` | `off54 += cursorX/20 − 6` |
| `cursorX ≥ SW−120` | `off54 += 6 − (SW−cursorX)/20` |
| clamp | `off54 ∈ ±256*356/div`, `off58 ∈ [−256*172/div, 256*192/div]` |

Offsets persist (not reset when Alt released). Then `ApplyProjectionOffsetOscillation` (`0x61FB26`),
`…ScaleOscillation` (`0x61FB93`), `…ColorBlend` (`0x61FC13`) run before the centre commit.

## 2. Scenery activation and visibility

Scenery component (type 3, `CMapSceneryComponent`, vtable `0x86A258`): loaded list `+0x34`, active render deque `+0x74`.

| Phase | Behaviour | Anchor |
|---|---|---|
| tick start | clear active deque `+0x74`; iterate a copy of the loaded list | `0x6353A9`, `0x6353B5` |
| per child | dispatch tick by type code (vfunc `+0xC`): 1→`tick(null)`, 4→`tick(heroPos)` (unused by callee), 5/other→`tick(null)`, 6/7→`tick(arg)`, 9→`tick(0)`, 0x0A/0x0E/0x11→`tick(&outFlag)`, 0x13→`tick(arg)` | `0x6353FC..0x635478` |
| expiry | `CMapSceneryComponent_DetachAndRemoveSubcomponent` (removes from active deque, type-2 parents and loaded list) for 9 if `+0x28≠0`; 0x0A/0x0E/0x11 if outFlag≠0; 0x13 if `C3DEffectNew_IsOver` (`0x733041`, byte `+0x448`) | `0x6354D6`, `0x6355E9` |
| activation | a child inserts **itself** each tick when visible: `CGameMap_NotifySceneryComponentSubcomponentUpdated` → `CMapSceneryComponent_ReorderSubcomponentForDepth` | `0x61E74B`, `0x635AE6` |
| render | for each active child: `vfunc+0x2C(map+0x13C)` (color) then `vfunc+4(0)` | `0x6352F4` |

Callers of the notify (who can appear in the active deque): terrain objects (`.scene`), type-04 ANI scenery,
type-0A effects, type-04-record child type-3 overlays, `CRole_Tick` (`0x64F505/0x64F5BA`),
`Role_TickCommandStateAndDispatchPlayback` (`0x672772/0x672830`), `C2DMapItemObj_Process` (`0x6404E9`, type 11, margin 8, effect step every 500 ms), `C3DMapSimpleObj_Process` (`0x64CB26`, type 9, skipped once `+0x28` dead), `C3DTraceObj_Process` (`0x7CAFB1`, type 14).
Roles conform to the child interface: CRole vfunc `+0xC` type = `role+0x360`, `+0x10` world px, `+0x14` tile
(`+0x318/+0x334`, XTEA), `+0x18` set tile.

Visibility test `CGameMap_IsTileWithinScaledScreenBoundsWithMargin(tx, ty, m)` (`0x61E00D`):

```
mx = (256*m << 6)/div ; my = (256*m << 5)/div
(px,py) = project(tx,ty)
visible = cx−mx ≤ px ≤ cx+SW+mx  &&  cy−my ≤ py ≤ cy+SH+my
```

| Child | Tile tested | Margin `m` | Anchor |
|---|---|---|---|
| terrain object | own tile | 8 | `0x644B8F` |
| type-04 ANI | (a) screen point − renderOffset projected back to tile (clamped), (b) own tile — both must pass | `max(+0x50,+0x54)`; ctor 30, then `(div*frameW/256)/64+9`, `(div*frameH/256)/32+9` once cached (`+0x4C` flag) | `0x645545`, `0x64561B`, `0x6455D3` |
| record child type-3 | own tile | 8 | `0x64B615` |
| type-0A effect | projected tile | `ini/MapEffectExtent.ini[path]`, default 8 | `0x63B33A` |

## 3. Render and depth order

### Map frame

1. `CGameMap_TickComponentsAndProcessScreenEffects` (`0x61D415`): queues, timers, effect managers, then each
   component `vfunc+8(0)` in deque order, viewport update, `ProcessScreenEffects`.
2. `Exe_TickMapProjectionAndDispatchMapRender` (`0x5ACAC3`): projection/camera (§1), earthquake, then
   `CGameMap_RenderComponentsAndShowScreenEffects` (`0x61D1F5`).

### Component deque order

Default appended types `[1 ground, 2, 6 no-op, 3 scenery, 5 weather]`; DMap type-4 records are inserted at their
file insert index (`0x61DF93`). Newbie has one record at index 0 ⇒ draw order:

| # | Component | Draws |
|---|---|---|
| 1 | type-4 record (insert 0), parallax 18%/35% | child 8: `map\puzzle\newbiebg.pul` background puzzle |
| 2 | type 1 ground/entity layer | `.pul` mode: ground puzzle `newbie.pul` (`CMapPuzzleBitmap_RenderAtOffset(+0xA0, baseX−cx, baseY−cy)`); else terrain cache; then blast traces, cartridge cases (`0x638E44`) |
| 3 | type 2 `CFloorLayer` (eosource `LAYER_FLOOR`) | `CRoseSys_Show` (`0x648060`, Rose.cpp), `CPatternRoseSys_Show` (`0x646CE9`, PatternRose.cpp), then floor objects (`CFloorObj`, ANI with lifetime) `vfunc+4(0)`; empty unless a rose event/floor obj exists |
| 4 | type 6 | no-op |
| 5 | type 3 scenery | active deque in depth order (terrain objects, type-04 ANI, roles, overlays, effects) |
| 6 | type 5 `CSkyLayer` | fireworks, letter fireworks, `sub_62db92`, air bubbles, child list `+0x6AC` |

Then (same render call): `CEntityRegistry_TickEntitiesAndUpdateState(&g_objPlayerSet)`, floating text, boss life,
radar (`+0xF0`), hero arrow durability, party HP bars, syndicate overlay, region name, timed countdown,
`CGameMap_ShowScreenEffects` (`0x61D26C..0x61D305`).

### Depth insertion (`0x635AE6`)

`tile(E)` = vfunc `+0x14`; `span(E)` = vfunc `+0x1C` or `(1,1)` (`CGameMap_GetType3SubcomponentDepthSpanOrDefault` `0x61E0BC`);
`s(E) = x+y`. `xov(A,B)`: `[Ax−Aw+1, Ax]` ∩ `[Bx−Bw+1, Bx]` ≠ ∅ (same for y with h).

```
if N.type != 2:
    for E in active: if E.type == 2 and E.footprint contains tile(N): E.InsertChildForDepth(N); return
cursor = -1
for i, E in active:
    if xov(N,E):
        if N.y < E.y: backward_insert(i); return
        cursor = i; for j > i: if s(active[j]) != s(E) and s(N) <= s(active[j]): break; cursor = j
    if yov(N,E):
        if N.x < E.x: backward_insert(i); return
        cursor = i; same forward scan
backward_insert(i): pos = i; for k = i-1 .. 0: if s(active[k]) != s(E) and s(N) >= s(active[k]): break
                                               if k <= cursor: break; pos = k
                    insert N at pos
after loop: cursor == -1 -> insert before first E with s(N) < s(E), else push back
            else insert at cursor+1 (push back if cursor is last)
```

**Verified on disassembly `0x635BCF..0x635FB8` (2026-10-31) — corrections to the pseudocode above:**
- x-overlap and y-overlap are `if / else if`: after the x-overlap branch (insert or forward scan) the loop goes to
  the next `i` (`jge/jle 0x635D78`); the y test runs only when x does not overlap (`jg 0x635CED`).
- main loop does not null-check `E` (`0x635C1F`); forward/backward scans and the fallback skip null entries without
  moving the cursor/pos.
- forward scan: `s(Ej)==s(E)` ⇒ `cursor=j`; else `s(N) <= s(Ej)` ⇒ stop; else `cursor=j`.
- backward scan from `i−1`: null ⇒ skip; `s(Ek)!=s(E) && s(N) >= s(Ek)` ⇒ stop; `k <= cursor` ⇒ stop; else `pos=k`. Insert at `pos`, return.
- end: `cursor == −1` ⇒ insert before first non-null `E` with `s(N) < s(E)`, else push back; otherwise insert at
  `cursor+1`, or push back when `cursor ≥ size−1`. Counts compare unsigned.

Type-2 parents = terrain objects (`.scene` entries; vfunc `+0xC` returns 2):

- footprint: `ax−w < x ≤ ax`, `ay−h < y ≤ ay` (anchor `+0x0C/+0x10`, grid `+0x1C/+0x20`) (`0x644E0F`)
- `InsertChildForDepth` (`0x644BB3`), child list `+0x88`, per existing child C:
  x-overlap ⇒ insert before C if `N.y < C.y`; else y-overlap ⇒ before C if `N.x < C.x`; else before C if
  `s(N) < s(C)`; none ⇒ push back.
- children render right after the object (`0x6446A7..0x64471D`), each with `vfunc+0x2C(map+0x13C)`, then the
  child list is cleared every render (`0x644722`).

### DMap type-4 record render (parent `CGameMapFileRecordType04_Render` `0x6399C6`)

```
pcx = cx + SW/2 ; pcy = cy + SH/2          (>>1 rounding toward zero)
hw = (W*64)/2 ; hh = (H*32)/2
rootX = int0*(pcx−hw)/100 + hw + SW/(−2) ; rootY = int1*(pcy−hh)/100 + hh + SH/(−2)
ctx = {rootX, rootY, _, _, int0, int1}; each child vfunc+4(&ctx)
```

Child 8 puzzle (`0x64B848`): `RenderAtOffset(+0x20, −(rootX − (hw − bmpW/2)), −(rootY − (hh − bmpH/2)), 0, 0)`.
Child 3 ANI (`0x64B48F`) ignores `ctx`.

## 4. `.scene` resources (type-1 scenery groups)

DMap type-1 payload `0x10C`: path `char[0x104]` → `+0x48`, anchor tile X/Y → `+0x0C/+0x10` (`0x63F58E`).
`CMapTerrainObjectGroup_LoadTerrainObjectListFromPath` (`0x63F24D`) `fopen(path,"rb")`:

| Off | Size | Field (`CMapTerrainObject`, `0xB0` bytes) |
|---|---:|---|
| 0 | 4 | object count (file header) |
| per object | `0x100` | ANI path → `+0x34` |
| | `0x40` | ANI section → `+0x28` |
| | 4+4 | render offset X/Y → `+0x14/+0x18` (added to screen point) |
| | 4 | frame interval ms → `+0x40` (ctor 200; 0 ⇒ 1 at draw) |
| | 4+4 | grid w/h → `+0x1C/+0x20` (vfunc `+0x20`; ctor 2×2) |
| | 4 | ARGB → `+0x24` (stored; draw color is `+0x08`) |
| | 4+4 | anchor offset X/Y → `+0x48/+0x4C` |
| | 4 | draw parameter → `+0x44` (not passed by `CMapTerrainObject_Render`) |
| | `12*w*h` | cells, row-major (y outer, x inner): dword1→`+6` passability, dword2→`+4` surface, dword3→`+8` elevation delta (low 16 bits) |

Object size = `0x164 + 12*w*h` (`0x100+0x40+9*4`; corrected 2026-11-01, earlier `0x144` was an arithmetic slip) (Newbie `stand01` 4×4 = 548). Object tile = group anchor + anchor offset
(`0x63F4D3`). Cells also attach to map tiles (passability/surface/elevation) at load (`0x6355C3`).

Render (`CMapTerrainObject_Render` `0x64450F`):

```
ani = Query(+0x34, +0x28, 0, 30000)
frame = ((now − +0x84)/+0x40) % frameCount      (+0x84 = timeGetTime at construction)
(sx,sy) = project(tile) − (cx,cy) + (+0x14,+0x18) ; zoom around centre
SetColor(A,R,G,B of +0x08)   (+0x08 = map+0x13C each scenery render; ctor 0xFFFFFFFF)
DrawSubRect(sx, sy, 0, div*fw/256, div*fh/256, 0, 0, 0)
then adopted children (§3)
```

## 5. Animation, transparency, blending

| Element | Frame | Timer origin | Interval source |
|---|---|---|---|
| ground/overlay puzzle | `+0x08 % count` of ANI section `Puzzle%d` | `+0x0C` | `ini/Info.ini` `[PuzzleBmp] FrameIntervalMilliSec` (default 1000) → `data_969A40`; `+0x08` += 1 once per render call when `now−+0x0C ≥ interval` |
| terrain object | `((now−+0x84)/+0x40) % count` | construction | `.scene` field |
| type-04 ANI | `((now−+0x44)/+0x40) % count` (tick, only while visible) | construction | DMap field (Newbie 100) |
| record child type-3 | `((now−+0x3C)/+0x38) % count` | construction | DMap field |

Puzzle tile render (`CMapPuzzleBitmap_RenderAtOffset` `0x63A04B`):

- scroll only when `+0x128` or `+0x12C` ≠ 0 **and** `+0x140` ≠ 0: `off += (+0x138*elapsed*velX)/100000` mod `scaledW`
  (Y: `+0x13C`, `+0x12C`, `scaledH`), `elapsed = now − +0x134`. Newbie puzzles are `PUZZLE` (no scroll).
- `T = +0x124` (256), `S = div*T/256`; `tile0 = −(off/T)`, −1 more when `off > 0`.
- window: column end `800/S + 3`, row end `600/S + 3`, start 0. `S ≠ T`: ends += `800/T − 800/S` (rows `600/T − 600/S`);
  `S < T` additionally starts at −1 and ends += 1. Fixed 800×600 regardless of window size (`0x63A162..0x63A1EC`).
- tile `(c+tile0, r+tile0y)`, wrapped into the grid only while scrolling; `0xFFFF` index = empty.
- position `(T*c + T*tile0 + offX, T*r + T*tile0y + offY)`, then zoom around centre; size `S×S`.
- color `map+0x13C`; ANI mode 1, timeout 20000; draw via ANI `vfunc+0xC(frame, x, y, 0, S, S, 0, 0)`.
- `CMapPuzzleBitmap_PreloadVisibleTileResources` (`0x63A7E0`) requests one extra tile ring first.

Blend (C3 `Sprite_Draw`, [c3_core_dll/02](../Rendering/c3_core_dll/02_sprites.md)): mode 0 = SRCALPHA/INVSRCALPHA.
Type-04 ANI passes draw parameter `+0x48` (ctor 0; not read from the DMap); terrain objects, puzzles and record
type-3 overlays pass 0. Color = `map+0x13C` (white unless a timed blend runs); frame `vfunc+0x20` takes
`(A,R,G,B)`.

## Layer and object type codes (eosource `MapLayer.h`, `MapObj.h`; matches native)

Layers: 1 TERRAIN (ground), 2 FLOOR, 3 INTERACTIVE (scenery), 4 SCENE (DMap type-4 parallax record), 5 SKY
(`CWeather_Show` `0x62DB92` at `+0x0C`, fireworks, letter fireworks, air bubbles), 6 SURFACE (no-op).
Interactive object type codes (native vfunc `+0xC` = eosource `MapObj.h` enum, confirmed by vtable getters
`push 0x0B/0x09/0x0E` at `0x640592`/`0x64CCE2`/`0x7CAFAD`): 1 TERRAIN (`.scene` group), 2 TERRAIN_PART (`.scene`
object, type-2 parent), 3 SCENE, 4 COVER (DMap type-04 ANI), 5 ROLE, 6 HERO, 7 PLAYER, 8 PUZZLE, 9 3DSIMPLE,
10 3DEFFECT, 11 2DITEM (ground item), 12 3DNPC, 13 3DOBJ, 14 3DTRACE, 15 SOUND, 16 2DREGION, 17 3DMAGICMAPITEM,
18 3DITEM, 19 3DEFFECTNEW. Roles/hero/players live in the scenery list and tick there
(native dispatch 6/7 → `tick(arg)`, 5 → `tick(null)`), then `CRole_Tick` (`0x64F464`) notifies when the role tile
passes `IsTileWithinScaledScreenBoundsWithMargin(.., 2)`.

Native colours **every** active child with `map+0x13C` (`0x63533F..0x63534F`, no type test); eosource's
role/puzzle/effect white exception is not in 5517.

Scenery tick set: `+0x34` is a spatial index (`CMapSceneryObjIndex_*`), not a flat list.

| Step | Behaviour | Anchor |
|---|---|---|
| insert | `CMapSceneryObjIndex_Insert` (`0x6414C2`): key = `Map_ProjectTileToScreen(tile)/256` (signed idiv) per axis; unbucketed types get `(0x7FFFFFFF,0x7FFFFFFF)` | `0x641C76` |
| unbucketed types | `CMapSceneryObjIndex_IsUnbucketedType` (`0x641352`) true for every type **except** 3,4,8,9,11,13,14,15,16,17,18 (so 1,2,5,6,7,10,12,19 roam); those are also appended straight to the current result deque `+0x18` | `0x64156F..0x641578` |
| bucketed insert | appended to bucket deque, then `InvalidateViewportCache` (`+4/+8 = 0x80000000`) | `0x641581` |
| remove | `CMapSceneryObjIndex_Remove` (`0x6415A6`): erase from its bucket and from `+0x18` | |
| collect | `CMapSceneryObjIndex_CollectViewportBuckets` (`0x641D2C`): `bx0 = (+0x48 + SW/2)/256`, `by0 = (+0x4C + SH/2)/256`; if unchanged from cache, reuse `+0x18`; else clear `+0x18`, then for `bx` in `[max(bx0−r,0), bx0+r]` (outer, ascending), `by` in `[max(by0−r',0), by0+r']` (inner, ascending) append that bucket in insertion order, then append the unbucketed bucket; `r=(SW/256+3)/2`, `r'=(SH/256+3)/2` (1024×768: 3, 3) | |
| tick | scenery `PerFrameTick` iterates that copy in order (§2); each visible child inserts itself into `+0x74` (§3), so equal depth ties resolve by this order | `0x6353B5` |

Static types far from the view are not ticked at all (no frame advance, no activation); roaming types are always ticked.

Role 3D placement (confirmed): `Role_TickAndRender` passes `roleWorld − base`
(`CGameMap_GetProjectionCenterOffsetFromScreenPoint` `0x61E31C`) to RoleView; the 3D camera sits at
`SW/2 + (cx − baseX)` (§1), so a role lands at screen `roleWorld − centre`, the same space as 2D sprites
(vertical action terms and scale: [Rendering/06](../Rendering/06_hero_render_pipeline.md)).

Record child type-3 double draw: both static paths exist (type code 3, span (1,1) via `0x641307`). The scenery
tick clears `+0x74` first and component ticks run in deque order, so a record inserted **before** the scenery
component has its child's insertion wiped ⇒ drawn once (record pass); a record inserted after it would also be
drawn by the scenery pass. Retail data never reaches either case: all 192 clean-install DMaps (181 loose + 11 archive-only, each parsed to
its last byte, 2026-11-01) contain no type-4 record child of type 3 — only type-8 puzzle children. No runtime check needed.

## Corrections to earlier notes

| Earlier claim | Correct |
|---|---|
| `centerX = heroX + SW/2` (cgamemap_class) | `heroX + SW/(−2)` = `heroX − SW/2` (`idiv` by `0xFFFFFFFE`) |
| type-3 tick post-branch `0x6354D6` inserts into active render deque | it removes expired children; activation is the child's own notify |
| subtype 0x04 "always enters active-render helper at 0x6354D6" | never; type 04 activates through `0x645625` when visible |
| `CMapType3Component_AppendType11SubcomponentPointer` | generic shared-ptr deque push back → renamed `StdDequeSharedPtr_PushBack` (`0x634D81`) |

## Open / blocking

None for Newbie 1010. Residual, non-blocking:

| Item | Status |
|---|---|
| `+0x148` (viewport rect sync `0x61D51A`) | not world-render relevant |
| Each record child type-3 render call draws twice (frame `+8` subrect, then ANI `+8`) | unreachable in retail data (above) |
