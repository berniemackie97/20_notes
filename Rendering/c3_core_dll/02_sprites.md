# Sprite subsystem (`Sprite_*`)

The `Sprite_*` API in `c3_core_dll.dll`, as the client uses it.

## Exported entry points

- ordinal `139` `0x10015840` `?Sprite_Clear@@YAXPAUC3Sprite@@@Z`
- ordinal `140` `0x10015900` `?Sprite_Create@@YAHPAPAUC3Sprite@@KKKW4_D3DFORMAT@@W4_D3DPOOL@@@Z`
- ordinal `141` `0x100162D0` `?Sprite_CreateEx@@YAPAUC3Sprite@@PAUC3Texture@@@Z`
- ordinal `142` `0x10015EE0` `?Sprite_Draw@@YAHPAUC3Sprite@@K@Z`
- ordinal `143` `0x10015E70` `?Sprite_DrawEx@@YAHPAUC3Sprite@@KK@Z`
- ordinal `144` `0x10016090` `?Sprite_DrawListBatch@@YAHPAUC3Sprite@@PAUSpriteVertex@@K@Z`
- ordinal `145` `0x10015890` `?Sprite_Load@@YAHPAPAUC3Sprite@@PBDW4_D3DPOOL@@HK@Z`
- ordinal `146` `0x10016040` `?Sprite_Lock@@YAHPAUC3Sprite@@PAUtagRECT@@PAU_D3DLOCKED_RECT@@@Z`
- ordinal `147` `0x10015990` `?Sprite_Mirror@@YAXPAUC3Sprite@@@Z`
- ordinal `148` `0x10015D20` `?Sprite_Prepare@@YAXXZ`
- ordinal `149` `0x10016100` `?Sprite_ReLoadNoFilter@@YAHPAPAUC3Sprite@@PADW4_D3DPOOL@@HK@Z`
- ordinal `150` `0x100159D0` `?Sprite_Rotate@@YAXPAUC3Sprite@@H@Z`
- ordinal `151` `0x10015CC0` `?Sprite_SetColor@@YAXPAUC3Sprite@@EEEE@Z`
- ordinal `152` `0x10015D00` `?Sprite_SetColor@@YAXPAUC3Sprite@@K@Z`
- ordinal `153` `0x10015AF0` `?Sprite_SetCoor@@YAXPAUC3Sprite@@PAUtagRECT@@HHKK@Z`
- ordinal `154` `0x10015960` `?Sprite_Unload@@YAXPAPAUC3Sprite@@@Z`
- ordinal `155` `0x10016070` `?Sprite_Unlock@@YAHPAUC3Sprite@@@Z`

## Construction and loading

### `Sprite_Clear` (ordinal `139`, `0x10015840`)

Initializes a `C3Sprite` object to a known default state.

Observed behavior:

- Clears 4 vertex records of 0x1C bytes each (via `memset`), then sets:
  - per-vertex `rhw` to `1.0f`
  - per-vertex color to `0xFFFFFFFF`
- Sets multiple UV fields to defaults, with several fields initialized to `1.0f` (used by `Sprite_SetCoor` UV coverage).
- Sets `sprite->texture` (at index `28` in the decompiler) to null.

### `Sprite_Create` (ordinal `140`, `0x10015900`)

Allocates a sprite and creates an owned backing texture:

- `operator new(0x74)` + `Sprite_Clear`
- calls `Texture_Create(&sprite->texture, width, height, levels, format, pool, a7=0, a8=0)`
- returns `1` on success (`*out = sprite`), `0` on failure (sprite freed)

### `Sprite_CreateEx` (ordinal `141`, `0x100162D0`)

Allocates a sprite that references an existing `C3Texture`:

- `operator new(0x74)` + `Sprite_Clear`
- sets `sprite->texture = texture`
- calls `Sprite_SetCoor(sprite, rect=null, x=0, y=0, width=0, height=0)` (full-UV, default size)
- returns the allocated sprite pointer

### `Sprite_Load` (ordinal `145`, `0x10015890`)

Allocates a sprite and loads its backing texture from a path:

- `operator new(0x74)` + `Sprite_Clear`
- calls `Texture_Load(&sprite->texture, path, a3, a4, a5, a7=2)`
  - if `Texture_Load(...) == -1`, frees sprite and returns `0`
  - else calls `Sprite_SetCoor(sprite, rect=null, x=0, y=0, width=0, height=0)`, stores `*out`, returns `1`

### `Sprite_ReLoadNoFilter` (ordinal `149`, `0x10016100`)

Creates a sprite + texture in a way that bypasses the shared texture cache path used by `Texture_Load`:

- Allocates a `C3Sprite` and a `C3Texture` directly (`operator new(0x74)` and `operator new(0x1C)`), then calls `Texture_Clear`.
- Loads from the DataFile system similarly to `Texture_Load` (choosing between `DataFile_UnpackSearch` + internal loader, or `DataFile_Load` + internal loader).
- After load:
  - queries the texture desc (`GetLevelDesc(0, ...)`-like call) and writes `tex->format`
  - writes `tex->width`/`tex->height` from loader outputs
  - stores an owned copy of the source path as `tex->name`
  - calls `Sprite_SetCoor(sprite, rect=null, x=0, y=0, width=0, height=0)`
- Returns `1` on success, `0` on failure.

## Draw submission (`Sprite_Draw` / `Sprite_DrawEx`)

### `Sprite_DrawEx` (ordinal `143`, `0x10015E70`)

Signature (export name):

- `?Sprite_DrawEx@@YAHPAUC3Sprite@@KK@Z`

Observed behavior:

- Writes D3D render states:
  - `SetRenderState(D3DRS_SRCBLEND=19, a2)`
  - `SetRenderState(D3DRS_DESTBLEND=20, a3)`
- Binds the sprite's underlying texture to stage 0 via `SetTexture(stage=0, sprite->texture->d3dTexture)`.
- Submits the sprite's vertex data using `DrawPrimitiveUP(D3DPT_TRIANGLESTRIP=5, primitiveCount=2, pVertices=sprite, vertexStride=28)`.
- Returns boolean success (both `SetTexture` and `DrawPrimitiveUP` must succeed).

### `Sprite_Draw` (ordinal `142`, `0x10015EE0`)

Signature (export name):

- `?Sprite_Draw@@YAHPAUC3Sprite@@K@Z`

Observed behavior:

This function selects a blend-state preset based on `a2` (0/1/2) and on the sprite's texture format / alpha.

- If `a2 == 0`:
  - sets `D3DRS_SRCBLEND` to `5` and `D3DRS_DESTBLEND` to `6`
- If `a2 == 1`:
  - inspects `sprite->texture->format` and vertex 0's packed diffuse alpha (`*(DWORD*)(sprite+0x10) & 0xFF000000`)
  - if the format is one of `{21, 25, 26, 28, 29, 0x33545844 /* 'DXT3' */}` or alpha is not fully opaque, uses `D3DRS_SRCBLEND=2`
  - otherwise uses `D3DRS_SRCBLEND=3`
  - then sets `D3DRS_DESTBLEND` to `2`
- If `a2 == 2`:
  - sets `D3DRS_SRCBLEND=5`, `D3DRS_DESTBLEND=6`, and also sets render state `168` to `7`

After setting states, it binds the sprite's underlying texture and submits a triangle-strip exactly like `Sprite_DrawEx`.

If `a2 == 2`, it resets render state `168` back to `-1` before returning.

Disassembly evidence for mode-1 destination blend (`2`):

- `0x10015F96`: `push 0x2`
- `0x10015FB5`: `push 0x14` (render-state id)
- `0x10015FB8`: `call [ecx+0xC8]` (`IDirect3DDevice8::SetRenderState`)

### Modes 1/2 closure audit, 2026-09-10

**Status, updated 2026-09-14: exact Sprite_Draw state/predicate contract proven; whole-program caller and
framebuffer closure remains incomplete.** Mode 1 has verified conditional production
firework paths. No retail mode-2 consumer has been verified. The unresolved boundaries
below are acceptance limits, not evidence that a path is dead or broken.

- **Proven:** mode 1 reads `C3Texture+0x18`, comparing exactly
  `{21,25,26,28,29,0x33545844}`. The fallback tests the high byte of **vertex 0's**
  packed diffuse color at `sprite+0x10`; it does not examine texture pixels. A format match
  or diffuse alpha below 255 selects ONE; otherwise SRCCOLOR. Destination factor is ONE.
  DXT1, DXT2, DXT4, DXT5 and A8L8 are absent from the format set.
- **Proven:** mode 2 uses the same source/destination factors as mode 0, then writes
  `COLORWRITEENABLE(168)=7` (RGB enabled, alpha disabled). Both success and failure paths
  attempt to write `0xFFFFFFFF`, at `0x10016025` and `0x10016006`. This is a fixed write,
  not restoration of the previous mask. State-write HRESULTs are ignored. The branch does
  not set render target, blend operation, alpha test, depth or texture-stage states.
- **Proven provenance distinction:** `Texture_Load`, `0x10016360`, calls level-0
  `GetLevelDesc` at `0x10016503` and stores its first dword at `texture+0x18` at
  `0x1001650A`. This is the uploaded resource format, not the source extension or a
  generic alpha capability. `Texture_Create`, `0x100169F0`, instead stores the selected
  request at `0x10016AE9`; do not conflate those construction paths.
- **Proven direct caller inventory:** `graphic.dll` import `0x100391EC` has four code
  references: temporary texture-backed wrapper `0x100053AD`; frame `DrawAt`
  `0x1001217A`; frame `DrawSubRectAt` `0x10012225` and `0x100122A1`. All forward an
  argument without a mode range check. `CAniX_DrawFrameAt`, `0x1000BE20`, forwards its
  draw argument at `0x1000BE55`; `CAniX_DrawFrameSubRectAt`, `0x1000BE70`, forwards at
  `0x1000BEB6` with rotation forced to zero.
- **Proven candidate consumer:** `Conquer.exe!Role_DrawAttachedEffectAniOverlay`,
  `0x71E96D`, resolves `ani/effect.ani`, gets a frame at `0x71E9B9`, and calls frame
  slot `+8` at `0x71EA6A` with `(x,y,null,width,height,0,this+0x14,0)`. Thus it retains
  color, uses computed destination dimensions, and forwards the object mode field.
  The parser chain is resolved below: clean Effect.ini supplies 75 zero values and
  one value 1, with no value 2. Exact-record activation is a separate question.

The corresponding mode predicate and write-mask instructions now have Binary Ninja comments.

Historical checkpoint before the user's save-policy change: this note recorded saves
of C3_CORE_DLL, graphic, GameData and Conquer. It does not certify the current database
files; all subsequent saves belong to the user. A byte-checked instruction replay has
passed 8,800 Sprite_Draw cases, including state-write, texture-bind and draw failures;
this checks native CPU control flow with mocked D3D calls, not GPU pixels.

The wider caller search also covers `C3DTextureX` vtable `0x100395FC`, slot `+0x2C`,
which points to the temporary-sprite wrapper at `0x10005300`. Its initializer is now
`C3DTextureX_Initialize` (`0x100050A0`). Slot offsets alone are not class identity.
Nineteen initially missing decompiles were traced to Binary Ninja analysis time/update
limits. Subsequent analysis retained native parent instructions and followed actual
continuations instead of relying on those missing decompiles.
Empty HLIL or call-site results must not be interpreted as dead or unreachable code.

#### Native mode-1 consumers recovered

The following Conquer call sites pass **literal 1** to `CAniX_DrawFrameAt` through ANI
vtable `+8`. All explicitly pass diffuse-alpha parameter 255; the frame wrapper therefore
writes `0xFFFFFFFF`, rebuilds full-texture coordinates and performs no rotation or cropping.
These bodies inherit the current render target; none binds a target locally.

| Renamed Conquer function | Function VA | Mode-1 call sites |
|---|---|---|
| `WeatherParticle_DrawAdditiveRiseAndPairedFade` | `0x62B006` | `0x62B0D2`, `0x62B1EE`, `0x62B210` |
| `WeatherParticle_DrawPairedAdditiveRiseAndFade` | `0x62C0C5` | `0x62C1DD`, `0x62C1FF` |
| `WeatherParticle_DrawAdditiveRiseAndLetterFade` | `0x62DCAD` | `0x62DD55`, `0x62DE06` |
| `WeatherAirBubble_DrawAdditiveFrame` | `0x640B6F` | `0x640C05` |

The first three switch to **mode 0** for their falling/fading branches:
`0x62B363/0x62B393`, `0x62C370/0x62C3A0`, `0x62DEC8`. Do not incorrectly describe
their calculated fall alpha as a mode-1 input. Resource names come from `ani/weather.ani`.
Their creation/resource-name provenance is qualified in the following paragraphs.

**Proven firework activation path (subsequent checkpoint):** `CMsgTick__Process`
calls `WeatherFireworkSystem_AddEmitterByKind` (`0x62D578`) at `0x6EB7F9`,
`0x6EB873`, `0x6EB8EA`, with kind 0 and resource variant `rand()%5+1`.
The chain is `0x62D05A -> 0x62B47D`; the latter builds `YinFa%d`.
The component render tick calls `0x62D5D9 -> 0x62D0C3 -> 0x62B58B ->
0x62B39B -> 0x62B006`. The final trampoline is an actual five-byte JMP,
not a separate draw operation. `CMsgName__Process` (`0x73EFDF`), action byte 1,
calls `WeatherLetterFireworkSystem_AddTextEmitters` (`0x62E7C2`) at `0x73F216`
with variants 1..3. That creates paired YinFa and Letter emitters through
`0x62C476` and `0x62DFC4`; `0x62E041` constructs `Letter%d`.
The paired tick `0x62C5A0` calls the `0x62C3A8 -> 0x62C0C5` trampoline at
`0x62CECA`. Clearing its analysis skip recovered HLIL; its original instructions
already contained the call. These are conditional production packet/render paths,
not evidence of a captured live game frame.

The intervening recovered helpers are also renamed: `0x62D0C3`
`WeatherFireworkSystem_TickOrdinaryEmitterList`, `0x62D34F`
`WeatherPairedFireworkSystem_TickEmitterList`, `0x62D5D9`
`WeatherFireworkSystem_TickAndDraw`, `0x62E108`
`WeatherLetterFireworkEmitter_TickAndDraw`, and `0x62E8D4`
`WeatherLetterFireworkSystem_TickAndDraw`. The upload normalizer `0x1001A775`
is `C3FormatTag_NormalizeForPaletteAnd16BitVariants`; its four tag remappings
leave DXT3 unchanged. Current MCP name verification is retained in
`10_work/docs/evidence/sprite-draw-modes-5517/bninja-annotations.json`.

**Air-bubble qualification:** `0x640B35` dispatches the particle vtable `+4` at
`0x640B6A` to the additive draw. The manager is constructed by the map component
at `0x634A24`; its tick is called at `0x634C69`. However, manager `+0x2F0`
starts at zero (`0x640C91`) and gates the tick. The local class bodies recovered
so far do not establish its enabling write or resource-name initialization.
The legacy reconstruction's `Create` method is not native proof of activation.
The original legacy `CAirBubble.Show` used mode 0. This audit corrected it to the
native literal 1 at `0x640C05`; that correction does not prove manager activation.

**Restart checkpoint:** Binary Ninja was restarted during this audit. All weather
renames above were found present through MCP after restart, including the paired
tick and trampolines. Per the user's updated instruction, database saving belongs
to the user; subsequent work uses MCP without screen automation or automatic saves.
Temporary bulk scans/probe outputs were lost in that restart. The durable verification
below was regenerated afterward; the follow-up captures and checks are now retained
on disk and no longer depend on that lost temporary scan.

**Durable verification regenerated after restart:**
The first retained run of `10_work/docs/evidence/sprite-draw-modes-5517/native_probe.py`
verified 12,423 instruction lines from 75 successful MCP disassembly captures against
clean PE bytes, replayed 8,800 Sprite_Draw cases, and resolved 88 selected ANI frames
using the original WDF normalization/hash instructions. Results, asset hashes/header bytes, config hashes
and representative state-call traces are in `native-probe-results.json` beside it.
One rejected address query (`graphic 0x10006590`) is explicitly retained as an error;
the actual `TargetBmpCreate` entry is `0x10006570`. Neither an error response nor
the byte count is a whole-program completeness claim. No GPU rasterization or live
retail game-frame execution was performed.

#### Effect content mode provenance

`GameData.dll!RoleDataSingleton_LoadSpriteEffectInfoFile`, renamed at `0x100060FF`,
opens `ini/Effect.ini` and scans `ShowWay=%d` at `0x10006286` into record `+0x88`.
No enum/range validation occurs. The table insertion is at `0x100062FA`, table `this+0xFC`.
`Conquer.exe!CAniEffect_CreateFromEffectInfo`, renamed at `0x71E91D`, loads that `+0x88`
field and forwards it at `0x71E961` to `CAniEffect_CreateWithDrawMode` (`0x71E8B3`).
The latter stores it at instance `+0x14` at `0x71E8CE`; `0x71EA6A` forwards that field
to the frame draw. The initializer `0x71E885` is now `CAniEffect_Initialize`.

Clean `ini/effect.ini` has 76 `ShowWay` fields: 75 are 0, one is 1, none is 2 or another
value. The 1 belongs to `[MapItemFlash]`, line 27, whose `AniTitle=MapItemFlush` resolves
to `ani/effect.ani` lines 20–30, nine `Data/Pic/MapItemFlush/effect0000.dds` through
`effect0008.dds` frames. This proves the content range and parser path. A record's mere
presence does **not** prove that record is instantiated during a particular retail scene.

#### Exact state and color contract

The complete mode-specific state writes are:

| Mode | Source factor (state 19) | Destination factor (state 20) | Write mask (state 168) |
|---|---|---|---|
| 0 | `5`, SRCALPHA | `6`, INVSRCALPHA | unchanged |
| 1, format-set match or vertex-0 alpha !=255 | `2`, ONE | `2`, ONE | unchanged |
| 1, other format and vertex-0 alpha ==255 | `3`, SRCCOLOR | `2`, ONE | unchanged |
| 2 | `5`, SRCALPHA | `6`, INVSRCALPHA | 7 before bind/draw; attempt `0xFFFFFFFF` before either checked return |
| any other DWORD | unchanged | unchanged | unchanged |

The format set is **exactly** A8R8G8B8 (21), A1R5G5B5 (25), A4R4G4B4 (26),
A8 (28), A8R3G3B2 (29), DXT3 (`0x33545844`). The unsigned comparison at
`0x10015F6B/0x10015F70` is `(v0.diffuse & 0xFF000000) < 0xFF000000`.
No RGB bit participates. No separate alpha field or sampled texture alpha is read.
Both `Sprite_SetColor` overloads (`0x10015CC0`, `0x10015D00`) write diffuse color
into all four vertices; `Sprite_Clear` (`0x10015840`) initializes it to white/255.

`SetTexture(0, texture->d3dTexture)` at `0x10015FCF` and
`DrawPrimitiveUP(TRIANGLESTRIP,2,sprite,28)` at `0x10015FE8` are checked for failure.
The mode-2 mask writes at `0x10016006/0x10016025` are attempted after texture-bind
failure, draw failure, or success. Render-state HRESULTs, including restoration, are
ignored. Consequently a failed state call can leave old state, even when the function
returns success. There is no query of the previous mask. Blend factors remain set;
the prior mask is lost when the fixed restoration succeeds. Subsequent draws can
therefore be affected. `Sprite_Draw` does not mutate any byte of the sprite, select
a target, or change blend operation, alpha-test, depth, fog, stencil or texture-stage state.

`Sprite_Prepare` (`0x10015D20`) enables alpha blending, disables alpha test, Z test
and Z writes, selects flat shading/no culling, sets stage-0 COLOROP and ALPHAOP to
MODULATE, point min/mag filtering and no mip filter, and selects FVF `0x144`.
It does **not** set blend operation or stage color/alpha argument selectors. The frame
wrapper calls `CMyBitmapPrepareSprite` (`0x100136B0`); that skips Prepare when the
shared pipeline-mode cache already equals 1. These are surrounding-state requirements,
not additional mode-2 branch writes.

With an independently established ADD blend operation, the factor meanings imply
mode 1 gives `S + D` for ONE or `S*S + D` for SRCCOLOR, componentwise before output
format conversion/clamping. Mode 0 gives `S*As + D*(1-As)`; mode 2 uses the same
factors while suppressing alpha writes if the mask write succeeds. Here `S` is the
post-texture-stage source, **not necessarily an unmodulated texture sample**.
These equations explain confirmed constants; they do not establish every caller's
ambient pipeline state or GPU rounding. D3D documentation is explanatory only:
[blend factors](https://learn.microsoft.com/en-us/windows/win32/direct3d9/d3dblend),
[render-state meanings](https://learn.microsoft.com/en-us/windows/win32/direct3d9/d3drenderstatetype),
[texture-stage operations](https://learn.microsoft.com/en-us/windows/win32/direct3d9/d3dtextureop).

#### Loaded versus created texture-format provenance

**Proven:** `Texture_Load` stores level-0 `GetLevelDesc.Format` at `+0x18` after
upload (`0x10016503 -> 0x1001650A`). `Texture_Reload` does the same
(`0x10016840/0x100168CC -> 0x100168E0`). The value remains on the CPU-side
`C3Texture`, reached through `C3Sprite+0x70`. DDS decode/upload can choose a supported
replacement format in `D3DTexture_LoadFromDecodedImage` (`0x1001B6B8`), with
format selection at `0x1001A693`; hence the mode predicate sees the resulting resource
format, not unconditionally the DDS FourCC. Conversion to modern RGBA alone loses
the distinction unless this native decision semantic is retained separately.

TGA decoding (`0x1001D362`) initially maps 32-bit truecolor to 21, 24-bit to 20,
16-bit to 25, and 15-bit to 24. BMP/DIB (`0x1001C6B6`) ordinary uncompressed
32-bit maps to 22, 24-bit to 20, 16-bit to 24; mask-based cases include 21/25/26.
Those are **decoder outputs**, not exceptions to the subsequent GetLevelDesc store.
A file extension, four channels, or a generic `hasAlpha` property is insufficient.

**Proven separate creation contract:** `Texture_Create` (`0x100169F0`) may select
a supported request with `SelectSupportedTextureFormat` (`0x10016910`), then stores
that selected request at `0x10016AE9`. `D3DDevice_CreateTextureWithAdjustedParams`
(`0x1001ACAD`) passes local width/height/level/format addresses through
`Texture_Adjust2DTextureRequirements` (`0x1001AC85`) and
`Texture_AdjustDimsChooseFormatAndMipCount` (`0x1001A95B`) before device creation at
`0x1001AD04`. The outer function does not query back the resource description.
Do not describe all native `+0x18` values as measured GPU formats.

#### Retail source families and branch reachability

The durable content probe records all selected frame paths, native WDF UIDs, offsets,
sizes, SHA-256 values and DDS headers. There are no missing selected frames:

| Family | Native path status | Clean source encoding | Representative path |
|---|---|---|---|
| YinFa1..5, 45 ANI frame records | production packet/emitter/render chain proven | all DXT3 | `data/firework/yinfa1/1.dds` |
| Letter1..3, 27 records | MsgName action-1 emitter/render chain proven | all DXT3 | `data/firework/yinfa1/1.dds` (Letter1 reuses YinFa1) |
| MapItemFlush, 9 records | ShowWay=1 parser/draw path proven; exact record activation unresolved | all DXT3 | `Data/Pic/MapItemFlush/effect0000.dds` |
| airbubble1..7, 7 records | draw routine proven; manager activation/resource setup unresolved | all DXT3 | `data/weather/airbubble/1/1.dds` |

**Proven conditional branch:** a successful DXT3-preserving upload of the verified
firework resources reaches ONE/ONE even at diffuse alpha 255. This follows from
the native loader and predicate; it is not a claim of a recorded driver execution.
No opaque alternate-format SRCCOLOR/ONE retail consumer has been verified.
The other five matching tags are proven accepted by Sprite_Draw, but not established
as actual uploaded formats of these retail draws. Device-dependent transcoding and
the complete alternate-format reachability set remain unresolved. The source-family
inspection does not turn the exact six-tag condition into a general alpha test.

#### Wrapper ordering, sentinels, and actual combinations

| Wrapper, graphic.dll | Order and forwarded semantics |
|---|---|
| `CMyBitmapSpriteFrame_DrawAt` `0x10012120`, draw `0x1001217A` | conditional Prepare; if the entire color argument !=0, set RGB=255 and alpha=low byte; full-texture SetCoor with default dimensions; Sprite_Draw(mode argument) |
| `CMyBitmapSpriteFrame_DrawSubRectAt` `0x10012190`, draws `0x10012225/0x100122A1` | conditional Prepare; same color sentinel; SetCoor(rect,x,y,width,height); optional Rotate if angle !=0; Sprite_Draw(mode argument) |
| `CAniX_DrawFrameAt` `0x1000BE20`, call `0x1000BE55` | frame index modulo frame count, forward x/y/color/mode to frame slot +4 |
| `CAniX_DrawFrameSubRectAt` `0x1000BE70`, call `0x1000BEB6` | select frame, forward rect/dimensions/color/mode to frame slot +8, **force angle 0** |
| `TextureBacked_DrawTemporarySpriteSubRectRotated` `0x10005300`, draw `0x100053AD` | SetCoor; unconditional packed-DWORD SetColor; optional Rotate; conditional Prepare; Sprite_Draw(mode); C3DTextureX vtable `0x100395FC +0x2C` |

The color argument zero means **retain previous diffuse**, not transparent black.
A nonzero value whose low byte is zero does write alpha 0. The temporary-texture
wrapper's packed color has no zero sentinel. None of these wrappers binds a target.
The temporary sprite's uninitialized Z/RHW limitation is documented in the rotation
contract; its existence is not evidence of a retail mode-1/2 consumer.

| Consumer | Source rect | Stretch | Diffuse RGB/alpha | Rotation | Repeated draws | Target |
|---|---|---|---|---|---|---|
| Proven firework mode-1 paths | null/full texture | default native size | explicitly white, alpha 255 | none | yes; coordinates/color rebuilt each draw | inherited; local body does not bind an offscreen target |
| Air-bubble literal-1 body; activation unresolved | null/full | default | explicitly white/255 | none | tick can repeat | inherited |
| Effect ShowWay=1 candidate | null/full | computed width/height, projection path | zero sentinel retains diffuse; actual prior color unresolved | forced 0 | cached frame/state reused | inherited |
| Mode 2 | **no verified retail consumer** | unverified | unverified | unverified | unverified | unverified |

Thus mode 1 + cropping, arbitrary RGB tint, partial diffuse alpha, or rotation is
supported by the generic primitive but **not proven as an actual combination on the
verified firework consumers**. Native texture alpha is not partial diffuse alpha.
Mode-0 falling/fading draws must not be counted as mode-1 alpha modulation.

#### Other caller provenance and mode-2 target audit

The machine-readable recovered caller ledger is
`10_work/docs/evidence/sprite-draw-modes-5517/caller-ledger.json`.
It distinguishes known literals, argument forwarding, object fields and parsed content.
It is **not** an assertion that every indirect call in the process has been resolved.

- The four direct graphic.dll Sprite_Draw import references listed above are proven.
  The frame/ANI/temporary-texture wrappers do not clamp their mode arguments; they
  can forward 2 or other DWORD values if supplied, which is capability, not retail use.
- Type-04 scenery renderer `0x645203`, calls `0x645314/0x645394/0x6453BA`, forwards
  object `+0x48`. Constructor `0x6450EB` initializes it to zero at `0x64517B`;
  loader `0x645654` does not deserialize it. That construction/load path is mode 0;
  a complete proof excluding every other writer has not been obtained.
- Terrain renderer `0x64450F` passes **literal 0** at `0x644671`, despite a separate
  loaded field `+0x44`. The field must not be substituted for the actual argument.
- `CDummyMovieMgr_ProcessMovieEntry`, draw `0x68C701`, also passes zero: `ECX` is
  cleared at `0x68C6E7` and pushed as the mode at `0x68C6ED`. The apparent HLIL
  iterator `i_1` does not describe the native argument value.
- `SpriteShader_DrawCopyWithOptionalStage2Texture` (`graphic 0x10007D60`) invokes
  **Sprite_DrawEx(sprite,ONE,ZERO)** at `0x10007E0D`; constant 2 there is a blend
  factor, not draw mode 2. Its pixel-shader/stage-2 setup does not establish a mode-2 consumer.
- The only recovered parsed draw-mode field is Effect.ini ShowWay: actual clean
  values are 0 and 1. None of its 76 records supplies 2 or another integer. The parser
  itself accepts an unrestricted signed integer; this is not a proof about modified files.
- Earlier broad scans inspected candidate indirect slots +4/+8/+0xC, then +0x2C.
  Receiver class identity, shared prologues, register-indirect calls and aliasing prevent
  turning a search miss into a whole-program unreachability proof. Bulk scan outputs
  were lost in the restart; retained exact functions/call sites carry the conclusions here.

**Target machinery is proven, its use by mode 2 is not.** `TargetBmpCreate`
(`graphic 0x10006570`) and `TargetBmpCreateEx` (`0x10006610`) call
`TargetBmpCreateInternal` (`0x100056A0`). It requests format 20 (R8G8B8) or 21
(A8R8G8B8) respectively, usage 1/render target, pool 0. Supported-request fallback
candidates are 22/X8R8G8B8, 24/X1R5G5B5, 23/R5G6B5, 30/X4R4G4B4.
`TargetTexture_BindAsRenderTarget` (`0x10005A40`) saves old target/depth surfaces,
gets level-0 color surface, binds it and the object's depth surface at `0x10005B2A`.
`TargetTexture_RestorePreviousRenderTarget` (`0x10005CA0`) restores those surfaces;
it does not restore Sprite_Draw's blend/write-mask state.
Creation requests alone cannot identify the actual target at a particular draw.
Normal presentation's 23/24/22 selection is documented in
[08_depth_stencil_and_presentation.md](08_depth_stencil_and_presentation.md).

No verified mode-2 caller/target pair, writable-alpha mode-2 target, or observable
retail framebuffer effect was found. This means **not established**, not impossible
or equivalent to mode 0. Even on an opaque target, mode 2 can change later rendering
through fixed mask restoration, and can differ in RGB if mode 0 inherited a restricted
RGB mask. Those are proven state consequences conditional on entry state and successful
state writes, not observed retail effects.

#### Mode-2 follow-up (2026-09-11 through 2026-09-14)

The follow-up retains 2,757 fresh MCP HLIL responses across Conquer.exe, graphic.dll,
GraphicData.dll, Role3D.dll, RoleView.dll, GameRole.dll and GameData.dll. These include
the initial 832 Conquer / 80 graphic / five GraphicData selection and the subsequent
register-indirect/tail-dispatch selection. Candidate selection uses clean
PE instruction decoding bounded by the current BN function-start inventory, then
queries BN itself. This is a search aid, not a completeness proof: register-indirect
calls, shared/overlapping blocks and incorrect boundaries require separate review.
The captures survived the subsequent usage interruptions and are now retained in
`10_work/docs/evidence/sprite-draw-modes-5517/mode2-followup/` with a checksum manifest.
The 1,935 parsed slot-call expressions and 114 register-call expressions with at
least four apparent arguments are search indexes, not verified draw-call counts.

**Proven exclusion:** `graphic.dll!SpriteShader_BindSpriteTextureAsRenderTargetAndClear`
(`0x10007A10`, renamed in BN) saves target/depth, obtains the sprite texture's level-0
surface (`0x10007AAA`), binds it (`0x10007B3A`), sets the viewport (`0x10007C32`),
clears (`0x10007C3D`) and optionally begins the scene (`0x10007C59`). Its `+8` calls
are COM Release calls, with an explicit object pointer on the stack; they are not
frame draws. Embedded `mov eax, continuation; ret` entries such as `0x10007AC2`
are referenced by exception metadata and must be read with the parent's CFG.
Neither short helper HLIL nor a nearby constant 2 establishes a Sprite_Draw mode.
The bounded caller and field-writer results below supersede that initial checkpoint.
They do not establish whole-program absence of mode 2.

**Type-04 field provenance, narrowed:** the constructor has one recovered code xref,
`CMapSceneryComponent_LoadSubcomponentsFromMapReader` at `0x6359B5`, in its type-code-4
branch. It allocates `0x58` bytes, constructs the object, loads it at `0x6359F5`, and
inserts it at `0x635A20`. The loader reads two strings plus fields
`+0x0C/+0x10/+0x34/+0x38/+0x2C/+0x30/+0x40`; it does not read a mode value from
retail map content. Vtable `0x86A5F8` has no draw-mode setter. Tick `0x6454D1`
updates the animation frame and cached extents, not `+0x48`. The destructor and
deleting destructor are now named in BN (`0x6451B1`, `0x645195`). These recovered
construction/load/virtual-method paths preserve mode 0. Arbitrary aliased writes
are not excluded by this bounded result.

The apparent `+0x48 = 2` stores at `0x63ACFB/0x63ADB2/0x63ADF2` belong to a
different object: `C3DMagicMapItem_Constructor` (`0x63A973`) installs vtable
`0x86A350`; `C3DMagicMapItem_TickUnitSequence` (`0x63AB04`) owns those writes.
Native diagnostic text identifies `3DGameMap/3DMagicMapItem.cpp`. Its field is a
unit-sequence state, not the scenery draw mode. Both functions are renamed, and
the misleading store is commented in BN. Nearby exception continuation helpers
do not truncate the parent's actual CFG.

**Native argument correction:** 35 candidate draw bodies were fetched as full BN
disassembly after HLIL showed misleading variable-valued mode arguments. For example,
`CMapPuzzleBitmap_RenderAtOffset` clears EAX at `0x63A4B0`, pushes it as mode at
`0x63A4B5`, and calls ANI slot `+0x0C` at `0x63A4C9`: mode 0. The six status-hint
panel draws at `0x5B9FD9/0x5BA0FC/0x5BA1E2/0x5BA313/0x5BA432/0x5BA633`
also push zero EDI as mode. EDI is initialized at `0x5B9C5B`; branches that later
reuse EDI as a GameDataSet pointer exit via `0x5BA142/0x5BA22C/0x5BA35D/0x5BA47C`
to the final text path, rather than flowing into another candidate panel draw.
Named dialog render bodies and
`SayHello_DrawDialogFrameAndText` / `LotteryEffect_DrawItemIcon` use zero at the
examined calls. These are resolved exclusions, not mode-2 consumers.
The remaining 21 unnamed UI bodies in that selection now have semantic names
based on their native ANI resource/string usage. Their BN comments explicitly
distinguish analyst names from recovered original C++ class names; the exact
address/name/resource mapping is retained in `mode2-followup/ui-annotations.json`.

**Obfuscated dynamic-import exclusions:** native decoder `0x5F7520` and thunk
`0x5F78C0` are now named `EncodedString_TranslateAlternatingTablesInPlace` and its
`_Thunk`. The fixed table pointers `0x93A520/0x93A524` point to the permutation
`0x93A65C` and alphabet `0x93A618`; direction alternates with character parity.
Original-x86 bounded replay, mocking only Windows lookup and the ASCII `_mbschr`
boundary, proves the constructed names in these six lookup prefixes:

| Conquer entry | Decoded module and procedures |
|---|---|
| `0x5F63C0` | wintrust.dll: six CryptCAT catalog functions plus WinVerifyTrust |
| `0x5F70A0` | psapi.dll: GetModuleFileNameExA, EnumProcessModules |
| `0x5FD670` | ntdll.dll: NtQueryVirtualMemory |
| `0x602E80` | iphlpapi.dll: GetAdaptersInfo |
| `0x6031D0` | netapi32.dll: Netbios |
| `0x615830` | iphlpapi.dll: GetAdaptersInfo, GetTcpTable, AllocateAndGetTcpExTableFromStack |

These six bodies are meaningfully named/commented in BN. The retained replay
records contain every exact procedure name and lookup return address. They prove
these particular hidden imports are not Sprite_Draw; they do not prove a universal
absence of computed imports, or that all these routines execute in live play.

**Corrected obfuscated continuation:** parent `0x6010C0` saves registers with
PUSHAD and calls `0x60110D` at `0x6010F3`. That trampoline pops `0x6010F8`, adds
`0x2C`, and jumps to `0x601124`, whose POPAD restores the registers. The apparent
SUB at `0x601122` is a misaligned decode bypassed by this caller. A named BN
internal-label function now exposes the real continuation, which builds
`NtQueryInformationProcess` starting at `0x601125`. Its GetProcAddress call is
`0x6011AF`; `0x6011B5` is the result store. Parent, trampoline and continuation
are separately named/commented. This is a process/module-inspection path, not a
missing or nonfunctional draw routine.
Original-x86 replay now starts at the real parent `0x6010C0` and verifies the
executed trampoline/POPAD sequence plus the lookup of `ntdll!NtQueryInformationProcess`.
It does not execute the misaligned `0x601122` block. The replay stops at the lookup;
it does not claim to execute the subsequent Windows process query.

**Instruction-boundary audit (2026-09-14):** an additional search starts at every
`FF` byte in executable PE sections, independently of the BN function-start list,
and selects memory-indirect call/jump patterns with displacement 4, 8, 12 or 44.
This produces 1,850 Conquer patterns and 121 graphic patterns, not that many actual
calls. Of the 154 Conquer patterns missing from the earlier call-site index, 153
lie inside a different BN-decoded instruction; one is a real tail jump. The one
additional graphic pattern also lies inside another instruction. The native
validation retains 121 parent disassemblies, with 48,738 instruction lines checked
against the clean Conquer image, plus the separately captured actual parents below.

The nearest function start was insufficient for five Conquer patterns. Full
`CMyShellDlg_WindowProc_DispatchMainWindowMessages` resolves `0x5BEB47`,
`0x5C0430` and `0x5C303E` inside instructions starting at `0x5BEB42`,
`0x5C042C` and `0x5C3039`. Parent `0x6A941A` resolves `0x6A977D` inside
the conditional branch at `0x6A9778`; parent `0x754D4C` resolves `0x754E35`
inside the call at `0x754E31`. In graphic.dll, `0x10029B81` is inside the branch
at `0x10029B7C`. These are resolved using native instruction boundaries and parent
control flow, not dismissed because a short exception helper lacked useful HLIL.
Parent `0x6A941A` is now named `MonsterStatusEffectCache_LoadConfiguredEffect`:
it reads `ini/MonsterStatus.ini` keys `2deffect`/`3deffect`, constructing a
CAniEffect or Game3DEffect record. The conditional branch is not a virtual draw.

The real tail jump is Conquer `0x6D51DE`, now in
`BurstEffectController_ClearSix3DEffectGroups` (`0x6D5195`). It invokes
slot `+8` on the nullable group at `this+0x38`, after doing the same for groups
`+0x24/+0x28/+0x2C/+0x30/+0x34`. `0x6D59C2`, now
`BurstEffectController_InitializeFadeOutEffect`, constructs `+0x38` with
`Game3DEffectCreate(0)` and adds `wumo_ondis`. Role3D's factory `0x10008700`
calls `Game3DEffect_ConstructHeader`; the constructor installs vtable `0x1001D39C`.
Native bytes at `0x1001D3A4` are `60 A6 00 10`, identifying slot `+8` as
`Game3DEffect_ClearAllEffectInstancesAndResetHeader` (`0x1000A660`). This closes
the specific receiver/slot ambiguity: it is an effect clear/reset, not a sprite draw.
The associated eject/drop/fade-out helpers have semantic BN names and comments;
these are analyst names, not a claim to have recovered original C++ symbols.
The other group factory paths are also resolved: `0x6D51E2` stores `+0x24`,
`0x6D530B` stores `+0x28/+0x2C`, `0x6D5633` stores `+0x30`, and `0x6D5B54`
stores `+0x34`, all from `Game3DEffectCreate(0)`. The register calls at
`0x6D531D/0x6D533E` use EDI loaded from that factory's IAT entry `0x8449B4`.
This establishes the corresponding constructor paths for all six group fields.

**Caller ledger:** the follow-up adds instruction-backed mode-0 provenance for 43
selected call sites; the combined ledger has 68 records, including existing
forwarders and qualified candidates. The movie draw at `0x68C701` specifically
uses `xor ecx,ecx` at `0x68C6E7` followed by `push ecx` at `0x68C6ED`.
Historical captures containing the earlier mistaken address are retained as
history; the current ledger and this note contain the corrected proof.

These exclusions close the selected search leads. They do **not** prove complete
computed-call or aliased-field-write coverage, and no verified retail mode-2
consumer or caller/target pair has emerged. Absence of a found consumer remains
an unresolved reachability result, not proof that mode 2 is dead or equivalent
to mode 0. The machine-readable records are retained in `mode2-followup/`.

**Verification retained on 2026-09-14:** the reproducible follow-up probe passes
for 20,379 standalone captured instruction lines, 48,738 instruction lines in
the 121 boundary parent captures, all 155 additional pattern classifications,
38 compressed checkpoint checksums, and seven original-x86 lookup-prefix replays.
Capture-line counts overlap and are not unique instruction counts. The separate
combined `captures/` verification contains 23,005 lines across 108 successful
captures; the one rejected MCP response is excluded. The earlier 8,800 Sprite_Draw
CPU cases and 88 resolved DDS frame records remain retained historical results,
not newly observed GPU or live-retail results. Live MCP readback confirms all 44
names in the earlier four-module rename selection, along with the separately
retained follow-up names/comments. Database saving remains user-managed.

#### Closure answers and safe compatibility boundary

| Required question | Answer |
|---|---|
| 1. Mode 1 production reachability? | **Yes**, conditional firework packet/emitter/render paths, with literal mode 1. No live packet/frame capture claimed. |
| 2. Which branches? | ONE/ONE for the verified DXT3 families when uploaded as DXT3. Alternate SRCCOLOR/ONE has no verified retail consumer; device fallback coverage is unresolved. |
| 3. Format semantic to retain? | The native `C3Texture+0x18` decision value: post-upload GetLevelDesc format for loaded textures; separately, selected-request metadata for created textures. Not generic alpha capability or modern storage format. |
| 4. Controlling alpha/color? | Vertex-0 packed diffuse high byte; SetColor writes all four. RGB does not select the branch. Wrapper zero retains prior color. |
| 5. Actual mode-1 combinations? | Full-texture, native-size, opaque-white firework draws, repeated with coordinates reset. Effect stretch/retained-color path is a candidate, not proven exact-record activation. |
| 6. Mode 2 production reachability? | **Not verified.** Generic forwarding capability is proven; absence/unreachability is not. |
| 7. Mode 2 on alpha target? | No verified caller/target pair. TargetBmpCreateEx capability alone is insufficient. |
| 8. Mode 2 framebuffer effect? | No verified retail effect. Its conditional RGB-only write and fixed-mask side effects are known exactly. |
| 9. Actual mode-2 combinations? | None verified. |
| 10. Mode-1 blockers? | No ambiguity in the primitive predicate/state writes. Complete all-consumer acceptance still needs indirect-caller closure, target/ambient-state provenance and device-dependent upload-format coverage. |
| 11. Mode-2 blockers? | Real retail consumer, mode provenance, target identity/format, entry state and downstream alpha use remain unestablished. Primitive state contract itself is known. |
| 12. Classification? | Mode 1: **required compatibility behavior**. Mode 2: **defer until a real consumer is verified**. Neither is proven unnecessary legacy machinery. |

For a later OpenConquer.Rendering implementation, the safe native behavior contract is
the exact mode-1 predicate and factor pair, existing coordinate/color wrapper semantics,
and the precise mode-2 state transition if a consumer is later established. This audit
does not authorize replacing the six-format test with `hasAlpha`, inferring blending
from the newly uploaded modern texture, assuming alpha is multiplied into additive RGB,
or treating an all-bits mask write as restoration of prior state. No API design or modern
production change is made here.

**Remaining unknowns:** complete indirect-call/field-writer reachability (including
C3DTextureX consumers), air-bubble activation/resource initialization, actual activation
and retained diffuse state of MapItemFlash, uploaded-format fallback outcomes across
devices, full inherited target/texture-stage/blend-operation state at every consumer,
and any mode-2 retail consumer/alpha-target/downstream-alpha use. Exact GPU rounding and
driver acceptance of the `0xFFFFFFFF` mask are not established by CPU replay. These
limits prevent claiming universal closure or "no remaining unknowns."

To establish a positive retail mode-2 result, a native capture must identify the
actual `Sprite_Draw` invocation, its caller/mode provenance, active target and
description, relevant entry state, the state-call outcomes, and any subsequent
use of target alpha. At the unmodified x86 entry `0x10015EE0`, `[ESP+4]` is the
sprite pointer and `[ESP+8]` is the mode; the function's initial pushes account
for its later stack offsets. A breakpoint that never fires in selected scenes
would not prove global unreachability. Full static absence would separately require
closure of computed dispatch and aliased state writers. Neither result is asserted
by this evidence package.

## Sprite rotation (`Sprite_Rotate`)

Ordinal `150`, `0x100159D0`, takes signed integer degrees modulo 360 and rotates
the current four vertex X/Y pairs in place. The pivot is computed as
`((v2.x-v0.x)/2+v0.x, (v1.y-v0.y)/2+v0.y)`, so repeated direct calls can move
the pivot. Positive matrix rotation is clockwise in screen coordinates.

**Numerical parity requires a specified math backend:** the native SSE helper
uses an unrefined reciprocal-derived scaling intermediate; scalar and 3DNow!
paths have different arithmetic. Do not assume a universal pure-rotation or
zero-angle identity result. The complete native proof, helper names, caller
ordering and remaining limits are in
[18_sprite_rotate_native_contract.md](18_sprite_rotate_native_contract.md).

## Sprite geometry (`Sprite_SetCoor`)

### `Sprite_SetCoor` (ordinal `153`, `0x10015AF0`)

Signature (export name):

- `?Sprite_SetCoor@@YAXPAUC3Sprite@@PAUtagRECT@@HHKK@Z`

Observed behavior:

- Computes normalized texture UV coordinates from the provided `RECT` relative to the underlying texture's width/height.
  - If `RECT` is null, it sets UVs to cover the full texture `[0..1]`.
- Computes screen-space vertex coordinates from `(x, y)`:
  - writes `x - 0.5` and `y - 0.5` into the left/top vertex positions (the `-0.5` offset is applied consistently).
  - computes right/bottom using `(x + width) - 0.5` and `(y + height) - 0.5`.
- The width/height used are either explicitly supplied by the last two parameters, or default to the underlying texture width/height.

## Sprite pipeline prepare (`Sprite_Prepare`)

### `Sprite_Prepare` (ordinal `148`, `0x10015D20`)

`Sprite_Prepare` writes a fixed render-state and texture-stage-state baseline used by the sprite path.

Verified call chain (all via `IDirect3DDevice8`):

- `+0xC8` => `SetRenderState`
- `+0xFC` => `SetTextureStageState`
- `+0x130` => `SetVertexShader`

`SetRenderState` writes:

| State id | Value | Evidence |
|---:|---:|---:|
| `0x1B` | `1` | `0x10015D27..0x10015D2C` |
| `0x07` | `0` | `0x10015D39..0x10015D3E` |
| `0x0E` | `0` | `0x10015D4B..0x10015D50` |
| `0x09` | `1` | `0x10015D5D..0x10015D62` |
| `0x08` | `3` | `0x10015D6F..0x10015D74` |
| `0x16` | `1` | `0x10015D81..0x10015D86` |
| `0x1A` | `0` | `0x10015D93..0x10015D98` |
| `0x89` | `0` | `0x10015DA5..0x10015DAD` |
| `0x93` | `1` | `0x10015DBA..0x10015DC2` |
| `0x91` | `1` | `0x10015DCF..0x10015DD7` |
| `0x0F` | `0` | `0x10015E48..0x10015E4D` |

`SetTextureStageState` writes on stage `0`:

| Stage-state id | Value | Evidence |
|---:|---:|---:|
| `1` | `4` | `0x10015DE4..0x10015DEB` |
| `4` | `4` | `0x10015DF8..0x10015DFF` |
| `0x11` | `1` | `0x10015E0C..0x10015E13` |
| `0x10` | `1` | `0x10015E20..0x10015E27` |
| `0x12` | `0` | `0x10015E34..0x10015E3B` |

Vertex shader/FVF write:

| API | Value | Evidence |
|---|---:|---:|
| `SetVertexShader` | `0x144` | `0x10015E5A..0x10015E60` |

## Locking and per-vertex color

### `Sprite_Lock` / `Sprite_Unlock` (ordinals `146` / `155`)

These call through to the underlying D3D texture object at mip level 0:

- `Sprite_Lock(sprite, rectPtr, lockedRectOut)` calls `LockRect(level=0, lockedRectOut, rectPtr, flags=0)` and returns true on `0`.
- `Sprite_Unlock(sprite)` calls `UnlockRect(level=0)` and returns true on `0`.

### `Sprite_SetColor` (ordinals `151` / `152`)

Two overloads are exported:

- `?Sprite_SetColor@@YAXPAUC3Sprite@@EEEE@Z` (ordinal `151`, `0x10015CC0`)
  - packs bytes in `ARGB` order as:
    - `arg2 -> bits 31..24` (A)
    - `arg3 -> bits 23..16` (R)
    - `arg4 -> bits 15..8` (G)
    - `arg5 -> bits 7..0` (B)
  - then writes that packed color into all 4 vertices at `sprite+0x10`, `+0x2C`, `+0x48`, `+0x64`.
- `?Sprite_SetColor@@YAXPAUC3Sprite@@K@Z` (ordinal `152`, `0x10015D00`)
  - writes the input `DWORD` directly to the same four per-vertex color slots.

Disassembly evidence (`0x10015CC0`):

- `0x10015CCA`: `mov ch, [esp+0x8]` (arg2)
- `0x10015CD9`: `mov cl, [esp+0xC]` (arg3)
- `0x10015CE0`: `or ecx, eax` (arg4 low byte)
- `0x10015CE9`: `or ecx, edx` (arg5 low byte)
- `0x10015CF3`: loop writes packed `ecx` every `0x1C` stride (4 vertices).
