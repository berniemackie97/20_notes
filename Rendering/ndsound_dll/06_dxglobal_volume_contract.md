# `_DXSet*Volume` / `_DXGet*Volume` Contracts (Verified)

## Export -> engine mappings

- `_DXSetMusicVolume@4` (`0x10009353`) -> `NdSoundEngine_SetMusicVolumePercent`
- `_DXSetSoundVolume@4` (`0x10009406`) -> `NdSoundEngine_SetSoundVolumePercent`
- `_DXGetMusicVolume@0` (`0x100094B9`) -> `NdSoundEngine_GetMusicVolumePercent`
- `_DXGetSoundVolume@0` (`0x10009533`) -> `NdSoundEngine_GetSoundVolumePercent`

---

## `_DXSetMusicVolume@4`

`_DXSetMusicVolume@4(requestedPercent)`

Verified behavior:

1. Calls `NdSoundEngine_SetMusicVolumePercent(g_NdSoundEngineSingleton, requestedPercent)`.
2. In core helper, when engine init flag is set (`this+0x1c != 0`):
   - clamp input to `[0, 100]`,
   - store clamped value at engine field `+0x10`,
   - iterate active media-instance vector and call `NdSoundMediaInstance_SetVolumePercent(instance, clamped)`.

Return semantics:

- Legacy helper returns a loop-carried value (vector count / pointer-style fallback), not a strict success code.
- Treat as side-effect API.

---

## `_DXSetSoundVolume@4`

`_DXSetSoundVolume@4(requestedPercent)`

Verified behavior:

1. Calls `NdSoundEngine_SetSoundVolumePercent(g_NdSoundEngineSingleton, requestedPercent)`.
2. In core helper, when engine init flag is set:
   - clamp input to `[0, 100]`,
   - store clamped value at engine field `+0x14`,
   - iterate active 2D instances and reapply volume with `NdSound2dInstance_ApplyCompositeVolume(instance, globalSoundPercent)`,
   - iterate active 3D instances and reapply volume with `NdSound3dInstance_ApplyGlobalVolumePercent(instance, globalSoundPercent)`.

Return semantics:

- Legacy helper returns a loop-carried value (vector count / pointer-style fallback), not a strict success code.
- Treat as side-effect API.

---

## `_DXGetMusicVolume@0`

`_DXGetMusicVolume@0()`

Verified behavior:

- Returns `NdSoundEngine_GetMusicVolumePercent(g_NdSoundEngineSingleton)`.
- Getter is direct field load from engine offset `+0x10`.
- Wrapper does not perform explicit initialization/null checks before call.

---

## `_DXGetSoundVolume@0`

`_DXGetSoundVolume@0()`

Verified behavior:

- Returns `NdSoundEngine_GetSoundVolumePercent(g_NdSoundEngineSingleton)`.
- Getter is direct field load from engine offset `+0x14`.
- Wrapper does not perform explicit initialization/null checks before call.
