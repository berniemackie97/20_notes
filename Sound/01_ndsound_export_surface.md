# NDsound.dll — export surface, and its drift from the ancestor source

Two independent sources pin this API, and they disagree in ways that matter.

1. **The ancestor source header** `40_tools/eosource/soul-code/NDSound/NDsound.h` declares the
   intended API with real C signatures, return types and defaulted parameters. Per
   [[eosource-is-the-5517-ancestor]] this tree is the same source one revision earlier.
2. **The shipped `NDsound.dll`** — its PE export directory, read directly from the file rather than
   from a symbol list, is authoritative for what this build actually exposes.

## Shipped exports — 26, from the PE export directory

All named, no ordinal-only entries. `__stdcall` decoration means each name states its own argument
byte count, so arity is checkable without reading an instruction.

```
_DXSoundinit@4        _DXDestroy@0          _DXPause@0            _DXContinue@0
_DXProcessSound@8     _DXPlaySound@24       _DXGetSound@12        _DXCloseSound@12
_DXClose2DSound@4     _DXSet2DSoundPos@12   _DXCloseAllSound@0
_DXPlay3DSound@32     _DXGet3DSound@12      _DXClose3DSound@4     _DXSet3DSoundPos@16
_DXPlayMedia@12       _DXCloseMedia@4       _DXCloseAllMedia@0
_DXSetVolume@16       _DXSetMusicVolume@4   _DXGetMusicVolume@0
_DXSetSoundVolume@4   _DXGetSoundVolume@0   _DXSaveMusicVolume@0  _DXFlushVolume@0
_NdSRegisterEvent@4
```

`Conquer.exe` imports **15** of them, by name, from its own import table:

```
_DXSoundinit@4  _DXDestroy@0  _DXProcessSound@8  _NdSRegisterEvent@4
_DXPlaySound@24  _DXCloseSound@12  _DXClose2DSound@4  _DXSet2DSoundPos@12  _DXCloseAllSound@0
_DXPlayMedia@12  _DXCloseMedia@4  _DXCloseAllMedia@0
_DXSetVolume@16  _DXSetMusicVolume@4  _DXSetSoundVolume@4
```

Notably the client does **not** import `_DXGetSound@12`, nor any of the 3D-sound entry points.

## Drift from the ancestor header

| Difference | Ancestor | Shipped 5517 |
|---|---|---|
| `Check2DSound(CSound*) -> BOOL` | declared `DLLAPI __stdcall` | **not exported** |
| `DXPlay3DSound` | 6 parameters | `@32`, i.e. 8 |
| `DXPlayMedia` | 2 parameters | `@12`, i.e. 3 |
| `DXSaveMusicVolume` | absent | `@0` |
| `DXFlushVolume` | absent | `@0` |
| `NdSRegisterEvent` | absent | `@4` |

Every other declaration matches its decorated arity exactly, which is what makes the six
differences above trustworthy rather than noise.

## `_NdSRegisterEvent@4` is exception telemetry, not a playback notification

It stores its single argument into the global `0x10016608`. That global is read at the entry and
exit of every DX export's SEH `__except` handler and invoked as

```
callback(0, context, "Catch in DXSoundinit")
```

so it is a crash-reporting hook the host installs, one message per export. It has nothing to do
with sounds finishing. Recorded explicitly because the name invites the opposite reading.

## What this means for `IMapSoundDevice.IsActive`

`Conquer.Assets.Map.IMapSoundDevice.IsActive` documents itself as mirroring `Check2DSound`. **That
citation is correct** — `Check2DSound(CSound*)` is a real NDsound API, declared `DLLAPI BOOL
__stdcall` in the ancestor header, and taking a sound handle and returning a boolean is exactly a
liveness query.

What is true, and narrower, is that **this build does not export it**. The capability still exists
inside the DLL — `NdSound2dInstance_IsPlaying` (`0x10003552`) is present but not exported — so a
faithful client cannot reach it through the DLL boundary the way the ancestor source could.

That is an open question, not a defect in the managed seam: how the 5517 client determines that a
2D sound has finished, given it imports neither `Check2DSound` nor `DXGetSound`. `DXProcessSound`
is the only per-frame entry point it does import, so that is where to look next.

> **Correction.** An earlier pass in this session asserted that `Check2DSound` "does not exist" and
> that the citation was invented, on the strength of two name searches inside the Binary Ninja
> database. That was wrong twice over: the search proved only that the *shipped DLL does not export
> it*, and the ancestor source header — a first-class evidence source for this project — declares
> it. The same pass also missed `_NdSRegisterEvent@4` entirely by reading a symbol list instead of
> the PE export directory, and then guessed that it was a playback-finished notification. Absence
> found by searching one source is not absence.
