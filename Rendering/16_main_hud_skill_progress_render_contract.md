# GFX-UI-003 — main HUD skill progress, clean 5517

Native evidence contract, 2026-09-27. This slice closes Progress42 state transitions,
placement, content and draw submissions. It also **disproves the proposed Progress44
no-draw boundary**: its live style 0xA draws procedural experience bands without
looking up an ANI section. No production implementation is changed.

Evidence: [GFX-UI-003 bundle](../../10_work/docs/evidence/gfx-ui-003-main-hud-skill-progress-5517/README.md).
Machine-readable results are in that directory; all addresses below are preferred
virtual addresses in Conquer.exe unless a DLL is named. Raw assembly is authoritative
where decompiler output merges shared exception-handling tails.

## Scope and provenance

The source is `00_clean/clean/5517`, compared byte-for-byte by SHA-256 with the
already-established GFX-UI-002 clean manifest. Important binaries:

| File | SHA-256 |
|---|---|
| Conquer.exe | `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62` |
| graphic.dll | `b099913f83c13b863ea2738f3f95f81ec2eb186b80c16e7ba7fdacf4feea9d46` |
| C3_CORE_DLL.dll | `f5bbe1d408320de33c17422b58576d3e883fa6f93830fe159ac27f3396551a7b` |
| TqPackageWdf.dll | `51312489c69ce51205cf2b84768a2bc875468e1177b092fed0aca0b1ee14c571` |
| ani/Control.ani | `a1db47baaeb2f75eea3b5216378f97d713c2afeaefe05ec02e6f584794532d27` |
| data.wdf | `fc628e4adeb7de48b0b7cde3c7793c7177a289a6defe9b90a33a1f683dcdb132` |

The exact GUI file hashes and all source sizes are in `source-manifest.json`.
Existing parent placement, UI calibration, generic style-0 rendering, texture
failure propagation and wider same-offset receiver exclusions are reused from
[GFX-UI-002](15_main_hud_gauge_render_contract.md), with evidence hashes in
`shared-evidence.json`. The missing Progress44 ANI investigation is not repeated.

## Progress42 identity and exhaustive bounded writer census

Object: `CDlgMain+0x13F590` = `shell+0x140528`; main is embedded at
`shell+0xF98`. The constructor call at `0x4B5E67` reaches
`CMyProgress_Constructor 0x5A8F86`, whose byte store `0x5A8FB5` initializes
subvariant `+0x84` to **0**. Init at `0x4BB981` passes range 0..100,
style 0, overlay mode 0. The zero overlay-offset arguments are unused.
Fill geometry at `0x4BB99A` is width 92, height 92, alternate width 92.
The per-frame range reset at `0x4BD671` uses `0x65D256`, which returns 100.

Setter `0x5A9A60` stores the low argument byte at `0x5A9A64`.
All eight native direct calls and live Binary Ninja xrefs agree; there are no
setter data references:

| Call | Receiver | Written subvariant |
|---|---|---|
| 0x4BB92E | Progress40 | 1 |
| 0x4BD612 | Progress40 | 0 |
| 0x5C39E6 | Progress41 | 1 |
| 0x5C39FE | Progress41 | 0 |
| **0x4BE18D** | **Progress42** | **1** |
| **0x5C3A6A** | **Progress42** | **0** |
| **0x4BCD09** | **Progress42** | **2** |
| **0x4BCD2C** | **Progress42** | **0** |

The 12 explicit Progress42 base references are:

| Address | Use |
|---|---|
| 0x4B5E5D | Constructor receiver |
| 0x4B9F85 | Destruction |
| 0x4BB71A | DDX binding |
| 0x4BB978 | Init receiver |
| 0x4BB994 | Fill geometry |
| 0x4BC779 | Show receiver, saved at EBP-0x18 for timer-tail setters |
| 0x4BD66B | Range reset |
| 0x4BE187 | Variant-1 receiver |
| 0x5BA7B3 | Status-hint range query |
| 0x5C3A64 | Shell-relative variant-0 receiver |
| 0x7ED225 | Unwind destruction |
| 0x7F0D81 | Unwind destruction |

The clean executable-section scan checks the widget-relative byte and rebased
main/shell offsets, including wider overlapping stores. Its 36 candidates are the
same 32 wider candidates and four byte candidates already reviewed in GFX-UI-002.
The only CMyProgress byte writers are its constructor and setter; the other two
byte candidates are CMyButton. No new direct rebased store is found.
`instance-references.json`, `setter-clean-calls.json`,
`subvariant-write-candidates.json`, native xrefs and `census-review.json`
preserve the evidence. This is a native code/receiver census for the clean image,
not a claim about arbitrary memory corruption or injected code.

## Variant 1: exact status/message/UI chain

When the status update receiver is the local CHero:

1. `CMsgUserAttribEx__Process 0x757374` (packet 10017), discriminator **25**,
   enters `0x7574C5`, copies the incoming 16-byte status bitfield, and invokes
   virtual slot `+0xD0` at `0x757712`.
2. CHero construction installs vtable `0x86AD08`; slot address `0x86ADD8`
   contains `0x65F01A`. That method compares **old status bit 4** with incoming
   bit 4 at `0x65F1B5` onward.
3. On **0 -> 1**, and only if hero byte `+0x9F4 == 0`, it calls
   `0x65ED10` at `0x65F1FF`. This records timeGetTime in hero `+0xD40`
   and writes skill value `+0x510 = 100` at `0x65ED24`.
   It then pushes command `0x40D` at `0x65F205` and calls
   `Conquer_PostMainWindowMessage464 0x64D015` at `0x65F20A`.
4. That wrapper calls PostMessageA with message `0x464`, command in wParam and
   payload 0 in lParam if the main HWND exists. This is queued delivery.
   The base status-bitfield application at `0x65FD6E` occurs after the post.
5. The native dispatcher maps `0x464/0x40D` to `0x5C3A08`.
   It requires status bit **5 absent**, then hero byte `+0x9F4 == 0`.
   At `0x5C3A3A` it calls `0x4BE165` with main as receiver.
6. `0x4BE165` requires `main+0x8EEC4 == 0`. If so, `0x4BE18D`
   sets Progress42 variant 1 **before** any magic-count or transformation query.

The rest of `0x4BE165` governs whether to show/populate the embedded dialog at
`main+0x8EDBC`; it does not gate the already-performed variant write:

- `0x6F77D9` counts learned entries whose effect parameter `0x19 == 1`.
- If `CRole_HasTransformLook 0x650B4C` is true, it enumerates that category
  through `0x6F786C` and counts non-null entries satisfying
  `0x6F4EB5`: effect parameter `0xD == 0x13`.
- A positive resulting count calls `0x57539B` at `0x4BE202`; that routine
  invokes dialog show command 5 and populates its grid. Its transformed entry
  filtering is a separate operation; do not infer it from the preceding count.

The guard is the embedded dialog's `+0x108` member, initialized to zero by its
constructor at `0x574C94`. Its broader semantic label is not needed or invented.
Likewise no gameplay name is inferred from inherited “TeamMagic” names or the art.

The proven purpose supports renaming `sub_4be165` to
**`CDlgMain_HandleSkillGaugeStatus4Activation`**. The live annotation and its old
name/comment are retained in `annotations.json`.

## Variant 0: both command producers and exact guards

Native `0x464/0x40E` dispatches to `0x5C3A44`. It requires only status bit 5
absent; it has **no** hero `+0x9F4` or embedded-dialog `+0x108` guard.
`0x5C3A6A` sets `shell+0x140528` variant 0, then the handler hides the
embedded dialog at `shell+0x8FD54` and updates following UI state.
It does not clear or restart the highlight fields.

Two native command 0x40E producers are established:

| Producer | Trigger and order |
|---|---|
| Status update `0x65F01A` | Old status bit 4 1 -> incoming 0: zero hero+0x510 at `0x65F1D0`; call `0x65ED40` (value reset, hero+0xD44 timer virtual+0x14 invoked with 3000, then a named UI event); push 0x40E at `0x65F1DC`; post through `0x65F20A`. No +0x9F4 suppression on this falling edge. |
| Per-frame expiry `0x65ED95` | Called at `0x65E0D4`; requires status 5 absent, unsigned hero+0x838 >=3, status 4 present, and unsigned now >= uint32(hero+0xD40+20000). Construct action 0x5D; send if construction succeeds; even on construction failure continue to zero +0x510 at `0x65EE46`, clear status 4 at `0x65EE4C`, push 0x40E at `0x65EE52` and post at `0x65EE57`. |

The immediate-producer census has seven pushes of 0x40D/0x40E:
the above three, plus `0x45F57A/0x45F590/0x48E9B7/0x48E9CA`,
which are DDX control IDs, not message producers. Raw contexts are in
`command-producer-candidates.json`. Message routing and guard cases are replayed
from native instructions in `command-chain-replay.json`.

A posted command changes the variant when its handler executes. The producer's
timestamp is not proof of delivery before a particular HUD frame. A delivered
40D/40E before Show affects that Show; the timer-tail stores below are always after
that frame's Show.

## Complete transition rules and ordering

Let V be Progress42's byte `+0x84`, A be main DWORD `+0x198`, and S be main
DWORD `+0x19C`. The native rules are:

| Event / guard | Effect |
|---|---|
| Widget constructor | V=0 |
| Accepted 40D and embedded guard zero | V=1; A/S untouched |
| Accepted 40E | V=0; A/S untouched |
| Accepted 40F, current unsigned hero+0x510 <100 | S=0, A=1; V untouched |
| Tail with A=0 | No change |
| Tail with A!=0 and S=0 | V=2, then S=timeGetTime(); skip expiration comparison in this pass |
| Tail with A!=0, S!=0, now < uint32(S+500) unsigned | No change, including no reassertion of V=2 |
| Tail with A!=0, S!=0, now >= uint32(S+500) unsigned | V=0, A=0; S retained |

40F's already-proven packet producer is attribute27: clamp to100 and store at
`0x757C1F`, post through `0x7585F3`. The handler checks the **current** value
at `0x5C3CD8`, not a value carried by the queued message. Arm is
`0x4BE215`, called at `0x5C3CE6`.

The render sequence is range updates, earlier HUD, Dialog4, Progress42 Show at
`0x4BC78E`, Progress44 Show at `0x4BC7F7`, grid/buttons, then highlight tail
`0x4BCCEE..0x4BCD31`. Thus:

- An arm event preserves the old V for that Show, then selects 2.
- At the ordinary 500 ms equality boundary, that frame still draws incoming V;
  the tail resets it to 0 for the next Show.
- There is **no saved previous variant**. Starting highlight from 1 gives 1 ->2 ->0;
  variant 1 is lost.
- A delivered 40D during a running nonzero-S highlight replaces 2 with 1. The
  tail leaves 1 in place until expiration forces 0.
- A delivered 40E during the timer replaces V with 0 but leaves the timer active.
- Rearming clears S; the next tail forces 2 after that Show, regardless of an
  intervening variant-1 or variant-0 write.

Exact expiration instructions: `ADD ECX,0x1F4` at `0x4BCD1E`,
`CMP EAX,ECX` at `0x4BCD24`, `JB` at `0x4BCD26`.
It is **not** an elapsed-time subtraction:

| Wrap case | Native result |
|---|---|
| S=0xFFFFFF00 | Deadline wraps to 244; a next pre-wrap tick 0xFFFFFF01 already compares >=244 and expires early. |
| Same S, first later pass after wrap | now 0 or 243 keeps; now 244 expires. |
| Deadline remains high, no pass until after wrap | A low post-wrap now is below that old deadline, so the timer can persist almost a full DWORD cycle. |
| First timeGetTime() returns 0 | S remains the zero sentinel; next active tail starts again and does not test expiration. |

Initialization is precise about what is proven: the widget constructor sets V=0.
The inspected main/shell constructor chain does **not** explicitly initialize A/S.
Do not promote the replay's zero-filled fixture storage into native startup proof.
A/S before the first Arm remain external heap state for this contract; Arm
deterministically overwrites both. The transition rules above cover arbitrary A/S,
and every timeline declares its initial fixture. This is not an assertion that
a native login always begins with an inactive timer.

## Placement and final geometry

Both GUI files contain `130-1018`: x=0, y=50, w=92, h=86.
Parent origin is `(0,H-141)`. Native Init stores the relative control origin
at `0x5A97B8/0x5A97C1`; calibrated stores are `0x5A97EF/0x5A9809`.
The already-proven model is
`sx=float32(8/mx), sy=float32(16/my)`,
where (mx,my) is MapDialogRect's result for RECT(0,0,4,8).
Define `R(z)=trunc(z+0.5)` using the native x87 operations.

| Logical resolution | Baseline MapDialogRect 8x16 origin | Active calibration |
|---|---|---|
| 800x600 | **(0,509)** | (R(0*sx),459+R(50*sy)) |
| 1024x768 | **(0,677)** | (R(0*sx),627+R(50*sy)) |

The fixed geometry call after Init overwrites width/height/alternate width with
**92/92/92**. Fill dimensions are not font-scaled. For arbitrary valid calibration,
substitute the resulting (X,Y) into every formula below; the parent offset is not
multiplied by sx/sy.

Let `r=float32(92/100)=0.9200000166893005` and
`p=trunc(value*r)` with native x87 arithmetic. Show's signed upper clamp limits
the inputs to100. The live call supplies equal inputs, so the dual-value frame-1
branch is unreachable. For the required domain 0..100:

| V | Value | Frame / source | Destination origin / effective extent |
|---|---|---|---|
| 0 | 0 | No ANI lookup or draw | None |
| 0 | positive | Frame 0, RECT(0,92-p,92,92) | (X,Y+92-p), requested 92×p |
| 1 | 0 | No ANI lookup or draw | None |
| 1 | positive | Frame 2, same RECT | Same geometry; alternate width is also 92 |
| 2 | any, including 0 | Frame 2, whole image / NULL RECT | (X,Y), **128×128** |

The whole-frame path is `graphic.dll!0x1000BE20` ->
frame vtable+4 -> `0x10012120`. At `0x1001216B` it calls
Sprite_SetCoor with NULL source and requested width/height 0. Core
`0x10015AF0` substitutes the decoded logical texture dimensions128/128.
It does not resize the whole highlight to the 92×92 fill box.
`downstream-replay.json` executes these wrappers; `render-vectors.json`
executes core coordinate setup and Sprite_Draw through its device-call boundary.

**Value 1 edge:** p truncates to 0, but the positive-value path still submits a
cropped draw with source(0,92,92,92) and requested 92×0.
Core substitutes128 for zero requested height. Final origin is (0,H+1), extent
92×128, so it has no logical framebuffer intersection at baseline.
Suppressing the submission is not the native call contract even though it is
offscreen here.

At baseline, nonempty cropped geometry ends at Y+92=H+1, extending one unit below
the framebuffer; whole highlight ends at Y+128=H+37, extending 37 units below.
Whole highlight's logical intersection is (0,509,128,600) or (0,677,128,768).
Native does not rewrite/crop those submitted rectangles. Core vertices use the
usual -0.5 coordinate adjustment, recorded explicitly with UVs in the vectors.
Ordinary viewport rasterization clips screen-edge coverage. The intersection
rectangles are geometric calculations, not measured GPU pixel masks.

## Exact ANI and content closure

Logical ANI section (frame path spelling is exact):

```ini
[Progress42]
FrameAmount=3
Frame0=data/main/ProgressPower.dds
Frame1=data/main/ProgressPower.dds
Frame2=data/main/ProgressPowerH.dds
```

The preserved raw section bytes and their source offset are in the bundle.
The source file on disk is `ani/Control.ani`; its case-insensitive Windows
identity is the requested Control.Ani.

| Logical path | ANI indices | Native WDF UID | Container | Offset | Size | Decoded | FourCC |
|---|---|---|---|---:|---:|---|---|
| data/main/ProgressPower.dds | 0,1 | 0x3BEA48E0 | data.wdf | 21761588 | 16512 | 128×128 | DXT3 |
| data/main/ProgressPowerH.dds | 2 | 0x9B8E4823 | data.wdf | 21778100 | 16512 | 128×128 | DXT3 |

| Asset | SHA-256 of exact DDS bytes |
|---|---|
| ProgressPower.dds | `c32b0c502b7ab00aff2308a5708ac777fe6ee29ff101bfad056bd4c54ad94248` |
| ProgressPowerH.dds | `e4d10a40d7ead3d91a3b29cf5339baca487df1f41a40c8afa8c892c80f351868` |

`assets.json` also records WDF table index, raw index record, reserved field,
decoded RGBA hash and extraction path. The UIDs are produced by executing the
clean native `TqPackageWdf.dll!0x100099D0`, with CRT boundaries mocked.
Both files decode successfully; no loose override is present in the clean corpus.
PNG previews are inspection aids, not replacement native content.

Native eager-load closure is **three frame entries**, all loaded by
`CAniX_CreateFromIndexInfo 0x1000BC80` (per-frame load at `0x1000BD68`),
with all-or-nothing resource success. Reachable live Progress42 drawing is
**frame 0 and frame 2**. Both closures require the same two unique DDS files.
Duplicate frame 1 repeats exactly the frame 0 path, UID and bytes; it adds no unique
content dependency even though the loader may create a separate frame object.
Retain the three-entry frame list for native-compatible ANI loading.

## Deterministic reference vectors

These are clean original-instruction replays, not screenshots. Both logical
resolutions and x87 precision controls 24/53/64 are covered. All 101 input values
across all 3 variants are checked: **1,818 cases**. The required examples have
72 detailed geometry records including vertices, UVs and device arguments.

For X=0 and Y=509 or677:

| Variant/value | Frame | Source RECT | Destination origin | Requested -> effective extent | Submission |
|---|---|---|---|---|---|
| 0/0 | — | — | — | — | None |
| 0/1 | 0 | (0,92,92,92) | (0,Y+92) | 92×0 ->92×128 | Draw, offscreen |
| 0/50 | 0 | (0,46,92,92) | (0,Y+46) | 92×46 | Draw |
| 0/99 | 0 | (0,1,92,92) | (0,Y+1) | 92×91 | Draw |
| 0/100 | 0 | (0,0,92,92) | (0,Y) | 92×92 | Draw |
| 1/50 | 2 | (0,46,92,92) | (0,Y+46) | 92×46 | Draw |
| 1/100 | 2 | (0,0,92,92) | (0,Y) | 92×92 | Draw |
| 2/any required value | 2 | NULL; full128×128 | (0,Y) | 0×0 ->128×128 | Draw |

The nine timelines in `transition-vectors.json` execute39 frames, each with
before-Show state, draw record and after-tail state. At value 50, start 1000:

| Timeline point | This Show | After tail |
|---|---|---|
| Arm from V=0 at1000 | Cropped frame 0 | V2, A1, S1000 |
| Immediately before expiry,1499 | Whole frame 2 | Unchanged |
| Exact expiry,1500 | Whole frame 2 | V0, A0, S1000 |
| Following Show,1501 | Cropped frame 0 | Unchanged |
| Arm from V=1 at1000 | Cropped frame 2 | V2, A1, S1000 |
| 40D delivered at1100 during timer | Cropped frame 2 | V1 retained until expiry |
| Expiry with V1 at1500 | Cropped frame 2 | V0; V1 is not restored |
| 40E delivered during timer | Cropped frame 0 | A/S keep running |

The remaining timeline records cover rearm, timestamp 0 and both wrap directions.
Message-edge replay separately tests 3 native routes,8 status edge/suppression
cases,8 dispatcher guard cases and16 activation-body cases.

## Progress44: corrected implementation boundary

The missing-section fact is retained from note13. Its prior **consequence** is
corrected: live Show does not perform that failing lookup.

Init `0x4BBA2A` pushes style 0xA at `0x4BBA14`, overlay 0.
The arithmetic style dispatch at `0x5A90D3` reaches `0x5A915C`.
It is not a style 1/2 branch. With positive value, the English/non-Arabic branch
submits three ShowBlock calls:

| Call | Color |
|---|---|
| 0x5A9287 | 0xFFF1D06E |
| 0x5A92C6 | 0xFFE8A326 |
| 0x5A92FE | 0xFFAB916C |

The only resource query on this branch is language string 0x28BA; NULL or a
non-Arabic string takes the English branch. There is no Progress44 ANI/DDS lookup.
Zero emits no block. Negative values take the red 0xFFFF0000 path at
`0x5A9414`; native's upper-only signed clamp does not remove that branch.

The style reads existing range/origin and writes no persistent **gauge object**
state. It does have rendering effects: `graphic.dll!ShowBlock 0x10013D80`
writes its global vertices, prepares line mode when necessary, submits vertex
format 0x44 through device vtable+0x130, and calls DrawPrimitiveUP at
`0x10013E68` (triangle strip 5, count 2, stride 20). The downstream replay proves
those submissions with mocked device calls; it is not a live GPU run.

At baseline, GUI `130-1019` gives origin(99,97), width 398, window height 8;
Init subtracts 4 to give fill height 4. The caller decrements parentY at
`0x4BC7E9`, so final (X,Y)=(99,H-45): (99,555)/(99,723).
For a positive width p, its English bands are:

```text
(X,Y,     X+p,Y+1)   0xFFF1D06E
(X,Y+1,   X+p,Y+3)   0xFFE8A326
(X,Y+3,   X+p,Y+4)   0xFFAB916C
```

The 36 Progress44 replay cases use a declared synthetic range 0..100 to isolate
the branch: value 50 gives p 199 and right 298. **The live maximum is not 100**:
the existing experience scaling/range contract in note13 still applies.

Show at `0x4BC7F7` returns into `0x4BC7FC`, with the next grid call at
`0x4BC810`, then subsequent HUD buttons. Three original-instruction continuation
probes verify this for zero, partial and full fixture values.

Implementation consequence: no Progress44 ANI/DDS content dependency is needed.
Visible 5517 parity still requires its experience inputs/range scaling and
procedural band draw. A managed implementation may compute these directly rather
than instantiate a CMyProgress-shaped object, but it cannot drop this behavior
on the proposed missing-section rationale. The requested universal “no persistent
or render side effect” claim is **false**.

## Verification limits and implementation acceptance

`validation.json` records byte comparisons, replay counts and external inputs.
Native instruction captures are checked against the clean PE images.
The replay mocks OS calls, resource/device boundaries, selected magic-query/UI
dependencies and CRT conversion helpers; exact boundaries are described in the
scripts and bundle README. Recorded ABI arguments and core vertices are the
managed conformance reference.

No live Windows framebuffer, actual OS MapDialogRect result, rendering-thread
control word, pre-arm heap contents or driver allocation is claimed as observed.
Conditional geometry and the full parameterized transition rules are provided
instead of inventing those values. Shared sampler/pipeline assumptions remain
those of GFX-UI-002. A future managed implementation must compare its call/vertex
results with these vectors and separately validate actual target-backend pixels.

Reject an implementation that restores variant 1 after timer expiry, changes the
DWORD deadline arithmetic to elapsed subtraction without an explicit deviation,
renders frame 1 for equal inputs, scales the 92×92 fill box with the font factors,
shrinks the whole highlight to 92×92, adds a third unique skill asset, or omits
Progress44 based on its missing ANI section.
