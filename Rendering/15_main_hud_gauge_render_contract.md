# Main HUD gauge rendering contract

GFX-UI-002; clean English PC 5517; native verification 2026-09-24.
Scope: Progress40 HP, Progress41 MP, Progress46 stamina, Progress47 overflow.
No managed implementation is evidence. No production implementation changed.

[Native captures, assets and instruction replays](../../10_work/docs/evidence/gfx-ui-002-main-hud-gauges-5517/README.md)
contain the full disassembly/MLIL/HLIL behind the excerpts below. Bare addresses
are Conquer.exe; DLL addresses always require the stated module.

## Conclusions and limits

- **Proven:** Progress47 source bottom 35 is not clipped to the 32-pixel image.
  It becomes texture V `35/32 = 1.09375`. The native sprite submission is a
  four-vertex triangle strip, not a Direct3D source-RECT blit. Normal native
  addressing is **WRAP**, with point min/mag filtering and no mip filter.
- **Proven draw-frame sets:** HP `{0,1,2}`, MP `{0,1,2}`, stamina `{0}`, overflow
  `{0}`. All four have overlay mode 0. Subvariant 1 draws cropped **frame 2**;
  it is not the normal 0/1 path with a different width.
- **Proven failure behavior:** an ordinary failed ANI/image creation skips the
  affected gauge; its caller continues subsequent gauges and Dialog4.
  Native ANI creation nevertheless eagerly requires every listed image, even
  frame 1 of stamina/overflow which these HUD objects never request for drawing.
- **Proven conditional placement:** font-unit calibration, not screen mode,
  controls the scaling branch. Baseline origins are tabulated below; the
  executable does not fix the OS's actual `MapDialogRect` result.
- **Not established by a live measurement:** the rendering thread's x87 control
  word, the OS font-unit result, or an actual driver's texture allocation.
  These are not silently assumed. The native instructions and exact conditional
  results are recorded below. No claim of complete live framebuffer parity.

## Objects, initialization, overlays and writer census

| Gauge | CDlgMain offset | Shell offset (`+0xF98`) | Init call | Geometry `(w,h,altW)` | Show call | Requested frames |
|---|---|---|---|---|---|---|
| Progress40 | `+0x13F6A0` | `+0x140638` | `0x4BB8D0` | `(36,74,86)` | `0x4BC455` | 0, 1, 2 |
| Progress41 | `+0x13F618` | `+0x1405B0` | `0x4BB908` | `(34,74,34)` | `0x4BC48F` | 0, 1, 2 |
| Progress46 | `+0x13C308` | `+0x13D2A0` | `0x4BB9B9` | `(8,70,8)` | `0x4BC4C2` | 0 only |
| Progress47 | `+0x13C280` | `+0x13D218` | `0x4BB9F1` | `(8,35,8)` | `0x4BC517` | 0 only |

All four Init calls pass `min=0,max=100,style=0,overlayMode=0,offX=0,offY=0`.
Raw pushes start with ESI zeroed at `0x4BB88F`. These initial ranges are placeholders;
the established per-frame range updates still apply. In Init, `0x5A9869`
stores overlay mode at `+0x4C`; `0x5A986C` bypasses offset writes when it is zero.
Consequently the zero offset arguments are **unused**, not proof that storage
`+0x50/+0x54` has been initialized to zero. Overlay-before mode 2 draws frame 1
at `0x5A90B8`; overlay-after mode 1 draws frame 1 at `0x5A977A` after the
`0x5A9726/0x5A972A` test. Neither path applies to these four instances.

Constructor `0x5A8F86` clears `+0x84` at `0x5A8FB5`. Setter `0x5A9A60`
contains `mov byte [ecx+0x84],al` at `0x5A9A64`. The complete eight direct
setter xrefs, with no data references, resolve as follows:

| Call address | Actual receiver | Value / condition |
|---|---|---|
| `0x4BB92E` | HP | 1 at HUD initialization; arms dialog `+0x100` |
| `0x4BD612` | HP | 0 when pending flag and `min(currentMana,effectiveMaxMana)>0`; clears flag at `0x4BD632` |
| `0x5C39E6` | MP, shell `+0x1405B0` | 1, window command `0x40B` in message `0x464` |
| `0x5C39FE` | same MP | 0, command `0x40C` |
| `0x4BCD09` | Progress42 skill | 2; outside this slice |
| `0x4BCD2C` | Progress42 skill | 0; outside this slice |
| `0x5C3A6A` | Progress42 skill | 0; outside this slice |
| `0x4BE18D` | Progress42 skill | 1; outside this slice |

HP transition runs in `CDlgMain_UpdateGaugeRangesFromHero` before Show, so frame 2
is possible during the zero-mana startup state but is not guaranteed to appear
on every login. Positive current HP/mana with a lagging follower reaches normal
frame 1, then frame 0. MP variant 1 has a real producer: `0x6F5FF1` starts a
hero timer and posts `0x40B` at `0x6F6029`; `0x6F604F` clears it and posts
`0x40C` at `0x6F605D`. Call `0x6F836F` follows a learned-magic predicate at
`0x6F830E`; `0x6F7DC7` checks effect parameter `0xD == 0x28` at
`0x6F7DEC/0x6F7DF4`. This is executable command flow, not inference from MPH.dds.
No new gameplay label is assigned to that magic category here.

The clean-byte census records 42 explicit references to these four object bases,
including shell-relative references, constructor/destructor/unwind paths, DDX,
Init, range/geometry setters, Show and status-hint getters. The constructor
calls at `0x4B5E1C/0x4B5E2B/0x4B5E76/0x4B5E85` initialize overflow/stamina/MP/HP.
Eight unwind stubs destroy the widgets; they are not subvariant setters.
The byte-write scan finds only CMyProgress constructor/setter and two unrelated
CMyButton writes; no direct rebased gauge-byte write. A separate wider-write
candidate census and function receiver review does not add a CMyProgress writer.
These are bounded instance/call/xref checks, not a claim that matching offsets
on other classes identify the same member.

Stamina Show loads one value twice. Overflow is gated by extended-force status
and force>=100, resets range to `(0,50)`, then passes force-100 twice. Equal
arguments cannot reach the dual-fill frame-1 branch. Neither instance receives
subvariant 1/2 nor an overlay mode, so its frame 1 is outside the draw closure.

## Exact style-0 submissions

Let `X,Y` be parent origin plus stored control origin, `h=+0x68`, `w=+0x60`,
`a=+0x64`, `r=float32(+0x6C)`, `c=float32(+0x70)`. Both input values are
upper-clamped to the signed maximum at `0x5A9047/0x5A904F` (no lower clamp).
`T` below denotes `_ftol` truncation after the native x87 expression; preserving
only the algebra does not settle intermediate-precision differences.
`v` is current and `f` is follower after the clamp.

| Branch | Draws in order: frame; source RECT; destination `(x,y,width,height)` |
|---|---|
| Variant 0, `v<=f`, `v!=0` | `0; (0,h-T(v*r),w,h); (X,Y+h-T(v*r),w,T(v*r))` |
| Variant 0, `v>f` | First `1; (0,h-T(v*r),w,h); (X,Y+h-T(v*r),w,T(v*r))`. Then let `b=T(c/r+0.5)`, `q=(f+b)*r`: `0; (0,h-T(q),w,h); (X,Y+h-T(q),w,T(q+0.5))` |
| Variant 1, `v<=f`, `v!=0` | `2; (0,h-T(v*r),a,h); (X,Y+h-T(v*r),a,T(v*r))` |
| Variant 1, `v>f` | **Only one draw:** `2; (0,h-T(f*r),a,h); (X,Y+h-T(f*r),a,T(f*r+0.5))`. No bias, no frame-1 current draw. |
| Single-fill `v=0` | no fill draw |

Variant 2 would draw frame 2 whole at `0x5A947C`, but no target gauge reaches
variant 2. Do not confuse that skill-gauge path with cropped HP/MP frame 2.

Decisive raw instructions:

```asm
; Conquer.exe: normal single, input already upper-clamped
005A95C0  fild  dword [ebp+0x10]
005A95C3  fmul  dword [esi+0x6c]
005A95C6  call  _ftol
005A95D4  mov   [ebp-0x8],edx       ; RECT.bottom = h
005A95D7  sub   ecx,eax             ; RECT.top = h - pixels
005A9632  push  0                   ; frame 0
005A9634  jmp   0x5A950C
005A950F  call  dword [eax+0xc]      ; ANI cropped draw
; normal dual: frame 1 then biased frame 0
005A96BE  push  1
005A96C0  call  dword [eax+0xc]
005A96C3  fld   dword [esi+0x70]
005A96C6  fdiv  dword [esi+0x6c]
005A96C9  fadd  dword [0x84D4A0]    ; 0.5
005A9718  push  0
005A971D  call  dword [ebx+0xc]
; alternate paths select 2, not 0/1
005A950A  push  2                   ; single -> 0x5A950F
005A9561  fild  dword [ebp+0x14]    ; follower overwrites source top
005A95A5  push  2                   ; dual-value -> 0x5A971D
```

Every cropped call passes color parameter **0**, draw mode **0**. At
`graphic.dll!CAniX_DrawFrameSubRectAt` `0x1000BE70`, the frame is selected
by unsigned modulo at `0x1000BE86`, rotation **0** is appended at `0x1000BE89`,
and the frame wrapper is called at `0x1000BEB6`. Source and destination sizes
pass through unchanged to `CMyBitmapSpriteFrame_DrawSubRectAt` `0x10012190`.

That wrapper prepares sprites when pipeline mode differs (`0x10012235/0x1001223E`),
preserves existing vertex color for zero color (`0x10012249`), calls SetCoor
at `0x10012279`, bypasses Rotate at `0x10012288`, then calls Sprite_Draw at
`0x100122A1`. Initial color is opaque white `0xFFFFFFFF` from core
`Sprite_Clear` `0x10015864`; **color 0 means preserve, not explicitly set white
on every draw**. No gauge path here retints those frames.

Core `Sprite_SetCoor` `0x10015AF0` divides source coordinates by logical image
width/height at texture `+0x10/+0x14`; it never checks RECT against those dimensions.
It subtracts 0.5 from destination vertex X/Y (`0x10015BE3`, `0x10015C02`).
Vertices are TL, BL, TR, BR, z=0, rhw=1, stride28. A **zero destination width or
height falls back to the image dimension** (`0x10015C13/0x10015C15`,
`0x10015C3B/0x10015C3D`), even with a nonnull source RECT. Thus a positive value
whose computed pixel height truncates to zero is not equivalent to Show(value=0).

Core `Sprite_Draw` `0x10015EE0`, mode0, sets SRCBLEND=5/SRCALPHA at
`0x10015FA6`, DESTBLEND=6/INVSRCALPHA at `0x10015FB8`, binds stage0 texture
at `0x10015FCF` and submits `DrawPrimitiveUP(type=5,primitiveCount=2,stride=28)`
at `0x10015FE8`. **No source RECT reaches Direct3D.** There is no source clipping,
destination reduction, automatic source-bound rejection, or gauge-specific scissor.
The ordinary viewport still determines screen-edge rasterization.

`Sprite_Prepare` `0x10015D20` enables alpha blending, disables Z/Z-write and
alpha testing (`0x10015D2C/0x10015D3E/0x10015D50/0x10015E4D`), sets color and
alpha MODULATE (`0x10015DEB/0x10015DFF`), point MIN/MAG (`0x10015E13/0x10015E27`),
MIPNONE (`0x10015E3B`), and FVF `0x144` (`0x10015E60`). It does not change
sampler addressing. Init3DEx sets stage0 U/V=WRAP(1) at
`0x10008964/0x10008977`; ResetDevice repeats at `0x10008CBA/0x10008CCE`,
ChangeDisplayResolution at `0x100090E2/0x100090F6`. The transient border-address
writer is `graphic.dll!BeginProjectiveShadowMap` `0x10006DB0`; End at
`0x10006E50` restores WRAP at `0x10006E8E/0x10006EA5`. Its only shipped import
caller, Role3D.dll, pairs Begin/End at `0x1000826B/0x10008281` with no intervening
return. This is native state evidence, not an assumed D3D default.

## Progress47 image size, texture creation and examples

Active retail `data/main/ProgressForce2.dds` is a **loose** 32x32 DXT3 file,
SHA-256 `9a67c108613cdf5440a40708bcbd3573ef9b3782da6d997c435b654a7fbbada9`.
The ANI does not declare an alternate logical extent. The full load chain is:

1. EXE Show query `0x5A9600` -> GraphicData.dll
   `GameDataSet_QueryAniResourceByDualPath` `0x100045E0`, mode1, timeout30000 ->
   `GameDataSet_CreateAniResource` `0x100062B0` -> graphic.dll `AniCreate`
   `0x1000BFE0` -> `CAniX_CreateFromDataAndIndexPath` `0x1000BBF0` ->
   `CAniX_CreateFromIndexInfo` `0x1000BC80`.
2. Every frame loads at graphic.dll `0x1000BD68` through
   `CMyBitmapSpriteFrame_LoadImageAndCreateSprite` `0x10011EB0`; ordinary DDS
   uses `Sprite_Load(&sprite,path,pool=1,1,0)` at `0x100120EC`.
3. Core `Sprite_Load` `0x10015890` -> `Texture_Load` `0x10016360`.
   Loose file call `0x100165AF` enters `Image_LoadFromPath_Thunk` `0x1001BD6B`,
   then memory loader at `0x1001BDB8` / `0x1001BD2B` ->
   `D3DTexture_LoadFromDecodedImage` `0x1001B6B8` via `0x1001BD5F`.
   Archive frames instead enter the same memory loader at `0x100164C2`.
4. Decoder `0x1001E957` selects DDS decoder `0x1001E075`;
   header width/height stores are `0x1001E0BA/0x1001E0C2`. Source image info
   reaches logical texture width/height at `0x10016511/0x1001651D`.
   `GetLevelDesc` at `0x10016503` supplies **format**, not replacement logical size.
5. Default requested dimensions -1 select decoded 32/32 at
   `0x1001B78F/0x1001B792`, `0x1001B79F/0x1001B7A2`. Dimension/capability
   adjustment `0x1001A95B`, called `0x1001B96C`, handles device limits,
   power-of-two and compressed-block alignment. 32x32 is already square,
   power-of-two and block-aligned; on a device supporting this extent it stays
   32x32. `CreateTexture` vtable+0x50 at **`0x1001B9DF`** receives 32x32,
   one mip and pool1. No code pads it to 35 or 64 because of the gauge.

**Source/logical dimensions are conclusively 32x32; the native GPU creation
request is 32x32 on a device admitting that extent.** Actual driver allocation
was not observed here. Device caps can constrain the loader; neither an actual
adapter's caps nor hidden physical texture pitch can be recovered from the DDS.
A failed creation follows the failure chain below, not a 35-high fallback.

For origin `(X,Y)`, let `p=T(value*float32(35/50))`. Requested source is
`(0,35-p,8,35)`, destination `(X,Y+35-p,8,p)`. No clipping occurs. UVs are
`(0,(35-p)/32)` to `(0.25,1.09375)` and the vertex bounds subtract 0.5.
Normal WRAP means the source region beyond row31 samples from the top again;
it does **not** repeat/clamp the last row. This sampling consequence follows
from the submitted UVs and proven native address state; no GPU image was captured.

| Example / arithmetic | Requested source RECT | Destination `(x,y,w,h)` at baseline 800x600 | Final UV bounds |
|---|---|---|---|
| value50, x87 precision24 | `(0,0,8,35)` | `(42,511,8,35)` | `(0,0)` to `(0.25,1.09375)` |
| value50, precision53/64 | `(0,1,8,35)` | `(42,512,8,34)` | `(0,0.03125)` to `(0.25,1.09375)` |
| value25, either precision | `(0,18,8,35)` | `(42,529,8,17)` | `(0,0.5625)` to `(0.25,1.09375)` |

At baseline1024x768 add168 to destination Y. In the precision24 full example,
vertices are `(41.5,510.5)`, `(41.5,545.5)`, `(49.5,510.5)`, `(49.5,545.5)`.
For value25 they are `(41.5,528.5)`, `(41.5,545.5)`, `(49.5,528.5)`,
`(49.5,545.5)`. No effective clipped rectangle replaces the requested one.

The stored ratio is `0.699999988079071`. Original-instruction replays reproduce
the precision-dependent endpoint above. CRT startup calls
`_controlfp(0x10000,0x30000)` at `0x777D4E` (53-bit request). Core CreateDevice
flags are `0x44/0x24` (`0x100086BF/0x100086EE`), without FPU_PRESERVE.
The external D3D8 runtime and imported MSVCRT `_ftol` implementation are not in
the authoritative clean set inspected here. **Do not present precision24 as a
measured rendering-thread fact.** The replay's `_ftol` boundary explicitly
implements truncation with saved/restored control word; it is not captured CRT code.

## Failure semantics

Style0 Init records the section name and succeeds without doing the ANI lookup:
`0x5A9886` branches to the assignment path, `0x5A998A` assigns the name,
`0x5A9996` returns1. The style0xB lookup in Init is irrelevant to these instances.

| Failure | Native branch and effect |
|---|---|
| Missing section / lookup null | graphic.dll index search `0x1000BC3A` fails -> create returns0 at `0x1000BC71`; AniCreate deletes failed instance at `0x1000C045` and returns null at `0x1000C05A`. GraphicData creator returns0 at `0x100062E5`. Show's null tests at `0x5A9608/0x5A9684` (normal), `0x5A94E0/0x5A955B` (alternate) go to `0x5A9726`, then overlay0 -> return `0x5A9781`. |
| Listed frame path missing / load fails / normal allocation returns null | graphic.dll `0x1000BD4E` allocation guard or `0x1000BD6F` image failure -> cleanup of partial frames, frameCount0 at `0x1000BE01`, failure return `0x1000BE1A`; same null chain. Core Sprite_Load texture failure returns0 at `0x100158D9`. |
| Requested numeric index outside a successfully loaded ANI | **Wraps modulo frameCount**, `0x1000BE86`; not a missing-image no-op. Nonpositive count returns0 at `0x1000BE7A/0x1000BE7D`. |
| Corrupted positive-count ANI with a null frame pointer | No null guard before dereference `0x1000BEA4`; not safely skipped. This is not the normal all-or-nothing factory failure state. |
| D3D texture bind or DrawPrimitiveUP failure | core `0x10015FD7/0x10015FF0` takes failure path; there is no successful geometry submission in that case. Gauge/HUD does not propagate it into an early HUD return. |

HUD calls `0x4BC455`, `0x4BC48F`, `0x4BC4C2`, `0x4BC517` do not test the
Show return. `0x4BC51C` starts Dialog4 lookup immediately after overflow Show.
A missing gauge does not itself abort the pass. Dialog4's own independent failure
can still end the later HUD pass, as documented in the static-chrome contract.
This describes ordinary returned failures, not arbitrary process exceptions/OOM crashes.

## UI calibration and final origins

Owner: global UI manager `0x957DE8`; enabled `+0x3C=0x957E24`, scaleX
`+0x44=0x957E2C`, scaleY `+0x48=0x957E30`. Constructor `0x5914C0`
clears the flag at `0x5915EA` and both floats at `0x5915AD/0x5915BE`.
Static initializer is `0x5914A0`. The other writes to these fields in the
manager's methods are the calibration stores below; mode selection `0x59188F`
selects the GUI file, not these values. Absolute-global xrefs are reads.

`CStartupLogoDialog_OnInitDialogLoadLogoBrush` `0x4B08B9` calls
`UiLayout_CalibrateDialogFontUnits` `0x591C7B` at `0x4B08DB`, table index12.
The startup logo uses RT_DIALOG `0x111`, **12-point 宋体 (SimSun)**; extracted
resource hash `d3385720032d4c083c288c299917df5226b47297f811beae5774db5fd78395fd`.
This is the English executable's actual resource, not a request to support other languages.

```asm
00591CCF call [MapDialogRect]       ; input RECT {0,0,4,8}, logo HWND
00591CD5 cmp  edi,[ebp-0x8]        ; expected width 8 vs mapped width mx
00591CD9 jne  0x591CE3
00591CDE cmp  eax,[ebp-0x4]        ; expected height16 vs mapped height my
00591CE1 je   0x591D4E             ; baseline: leave initialized flag0
00591CE9 mov  dword [esi+0x3c],1
00591CF1 fidiv dword [ebp-0x8]
00591CF4 fstp dword [esi+0x44]     ; sx=float32(8/mx)
00591CFA fidiv dword [ebp-0x4]
00591CFD fstp dword [esi+0x48]     ; sy=float32(16/my)
```

The API return is not checked; valid OS dialog/font realization is an external
input. If the units differ, compensation can run in any supported screen mode.
There is no separate user scaling option in this writer chain. Therefore **A
(unconditionally inactive in English modes0..3) is not proven**. The resolved
mechanism is C-like runtime dependence on OS font metrics, not an INI option;
there is no single binary-proven OS result for all English installations.

`CMyProgress_Init` calls the GUI registrar `0x591DF4` at `0x5A979B`.
Although the registrar has an earlier scaling resize at `0x591E70`, its later
explicit INI x/y/w/h application at `0x591FF6` places these controls at the
shipped values. Init reads the resulting screen rect at `0x5A97AD`, subtracts
its baseX/Y at `0x5A97B8/0x5A97C1`, then branches on the calibration flag at
`0x5A97CE`. Active origin stores are `0x5A97EF/0x5A9809`; MoveWindow is
`0x5A9848`. Native uses `R(z)=trunc(z+0.5)` after x87 multiplication.
The later explicit fill geometry remains `(36,74)`, `(34,74)`, `(8,70)`, `(8,35)`;
it is not multiplied by these factors.

Both GUI files contain the same child coordinates. The independently established
parent origin is `(0,H-141)`: `(0,459)` / `(0,627)`; see
[static HUD placement](14_static_main_hud_chrome.md).

| Gauge | GUI section; local baseline | Final baseline 800x600 | Final baseline 1024x768 | Active-compensation final formula |
|---|---|---|---|---|
| HP | `130-1501`; `(4,54)` | `(4,513)` | `(4,681)` | `(R(4*sx),H-141+R(54*sy))` |
| MP | `130-1502`; `(52,54)` | `(52,513)` | `(52,681)` | `(R(52*sx),H-141+R(54*sy))` |
| stamina | `130-1025`; `(42,58)` | `(42,517)` | `(42,685)` | `(R(42*sx),H-141+R(58*sy))` |
| overflow | `130-1027`; `(42,52)` | `(42,511)` | `(42,679)` | `(R(42*sx),H-141+R(52*sy))` |

The baseline column applies when MapDialogRect returns `(8,16)`. Actual final
numbers for a different Windows font realization require its measured `mx,my`.
Nothing in this result licenses applying RT_DIALOG scaling to static panel art.

## Asset closure and remaining evidence boundary

Exact section/frame/path identities, active container offsets, decoded dimensions,
DXT3 format and SHA-256 hashes for all ten listed files are in
[assets.json](../../10_work/docs/evidence/gfx-ui-002-main-hud-gauges-5517/assets.json).
The **draw closure** is HP/HPA/HPH, MP/MPA/MPH, ProgressForce and ProgressForce2
(eight images). ForceA and Force2A are **native eager-load dependencies only**,
not reachable draws for these instances. An implementation with a selective
resource loader should not invent frame-1 stamina drawing to justify loading them.

Outstanding measurements are specific: OS MapDialogRect calibration values,
render-thread x87 control word, and adapter caps/created texture description in
an actual clean Windows run. Native source-RECT forwarding, UV endpoint,
address-mode writes, frame-index selection, overlay modes, failure continuation
and conditional placement formulas are established independently of those inputs.
