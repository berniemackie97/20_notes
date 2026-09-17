# Map sound in 5517 — and why the managed `CMapSound` models the wrong class

## Resolution of the `Check2DSound` thread

`Check2DSound` is real and is genuinely *used* by the ancestor source.
`40_tools/eosource/soul-code/3dgamemap/MapSound.cpp`:

```cpp
void CMapSound::Play()
{
    if(m_pSound && Check2DSound(m_pSound))
        DXClose2DSound(m_pSound);
    if(m_dwInterval == 0)
        m_pSound = (CSound*)DXPlaySound(m_szFile, m_posWorld.x, m_posWorld.y, m_nRange, -1, m_nVolume);
    else
        m_pSound = (CSound*)DXPlaySound(m_szFile, m_posWorld.x, m_posWorld.y, m_nRange,  0, m_nVolume);
}
```

`Conquer.Assets.Map.CMapSound` ports this faithfully, down to the
`interval == 0 ? -1 : 0` loop flag and the liveness check before closing. **The managed code is a
correct port of the source it cites.** Nothing is wrong with it as a transcription.

## But 5517 does not contain that class

Four independent observations, each checked against a primary source:

1. `Check2DSound` is **not among the 26 exports** of the shipped `NDsound.dll` (PE export
   directory). See [01_ndsound_export_surface.md](01_ndsound_export_surface.md).
2. `Conquer.exe` imports 15 NDsound functions (PE import table) and imports **neither**
   `Check2DSound` nor `DXGetSound`, so it has no way to ask whether a handle is still playing.
3. No shipped binary — `Conquer.exe`, `Role3D.dll`, `GameRole.dll`, `C3_CORE_DLL.dll`,
   `graphic.dll`, `NDsound.dll` — contains the bytes `MapSound`, `CMapSound` or `Check2DSound`
   (byte-exact count, not a `grep`; see the caution below).
4. Stronger still: `Conquer.exe` retains **393 `.cpp` source paths** in its assert strings, across
   four directories, and **43 of them are from `3DGameMap`** — the directory that holds
   `MapSound.cpp` in every reference tree. Its siblings are all present (`MapInfo.cpp`,
   `MapItemManager.cpp`, `MapSeeker.cpp`, `Radar.cpp`, `Weather.cpp`, …). `MapSound.cpp` is not.
   A file only leaves a retained path if it contains an assert, so this is strong rather than
   absolute — but the directory around it is densely represented.
5. The map sound that 5517 *does* have has a different design, below.

Taken together: the interval-driven `CMapSound` is ancestor code that this build does not use, and
whose central primitive this build could not call even if it did.

## What 5517 actually does: `CMapType3SubcomponentType0F`

A scenery subcomponent, loaded from the map file.

| Field | Meaning |
|---|---|
| `+0x0C` / `+0x10` | world X / Y |
| `+0x14` / `+0x18` | projected tile X / Y, with `0x3C` subtracted from X |
| `+0x20` | `CSound*` handle |
| `+0x24` | range |
| `+0x28` | volume |
| `+0x2C` | sound file path |

**`StartSoundPlayback`** (`0x6459CB`):

```c
if (handle) DXClose2DSound(handle);
handle = DXPlaySound(path, worldX, worldY, range, -1, volume);
```

It is called from exactly one place — `CMapSceneryComponent_LoadSubcomponentsFromMapReader`
(`0x6358FD`) — so it runs **once, at map load**, not on a timer.

**`SetSoundScreenPositionAndProjectTilePair`** (`0x6458EF`):

```c
worldX = x; worldY = y;
if (handle) DXSet2DSoundPos(handle, x, y);
CGameMap_ProjectScreenPointToTileCoordinatesUnchecked(map, x, y, &tileX, &tileY);
tileX -= 0x3C;
```

So the 5517 model is: **start once with loop `-1`, then reposition as the view moves.** There is no
interval, no replay, and no liveness poll — which is consistent with the liveness primitive being
absent from the import table. The `close-then-play` guard at the top of `StartSoundPlayback` exists
only to make a repeated start idempotent, not to poll.

## Consequence for the managed client

`Conquer.Assets.Map.CMapSound` should not be the map sound path for a 5517 reconstruction. It is a
faithful port of an *earlier* revision's class. The 5517 behaviour to reproduce is the Type0F
subcomponent above, whose seam needs only `Play`, `Close` and `SetPosition` — **not** `IsActive`.

Left open deliberately: whether any other 5517 subsystem needs a liveness check, and if so how it
gets one without `Check2DSound` or `DXGetSound`. Nothing found so far requires it.

## Tooling caution for anyone re-checking this

The reference sources under `40_tools/` are **ISO-8859 with CRLF**, and the shell's `grep` is a
`ugrep` wrapper invoked with `-I`, which classifies them as binary and skips them silently —
returning zero matches and exit code 1, indistinguishable from a real absence.

Measured on `eosource/soul-code/3dgamemap/MapSound.cpp`, which contains `Check2DSound` three times:
the wrapper reports `0`, while `/usr/bin/grep`, `rg` and a python byte count all report `3`.

An earlier pass on this very question was misled by exactly that, concluding `Check2DSound` appeared
only in a header when it has three call sites in `MapSound.cpp`. **Use `/usr/bin/grep`, `rg`, or
python for these trees and for any binary.** Every claim in this note was re-derived with one of
those.
