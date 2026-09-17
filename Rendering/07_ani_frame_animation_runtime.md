# `CAni` / `CAniFile` — 2D Frame Animation Runtime

**Scope:** Managed port of the native `CAni` 2D frame-animation class used by
every 2D sprite path in the EXE (hero flags, team overheads, effects, map
icons, UI buttons, cursor sets, card faces, etc.). This is the retail Conquer
animation primitive, not the skeletal system in Role3D.dll.

## Retail oracle (`40_tools/fight-master/my_client/3DBaseCode/Ani.{h,cpp}`)

Class surface (retail signatures verified):

```cpp
class CAni {
public:
    BOOL  Create(const char* pszDataFile, const char* pszIndex, BOOL bHalf, DWORD dwLoadWay);
    BOOL  Create(AniIndexInfo* pInfo);        // from parsed text index
    BOOL  Create(IFrameSet* pFrameSet);       // from DAI resolver
    BOOL  Show  (UINT uFrame, int x, int y, int alpha, DWORD dwShowWay) const;
    BOOL  ShowEx(UINT uFrame, int x, int y, RECT* lpSrc, DWORD dwWidth,
                 DWORD dwHeight, int alpha, DWORD dwShowWay);
    CMyBitmap* GetFrame(UINT uFrameIndex) const;
    CMySize    GetSize (UINT uFrame) const;
    DWORD      GetSize ()           const;   // total byte size across frames
    int        GetFrameAmount()     const;
    int        GetStatus()          const;
    void       Destroy();
private:
    CMyBitmap* m_pbmpFrame[_MAX_FRAME];      // _MAX_FRAME = 64
    int        m_iFrameAmount;
    volatile int m_nStatus;                   // ANISTATUS_{INIT, LOADED, FAILED}
    BOOL       m_bHalf;                       // even-index shares odd-index bitmap
};
```

Status enum:
- `ANISTATUS_INIT` — zeroed, no frames
- `ANISTATUS_LOADED` — `m_iFrameAmount > 0`, all frame bitmaps present
- `ANISTATUS_FAILED` — load aborted, all slots freed back to `NULL`

Half-share optimization (`m_bHalf == TRUE`):
- Frame `i` reuses pointer of frame `i-1` when `(i != 0) && (i % 2 == 0)`
- Cuts memory in half when every odd-indexed frame is a mirror of the prior even-indexed frame
- `Destroy()` only frees odd-indexed slots to avoid double-free

Return contract:
- `Show` returns `TRUE` when `uFrame + 1 >= m_iFrameAmount` → signals "this was the
  last frame" so callers can advance/loop animation state
- Both `Show` and `ShowEx` take `uFrame % m_iFrameAmount` — caller never has to clamp

## client-5517 CAni vtable (verified via BNinja decomp)

`CAni*` is obtained from the global `GameDataSetQuery()` singleton
(`CAniFileSet`-equivalent) via:

```c
CAni* pAni = GameDataSetQuery()->vtable[+0x10](
    "ani/common.ani", "PlayerFlag", /*bHalf*/1, /*ttl_ms*/0x7530);
```

`ttl_ms = 0x7530 = 30000` → 30-second cache lifetime for the resolved handle.

**CAniX vtable — base `0x1003994C`, verified**

The base is proven, not inferred: `AniCreate` stores `0x1003994C` into the object at
`0x1000C016`, and `CAniX_DeletingDestructor` restores it at `0x1000DDE3`.

| Offset | Target | Notes |
|---:|---|---|
| `+0x00` | `CAniX_ReleaseInstance` | |
| `+0x04` | `CAniX_CreateFromDataAndIndexPath` | |
| `+0x08` | `CAniX_DrawFrameAt` | |
| `+0x0C` | `CAniX_DrawFrameSubRectAt` | forwards to the frame's `+0x08` |
| `+0x10` | `CAniX_GetFrameAt` | |
| `+0x14` | `0x10007140` | not yet named |
| `+0x18` | `CAniX_GetFrameDimensionsAt` | the `GetSize` used by `#NN` measurement |
| `+0x1C` | `CAniX_GetTotalFrameDuration` | |
| `+0x20` | `CAniX_DrawFrameLinearAt` | |
| `+0x24` | `CAniX_DeletingDestructor` | |

`CAniX_DrawFrameSubRectAt` wraps the frame index with an **unsigned** modulo of the frame count
at `this+4`, returns `0` when that count is `<= 0`, and returns an **end-of-animation flag** —
`0` while frames remain, `1` when the drawn frame was the last — rather than a success code.

**`CMyBitmapSpriteFrame` vtable — base `0x10039A34`** (installed by
`CMyBitmapSpriteFrame_Initialize`). Slot `+0x08` is `CMyBitmapSpriteFrame_DrawSubRectAt`
(`0x10012190`), `__thiscall` with `retn 0x20`, i.e. eight stack parameters. Positions were
verified by tracking each stack read against its push depth and cross-checking the demangled
callee prototype `?Sprite_SetCoor@@YAXPAUC3Sprite@@PAUtagRECT@@HHKK@Z`:

| # | Parameter | Use |
|---:|---|---|
| 1 | `screenX` | |
| 2 | `screenY` | |
| 3 | `sourceRect` | **`tagRECT*`**, not a scalar source X |
| 4 | `widthPixels` | destination width |
| 5 | `heightPixels` | destination height |
| 6 | `colorParameter` | `Sprite_SetColor(sprite, value, 0xFF, 0xFF, 0xFF)` when non-zero |
| 7 | `drawParameter` | `Sprite_Draw(sprite, value)` |
| 8 | `rotationParameter` | Signed integer degrees; `Sprite_Rotate(sprite, value)` when the original argument is non-zero |

Full `CMyBitmapSpriteFrame` slot map read from the vtable at `0x10039A34`:

The rotation unit, pivot, mutation, CPU-specific arithmetic and complete caller
ordering are now verified in
[the native Sprite_Rotate contract](c3_core_dll/18_sprite_rotate_native_contract.md).
`Sprite_SetCoor` runs before rotation on every draw, so these frame calls do not
accumulate prior rotated geometry. Original angle 0 skips rotation; 360 still calls it.

| Offset | Target | Name |
|---:|---:|---|
| `+0x00` | `0x10012DD0` | not yet named |
| `+0x04` | `0x10012120` | `CMyBitmapSpriteFrame_DrawAt` |
| `+0x08` | `0x10012190` | `CMyBitmapSpriteFrame_DrawSubRectAt` |
| `+0x0C` | `0x100122C0` | `CMyBitmapSpriteFrame_DrawExSubRectAt` |
| `+0x10` | `0x10012550` | not yet named |
| `+0x14` | `0x10012520` | `CMyBitmapSpriteFrame_GetDimensions` |
| `+0x18` | `0x10012560` | `CMyBitmapSpriteFrame_GetFrameWidth` |
| `+0x1C` | `0x10012570` | `CMyBitmapSpriteFrame_GetFrameHeight` |
| `+0x20` | `0x100125D0` | `CMyBitmapSpriteFrame_SetColorArgbBytes` |
| `+0x24` | `0x10012600` | not yet named |

This supersedes and agrees with the earlier `CMyBitmap` slot listing for `+0x14`, `+0x18` and
`+0x1C`; only the `+0x08` parameter naming was wrong.

When `sourceRect`, `widthPixels` and `heightPixels` are all zero the frame is drawn whole;
otherwise the source region is stretched to the destination size. Both branches compare
`g_CurrentGraphicsPipelinePrepareMode` against sprite mode `1` and call `CMyBitmap::PrepareSprite`
when it differs.

> **Superseded reading.** An earlier revision of this note recorded `+0x0C` as
> `ShowEx(frame, x, y, srcX, w, h, alpha, way)` and the frame slot as
> `ShowEx(x, y, srcX, w, h, srcAlpha, alpha, way)`, both read from 8-integer call sites without
> decompiling the targets. Parameter 3 is a `tagRECT*`, and parameters 7/8 are the draw and
> rotation parameters in that order. The table above is the verified form.

**Confirmed usage.** `CMyShellDlg__RenderStatusHintPanel` draws the `Control.ani` `Dialog21`
backdrop as `(frame 0, x, y, &RECT{0,0,0x64,0xC8}, measuredWidth, measuredHeight, 0, 0)`, so a
100x200 source region is stretched to the measured text extent.

## Managed port seams (`Conquer.Assets.Ani`)

Leaf interfaces — DI boundaries around parts we don't own yet:

```csharp
// Handle to one loaded frame bitmap. Implementation wraps the platform
// blit target (DirectDraw surface in retail / texture in managed reboot).
internal interface IAniFrameBitmap
{
    int Width  { get; }
    int Height { get; }
    void Show  (int x, int y, int alpha, uint showWay);
    void ShowEx(int x, int y, int srcX, int srcY, int width, int height,
                int alpha, uint showWay);
}

// Resolves a frame texture path (from AniIndexSection.FramePaths) into a
// live IAniFrameBitmap. Retail equivalent: CMyBitmap::Load(pszFile).
internal interface IAniFrameBitmapLoader
{
    IAniFrameBitmap? Load(string framePath);
}
```

Concrete managed `CAni`:

```csharp
internal sealed class CAni
{
    // Native: layer+0x00..+0xff (m_pbmpFrame[64])
    private readonly IAniFrameBitmap?[] _frames = new IAniFrameBitmap?[MaxFrames];

    // Native constants
    public  const int MaxFrames = 64;       // retail _MAX_FRAME

    // Native: +0x100 m_iFrameAmount, +0x104 m_nStatus, +0x108 m_bHalf
    private int _frameAmount;
    private AniStatus _status = AniStatus.Init;
    private bool _halfShare;

    public AniStatus Status        => _status;
    public int       FrameAmount   => _frameAmount;
    public bool      HalfShareEnabled => _halfShare;

    // Mirrors CAni::Create(AniIndexInfo*) — uses already-parsed section plus
    // injected loader to materialise each frame bitmap.
    public bool Create(AniIndexSection section, IAniFrameBitmapLoader loader, bool halfShare) { ... }

    // Mirrors CAni::Show — returns true when last frame rendered.
    public bool Show(uint frame, int x, int y, int alpha, uint showWay) { ... }

    // Mirrors CAni::ShowEx.
    public bool ShowEx(uint frame, int x, int y, int srcX, int srcY,
                       int width, int height, int alpha, uint showWay) { ... }

    // Mirrors CAni::GetFrame — modulo frame, status guard.
    public IAniFrameBitmap? GetFrame(uint frame) { ... }

    // Mirrors CAni::GetSize(UINT).
    public (int Width, int Height) GetSize(uint frame) { ... }

    public void Destroy() { ... }
}

public enum AniStatus
{
    Init   = 0,
    Loaded = 1,
    Failed = 2,
}
```

### Half-share invariants (tested)

- `Create` with `halfShare = true` populates even-index slots (`i > 0`, `i % 2 == 0`)
  with the *same reference* as slot `i-1`.
- `Destroy` with `halfShare = true` nulls even-index slots without calling
  dispose on them; dispose only fires for odd-index + slot 0.
- Even when `halfShare = false`, `Destroy` nulls every slot and disposes each.

### Failure rollback

- If any frame load fails mid-`Create`, every slot allocated so far is
  released, `_frameAmount = 0`, and `_status = Failed`. No partial state.

### Status guards

- `Show`, `ShowEx`, `GetFrame`, `GetSize` all early-return default/false when
  `Status != Loaded || FrameAmount <= 0`.

## Call-site inventory (client-5517)

Verified via BNinja xrefs to string literals `ani/*.ani`:

| .ani file | Section samples | Caller (renamed) |
|---|---|---|
| `ani/common.ani` | `PlayerFlag`, `TeamLeader`, `Friend`, `Tutor`, `Student` | `Role_RenderRelationshipFlagAniOverheadOverlay` |
| `ani/Control.ani` | `Card_BG` | `CShowHandCardDlg_RenderCardFaceAndButtons` |
| `ani/Card.Ani` | card-face index | `CShowHandCardDlg_RenderCardFaceAndButtons` |
| `ani/effect.ani` | per-effect name from entity `+4` | `Role_DrawAttachedEffectAniOverlay` |
| `ani/MiniMap.ani` | various | `CMiniMap_*` callers (see xrefs to `0x869f68`) |
| `ani/weather.ani` | weather-effect frames | `sub_73a3ec` etc. |
| `ani/EmotionIco.ani` | chat bubble icons | `CMyShellDlg__RenderStatusHintPanel` |
| `Data/Cursor/*.ani` | mouse cursor states | cursor HUD callers |

## What this port does **not** cover yet

- `IFrameSet` / DAI cache layer (`CAniFileSet::Locate`, `String2ID`, TTL = 0x7530).
  That's the CAniFile*Set* singleton wrapping many CAni instances keyed by
  `(file, index)`. Phase A ships CAni only; the DAI cache lands in a follow-up
  slice once we need cross-section lookup.
- Encrypted .ani binary format (retail `ANIFILE_FLAG = 0x8888`).
  Current managed reboot uses **text** index files only — matching the
  `Create(AniIndexInfo*)` overload, not `Create(pszDataFile, pszIndex)`.
- `CMyBitmap` concrete implementation. `IAniFrameBitmap` is the seam;
  managed bitmap wrapping lives in the graphic-dll port.

## Cross-refs

- **Retail source:** `40_tools/fight-master/my_client/3DBaseCode/Ani.{h,cpp}`
  — complete header + `.cpp` through line 508 (plus CDynamicAni, CAniFile,
  CAniFileSet tails).
- **Existing managed state:** `10_work/src/Conquer.Assets/Ani/AniIndexFile.cs`
  (text parser — already handles `[Section]`, `FrameAmount=N`, `FrameN=path`
  lines with native signed-clamp quirk).
- **ConquerMono reconstruction:** `40_tools/ConquerMono/*` does not include a
  CAni port; the managed reboot skipped retail's 64-frame animation primitive
  entirely. Our port is the first.
- **Native vtable evidence:** BNinja database
  `00_clean/clean/5517-bninja/Conquer.exe.bndb` — see renamed symbols
  `Role_RenderRelationshipFlagAniOverheadOverlay` (`0x626d8a`),
  `CShowHandCardDlg_RenderCardFaceAndButtons` (`0x430936`),
  `Role_DrawAttachedEffectAniOverlay` (`0x71e96d`).
