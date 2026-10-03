# Static main HUD chrome (GFX-UI-001)

Clean PC 5517 `Conquer.exe` and shipped assets; verified 2026-09-23/24. English only.

## Conclusion and scope

The English static HUD uses **left-anchored, unscaled pixel artwork**, with
`CDlgMain` origin `(0, screenHeight - 141)`. The previous right-anchored default,
`screenHeight - 163`, fourth-call address `0x4BC679`, and final show-way `1`
claims are withdrawn. They do not describe the verified English path.

This contract covers Progress45 and four Dialog4 submissions. Gauges, controls,
text, hints, gameplay, Flash and sound remain outside implementation scope;
their native order is recorded only to preserve future insertion points.
No managed reconstruction or reference project supplies evidence here.

## Native call contract

`CDlgMain_RenderMainUiDialogAndStatusOverlay` starts at `0x4BC1F8`; `0x4BC202`
is its body after the exception prologue. `ESI = this` at `0x4BC208`.
Let `X = *(CDlgMain+0xF0)` and `Y = *(CDlgMain+0xF4)`.
All RECT values below are `(left, top, right, bottom)` in source pixels.

| Operation | Exact call | Arguments |
|---|---|---|
| Progress45 lookup | `0x4BC3C6` | dataset virtual `+0x10("ani/Control.ani", "Progress45", 1, 0x7530)` |
| Progress45 English draw | `0x4BC420` | ANI virtual `+0x08(0, X, Y, 0, 0)` |
| Dialog4 lookup | `0x4BC537` | dataset virtual `+0x10("ani/Control.ani", "Dialog4", 1, 0x7530)` |
| Dialog4 A | `0x4BC6B6` | ANI virtual `+0x0C(0, X, Y-3, &(0,112,256,256), 256,144, 0,0)` |
| Dialog4 B | `0x4BC6E9` | ANI virtual `+0x0C(0, X+256, Y+88, &(0,0,256,54), 256,54, 0,0)` |
| Dialog4 C | `0x4BC720` | ANI virtual `+0x0C(1, X+512, Y+88, &(0,0,256,54), 256,54, 0,0)` |
| Dialog4 D | `0x4BC75E` | ANI virtual `+0x0C(1, X+768, Y+88, &(0,64,256,118), 256,54, 0,0)` |

The two trailing arguments are **color parameter 0 and draw mode 0**. The first
argument is the ANI frame index. The pushes of `1` at `0x4BC71B` / `0x4BC75C`
select frame 1. None of these calls requests rotation.

Decisive raw instructions, with unrelated setup omitted:

```asm
004bc3d2  cmp  dword [0x96ab30], ebx  ; EBX = 0
004bc3db  je   0x4bc410
004bc410  push ebx                  ; draw mode 0 already pushed at 3DA; color 0
004bc413  push dword [esi+0xf4]
004bc419  push dword [esi+0xf0]
004bc41f  push ebx                  ; frame 0
004bc420  call dword [eax+0x8]

004bc545  cmp  dword [0x96ab30], ebx
004bc54b  je   0x4bc680             ; English panel branch
...
004bc73b  mov  edx, dword [esi+0xf0]
004bc741  add  edx, 0x300
004bc74a  mov  dword [ebp-0x44], 0x40
004bc754  mov  dword [ebp-0x3c], 0x76
004bc75b  push edx
004bc75c  push 1                    ; frame index
004bc75e  call dword [eax+0xc]
```

For correcting old citations only: the other branch uses calls `0x4BC40B`
and `0x4BC59E` / `0x4BC5E5` / `0x4BC62D` / `0x4BC75E`. It is selected by
**nonzero**, not zero. `0x4BC679` is a `PUSH 1`, not a call. Supporting that
layout is outside this English-only slice.

## Exact clean artwork and precedence

The actual loose ANI file is `ani/Control.Ani` (lookup spelling
`ani/Control.ani`). Progress45 is at line 1424, preceded by `背景(Dialog4)`
(background); Dialog4 is at line 14, preceded by `主界面窗口` (main interface).

| ANI section / frame | Exact ANI path | Decoded dimensions | Active clean storage |
|---|---|---|---|
| Progress45 / 0 | `data/main/ProgressBk.dds` | 256 × 256 | `data.wdf`, UID `0x0561D7F3`, byte offset 21563828, length 65664 |
| Dialog4 / 0 | `data/main/mainDialog1.dds` | 256 × 256 | `data.wdf`, UID `0xCAE8016F`, byte offset 21351988, length 65664 |
| Dialog4 / 1 | `data/main/mainDialog2.dds` | 256 × 128 | loose `data/main/MainDialog2.dds`, length 32896 |

SHA-256 of the exact DDS payloads, fully decoded as RGBA with Pillow:

| Frame | SHA-256 |
|---|---|
| Progress45 / 0 | `9b91a28e0170142a48dc03332691959eca01c179b9d8c592aa5b11af4f5d966c` |
| Dialog4 / 0 | `505a4655c398e41bd25698b57caa50f48376cff713e1c8c6f287a03866038fe1` |
| Dialog4 / 1 | `818d13f62509ac859fb0ed72d36ec6aeb2b12f9ed3dee3c6172171d99ba86f41` |

**The archive also contains a different Dialog4 frame 1. Do not select it over
the loose file.** Its UID is `0x4529D0E7`, offset 21417652, length 32896,
SHA-256 `75be49088aeeb55b5b6cb5c3ae2545c9cff22aaf02d916950890f7733ceedba9`.
The active loose file is established by this native path:

1. `graphic.dll` `CMyBitmapSpriteFrame_LoadImageAndCreateSprite`
   calls `Sprite_Load` at `0x100120EC` for DDS paths.
2. `C3_CORE_DLL.dll` `Texture_Load` calls `DataFile_UnpackSearch` at
   `0x10016415`; nonzero branches at `0x1001641F` to the file-path loader
   call `0x100165AF`. Otherwise `DataFile_Load` is called at `0x10016438`.
3. `DataFile_UnpackSearch` (`0x10001D00`) uses `TqFCheck(path, 1)`.
   `TqPackageWdf.dll` `TqPackage_CheckPathByFileType` (`0x10001640`)
   selects its loose-only branch at `0x10001651`, calling
   `GetFileAttributesExA` at `0x1000169B`.

Archive UIDs were obtained by executing the original WDF normalization/hash
instructions at `TqPackageWdf.dll` `0x100099D0`, not a managed hash port.

## Lookup and failure behavior

The EXE import resolves to `GraphicData.dll`'s dataset. Its vtable
`0x10030190 + 0x10` contains `GameDataSet_QueryAniResourceByDualPath`
(`0x100045E0`). Both EXE requests pass load mode `1` and cache timeout
`0x7530` (30000 milliseconds).

The query hashes the two strings, uses the animation cache at dataset `+0x10C`,
returns an existing resource at `0x100046DC`, or submits a mode-1 request at
`0x10004992`; the resulting ANI pointer is stored at `0x100049A2` and returned
at `0x10004A13`. For an already pending cache entry, the mode-1 path pumps
requests/completions, with a 3000-ms wait bound at `0x10004715`.

`GameDataSet_CreateAniResource` (`0x100062B0`) calls `graphic.dll!AniCreate`
at `0x100062C9`. In `graphic.dll`, `AniCreate` calls virtual creation at
`0x1000C035`, releases failed creation at `0x1000C045`, and returns null at
`0x1000C05A`. `CAniX_CreateFromDataAndIndexPath` looks up the section at
`0x1000BC3A`; a missing section logs `AniIndexInfo Not Found %s` and returns
zero at `0x1000BC71`. A frame-image load failure branches at `0x1000BD6F`,
logs the failed image, destroys partial frames, zeroes frame count at
`0x1000BE01`, and returns zero at `0x1000BE1A`.

| Condition at the EXE | Exact branch | Consequence |
|---|---|---|
| HUD gate zero | `0x4BC3A5 → 0x4BCD37` | no background, gauges, panels or subsequent HUD art; preceding range/Flash work already ran |
| Progress45 lookup null | `0x4BC3D0 → 0x4BC423` | background only skipped; HP and remaining HUD continue |
| Dialog4 lookup null | `0x4BC53F → 0x4BCD37` | earlier background/gauges remain; panels and all later HUD work are skipped |
| ANI draw returns zero | no return-value test at these sites | no extra HUD cancellation; CAniX return is frame-sequence information, not a reliable draw-success result |

Deleting a file does not invalidate an already cached ANI immediately. The
missing-resource rules describe a failed lookup/load, not immediate behavior
of a previously loaded cache after a disk edit. An empty but successfully
created ANI is non-null and its draw methods perform no submission; it is
not equivalent to a null lookup.

## Gate ownership and initialization

`CMyShellDlg_ConstructAndInitializeMembers` establishes the embedded receiver:
`LEA ECX,[ESI+0xF98]` at `0x5ADB11`, call `CDlgMain_Constructor` at `0x5ADB1B`.
Consequently:

```text
CDlgMain = CMyShellDlg + 0xF98
CDlgMain draw X +0xF0 = CMyShellDlg +0x1088
CDlgMain draw Y +0xF4 = CMyShellDlg +0x108C
CDlgMain gate   +0x110 = CMyShellDlg +0x10A8
```

The receiver-proven gate stores are constructor zero at `0x4B5F7F` and
initializer one at `0x4BBF04`. The latter writes EAX=1 to `[EBX+0x110]`,
where EBX is the CDlgMain receiver saved at `0x4BB879`. This enables the
ordinary successfully initialized HUD. Early control-initialization failure
returns zero through `0x4BBBF1`; allocation-failure exits can also bypass the
assignment. Successful OS/resource initialization is required, not guaranteed
against runtime allocation or device failure.

Progress45 is queried during rendering, not during this initializer; its
absence does not itself prevent enabling the gate. In particular, missing
ANI data in `CMyProgress_Init` does not alone imply init failure: the method
returns 1 at `0x5A9996` after its guarded lookup.

Writer enumeration used function-bounded BN receiver analysis plus a saved
instruction candidate census for `+0x110` and explicit embedded `+0x10A8`.
It identified these two CDlgMain stores; same-offset stores on unrelated
classes are not HUD writers. The census is not presented as an exhaustive
proof against every possible indirectly computed alias.

## English mode and placement in both resolutions

`0x96AB30`, renamed `g_uiArabicLikeLayoutEnabled`, is zero-initialized in the
PE's zero-filled data tail. Startup stores the result of
`strcmp(datasetString(10426), "Arabic") == 0` at `0x5AAA77`, following string
lookup `0x5AAA67` and comparison `0x5AAA6B`. Clean `ini/StrRes.ini` line 281
contains `10426=English`. The dataset virtual `+0x3C` resolves to
`GraphicData.dll!GameDataSet_GetStringById` (`0x1000A030`), which calls
`StringTable_LookupById` at `0x1000A03B`. The string-table initialization calls
`StringTable_LoadStrResIni` at `0x1001DBC2`; its `fopen` at `0x1002BD46`
opens `ini/StrRes.ini`. Thus the English branch is zero. Other-language
support and command-driven toggling are outside the narrowed scope. The
direct writer inventory contains startup `0x5AAA77`, set-one `0x5375B4`, and
set-zero `0x5375D6`. All 285 BN code xrefs were decoded; the additional data
xref at `0x59CF40` belongs to a read-only CMP operand beginning at `0x59CF3E`.
This establishes the shipped English initialization; it does not assert that
the alternate command-selected state is unreachable.

Successful `ANSWER_OK` handling calls shell placement at `0x5DCC9D`.
Its raw sequence proves the final initial origin, independently of the GUI files:

```asm
005b9222  mov  ebx, 0x8d
005b9227  push 1                   ; repaint
005b9229  push ebx                 ; height 141
005b922a  call [GetScreenWidth]
005b9230  push eax                 ; width W
005b9231  call [GetScreenHeight]
005b9237  sub  eax, ebx             ; H - 141
005b9239  lea  ecx, [esi+0xf98]     ; CDlgMain
005b923f  push eax                 ; y
005b9240  push 0                   ; x
005b9242  call CWnd::MoveWindow
```

The decompiler currently misrecovers some `MoveWindow` parameters; these raw
pushes determine the call contract. The old function comment also incorrectly
claimed an early return when shell `+0x179684` is already set. In fact,
`0x5B91FA → 0x5B9202` skips only the store of 1 and continues into layout.

`graphic.dll!GetScreenWidth` / `GetScreenHeight` (`0x10013FC0` /
`0x10013FD0`) return the stored backbuffer dimensions directly.
`ChangeDisplayResolution` stores the requested width/height at `0x10013611`
/ `0x10013617`; no minus-22 or other adjustment exists in these getters.

The inherited WM_MOVE handler `CMyDialog_OnMoveCacheDrawOrigin` (`0x596473`)
calls `CWnd::Default` at `0x596476`, stores x at `0x59647F` into `+0xF0`,
and y at `0x596489` into `+0xF4`. Message-map chain:
CDlgMain getter `0x4BB863 → 0x855BB0`; base getter `0x42E58B → 0x8673A0`;
WM_MOVE entry `0x8673C0` has message 3 and handler `0x596473` at `0x8673D4`.
There is no intermediate Y transform in `CMyDialog_RenderIfVisible`
(`0x5971CF`), whose virtual `+0xF4` call at `0x5971E8` dispatches through
`0x855EB4` to the CDlgMain renderer.

Screen-mode changes agree with initial placement:

- `CMyShellDlg_ApplyScreenMode` (`0x5D7C51`) sets 800×600 for modes 0/1
  (`0x5D831B` / `0x5D8325`, `0x5D81EB` / `0x5D81F5`) and calls relayout
  with 1 (`0x5D8367`, `0x5D8237`). Modes 2/3 set 1024×768
  (`0x5D7EEF` / `0x5D7EF4`, `0x5D7CDF` / `0x5D7CE4`) and call relayout
  with 2 (`0x5D7F31`, `0x5D7D21`).
- `CMyShellDlg_RelayoutChildWindowsForScreenMode` (`0x5D9BDF`) loads the
  selected GUI file through `0x5D9C20`. `UiLayout_LoadGuiFileForScreenMode`
  (`0x593D5B`) chooses `ini/GUI800X600.ini` for 1, `ini/GUI.ini` for 2.
- It obtains the registered window/parent IDs at `0x5D9CAB` / `0x5D9CBA`,
  uses parent ID zero when unregistered, reads the dialog rectangle at
  `0x5D9F0F`, and calls `MoveWindow` at `0x5D9F2C`.
  `UiLayout_GetWindowRectByDialogIds` (`0x5938A3`) reads x/y/w/h as pixels.
- Clean `[0-130]`: 800 file `(x,y,w,h)=(0,459,800,150)`; 1024 file
  `(0,627,1024,142)`. **Configured window height is not a scale for artwork.**
  The initial login MoveWindow uses height 141; the screen-mode relayout can
  use the INI heights 150/142 while preserving these identical origins.
- Both sections set `ChickToTop=0` and omit `FlyDir` / `MoveBind`.
  `CMyDialog_LoadWindowBehaviorFromGuiIni` (`0x596901`) reads those options;
  the constructor clears slide direction/timer (`0x59615D`, `0x5961A9`).
  Consequently the horizontal slide helper `0x596C01` contributes no
  animation offset in this clean main-dialog configuration.

| Submission | Formula | 800×600 destination | 1024×768 destination | Size |
|---|---|---|---|---|
| Progress45 | `(0,H-141)` | `(0,459)` | `(0,627)` | 256×256 |
| Dialog4 A | `(0,H-144)` | `(0,456)` | `(0,624)` | 256×144 |
| Dialog4 B | `(256,H-53)` | `(256,547)` | `(256,715)` | 256×54 |
| Dialog4 C | `(512,H-53)` | `(512,547)` | `(512,715)` | 256×54 |
| Dialog4 D | `(768,H-53)` | `(768,547)` | `(768,715)` | 256×54 |

These are submitted rectangles, including portions beyond the backbuffer.
Do not scale, re-anchor or shrink them to fit 800 pixels.

## Dialog template boundary

The clean PE `RT_DIALOG 0x82`, language `0x804`, at RVA `0x5759B8` is a
400×70 **dialog-unit** template with 23 controls and style `0x40000040`
(`WS_CHILD | DS_SETFONT`). CDlgMain passes ID `0x82` to its base constructor
at `0x4B5487` / `0x4B548C`; `CMyDialog_CreateWindowOnly` calls
`CDialog::Create` at `0x596559`.

It creates the HWND and child controls. Base initialization can reposition
the HWND from GUI INI through `0x591DF4`; successful-login placement then
explicitly applies the pixel origin above. Progress45 and Dialog4 have no
child-control binding used by their draw sites: the renderer directly queries
ANI and submits the listed pixel rectangles. There is **no** `W/400`, `141/70`,
`163/70`, dialog-base-unit, or child-control scale applied to this static art.
This does not assert that all other HUD controls avoid scaling.

## Draw order and native sprite state

| Sequence | Native site |
|---|---|
| Update gauge ranges | `0x4BC20A` |
| Flash-host visibility/lifecycle work | `0x4BC215`–`0x4BC39A` |
| Gate, then Progress45 | `0x4BC39F`, `0x4BC420` |
| HP40, MP41, stamina46 | `0x4BC455`, `0x4BC48F`, `0x4BC4C2` |
| Conditional stamina overflow47 | `0x4BC517` |
| Dialog4 A/B/C/D | `0x4BC6B6`, `0x4BC6E9`, `0x4BC720`, `0x4BC75E` |
| Skill42, XP44 | `0x4BC78E`, `0x4BC7F7` |
| Grid, then buttons/checks | grid begins `0x4BC810`; controls `0x4BC971`–`0x4BCC0F` |
| Selected-skill image, then conditional highlights | `0x4BCC2C`, subsequent tail to `0x4BCD37` |

The production API must preserve two separate insertion points: background
before HP/MP/stamina and panels after them but before skill/XP. A single
indivisible chrome draw operation would erase that interleaving boundary.

`graphic.dll`'s ANI vtable `0x1003994C` maps `+0x08` to `0x1000BE20`
and `+0x0C` to `0x1000BE70`. Full-frame dispatch calls the frame's `+0x04`
at `0x1000BE55`; sub-rectangle dispatch appends literal rotation 0 at
`0x1000BE89`, then calls frame `+0x08` at `0x1000BEB6`.
The frame vtable `0x10039A34` resolves these to `0x10012120` / `0x10012190`.

- The wrappers call `CMyBitmap::PrepareSprite` when necessary; it calls
  `C3_CORE_DLL.dll!Sprite_Prepare` through `graphic.dll` `0x100136B9`.
- Color parameter zero bypasses `Sprite_SetColor`; it **preserves** vertex
  color rather than imposing transparent black. Newly loaded sprites start
  white (`Sprite_Clear`, `C3_CORE_DLL.dll` `0x10015840`).
- Full-frame coordinates use `Sprite_SetCoor` at `graphic.dll` `0x1001216B`;
  cropped coordinates at `0x10012279`. No Sprite_Rotate call is taken.
- `Sprite_Draw` receives mode 0 (`0x1001217A`, `0x100122A1`). In
  `C3_CORE_DLL.dll`, mode 0 sets source/destination blend to
  `SRCALPHA` / `INVSRCALPHA` at `0x10015FA6` / `0x10015FB8`.
- `Sprite_SetCoor` (`0x10015AF0`) applies the existing half-pixel position
  convention, normalizes source UVs by texture dimensions, and uses supplied
  destination widths/heights. Full-frame zeros use the texture's dimensions.
- No additional HUD-specific tint, blend mode, rotation, scissor/clip rectangle,
  or scale is established by these call sites. Normal render-target/viewport
  clipping and the existing sprite preparation/state contract still apply.
  The shell's Win32 region is not supplied as a per-sprite clipping parameter.

## Evidence, annotations and remaining limits

Evidence bundle:
[raw BN captures, assets and replay](../../10_work/docs/evidence/gfx-ui-001-static-hud-5517/README.md).
80 saved function captures contain **14,761 raw instruction lines**, checked
against the original clean PE bytes. Seven original-instruction replays verify
the English background/panel arguments at both heights, missing-background
continuation, missing-panel exit and zero-gate exit. Only resource lookup/draw
boundaries were stubbed; this is not a GPU or live-client screenshot test.

Relevant helpers were renamed and annotated in Binary Ninja before note updates.
The evidence bundle preserves their names/comments for recovery; the user owns
saving the databases. No production code was changed.

There is **no unresolved asset, argument, placement, failure-branch or draw-order
ambiguity for the clean English static-art path**. The gate-writer census has
its explicit static-analysis boundary above; this does not claim proof against
arbitrary aliases or externally modified state. Live GPU visual conformance is
a later implementation validation, not an outcome of this evidence pass.
Other-language behavior, custom GUI configuration and the excluded dynamic HUD
features are outside this contract.
