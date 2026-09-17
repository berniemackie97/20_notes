# `_DXSaveMusicVolume@0` / `_DXFlushVolume@0` Contracts

## Export -> engine mappings

- `_DXSaveMusicVolume@0` (`0x100097C8`) -> `NdSoundEngine_SaveCurrentVolumesAndMuteOutput` (`0x10004F1A`)
- `_DXFlushVolume@0` (`0x10009757`) -> `NdSoundEngine_StartSavedVolumeRestore` (`0x10004EE4`)

## `_DXSaveMusicVolume@0`

`_DXSaveMusicVolume@0()`

Verified behavior in `NdSoundEngine_SaveCurrentVolumesAndMuteOutput`:

1. Sets engine field `+0x18` to `1`.
2. Saves current global volumes:
   - `savedMusicVolumePercent` (`+0x08`) = `musicVolumePercent` (`+0x10`)
   - `savedSoundVolumePercent` (`+0x0C`) = `soundVolumePercent` (`+0x14`)
3. Iterates active 3D sound instances and calls `NdSound3dInstance_UpdateRelativePositionFromListener(instance, 0, 0, 0)`.
4. Calls `NdSoundEngine_SetSoundVolumePercent(engine, 0)`.
5. Calls `NdSoundEngine_SetMusicVolumePercent(engine, 0)`.

Wrapper notes:

- Export wrapper directly calls engine helper via singleton.
- No explicit null guard in the wrapper.

## `_DXFlushVolume@0`

`_DXFlushVolume@0()`

Verified behavior in `NdSoundEngine_StartSavedVolumeRestore`:

1. Sets engine field `+0x18` to `0`.
2. Sets delayed-restore counter field `+0x20` to `1`.
3. Copies saved volume slots back into current slots:
   - `musicVolumePercent` (`+0x10`) = `savedMusicVolumePercent` (`+0x08`)
   - `soundVolumePercent` (`+0x14`) = `savedSoundVolumePercent` (`+0x0C`)

Wrapper notes:

- Export wrapper directly calls engine helper via singleton.
- No explicit null guard in the wrapper.

## Delayed restore finalization (in `NdSoundEngine_ProcessFrame`)

The restore sequence is completed inside `NdSoundEngine_ProcessFrame` (`0x10007360`):

1. When field `+0x20` is non-zero, it is incremented each frame (`uint16` behavior).
2. A signed comparison is used: finalize when `(short)restoreCounter > 30`.
3. On finalize:
   - reapplies `musicVolumePercent` from field `+0x10`,
   - reapplies `soundVolumePercent` from field `+0x14`,
   - clears saved slots `+0x08` and `+0x0C`,
   - clears restore counter `+0x20`.

This is the verified source for `LegacyDxVolumeLifecycleContract` constants and threshold logic.
