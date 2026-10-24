# `graphic.dll` Import Surface (CMyBitmap API) — 5517 Client
Every symbol the 5517 client imports from `graphic.dll`, grouped by function.

Source: IDA import table (client calls into `graphic.dll` via these IAT entries).

## Device / Frame Lifecycle
- `CMyBitmap::Init3DEx(HWND, width, height, ...)` — **HWND-based** graphics initialization
- `CMyBitmap::IfDeviceLost()` — device-loss polling (observed return values include 0/1/2)
- `CMyBitmap::ResetDevice()` — device reset (called after resource invalidation)
- `CMyBitmap::Begin3D()` / `CMyBitmap::End3D()` — frame begin/end (observed used around UI/world draws)
- `CMyBitmap::Flip(const RECT* src, const RECT* dst, HWND* hwnd)` — present/swap (HWND tie-in)
- `CMyBitmap::ClearBuffer(int, int, uint32 color)` — clear (used for both full-frame and offscreen clears)

## Display / Output / Diagnostics
- `CMyBitmap::ChangeDisplayResolution(uint32 w, uint32 h)`
- `CMyBitmap::GetScreenSize(int* w, int* h)`
- `CMyBitmap::GetScreenWidth()`
- `CMyBitmap::GetScreenHeight()`
- `CMyBitmap::ScreenShot(const char* path)`
- `CMyBitmap::HintGraphicDetail(uint32 level)`

## Camera
- `CMyBitmap::GameCameraBuild(CMySize)`
- `CMyBitmap::GameCameraDestroy()`
- `CMyBitmap::GameCameraSet(float x, float y, float z, uint32 flags)`
- `CMyBitmap::GameCameraGetPos(float* x, float* y, float* z, uint32 flags)`
- `CMyBitmap::GetObliqueAngle()`

## Bitmap / Sprite / Primitive Draw
- `TargetBmpCreate(int)` / `TargetBmpCreateEx(...)` — offscreen render-target bitmap creation
- `MyBitmapCreateEx(int)` — bitmap object creation (client treats result as an object with vtable methods)
- `MultiBmpCreate(...)`
- `PrepareSprite()`
- `PrepareLine()`
- `ShowBlock(...)` (overload: by `CMyPos` + sizes; and raw coords)
- `ShowRect(int left, int top, int right, int bottom, uint32 color)` — endpoint coordinates, not width/height; native `graphic.dll!0x10013A10` emits four line-list edges through `0x10013960`. See [GFX-UI-009](21_main_hud_magic_status_hint_native_contract.md).
- `ShowLine(int x1, int y1, int x2, int y2, uint32 color)`

## Text / Font / String Metrics
- `GameFontCreate()`
- `GetDefaultFontName()`
- `GetFontSize()` (scalar) and `GetFontSize(CMySize* out)`
- `GetFontWidth(const char* text, int len)`
- `GetStrShowLen(const char* text, int maxPixels, int flags)`
- `CalcuTextExtent(...)`, `CalcuTextExtentW(...)`, `CalcuTextExtentCommon(...)`
- `CalcuCharPosInString(...)`
- `CheckStringPixels(const char* text, uint32 color, const char* font, int flags)`
- `IsDBCSLeadByte(const char* bytes, int idx)` — DBCS support (text handling parity concern)
- `ShowStringW(...)`
- `ShowStringCommon(...)`
- `ShowEmotionStringW(...)`
- `ShowEmotionStringEx(...)`
- `ShowEmotionStringCommon(...)`

## Mini-game / Puzzle Primitives (specialized)
- `PuzzelTriangleCreate(...)`
- `PuzzelBlockCreate(...)`

## Observed Call Patterns (high-level)
- Frame helpers exist in `conquer.exe` (at `0x5AD965` and `0x5AD981`) that wrap:
  - `Begin3D(); ClearBuffer(...);` then later `End3D(); Flip(...);`
- A separate "outchat/exchat" render path draws into a top/bottom split and flips with source/dest RECTs.
- Map/tile and puzzle systems sometimes call `IfDeviceLost()` before attempting offscreen rendering.

### Concrete call-sites (useful anchors)
- `Exe_BeginFrame3DAndClear` (`0x5AD965`): `Begin3D()` + `ClearBuffer(1,1,0xFF000000)` (simple begin-frame helper).
- `Exe_EndFrame3DAndPresent` (`0x5AD981`): `End3D()` + `Flip(NULL,NULL,NULL)` (simple present helper).
- `CMyShellDlg__RunFrameTick` (`0x5DCFAA`): main per-frame driver; polls `IfDeviceLost()` and calls `ResetDevice()` on state `2`
- `conquer.exe` function at `0x5DE04A`: "exchat top bar" render path; flips with explicit `RECT` + `HWND`. Not yet decompiled/renamed in IDA.
- `CGameMain__func_002` (0x66DB69): clears and draws centered string using `CalcuTextExtentCommon` + `ShowStringCommon`
