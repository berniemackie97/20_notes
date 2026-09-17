# Retail 5517 depth, stencil, multisampling, and presentation

## Result

The retail v5517 client always reaches a windowed Direct3D 8 device with an automatic
`D3DFMT_D16` depth buffer. It does not create or use a stencil buffer. The dormant
`D3DFMT_D24S8` library branch requires bit 31 of the upper `HintGraphicDetail` flags, but every
retail caller supplies a literal whose upper bits are zero. Device reset and resolution-change
paths preserve the original depth format.

The managed OpenGL target should therefore use a 16-bit depth-only attachment. It should not
allocate stencil merely because the native library contains a D24S8 branch.

## Evidence scope and cross-binary completeness

The complete clean retail runtime module set was checked through PE import tables, export tables,
symbol strings, Binary Ninja xrefs, and the relevant `LoadLibrary` / `GetProcAddress` call paths.

The only static chain is:

```text
Conquer.exe
  -> graphic.dll!CMyBitmap::HintGraphicDetail (0x10013FE0)
  -> C3_CORE_DLL.dll!HintGraphicDetail         (0x10008E40)

Conquer.exe
  -> graphic.dll!CMyBitmap::Init3DEx           (0x100131E0)
  -> C3_CORE_DLL.dll!Init3DEx                  (0x10008580)
```

- Only `Conquer.exe` imports the two `CMyBitmap` wrappers.
- Only `graphic.dll` imports the two C3 exports.
- `graphic.dll`'s `HintGraphicDetail` wrapper is a pure forwarder.
- `graphic.dll`'s `Init3DEx` wrapper forwards the five device arguments before performing its
  separately documented `graphic.ini` and camera setup.
- No other retail image contains either target export name.
- No relevant dynamic resolution path resolves either target by name or by export ordinal
  (`HintGraphicDetail` ordinal 50, `Init3DEx` ordinal 52).

This proves that no omitted retail module can supply an additional graphic-detail value or create
another device through these APIs.

## `HintGraphicDetail`

Module/function: `C3_CORE_DLL.dll!HintGraphicDetail`, `0x10008E40`.

The raw split is:

```asm
10008e41  mov esi, dword [esp+8]
10008e45  mov eax, esi
10008e47  and eax, 0xfffffff0
10008e4a  mov dword [0x100b0510], eax
10008e4f  mov eax, dword [0x100b050c]
10008e55  and esi, 0x0f
10008e5a  cmp esi, eax
10008e5c  je  0x10008e72
10008e5e  cmp esi, 3
10008e61  jae 0x10008e72
```

Therefore:

- bits 4..31 are stored in `g_GraphicDetailUpperFlags` (`0x100B0510`);
- bits 0..3 are the independent multisample quality tier cached in
  `g_GraphicDetailMultisampleTier` (`0x100B050C`);
- low-nibble values at or above 3 are rejected;
- the upper flags are stored before every early return.

The low-tier render-state writes are:

```asm
; tier 2
10008e86  push 1
10008e88  push 0xA1
10008e8e  call dword [ecx+0xC8] ; IDirect3DDevice8::SetRenderState

; tier 1
10008ea6  push 1
10008ea8  push 0xA1
10008eae  call dword [edx+0xC8]

; tier 0
10008ec6  push 0
10008ec8  push 0xA1
10008ece  call dword [ecx+0xC8]
```

Render state `0xA1` is `D3DRS_MULTISAMPLEANTIALIAS` (`161`). Microsoft documents that this state
controls sample placement when the render target is multisampled and has no effect for a
single-sample target: [D3DRENDERSTATETYPE](https://learn.microsoft.com/en-us/previous-versions/windows/embedded/ms886344%28v%3Dmsdn.10%29).

### Complete retail caller values

The only `Conquer.exe` call sites use literal values:

```asm
005aef10  push 0
005aef12  call dword [0x844c20]

005aef1b  push 2
005aef1d  call dword [0x844c20]

005aef26  push 0
005aef28  call dword [0x844c20]
```

The surrounding configuration branch selects among those three call sites; it does not compute a
fourth argument. Consequently bit 31 cannot be passed by the retail client.

## `g_GraphicDetailUpperFlags` (`0x100B0510`)

Binary Ninja and a full raw-disassembly address search find exactly two references in
`C3_CORE_DLL.dll`:

```asm
10008e4a  mov dword [0x100b0510], eax ; sole writer: HintGraphicDetail
1000865e  mov eax, dword [0x100b0510] ; sole reader: Init3DEx
```

The image value is zero. No other module imports or references the internal global.

Only bit 31 has an established meaning. Bits 4..30 are retained but never read by this binary, so
they have no proven runtime semantics in retail 5517 and are not assigned speculative names.

## Exact `D3DPRESENT_PARAMETERS` initialization

Module/function: `C3_CORE_DLL.dll!Init3DEx`, `0x10008580`.

The D3D8 structure is exactly 13 DWORDs (`0x34` bytes). Native first clears all fields:

```asm
10008637  xor eax, eax
10008639  mov ecx, 0x0d
1000863e  mov edi, 0x100b02d0 ; g_D3DPresentParameters
10008643  rep stosd
```

The populated values are:

| Offset | D3D8 field | Native value |
|---:|---|---|
| `+0x00` | `BackBufferWidth` | width argument |
| `+0x04` | `BackBufferHeight` | height argument |
| `+0x08` | `BackBufferFormat` | `0x17`, else `0x18`; creation fallback `0x16` |
| `+0x0C` | `BackBufferCount` | argument; retail passes `1` |
| `+0x10` | `MultiSampleType` | `SelectSupportedMultisampleType` result |
| `+0x14` | `SwapEffect` | `1` = `D3DSWAPEFFECT_DISCARD` |
| `+0x18` | `hDeviceWindow` | cached `g_D3DDeviceWindow`; zero on initial creation |
| `+0x1C` | `Windowed` | argument; retail passes `1` |
| `+0x20` | `EnableAutoDepthStencil` | `1` |
| `+0x24` | `AutoDepthStencilFormat` | `0x50` or dormant `0x4B` branch |
| `+0x28` | `Flags` | `0` from the clear |
| `+0x2C` | `FullScreen_RefreshRateInHz` | `0` from the clear |
| `+0x30` | `FullScreen_PresentationInterval` | `0` from the clear |

Relevant writes:

```asm
10008645  mov eax, dword [esp+0x24] ; back-buffer count
1000864f  mov dword [0x100b02dc], eax
10008654  mov eax, dword [0x100b0414] ; height
10008659  mov dword [0x100b02d4], eax
10008672  mov dword [0x100b02d0], ecx ; width
10008686  mov dword [0x100b02ec], ebx ; Windowed
1000868c  mov dword [0x100b02e8], ecx ; hDeviceWindow
10008692  mov dword [0x100b02e4], ebp ; SwapEffect = 1
10008698  mov dword [0x100b02d8], edx ; BackBufferFormat
1000869e  mov dword [0x100b02f0], ebp ; auto depth = 1
100086a4  mov dword [0x100b02f4], eax ; depth format
100086c3  mov dword [0x100b02e0], eax ; multisample type
```

The first `CreateDevice` call receives behavior flags `0x44`; retry uses `0x24`. If both fail,
native changes only the back-buffer format to `0x16`, recomputes multisample compatibility against
the same depth format, and retries `0x44` then `0x24`. It never substitutes another depth format.

The sole retail caller proves the live creation arguments:

```asm
0066dc5e  push 1                       ; BackBufferCount
0066dc60  push 1                       ; Windowed
0066dc67  push dword [0x93fd80]        ; height
0066dc6d  push dword [0x93fd7c]        ; width
0066dc73  push eax                     ; HWND
0066dc74  call dword [0x844be0]        ; CMyBitmap::Init3DEx
```

## Depth-format branch and reachability

The selection is direct and exact:

```asm
1000865e  mov eax, dword [0x100b0510]
10008663  and eax, 0x80000000
10008668  neg eax
1000866a  sbb eax, eax
1000866c  and eax, 0xfffffffb
1000866f  add eax, 0x50
```

- bit 31 clear produces `0x50` = `D3DFMT_D16` (`80`);
- bit 31 set produces `0x4B` = `D3DFMT_D24S8` (`75`).

The enum values are confirmed by Microsoft's archived Direct3D 8
[D3DFORMAT table](https://learn.microsoft.com/en-us/previous-versions/ms886236%28v%3Dmsdn.10%29).

The D24S8 path is present in the reusable C3 library but unreachable in this retail client:

1. the upper-flags image value starts at zero;
2. `HintGraphicDetail` is the sole writer;
3. every retail call passes `0` or `2`, both with bit 31 clear;
4. no second `Init3DEx` caller or alternate `CreateDevice` path exists.

Normal startup therefore definitely uses D16.

## Color-buffer format selection (`Init3DEx`)

The exact D3D8 color-format values used by `C3_CORE_DLL.dll!Init3DEx` (`0x10008580`) are:

| Value | D3D8 enum | Role |
|---:|---|---|
| `0x17` (23) | `D3DFMT_R5G6B5` | first `CheckDeviceType` probe and preferred back buffer |
| `0x18` (24) | `D3DFMT_X1R5G5B5` | second probe when 0x17 fails |
| `0x16` (22) | `D3DFMT_X8R8G8B8` | only `CreateDevice` fallback after both behavior retries fail |

Microsoft's D3D8 signature defines `CheckDeviceType(Adapter, DeviceType, DisplayFormat,
BackBufferFormat, Windowed)`, matching the native push order ([reference](https://learn.microsoft.com/en-ie/previous-versions/ms889263%28v%3Dmsdn.10%29)).
The first probe passes 0x17 for both formats; a nonnegative HRESULT branches to `0x10008632`
(`mov edx, 0x17`). On failure, the second probe passes 0x18 for both formats and a nonnegative
HRESULT branches to `0x1000862b` (`mov edx, 0x18`). If both probes fail, the function releases
`IDirect3D8` and returns `-2`; it does not attempt 0x16 in that case.

```asm
100085eb  push ebx       ; Windowed
100085ec  push 0x17      ; BackBufferFormat = D3DFMT_R5G6B5
100085ee  push 0x17      ; DisplayFormat    = D3DFMT_R5G6B5
100085f3  call [ecx+0x24] ; IDirect3D8::CheckDeviceType
100085f8  jge  0x10008632
10008601  push ebx
10008602  push 0x18      ; BackBufferFormat = D3DFMT_X1R5G5B5
10008604  push 0x18      ; DisplayFormat    = D3DFMT_X1R5G5B5
10008609  call [edx+0x24]
1000860e  jge  0x1000862b
```

After either probe succeeds, the selected 16-bit value is written to
`g_D3DPresentParameters.BackBufferFormat` (`0x100b02d8`) and used by `CreateDevice` with behavior
flags `0x44`, then `0x24`. The `0x16` path is a real control-flow fallback, not an alternate probe:

```asm
100086d1  call [edx+0x3c] ; CreateDevice, behavior 0x44
100086d6  mov edi, 0x16   ; prepare X8R8G8B8 fallback after failure
100086f4  call [ecx+0x3c] ; behavior 0x24, still using 0x17/0x18
100086f9  jge  0x1000875c
100086fb  mov edx, [0x100b02f4] ; preserve depth format
10008703  mov [0x100b041c], edi
10008709  mov [0x100b02d8], edi ; BackBufferFormat = D3DFMT_X8R8G8B8
10008733  call [ecx+0x3c] ; fallback behavior 0x44
10008751  call [edx+0x3c] ; fallback behavior 0x24
```

Therefore all three formats are reachable in the retail control flow. The static binary proves the
preference and fallback conditions but cannot prove which adapter HRESULT occurs on a particular
machine: normal/default creation starts with R5G6B5, then X1R5G5B5, and only falls back to X8R8G8B8
if both `CreateDevice` behavior attempts fail. If both `CheckDeviceType` probes fail, initialization
returns `-2` instead.

`Conquer.exe!CGameMain_InitializeGraphicsAndGameFont` (`0x66dc74`) is the sole retail call into the
`graphic.dll` `CMyBitmap::Init3DEx` import. `ResetDevice` (`0x10008af0`) passes
`g_D3DPresentParameters` unchanged, and `ChangeDisplayResolution` (`0x10008ee0`) copies all 13
DWORDs, changes only width/height, resets, and copies them back. Screen-mode changes therefore do
not reselect the color format; only a fresh `Init3DEx` invocation can re-probe it.

The ordinary gameplay frame renders to the swap-chain back buffer (`Begin3D`, `ClearBuffer`, and
`Flip` in `Conquer.exe!CMyShellDlg_RunFrameTick`), so that selected format is the effective main
render-surface precision. Optional `TargetBmpCreate`/`TargetBmpCreateEx` calls use the renamed
`graphic.dll!TargetBmpCreateInternal` (`0x100056a0`) and create separate textures with
`0x14 = D3DFMT_R8G8B8` or `0x15 = D3DFMT_A8R8G8B8`; those offscreen formats do not replace the main
back buffer.

The managed `InternalRenderTarget` currently uses `ColorAttachmentFormat = Rgba8`. This is an
explicit managed difference, not a proven native-equivalent choice: native normal startup uses a
selected 16-bit RGB format, and the effect of the higher-precision RGBA8 target on blended and
quantized output has not been established by a native/managed framebuffer comparison.

## Reset, resolution change, and recreation

`ResetDevice` (`0x10008AF0`) passes the global block unchanged:

```asm
10008af0  mov eax, dword [0x100b0484]
10008af5  mov ecx, dword [eax]
10008af7  push 0x100b02d0
10008afc  push eax
10008afd  call dword [ecx+0x38] ; IDirect3DDevice8::Reset
```

`ChangeDisplayResolution` (`0x10008EE0`) clones all 13 DWORDs, changes only width and height,
resets, and copies the successful block back:

```asm
10008ef8  mov ecx, 0x0d
10008efd  mov esi, 0x100b02d0
10008f02  lea edi, [esp+0x10]
10008f06  rep movsd
10008f09  mov dword [esp+0x14], ebx ; width
10008f0d  mov dword [esp+0x18], ebp ; height
10008f14  call dword [ecx+0x38]     ; Reset
...
10008f26  mov ecx, 0x0d
10008f2b  lea esi, [esp+0x14]
10008f2f  mov edi, 0x100b02d0
10008f39  rep movsd
```

`ChangeViewportResolution` changes only the viewport. Device-loss recovery uses `ResetDevice`.
No startup, runtime screen-mode, reset, lost-device, or recreation path can change the original
depth format or presentation interval.

## Four screen modes

`Conquer.exe!CMyShellDlg_ApplyScreenMode` (`0x5D7C51`) dispatches the byte argument exactly:

```asm
005d7c61  movzx eax, byte [ebp+8]
005d7c6e  je 0x5d8307 ; mode 0
005d7c74  dec eax
005d7c75  je 0x5d81d7 ; mode 1
005d7c7b  dec eax
005d7c7c  je 0x5d7e99 ; mode 2
005d7c82  dec eax
005d7c83  jne default ; otherwise mode 3
```

| Mode | Internal back buffer | Shell behavior | D3D `Windowed` |
|---:|---:|---|---:|
| 0 | 800x600 | windowed | `TRUE` |
| 1 | 800x600 | `ChangeDisplaySettingsA` + window movement | `TRUE` |
| 2 | 1024x768 | windowed | `TRUE` |
| 3 | 1024x768 | `ChangeDisplaySettingsA` + window movement | `TRUE` |

Modes 1 and 3 are shell/desktop display-mode fullscreen. They are not D3D fullscreen swap chains.
Runtime transitions across the 800/1024 groups call `ChangeDisplayResolution`; transitions within a
resolution group do not reset the D3D device.

The managed client intentionally remains resizable. That is a documented product difference:
resizing affects only the final presentation surface, while native game/UI calculations continue
to use the fixed internal resolution.

## Multisample selection

`SelectSupportedMultisampleType` (`0x10008390`) tries candidates 8, 4, and 2. Each candidate must
pass `IDirect3D8::CheckDeviceMultiSampleType` for both the chosen back-buffer format and chosen
depth format in windowed mode:

```asm
10008413  mov esi, dword [edi]  ; candidate 8, then 4, then 2
...
10008425  call dword [ecx+0x2c] ; check back-buffer format
...
1000843c  call dword [edx+0x2c] ; check depth format
```

The helper also refuses the verified `RADEON 9250` blacklist path. For the retail tiers:

- tier 0 selects `D3DMULTISAMPLE_NONE`;
- tier 2 selects the best supported of 8, 4, or 2 samples, else none.

The low nibble and bit 31 are independent stored controls. They are coupled only by the necessary
capability check that the selected color and selected depth formats support the same sample type.

## Stencil audit

Only `graphic.dll` imports the C3 `g_D3DDevice` global. Direct device render-state calls were
enumerated in both modules:

- 159 direct `SetRenderState` calls in `C3_CORE_DLL.dll`;
- 30 direct `SetRenderState` calls in `graphic.dll`.

None uses the D3D8 stencil-state range:

- `D3DRS_STENCILENABLE` (`0x34`)
- `D3DRS_STENCILFAIL` (`0x35`)
- `D3DRS_STENCILZFAIL` (`0x36`)
- `D3DRS_STENCILPASS` (`0x37`)
- `D3DRS_STENCILFUNC` (`0x38`)
- `D3DRS_STENCILREF` (`0x39`)
- `D3DRS_STENCILMASK` (`0x3A`)
- `D3DRS_STENCILWRITEMASK` (`0x3B`)

The exported dynamic render-state wrapper has no internal xrefs and is not imported by a retail
module.

`ClearBuffer` (`0x10008D10`) can form only target and depth flags:

```asm
10008d14  xor eax, eax
10008d1a  mov eax, 2       ; D3DCLEAR_ZBUFFER when requested
10008d27  or  eax, 1       ; D3DCLEAR_TARGET when requested
...
10008d37  push 0           ; stencil value
10008d39  push 0x3f800000  ; depth = 1.0f
10008d3f  push eax          ; clear flags: only bits 1/2
10008d45  call dword [edx+0x90]
```

`D3DCLEAR_STENCIL` (`4`) is never set. Retail gameplay rendering does not use stencil.

## Depth use and visual relevance

Depth is active, not an unused attachment. Initial device state includes:

```asm
100087fd  push 4
100087ff  push 0x17
10008802  call dword [edx+0xC8]
```

That is `D3DRS_ZFUNC = D3DCMP_LESSEQUAL`. The same state is restored after reset/resolution change.
Renderer paths also toggle `D3DRS_ZENABLE` (`7`) and `D3DRS_ZWRITEENABLE` (`0x0E`), and special
paths use `D3DCMP_LESS` where verified.

The normal frame begin clears both target and depth:

```asm
005ad965  call dword [0x844c2c] ; Begin3D
005ad96b  push 0xff000000
005ad970  push 1                ; clear target
005ad972  push 1                ; clear depth
005ad974  call dword [0x844c34] ; CMyBitmap::ClearBuffer
```

`CRole3DSceneMgr_RenderSceneToBuffer` also performs depth-only clears at `0x6B48CC` and
`0x6B491F`. D16 precision can therefore affect visible occlusion and z-fighting and must be
preserved.

## Presentation interval and VSync

`FullScreen_PresentationInterval` remains zero from the 13-DWORD clear. Reset and resolution
change preserve it. `Flip` calls `IDirect3DDevice8::Present` without another pacing flag:

```asm
10008d6b  push 0
...
10008d79  call dword [ecx+0x3c] ; IDirect3DDevice8::Present
```

The D3D8 parameter rule is that a windowed swap chain must use interval default (`0`):
[D3DPRESENT_PARAMETERS](https://learn.microsoft.com/en-us/previous-versions/ms886318%28v%3Dmsdn.10%29).
More importantly, D3D8 documents that a windowed swap chain presents through copy operations and
does so immediately; synchronized windowed copying required the distinct `COPY_VSYNC` effect:
[D3DSWAPEFFECT](https://learn.microsoft.com/en-us/previous-versions/ms886364%28v%3Dmsdn.10%29).

Retail uses `D3DSWAPEFFECT_DISCARD`, keeps `Windowed=TRUE` in every screen mode, and never requests
`COPY_VSYNC`. Its effective presentation is immediate, not forced VSync.

## Concise answers

| Question | Proven answer |
|---|---|
| A. All callers of `HintGraphicDetail`? | Three `Conquer.exe` calls at `0x5AEF12`, `0x5AEF1D`, `0x5AEF28`, through the pure `graphic.dll` wrapper at `0x10013FE0`; values `0`, `2`, `0`. |
| B. All writers/readers of `0x100B0510`? | Sole writer `HintGraphicDetail+0x0A` (`0x10008E4A`); sole reader `Init3DEx+0xDE` (`0x1000865E`). |
| C. Can bit 31 be set by retail? | No. Every reachable caller literal has all upper bits clear. |
| D. Is D16 used at normal startup? | Yes, definitely. |
| E. Is D24S8 reachable? | No in this retail client; it is a dormant C3 library branch only. |
| F. Can reset/reinit change depth? | No. Reset reuses the block; resolution change modifies width/height only; no alternate creation path exists. |
| G. Does retail use stencil? | No stencil states and no stencil clears exist in the reachable renderer. |
| H. Presentation behavior? | Interval field `0`; all modes are windowed D3D8 `DISCARD`, which presents immediately. |
| I. Any unresolved path blocking the OpenGL choice? | No. Use a 16-bit depth-only attachment and no stencil. |

## Binary Ninja changes

### `C3_CORE_DLL.dll.bndb`

- `sub_10008390` -> `SelectSupportedMultisampleType`
- `data_100B050C` -> `g_GraphicDetailMultisampleTier`
- `data_100B0510` -> `g_GraphicDetailUpperFlags`
- `0x100B02D0` -> `g_D3DPresentParameters`
- `0x100B0348` -> `g_D3DDeviceWindow`
- Added verified prototypes and evidence comments to `HintGraphicDetail`, `Init3DEx`,
  `SelectSupportedMultisampleType`, `ResetDevice`, `ChangeDisplayResolution`, and `ClearBuffer`.

### `Conquer.exe.bndb`

- `sub_5D7C51` -> `CMyShellDlg_ApplyScreenMode`
- `data_93FD7C` -> `g_ScreenModeWidthPixels`
- `data_93FD80` -> `g_ScreenModeHeightPixels`
- Added a verified prototype plus mode/caller comments.

### `graphic.dll.bndb`

- Added cross-module forwarding and lifecycle comments to the four relevant `CMyBitmap` wrappers.
