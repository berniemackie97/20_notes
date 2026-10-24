# GFX-UI-009 — main HUD quickbar Magic status hints, native 5517

**Verdict: READY FOR GFX-UI-009 IMPLEMENTATION.** The category-9 input/state/text/layout/content contract is closed against original native instructions. This is evidence readiness, not a claim that a managed implementation exists or has passed pixel comparison. No production source, executable, or BNDB was written; Binary Ninja analysis names/comments were applied in memory and their previous values retained.

Scope: shell category 9, including its zero-ID branch because native quickbar configuration can produce it. Category 8/subkind 6 is the skill **gauge** hint and is a different contract. Existing GFX-UI-006/008 captures were reused, not reinterpreted as evidence of category 9. Changes to unrelated-category text below only correct two previously false dispatcher labels.

Evidence bundle: `10_work/docs/evidence/gfx-ui-009-main-hud-magic-status-hint-5517/`. Unless a DLL is named, addresses are virtual addresses in clean `Conquer.exe`. `native/<module>/<address>.asm.txt` contains original bytes; adjacent HLIL/MLIL are navigation aids. Operand widths, assembly branches and stack cleanup take precedence over inherited symbols or decompiler prototypes. Names ending `_Analyst` are analyst names, not recovered source symbols.

## 1. Selection, visibility and quickbar handoff

| Shell offset | Width | Category-9 use |
|---|---|---|
| `+0x179694` | DWORD | Hint visible; caller tests nonzero. |
| `+0x179698` | DWORD | Also reset by command 6; no category-9 render read. |
| `+0x17969C` | int32 | Stored logical-screen anchor X. |
| `+0x1796A0` | int32 | Stored logical-screen anchor Y, including command-7's +42. |
| `+0x1796EC` | DWORD | Category, 9. |
| `+0x1796F0` | DWORD | Full skill **type**, not learned-vector index, level, item UID, or truncated WORD. |
| `+0x1796F4` | byte | Category-8 subkind; not used to select a category-9 magic. |

At `0x5B2D61`, command 7 sign-extends LOWORD of its packed payload, clamps negative X to zero, and stores `(uint32(payload) >> 16) + 42` as Y. At `0x5B2DAA`, command 9 sets visible; `0x5B2E31` selects category 9 and joins `0x5B2D9C` to store the **entire DWORD** parameter. Command 7 alone does not show a hint. Command 6 at `0x5B2DCC` writes zero to visible and `+0x179698` at `0x5B2DD4/DA`, **before** the `+0x1797CC` condition. It retains category, parameter and anchors.

`CMyGrid` at `CDlgMain+0x13C430 = shell+0x13D3C8` posts message `0x464` commands 7 then 9 for both content kinds **3 Magic** and **4 XP Magic**. The second payload is the slot content ID; it contains no XP discriminator. Both therefore select the same learned-magic lookup and renderer. Command 7 uses the cell coordinates without the extra one-pixel draw spacing:

```
X = grid.+A0 + 40*(oneBasedColumn - 1)
Y = grid.+A4 + 40*(oneBasedRow - 1)
packed = LOWORD(X) | (LOWORD(Y) << 16)
```

The main grid has one row, ten columns and origin `(90,H-43)`; its outer native HWND rectangle is 410×40. For zero-based slot i=0..9, packed anchors are `(90+40*i,557)` at 800×600 and `(90+40*i,725)` at 1024×768. The shell stores Y=599/767. The helper receives Y=557/725 after subtracting 42. These are logical-screen coordinates, not CDlgMain-local coordinates. Refer to [19](19_main_hud_quickbar_native_contract.md) for the already-proven 41-pixel draw stride and 40-pixel hit-cell distinction.

Input transition contract from `0x5A1226` and existing grid Show/poll captures:

- Repeated hover over the cached occupied coordinates with grid `+0x52` active emits nothing. Replacing a slot's content at the same coordinates does not force a new notification.
- Moving to a different kind-3/4 occupied slot posts new anchor then type. Rendering subsequently rereads the selected learned magic each eligible frame; mouse movement is not the live-value refresh mechanism.
- An empty slot, when the active-hover byte is set, clears it, posts command 6, hides the separate item tip and delegates to Default.
- An outside-grid mouse-move returns at the rectangle test without clearing or delegating. Separately, the end of `CMyGrid_Show` polls `GetCursorPos`/`GetWindowRect` through `0x5A1558`; when active and outside it clears and posts command 6. Earlier Show failure exits can bypass this poll.
- Kind 2 Action updates cached coordinates and hides the separate item tooltip on a changed cell but does **not** clear the shell skill hint. A stale category-9 hint can persist. Returning to the same cached coordinates may also preserve the previous type. Do not replace this with an invented universal leave/enter reset.
- Kind 5 uses category `0x38`; kind 6 uses `0x6A`. Neither is a category-9 producer.

Native configuration restoration `0x4BDC59` cases 3/4 forwards saved `unsignedValue/10` through `0x4BDF2C` without requiring a learned magic. In particular saved values 3/4 produce **type zero**. Thus the zero-ID branches below cannot be discarded as universally unreachable. The clean magic table itself has no type-zero row.

The frame gate is outside the renderer: `0x5DD337..0x5DD36A` checks the skill-drag visual twice, routes active dragging to cursor tracking, and calls `0x5B9C3F` only with dragging inactive and visible nonzero. The renderer first requires `Load_FontSetting_Ini` (`0x5B9C54`); null logs and returns. It does not independently test visible. The already-closed ordering is main-HUD progress → grid → buttons → checks → selected-skill image/cover → selected-skill cooldown text → frame-level status panel. This late position applies to category 9 too.

## 2. Category-9 dispatcher and exact helper ABI

Category dispatch arithmetic `0x5B9C87..0x5B9CB8` reaches category 9 at `0x5B9E6E`. If `DWORD[shell+0x1796F0] != 0`, it bypasses every XP-dialog conditional and jumps to `0x5BA6A9`. If zero, it takes the priority chain in section 6 and only reaches this lookup if no conditional branch applies.

At `0x5BA6A9..0x5BA6EE`:

```
hero = CHero_GetSingletonPtr();              // thunk403F88 ->404460
magic = CRole__FindLearnedMagicByType(hero, fullDWORDType); //6F770C
RenderMagicStatusHint(magic, anchorX, anchorY-42,
                      30, FontInfo.faceAt10D, 0xFFFFFFFF, 12,
                      5, 5, 5, 5);        //5DA7AA, ECX=shell
```

The ABI is `__thiscall` with **12 stack DWORDs**: by-value shared pointer `{raw,control}`, then X, Y, maximum-character parameter, face pointer, color, font height, left/top/right/bottom padding. `0x5DB439` returns with `RET 0x30`. There is no success boolean tested by the caller. The shell pointer is only saved for calls to `0x5DB43C`, which does not dereference it.

`0x6F770C` traverses the learned vector at role `+0x1208/+0x120C`, eight-byte shared-pointer entries, skipping null entries. It compares `DWORD[magic+0x4C]` against the full requested DWORD, returns the first match and retains its shared ownership. Miss/empty vector produces an empty shared pointer. **No WORD truncation** occurs here even though protocol producers use narrower type fields.

`0x5DA7C3` tests the raw magic pointer. Null skips all measurement/art/text and joins shared-pointer cleanup. It does not clear the shell selection, so later learned-state changes can make the hint appear without a new mouse event. Missing hero is not a separate graceful branch: `0x404460` lazily constructs the singleton when global `0x955F8C` is zero. Neither caller nor lookup provides a reliable allocation-failure/null-hero guard. Invalid pointers are not validated. Do not invent fallback data for malformed objects or allocation failure.

## 3. Magic record and required live data

Crucial folded-getter correction: `0x696B1C` is **`LEA EAX,[ECX+0x0C]`**, not a pointer load. Its existing MapPathService symbol describes another caller. `CMagic` embeds its 0x44-byte static row at `+0x0C`. `0x69A6A3` is a DWORD load at `+8`, current magic experience in this context.

| CMagic / embedded row | Meaning read by this contract | Zero-based `MagicType.dat` field |
|---|---|---|
| CMagic `+8` | Current experience, runtime value | Not from this row |
| row `+0x14` = CMagic `+0x20` | Required experience | 18 |
| row `+0x18` = CMagic `+0x24` | Skill level | 8 |
| row `+0x1C` = CMagic `+0x28` | Required character level for EXP line selection | 20 |
| row `+0x30` = CMagic `+0x3C` | Required subprofession phase | 42 |
| row `+0x34` = CMagic `+0x40` | Encoded profession requirement; unsigned `%1000` gives class ID | 41 |
| row `+0x40` = CMagic `+0x4C` | Full type DWORD | 1 |

`0x69C19E` parses `ini/magictype.dat` after seed-`0x2537` decoding; `0x69CDFB` selects the row by low32(type×10+level), copying 17 DWORDs into the embedded record. `0x6F4CF8/0x6F4DB3` require that lookup to construct a learned magic; missing row returns failure and releases the failed object. `magic-parser-replay.json` establishes every destination field with unique tokenizer values in original x86. Clean data: **893 records, 527 distinct types**, 48 tokens per record plus the final delimiter. Only types 1415..1419 have nonzero required subprofession phase: class6, phases1/3/5/7/9, all level0. The inventory includes exact resolved text bytes for every row.

Additional live inputs are:

- Hero `+0x838`: character level, unsigned comparison against row+1C.
- Hero `+0x450`: active subprofession; `+0x454`: active phase; `+0x468/+0x46C`: packed phase value. `0x6C27CE` tests whether the required class is learned by extracting its decimal digit from this signed 64-bit packed value using `pow(10,class-1)`, conversion/division and signed remainder; it requires a nonzero class and digit >0. Invalid large class IDs are not sanitized here. Retail required class6 uses a safe, exact power of ten.
- Equipped item at slot **12** for skill type7001: item display name via `0x67DCE2`, normally item+20, or the existing role-view override name+DC when that predicate applies; item add/lineage level via `0x717847`.

Existing authoritative producer contracts are [Network/06](../Network/06_combat_packets.md) for 1103 learned type/level and 1104 action1 experience, and [Network/01](../Network/01_core_packets.md) / [Network/10](../Network/10_extended_packets.md) for character/subprofession state. The tooltip does not manufacture those gameplay values. `0x6B0AF5` updates CMagic+8; initialization is in `0x6F4CF8`. This slice does not re-research those protocols.

## 4. Exact text generation, resources and ownership

The helper measures all groups, then draws background/border, then draws the groups in this order. Color is caller white except explicit red failure/warning and the explicit white satisfied-requirement branch. Line count is **content/metric dependent**, not a fixed number of lines.

| Order | Text and branch | Native evidence |
|---|---|---|
| 1 | `MagicEffect` **Name**, kind3 | `0x5DA81D..0x5DA84D`, `0x6F4D41 →0x69D515` |
| 2 | level0: StrRes11038 `Level: Elementary`; otherwise StrRes11039 `Level: %u` with row+18 | Level formatting after `0x5DA8A1` |
| 3 | Optional subprofession requirement, below | `0x5DA9DB` onward; helpers6C27CE/6C209F |
| 4 | Type7001: dynamic mount description; otherwise **DescEx**, kind1 | Measurement and drawing branches; draw `0x5DB2D5..0x5DB31F`, mount7177A3 |
| 5 | Fixed/level requirement/EXP text, below | `0x5DAE28..0x5DAF0F` and following formatting |
| 6 | Optional red dance warning, below | helper667676, learned lookup repeated before drawing at5DB395..5DB3EE |

Numeric strings, key strings, byte encodings and source line numbers are in `localization.json`; `magic-hint-content.json` resolves Name/DescEx/Desc for all clean records. CP936 text in JSON is a reading aid; `encoded_hex` is authoritative. These are ANSI byte strings, not an instruction to replace native encoding/metrics with Unicode defaults.

Subprofession text exists only if unsigned row+30 >0. Look up class `row+34 %1000` through `0x6C209F` and obtain the record's **title** char vector at +44, read from `ini/SubProfessionInfo.ini` by `0x6C17FD`. Missing class record leaves the requirement buffer empty. The class6 base title is `Performer`, not a level-specific `P<n> Performer` row. With `P=requiredPhase`, `T=title`, `N=magicName`:

- Learned class, active class matches, **signed** activePhase >= requiredPhase: `STR_MAGIC_REQ_SUBPRO_ACCORD` = `Requires: P%d %s`, args P,T, white `FFFFFFFF`.
- Learned/active class matches but insufficient phase: `STR_MAGIC_REQ_SUBPRO_UNACCORD_STEP` = `Requires: P%d %s(Only P%d %s can use %s)`, args P,T,P,T,N, red `FFFF0000`.
- Otherwise: `STR_MAGIC_SUBPRO_UNACCORD_SWITCH` = `Requires: P%d %s(Switch to P%d %s to use %s)`, same args and red.

Requirement formatting uses `_snprintf` count511 into a 512-byte buffer and explicit final NUL. Level/progress/warnings use count255 and a final NUL in a 256-byte buffer.

For **type7001** (`0x1B59`), `0x7177A3` gets equipped slot12. Missing item selects `STR_MOUNT_MAGIC_TIP_NO_EQUITMENT`: bytes decode as `Unequipped。` (the final two native bytes are `A1 A3`). Present item formats `STR_MOUNT_MAGIC_TIP` with name and add level:

```
Steed: %s, Lineage Level: %d.\nRight click to mount your steed, which costs 20 Stamina. When riding a steed, press ALT + Left Click to attack and press CTRL + Left Click to jump. You can mount your steed in the main cities when your Lineage Level reaches 4, and in the Market at Level 6.
```

The **formatted result is truncated to255 bytes before** `0x76A7E1` translates literal `\t` and `\n` into TAB/LF (copy limit1023). Both item and no-item paths call this conversion. Do not render the entire template untruncated merely because it is present in the file.

Progress group priority:

1. Required experience==0: StrRes11040 `Fixed`.
2. Otherwise unsigned required character level > hero level: kind0 **Desc**, used as the `_snprintf` format with no extra formatting arguments. Clean resolved Desc values contain no percent signs. Modified malformed format strings do not have a safe native formatting contract.
3. Otherwise StrRes10019 **`EXP: %0.3f%% `**, including its trailing space. The argument is `double(float32(uint32(currentExp)*100.0) / uint32(requiredExp))`: native x87 stores the multiplication as float32 before division, then passes a double. There is no 100% clamp. `contract-replay.json` checks zero/partial/full/over-full and high-DWORD cases against original instructions.

Dance classifier `0x667676` accepts types1380,1385,1390,1395,1400,1405 and1410..1423. Missing learned magic selects `STR_NOTSTUDY_DANCE` = ``You haven`t learned a dance skill.``. Otherwise active subprofession !=6 and signed type in1415..1419 selects `STR_NOT_COOL_DANCE_STATE` = `Usable only as a Performer.`. Red `FFFF0000`. The missing-learned warning cannot occur in a stable category-9 call that just found the same learned magic; the shared helper is also used by category0x38 with a synthetic magic. That wider caller does not turn the warning into a required ordinary quickbar9 case. Native repeats the dance check during draw; live state is not captured as an atomic snapshot.

### Static text lookup and failure

Numeric StrRes lookups retain the existing GraphicData contract: vtable+3C `0x1000A030` delegates to `0x1002C030`. Missing IDs return the shared `SE:%u` fallback buffer; an existing null string pointer returns empty. Thus missing numeric localization does not automatically suppress category9. These original captures are reused from GFX-UI-001. Keyed Cn_Res misses instead return empty, as documented below.

`0x6F4D41` forwards type/level/kind to `0x69D515`. For relevant kinds0/1/3, resolve `ini/MagicEffect.ini` keys Desc/DescEx/Name. Base section is decimal **signed low32(type×10)**. If unsigned level>0, try decimal signed low32(type×10+level) with the base result as default. **An absent OR empty override falls back** (`0x76FA38`). Sections/keys are case-insensitive (`0x76F640`). Cache key is signed decimal low32(type×10+level) concatenated with the key string, held by manager+1C. Results are copied to caller-owned char vectors. Retail English replaces `~` with space. It does not run the mount `\n` escape conversion on these values.

The underlying store (`0x66E514 →0x66E27D →0x76F83D →0x76EF0E`) uses loose `fopen(path,"r")`, not WDF resolution. `0x76EDF5` strips leading value spaces/tabs and ends a value at TAB, semicolon, CR or LF; trailing spaces otherwise survive. Missing file/section/key resolves the passed default, empty for the base relevant keys. Name/description can therefore be empty while the remaining groups still render. Empty groups contribute no wrapper lines. The original record is not rejected merely because Name is empty.

`CStringManager` (`0x76B49E/0x76B463/0x76B745`) uses `ini/info.ini [Language] StringFile` when no explicit file path is given. Retail value `ini\cn_Res.ini` resolves to the loose file `ini/Cn_Res.ini`. Its parser `0x76B56B` strips line endings but does not expand escape sequences. Missing key (`0x76B711`) logs and returns an empty string. `SubProfessionInfo.ini` is also a loose file (`0x6C22B1`); title parsing applies `0x76A7E1`.

Ownership: helper releases the by-value magic shared reference on all ordinary exits; temporary string vectors, wrapped-line vectors and temporary shared references are destroyed. ANI from GameDataSet is a borrowed cached resource; this helper does not free it. `0x5DB43C` returns no application success result. Its later FontInfo failure can skip a group without advancing Y. Allocation faults/invalid pointers are not converted into a documented successful no-draw outcome.

## 5. Measurement, wrapping, geometry and rendering

`0x76938E` receives `(text,face,12,180,outLines,language,32,1,0)` for the normal call. The nominal180 limit derives from `IMUL; CDQ; SUB; SAR` at `0x5DA7D7..0x5DA7E8`: signed division by2 of the **low32** product maxChars×fontHeight, truncating toward zero. The original language virtual is resolved: GraphicData vtable `0x10030190 +0x34` → `0x1001DC00`, returning literal **English** at `0x10034910`.

The entire English specialization is in `english_wrap_reference.py` and independently compared against original x86 by `verify_wrap_reference.py`. Its native measurement callback remains an explicit input. Important verified details:

- Null/empty input, null output or zero pixel limit returns no lines. If no LF and measured width is strictly below limit, it takes the single-line fast path.
- Otherwise effective limit is at least `2*globalFontWidth+1`. A prefix only overflows when its measured width is **greater than** the effective limit.
- Backward space search preserves the break-space as the first byte of the next line. The loop's counter/advance behavior is significant: with synthetic6-pixel metrics, 61 unbroken `a` bytes yield lengths30 and31, not30/30/1.
- Lone LF stays inside a stored line; terminal CRLF is removed. A trailing LF can create a final empty line. For example `abc\n` produces `["abc\n", ""]`.
- DBCS boundary helper `0x76A246` uses KERNEL32 `IsDBCSLeadByte` classification (IAT `0x844114`), but the wrapper only acts on that result for Chinese/Japanese/Big5 language labels (`0x7694E3..0x769519`, `0x7696E1..0x769723`). **English always takes the bytewise branch**, including for non-ASCII bytes. Argument8=1 controls the DBCS split-side choice only in those other-language branches; it changes nothing in this English call. The metric/rendering backend still interprets encoded text using its codepage inputs.

Measurement in `0x5DA7AA` **always** wraps each group. For every 12-byte string-vector entry, it calls `CalcuTextExtentCommon(text,face,height,GameDataSet+5C(0),0x15)` and keeps the maximum width. `0x15` is the data-icon width override21; it is not a wrap flag. The wrapper's own measurement uses no icon provider. The group-measurement height is ignored. Empty trailing vector entries still increase line count. There are no blank separator rows inserted between groups.

Let `N` be total measured wrapper entries and `M` their maximum measured width. For the normal call:

```
width  = M + 10
height = N*12 + 10
panelX = (signed32(anchorX + width + 2) <= screenWidth)
         ? anchorX : low32(screenWidth - 2 - width)
panelY = signed32(inputY - height) < 0 ? 0 : low32(inputY-height)
textY  = panelY + 5
textX  = alternate ? panelX + width - 5 : panelX + 5
```

`inputY=H-43`, so ordinary panels extend upward from the quickbar at y557/725. Formula operations use original32-bit arithmetic; the Y decision is `SUB; JS` on the resulting sign. There is no bottom-screen clamp and no left clamp for an over-wide panel; a negative panelX is possible. `0x96AB30 !=0` selects the alternate text anchor and does not change the panel geometry. It is distinct from any independently maintained graphic-DLL text-direction flag. The generic helper uses its actual four padding arguments; 5 is a caller value, not an internal invariant.

Art lookup: `GameDataSet+0x10("ani/Control.ani","Dialog21",1,30000)`. If non-null, draw **frame0**, source RECT `(0,0,100,200)`, destination `(panelX,panelY,width,height)`, color0, mode0; then draw outline `CMyBitmap::ShowRect(panelX,panelY,panelX+width,panelY+height,0xFFCCCCCC)`. The original source is a256×256 DXT3 texture, not a100×200 image. Missing Dialog21 (`0x5DB1E5 →0x5DB22D`) skips **both** backdrop and outline but continues text. No new skill image is requested here.

`graphic.dll!0x10013A10` proves ShowRect's third/fourth parameters are **right and bottom endpoints**. It supplies eight XYZRHW/color vertices to ShowLine: (L,T)→(L,B)→(R,B)→(R,T)→(L,T), as four independent line segments. ShowLine `0x10013960` uses FVF0x44, stride20 and primitive type2/line-list, count4. This is a native line outline, not evidence that four arbitrary filled rectangles have identical raster coverage. Backdrop blending/sampling/clipping follows the already-established CAniX draw path; this helper adds no scissor rectangle. Offscreen primitive clipping is renderer behavior, not text wrapping.

Drawing uses `0x5DB43C` with `(text,x,&y,30,face,12,color)`, RET1C. Empty text or signed maxChars>=256 returns without drawing/advancing. If byte strlen<=30 it normalizes through `0x76A89F` (copy at most1023, replace tilde except Big5), draws **once**, then adds12 to external Y. If longer, it wraps as above and draws/advances once per returned entry. **Measurement and drawing therefore differ for short embedded newlines.** ShowString's internal newline step at font12 is15, while this helper's external advance remains12. Do not substitute a standard text-layout engine and assume identical height.

Font face is FontInfo+10D; size is fixed **12** for learned magic, even if configured normal text size differs. AA=FontInfo+8, style=+4, corner ARGB=+214 and corner offset=(+218,+21C) are forwarded. Clean `Font.ini` is `Arial 12`; absent optional FontSetting/CodePage files retain the existing shared defaults (AA0, style0, corner0, offset1,1). Normal non-AA glyph drawing forces opaque alpha. The existing [graphic font contract](graphic_dll/04_fonts_and_text.md) supplies the shared platform/encoding behavior. Measurement uses actual native glyph metrics, not `strlen*6`; six-pixel metrics in replay files are explicitly synthetic test inputs.

## 6. Zero-ID conditional shell state: CDlgXp, dialog189

`0x4B5654/0x4B565E` constructs `CDlgXp` at `CDlgMain+0x8EDBC`, hence **shell+0x8FD54**; constructor `0x574B86`, template ID189 (`0xBD`), native debug file `DlgXp.cpp`. The queried fields belong to this child dialog, not to the status panel. They initialize to zero. Raw displacement census and bounded owner-method scans are archived separately; absence of a literal displacement alone is not used as proof of no alias writes.

| Shell / CDlgXp field | Width, effect | Proven producer/clear functions |
|---|---|---|
| `+8FE54 / +100` | byte mode; value2 takes Settle path | ctor574B86; set576830; clears5753BF/575962 |
| `+8FE58 / +104` | DWORD revive affordance (`m_bDie`) | set576B48; clear576C65 (both in `CDlgXp_SetReborn` `0x576B29`); shell external clear5CD511. Buttons: [death/ghost/revive](../Server/death-ghost-revive-5517.md) |
| `+8FE5C / +108` | DWORD restore-appearance affordance | set576997; clear5769EE; click575905 clears after hero6F7BCC |
| `+8FE60 / +10C` | DWORD descend affordance | set576A95; clear576B17; click calls6614BF |
| `+8FE64 / +110` | DWORD tryout affordance | set576C97; clear576D19/576D2B |

Priority below is exact and applies **only when skillID==0**. Let A=(storedAnchorX,storedAnchorY), W=screen width, (w,h)=measured string extent. These branches use configured normal font height, white color and the common style settings, not the learned helper's fixed12/padding. They do not draw its border.

1. **Revive** (`0x5B9E86`): X>=W-50 selects StrRes10486 `Revive Here`, else10355 `Revive`. Null returned string exits. Fits=(A.x+w<=W). Backdrop X=fits?A.x-3:W-3-w, Y=A.y-60, extent(w,h). Normal textX=backdropX; alternate textX=fits?A.x+w-3:W-3. Missing Dialog21 still allows text.
2. **Mode byte==2** (`0x5BA016`): Dialog21 is required. If restore flag also set and A.x==**750**, choose10379 `Restore Appearance` and draw text at A.x **even in alternate mode**. Otherwise10357 `Settle`; backdropX=A.x, textX=normal A.x / alternate A.x+w. Y=A.y-60. The750 constant does not scale with resolution.
3. **Restore appearance** (`0x5BA231`):10379, required art; backdropX=A.x-4, textX=normal A.x / alternate A.x+w, Y=A.y-60.
4. **Descend** (`0x5BA362`):10396 `Descend`, required art; backdropX=A.x, textX=normal A.x / alternate A.x+w, Y=A.y-60.
5. **Tryout** (`0x5BA481`): required art and retained WrapShop item from manager `0x9560A0` via `0x6D3A99` (+50/+54 shared pair). Null item exits with cleanup. Format `STR_WRAPSHOP_TRY_TIP` = `You are trying on %s\nRemaining Time: %d s`, item display name and seconds; replace literal `\n` with LF. `0x6D3A1E` returns0 if IsTryWrap6D3AC1 false (logs) or timer+58 virtual+8 reports expiry; else unsigned32(manager+60+manager+5C-timeGetTime())/1000. Normal X is A.x unless A.x+w>=W, then W-w. Alternate backdropX=A.x and textX=A.x+w, without that clamp. Then add global `0x958098` to X and `0x958084` to Y. `0x5AC8CA/0x5AC98F` load `[TryWrapTip] OffsetX/OffsetY`, default0; clean values **-5/-75**. TimeOffsetX/Y and FontSize in the same section are not read by this category-9 branch.
6. No flags: run learned lookup with type0; clean table cannot normally construct that type, so it yields no hint. No fictitious generic skill name is displayed.

For the ten main-grid anchors X=90..450, the revive `X>=W-50` test is false at both supported resolutions and the mode2 `X==750` special case is unreachable. A zero-valued restored main slot can reach the five flag-selected branches, but it cannot select those two coordinate-specific alternatives. They remain part of the complete category9 renderer contract.

All these branches use the same Dialog21 frame/source crop where they draw art. A fresh valid nonzero main-quickbar skill does not require any of these flags. Faithful handling of zero-valued restored slots does require using actual current conditional state, not arbitrarily treating the ID as a real skill or assuming a particular revive/transform/tryout state.

## 7. Retail dependencies and managed integration boundary

`retail-provenance.json` pins freshly extracted bytes against the pristine archive `5517.7z` (444752639 bytes, SHA256 `e44d7a30cfdf3ad3af79ea123599ebbcfe85786493ae24a5a3a3ac2a4014c080`). The authority executable is5880840 bytes, SHA256 `b6ba5ab8573ec073ea271f57b16fa14de1c67bfb44efd5aa7cfbfc0d3b488a62`. `assets.json` preserves the reused GFX-UI-008 ANI/WDF identity and the new loose dependencies. Full hashes are not shortened there.

| Retail path/case winner | Bytes | SHA-256 | Requirement |
|---|---:|---|---|
| ini/MagicType.dat |155373|e8b9559e640c75ed61fc859743f18bd372e6c5d9051457a639cedff9ba2a6e3d|New tooltip static-data input; shared learned-magic record source.|
| ini/MagicEffect.ini |236878|092091f8ff22ce700e3fe7562a767baa51fde3516d9df635e7dfb1a60ad1ad0b|New Name/DescEx/Desc source.|
| ini/Cn_Res.ini |138697|23c23e12a954a97c202bb10cab86c6c7253c55232aa7491cdadbc52070db6026|New keyed localization, path selected by Info.ini.|
| ini/SubProfessionInfo.ini |26293|a5bf8d02082f429f082c4b3ac2614b292f8eb0f2493118b07c1b16eb9152c63e|Conditional requirement title.|
| ini/info.ini |17145|da9400900fc84898b428f302723c7949197bb1e94b00475010d72ff937e6790a|Language/StringFile; conditional TryWrapTip offsets.|
| ini/StrRes.ini |59577|efe9f5f1d3e29bb79b9970c25dcb238179e3ab6e059e94d981b37236157cd072|Existing numeric localization sufficient, including all IDs above.|
| ini/Font.ini |8|a8bc4c8523360dd55fea61a4f1c908fe1e70cce00c9962a263968765ef47e8bb|Existing shared font configuration.|

These INI/DAT readers use **LooseOnly** lookup, matching native fopen. Preserve Windows case/slash equivalence when resolving the captured spellings. No new skill DDS/ANI is used. Existing `ani/Control.Ani [Dialog21] FrameAmount=1`, Frame0=`data/main/MsgDlg.dds`, is sufficient: no loose image override, data.wdf UID87576CFA, offset23254863, size65664, SHA256 `c91b686fa8e9758dd8c8825e401503825434a0ebaca3be30e8e0263b52985719`, DXT3/256×256; decoded RGBA SHA256 `14c946e2af2f39339294b08c69357fdd59f87c1946065ee5ca84e60e489f4556`. A missing image affects art as described above, not static skill lookup. Existing category8 region files are not new category9 dependencies.

The modern checkout was read only: `/Volumes/EnderChest/Development/Repos/DotNet/Conquer/OpenConquerClient`, HEAD and exact source hashes in `managed-readonly-inventory.json`. This is distinct from the evidence repository. `10_work/OpenConquerPublic` is absent in this workspace; the established maintained evidence destination is `10_work/docs`, which is updated here.

Minimum affected existing APIs/data, without prescribing an architecture:

- `MainHudQuickbarInput.HandlePointerMoved` / `PollPointer` already expose `MainHudQuickbarHoverNotification` with Kind, SlotIndex, ContentId, ItemUid, AnchorX/Y, Context. Skill notification covers Magic and XP Magic; current anchors and empty/outside behavior already provide the native producer seam. Consume it in `ClientApplication`: current calls discard `out _`, including the post-quickbar-draw poll. Preserve command7→9 ordering and command6 clearing.
- `MainHudStatusHintState` currently only represents category8 hotspot kinds and gates `CanRender` to WalkRun..Life. Category9 requires visible/category/full-type/anchor selection alongside shared drag suppression. `MainHudStatusHintInput.Clear/Select` currently changes category8 state; integrating the shared selection must preserve actual native event ordering rather than allowing unrelated hotspot maintenance to erase a freshly selected skill by accident.
- `MainHudStatusHintRenderer.Draw` currently consumes check/vital/gauge state and configured font size. It needs actual learned magic/static record and conditional hero inputs above, per-frame text/layout regeneration when those live values change, fixed12 learned-hint metrics, exact wrapping, border and failure behavior. Same-slot hover caching does not authorize caching live EXP text indefinitely.
- `ClientStringResources.GetEncoded/TryGetEncoded` already has all StrRes IDs. Existing `FontsConfiguration`, `MainHudStatusHintAssets` and Dialog21 texture/content are sufficient. The current `MainHudStatusHintContentRequirements` does not request MagicType/MagicEffect/Cn_Res/SubProfessionInfo. Add those content/data requirements when implementing, plus the exact Info.ini keys; do not invent runtime values to populate the lines.
- `OpenGLTextContext.Layout(encodedText,recognizeDataIcons,dataIconWidthPixels)` and Draw provide the existing metric/draw seam. Category9 needs the native distinction between wrapper metrics, icon-width21 group measurement and ordinary ShowString drawing. `OpenGLRenderer.DrawSprite` supplies the backdrop seam. The inspected renderer exposes filled rectangles but no matching endpoint-line outline API; satisfying the native four-line border and its pixel coverage is an implementation conformance requirement, not proof that a proposed replacement is equivalent.
- Optional zero-ID fallback needs actual CDlgXp mode/revive/restore/descend/tryout and WrapShop item/timer state when those game states are supported. Normal nonzero skills need none of those five flags. Mount text needs equipped slot12's real name/add level. Existing category8 gauge values are not substitutes for learned magic EXP, character level, subprofession phases or equipment data.

## 8. Verification, corrections and limits

`validation.json` records the final gate. Checks include clean-byte comparison of every archived assembly instruction, archive/clean input hashes, original-x86 category priority/ABI/lookup/layout/percentage replays (1030 cases), original record-parser field assignments and full DAT decode, and an independent English wrapper comparison (301 cases). The wrappers use explicit foreign-service mocks and synthetic metrics; they are not a captured game session. The catalog records every clean magic row's resolved encoded strings; clean Desc has no formatting directives.

Corrections applied to maintained evidence: category9 helper uses fixed12; CMagic's record is embedded; existing category0x38 weapon-swap label was wrong (0x6A is weapon-swap); category0x6A is handled; ShowRect uses endpoint coordinates. Previous notes/user changes were preserved except where these exact corrections were supported. Old raw captures retain their original comments so provenance is not silently rewritten; this contract identifies the superseding facts.

**Still not experimentally established:** a live Windows5517/GPU screenshot corpus for this complete tooltip, platform-specific installed Arial file/version and host text-codepage/rasterization inputs, and managed-renderer pixel equivalence. These are shared font/raster/platform conformance inputs, not an unresolved category-9 branch or a license to assume six-pixel glyph widths. Allocator failure and arbitrary corrupt pointers/config formats have no safe behavior promised by the native code. Non-English branches of the shared wrapper are outside clean English5517 reachability and are not represented as verified by the English reference.

**No remaining native category-9 selection/text/resource/layout gap is claimed.** All measured sizes are functions of the documented native metric input; no fixed pixel size is invented for dynamic skill text. The evidence is ready for implementation, while implementation and final native/managed pixel validation remain future work.

## HUD-010 category-0x38 reuse (2026-10-10)

[Rendering/22](22_main_hud_dance_weapon_swap_status_hint_native_contract.md) adds the synthetic-Magic caller: constructor0x6F4DB3 takes type, level and initial experience (the historical Caster suffix was wrong), with the latter two forced to0. The main quickbar type parameter is context3 and misses the clean table; the separate dance dialog posts real types. A constructed dance reuses this note's text/layout contract, with learned state consulted separately for warnings. Missing learned dance can therefore be a stable category0x38 outcome. Category9 findings and tests are reused unchanged. Rendering/22 also records a fresh read-only managed integration snapshot; section7 above remains the historical GFX-UI-009 inventory.
