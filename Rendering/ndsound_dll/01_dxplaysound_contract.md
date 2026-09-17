# `_DXPlaySound@24` Contract

## Export + core implementation

- Export: `_DXPlaySound@24` (`0x100085FC`)
- Core function: `NdSoundEngine_PlaySound2dOrPositional` (`0x1000684A`)

## Verified argument semantics

`_DXPlaySound@24(soundPath, emitterX, emitterY, audibleRange, replayCount, selfVolumePercent)`

- `soundPath`:
  - required, non-empty, not `" "`
  - extension must be `.WAV` (case-insensitive)
- `emitterX`, `emitterY`:
  - positional key / emitter coordinates
- `audibleRange`:
  - `0` => non-positional playback path
  - non-zero => positional attenuation and pan path
- `replayCount`:
  - `-1` => loop mode
  - `>= 0` => replay budget consumed by `_DXProcessSound@8`
- `selfVolumePercent`:
  - per-sound volume scaler stored on sound instance

## Verified behavior

1. Validate engine init + `soundPath` + `.WAV`.
2. For non-loop requests (`replayCount != -1`), reject when global sound volume `< 20` or `selfVolumePercent < 20`.
3. Try to reuse an existing active sound instance with matching `(path, positional key)`.
4. Otherwise allocate a new 2D sound instance and configure metadata:
  - playback flags,
  - emitter/range when positional,
  - replay mode and self volume.
5. Start playback and return handle; failure returns null.

## Positional attenuation (verified formula)

For positional sounds, initial/requested instance volume is computed from listener distance:

`distance = floor(sqrt((listenerX - emitterX)^2 + (listenerY - emitterY)^2))`

When `distance < audibleRange`:

`attenuated = (((abs(audibleRange - distance) * 100 / audibleRange) * 100 * globalSoundVolume) / 10000)`

Then `attenuated` is clamped to `<= globalSoundVolume`.

## Composite volume write to DirectSound buffer

`NdSound2dInstance_ApplyCompositeVolume` (`0x10002E39`) combines caller volume and self volume:

- caller volume arg (`0..100`) is stored on instance (`+0xB4`)
- self volume percent comes from instance (`+0xB8`)
- final DirectSound volume is clamped to `[-5000, 0]` dB range before `SetVolume`.

## `_DXProcessSound@8` linkage

`_DXProcessSound@8` (`0x10008940`) -> `NdSoundEngine_ProcessFrame` (`0x10007366`) performs:

- listener position update,
- positional attenuation/pan refresh for active positional sounds,
- replay-count handling for non-loop sounds,
- stale-handle cleanup from 2D/3D vectors.
