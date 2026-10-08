# GFX-UI-007 — selected-skill CMyImage: remaining native evidence

Status: **native-owned behavior closed for the requested slice**, against clean
5517. These are analyst semantics, not recovered C++ source symbols. Existing
DDX/init callsite, render ordering, `0x4BE7FB` cooldown algorithm, `0x5BB2E4`
producer internals, resource record and drag descriptor are reused, not reworked.
See [quickbar/drag context](19_main_hud_quickbar_native_contract.md),
[HUD hint rendering](12_hud_status_hint_panel.md), and
[common sprite contract](15_main_hud_gauge_render_contract.md).

Authority: `Conquer.exe`, SHA-256
`b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`.
Raw assembly, MLIL/HLIL, exact instruction-byte comparison, tables/census,
configuration excerpts, replay scripts/results, and reversible BN annotations:
[`10_work/docs/evidence/gfx-ui-007-main-hud-selected-skill-5517`](../../10_work/docs/evidence/gfx-ui-007-main-hud-selected-skill-5517/README.md).
BN changes remain in the open analysis view; **no BNDB save was performed**.

## 1. Identity, ABI and initialization

The object is `CDlgMain+0x13FF84 = shell+0x140F1C`, ID `0x3FE` /1022.
`CDlgMain = shell+0xF98`. The drag adapter receiver is `CDlgMain+0xF8`,
so its selected-image offset is `+0x13FE8C`; its `+0x13FEAC` is the selected
HWND (`CMyImage+0x20`). These bases must not be interchanged.

`0x5A1F8A`, existing analyst name `CMyImage_Init`, is `__thiscall`, `RET 0x18`:

| Argument | Native meaning and proof |
|---|---|
| 1: signed parent screen X | Subtracted from GetWindowRect.left at `0x5A1FBD`; relative X stored `+0x50`. |
| 2: signed parent screen Y | Subtracted from top at `0x5A1FC6`; relative Y stored `+0x54`. |
| 3: `const char* sectionOrFaceId` | For selected kind3, copied to `+0x6C` and used as ANI section. Kind2 uses `atoi` and RoleData face lookup. Null skips loading and returns1; it is not a clear operation. |
| 4: low-byte image kind | Stored byte `+0x98` at `0x5A2269`; selects resource resolution and input/draw branches. Main supplies3. |
| 5: hover selector/sentinel | Stored DWORD `+0xA8` at `0x5A22F6` only on kind0, kind2, and ordinary kind1 paths. Kind0 hover posts this command to parent unless -1; kind2 uses -1 as the hover-hint suppression sentinel. **Kind3 skips this store and never consumes it in its hover path.** Main's -1 does not disable Magic0 hover. |
| 6: context code | Stored DWORD `+0xDC` at `0x5A224E`; affects resource selection for some kinds and drag-manager notifications. Main supplies3. It is not a frame count. |

`0x92BD34` is the literal **`"Magic0\0"`**. The ordinary main call is therefore
`Init(parentLeft,parentTop,"Magic0",3,-1,3)`. The subsequent existing clear
call intentionally leaves the initial image inactive; its semantics are below.

Init first invokes layout registration/placement `0x591DF4` at `0x5A1FA8`,
then queries the HWND rectangle. It reads `ini/Info.ini / [ImageNum]`
`Dir` (default3) into `+0x48` and `Size` (default16) into `+0x4C`; shipped values
are3/16. They configure numeric overlays, not icon dimensions. Optional font
calibration moves the HWND at `0x5A2233`, then queries its rectangle again.
`+0x80/+0x84` receive actual HWND width/height at `0x5A2254/260`.

ANI filename vector `+0x9C`: kind0 and kind10 use empty/default-Control;
kind1/context`0x4A` also uses empty/default-Control; other kind1 and the default
kind branch use `ani/ItemMinIcon.Ani`; kind2 uses `ani/PlayerFace.ani`;
**kind3 uses `ani/Magic.ani`**. Kind3, kind10, kind1/context4A and the default
branch bypass the `+0xA8` argument store.

For a nonnull section, Init sets `+0x60=1` before lookup. Ordinary query is
`GameDataSetQuery()->vtable+0x10(filename,section,1,30000)`; an empty filename
vector selects `ani/Control.ani`. A null resource returns0 without undoing
those writes. A nonnull resource's `vtable+0x18(outSize,+0x68)` supplies
`+0x90/+0x94`; success returns1, even when size is0×0. The selected branch's
actual draw source is separately fixed at50×50, not these measured dimensions.

Relevant CMyImage storage:

| Offset | Width | Meaning |
|---|---:|---|
| `+0x20` | 4 | HWND |
| `+0x40` | interface | Data-migration observer; callback `0x5A1F3F` only updates item-kind1 data, not selected kind3 |
| `+0x44` | 4 | Mouse tracking/hover flag |
| `+0x48/+0x4C` | 4 each | Numeric overlay direction/font-image size |
| `+0x50/+0x54` | 4 each | Relative HWND/draw origin |
| `+0x58/+0x5C` | 4 each | Last Show absolute origin; hover anchor uses these cached values |
| `+0x60` | 4 | Main image active flag, not successful-resource ownership |
| `+0x64` | 4 | Independent cover byte stored zero-extended; zero/nonzero draw gate |
| `+0x68` | 4 | Frame index, initialized0; no selected-path writer advances it |
| `+0x6C..0x77` | vector | Section string |
| `+0x78` | 4 | Face ID for kind2 |
| `+0x7C` | 4 | Item tooltip/observer payload, unused by selected-kind hover |
| `+0x80/+0x84` | 4 each | Cached destination width/height |
| `+0x88/+0x8C` | 4 each | Generic source origin (constructor0); kind3 uses local fixed RECT instead |
| `+0x90/+0x94` | 4 each | Measured frame dimensions / generic source RECT right,bottom |
| `+0x98` | 1 | Image kind |
| `+0x9C..0xA7` | vector | ANI filename |
| `+0xA8` | 4 | Kind-dependent hover selector; not initialized by the constructor or selected Init branch |
| `+0xAC` | 4 | Content ID; selected skill ID used by hints/drag descriptor |
| `+0xB0..0xBF` | 16 | Copied metadata: B0 add-level overlay, B4 quantity; selected setters supply both0 |
| `+0xC0/+0xC4` | 1 /4 | Optional glow selector/start tick; constructor0; no selected setter enables it |
| `+0xC8` | 4 | Load-time blocked/cover flag; also gates left-down |
| `+0xDC` | 4 | Context; main3 |
| `+0xE0..0xEB` | vector | Independent extra-overlay section, initially empty |
| `+0xEC` | 4 | Independent effect interface, initially null |

Constructor `0x5A1D2D` establishes frame0, active0, cover0, hover0, content0,
blocked0, zero source origin, empty string vectors and no effect/glow. It does
not initialize cached origin/dimensions or `+0xA8`; do not give them invented
constructor defaults. The selected Init and subsequent Show populate the needed
geometry before normal use. Metadata initialization writes B0=0,B4=0,B8 byte=1,
BC=0; the three padding bytes after B8 are not explicitly initialized.

## 2. Replacement, missing content and exact clear

`0x5A24DE`, analyst `CMyImage_SetSectionAndContent_Analyst`, is `__thiscall`,
`RET 0x10`:

```text
Set(sectionOrFaceId, uint32 contentId, uint32 blockedCover,
    const void* metadata16)
```

It writes active `+0x60=1`, blocked/cover `+0xC8=arg3`, then copies all16 bytes
of metadata into `+0xB0` **before attempting lookup**. There is no null check
on the metadata pointer. For kind3/non-null section it replaces the section
vector and stores contentId in `+0xAC`; it does not reset frame `+0x68`.
It resolves the configured ANI/default-Control using mode1/30000 and measures
the existing frame. On success it updates measured dimensions and returns1.

For null section in the non-face branch, it assigns the empty string to the
stored section but still passes the **original null argument** to lookup;
`+0xAC` is not rewritten on that branch before failure. GraphicData rejects
null/empty section, so this is a failed replacement, not the native clear API.
For kind2, the alternate branch parses the face ID and uses RoleData vtable+A0.

| Case | Exact result |
|---|---|
| Missing ANI section / null lookup | Return0; changed section/content/active/metadata/blocked remain; previous measured dimensions remain. Later Show queries the new section, not the old resource. |
| Missing required DDS on a cold/uncached load | ANI creation fails and returns null after cleaning the partially constructed ANI. Same CMyImage failure result; it does not keep the previous image as fallback. |
| Valid section with zero frames | CAniX creation succeeds with count0. Size returns0×0; CMyImage returns1 and remains active. Main image draw emits no bitmap draw. Independent cover can still draw. |
| Nonzero frame count | Frame is selected by **unsigned frame modulo count** in both dimensions and draw. Selected path remains frame0. |

Native resource chain: GraphicData.dll `0x100045E0` checks both paths nonnull
and nonempty, uses a shared hash/cache and mode1 request; `0x100062B0` invokes
graphic.dll `AniCreate` `0x1000BFE0`. Section resolution is `0x1000BC3A`;
`CAniX_CreateFromIndexInfo` `0x1000BC80` loads each frame through
`0x10011EB0`. Failure cleanup is `0x1000BDBB..0x1000BE1A`; AniCreate deletes a
failed instance at `0x1000C045`. Count0 succeeds at `0x1000BDA5..0x1000BDB8`.
`CAniX_GetFrameAt` `0x1000BF30` returns null for signed count<=0 before division;
`GetFrameDimensionsAt` `0x1000BF90` initializes output0×0 and keeps that for
null frame. `DrawFrameSubRectAt` `0x1000BE70` also rejects count<=0.

CMyImage stores the section, configuration, payload and dimensions; **it stores
no loaded ANI pointer**. Init/Set/Show borrow resource results from the cache;
Set and Clear contain no release of the previous ANI. An already usable cached
ANI is returned without rechecking its files; deleting an underlying DDS is not
a per-frame missing-image test. A replacement switches
future lookups; cache retention/eviction owns resource lifetime. The30000
argument is a cache lifetime parameter, not an icon animation duration.

`0x5A2612`, existing `CMyImage_ClearLoadedImage`, does exactly:

```text
+0x60 = 0; +0xC8 = 0; +0xAC = 0;
if (old +0x44 != 0 && byte +0x98 == 1)
    tooltipSingleton(0x581BE7)->clear(0x5EAA08,0);
```

For selected kind3 only the three DWORD stores occur. It preserves section,
filename, frame, both dimension pairs, hover, metadata, `+0x64`, glow and
extra-overlay/effect state. No pointer/resource destructor runs here.

## 3. Actual Show target and geometry

Constructor store `0x5A1DA6` proves primary vtable `0x867C38`.
Slot `+0xC4`, at `0x867CFC`, is **`0x5A26EE`**, analyst
`CMyImage_DrawAtParentOrigin_Analyst`, `__thiscall RET8(parentX,parentY)`.
The existing main Show at `0x4BCC2C` calls that slot.

1. Always cache `(parentX+relativeX,parentY+relativeY)` into `+0x58/+0x5C`.
2. With `+0x60!=0`, generic optional glow comes first (not enabled for selected).
   Query the configured/default ANI, then for kind3 query `ani/Magic.ani`
   again using the stored section; the latter result controls the icon.
3. With a nonnull result, kind3 draws at `0x5A2961`:
   **frame `+0x68`; source RECT `(0,0,50,50)`; destination origin `+0x58/+0x5C`,
   extent `+0x80/+0x84`; color0; draw mode0.** No natural-image destination sizing.
   `0x5A23CA` add-level and `0x5A342E` count overlays follow; selected-producer
   metadata B0=B4=0 makes both return without drawing.
4. Tail `0x5A29D8` is outside the active/image-success gate: extra overlay
   `0x5A2AB9`, effect `0x5A2692`, then cover if `+0xC8!=0 || +0x64!=0`.
   Selected default has no extra overlay/effect. Cover resolves
   `ani/Control.ani / Image0`, frame0, source `(0,0,64,64)`, **the same destination
   origin and extent**, color0/mode0 at `0x5A2A3E`.

`0x5A2E90` is exactly `DWORD[+0x64] = zero_extend(arg1.low_byte)`, `RET4`.
Arguments0/1 hide/show that independent cover. It neither changes the image
frame/section nor invokes EnableWindow; left-down checks **C8**, not64.
A byte other than1 also means cover-on; `0x100` truncates to0.
Its only direct EXE callsites are `0x4BE819` and `0x4BECC0` in the already-proven
cooldown routine. Its pre-existing ordering/algorithm is unchanged by this note.

The shared renderer is graphic.dll `CAniX+0x0C -> 0x1000BE70`, bitmap+8
`0x10012190 -> Sprite_SetCoor -> Sprite_Draw(mode0)`.
Color0 preserves the existing vertex color; it is not transparent-alpha0.
The verified mode0 path uses source-alpha / inverse-source-alpha blending,
point sampling and ordinary viewport clipping, with no CMyImage HWND/scissor
clip or source-alpha hit mask. Source50×50 is stretched to47×46 at baseline.
A missing main image skips that icon but **does not skip the unconditional tail**.
A logically cleared image can therefore still display Image0 if64 remains set.

## 4. Final Magic0 HWND and image rectangles

There **is** a retail layout override. Both `ini/GUI800X600.ini` and `ini/GUI.ini`
have one `[130-1022]` section with `x=753,y=96,w=47,h=46`. This wins over
resource DLU `(375,46,25,24)` via `0x591DF4` / MoveWindow `0x591FF6`.
Do not derive the final rectangle from those resource DLU or multiply X by
screen width. Parent placement `0x5B9242` is `(0,H-141,W,141)`.

At baseline MapDialogRect calibration8×16 (or Init font scaling disabled):

| Resolution | HWND and image destination `(x,y,w,h)` | Half-open destination | Viewport intersection |
|---|---|---|---|
| 800×600 | **`(753,555,47,46)`** | `[753,800) × [555,601)` | `[753,800) × [555,600)` |
| 1024×768 | **`(753,723,47,46)`** | `[753,800) × [723,769)` | `[753,800) × [723,768)` |

The bottom one-pixel geometric strip lies outside the logical framebuffer at
both resolutions. These are rectangle/viewport facts, not claims about the
asset's nontransparent pixel coverage or a live GPU capture.

With the already-proven Init calibration enabled,
`sx=float32(8/mx)`, `sy=float32(16/my)`, and native x87 conversion
`R(z)=trunc_toward_zero(z+0.5)`, the rectangle is:

```text
(R(753*sx), H-141 + R(96*sy), R(47*sx), R(46*sy))
```

Conversions are at `0x5A21D3/1E8/2209/2225`. This scales the destination HWND;
source50×50 and asset bytes are not font-scaled. Arbitrary physical desktop
pixels cannot be determined from logical resolution without actual calibration
and window origin; the table specifies the requested baseline logical pixels.

Resolution relayout `0x5D9BDF` reads the selected GUI pixel rectangles through
`0x5938A3`, sends private `0x271C`, and CMyImage `0x5A3365` moves at
`0x5A33C6`. Its shared WM_MOVE handler `0x5A3414` updates `+0x50/+0x54`.
**This path does not recache `+0x80/+0x84`**; those remain Init destination
sizes. At baseline both resolutions have the same47×46 dimensions, so the
table holds after either initial layout or resolution change. With nonbaseline
font calibration followed by raw-pixel relayout, HWND dimensions and cached
image extent can differ. Do not silently refresh those cached dimensions.
Parent INI heights150/142 differ from initial141 but preserve y459/627.

## 5. Selected clear/drop and complete bounded writer census

`0x5BABBC`, analyst `CMyShellDlg_ClearSelectedMagicImageAndIds_Analyst`:
call Clear on shell+140F1C at `0x5BABC5`, then write0 to
`+0x1797B0` (`0x5BABCC`), `+0x1797A4` (`0x5BABD2`),
`+0x1797AC` (`0x5BABD8`), return EAX0. No packet, hero collection mutation or
persistence call occurs here. **Backup `+0x1797A8` is retained**, as is image64.

Two direct callers:

- `0x4BC01B`: known main drag callback `0x4BBF81`, receiver main+F8.
  For descriptor3FE it queries selected HWND using adapter+13FEAC, gets the
  **actual cursor screen point**, and calls Clear only when PtInRect returns0.
  A point inside keeps selection. Right/bottom are excluded by PtInRect.
  Both paths join the callback's true return at `0x4BC17E`; helper EAX0 does
  not mean drag rejection. No rollback is performed by this callback.
- `0x5DC853`: runtime reset `0x5DC783`; this caller separately clears backup
  +1797A8 at `0x5DC858`. That additional store is not part of5BABBC itself.

The byte-backed census finds **19 direct writes** to the requested three shell
fields. Addresses below are stores, not merely references:

| Native owner / trigger | `+1797A4` normal ID | `+1797AC` XP ID | `+1797B0` active kind |
|---|---|---|---|
| Constructor `0x5ADAB7` | `5ADF98`=0 | `5ADFA6`=0 | `5ADFAC`=0 |
| Dispatcher `0x5B29E2`, command36 | `5B3B9A`=parameter | — | `5B3BA0`=1 |
| Dispatcher command37 | — | `5B3C13`=parameter, before validation | `5B3D27`=2 only on selected display branch |
| Clear `0x5BABBC` | `5BABD2`=0 | `5BABD8`=0 | `5BABCC`=0 |
| Existing producer `0x5BB2E4` | `5BB5CC`=normal ID | `5BB36D`=XP ID | `5BB448`=2; `5BB5AF`=1 |
| WindowProc `0x5BB79D`, WM464 command40E | — | — | `5C3A88`=1 |
| WindowProc commandD99 | — | **not written** | `5C3B9D`=2 for nonzero parameter; `5C3BFC`=1 for zero |
| WindowProc command431 | `5C40CC`=0; `5C41C1`=backup | — | — |

Command36 builds `MagicSkillType%d` and sets the selected image at `5B3BD6`.
Command37 writes the candidate XP ID before scanning/guards; its selected
branch builds `XpSkillType%d`, sets kind2 and calls Set at `5B3D5D`.
Failure to reach that branch can leave the candidate ID changed without an
image/kind update. This is a census of the selected state, not a new reanalysis
of magic activation internals.

Command40E (status5 absent) restores the stored normal section, or **`Magic0`**
with content0 when no normal ID: Set at `5C3B0F/5C3B70`.
CommandD99 (`5BBCDD..5BBCEA` table -> `5C3B7A`) displays `XpSkillType<lParam>`
and kind2 if nonzero; **it does not write1797AC**. With zero parameter it returns
to kind1 and stored normal section or Magic0. Set calls:
`5C3BEC`, `5C3C6C`, `5C3CB6`.

Command431 (`5C3FD3`) looks up normal selected ID in the learned-magic collection.
If found and the returned magic object's DWORD+4 is nonzero, it refreshes the
normal image (`5C4096`). If found with that DWORD0, it clears image (`5C40A9`),
backs normal ID up in1797A8 (`5C40C0`), and clears1797A4. It then independently
checks the backup; a found object with DWORD+4 nonzero restores its image
(`5C41AA`), copies backup to1797A4 and clears backup (`5C41CD`). A missing
lookup alone does not execute that clear branch. This slice uses the exact
DWORD+4 condition without importing an unproven semantic label for that field.

Selected-instance call/reference ledger (in `selected-call-ledger.json`):
constructor `4B5F66`, destructor `4B9E90`; DDX `4BB859`; Init `4BBC11`;
Clear `4BBC18`, `5BABC5`, `5C40A9`; virtual Show `4BCC2C`;
cover writes `4BE819`, `4BECC0`; content getter `4BC1B6` in the known drag start;
Set calls `5B3BD6`, `5B3D5D`, `5BB47E`, `5BB5FE`, `5C3B0F`, `5C3B70`,
`5C3BEC`, `5C3C6C`, `5C3CB6`, `5C4096`, `5C41AA`.
MFC-dispatched members are captured through the actual vtable/message map.
Generic HWND relayout is additionally documented above.

**Therefore `0x5BB2E4` is not the complete producer path.** Both direct
selection commands and refresh/restore messages also produce selected images.
The census covers clean EXE executable-section displacement matches, a raw
little-endian backstop, canonical shell/main/adapter receiver adjustments,
callee xrefs, native message/vtables and CMyImage member methods. False positives
are retained/classified; one raw match is the rel32 displacement of unrelated
`call 0x5E5029` at `0x46C904`, not a field access. This is static closure of
shipped client references, not a claim about arbitrary external runtime writes.

## 6. Direct click, right-click and hover

**Magic0 is not drag-only.** Main message-map row `0x855D08` is
`WM_COMMAND(0x111), BN_CLICKED(0), ID3FE..3FE -> 0x4BD9D4`.
Analyst name `CDlgMain_OnSelectedMagicClicked_Analyst`:

1. `0x657B03` rejects hero status bits36,3B,3A (`0x4BD9DF..9E6`).
2. If `CHero__GetMagicAmount` (`0x6F573C`) >0, toggle main+8E100
   (shell+8F098): `0x5964C1(...,1)` visible/pending -> hide0 via `0x596F79`;
   otherwise `0x4B3FE8` shows5 and populates the normal magic chooser.
3. Independently, if `CHero__GetXpSkillAmount` (`0x6F7948`) >0, toggle
   main+8FA64 (shell+909FC): visible/pending -> hide0, else show5,
   both through `0x596F79` at `0x4BDA48`.

The count functions are filtered views of the hero magic container: effect
parameter25==0 and==2 respectively. Do not confuse image-kind3 or active-kind2
with those effect-parameter categories. This handler does not cast a skill or
write the three selected fields. Native BN_CLICKED mapping is proven;
Windows' delivery/capture timing is a separate external boundary.

Selected-kind3/context3 message behavior, map at `0x867B60`:

| Message / native handler | Exact client-owned action |
|---|---|
| Move200 / `5A2B1A` | If44==0, TrackMouseEvent with flags3, HWND20, timeoutFFFFFFFF; then44=1 regardless return. Always Default. |
| Left down201 / `5A2C01` | IfC8!=0, return without Default. Else ifAC!=0 postWM464(B,3), then post(6,0), then Default. No own capture call, frame change or hit/alpha test. |
| Left up202 / `5A2E50` | IfAC!=0 andDC!=-1, postWM464(C,DC), then Default. Does not test60,64,C8 or release POINT. |
| Right down204 / `5A311D` | Selected kind3 bypasses item-only commands. If parent CWnd resolves, PostMessage(parentHWND,204,0,0), then Default. No direct skill cast, clear, section/frame swap or ID write. |
| Hover2A1 / `5A361E` |44=1; postWM464(A,AC), **even if60==0**. If60!=0, then post(7,packLow16(X,Y)) using cached58/5C; then post(9,AC). Return0. |
| Leave2A3 / `5A37C7` |44=0; postWM464(6,0); return0. No image clear or frame change. |

These are posted messages in native call order, not synchronous dispatch.
CommandB routes `5B2E40 -> 5BABE0 -> drag start5E7C8B`; C routes
`5B2E4F -> 5BAC27 -> drop5E7C04`. The existing descriptor/callback evidence
supplies the rest of the drag path.

Hint commands in dispatcher `0x5B29E2`:
A (`5B2E18`) changes category9/content only when hint-visible179694 is zero;
7 (`5B2D61`) sets anchorX=max(signExtend16(x),0), anchorY=unsigned16(y)+42;
9 (`5B2DAA`) unconditionally makes hint-visible1, category1796EC=9 and
content1796F0=AC. Thus loaded hover ends with that category/content even if A
was ignored. Command6 (`5B2DCC`) **always** zeros179694 and179698; its later
1797CC test gates only the subsequent map call, not these two stores.

No CMyImage hover/press/release frame substitution exists for selected kind3.
The inherited CMyDialog WindowProc `0x59637A` handles left down/up specially,
but right204 reaches CWnd::WindowProc; neither the CDlgMain nor CMyDialog
application map has a right204 row. This forwarding is distinct from a
selected-skill-specific right-click action. The remaining platform default
handling is not experimentally observed here.

## 7. Verification and boundaries

The evidence bundle records instruction-byte equality against the clean EXE
and DLLs, **132 original-x86 replay cases**, the raw tables/configuration,
19-write census, direct-call ledger, and before/after BN annotations.
Replay covers Init and scaling, failed/null/zero-frame replacement, exact clear,
byte truncation, both resolutions' icon/cover draws, all selected input handlers,
CAniX frame modulo/zero-frame behavior, and guarded independent chooser toggles.
No production implementation or executable was changed.

No guessed client-owned behavior is required for this requested slice.
Precisely unobserved: live USER32 BUTTON capture and BN_CLICKED delivery for
arbitrary pointer sequences, and a physical GPU/desktop pixel trace. API mocks
verify which native calls occur and their ordering/arguments; they do not prove
Windows behavior inside those calls. The supplied logical geometry and shared
render contract are native instruction/configuration evidence, not screenshots.
