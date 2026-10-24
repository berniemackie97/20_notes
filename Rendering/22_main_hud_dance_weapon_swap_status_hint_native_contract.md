# HUD-010 — dance and weapon-swap status hints, native 5517

Native contract closed on 2026-10-10. **Documentation and deobfuscation only; no implementation updates.** This note adds category `0x38` and `0x6A` facts to [12](12_hud_status_hint_panel.md), [19](19_main_hud_quickbar_native_contract.md), and [21](21_main_hud_magic_status_hint_native_contract.md). Category-8 and category-9 investigations are reused, not repeated.

Evidence: [HUD-010 bundle](../../10_work/docs/evidence/hud-010-dance-weapon-swap-status-hints-5517/README.md), including original instruction captures, bounded x86 execution, annotation before/after/readback, hashes and final verification. EXE addresses below refer to clean `Conquer.exe`, SHA-256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`. Raw operand widths and dataflow take precedence over historical names/comments in reused captures.

The three requested notes matched `sources/20_notes.zip` before this task's additions. All 2,252 non-metadata files in the requested GFX-UI-006/008/009 scopes matched `sources/Archive.zip`; `archive-reuse-verification.json` pins them. No synced source archive was modified. The full dispatcher captures are inherited.

## 1. Dance payload and construction

### Main quickbar: grid context is the literal Magic type

At `0x5A1342..0x5A134D`, kind 5 posts command 7 with the cell anchor, then command `0x38` with **DWORD `[grid+0x48]`**, loaded at `0x5A134A`. Main HUD initializes this context to **3**. The cached dance content ID at `grid+0x74` is not the hover parameter. GFX-UI-006 already establishes initialization, caching and activation; this is the renderer consequence of that proven payload.

Dispatcher `0x5B3BEC..0x5B3C09` stores visible=1, category=`0x38`, and the full DWORD parameter at shell `+0x1796F0`. At `0x5B9E0E..0x5B9E1A`, the renderer calls:

```text
Create(outShared, type=storedParameter, level=0, initialExperience=0)
```

`0x6F4DB3` was named `CMagic__CreateFromIdLevelCaster`. That name was wrong. The verified name is `CMagic_CreateFromTypeLevelExperience_Analyst`:

- It allocates a `0x50`-byte CMagic and shared control block. `0x6F4CB5` initializes the embedded record at `+0x0C` and experience at `+8`.
- `0x6F4CF8(type,level,initialExperience)`, `RET 0x0C`, passes type/level and the embedded destination to `0x69CDFB`.
- `0x69CDFB` searches key **low32(type×10+level)** and copies **17 DWORDs** from the found table node `+0x14` into the embedded record. This is static table selection, not a learned-magic search.
- On success, `0x6F4D17..0x6F4D1B` stores the third argument at CMagic `+8`. On record miss, the factory returns `{raw=0,control=0}` and releases its failed temporary.
- The renderer copies the shared reference by value for `0x5DA7AA`, then releases its local reference. The helper releases its argument on ordinary exits. Control decrement `0x404CE4` destroys the object when strong count reaches zero, then deletes the control block when weak count reaches zero.

The clean 893-row MagicType table has **no type 3 / key 30 record**. Therefore main quickbar dance hover selects category `0x38` but produces **no text, no backdrop, no outline and no warning**. `0x5DA7C3` rejects the null raw pointer before all those operations. It does not clear the selection or restore the previous Magic hint. Learned type 3, a real learned dance in the slot, or the cached slot ID cannot substitute for the missing static record.

This is data-dependent, not a special `type==3` guard. A modified table containing key 30 would be consumed. The category itself has no dance-classifier precondition: an existing non-dance type at level 0 would enter the shared Magic renderer. Preserve full DWORD arithmetic; do not narrow the parameter to a WORD or replace it with a dance index.

### Separate dance producer: actual list-entry type

`0x442E99` draws the dance dialog and polls cursor hover. Its call to `0x4433C6(outType,screenX,screenY)` traverses the list rooted at dialog `+0xB6C` alongside at most 16 button pointers at `+0xB04`. For non-null buttons it obtains the HWND rectangle and calls `PtInRect`. On a hit, `0x44343A..0x44343F` copies **DWORD `[node+0x14]`** to `outType` and sets byte `[dialog+0xB00]=1`.

`0x443176` constructs this mapped value from the Magic type table at `0x84AB10`; the node key at `+0x10` is an index, while `+0x14` is the actual Magic type. Hit testing does not inspect the entry's learned flag. The 16 retail types are:

| Types | Level-0 names | Required Performer phase |
|---|---|---:|
| 1380, 1385, 1390, 1395, 1400, 1405, 1410 | Dance2 through Dance8 | 0 |
| 1415 | BattleDance | 1 |
| 1416 | Triumph | 3 |
| 1417 | StepStomp | 5 |
| 1418 | Moonlight | 7 |
| 1419 | SnowWind | 9 |
| 1420, 1421, 1422, 1423 | Phoenix, Melody, Tipsy, Felicity | 0 |

`0x44304D` refreshes learned/unlearned groups after hover posting, and `0x443176` rebuilds the list. Types 1415..1419 enter the learned group only while active subprofession is 6. This affects list ordering/grouping, not the hit-test permission to display an unlearned entry. The type always comes from the currently hit entry; do not assume a permanent button-index/type mapping.

On **every hit**, the producer posts command 7, then command `0x38` at `0x442F52` with that type. There is no quickbar-style same-cell suppression. Anchor construction is explicit at `0x442F1E..0x442F43`: convert the cursor to dialog client coordinates, add the low WORDs of dialog origin `+0xF0/+0xF4`, and pack the low 16 bits of each result. Shared command 7 stores `X=max(0,signExtend(lowWORD))` and `Y=unsigned(highWORD)+42`. The shared Magic helper subtracts 42, so its input is the cursor-derived Y. This is not a button-top-left anchor. On no hit, a previously set `+0xB00` is cleared and command 6 is posted once; subsequent outside polls post nothing.

Missing button pointers are skipped. An empty list yields no hit. The button drawing loop checks list count==16, but the hover loop itself traverses available entries up to 16. `GetCursorPos`, `GetWindowRect` and `ScreenToClient` return values are not checked here; failed window API output is not converted to a defined safe no-hint result.

## 2. Additional shared-Magic behavior for category 0x38

The call at `0x5B9E5D` has the same verified ABI as the ordinary nonzero category-9 helper:

```text
(sharedRaw, sharedControl, storedX, storedY-42,
 maxChars=30, FontInfo+0x10D, white=0xFFFFFFFF,
 height=12, left=5, top=5, right=5, bottom=5)
```

Reuse Rendering/21 sections 4–5 verbatim for text construction, English wrapping, measured line count, layout, backdrop, outline, per-group drawing and cleanup. In particular, this branch uses fixed height 12 even when normal font size differs. It uses the synthetic static **level-0, experience-0** object, not the learned object's level or experience. Learned state is a separate input to warnings/requirements.

Every one of the 16 clean dance rows has level 0 and required experience 0. Its groups are the level-0 Name, `Level: Elementary`, any subprofession requirement, level-0 DescEx, `Fixed`, then any warning. Types 1380..1410 have DescEx `Dance`; types 1415..1422 have `Unique Dance`, while 1423 has `Unique Dance.` including the period. The progress group is the numeric `Fixed` string because requiredExp==0 wins; it does not use MagicEffect Desc values such as `Fix` or `Unavailable`. Encoded strings, source lines and all record fields are retained in `contract-replay.json` / inherited `magic-hint-content.json`.

The already-proven dance classifier accepts 1380, 1385, 1390, 1395, 1400, 1405, and 1410..1423. Thus classifier acceptance is broader than the retail list: types 1411..1414 classify as dance but have no clean static records and still produce no category-0x38 hint.

| Stable state, with a constructed dance object | Additional warning |
|---|---|
| No learned object matching the full type | Red `STR_NOTSTUDY_DANCE`: ``You haven`t learned a dance skill.`` |
| Learned match, active class !=6, signed type 1415..1419 | Red `STR_NOT_COOL_DANCE_STATE`: `Usable only as a Performer.` |
| Learned match and active class==6 | None |
| Learned match, other accepted dance type | None, even when active class !=6 |
| No static record / null constructed object | No groups or warnings at all |

The backtick in the missing-learned text is byte `0x60`; it is not an apostrophe or a backslash escape. The missing-learned warning takes priority over the Performer warning. The Performer **requirement group** remains independent: an active Performer with insufficient phase gets the red requirement group but no Performer warning. A missing learned dance can have both a requirement group and the missing-learned warning.

Measurement warning selection is at `0x5DAF87..0x5DB173`; the helper checks live state again during draw at `0x5DB378..0x5DB410`. Stable-state tests are deterministic; no atomic snapshot across those calls is promised by native code.

Missing MagicEffect name/description, numeric/keyed localization, subprofession title and Dialog21 retain the exact Rendering/21 behavior. A static record with missing text is not a missing record. Missing Dialog21 skips its backdrop/outline and still allows text. The common outer FontInfo failure skips the entire branch. A valid dance reaches hero-dependent learned lookup without a null-object guard; a missing static record exits before that lookup. Nothing here grants gameplay availability or invokes a dance.

## 3. Weapon-swap selection and one-entry construction

The subtract/compare dispatcher reaches `0x5B9CB8` only for category `0x6A`. Hero query `0x6DA8B2` is exactly `MOV EAX,[ECX+0xF1C]; RET`. The comparison at `0x5B9CC4` is **DWORD equality to 1**, not a truthiness test:

| Hero DWORD +0xF1C | Key | Exact retail value |
|---|---|---|
| 1 | `STR_SWAP_MAJOR_WEAPONTIP` | `Switch to your Main Equipment.` |
| Any other value | `STR_SWAP_SUB_WEAPONTIP` | `Switch to your Alternate Equipment.` |

These are the already-extracted `Cn_Res.ini` lines 679 and 680, respectively. Key literals are at `0x937B84` and `0x937B6C`. The quickbar's `0x5E` parameter is stored but unused by this render branch. State is reread for every eligible frame, even with unchanged hover. This proves presentation selection only; it does not establish which equipment is currently active or any swap/network action.

At `0x5B9D4F`, measure the whole returned byte string:

```text
CalcuTextExtentCommon(text, FontInfo.guiFace(+0x10D),
 normalHeight, GameDataSet.vtable+0x5C(0), iconWidth=21)
```

EAX is measured width `w`; EDX is measured height, stored but not used for this branch's geometry. Normal height is the DWORD returned by `0x69A6A3` from font-size settings `+8`. The pair subsequently copied into the queue is `{settings+0x0C, settings+8}`. Its first value is retained but unused by the queue renderer; its second value is height. It is not the measured `(w,h)` pair.

Let stored hover anchor be `(A.x,A.y)` and EXE alternate-layout flag be DWORD `0x96AB30 !=0`. The enqueue call at `0x5B9DF8` is:

```text
x0 = alternate ? low32(A.x + w - 3) : low32(A.x - 3)
y0 = low32(A.y - 60)
592D78(this=0x957DE8, x0, y0, w,
       faceOverride=NULL, &fontPair, backgroundOverride=NULL,
       &oneWholeStringVector, alignment=0)
```

The caller constructs exactly **one** 12-byte char-vector entry. `0x592D78` copies each supplied entry into a 16-byte `{charVector,color}` entry with `0xFFFFFFFF`, delegates to `0x592C38`, then destroys its temporaries. It neither wraps nor splits the string and performs no drawing. In particular it never calls the category-9 wrapper `0x76938E`.

`0x592C38` constructs a 60-byte owned queue record and deep-appends it to manager `+0x94` through `0x59415A` / copy constructor `0x594F36`:

| Offset | Field |
|---|---|
| +0, +4, +8 | X, Y, width |
| +0x0C, +0x10 | copied font pair; height is second DWORD |
| +0x14 | alignment, 0 for this branch |
| +0x18 | owned face char vector |
| +0x24 | owned background-section char vector |
| +0x30 | owned colored-line vector, 16 bytes per entry |

A null face override causes a second FontInfo query at `0x592C8D`, then copies its GUI face. A null background override leaves the background vector empty. Empty selects the default section pointed to by DWORD `0x93625C`: **Dialog21**. It does not mean no backdrop. Text, face and vector contents survive destruction of all caller temporaries.

## 4. Deferred swap layout and draw order

`CFrameEventList_BeginTick` (`0x592F51`) destroys all queued entries in `[begin,end)` through `0x5946BC`/`0x592D29`, sets end=begin, and retains capacity. `CFrameEventList_EndFrameDispatch` (`0x592F2B`) draws 60-byte entries in insertion order through `0x592F65`; it does **not** remove them. There is no age predicate despite the historical `PurgeOldEntriesForTick` label.

Frame anchors in reused `0x5DCFAA`: BeginTick at `0x5DD040`; status-panel call at `0x5DD36A`; queue flush at `0x5DD6B0`, conditional on the frame's device-lost flag being zero. Other HUD work can occur between enqueue and flush, and later prompts can follow the flush. The swap art/text is therefore deferred relative to the synchronous Magic helper; it is not necessarily the final drawing in the frame.

### Exact arithmetic

Use 32-bit arithmetic, signed comparisons and the actual measured `w`. Let `n` be queue entry count, `h` the copied font height, and `(W,H)` the logical screen size. For this category n=1, including empty localization.

```text
x = x0
if signed32(low32(x0+w)) > W: x = low32(W-w)
else if signed32(x0) < 0:     x = 10

d = low32(-12 - low32(n*h))
y = y0
if signed32(low32(y0+d)) > H: y = low32(H-d)
else if signed32(y0) < 0:     y = 10
```

These values are written back into the queue record, not the shared hover anchor. There is no second left clamp after the overflow branch; over-wide text can yield negative x. The Y expression deliberately subtracts height; do not replace it with a conventional bottom-bound check.

With an empty background section, the renderer resolves `ani/Control.ani [Dialog21]`, `(1,30000)` cache arguments, and, if present, calls its vtable `+0x0C`:

```text
frame=0
source RECT=(0,0,100,100)
destination=(x-5, y-5, w+10, (low32(3*n*h) logicalShiftRight 1)+10)
color=0, mode=0
```

This is a **100×100 source crop**, not category 9's 100×200 crop. There is no outline call. One retail line at h=12 produces backdrop height **28** regardless of measured text height. Existing Dialog21 asset identity from GFX-UI-008/009 applies; no new artwork is required.

Art is submitted first. Then a third FontInfo query supplies current AA/style/corner parameters. Each colored entry is measured again with its stored face/height and icon width 21. At alignment 0 this second measured size does not influence the text origin:

```text
textX = alternate ? low32(x+w) : x
textY(first) = y
textY(next) += truncTowardZero(signed32(low32(3*h))/2)
```

Consequently, absent clamping and with a stable nonzero alternate flag, swap text X is **A.x+2*w-3**. The EXE layout flag is sampled at enqueue and again at draw, so state changes between them use the respective readings. The independent graphic-DLL Arabic flag is not set by either of these arithmetic branches. The DLL boundary replays use its non-Arabic path; do not reinterpret the added width as evidence that these calls enable right-to-left rendering.

`ShowEmotionStringCommon` at `0x5931A9` receives `(textX,textY,white,text,icons,storedFace,h,FontInfo+8,21,0,0,FontInfo+4,FontInfo+0x214,&FontInfo+0x218)`, 14 DWORDs. The two zero arguments are **icon XY offsets**, not clipping dimensions. No text-width limit, hint scissor or per-entry clipping rectangle is supplied. Existing viewport/GPU clipping is downstream.

The queue does no literal `\n` translation and no tilde normalization. Raw LF, if supplied, reaches graphic.dll's existing emotion-text newline handling; at nominal h=12 the internal LF step is 15, while the queue's external per-entry step is 18. A multiline string is still one queue entry and does not enlarge its backdrop by its internal line count. Retail swap values are plain ASCII without these tokens. Original DLL execution also verifies that a 200-character string advances past the viewport rather than automatically wrapping; this is an API/glyph-position result, not a claim about final clipped GPU pixels.

## 5. Missing dependencies and cleanup

| Condition | Native outcome and evidence |
|---|---|
| Outer FontInfo null | `0x5B9C5D..0x5B9C82` logs MyShellDlg.cpp line 0x1842, exits before either category. |
| Dance static row absent, including retail type 3 | Factory returns empty shared pair; `0x5DA7AA` exits without art/text/warnings. Selection remains visible. |
| Learned dance absent but static row present | Renders static level-0 text and red missing-learned warning. |
| Swap Cn_Res key absent / returns empty | Inherited `0x76B711` logs and returns non-null empty string. One empty queue entry, width 0; h=12 gives a **10×28** backdrop if available; text API receives empty string and emits no glyphs. |
| Missing configured localization path or file | Inherited `0x76B745`: missing Info.ini StringFile value or failed fopen logs and returns without inserting records. It does not erase pre-existing global map entries. Subsequent absent keys follow the empty-string row above. |
| Swap Dialog21 absent | `0x59301A` skips art and continues text. |
| FontInfo null during enqueue | `0x592C94..0x592CB7` logs MyCommon.cpp line 0x3EC, destroys temporary record, does not enqueue. |
| FontInfo null during deferred draw | `0x593088..0x5930AB` logs MyCommon.cpp line 0x48F, returns **after** any backdrop draw. |
| Underlying graphic font record unavailable | `graphic.dll!0x10017160` measurement and `0x10018410` draw return `(0,0)` with no glyphs. Backdrop can still be drawn from the queued dimensions. It is distinct from FontInfo being null. |
| Hero singleton not yet allocated | `0x404460` attempts lazy construction. If it returns null, swap's immediate `0x6DA8B2` dereferences `+0xF1C` without a guard; valid dance's learned lookup similarly reads `+0x120C` without a guard. This is not a native graceful no-hint state. |
| Entire GameDataSet, Magic-type manager or required settings object null | Call sites immediately dereference object/vtable or getters. No supported safe fallback is established for an uninitialized core service. Missing optional art/icon results are different from a null service object. |
| Null optional data-icon provider, retail swap bytes | Retail text has no icon tokens. Plain glyph drawing still proceeds; DLL boundary tests use a null icon provider. No general missing-icon-token policy is added here. |
| Drag suppression / visible false | Shared frame gate skips the status-panel call; neither branch clears shared selection itself. BeginTick has already cleared prior deferred records. |
| Device-lost frame | End-frame floating-text flush is skipped by the enclosing frame gate. Next BeginTick clears entries; no indefinite deferred replay. |

Ownership is explicit: `0x592D29` destroys colored lines, background string, then face string; BeginTick applies that destructor to every queued entry. Caller and intermediate vectors are destroyed after deep enqueue, and frame dispatch retains queue storage until the next clear. ANI/icon providers are borrowed services, not freed by the hint renderer.

Allocation-return edge cases are retained rather than replaced by a universal safe fallback: if the CMagic object allocation returns null, `0x6F4E1C..0x6F4E45` logs and returns an empty pair. If only its control-block allocation returns null, the captured constructor can return a successfully initialized raw object with control=0; normal shared cleanup cannot own that raw pointer. `cleanup-failure-replay.json` records both outcomes. Throwing allocators, arbitrary corrupt pointers and malformed configurations are not assigned invented graceful behavior.

## 6. Shared transitions and hover versus activation

Only the additional consequences are listed; GFX-UI-006/008/009 remain the source of shared input rules.

- A fresh Magic→dance hover replaces category 9 with `0x38`/parameter 3. It renders nothing with clean data; it does not preserve visible Magic text. Fresh dance→swap selects `0x6A`/parameter `0x5E`; swap→Magic selects category 9/full Magic type.
- Repeated hover in the cached occupied cell posts nothing. Replacing kind 5 with kind 6 while remaining in that cell leaves category `0x38` selected until a real producer event occurs. Cached content is not permission to recompute selection every draw.
- An Action cell posts no hint selection and can leave the previous selection stale. Outside mouse movement itself does not clear; the established end-of-grid-Show cursor poll posts command 6 when leaving. Empty-cell entry clears once; repeated empty hover does not repeatedly clear. Reentry after clear posts a fresh anchor and category.
- Command 6 clears the shared visibility fields, not the stored category/parameter/anchor. Both new category setters preserve the full DWORD parameter. Drag suppresses rendering without erasing the selection. Ending drag can therefore expose that retained selection.
- Queue ownership is per frame: old swap records are cleared before the next status pass. Category changes do not replay the previous frame's swap text.
- The separate dance dialog posts on every current hit and clears on leaving its own prior hover. Its ordering with other producers follows actual posted-message delivery; the renderer adds no producer-priority rule.

Quickbar activation remains a different path: GFX-UI-006 establishes command `0x10` with packed content ID/index, kind-5 dispatch to `0x44344A`, and kind-6 dispatch of command `0xC29`. Hover does not use those activation parameters or initiate those actions. No gameplay or network effect is inferred here.

## 7. Deterministic conformance cases and resolution vectors

The bundle runs **558 verification cases: 557 bounded original-x86 cases and one retail-catalog assertion**. The four suites contain 465 construction/selection/queue/catalog cases, 51 input/transition/gate cases, 33 DLL/font/null-object cases, and 9 allocation/cleanup cases. Foreign services are explicitly mocked. The prior Magic text/wrapper/layout proof is inherited; it is not relabeled as a fresh full-helper/live-client execution.

| Test | Expected result | Proof type |
|---|---|---|
| Main kind-5 slot contains learned 1415, grid context 3 | Posts 7 then 0x38/3; key30 miss; no art/text/warning | Original producer, constructor and null-helper execution + retail table |
| Separate dialog hit 1380, not learned | Actual type1380 posted; static level0 groups Dance2 / Elementary / Dance / Fixed, then red missing-learned warning | Producer/construction/warning execution; inherited text contract |
| Separate dialog 1380 learned with arbitrary learned level/EXP | Constructor still gets level0/EXP0; same static groups, no warning | Constructor/ABI execution + inherited text contract |
| 1415 learned, active class!=6 | Static BattleDance; applicable requirement; red Performer warning | Original warning decision + inherited requirement formatting |
| 1415 not learned, active class!=6 | Missing-learned warning wins over Performer warning | Original warning decision |
| 1419 learned, active class6, insufficient phase | Red requirement; no additional Performer warning | Inherited requirement instructions + original warning decision |
| 1420 learned, active class!=6 | No required-phase group (phase0), no Performer warning | Retail row + original warning decision |
| Missing 1411 / arbitrary absent type | No static object and no visible hint, even though 1411 passes classifier | Original lookup + null-helper execution |
| Swap state 1 versus 0, 2, 0xFFFFFFFF | Main string only for 1; Alternate for all others | Full original branch and enqueue execution |
| Swap parameter 0xDEADBEEF | Parameter retained, rendering still follows hero state | Dispatcher + branch dataflow/execution |
| Swap missing key/art/three FontInfo sites/font record/hero | Exactly the dependency matrix above | Original boundaries, with injected dependency results |
| Magic→dance→swap→Magic, same-cell replacement, outside poll, empty cell, drag | Exactly section 6; no invented resets | Original producer/dispatcher/frame-gate execution |
| Deferred EndFrame followed by BeginTick | Ordered draws, then destruction of every record and retained capacity | Original loop execution |
| Long string, LF, literal backslash+n | No queue wrap; DLL LF step; no escape expansion | Queue instructions and original DLL execution with synthetic glyph advances |

Run each relevant case at both 800×600 and 1024×768 with the inherited shared-Magic layout function. Main cell index i has `A.x=90+40*i`, `A.y=H-1`. For a **valid directly selected** dance at that anchor, helper inputY is **557/725**. For measured wrapped line count N and maximum width M, use Rendering/21's unchanged panel width M+10, height 12N+10 and upward placement. The actual main context-3 producer renders no panel at either resolution. A separate dialog cursor example `(105,205)` with origin `(100,200)` produces shared anchor `(105,247)` and helper input `(105,205)` at either resolution; the shared width clamp uses the actual screen width.

For swap, one entry and normal h=12:

| Logical screen | Queue/text Y | Backdrop Y | Backdrop height |
|---|---:|---:|---:|
| 800×600 | 539 | 534 | 28 |
| 1024×768 | 707 | 702 | 28 |

For **synthetic uniform six-pixel glyph advances only**, the exact retail strings measure 180 (Main) and 210 (Alternate). At main slot 0, anchorX90:

| Layout | Hero state | Backdrop X / width | Text X |
|---|---:|---|---:|
| Normal | 1 | 82 / 190 | 87 |
| Normal | 0 | 82 / 220 | 87 |
| Alternate | 1 | 262 / 190 | 447 |
| Alternate | 0 | 292 / 220 | 507 |

At slot9/anchorX450 in alternate layout, 800-wide clamps textX to800 for either string (backdropX615 for Main,585 for Alternate); 1024-wide fits without clamping and yields textX807/867 respectively. These are deterministic metric-injection vectors, **not measured retail Arial widths**. The complete test grid includes negative coordinates, zero width, over-wide strings and the unusual bottom comparison.

Established without host/GPU assumptions: payload widths, static row keys/content, warning predicates, localization bytes, call arguments, queue ownership, arithmetic as functions of measured width/height, and draw order. Host-dependent: installed font file/version, glyph advances, codepage realization and rasterization. GPU-dependent: final sampling, alpha/blending, viewport clipping and exact pixel coverage. No live Windows screenshot corpus or native-versus-managed pixel comparison was produced. Those limits do not leave an untraced HUD-010 selector or renderer branch; they remain explicit platform acceptance inputs.

## 8. Current implementation handoff, read only

Read-only source snapshot: modern OpenConquerClient HEAD `0fb467dc13bdbb914bfd7d41b0e824b52cfbad49`; exact file hashes are in `managed-readonly-inventory.json`. This is a later snapshot than GFX-UI-009's integration inventory. `10_work/OpenConquerPublic` is absent; the supplied OpenConquerPublic archive is not treated as the modern client checkout. No implementation changes were made anywhere.

The existing client provides the necessary seams:

- `MainHudQuickbarInput` already emits Dance/WeaponSwap notifications, anchors and Context. Preserve its native cache behavior. `MainHudQuickbarHintHandoff.Apply` currently clears a visible Magic hint for these notifications; later implementation must instead store the corresponding category/full parameter after the anchor operation.
- `MainHudStatusHintState` already stores visibility, category, Magic type and packed-anchor interpretation. Generalize those existing selection fields for the two categories without conflating invisible selection with missing static data. `CanRenderMagic` is currently category9-only.
- `MainHudMagicHintContent` already loads MagicType, MagicEffect, Cn_Res and SubProfessionInfo. `MagicTypeFile.TryGet(type,0)` and a synthetic value carrying `(type,0,0)` supply the dance construction input. `MainHudMagicHintTextBuilder.Build` already contains the shared dance warnings and requirements; its runtime learned list must stay actual, not be populated with the synthetic object. `MainHudMagicHintRenderer` currently requires a learned match in its category9 entry point; the category0x38 entry point must use the static construction route while reusing its text/layout work.
- Swap needs the actual DWORD hero +0xF1C equivalent, tested with equality to1. The existing Magic runtime snapshot does not include that field. An invented default state or boolean interpreted as nonzero is not an evidence-backed replacement.
- `ClientKeyedStringResources.GetEncoded` supplies both swap keys. Existing `MainHudStatusHintRenderer.NormalTextContext`, `NormalTextOptions` and `BackdropTexture` expose normal text and art resources. Use whole-string measurement/emotion-text behavior with icon width21; do not reuse the Magic English wrapper or the category8 no-art/zero-size suppression policy.
- `OpenGLTextContext.Layout/Draw` and `OpenGLRenderer.DrawSprite` provide the existing text/sprite facilities. Swap requires the 100×100 crop, padding, no outline, and a deferred phase after the synchronous status pass. A managed queue or equivalent retained draw record needs the same per-frame clearing and ownership behavior; the evidence does not require native C++ allocation machinery.

This handoff identifies the required changes for future implementation. It does not claim that the current implementation conforms to HUD-010 or that its platform rendering has been verified.
