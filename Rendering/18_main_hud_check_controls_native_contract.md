# GFX-UI-005: main HUD CMyCheck native evidence

Evidence-only closure, 2026-10-01. This document covers the remaining interaction,
handler and placement questions. Existing control IDs, ANI lists, initial states,
draw order, BN_CLICKED mappings and Check40's empty handler are inputs, not new
discoveries. No managed implementation or architecture is proposed.

**Evidence levels:** **PROVEN-NATIVE** means clean EXE or bundled MFC instructions/data;
**REPLAY** means original x86 executed with the recorded boundary mocks;
**WIN32-CONTRACT** means Microsoft's published API contract. These are not a live
Windows/game trace. In particular, no target Windows USER32 binary or live
outside-release notification trace was available. Do not call that external
boundary 100% runtime verified; see the precise limit below.

Clean `Conquer.exe`: SHA-256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Bundled `mfc42.dll`: SHA-256
`721232b09c0431b57b2c5d5147114c6a139ea8d2ce98f5644013132de7c66bcf`.
EXE addresses use preferred base `0x400000`; MFC addresses use preferred base
`0x73D30000`, not an observed ASLR load address. Raw assembly, HLIL, MLIL, INI
extracts, xrefs, restorable annotations and original-instruction replay results:
[evidence bundle](../../10_work/docs/evidence/gfx-ui-005-main-hud-check-controls-5517/README.md).

## 1. State, frame and window fields

Offsets below are from the CMyCheck object, whose HWND is `+0x20`.

| Offset | Width | Proven use |
|---|---|---|
| `+0x40` | DWORD | Current ANI draw-frame index, read by Show at `0x58B8CA` |
| `+0x44` | char-buffer object | ANI section string; Show reads its buffer pointer |
| `+0x50/+0x54` | DWORD each | Cached local x/y origin |
| `+0x58` | byte | State count |
| `+0x59` | byte | Logical state; getter `0x58B907` returns AL only |
| `+0x5C/+0x60` | DWORD each | Zeroed by Init; no additional semantic name assigned here |
| `+0x64/+0x68` | DWORD each | ANI current-frame dimensions queried by Init |
| `+0x6C/+0x70` | DWORD each | Actual HWND width/height cached by Init |
| `+0x74` | byte | Tooltip hover flag, not a pressed frame or capture flag |
| `+0x78/+0x7C` | DWORD each | Additional render x/y offsets |
| `+0x80/+0x84/+0x88` | pointers | Tooltip vector begin/end/storage end; entries have stride `0xC` |

`0x58B448` stores state-count/state bytes at `0x58B53D/543`, then mirrors
zero-extended state into frame DWORD at `0x58B549`. The count and state are
distinct from native BUTTON push/check/focus bits maintained by USER32.
The class does not implement CMyButton's WM_ENABLE→frame-2 rule.

### Mouse-down, not mouse-up, cycles the state

The message-map record at `0x866FC0` is
`{0x201,0,0,0,0x31,0x58B8E4}`. Its unsigned byte loads followed by a **signed**
comparison implement:

```c
void OnLButtonDown(unsigned flags, Point point) { // 0x58B8E4
    int count = (uint8_t)this[0x58];
    int state = (uint8_t)this[0x59];
    int next = state < count - 1 ? state + 1 : 0;
    this[0x59] = (uint8_t)next;           // 0x58B8F6
    *(uint32_t *)(this+0x40) = (uint8_t)next; // 0x58B8FC
    CWnd::Default();                     // 0x58B8FF
}
```

For count 2, `0→1→0`. Count 0 and count 1 both produce zero. A state at or
beyond the last valid state resets to zero. Neither the supplied point nor flags
is tested here. There is no local enabled test, PtInRect, SetCapture,
ReleaseCapture, sound, redraw call or parent notification.

**Ordering is proven:** state byte, frame DWORD, then default BUTTON processing.
A delivered down changes the image state even if no accepted click notification
ever follows. There is no release-time state rollback in CMyCheck. This is why
an outside release or lost capture must not be modeled as undoing these two
stores. A later application command may independently reset a check, notably
Button411 inspection-mode cleanup.

### Exact `0x58B91D` behavior

```c
void SetStateByteIfInRange(uint32_t argument) { // analyst name
    uint8_t requested = (uint8_t)argument;     // 0x58B91D
    if (requested >= this[0x58]) return;       // unsigned JAE, 0x58B924
    this[0x59] = requested;                    // 0x58B926
    *(uint32_t *)(this+0x40) = requested;      // 0x58B92C
}
```

It is a bounds-checked setter, not a toggle, clamp, press handler or EnableWindow
equivalent. Only the low byte of the argument matters: `0x100` requests zero;
`0x101` requests one; `-1` requests 255 and is rejected for every possible byte
count. Rejection preserves **both** fields, including an existing mismatch.
Acceptance synchronizes them. It makes no calls and sends no notification.
Return-register contents are not a success-result contract.

Other reviewed entry points:

| Address | Exact behavior |
|---|---|
| `0x58B907` | `AL = byte[this+0x59]`; upper EAX is unspecified by this getter |
| `0x58B90B` | Copy DWORD local x/y to caller POINT and return its pointer |
| `0x58B871` | Store DWORD render offsets at `+0x78/+0x7C`; do not move HWND |
| `0x58B882` | Validate hover; query `ani/Control.ani`, section buffer, `1,30000`; if found, submit ANI vfunc `+8(frameDWORD,parentX+localX+offsetX,parentY+localY+offsetY,0,0)`; then call tooltip even on lookup failure |
| `0x58B6BD` | If hover is set, query cursor, GetWindowRect and WindowFromPoint; preserve it only for self-or-parent HWND **and** PtInRect success; otherwise clear byte `+0x74` at `0x58B72B` |
| `0x58B733` | Tooltip only: require nonempty `+0x80..84` vector and hover; load font settings (log and return on failure), measure maximum line width, then call `0x592D78` at `0x58B865` |
| `0x58B932` | Post parent WM_MOUSEMOVE, then set hover; no Default call |
| `0x58B97E` | WindowProc special cases and delegation described below |

Tooltip x is `parentX+localX`; y is
`parentY+localY - DWORD[0x867380] - lineCount*normalFontHeight`, with native signed
integer arithmetic. It does not add the Show-only `+0x78/+0x7C` offsets. Width is
the maximum measured line width; line-count division uses vector byte size /12.
None of these tooltip operations writes the state byte or frame DWORD.

## 2. Capture, release, notifications and hit testing

The **complete CMyCheck message map** is four entries and a terminator:

| Entry address | Message | Target |
|---|---|---|
| `0x866FC0` | WM_LBUTTONDOWN `0x201` | `0x58B8E4` |
| `0x866FD8` | WM_MOUSEMOVE `0x200` | `0x58B932` |
| `0x866FF0` | WM_SETCURSOR `0x20` | `0x58BA01` |
| `0x867008` | WM_MOVE `3` | `0x5A3414` |
| `0x867020` | all zero | terminator |

Map getter `0x58B442` returns `0x866FB8`; base getter `0x589F03` reads the
imported CWnd map. The bundled MFC CWnd map at `0x73DD72A4` and its CCmdTarget
base do not add a mouse-up/capture-cancellation handler. This is checked from
their actual map records, not just the absence of a named EXE function.

`0x58B97E` consumes WM_ERASEBKGND with result 1; WM_NCPAINT with result 0;
WM_PAINT with BeginPaint/EndPaint and result 0. Private `0x271C` sign-extends four
16-bit coordinates/sizes, calls MoveWindow with repaint=1, returns zero.
Other messages call `CWnd::WindowProc` at `0x58B9F7` → EXE thunk `0x77716C`.

The bundled DLL proves the rest of the delegation:

* `CWnd::WindowProc` (`MFC+0x1B77`) calls virtual `+0xA4` OnWndMsg and, when
  unhandled, virtual `+0xA8` DefWindowProc.
* CMyCheck's `+0xA8` is EXE thunk **`0x777160`**, IAT `0x8445CC`, MFC ordinal
  2385, DLL RVA `0x2127`. It calls `CallWindowProcA` with saved super-procedure
  `CWnd+0x2C` (or class-super fallback); otherwise calls `DefWindowProcA`.
* `CWnd::Default` (`0x777268`, IAT `0x844518`, ordinal 2379, DLL RVA `0x21C5`)
  retrieves the current message and directly invokes that `+0xA8` slot.
* The `+0x9C` slot/`0x777172` is **not** this DefWindowProc route. Raw vtable and
  MFC ordinal resolution take precedence over a misleading thunk label.

The four resource controls use predefined BUTTON class atom `0x80`, style
`0x5001800B`, exstyle zero. CMyCheck thus delegates button capture/release and
accepted-click generation to the original Windows BUTTON procedure; it does
not replace them with its own capture state machine. Microsoft's documented
BUTTON processing releases capture on WM_LBUTTONUP and cancels a captured click
on loss of focus. BN_CLICKED reaches the parent through WM_COMMAND; a disabled
button does not send it. These are **WIN32-CONTRACT**, not captured target-OS
instruction traces. [Button messages](https://learn.microsoft.com/en-us/windows/win32/controls/button-messages),
[BN_CLICKED](https://learn.microsoft.com/en-us/windows/win32/controls/bn-clicked).

**Important native exception:** `0x58B932` swallows default WM_MOUSEMOVE. It
packs `low16(point.x+localX)` and `low16(point.y+localY)` into LPARAM, forwards the
same flags with PostMessageA at `0x58B96F`, then writes hover=1 at `0x58B975`.
Consequently a textbook unmodified-button drag/outside-release model is not
sufficient evidence for this subclass. The order between USER32's capture
release and BN_CLICKED, and its exact outside-release acceptance after swallowed
mouse moves, **remain unobserved on a target Windows runtime**. Neither has been
invented from Wine, ReactOS, filenames, or a mocked replay.

What is closed for inside/outside release:

| Event | Proven client-owned state behavior |
|---|---|
| Delivered down inside | Advance `+0x59/+0x40`, then Default |
| Delivered/synthetic down outside | Same native state advance; no point test in this handler |
| Up inside or outside | No CMyCheck state/frame store; delegates through MFC to BUTTON |
| Mouse move outside then back inside | No state/frame change; forwarding and hover behavior only |
| Capture lost / cancellation | No CMyCheck rollback handler |
| Accepted BN_CLICKED | Handler executes after the earlier down's state change in an ordinary mouse-click sequence; two handlers read that current state |
| Direct handler/WM_COMMAND invocation | Does not synthesize the preceding down or toggle |

**Clickable area:** normal uncaptured input uses the actual HWND rectangle,
subject to ordinary visibility, enablement, capture and occlusion. These four
unbordered 22×22 controls have the full client rectangle as their input surface.
DDS natural dimensions, opaque-pixel bounds and `+0x64/+0x68` are not the hit
rectangle. There is no texture-alpha/CAlphaMask test in this control's input
path. A transparent rendered pixel inside the HWND is not an input hole.

Hover validation explicitly uses GetWindowRect, then **left/top inclusive,
right/bottom exclusive** PtInRect. This hover test must not be confused with an
extra mouse-down gate. The same half-open rectangle notation is used in the
placement table. [PtInRect contract](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-ptinrect).

Parent clipping is also closed: shell layout ORs the entire Check40,
Button411, Check46 and Check43 HWND rectangles into the main HUD polygon,
using GetWindowRect → ScreenToClient(CDlgMain) → CreateRectRgnIndirect →
CombineRgn(RGN_OR=2), at `0x5B976A..0x5B9829`, then SetWindowRgn at `0x5B9838`.
These rectangles are not removed by transparent parts of the shaped HUD.

## 3. Full handler bodies and observable effects

Names below are analyst names, not recovered native symbols. The offset inputs
are retained for clarity:

| Control | CDlgMain member | CMyShellDlg member |
|---|---|---|
| Check40 | `+0x13F840` | `+0x1407D8` |
| Check43 | `+0x13F7B4` | `+0x14074C` |
| Check46 | `+0x13F8CC` | `+0x140864` |
| Button411 (CMyCheck) | `+0x13F958` | `+0x1408F0` |

### `0x4BD3FD`: Check43, radar expansion/collapse

Complete handler-equivalent body, with the two singleton calls preserved:

```c
DXPlaySound("Sound/BtnClick.wav", 0, 0, 0, 0, 100); // 0x4BD40B
uint32_t mode = CGameMap_GetSingletonPtr()->radarVisible_F0 ? 2 : 1;
CRadar_SetTransitionModeAndEnsureVisible(
    CGameMap_GetSingletonPtr() + 0xF4, mode);       // 0x4BD432 -> 0x6279A9
```

`0x6279A9` sets the singleton map's DWORD `+0xF0=1` for nonzero mode, then
writes the receiver DWORD `+0x40=mode` at `0x6279C4`. Thus the map-relative
transition field is **`+0x134`**. Mode 1 expands; mode 2 collapses. Both leave
visibility on initially. Collapse clears visibility only when the previously
verified animation finishes in `0x6277EC`; `0x62621C` ticks that animation before
its radar drawing. The handler/setter do not reset zoom globals
`0x969614/0x969618`, and repeated activation while visibility is still nonzero
requests collapse again. See [existing radar animation proof](../Game_Map/cradar_cell_to_radar_projection.md).

There is no CMyCheck state read/write, packet call, dialog ShowWindow, or
activation guard in this handler. It does **not** require a pre-toggled check to
choose its action: current map visibility is authoritative. Config restoration
calls the setter with Check43=1 at `0x4BDCF2`, then this handler at `0x4BDCF9`;
configured hotkey caller `0x5D9726` invokes it without a check setter. The latter
is direct evidence against assuming check-state equality with radar visibility.

### `0x4BD99D`: Check46, edge-scroll setting

```c
CWnd *parent = CWnd::FromHandle(GetParent(this->hWnd)); // 0x4BD9A4/AB
uint8_t state = CMyCheck_GetStateFrameByte(this+0x13F8CC); // 0x4BD9B8
PostMessageA(parent->hWnd, 0x464, 0x18, (uint32_t)state); // 0x4BD9CB
```

This is the complete handler. It reads the existing state, makes no local state
change, and has no explicit null, hero, world, cooldown or enable guard. It does
not play sound or send a packet. Posting failure is not handled or rolled back.

The queued shell command dispatches through `0x5B29E2`, table
`0x5B80FC[0x18]`, to `0x5B3AB3`. It writes the **entire DWORD payload**, without
Boolean normalization, to `0x958640` at `0x5B3AB8`. For payload zero only, it
calls `0x61E0DE` at `0x5B3ACA`, clearing map DWORDs **`+0x54/+0x58`**. Nonzero
does not clear those camera/projection offsets.

The world-view consequence is the already-proven Alt edge-scroll gate:
`0x5ACB07..0x5ACB4A` enables camera edge scrolling only when keyboard VK_MENU
has its high bit set, `0x958640!=0`, and hero status `0x3C` is absent. Check46
therefore permits that input mode; checking it alone does not immediately pan
the map. This chain changes local camera behavior, not a server movement mode.

The ordinary mouse path already advanced the state before notification.
Configured hotkey code explicitly computes `state==0 ? 1 : 0`, calls setter
`0x58B91D` at `0x5D97C3`, then calls this handler at `0x5D97CE`. Direct invocation
without that preparation merely reposts the existing state.

### `0x4BE63A`: Button411, equipment-inspection target mode

```c
uint8_t state = CMyCheck_GetStateFrameByte(this+0x13F958); // 0x4BE640
Conquer_PostMainWindowMessage464(0x43, state != 0);      // 0x4BE651
```

That is the entire body. Unlike Check46, it normalizes nonzero to 1.
`0x64D015` posts `(HWND[0x96AB00],0x464,0x43,payload)` only if that global HWND
is nonzero. No toggle, sound, dialog opening or packet send happens in the
click handler itself; state is expected to have been selected already.

The queued consumer is table `0x5B80FC[0x43]` → `0x5B4473`:

* Nonzero payload calls `0x5B27AE(shell,0x14,0)` through `0x5B7EF8`.
* Zero payload calls cleanup `0x5B26D4` through `0x5B54F5` **only if** current
  shell DWORD `+0x179800==0x14`; it leaves a different interaction mode intact.
* Setter `0x5B27AE` cleans up the old mode first if it differs from the requested
  mode, then writes `shell+0x179800=mode`, global `0x95864C=mode`, and
  `shell+0x179804=parameter`. Same-mode calls skip cleanup but rewrite fields.
* Cleanup's old-mode-`0x14` branch calls `SetStateByteIfInRange(0)` on
  `shell+0x1408F0` at `0x5B2720`. Common cleanup clears the two shell fields and
  global `0x95864C`. No parent notification is generated by this check reset.

Old-mode cleanup can also invoke existing behavior of another mode before
arming inspection. The complete branch census is: `0x11` calls `0x660ABE`, then
`0x660EC3` if false; `0x1F` posts `(0xCAB,0)`; `0x24` calls `0x71760E(hero,0)`;
`0x27` calls `0x628800(0x5139F3())`; `0x28` posts `(0xC66,0)`; `0x2A` calls
`0x65AF7C`, then `0x65AF8B` if true; `0x2D` calls `0x57229F(shell+0x171A58)`.
Other modes have only the common clears. Their unrelated subsystem internals
are not relabeled or claimed packet-free by this slice.

The mode's meaning is established by its **world-target consumer**, not the
ANI filename or INI comment. In `0x5AFEDF`, byte dispatch
`[0x5B258D+0x14]=12`, DWORD table `[0x5B2521+12*4]=0x5B0F51` leads to:

1. Reset Button411 to state/frame zero at `0x5B0F58`.
2. Call `CDummy_RefreshInspectedRoleAndRequestEquipment` (`0x66C9A3`) at
   `0x5B0F75`, receiver `hero+0x1EA0`, arguments `(target->DWORD_CC,0)`.
   This refreshes the inspection role view; on its valid resolved-role path,
   a nonzero target UID produces action `0x75` and the request built by
   `0x73ED85(...,0x10,emptyString,targetUID)`. Its return value is not tested
   by this caller.
3. Construct CMsgAction, call its Create with `(heroUID,0,0,0,0x136,targetUID)`
   at `0x5B0FAD`; send at `0x5B0FBC` if Create succeeds.
4. Construct the message at `0x72CCEF`; `0x72CD78` sets packet size `0x88`,
   type **`0x410` (1040)**, and target UID DWORD at packet `+4`, and returns 1.
   Call Create at `0x5B0FDF`, Send at `0x5B0FEE` if successful, then destroy it
   and the CMsgAction object.
5. Shared tail `0x5B192A` calls `0x5DC281` →
   `0x47CB44(shell+0x68,0,-1)`, then cleanup at `0x5B1933`; mode/global/parameter
   become zero, and the mode-14 cleanup resets Button411 again.

These are later **target-action** side effects, not unconditional results of
pressing Button411. That branch needs a selected role reference and the
surrounding world-click gates to reach the mode dispatch. The immediate target
type gate at `0x5B020B..0x5B021E` accepts types `0xB/0xC/0xD`; hero action gate
`0x5B02EB` or map-overlay gate `0x5B02FB` must admit mode 14 to `0x5B0321`.
The shared earlier input guards remain in the full raw `0x5AFEDF` capture;
this report does not equate “mode armed” with guaranteed network transmission.

## 4. Native pixel rectangles

Coordinates below are **logical framebuffer/client pixels**, not OS desktop
coordinates. They apply to the shipped English GUI files at baseline
MapDialogRect calibration `(mx,my)=(8,16)` (or initialization with font scaling
disabled). The display resolution alone cannot establish an arbitrary Windows
font's actual calibration; the conditional formula follows the table.

| Control / ID | Local `(x,y,w,h)` | Final at 800×600 | Final at 1024×768 |
|---|---|---|---|
| Check40 / `0x3F4` | `(0,23,22,22)` | **`(0,482,22,22)`** | **`(0,650,22,22)`** |
| Check43 / `0x3F7` | `(72,23,22,22)` | **`(72,482,22,22)`** | **`(72,650,22,22)`** |
| Check46 / `0x3FF` | `(50,11,22,22)` | **`(50,470,22,22)`** | **`(50,638,22,22)`** |
| Button411 / `0x3F8` | `(22,11,22,22)` | **`(22,470,22,22)`** | **`(22,638,22,22)`** |

For example Check43 at 800×600 accepts the rectangle notation
`[72,94) × [482,504)`; pixel `(93,503)` is inside, x=94 or y=504 is outside.
All four rectangles lie inside both logical framebuffers.

Proof chain, including the final writes:

1. `CMyCheck_Init` calls `UiLayout_RegisterAndPlaceWindowFromIni` (`0x591DF4`)
   at `0x58B468`. It formats parent/control keys; the clean files give
   `130-1012`, `130-1015`, `130-1023`, `130-1016` the exact local rectangles
   above, identically in both files. The MoveWindow at `0x591FF6` consumes
   those pixel values. It overrides the earlier template/font-size placement.
2. Init queries GetWindowRect at `0x58B47A`, subtracts its supplied parent
   origin, caches local x/y, and conditionally applies font calibration below.
   It caches resulting actual HWND dimensions at `0x58B552/55D`. The later ANI
   dimension stores `0x58B5B9/5BC` change only `+0x64/+0x68`, not HWND bounds.
3. Shell layout's exact `0x5B9242` call is
   `MoveWindow(shell+0xF98,0,H-141,W,141,TRUE)`. Thus parent origin is `(0,459)`
   or `(0,627)`. No `H-163` or screen-width multiplier appears here.
4. Resolution-change path `0x5D9BDF` reloads the selected GUI INI, obtains
   child rectangles at `0x5D9D6A` through `0x5938A3`, and sends BUTTON windows
   private `0x271C` at `0x5D9E4B`. CMyCheck decodes and moves at `0x58B9E5`.
   WM_MOVE handler `0x5A3414` calls Default, then stores x/y at
   `0x5A3420/427`. It is incorrect to claim the draw-origin cache stays stale.
   Parent relayout at `0x5D9F2C` uses `[0-130]` with the same y=459/627.

Parent INI heights are 150 (800) and 142 (1024), whereas initial shell placement
uses 141. This does not change the child rectangles or parent y: the table does
not silently treat those differing heights as identical.

For initialization when `g_uiDialogFontScaleEnabled` (`0x957E24`) is nonzero,
use the [already-proven calibration](15_main_hud_gauge_render_contract.md):
`sx=float32(8/mx)` at `0x957E2C`, `sy=float32(16/my)` at `0x957E30`, and
`R(z)=trunc_toward_zero(z+0.5)` with native x87 arithmetic and DWORD float
scales. Then the exact rectangle is:

```text
(R(x*sx), H-141+R(y*sy), R(22*sx), R(22*sy))
```

The four conversion calls are `0x58B4B7/4CF/4F2/512`, followed by MoveWindow
at `0x58B529`. This scales **the HWND**, not ANI image bytes. The later
screen-mode relayout described above reads pixel rectangles directly from the
INI; `0x5938A3` and `0x58B9E5` do not repeat this Init-only calibration pass.
At the 8×16 baseline both paths produce the table exactly.

## 5. Validation and precise completion boundary

Original-x86 replay covers all **65,536** combinations of state-count and
current-state bytes on mouse-down, plus **65,576** setter cases (all count/low
byte pairs and high-byte truncation vectors). It also covers hover edges and
window ownership, signed/wrapping forwarded points, WindowProc delegation,
Show frame-vs-state behavior and failed lookup, all three handlers, command
`0x18/0x43` consumers, WM_MOVE, and 40 layout/calibration vectors.

External calls are explicit mocks; `_ftol` is a truncating x87 boundary stub.
Every retained EXE assembly line and the retained MFC instruction ranges are
byte-compared against the hashed clean inputs. Raw decompiler output is retained
for review but does not override operand widths, branch conditions or stack
arguments. Replays do not claim full-program execution or actual HWND creation.

**Closed in native evidence:** requested CMyCheck fields and methods, toggler,
ordering relative to Default, absence of local release rollback, full three
handler bodies and immediate consumers, native pixel-placement paths, HWND
authority, explicit hover edges, and lack of alpha-pixel hit testing.

**Not claimed:** live target-OS capture/notification order or outside-release
acceptance after the swallowed WM_MOUSEMOVE, and an observed nonbaseline
MapDialogRect result. Windows supplies those runtime inputs/behavior. The
bundled EXE/MFC prove the delegation exactly but do not contain USER32's BUTTON
procedure. A mocked boundary is not evidence that those runtime observations
have occurred. The supplied Windows boundary probe records that last distinction
without changing the executable; its status remains **not run here**.

Binary Ninja received 15 explicitly suffixed `_Analyst` names and 22 address
comments, with readback and restorable records. The working database was saved
through Binary Ninja's UI, with save completion and before/after hashes recorded
in the evidence bundle. The installed MCP's
`set_function_comment` stores an address comment at the function entry; the
restoration script uses that same storage, not `Function.comment`.
Existing annotations were preserved; one existing movement-only comment was
qualified with the separately proven inspection-packet branch. No executable
patches or production changes were made.
