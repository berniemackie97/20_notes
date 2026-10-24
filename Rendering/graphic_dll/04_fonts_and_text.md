# `graphic.dll` — Fonts and text rendering

The verified clean v5517 native contract between `graphic.dll`,
`C3_CORE_DLL.dll`, and the Conquer executable. Addresses are from
`00_clean/clean/5517-bninja/graphic.dll.bndb` unless stated otherwise.

## Persistent Binary Ninja model

- `GraphicFontRecord` is `0x10C` bytes:
  - `+0x000` requested nominal pixel height
  - `+0x004` requested face/path bytes (`char[256]`)
  - `+0x104` four reserved bytes
  - `+0x108` `C3Font*`
- `g_ArabicClientTextLayoutEnabled` is `0x1004ACF1`.
- `g_FontBatchOwnedByCaller` is `0x1004AD28`.
- `g_FontRecordCount` is `0x1004AD24`.
- `FontCache_GetOrCreateFontRecord` is `0x10014700`.
- `FontCache_CreateFontRecord` is `0x10014B70`.

The type, symbols, signatures, parameter names, and evidence comments above were
re-read from the selected database after writing them.

## Startup configuration

`CMyBitmap::GameFontCreate` (`0x10014C50`) reads at most `0x100` bytes from
`ini/font.ini`, splits the last ASCII space, and treats the suffix as the nominal
height. An invalid height becomes `12`.

A face token matching `$*.tt?` has the `$` removed and is expanded beneath the
Windows Fonts directory. The initial record is requested with antialiasing off.

`ini/CodePage.ini` supplies the client code page on its first line and optional
font-size levels on later lines. When no size levels are supplied, the defaults
are `16`, `32`, `64`, and `128`.

## Client code page

`g_nLocaleCodePage` is `C3_CORE_DLL.dll` data at `0x100B01D8`, imported by
`graphic.dll` through the slot at `0x10039034`. C3_CORE contains only reads of it
(`Font_CheckPixel`, `Font_RasterizeAndCacheGlyph`, `Font_GetStrShowLen`,
`Font_Draw`); `graphic.dll` reads it in `IsDBCSLeadByte`, `CheckStringPixels`,
`GetStrShowLen`, `ShowString`, `ShowStringEx`, `CalcuTextExtent`,
`ShowEmotionString`, and `ShowEmotionStringEx`.

Its only writer in either module is `CMyBitmap::GameFontCreate` at `0x10014F3B`:
`*g_nLocaleCodePage = atoi(CodePage.ini line 1)`. When `ini/CodePage.ini` is
absent, the `fopen` failure path jumps directly to the default
`Font_AddFontSizeLevel(0x10/0x20/0x40/0x80)` levels and returns `1` without
writing the global, which therefore keeps its image value `0`.

The clean v5517 asset set ships no `ini/CodePage.ini` in any casing, so the
global stays `0` — `CP_ACP` — and every `IsDBCSLeadByteEx` and
`MultiByteToWideChar` call in the text path resolves against the host ANSI code
page. DBCS behaviour in the original client was therefore a property of the
Windows install, not of any shipped asset.

Decoding the shipped `.dat` corpus with the verified seed `0x2537` settles which
code page the data was authored in. In `ini/ItemType.dat` (3,634,428 bytes) all
78 high bytes form 39 well-formed CP936 pairs with zero orphans; `MountType.dat`
gives 8 pairs from 16 high bytes, also with no orphans. Decoded as GBK the text
is coherent Chinese (`毒囊`; mount comments `//白马`, `//赤兔`, `//绝影`,
`//的卢`), and as Latin-1 it is mojibake. The corpus is CP936.

A cross-platform reconstruction has no host ANSI code page, so `CP_ACP` must be
pinned explicitly. The managed client keeps the settable native contract —
`CodePage.ini` line 1 when present — and resolves the absent-file default to
`936`. This is the one place the text path deliberately departs from a literal
reading of the native default, and it is recorded here because the native value
`0` is not representable off Windows.

The clean asset set contains `ini/Font.ini` with exactly `Arial 12` and no
`CodePage.ini`, `FontSetting.ini`, or bundled font file. Filename case differs
from the Windows spelling and therefore requires the reconstruction's existing
case-insensitive client-path resolution on case-sensitive hosts.

## Cache lookup and fallback

`FontCache_GetOrCreateFontRecord` matches all of the following:

- exact requested nominal height;
- case-sensitive requested face/path bytes;
- `C3Font.antialiasEnabled`.

The final Boolean is antialiasing, not a generic TrueType flag. An empty/null
face selects the cached default. On a miss, creation is attempted with the
requested face, then with these native Windows fallbacks in order:

1. the face returned by `GetStockObject(DEFAULT_GUI_FONT)`;
2. `%WINDIR%\\Fonts\\simsun.ttc`;
3. `%WINDIR%\\Fonts\\simsun.ttf`;
4. `Courier New`.

`FontCache_CreateFontRecord` allocates `0x10C`, calls `Font_Create`, then records
the exact requested height/name only after creation succeeds. Failure releases
the font and allocation and returns null.

## Active clean-client draw path

Clean `Conquer.exe` does not import the Arabic-client setter, and
`g_ArabicClientTextLayoutEnabled` initializes to zero. Consequently:

- `CMyBitmap::ShowStringCommon` (`0x100178E0`) forwards to
  `CMyBitmap::ShowStringEx` (`0x10015710`);
- `CMyBitmap::CalcuTextExtentCommon` (`0x10017160`) forwards to
  `CMyBitmap::CalcuTextExtent` (`0x10015980`).

`ShowStringEx`:

- returns `{0,0}` for null text;
- enters shared graphics prepare mode `9`, calling `Font_Prepare` only when the
  current mode differs;
- forces both text and corner alpha to `0xFF` when antialiasing is off;
- begins a font batch and ends it unless `g_FontBatchOwnedByCaller` is set;
- walks one- or two-byte characters according to the client code page;
- retries a missing glyph (`0xFFFF0000`) through font-record index 0, the default
  record created by `GameFontCreate`;
- skips the retry when that record is already the primary, and otherwise advances
  by the primary `C3Font.lineHeightPixels` if the retry still fails;
- resets X on newline and advances Y by
  `nominalPixelHeight + nominalPixelHeight / 4`;
- returns maximum line width and total newline advance plus nominal height.

`CalcuTextExtent` uses the same character, fallback, missing-glyph, newline, and
return-size rules without emitting vertices.

Its `#NN` data-icon branch is taken only when the caller supplies a non-null
`IDataIcon`, the current byte is `'#'` (`0x23`), at least two bytes remain, and
both following bytes are ASCII digits (`0x30`–`0x39`). It then `strncpy`s those
two digits, `atoi`s them, and resolves the icon through `IDataIcon` vtable slot
`0`. On a hit, the width comes from vtable `+0x18`; when the lookup fails or
reports width `0`, the run advances by the fallback `0x10` pixels. The cursor
advances three bytes in total (two in the branch plus the shared trailing
increment). A caller-supplied non-zero icon width parameter short-circuits the
lookup and is used directly.

## Clean Conquer floating-text consumer

`Conquer.exe` `CGameMap_RenderQueuedFloatingTextEntries` (`0x620D2A`) uses:

- `CFontSettingInfo.guiFontFaceName` at byte offset `+0x10D`;
- `ClientFontSizeSettings.normalFontHeightPixels` at `+0x08`;
- `CFontSettingInfo.antialiasEnabled` at `+0x08`;
- settings style/corner/offset when the entry style is zero;
- the entry's style/corner/offset when its style is nonzero.

Clean `Font.ini` plus `info.ini` therefore resolve the default floating-text path
to `Arial`, height `12`, antialias off, style `0`, raw corner color `0`, and
corner offset `(1,1)`. `ShowStringEx` makes both colors opaque because
antialiasing is off.

## Remaining uncertainty

The embedded rasterizer API is FreeType-shaped, but no trustworthy version
string identifies the exact retail FreeType revision. The surrounding cache,
measurement, atlas, style, and draw-state algorithms are verified. A managed
backend must keep rasterizer/version output as an explicit conformance seam and
must not claim pixel identity from a self-generated golden.


## Auth string-validation evidence delta — 2026-10-18

The [auth string evidence](../../Network/Native-auth-string-validation-2026-10-18.md)
connects1006/2078 byte storage to this existing font contract and records the
flags0 one-/two-byte conversion anchors. MsgTalk1004 additionally has a
conditional system-ACP filter independent of the font code-page override;
a font override is not a universal network decoding selector.
