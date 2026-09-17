# `CAlphaMask` — 1-bit-per-pixel sprite hit-test

**Scope:** Managed port of the native `CAlphaMask` 1-bit-per-pixel hit-mask used to
test whether a screen-space click lands on the opaque region of a sprite. This is
the retail Conquer hit-test primitive — distinct from the byte-per-pixel SWF
alpha rasterization in `Conquer.Assets.Startup` and from the GPU-side projective
shadow map in Role3D.dll's `3TechnicProcessorX.cpp`.

---

## Retail oracle (`40_tools/fight-master/my_client/3DBaseCode/AlphaMask.{h,cpp}`)

Class surface (retail signatures, complete):

```cpp
class CAlphaMask {
public:
    CAlphaMask();
    virtual ~CAlphaMask();

    BOOL IsTransparent(CMyPos posPoint);
    BOOL Load(CMySize sizeBmp, char* pszFileName);
    BOOL Load(CMySize sizeBmp, void* pMaskData);

private:
    BYTE*   m_pBuffer;
    CMySize m_sizeInfo;

    BOOL CreateBuffer();
};
```

Buffer rule:

```cpp
int nBufferSize = (m_sizeInfo.iWidth * m_sizeInfo.iHeight) / 8 + 1;
m_pBuffer = new BYTE[nBufferSize];
```

`IsTransparent(x, y)` (lines 42-63):

```cpp
if (x<0 || y<0 || x>=width || y>=height) return TRUE;
int  nIndex      = x + y * width;
int  nByteOffset = nIndex / 8;
int  nBitOffset  = nIndex % 8;
BYTE bMask       = 1 << nBitOffset;        // LSB-first within byte
if (bMask & m_pBuffer[nByteOffset]) return FALSE;  // bit set ⇒ opaque
return TRUE;                                       // bit clear ⇒ transparent
```

`Load(file)` tries `fopen(pszFileName, "rb")` first; on failure falls through to
`MyDataFileLoad(pszFileName, dwSize)` (the .wdf-pack lookup) and recurses through
the `Load(size, void*)` overload.

---

## client-5517 surviving usage

The retail-era purpose — generic per-sprite click-mask for any UI bitmap — has
shrunk in 5517. Current observed usage:

| Binary | Strings / call-site | Purpose |
|---|---|---|
| `graphic.dll` | `"CAlphaMask"` (debug class-name string at `0x10043cfc`, no method symbols) | RTTI/debug leftover only — class definition retained, no in-game caller in the verified scan |
| `Conquer.exe` | `TableMaskSizeX/Y`, `ChairMaskSizeX/Y` (read by `sub_745225` from `ini/TexasHoldEm.ini` `[TexasPublic]`) | Texas Hold'em furniture click hit-test: which pixels of the table/chair sprite are clickable seats |

No `CAlphaMask::IsTransparent`-shaped call site survives in `Role3D.dll` /
`RoleView.dll` — the hero render pipeline does not consume this type. The
projective shadow path is a separate subsystem (see Phase C2 below).

The class is small enough and self-contained enough that the managed port lands
as a clean primitive callers can compose on demand, without driving any specific
caller into the same slice.

---

## Managed port seams (`Conquer.Assets.AlphaMask`)

```csharp
public interface IAlphaMaskFileLoader
{
    byte[]? Load(string filePath);   // null on miss; mirrors fopen + MyDataFileLoad fallback
}

public sealed class CAlphaMask
{
    public int  Width  { get; }
    public int  Height { get; }
    public bool IsLoaded { get; }

    public bool IsTransparent(int x, int y);                                       // OOB ⇒ true
    public bool Load(int width, int height, ReadOnlySpan<byte> maskData);          // copies (w*h/8 + 1) bytes
    public bool Load(int width, int height, string filePath, IAlphaMaskFileLoader loader);
    public void Reset();                                                           // clears buffer + dims
}
```

### Invariants (tested)

- Pre-`Load`: every `IsTransparent(x, y)` returns `true` (no buffer ⇒ everything passes through).
- Buffer size formula `(w * h) / 8 + 1` matches retail `CreateBuffer`; oversize source span tolerated, undersize rejected (`Load` returns false, no state mutation).
- Bit ordering is LSB-first within each byte (retail line 57: `BYTE bMask = 1 << nBitOffset;`).
- OOB coordinates always return `true` (retail guard at line 44-50).
- `Load(filePath, loader)` returns `false` when the loader returns `null`; throws on `null`/empty path or `null` loader.
- `Reset` releases the buffer (mirrors retail `SAFE_DELETE(m_pBuffer)` in the destructor).

### What this port does **not** cover

- The retail `Load(file)` filename → fopen → `MyDataFileLoad` chain is split: callers wrap the lookup in an `IAlphaMaskFileLoader` impl. Same end-state, but the I/O strategy is the caller's choice (loose-file priority vs. .wdf-pack priority lives in the impl, not the mask).
- Endianness inside the buffer is not transcoded — managed reads the same byte stream the native loader would have produced. The retail `.mask` file format is a flat little-endian bitfield, which `Load(int, int, ReadOnlySpan<byte>)` consumes as-is.

---

## Phase C2 (deferred): projective shadow path

The retail "shadow" subsystem callers might expect alongside `CAlphaMask` lives in
a different binary in 5517: Role3D.dll's `3TechnicProcessorX.cpp` projective
shadow renderer.

- `BeginProjectiveShadowMap` / `EndProjectiveShadowMap` — exported from `graphic.dll`, called by Role3D.dll's `sub_10007f60`
- `I3DRole_StoreShadowRenderParameters` (Role3D.dll export, `0x10004820`) — stores intensity/x/y/z/alpha at `role+0x14..+0x24`
- `sub_10007f60` walks: validate render-target + render-callback → clear buffer → save view inverse → save current camera mode (perspective vs ortho) → set up shadow-light look + projection (45° persp or 512×512 ortho) → compute viewProj × bias → restore original camera state → `BeginProjectiveShadowMap(viewProjBias)` → invoke render callback → `EndProjectiveShadowMap()`
- The bias matrix written into `data_10022d80..` packs the standard `[0.5, 0, 0, 0; 0, -0.5, 0, 0; 0, 0, 1, 0; tx, ty, 0, 1]` projective-texture remap with per-light texel offsets `0.5/width`, `0.5/height`

That subsystem is a full C3Engine integration (shadow-map render target, render callback dispatch, camera-state save/restore, custom matrix multiply) and lands as its own slice once the C3Engine render-target seam is mirrored. It is intentionally out of scope for the `CAlphaMask` port.

---

## Cross-refs

- **Retail source:** `40_tools/fight-master/my_client/3DBaseCode/AlphaMask.{h,cpp}` — complete header + cpp (109 lines total)
- **Managed code:** `10_work/src/Conquer.Assets/AlphaMask/CAlphaMask.cs`
- **Tests:** `10_work/tests/Conquer.Tests/Assets/AlphaMask/CAlphaMaskTests.cs` — 14 tests covering buffer-size rule, OOB, LSB-first bit ordering, multi-row linear index, byte-boundary crossing, reload, file-loader DI, null-arg validation
- **5517 usage:** `Conquer.exe` `sub_745225` (`ini/TexasHoldEm.ini` reader), `graphic.dll` `0x10043cfc` (RTTI debug string)
- **Adjacent (separate subsystem):** Role3D.dll `sub_10007f60` projective shadow render path (Phase C2)
